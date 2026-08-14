; 录制会话先取得低级钩子，再暂停项目内规则；新安装的钩子位于当时已有的
; 普通桌面用户态输入链最前端，可封住规则暂停过程中的按键竞争窗口。
; Windows 安全注意序列和安全桌面在内核边界处理，不会进入任何用户态钩子。
class CaptureInputGuard {
    static KeyboardHookType := 13 ; WH_KEYBOARD_LL
    static MouseHookType := 14 ; WH_MOUSE_LL
    static MouseMoveMessage := 0x0200 ; WM_MOUSEMOVE
    static MousePointMessages := Map(
        0x0201, true, ; WM_LBUTTONDOWN
        0x0202, true, ; WM_LBUTTONUP
        0x0204, true, ; WM_RBUTTONDOWN
        0x0205, true, ; WM_RBUTTONUP
        0x0207, true, ; WM_MBUTTONDOWN
        0x0208, true, ; WM_MBUTTONUP
        0x020B, true, ; WM_XBUTTONDOWN
        0x020C, true) ; WM_XBUTTONUP

    __New(nativeApi := "", eventSink := "") {
        this.Native := IsObject(nativeApi)
            ? nativeApi : CaptureInputGuardNative()
        this.EventSink := IsObject(eventSink) ? eventSink : ""
        this.Active := false
        this.KeyboardHook := 0
        this.MouseHook := 0
        this.KeyboardCallback := 0
        this.MouseCallback := 0
        this.KeyboardMethod := ""
        this.MouseMethod := ""
        this.LastMouseX := 0
        this.LastMouseY := 0
        this.LastMousePointTick := 0
    }

    Start() {
        if this.Active
            return false
        if this.HasResources()
            throw Error("录制输入守卫仍有未清理的系统钩子。")
        this.CreateCallbacks()
        this.LastMousePointTick := 0
        this.Active := true
        try {
            this.KeyboardHook := this.Native.InstallHook(
                CaptureInputGuard.KeyboardHookType, this.KeyboardCallback)
            if !this.KeyboardHook
                throw Error("无法安装录制键盘拦截钩子。")
            this.MouseHook := this.Native.InstallHook(
                CaptureInputGuard.MouseHookType, this.MouseCallback)
            if !this.MouseHook
                throw Error("无法安装录制鼠标拦截钩子。")
            return true
        } catch as startError {
            this.Active := false
            cleanupErrors := this.ReleaseResources()
            if cleanupErrors.Length
                throw Error(startError.Message "；启动回滚失败："
                    . this.Join(cleanupErrors, "；"), -1, startError)
            throw startError
        }
    }

    Stop() {
        wasEngaged := this.Active || this.HasResources()
        this.Active := false
        cleanupErrors := this.ReleaseResources()
        if cleanupErrors.Length
            throw Error("无法完整停止录制输入守卫："
                . this.Join(cleanupErrors, "；"))
        return wasEngaged
    }

    Shutdown() => this.Stop()

    HasResources() {
        return this.KeyboardHook || this.MouseHook
            || this.KeyboardCallback || this.MouseCallback
    }

    CreateCallbacks() {
        if this.KeyboardCallback || this.MouseCallback
            throw Error("录制输入守卫回调已存在。")
        this.KeyboardMethod := ObjBindMethod(this, "OnKeyboardHook")
        this.MouseMethod := ObjBindMethod(this, "OnMouseHook")
        try {
            this.KeyboardCallback := this.Native.CreateCallback(
                this.KeyboardMethod)
            this.MouseCallback := this.Native.CreateCallback(
                this.MouseMethod)
        } catch as callbackError {
            cleanupErrors := this.ReleaseResources()
            if cleanupErrors.Length
                throw Error(callbackError.Message "；回调回滚失败："
                    . this.Join(cleanupErrors, "；"), -1, callbackError)
            throw callbackError
        }
        return true
    }

    ReleaseResources() {
        errors := []
        this.ReleaseHook("MouseHook", "鼠标钩子", errors)
        this.ReleaseHook("KeyboardHook", "键盘钩子", errors)
        if !this.MouseHook
            this.ReleaseCallback("MouseCallback", "MouseMethod",
                "鼠标回调", errors)
        if !this.KeyboardHook
            this.ReleaseCallback("KeyboardCallback", "KeyboardMethod",
                "键盘回调", errors)
        return errors
    }

    ReleaseHook(propertyName, label, errors) {
        hookHandle := this.%propertyName%
        if !hookHandle
            return true
        try {
            if !this.Native.UninstallHook(hookHandle)
                throw Error("系统拒绝注销。")
            this.%propertyName% := 0
            return true
        } catch as hookError {
            errors.Push(label "：" hookError.Message)
            return false
        }
    }

