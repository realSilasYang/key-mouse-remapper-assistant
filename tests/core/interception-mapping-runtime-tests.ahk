#Requires AutoHotkey v2.0 64-bit
#SingleInstance Off
#Warn All, StdOut

#Include ..\..\src\Core\JsonCodec.ahk
#Include ..\..\src\Core\RuleSpec.ahk
#Include ..\..\src\Core\RuleCompiler.ahk
#Include ..\..\src\Core\RuleConditionEvaluator.ahk
#Include ..\..\src\Core\InputEvent.ahk
#Include ..\..\src\Core\DirectRuntimeSupport.ahk
#Include ..\..\src\Core\DirectHotkeyRuntime.ahk
#Include ..\..\src\Core\InterceptionMappingRuntime.ahk

try {
    app := InterceptionRuntimeTestApp()
    service := InterceptionRuntimeServiceProbe()
    runtime := InterceptionRuntimeProbe(app, service)
    mapping := InterceptionRuntimeMapping("device-apps-win", false)
    report := runtime.ApplyMappings([mapping])
    InterceptionRuntimeAssert(report.Applied == 1
            && service.StartCount == 1
            && service.DeviceNumbers.Length == 1
            && service.DeviceNumbers[1] == 2,
        "A device rule did not start one centralized Interception context.")

    runtime.ProcessStroke(InterceptionKeyboardStroke(2, 0x5D, 0x02))
    runtime.ProcessStroke(InterceptionKeyboardStroke(2, 0x5D, 0x03))
    InterceptionRuntimeAssert(runtime.Dispatches.Length == 2
            && runtime.Dispatches[1] == "{Blind}{LWin down}"
            && runtime.Dispatches[2] == "{Blind}{LWin up}"
            && service.SendCount == 0,
        "A device-specific source did not produce paired target down/up events.")

    runtime.ProcessStroke(InterceptionKeyboardStroke(2, 0x1E, 0x00))
    runtime.ProcessStroke(InterceptionKeyboardStroke(2, 0x1E, 0x01))
    InterceptionRuntimeAssert(service.SendCount == 2,
        "Unmatched Interception strokes were not returned unchanged.")

    genericWinMapping := InterceptionRuntimeGenericWinMapping()
    runtime.ApplyMappings([genericWinMapping])
    runtime.ProcessStroke(InterceptionKeyboardStroke(2, 0x5B, 0x02))
    runtime.ProcessStroke(InterceptionKeyboardStroke(2, 0x5B, 0x03))
    InterceptionRuntimeAssert(runtime.Dispatches.Length == 4
            && runtime.Dispatches[3] == "{Blind}{LWin down}"
            && runtime.Dispatches[4] == "{Blind}{LWin up}"
            && service.SendCount == 2,
        "A side-neutral Win source did not match the physical Win key.")

    unavailableApp := InterceptionRuntimeUnavailableApp()
    unavailableRuntime := InterceptionRuntimeProbe(unavailableApp,
        InterceptionRuntimeUnavailableService())
    unavailableReport := unavailableRuntime.ApplyMappings([mapping])
    Sleep(30)
    InterceptionRuntimeAssert(unavailableReport.Applied == 1
            && unavailableReport.Issues.Length == 1
            && unavailableRuntime.Rules.Count == 1,
        "A failed Interception context start escaped rule application or lost the blocked rule state.")
    unavailableRuntime.Shutdown()

    blockMapping := InterceptionBlockMapping()
    runtime.ApplyMappings([blockMapping])
    dispatchesBeforeBlock := runtime.Dispatches.Length
    sendsBeforeBlock := service.SendCount
    runtime.ProcessStroke(InterceptionKeyboardStroke(2, 0x52, 0x02))
    runtime.ProcessStroke(InterceptionKeyboardStroke(2, 0x52, 0x03))
    InterceptionRuntimeAssert(runtime.Dispatches.Length == dispatchesBeforeBlock
            && service.SendCount == sendsBeforeBlock,
        "A device-specific block rule did not suppress both source strokes.")

    passthrough := InterceptionRuntimeMapping("device-apps-win-pass", true)
    runtime.ApplyMappings([passthrough])
    sendsBefore := service.SendCount
    runtime.ProcessStroke(InterceptionKeyboardStroke(2, 0x5D, 0x02))
    runtime.ProcessStroke(InterceptionKeyboardStroke(2, 0x5D, 0x03))
    InterceptionRuntimeAssert(service.SendCount == sendsBefore + 2,
        "A passthrough device rule suppressed its original strokes.")

    runtime.ApplyMappings([mapping])
    runtime.ProcessStroke(InterceptionKeyboardStroke(2, 0x5D, 0x02))
    dispatchesBeforeSuspend := runtime.Dispatches.Length
    runtime.Suspend()
    InterceptionRuntimeAssert(runtime.Dispatches.Length
            == dispatchesBeforeSuspend + 1
            && runtime.Dispatches[runtime.Dispatches.Length]
                == "{Blind}{LWin up}"
            && service.StopCount >= 1,
        "Suspending the Interception runtime did not release held output.")
    runtime.Shutdown()

    FileAppend("PASS interception-mapping-runtime`n", "*")
    ExitApp(0)
} catch as testError {
    FileAppend("FAIL interception-mapping-runtime-tests: " testError.Message
        "`n" testError.Stack "`n", "*")
    ExitApp(1)
}

