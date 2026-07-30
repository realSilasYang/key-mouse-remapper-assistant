#Requires AutoHotkey v2.0.26 64-bit
#SingleInstance Off
#Warn All, StdOut

#Include ..\..\src\Core\JsonCodec.ahk
#Include ..\..\src\Core\RuleSpec.ahk
#Include ..\..\src\Platform\WindowsContextService.ahk
#Include ..\DesktopContextEvidenceModel.ahk

class DesktopContextEvidenceSession {
    static WmPowerBroadcast := 0x0218
    static WmWtsSessionChange := 0x02B1
    static SampleHeartbeatMs := 2000
    static ListOnlyForegroundWaitMs := 2000

    __New(options) {
        this.Options := options
        this.ContextService := WindowsContextService()
        this.Samples := []
        this.Events := []
        this.Errors := []
        this.Cancelled := false
        this.StartTick := 0
        this.EndTick := 0
        this.LastSampleTick := 0
        this.LastFingerprint := ""
        this.LastStatus := "collecting"
        this.WtsRegistered := false
        this.ShuttingDown := false
        this.TickTimer := ObjBindMethod(this, "OnTick")
        this.WtsCallback := ObjBindMethod(this, "OnWtsSessionChange")
        this.PowerCallback := ObjBindMethod(this, "OnPowerBroadcast")
        this.CollectorIntegrity := this.GetProcessIntegrity(
            DllCall("kernel32\GetCurrentProcessId", "UInt"))
        this.Window := Gui("+Resize +MinSize900x590",
            "键鼠重映射小助手 - 真实桌面验证")
        this.Window.SetFont("s10", "Microsoft YaHei UI")
        this.Window.OnEvent("Close", ObjBindMethod(this, "Cancel"))
        this.Window.OnEvent("Escape", ObjBindMethod(this, "Cancel"))
        this.Window.OnEvent("Size", ObjBindMethod(this, "OnSize"))
        this.Instruction := this.Window.Add("Text", "x16 y14 w948 h122",
            "请在本轮采集期间依次完成以下真实操作：`n"
            . "1. 锁定 Windows 后再解锁；2. 通过远程桌面连接到同一会话；"
            . "3. 让电脑睡眠后唤醒；`n"
            . "4. 聚焦一个以管理员权限运行的窗口；5. 触发 UAC 安全桌面并取消；"
            . "6. 切换到另一种键盘布局。`n"
            . "采集器会持续原子保存脱敏证据。不要结束进程；关闭窗口或按 Esc 会取消本轮。")
        this.RequirementList := this.Window.Add("ListView",
            "x16 y144 w948 h300 -Multi", ["验收项", "状态", "当前证据"])
        this.RequirementList.ModifyCol(1, 190)
        this.RequirementList.ModifyCol(2, 90)
        this.RequirementList.ModifyCol(3, 640)
        for item in [
                ["锁屏 / 解锁", "等待", "同一 WTS 会话必须同时出现锁定和解锁"],
                ["RDP 会话", "等待", "WTS client protocol 必须实际为 RDP"],
                ["睡眠 / 唤醒", "等待", "必须收到有序 suspend 和 resume 通知"],
                ["高权限焦点", "等待", "前台进程完整性必须高于采集器"],
                ["UAC 安全桌面", "等待", "WTS 解锁且输入桌面返回拒绝访问"],
                ["键盘布局切换", "等待", "前台线程必须出现至少两个 HKL"]]
            this.RequirementList.Add("", item*)
        this.EventText := this.Window.Add("Text", "x16 y452 w948 h44",
            "尚未收到会话或电源通知。")
        this.StatusText := this.Window.Add("Text", "x16 y510 w948 h46",
            "准备采集。")
    }