    ReleaseCallback(callbackProperty, methodProperty, label, errors) {
        callbackAddress := this.%callbackProperty%
        if !callbackAddress {
            this.%methodProperty% := ""
            return true
        }
        try {
            this.Native.FreeCallback(callbackAddress)
            this.%callbackProperty% := 0
            this.%methodProperty% := ""
            return true
        } catch as callbackError {
            errors.Push(label "：" callbackError.Message)
            return false
        }
    }

    OnKeyboardHook(code, message, eventData) {
        ; WH_KEYBOARD_LL only reports keyboard input messages. Suppress every
        ; valid callback instead of maintaining an allow-list which could let
        ; a system or future keyboard message escape.
        if code >= 0 && this.Active {
            if eventData && IsObject(this.EventSink)
                try this.EventSink.PublishKeyboard(message, eventData)
            return 1
        }
        return this.Native.CallNext(this.KeyboardHook, code, message,
            eventData)
    }

    OnMouseHook(code, message, eventData) {
        if code >= 0 && eventData
                && CaptureInputGuard.MousePointMessages.Has(message) {
            ; MSLLHOOKSTRUCT starts with the screen-space POINT. Keeping the
            ; hook-time coordinate avoids a race where the cursor moves away
            ; before the corresponding Raw Input packet reaches the GUI thread.
            try {
                this.LastMouseX := NumGet(eventData, 0, "Int")
                this.LastMouseY := NumGet(eventData, 4, "Int")
                this.LastMousePointTick := A_TickCount
            }
            catch
                ; Test doubles and malformed callbacks may provide a token
                ; instead of a valid MSLLHOOKSTRUCT pointer.
                this.LastMousePointTick := 0
        }
        ; Pointer movement is not a recordable button. Every other valid
        ; low-level mouse event is treated as input and fails closed.
        if code >= 0 && this.Active
                && message != CaptureInputGuard.MouseMoveMessage {
            if eventData && IsObject(this.EventSink)
                try this.EventSink.PublishMouse(message, eventData)
            return 1
        }
        return this.Native.CallNext(this.MouseHook, code, message, eventData)
    }

    GetLastMousePoint(maxAgeMs := 500) {
        if !this.LastMousePointTick
            return ""
        if maxAgeMs >= 0 && A_TickCount - this.LastMousePointTick > maxAgeMs
            return ""
        return {X: this.LastMouseX, Y: this.LastMouseY,
            Tick: this.LastMousePointTick}
    }

    Join(values, separator) {
        result := ""
        for index, value in values
            result .= (index == 1 ? "" : separator) value
        return result
    }
}

class CaptureInputGuardNative {
    CreateCallback(callback) => CallbackCreate(callback, "Fast", 3)

    FreeCallback(callbackAddress) {
        CallbackFree(callbackAddress)
        return true
    }

    InstallHook(hookType, callbackAddress) {
        moduleHandle := DllCall("kernel32\GetModuleHandleW", "Ptr", 0,
            "Ptr")
        hookHandle := DllCall("user32\SetWindowsHookExW", "Int", hookType,
            "Ptr", callbackAddress, "Ptr", moduleHandle, "UInt", 0, "Ptr")
        if !hookHandle
            throw OSError(A_LastError, "无法安装录制输入钩子。")
        return hookHandle
    }

    UninstallHook(hookHandle) {
        if !DllCall("user32\UnhookWindowsHookEx", "Ptr", hookHandle, "Int")
            throw OSError(A_LastError, "无法注销录制输入钩子。")
        return true
    }

    CallNext(hookHandle, code, message, eventData) {
        return DllCall("user32\CallNextHookEx", "Ptr", hookHandle,
            "Int", code, "Ptr", message, "Ptr", eventData, "Ptr")
    }
}

; The recorder owns this short-lived process, whose only job is to keep the
; low-level hook thread responsive while the GUI waits for rule workers.
class CaptureInputGuardProcess {
    static WorkerFlag := "--capture-input-guard-worker"
    static ReadyTimeoutMs := 5000
    static StopTimeoutMs := 3000
    static KeyboardMessageName :=
        "KeyMouseRemapperAssistant.Capture.Keyboard.v1"
    static MouseMessageName :=
        "KeyMouseRemapperAssistant.Capture.Mouse.v1"

