; Interception 设备识别窗口。
; 设备枚举不会拦截输入；实时识别会临时接收并原样回送 stroke。

class InterceptionDeviceWindow {
    __New(ownerWindow) {
        this.OwnerWindow := ownerWindow
        this.App := ownerWindow.App
        this.Service := this.App.Interception
        this.Gui := ""
        this.OwnerLease := ""
        this.IconHandles := []
        this.Interactions := ""
        this.Devices := []
        this.RowDevices := Map()
        this.IdentifyTimer := ObjBindMethod(this, "PollIdentify")
        this.Identifying := false
        this.RuntimeSuspensionOwned := false
        this.Disposed := false
        try this.Build()
        catch as buildError {
            try this.Dispose()
            throw buildError
        }
    }

    Build() {
        colors := UiThemeService.GetPalette()
        fontName := LocalizationService.GetUiFontName()
        systemFont := LocalizationService.GetLanguageSystemUiFontName()
        this.WindowWidth := 980
        this.WindowHeight := 600
        this.Gui := Gui("+Owner" this.OwnerWindow.Gui.Hwnd
            " +Resize +MinimizeBox " UiScaleService.ScaleMinSizeOptions(700, 480),
            InterceptionDeviceText("Interception 设备识别"))
        this.IconHandles := ApplyApplicationWindowIcon(this.Gui.Hwnd)
        this.OwnerLease := WindowHierarchy.Acquire(this.OwnerWindow.Gui,
            this.Gui.Hwnd)
        if !this.OwnerLease
            throw Error("无法建立 Interception 设备窗口层级。")
        this.Gui.BackColor := colors.Window
        this.Gui.MarginX := 0
        this.Gui.MarginY := 0
        this.Gui.SetFont("norm s10 c" colors.Text, fontName)
        this.Interactions := MappingUiInteractions(this.Gui, colors.Window,
            this.App.SvgRenderer)

        this.Status := this.Gui.Add("Text", "x14 y12 w" (this.WindowWidth - 28)
            " h42 Background" colors.Surface " c" colors.Text, "")
        this.Status.SetFont("s10", fontName)
        this.RefreshButton := this.AddButton(14, 62, 110, InterceptionDeviceText("刷新设备"),
            colors.Toolbar, ObjBindMethod(this, "Refresh"), colors.ToolbarText)
        this.StartButton := this.AddButton(132, 62, 126, InterceptionDeviceText("开始识别"),
            colors.Primary, ObjBindMethod(this, "StartIdentify"))
        this.StopButton := this.AddButton(266, 62, 110, InterceptionDeviceText("停止识别"),
            colors.Danger, ObjBindMethod(this, "StopIdentify"))
        this.CopyButton := this.AddButton(384, 62, 130, InterceptionDeviceText("复制设备编号"),
            colors.Toolbar, ObjBindMethod(this, "CopySelected"),
            colors.ToolbarText)
        this.CopyConfigButton := this.AddButton(522, 62, 160,
            InterceptionDeviceText("复制键盘配置片段"), colors.Toolbar,
            ObjBindMethod(this, "CopyKeyboardConfig"), colors.ToolbarText)
        this.InstallButton := this.AddButton(690, 62, 150,
            InterceptionDeviceText("安装驱动"), colors.Primary,
            ObjBindMethod(this, "InstallDriver"))
        this.ApplyCommandIcons()

        this.List := this.Gui.Add("ListView", "x14 y106 w" (this.WindowWidth - 28)
            " h380 Report +ReadOnly -Multi -Hdr -Border -E0x200 Background"
            colors.Surface " c" colors.Text,
            [InterceptionDeviceText("项目编号"), InterceptionDeviceText("identify 编号"),
                InterceptionDeviceText("类型"), InterceptionDeviceText("状态"),
                InterceptionDeviceText("硬件 ID"), InterceptionDeviceText("过滤器")])
        this.List.SetFont("s10 c" colors.Text, fontName)
        this.List.OnEvent("ItemSelect", ObjBindMethod(this, "OnSelected"))
        this.Detail := this.Gui.Add("Edit", "x14 y496 w" (this.WindowWidth - 28)
            " h72 ReadOnly Multi -Wrap -Border -E0x200 Background"
            colors.Input " c" colors.Text, "")
        this.Detail.SetFont("s10", fontName)
        this.Interactions.RegisterTextInput(this.Detail)
        this.Gui.OnEvent("Size", ObjBindMethod(this, "OnResize"))
        this.Gui.OnEvent("Close", ObjBindMethod(this, "RequestClose"))
        this.Gui.OnEvent("Escape", ObjBindMethod(this, "RequestClose"))
        this.Refresh()
    }

