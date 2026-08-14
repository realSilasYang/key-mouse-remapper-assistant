#Requires AutoHotkey v2.0 64-bit
#SingleInstance Off
#Warn All, StdOut

#Include ..\..\src\Core\JsonCodec.ahk
#Include ..\..\src\Core\RuleSpec.ahk
#Include ..\..\src\Core\RuleCompiler.ahk
#Include ..\..\src\Core\DeviceIdentityService.ahk
#Include ..\..\src\Core\InputEvent.ahk
#Include ..\..\src\Platform\Win32.ahk
#Include ..\..\src\Input\RawInputService.ahk
#Include ..\..\src\Input\CaptureInputGuard.ahk
#Include ..\..\src\Input\KeyCaptureSession.ahk

try {
    dispatchOrder := []
    dispatchCapture := CapturePrioritySession(dispatchOrder)
    dispatchRuntime := CapturePriorityRuntime(dispatchOrder)
    dispatchEvent := Map("origin", "raw-input")
    KeyCaptureSession.Prototype.DispatchRawInputEvent.Call(dispatchCapture,
        dispatchEvent, dispatchRuntime)
    CaptureAssertTrue(dispatchOrder.Length == 2
            && dispatchOrder[1] == "capture"
            && dispatchOrder[2] == "capture-state"
            && dispatchRuntime.Observed == 0,
        "The remapping runtime observed Raw Input owned by recording.")
    dispatchOrder.Length := 0
    dispatchCapture.Blocked := false
    KeyCaptureSession.Prototype.DispatchRawInputEvent.Call(dispatchCapture,
        dispatchEvent, dispatchRuntime)
    CaptureAssertTrue(dispatchOrder.Length == 3
            && dispatchOrder[1] == "capture"
            && dispatchOrder[2] == "capture-state"
            && dispatchOrder[3] == "runtime"
            && dispatchRuntime.Observed == 1,
        "Idle Raw Input was not dispatched after the capture priority check.")

    drainLifecycle := []
    drainApp := CaptureTestApp(drainLifecycle)
    drainGuard := CaptureTestInputGuard(drainLifecycle)
    drainSession := KeyCaptureSession(drainApp, drainGuard)
    CaptureAssertTrue(drainSession.Start("source"),
        "The input-drain test did not start.")
    drainSession.ObserveRawInputEvent(CaptureEvent("A", 0x41, 0x01E,
        "down"))
    CaptureAssertTrue(drainSession.Cancel() && !drainSession.Active
            && drainSession.Draining && drainGuard.Active
            && drainApp.CancelledCount == 0,
        "Cancellation released interception before the held key was drained.")
    CaptureAssertTrue(!drainSession.FinalizeInputDrain()
            && drainSession.Draining && drainGuard.Active,
        "The input drain ignored a physically held key.")
    drainSession.ObserveRawInputEvent(CaptureEvent("A", 0x41, 0x01E,
        "up"))
    CaptureAssertTrue(drainSession.Draining && drainGuard.Active
            && drainApp.CancelledCount == 0,
        "The terminating key-up removed interception inside its Raw Input callback.")
    CaptureAssertTrue(drainSession.FinalizeInputDrain()
            && !drainSession.Draining && !drainGuard.Active
            && drainApp.CancelledCount == 1,
        "The input drain did not finish after all physical keys were released.")

    lifecycleLog := []
    app := CaptureTestApp(lifecycleLog)
    inputGuard := CaptureTestInputGuard(lifecycleLog)
    session := KeyCaptureSession(app, inputGuard)

    CaptureAssertTrue(session.Start("source"),
        "Source capture did not start.")
    CaptureAssertTrue(inputGuard.Active && inputGuard.StartCount == 1,
        "Capture did not acquire the exclusive input guard.")
    CaptureAssertTrue(lifecycleLog.Length >= 2
            && lifecycleLog[1] == "guard-start"
            && lifecycleLog[2] == "suspend",
        "Capture did not establish interception before suspending mappings.")
    session.ObserveRawInputEvent(CaptureEvent("LCtrl", 0xA2, 0x01D,
        "down"))
    session.ObserveRawInputEvent(CaptureEvent("A", 0x41, 0x01E,
        "down"))
    session.ObserveRawInputEvent(CaptureEvent("B", 0x42, 0x030,
        "down"))
    session.ObserveRawInputEvent(CaptureEvent("B", 0x42, 0x030,
        "down"))
    CaptureAssertEqual("LCtrl + A + B", app.LastPreview.RawDisplay,
        "A source chord containing multiple ordinary keys was not previewed.")
    CaptureAssertEqual(3, session.RecordedOrder.Length,
        "Keyboard auto-repeat duplicated a recorded chord key.")
    CaptureRelease(session, "A", 0x41, 0x01E)
    CaptureAssertTrue(session.Active && session.CaptureFrozen,
        "The source chord did not freeze on its first release.")
    session.ObserveRawInputEvent(CaptureEvent("C", 0x43, 0x02E,
        "down"))
    CaptureAssertEqual("LCtrl + A + B", app.LastPreview.RawDisplay,
        "A key pressed after the first release was merged into the chord.")
    CaptureRelease(session, "B", 0x42, 0x030)
    CaptureRelease(session, "LCtrl", 0xA2, 0x01D)
    CaptureAssertTrue(session.Active,
        "Capture completed while a post-freeze physical key was still held.")
    CaptureRelease(session, "C", 0x43, 0x02E)
    CaptureAssertTrue(!session.Active && app.CompletedCount == 1,
        "A multi-key source chord did not complete after every key was released.")
    CaptureAssertTrue(lifecycleLog[lifecycleLog.Length - 1] == "resume"
            && lifecycleLog[lifecycleLog.Length] == "guard-stop",
        "Capture released interception before remapping was restored.")
    sourceChord := app.CompletedCapture
    CaptureAssertTrue(sourceChord.IsSimultaneous
            && sourceChord.Keys.Length == 3
            && sourceChord.RawDisplay == "LCtrl + A + B",
        "The completed source chord lost one of its simultaneous keys.")
    sourceChordSpec := RuleSpec.CreateFromCaptures("multi-source",
        sourceChord, CaptureTarget("F12"))
    CaptureAssertTrue(sourceChordSpec["from"].Has("simultaneous")
            && sourceChordSpec["from"]["simultaneous"].Length == 3,
        "A recorded multi-key source did not enter RuleSpec.simultaneous.")
    CaptureAssertEqual("<^sc030", RuleCompiler.Compile(sourceChordSpec).Hotkey,
        "The last ordinary chord key was not compiled as its trigger.")
    genericChordSpec := RuleSpec.CreateFromCaptures("generic-multi-source",
        sourceChord, CaptureTarget("F12"), false)
    CaptureAssertEqual("^sc030", RuleCompiler.Compile(genericChordSpec).Hotkey,
        "A multi-key source did not honor generic modifier capture.")
    manyKeyInfos := []
    for recordedKeyLabel in StrSplit(
            "A,B,C,D,E,F,G,H,I,J,K,L,M,N,O,P,Q,R,S,T,U,V,W,X,Y,Z", ",")
        manyKeyInfos.Push(session.CreateKeyInfo("keyboard", recordedKeyLabel,
            0, 0, recordedKeyLabel))
    Loop 24
        manyKeyInfos.Push(session.CreateKeyInfo("keyboard", "F" A_Index,
            0, 0, "F" A_Index))
    manyKeyCapture := session.BuildCaptureFromInfos(manyKeyInfos)
    manyKeySpec := RuleSpec.CreateFromCaptures("many-key-source",
        manyKeyCapture, CaptureTarget("F12"))
    CaptureAssertTrue(manyKeyCapture.Keys.Length == 50
            && manyKeySpec["from"]["simultaneous"].Length == 50,
        "A large simultaneous key set was truncated during capture or normalization.")

    CaptureAssertTrue(session.Start("source"),
        "The source-order test did not start.")
    session.ObserveRawInputEvent(CaptureEvent("A", 0x41, 0x01E,
        "down"))
    session.ObserveRawInputEvent(CaptureEvent("LCtrl", 0xA2, 0x01D,
        "down"))
    CaptureRelease(session, "LCtrl", 0xA2, 0x01D)
    CaptureRelease(session, "A", 0x41, 0x01E)
    CaptureAssertTrue(app.CompletedCount == 2
            && !app.CompletedCapture.IsSimultaneous
            && app.CompletedCapture.RawDisplay == "LCtrl + A",
        "A modifier pressed after the main key was not normalized correctly.")

    CaptureAssertTrue(session.Start("target"),
        "Target capture did not start.")
    session.ObserveRawInputEvent(CaptureEvent("LShift", 0xA0, 0x02A,
        "down"))
    session.ObserveRawInputEvent(CaptureEvent("A", 0x41, 0x01E,
        "down"))
    session.ObserveRawInputEvent(CaptureEvent("B", 0x42, 0x030,
        "down"))
    session.ObserveRawInputEvent(CapturePointerEvent("XButton1", "down"))
    session.ObserveRawInputEvent(CapturePointerEvent("XButton1", "up"))
    CaptureRelease(session, "B", 0x42, 0x030)
    CaptureRelease(session, "A", 0x41, 0x01E)
    CaptureRelease(session, "LShift", 0xA0, 0x02A)
    CaptureAssertTrue(app.CompletedCount == 3
            && app.CompletedCapture.IsSimultaneous
            && app.CompletedCapture.Keys.Length == 4,
        "A mixed keyboard and mouse target chord was not captured completely.")

    CaptureAssertTrue(session.Start("source"),
        "The cross-device source test did not start.")
    session.ObserveRawInputEvent(CaptureEvent("LCtrl", 0xA2, 0x01D,
        "down", "keyboard-b"))
    session.ObserveRawInputEvent(CaptureEvent("A", 0x41, 0x01E,
        "down", "keyboard-a"))
    session.ObserveRawInputEvent(CapturePointerEvent("XButton1", "down"))
    session.ObserveRawInputEvent(CapturePointerEvent("XButton1", "up"))
    CaptureRelease(session, "A", 0x41, 0x01E, "keyboard-a")
    CaptureRelease(session, "LCtrl", 0xA2, 0x01D, "keyboard-b")
    CaptureAssertTrue(app.CompletedCount == 4
            && app.CompletedCapture.RawDisplay == "LCtrl + A + XButton1"
            && !CaptureContainsDeviceInfo(app.CompletedCapture),
        "A global source dropped keys that came from another input device.")

    CaptureAssertTrue(session.Start("target"),
        "The cross-device duplicate-key test did not start.")
    session.ObserveRawInputEvent(CaptureEvent("A", 0x41, 0x01E,
        "down", "keyboard-a"))
    session.ObserveRawInputEvent(CaptureEvent("A", 0x41, 0x01E,
        "down", "keyboard-b"))
    CaptureRelease(session, "A", 0x41, 0x01E, "keyboard-a")
    CaptureAssertTrue(session.Active,
        "A duplicate logical key completed before both devices released it.")
    CaptureRelease(session, "A", 0x41, 0x01E, "keyboard-b")
    CaptureAssertTrue(app.CompletedCount == 5
            && app.CompletedCapture.Keys.Length == 1
            && !app.CompletedCapture.IsSimultaneous,
        "The same logical key from two devices produced an impossible duplicate rule.")

    app.Settings.EscapeCancelsRecording := false
    CaptureAssertTrue(session.Start("target"),
        "The Escape chord test did not start.")
    session.ObserveRawInputEvent(CaptureEvent("A", 0x41, 0x01E, "down"))
    session.ObserveRawInputEvent(CaptureEvent("Escape", 0x1B, 0x001,
        "down"))
    CaptureRelease(session, "Escape", 0x1B, 0x001)
    CaptureRelease(session, "A", 0x41, 0x01E)
    CaptureAssertTrue(app.CompletedCount == 6
            && app.CompletedCapture.RawDisplay == "A + Escape",
        "Escape inside a chord cancelled capture instead of being recorded.")

    app.Settings.EscapeCancelsRecording := true
    app.SuppressEscapeCount := 0
    CaptureAssertTrue(session.Start("target"),
        "The in-progress Escape cancellation test did not start.")
    session.ObserveRawInputEvent(CaptureEvent("A", 0x41, 0x01E, "down"))
    session.ObserveRawInputEvent(CaptureEvent("Escape", 0x1B, 0x001,
        "down"))
    CaptureRelease(session, "Escape", 0x1B, 0x001)
    CaptureRelease(session, "A", 0x41, 0x01E)
    CaptureAssertTrue(!session.Active && app.CompletedCount == 6
            && app.CancelledCount == 1
            && app.SuppressEscapeCount == 1,
        "Escape did not cancel a recording after another key was pressed.")

    CaptureAssertTrue(session.Start("target"),
        "The standalone Escape cancellation test did not start.")
    session.ObserveRawInputEvent(CaptureEvent("Escape", 0x1B, 0x001,
        "down"))
    CaptureRelease(session, "Escape", 0x1B, 0x001)
    CaptureAssertTrue(!session.Active && app.CancelledCount == 2,
        "Standalone Escape did not cancel capture.")

    ; Regression: cancellation is finalized only after Escape Up. The GUI
    ; Escape event must still be consumed even though the key is no longer
    ; physically held when OnCaptureCancelled runs.
    CaptureAssertTrue(app.SuppressEscapeCount == 2,
        "Escape cancellation did not arm the post-capture GUI suppression.")

    CaptureAssertTrue(session.Start("source"),
        "The wheel chord test did not start.")
    session.ObserveRawInputEvent(CaptureEvent("A", 0x41, 0x01E, "down"))
    session.ObserveRawInputEvent(CapturePointerEvent("WheelUp", "wheel"))
    session.ObserveRawInputEvent(CaptureEvent("B", 0x42, 0x030, "down"))
    CaptureRelease(session, "A", 0x41, 0x01E)
    CaptureRelease(session, "B", 0x42, 0x030)
    CaptureAssertTrue(app.CompletedCount == 7
            && app.CompletedCapture.RawDisplay == "A + WheelUp",
        "A wheel chord did not freeze at its instantaneous wheel event. Got "
            app.CompletedCount " / " app.CompletedCapture.RawDisplay)

    CaptureAssertTrue(session.Start("source"),
        "App-command source capture did not start.")
    session.ObserveRawInputEvent(CaptureEvent("LCtrl", 0xA2, 0x01D,
        "down"))
    CaptureAssertTrue(session.CompleteAppCommand(5) && session.Active
            && app.CompletedCount == 7,
        "An app command completed before its Raw Input correlation window.")
    CaptureRelease(session, "LCtrl", 0xA2, 0x01D)
    session.FinalizePendingAppCommand()
    CaptureFinalizeDrain(session)
    CaptureAssertTrue(app.CompletedCount == 8
            && app.CompletedRole == "source"
            && app.CompletedCapture.AppCommand == 5
            && app.CompletedCapture.RawDisplay == "LCtrl + Browser_Search",
        "A pending app command lost the modifier held at command time.")

    CaptureAssertTrue(session.Start("source"),
        "The app-command-first correlation test did not start.")
    session.CompleteAppCommand(5)
    session.ObserveRawInputEvent(CaptureEvent("Browser_Search", 0xAA, 0,
        "down", "keyboard-b"))
    CaptureRelease(session, "Browser_Search", 0xAA, 0, "keyboard-b")
    CaptureAssertTrue(app.CompletedCount == 9
            && app.CompletedCapture.AppCommand == 5
            && !CaptureContainsDeviceInfo(app.CompletedCapture),
        "A completed app-command capture leaked Raw Input device identity.")

    diagnosticDetail := InputEvent.FormatDiagnosticDetail(CaptureEvent("A",
        0x41, 0x01E, "down", "keyboard-a"), [Map(
            "id", "keyboard-a", "stable_id", "device-0123456789abcdef0123456789abcdef",
            "display_name", "诊断键盘", "vendor_id", "046D",
            "product_id", "C31C")])
    CaptureAssertTrue(InStr(diagnosticDetail, "来源设备：诊断键盘")
            && InStr(diagnosticDetail, "VID 046D")
            && InStr(diagnosticDetail, "PID C31C")
            && InStr(diagnosticDetail,
                "设备 ID device-0123456789abcdef0123456789abcdef"),
        "Raw Input event detail omitted physical-device diagnostics.")

    CaptureAssertTrue(session.Start("source"),
        "The modifier-only chord test did not start.")
    session.ObserveRawInputEvent(CaptureEvent("LCtrl", 0xA2, 0x01D,
        "down"))
    session.ObserveRawInputEvent(CaptureEvent("RCtrl", 0xA3, 0x11D,
        "down"))
    CaptureRelease(session, "RCtrl", 0xA3, 0x11D)
    CaptureRelease(session, "LCtrl", 0xA2, 0x01D)
    CaptureAssertTrue(app.CompletedCount == 10
            && app.CompletedCapture.IsSimultaneous
            && app.CompletedCapture.Keys.Length == 2,
        "A chord containing only modifier keys was not recorded completely.")
    genericModifierChord := RuleSpec.CreateFromCaptures(
        "generic-modifier-only", app.CompletedCapture, CaptureTarget("F12"),
        false)
    CaptureAssertTrue(genericModifierChord["from"].Has("key")
            && genericModifierChord["from"]["key"]["name"] == "Ctrl",
        "Equivalent sided modifiers were not collapsed for generic matching.")

    CaptureAssertTrue(session.Start("target"),
        "The device-rebound capture test did not start.")
    session.ObserveRawInputEvent(CaptureEvent("A", 0x41, 0x01E, "down"))
    session.ObserveRawInputEvent(CaptureDeviceEvent("keyboard-a", "rebound"))
    CaptureFinalizeDrain(session)
    CaptureAssertTrue(!session.Active && app.CompletedCount == 10
            && app.CancelledCount == 3,
        "A rebound device committed an incomplete key capture.")

    CaptureAssertTrue(session.Start("target"),
        "The pointer-button cancellation test did not start.")
    app.CancelForPointer := true
    completedBeforePointerCancel := app.CompletedCount
    session.ObserveRawInputEvent(CapturePointerEvent("LButton", "down"))
    CaptureAssertTrue(session.Active && session.PointerButtonCancelPending
            && session.RecordedOrder.Length == 0,
        "A capture-button click was recorded as LButton before cancellation.")
    session.ObserveRawInputEvent(CapturePointerEvent("LButton", "up"))
    CaptureFinalizeDrain(session)
    CaptureAssertTrue(!session.Active
            && app.CompletedCount == completedBeforePointerCancel
            && app.CancelledCount == 4
            && app.PointerFinalizedCount == 1,
        "A capture-button click completed a mapping instead of cancelling it.")

    CaptureAssertTrue(session.Start("target"),
        "The pointer-cancellation timeout test did not start.")
    session.ObserveRawInputEvent(CapturePointerEvent("LButton", "down"))
    CaptureAssertTrue(session.Active && session.PointerButtonCancelPending,
        "A pointer-button cancellation was not deferred until button release.")
    session.FinalizePointerCancellationTimeout()
    session.ObserveRawInputEvent(CapturePointerEvent("LButton", "up"))
    CaptureFinalizeDrain(session)
    CaptureAssertTrue(!session.Active && app.CancelledCount == 5
            && app.PointerFinalizedCount == 2,
        "A lost pointer-button release left capture and remapping suspended.")
    app.CancelForPointer := false

    CaptureAssertTrue(session.Start("target"),
        "The resume-failure reporting test did not start.")
    app.ResumeThrows := true
    session.Cancel()
    CaptureFinalizeDrain(session)
    CaptureAssertTrue(!session.Active && app.ResumeFailureCount == 1,
        "A remapping resume failure was silently discarded after capture.")

    CaptureAssertTrue(session.Start("target"),
        "The completed resume-failure test did not start.")
    completedBeforeResumeFailure := app.CompletedCount
    session.ObserveRawInputEvent(CaptureEvent("A", 0x41, 0x01E,
        "down"))
    CaptureRelease(session, "A", 0x41, 0x01E)
    CaptureAssertTrue(!session.Active && app.ResumeFailureCount == 2
            && app.CompletedCount == completedBeforeResumeFailure,
        "A capture was committed after remapping failed to resume.")

    app.ResumeThrows := false
    completedBeforeLongChord := app.CompletedCount
    CaptureAssertTrue(session.Start("source"),
        "The unrestricted chord test did not start.")
    longChordNames := StrSplit(
        "1,Q,2,W,3,E,4,R,5,T,6,Y,7,U,8,I,9,O,0,P,A,S,D,F,G,H,J,K,L,Z,X,C", ",")
    for longChordPosition, longChordKeyName in longChordNames
        session.ObserveRawInputEvent(CaptureEvent(longChordKeyName,
            GetKeyVK(longChordKeyName), longChordPosition + 1, "down"))
    CaptureAssertTrue(session.RecordedOrder.Length == longChordNames.Length
            && app.LastPreview.Keys.Length == longChordNames.Length
            && InStr(app.LastPreview.RawDisplay, " + C"),
        "A long arbitrary key set was truncated in the live Raw Input preview.")
    Loop longChordNames.Length {
        longChordPosition := longChordNames.Length - A_Index + 1
        longChordKeyName := longChordNames[longChordPosition]
        CaptureRelease(session, longChordKeyName,
            GetKeyVK(longChordKeyName), longChordPosition + 1)
    }
    CaptureAssertTrue(!session.Active
            && app.CompletedCount == completedBeforeLongChord + 1
            && app.CompletedCapture.Keys.Length == longChordNames.Length,
        "A long arbitrary key set was truncated before capture completion.")

    app.SuspendReturns := false
    guardStartsBeforeRejectedSuspension := inputGuard.StartCount
    guardStopsBeforeRejectedSuspension := inputGuard.StopCount
    CaptureAssertTrue(!session.Start("source") && !session.Active,
        "Capture started without owning the remapping suspension.")
    CaptureAssertTrue(session.LastStartError != "",
        "A capture start failure did not retain its diagnostic message.")
    CaptureAssertTrue(inputGuard.StartCount
            == guardStartsBeforeRejectedSuspension + 1
            && inputGuard.StopCount == guardStopsBeforeRejectedSuspension + 1
            && !inputGuard.HasResources(),
        "A rejected remapping suspension did not roll back interception.")

    app.SuspendReturns := true
    suspendCountBeforeGuardStartFailure := app.SuspendCount
    resumeCountBeforeGuardStartFailure := app.ResumeCount
    inputGuard.FailStart := true
    CaptureAssertTrue(!session.Start("source") && !session.Active
            && app.SuspendCount == suspendCountBeforeGuardStartFailure
            && app.ResumeCount == resumeCountBeforeGuardStartFailure
            && !inputGuard.HasResources(),
        "A failed input-guard start touched remapping state or leaked resources.")
    CaptureAssertTrue(InStr(session.LastStartError,
            "expected input-guard start failure"),
        "The input-guard start diagnostic was not retained.")
    inputGuard.FailStart := false

    rejectedBeforeGuardStopFailure := app.RejectedCount
    resumeCountBeforeGuardStopFailure := app.ResumeCount
    CaptureAssertTrue(session.Start("target"),
        "The input-guard cleanup failure test did not start.")
    inputGuard.FailStop := true
    session.Cancel()
    CaptureAssertTrue(!session.FinalizeInputDrain() && !session.Active
            && session.InputGuardOwned
            && app.ResumeCount == resumeCountBeforeGuardStopFailure + 1
            && app.RejectedCount == rejectedBeforeGuardStopFailure + 1,
        "An input-guard cleanup failure was not isolated and reported.")
    inputGuard.FailStop := false
    session.Stop(false)
    CaptureAssertTrue(!session.InputGuardOwned
            && !inputGuard.HasResources(),
        "A deferred input-guard cleanup could not be retried.")

    resumeCountBeforeShutdownStop := app.ResumeCount
    CaptureAssertTrue(session.Start("target"),
        "The shutdown cleanup capture did not start.")
    CaptureAssertTrue(session.Stop(false, false)
            && app.ResumeCount == resumeCountBeforeShutdownStop
            && !inputGuard.Active && !inputGuard.HasResources(),
        "Shutdown cleanup unnecessarily resumed remapping hotkeys.")

    forwardedApp := CaptureTestApp()
    forwardedGuard := CaptureTestInputGuard()
    forwardedSession := KeyCaptureSession(forwardedApp, forwardedGuard)
    CaptureAssertTrue(forwardedSession.Start("target"),
        "The forwarded-hook capture test did not start.")
    forwardedSession.ObserveGuardInputEvent({Kind: "keyboard",
        Message: 0x0100, VK: 0x70, SC: 0x3B, Flags: 0})
    forwardedSession.ObserveGuardInputEvent({Kind: "keyboard",
        Message: 0x0101, VK: 0x70, SC: 0x3B, Flags: 0x80})
    CaptureFinalizeDrain(forwardedSession)
    CaptureAssertTrue(forwardedApp.CompletedCount == 1
            && forwardedApp.CompletedCapture.RawDisplay == "F1",
        "A swallowed low-level keyboard event was not recorded.")

    CaptureAssertTrue(forwardedSession.Start("target"),
        "The forwarded wheel capture test did not start.")
    forwardedSession.ObserveGuardInputEvent({Kind: "mouse",
        Message: 0x020A, MouseData: 120, Flags: 0, X: 10, Y: 20})
    CaptureFinalizeDrain(forwardedSession)
    CaptureAssertTrue(forwardedApp.CompletedCount == 2
            && forwardedApp.CompletedCapture.RawDisplay == "WheelUp",
        "A swallowed low-level wheel event was not recorded.")

    CaptureAssertTrue(forwardedSession.Start("target"),
        "The Consumer Control browser-search capture test did not start.")
    forwardedSession.ObserveRawInputEvent(ConsumerControlUsage.CreateEvent(
        0x0221, "down", Map("id", "consumer-a", "handle", "consumer-a",
            "usage_page", 0x0C, "usage", 1)))
    forwardedSession.ObserveRawInputEvent(ConsumerControlUsage.CreateEvent(
        0x0221, "up", Map("id", "consumer-a", "handle", "consumer-a",
            "usage_page", 0x0C, "usage", 1)))
    CaptureFinalizeDrain(forwardedSession)
    CaptureAssertTrue(forwardedApp.CompletedCount == 3
            && forwardedApp.CompletedCapture.RawDisplay == "Browser_Search"
            && forwardedApp.CompletedCapture.AppCommand == 5
            && forwardedApp.CompletedCapture.SC == 0
            && forwardedApp.CompletedCapture.SourceSpec == "Browser_Search",
        "HID Browser_Search did not reach the completed recording.")
    consumerSearchSpec := RuleSpec.CreateFromCaptures(
        "consumer-browser-search", forwardedApp.CompletedCapture,
        CaptureTarget("F12"))
    CaptureAssertEqual("vkAA", RuleCompiler.Compile(
        consumerSearchSpec).Hotkey,
        "A HID Browser_Search source was compiled to a scan code it never emits.")

    CaptureAssertTrue(forwardedSession.Start("target"),
        "The Consumer Control browser-home capture test did not start.")
    forwardedSession.ObserveRawInputEvent(ConsumerControlUsage.CreateEvent(
        0x0223, "down", Map("id", "consumer-a", "handle", "consumer-a",
            "usage_page", 0x0C, "usage", 1)))
    forwardedSession.ObserveRawInputEvent(ConsumerControlUsage.CreateEvent(
        0x0223, "up", Map("id", "consumer-a", "handle", "consumer-a",
            "usage_page", 0x0C, "usage", 1)))
    CaptureFinalizeDrain(forwardedSession)
    CaptureAssertTrue(forwardedApp.CompletedCount == 4
            && forwardedApp.CompletedCapture.RawDisplay == "Browser_Home"
            && forwardedApp.CompletedCapture.AppCommand == 7
            && forwardedApp.CompletedCapture.SC == 0
            && forwardedApp.CompletedCapture.SourceSpec == "Browser_Home",
        "HID Browser_Home did not reach the completed recording.")

    standardMouseCases := [
        {Name: "LButton", Down: 0x0201, Up: 0x0202, Data: 0},
        {Name: "RButton", Down: 0x0204, Up: 0x0205, Data: 0},
        {Name: "MButton", Down: 0x0207, Up: 0x0208, Data: 0},
        {Name: "XButton1", Down: 0x020B, Up: 0x020C, Data: 1},
        {Name: "XButton2", Down: 0x020B, Up: 0x020C, Data: 2},
        {Name: "WheelUp", Down: 0x020A, Up: 0, Data: 120},
        {Name: "WheelDown", Down: 0x020A, Up: 0, Data: -120},
        {Name: "WheelRight", Down: 0x020E, Up: 0, Data: 120},
        {Name: "WheelLeft", Down: 0x020E, Up: 0, Data: -120}]
    for standardMouseCase in standardMouseCases {
        CaptureAssertTrue(forwardedSession.Start("target"),
            "A standard mouse capture test did not start: "
                standardMouseCase.Name)
        forwardedSession.ObserveGuardInputEvent({Kind: "mouse",
            Message: standardMouseCase.Down,
            MouseData: standardMouseCase.Data, Flags: 0, X: 10, Y: 20})
        if standardMouseCase.Up
            forwardedSession.ObserveGuardInputEvent({Kind: "mouse",
                Message: standardMouseCase.Up,
                MouseData: standardMouseCase.Data,
                Flags: 0, X: 10, Y: 20})
        CaptureFinalizeDrain(forwardedSession)
        CaptureAssertTrue(forwardedApp.CompletedCapture.RawDisplay
                == standardMouseCase.Name,
            "A standard mouse input was not recordable: "
                standardMouseCase.Name)
    }

    CaptureAssertTrue(forwardedSession.Start("target"),
        "The injected-event filtering test did not start.")
    forwardedSession.ObserveGuardInputEvent({Kind: "keyboard",
        Message: 0x0100, VK: 0x72, SC: 0x3D, Flags: 0x10})
    CaptureAssertTrue(forwardedSession.RecordedOrder.Length == 0,
        "Injected remapping output polluted the recorded keys.")
    forwardedSession.Stop(false)

    FileAppend("PASS key capture session`n", "*")
} catch as testError {
    FileAppend(testError.Message "`n" testError.Stack "`n", "**")
    ExitApp(1)
}
ExitApp(0)

