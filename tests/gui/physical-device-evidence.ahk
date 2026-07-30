#Requires AutoHotkey v2.0.26 64-bit
#SingleInstance Off
#Warn All, StdOut

#Include ..\..\src\Core\JsonCodec.ahk
#Include ..\..\src\Core\Sha256.ahk
#Include ..\..\src\Core\RuleSpec.ahk
#Include ..\..\src\Core\DeviceIdentityService.ahk
#Include ..\..\src\Core\InputEvent.ahk
#Include ..\..\src\Platform\Win32.ahk
#Include ..\..\src\Input\RawInputService.ahk
#Include ..\PhysicalDeviceEvidenceModel.ahk

class PhysicalDeviceEvidenceSession {
    __New(options) {
        this.Options := options
        this.Stats := Map()
        this.DeviceOrder := []
        this.RowByDevice := Map()
        this.Errors := []
        this.Lifecycle := Map("arrival", 0, "removal", 0, "rebound", 0)
        this.Cancelled := false
        this.StartTick := 0
        this.EndTick := 0
        this.LastRefreshTick := 0
        this.Window := Gui("+Resize +MinSize880x460",
            "键鼠重映射小助手 - 真实设备验证")
        this.Window.SetFont("s10", "Microsoft YaHei UI")
        this.Window.OnEvent("Close", ObjBindMethod(this, "Cancel"))
        this.Window.OnEvent("Escape", ObjBindMethod(this, "Cancel"))
        this.Instruction := this.Window.Add("Text", "x14 y12 w852 h44",
            "请在倒计时内分别操作每一套物理键盘和鼠标。"
            . "需要热插拔证据时，再拔出并重新接入其中一套设备。")
        this.DeviceList := this.Window.Add("ListView",
            "x14 y64 w852 h320 Grid -Multi", [
                "类型", "VID:PID", "稳定设备 ID", "事件", "按下", "释放",
                "移动", "滚轮", "拔插"])
        this.DeviceList.ModifyCol(1, 76)
        this.DeviceList.ModifyCol(2, 86)
        this.DeviceList.ModifyCol(3, 270)
        Loop 6
            this.DeviceList.ModifyCol(A_Index + 3, 62)
        this.StatusText := this.Window.Add("Text", "x14 y398 w852 h24", "准备中")
        this.Observer := RawInputService(this.Window.Hwnd,
            ObjBindMethod(this, "OnInputEvent"))
    }

    Run() {
        exitCode := 1
        try {
            this.Observer.Start()
            this.InitializeDevices(this.Observer.GetDevices())
            this.ResetObservationCounters()
            if this.Options.ListOnly {
                this.StartTick := A_TickCount
                this.EndTick := this.StartTick
                this.WriteEvidence("listed")
                exitCode := 0
            } else {
                this.Window.Show("w880 h460")
                this.StartTick := A_TickCount
                deadline := this.StartTick + this.Options.DurationSeconds * 1000
                while !this.Cancelled && A_TickCount < deadline {
                    if A_TickCount - this.LastRefreshTick >= 200
                        this.RefreshWindow(deadline)
                    Sleep(25)
                }
                this.EndTick := A_TickCount
                heldCount := this.Observer.HeldKeys.Count
                result := this.Evaluate(heldCount)
                this.WriteEvidence(this.Cancelled ? "cancelled"
                    : (result.Passed ? "passed" : "failed"), result)
                exitCode := this.Cancelled ? 2 : (result.Passed ? 0 : 3)
            }
        } catch as evidenceError {
            this.Errors.Push(Map("event", "session_failed",
                "detail", evidenceError.Message))
            if !this.StartTick
                this.StartTick := A_TickCount
            this.EndTick := A_TickCount
            try this.WriteEvidence("error")
            FileAppend(evidenceError.Message "`n" evidenceError.Stack, "**")
            exitCode := 1
        } finally {
            try this.Observer.Stop()
            try this.Window.Destroy()
        }
        return exitCode
    }

    InitializeDevices(devices) {
        for device in devices
            this.EnsureDevice(device)
    }

    ResetObservationCounters() {
        this.Lifecycle := Map("arrival", 0, "removal", 0, "rebound", 0)
        for deviceId in this.DeviceOrder {
            stats := this.Stats[deviceId]
            stats["events"] := 0
            stats["phases"] := Map("down", 0, "up", 0, "move", 0,
                "wheel", 0, "arrival", 0, "removal", 0)
            stats["names"] := Map()
            stats["lifecycle"] := Map(
                "arrival", 0, "removal", 0, "rebound", 0)
        }
    }