    AddButton(x, y, width, text, color, callback, textColor := "") {
        if textColor == ""
            textColor := UiThemeService.GetPalette().ButtonText
        button := this.Gui.Add("Text", "x" x " y" y " w" width
            " h30 Center 0x200 Background" color " c" textColor, text)
        button.SetFont("s10 bold",
            LocalizationService.GetLanguageSystemUiFontName())
        if !this.Interactions.RegisterButton(button, color, callback,
                "", "", false, textColor)
            button.OnEvent("Click", callback)
        return button
    }

    ApplyCommandIcons() {
        colors := UiThemeService.GetPalette()
        this.Interactions.SetButtonLucideIcon(this.RefreshButton,
            "refresh-cw.svg", 15, 6,
            UiThemeService.ButtonIconColor(colors.ToolbarText))
        this.Interactions.SetButtonLucideIcon(this.StartButton,
            "scan-line.svg", 15, 6,
            UiThemeService.ButtonIconColor(colors.ButtonText))
        this.Interactions.SetButtonLucideIcon(this.StopButton,
            "square.svg", 15, 6,
            UiThemeService.ButtonIconColor(colors.ButtonText))
        this.Interactions.SetButtonLucideIcon(this.CopyButton,
            "copy.svg", 15, 6,
            UiThemeService.ButtonIconColor(colors.ToolbarText))
        this.Interactions.SetButtonLucideIcon(this.CopyConfigButton,
            "clipboard-copy.svg", 15, 6,
            UiThemeService.ButtonIconColor(colors.ToolbarText))
        this.Interactions.SetButtonLucideIcon(this.InstallButton,
            "power.svg", 15, 6,
            UiThemeService.ButtonIconColor(colors.ButtonText))
    }

    Show() {
        if this.Disposed
            return false
        return ShowPreparedWindow(this.Gui,
            "w" this.WindowWidth " h" this.WindowHeight,
            ObjBindMethod(this, "ApplyNativeThemes"), true)
    }

    Activate() {
        if this.Disposed
            return false
        return ActivatePreparedWindow(this.Gui)
    }

    ApplyNativeThemes(*) {
        if this.Disposed
            return false
        ApplyDarkWindow(this.Gui.Hwnd)
        ApplyDarkListView(this.List.Hwnd)
        ApplyDarkControl(this.Detail.Hwnd)
        return true
    }

    Refresh(*) {
        if this.Disposed
            return false
        if this.Identifying
            this.StopIdentify()
        status := this.Service.GetStatus()
        this.Devices := this.Service.EnumerateDevices()
        this.List.Delete()
        this.RowDevices.Clear()
        for device in this.Devices {
            row := this.List.Add("", device["number"],
                device["official_index"],
                device["type"] == "keyboard" ? InterceptionDeviceText("键盘")
                    : InterceptionDeviceText("鼠标"),
                device["is_valid"] ? InterceptionDeviceText("有效")
                    : InterceptionDeviceText("不可用"),
                device["hardware_id"],
                Format("0x{:04X}", device["filter"]))
            this.RowDevices[row] := device
        }
        available := status.Get("available", false)
        prefix := available ? InterceptionDeviceText("Interception 已就绪")
            : InterceptionDeviceText("Interception 不可用")
        this.Status.Value := prefix . "：" . status.Get("message", "")
            . "`r`n" . InterceptionDeviceText("编号说明：项目配置使用 1-based 编号；官方 identify 输出使用 0-based 编号。")
            . " " . InterceptionDeviceText("识别期间请先暂停其他 Interception 规则。")
        this.Detail.Value := status.Get("library_path", "") == ""
            ? InterceptionDeviceText("库路径：未找到。可设置环境变量 KMRA_INTERCEPTION_DLL，或将 x64 DLL 放入发行包 third_party\interception\library\x64。")
            : InterceptionDeviceText("库路径：") . status.Get("library_path", "")
        this.UpdateButtons(available)
        return true
    }

