#Requires AutoHotkey v2.0.26 64-bit
#SingleInstance Off
#Warn All, StdOut

#Include ..\TestSupport.ahk
#Include ..\..\src\Core\JsonCodec.ahk
#Include ..\..\src\Core\Sha256.ahk
#Include ..\..\src\Core\HmacSha256.ahk
#Include ..\..\src\Core\AuthenticatedIpcProtocol.ahk
#Include ..\..\src\Core\CrossProcessWriteLock.ahk
#Include ..\..\src\Core\CrashRecoveryService.ahk
#Include ..\..\src\Core\OutputRecoveryJournal.ahk
#Include ..\..\src\Core\RuleSpec.ahk
#Include ..\..\src\Core\DeviceIdentityService.ahk
#Include ..\..\src\Core\InputEvent.ahk
#Include ..\..\src\Core\RuleTimingResolver.ahk
#Include ..\..\src\Core\ScopedVariableStore.ahk
#Include ..\..\src\Core\RuleConditionEvaluator.ahk
#Include ..\..\src\Core\InputBackend.ahk
#Include ..\..\src\Platform\Win32.ahk
#Include ..\..\src\Input\RawInputService.ahk
#Include ..\..\src\Core\RawInputBackend.ahk
#Include ..\..\src\Platform\NamedPipeChannel.ahk
#Include ..\..\src\UI\ApplicationIcon.ahk
#Include ..\..\src\Process\WorkerBootstrap.ahk
#Include ..\..\src\Process\InputWorkerController.ahk

testRoot := A_Temp "\key-mouse-remapper-assistant-worker-integration-" A_TickCount
    . "-" Format("{:08X}", Random(0, 0xFFFFFFFF))
