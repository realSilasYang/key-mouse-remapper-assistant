class WindowWheelPropagationGuard {
    static SubclassId := 0x4B4D5750

    static ForOwnedWindow(guiObj) {
        try hwnd := guiObj.Hwnd
        catch
            return ""
        if !hwnd || !DllCall("user32\GetWindow", "Ptr", hwnd,
                "UInt", 4, "Ptr") ; GW_OWNER
            return ""
        return this(guiObj)
    }

    __New(guiObj) {
        this.Gui := guiObj
        this.Hwnd := guiObj.Hwnd
        this.Attached := false
        this.Disposed := false
        this.SubclassMethod := ObjBindMethod(this, "SubclassProc")
        this.SubclassCallback := CallbackCreate(this.SubclassMethod, "", 6)
        this.ReleaseTimer := ObjBindMethod(this,
            "ReleaseCallbackAfterDestroy")
        if !DllCall("comctl32\SetWindowSubclass", "Ptr", this.Hwnd,
                "Ptr", this.SubclassCallback,
                "UPtr", WindowWheelPropagationGuard.SubclassId,
                "UPtr", 0, "Int") {
            CallbackFree(this.SubclassCallback)
            this.SubclassCallback := 0
            this.SubclassMethod := ""
            this.ReleaseTimer := ""
            throw Error("无法阻止窗口滚轮消息向上级窗口传播。")
        }
        this.Attached := true
    }

    SubclassProc(hwnd, message, wParam, lParam, subclassId, referenceData) {
        try {
            if message == Win32.WM_MOUSEWHEEL
                    || message == Win32.WM_MOUSEHWHEEL
                return 0
            if message == Win32.WM_NCDESTROY {
                this.Attached := false
                this.Hwnd := 0
                result := this.DefSubclassProc(hwnd, message, wParam, lParam)
                SetTimer(this.ReleaseTimer, -1)
                return result
            }
        } catch {
            ; Exceptions must not cross the native window-procedure boundary.
        }
        return this.DefSubclassProc(hwnd, message, wParam, lParam)
    }

    DefSubclassProc(hwnd, message, wParam, lParam) {
        return DllCall("comctl32\DefSubclassProc", "Ptr", hwnd,
            "UInt", message, "UPtr", wParam, "Ptr", lParam, "Ptr")
    }

    Dispose() {
        if this.Disposed
            return true
        this.Disposed := true
        SetTimer(this.ReleaseTimer, 0)
        if this.Attached && this.Hwnd
                && DllCall("user32\IsWindow", "Ptr", this.Hwnd, "Int") {
            if !DllCall("comctl32\RemoveWindowSubclass", "Ptr", this.Hwnd,
                    "Ptr", this.SubclassCallback,
                    "UPtr", WindowWheelPropagationGuard.SubclassId, "Int") {
                this.Disposed := false
                throw Error("无法移除窗口滚轮传播边界。Win32 " A_LastError)
            }
        }
        this.Attached := false
        this.Hwnd := 0
        this.Gui := ""
        return this.ReleaseCallback()
    }

    ReleaseCallbackAfterDestroy(*) {
        if this.Attached
            return false
        this.Disposed := true
        this.Gui := ""
        return this.ReleaseCallback()
    }

    ReleaseCallback() {
        if this.SubclassCallback {
            CallbackFree(this.SubclassCallback)
            this.SubclassCallback := 0
        }
        this.SubclassMethod := ""
        this.ReleaseTimer := ""
        return true
    }
}