    UpdateButtons(available) {
        this.StartButton.Enabled := available && !this.Identifying
        this.StopButton.Enabled := this.Identifying
        this.CopyButton.Enabled := this.List.GetCount() > 0
        this.CopyConfigButton.Enabled := this.List.GetCount() > 0
        this.InstallButton.Enabled := !available && !this.Identifying
            && this.Service.CanInstallDriver()
    }

    InstallDriver(*) {
        if this.Disposed || this.Identifying
            return false
        this.App.InstallInterceptionDriver(this.Gui)
        this.Refresh()
        return true
    }

    StartIdentify(*) {
        if this.Disposed || this.Identifying
            return false
        if this.App.Runtime.HasOwnProp("Interception")
                && this.App.Runtime.Interception.HasOwnProp("ContextActive")
                && this.App.Runtime.Interception.ContextActive {
            try this.RuntimeSuspensionOwned :=
                this.App.Runtime.Interception.Suspend()
            catch as suspendError {
                this.Status.Value := InterceptionDeviceText(
                    "无法暂停设备专属规则：") . suspendError.Message
                return false
            }
        }
        if this.App.HasActiveInterceptionRule() {
            this.Status.Value := InterceptionDeviceText(
                "无法开始识别：检测到正在运行的 Interception 受托管规则，请先暂停或停止它。")
            this.ResumeInterceptionRuntime()
            return false
        }
        status := this.Service.GetStatus()
        if !status.Get("available", false) {
            this.Status.Value := InterceptionDeviceText("无法开始识别：") . status.Get("message", "")
            this.ResumeInterceptionRuntime()
            return false
        }
        try this.Service.StartIdentify()
        catch as caughtError {
            this.Status.Value := InterceptionDeviceText("无法开始识别：") . caughtError.Message
            this.ResumeInterceptionRuntime()
            return false
        }
        this.Identifying := true
        this.Status.Value := InterceptionDeviceText("正在识别：请按下任意键或鼠标按钮；输入会原样回送。")
            . "`r`n" . InterceptionDeviceText("若已有受托管 Interception 规则，请先暂停它。")
        SetTimer(this.IdentifyTimer, 15)
        this.UpdateButtons(true)
        return true
    }

    PollIdentify(*) {
        if this.Disposed || !this.Identifying
            return
        try hit := this.Service.PollIdentify(1)
        catch as caughtError {
            this.Status.Value := InterceptionDeviceText("识别失败：") . caughtError.Message
            this.StopIdentify()
            return
        }
        if !IsObject(hit)
            return
        for row, device in this.RowDevices {
            if device["number"] == hit["number"] {
                this.List.Modify(row, "Select Focus Vis")
                this.List.EnsureVisible(row)
                this.Detail.Value := InterceptionDeviceText("识别到：项目编号 ") . hit["number"]
                    . "，official identify 编号 " . hit["official_index"]
                    . "，" . (hit["type"] == "keyboard" ? InterceptionDeviceText("键盘")
                        : InterceptionDeviceText("鼠标"))
                break
            }
        }
    }

    StopIdentify(*) {
        if IsObject(this.IdentifyTimer)
            try SetTimer(this.IdentifyTimer, 0)
        try this.Service.StopIdentify()
        this.Identifying := false
        this.ResumeInterceptionRuntime()
        this.UpdateButtons(this.Service.GetStatus().Get("available", false))
        return true
    }

    ResumeInterceptionRuntime(throwOnFailure := false) {
        if !this.RuntimeSuspensionOwned
            return false
        this.RuntimeSuspensionOwned := false
        try return this.App.Runtime.Interception.Resume()
        catch as resumeError {
            if throwOnFailure
                throw resumeError
            this.Status.Value := InterceptionDeviceText(
                "设备识别结束，但设备专属规则恢复失败：") . resumeError.Message
            return false
        }
    }