InterceptionRuntimeMapping(id, passthrough) {
    spec := Map("id", id,
        "display", Map("source", "AppsKey (keyboard 2)",
            "target", "LWin", "scope", "全局"),
        "from", Map("key", Map("name", "AppsKey", "vk", "5D",
                "sc", "15D"),
            "device", Map("backend", "interception", "number", 2,
                "type", "keyboard"),
            "optional_modifiers", ["any"], "repeat", "ignore"),
        "to", [Map("type", "key_down", "value", "LWin")],
        "to_after_key_up", [Map("type", "key_up", "value", "LWin")])
    if passthrough
        spec["passthrough"] := JsonBoolean(true)
    return {Mode: "managed", Spec: RuleSpec.Normalize(spec)}
}

InterceptionBlockMapping() {
    spec := Map("id", "device-block-insert",
        "display", Map("source", "Insert (keyboard 2)",
            "target", "屏蔽", "scope", "全局"),
        "from", Map("key", Map("name", "Insert", "vk", "2D",
                "sc", "152"),
            "device", Map("backend", "interception", "number", 2,
                "type", "keyboard"),
            "optional_modifiers", ["any"], "repeat", "ignore"),
        "block", JsonBoolean(true))
    return {Mode: "managed", Spec: RuleSpec.Normalize(spec)}
}

InterceptionRuntimeGenericWinMapping() {
    spec := Map("id", "device-generic-win",
        "display", Map("source", "Win (keyboard 2)",
            "target", "LWin", "scope", "全局"),
        "from", Map("key", Map("name", "Win"),
            "device", Map("backend", "interception", "number", 2,
                "type", "keyboard"),
            "optional_modifiers", ["any"], "repeat", "ignore"),
        "to", [Map("type", "key_down", "value", "LWin")],
        "to_after_key_up", [Map("type", "key_up", "value", "LWin")])
    return {Mode: "managed", Spec: RuleSpec.Normalize(spec)}
}

InterceptionKeyboardStroke(deviceNumber, code, state) {
    return Map("device", deviceNumber, "type", "keyboard", "code", code,
        "state", state, "received", 1)
}

InterceptionRuntimeAssert(condition, message) {
    if !condition
        throw Error(message)
}

class InterceptionRuntimeServiceProbe {
    __New() {
        this.StartCount := 0
        this.StopCount := 0
        this.SendCount := 0
        this.DeviceNumbers := []
    }
    StartRuntime(deviceNumbers) {
        this.StartCount++
        this.DeviceNumbers := deviceNumbers.Clone()
        return true
    }
    StopRuntime() {
        this.StopCount++
        return true
    }
    PollRuntime(*) => ""
    SendRuntimeStroke(*) {
        this.SendCount++
        return true
    }
}

class InterceptionRuntimeUnavailableService extends InterceptionRuntimeServiceProbe {
    StartRuntime(*) {
        throw Error("无法创建 Interception runtime 上下文。")
    }
}

class InterceptionRuntimeUnavailableApp extends InterceptionRuntimeTestApp {
    __New() {
        super.__New()
        this.UnavailableCallbackCount := 0
    }
    OnInterceptionRuntimeUnavailable(*) => this.UnavailableCallbackCount++
    HasMethod(name) => name == "OnInterceptionRuntimeUnavailable"
}

class InterceptionRuntimeProbe extends InterceptionMappingRuntime {
    __New(app, service) {
        super.__New(app, service)
        this.Dispatches := []
    }
    DispatchKeySequence(sequence) {
        this.Dispatches.Push(String(sequence))
        return true
    }
}

class InterceptionRuntimeTestApp {
    __New() {
        this.ContextService := DirectContextService()
        this.Events := []
    }
    TraceEvent(category, eventName, fields := "") {
        this.Events.Push({Category: category, Event: eventName, Fields: fields})
        return true
    }
}

Tr(text, values*) => values.Length ? Format(text, values*) : text