CaptureEvent(name, vk, sc, phase, deviceId := "keyboard-a") {
    identity := KeyIdentity.Create("keyboard", name, vk, sc,
        (sc & 0x100) != 0, deviceId, deviceId, 1, 6)
    return InputEvent.Create(identity, phase, false, false, "raw-input")
}

CaptureRelease(session, name, vk, sc, deviceId := "keyboard-a") {
    result := session.ObserveRawInputEvent(CaptureEvent(name, vk, sc, "up",
        deviceId))
    CaptureFinalizeDrain(session)
    return result
}

CaptureFinalizeDrain(session) {
    if session.Draining
        return session.FinalizeInputDrain()
    return false
}

CaptureDeviceEvent(deviceId, lifecycle) {
    device := Map("id", deviceId, "stable_id", deviceId,
        "display_name", deviceId, "handle", deviceId,
        "usage_page", 1, "usage", 6)
    identity := KeyIdentity.Create("device", deviceId, 0, 0, false,
        deviceId, deviceId, 1, 6)
    phase := lifecycle == "removal" ? "removal" : "arrival"
    return InputEvent.Create(identity, phase, false, false,
        "raw-input-device", "", Map("device", device,
            "lifecycle", lifecycle))
}

CapturePointerEvent(name, phase, deviceId := "mouse-a") {
    identity := KeyIdentity.Create("mouse", name, 0, 0, false,
        deviceId, deviceId, 1, 2)
    return InputEvent.Create(identity, phase, false, false, "raw-input")
}

