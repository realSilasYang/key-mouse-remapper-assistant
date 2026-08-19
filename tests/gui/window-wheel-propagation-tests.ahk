#Requires AutoHotkey v2.0 64-bit
#SingleInstance Off
#Warn All, StdOut

#Include ..\..\src\Platform\Win32.ahk
#Include ..\..\src\UI\WindowWheelPropagationGuard.ahk

ExitApp(RunWindowWheelPropagationTests() ? 0 : 1)

RunWindowWheelPropagationTests() {
    ownerGui := childGui := guard := parentProbe := forwardingProbe := ""
    try {
        ownerGui := Gui(, "wheel propagation owner")
        childGui := Gui("+Owner" ownerGui.Hwnd, "wheel propagation child")
        ownerGui.Show("x40 y40 w240 h160 NA")
        childGui.Show("x60 y60 w180 h100 NA")
        parentProbe := WindowWheelParentProbe(ownerGui.Hwnd)
        forwardingProbe := WindowWheelForwardingProbe(childGui.Hwnd,
            ownerGui.Hwnd)
        guard := WindowWheelPropagationGuard.ForOwnedWindow(childGui)
        WindowWheelAssert(IsObject(guard) && guard.Attached,
            "The owned window did not install a wheel propagation boundary.")

        wheelDownWParam := ((-120 & 0xFFFF) << 16)
        SendMessage(Win32.WM_MOUSEWHEEL, wheelDownWParam, 0, , childGui.Hwnd)
        SendMessage(Win32.WM_MOUSEHWHEEL, wheelDownWParam, 0, , childGui.Hwnd)
        WindowWheelAssert(parentProbe.VerticalCount == 0
                && parentProbe.HorizontalCount == 0,
            "An owned window forwarded a wheel message to its owner.")

        guard.Dispose()
        guard := ""
        SendMessage(Win32.WM_MOUSEWHEEL, wheelDownWParam, 0, , childGui.Hwnd)
        SendMessage(Win32.WM_MOUSEHWHEEL, wheelDownWParam, 0, , childGui.Hwnd)
        WindowWheelAssert(parentProbe.VerticalCount == 1
                && parentProbe.HorizontalCount == 1,
            "The propagation probe could not observe the unguarded baseline.")

        unownedGui := Gui(, "unowned wheel window")
        try WindowWheelAssert(
            WindowWheelPropagationGuard.ForOwnedWindow(unownedGui) == "",
            "An unowned top-level window installed an unnecessary boundary.")
        finally unownedGui.Destroy()
        return true
    } catch as testError {
        FileAppend(testError.Message "`n" testError.Stack "`n", "**")
        return false
    } finally {
        if IsObject(guard)
            try guard.Dispose()
        if IsObject(forwardingProbe)
            try forwardingProbe.Dispose()
        if IsObject(parentProbe)
            try parentProbe.Dispose()
        if IsObject(childGui)
            try childGui.Destroy()
        if IsObject(ownerGui)
            try ownerGui.Destroy()
    }
}

WindowWheelAssert(condition, message) {
    if !condition
        throw Error(message)
}

class WindowWheelParentProbe {
    static SubclassId := 0x4B4D5751

    __New(hwnd) {
        this.Hwnd := hwnd
        this.VerticalCount := 0
        this.HorizontalCount := 0
        this.SubclassMethod := ObjBindMethod(this, "SubclassProc")
        this.SubclassCallback := CallbackCreate(this.SubclassMethod, "", 6)
        if !DllCall("comctl32\SetWindowSubclass", "Ptr", hwnd,
                "Ptr", this.SubclassCallback, "UPtr",
                WindowWheelParentProbe.SubclassId,
                "UPtr", 0, "Int")
            throw Error("The owner wheel probe could not be installed.")
    }

    SubclassProc(hwnd, message, wParam, lParam, subclassId, referenceData) {
        if message == Win32.WM_MOUSEWHEEL {
            this.VerticalCount++
            return 0
        }
        if message == Win32.WM_MOUSEHWHEEL {
            this.HorizontalCount++
            return 0
        }
        return DllCall("comctl32\DefSubclassProc", "Ptr", hwnd,
            "UInt", message, "UPtr", wParam, "Ptr", lParam, "Ptr")
    }

    Dispose() {
        if !this.SubclassCallback
            return true
        if this.Hwnd && DllCall("user32\IsWindow", "Ptr", this.Hwnd, "Int")
            DllCall("comctl32\RemoveWindowSubclass", "Ptr", this.Hwnd,
                "Ptr", this.SubclassCallback, "UPtr",
                WindowWheelParentProbe.SubclassId, "Int")
        CallbackFree(this.SubclassCallback)
        this.SubclassCallback := 0
        this.SubclassMethod := ""
        this.Hwnd := 0
        return true
    }
}

class WindowWheelForwardingProbe {
    static SubclassId := 0x4B4D5752

    __New(hwnd, ownerHwnd) {
        this.Hwnd := hwnd
        this.OwnerHwnd := ownerHwnd
        this.SubclassMethod := ObjBindMethod(this, "SubclassProc")
        this.SubclassCallback := CallbackCreate(this.SubclassMethod, "", 6)
        if !DllCall("comctl32\SetWindowSubclass", "Ptr", hwnd,
                "Ptr", this.SubclassCallback, "UPtr",
                WindowWheelForwardingProbe.SubclassId,
                "UPtr", 0, "Int")
            throw Error("The child wheel forwarding probe could not be installed.")
    }

    SubclassProc(hwnd, message, wParam, lParam, subclassId, referenceData) {
        if message == Win32.WM_MOUSEWHEEL
                || message == Win32.WM_MOUSEHWHEEL
            return SendMessage(message, wParam, lParam, , this.OwnerHwnd)
        return DllCall("comctl32\DefSubclassProc", "Ptr", hwnd,
            "UInt", message, "UPtr", wParam, "Ptr", lParam, "Ptr")
    }

    Dispose() {
        if !this.SubclassCallback
            return true
        if this.Hwnd && DllCall("user32\IsWindow", "Ptr", this.Hwnd, "Int")
            DllCall("comctl32\RemoveWindowSubclass", "Ptr", this.Hwnd,
                "Ptr", this.SubclassCallback, "UPtr",
                WindowWheelForwardingProbe.SubclassId, "Int")
        CallbackFree(this.SubclassCallback)
        this.SubclassCallback := 0
        this.SubclassMethod := ""
        this.Hwnd := 0
        this.OwnerHwnd := 0
        return true
    }
}