    EnsureDevice(device) {
        if Type(device) != "Map"
            return ""
        deviceId := device.Has("id") ? String(device["id"]) : ""
        if deviceId == ""
            return ""
        if this.Stats.Has(deviceId) {
            this.Stats[deviceId]["device"] := this.SanitizeDevice(device)
            return this.Stats[deviceId]
        }
        stats := Map(
            "device", this.SanitizeDevice(device),
            "events", 0,
            "phases", Map("down", 0, "up", 0, "move", 0,
                "wheel", 0, "arrival", 0, "removal", 0),
            "names", Map(),
            "lifecycle", Map("arrival", 0, "removal", 0, "rebound", 0))
        this.Stats[deviceId] := stats
        this.DeviceOrder.Push(deviceId)
        row := this.DeviceList.Add("", this.DeviceField(device, "type", "unknown"),
            this.DeviceVidPid(device), deviceId, 0, 0, 0, 0, 0, 0)
        this.RowByDevice[deviceId] := row
        return stats
    }

    OnInputEvent(event) {
        Critical()
        try {
            if Type(event) != "Map" || !event.Has("identity")
                return
            identity := event["identity"]
            metadata := event.Has("metadata") ? event["metadata"] : Map()
            device := metadata.Has("device") ? metadata["device"] : ""
            deviceId := identity.Has("device_id")
                ? String(identity["device_id"]) : ""
            if deviceId == "" && Type(device) == "Map" && device.Has("id")
                deviceId := String(device["id"])
            if deviceId == ""
                return
            if !this.Stats.Has(deviceId) {
                if Type(device) != "Map"
                    device := Map("id", deviceId, "stable_id", deviceId,
                        "type", identity.Has("kind") ? identity["kind"] : "unknown",
                        "display_name", identity.Has("name")
                            ? identity["name"] : "Input device")
                this.EnsureDevice(device)
            } else if Type(device) == "Map"
                this.EnsureDevice(device)
            stats := this.Stats[deviceId]
            phase := event.Has("phase") ? String(event["phase"]) : ""
            stats["events"] += 1
            if stats["phases"].Has(phase)
                stats["phases"][phase] += 1
            name := identity.Has("name") ? String(identity["name"]) : ""
            if name != ""
                stats["names"][name] := stats["names"].Get(name, 0) + 1
            if metadata.Has("lifecycle") {
                lifecycle := String(metadata["lifecycle"])
                if stats["lifecycle"].Has(lifecycle) {
                    stats["lifecycle"][lifecycle] += 1
                    this.Lifecycle[lifecycle] += 1
                }
            }
            if event.Has("origin") && event["origin"] == "raw-input-service"
                    && metadata.Has("service_event") {
                this.Errors.Push(Map("event", String(metadata["service_event"]),
                    "detail", metadata.Has("detail")
                        ? String(metadata["detail"]) : ""))
            }
        } catch as callbackError {
            this.Errors.Push(Map("event", "collector_callback_failed",
                "detail", callbackError.Message))
        }
    }

    RefreshWindow(deadline) {
        this.LastRefreshTick := A_TickCount
        for deviceId in this.DeviceOrder {
            if !this.RowByDevice.Has(deviceId)
                continue
            stats := this.Stats[deviceId]
            phases := stats["phases"]
            lifecycleCount := stats["lifecycle"]["arrival"]
                + stats["lifecycle"]["removal"]
                + stats["lifecycle"]["rebound"]
            this.DeviceList.Modify(this.RowByDevice[deviceId], "",
                this.DeviceField(stats["device"], "type", "unknown"),
                this.DeviceVidPid(stats["device"]), deviceId,
                stats["events"], phases["down"], phases["up"],
                phases["move"], phases["wheel"], lifecycleCount)
        }
        remaining := Max(0, Ceil((deadline - A_TickCount) / 1000))
        counts := this.CountActiveDevices()
        this.StatusText.Text := Format(
            "剩余 {1} 秒 · 活跃键盘 {2}/{3} · 活跃鼠标 {4}/{5}"
                . " · 拔出 {6} · 接入/重绑 {7}",
            remaining, counts.Keyboards, this.Options.MinimumKeyboards,
            counts.Mice, this.Options.MinimumMice,
            this.Lifecycle["removal"],
            this.Lifecycle["arrival"] + this.Lifecycle["rebound"])
    }

    Evaluate(heldCount) {
        counts := this.CountActiveDevices()
        hotplugPassed := !this.Options.RequireHotplug
            || PhysicalDeviceEvidenceModel.HasCompletedHotplugCycle(
                this.Stats, this.DeviceOrder)
        compositePairs := this.CountCompositePairs()
        passed := counts.Keyboards >= this.Options.MinimumKeyboards
            && counts.Mice >= this.Options.MinimumMice
            && heldCount == 0 && this.Errors.Length == 0 && hotplugPassed
        return {
            Passed: passed,
            ActiveKeyboards: counts.Keyboards,
            ActiveMice: counts.Mice,
            HeldKeys: heldCount,
            CompositePairs: compositePairs,
            HotplugPassed: hotplugPassed
        }
    }

