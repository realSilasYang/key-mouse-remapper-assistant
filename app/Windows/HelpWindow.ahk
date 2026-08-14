; 内置使用说明窗口。
; 以只读文本展示当前版本功能，保留选择和复制能力；窗口关闭只恢复主窗口，
; 不停止映射运行时，也不会改变当前列表选择或排序。

class HelpWindow {
    static CompactWidth := 660
    static ExpandedWidth := 760
    static TextCache := Map()

    __New(ownerWindow) {
        this.OwnerWindow := ownerWindow
        this.App := ownerWindow.App
        this.Gui := ""
        this.OwnerLease := ""
        this.IconHandles := []
        this.Interactions := ""
        this.TextEdit := ""
        this.HideCaretTimer := ObjBindMethod(this, "HideCaretNow")
        this.Disposed := false
        try this.Build()
        catch as buildError {
            try this.Dispose()
            throw buildError
        }
    }

    Build() {
        colors := UiThemeService.GetPalette()
        this.WindowWidth := LocalizationService.UsesCompactLayout()
            ? HelpWindow.CompactWidth : HelpWindow.ExpandedWidth
        this.Gui := Gui("+Owner" this.OwnerWindow.Gui.Hwnd
            " +OwnDialogs -MinimizeBox -MaximizeBox", Tr("使用说明"))
        this.IconHandles := ApplyApplicationWindowIcon(this.Gui.Hwnd)
        this.OwnerLease := WindowHierarchy.Acquire(this.OwnerWindow.Gui,
            this.Gui.Hwnd)
        if !this.OwnerLease
            throw Error("无法建立使用说明窗口层级。")
        this.Gui.BackColor := colors.Window
        this.Gui.MarginX := 14
        this.Gui.MarginY := 14
        this.Gui.SetFont("norm s11 c" colors.Text,
            LocalizationService.GetUiFontName())
        this.Interactions := MappingUiInteractions(this.Gui, colors.Window,
            this.App.SvgRenderer)

        this.TextEdit := this.Gui.Add("Edit", "w" (this.WindowWidth - 28)
            " r23 ReadOnly Multi VScroll -E0x200 Background" colors.Surface
            " c" colors.Text, this.BuildText())
        if !this.Interactions.RegisterTextInput(this.TextEdit)
            throw Error("无法注册使用说明文本交互。")
        this.TextEdit.OnEvent("Focus", ObjBindMethod(this,
            "ScheduleHideCaret"))
        ApplyDarkControl(this.TextEdit.Hwnd)
        this.Gui.OnEvent("Close", ObjBindMethod(this, "RequestClose"))
        this.Gui.OnEvent("Escape", ObjBindMethod(this, "RequestClose"))
    }

    BuildText() {
        cacheKey := LocalizationService.GetLanguage() "|"
            (HasCommandLineFlag("--packaged") ? "portable"
                : (A_IsCompiled ? "compiled" : "source"))
        if HelpWindow.TextCache.Has(cacheKey)
            return HelpWindow.TextCache[cacheKey]
        lines := [
            "",
            Tr("键鼠重映射小助手用于录制、审阅和维护键盘与鼠标映射。关闭主窗口只会隐藏到系统托盘，已经启用的映射仍会继续生效。"),
            "",
            Tr("一、快速上手"),
            Tr("• 点击顶部“新增”，会打开已经填好元数据字段的 @mapping 编辑器；也可以在下方分别录制来源按键和目标按键，填写名称后保存。"),
            Tr("• 录制会实时显示原始规范名称、阅读友好名称、虚拟键码和扫描码，并区分左右 Ctrl、Shift、Alt、Win 以及键盘、鼠标和滚轮输入。"),
            "",
            Tr("二、主界面与代码编辑"),
            Tr("• 单击选择映射；双击条目、选中后按 F2 或使用右键菜单，可编辑完整 @mapping 代码块。"),
            Tr("• 选中条目后可暂停、恢复或删除；直接拖动列表行可调整永久顺序，脚本中的代码块顺序会实时同步。"),
            Tr("• 新增、删除、暂停或恢复、代码编辑、拖动排序和规则包导入均可撤销；Ctrl+Z 撤销，Ctrl+Shift+Z 或 Ctrl+Y 重做。"),
            Tr("• 点击伪表头只进行临时排序；字段按升序、降序、自定义顺序循环，序号列按降序、自定义顺序循环，不会改写脚本。"),
            "",
            Tr("三、规则与生效范围"),
            Tr("• 映射区域以注释形式保存规则块和受托管脚本。规则块在主进程热应用；受托管脚本的自定义 AHK v2 源码在独立受管进程运行，保存、暂停、恢复、删除和退出均由小助手统一管理。"),
            Tr("• 所有规则属于同一全局规则集；生效范围和条件可在 @mapping 编辑器中精确调整，保存后会立即重新选择生效规则。"),
            "",
            Tr("四、事件查看与设置"),
            Tr("• 事件查看记录输入、规则匹配、条件拒绝、执行结果、仓储和系统事件，支持筛选、暂停、清空及 JSONL 导出。"),
            Tr("五、后台运行与问题排查"),
            Tr("• 主窗口关闭后程序仍驻留托盘。托盘可以重新显示主界面、手动重新加载或彻底退出；修改映射规则后通常不需要手动重新加载。"),
            Tr("• “帮助”还可打开项目反馈页面。提交问题时请说明系统版本、复现步骤、相关 @mapping 代码和事件导出，并在公开前移除敏感路径或应用信息。"),
            "",
            Tr("当前版本") ": " GetApplicationEditionSummary(),
            Tr("运行环境") ": " GetAutoHotkeyRuntimeSummary()
        ]
        text := ""
        for index, line in lines
            text .= (index > 1 ? "`r`n" : "") line
        HelpWindow.TextCache[cacheKey] := text
        return text
    }

