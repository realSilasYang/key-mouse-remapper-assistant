class InputWorkerController {
    static StartupTimeoutMs := 8000
    static CommandTimeoutMs := 5000
    static HeartbeatIntervalMs := 1000
    static WorkerTimeoutMs := 15000
    static MaximumCommandTimeoutMs := 60000
    static MaximumStartupErrorBytes := 64 * 1024

    __New(app, inputWorkerPath := "") {
        this.App := app
        this.InputWorkerPath := inputWorkerPath == ""
            ? GetApplicationRootFilePath("workers\input-engine-worker.ahk")
            : String(inputWorkerPath)
        this.States := Map()
        this.Started := false
        this.Starting := false
        this.Stopping := false
        this.Polling := false
        this.LastHeartbeatSent := 0
        this.LastDeviceRefresh := 0
        this.DeviceCache := []
        this.RestartScheduled := false
        this.RestartTicks := []
        this.DesiredSuspended := false
        this.PowerSuspended := false
        this.ActiveRuntimeRole := "input-worker"
        this.PollTimer := ObjBindMethod(this, "Poll")
        this.RestartTimer := ObjBindMethod(this, "RestartAfterFailure")
    }

    EnsureStarted() {
        if this.Started
            return true
        return this.Start()
    }

    Start() {
        if this.Started || this.Starting
            return this.Started
        if this.States.Count
            throw Error("上一个工作进程组尚未完成资源清理。")
        this.InputWorkerPath := this.ValidateWorkerPath(
            this.InputWorkerPath, "输入工作进程")
        this.Starting := true
        this.Stopping := false
        try {
            this.States := Map()
            this.States["input-worker"] := this.CreateState("input-worker",
                this.InputWorkerPath)
            for role, state in this.States
                this.LaunchState(state)
            for role, state in this.States
                this.WaitUntilReady(state)
            this.SelectAndActivateRuntime()
            this.Started := true
            if this.DesiredSuspended {
                this.SendInputCommand("suspend")
            }
            this.LastHeartbeatSent := this.TickCount64()
            SetTimer(this.PollTimer, 50)
            return true
        } catch as startupError {
            cleanupDetail := ""
            try {
                if !this.StopWorkers(true)
                    cleanupDetail := "；启动失败后的进程清理未完成"
            } catch as cleanupError
                cleanupDetail := "；启动失败后的进程清理异常："
                    . cleanupError.Message
            throw Error("输入工作进程组启动失败：" startupError.Message
                . cleanupDetail)
        } finally this.Starting := false
    }

    CreateState(role, entryPath) {
        pipeId := StrLower(HmacSha256.RandomHex(16))
        sessionId := StrLower(HmacSha256.RandomHex(16))
        secret := HmacSha256.RandomHex(32)
        errorDirectory := ""
        SplitPath(this.App.OutputRecoveryJournal.FilePath, , &errorDirectory)
        return {
            Role: role,
            EntryPath: entryPath,
            PipeId: pipeId,
            SessionId: sessionId,
            Secret: secret,
            ErrorPath: errorDirectory "\" role "-startup-error.txt",
            BootstrapPath: "",
            Channel: NamedPipeChannel.CreateServer(pipeId),
            Protocol: AuthenticatedIpcProtocol(sessionId, "gui", role,
                secret),
            ProcessId: 0,
            ProcessHandle: 0,
            ProcessCanTerminate: false,
            Connected: false,
            HelloReceived: false,
            Ready: false,
            ReadyData: Map(),
            LastHeartbeat: this.TickCount64(),
            FailureReported: false,
            PendingRequests: Map(),
            Responses: Map()
        }
    }

    LaunchState(state) {
        environment := Map(
            "KMR_IPC_PIPE_ID", state.PipeId,
            "KMR_IPC_SESSION_ID", state.SessionId,
            "KMR_IPC_SECRET", state.Secret,
            "KMR_PARENT_PROCESS_ID",
                DllCall("kernel32\GetCurrentProcessId", "UInt"),
            "KMR_WORKER_ERROR_PATH", state.ErrorPath)
        if FileExist(state.ErrorPath)
            try FileDelete(state.ErrorPath)
        mappingScriptPath := this.App.HasOwnProp("Repository")
                && IsObject(this.App.Repository)
                && this.App.Repository.HasOwnProp("ScriptPath")
            ? this.App.Repository.ScriptPath : A_ScriptFullPath
        environment["KMR_MAPPING_SCRIPT_PATH"] := mappingScriptPath
        environment["KMR_VARIABLE_PATH"] := this.App.VariableStore.FilePath
        environment["KMR_OUTPUT_RECOVERY_PATH"] :=
            this.App.OutputRecoveryJournal.FilePath
        environment["KMR_WORKER_ROLE"] := state.Role
        environment["KMR_RUNTIME_STANDBY"] := "1"
        bootstrapDirectory := ""
        SplitPath(state.ErrorPath, , &bootstrapDirectory)
        state.BootstrapPath := WorkerBootstrap.Create(bootstrapDirectory,
            state.Role, state.SessionId, environment)
        try {
            workingDirectory := ""
            SplitPath(state.EntryPath, , &workingDirectory)
            commandLine := this.Quote(A_AhkPath) " /ErrorStdOut "
                . this.Quote(state.EntryPath)
                . " --worker-bootstrap " this.Quote(state.BootstrapPath)
            Run(commandLine, workingDirectory, "Hide", &processId)
            state.ProcessId := processId
            canTerminate := false
            try {
                state.ProcessHandle := this.OpenWorkerProcessHandle(processId,
                    &canTerminate)
                state.ProcessCanTerminate := canTerminate
            }
            catch as processHandleError {
                if processId && ProcessExist(processId)
                    try ProcessClose(processId)
                state.ProcessId := 0
                throw processHandleError
            }
        } catch as launchError {
            try WorkerBootstrap.Delete(state.BootstrapPath)
            state.BootstrapPath := ""
            throw launchError
        }
        if !state.ProcessId
            throw Error(state.Role " 没有返回进程标识。")
        return state.ProcessId
    }

    WaitUntilReady(state) {
        deadline := this.TickCount64() + InputWorkerController.StartupTimeoutMs
        while this.TickCount64() < deadline {
            if !this.IsStateProcessRunning(state)
                throw Error(state.Role " 在握手前退出。"
                    . this.ReadWorkerStartupError(state))
            this.PollState(state)
            if state.Ready {
                try WorkerBootstrap.Delete(state.BootstrapPath)
                state.BootstrapPath := ""
                return true
            }
            Sleep(10)
        }
        throw Error(state.Role " 启动与认证握手超时。")
    }

    ReadWorkerStartupError(state) {
        if !FileExist(state.ErrorPath)
            return ""
        try {
            detail := Trim(BoundedFileReader.ReadUtf8(state.ErrorPath,
                InputWorkerController.MaximumStartupErrorBytes,
                InputWorkerController.MaximumStartupErrorBytes,
                "工作进程错误报告"), " `t`r`n")
            return detail == "" ? "" : "；" SubStr(detail, 1, 4000)
        } catch as readError {
            return readError is BoundedFileLimitError
                ? "；" readError.Message : ""
        }
    }

    Poll(*) {
        if this.Polling || this.Stopping || !this.Started
            return false
        this.Polling := true
        activeState := ""
        try {
            for role, state in this.States {
                activeState := state
                if state.FailureReported
                    continue
                if !this.IsStateProcessRunning(state) {
                    this.HandleWorkerFailure(state, "工作进程已退出。"
                        . this.ReadWorkerStartupError(state))
                    return false
                }
                this.PollState(state)
            }
            ; A pending group restart may still need to attribute another
            ; failed role, but no failed channel should receive heartbeats.
            if this.RestartScheduled
                return false
            now := this.TickCount64()
            if now - this.LastHeartbeatSent
                    >= InputWorkerController.HeartbeatIntervalMs {
                for role, state in this.States {
                    activeState := state
                    this.WriteMessage(state, "heartbeat",
                        Map("state", "running"))
                }
                this.LastHeartbeatSent := now
            }
            for role, state in this.States {
                if !this.PowerSuspended && now - state.LastHeartbeat
                        > InputWorkerController.WorkerTimeoutMs {
                    this.HandleWorkerFailure(state,
                        "工作进程认证心跳超时。")
                    return false
                }
            }
            return true
        } catch as pollError {
            if !this.Stopping {
                detail := pollError.Message
                if IsObject(activeState)
                    detail .= this.ReadWorkerStartupError(activeState)
                this.HandleWorkerFailure(activeState, detail)
            }
            return false
        } finally this.Polling := false
    }

    PollState(state) {
        previousCritical := A_IsCritical
        deferredEvents := []
        Critical()
        try {
            if !state.Connected {
                if !state.Channel.PollConnection()
                    return false
                peer := state.Channel.AssertPeerCurrentUser()
                if peer.ProcessId != state.ProcessId {
                    state.Channel.RejectServerConnection()
                    return false
                }
                state.Connected := true
                state.Protocol.SendHello(state.Channel,
                    DllCall("kernel32\GetCurrentProcessId", "UInt"),
                    state.Channel.UserSid,
                    ["supervision", "heartbeat", "authenticated-command"])
            }
            Loop 100 {
                encoded := state.Channel.TryRead()
                if encoded == ""
                    break
                try message := state.Protocol.ValidateMessage(encoded)
                catch as validationError
                    throw Error(state.Role " 消息验证失败："
                        validationError.Message)
                this.HandleStateMessage(state, message, deferredEvents)
            }
        } finally Critical(previousCritical ? previousCritical : "Off")
        for payload in deferredEvents
            this.DispatchWorkerEvent(payload)
        return state.Ready
    }

    HandleStateMessage(state, message, deferredEvents := "") {
        switch message["type"] {
            case "hello":
                if state.HelloReceived || state.Ready
                    throw Error(state.Role " 重复发送了握手消息。")
                peer := state.Channel.AssertPeerCurrentUser()
                state.Protocol.ValidateHello(message, peer.ProcessId,
                    peer.UserSid)
                state.HelloReceived := true
                state.LastHeartbeat := this.TickCount64()
            case "ready":
                if !state.HelloReceived
                    throw Error(state.Role " 在握手前报告就绪。")
                if state.Ready
                    throw Error(state.Role " 重复报告就绪。")
                this.ValidateReadyPayload(state, message["payload"])
                state.Ready := true
                state.ReadyData := message["payload"]
                state.LastHeartbeat := this.TickCount64()
            case "heartbeat":
                this.RequireReadyState(state, "心跳")
                this.ValidateHeartbeatPayload(state, message["payload"])
                state.LastHeartbeat := this.TickCount64()
            case "response":
                this.RequireReadyState(state, "响应")
                payload := message["payload"]
                if payload.Count != 4
                        || !payload.Has("request_id")
                        || Type(payload["request_id"]) != "String"
                        || !RegExMatch(payload["request_id"],
                            "^[0-9a-f]{32}$")
                        || !payload.Has("ok")
                        || !(payload["ok"] is JsonBoolean)
                        || !payload.Has("data")
                        || Type(payload["data"]) != "Map"
                        || !payload.Has("error")
                        || Type(payload["error"]) != "String"
                    throw Error(state.Role " 响应格式无效。")
                requestId := payload["request_id"]
                if !state.PendingRequests.Has(requestId) {
                    state.LastHeartbeat := this.TickCount64()
                    return false
                }
                if state.Responses.Has(requestId)
                    throw Error(state.Role " 对同一请求发送了重复响应。")
                state.Responses[requestId] := payload
                state.LastHeartbeat := this.TickCount64()
            case "event":
                this.RequireReadyState(state, "事件")
                state.LastHeartbeat := this.TickCount64()
                if Type(deferredEvents) == "Array"
                    deferredEvents.Push(message["payload"])
                else
                    this.DispatchWorkerEvent(message["payload"])
            default:
                throw Error(state.Role " 发送了不支持的消息类型。")
        }
    }

    ValidateReadyPayload(state, payload) {
        if Type(payload) != "Map"
            throw Error(state.Role " 就绪负载无效。")
        if payload.Count != 9 || !payload.Has("mapping_count")
                || Type(payload["mapping_count"]) != "Integer"
                || payload["mapping_count"] < 0
                || !payload.Has("registration_count")
                || Type(payload["registration_count"]) != "Integer"
                || payload["registration_count"] < 0
                || !payload.Has("recovered_output_keys")
                || Type(payload["recovered_output_keys"]) != "Integer"
                || payload["recovered_output_keys"] < 0
                || !payload.Has("output_recovery_error")
                || Type(payload["output_recovery_error"]) != "String"
                || !payload.Has("worker_role")
                || Type(payload["worker_role"]) != "String"
                || payload["worker_role"] != state.Role
                || !payload.Has("backend")
                || Type(payload["backend"]) != "Map"
                || !payload.Has("backend_available")
                || !(payload["backend_available"] is JsonBoolean)
                || !payload.Has("backend_error")
                || Type(payload["backend_error"]) != "String"
                || !payload.Has("runtime_active")
                || !(payload["runtime_active"] is JsonBoolean)
            throw Error(state.Role " 就绪负载格式无效。")
        return true
    }

    ValidateHeartbeatPayload(state, payload) {
        if Type(payload) != "Map" || payload.Count != 1
            throw Error(state.Role " 心跳负载格式无效。")
        if !payload.Has("state")
                || Type(payload["state"]) != "String"
                || payload["state"] != "running"
            throw Error(state.Role " 心跳负载格式无效。")
        return true
    }

    DispatchWorkerEvent(payload) {
        if Type(payload) != "Map" || !payload.Has("kind")
                || Type(payload["kind"]) != "String"
            throw Error("输入工作进程事件缺少 kind。")
        switch payload["kind"] {
            case "raw_input":
                if payload.Count != 2 || !payload.Has("event")
                        || Type(payload["event"]) != "Map"
                    throw Error("Raw Input 工作进程事件格式无效。")
                this.App.OnRawInputEvent(payload["event"])
            case "trace":
                if payload.Count != 4 || !payload.Has("category")
                        || Type(payload["category"]) != "String"
                        || !payload.Has("event_name")
                        || Type(payload["event_name"]) != "String"
                        || !payload.Has("fields")
                        || Type(payload["fields"]) != "Map"
                    throw Error("工作进程跟踪事件格式无效。")
                this.App.TraceEvent(payload["category"],
                    payload["event_name"], payload["fields"])
            default:
                throw Error("输入工作进程事件类型无效。")
        }
        return true
    }

    RequireReadyState(state, messageLabel) {
        if !state.HelloReceived || !state.Ready
            throw Error(state.Role " 在就绪前发送了" messageLabel "。")
        return true
    }

    SendInputCommand(command, data := "", timeoutMs := "") {
        this.EnsureStarted()
        if !this.States.Has(this.ActiveRuntimeRole)
            throw Error("活动输入工作进程不可用。")
        return this.SendCommand(this.States[this.ActiveRuntimeRole], command,
            data, timeoutMs)
    }

    SendObservationCommand(command, data := "", timeoutMs := "") {
        this.EnsureStarted()
        if !this.States.Has("input-worker")
            throw Error("输入观察工作进程不可用。")
        return this.SendCommand(this.States["input-worker"], command,
            data, timeoutMs)
    }

    SendCommand(state, command, data := "", timeoutMs := "") {
        if !this.Started && !this.Starting
            this.EnsureStarted()
        if data == ""
            data := Map()
        if Type(data) != "Map"
            throw TypeError("工作进程命令数据必须是 Map。")
        if Type(command) != "String"
            throw TypeError("工作进程命令名称必须是字符串。")
        command := StrLower(Trim(command))
        if !RegExMatch(command, "^[a-z][a-z0-9_.-]{0,63}$")
            throw ValueError("工作进程命令名称无效。")
        if timeoutMs == ""
            timeoutMs := InputWorkerController.CommandTimeoutMs
        else if Type(timeoutMs) != "Integer" || timeoutMs < 100
                || timeoutMs > InputWorkerController.MaximumCommandTimeoutMs
            throw ValueError("工作进程命令超时必须是有效的整数毫秒值。")
        requestId := StrLower(HmacSha256.RandomHex(16))
        state.PendingRequests[requestId] := true
        try {
            this.WriteMessage(state, "command", Map(
                "request_id", requestId,
                "command", command,
                "data", data))
            deadline := this.TickCount64() + timeoutMs
            while this.TickCount64() < deadline {
                this.PollState(state)
                if state.Responses.Has(requestId) {
                    response := state.Responses.Delete(requestId)
                    if !response["ok"].Value
                        throw Error(response["error"])
                    return response["data"]
                }
                if !this.IsStateProcessRunning(state)
                    throw Error(state.Role " 在响应命令前退出。")
                Sleep(5)
            }
            throw Error(state.Role " 命令响应超时：" command)
        } finally {
            state.PendingRequests.Delete(requestId)
            if state.Responses.Has(requestId)
                state.Responses.Delete(requestId)
        }
    }

    WriteMessage(state, messageType, payload) {
        if !state.Connected
            throw Error(state.Role " 尚未建立 IPC 连接。")
        return state.Protocol.SendMessage(state.Channel, messageType, payload)
    }

    SuspendAll() {
        inputResult := this.SendInputCommand("suspend")
        this.DesiredSuspended := true
        return Map("input", inputResult)
    }

    ResumeAll() {
        inputResult := this.SendInputCommand("resume")
        this.DesiredSuspended := false
        return Map("input", inputResult)
    }

    HandlePowerTransition(transition) {
        transition := StrLower(String(transition))
        if transition != "suspend" && transition != "resume"
            throw ValueError("电源转换只能是 suspend 或 resume。")
        this.PowerSuspended := transition == "suspend"
        this.ResetHeartbeatBaselines()
        return true
    }

    ResetHeartbeatBaselines() {
        now := this.TickCount64()
        this.LastHeartbeatSent := now
        for role, state in this.States
            state.LastHeartbeat := now
        return now
    }

    RecoverAfterResume() {
        if !this.Started
            return Map("started", JsonBoolean(false))
        this.PowerSuspended := false
        this.ResetHeartbeatBaselines()
        desired := Map("desired_suspended",
            JsonBoolean(this.DesiredSuspended))
        try {
            observationState := this.States["input-worker"]
            try observationResult := this.SendCommand(observationState,
                "power_recover", desired)
            catch as observationRecoveryError {
                this.HandleWorkerFailure(observationState,
                    "休眠恢复失败：" observationRecoveryError.Message)
                throw observationRecoveryError
            }
            inputResult := observationResult
            if inputResult.Has("devices")
                    && Type(inputResult["devices"]) == "Array"
                this.DeviceCache := this.CloneJson(inputResult["devices"])
            this.LastDeviceRefresh := this.TickCount64()
            return Map("input", inputResult, "observation", observationResult,
                "started", JsonBoolean(true))
        } finally this.ResetHeartbeatBaselines()
    }

    GetDevices(force := false) {
        now := this.TickCount64()
        if !force && this.LastDeviceRefresh > 0
                && now - this.LastDeviceRefresh < 1000
            return this.CloneJson(this.DeviceCache)
        response := this.SendInputCommand("devices")
        this.DeviceCache := response.Has("devices")
            && Type(response["devices"]) == "Array"
            ? this.CloneJson(response["devices"]) : []
        this.LastDeviceRefresh := now
        return this.CloneJson(this.DeviceCache)
    }

    GetHealth() {
        if !this.Started
            return Map("healthy", JsonBoolean(false),
                "detail", "工作进程尚未启动。")
        return this.SendInputCommand("health")
    }

    GetActiveBackendCapabilities() {
        if this.States.Has(this.ActiveRuntimeRole) {
            state := this.States[this.ActiveRuntimeRole]
            if state.ReadyData.Has("backend")
                    && Type(state.ReadyData["backend"]) == "Map" {
                result := this.CloneJson(state.ReadyData["backend"])
                result["process_isolated"] := JsonBoolean(true)
                result["authenticated_ipc"] := JsonBoolean(true)
                result["active_worker"] := this.ActiveRuntimeRole
                return result
            }
        }
        result := RawInputBackend.Describe()
        result["process_isolated"] := JsonBoolean(true)
        result["authenticated_ipc"] := JsonBoolean(true)
        result["active_worker"] := this.ActiveRuntimeRole
        return result
    }

    HandleWorkerFailure(state, message) {
        if this.Stopping
            return false
        if IsObject(state) {
            if state.HasOwnProp("FailureReported") && state.FailureReported
                return false
            state.FailureReported := true
        }
        role := IsObject(state) ? state.Role : "worker-group"
        detail := role ": " String(message)
        try this.App.CrashRecovery.Record("worker_failure", detail,
            Map("role", role,
                "process_id", IsObject(state) ? state.ProcessId : 0))
        try this.App.TraceEvent("ipc", "worker_failure", {
            Source: role, Outcome: "restart", Detail: detail})
        try this.App.Window.SetStatus("键鼠工作进程异常，正在自动恢复："
            detail, true)
        if this.RestartScheduled
            return true
        this.RestartScheduled := true
        SetTimer(this.RestartTimer, -250)
        return true
    }

    RestartAfterFailure(*) {
        this.RestartScheduled := false
        now := this.TickCount64()
        while this.RestartTicks.Length && now - this.RestartTicks[1] > 60000
            this.RestartTicks.RemoveAt(1)
        this.RestartTicks.Push(now)
        if !this.StopWorkers(true) {
            this.RestartScheduled := true
            SetTimer(this.RestartTimer, -1000)
            return false
        }
        if this.RestartTicks.Length > 3 {
            this.App.SafeMode := true
            try this.App.Health.RecordStartupFailure(
                "键鼠工作进程在一分钟内连续恢复失败。")
            try this.App.Window.SetStatus(
                "安全模式：键鼠工作进程连续失败，已停用所有映射。", true)
            return false
        }
        try {
            this.Start()
            try this.App.Window.SetStatus(this.App.GetSummaryText())
            return true
        } catch as restartError {
            this.HandleWorkerFailure("", restartError.Message)
            return false
        }
    }

    Shutdown(*) {
        return this.StopWorkers(true)
    }

    StopWorkers(forceOwnedProcesses := false) {
        if this.Stopping
            return false
        this.Stopping := true
        cleanupFailures := []
        retainedStates := Map()
        try {
            try SetTimer(this.PollTimer, 0)
            try SetTimer(this.RestartTimer, 0)
            this.RestartScheduled := false
            for role, state in this.States {
                try {
                    if state.Connected && this.IsStateProcessRunning(state)
                        this.SendCommand(state, "shutdown", Map(), 750)
                } catch {
                    ; A failed graceful request falls through to owned-process
                    ; termination below.
                }
            }
            deadline := this.TickCount64() + 1000
            while this.TickCount64() < deadline {
                anyRunning := false
                for role, state in this.States {
                    try running := this.IsStateProcessRunning(state)
                    catch
                        running := true
                    if running {
                        anyRunning := true
                        break
                    }
                }
                if !anyRunning
                    break
                Sleep(20)
            }
            for role, state in this.States {
                stateFailed := false
                processStopped := false
                try {
                    running := this.IsStateProcessRunning(state)
                    if running && forceOwnedProcesses
                        this.ForceStopState(state)
                    processStopped := !running || (forceOwnedProcesses
                        && this.WaitForStateExit(state, 1000))
                    if !processStopped {
                        cleanupFailures.Push(role
                            " process remained active after shutdown")
                        stateFailed := true
                    }
                } catch as forceStopError {
                    cleanupFailures.Push(role " process termination: "
                        forceStopError.Message)
                    stateFailed := true
                }
                try {
                    state.Channel.Close()
                    state.Connected := false
                } catch as channelCloseError {
                    cleanupFailures.Push(role " pipe: "
                        channelCloseError.Message)
                    stateFailed := true
                }
                if state.HasOwnProp("BootstrapPath")
                        && state.BootstrapPath != "" {
                    try {
                        WorkerBootstrap.Delete(state.BootstrapPath)
                        state.BootstrapPath := ""
                    } catch as bootstrapDeleteError {
                        cleanupFailures.Push(role " bootstrap: "
                            bootstrapDeleteError.Message)
                        stateFailed := true
                    }
                }
                if processStopped {
                    try {
                        this.CloseStateProcessHandle(state)
                        state.ProcessId := 0
                    }
                    catch as processHandleError {
                        cleanupFailures.Push(role " process handle: "
                            processHandleError.Message)
                        stateFailed := true
                    }
                }
                if stateFailed
                    retainedStates[role] := state
            }
            this.States := retainedStates
            this.Started := false
            this.DeviceCache := []
            this.LastDeviceRefresh := 0
            if cleanupFailures.Length
                try this.App.CrashRecovery.Record("worker_cleanup_failed",
                    "工作进程资源清理未完整完成。",
                    Map("failures", cleanupFailures))
            return cleanupFailures.Length == 0 && !this.States.Count
        } finally this.Stopping := false
    }

    SelectAndActivateRuntime() {
        this.ActiveRuntimeRole := "input-worker"
        this.SendCommand(this.States["input-worker"], "activate")
        return this.ActiveRuntimeRole
    }

    ValidateWorkerPath(path, label) {
        path := CrossProcessWriteLock.NormalizePath(path)
        attributes := FileExist(path)
        if !attributes || InStr(attributes, "D")
            throw Error(label "入口不存在：" path)
        return path
    }

    OpenWorkerProcessHandle(processId, &canTerminate) {
        processId := Integer(processId)
        canTerminate := false
        if processId <= 0
            throw Error("工作进程没有可跟踪的进程标识。")
        handle := DllCall("kernel32\OpenProcess", "UInt", 0x00101001,
            "Int", false, "UInt", processId, "Ptr")
        if handle
            canTerminate := true
        else
            handle := DllCall("kernel32\OpenProcess", "UInt", 0x00101000,
                "Int", false, "UInt", processId, "Ptr")
        if !handle
            throw OSError(A_LastError, "无法取得工作进程监督句柄。")
        return handle
    }

    IsStateProcessRunning(state) {
        if !IsObject(state) || !state.HasOwnProp("ProcessId")
                || !state.ProcessId
            return false
        if !state.HasOwnProp("ProcessHandle") || !state.ProcessHandle
            return !!ProcessExist(state.ProcessId)
        exitCode := 0
        if !DllCall("kernel32\GetExitCodeProcess", "Ptr", state.ProcessHandle,
                "UInt*", &exitCode, "Int")
            throw OSError(A_LastError, "无法读取工作进程退出状态。")
        return exitCode == 259
    }

    ForceStopState(state) {
        if !this.IsStateProcessRunning(state)
            return false
        if state.HasOwnProp("ProcessCanTerminate")
                && state.ProcessCanTerminate {
            if !DllCall("kernel32\TerminateProcess", "Ptr",
                    state.ProcessHandle, "UInt", 1, "Int")
                throw OSError(A_LastError, "无法终止失去响应的工作进程。")
        } else
            ProcessClose(state.ProcessId)
        return true
    }

    WaitForStateExit(state, timeoutMs) {
        if !IsObject(state) || !state.HasOwnProp("ProcessId")
                || !state.ProcessId
            return true
        timeoutMs := Integer(timeoutMs)
        if timeoutMs < 0
            throw ValueError("工作进程退出等待时间不能为负数。")
        if state.HasOwnProp("ProcessHandle") && state.ProcessHandle {
            waitResult := DllCall("kernel32\WaitForSingleObject", "Ptr",
                state.ProcessHandle, "UInt", timeoutMs, "UInt")
            if waitResult == 0
                return true
            if waitResult == 0x102
                return false
            throw OSError(A_LastError, "无法等待工作进程退出。")
        }
        ProcessWaitClose(state.ProcessId, timeoutMs / 1000)
        return !ProcessExist(state.ProcessId)
    }

    CloseStateProcessHandle(state) {
        if !IsObject(state) || !state.HasOwnProp("ProcessHandle")
                || !state.ProcessHandle
            return false
        if !DllCall("kernel32\CloseHandle", "Ptr", state.ProcessHandle,
                "Int")
            throw OSError(A_LastError, "无法关闭工作进程监督句柄。")
        state.ProcessHandle := 0
        state.ProcessCanTerminate := false
        return true
    }

    Quote(value) => Chr(34) StrReplace(String(value), Chr(34), Chr(34) Chr(34))
        . Chr(34)

    CloneJson(value) {
        return JsonCodec.Parse(JsonCodec.Stringify(value, false, true))
    }

    TickCount64() => DllCall("kernel32\GetTickCount64", "UInt64")
}