    __New(interpreterPath := "", scriptPath := "", eventSink := "") {
        this.InterpreterPath := interpreterPath != ""
            ? String(interpreterPath) : A_AhkPath
        this.ScriptPath := scriptPath != ""
            ? String(scriptPath) : CaptureInputGuardProcess.WorkerScriptPath()
        this.EventSink := IsObject(eventSink) ? eventSink : ""
        this.Active := false
        this.ProcessId := 0
        this.ProcessHandle := 0
        this.ReadyHandle := 0
        this.StopHandle := 0
        this.KeyboardMessageCallback := ""
        this.MouseMessageCallback := ""
        this.KeyboardMessageRegistered := false
        this.MouseMessageRegistered := false
        this.LastMouseX := 0
        this.LastMouseY := 0
        this.LastMousePointTick := 0
    }

    Start() {
        if this.Active
            return false
        if this.HasResources()
            throw Error("录制输入守卫进程仍有未清理的资源。")
        sessionToken := DllCall("kernel32\GetCurrentProcessId", "UInt") "-"
            . A_TickCount "-" Format("{:08X}", Random(0, 0xFFFFFFFF))
        readyName := "Local\KMRA-Capture-" sessionToken "-ready"
        stopName := "Local\KMRA-Capture-" sessionToken "-stop"
        try {
            if !FileExist(this.ScriptPath)
                throw Error("录制输入守卫入口不存在：" this.ScriptPath)
            this.RegisterEventMessages()
            this.ReadyHandle := this.CreateEvent(readyName)
            this.StopHandle := this.CreateEvent(stopName)
            command := this.Quote(this.InterpreterPath) " /ErrorStdOut "
                . this.Quote(this.ScriptPath) " "
                . CaptureInputGuardProcess.WorkerFlag " "
                . this.Quote(stopName) " " . this.Quote(readyName) " "
                . this.Quote(IsObject(this.EventSink) ? A_ScriptHwnd : 0)
            Run(command, , "Hide", &processId)
            this.ProcessId := processId
            this.ProcessHandle := DllCall("kernel32\OpenProcess", "UInt",
                0x00101001, "Int", false, "UInt", processId, "Ptr")
            if !this.ProcessHandle
                throw OSError(A_LastError,
                    "无法取得录制输入守卫进程句柄。")
            waitResult := DllCall("kernel32\WaitForSingleObject", "Ptr",
                this.ReadyHandle, "UInt",
                CaptureInputGuardProcess.ReadyTimeoutMs, "UInt")
            if waitResult != 0 {
                exited := DllCall("kernel32\WaitForSingleObject", "Ptr",
                    this.ProcessHandle, "UInt", 0, "UInt") == 0
                throw Error(exited ? "录制输入守卫进程提前退出。"
                    : "录制输入守卫进程启动超时。")
            }
            this.Active := true
            this.LastMousePointTick := 0
            return true
        } catch as startError {
            cleanupErrors := this.ReleaseResources(true)
            if cleanupErrors.Length
                throw Error(startError.Message "；启动回滚失败："
                    . this.Join(cleanupErrors, "；"), -1, startError)
            throw startError
        }
    }

    Stop() {
        wasEngaged := this.Active || this.HasResources()
        this.Active := false
        cleanupErrors := this.ReleaseResources(true)
        if cleanupErrors.Length
            throw Error("无法完整停止录制输入守卫进程："
                . this.Join(cleanupErrors, "；"))
        return wasEngaged
    }

    Shutdown() => this.Stop()

    HasResources() {
        return this.ProcessId || this.ProcessHandle
            || this.ReadyHandle || this.StopHandle
            || this.KeyboardMessageRegistered
            || this.MouseMessageRegistered
    }

    GetLastMousePoint(maxAgeMs := 500) {
        if !this.LastMousePointTick
            return ""
        if maxAgeMs >= 0 && A_TickCount - this.LastMousePointTick > maxAgeMs
            return ""
        return {X: this.LastMouseX, Y: this.LastMouseY,
            Tick: this.LastMousePointTick}
    }