    Run() {
        exitCode := 1
        try {
            this.StartTick := this.TickCount64()
            if !this.CollectorIntegrity["known"]
                this.AddError("collector_integrity",
                    "无法读取采集器进程完整性级别。",
                    this.CollectorIntegrity["error"])
            this.RegisterNotifications()
            if this.Options.ListOnly {
                context := this.WaitForForegroundContext()
                this.Sample(true, "list_only", context)
                this.EndTick := this.StartTick
                this.LastStatus := "listed"
                this.WriteEvidence("listed")
                exitCode := 0
            } else {
                this.Window.Show("w980 h590")
                this.Sample(true, "initial")
                this.WriteEvidence("collecting")
                SetTimer(this.TickTimer, 100)
                deadline := this.StartTick
                    + this.Options.DurationSeconds * 1000
                while !this.Cancelled && this.TickCount64() < deadline
                    Sleep(25)
                this.EndTick := this.TickCount64()
                this.Sample(true, this.Cancelled ? "cancelled" : "final")
                result := this.Evaluate()
                status := this.Cancelled ? "cancelled"
                    : (result.Passed ? "passed" : "failed")
                this.LastStatus := status
                this.WriteEvidence(status, result)
                exitCode := this.Cancelled ? 2 : (result.Passed ? 0 : 3)
            }
        } catch as evidenceError {
            this.AddError("session_failed", evidenceError.Message)
            if !this.StartTick
                this.StartTick := this.TickCount64()
            this.EndTick := this.TickCount64()
            this.LastStatus := "error"
            try this.WriteEvidence("error")
            FileAppend(evidenceError.Message "`n" evidenceError.Stack, "**")
            exitCode := 1
        } finally {
            this.ShuttingDown := true
            try SetTimer(this.TickTimer, 0)
            this.UnregisterNotifications()
            try this.Window.Destroy()
        }
        return exitCode
    }

    RegisterNotifications() {
        OnMessage(DesktopContextEvidenceSession.WmWtsSessionChange,
            this.WtsCallback)
        OnMessage(DesktopContextEvidenceSession.WmPowerBroadcast,
            this.PowerCallback)
        if !DllCall("wtsapi32\WTSRegisterSessionNotification",
                "Ptr", this.Window.Hwnd, "UInt", 0, "Int") {
            errorCode := A_LastError
            OnMessage(DesktopContextEvidenceSession.WmWtsSessionChange,
                this.WtsCallback, 0)
            OnMessage(DesktopContextEvidenceSession.WmPowerBroadcast,
                this.PowerCallback, 0)
            throw OSError(errorCode, "无法注册 WTS 会话通知。")
        }
        this.WtsRegistered := true
        return true
    }

    UnregisterNotifications() {
        if this.WtsRegistered
            try DllCall("wtsapi32\WTSUnRegisterSessionNotification",
                "Ptr", this.Window.Hwnd, "Int")
        this.WtsRegistered := false
        try OnMessage(DesktopContextEvidenceSession.WmWtsSessionChange,
            this.WtsCallback, 0)
        try OnMessage(DesktopContextEvidenceSession.WmPowerBroadcast,
            this.PowerCallback, 0)
        return true
    }

    OnTick() {
        if this.ShuttingDown || !this.StartTick
            return
        try this.Sample(false, "poll")
        catch as sampleError
            this.AddError("context_sample", sampleError.Message)
    }

    OnWtsSessionChange(wParam, lParam, msg, hwnd) {
        if this.ShuttingDown || hwnd != this.Window.Hwnd
            return
        Critical()
        try {
            context := this.ContextService.Build()
            this.Events.Push(Map(
                "type", "session",
                "name", this.WtsNotificationName(wParam),
                "code", Integer(wParam),
                "session_id", Integer(lParam),
                "tick_ms", this.ElapsedTick(),
                "utc", this.UtcNow(),
                "session", RuleSpec.Clone(context["session"])))
            this.Sample(true, "wts_notification", context)
            this.WriteEvidence("collecting")
        } catch as notificationError
            this.AddError("wts_notification", notificationError.Message)
        return 0
    }

    OnPowerBroadcast(wParam, lParam, msg, hwnd) {
        if this.ShuttingDown || hwnd != this.Window.Hwnd
            return
        phase := ""
        name := this.PowerNotificationName(wParam)
        if wParam == 0x4
            phase := "suspend"
        else if wParam == 0x6 || wParam == 0x7 || wParam == 0x12
            phase := "resume"
        if phase == ""
            return true
        Critical()
        try {
            this.Events.Push(Map(
                "type", "power",
                "phase", phase,
                "name", name,
                "code", Integer(wParam),
                "tick_ms", this.ElapsedTick(),
                "utc", this.UtcNow()))
            this.Sample(true, "power_" phase)
            this.WriteEvidence("collecting")
        } catch as powerError
            this.AddError("power_notification", powerError.Message)
        return true
    }

    Sample(force, reason, suppliedContext := "") {
        context := IsObject(suppliedContext) ? suppliedContext
            : this.ContextService.Build()
        now := this.TickCount64()
        sample := this.BuildSample(context, now, reason)
        fingerprint := this.SampleFingerprint(sample)
        if !force && fingerprint == this.LastFingerprint
                && now - this.LastSampleTick
                    < DesktopContextEvidenceSession.SampleHeartbeatMs
            return false
        this.Samples.Push(sample)
        this.LastFingerprint := fingerprint
        this.LastSampleTick := now
        this.EndTick := now
        this.RefreshWindow()
        this.WriteEvidence("collecting")
        return true
    }

