class InputEngineWorker {
    static HeartbeatIntervalMs := 1000
    static ParentTimeoutMs := 15000
    static MaximumObservationEvents := 2048
    static ObservationEventsPerPoll := 16

    static StartFromEnvironment() {
        workerInstance := InputEngineWorker()
        workerInstance.Start()
        return workerInstance
    }

    static RunFromEnvironment() {
        workerInstance := ""
        try {
            workerInstance := InputEngineWorker()
            workerInstance.Start()
            return workerInstance
        }
        catch as startupError {
            cleanupDetail := ""
            if IsObject(workerInstance)
                    && !workerInstance.Shutdown(false)
                cleanupDetail := workerInstance.LastShutdownError
            if cleanupDetail != ""
                startupError := Error(startupError.Message
                    . "；启动失败清理不完整：" cleanupDetail)
            this.WriteStartupFailure(startupError)
            ExitApp(1)
        }
    }

    static WriteStartupFailure(startupError) {
        errorPath := EnvGet("KMR_WORKER_ERROR_PATH")
        if errorPath == ""
            return false
        try {
            if FileExist(errorPath)
                FileDelete(errorPath)
            FileAppend(startupError.Message "`r`n" startupError.Stack,
                errorPath, "UTF-8-RAW")
            return true
        }
        return false
    }

    __New() {
        this.Role := "input-worker"
        this.RuntimeStandby := EnvGet("KMR_RUNTIME_STANDBY") == "1"
        this.PipeId := this.RequireEnvironment("KMR_IPC_PIPE_ID")
        this.SessionId := this.RequireEnvironment("KMR_IPC_SESSION_ID")
        this.Secret := this.RequireEnvironment("KMR_IPC_SECRET")
        this.ParentProcessId := Integer(this.RequireEnvironment(
            "KMR_PARENT_PROCESS_ID"))
        this.ParentProcessHandle := this.OpenParentProcessHandle()
        this.ScriptPath := this.RequireEnvironment("KMR_MAPPING_SCRIPT_PATH")
        this.VariablePath := this.RequireEnvironment("KMR_VARIABLE_PATH")
        this.OutputRecoveryPath := this.RequireEnvironment(
            "KMR_OUTPUT_RECOVERY_PATH")
        this.Channel := ""
        this.Protocol := AuthenticatedIpcProtocol(this.SessionId,
            this.Role, "gui", this.Secret)
        this.LastParentHeartbeat := this.TickCount64()
        this.LastHeartbeatSent := 0
        this.LastHeartbeatAttempt := 0
        this.LastBackendHealthCheck := 0
        this.ShuttingDown := false
        this.LastShutdownError := ""
        this.Polling := false
        this.Started := false
        this.PowerSuspended := false
        this.PowerBackendWasSuspended := false
        this.PollTimer := ObjBindMethod(this, "Poll")
        this.PowerRecoveryTimer := ObjBindMethod(this,
            "PerformLocalPowerRecovery")
        this.PowerCallback := ObjBindMethod(this, "OnPowerEvent")
        this.ExitCallback := ObjBindMethod(this, "OnExit")
        this.ExitCallbackRegistered := false
        this.ObservationEvents := WorkerEventBuffer(
            InputEngineWorker.MaximumObservationEvents)
        this.ReportedDroppedObservationEvents := 0
        this.ObservationBackpressureCount := 0
        this.HostGui := Gui("+ToolWindow -Caption")
        this.HostGui.Show("Hide w1 h1")
        this.App := InputEngineWorkerApp(this)
        this.BackendStartupError := ""
        backend := RawInputBackend(this.HostGui.Hwnd,
            ObjBindMethod(this, "OnRawInput"))
        this.Runtime := ManagedRuleRuntime(this.App, backend)
        this.RuntimeActive := !this.RuntimeStandby
        this.RawInput := backend.RawInput
    }

