; Interception 动态库适配层。
; 所有会拦截输入的会话都由这里集中仲裁，避免多个 context 竞争 stroke。

class InterceptionService {
    static MaximumKeyboard := 10
    static MaximumMouse := 10
    static MaximumDevice := 20
    static HardwareIdBufferSize := 4096
    static IdentifyStrokeBufferSize := 24
    static AllFilter := 0xFFFF
    static MouseButtonAndWheelFilter := 0x0FFF

    __New() {
        this.LibraryHandle := 0
        this.LibraryPath := ""
        this.Context := 0
        this.Functions := Map()
        this.Status := Map(
            "available", false,
            "library_loaded", false,
            "driver_available", false,
            "architecture", "x64",
            "library_path", "",
            "code", "not_loaded",
            "pending_operation", "",
            "message", "尚未加载 Interception。")
        this.IdentifyContext := 0
        this.IdentifyPredicateCallback := 0
        this.IdentifyPredicateTarget := ""
        this.ConsumerContext := 0
        this.ConsumerMode := ""
        this.ConsumerDevices := Map()
        this.ConsumerPredicateCallbacks := []
        this.Disposed := false
    }

    GetInstallerPath() {
        candidates := []
        try candidates.Push(GetApplicationRootFilePath(
            "third_party\interception\command-line-installer\install-interception.exe"))
        catch
            candidates.Push(A_ScriptDir
                "\third_party\interception\command-line-installer\install-interception.exe")
        for candidate in candidates
            if FileExist(candidate)
                return GetCanonicalPath(candidate)
        return ""
    }

    CanInstallDriver() => this.GetInstallerPath() != ""

    BuildInstallCommand(installerPath := "") {
        if installerPath == ""
            installerPath := this.GetInstallerPath()
        if installerPath == ""
            throw Error("未找到 Interception 驱动安装器。")
        return '"' String(installerPath) '" /install'
    }

    BuildUninstallCommand(installerPath := "") {
        if installerPath == ""
            installerPath := this.GetInstallerPath()
        if installerPath == ""
            throw Error("未找到 Interception 驱动安装器。")
        return '"' String(installerPath) '" /uninstall'
    }

    InstallDriver() {
        installerPath := this.GetInstallerPath()
        if installerPath == ""
            throw Error("未找到 Interception 驱动安装器。")
        exitCode := this.ExecuteInstaller(this.BuildInstallCommand(
            installerPath), this.GetInstallerWorkingDirectory(installerPath))
        if exitCode != 0
            throw Error("Interception 驱动安装器返回错误代码 " exitCode "。")
        this.Status["available"] := false
        this.Status["driver_available"] := false
        this.Status["code"] := "restart_required"
        this.Status["pending_operation"] := "install"
        this.Status["message"] := "Interception 驱动已安装；重启 Windows 后生效。"
        return Map("installed", true, "restart_required", true,
            "exit_code", exitCode, "installer_path", installerPath)
    }

    UninstallDriver() {
        installerPath := this.GetInstallerPath()
        if installerPath == ""
            throw Error("未找到 Interception 驱动安装器。")
        exitCode := this.ExecuteInstaller(this.BuildUninstallCommand(
            installerPath), this.GetInstallerWorkingDirectory(installerPath))
        if exitCode != 0
            throw Error("Interception 驱动卸载程序返回错误代码 " exitCode "。")
        this.Status["available"] := false
        this.Status["driver_available"] := false
        this.Status["code"] := "restart_required"
        this.Status["pending_operation"] := "uninstall"
        this.Status["message"] := "Interception 驱动已卸载；重启 Windows 后生效。"
        return Map("uninstalled", true, "restart_required", true,
            "exit_code", exitCode, "installer_path", installerPath)
    }

    ExecuteInstaller(commandLine, workingDirectory) {
        return RunWait("*RunAs " commandLine, workingDirectory, "Hide")
    }

    GetInstallerWorkingDirectory(installerPath) {
        SplitPath(installerPath, , &directory)
        return directory
    }

    GetStatus() {
        if this.Disposed
            return this.Status.Clone()
        try this.EnsureReady()
        catch as caughtError {
            currentStatus := this.Status.Clone()
            if currentStatus.Get("code", "") == "not_loaded"
                currentStatus["message"] := caughtError.Message
            return currentStatus
        }
        return this.Status.Clone()
    }