    WaitForForegroundContext() {
        deadline := this.TickCount64()
            + DesktopContextEvidenceSession.ListOnlyForegroundWaitMs
        context := this.ContextService.Build()
        while Trim(String(context["input_source"]["layout"])) == ""
                && this.TickCount64() < deadline {
            Sleep(25)
            context := this.ContextService.Build()
        }
        return context
    }

    BuildSample(context, now, reason) {
        application := context["application"]
        window := context["window"]
        processId := Integer(application["pid"])
        integrity := this.GetProcessIntegrity(processId)
        return Map(
            "sequence", this.Samples.Length + 1,
            "tick_ms", Max(0, now - this.StartTick),
            "utc", this.UtcNow(),
            "reason", String(reason),
            "session", RuleSpec.Clone(context["session"]),
            "input_source", RuleSpec.Clone(context["input_source"]),
            "foreground", Map(
                "process", String(application["process"]),
                "process_id", processId,
                "hwnd", Integer(window["hwnd"]),
                "thread_id", Integer(window["thread_id"]),
                "focused_hwnd", Integer(window["focused_hwnd"]),
                "focused_class", String(window["focused_class"]),
                "focus_source", String(window["focus_source"]),
                "integrity_known", JsonBoolean(integrity["known"]),
                "integrity_rid", integrity["known"]
                    ? integrity["rid"] : JsonNull(),
                "integrity_error", integrity["error"]))
    }

    SampleFingerprint(sample) {
        foreground := sample["foreground"]
        session := sample["session"]
        inputSource := sample["input_source"]
        return JsonCodec.Stringify(Map(
            "session", session,
            "layout", inputSource["layout"],
            "foreground", Map(
                "process", foreground["process"],
                "process_id", foreground["process_id"],
                "hwnd", foreground["hwnd"],
                "focused_hwnd", foreground["focused_hwnd"],
                "focused_class", foreground["focused_class"],
                "integrity_known", foreground["integrity_known"],
                "integrity_rid", foreground["integrity_rid"])))
    }

    Evaluate() {
        duration := Max(0, this.EndTick - this.StartTick)
        result := DesktopContextEvidenceModel.Evaluate(this.Samples,
            this.Events, this.Options.Requirements,
            this.CollectorIntegrity["known"]
                ? this.CollectorIntegrity["rid"] : 0,
            this.Errors.Length, duration)
        if !this.CollectorIntegrity["known"]
            result.Passed := false
        return result
    }

    BuildEvidence(status, suppliedEvaluation := "") {
        evaluation := IsObject(suppliedEvaluation)
            ? suppliedEvaluation : this.Evaluate()
        duration := Max(0, this.EndTick - this.StartTick)
        finalStatus := status == "passed" || status == "failed"
        acceptanceEligible := !this.Options.ListOnly && !this.Cancelled
            && finalStatus && duration
                >= DesktopContextEvidenceModel.MinimumDurationMs
        passed := status == "passed" && evaluation.Passed
        return Map(
            "schema", 1,
            "status", status,
            "passed", JsonBoolean(passed),
            "acceptance_eligible", JsonBoolean(acceptanceEligible),
            "created_utc", this.UtcNow(),
            "runtime", Map(
                "autohotkey", A_AhkVersion,
                "architecture", A_PtrSize == 8 ? "x64" : "x86",
                "executable_sha256", this.Options.RuntimeSha256),
            "collector", Map(
                "script_sha256", this.Options.CollectorSha256,
                "process_id", DllCall("kernel32\GetCurrentProcessId", "UInt"),
                "integrity_known", JsonBoolean(
                    this.CollectorIntegrity["known"]),
                "integrity_rid", this.CollectorIntegrity["known"]
                    ? this.CollectorIntegrity["rid"] : JsonNull(),
                "integrity_error", this.CollectorIntegrity["error"],
                "list_only", JsonBoolean(this.Options.ListOnly)),
            "duration_ms", duration,
            "requirements", RuleSpec.Clone(this.Options.Requirements),
            "summary", Map(
                "passed", JsonBoolean(passed),
                "lock_cycle", JsonBoolean(evaluation.LockCycle),
                "rdp", JsonBoolean(evaluation.Rdp),
                "sleep_resume", JsonBoolean(evaluation.SleepResume),
                "elevated_focus", JsonBoolean(evaluation.ElevatedFocus),
                "secure_desktop", JsonBoolean(evaluation.SecureDesktop),
                "layout_switch", JsonBoolean(evaluation.LayoutSwitch),
                "distinct_layouts", evaluation.DistinctLayouts,
                "sample_count", this.Samples.Length,
                "event_count", this.Events.Length,
                "error_count", this.Errors.Length),
            "samples", RuleSpec.Clone(this.Samples),
            "events", RuleSpec.Clone(this.Events),
            "errors", RuleSpec.Clone(this.Errors))
    }