    OnSelected(listView, row, selected) {
        if !selected || !this.RowDevices.Has(row)
            return
        device := this.RowDevices[row]
        this.Detail.Value := InterceptionDeviceText("项目编号：") . device["number"]
            . "`r`n" . InterceptionDeviceText("官方 identify 编号：") . device["official_index"]
            . "`r`n" . InterceptionDeviceText("硬件 ID：") . device["hardware_id"]
    }

    GetSelectedDevice() {
        row := this.List.GetNext(0, "Focused")
        return row && this.RowDevices.Has(row) ? this.RowDevices[row] : ""
    }

    CopySelected(*) {
        device := this.GetSelectedDevice()
        if !IsObject(device)
            return false
        A_Clipboard := String(device["number"])
        this.Status.Value := InterceptionDeviceText("已复制项目设备编号：") . device["number"]
        return true
    }

    CopyKeyboardConfig(*) {
        device := this.GetSelectedDevice()
        if !IsObject(device) || device["type"] != "keyboard"
            return false
        A_Clipboard := "static ConfiguredKeyboardDevices := ["
            device["number"] "]"
        this.Status.Value := InterceptionDeviceText("已复制受托管脚本键盘设备配置片段。")
        return true
    }

    OnResize(guiObj, minMax, width, height) {
        if this.Disposed || minMax == 1
            return
        width := Max(700, width), height := Max(480, height)
        this.Status.Move(14, 12, width - 28, 42)
        this.List.Move(14, 106, width - 28, height - 220)
        this.Detail.Move(14, height - 110, width - 28, 72)
    }

    ApplyAppearance() {
        if this.Disposed
            return false
        colors := UiThemeService.GetPalette()
        fontName := LocalizationService.GetUiFontName()
        systemFont := LocalizationService.GetLanguageSystemUiFontName()
        this.Gui.Title := InterceptionDeviceText("Interception 设备识别")
        this.Gui.BackColor := colors.Window
        this.Status.Opt("Background" colors.Surface " c" colors.Text)
        this.Status.SetFont("s10", fontName)
        this.List.Opt("Background" colors.Surface " c" colors.Text)
        this.List.SetFont("s10 c" colors.Text, fontName)
        this.Detail.Opt("Background" colors.Input " c" colors.Text)
        this.Detail.SetFont("s10", fontName)
        for button in [this.RefreshButton, this.StartButton, this.StopButton,
                this.CopyButton, this.CopyConfigButton, this.InstallButton]
            button.SetFont("s10 bold", systemFont)
        this.ApplyCommandIcons()
        this.ApplyNativeThemes()
        return true
    }

    RequestClose(*) => this.Dispose()

    Dispose(activateOwner := true) {
        if this.Disposed
            return
        this.Disposed := true
        cleanup := CleanupCollector("Interception 设备窗口")
        if IsObject(this.IdentifyTimer)
                && cleanup.Run("停止识别计时器",
                    () => SetTimer(this.IdentifyTimer, 0))
            this.IdentifyTimer := ""
        cleanup.Run("停止识别会话", () => this.Service.StopIdentify())
        cleanup.Run("恢复设备专属规则",
            () => this.ResumeInterceptionRuntime(true))
        closeContext := ""
        if this.OwnerLease {
            try {
                closeContext := WindowHierarchy.Release(this.OwnerLease)
                this.OwnerLease := ""
            } catch as ownerError {
                cleanup.Failures.Push("释放父窗口关系：" ownerError.Message)
            }
        }
        if IsObject(this.Interactions)
                && cleanup.Run("释放交互服务",
                    () => this.Interactions.Dispose())
            this.Interactions := ""
        if IsObject(this.Gui)
                && cleanup.Run("销毁窗口", () => this.Gui.Destroy())
            this.Gui := ""
        cleanup.Run("释放窗口图标",
            () => ReleaseApplicationWindowIcons(this.IconHandles))
        this.IconHandles := []
        cleanup.Run("通知父窗口",
            () => this.OwnerWindow.OnInterceptionDevicesClosed(this))
        if activateOwner
            cleanup.Run("恢复父窗口", () =>
                WindowHierarchy.CompleteClose(closeContext))
        cleanup.Complete()
        return true
    }
}

InterceptionDeviceText(text) => text