    ReleaseResources(forceProcess := false) {
        errors := []
        if this.ProcessId {
            if this.StopHandle
                try {
                    if !DllCall("kernel32\SetEvent", "Ptr", this.StopHandle,
                            "Int")
                        throw OSError(A_LastError,
                            "无法通知录制输入守卫退出。")
                } catch as signalError
                    errors.Push(signalError.Message)
            stopped := false
            if this.ProcessHandle {
                waitResult := DllCall("kernel32\WaitForSingleObject", "Ptr",
                    this.ProcessHandle, "UInt",
                    CaptureInputGuardProcess.StopTimeoutMs, "UInt")
                stopped := waitResult == 0
                if !stopped && waitResult != 0x00000102
                    errors.Push("等待录制输入守卫退出失败。")
            } else {
                stopped := !ProcessExist(this.ProcessId)
            }
            if !stopped && forceProcess {
                try ProcessClose(this.ProcessId)
                catch as closeError
                    errors.Push("强制停止录制输入守卫失败："
                        closeError.Message)
                if this.ProcessHandle
                    stopped := DllCall("kernel32\WaitForSingleObject", "Ptr",
                        this.ProcessHandle, "UInt", 1000, "UInt") == 0
                else
                    stopped := !ProcessExist(this.ProcessId)
            }
            if stopped
                this.ProcessId := 0
            else
                errors.Push("录制输入守卫进程仍在运行。")
        }
        if !this.ProcessId {
            this.CloseHandle("ProcessHandle", errors)
            this.CloseHandle("ReadyHandle", errors)
            this.CloseHandle("StopHandle", errors)
            this.UnregisterEventMessages(errors)
        }
        return errors
    }

    RegisterEventMessages() {
        if !IsObject(this.EventSink)
            return false
        this.KeyboardMessageCallback := ObjBindMethod(this,
            "OnKeyboardMessage")
        this.MouseMessageCallback := ObjBindMethod(this, "OnMouseMessage")
        try {
            OnMessage(CaptureInputGuardProcess.KeyboardMessageId(),
                this.KeyboardMessageCallback)
            this.KeyboardMessageRegistered := true
            OnMessage(CaptureInputGuardProcess.MouseMessageId(),
                this.MouseMessageCallback)
            this.MouseMessageRegistered := true
            return true
        } catch as registrationError {
            errors := []
            this.UnregisterEventMessages(errors)
            throw registrationError
        }
    }

    UnregisterEventMessages(errors) {
        this.UnregisterEventMessage("MouseMessageRegistered",
            "MouseMessageCallback", CaptureInputGuardProcess.MouseMessageId(),
            errors)
        this.UnregisterEventMessage("KeyboardMessageRegistered",
            "KeyboardMessageCallback",
            CaptureInputGuardProcess.KeyboardMessageId(), errors)
        return true
    }

    UnregisterEventMessage(registrationProperty, callbackProperty,
            messageId, errors) {
        if !this.%registrationProperty% {
            this.%callbackProperty% := ""
            return true
        }
        try {
            OnMessage(messageId, this.%callbackProperty%, 0)
            this.%registrationProperty% := false
            this.%callbackProperty% := ""
            return true
        } catch as unregisterError {
            errors.Push("无法注销录制输入回传消息：" unregisterError.Message)
            return false
        }
    }

    OnKeyboardMessage(message, payload, *) {
        if !this.Active || !IsObject(this.EventSink)
            return 0
        packet := {
            Kind: "keyboard",
            Message: Integer(message) & 0xFFFF,
            VK: Integer(payload) & 0xFFFF,
            SC: (Integer(payload) >> 16) & 0xFFFF,
            Flags: (Integer(payload) >> 32) & 0xFF
        }
        try this.EventSink.Call(packet)
        return 0
    }

    OnMouseMessage(payload, pointPayload, *) {
        if !this.Active || !IsObject(this.EventSink)
            return 0
        x := Integer(pointPayload) & 0xFFFF
        y := (Integer(pointPayload) >> 16) & 0xFFFF
        if x & 0x8000
            x -= 0x10000
        if y & 0x8000
            y -= 0x10000
        data := (Integer(payload) >> 16) & 0xFFFF
        if data & 0x8000
            data -= 0x10000
        this.LastMouseX := x
        this.LastMouseY := y
        this.LastMousePointTick := A_TickCount
        packet := {
            Kind: "mouse",
            Message: Integer(payload) & 0xFFFF,
            MouseData: data,
            Flags: (Integer(payload) >> 32) & 0xFF,
            X: x,
            Y: y
        }
        try this.EventSink.Call(packet)
        return 0
    }

    static KeyboardMessageId() {
        static messageId := 0
        if !messageId
            messageId := DllCall("user32\RegisterWindowMessageW", "WStr",
                CaptureInputGuardProcess.KeyboardMessageName, "UInt")
        if !messageId
            throw OSError(A_LastError, "无法注册录制键盘回传消息。")
        return messageId
    }

    static MouseMessageId() {
        static messageId := 0
        if !messageId
            messageId := DllCall("user32\RegisterWindowMessageW", "WStr",
                CaptureInputGuardProcess.MouseMessageName, "UInt")
        if !messageId
            throw OSError(A_LastError, "无法注册录制鼠标回传消息。")
        return messageId
    }

    static WorkerScriptPath() {
        return A_ScriptDir "\src\Input\CaptureInputGuardWorker.ahk"
    }