    EnumerateDevices() {
        if this.Disposed
            return []
        try this.EnsureReady()
        catch
            return this.BuildUnavailableDevices()
        deviceList := []
        Loop InterceptionService.MaximumDevice {
            deviceNumber := A_Index
            isKeyboard := this.Call("is_keyboard", "Int", deviceNumber) != 0
            isMouse := this.Call("is_mouse", "Int", deviceNumber) != 0
            if !isKeyboard && !isMouse
                continue
            invalid := this.Call("is_invalid", "Int", deviceNumber) != 0
            hardwareId := ""
            if !invalid
                hardwareId := this.ReadHardwareId(deviceNumber)
            typeName := isKeyboard ? "keyboard" : "mouse"
            deviceList.Push(Map(
                "number", deviceNumber,
                "official_index", typeName == "keyboard"
                    ? deviceNumber - 1 : deviceNumber - 11,
                "type", typeName,
                "kind", typeName,
                "hardware_id", hardwareId,
                "is_valid", !invalid,
                "filter", this.ReadFilter(deviceNumber),
                "precedence", this.ReadPrecedence(deviceNumber),
                "display_name", (typeName == "keyboard" ? "Keyboard "
                    : "Mouse ") (typeName == "keyboard" ? deviceNumber
                    : deviceNumber - 10)))
        }
        return deviceList
    }

    BuildUnavailableDevices() {
        deviceList := []
        Loop InterceptionService.MaximumKeyboard {
            deviceList.Push(Map("number", A_Index,
                "official_index", A_Index - 1, "type", "keyboard",
                "kind", "keyboard", "hardware_id", "",
                "is_valid", false, "filter", 0, "precedence", 0,
                "display_name", "Keyboard " A_Index))
        }
        Loop InterceptionService.MaximumMouse {
            deviceNumber := InterceptionService.MaximumKeyboard + A_Index
            deviceList.Push(Map("number", deviceNumber,
                "official_index", A_Index - 1, "type", "mouse",
                "kind", "mouse", "hardware_id", "",
                "is_valid", false, "filter", 0, "precedence", 0,
                "display_name", "Mouse " A_Index))
        }
        return deviceList
    }

    StartIdentify() {
        if this.Disposed
            throw Error("Interception 服务已经释放。")
        if this.IdentifyContext
            return true
        this.AssertConsumerAvailable("identify")
        this.EnsureReady()
        context := this.Call("create_context", "Ptr")
        if !context
            throw Error("无法创建 Interception 识别上下文。")
        predicate := 0
        try {
            this.IdentifyPredicateTarget := this
            predicate := CallbackCreate(ObjBindMethod(this,
                "IdentifyPredicate"), "Fast", 1)
            this.Call("set_filter", "Ptr", context, "Ptr", predicate,
                "UShort", InterceptionService.AllFilter)
        } catch as caughtError {
            if predicate
                try CallbackFree(predicate)
            this.IdentifyPredicateTarget := ""
            this.Call("destroy_context", "Ptr", context)
            throw caughtError
        }
        this.IdentifyContext := context
        this.IdentifyPredicateCallback := predicate
        this.ConsumerMode := "identify"
        return true
    }

    IdentifyPredicate(device) {
        return (device >= 1 && device <= InterceptionService.MaximumDevice)
            ? 1 : 0
    }

    PollIdentify(timeoutMs := 1) {
        if !this.IdentifyContext
            return ""
        timeoutMs := Max(0, Min(100, Integer(timeoutMs)))
        device := this.Call("wait_with_timeout", "Ptr",
            this.IdentifyContext, "UInt", timeoutMs, "Int")
        if !device
            return ""
        stroke := Buffer(InterceptionService.IdentifyStrokeBufferSize, 0)
        received := this.Call("receive", "Ptr", this.IdentifyContext,
            "Int", device, "Ptr", stroke, "UInt", 1, "Int")
        if received > 0 {
            sent := this.Call("send", "Ptr", this.IdentifyContext,
                "Int", device, "Ptr", stroke, "UInt", received, "Int")
            if sent != received
                throw Error("Interception 无法完整回送识别到的输入。")
        }
        typeName := this.Call("is_keyboard", "Int", device) != 0
            ? "keyboard" : (this.Call("is_mouse", "Int", device) != 0
                ? "mouse" : "unknown")
        return Map("number", device,
            "official_index", typeName == "keyboard" ? device - 1
                : (typeName == "mouse" ? device - 11 : -1),
            "type", typeName, "received", received > 0)
    }

