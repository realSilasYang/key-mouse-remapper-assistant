#Requires AutoHotkey v2.0 64-bit
#SingleInstance Off
#Warn All, StdOut

#Include ..\..\src\Input\CaptureInputGuard.ahk

try {
    native := CaptureInputGuardTestNative()
    guard := CaptureInputGuard(native)

    GuardAssertTrue(guard.Start() && guard.Active && guard.HasResources(),
        "The capture input guard did not start.")
    GuardAssertEqual(2, native.InstalledHookTypes.Length,
        "The capture guard did not install both low-level hooks.")
    GuardAssertEqual(CaptureInputGuard.KeyboardHookType,
        native.InstalledHookTypes[1], "The keyboard hook was not installed first.")
    GuardAssertEqual(CaptureInputGuard.MouseHookType,
        native.InstalledHookTypes[2], "The mouse hook was not installed second.")

    for message in [0x0100, 0x0101, 0x0104, 0x0105]
        GuardAssertEqual(1, guard.OnKeyboardHook(0, message, 123),
            "A keyboard or system-key message escaped the active guard.")
    GuardAssertEqual(native.NextResult,
        guard.OnKeyboardHook(-1, 0x0100, 123),
        "A negative keyboard hook code was not forwarded.")
    GuardAssertEqual(1, guard.OnKeyboardHook(0, 0x9999, 123),
        "An unrecognized keyboard message escaped the fail-closed guard.")

    publishedEvents := CaptureInputGuardPublishedEvents()
    publishingNative := CaptureInputGuardTestNative()
    publishingGuard := CaptureInputGuard(publishingNative, publishedEvents)
    GuardAssertTrue(publishingGuard.Start(),
        "The publishing guard did not start.")
    keyboardData := Buffer(24, 0)
    NumPut("UInt", 0x70, keyboardData, 0)
    NumPut("UInt", 0x3B, keyboardData, 4)
    NumPut("UInt", 0x01, keyboardData, 8)
    GuardAssertEqual(1, publishingGuard.OnKeyboardHook(0, 0x0100,
        keyboardData.Ptr), "A forwarded keyboard event escaped the guard.")
    mouseData := Buffer(32, 0)
    NumPut("Int", -25, mouseData, 0)
    NumPut("Int", 40, mouseData, 4)
    NumPut("UInt", 120 << 16, mouseData, 8)
    GuardAssertEqual(1, publishingGuard.OnMouseHook(0, 0x020A,
        mouseData.Ptr), "A forwarded wheel event escaped the guard.")
    GuardAssertTrue(publishedEvents.Keyboard.Length == 1
            && publishedEvents.Keyboard[1].Message == 0x0100
            && publishedEvents.Keyboard[1].VK == 0x70
            && publishedEvents.Keyboard[1].SC == 0x3B
            && publishedEvents.Mouse.Length == 1
            && publishedEvents.Mouse[1].Message == 0x020A
            && publishedEvents.Mouse[1].X == -25
            && publishedEvents.Mouse[1].Y == 40,
        "The low-level guard did not copy intercepted input to its publisher.")
    publishingGuard.Stop()

    transportedPackets := []
    transport := CaptureInputGuardProcess("", "",
        GuardCollectTransportPacket.Bind(transportedPackets))
    transport.Active := true
    keyboardPayload := 0x2C | (0x137 << 16) | (0x01 << 32)
    transport.OnKeyboardMessage(0x0100, keyboardPayload)
    mousePayload := 0x020A | ((120 & 0xFFFF) << 16)
    transport.OnMouseMessage(mousePayload,
        ((-12 & 0xFFFF) | ((33 & 0xFFFF) << 16)))
    GuardAssertTrue(transportedPackets.Length == 2
            && transportedPackets[1].Kind == "keyboard"
            && transportedPackets[1].VK == 0x2C
            && transportedPackets[1].SC == 0x137
            && transportedPackets[2].Kind == "mouse"
            && transportedPackets[2].MouseData == 120
            && transportedPackets[2].X == -12
            && transportedPackets[2].Y == 33,
        "The parent-side transport did not decode forwarded hook input.")
    transport.Active := false

    for message in [0x0201, 0x0202, 0x0204, 0x0205, 0x0207, 0x0208,
            0x020A, 0x020B, 0x020C, 0x020E]
        GuardAssertEqual(1, guard.OnMouseHook(0, message, 456),
            "A mouse button or wheel message escaped the active guard.")
    GuardAssertEqual(native.NextResult,
        guard.OnMouseHook(0, 0x0200, 456),
        "Mouse movement was blocked during capture.")
    GuardAssertEqual(1, guard.OnMouseHook(0, 0x9999, 456),
        "An unrecognized mouse input message escaped the fail-closed guard.")
    GuardAssertEqual(native.NextResult,
        guard.OnMouseHook(-1, 0x0201, 456),
        "A negative mouse hook code was not forwarded.")

    GuardAssertTrue(guard.Stop() && !guard.Active && !guard.HasResources(),
        "The capture input guard did not release its hooks and callbacks.")
    GuardAssertEqual(2, native.UninstalledHooks.Length,
        "The capture guard did not uninstall both hooks.")
    GuardAssertEqual(2, native.FreedCallbacks.Length,
        "The capture guard did not release both callbacks.")
    GuardAssertTrue(!guard.Stop(),
        "Stopping an idle capture input guard reported a state change.")

    callbackFailureNative := CaptureInputGuardTestNative()
    callbackFailureNative.FailCallbackNumber := 2
    callbackFailureGuard := CaptureInputGuard(callbackFailureNative)
    GuardAssertThrows(() => callbackFailureGuard.Start(),
        "A partial callback creation failure was accepted.")
    GuardAssertTrue(!callbackFailureGuard.Active
            && !callbackFailureGuard.HasResources()
            && callbackFailureNative.FreedCallbacks.Length == 1,
        "A partial callback creation failure leaked its first callback.")

    installFailureNative := CaptureInputGuardTestNative()
    installFailureNative.FailHookType := CaptureInputGuard.MouseHookType
    installFailureGuard := CaptureInputGuard(installFailureNative)
    GuardAssertThrows(() => installFailureGuard.Start(),
        "A partial hook installation failure was accepted.")
    GuardAssertTrue(!installFailureGuard.Active
            && !installFailureGuard.HasResources()
            && installFailureNative.UninstalledHooks.Length == 1
            && installFailureNative.FreedCallbacks.Length == 2,
        "A partial hook installation failure was not rolled back.")

    retryNative := CaptureInputGuardTestNative()
    retryGuard := CaptureInputGuard(retryNative)
    retryGuard.Start()
    retryNative.FailUninstallHook := retryGuard.KeyboardHook
    GuardAssertThrows(() => retryGuard.Stop(),
        "A native unhook failure was silently ignored.")
    GuardAssertTrue(!retryGuard.Active && retryGuard.HasResources()
            && retryGuard.OnKeyboardHook(0, 0x0100, 0)
                == retryNative.NextResult,
        "A failed unhook left the inactive guard suppressing input.")
    retryNative.FailUninstallHook := 0
    GuardAssertTrue(retryGuard.Stop() && !retryGuard.HasResources(),
        "A deferred native unhook could not be retried.")

    FileAppend("PASS capture input guard`n", "*")
} catch as testError {
    FileAppend(testError.Message "`n" testError.Stack "`n", "**")
    ExitApp(1)
}
ExitApp(0)