class RemoteManagedRuleRuntime {
    __New(controller) {
        this.Controller := controller
        this.Backend := RemoteInputBackend(controller)
        this.OutputLedger := {Keys: Map()}
    }

    ApplyMappings(*) {
        data := this.Controller.SendInputCommand("apply")
        return {
            MappingCount: data.Has("MappingCount") ? data["MappingCount"] : 0,
            RegistrationCount: data.Has("RegistrationCount")
                ? data["RegistrationCount"] : 0,
            ConflictCount: data.Has("ConflictCount")
                ? data["ConflictCount"] : 0,
            Backend: data.Has("Backend") ? data["Backend"] : Map()
        }
    }

    ResetActiveState(reason := "remote_reset") {
        data := this.Controller.SendInputCommand("reset",
            Map("reason", String(reason)))
        return data.Has("released") ? data["released"] : 0
    }

    Shutdown() {
        this.Controller.Shutdown()
    }
}

class RemoteInputBackend extends IInputBackend {
    __New(controller) {
        this.Controller := controller
        this.Suspended := false
    }

    GetBackendId() {
        capabilities := this.Controller.GetActiveBackendCapabilities()
        return capabilities.Has("backend")
            ? capabilities["backend"] : "worker-input"
    }

    GetCapabilities() {
        return this.Controller.GetActiveBackendCapabilities()
    }

    Replace(*) {
        throw Error("远程输入后端只能通过规则运行时整体替换。")
    }

    Suspend() {
        if this.Suspended
            return false
        this.Controller.SuspendAll()
        this.Suspended := true
        return true
    }

    Resume() {
        if !this.Suspended
            return false
        this.Controller.ResumeAll()
        this.Suspended := false
        return true
    }

    ReleaseAll() {
        response := this.Controller.SendInputCommand("reset",
            Map("reason", "remote_release_all"))
        return response.Has("released") ? response["released"] : 0
    }

    GetDevices() => this.Controller.GetDevices()

    HealthCheck() {
        try return this.Controller.GetHealth()
        catch as healthError
            return Map("backend", this.GetBackendId(),
                "healthy", JsonBoolean(false), "detail", healthError.Message)
    }

    Shutdown() {
        return this.Controller.Shutdown()
    }
}

class RemoteRawInputService {
    __New(controller) {
        this.Controller := controller
        this.Started := false
    }

    Start() {
        this.Controller.EnsureStarted()
        this.Started := true
        return true
    }

    Shutdown() {
        this.Started := false
        return true
    }

    GetDevices() => this.Controller.GetDevices()
}