    Start() {
        this.Channel := NamedPipeChannel.ConnectClient(this.PipeId, 5000)
        peer := this.Channel.AssertPeerCurrentUser()
        if peer.ProcessId != this.ParentProcessId
            throw Error("输入工作进程连接的 GUI PID 与启动参数不一致。")
        features := ["managed-rules", "raw-input", "device-identification",
            "output-recovery"]
        this.Protocol.SendHello(this.Channel,
            DllCall("kernel32\GetCurrentProcessId", "UInt"),
            this.Channel.UserSid, features)
        this.WaitForParentHello()
        recoveredOutputs := 0
        recoveryError := ""
        try recoveredOutputs := this.App.OutputRecoveryJournal.Recover(
            ObjBindMethod(this, "ReleaseRecoveredOutputKey"))
        catch as outputRecoveryError
            recoveryError := outputRecoveryError.Message
        this.RawInput.Start()
        report := this.RuntimeActive
            ? this.ApplyConfiguration() : this.BuildIdleReport()
        capabilities := this.Runtime.Backend.GetCapabilities()
        backendAvailable := capabilities.Has("available")
            && capabilities["available"] is JsonBoolean
            && capabilities["available"].Value
        this.Started := true
        OnMessage(0x0218, this.PowerCallback)
        OnExit(this.ExitCallback)
        this.ExitCallbackRegistered := true
        this.Send("ready", Map(
            "mapping_count", report.MappingCount,
            "registration_count", report.RegistrationCount,
            "recovered_output_keys", recoveredOutputs,
            "output_recovery_error", recoveryError,
            "worker_role", this.Role,
            "backend", capabilities,
            "backend_available", JsonBoolean(backendAvailable),
            "backend_error", this.BackendStartupError,
            "runtime_active", JsonBoolean(this.RuntimeActive)))
        SetTimer(this.PollTimer, 10)
        return true
    }

    WaitForParentHello() {
        deadline := this.TickCount64() + 5000
        while this.TickCount64() < deadline {
            encoded := this.Channel.TryRead()
            if encoded == "" {
                Sleep(10)
                continue
            }
            message := this.Protocol.ValidateMessage(encoded)
            peer := this.Channel.AssertPeerCurrentUser()
            this.Protocol.ValidateHello(message, peer.ProcessId, peer.UserSid)
            this.LastParentHeartbeat := this.TickCount64()
            return true
        }
        throw Error("等待 GUI IPC 握手超时。")
    }

    Poll(*) {
        if this.ShuttingDown || this.Polling
            return false
        this.Polling := true
        try {
            Loop 100 {
                encoded := this.Channel.TryRead()
                if encoded == ""
                    break
                message := this.Protocol.ValidateMessage(encoded)
                this.HandleMessage(message)
            }
            now := this.TickCount64()
            if this.RuntimeActive && !this.PowerSuspended
                    && now - this.LastBackendHealthCheck >= 250 {
                backendHealth := this.Runtime.Backend.HealthCheck()
                this.LastBackendHealthCheck := now
                if !backendHealth.Has("healthy")
                        || !(backendHealth["healthy"] is JsonBoolean)
                        || !backendHealth["healthy"].Value
                    throw Error("设备后端运行异常："
                        . (backendHealth.Has("detail")
                            ? backendHealth["detail"] : "未知错误"))
            }
            if now - this.LastHeartbeatAttempt
                    >= InputEngineWorker.HeartbeatIntervalMs {
                this.LastHeartbeatAttempt := now
                if this.TrySend("heartbeat", Map("state", "running"))
                    this.LastHeartbeatSent := now
                else
                    this.ObservationBackpressureCount++
            }
            this.FlushObservationEvents()
            if !this.IsParentRunning()
                    || (!this.PowerSuspended
                        && now - this.LastParentHeartbeat
                            > InputEngineWorker.ParentTimeoutMs) {
                this.App.TraceEvent("ipc", "parent_heartbeat_lost",
                    {Outcome: "shutdown"})
                this.Shutdown(true)
            }
            return true
        } catch as pollError {
            this.WriteStartupFailure(pollError)
            try this.App.TraceEvent("ipc", "worker_poll_failed", {
                Outcome: "shutdown", Detail: pollError.Message})
            this.Shutdown(true)
            return false
        } finally this.Polling := false
    }