GuardAssertTrue(value, message) {
    if !value
        throw Error(message)
}

GuardAssertEqual(expected, actual, message) {
    if expected != actual
        throw Error(message " Expected=" expected " Actual=" actual)
}

GuardAssertThrows(callback, message) {
    try callback.Call()
    catch
        return true
    throw Error(message)
}

GuardCollectTransportPacket(packets, packet) {
    packets.Push(packet)
}

class CaptureInputGuardPublishedEvents {
    __New() {
        this.Keyboard := []
        this.Mouse := []
    }

    PublishKeyboard(message, eventData) {
        this.Keyboard.Push({Message: message,
            VK: NumGet(eventData, 0, "UInt"),
            SC: NumGet(eventData, 4, "UInt"),
            Flags: NumGet(eventData, 8, "UInt")})
    }

    PublishMouse(message, eventData) {
        this.Mouse.Push({Message: message,
            X: NumGet(eventData, 0, "Int"),
            Y: NumGet(eventData, 4, "Int"),
            MouseData: NumGet(eventData, 8, "UInt")})
    }
}

class CaptureInputGuardTestNative {
    __New() {
        this.NextCallback := 100
        this.NextHook := 200
        this.CallbackCount := 0
        this.FailCallbackNumber := 0
        this.FailHookType := 0
        this.FailUninstallHook := 0
        this.NextResult := 77
        this.InstalledHookTypes := []
        this.UninstalledHooks := []
        this.FreedCallbacks := []
    }

    CreateCallback(*) {
        this.CallbackCount++
        if this.CallbackCount == this.FailCallbackNumber
            throw Error("expected callback creation failure")
        this.NextCallback++
        return this.NextCallback
    }

    FreeCallback(callbackAddress) {
        this.FreedCallbacks.Push(callbackAddress)
        return true
    }

    InstallHook(hookType, *) {
        if hookType == this.FailHookType
            throw Error("expected hook installation failure")
        this.InstalledHookTypes.Push(hookType)
        this.NextHook++
        return this.NextHook
    }

    UninstallHook(hookHandle) {
        if hookHandle == this.FailUninstallHook
            throw Error("expected hook removal failure")
        this.UninstalledHooks.Push(hookHandle)
        return true
    }

    CallNext(*) => this.NextResult
}