CaptureContainsDeviceInfo(capture) {
    deviceFields := ["DeviceId", "DeviceHandle", "DeviceDisplayName",
        "Device", "UsagePage", "Usage"]
    for fieldName in deviceFields
        if capture.HasOwnProp(fieldName)
            return true
    for collectionName in ["Keys", "Modifiers"] {
        if !capture.HasOwnProp(collectionName)
            continue
        for keyInfo in capture.%collectionName% {
            for fieldName in deviceFields
                if keyInfo.HasOwnProp(fieldName)
                    return true
        }
    }
    return false
}

CaptureTarget(name) {
    return {RawDisplay: name, Display: name, TargetSend: "{" name "}"}
}

CaptureAssertTrue(value, message) {
    if !value
        throw Error(message)
}

CaptureAssertEqual(expected, actual, message) {
    if expected != actual
        throw Error(message " Expected '" expected "', got '" actual "'.")
}

Tr(chineseTemplate, values*) {
    return values.Length ? Format(chineseTemplate, values*) : chineseTemplate
}

class CaptureTestApp {
    __New(lifecycle := "") {
        this.Lifecycle := IsObject(lifecycle) ? lifecycle : []
        this.Settings := {EscapeCancelsRecording: true}
        this.SuspendCount := 0
        this.ResumeCount := 0
        this.CompletedCount := 0
        this.RejectedCount := 0
        this.ResumeFailureCount := 0
        this.CancelledCount := 0
        this.PointerFinalizedCount := 0
        this.SuppressEscapeCount := 0
        this.ResumeThrows := false
        this.SuspendReturns := true
        this.CancelForPointer := false
        this.LastPreview := ""
        this.CompletedCapture := ""
        this.CompletedRole := ""
    }