    HandleMessage(message) {
        switch message["type"] {
            case "heartbeat":
                this.ValidateParentHeartbeat(message["payload"])
                this.LastParentHeartbeat := this.TickCount64()
                return true
            case "command":
                this.LastParentHeartbeat := this.TickCount64()
                return this.HandleCommand(message["payload"])
            default:
                throw Error("输入工作进程收到不支持的消息类型。")
        }
    }

    ValidateParentHeartbeat(payload) {
        if Type(payload) != "Map" || payload.Count != 1
                || !payload.Has("state")
                || Type(payload["state"]) != "String"
                || payload["state"] != "running"
            throw Error("GUI 心跳负载格式无效。")
        return true
    }

    HandleCommand(payload) {
        if Type(payload) != "Map" || payload.Count != 3
                || !payload.Has("request_id")
                || Type(payload["request_id"]) != "String"
                || !RegExMatch(payload["request_id"],
                    "^[0-9a-f]{32}$")
                || !payload.Has("command")
                || Type(payload["command"]) != "String"
                || !payload.Has("data")
                || Type(payload["data"]) != "Map"
            throw Error("输入工作进程命令格式无效。")
        requestId := payload["request_id"]
        command := StrLower(payload["command"])
        data := payload["data"]
        try {
            this.ValidateCommandData(command, data)
            switch command {
                case "apply": result := this.ApplyConfiguration()
                case "activate": result := this.ActivateRuntime()
                case "deactivate": result := this.DeactivateRuntime()
                case "suspend": result := this.SuspendRuntime()
                case "resume": result := this.ResumeRuntime()
                case "reset": result := this.ResetRuntime(data)
                case "devices": result := Map("devices", this.GetDevices())
                case "power_recover": result := this.RecoverAfterResume(data)
                case "health": result := this.GetHealth()
                case "shutdown":
                    this.SendResponse(requestId, true, Map("stopping", true))
                    this.Shutdown(true)
                    return true
                default: throw Error("不支持的输入工作进程命令：" command)
            }
            this.SendResponse(requestId, true, this.ResultToMap(result))
        } catch as commandError {
            this.SendResponse(requestId, false, Map(), commandError.Message)
        }
        return true
    }

    ValidateCommandData(command, data) {
        switch command {
            case "apply", "activate", "deactivate", "suspend", "resume",
                    "devices", "health", "shutdown":
                if data.Count
                    throw Error("工作进程命令不接受 data 字段。")
            case "reset":
                if data.Count > 1 || (data.Count == 1 && !data.Has("reason"))
                    throw Error("reset 命令 data 字段无效。")
                if data.Has("reason")
                        && (Type(data["reason"]) != "String"
                            || StrLen(data["reason"]) > 128)
                    throw Error("reset 命令 reason 必须是短字符串。")
            case "power_recover":
                if data.Count > 1 || (data.Count == 1
                        && !data.Has("desired_suspended"))
                    throw Error("power_recover 命令 data 字段无效。")
                if data.Has("desired_suspended")
                        && !(data["desired_suspended"] is JsonBoolean)
                    throw Error("desired_suspended 必须是布尔值。")
        }
        return true
    }

    ApplyConfiguration() {
        this.App.VariableStore.Load()
        mappings := this.App.Repository.Load()
        report := this.Runtime.ApplyMappings(mappings)
        return {
            MappingCount: mappings.Length,
            RegistrationCount: report.Registrations,
            ConflictCount: report.Issues.Length,
            Backend: report.Capabilities
        }
    }

    ActivateRuntime() {
        report := this.ApplyConfiguration()
        this.RuntimeActive := true
        return this.ResultToMap(report)
    }

    DeactivateRuntime() {
        if !this.RuntimeActive
            return Map("changed", JsonBoolean(false))
        this.Runtime.ApplyMappings([])
        this.RuntimeActive := false
        return Map("changed", JsonBoolean(true))
    }

