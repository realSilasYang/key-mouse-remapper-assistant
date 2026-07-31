; Restore MSAA push-button semantics for owner-drawn text controls.
; The accessible name remains backed by WM_GETTEXT, so dynamic button labels
; do not need a second synchronization path.

class ControlAccessibilityService {
    static ObjectIdClient := -4
    static RolePushButton := 0x2B
    static PropertyRole := "{CB905FF2-7BD1-4C05-B3C8-E6C241364D70}"
    static PropertyDefaultAction := "{180C072B-C27F-43C7-9922-F63562A4632B}"
    static Service := ""
    static RoleGuid := ""
    static DefaultActionGuid := ""
    static ActiveButtons := Map()

    static RegisterButton(hwnd, defaultAction) {
        if !this.IsWindow(hwnd)
            return false
        service := this.GetService()
        if !service
            return false
        try {
            roleValue := this.CreateIntegerVariant(this.RolePushButton)
            if ComCall(6, service, "Ptr", hwnd, "Int", this.ObjectIdClient,
                "Int", 0, "Ptr", this.GetRoleGuid(), "Ptr", roleValue,
                "Int") < 0
                return false
            this.ActiveButtons[hwnd] := true
            if ComCall(7, service, "Ptr", hwnd, "Int", this.ObjectIdClient,
                "Int", 0, "Ptr", this.GetDefaultActionGuid(), "WStr",
                String(defaultAction), "Int") < 0 {
                this.ClearButton(hwnd)
                return false
            }
            return true
        } catch {
            if this.ActiveButtons.Has(hwnd)
                this.ClearButton(hwnd)
            return false
        }
    }

    static ClearButton(hwnd) {
        if !hwnd
            return false
        wasRegistered := this.ActiveButtons.Has(hwnd)
        if !wasRegistered
            return false
        if !this.IsWindow(hwnd) {
            this.ActiveButtons.Delete(hwnd)
            return true
        }
        service := this.GetService()
        if !service
            return false
        propertyList := Buffer(32, 0)
        DllCall("kernel32\RtlMoveMemory", "Ptr", propertyList, "Ptr",
            this.GetRoleGuid(), "UPtr", 16)
        DllCall("kernel32\RtlMoveMemory", "Ptr", propertyList.Ptr + 16,
            "Ptr", this.GetDefaultActionGuid(), "UPtr", 16)
        cleared := false
        try cleared := ComCall(9, service, "Ptr", hwnd, "Int",
            this.ObjectIdClient, "Int", 0, "Ptr", propertyList,
            "Int", 2, "Int") >= 0
        catch
            return false
        if cleared
            this.ActiveButtons.Delete(hwnd)
        return cleared
    }

    static Shutdown() {
        buttonHandles := []
        for hwnd, _ in this.ActiveButtons
            buttonHandles.Push(hwnd)
        failures := []
        for hwnd in buttonHandles
            if !this.ClearButton(hwnd)
                failures.Push(hwnd)
        if failures.Length
            throw Error("无法清除 " failures.Length " 个按钮的无障碍属性。")
        this.Service := ""
        this.RoleGuid := ""
        this.DefaultActionGuid := ""
        return true
    }

    static GetService() {
        if IsObject(this.Service)
            return this.Service
        try this.Service := ComObject(
            "{B5F8350B-0548-48B1-A6EE-88BD00B4A5E7}",
            "{6E26E776-04F0-495D-80E4-3330352E3169}")
        catch
            this.Service := ""
        return this.Service
    }

    static GetRoleGuid() {
        if IsObject(this.RoleGuid)
            return this.RoleGuid
        this.RoleGuid := this.CreateGuid(this.PropertyRole)
        return this.RoleGuid
    }

    static GetDefaultActionGuid() {
        if IsObject(this.DefaultActionGuid)
            return this.DefaultActionGuid
        this.DefaultActionGuid := this.CreateGuid(this.PropertyDefaultAction)
        return this.DefaultActionGuid
    }

    static CreateGuid(value) {
        guid := Buffer(16, 0)
        if DllCall("ole32\CLSIDFromString", "WStr", value, "Ptr", guid,
                "Int") < 0
            throw Error("Invalid accessibility property identifier")
        return guid
    }

    static CreateIntegerVariant(value) {
        variant := Buffer(24, 0)
        NumPut("UShort", 3, variant, 0) ; VT_I4
        NumPut("Int", value, variant, 8)
        return variant
    }

    static IsWindow(hwnd) {
        return hwnd && DllCall("user32\IsWindow", "Ptr", hwnd, "Int") != 0
    }
}
