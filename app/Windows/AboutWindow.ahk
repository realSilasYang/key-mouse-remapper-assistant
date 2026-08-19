; 主窗口的关于入口。
; 产品信息、更新检查、打赏和项目地址集中在一个只读子窗口；更新任务仍由
; 应用级服务持有，窗口关闭后不会中断后台检查。

class AboutWindow {
    static ProjectHomeUrl :=
        "https://github.com/realSilasYang/key-mouse-remapper-assistant"

    __New(ownerWindow) {
        this.OwnerWindow := ownerWindow
        this.App := ownerWindow.App
        this.Gui := ""
        this.OwnerLease := ""
        this.IconHandles := []
        this.Interactions := ""
        this.Disposed := false
        this.UpdateCheckActive := false
        try this.Build()
        catch as buildError {
            try this.Dispose()
            throw buildError
        }
    }

    Build() {
        colors := UiThemeService.GetPalette()
        compactLayout := LocalizationService.UsesCompactLayout()
        this.WindowWidth := compactLayout ? 520 : 680
        this.WindowHeight := 291
        contentX := compactLayout ? 50 : 60
        contentWidth := this.WindowWidth - contentX * 2
        fontName := LocalizationService.GetUiFontName()

        this.Gui := Gui("+Owner" this.OwnerWindow.Gui.Hwnd
            " +OwnDialogs +MinimizeBox -MaximizeBox", Tr("关于"))
        this.IconHandles := ApplyApplicationWindowIcon(this.Gui.Hwnd)
        this.OwnerLease := WindowHierarchy.Acquire(this.OwnerWindow.Gui,
            this.Gui.Hwnd)
        if !this.OwnerLease
            throw Error("无法建立关于窗口层级。")
        this.Gui.BackColor := colors.Window
        this.Gui.MarginX := 0
        this.Gui.MarginY := 0
        this.Gui.SetFont("norm s10 c" colors.Text, fontName)
        this.Interactions := MappingUiInteractions(this.Gui, colors.Window,
            this.App.SvgRenderer)

        logoSize := 44
        this.Logo := this.Gui.Add("Picture",
            "x" Floor((this.WindowWidth - logoSize) / 2)
                " y20 w" logoSize " h" logoSize,
            GetApplicationIconPath())
        this.Gui.SetFont("bold s14 c" colors.Text,
            LocalizationService.GetLanguageSystemUiFontName())
        this.ProductName := this.Gui.Add("Text",
            "x" contentX " y70 w" contentWidth
                " h30 Center 0x200 BackgroundTrans",
            Tr("键鼠重映射小助手"))
        this.Gui.SetFont("norm s10 c" colors.Muted, fontName)
        this.Subtitle := this.Gui.Add("Text",
            "x" contentX " y106 w" contentWidth
                " h24 Center 0x200 BackgroundTrans",
            Tr("让每一条键鼠映射都可录制、可审阅、可掌控"))

        this.TopDivider := this.Gui.Add("Text",
            "x" contentX " y140 w" contentWidth
                " h1 Background" colors.Divider)
        infoCenterX := this.WindowWidth // 2
        infoGap := compactLayout ? 14 : 20
        leftInfoWidth := infoCenterX - infoGap - contentX
        rightInfoX := infoCenterX + infoGap
        rightInfoWidth := this.WindowWidth - contentX - rightInfoX
        this.Gui.SetFont("norm s10 c" colors.Muted, fontName)
        this.VersionLabel := this.Gui.Add("Text",
            "x" contentX " y153 w" leftInfoWidth
                " h22 Center 0x200 BackgroundTrans", Tr("当前版本"))
        this.RuntimeLabel := this.Gui.Add("Text",
            "x" rightInfoX " y153 w" rightInfoWidth
                " h22 Center 0x200 BackgroundTrans", Tr("运行环境"))
        this.Gui.SetFont("norm s11 c" colors.Text, fontName)
        this.VersionValue := this.Gui.Add("Text",
            "x" contentX " y180 w" leftInfoWidth
                " h28 Center 0x200 BackgroundTrans",
            GetApplicationEditionSummary())
        this.RuntimeValue := this.Gui.Add("Text",
            "x" rightInfoX " y180 w" rightInfoWidth
                " h28 Center 0x200 BackgroundTrans",
            GetAutoHotkeyRuntimeSummary())
        this.InfoDivider := this.Gui.Add("Text",
            "x" infoCenterX " y153 w1 h55 Background" colors.Divider)
        this.BottomDivider := this.Gui.Add("Text",
            "x" contentX " y221 w" contentWidth
                " h1 Background" colors.Divider)

        updateWidth := compactLayout ? 126 : 205
        donationWidth := compactLayout ? 88 : 96
        projectWidth := compactLayout ? 112 : 175
        actionGap := compactLayout ? 10 : 12
        actionWidth := updateWidth + donationWidth + projectWidth
            + actionGap * 2
        actionX := Floor((this.WindowWidth - actionWidth) / 2)
        this.UpdateButton := this.AddButton(actionX, 237, updateWidth,
            Tr("检查更新"), ObjBindMethod(this, "CheckForUpdates"))
        this.DonationButton := this.AddButton(
            actionX + updateWidth + actionGap, 237, donationWidth,
            Tr("打赏"), ObjBindMethod(this, "OpenDonation"))
        this.ProjectButton := this.AddButton(
            actionX + updateWidth + donationWidth + actionGap * 2,
            237, projectWidth, Tr("开源地址"),
            ObjBindMethod(this, "OpenProjectHomepage"))
        this.ApplyCommandIcons()
        this.RefreshButtonTooltips()
        this.SetUpdateCheckActive(this.App.UpdateService.IsChecking())

        this.Gui.OnEvent("Close", ObjBindMethod(this, "RequestClose"))
        this.Gui.OnEvent("Escape", ObjBindMethod(this, "RequestClose"))
    }