    Show() {
        if this.Disposed
            return false
        shown := ShowPreparedWindow(this.Gui, "AutoSize",
            ObjBindMethod(this, "ApplyNativeThemes"))
        if shown {
            SendMessage(Win32.EM_SETSEL, 0, 0, , this.TextEdit.Hwnd)
            SendMessage(0x00B7, 0, 0, , this.TextEdit.Hwnd) ; EM_SCROLLCARET
            this.ScheduleHideCaret()
        }
        return shown
    }

    Activate() {
        if this.Disposed
            return false
        return ActivatePreparedWindow(this.Gui)
    }

    ScheduleHideCaret(*) {
        if !this.Disposed
            SetTimer(this.HideCaretTimer, -1)
    }

    HideCaretNow(*) {
        if this.Disposed || !IsObject(this.TextEdit)
            return
        try DllCall("user32\HideCaret", "Ptr", this.TextEdit.Hwnd, "Int")
    }

    ApplyNativeThemes(*) {
        if this.Disposed
            return false
        ApplyDarkWindow(this.Gui.Hwnd)
        ApplyDarkControl(this.TextEdit.Hwnd)
        return true
    }

    ApplyAppearance() {
        if this.Disposed
            return false
        BeginStableWindowUpdate(this.Gui.Hwnd)
        try {
            colors := UiThemeService.GetPalette()
            this.Gui.Title := Tr("使用说明")
            this.Gui.BackColor := colors.Window
            this.Interactions.SetParentColor(colors.Window)
            this.TextEdit.Value := this.BuildText()
            this.TextEdit.Opt("Background" colors.Surface " c" colors.Text)
            this.TextEdit.SetFont("norm s11 c" colors.Text,
                LocalizationService.GetUiFontName())
            this.ApplyNativeThemes()
            SendMessage(Win32.EM_SETSEL, 0, 0, , this.TextEdit.Hwnd)
            SendMessage(0x00B7, 0, 0, , this.TextEdit.Hwnd)
            this.ScheduleHideCaret()
        } finally EndStableWindowUpdate(this.Gui.Hwnd, true)
        return true
    }

    RequestClose(*) => this.Dispose()

    Dispose(activateOwner := true) {
        if this.Disposed
            return
        this.Disposed := true
        cleanup := CleanupCollector("帮助窗口")
        if cleanup.Run("停止光标计时器",
                () => SetTimer(this.HideCaretTimer, 0))
            this.HideCaretTimer := ""
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
        this.TextEdit := ""
        cleanup.Run("通知父窗口", () => this.OwnerWindow.OnHelpClosed(this))
        if activateOwner
            cleanup.Run("恢复父窗口", () =>
                WindowHierarchy.CompleteClose(closeContext))
        cleanup.Complete()
        return true
    }
}