    SuspendRemappingForCapture() {
        this.Lifecycle.Push("suspend")
        this.SuspendCount++
        return this.SuspendReturns
    }

    ResumeRemappingAfterCapture(*) {
        this.Lifecycle.Push("resume")
        this.ResumeCount++
        if this.ResumeThrows
            throw Error("expected resume failure")
    }

    OnCapturePreview(role, capture) => this.LastPreview := capture

    OnCaptureCompleted(role, capture) {
        this.CompletedCount++
        this.CompletedRole := role
        this.CompletedCapture := capture
    }

    OnCaptureRejected(reason) => this.RejectedCount++
    OnCaptureResumeFailed(*) => this.ResumeFailureCount++
    OnCaptureCancelled(*) => this.CancelledCount++
    ShouldCancelCaptureForPointer(*) => this.CancelForPointer
    PrepareCapturePointerCancellation(*) => true
    FinalizeCapturePointerCancellation(*) => this.PointerFinalizedCount++
    PrepareCaptureEscapeCancellation(*) => this.SuppressEscapeCount++
    TraceEvent(*) => true
}

class CaptureTestInputGuard {
    __New(lifecycle := "") {
        this.Lifecycle := IsObject(lifecycle) ? lifecycle : []
        this.Active := false
        this.Resources := false
        this.StartCount := 0
        this.StopCount := 0
        this.FailStart := false
        this.FailStop := false
    }

    Start() {
        this.Lifecycle.Push("guard-start")
        this.StartCount++
        if this.FailStart
            throw Error("expected input-guard start failure")
        if this.Active
            return false
        this.Active := true
        this.Resources := true
        return true
    }

    Stop() {
        this.Lifecycle.Push("guard-stop")
        this.StopCount++
        wasEngaged := this.Active || this.Resources
        this.Active := false
        if this.FailStop
            throw Error("expected input-guard stop failure")
        this.Resources := false
        return wasEngaged
    }

    HasResources() => this.Resources
}

class CapturePrioritySession {
    __New(order) {
        this.Order := order
        this.Blocked := true
    }

    ObserveRawInputEvent(*) {
        this.Order.Push("capture")
        return true
    }

    IsInputBlocked() {
        this.Order.Push("capture-state")
        return this.Blocked
    }
}

class CapturePriorityRuntime {
    __New(order) {
        this.Order := order
        this.Observed := 0
    }

    ObserveInputEvent(*) {
        this.Order.Push("runtime")
        this.Observed++
        return true
    }
}
