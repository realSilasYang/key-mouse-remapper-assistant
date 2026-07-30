#Requires AutoHotkey v2.0.26 64-bit
#SingleInstance Off
#Warn All, StdOut

#Include ..\TestSupport.ahk
#Include ..\..\src\Core\JsonCodec.ahk
#Include ..\..\src\Core\Sha256.ahk
#Include ..\..\src\Core\RuleSpec.ahk
#Include ..\..\src\Core\CrossProcessWriteLock.ahk
#Include ..\..\src\Core\ScopedVariableStore.ahk
#Include ..\..\src\Platform\WindowsContextService.ahk

try {
    contextStore := ScopedVariableStore()
    contextStore.Set("layer", "navigation")
    fakePlatform := DeterministicContextPlatform()
    contextService := WindowsContextService(fakePlatform)
    devices := [Map("id", "keyboard-one", "stable_id", "keyboard-one",
        "exact_path_id", "path-one", "hardware_id", "keyboard:046D:C52B",
        "container_id", "container-one", "serial", "serial-one",
        "instance_id", "instance-one", "type", "keyboard",
        "vendor_id", "046D", "product_id", "C52B",
        "match_keys", ["stable:keyboard-one", "hardware:046D:C52B"])]
    contextSnapshot := contextService.Build(contextStore, devices)
    AssertTrue(contextSnapshot.Has("application")
            && contextSnapshot["application"]["aumid"]
                == "test.application"
            && contextSnapshot["window"]["focused_control"] == "Edit1"
            && contextSnapshot["window"]["focused_hwnd"] == 9876
            && contextSnapshot["window"]["focused_class"] == "Edit"
            && contextSnapshot["window"]["focus_source"]
                == "get_gui_thread_info"
            && contextSnapshot["input_source"]["layout"] == "00000411"
            && contextSnapshot["input_source"]["language_id"] == "0411"
            && contextSnapshot["input_source"]["available"].Value
            && contextSnapshot["input_source"]["thread_id"] == 4321
            && fakePlatform.LayoutThreadId == 4321
            && fakePlatform.AumidProcessId == 2468
            && contextSnapshot["session"]["remote"].Value
            && contextSnapshot["session"]["lock_known"].Value
            && !contextSnapshot["session"]["locked"].Value
            && contextSnapshot["device"]["ids"].Has("keyboard-one")
            && contextSnapshot["device"]["stable_ids"].Has("keyboard-one")
            && contextSnapshot["device"]["exact_path_ids"].Has("path-one")
            && contextSnapshot["device"]["hardware_ids"].Has(
                "keyboard:046D:C52B")
            && contextSnapshot["device"]["container_ids"].Has(
                "container-one")
            && contextSnapshot["device"]["types"].Has("keyboard")
            && contextSnapshot["device"]["vendor_ids"].Has("046D")
            && contextSnapshot["device"]["product_ids"].Has("C52B")
            && contextSnapshot["device"]["match_keys"].Has(
                "stable:keyboard-one")
            && contextSnapshot["device"]["present"].Value
            && contextSnapshot["device"]["current"] is JsonNull
            && contextSnapshot["device"]["scope"] == "present_devices"
            && contextSnapshot["variables"]["layer"] == "navigation"
            && contextSnapshot["variables"].Has("builtin.session_locked")
            && contextSnapshot["variables"].Has(
                "builtin.session_lock_known")
            && contextSnapshot["variables"].Has(
                "builtin.remote_session_known"),
        "Windows 上下文没有使用前台线程、焦点、会话、设备或内建变量")
    sourceContext := contextService.Build(contextStore, devices,
        devices[1])
    AssertTrue(sourceContext["device"]["scope"] == "event_source"
            && sourceContext["device"]["current"]["stable_id"]
                == "keyboard-one",
        "事件来源设备没有进入独立上下文")

    rdpPlatform := SessionScenarioPlatform(
        Map("known", true, "value", 42, "error", 0),
        Map("known", true, "value", 0, "error", 0),
        Map("known", true, "value", 2, "error", 0),
        Map("known", true, "locked", false,
            "source", "wts_session_info_ex", "error", 0),
        Map("state", "unavailable", "error", 5))
    rdpState := rdpPlatform.GetSessionState()
    AssertTrue(rdpState["session_id"] == 42
            && rdpState["state"] == "active"
            && rdpState["remote"].Value
            && rdpState["protocol"] == "rdp"
            && !rdpState["locked"].Value
            && rdpPlatform.QueriedSessionIds.Length == 3
            && rdpPlatform.QueriedSessionIds[1] == 42
            && rdpPlatform.QueriedSessionIds[2] == 42
            && rdpPlatform.QueriedSessionIds[3] == 42,
        "当前进程会话 ID 没有用于 RDP、连接状态和锁屏查询")

    unknownLockPlatform := SessionScenarioPlatform(
        Map("known", true, "value", 7, "error", 0),
        Map("known", true, "value", 0, "error", 0),
        Map("known", true, "value", 0, "error", 0),
        Map("known", false, "locked", false,
            "source", "wts_session_info_ex", "error", 5),
        Map("state", "unavailable", "error", 5))
    unknownLockState := unknownLockPlatform.GetSessionState()
    AssertTrue(unknownLockState["state"] == "unknown"
            && unknownLockState["locked"] is JsonNull
            && !unknownLockState["lock_known"].Value
            && unknownLockState["desktop_state"] == "unavailable",
        "输入桌面访问失败被错误归类为锁屏或活动状态")

    lockedPlatform := SessionScenarioPlatform(
        Map("known", true, "value", 9, "error", 0),
        Map("known", true, "value", 0, "error", 0),
        Map("known", true, "value", 0, "error", 0),
        Map("known", true, "locked", true,
            "source", "wts_session_info_ex", "error", 0),
        Map("state", "accessible", "error", 0))
    lockedState := lockedPlatform.GetSessionState()
    AssertTrue(lockedState["state"] == "locked"
            && lockedState["locked"].Value
            && lockedState["lock_known"].Value,
        "WTS 明确锁屏状态没有进入上下文")

    disconnectedPlatform := SessionScenarioPlatform(
        Map("known", true, "value", 11, "error", 0),
        Map("known", true, "value", 4, "error", 0),
        Map("known", true, "value", 2, "error", 0),
        Map("known", true, "locked", true,
            "source", "wts_session_info_ex", "error", 0),
        Map("state", "unavailable", "error", 5))
    disconnectedState := disconnectedPlatform.GetSessionState()
    AssertTrue(disconnectedState["state"] == "disconnected"
            && disconnectedState["connection_state"] == "disconnected",
        "断开的 RDP 会话被锁屏状态覆盖")

    missingSessionPlatform := SessionScenarioPlatform(
        Map("known", false, "value", 0, "error", 87),
        Map("known", false, "value", -1, "error", 87),
        Map("known", false, "value", -1, "error", 87),
        Map("known", false, "locked", false,
            "source", "unavailable", "error", 87),
        Map("state", "accessible", "error", 0), true)
    missingSessionState := missingSessionPlatform.GetSessionState()
    AssertTrue(missingSessionState["session_id"] is JsonNull
            && !missingSessionState["session_id_known"].Value
            && missingSessionState["remote"].Value
            && missingSessionState["remote_source"]
                == "sm_remote_session_fallback"
            && missingSessionState["state"] == "unknown",
        "当前会话查询失败没有保留未知状态或受控远程回退")

    nativePlatform := WindowsContextPlatform()
    nativeForeground := nativePlatform.GetForegroundContext()
    if nativeForeground["hwnd"] {
        nativeProcessId := 0
        nativeThreadId := DllCall("user32\GetWindowThreadProcessId", "Ptr",
            nativeForeground["hwnd"], "UInt*", &nativeProcessId, "UInt")
        AssertTrue(nativeForeground["thread_id"] == nativeThreadId
                && nativeForeground["process_id"] == nativeProcessId
                && nativePlatform.GetKeyboardLayout(nativeThreadId)
                    == DllCall("user32\GetKeyboardLayout", "UInt",
                        nativeThreadId, "UPtr"),
            "真实前台 HWND、线程、进程或键盘布局不一致")
    }
    nativeSession := nativePlatform.GetSessionState()
    directSessionId := 0
    directSessionKnown := DllCall("kernel32\ProcessIdToSessionId", "UInt",
        DllCall("kernel32\GetCurrentProcessId", "UInt"),
        "UInt*", &directSessionId, "Int")
    AssertTrue(!directSessionKnown
            || (nativeSession["session_id_known"].Value
                && nativeSession["session_id"] == directSessionId),
        "真实上下文没有报告当前测试进程所在会话")
    WriteTestSuccess("windows-context-service")
} catch as contextTestError {
    FileAppend(contextTestError.Message "`n" contextTestError.Stack, "**")
    ExitApp(1)
}
ExitApp(0)