    WriteEvidence(status, evaluation := "") {
        if this.Options.OutputPath == ""
            return false
        evidence := this.BuildEvidence(status, evaluation)
        DirCreate(this.Options.OutputDirectory)
        temporary := this.Options.OutputPath ".tmp-" this.TickCount64()
            . "-" DllCall("kernel32\GetCurrentProcessId", "UInt")
        try {
            stream := FileOpen(temporary, "w", "UTF-8-RAW")
            if !IsObject(stream)
                throw Error("无法创建真实桌面证据临时文件。")
            try stream.Write(JsonCodec.Stringify(evidence, true))
            finally stream.Close()
            FileMove(temporary, this.Options.OutputPath, true)
        } finally {
            if FileExist(temporary)
                FileDelete(temporary)
        }
        return true
    }

    RefreshWindow() {
        if this.Options.ListOnly || !this.Window.Hwnd
            return
        evaluation := this.Evaluate()
        rows := [
            [evaluation.LockCycle, "同一会话已观察到锁定与解锁"],
            [evaluation.Rdp, "已观察到 WTS RDP protocol"],
            [evaluation.SleepResume, "已收到有序睡眠与唤醒通知"],
            [evaluation.ElevatedFocus, "已聚焦高于采集器完整性的进程"],
            [evaluation.SecureDesktop, "解锁状态下输入桌面访问被拒绝"],
            [evaluation.LayoutSwitch,
                "已观察到 " evaluation.DistinctLayouts " 个 HKL"]]
        for index, row in rows
            this.RequirementList.Modify(index, "", , row[1] ? "完成" : "等待",
                row[2])
        remaining := Max(0, this.Options.DurationSeconds * 1000
            - this.ElapsedTick())
        this.StatusText.Text := "剩余 " Ceil(remaining / 1000) " 秒；样本 "
            . this.Samples.Length "；通知 " this.Events.Length "；错误 "
            . this.Errors.Length "。证据文件：" this.Options.OutputPath
        if this.Events.Length {
            latest := this.Events[this.Events.Length]
            detail := latest["type"] == "power" ? latest["phase"]
                : latest["name"] " / session " latest["session_id"]
            this.EventText.Text := "最近通知：" latest["type"] " - " detail
                . "（" latest["utc"] "）"
        }
    }

    OnSize(guiObject, minMax, width, height) {
        if minMax == -1
            return
        contentWidth := Max(600, width - 32)
        listHeight := Max(240, height - 290)
        this.Instruction.Move(, , contentWidth)
        this.RequirementList.Move(, , contentWidth, listHeight)
        this.RequirementList.ModifyCol(3, Max(240, contentWidth - 300))
        this.EventText.Move(, 152 + listHeight, contentWidth)
        this.StatusText.Move(, 208 + listHeight, contentWidth)
    }

    AddError(category, detail, errorCode := 0) {
        if this.Errors.Length >= 100
            return false
        this.Errors.Push(Map(
            "category", String(category),
            "detail", String(detail),
            "error", Integer(errorCode),
            "tick_ms", this.StartTick ? this.ElapsedTick() : 0,
            "utc", this.UtcNow()))
        if this.StartTick && this.Options.OutputPath != ""
            try this.WriteEvidence("collecting")
        return true
    }