    AddButton(x, y, width, text, callback) {
        colors := UiThemeService.GetPalette()
        button := this.Gui.Add("Text", "x" x " y" y " w" width
            " h36 Center 0x200 Background" colors.Toolbar
            " c" colors.ToolbarText, text)
        button.SetFont("s10 bold",
            LocalizationService.GetLanguageSystemUiFontName())
        if !this.Interactions.RegisterButton(button, colors.Toolbar,
                callback, "", "", false, colors.ToolbarText)
            button.OnEvent("Click", callback)
        return button
    }

    ApplyCommandIcons() {
        colors := UiThemeService.GetPalette()
        this.Interactions.SetButtonLucideIcon(this.UpdateButton,
            "refresh-cw-action.svg", 15, 7, UiThemeService.Color("Primary"))
        this.Interactions.SetButtonLucideIcon(this.DonationButton,
            "heart.svg", 15, 7,
            UiThemeService.ButtonIconColor(colors.Danger))
        this.Interactions.SetButtonSvgIcon(this.ProjectButton,
            GetApplicationAssetPath("ui-icons\external-link.svg"), 14, 7,
            UiThemeService.ButtonIconColor(colors.RulesEventIcon))
    }

    RefreshButtonTooltips() {
        this.Interactions.SetButtonTooltip(this.DonationButton,
            Tr("快揭不开锅了（≥Д≤）"))
        this.Interactions.SetButtonTooltip(this.ProjectButton,
            Tr("点个 star 吧~"))
    }

    Show() {
        if this.Disposed
            return false
        return ShowPreparedWindow(this.Gui,
            "w" this.WindowWidth " h" this.WindowHeight,
            ObjBindMethod(this, "ApplyNativeThemes"))
    }

    Activate() {
        if this.Disposed
            return false
        return ActivatePreparedWindow(this.Gui)
    }

    ApplyNativeThemes(*) {
        if this.Disposed
            return false
        return ApplyDarkWindow(this.Gui.Hwnd)
    }

