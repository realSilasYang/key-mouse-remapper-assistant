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
#Include ..\..\src\Core\InterceptionService.ahk
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

    runtime.StopContext()
    InterceptionRuntimeAssert(runtime.EnsureRunning("session_unlock")
            && service.StartCount == 2 && runtime.ContextActive,
        "Session recovery did not recreate a stopped Interception context.")

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

    chordService := InterceptionRuntimeChordServiceProbe()
    chordRuntime := InterceptionRuntimeProbe(app, chordService)
    chordRuntime.ModifierState := 0x44 ; LWin and LShift physically held
    chordMapping := InterceptionRuntimeWinChordMapping()
    chordRuntime.ApplyMappings([
        InterceptionRuntimeBlockWinMapping(), chordMapping])
    chordRuntime.ProcessStroke(InterceptionKeyboardStroke(2, 0x5B, 0x02))
    chordRuntime.ProcessStroke(InterceptionKeyboardStroke(2, 0x2A, 0x00))
    chordRuntime.ProcessStroke(InterceptionKeyboardStroke(2, 0x6E, 0x00))
    InterceptionRuntimeAssert(chordRuntime.Dispatches.Length == 1
            && chordRuntime.Dispatches[1] == "{Blind}{LShift up}"
            && chordService.KeyEvents.Length == 2
            && chordService.KeyEvents[1].KeyName == "LWin"
            && chordService.KeyEvents[1].Phase == "up"
            && chordService.KeyEvents[1].DeviceNumber == 2
            && chordService.KeyEvents[2].KeyName == "LWin"
            && chordService.KeyEvents[2].Phase == "down"
            && chordService.KeyEvents[2].DeviceNumber == 2
            && chordService.SendCount == 0,
        "A Win+Shift+F23 device rule did not replace held modifiers with a held Win output on its device.")
    chordRuntime.ProcessStroke(InterceptionKeyboardStroke(2, 0x26, 0x00))
    chordRuntime.ProcessStroke(InterceptionKeyboardStroke(2, 0x26, 0x01))
    InterceptionRuntimeAssert(chordService.SendCount == 2
            && chordService.SentStrokes[1]["code"] == 0x26
            && chordService.SentStrokes[1]["state"] == 0x00
            && chordService.SentStrokes[2]["code"] == 0x26
            && chordService.SentStrokes[2]["state"] == 0x01,
        "A subsequent L key was not passed through while the mapped Win was held.")
    chordRuntime.ProcessStroke(InterceptionKeyboardStroke(2, 0x6E, 0x01))
    InterceptionRuntimeAssert(chordRuntime.Dispatches.Length == 1
            && chordService.KeyEvents.Length == 3
            && chordService.KeyEvents[3].KeyName == "LWin"
            && chordService.KeyEvents[3].Phase == "up"
            && chordService.KeyEvents[3].DeviceNumber == 2
            && chordService.SendCount == 2,
        "A Win+Shift+F23 device rule did not release its Win output on source up.")
    chordRuntime.ProcessStroke(InterceptionKeyboardStroke(2, 0x5B, 0x03))
    chordRuntime.ProcessStroke(InterceptionKeyboardStroke(2, 0x2A, 0x01))
    InterceptionRuntimeAssert(chordService.SendCount == 2,
        "The source Win/Shift releases escaped after the mapped key cycle.")
    chordRuntime.Shutdown()

    keyService := InterceptionRuntimeKeySerializationProbe()
    InterceptionRuntimeAssert(keyService.SendRuntimeKey(2, "LWin", "down")
            && keyService.SendRuntimeKey(2, "LWin", "up")
            && keyService.SentStrokes.Length == 2
            && NumGet(keyService.SentStrokes[1]["buffer"], 0, "UShort") == 0x5B
            && NumGet(keyService.SentStrokes[1]["buffer"], 2, "UShort") == 0x02
            && NumGet(keyService.SentStrokes[2]["buffer"], 0, "UShort") == 0x5B
            && NumGet(keyService.SentStrokes[2]["buffer"], 2, "UShort") == 0x03,
        "A synthetic Win key was not encoded as matching Interception down/up strokes.")

    fallbackService := InterceptionRuntimeServiceProbe()
    fallbackRuntime := InterceptionRuntimeProbe(app, fallbackService)
    fallbackRuntime.ApplyMappings([chordMapping])
    fallbackRuntime.ProcessStroke(InterceptionKeyboardStroke(2, 0x5B, 0x02))
    fallbackRuntime.ProcessStroke(InterceptionKeyboardStroke(2, 0x2A, 0x00))
    InterceptionRuntimeAssert(fallbackService.SendCount == 0,
        "A possible modifier prefix was forwarded before its chord resolved.")
    fallbackRuntime.ProcessStroke(InterceptionKeyboardStroke(2, 0x1E, 0x00))
    InterceptionRuntimeAssert(fallbackService.SendCount == 3
            && fallbackService.SentStrokes[1]["code"] == 0x5B
            && fallbackService.SentStrokes[2]["code"] == 0x2A
            && fallbackService.SentStrokes[3]["code"] == 0x1E,
        "An unmatched chord did not replay its prefix before the trigger key.")
    fallbackRuntime.ProcessStroke(InterceptionKeyboardStroke(2, 0x1E, 0x01))
    fallbackRuntime.ProcessStroke(InterceptionKeyboardStroke(2, 0x2A, 0x01))
    fallbackRuntime.ProcessStroke(InterceptionKeyboardStroke(2, 0x5B, 0x03))
    fallbackRuntime.Shutdown()

    cancelService := InterceptionRuntimeServiceProbe()
    cancelRuntime := InterceptionRuntimeProbe(app, cancelService)
    cancelRuntime.ApplyMappings([chordMapping])
    cancelRuntime.ProcessStroke(InterceptionKeyboardStroke(2, 0x5B, 0x02))
    cancelRuntime.ProcessStroke(InterceptionKeyboardStroke(2, 0x5B, 0x03))
    InterceptionRuntimeAssert(cancelService.SendCount == 2
            && cancelService.SentStrokes[1]["state"] == 0x02
            && cancelService.SentStrokes[2]["state"] == 0x03,
        "Releasing an incomplete modifier prefix did not replay its down/up strokes.")
    cancelRuntime.Shutdown()

    reconfigureService := InterceptionRuntimeServiceProbe()
    reconfigureRuntime := InterceptionRuntimeProbe(app, reconfigureService)
    reconfigureRuntime.ApplyMappings([chordMapping])
    reconfigureRuntime.ProcessStroke(InterceptionKeyboardStroke(2,
        0x5B, 0x02))
    reconfigureRuntime.ApplyMappings([chordMapping])
    InterceptionRuntimeAssert(reconfigureService.SendCount == 1
            && reconfigureService.SentStrokes[1]["code"] == 0x5B,
        "Reconfiguring the runtime discarded a staged modifier stroke.")
    reconfigureRuntime.Shutdown()

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