    BuildIdleReport() {
        return {
            MappingCount: 0,
            RegistrationCount: 0,
            ConflictCount: 0,
            Backend: this.Runtime.Backend.GetCapabilities()
        }
    }

    GetDevices() {
        return this.Runtime.Backend.GetDevices()
    }

    SuspendRuntime() {
        changed := this.Runtime.Backend.Suspend()
        this.Runtime.ResetActiveState("remote_suspend")
        return Map("changed", JsonBoolean(changed))
    }

    ResumeRuntime() {
        changed := this.Runtime.Backend.Resume()
        return Map("changed", JsonBoolean(changed))
    }

    ResetRuntime(data) {
        reason := data.Has("reason") ? data["reason"] : "remote_reset"
        released := this.Runtime.ResetActiveState(reason)
        return Map("released", released)
    }

    OnPowerEvent(wParam, *) {
        try return this.ProcessPowerEvent(wParam)
        catch as powerError {
            this.WriteStartupFailure(powerError)
            try this.App.TraceEvent("system", "power_callback_failed", {
                Outcome: "shutdown", Detail: powerError.Message})
            this.Shutdown(true)
            return false
        }
    }

    ProcessPowerEvent(wParam) {
        now := this.TickCount64()
        this.LastParentHeartbeat := now
        this.LastHeartbeatSent := now
        if wParam == 0x4 {
            if this.PowerSuspended
                return true
            SetTimer(this.PowerRecoveryTimer, 0)
            this.PowerSuspended := true
            this.PowerBackendWasSuspended := !!this.Runtime.Backend.Suspended
            failures := []
            this.CollectFailure(failures, "重置运行时输出",
                () => this.Runtime.ResetActiveState("system_suspend"))
            if !this.PowerBackendWasSuspended
                this.CollectFailure(failures, "挂起输入后端",
                    () => this.Runtime.Backend.Suspend())
            this.CollectFailure(failures, "停止 Raw Input",
                () => this.RawInput.Stop())
            if failures.Length
                throw Error("系统挂起清理不完整："
                    . this.JoinMessages(failures, "；"))
            return true
        }
        if wParam == 0x12 || wParam == 0x7 {
            SetTimer(this.PowerRecoveryTimer, -750)
            return true
        }
        return false
    }

    PerformLocalPowerRecovery(*) {
        try return this.RecoverAfterResume()
        catch as recoveryError {
            this.App.TraceEvent("system", "power_recovery_failed", {
                Outcome: "awaiting_parent_retry", Detail: recoveryError.Message})
            return false
        }
    }

    RecoverAfterResume(data := "") {
        targetSuspended := this.PowerBackendWasSuspended
        if Type(data) == "Map" && data.Has("desired_suspended")
            targetSuspended := data["desired_suspended"].Value
        if !this.Runtime.Backend.Suspended
            this.Runtime.Backend.Suspend()
        this.Runtime.ResetActiveState("system_resume")
        if this.RawInput.Started
            devices := this.RawInput.RecoverAfterResume()
        else {
            this.RawInput.Start()
            devices := this.RawInput.GetDevices()
        }
        report := this.RuntimeActive
            ? this.ApplyConfiguration() : this.BuildIdleReport()
        if targetSuspended {
            if !this.Runtime.Backend.Suspended
                this.Runtime.Backend.Suspend()
        } else if this.Runtime.Backend.Suspended
            this.Runtime.Backend.Resume()
        this.PowerSuspended := false
        this.LastParentHeartbeat := this.TickCount64()
        return Map(
            "mapping_count", report.MappingCount,
            "registration_count", report.RegistrationCount,
            "devices", devices,
            "suspended", JsonBoolean(targetSuspended))
    }