    GetProcessIntegrity(processId) {
        if !processId
            return Map("known", false, "rid", 0, "error", 87)
        processHandle := DllCall("kernel32\OpenProcess", "UInt", 0x1000,
            "Int", false, "UInt", processId, "Ptr")
        if !processHandle
            return Map("known", false, "rid", 0, "error", A_LastError)
        tokenHandle := 0
        try {
            if !DllCall("advapi32\OpenProcessToken", "Ptr", processHandle,
                    "UInt", 0x0008, "Ptr*", &tokenHandle, "Int")
                return Map("known", false, "rid", 0, "error", A_LastError)
            required := 0
            DllCall("advapi32\GetTokenInformation", "Ptr", tokenHandle,
                "Int", 25, "Ptr", 0, "UInt", 0, "UInt*", &required, "Int")
            if !required
                return Map("known", false, "rid", 0, "error", A_LastError)
            tokenInfo := Buffer(required, 0)
            if !DllCall("advapi32\GetTokenInformation", "Ptr", tokenHandle,
                    "Int", 25, "Ptr", tokenInfo, "UInt", tokenInfo.Size,
                    "UInt*", &required, "Int")
                return Map("known", false, "rid", 0, "error", A_LastError)
            sid := NumGet(tokenInfo, 0, "Ptr")
            countPointer := DllCall("advapi32\GetSidSubAuthorityCount",
                "Ptr", sid, "Ptr")
            if !countPointer
                return Map("known", false, "rid", 0, "error", A_LastError)
            count := NumGet(countPointer, 0, "UChar")
            if !count
                return Map("known", false, "rid", 0, "error", 13)
            ridPointer := DllCall("advapi32\GetSidSubAuthority", "Ptr", sid,
                "UInt", count - 1, "Ptr")
            if !ridPointer
                return Map("known", false, "rid", 0, "error", A_LastError)
            return Map("known", true, "rid", NumGet(ridPointer, 0, "UInt"),
                "error", 0)
        } finally {
            if tokenHandle
                DllCall("kernel32\CloseHandle", "Ptr", tokenHandle)
            DllCall("kernel32\CloseHandle", "Ptr", processHandle)
        }
    }

    WtsNotificationName(code) {
        switch code {
            case 0x1: return "console_connect"
            case 0x2: return "console_disconnect"
            case 0x3: return "remote_connect"
            case 0x4: return "remote_disconnect"
            case 0x5: return "session_logon"
            case 0x6: return "session_logoff"
            case 0x7: return "session_lock"
            case 0x8: return "session_unlock"
            case 0x9: return "session_remote_control"
        }
        return "session_change_" Integer(code)
    }

    PowerNotificationName(code) {
        switch code {
            case 0x4: return "suspend"
            case 0x6: return "resume_critical"
            case 0x7: return "resume_suspend"
            case 0x12: return "resume_automatic"
        }
        return "power_" Integer(code)
    }

    TickCount64() {
        return DllCall("kernel32\GetTickCount64", "UInt64")
    }

    ElapsedTick() {
        return Max(0, this.TickCount64() - this.StartTick)
    }

    UtcNow() {
        return FormatTime(A_NowUTC, "yyyy-MM-ddTHH:mm:ssZ")
    }

    Cancel(*) {
        this.Cancelled := true
    }
}

ParseDesktopEvidenceOptions(arguments) {
    options := {
        OutputPath: "",
        OutputDirectory: "",
        DurationSeconds: 300,
        RuntimeSha256: "",
        CollectorSha256: "",
        ListOnly: false,
        SyntaxCheck: false,
        Requirements: Map(
            "lock_cycle", JsonBoolean(true),
            "rdp", JsonBoolean(true),
            "sleep_resume", JsonBoolean(true),
            "elevated_focus", JsonBoolean(true),
            "secure_desktop", JsonBoolean(true),
            "layout_switch", JsonBoolean(true))
    }
    index := 1
    while index <= arguments.Length {
        argument := arguments[index]
        switch argument {
            case "--syntax-check": options.SyntaxCheck := true
            case "--list-only": options.ListOnly := true
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
            case "--runtime-sha256":
                index++
                if index > arguments.Length
                    throw ValueError("--runtime-sha256 缺少摘要。")
                options.RuntimeSha256 := StrUpper(String(arguments[index]))
            case "--collector-sha256":
                index++
                if index > arguments.Length
                    throw ValueError("--collector-sha256 缺少摘要。")
                options.CollectorSha256 := StrUpper(String(arguments[index]))
            default:
                throw ValueError("未知参数：" argument)
        }
        index++
    }
    if options.SyntaxCheck
        return options
    if options.OutputPath == ""
        throw ValueError("必须提供 --output 证据文件路径。")
    if options.DurationSeconds < 60 || options.DurationSeconds > 1800
        throw ValueError("采集时长必须在 60 到 1800 秒之间。")
    if !RegExMatch(options.RuntimeSha256, "^[0-9A-F]{64}$")
        throw ValueError("运行时 SHA-256 无效。")
    if !RegExMatch(options.CollectorSha256, "^[0-9A-F]{64}$")
        throw ValueError("采集器 SHA-256 无效。")
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
    desktopEvidenceOptions := ParseDesktopEvidenceOptions(A_Args)
    if desktopEvidenceOptions.SyntaxCheck
        ExitApp(0)
    desktopEvidenceSession := DesktopContextEvidenceSession(
        desktopEvidenceOptions)
    ExitApp(desktopEvidenceSession.Run())
} catch as startupError {
    FileAppend(startupError.Message "`n" startupError.Stack, "**")
    ExitApp(1)
}