testFailure := ""
controller := ""
mouseProbe := InjectedMouseButtonProbe()
DirCreate(testRoot)
try {
    mouseProbe.Start()
    app := WorkerControllerTestApp(testRoot)
    inputWorkerPath := GetApplicationRootFilePath(
        "workers\input-engine-worker.ahk")

    failedCleanupController := FailingCleanupController(app,
        inputWorkerPath)
    failedCleanupState := FailingCleanupController.BuildState("input-worker")
    failedCleanupController.States["input-worker"] := failedCleanupState
    failedCleanupController.Started := true
    AssertTrue(!failedCleanupController.StopWorkers(true)
            && failedCleanupController.States.Has("input-worker")
            && failedCleanupState.ProcessHandle == 456
            && !failedCleanupController.Started,
        "工作进程终止失败后丢失了待重试状态或监督句柄")
    retainedStateStartRejected := false
    try failedCleanupController.Start()
    catch as retainedStateStartError
        retainedStateStartRejected := InStr(retainedStateStartError.Message,
            "尚未完成资源清理") > 0
    AssertTrue(retainedStateStartRejected,
        "旧工作进程未清理时仍允许启动第二组进程")

    controller := InputWorkerController(app, inputWorkerPath)
    app.Controller := controller
    autoStartHealth := controller.SendInputCommand("health")
    AssertTrue(controller.Started && autoStartHealth.Has("healthy")
            && !autoStartHealth["observation_transport"]
                ["full_raw_input"].Value,
        "首次工作进程命令没有自动启动进程组")
    AssertTrue(controller.SetRawObservation(true)
            && controller.DesiredRawObservation
            && controller.SendInputCommand("health")
                ["observation_transport"]["full_raw_input"].Value,
        "GUI 无法按需开启工作进程完整 Raw Input 转发")
    AssertTrue(controller.SetRawObservation(false)
            && !controller.DesiredRawObservation
            && !controller.SendInputCommand("health")
                ["observation_transport"]["full_raw_input"].Value,
        "退出原始观察后工作进程仍转发完整 Raw Input")
    inputStateForLateResponse := controller.States["input-worker"]
    controller.HandleStateMessage(inputStateForLateResponse,
        Map("type", "response", "payload", Map(
            "request_id", "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
            "ok", JsonBoolean(true),
            "data", Map(), "error", "")))
    AssertEqual(0, inputStateForLateResponse.Responses.Count,
        "迟到或未知工作进程响应被永久保留")
    invalidCommandDataRejected := false
    try controller.SendInputCommand("health", Map("unexpected", 1))
    catch as invalidCommandDataError
        invalidCommandDataRejected := InStr(invalidCommandDataError.Message,
            "不接受") > 0
    AssertTrue(invalidCommandDataRejected
            && controller.States["input-worker"].Ready,
        "输入工作进程静默忽略了未知命令 data 或拒绝后退出")
    invalidObservationDataRejected := false
    try controller.SendInputCommand("raw_observation",
        Map("enabled", 1))
    catch
        invalidObservationDataRejected := true
    AssertTrue(invalidObservationDataRejected
            && controller.States["input-worker"].Ready,
        "输入工作进程接受了非布尔原始观察开关")
    fractionalTimeoutRejected := false
    try controller.SendCommand(inputStateForLateResponse, "health", Map(),
        100.5)
    catch
        fractionalTimeoutRejected := true
    AssertTrue(fractionalTimeoutRejected,
        "控制器接受并截断了小数命令超时")

    controller.RestartScheduled := true
    SetTimer(controller.RestartTimer, -250)
    AssertTrue(controller.Shutdown(), "待重启状态下无法关闭工作进程组")
    Sleep(350)
    AssertTrue(!controller.Started && !controller.RestartScheduled
            && controller.States.Count == 0,
        "关闭后残留的自动重启定时器仍然执行")
    AssertTrue(controller.Start(), "取消待重启定时器后无法再次启动工作进程组")
    currentProcessId := DllCall("kernel32\GetCurrentProcessId", "UInt")
    inputState := controller.States["input-worker"]
    AssertTrue(controller.States.Count == 1 && inputState.Ready
            && inputState.ProcessHandle
            && inputState.ProcessId != currentProcessId,
        "唯一 Raw Input 工作进程没有运行在独立 PID")
    AssertTrue(inputState.HelloReceived,
        "Raw Input 工作进程没有完成双端认证握手")
    AssertEqual("input-worker", controller.ActiveRuntimeRole,
        "Raw Input 运行时没有激活输入工作进程")
    remoteCapabilities := RemoteInputBackend(controller).GetCapabilities()
    AssertTrue(remoteCapabilities["backend"] == "raw-input"
            && remoteCapabilities["process_isolated"].Value
            && remoteCapabilities["authenticated_ipc"].Value
            && remoteCapabilities["device_identification"].Value
            && !remoteCapabilities["requires_driver"].Value,
        "GUI 远程后端没有报告 Raw Input 真实能力")

    applyResult := controller.SendInputCommand("apply")
    AssertTrue(applyResult.Has("MappingCount")
            && applyResult["MappingCount"] == 0,
        "输入工作进程无法应用测试配置")
    devicesResult := controller.SendInputCommand("devices")
    AssertTrue(devicesResult.Has("devices")
            && Type(devicesResult["devices"]) == "Array",
        "输入工作进程无法返回设备快照")
    controller.SuspendAll()
    AssertTrue(controller.SendInputCommand("health")["backend"]
            ["suspended"].Value,
        "跨进程暂停没有作用于托管输入后端")
    controller.ResumeAll()
    AssertTrue(!controller.SendInputCommand("health")["backend"]
            ["suspended"].Value,
        "跨进程恢复没有作用于托管输入后端")

    controller.LastHeartbeatSent := 0
    controller.Poll()
    Sleep(80)
    controller.Poll()
    AssertTrue(controller.States["input-worker"].LastHeartbeat > 0,
        "工作进程心跳没有被认证接收")

    inputProcessBeforePower := controller.States["input-worker"].ProcessId
    controller.HandlePowerTransition("suspend")
    AssertTrue(controller.PowerSuspended,
        "控制器没有进入休眠宽限状态")
    controller.HandlePowerTransition("resume")
    powerResult := controller.RecoverAfterResume()
    AssertTrue(powerResult["started"].Value
            && Type(powerResult["input"]["devices"]) == "Array"
            && controller.States["input-worker"].ProcessId
                == inputProcessBeforePower,
        "唤醒恢复重启了 GUI/worker 或没有重新枚举设备")
    controller.SuspendAll()
    controller.HandlePowerTransition("suspend")
    controller.HandlePowerTransition("resume")
    controller.RecoverAfterResume()
    AssertTrue(controller.SendInputCommand("health")["backend"]
            ["suspended"].Value,
        "唤醒恢复没有保留用户主动暂停状态")
    controller.ResumeAll()

    AssertTrue(controller.SetRawObservation(true),
        "工作进程恢复测试无法预先开启原始观察")
    failedInputProcessId := controller.States["input-worker"].ProcessId
    controller.States["input-worker"].Channel.Close()
    controller.LastHeartbeatSent := 0
    controller.Poll()
    recoveryTimeout := Max(15000,
        InputWorkerController.StartupTimeoutMs * controller.States.Count + 3000)
    recoveryDeadline := DllCall("kernel32\GetTickCount64", "UInt64")
        + recoveryTimeout
    inputRecovery := ""
    while DllCall("kernel32\GetTickCount64", "UInt64") < recoveryDeadline {
        controller.Poll()
        inputRecovery := FindWorkerFailure(app.CrashRecovery.Snapshot(),
            "input-worker")
        if controller.Started && controller.States.Has("input-worker")
                && controller.States["input-worker"].Ready
                && controller.States["input-worker"].ProcessId
                    != failedInputProcessId && IsObject(inputRecovery)
            break
        Sleep(50)
    }
    AssertTrue(controller.Started
            && controller.States["input-worker"].ProcessId
                != failedInputProcessId
            && IsObject(inputRecovery)
            && controller.DesiredRawObservation
            && controller.SendInputCommand("health")
                ["observation_transport"]["full_raw_input"].Value,
        "输入工作进程故障恢复没有保留原始观察状态或错误归因")
    AssertTrue(controller.SetRawObservation(false),
        "工作进程恢复后无法退出原始观察")

    inputProcessId := controller.States["input-worker"].ProcessId
    inputStateAtShutdown := controller.States["input-worker"]
    AssertTrue(controller.Shutdown(), "工作进程组无法关闭")
    Sleep(100)
    AssertTrue(!ProcessExist(inputProcessId),
        "工作进程组关闭后仍有子进程残留")
    AssertTrue(inputStateAtShutdown.ProcessHandle == 0,
        "工作进程组关闭后残留监督句柄")
    AssertEqual(0, mouseProbe.Events.Length,
        "worker 生命周期向真实桌面注入了无所有权的鼠标按钮事件")

    WriteTestSuccess("worker-process-integration")
} catch as workerIntegrationError {
    testFailure := workerIntegrationError.Message "`n"
        . workerIntegrationError.Stack
} finally {
    if IsObject(controller)
        try controller.Shutdown()
    mouseProbe.Stop()
    if DirExist(testRoot)
        DirDelete(testRoot, true)
}
if testFailure != "" {
    FileAppend(testFailure "`n", "**")
    ExitApp(1)
}
ExitApp(0)

