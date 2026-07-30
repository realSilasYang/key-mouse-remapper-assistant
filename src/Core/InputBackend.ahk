; 所有输入后端共享的最小稳定契约。业务层只能依赖这些方法，不能根据
; 后端名称猜测设备识别、阻止或安全桌面能力。
class IInputBackend {
    GetBackendId() {
        throw MethodError("输入后端没有实现 GetBackendId。")
    }

    GetCapabilities() {
        throw MethodError("输入后端没有实现 GetCapabilities。")
    }

    Replace(registrations) {
        throw MethodError("输入后端没有实现 Replace。")
    }

    StartObservation(callback) {
        return false
    }

    StopObservation() {
        return false
    }

    Suspend() {
        return false
    }

    Resume() {
        return false
    }

    ReleaseAll() {
        return 0
    }

    EmitAction(actionType, value, phase := "") {
        switch StrLower(String(actionType)) {
            case "send", "mouse": Send(String(value))
            case "text": SendText(String(value))
            case "app_command": Send("{" String(value) "}")
            case "key": Send("{" String(value) " " String(phase) "}")
            case "sleep": Sleep(Integer(value))
            case "window_minimize":
                if hwnd := WinExist("A")
                    DllCall("user32\ShowWindow", "Ptr", hwnd, "Int", 6)
            case "window_close":
                if hwnd := WinExist("A")
                    WinClose("ahk_id " hwnd)
            case "lock_workstation":
                if !DllCall("user32\LockWorkStation", "Int")
                    throw OSError(A_LastError, "无法锁定工作站。")
            default: throw Error("输入后端不支持输出动作：" actionType)
        }
        return true
    }

    GetCurrentEventDevice() {
        return ""
    }

    GetDevices() {
        return []
    }

    RecoverAfterResume() {
        return this.GetDevices()
    }

    HealthCheck() {
        return Map("backend", this.GetBackendId(),
            "healthy", JsonBoolean(true), "detail", "")
    }

    Shutdown() {
    }
}

class InputBackendContract {
    static RequiredMethods := ["GetBackendId", "GetCapabilities", "Replace",
        "StartObservation", "StopObservation", "Suspend", "Resume",
        "ReleaseAll", "EmitAction", "GetCurrentEventDevice", "GetDevices",
        "RecoverAfterResume", "HealthCheck", "Shutdown"]

    static Validate(backend) {
        if !IsObject(backend)
            throw TypeError("输入后端必须是对象。")
        missing := []
        for methodName in this.RequiredMethods {
            if !HasMethod(backend, methodName)
                missing.Push(methodName)
        }
        if missing.Length
            throw TypeError("输入后端缺少契约方法：" this.Join(missing, ", "))
        backendCapabilities := backend.GetCapabilities()
        if Type(backendCapabilities) != "Map"
                || !backendCapabilities.Has("backend")
                || !backendCapabilities.Has("available")
            throw TypeError("输入后端能力描述无效。")
        if String(backendCapabilities["backend"])
                != String(backend.GetBackendId())
            throw Error("输入后端标识与能力描述不一致。")
        return backend
    }

    static Join(values, separator) {
        result := ""
        for index, value in values
            result .= (index > 1 ? separator : "") String(value)
        return result
    }
}