    StopIdentify() {
        if this.IdentifyPredicateCallback {
            try CallbackFree(this.IdentifyPredicateCallback)
            this.IdentifyPredicateCallback := 0
        }
        this.IdentifyPredicateTarget := ""
        if this.IdentifyContext {
            try this.Call("destroy_context", "Ptr", this.IdentifyContext)
            this.IdentifyContext := 0
        }
        if this.ConsumerMode == "identify"
            this.ConsumerMode := ""
        return true
    }

    StartCapture() => this.StartConsumer("capture", [])

    PollCapture(timeoutMs := 1) {
        if this.ConsumerMode != "capture"
            return ""
        stroke := this.PollConsumerStroke(timeoutMs)
        if !IsObject(stroke)
            return ""
        stroke["hardware_id"] := this.ReadHardwareId(stroke["device"])
        return stroke
    }

    StopCapture() => this.StopConsumer("capture")

    StartRuntime(deviceNumbers) => this.StartConsumer("runtime",
        deviceNumbers)

    PollRuntime(timeoutMs := 0) {
        return this.ConsumerMode == "runtime"
            ? this.PollConsumerStroke(timeoutMs) : ""
    }

    SendRuntimeStroke(stroke) {
        if this.ConsumerMode != "runtime" || !IsObject(stroke)
            return false
        return this.SendConsumerStroke(stroke)
    }

    StopRuntime() => this.StopConsumer("runtime")

    StartConsumer(mode, deviceNumbers) {
        if this.Disposed
            throw Error("Interception 服务已经释放。")
        if this.ConsumerContext && this.ConsumerMode == mode
            return true
        this.AssertConsumerAvailable(mode)
        this.EnsureReady()
        devices := Map()
        if Type(deviceNumbers) == "Array"
            for deviceNumber in deviceNumbers {
                deviceNumber := Integer(deviceNumber)
                if deviceNumber < 1
                        || deviceNumber > InterceptionService.MaximumDevice
                    throw ValueError("Interception 设备编号必须在 1 到 20 之间。")
                devices[deviceNumber] := true
            }
        context := this.Call("create_context", "Ptr")
        if !context
            throw Error("无法创建 Interception " mode " 上下文。")
        callbacks := []
        try {
            this.ConsumerDevices := devices
            keyboardCallback := CallbackCreate(ObjBindMethod(this,
                "ConsumerKeyboardPredicate"), "Fast", 1)
            callbacks.Push(keyboardCallback)
            mouseCallback := CallbackCreate(ObjBindMethod(this,
                "ConsumerMousePredicate"), "Fast", 1)
            callbacks.Push(mouseCallback)
            this.Call("set_filter", "Ptr", context, "Ptr", keyboardCallback,
                "UShort", InterceptionService.AllFilter)
            this.Call("set_filter", "Ptr", context, "Ptr", mouseCallback,
                "UShort", InterceptionService.MouseButtonAndWheelFilter)
        } catch as caughtError {
            for callback in callbacks
                try CallbackFree(callback)
            this.ConsumerDevices := Map()
            this.Call("destroy_context", "Ptr", context)
            throw caughtError
        }
        this.ConsumerContext := context
        this.ConsumerPredicateCallbacks := callbacks
        this.ConsumerMode := mode
        return true
    }

    AssertConsumerAvailable(requestedMode) {
        if this.ConsumerMode != "" && this.ConsumerMode != requestedMode
            throw Error("Interception 正在用于" this.ConsumerMode
                "；请先结束当前会话。")
        return true
    }

    ConsumerKeyboardPredicate(device) {
        if device < 1 || device > InterceptionService.MaximumKeyboard
            return 0
        return !this.ConsumerDevices.Count || this.ConsumerDevices.Has(device)
            ? 1 : 0
    }

    ConsumerMousePredicate(device) {
        if device <= InterceptionService.MaximumKeyboard
                || device > InterceptionService.MaximumDevice
            return 0
        return !this.ConsumerDevices.Count || this.ConsumerDevices.Has(device)
            ? 1 : 0
    }