    GetHealth() {
        return Map(
            "worker", this.Role,
            "healthy", JsonBoolean(!this.ShuttingDown),
            "backend", this.Runtime.Backend.HealthCheck(),
            "devices", this.GetDevices(),
            "runtime_active", JsonBoolean(this.RuntimeActive),
            "backend_error", this.BackendStartupError,
            "observation_transport", Map(
                "buffer", this.ObservationEvents.GetHealth(),
                "backpressure", this.ObservationBackpressureCount))
    }

    OnRawInput(unifiedEvent) {
        return this.QueueObservationEvent("raw_input", unifiedEvent)
    }

    SendTrace(category, eventName, fields) {
        return this.QueueObservationPayload(Map("kind", "trace",
            "category", String(category), "event_name", String(eventName),
            "fields", this.FieldsToMap(fields)))
    }

    QueueObservationEvent(kind, unifiedEvent) {
        return this.QueueObservationPayload(Map("kind", String(kind),
            "event", unifiedEvent), this.GetMoveCoalesceKey(kind,
                unifiedEvent))
    }

    QueueObservationPayload(payload, moveKey := "", priority := false) {
        return this.ObservationEvents.Push(payload, moveKey, priority)
    }

    GetMoveCoalesceKey(kind, unifiedEvent) {
        if Type(unifiedEvent) != "Map" || !unifiedEvent.Has("phase")
                || String(unifiedEvent["phase"]) != "move"
                || !unifiedEvent.Has("identity")
                || Type(unifiedEvent["identity"]) != "Map"
            return ""
        identity := unifiedEvent["identity"]
        name := identity.Has("name") ? String(identity["name"]) : ""
        deviceId := identity.Has("device_id")
            ? String(identity["device_id"]) : ""
        return String(kind) "|" deviceId "|" name
    }

    FlushObservationEvents() {
        if this.ObservationEvents.DroppedCount
                > this.ReportedDroppedObservationEvents {
            dropped := this.ObservationEvents.DroppedCount
                - this.ReportedDroppedObservationEvents
            report := Map(
                "kind", "trace",
                "category", "ipc",
                "event_name", "observation_events_dropped",
                "fields", Map(
                    "Source", this.Role,
                    "Outcome", "degraded",
                    "Detail", "工作进程观察事件缓冲区已丢弃旧事件。",
                    "Data", Map("dropped", dropped,
                        "queued", this.ObservationEvents.Length)))
            if this.TrySend("event", report)
                this.ReportedDroppedObservationEvents :=
                    this.ObservationEvents.DroppedCount
            else {
                this.ObservationBackpressureCount++
                return false
            }
        }
        sent := 0
        while this.ObservationEvents.Length
                && sent < InputEngineWorker.ObservationEventsPerPoll {
            item := this.ObservationEvents.Peek()
            if !this.TrySend("event", item.Payload) {
                this.ObservationBackpressureCount++
                break
            }
            this.ObservationEvents.RemoveFirst()
            sent++
        }
        return sent
    }

    SendResponse(requestId, succeeded, data := "", errorMessage := "") {
        if data == ""
            data := Map()
        return this.Send("response", Map(
            "request_id", String(requestId),
            "ok", JsonBoolean(!!succeeded),
            "data", data,
            "error", String(errorMessage)))
    }

    Send(messageType, payload) {
        return this.Protocol.SendMessage(this.Channel, messageType, payload)
    }

    TrySend(messageType, payload) {
        return this.Protocol.TrySendMessage(this.Channel, messageType, payload)
    }

    ReleaseRecoveredOutputKey(keyName) {
        Send("{" String(keyName) " up}")
        return true
    }