FindWorkerFailure(entries, role, messageFragment := "") {
    Loop entries.Length {
        entry := entries[entries.Length - A_Index + 1]
        if entry["category"] != "worker_failure"
                || !entry["data"].Has("role")
                || entry["data"]["role"] != role
            continue
        if messageFragment == "" || InStr(entry["message"], messageFragment)
            return entry
    }
    return ""
}

DescribeWorkerController(controller, app) {
    detail := "Started=" controller.Started
        . ", Starting=" controller.Starting
        . ", Stopping=" controller.Stopping
        . ", RestartScheduled=" controller.RestartScheduled
        . ", RestartCount=" controller.RestartTicks.Length
        . ", SafeMode=" app.SafeMode
    for role, state in controller.States {
        detail .= "`n" role ": pid=" state.ProcessId
            . ", exists=" (!!ProcessExist(state.ProcessId))
            . ", ready=" state.Ready
            . ", connected=" state.Connected
            . ", hello=" state.HelloReceived
    }
    entries := app.CrashRecovery.Snapshot()
    first := Max(1, entries.Length - 5)
    Loop entries.Length - first + 1 {
        entry := entries[first + A_Index - 1]
        detail .= "`ncrash[" (first + A_Index - 1) "]="
            . entry["category"] ":" entry["message"]
    }
    return detail
}

