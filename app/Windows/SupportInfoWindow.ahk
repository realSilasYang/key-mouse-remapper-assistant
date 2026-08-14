; 主窗口的帮助入口。
; 窗口只负责在使用说明、事件查看和反馈页面之间分流；选择后先释放
; 主窗口的 Owner 租约，再打开目标内容，避免形成无意义的三级窗口关系。

class SupportInfoWindow {
    static FeedbackUrl :=
        "https://github.com/realSilasYang/key-mouse-remapper-assistant/issues/new/choose"

    __New(ownerWindow) {
        this.OwnerWindow := ownerWindow
        this.App := ownerWindow.App
        this.Gui := ""
        this.OwnerLease := ""
        this.IconHandles := []
        this.Interactions := ""
        this.Disposed := false
        try this.Build()
        catch as buildError {
            try this.Dispose()
            throw buildError
        }
    }

    Build() {
        colors := UiThemeService.GetPalette()
        compactLayout := LocalizationService.UsesCompactLayout()
        this.WindowWidth := compactLayout ? 220 : 300
        this.ButtonWidth := compactLayout ? 150 : 220
        buttonX := (this.WindowWidth - this.ButtonWidth) // 2

        this.Gui := Gui("+Owner" this.OwnerWindow.Gui.Hwnd
            " +OwnDialogs +MinimizeBox -MaximizeBox", Tr("帮助"))
        this.IconHandles := ApplyApplicationWindowIcon(this.Gui.Hwnd)
        this.OwnerLease := WindowHierarchy.Acquire(this.OwnerWindow.Gui,
            this.Gui.Hwnd)
        if !this.OwnerLease
            throw Error("无法建立帮助窗口层级。")
        this.Gui.BackColor := colors.Window
        this.Gui.MarginX := 0
        this.Gui.MarginY := 0
        this.Gui.SetFont("norm s10 c" colors.Text,
            LocalizationService.GetUiFontName())
        this.Interactions := MappingUiInteractions(this.Gui, colors.Window,
            this.App.SvgRenderer)

        this.GuideButton := this.AddButton(buttonX, 18, Tr("使用说明"),
            ObjBindMethod(this, "OpenGuide"))
        this.EventButton := this.AddButton(buttonX, 62, Tr("事件查看"),
            ObjBindMethod(this, "OpenEventViewer"))
        this.FeedbackButton := this.AddButton(buttonX, 106, Tr("提交反馈"),
            ObjBindMethod(this, "OpenFeedback"))
        this.ApplyCommandIcons()
        this.Interactions.SetButtonTooltip(this.FeedbackButton,
            Tr("找作者对线"))

        this.Gui.OnEvent("Close", ObjBindMethod(this, "RequestClose"))
        this.Gui.OnEvent("Escape", ObjBindMethod(this, "RequestClose"))
    }

    AddButton(x, y, text, callback) {
        colors := UiThemeService.GetPalette()
        button := this.Gui.Add("Text", "x" x " y" y " w"
            this.ButtonWidth " h36 Center 0x200 Background" colors.Toolbar
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
        this.Interactions.SetButtonLucideIcon(this.GuideButton,
            "book-open.svg", 16, 7,
            UiThemeService.ButtonIconColor(colors.DisplayIcon))
        this.Interactions.SetButtonLucideIcon(this.EventButton,
            "logs.svg", 16, 7,
            UiThemeService.ButtonIconColor(colors.CodeType))
        this.Interactions.SetButtonLucideIcon(this.FeedbackButton,
            "message-square-text.svg", 16, 7,
            UiThemeService.ButtonIconColor(colors.RulesEventIcon))
    }

    Show() {
        if this.Disposed
            return false
        return ShowPreparedWindow(this.Gui,
            "w" this.WindowWidth " h160",
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
            systemFont := LocalizationService.GetLanguageSystemUiFontName()
            this.Gui.Title := Tr("帮助")
            this.Gui.BackColor := colors.Window
            this.Interactions.SetParentColor(colors.Window)
            buttonSpecs := [
                {Button: this.GuideButton, Text: Tr("使用说明")},
                {Button: this.EventButton, Text: Tr("事件查看")},
                {Button: this.FeedbackButton, Text: Tr("提交反馈")}
            ]
            for spec in buttonSpecs {
                this.Interactions.SetTextNoErase(spec.Button, spec.Text)
                this.Interactions.SetButtonAppearance(spec.Button,
                    colors.Toolbar, colors.ToolbarText, true)
                spec.Button.SetFont("s10 bold", systemFont)
            }
            this.ApplyCommandIcons()
            this.Interactions.SetButtonTooltip(this.FeedbackButton,
                Tr("找作者对线"))
            this.ApplyNativeThemes()
        } finally EndStableWindowUpdate(this.Gui.Hwnd, true)
        return true
    }

    OpenGuide(*) {
        if this.Disposed
            return false
        this.Dispose(false)
        return this.App.OpenHelp()
    }

    OpenEventViewer(*) {
        if this.Disposed
            return false
        this.Dispose(false)
        return this.App.OpenEventViewer()
    }

    OpenFeedback(*) {
        if this.Disposed
            return false
        ownerWindow := this.OwnerWindow
        this.Dispose(false)
        try {
            Run(SupportInfoWindow.FeedbackUrl)
            return true
        } catch as openError {
            ownerWindow.SetStatus(Tr("无法打开反馈页面：{1}",
                openError.Message), true)
            return false
        }
    }

    RequestClose(*) => this.Dispose()

    Dispose(activateOwner := true) {
        if this.Disposed
            return
        this.Disposed := true
        cleanup := CleanupCollector("支持信息窗口")
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
            () => this.OwnerWindow.OnSupportInfoClosed(this))
        if activateOwner
            cleanup.Run("恢复父窗口", () =>
                WindowHierarchy.CompleteClose(closeContext))
        cleanup.Complete()
        return true
    }
}