    CreateEvent(name) {
        handle := DllCall("kernel32\CreateEventW", "Ptr", 0, "Int", true,
            "Int", false, "WStr", name, "Ptr")
        if !handle
            throw OSError(A_LastError, "无法创建录制输入守卫控制信号。")
        return handle
    }

    CloseHandle(propertyName, errors) {
        handle := this.%propertyName%
        if !handle
            return true
        if !DllCall("kernel32\CloseHandle", "Ptr", handle, "Int") {
            errors.Push("无法关闭录制输入守卫资源：" propertyName)
            return false
        }
        this.%propertyName% := 0
        return true
    }

    Quote(value) {
        return Chr(34) StrReplace(String(value), Chr(34), Chr(92) Chr(34))
            . Chr(34)
    }

    Join(values, separator) {
        result := ""
        for index, value in values
            result .= (index == 1 ? "" : separator) value
        return result
    }
}

class CaptureInputGuardMessagePublisher {
    __New(targetWindow) {
        this.TargetWindow := Integer(targetWindow)
    }

    PublishKeyboard(message, eventData) {
        virtualKey := NumGet(eventData, 0, "UInt") & 0xFFFF
        scanCode := NumGet(eventData, 4, "UInt") & 0xFFFF
        flags := NumGet(eventData, 8, "UInt") & 0xFF
        payload := virtualKey | (scanCode << 16) | (flags << 32)
        return this.Post(CaptureInputGuardProcess.KeyboardMessageId(),
            Integer(message) & 0xFFFF, payload)
    }

    PublishMouse(message, eventData) {
        x := NumGet(eventData, 0, "Int")
        y := NumGet(eventData, 4, "Int")
        mouseDataHigh := (NumGet(eventData, 8, "UInt") >> 16) & 0xFFFF
        flags := NumGet(eventData, 12, "UInt") & 0xFF
        payload := (Integer(message) & 0xFFFF) | (mouseDataHigh << 16)
            | (flags << 32)
        pointPayload := (x & 0xFFFF) | ((y & 0xFFFF) << 16)
        return this.Post(CaptureInputGuardProcess.MouseMessageId(), payload,
            pointPayload)
    }

    Post(messageId, wParam, lParam) {
        return DllCall("user32\PostMessageW", "Ptr", this.TargetWindow,
            "UInt", messageId, "UPtr", wParam, "Ptr", lParam, "Int")
    }
}

class CaptureInputGuardWorker {
    static TryRun(arguments) {
        if arguments.Length < 1
                || String(arguments[1])
                    != CaptureInputGuardProcess.WorkerFlag
            return false
        if arguments.Length != 4
            throw Error("录制输入守卫进程参数无效。")
        stopHandle := 0
        readyHandle := 0
        workerGuard := ""
        try {
            stopHandle := DllCall("kernel32\OpenEventW", "UInt",
                0x00100000, "Int", false, "WStr", arguments[2], "Ptr")
            readyHandle := DllCall("kernel32\OpenEventW", "UInt", 0x0002,
                "Int", false, "WStr", arguments[3], "Ptr")
            if !stopHandle || !readyHandle
                throw OSError(A_LastError,
                    "无法连接录制输入守卫控制信号。")
            targetWindow := Integer(arguments[4])
            if targetWindow && !DllCall("user32\IsWindow", "Ptr",
                    targetWindow, "Int")
                throw Error("录制输入回传窗口无效。")
            publisher := targetWindow
                ? CaptureInputGuardMessagePublisher(targetWindow) : ""
            workerGuard := CaptureInputGuard("", publisher)
            workerGuard.Start()
            if !DllCall("kernel32\SetEvent", "Ptr", readyHandle, "Int")
                throw OSError(A_LastError,
                    "无法确认录制输入守卫已就绪。")
            loop {
                waitResult := DllCall("kernel32\WaitForSingleObject", "Ptr",
                    stopHandle, "UInt", 0, "UInt")
                if waitResult == 0
                    break
                if waitResult != 0x00000102
                    throw OSError(A_LastError,
                        "无法读取录制输入守卫停止信号。")
                ; Sleep pumps the worker's message queue so low-level hook
                ; callbacks remain responsive regardless of GUI/runtime work.
                Sleep(5)
            }
            return true
        } finally {
            if IsObject(workerGuard)
                try workerGuard.Stop()
            if readyHandle
                DllCall("kernel32\CloseHandle", "Ptr", readyHandle)
            if stopHandle
                DllCall("kernel32\CloseHandle", "Ptr", stopHandle)
        }
    }
}