class WorkerControllerTestApp {
    __New(testRoot) {
        this.Repository := {ScriptPath: GetApplicationRootFilePath(
            "tests\fixtures\worker-mapping-fixture.ahk")}
        this.VariableStore := ScopedVariableStore(testRoot "\variables.json")
        this.OutputRecoveryJournal := OutputRecoveryJournal(
            testRoot "\output-recovery.json")
        this.CrashRecovery := CrashRecoveryService(
            testRoot "\crash-diagnostics.json")
        this.Window := WorkerControllerTestWindow()
        this.TraceCount := 0
        this.RawEventCount := 0
        this.Controller := ""
        this.SafeMode := false
    }

    TraceEvent(*) {
        this.TraceCount++
        return true
    }

    OnRawInputEvent(*) {
        this.RawEventCount++
        return true
    }

    GetSummaryText() => "worker integration ready"
}

class WorkerControllerTestWindow {
    SetStatus(*) => true
}

class InjectedMouseButtonProbe {
    __New() {
        this.Events := []
        this.Hook := 0
        this.Callback := 0
    }

    Start() {
        this.Callback := CallbackCreate(ObjBindMethod(this, "HookProc"), , 3)
        moduleHandle := DllCall("kernel32\GetModuleHandleW", "Ptr", 0,
            "Ptr")
        this.Hook := DllCall("user32\SetWindowsHookExW", "Int", 14,
            "Ptr", this.Callback, "Ptr", moduleHandle, "UInt", 0, "Ptr")
        if !this.Hook {
            CallbackFree(this.Callback)
            this.Callback := 0
            throw OSError(A_LastError, "无法安装测试鼠标隔离钩子。")
        }
        return true
    }

    HookProc(code, message, dataPointer) {
        if code >= 0 && this.IsButtonMessage(message) {
            flags := NumGet(dataPointer, 12, "UInt")
            if flags & 0x01
                this.Events.Push(Integer(message))
        }
        return DllCall("user32\CallNextHookEx", "Ptr", this.Hook,
            "Int", code, "UPtr", message, "Ptr", dataPointer, "Ptr")
    }

    IsButtonMessage(message) {
        return message == 0x0201 || message == 0x0202
            || message == 0x0204 || message == 0x0205
            || message == 0x0207 || message == 0x0208
            || message == 0x020B || message == 0x020C
    }

    Stop() {
        if this.Hook
            try DllCall("user32\UnhookWindowsHookEx", "Ptr", this.Hook)
        this.Hook := 0
        if this.Callback
            try CallbackFree(this.Callback)
        this.Callback := 0
        return true
    }
}

class FailingCleanupController extends InputWorkerController {
    __New(app, inputWorkerPath) {
        super.__New(app, inputWorkerPath)
        this.FakeTick := 0
    }

    static BuildState(role) {
        return {
            Role: role,
            Connected: false,
            Channel: FakeCleanupChannel(),
            ProcessId: 123,
            ProcessHandle: 456,
            ProcessCanTerminate: true,
            BootstrapPath: ""
        }
    }

    TickCount64() {
        this.FakeTick += 1000
        return this.FakeTick
    }

    IsStateProcessRunning(*) => true

    ForceStopState(*) {
        throw Error("injected process termination failure")
    }
}

class FakeCleanupChannel {
    __New() {
        this.Closed := false
    }

    Close() {
        changed := !this.Closed
        this.Closed := true
        return changed
    }
}