InterceptionRuntimeWinChordMapping() {
    spec := Map("id", "device-win-chord-to-win",
        "display", Map("source", "Win + Shift + F23 (keyboard 2)",
            "target", "Win", "scope", "全局"),
        "from", Map("key", Map("name", "F23", "vk", "86",
                "sc", "06E"),
            "modifiers", ["Win", "Shift"],
            "device", Map("backend", "interception", "number", 2,
                "type", "keyboard"),
            "repeat", "ignore"),
        "to", [Map("type", "key_down", "value", "LWin")],
        "to_after_key_up", [Map("type", "key_up", "value", "LWin")])
    return {Mode: "managed", Spec: RuleSpec.Normalize(spec)}
}

InterceptionRuntimeBlockWinMapping() {
    spec := Map("id", "device-block-win",
        "display", Map("source", "Win (keyboard 2)",
            "target", "屏蔽", "scope", "全局"),
        "from", Map("key", Map("name", "Win"),
            "device", Map("backend", "interception", "number", 2,
                "type", "keyboard")),
        "block", JsonBoolean(true))
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
        this.SentStrokes := []
        this.KeyEvents := []
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
    SendRuntimeStroke(stroke) {
        this.SendCount++
        this.SentStrokes.Push(stroke.Clone())
        return true
    }
}

class InterceptionRuntimeChordServiceProbe extends InterceptionRuntimeServiceProbe {
    SendRuntimeKey(deviceNumber, keyName, phase) {
        this.KeyEvents.Push({DeviceNumber: deviceNumber, KeyName: keyName,
            Phase: phase})
        return true
    }
}

class InterceptionRuntimeKeySerializationProbe extends InterceptionService {
    __New() {
        super.__New()
        this.ConsumerMode := "runtime"
        this.SentStrokes := []
    }
    SendRuntimeStroke(stroke) {
        this.SentStrokes.Push(stroke)
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
        this.ModifierState := 0
    }
    GetPhysicalModifierState() => this.ModifierState
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