    CountActiveDevices() {
        keyboards := 0, mice := 0
        for deviceId in this.DeviceOrder {
            stats := this.Stats[deviceId]
            typeName := this.DeviceField(stats["device"], "type", "unknown")
            phases := stats["phases"]
            if typeName == "keyboard" && phases["down"] > 0
                    && phases["up"] > 0
                keyboards++
            if typeName == "mouse" && (phases["move"] > 0
                    || phases["wheel"] > 0
                    || (phases["down"] > 0 && phases["up"] > 0))
                mice++
        }
        return {Keyboards: keyboards, Mice: mice}
    }

    CountCompositePairs() {
        pairs := Map()
        for deviceId in this.DeviceOrder {
            device := this.Stats[deviceId]["device"]
            vendor := this.DeviceField(device, "vendor_id")
            product := this.DeviceField(device, "product_id")
            if vendor == "" || product == ""
                continue
            pairId := vendor ":" product
            if !pairs.Has(pairId)
                pairs[pairId] := Map("keyboard", false, "mouse", false)
            typeName := this.DeviceField(device, "type")
            if pairs[pairId].Has(typeName)
                pairs[pairId][typeName] := true
        }
        count := 0
        for , pair in pairs {
            if pair["keyboard"] && pair["mouse"]
                count++
        }
        return count
    }

    BuildEvidence(status, evaluation := "") {
        passed := status == "passed" && IsObject(evaluation)
            && evaluation.Passed
        deviceReports := []
        for deviceId in this.DeviceOrder {
            stats := this.Stats[deviceId]
            names := []
            for name, count in stats["names"]
                names.Push(Map("name", name, "count", count))
            deviceReports.Push(Map(
                "device", RuleSpec.Clone(stats["device"]),
                "events", stats["events"],
                "phases", RuleSpec.Clone(stats["phases"]),
                "names", names,
                "lifecycle", RuleSpec.Clone(stats["lifecycle"])))
        }
        summary := Map(
            "enumerated_devices", this.DeviceOrder.Length,
            "active_keyboards", IsObject(evaluation)
                ? evaluation.ActiveKeyboards : 0,
            "active_mice", IsObject(evaluation) ? evaluation.ActiveMice : 0,
            "held_keys_at_finish", IsObject(evaluation)
                ? evaluation.HeldKeys : 0,
            "composite_pairs", IsObject(evaluation)
                ? evaluation.CompositePairs : this.CountCompositePairs(),
            "hotplug_passed", JsonBoolean(IsObject(evaluation)
                ? evaluation.HotplugPassed : !this.Options.RequireHotplug),
            "error_count", this.Errors.Length)
        return Map(
            "schema", 1,
            "status", status,
            "passed", JsonBoolean(passed),
            "acceptance_eligible", JsonBoolean(passed),
            "created_utc", FormatTime(A_NowUTC, "yyyy-MM-ddTHH:mm:ssZ"),
            "runtime", Map("autohotkey", A_AhkVersion,
                "architecture", A_PtrSize == 8 ? "x64" : "x86",
                "executable_sha256", this.Options.RuntimeSha256),
            "collector", Map(
                "script_sha256", this.Options.CollectorSha256,
                "process_id", DllCall("kernel32\GetCurrentProcessId", "UInt"),
                "list_only", JsonBoolean(this.Options.ListOnly)),
            "duration_ms", Max(0, this.EndTick - this.StartTick),
            "requirements", Map(
                "minimum_keyboards", this.Options.MinimumKeyboards,
                "minimum_mice", this.Options.MinimumMice,
                "require_hotplug", JsonBoolean(this.Options.RequireHotplug)),
            "summary", summary,
            "lifecycle", RuleSpec.Clone(this.Lifecycle),
            "devices", deviceReports,
            "errors", RuleSpec.Clone(this.Errors))
    }

    WriteEvidence(status, evaluation := "") {
        evidence := this.BuildEvidence(status, evaluation)
        directory := this.Options.OutputDirectory
        DirCreate(directory)
        temporary := this.Options.OutputPath ".tmp-" A_TickCount "-" DllCall(
            "kernel32\GetCurrentProcessId", "UInt")
        try {
            stream := FileOpen(temporary, "w", "UTF-8-RAW")
            if !IsObject(stream)
                throw Error("无法创建真实设备证据临时文件。")
            try stream.Write(JsonCodec.Stringify(evidence, true))
            finally stream.Close()
            FileMove(temporary, this.Options.OutputPath, true)
        } finally {
            if FileExist(temporary)
                FileDelete(temporary)
        }
    }