    ApplyAppearance() {
        if this.Disposed
            return false
        BeginStableWindowUpdate(this.Gui.Hwnd)
        try {
            colors := UiThemeService.GetPalette()
            fontName := LocalizationService.GetUiFontName()
            systemFont := LocalizationService.GetLanguageSystemUiFontName()
            this.Gui.Title := Tr("关于")
            this.Gui.BackColor := colors.Window
            this.Interactions.SetParentColor(colors.Window)
            this.ProductName.Text := Tr("键鼠重映射小助手")
            this.ProductName.SetFont("bold s14 c" colors.Text, systemFont)
            this.Subtitle.Text := Tr(
                "让每一条键鼠映射都可录制、可审阅、可掌控")
            this.Subtitle.SetFont("norm s10 c" colors.Muted, fontName)
            this.VersionLabel.Text := Tr("当前版本")
            this.RuntimeLabel.Text := Tr("运行环境")
            for label in [this.VersionLabel, this.RuntimeLabel]
                label.SetFont("norm s10 c" colors.Muted, fontName)
            this.VersionValue.Text := GetApplicationEditionSummary()
            this.RuntimeValue.Text := GetAutoHotkeyRuntimeSummary()
            for value in [this.VersionValue, this.RuntimeValue]
                value.SetFont("norm s11 c" colors.Text, fontName)
            for divider in [this.TopDivider, this.InfoDivider,
                    this.BottomDivider]
                divider.Opt("Background" colors.Divider)
            buttonSpecs := [
                {Button: this.UpdateButton,
                    Text: this.UpdateCheckActive
                        ? Tr("正在检查更新…") : Tr("检查更新"),
                    Interactive: !this.UpdateCheckActive},
                {Button: this.DonationButton, Text: Tr("打赏"),
                    Interactive: true},
                {Button: this.ProjectButton, Text: Tr("开源地址"),
                    Interactive: true}
            ]
            for spec in buttonSpecs {
                this.Interactions.SetTextNoErase(spec.Button, spec.Text)
                this.Interactions.SetButtonAppearance(spec.Button,
                    colors.Toolbar, colors.ToolbarText, spec.Interactive)
                spec.Button.SetFont("s10 bold", systemFont)
            }
            this.ApplyCommandIcons()
            this.RefreshButtonTooltips()
            this.ApplyNativeThemes()
        } finally EndStableWindowUpdate(this.Gui.Hwnd, true)
        return true
    }

    CheckForUpdates(*) {
        if this.Disposed || this.UpdateCheckActive
            return false
        this.SetUpdateCheckActive(true)
        started := this.App.BeginApplicationUpdateCheck(true, this.Gui)
        this.SetUpdateCheckActive(this.App.UpdateService.IsChecking())
        return started
    }

    SetUpdateCheckActive(active) {
        this.UpdateCheckActive := !!active
        if this.Disposed || !this.UpdateButton
            return false
        text := this.UpdateCheckActive ? Tr("正在检查更新…")
            : Tr("检查更新")
        this.Interactions.SetTextNoErase(this.UpdateButton, text)
        this.Interactions.SetButtonAppearance(this.UpdateButton,
            UiThemeService.Color("Toolbar"),
            UiThemeService.Color("ToolbarText"), !this.UpdateCheckActive)
        return true
    }

    OpenProjectHomepage(*) {
        if !this.Disposed
            try Run(AboutWindow.ProjectHomeUrl)
    }

    OpenDonation(*) {
        if this.Disposed
            return false
        return this.App.OpenDonation(this)
    }

    OnDonationClosed(donationWindow) {
        return this.App.OnDonationClosed(donationWindow)
    }

    RequestClose(*) => this.Dispose()

    Dispose(activateOwner := true) {
        if this.Disposed
            return
        this.Disposed := true
        cleanup := CleanupCollector("关于窗口")
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
        if cleanup.Run("释放窗口图标",
                () => ReleaseApplicationWindowIcons(this.IconHandles))
            this.IconHandles := []
        cleanup.Run("通知父窗口",
            () => this.OwnerWindow.OnAboutClosed(this))
        if activateOwner
            cleanup.Run("恢复父窗口", () =>
                WindowHierarchy.CompleteClose(closeContext))
        cleanup.Complete()
        return true
    }
}