    PollConsumerStroke(timeoutMs := 0) {
        if !this.ConsumerContext
            return ""
        timeoutMs := Max(0, Min(100, Integer(timeoutMs)))
        device := this.Call("wait_with_timeout", "Ptr", this.ConsumerContext,
            "UInt", timeoutMs, "Int")
        if !device
            return ""
        strokeBuffer := Buffer(InterceptionService.IdentifyStrokeBufferSize, 0)
        received := this.Call("receive", "Ptr", this.ConsumerContext,
            "Int", device, "Ptr", strokeBuffer, "UInt", 1, "Int")
        if received <= 0
            return ""
        typeName := device <= InterceptionService.MaximumKeyboard
            ? "keyboard" : "mouse"
        stroke := Map("device", device, "type", typeName,
            "buffer", strokeBuffer, "received", received)
        if typeName == "keyboard" {
            stroke["code"] := NumGet(strokeBuffer, 0, "UShort")
            stroke["state"] := NumGet(strokeBuffer, 2, "UShort")
            stroke["information"] := NumGet(strokeBuffer, 4, "UInt")
        } else {
            stroke["state"] := NumGet(strokeBuffer, 0, "UShort")
            stroke["flags"] := NumGet(strokeBuffer, 2, "UShort")
            stroke["rolling"] := NumGet(strokeBuffer, 4, "Short")
            stroke["x"] := NumGet(strokeBuffer, 8, "Int")
            stroke["y"] := NumGet(strokeBuffer, 12, "Int")
            stroke["information"] := NumGet(strokeBuffer, 16, "UInt")
        }
        return stroke
    }

    SendConsumerStroke(stroke) {
        if !this.ConsumerContext || !stroke.Has("buffer")
            return false
        sent := this.Call("send", "Ptr", this.ConsumerContext, "Int",
            stroke["device"], "Ptr", stroke["buffer"], "UInt",
            stroke.Get("received", 1), "Int")
        if sent != stroke.Get("received", 1)
            throw Error("Interception 无法完整回送输入 stroke。")
        return true
    }

    StopConsumer(expectedMode := "") {
        if expectedMode != "" && this.ConsumerMode != expectedMode
            return false
        for callback in this.ConsumerPredicateCallbacks
            try CallbackFree(callback)
        this.ConsumerPredicateCallbacks := []
        this.ConsumerDevices := Map()
        if this.ConsumerContext {
            try this.Call("destroy_context", "Ptr", this.ConsumerContext)
            this.ConsumerContext := 0
        }
        if this.ConsumerMode != "identify"
            this.ConsumerMode := ""
        return true
    }

    EnsureReady() {
        if this.Status.Get("code", "") == "restart_required"
            throw Error(this.Status.Get("message",
                "Interception 驱动已安装；重启 Windows 后生效。"))
        if this.Context
            return true
        this.EnsureLibrary()
        context := this.Call("create_context", "Ptr")
        if !context {
            driverRegistered := this.HasInstalledDriverRegistration()
            this.Status["code"] := driverRegistered
                ? "restart_required" : "driver_unavailable"
            this.Status["driver_available"] := false
            this.Status["message"] := driverRegistered
                ? "Interception 驱动已注册但尚不可用；请重启 Windows。若重启后仍失败，请检查驱动安装状态。"
                : "无法创建 Interception 上下文；请确认驱动已安装。"
            throw Error(this.Status["message"])
        }
        this.Context := context
        this.Status["available"] := true
        this.Status["driver_available"] := true
        this.Status["code"] := "ready"
        this.Status["message"] := "Interception 驱动和 DLL 已就绪。"
        return true
    }