    SanitizeDevice(device) {
        result := Map()
        for field in ["id", "stable_id", "exact_path_id", "type",
                "display_name", "vendor_id", "product_id", "hardware_id",
                "container_id", "interface_number", "revision", "usage_page",
                "usage", "stability", "ambiguous", "observation_only"] {
            if device.Has(field)
                result[field] := RuleSpec.Clone(device[field])
        }
        return result
    }

    DeviceField(device, field, fallback := "") {
        return Type(device) == "Map" && device.Has(field)
            ? String(device[field]) : fallback
    }

    DeviceVidPid(device) {
        vendor := this.DeviceField(device, "vendor_id")
        product := this.DeviceField(device, "product_id")
        return vendor == "" && product == "" ? "unknown"
            : (vendor == "" ? "????" : vendor) ":"
                . (product == "" ? "????" : product)
    }

    Cancel(*) {
        this.Cancelled := true
    }
}

ParsePhysicalEvidenceOptions(arguments) {
    options := {
        OutputPath: "",
        OutputDirectory: "",
        DurationSeconds: 60,
        MinimumKeyboards: 2,
        MinimumMice: 2,
        RuntimeSha256: "",
        CollectorSha256: "",
        RequireHotplug: false,
        ListOnly: false,
        SyntaxCheck: false
    }
    index := 1
    while index <= arguments.Length {
        argument := arguments[index]
        switch argument {
            case "--syntax-check": options.SyntaxCheck := true
            case "--list-only": options.ListOnly := true
            case "--require-hotplug": options.RequireHotplug := true
            case "--output":
                index++
                if index > arguments.Length
                    throw ValueError("--output 缺少路径。")
                options.OutputPath := String(arguments[index])
            case "--duration":
                index++
                if index > arguments.Length
                    throw ValueError("--duration 缺少秒数。")
                options.DurationSeconds := Integer(arguments[index])
            case "--min-keyboards":
                index++
                if index > arguments.Length
                    throw ValueError("--min-keyboards 缺少数量。")
                options.MinimumKeyboards := Integer(arguments[index])
            case "--min-mice":
                index++
                if index > arguments.Length
                    throw ValueError("--min-mice 缺少数量。")
                options.MinimumMice := Integer(arguments[index])
            case "--runtime-sha256":
                index++
                if index > arguments.Length
                    throw ValueError("--runtime-sha256 缺少摘要。")
                options.RuntimeSha256 := String(arguments[index])
            case "--collector-sha256":
                index++
                if index > arguments.Length
                    throw ValueError("--collector-sha256 缺少摘要。")
                options.CollectorSha256 := String(arguments[index])
            default:
                throw ValueError("未知参数：" argument)
        }
        index++
    }
    if options.SyntaxCheck
        return options
    if options.OutputPath == ""
        throw ValueError("必须提供 --output 证据文件路径。")
    if options.DurationSeconds < 5 || options.DurationSeconds > 900
        throw ValueError("采集时长必须在 5 到 900 秒之间。")
    if options.MinimumKeyboards < 1 || options.MinimumKeyboards > 16
        throw ValueError("键盘数量必须在 1 到 16 之间。")
    if options.MinimumMice < 1 || options.MinimumMice > 16
        throw ValueError("鼠标数量必须在 1 到 16 之间。")
    if !RegExMatch(options.RuntimeSha256, "i)^[a-f0-9]{64}$")
        throw ValueError("运行时 SHA-256 无效。")
    if !RegExMatch(options.CollectorSha256, "i)^[a-f0-9]{64}$")
        throw ValueError("采集器 SHA-256 无效。")
    options.RuntimeSha256 := StrUpper(options.RuntimeSha256)
    options.CollectorSha256 := StrUpper(options.CollectorSha256)
    outputPath := String(options.OutputPath)
    if !RegExMatch(outputPath, "i)^[a-z]:\\")
        outputPath := A_WorkingDir "\\" outputPath
    options.OutputPath := outputPath
    options.OutputDirectory := RegExReplace(outputPath, "\\[^\\]+$")
    if options.OutputDirectory == outputPath
        throw ValueError("证据输出路径缺少文件名。")
    return options
}

try {
    evidenceOptions := ParsePhysicalEvidenceOptions(A_Args)
    if evidenceOptions.SyntaxCheck
        ExitApp(0)
    evidenceSession := PhysicalDeviceEvidenceSession(evidenceOptions)
    ExitApp(evidenceSession.Run())
} catch as startupError {
    FileAppend(startupError.Message "`n" startupError.Stack, "**")
    ExitApp(1)
}