class DeterministicContextPlatform {
    __New() {
        this.LayoutThreadId := 0
        this.AumidProcessId := 0
    }

    GetForegroundContext() {
        return Map(
            "hwnd", 1234,
            "thread_id", 4321,
            "process_id", 2468,
            "process", "TestApp.exe",
            "process_path", "C:\Program Files\TestApp\TestApp.exe",
            "title", "Test window",
            "class", "TestWindowClass",
            "focused_control", "Edit1",
            "focused_text", "focused text",
            "focused_hwnd", 9876,
            "focused_class", "Edit",
            "focus_source", "get_gui_thread_info")
    }

    GetKeyboardLayout(threadId) {
        this.LayoutThreadId := threadId
        return 0x0411
    }

    GetApplicationUserModelId(processId) {
        this.AumidProcessId := processId
        return "test.application"
    }

    GetSessionState() {
        return Map(
            "state", "active",
            "locked", JsonBoolean(false),
            "lock_known", JsonBoolean(true),
            "lock_source", "wts_session_info_ex",
            "lock_error", 0,
            "remote", JsonBoolean(true),
            "remote_known", JsonBoolean(true),
            "remote_source", "wts_client_protocol",
            "protocol", "rdp",
            "protocol_type", 2,
            "connection_state", "active",
            "connection_state_code", 0,
            "desktop_state", "visible",
            "desktop_error", 0,
            "session_id", 42,
            "session_id_known", JsonBoolean(true),
            "session_error", 0)
    }
}

class SessionScenarioPlatform extends WindowsContextPlatform {
    __New(session, connection, protocol, lock, desktop,
            remoteMetric := false) {
        this.SessionResult := session
        this.ConnectionResult := connection
        this.ProtocolResult := protocol
        this.LockResult := lock
        this.DesktopResult := desktop
        this.RemoteMetric := remoteMetric
        this.QueriedSessionIds := []
    }

    GetCurrentProcessSession() {
        return RuleSpec.Clone(this.SessionResult)
    }

    QueryConnectionState(sessionId) {
        this.QueriedSessionIds.Push(sessionId)
        return RuleSpec.Clone(this.ConnectionResult)
    }

    QueryClientProtocol(sessionId) {
        this.QueriedSessionIds.Push(sessionId)
        return RuleSpec.Clone(this.ProtocolResult)
    }

    QueryLockState(sessionId) {
        this.QueriedSessionIds.Push(sessionId)
        return RuleSpec.Clone(this.LockResult)
    }

    ProbeInputDesktop() {
        return RuleSpec.Clone(this.DesktopResult)
    }

    GetRemoteSessionMetric() {
        return this.RemoteMetric
    }
}