    HasInstalledDriverRegistration() {
        services := "HKLM\SYSTEM\CurrentControlSet\Services\"
        for name in ["keyboard", "mouse"] {
            try driverType := RegRead(services name, "Type")
            catch
                return false
            if driverType != 1
                    || !FileExist(A_WinDir "\System32\drivers\" name ".sys")
                return false
        }
        return this.HasUpperFilter("{4D36E96B-E325-11CE-BFC1-08002BE10318}",
                "keyboard")
            && this.HasUpperFilter(
                "{4D36E96F-E325-11CE-BFC1-08002BE10318}", "mouse")
    }

    HasUpperFilter(classGuid, serviceName) {
        try filters := RegRead("HKLM\SYSTEM\CurrentControlSet"
            "\Control\Class\" classGuid, "UpperFilters")
        catch
            return false
        for filter in StrSplit(String(filters), "`n", "`r")
            if StrLower(Trim(filter, " `t`r`n")) == serviceName
                return true
        return false
    }

    EnsureLibrary() {
        if this.LibraryHandle
            return true
        path := this.ResolveLibraryPath()
        if path == "" {
            this.Status["code"] := "dll_missing"
            this.Status["message"] :=
                "未找到 x64 interception.dll；可设置 KMRA_INTERCEPTION_DLL。"
            throw Error(this.Status["message"])
        }
        handle := DllCall("kernel32\LoadLibraryW", "Str", path, "Ptr")
        if !handle {
            this.Status["code"] := "dll_load_failed"
            this.Status["message"] := "无法加载 interception.dll（Win32 "
                A_LastError "）。"
            throw OSError(A_LastError, this.Status["message"])
        }
        functionNames := [
            "create_context", "destroy_context", "get_filter",
            "get_hardware_id", "get_precedence", "is_invalid",
            "is_keyboard", "is_mouse", "receive", "send",
            "set_filter", "set_precedence", "wait", "wait_with_timeout"]
        try {
            for name in functionNames {
                address := DllCall("kernel32\GetProcAddress", "Ptr", handle,
                    "AStr", "interception_" name, "Ptr")
                if !address
                    throw Error("interception.dll 缺少函数：interception_" name)
                this.Functions[name] := address
            }
        } catch as caughtError {
            DllCall("kernel32\FreeLibrary", "Ptr", handle, "Int")
            throw caughtError
        }
        this.LibraryHandle := handle
        this.LibraryPath := path
        this.Status["library_loaded"] := true
        this.Status["library_path"] := path
        return true
    }

    ResolveLibraryPath() {
        candidates := []
        try envPath := Trim(EnvGet("KMRA_INTERCEPTION_DLL"))
        catch
            envPath := ""
        if envPath != ""
            candidates.Push(envPath)
        sharedPath := A_AppData "\KeyMouseRemapperAssistant\interception\interception.dll"
        try this.PrepareSharedLibrary(sharedPath)
        candidates.Push(sharedPath)
        candidates.Push(this.GetBundledLibraryPath())
        for candidate in candidates {
            if FileExist(candidate)
                return GetCanonicalPath(candidate)
        }
        return ""
    }

    GetBundledLibraryPath() {
        try return GetApplicationRootFilePath(
            "third_party\interception\library\x64\interception.dll")
        catch
            return A_ScriptDir "\third_party\interception\library\x64\interception.dll"
    }

    PrepareSharedLibrary(destinationPath) {
        if FileExist(destinationPath)
            return destinationPath
        sourcePath := this.GetBundledLibraryPath()
        if !FileExist(sourcePath)
            return ""
        SplitPath(destinationPath, , &destinationDirectory)
        try {
            DirCreate(destinationDirectory)
            FileCopy(sourcePath, destinationPath, false)
            return FileExist(destinationPath) ? destinationPath : ""
        } catch
            return ""
    }

    ReadHardwareId(device) {
        hardwareIdBuffer := Buffer(InterceptionService.HardwareIdBufferSize, 0)
        length := this.Call("get_hardware_id", "Ptr", this.Context,
            "Int", device, "Ptr", hardwareIdBuffer, "UInt",
            hardwareIdBuffer.Size, "UInt")
        if !length
            return ""
        try return StrGet(hardwareIdBuffer, "UTF-16")
        catch
            return ""
    }

    ReadFilter(device) {
        try return this.Call("get_filter", "Ptr", this.Context,
            "Int", device, "UShort")
        catch
            return 0
    }

    ReadPrecedence(device) {
        try return this.Call("get_precedence", "Ptr", this.Context,
            "Int", device, "Int")
        catch
            return 0
    }

    Call(name, types*) {
        if !this.Functions.Has(name)
            throw Error("Interception 函数未加载：" name)
        return DllCall(this.Functions[name], types*)
    }

    Shutdown() {
        if this.Disposed
            return true
        this.Disposed := true
        try this.StopIdentify()
        try this.StopConsumer()
        if this.Context {
            try this.Call("destroy_context", "Ptr", this.Context)
            this.Context := 0
        }
        if this.LibraryHandle {
            try DllCall("kernel32\FreeLibrary", "Ptr", this.LibraryHandle,
                "Int")
            this.LibraryHandle := 0
        }
        this.Functions.Clear()
        return true
    }
}