    Shutdown(exitProcess := false) {
        if this.ShuttingDown
            return false
        this.ShuttingDown := true
        failures := []
        if this.ExitCallbackRegistered {
            this.CollectFailure(failures, "注销退出回调",
                () => OnExit(this.ExitCallback, 0))
            this.ExitCallbackRegistered := false
        }
        this.CollectFailure(failures, "停止轮询计时器",
            () => SetTimer(this.PollTimer, 0))
        this.CollectFailure(failures, "停止电源恢复计时器",
            () => SetTimer(this.PowerRecoveryTimer, 0))
        this.CollectFailure(failures, "注销电源回调",
            () => OnMessage(0x0218, this.PowerCallback, 0))
        this.ObservationEvents.Clear()
        this.CollectFailure(failures, "关闭规则运行时",
            () => this.Runtime.Shutdown())
        if IsObject(this.Channel)
            this.CollectFailure(failures, "关闭 IPC 通道",
                () => this.Channel.Close())
        this.CollectFailure(failures, "销毁 worker 窗口",
            () => this.HostGui.Destroy())
        this.CollectFailure(failures, "关闭父进程监督句柄",
            () => this.CloseParentProcessHandle())
        this.LastShutdownError := this.JoinMessages(failures, "；")
        if this.LastShutdownError != ""
            this.WriteStartupFailure(Error("输入工作进程关闭不完整："
                this.LastShutdownError))
        if exitProcess
            ExitApp(failures.Length ? 1 : 0)
        return failures.Length == 0
    }

    OnExit(*) {
        this.Shutdown(false)
    }

    CollectFailure(failures, label, callback) {
        try callback.Call()
        catch as cleanupError
            failures.Push(label "：" cleanupError.Message)
    }

    JoinMessages(values, separator) {
        result := ""
        for index, value in values
            result .= (index == 1 ? "" : separator) value
        return result
    }

    FieldsToMap(fields) {
        if fields == ""
            return Map()
        if Type(fields) == "Map"
            return fields
        result := Map()
        if IsObject(fields) {
            for propertyName in ["Source", "RuleId", "Outcome", "Detail",
                    "Data"] {
                if fields.HasOwnProp(propertyName)
                    result[propertyName] := fields.%propertyName%
            }
        }
        return result
    }

    ResultToMap(result) {
        if Type(result) == "Map"
            return result
        if !IsObject(result)
            return Map("value", result)
        mapResult := Map()
        for propertyName in result.OwnProps()
            mapResult[propertyName] := result.%propertyName%
        return mapResult
    }

    RequireEnvironment(name) {
        value := EnvGet(name)
        if value == ""
            throw Error("输入工作进程缺少环境变量：" name)
        return value
    }

    OpenParentProcessHandle() {
        if this.ParentProcessId <= 0
            throw Error("输入工作进程收到无效的 GUI 进程标识。")
        handle := DllCall("kernel32\OpenProcess", "UInt", 0x00101000,
            "Int", false, "UInt", this.ParentProcessId, "Ptr")
        if !handle
            throw OSError(A_LastError, "输入工作进程无法监督 GUI 进程。")
        return handle
    }

    IsParentRunning() {
        if !this.ParentProcessHandle
            return false
        exitCode := 0
        if !DllCall("kernel32\GetExitCodeProcess", "Ptr",
                this.ParentProcessHandle, "UInt*", &exitCode, "Int")
            throw OSError(A_LastError, "输入工作进程无法读取 GUI 状态。")
        return exitCode == 259
    }

    CloseParentProcessHandle() {
        if !this.ParentProcessHandle
            return false
        if !DllCall("kernel32\CloseHandle", "Ptr", this.ParentProcessHandle,
                "Int")
            throw OSError(A_LastError, "输入工作进程无法关闭 GUI 监督句柄。")
        this.ParentProcessHandle := 0
        return true
    }

    TickCount64() => DllCall("kernel32\GetTickCount64", "UInt64")
}

class InputEngineWorkerApp {
    __New(worker) {
        this.Worker := worker
        this.Repository := MappingCodeRepository(worker.ScriptPath)
        this.VariableStore := ScopedVariableStore(worker.VariablePath)
        this.ContextService := WindowsContextService()
        this.OutputRecoveryJournal := OutputRecoveryJournal(
            worker.OutputRecoveryPath)
    }

    GetInputDevices() {
        try return this.Worker.GetDevices()
        catch
            return []
    }

    TraceEvent(category, eventName, fields := "") {
        return this.Worker.SendTrace(category, eventName, fields)
    }
}
