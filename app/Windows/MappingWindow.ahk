class MappingWindow {
    static DefaultClientWidth := 1040
    static DefaultClientHeight := 650
    static MinClientWidth := 760
    static ExpandedMinClientWidth := 920
    static BaseMinClientHeight := 492
    static MinListHeight := 160
    static ListRowHeight := 36
    static SmoothScrollFastIntervalMs := 12
    static SmoothScrollSlowIntervalMs := 40
    static SmoothScrollAccelerationLines := 8
    static SmoothScrollMaximumQueuedLines := 18
    static SmoothScrollTimerResolutionMs := 1
    static WheelDelta := 120
    static ListWheelSubclassId := 0x4D575343
    static ListTop := 90
    static ListToEditorGap := 10
    static EditorHeadingTopPadding := 6
    static EditorHeadingBandMinHeight := 62
    static CaptureDetailGap := 10
    static EditorToCommandGap := 2
    static MinSourceColumnWidth := 140
    static MinTargetColumnWidth := 140
    static ListTextInsetDip := 10
    static ListStatusIconSlotDip := 20
    static ListStatusIconGapDip := 4
    static SequenceDotDiameterDip := 8
    ; Keep the scope column compact enough for the common four-character
    ; values; the freed space is assigned to the mapping name column.
    static ScopeColumnWidth := 72
    static MinNameColumnWidth := 210
    static StatusColumnWidth := 92
    static MinCaptureButtonHeight := 52
    static NameInputInitialHeight := 28
    static NameInputVisibleLines := 1
    static NameInputHorizontalPadding := 8
    static NameInputVerticalPadding := 3
    static MinCaptureDetailHeight := 72
    static MinStatusHeight := 24
    static StatusBottomMargin := 22
    static CompactToolbarButtonWidth := 70
    static ExpandedToolbarButtonMinWidth := 80
    static SettingsButtonHeight := 30
    static CommandButtonHeight := 30
    static CompactActionButtonWidth := 80
    static ExpandedActionButtonMinWidth := 80
    static ActionIconSlotWidth := 20
    static ActionIconGap := 4
    static ToolbarIconWidth := 15
    static ToolbarIconGap := 6
    static ButtonContentPadding := 16
    static TopButtonGap := 10
    static ToolbarRightMargin := 10
    static SaveButtonWidth := 112
    static ExpandedSaveButtonWidth := 140
    static ClearButtonWidth := 112
    static CommandButtonGap := 8
    static CommandRightMargin := 14
    static DefaultDistinguishModifierSides := false
    ; Keep the primary ListView item as the mapping name, matching the
    ; reference application's stable identity layout. Status is a subitem
    ; displayed on the right, with its icon-text group drawn independently.
    static NameColumn := 1
    static StatusColumn := 2
    static SourceColumn := 3
    static TargetColumn := 4
    static SequenceColumn := 5
    static ScopeColumn := 6
    static EnabledColumn := 7
    static DividerDashWidth := 14
    static DividerDashGap := 7
    static DividerDashHeight := 1
    static Colors := {
        Window: "1E1E1E", Surface: "252526", Input: "252526",
        Toolbar: "333333", Divider: "3A3A3A",
        Text: "FFFFFF",
        Muted: "B8BAB9", Hint: "AFAFAF", Primary: "0078D7",
        Add: "3F6B5B", Delete: "6B4B4B", DeleteDisabled: "554B4B",
        AI: "F2C14E", AIButton: "5A4610", AIButtonText: "FFFFFF",
        Success: "6ED7A0", Danger: "FF8A8A",
        Disabled: "554B4B",
        Pause: "6B6244", PauseDisabled: "555148",
        ButtonText: "FFFFFF", DisabledButtonText: "D8D8D8",
        CodeGutter: "202020", CodeLineNumber: "858585",
        CodeComment: "858585", CodeVariable: "D17A2A",
        CodeValue: "6A8754", CodeKeyword: "C586C0",
        CodeDirective: "C586C0", CodeString: "CE9178",
        CodeNumber: "B5CEA8", CodeFunction: "DCDCAA",
        CodeType: "4EC9B0", CodeProperty: "9CDCFE",
        CodeOperator: "D4D4D4", CodePunctuation: "D4D4D4",
        CodeHotkey: "4FC1FF", CodeLabel: "D7BA7D",
        CodeBuiltin: "4EC9B0", CodeLiteral: "569CD6",
        CodeEscape: "D7BA7D", StatusEnabledIcon: "03C078",
        StatusPausedIcon: "F4A71D"
    }

    __New(app) {
        this.App := app
        this.Gui := ""
        this.IconHandles := []
        this.Interactions := ""
        this.BlockEditor := ""
        this.ContextPopup := ""
        this.CellTooltip := ""
        this.ListSelection := ""
        this.ListHeader := ""
        this.SelectionTimer := ""
        this.SelectionChangedCallback := ""
        this.ListNativeSelectionCallback := ""
        this.ListNativeSelectionRegistered := false
        this.ListKeyDownRegistered := false
        this.ListWheelCallback := ""
        this.ListWheelRegistered := false
        this.ListWheelSubclassMethod := ""
        this.ListWheelSubclassCallback := 0
        this.ListWheelSubclassAttached := false
        this.SmoothListScrollTimer := ""
        this.PendingListScrollLines := 0
        this.ListWheelDeltaRemainder := 0
        this.LastSmoothListScrollIntervalMs := 0
        this.SmoothListTimerResolutionActive := false
        this.ResizeMessagesRegistered := false
        this.HistoryHotkeysRegistered := false
        this.NewMappingHotkeyCallback := ""
        this.EscapeAfterCaptureDeadline := 0
        this.PendingCapturePointerAction := ""
        this.PendingCapturePointerActionTimer := ObjBindMethod(this,
            "RunPendingCapturePointerAction")
        this.CaptureButtonHwnds := Map()
        this.ListRowImageList := 0
        this.ListMetricsImageList := 0
        this.ListRowDpi := 0
        this.ListStatusIconIndices := Map()
        this.NameInputHeight := MappingWindow.NameInputInitialHeight
        this.NameInputMetrics := ""
        this.Disposed := false
        try {
        MappingWindow.Colors := UiThemeService.GetPalette()
        this.FontName := LocalizationService.GetUiFontName()
        this.SystemFontName := LocalizationService.GetLanguageSystemUiFontName()
        this.UpdateLanguageLayoutMetrics()
        this.Gui := Gui("+Resize " UiScaleService.ScaleMinSizeOptions(
            this.MinClientWidth, MappingWindow.BaseMinClientHeight),
            Tr("键鼠重映射小助手"))
        this.IconHandles := ApplyApplicationWindowIcon(this.Gui.Hwnd)
        this.Gui.BackColor := MappingWindow.Colors.Window
        RegisterNativeWindowBackground(this.Gui.Hwnd,
            MappingWindow.Colors.Window)
        ApplyDarkWindow(this.Gui.Hwnd)
        this.Gui.MarginX := 0
        this.Gui.MarginY := 0
        this.Gui.SetFont("s10 c" MappingWindow.Colors.Text, this.FontName)
        this.SourceCapture := ""
        this.TargetCapture := ""
        this.HasShown := false
        this.LastFirstVisiblePresentation := ""
        this.SortColumn := 0
        this.SortDescending := false
        this.SuppressSortStatus := false
        this.DragActive := false
        this.LastDragScrollTicks := 0
        this.RequiredClientHeight := MappingWindow.BaseMinClientHeight
        this.RequiredClientWidth := this.MinClientWidth
        this.LayoutResizeActive := false
        this.LastLayoutSignature := ""
        this.LastLayoutResult := ""
        this.LastChangedLayoutResult := ""
        this.ModifierSidesPreferredWidth := 1
        this.InitialClientWidth := MappingWindow.DefaultClientWidth
        this.InitialClientHeight := MappingWindow.DefaultClientHeight
        this.LastNormalClientWidth := 0
        this.LastNormalClientHeight := 0
        this.StatusIsError := false
        this.StatusRevision := 0
        this.AppliedColumnWidths := Map()
        this.SelectionTimer := ObjBindMethod(this,
            "RefreshSelectionState")
        this.SelectionChangedCallback := ObjBindMethod(this,
            "OnSelectionChanged")
        this.ListNativeSelectionCallback := ObjBindMethod(this,
            "OnNativeSelectionChanged")
        this.ResizeMessageCallback := ObjBindMethod(this,
            "OnInteractiveResizeMessage")
        this.Interactions := MappingUiInteractions(this.Gui,
            MappingWindow.Colors.Window, this.App.SvgRenderer)
        this.BuildControls()
        this.ListWheelCallback := ObjBindMethod(this,
            "HandleListMouseWheel")
        this.SmoothListScrollTimer := ObjBindMethod(this,
            "AdvanceSmoothListScroll")
        this.InstallListWheelSubclass()
        OnMessage(Win32.WM_MOUSEWHEEL, this.ListWheelCallback)
        this.ListWheelRegistered := true
        this.ContextPopup := MappingContextPopupWindow(this)
        this.ListKeyDownCallback := ObjBindMethod(this,
            "HandleListKeyDown")
        OnMessage(Win32.WM_KEYDOWN, this.ListKeyDownCallback)
        this.ListKeyDownRegistered := true
        OnMessage(Win32.WM_ENTERSIZEMOVE, this.ResizeMessageCallback)
        OnMessage(Win32.WM_EXITSIZEMOVE, this.ResizeMessageCallback)
        this.ResizeMessagesRegistered := true
        this.HistoryHotIf := ObjBindMethod(this,
            "CanUseHistoryShortcuts")
        this.UndoHotkeyCallback := ObjBindMethod(this.App,
            "UndoMappingChange")
        this.RedoHotkeyCallback := ObjBindMethod(this.App,
            "RedoMappingChange")
        this.NewMappingHotkeyCallback := ObjBindMethod(this,
            "OpenNewMappingEditor", true)
        this.RegisterHistoryHotkeys()
        this.Gui.OnEvent("Size", ObjBindMethod(this, "OnResize"))
        this.Gui.OnEvent("Close", ObjBindMethod(this, "Hide"))
        this.Gui.OnEvent("Escape", ObjBindMethod(this, "OnEscape"))
        } catch as buildError {
            try this.Dispose()
            throw buildError
        }
    }

    BuildControls() {
        colors := MappingWindow.Colors
        this.AddButton := this.AddCommandButton(10, 15,
            this.AddButtonWidth,
            this.GetAddButtonText(), colors.Add,
            ObjBindMethod(this, "OpenNewMappingEditor", false),
            colors.ButtonText,
            MappingWindow.CommandButtonHeight)
        this.PauseResumeButton := this.AddCommandButton(this.PauseButtonX,
            15,
            this.PauseButtonWidth,
            this.GetPauseButtonText(), colors.PauseDisabled,
            ObjBindMethod(this, "ToggleSelectedMapping"),
            colors.DisabledButtonText, MappingWindow.CommandButtonHeight)
        this.Interactions.SetButtonAppearance(this.PauseResumeButton,
            colors.PauseDisabled, colors.DisabledButtonText, false)
        this.DeleteButton := this.AddCommandButton(this.DeleteButtonX,
            15, this.DeleteButtonWidth,
            this.GetDeleteButtonText(), colors.DeleteDisabled,
            ObjBindMethod(this, "DeleteSelected"),
            colors.DisabledButtonText, MappingWindow.CommandButtonHeight)
        this.Interactions.SetButtonAppearance(this.DeleteButton,
            colors.DeleteDisabled, colors.DisabledButtonText, false)
        selectionCommandPreflight := ObjBindMethod(this,
            "EnsureSelectionCommandState")
        this.Interactions.SetButtonPreflight(this.PauseResumeButton,
            selectionCommandPreflight)
        this.Interactions.SetButtonPreflight(this.DeleteButton,
            selectionCommandPreflight)
        toolbarPositions := this.GetToolbarButtonPositions(
            this.MinClientWidth)
        this.SettingsButton := this.AddCommandButton(
            toolbarPositions.Settings, 15,
            this.SettingsButtonWidth,
            Tr("设置"), colors.Toolbar,
            ObjBindMethod(this.App, "OpenSettings"), "",
            MappingWindow.SettingsButtonHeight)
        this.SupportButton := this.AddCommandButton(
            toolbarPositions.Support, 15, this.SupportButtonWidth,
            Tr("帮助"), colors.Toolbar,
            ObjBindMethod(this.App, "OpenHelpInfo"), "",
            MappingWindow.SettingsButtonHeight)
        this.AboutButton := this.AddCommandButton(
            toolbarPositions.About, 15, this.AboutButtonWidth,
            Tr("关于"), colors.Toolbar,
            ObjBindMethod(this.App, "OpenAbout"), "",
            MappingWindow.SettingsButtonHeight)
        this.ApplyCommandIcons()
        this.UpdateCommandButtonGroupWidths()
        this.RefreshToolbarTooltips()

        this.HeaderLabels := [Tr("序号"), Tr("名称"), Tr("来源按键"),
            Tr("映射结果"), Tr("生效范围"), Tr("状态")]
        this.Gui.SetFont("s12 c" colors.Text, this.FontName)
        this.List := this.Gui.Add("ListView",
            "x10 y90 w960 h322 Report +ReadOnly -Hdr Background" colors.Surface
            " c" colors.Text " +LV0x10002 -E0x200 -HScroll",
            [Tr("名称"), Tr("状态"), Tr("来源按键"), Tr("映射结果"),
                Tr("序号"), Tr("生效范围"), "启用状态"])
        if !this.ApplyListColumnOrder()
            throw Error("Unable to apply the mapping-list column order.")
        this.EnsureListRowMetrics()
        this.List.OnEvent("ItemSelect", this.SelectionChangedCallback)
        this.List.OnEvent("ItemFocus", this.SelectionChangedCallback)
        this.List.OnNotify(-101, this.ListNativeSelectionCallback)
        this.ListNativeSelectionRegistered := true
        this.List.OnEvent("DoubleClick", ObjBindMethod(this, "OnListDoubleClick"))
        this.List.OnEvent("ContextMenu", ObjBindMethod(this, "OnListContextMenu"))
        this.List.OnNotify(-109, ObjBindMethod(this, "OnListBeginDrag"))
        this.CellTooltip := ListCellTooltipWindow(this.List,
            MappingWindow.NameColumn, MappingWindow.ScopeColumn,
            ObjBindMethod(this, "GetListCellTextAvailableWidth"))
        this.ListSelection := ListViewSelectionPresenter(this.List,
            this.Interactions.Painter, ObjBindMethod(this,
                "DrawListSubItem"))
        this.ListHeader := ListViewPseudoHeader(this.Gui, this.List, [
            {Column: MappingWindow.SequenceColumn, Label: Tr("序号"),
                Align: "Center", SortOptions: "Integer", SkipAscending: true},
            {Column: MappingWindow.NameColumn, Label: Tr("名称"),
                Align: "Left", HeaderAlign: "Center",
                SortOptions: "Logical"},
            {Column: MappingWindow.SourceColumn, Label: Tr("来源按键"),
                Align: "Left", HeaderAlign: "Center",
                SortOptions: "Logical"},
            {Column: MappingWindow.TargetColumn, Label: Tr("映射结果"),
                Align: "Left", HeaderAlign: "Center",
                SortOptions: "Logical"},
            {Column: MappingWindow.ScopeColumn, Label: Tr("生效范围"),
                Align: "Center", SortOptions: "Logical"},
            {Column: MappingWindow.StatusColumn, Label: Tr("状态"),
                Align: "Left", HeaderAlign: "Center",
                SortOptions: "Logical"}
        ], {
            BackgroundColor: colors.Toolbar,
            TextColor: colors.Muted,
            FontName: this.SystemFontName,
            CursorRegistrar: ObjBindMethod(this.Interactions,
                "RegisterHandCursor"),
            RestoreColumn: MappingWindow.SequenceColumn,
            RestoreSortOptions: "Integer Center",
            OnSortChanged: ObjBindMethod(this, "OnHeaderSortChanged")
        })
        this.Gui.SetFont("s10 c" colors.Text, this.FontName)

        this.SectionTopDivider := this.Gui.Add("Text",
            "x10 y396 w960 h4 Background" colors.Window)
        if !this.Interactions.RegisterDashedDivider(this.SectionTopDivider,
                colors.Window, colors.DividerAccent,
                MappingWindow.DividerDashWidth, MappingWindow.DividerDashGap,
                MappingWindow.DividerDashHeight)
            throw Error("Unable to register the mapping-section divider.")
        this.SectionTitle := this.Gui.Add("Text",
            "x10 y400 w960 h24 Center 0x200 Background" colors.Window
                " c" colors.Text,
            Tr("新建映射"))
        this.SectionTitle.SetFont("s11 bold", this.SystemFontName)
        this.DistinguishModifierSidesCheck := this.Gui.Add("CheckBox",
            "x0 y400 h24 c" colors.Text,
            Tr("区分左右修饰键"))
        this.DistinguishModifierSidesCheck.SetFont("s10", this.FontName)
        this.RefreshModifierSidesPreferredWidth()
        this.DistinguishModifierSidesCheck.Value :=
            MappingWindow.DefaultDistinguishModifierSides ? 1 : 0
        this.DistinguishModifierSidesCheck.OnEvent("Click",
            ObjBindMethod(this, "OnModifierSideDisplayChanged"))
        ApplyDarkControl(this.DistinguishModifierSidesCheck.Hwnd)
        this.Interactions.RegisterHandCursor(
            this.DistinguishModifierSidesCheck)

        this.SourceLabel := this.Gui.Add("Text", "x10 y434 w80 h20 Background" colors.Window " c" colors.Muted,
            Tr("来源按键"))
        this.TargetLabel := this.Gui.Add("Text", "x334 y434 w80 h20 Background" colors.Window " c" colors.Muted,
            Tr("映射为"))
        this.NameLabel := this.Gui.Add("Text", "x654 y434 w80 h20 Background" colors.Window " c" colors.Muted,
            Tr("名称"))

        this.SourceButton := this.Gui.Add("Text",
            "x10 y458 w280 h52 Center +Wrap Background" colors.Toolbar " c" colors.Text,
            Tr("点击录制来源按键"))
        sourceCallback := ObjBindMethod(this, "BeginCapture", "source")
        if !this.Interactions.RegisterButton(this.SourceButton, colors.Toolbar,
            sourceCallback, "", "", true)
            this.SourceButton.OnEvent("Click", sourceCallback)
        else
            this.Interactions.SetButtonPointerDownHandler(this.SourceButton,
                ObjBindMethod(this, "OnCaptureButtonPointerDown"))
        this.CaptureButtonHwnds[this.SourceButton.Hwnd] := "source"
        this.Interactions.SetButtonTooltip(this.SourceButton,
            Tr("演奏你的和弦！"))
        this.ArrowText := this.Gui.Add("Text", "x300 y463 w28 h24 Center Background" colors.Window " c" colors.Hint,
            "")
        if !this.Interactions.RegisterIconSurface(this.ArrowText,
                colors.Window, colors.Hint)
            throw Error("无法注册映射方向图标。")
        if !this.Interactions.SetControlLucideIcon(this.ArrowText,
                "arrow-right.svg", 20, 0,
                UiThemeService.ButtonIconColor(colors.RulesEventIcon))
            throw Error("无法加载映射方向图标。")
        this.TargetButton := this.Gui.Add("Text",
            "x334 y458 w280 h52 Center +Wrap Background" colors.Toolbar " c" colors.Text,
            Tr("点击录制目标按键"))
        targetCallback := ObjBindMethod(this, "BeginCapture", "target")
        if !this.Interactions.RegisterButton(this.TargetButton, colors.Toolbar,
            targetCallback, "", "", true)
            this.TargetButton.OnEvent("Click", targetCallback)
        else
            this.Interactions.SetButtonPointerDownHandler(this.TargetButton,
                ObjBindMethod(this, "OnCaptureButtonPointerDown"))
        this.CaptureButtonHwnds[this.TargetButton.Hwnd] := "target"
        this.Interactions.SetButtonTooltip(this.TargetButton,
            Tr("演奏你的和弦！"))
        this.RefreshCaptureButtonIcons()
        this.NameInput := AddPaddedMultilineEdit(this.Gui,
            654, 458, 312, this.NameInputHeight,
            colors.Input, colors.Text)
        this.NameEdit := this.NameInput.Edit
        this.NameEdit.Opt("-WantReturn +0x40 -TabStop")
        this.NameEdit.SetFont("norm s11 c" colors.Text, this.FontName)
        this.RefreshNameInputMetrics(0, true)
        this.ApplyNameInputViewport()
        this.NameEdit.OnEvent("Change", ObjBindMethod(this,
            "OnNameInputChanged"))
        if !this.Interactions.RegisterTextInput(this.NameEdit,
                this.NameInput.Background)
            throw Error("无法注册名称输入框交互。")
        if !this.Interactions.EnableHiddenVerticalWheelScroll(this.NameEdit)
            throw Error("无法注册名称输入框隐藏滚动交互。")
        ApplyDarkControl(this.NameEdit.Hwnd)
        this.ApplyNameInputViewport()

        this.SourceDetail := this.Gui.Add("Text",
            "x10 y514 w280 h72 +Wrap Background" colors.Window " c" colors.Hint,
            this.GetCaptureDetail(""))
        this.TargetDetail := this.Gui.Add("Text",
            "x334 y514 w280 h72 +Wrap Background" colors.Window " c" colors.Hint,
            this.GetCaptureDetail(""))
        this.SourceDetail.SetFont("s10", this.FontName)
        this.TargetDetail.SetFont("s10", this.FontName)

        mappingClearButtonX := MappingWindow.DefaultClientWidth
            - MappingWindow.CommandRightMargin
            - MappingWindow.ClearButtonWidth
        mappingSaveButtonX := mappingClearButtonX
            - MappingWindow.CommandButtonGap
            - this.SaveButtonWidth
        this.SaveButton := this.AddCommandButton(mappingSaveButtonX, 514,
            this.SaveButtonWidth,
            Tr("保存映射"), colors.Toolbar,
            ObjBindMethod(this, "SaveMapping"), "",
            MappingWindow.CommandButtonHeight)
        this.Interactions.ClearButtonIcon(this.SaveButton)
        this.ClearButton := this.AddCommandButton(mappingClearButtonX, 514,
            MappingWindow.ClearButtonWidth,
            Tr("清空"), colors.Toolbar,
            ObjBindMethod(this, "ClearEditor"), "",
            MappingWindow.CommandButtonHeight)
        this.Interactions.ClearButtonIcon(this.ClearButton)
        this.CaptureButtonHwnds[this.ClearButton.Hwnd] := "clear"
        this.Status := this.Gui.Add("Edit",
            "x10 y604 w1020 h24 ReadOnly Multi Wrap -TabStop -Border"
                . " -VScroll -HScroll -E0x200 Background" colors.Window
                . " c" colors.Muted,
            Tr("准备就绪"))
        ApplyDarkControl(this.Status.Hwnd)
        if !this.Interactions.RegisterTextInput(this.Status, "", "text", true)
            throw Error("无法注册主窗口状态复制交互。")
        if !this.Interactions.SuppressTextInputWheelScroll(this.Status)
            throw Error("无法固定主窗口状态文字视口。")
        this.Interactions.SetFocusSink(this.Status)
        this.NormalizeStatusViewport()
    }

    AddCommandButton(x, y, width, text, color, callback, textColor := "",
            height := MappingWindow.CommandButtonHeight) {
        if textColor == ""
            textColor := MappingWindow.Colors.Text
        button := this.Gui.Add("Text", "x" x " y" y " w" width
            " h" height " Center 0x200 Background" color " c" textColor, text)
        button.SetFont("s10 bold", this.SystemFontName)
        if !this.Interactions.RegisterButton(button, color, callback,
                "", "", false, textColor)
            button.OnEvent("Click", callback)
        return button
    }

    ApplyCommandIcons() {
        colors := MappingWindow.Colors
        for button in [this.AddButton, this.PauseResumeButton,
                this.DeleteButton] {
            this.Interactions.ClearButtonIcon(button)
            this.Interactions.SetButtonLeadingTextSlot(button, 20, 4, 10)
        }
        for item in [
            {Button: this.SettingsButton, Icon: "settings.svg",
                LightColor: colors.Muted},
            {Button: this.SupportButton, Icon: "circle-question-mark.svg",
                LightColor: colors.DisplayIcon},
            {Button: this.AboutButton, Icon: "circle-info.svg",
                LightColor: colors.RulesEventIcon}
        ] {
            this.Interactions.SetButtonLucideIcon(item.Button,
                item.Icon, 15, 6,
                UiThemeService.ButtonIconColor(item.LightColor))
        }
    }

    RefreshToolbarTooltips() {
        this.Interactions.SetButtonTooltip(this.SettingsButton,
            Tr("配置显示、规则包和事件选项"))
        this.Interactions.SetButtonTooltip(this.SupportButton,
            Tr("打开帮助`n可选择查看使用说明、运行日志或提交反馈"))
        this.Interactions.SetButtonTooltip(this.AboutButton,
            Tr("查看版本、运行环境和项目入口"))
    }

    GetAddButtonText() => "➕ " Tr("新增")

    GetPauseButtonText(mode := "pause") {
        if mode == true || mode == "resume"
            return "▶️ " Tr("恢复")
        if mode == "mixed"
            return "🔄 " Tr("反转状态")
        return "⏸️ " Tr("暂停")
    }

    GetDeleteButtonText() => "🗑️ " Tr("删除")

    GetToolbarButtonPositions(clientWidth) {
        aboutX := clientWidth - MappingWindow.ToolbarRightMargin
            - this.AboutButtonWidth
        supportX := aboutX - MappingWindow.TopButtonGap
            - this.SupportButtonWidth
        settingsX := supportX - MappingWindow.TopButtonGap
            - this.SettingsButtonWidth
        return {Settings: settingsX, Support: supportX, About: aboutX}
    }

    RegisterHistoryHotkeys() {
        this.SetHistoryHotkeyState(true)
        return true
    }

    SetHistoryHotkeyState(enabled) {
        bindings := [
            {Name: "^z", Callback: this.UndoHotkeyCallback},
            {Name: "^+z", Callback: this.RedoHotkeyCallback},
            {Name: "^y", Callback: this.RedoHotkeyCallback},
            {Name: "^n", Callback: this.NewMappingHotkeyCallback}
        ]
        changedBindings := []
        try {
            HotIf(this.HistoryHotIf)
            for binding in bindings {
                if enabled
                    Hotkey(binding.Name, binding.Callback, "On")
                else
                    Hotkey(binding.Name, "Off")
                changedBindings.Push(binding)
            }
            this.HistoryHotkeysRegistered := !!enabled
        } catch as hotkeyError {
            for binding in changedBindings {
                try {
                    if enabled
                        Hotkey(binding.Name, "Off")
                    else
                        Hotkey(binding.Name, binding.Callback, "On")
                }
            }
            throw hotkeyError
        } finally HotIf()
        return true
    }

    CanUseHistoryShortcuts(*) {
        if this.Disposed || !WinActive("ahk_id " this.Gui.Hwnd)
            return false
        return this.IsShortcutFocusEligible()
    }

    IsShortcutFocusEligible(focusedHwnd := 0) {
        if !focusedHwnd
            focusedHwnd := DllCall("user32\GetFocus", "Ptr")
        if !focusedHwnd
            return true
        try className := WinGetClass("ahk_id " focusedHwnd)
        catch
            return true
        if className != "Edit" && !InStr(className, "RichEdit")
            return true
        ; The status Edit is the main window's deliberate focus sink. AHK's
        ; ReadOnly option is applied through the native control state on some
        ; versions and is not always reflected in GWL_STYLE.
        if IsObject(this.Status) && focusedHwnd == this.Status.Hwnd
            return true
        style := DllCall("user32\GetWindowLongPtrW", "Ptr", focusedHwnd,
            "Int", Win32.GWL_STYLE, "Ptr")
        return (style & 0x0800) != 0 ; ES_READONLY
    }

    HandleListKeyDown(wParam, lParam, msg, hwnd) {
        if this.Disposed || hwnd != this.List.Hwnd
            return
        this.StopSmoothListScroll(true)
        this.QueueSelectionRefresh()
        return this.HandleListCommand(wParam, lParam,
            GetKeyState("Ctrl", "P"), GetKeyState("Shift", "P"),
            GetKeyState("Alt", "P"))
    }

    HandleListMouseWheel(wParam, lParam, msg, hwnd) {
        if this.Disposed || this.DragActive
                || !this.IsMessageFromMainWindow(hwnd)
                || !this.IsScreenPointInsideList(lParam, hwnd)
            return
        wheelDelta := this.SignedWord(wParam >> 16)
        return this.ProcessListWheelDelta(wheelDelta)
    }

    IsMessageFromMainWindow(hwnd) {
        if !hwnd || !IsObject(this.Gui) || !this.Gui.Hwnd
                || !DllCall("user32\IsWindow", "Ptr", hwnd, "Int")
            return false
        rootHwnd := DllCall("user32\GetAncestor", "Ptr", hwnd,
            "UInt", 2, "Ptr") ; GA_ROOT, deliberately excludes owners.
        return rootHwnd == this.Gui.Hwnd
    }

    ProcessListWheelDelta(wheelDelta) {
        if !wheelDelta
            return 0
        scrollLines := this.GetSystemWheelScrollLines()
        if !scrollLines {
            this.StopSmoothListScroll(true)
            return 0
        }
        if this.ListWheelDeltaRemainder
                && (this.ListWheelDeltaRemainder > 0) != (wheelDelta > 0)
            this.ListWheelDeltaRemainder := 0
        this.ListWheelDeltaRemainder += wheelDelta
        wheelNotches := this.ListWheelDeltaRemainder > 0
            ? Floor(this.ListWheelDeltaRemainder / MappingWindow.WheelDelta)
            : Ceil(this.ListWheelDeltaRemainder / MappingWindow.WheelDelta)
        if wheelNotches {
            this.ListWheelDeltaRemainder -= wheelNotches
                * MappingWindow.WheelDelta
            this.QueueSmoothListScroll(-wheelNotches * scrollLines)
        }
        return 0
    }

    InstallListWheelSubclass() {
        this.ListWheelSubclassMethod := ObjBindMethod(this,
            "ListWheelSubclassProc")
        this.ListWheelSubclassCallback := CallbackCreate(
            this.ListWheelSubclassMethod, "", 6)
        attached := !!DllCall("comctl32\SetWindowSubclass", "Ptr",
            this.List.Hwnd, "Ptr", this.ListWheelSubclassCallback,
            "UPtr", MappingWindow.ListWheelSubclassId,
            "UPtr", 0, "Int")
        if !attached {
            CallbackFree(this.ListWheelSubclassCallback)
            this.ListWheelSubclassCallback := 0
            this.ListWheelSubclassMethod := ""
            throw Error("无法启用列表平滑滚动。")
        }
        this.ListWheelSubclassAttached := true
        return true
    }

    ListWheelSubclassProc(hwnd, message, wParam, lParam, subclassId,
            referenceData) {
        if message == Win32.WM_MOUSEWHEEL
                && !this.Disposed && !this.DragActive {
            try
                this.ProcessListWheelDelta(this.SignedWord(wParam >> 16))
            return 0
        }
        try {
            if message == Win32.WM_LBUTTONDOWN
                    && this.PendingListScrollLines
                this.StopSmoothListScroll(true)
            if message == 0x0082 ; WM_NCDESTROY
                this.ListWheelSubclassAttached := false
        } catch {
            ; Exceptions must not cross the native window-procedure boundary.
        }
        return DllCall("comctl32\DefSubclassProc", "Ptr", hwnd,
            "UInt", message, "UPtr", wParam, "Ptr", lParam, "Ptr")
    }

    RemoveListWheelSubclass() {
        if this.ListWheelSubclassAttached {
            if this.List.Hwnd
                    && DllCall("user32\IsWindow", "Ptr", this.List.Hwnd,
                        "Int") {
                if !DllCall("comctl32\RemoveWindowSubclass", "Ptr",
                        this.List.Hwnd, "Ptr",
                        this.ListWheelSubclassCallback, "UPtr",
                        MappingWindow.ListWheelSubclassId, "Int")
                    return false
            }
            this.ListWheelSubclassAttached := false
        }
        if this.ListWheelSubclassCallback {
            CallbackFree(this.ListWheelSubclassCallback)
            this.ListWheelSubclassCallback := 0
        }
        this.ListWheelSubclassMethod := ""
        return true
    }

    IsScreenPointInsideList(lParam, messageHwnd := 0) {
        if !IsObject(this.List) || !this.List.Hwnd
                || !DllCall("user32\IsWindow", "Ptr", this.List.Hwnd,
                    "Int")
            return false
        ; Synthetic tests and accessibility clients can target the ListView
        ; without supplying screen coordinates.
        if messageHwnd == this.List.Hwnd && !lParam
            return true
        screenX := this.SignedWord(lParam)
        screenY := this.SignedWord(lParam >> 16)
        rect := Buffer(16, 0)
        if !DllCall("user32\GetWindowRect", "Ptr", this.List.Hwnd,
                "Ptr", rect, "Int")
            return false
        return screenX >= NumGet(rect, 0, "Int")
            && screenX < NumGet(rect, 8, "Int")
            && screenY >= NumGet(rect, 4, "Int")
            && screenY < NumGet(rect, 12, "Int")
    }

    GetSystemWheelScrollLines() {
        scrollLines := 0
        if !DllCall("user32\SystemParametersInfoW", "UInt", 0x0068,
                "UInt", 0, "UInt*", &scrollLines, "UInt", 0, "Int")
            return 3
        if scrollLines != 0xFFFFFFFF
            return Max(0, Integer(scrollLines))
        clientRect := Buffer(16, 0)
        if !DllCall("user32\GetClientRect", "Ptr", this.List.Hwnd,
                "Ptr", clientRect, "Int")
            return 1
        clientHeight := NumGet(clientRect, 12, "Int")
        visibleLines := Floor(clientHeight / this.GetListRowHeightPixels())
        return Max(1, visibleLines - 1)
    }

    QueueSmoothListScroll(lines) {
        lines := Integer(lines)
        if !lines
            return false
        this.BeginSmoothListTimerResolution()
        if this.PendingListScrollLines
                && (this.PendingListScrollLines > 0) != (lines > 0) {
            ; A direction change must be visible immediately instead of first
            ; draining motion queued in the old direction.
            SetTimer(this.SmoothListScrollTimer, 0)
            this.PendingListScrollLines := 0
        }
        maximum := MappingWindow.SmoothScrollMaximumQueuedLines
        this.PendingListScrollLines := Max(-maximum,
            Min(maximum, this.PendingListScrollLines + lines))
        return this.AdvanceSmoothListScroll()
    }

    AdvanceSmoothListScroll(*) {
        if this.Disposed || this.DragActive || !this.PendingListScrollLines
                || !IsObject(this.List) || !this.List.Hwnd
                || !DllCall("user32\IsWindow", "Ptr", this.List.Hwnd,
                    "Int")
                || !DllCall("user32\IsWindowVisible", "Ptr",
                    this.List.Hwnd, "Int") {
            this.StopSmoothListScroll()
            return false
        }
        direction := this.PendingListScrollLines > 0 ? 1 : -1
        before := SendMessage(Win32.LVM_GETTOPINDEX, 0, 0, ,
            this.List.Hwnd)
        SendMessage(Win32.LVM_SCROLL, 0,
            direction * this.GetListRowHeightPixels(), , this.List.Hwnd)
        after := SendMessage(Win32.LVM_GETTOPINDEX, 0, 0, ,
            this.List.Hwnd)
        if after == before {
            this.StopSmoothListScroll()
            return false
        }
        this.PendingListScrollLines -= direction
        if this.PendingListScrollLines
            this.ScheduleNextSmoothListScroll()
        else
            this.StopSmoothListScroll()
        return true
    }

    ScheduleNextSmoothListScroll() {
        remainingLines := Abs(this.PendingListScrollLines)
        accelerationRange := Max(1,
            MappingWindow.SmoothScrollAccelerationLines - 1)
        speedRatio := Min(1, Max(0,
            (remainingLines - 1) / accelerationRange))
        ; A larger queue represents a faster wheel gesture. Ease the delay
        ; toward the slow interval as momentum is consumed.
        easedSpeed := 1 - ((1 - speedRatio) * (1 - speedRatio))
        interval := Round(MappingWindow.SmoothScrollSlowIntervalMs
            - (MappingWindow.SmoothScrollSlowIntervalMs
                - MappingWindow.SmoothScrollFastIntervalMs) * easedSpeed)
        this.LastSmoothListScrollIntervalMs := interval
        SetTimer(this.SmoothListScrollTimer, -interval)
        return interval
    }

    BeginSmoothListTimerResolution() {
        if this.SmoothListTimerResolutionActive
            return true
        resolution := MappingWindow.SmoothScrollTimerResolutionMs
        try this.SmoothListTimerResolutionActive := DllCall(
            "winmm\timeBeginPeriod", "UInt", resolution, "UInt") == 0
        catch
            this.SmoothListTimerResolutionActive := false
        return this.SmoothListTimerResolutionActive
    }

    EndSmoothListTimerResolution() {
        if !this.SmoothListTimerResolutionActive
            return false
        this.SmoothListTimerResolutionActive := false
        try DllCall("winmm\timeEndPeriod", "UInt",
            MappingWindow.SmoothScrollTimerResolutionMs, "UInt")
        return true
    }

    StopSmoothListScroll(resetWheelRemainder := false) {
        if IsObject(this.SmoothListScrollTimer)
            try SetTimer(this.SmoothListScrollTimer, 0)
        this.PendingListScrollLines := 0
        this.EndSmoothListTimerResolution()
        if resetWheelRemainder
            this.ListWheelDeltaRemainder := 0
        return true
    }

    SignedWord(value) {
        value &= 0xFFFF
        return value & 0x8000 ? value - 0x10000 : value
    }

    HandleListCommand(wParam, lParam, ctrlDown := false,
            shiftDown := false, altDown := false) {
        repeated := (lParam & 0x40000000) != 0
        if wParam == 32 && !ctrlDown && !shiftDown && !altDown {
            if !repeated && this.GetSelectedRows().Length
                this.ToggleSelectedMapping()
            return 0
        }
        if wParam == 113 && !ctrlDown && !shiftDown && !altDown {
            if !repeated {
                row := this.List.GetNext(0, "Focused")
                if row > 0
                    this.OpenEditorForRow(row)
            }
            return 0
        }
        if wParam == 65 && ctrlDown && !altDown {
            if !repeated {
                this.List.Modify(0, "Select")
                this.RefreshSelectionState()
            }
            return 0
        }
        if wParam == 46 {
            if !repeated && this.GetSelectedRows().Length
                this.DeleteSelected()
            return 0
        }
        if wParam == 27 {
            if this.GetSelectedRows().Length {
                this.List.Modify(0, "-Select")
                this.RefreshSelectionState()
            } else {
                this.RequestHide()
            }
            return 0
        }
    }

    Dispose() {
        if this.Disposed
            return
        this.Disposed := true
        cleanupFailures := []
        this.StopSmoothListScroll(true)
        if this.ListWheelRegistered {
            try {
                OnMessage(Win32.WM_MOUSEWHEEL,
                    this.ListWheelCallback, 0)
                this.ListWheelRegistered := false
            } catch as messageError {
                cleanupFailures.Push("列表滚轮：" messageError.Message)
            }
        }
        try {
            if !this.RemoveListWheelSubclass()
                cleanupFailures.Push("列表滚轮子类：Win32 " A_LastError)
        } catch as subclassError {
            cleanupFailures.Push("列表滚轮子类：" subclassError.Message)
        }
        if this.ListKeyDownRegistered {
            try {
                OnMessage(Win32.WM_KEYDOWN,
                    this.ListKeyDownCallback, 0)
                this.ListKeyDownRegistered := false
            } catch as messageError {
                cleanupFailures.Push("列表快捷键：" messageError.Message)
            }
        }
        if this.ResizeMessagesRegistered {
            try {
                OnMessage(Win32.WM_ENTERSIZEMOVE,
                    this.ResizeMessageCallback, 0)
                OnMessage(Win32.WM_EXITSIZEMOVE,
                    this.ResizeMessageCallback, 0)
                this.ResizeMessagesRegistered := false
            } catch as messageError {
                cleanupFailures.Push("缩放消息：" messageError.Message)
            }
        }
        if this.ListNativeSelectionRegistered {
            try {
                this.List.OnNotify(-101,
                    this.ListNativeSelectionCallback, -1)
                this.ListNativeSelectionRegistered := false
            } catch as notifyError {
                cleanupFailures.Push("列表选择通知：" notifyError.Message)
            }
        }
        if this.HistoryHotkeysRegistered {
            try this.SetHistoryHotkeyState(false)
            catch as hotkeyError
                cleanupFailures.Push("主界面快捷键：" hotkeyError.Message)
        }
        this.DisposeOwnedResource(cleanupFailures, "映射编辑器",
            "BlockEditor", false)
        this.DisposeOwnedResource(cleanupFailures, "单元格提示",
            "CellTooltip")
        this.DisposeOwnedResource(cleanupFailures, "列表选择器",
            "ListSelection")
        this.DisposeOwnedResource(cleanupFailures, "右键菜单",
            "ContextPopup")
        try {
            SetTimer(this.SelectionTimer, 0)
            this.SelectionTimer := ""
        } catch as timerError
            cleanupFailures.Push("选择计时器：" timerError.Message)
        try {
            SetTimer(this.PendingCapturePointerActionTimer, 0)
            this.PendingCapturePointerActionTimer := ""
            this.PendingCapturePointerAction := ""
        } catch as timerError
            cleanupFailures.Push("录制界面命令：" timerError.Message)
        this.DisposeOwnedResource(cleanupFailures, "列表表头",
            "ListHeader")
        this.DisposeOwnedResource(cleanupFailures, "交互服务",
            "Interactions")
        try this.ReleaseListRowImageList()
        catch as imageListError
            cleanupFailures.Push("列表图像：" imageListError.Message)
        if IsObject(this.Gui) {
            try UnregisterNativeWindowBackground(this.Gui.Hwnd)
            try this.Gui.Destroy()
            catch as guiError
                cleanupFailures.Push("主窗口：" guiError.Message)
        }
        try {
            ReleaseApplicationWindowIcons(this.IconHandles)
            this.IconHandles := []
        } catch as iconError
            cleanupFailures.Push("窗口图标：" iconError.Message)
        if !this.ListKeyDownRegistered
            this.ListKeyDownCallback := ""
        if !this.ListWheelRegistered
            this.ListWheelCallback := ""
        this.SmoothListScrollTimer := ""
        if !this.ResizeMessagesRegistered
            this.ResizeMessageCallback := ""
        if !this.ListNativeSelectionRegistered
            this.ListNativeSelectionCallback := ""
        this.SelectionChangedCallback := ""
        if !this.HistoryHotkeysRegistered {
            this.HistoryHotIf := ""
            this.UndoHotkeyCallback := ""
            this.RedoHotkeyCallback := ""
            this.NewMappingHotkeyCallback := ""
        }
        if cleanupFailures.Length
            throw Error("主窗口资源清理失败："
                . this.JoinCleanupFailures(cleanupFailures))
        return true
    }

    DisposeOwnedResource(failures, label, propertyName, arguments*) {
        resource := this.%propertyName%
        if !IsObject(resource)
            return false
        try {
            resource.Dispose(arguments*)
            this.%propertyName% := ""
            return true
        } catch as resourceError {
            failures.Push(label "：" resourceError.Message)
            return false
        }
    }

    JoinCleanupFailures(failures) {
        message := ""
        for failure in failures
            message .= (message == "" ? "" : "；") failure
        return message
    }

    LoadRows(mappings) {
        if IsObject(this.CellTooltip)
            this.CellTooltip.InvalidateMeasurements()
        for customOrder, mapping in mappings {
            enabled := !mapping.HasOwnProp("Enabled") || mapping.Enabled
            row := this.List.Add("", mapping.Id,
                this.GetMappingStatusDisplay(enabled), mapping.Source,
                mapping.Target, customOrder,
                this.GetScopeDisplay(mapping.Scope), enabled ? "1" : "0")
            this.SetMappingStatusIcon(row, enabled)
        }
        this.RefreshListColumnLayout()
    }

    ReplaceRows(mappings, preferredId := "") {
        if Type(mappings) != "Array"
            return false
        this.StopSmoothListScroll(true)
        listRedrawTransaction := AtomicControlRedrawTransaction.Begin(
            [this.List])
        try {
            this.List.Delete()
            this.LoadRows(mappings)
            if this.ListHeader.HasActiveSort()
                this.ListHeader.ApplyCurrentSort()
            preferredIds := Type(preferredId) == "Array"
                ? preferredId : (preferredId == "" ? [] : [preferredId])
            focused := false
            for selectedId in preferredIds {
                row := this.FindMappingRow(selectedId)
                if !row
                    continue
                this.List.Modify(row, "Select"
                    . (!focused ? " Focus Vis" : ""))
                focused := true
            }
        } finally AtomicControlRedrawTransaction.End(listRedrawTransaction)
        this.UpdateSelectionButtons(this.GetSelectedRows())
        return true
    }

    AddMappingRow(mapping, customOrder) {
        this.StopSmoothListScroll(true)
        enabled := !mapping.HasOwnProp("Enabled") || mapping.Enabled
        addedRow := this.List.Add("", mapping.Id,
            this.GetMappingStatusDisplay(enabled), mapping.Source,
            mapping.Target, customOrder,
            this.GetScopeDisplay(mapping.Scope), enabled ? "1" : "0")
        this.SetMappingStatusIcon(addedRow, enabled)
        this.RefreshListColumnLayout()
        if this.SortColumn
            this.ApplyCurrentSort()
        row := this.FindMappingRow(mapping.Id)
        if row {
            this.SelectOnlyRow(row)
            this.UpdateSelectionButtons(row)
        }
        return row
    }

    UpdateMappingRow(mapping, previousId := "") {
        row := this.FindMappingRow(mapping.Id)
        if !row && previousId != "" && previousId != mapping.Id
            row := this.FindMappingRow(previousId)
        if !row
            return false
        sequence := this.List.GetText(row, MappingWindow.SequenceColumn)
        enabled := !mapping.HasOwnProp("Enabled") || mapping.Enabled
        this.List.Modify(row, "", mapping.Id,
            this.GetMappingStatusDisplay(enabled), mapping.Source,
            mapping.Target, sequence, this.GetScopeDisplay(mapping.Scope),
            enabled ? "1" : "0")
        this.SetMappingStatusIcon(row, enabled)
        if IsObject(this.CellTooltip)
            this.CellTooltip.InvalidateMeasurements()
        this.UpdateSelectionButtons(row)
        return true
    }

    RemoveMappingRow(mappingId) {
        row := this.FindMappingRow(mappingId)
        if !row
            return false
        this.StopSmoothListScroll(true)
        removedOrder := Integer(this.List.GetText(row,
            MappingWindow.SequenceColumn))
        this.List.Delete(row)
        Loop this.List.GetCount() {
            order := Integer(this.List.GetText(A_Index,
                MappingWindow.SequenceColumn))
            if order > removedOrder
                this.List.Modify(A_Index, "Col" MappingWindow.SequenceColumn,
                    order - 1)
        }
        this.RefreshListColumnLayout()
        this.UpdateSelectionButtons(this.List.GetNext())
        return true
    }

    ApplyCurrentSort() {
        return IsObject(this.ListHeader)
            ? this.ListHeader.ApplyCurrentSort() : false
    }

    RestoreCustomOrder(showStatus := true) {
        if !IsObject(this.ListHeader)
            return false
        this.SuppressSortStatus := !showStatus
        try return this.ListHeader.RestoreOrder()
        catch as sortError {
            this.SetStatus(Tr("无法恢复自定义顺序：{1}",
                sortError.Message), true)
            return false
        } finally this.SuppressSortStatus := false
    }

    OnHeaderSortChanged(header, column, descending) {
        this.StopSmoothListScroll(true)
        this.SortColumn := column
        this.SortDescending := descending
        if this.SuppressSortStatus
            return
        if !column {
            this.SetStatus(Tr("已恢复脚本中的自定义顺序。"))
            return
        }
        this.SetStatus(Tr("已临时按“{1}”{2}排列；不会改写脚本顺序。",
            this.GetHeaderLabel(column),
            descending ? Tr("降序") : Tr("升序")))
    }

    GetHeaderLabel(column) {
        if !IsObject(this.ListHeader)
            return ""
        for displayColumn, spec in this.ListHeader.Columns {
            if spec.Column == column
                return this.HeaderLabels[displayColumn]
        }
        return ""
    }

    OnListBeginDrag(control, notification) {
        if this.Disposed || this.DragActive || control != this.List
            return
        this.StopSmoothListScroll(true)
        draggedRowOffset := A_PtrSize == 8 ? 24 : 12
        draggedRow := NumGet(notification, draggedRowOffset, "Int") + 1
        if draggedRow < 1 || draggedRow > this.List.GetCount()
            return
        draggedId := this.List.GetText(draggedRow,
            MappingWindow.NameColumn)
        if draggedId == ""
            return
        selectedIds := this.GetSelectedMappingIds()
        draggedIsSelected := false
        for mappingId in selectedIds {
            if mappingId == draggedId {
                draggedIsSelected := true
                break
            }
        }
        mappingIds := draggedIsSelected ? selectedIds : [draggedId]
        if !draggedIsSelected
            this.SelectOnlyRow(draggedRow)
        if IsObject(this.CellTooltip)
            this.CellTooltip.Hide()
        if this.SortColumn && !this.RestoreCustomOrder(false)
            return
        if !this.SelectMappingIds(mappingIds)
            return
        this.DragActive := true
        this.LastDragScrollTicks := 0
        lastMark := ""
        try {
            while GetKeyState("LButton", "P") {
                this.AutoScrollListDuringDrag()
                dropInfo := this.GetListDropInfo()
                markKey := IsObject(dropInfo)
                    ? dropInfo.MarkRow ":" (dropInfo.After ? 1 : 0) : "none"
                if markKey != lastMark {
                    this.SetListInsertMark(dropInfo)
                    lastMark := markKey
                }
                Sleep(16)
            }
            dropInfo := this.GetListDropInfo()
        } finally {
            this.SetListInsertMark(false)
            this.DragActive := false
        }
        if !IsObject(dropInfo)
            return
        this.ApplyMappingMove(mappingIds, dropInfo.InsertIndex)
    }

    ApplyMappingMove(mappingIds, targetIndex) {
        if Type(mappingIds) != "Array"
            mappingIds := [mappingIds]
        if !this.App.MoveMappingsTo(mappingIds, targetIndex)
            return false
        return true
    }

    AutoScrollListDuringDrag() {
        point := Buffer(8, 0)
        if !DllCall("user32\GetCursorPos", "Ptr", point, "Int")
                || !DllCall("user32\ScreenToClient", "Ptr", this.List.Hwnd,
                    "Ptr", point, "Int")
            return false
        clientRect := Buffer(16, 0)
        if !DllCall("user32\GetClientRect", "Ptr", this.List.Hwnd,
                "Ptr", clientRect, "Int")
            return false
        y := NumGet(point, 4, "Int")
        clientHeight := NumGet(clientRect, 12, "Int")
        edgeSize := Max(18, this.GetListRowHeightPixels())
        direction := y < edgeSize ? -1 : (y >= clientHeight - edgeSize ? 1 : 0)
        if !direction
            return false
        nowTicks := DllCall("kernel32\GetTickCount64", "UInt64")
        if nowTicks - this.LastDragScrollTicks < 70
            return false
        this.LastDragScrollTicks := nowTicks
        return !!SendMessage(0x1014, 0,
            direction * this.GetListRowHeightPixels(), , this.List.Hwnd)
    }

    GetListDropInfo() {
        point := Buffer(8, 0)
        if !DllCall("user32\GetCursorPos", "Ptr", point, "Int")
            || !DllCall("user32\ScreenToClient", "Ptr", this.List.Hwnd,
                "Ptr", point, "Int")
            return false
        x := NumGet(point, 0, "Int")
        y := NumGet(point, 4, "Int")
        clientRect := Buffer(16, 0)
        if !DllCall("user32\GetClientRect", "Ptr", this.List.Hwnd,
                "Ptr", clientRect, "Int")
            return false
        clientWidth := NumGet(clientRect, 8, "Int")
        clientHeight := NumGet(clientRect, 12, "Int")
        if x < 0 || x >= clientWidth
            return false
        count := this.List.GetCount()
        if !count
            return false
        if y < 0
            return {MarkRow: 0, After: false, InsertIndex: 1}
        if y >= clientHeight
            return {MarkRow: count - 1, After: true,
                InsertIndex: count + 1}
        hitTest := Buffer(24, 0)
        NumPut("Int", x, hitTest, 0)
        NumPut("Int", y, hitTest, 4)
        rawRow := SendMessage(0x1012, 0, hitTest.Ptr, , this.List.Hwnd)
        if rawRow < 0 {
            return {MarkRow: count - 1, After: true,
                InsertIndex: count + 1}
        }
        itemRect := Buffer(16, 0)
        NumPut("Int", 0, itemRect, 0) ; LVIR_BOUNDS
        SendMessage(0x100E, rawRow, itemRect.Ptr, , this.List.Hwnd)
        midpoint := (NumGet(itemRect, 4, "Int")
            + NumGet(itemRect, 12, "Int")) // 2
        after := y >= midpoint
        return {MarkRow: rawRow, After: after,
            InsertIndex: rawRow + 1 + (after ? 1 : 0)}
    }

    SetListInsertMark(dropInfo) {
        insertMark := Buffer(16, 0)
        NumPut("UInt", 16, insertMark, 0)
        if IsObject(dropInfo) {
            NumPut("UInt", dropInfo.After ? 1 : 0, insertMark, 4)
            NumPut("Int", dropInfo.MarkRow, insertMark, 8)
        } else {
            NumPut("Int", -1, insertMark, 8)
        }
        return SendMessage(0x10A6, 0, insertMark.Ptr, , this.List.Hwnd)
    }

    FindMappingRow(mappingId) {
        Loop this.List.GetCount() {
            if this.List.GetText(A_Index, MappingWindow.NameColumn)
                    == mappingId
                return A_Index
        }
        return 0
    }

    Show(*) {
        return this.ShowWithOptions()
    }

    Activate(*) {
        if WindowHierarchy.IsOwnerLocked(this.Gui)
                && WindowHierarchy.ActivateTopOwned(this.Gui)
            return true
        hwnd := this.Gui.Hwnd
        visible := DllCall("user32\IsWindowVisible", "Ptr", hwnd, "Int")
        if !visible && !this.Show()
            return false
        if WindowHierarchy.IsOwnerLocked(this.Gui)
            return WindowHierarchy.ActivateTopOwned(this.Gui)
        preventSelectionFlash := visible && this.GetSelectedRows().Length > 0
        if preventSelectionFlash
            this.SetListActivationRedraw(false)
        activated := false
        try {
            if DllCall("user32\IsIconic", "Ptr", hwnd, "Int")
                DllCall("user32\ShowWindow", "Ptr", hwnd,
                    "Int", Win32.SW_RESTORE, "Int")
            try WinActivate("ahk_id " hwnd)
            this.RefreshVisibleRoundedButtons()
            activated := DllCall("user32\IsWindowVisible", "Ptr", hwnd,
                "Int") && !DllCall("user32\IsIconic", "Ptr", hwnd, "Int")
        } finally {
            if preventSelectionFlash {
                this.SetListActivationRedraw(true)
                this.RefreshSelectedListRows()
            }
        }
        return activated
    }

    SetListActivationRedraw(enabled) {
        if this.Disposed || !IsObject(this.List) || !this.List.Hwnd
            return false
        DllCall("user32\SendMessageW", "Ptr", this.List.Hwnd,
            "UInt", 0x000B, "Ptr", enabled ? 1 : 0, "Ptr", 0,
            "Ptr") ; WM_SETREDRAW
        return true
    }

    SetInitialClientSize(width, height) {
        size := this.ConstrainRestoredClientSize(width, height)
        this.InitialClientWidth := size.Width
        this.InitialClientHeight := size.Height
        this.LastNormalClientWidth := size.Width
        this.LastNormalClientHeight := size.Height
        return size
    }

    ConstrainRestoredClientSize(width, height) {
        try width := Integer(width)
        catch {
            width := MappingWindow.DefaultClientWidth
        }
        try height := Integer(height)
        catch {
            height := MappingWindow.DefaultClientHeight
        }
        width := Max(this.MinClientWidth, width)
        height := Max(MappingWindow.BaseMinClientHeight, height)
        maximum := this.GetWorkAreaMaximumClientSize()
        if IsObject(maximum) {
            width := Min(width, Max(this.MinClientWidth, maximum.Width))
            height := Min(height,
                Max(MappingWindow.BaseMinClientHeight, maximum.Height))
        }
        return {Width: width, Height: height}
    }

    GetWorkAreaMaximumClientSize() {
        monitor := DllCall("user32\MonitorFromWindow", "Ptr", this.Gui.Hwnd,
            "UInt", 2, "Ptr") ; MONITOR_DEFAULTTONEAREST
        monitorInfo := Buffer(40, 0)
        NumPut("UInt", 40, monitorInfo, 0)
        if !monitor || !DllCall("user32\GetMonitorInfoW", "Ptr", monitor,
                "Ptr", monitorInfo, "Int")
            return false
        workWidth := NumGet(monitorInfo, 28, "Int")
            - NumGet(monitorInfo, 20, "Int")
        workHeight := NumGet(monitorInfo, 32, "Int")
            - NumGet(monitorInfo, 24, "Int")
        dpi := DllCall("user32\GetDpiForWindow", "Ptr", this.Gui.Hwnd,
            "UInt")
        if !dpi
            dpi := 96
        frame := Buffer(16, 0)
        style := DllCall("user32\GetWindowLongPtrW", "Ptr", this.Gui.Hwnd,
            "Int", -16, "Ptr")
        extendedStyle := DllCall("user32\GetWindowLongPtrW", "Ptr",
            this.Gui.Hwnd, "Int", -20, "Ptr")
        adjusted := false
        try adjusted := DllCall("user32\AdjustWindowRectExForDpi", "Ptr",
            frame, "UInt", style, "Int", false, "UInt", extendedStyle,
            "UInt", dpi, "Int")
        if !adjusted
            adjusted := DllCall("user32\AdjustWindowRectEx", "Ptr", frame,
                "UInt", style, "Int", false, "UInt", extendedStyle, "Int")
        frameWidth := adjusted
            ? NumGet(frame, 8, "Int") - NumGet(frame, 0, "Int") : 0
        frameHeight := adjusted
            ? NumGet(frame, 12, "Int") - NumGet(frame, 4, "Int") : 0
        effectiveDpi := UiScaleService.GetEffectiveDpi(this.Gui.Hwnd)
        return {
            Width: Max(1, Floor((workWidth - frameWidth) * 96
                / effectiveDpi)),
            Height: Max(1, Floor((workHeight - frameHeight) * 96
                / effectiveDpi))
        }
    }

    GetPersistableClientSize() {
        if this.LastNormalClientWidth > 0 && this.LastNormalClientHeight > 0
            return {Width: Round(this.LastNormalClientWidth),
                Height: Round(this.LastNormalClientHeight)}
        try {
            this.Gui.GetClientPos(, , &width, &height)
            if width > 0 && height > 0
                return {Width: Round(UiScaleService.ToDesign(width)),
                    Height: Round(UiScaleService.ToDesign(height))}
        }
        return false
    }

    BuildFirstShowOptions(showOptions) {
        options := Trim(String(showOptions))
        if !RegExMatch(options, "i)(^|\s)w\d+(?:\.\d+)?(?:\s|$)")
            options := "w" this.InitialClientWidth
                . (options == "" ? "" : " " options)
        if !RegExMatch(options, "i)(^|\s)h\d+(?:\.\d+)?(?:\s|$)")
            options := "h" this.InitialClientHeight " " options
        return Trim(options)
    }

    ShowWithOptions(showOptions := "") {
        if this.Disposed || (this.App.HasOwnProp("ShuttingDown")
                && this.App.ShuttingDown)
            return false
        if WindowHierarchy.IsOwnerLocked(this.Gui)
                && WindowHierarchy.ActivateTopOwned(this.Gui)
            return true
        presentationOptions := this.HasShown ? Trim(String(showOptions))
            : this.BuildFirstShowOptions(showOptions)
        presentationOptions := UiScaleService.ScaleShowOptions(
            presentationOptions)
        UiScaleService.PrepareGui(this.Gui, false)
        result := FirstVisibleWindowPresenter.Show(this.Gui,
            presentationOptions, this.HasShown,
            ObjBindMethod(this, "PrepareFirstVisibleSurface"),
            ObjBindMethod(this, "RefreshVisibleRoundedButtons"))
        this.LastFirstVisiblePresentation := result
        this.HasShown := result.FirstVisibleCompleted
        return result.Visible
    }

    PrepareFirstVisibleSurface() {
        ; Gui.Show 已在 DWM cloak 内创建最终原生表面。严格沿用参照项目的
        ; 顺序重申进程、顶层和子控件主题，再一次性提交完整首帧。
        this.RefreshCaptureLayout(true)
        UiThemeService.ApplyProcessPreference()
        this.ApplyNativeThemes(false)
        this.Gui.BackColor := MappingWindow.Colors.Window
        this.ClearAutomaticControlFocus()
        this.RefreshVisibleRoundedButtons()
        DllCall("user32\RedrawWindow", "Ptr", this.Gui.Hwnd,
            "Ptr", 0, "Ptr", 0, "UInt", Win32.RDW_LAYOUT_REFRESH,
            "Int")
        return true
    }

    ClearAutomaticControlFocus() {
        if this.Disposed || !IsObject(this.Status) || !this.Status.Hwnd
            return false
        this.Interactions.MoveKeyboardFocus(this.Status.Hwnd)
        focused := DllCall("user32\GetFocus", "Ptr") == this.Status.Hwnd
        if focused
            this.Interactions.HideTextInputCaret(this.Status.Hwnd)
        return focused
    }

    RefreshVisibleRoundedButtons(*) {
        for button in [
                this.AddButton, this.PauseResumeButton, this.DeleteButton,
                this.SettingsButton, this.SupportButton, this.AboutButton,
                this.SourceButton, this.TargetButton,
                this.SaveButton, this.ClearButton]
            this.Interactions.Redraw(button.Hwnd)
        return true
    }

    ApplyNativeThemes(stabilize := true, *) {
        if this.Disposed
            return
        try {
            ApplyDarkWindow(this.Gui.Hwnd)
            ApplyDarkListView(this.List.Hwnd)
            ApplyDarkControl(this.NameEdit.Hwnd)
            this.ApplyNameInputViewport()
            ApplyDarkControl(this.DistinguishModifierSidesCheck.Hwnd)
        } finally {
            if stabilize
                this.RedrawStable()
        }
    }

    ApplyAppearance(*) {
        if this.Disposed
            return false
        try {
            MappingWindow.Colors := UiThemeService.GetPalette()
            colors := MappingWindow.Colors
            this.FontName := LocalizationService.GetUiFontName()
            this.SystemFontName := LocalizationService
                .GetLanguageSystemUiFontName()
            this.UpdateLanguageLayoutMetrics()
            this.Gui.Title := Tr("键鼠重映射小助手")
            RegisterNativeWindowBackground(this.Gui.Hwnd, colors.Window)
            this.Gui.SetFont("s10 c" colors.Text, this.FontName)
            this.Interactions.SetParentColor(colors.Window)
            if IsObject(this.CellTooltip)
                this.CellTooltip.InvalidateTheme()

            for button in [this.AddButton, this.PauseResumeButton,
                    this.DeleteButton, this.SettingsButton, this.SupportButton,
                    this.AboutButton, this.SaveButton, this.ClearButton]
                button.SetFont("s10 bold", this.SystemFontName)
            this.Interactions.SetTextNoErase(this.AddButton,
                this.GetAddButtonText())
            this.Interactions.SetTextNoErase(this.SettingsButton,
                Tr("设置"))
            this.Interactions.SetTextNoErase(this.SupportButton,
                Tr("帮助"))
            this.Interactions.SetTextNoErase(this.AboutButton,
                Tr("关于"))
            this.Interactions.SetTextNoErase(this.DeleteButton,
                this.GetDeleteButtonText())
            this.Interactions.SetTextNoErase(this.SaveButton,
                Tr("保存映射"))
            this.Interactions.SetTextNoErase(this.ClearButton, Tr("清空"))
            this.Interactions.SetButtonAppearance(this.AddButton, colors.Add,
                colors.ButtonText, true)
            this.Interactions.SetButtonAppearance(this.SettingsButton,
                colors.Toolbar, colors.ToolbarText, true)
            this.Interactions.SetButtonAppearance(this.SupportButton,
                colors.Toolbar, colors.ToolbarText, true)
            this.Interactions.SetButtonAppearance(this.AboutButton,
                colors.Toolbar, colors.ToolbarText, true)
            this.Interactions.SetButtonAppearance(this.SaveButton,
                colors.Toolbar, colors.ToolbarText, true)
            this.Interactions.SetButtonAppearance(this.ClearButton,
                colors.Toolbar, colors.ToolbarText, true)
            this.Interactions.ClearButtonIcon(this.SaveButton)
            this.Interactions.ClearButtonIcon(this.ClearButton)
            this.ApplyCommandIcons()
            this.UpdateCommandButtonGroupWidths()
            this.RefreshToolbarTooltips()
            this.Interactions.SetButtonTooltip(this.SourceButton,
                Tr("演奏你的和弦！"))
            this.Interactions.SetButtonTooltip(this.TargetButton,
                Tr("演奏你的和弦！"))
            this.RefreshCaptureButtonIcons()
            this.Interactions.SetIconSurfaceAppearance(this.ArrowText,
                colors.Window, colors.Hint)
            this.Interactions.SetControlLucideIcon(this.ArrowText,
                "arrow-right.svg", 20, 0,
                UiThemeService.ButtonIconColor(colors.RulesEventIcon))

            this.HeaderLabels := [Tr("序号"), Tr("名称"), Tr("来源按键"),
                Tr("映射结果"), Tr("生效范围"), Tr("状态")]
            this.ListHeader.SetLabels(this.HeaderLabels)
            this.ListHeader.ApplyAppearance(colors.Toolbar, colors.Muted,
                this.SystemFontName, 10)
            this.List.Opt("Background" colors.Surface " c" colors.Text)
            this.List.SetFont("s12 c" colors.Text, this.FontName)

            this.SectionTitle.Text := Tr("新建映射")
            this.SectionTitle.Opt("Background" colors.Window)
            this.SectionTitle.SetFont("s11 bold c" colors.Text,
                this.SystemFontName)
            this.DistinguishModifierSidesCheck.Text := Tr(
                "区分左右修饰键")
            this.DistinguishModifierSidesCheck.Opt("c" colors.Text)
            this.DistinguishModifierSidesCheck.SetFont("s10 c" colors.Text,
                this.FontName)
            this.RefreshModifierSidesPreferredWidth()
            this.Interactions.SetDashedDividerAppearance(
                this.SectionTopDivider, colors.Window,
                colors.DividerAccent)
            this.SourceLabel.Text := Tr("来源按键")
            this.TargetLabel.Text := Tr("映射为")
            this.NameLabel.Text := Tr("名称")
            for label in [this.SourceLabel, this.TargetLabel,
                    this.NameLabel] {
                label.Opt("Background" colors.Window)
                label.SetFont("s10 c" colors.Muted, this.FontName)
            }
            this.ArrowText.Opt("Background" colors.Window)
            this.ArrowText.SetFont("s15 c" colors.Hint, this.FontName)
            this.Interactions.SetButtonAppearance(this.SourceButton,
                colors.Toolbar, colors.Text, true)
            this.Interactions.SetButtonAppearance(this.TargetButton,
                colors.Toolbar, colors.Text, true)
            if !IsObject(this.SourceCapture)
                this.Interactions.SetTextNoErase(this.SourceButton,
                    Tr("点击录制来源按键"))
            if !IsObject(this.TargetCapture)
                this.Interactions.SetTextNoErase(this.TargetButton,
                    Tr("点击录制目标按键"))
            for captureButton in [this.SourceButton, this.TargetButton]
                captureButton.SetFont("s10 bold c" colors.Text,
                    this.SystemFontName)
            for detail in [this.SourceDetail, this.TargetDetail] {
                detail.Opt("Background" colors.Window)
                detail.SetFont("s10 c" colors.Hint, this.FontName)
            }
            this.NameInput.Background.Opt("Background" colors.Input)
            this.NameEdit.Opt("Background" colors.Input " c" colors.Text)
            this.NameEdit.SetFont("norm s11 c" colors.Text, this.FontName)
            this.RefreshNameInputMetrics(0, true)
            this.ApplyNameInputViewport()
            this.Status.Opt("Background" colors.Window)
            this.Status.SetFont("s10 c" (this.StatusIsError
                ? colors.Error : colors.Muted), this.FontName)
            ApplyDarkControl(this.Status.Hwnd)
            UiScaleService.RefreshGuiFonts(this.Gui)
            this.RefreshNameInputMetrics(0, true)
            this.EnsureListRowMetrics("", true)
            this.UpdateSelectionButtons(this.List.GetNext())
            this.ContextPopup.ApplyAppearance()
            if IsObject(this.BlockEditor)
                this.BlockEditor.ApplyAppearance()
            this.LastLayoutSignature := ""
            this.Gui.GetClientPos(, , &clientWidth, &clientHeight)
            clientWidth := UiScaleService.ToDesign(clientWidth)
            clientHeight := UiScaleService.ToDesign(clientHeight)
            this.ApplyLayout(clientWidth, clientHeight, true)
            this.ApplyNativeThemes(false)
            ; 与公共窗口初始化顺序一致：先许可原生主题，再提交应用客户区颜色。
            this.Gui.BackColor := colors.Window
        ; 语言和字体只需重绘子控件，但主题会替换顶层窗口的背景刷。
        ; 热切换解锁后只擦除并重绘一次整棵窗口树，
        ; 否则 Win32 会继续显示切换前缓存的客户区底色。
        } finally this.RedrawStable(true)
        return true
    }

    RedrawStable(eraseBackground := false, updateImmediately := true) {
        if this.Disposed || !this.Gui.Hwnd
            return false
        ; 首次隐藏预布局需要擦除一次；后续事务提交保持无擦除以避免闪烁。
        flags := 0x0081
            | (eraseBackground ? 0x0004 : 0x0020)
            | (updateImmediately ? 0x0100 : 0)
        return !!DllCall("user32\RedrawWindow", "Ptr", this.Gui.Hwnd,
            "Ptr", 0, "Ptr", 0, "UInt", flags, "Int")
    }

    Hide(*) {
        return this.RequestHide()
    }

    HideForShutdown() {
        if this.Disposed || !IsObject(this.Gui)
            return false
        this.StopSmoothListScroll(true)
        hwnd := this.Gui.Hwnd
        ; This must be the first shutdown operation and must not depend on
        ; capture, tooltip or persistence cleanup succeeding. ShowWindow is
        ; synchronous, so no half-disposed owner-draw surface can remain in
        ; the compositor while isolated rule processes are being stopped.
        DllCall("user32\ShowWindow", "Ptr", hwnd,
            "Int", Win32.SW_HIDE, "Int")
        if IsObject(this.CellTooltip)
            try this.CellTooltip.Hide()
        if IsObject(this.ContextPopup)
            try this.ContextPopup.Hide()
        return !DllCall("user32\IsWindowVisible", "Ptr", hwnd, "Int")
    }

    RequestHide(force := false) {
        if !force && WindowHierarchy.IsOwnerLocked(this.Gui) {
            WindowHierarchy.ActivateTopOwned(this.Gui)
            return false
        }
        this.StopSmoothListScroll(true)
        captureWasActive := this.App.Capture.Active
        this.App.Capture.Stop(false)
        if captureWasActive
            this.CancelCaptureState()
        if IsObject(this.CellTooltip)
            this.CellTooltip.Hide()
        if IsObject(this.ContextPopup)
            this.ContextPopup.Hide()
        try this.App.TrySaveMainWindowLayout()
        ; Store a neutral child as the dialog's last focus target before the
        ; window disappears, so a later Show cannot restore the name Edit.
        this.ClearAutomaticControlFocus()
        this.Gui.Hide()
        return true
    }

    OnEscape(*) {
        ; Capture owns Escape globally. Handle it before child-window routing
        ; so an auxiliary window can never steal the cancellation gesture.
        captureBlocked := false
        try {
            captureBlocked := this.App.Capture.IsInputBlocked()
        }
        catch {
            try {
                captureBlocked := this.App.Capture.Active
            } catch {
                captureBlocked := false
            }
        }
        if captureBlocked {
            try this.SuppressEscapeAfterCapture(3000)
            if this.App.Capture.Active
                this.App.Capture.Cancel("escape")
            return
        }
        if WindowHierarchy.IsOwnerLocked(this.Gui) {
            WindowHierarchy.ActivateTopOwned(this.Gui)
            return
        }
        if this.ConsumeEscapeAfterCapture()
            return
        focusedHwnd := DllCall("user32\GetFocus", "Ptr")
        if focusedHwnd == this.List.Hwnd && this.List.GetNext(0) > 0 {
            this.List.Modify(0, "-Select")
            this.SetTransientStatus(this.App.GetSummaryText())
            return
        }
        this.RequestHide()
    }

    OpenNewMappingEditor(forceOpen := false, *) {
        if IsObject(this.BlockEditor) {
            if this.BlockEditor.HasOwnProp("Disposed")
                    && this.BlockEditor.Disposed {
                this.BlockEditor := ""
            } else {
                this.BlockEditor.Activate()
                return
            }
        }
        if IsObject(this.ContextPopup) && this.ContextPopup.IsVisible() {
            this.ContextPopup.Hide()
            if !forceOpen
                return
        }
        try {
            blockText := this.App.Repository.CreateBlankBlock()
            startLine := this.App.Repository.GetAppendStartLine()
        }
        catch as repositoryError {
            this.SetStatus(Tr("无法创建空白映射代码：{1}",
                repositoryError.Message), true)
            return
        }
        mapping := {Id: "", Source: "", Target: "", Block: blockText,
            EditorText: blockText, Mode: "managed", StartLine: startLine}
        try {
            editor := MappingBlockEditor(this, mapping, true)
            this.BlockEditor := editor
            editor.Show()
        } catch as editorError {
            if IsSet(editor)
                try editor.Dispose()
            this.BlockEditor := ""
            this.SetStatus(Tr("无法打开代码编辑器：{1}",
                editorError.Message), true)
        }
    }

    BeginCapture(role, *) {
        this.PendingCapturePointerAction := ""
        if this.App.Capture.Active {
            this.App.Capture.Cancel()
            return
        }
        this.RefreshCaptureButtonIcons(role)
        if !this.App.Capture.Start(role) {
            this.RefreshCaptureButtonIcons()
            startError := this.App.Capture.HasOwnProp("LastStartError")
                ? Trim(String(this.App.Capture.LastStartError)) : ""
            this.SetStatus(startError != ""
                ? Tr("无法启动按键录制：{1}", TrDiagnostic(startError))
                : Tr("无法启动按键录制，请重试。"), true)
            return
        }
        activeButton := role == "source" ? this.SourceButton : this.TargetButton
        idleButton := role == "source" ? this.TargetButton : this.SourceButton
        activeDetail := role == "source" ? this.SourceDetail : this.TargetDetail
        idleDetail := role == "source" ? this.TargetDetail : this.SourceDetail
        idleCapture := role == "source" ? this.TargetCapture : this.SourceCapture
        activeButton.Text := Tr("请按下按键 · Esc 取消")
        activeButton.Redraw()
        activeDetail.Text := ""
        if role == "source"
            idleButton.Text := this.GetCaptureButtonText(this.TargetCapture,
                Tr("点击录制目标按键"))
        else
            idleButton.Text := this.GetCaptureButtonText(this.SourceCapture,
                Tr("点击录制来源按键"))
        idleDetail.Text := this.GetCaptureDetail(idleCapture)
        this.UpdateStatus(role == "source" ? Tr("正在录制来源按键…")
            : Tr("正在录制目标按键…"))
        this.RefreshCaptureLayout()
        this.App.Capture.PreviewHeldModifiers()
    }

    OnCaptureButtonPointerDown(controlHwnd, *) {
        if !this.App.Capture.Active
            return false
        this.App.Capture.Cancel()
        return true
    }

    PreviewCapture(role, capture) {
        activeButton := role == "source" ? this.SourceButton : this.TargetButton
        activeDetail := role == "source" ? this.SourceDetail : this.TargetDetail
        displayText := this.GetCaptureDisplay(capture)
        this.Interactions.ClearButtonIcon(activeButton)
        this.Interactions.SetTextNoErase(activeButton, displayText)
        this.Interactions.SetTextNoErase(activeDetail,
            this.GetCaptureDetail(capture))
        this.UpdateStatus(Tr("正在录制{1}按键：{2}",
            role == "source" ? Tr("来源") : Tr("目标"), displayText))
        this.RefreshCaptureLayout()
    }

    AcceptCapture(role, capture) {
        activeButton := role == "source" ? this.SourceButton : this.TargetButton
        this.Interactions.ClearButtonIcon(activeButton)
        if role == "source" {
            this.SourceCapture := capture
            this.SourceButton.Text := this.GetCaptureDisplay(capture)
            this.SourceDetail.Text := this.GetCaptureDetail(capture)
        } else {
            this.TargetCapture := capture
            this.TargetButton.Text := this.GetCaptureDisplay(capture)
            this.TargetDetail.Text := this.GetCaptureDetail(capture)
        }
        this.RefreshCaptureButtonIcons()
        this.UpdateStatus(Tr("已录制{1}按键：{2}",
            role == "source" ? Tr("来源") : Tr("目标"), capture.KeyInfo))
        this.RefreshCaptureLayout()
    }

    CancelCaptureState(*) {
        this.SourceButton.Text := this.GetCaptureButtonText(this.SourceCapture,
            Tr("点击录制来源按键"))
        this.TargetButton.Text := this.GetCaptureButtonText(this.TargetCapture,
            Tr("点击录制目标按键"))
        this.SourceDetail.Text := this.GetCaptureDetail(this.SourceCapture)
        this.TargetDetail.Text := this.GetCaptureDetail(this.TargetCapture)
        this.RefreshCaptureButtonIcons()
        this.UpdateStatus(Tr("已取消按键录制。"))
        this.RefreshCaptureLayout()
    }

    RejectCapture(reason) {
        this.CancelCaptureState()
        this.UpdateStatus(reason, true)
    }

    SaveMapping(*) {
        if this.App.Capture.Active {
            this.SetStatus(Tr("请先完成或取消当前按键录制。"), true)
            return
        }
        if !IsObject(this.SourceCapture) || !IsObject(this.TargetCapture) {
            this.SetStatus(Tr("请先录制来源按键和目标按键。"), true)
            return
        }
        if this.App.AddMapping(this.SourceCapture, this.TargetCapture,
            this.NameEdit.Value,
            !!this.DistinguishModifierSidesCheck.Value) {
            this.ClearEditor(false)
        }
    }

    OnNameInputChanged(*) {
        if !this.Disposed
            this.ApplyNameInputViewport()
    }

    RefreshNameInputMetrics(dpi := 0, force := false) {
        if !force && IsObject(this.NameInputMetrics)
                && (!dpi || this.NameInputMetrics.Dpi == dpi)
            return this.NameInputMetrics
        metrics := GetMultilineEditLineMetrics(this.NameEdit.Hwnd,
            MappingWindow.NameInputVisibleLines,
            MappingWindow.NameInputHorizontalPadding,
            MappingWindow.NameInputVerticalPadding, dpi)
        if IsObject(metrics) {
            this.NameInputMetrics := metrics
            this.NameInputHeight := metrics.OuterHeightDip
        }
        return this.NameInputMetrics
    }

    ApplyNameInputViewport() {
        metrics := this.RefreshNameInputMetrics()
        applied := IsObject(metrics)
            && ApplyMultilineEditLineMetrics(this.NameEdit.Hwnd, metrics)
        if applied
            this.Interactions.EnsureTextInputCaret(this.NameEdit.Hwnd)
        return applied
    }

    ClearEditor(showStatus := true, *) {
        if this.App.Capture.Active
            this.App.Capture.Stop(false)
        this.SourceCapture := ""
        this.TargetCapture := ""
        this.NameEdit.Value := ""
        this.DistinguishModifierSidesCheck.Value :=
            MappingWindow.DefaultDistinguishModifierSides ? 1 : 0
        this.SourceButton.Text := Tr("点击录制来源按键")
        this.TargetButton.Text := Tr("点击录制目标按键")
        this.SourceDetail.Text := this.GetCaptureDetail("")
        this.TargetDetail.Text := this.GetCaptureDetail("")
        this.RefreshCaptureButtonIcons()
        if showStatus
            this.UpdateStatus(Tr("已清空新建区域。"))
        this.RefreshCaptureLayout()
    }

    DeleteSelected(*) {
        rows := this.GetSelectedRows()
        if !rows.Length {
            this.SetStatus(Tr("请先选择要删除的映射。"), true)
            return
        }
        mappingIds := []
        for row in rows {
            mappingId := this.List.GetText(row,
                MappingWindow.NameColumn)
            if mappingId == "" {
                this.SetStatus(Tr(
                    "所选映射缺少名称，无法删除。"), true)
                return
            }
            mappingIds.Push(mappingId)
        }
        this.App.DeleteMappings(mappingIds)
    }

    ToggleSelectedMapping(*) {
        rows := this.GetSelectedRows()
        if !rows.Length {
            this.SetStatus(Tr("请先选择要暂停或恢复的映射。"), true)
            return
        }
        mappingIds := []
        for row in rows {
            mappingId := this.List.GetText(row,
                MappingWindow.NameColumn)
            if mappingId == "" {
                this.SetStatus(Tr(
                    "所选映射缺少名称，无法修改状态。"), true)
                return
            }
            mappingIds.Push(mappingId)
        }
        this.App.ToggleMappingsEnabled(mappingIds)
    }

    GetSelectedRows() {
        rows := []
        row := 0
        while row := this.List.GetNext(row)
            rows.Push(row)
        return rows
    }

    GetSelectedMappingIds(rows := "") {
        if Type(rows) != "Array"
            rows := this.GetSelectedRows()
        mappingIds := []
        for row in rows {
            mappingId := this.List.GetText(row, MappingWindow.NameColumn)
            if mappingId != ""
                mappingIds.Push(mappingId)
        }
        return mappingIds
    }

    SelectMappingIds(mappingIds) {
        if Type(mappingIds) != "Array" || !mappingIds.Length
            return false
        selectedRows := []
        this.List.Modify(0, "-Select")
        for mappingId in mappingIds {
            row := this.FindMappingRow(mappingId)
            if !row
                continue
            this.List.Modify(row, "Select"
                . (!selectedRows.Length ? " Focus Vis" : ""))
            selectedRows.Push(row)
        }
        if selectedRows.Length && IsObject(this.ListSelection)
            for row in selectedRows
                this.ListSelection.RefreshItem(row)
        return selectedRows.Length
    }

    OnListDoubleClick(control, item) {
        if IsObject(this.CellTooltip)
            this.CellTooltip.Hide()
        if IsObject(this.ContextPopup)
            this.ContextPopup.Hide()
        if item > 0
            this.OpenEditorForRow(item)
    }

    OnListContextMenu(control, item, isRightClick, x, y) {
        if item <= 0
            return
        mappingId := this.List.GetText(item, MappingWindow.NameColumn)
        if mappingId == ""
            return
        selectedIds := this.GetSelectedMappingIds()
        clickedIsSelected := false
        for selectedId in selectedIds {
            if selectedId == mappingId {
                clickedIsSelected := true
                break
            }
        }
        if !clickedIsSelected {
            this.SelectOnlyRow(item)
            selectedIds := [mappingId]
        }
        SetTimer(this.SelectionTimer, 0)
        this.UpdateSelectionButtons(this.GetSelectedRows())
        if IsObject(this.ListSelection)
            this.ListSelection.RefreshItem(item)
        this.ContextPopup.ShowForMapping(mappingId, selectedIds)
    }

    SelectOnlyRow(row) {
        selectedRow := this.List.GetNext()
        hasAdditionalSelection := selectedRow
            && this.List.GetNext(selectedRow) > 0
        if selectedRow != row || hasAdditionalSelection {
            this.List.Modify(0, "-Select")
            this.List.Modify(row, "Select Focus Vis")
        } else {
            this.List.Modify(row, "Focus Vis")
        }
        if IsObject(this.ListSelection)
            this.ListSelection.RefreshItem(row)
    }

    OpenEditorForRow(row) {
        if row <= 0 || row > this.List.GetCount()
            return
        mappingId := this.List.GetText(row, MappingWindow.NameColumn)
        if mappingId != ""
            this.OpenEditorForId(mappingId)
    }

    OpenEditorForId(mappingId, startAiRequest := false) {
        if IsObject(this.BlockEditor) {
            this.BlockEditor.Activate()
            if startAiRequest
                    && this.BlockEditor.MappingId == mappingId
                SetTimer(ObjBindMethod(this.BlockEditor,
                    "StartAiRequest"), -1)
            else if startAiRequest
                this.SetStatus(Tr(
                    "请先关闭当前代码编辑器，再优化其他映射。"), true)
            return this.BlockEditor.MappingId == mappingId
        }
        try mapping := this.App.Repository.GetById(mappingId)
        catch as repositoryError {
            this.SetStatus(Tr("无法打开映射代码：{1}",
                repositoryError.Message), true)
            return
        }
        try {
            editor := MappingBlockEditor(this, mapping)
            this.BlockEditor := editor
            editor.Show()
            if startAiRequest
                SetTimer(ObjBindMethod(editor, "StartAiRequest"), -1)
            return true
        } catch as editorError {
            if IsSet(editor)
                try editor.Dispose()
            this.BlockEditor := ""
            this.SetStatus(Tr("无法打开代码编辑器：{1}",
                editorError.Message), true)
            return false
        }
    }

    OptimizeMappingById(mappingId) {
        return this.OpenEditorForId(mappingId, true)
    }

    OnBlockEditorClosed(editor) {
        if IsObject(this.BlockEditor) && this.BlockEditor == editor
            this.BlockEditor := ""
    }

    OnSelectionChanged(*) {
        this.QueueSelectionRefresh()
    }

    OnNativeSelectionChanged(control, lParam) {
        if this.Disposed || control != this.List || !lParam
            return
        stateOffset := A_PtrSize == 8 ? 24 : 12
        newState := NumGet(lParam, stateOffset + 8, "UInt")
        oldState := NumGet(lParam, stateOffset + 12, "UInt")
        changedFields := NumGet(lParam, stateOffset + 16, "UInt")
        if !(changedFields & 0x0008) || !((newState ^ oldState) & 0x0003)
            return
        this.QueueSelectionRefresh()
    }

    QueueSelectionRefresh() {
        if this.Disposed || !IsObject(this.SelectionTimer)
            return false
        SetTimer(this.SelectionTimer, -1)
        return true
    }

    RefreshSelectedListRows(*) {
        if this.Disposed || !IsObject(this.ListSelection)
            return false
        refreshed := false
        for row in this.GetSelectedRows()
            refreshed := this.ListSelection.RefreshItem(row) || refreshed
        return refreshed
    }

    RefreshMappingColors(mappingIds) {
        if Type(mappingIds) != "Array"
            mappingIds := [mappingIds]
        rows := Map()
        for mappingId in mappingIds {
            row := this.FindMappingRow(mappingId)
            if row
                rows[row] := true
        }
        if !rows.Count
            return 0
        for row, unused in rows
            SendMessage(Win32.LVM_REDRAWITEMS, row - 1, row - 1,
                this.List.Hwnd)
        DllCall("user32\UpdateWindow", "Ptr", this.List.Hwnd, "Int")
        return rows.Count
    }

    RefreshSelectionState(*) {
        if this.Disposed
            return false
        if IsObject(this.ContextPopup) && this.ContextPopup.IsVisible()
            this.ContextPopup.Hide()
        rows := this.GetSelectedRows()
        this.UpdateSelectionButtons(rows)
        if !rows.Length {
            this.SetTransientStatus(this.App.GetSummaryText())
            return
        }
        row := rows[1]
        if rows.Length > 1 {
            this.SetTransientStatus(this.App.GetSummaryText())
            return true
        }
        pausedText := this.List.GetText(row, MappingWindow.EnabledColumn) == "0"
            ? " · " Tr("已暂停") : ""
        this.SetTransientStatus(Tr("映射 · {1} -> {2}{3}",
            this.List.GetText(row, MappingWindow.SourceColumn),
            this.List.GetText(row, MappingWindow.TargetColumn), pausedText))
        return true
    }

    FocusMapping(mappingId) {
        row := this.FindMappingRow(mappingId)
        if !row
            return false
        this.SelectOnlyRow(row)
        this.UpdateSelectionButtons(row)
        return true
    }

    OnSettingsClosed(settingsWindow) {
        this.App.OnSettingsClosed(settingsWindow)
    }

    OnEventViewerClosed(viewer) {
        this.App.OnEventViewerClosed(viewer)
    }

    OnSupportInfoClosed(supportInfo) {
        this.App.OnSupportInfoClosed(supportInfo)
    }

    OnHelpClosed(helpWindow) {
        this.App.OnHelpClosed(helpWindow)
    }

    OnAboutClosed(aboutWindow) {
        this.App.OnAboutClosed(aboutWindow)
    }

    OnDonationClosed(donationWindow) {
        this.App.OnDonationClosed(donationWindow)
    }

    OnRulePackageImportClosed(previewWindow) {
        this.App.OnRulePackageImportClosed(previewWindow)
    }

    UpdateSelectionButtons(rows := "", *) {
        if !IsObject(rows)
            rows := this.GetSelectedRows()
        this.UpdatePauseResumeButton(rows)
        this.UpdateDeleteButton(rows)
    }

    EnsureSelectionCommandState(*) {
        if this.Disposed || !IsObject(this.Interactions)
            return false
        hasSelection := this.GetSelectedRows().Length > 0
        pauseState := this.Interactions.Controls[
            this.PauseResumeButton.Hwnd]
        deleteState := this.Interactions.Controls[this.DeleteButton.Hwnd]
        expectedPauseColor := hasSelection ? MappingWindow.Colors.Pause
            : MappingWindow.Colors.PauseDisabled
        expectedDeleteColor := hasSelection ? MappingWindow.Colors.Delete
            : MappingWindow.Colors.DeleteDisabled
        expectedTextColor := hasSelection ? MappingWindow.Colors.ButtonText
            : MappingWindow.Colors.DisabledButtonText
        if pauseState.Interactive != hasSelection
                || deleteState.Interactive != hasSelection
                || pauseState.Normal != expectedPauseColor
                || deleteState.Normal != expectedDeleteColor
                || pauseState.TextColor != expectedTextColor
                || deleteState.TextColor != expectedTextColor
            this.UpdateSelectionButtons()
        return hasSelection
    }

    UpdateLanguageLayoutMetrics() {
        compact := LocalizationService.UsesCompactLayout()
        this.MinClientWidth := compact ? MappingWindow.MinClientWidth
            : MappingWindow.ExpandedMinClientWidth
        toolbarButtonWidth := LocalizationService.IsChinese()
            ? MappingWindow.CompactToolbarButtonWidth
            : MappingWindow.ExpandedToolbarButtonMinWidth
        this.SettingsButtonWidth := toolbarButtonWidth
        this.SupportButtonWidth := toolbarButtonWidth
        this.AboutButtonWidth := toolbarButtonWidth
        this.SaveButtonWidth := compact ? MappingWindow.SaveButtonWidth
            : MappingWindow.ExpandedSaveButtonWidth
        actionButtonWidth := LocalizationService.IsChinese()
            ? MappingWindow.CompactActionButtonWidth
            : MappingWindow.ExpandedActionButtonMinWidth
        this.AddButtonWidth := actionButtonWidth
        this.PauseButtonWidth := actionButtonWidth
        this.DeleteButtonWidth := actionButtonWidth
        this.UpdateActionButtonPositions()
    }

    UpdateCommandButtonGroupWidths() {
        if !IsObject(this.AddButton) || !IsObject(this.SettingsButton)
            return false
        if !LocalizationService.IsChinese() {
            actionButtonWidth := this.MeasureActionButtonGroupWidth()
            this.AddButtonWidth := actionButtonWidth
            this.PauseButtonWidth := actionButtonWidth
            this.DeleteButtonWidth := actionButtonWidth

            toolbarButtonWidth := this.MeasureToolbarButtonGroupWidth()
            this.SettingsButtonWidth := toolbarButtonWidth
            this.SupportButtonWidth := toolbarButtonWidth
            this.AboutButtonWidth := toolbarButtonWidth
        }
        this.UpdateActionButtonPositions()
        requiredToolbarWidth := this.AddButtonWidth * 3
            + this.SettingsButtonWidth * 3
            + MappingWindow.TopButtonGap * 4
            + 40
        this.MinClientWidth := Max(this.MinClientWidth,
            requiredToolbarWidth)
        return true
    }

    MeasureActionButtonGroupWidth() {
        width := MappingWindow.ExpandedActionButtonMinWidth
        candidates := [
            {Control: this.AddButton, Text: this.GetAddButtonText()},
            {Control: this.PauseResumeButton,
                Text: this.GetPauseButtonText()},
            {Control: this.PauseResumeButton,
                Text: this.GetPauseButtonText("resume")},
            {Control: this.PauseResumeButton,
                Text: this.GetPauseButtonText("mixed")},
            {Control: this.DeleteButton, Text: this.GetDeleteButtonText()}
        ]
        for candidate in candidates {
            bodyText := candidate.Text
            if RegExMatch(bodyText, "^\S+\s+(.+)$", &match)
                bodyText := match[1]
            requiredWidth := this.MeasureControlTextWidth(
                candidate.Control, bodyText)
                + MappingWindow.ActionIconSlotWidth
                + MappingWindow.ActionIconGap
                + MappingWindow.ButtonContentPadding
            width := Max(width, requiredWidth)
        }
        return Ceil(width / 4) * 4
    }

    MeasureToolbarButtonGroupWidth() {
        width := MappingWindow.ExpandedToolbarButtonMinWidth
        for button in [this.SettingsButton, this.SupportButton,
                this.AboutButton] {
            requiredWidth := this.MeasureControlTextWidth(button,
                button.Text)
                + MappingWindow.ToolbarIconWidth
                + MappingWindow.ToolbarIconGap
                + MappingWindow.ButtonContentPadding
            width := Max(width, requiredWidth)
        }
        return Ceil(width / 4) * 4
    }

    UpdateActionButtonPositions() {
        this.PauseButtonX := 10 + this.AddButtonWidth
            + MappingWindow.TopButtonGap
        this.DeleteButtonX := this.PauseButtonX
            + this.PauseButtonWidth + MappingWindow.TopButtonGap
    }

    UpdatePauseResumeButton(rows := "") {
        if !IsObject(rows)
            rows := this.GetSelectedRows()
        if !rows.Length {
            this.Interactions.SetTextNoErase(this.PauseResumeButton,
                this.GetPauseButtonText())
            this.Interactions.SetButtonAppearance(this.PauseResumeButton,
                MappingWindow.Colors.PauseDisabled,
                MappingWindow.Colors.DisabledButtonText, false)
            return
        }
        firstEnabled := this.List.GetText(rows[1],
            MappingWindow.EnabledColumn) != "0"
        allSameState := true
        for row in rows {
            enabled := this.List.GetText(row,
                MappingWindow.EnabledColumn) != "0"
            if enabled != firstEnabled {
                allSameState := false
                break
            }
        }
        mode := allSameState ? (firstEnabled ? "pause" : "resume")
            : "mixed"
        this.Interactions.SetTextNoErase(this.PauseResumeButton,
            this.GetPauseButtonText(mode))
        this.Interactions.SetButtonAppearance(this.PauseResumeButton,
            MappingWindow.Colors.Pause, MappingWindow.Colors.ButtonText, true)
    }

    UpdateDeleteButton(rows := "") {
        if !IsObject(rows)
            rows := this.GetSelectedRows()
        hasSelection := rows.Length > 0
        this.Interactions.SetTextNoErase(this.DeleteButton,
            this.GetDeleteButtonText())
        this.Interactions.SetButtonAppearance(this.DeleteButton,
            hasSelection ? MappingWindow.Colors.Delete
                : MappingWindow.Colors.DeleteDisabled,
            hasSelection ? MappingWindow.Colors.ButtonText
                : MappingWindow.Colors.DisabledButtonText,
            hasSelection)
    }

    GetScopeDisplay(scope) => scope == "全局" ? Tr("全局") : scope

    GetMappingStatusDisplay(enabled) {
        return enabled ? Tr("启用") : Tr("暂停")
    }

    GetCaptureDetail(capture) {
        if !IsObject(capture) || !capture.HasOwnProp("DetailLines")
            return ""
        detail := capture.DetailLines
        if this.DistinguishModifierSidesCheck.Value
            return detail
        exactDisplay := capture.HasOwnProp("Display")
            ? capture.Display : (capture.HasOwnProp("RawDisplay")
                ? capture.RawDisplay : "")
        genericDisplay := this.GetCaptureDisplay(capture)
        return exactDisplay != "" && exactDisplay != genericDisplay
            ? StrReplace(detail, exactDisplay, genericDisplay, , , 1)
            : detail
    }

    GetCaptureDisplay(capture) {
        if !IsObject(capture)
            return ""
        display := capture.HasOwnProp("RawDisplay")
            ? capture.RawDisplay : capture.Display
        if this.DistinguishModifierSidesCheck.Value
            return display
        try return RuleSpec.NormalizeCapturedSourceDisplay(display)
        catch
            return display
    }

    GetCaptureButtonText(capture, placeholder) {
        if !IsObject(capture)
            return placeholder
        return this.GetCaptureDisplay(capture)
    }

    OnModifierSideDisplayChanged(*) {
        activeRole := ""
        displayChanged := false
        ; Keep the native checkbox clickable without leaving a keyboard-focus
        ; rectangle around its label after a mouse click.
        try DllCall("user32\SetFocus", "Ptr", this.SectionTitle.Hwnd, "Ptr")
        try {
            if IsObject(this.App.Capture) && this.App.Capture.Active
                activeRole := this.App.Capture.Role
        }
        if activeRole != "source" {
            displayChanged := this.Interactions.SetTextNoErase(
                this.SourceButton, this.GetCaptureButtonText(
                    this.SourceCapture, Tr("点击录制来源按键")))
                || displayChanged
            displayChanged := this.Interactions.SetTextNoErase(
                this.SourceDetail, this.GetCaptureDetail(this.SourceCapture))
                || displayChanged
        }
        if activeRole != "target" {
            displayChanged := this.Interactions.SetTextNoErase(
                this.TargetButton, this.GetCaptureButtonText(
                    this.TargetCapture, Tr("点击录制目标按键")))
                || displayChanged
            displayChanged := this.Interactions.SetTextNoErase(
                this.TargetDetail, this.GetCaptureDetail(this.TargetCapture))
                || displayChanged
        }
        if activeRole != ""
            this.App.Capture.PreviewHeldModifiers()
        else if displayChanged
            this.RefreshCaptureLayout()
        return true
    }

    BuildDashedDividerLayoutEntry(sectionY, contentWidth) {
        dividerY := sectionY - 6
        return {Control: this.SectionTopDivider, X: 10, Y: dividerY,
            Width: contentWidth, Height: 4}
    }

    SetStatus(text, isError := false) {
        this.StatusRevision++
        if !this.UpdateStatus(text, isError, false)
            return false
        return this.RefreshStatusLayoutIfNeeded()
    }

    GetStatusRevision() => this.StatusRevision

    IsCurrentStatus(text, isError := false, revision := 0) {
        return !this.Disposed && this.Status.Text == String(text)
            && this.StatusIsError == !!isError
            && (!revision || this.StatusRevision == Integer(revision))
    }

    SetTransientStatus(text) {
        if this.StatusIsError
            return false
        text := String(text)
        layoutResult := this.RefreshTransientStatusLayout(text, true)
        if IsObject(layoutResult)
            return layoutResult.Changed
        return this.UpdateStatus(text)
    }

    RefreshCaptureButtonIcons(activeRole := "") {
        if activeRole == "" {
            try {
                if IsObject(this.App.Capture) && this.App.Capture.Active
                    activeRole := this.App.Capture.Role
            }
        }
        this.RefreshCaptureButtonIcon(this.SourceButton, "source",
            this.SourceCapture, activeRole)
        this.RefreshCaptureButtonIcon(this.TargetButton, "target",
            this.TargetCapture, activeRole)
    }

    RefreshCaptureButtonIcon(button, role, capture, activeRole) {
        colors := MappingWindow.Colors
        if activeRole == role {
            this.Interactions.SetButtonAppearance(button, colors.Primary,
                colors.ButtonText, true)
            this.Interactions.ClearButtonIcon(button)
            return true
        }
        if IsObject(capture) {
            this.Interactions.SetButtonAppearance(button, colors.Add,
                colors.ButtonText, true)
            this.Interactions.ClearButtonIcon(button)
            return true
        }
        this.Interactions.SetButtonAppearance(button, colors.Toolbar,
            colors.Text, true)
        return this.Interactions.SetButtonLucideIcons(button,
            "keyboard.svg", "mouse.svg", 17, 8,
            UiThemeService.ButtonIconColor(colors.RulesEventIcon),
            UiThemeService.ButtonIconColor(colors.LanguageIcon))
    }

    IsPointerOverCaptureButton(controlHwnd := 0) {
        controlHwnd := this.GetPointerButtonHwnd(controlHwnd)
        return controlHwnd == this.SourceButton.Hwnd
            || controlHwnd == this.TargetButton.Hwnd
            || controlHwnd == this.ClearButton.Hwnd
    }

    SuppressNextPointerButtonActivation(controlHwnd := 0) {
        buttonHwnd := this.GetPointerButtonHwnd(controlHwnd)
        if !buttonHwnd
            return false
        this.PendingCapturePointerAction := buttonHwnd
                == this.ClearButton.Hwnd ? "clear" : ""
        return this.Interactions.SuppressNextButtonActivation(buttonHwnd)
    }

    FinalizePointerButtonCancellation() {
        result := this.Interactions.ScheduleSuppressedButtonActivationReset()
        if this.PendingCapturePointerAction == "clear" {
            this.PendingCapturePointerAction := ""
            SetTimer(this.PendingCapturePointerActionTimer, -1)
        }
        return result
    }

    RunPendingCapturePointerAction(*) {
        if this.Disposed
            return false
        this.ClearEditor()
        return true
    }

    SuppressEscapeAfterCapture(timeoutMs := 500) {
        this.EscapeAfterCaptureDeadline := A_TickCount
            + Max(1, Integer(timeoutMs))
        return true
    }

    ConsumeEscapeAfterCapture() {
        deadline := this.EscapeAfterCaptureDeadline
        this.EscapeAfterCaptureDeadline := 0
        return deadline && A_TickCount <= deadline
    }

    GetPointerButtonHwnd(controlHwnd := 0) {
        ; During capture the low-level mouse guard consumes WM_LBUTTON* before
        ; the GUI control can process it. Use the physical cursor position and
        ; the buttons' screen rectangles as the authoritative hit test.
        if !controlHwnd {
            ; The low-level hook records the click's point before the message
            ; can be delayed. Prefer that transaction-bound point over the
            ; cursor's later position.
            try {
                hookPoint := this.App.Capture.InputGuard.GetLastMousePoint(2000)
                if IsObject(hookPoint) {
                    for button in [this.SourceButton, this.TargetButton,
                        this.ClearButton] {
                        if this.IsPointInsideWindow(button.Hwnd, hookPoint.X,
                                hookPoint.Y)
                            return button.Hwnd
                    }
                }
            }
            catch
                hookPoint := ""
            point := Buffer(8, 0)
            if !DllCall("user32\GetCursorPos", "Ptr", point, "Int")
                return 0
            x := NumGet(point, 0, "Int")
            y := NumGet(point, 4, "Int")
            for button in [this.SourceButton, this.TargetButton,
                this.ClearButton] {
                if this.IsPointInsideWindow(button.Hwnd, x, y)
                    return button.Hwnd
            }
            ; MouseGetPos can still identify a child when the cursor moved
            ; between the Raw Input packet and GetCursorPos. Keep it only as a
            ; secondary fallback, never as the primary hit test.
            try MouseGetPos(, , , &fallbackHwnd, 2)
            catch
                fallbackHwnd := 0
            if fallbackHwnd && this.CaptureButtonHwnds.Has(fallbackHwnd)
                return fallbackHwnd
            return 0
        }
        while controlHwnd {
            if this.Interactions.Controls.Has(controlHwnd) {
                state := this.Interactions.Controls[controlHwnd]
                return state.Kind == "button" ? controlHwnd : 0
            }
            if controlHwnd == this.Gui.Hwnd
                break
            controlHwnd := DllCall("user32\GetParent", "Ptr", controlHwnd,
                "Ptr")
        }
        return 0
    }

    IsPointInsideWindow(hwnd, x, y) {
        if !hwnd || !DllCall("user32\IsWindow", "Ptr", hwnd, "Int")
                || !DllCall("user32\IsWindowVisible", "Ptr", hwnd, "Int")
            return false
        rect := Buffer(16, 0)
        if !DllCall("user32\GetWindowRect", "Ptr", hwnd, "Ptr", rect, "Int")
            return false
        left := NumGet(rect, 0, "Int")
        top := NumGet(rect, 4, "Int")
        right := NumGet(rect, 8, "Int")
        bottom := NumGet(rect, 12, "Int")
        return x >= left && x < right && y >= top && y < bottom
    }

    UpdateStatus(text, isError := false, advanceRevision := true) {
        text := String(text)
        isError := !!isError
        textChanged := this.Status.Text != text
        wasVisible := false
        if textChanged {
            ; The status editor uses no-erase redraws to avoid flicker. When a
            ; longer status is replaced by a shorter one, hide the child first
            ; so the old second line is removed instead of being left behind.
            wasVisible := DllCall("user32\IsWindowVisible",
                "Ptr", this.Status.Hwnd, "Int") != 0
            if wasVisible
                DllCall("user32\ShowWindow", "Ptr", this.Status.Hwnd,
                    "Int", 0, "Int")
            this.Interactions.SetTextNoErase(this.Status, text)
            this.NormalizeStatusViewport(true)
            if wasVisible {
                DllCall("user32\ShowWindow", "Ptr", this.Status.Hwnd,
                    "Int", 4, "Int")
                this.NormalizeStatusViewport()
                this.RedrawStatusSurface()
            }
        }
        styleChanged := this.StatusIsError != isError
        if !textChanged && !styleChanged
            return false
        if advanceRevision
            this.StatusRevision++
        this.StatusIsError := isError
        if styleChanged {
            this.Status.SetFont("c" (isError ? MappingWindow.Colors.Error
                : MappingWindow.Colors.Muted))
            UiScaleService.RefreshGuiFonts(this.Gui)
            ; WM_SETFONT resets the native Edit formatting rectangle. Restore
            ; the wrapped-status viewport after the new font is installed.
            this.NormalizeStatusViewport()
            this.RedrawStatusSurface()
        }
        this.Interactions.HideTextInputCaret(this.Status.Hwnd)
        return true
    }

    NormalizeStatusViewport(resetSelection := false) {
        if this.Disposed || !IsObject(this.Status) || !this.Status.Hwnd
            return false
        hwnd := this.Status.Hwnd
        if !DllCall("user32\IsWindow", "Ptr", hwnd, "Int")
            return false
        if resetSelection
            SendMessage(Win32.EM_SETSEL, 0, 0, , hwnd)
        ; The status control is sized to its wrapped text. Keep the native
        ; Edit formatting rectangle in sync with that size, then remove any
        ; focus- or wheel-induced vertical offset so the first line is whole.
        SetMultilineEditPadding(hwnd, 1, 2, 1, 2)
        SendMessage(Win32.EM_LINESCROLL, 0, -0x7FFF, , hwnd)
        this.Interactions.HideTextInputCaret(hwnd)
        return true
    }

    RedrawStatusSurface() {
        if this.Disposed || !IsObject(this.Status) || !this.Status.Hwnd
            return false
        hwnd := this.Status.Hwnd
        if !DllCall("user32\IsWindow", "Ptr", hwnd, "Int")
            return false
        if !DllCall("user32\IsWindowVisible", "Ptr", hwnd, "Int")
            return true
        ; EM_SETRECT updates the native Edit viewport but does not repaint it.
        ; Erase and redraw only this child so a newly exposed first line never
        ; retains pixels rendered against the previous one-line viewport.
        return DllCall("user32\RedrawWindow", "Ptr", hwnd,
            "Ptr", 0, "Ptr", 0, "UInt", 0x0105, "Int") != 0
    }

    RefreshStatusLayoutIfNeeded() {
        if this.Disposed
            return false
        try this.Gui.GetClientPos(, , &width, &height)
        catch
            return false
        if width <= 0 || height <= 0
            return false
        width := UiScaleService.ToDesign(width)
        height := UiScaleService.ToDesign(height)
        statusLayout := this.GetStatusLayout(width)
        try UiScaleService.GetControlDesignPos(this.Status, , ,
            &currentWidth, &currentHeight)
        catch
            return false
        if currentWidth == statusLayout.Width
                && currentHeight == statusLayout.Height
            return true
        return this.ApplyLayout(width, height)
    }

    RefreshTransientStatusLayout(text := unset, updateText := false) {
        if this.Disposed
            return false
        try this.Gui.GetClientPos(, , &width, &height)
        catch
            return false
        if width <= 0 || height <= 0
            return false
        width := UiScaleService.ToDesign(width)
        height := UiScaleService.ToDesign(height)
        statusLayout := IsSet(text)
            ? this.GetStatusLayout(width, "", text)
            : this.GetStatusLayout(width)
        statusY := height - MappingWindow.StatusBottomMargin
            - statusLayout.Height
        try UiScaleService.GetControlDesignPos(this.Status, &currentX,
            &currentY, &currentWidth, &currentHeight)
        catch
            return false
        if currentX == 10 && currentY == statusY
                && currentWidth == statusLayout.Width
                && currentHeight == statusLayout.Height
            return false
        statusHwnd := this.Status.Hwnd
        wasVisible := DllCall("user32\IsWindowVisible", "Ptr", statusHwnd,
            "Int") != 0
        hadFocus := DllCall("user32\GetFocus", "Ptr") == statusHwnd
        if wasVisible
            DllCall("user32\ShowWindow", "Ptr", statusHwnd, "Int", 0,
                "Int") ; SW_HIDE removes the old child composition surface.
        textChanged := false
        try {
            result := AtomicControlLayout.Apply(this.Gui, [{
                Control: this.Status, X: 10, Y: statusY,
                Width: statusLayout.Width, Height: statusLayout.Height
            }], {ParentColor: MappingWindow.Colors.Window, ClearMargin: 2})
            if updateText && IsSet(text)
                textChanged := this.UpdateStatus(text)
        } finally {
            if wasVisible {
                DllCall("user32\ShowWindow", "Ptr", statusHwnd, "Int", 4,
                    "Int") ; SW_SHOWNOACTIVATE
                if hadFocus {
                    DllCall("user32\SetFocus", "Ptr", statusHwnd, "Ptr")
                }
                this.NormalizeStatusViewport()
                this.RedrawStatusSurface()
            }
        }
        changed := IsObject(result)
            && result.Status == AtomicControlLayout.Applied
            && result.Changed
        return {Changed: changed || textChanged, LayoutChanged: changed,
            TextChanged: textChanged}
    }

    GetStatusLayout(width, layoutRound := "", text := unset) {
        statusWidth := Max(1, width - 20)
        statusText := IsSet(text) ? String(text) : this.Status.Text
        textHeight := this.Interactions.Painter.MeasureTextHeight(this.Status,
            statusText, statusWidth, 0, 0, layoutRound)
        statusHeight := Max(MappingWindow.MinStatusHeight, textHeight + 4)
        return {
            Width: statusWidth,
            Height: statusHeight,
            Extra: Max(0, statusHeight - MappingWindow.MinStatusHeight)
        }
    }

    GetCommandLayout(editor) {
        availableWidth := Max(1, editor.NameWidth)
        buttonGap := MappingWindow.CommandButtonGap
        saveWidth := Max(1, Floor((availableWidth - buttonGap) / 2))
        clearWidth := Max(1, availableWidth - buttonGap - saveWidth)
        saveX := editor.NameX
        clearX := saveX + saveWidth + buttonGap
        return {
            SaveButtonX: saveX,
            SaveButtonWidth: saveWidth,
            ClearButtonX: clearX,
            ClearButtonWidth: clearWidth
        }
    }

    RefreshCaptureLayout(force := false, *) {
        if this.Disposed
            return false
        this.CancelPendingResize()
        try this.Gui.GetClientPos(, , &width, &height)
        catch
            return false
        if width <= 0 || height <= 0
            return false
        width := UiScaleService.ToDesign(width)
        height := UiScaleService.ToDesign(height)
        return this.ApplyLayout(width, height, force)
    }

    CancelPendingResize() {
        return true
    }

    GetCaptureControlHeights(inputWidth, layoutRound := "") {
        buttonTextHeight := 0
        for control in [this.SourceButton, this.TargetButton] {
            state := this.Interactions.Controls[control.Hwnd]
            buttonTextHeight := Max(buttonTextHeight,
                this.Interactions.Painter.MeasureButtonTextHeight(control,
                    control.Text, inputWidth, state, layoutRound))
        }
        detailTextHeight := 0
        for control in [this.SourceDetail, this.TargetDetail] {
            detailTextHeight := Max(detailTextHeight,
                this.Interactions.Painter.MeasureTextHeight(control,
                    control.Text, inputWidth, 0, 0, layoutRound))
        }
        nameCommandStackHeight := this.NameInputHeight
            + MappingWindow.EditorToCommandGap
            + MappingWindow.CommandButtonHeight
        return {
            Button: Max(MappingWindow.MinCaptureButtonHeight,
                nameCommandStackHeight, buttonTextHeight + 16),
            Detail: Max(MappingWindow.MinCaptureDetailHeight,
                detailTextHeight + 4)
        }
    }

    EnsureCaptureMinimumSize(requiredHeight, currentWidth, currentHeight) {
        if requiredHeight != this.RequiredClientHeight
                || this.MinClientWidth != this.RequiredClientWidth {
            this.RequiredClientHeight := requiredHeight
            this.RequiredClientWidth := this.MinClientWidth
            this.Gui.Opt(UiScaleService.ScaleMinSizeOptions(
                this.MinClientWidth, requiredHeight))
        }
        if (currentWidth >= this.MinClientWidth
                && currentHeight >= requiredHeight) || this.LayoutResizeActive
            return false
        this.LayoutResizeActive := true
        try {
            sizeOptions := (currentWidth < this.MinClientWidth
                ? "w" this.MinClientWidth : "")
                . (currentHeight < requiredHeight ? " h" requiredHeight : "")
            showOptions := DllCall("user32\IsWindowVisible", "Ptr",
                this.Gui.Hwnd, "Int")
                ? sizeOptions " NoActivate"
                : "Hide " sizeOptions " NoActivate"
            this.Gui.Show(UiScaleService.ScaleShowOptions(showOptions))
            this.ApplyNativeThemes()
        } finally {
            this.LayoutResizeActive := false
        }
        return true
    }

    EnsureListRowMetrics(layoutRound := "", forceRefresh := false) {
        if this.Disposed || !IsObject(this.List) || !this.List.Hwnd
            return false
        rowDpi := IsObject(layoutRound) && layoutRound.HasOwnProp("Dpi")
            ? layoutRound.Dpi
            : UiScaleService.GetEffectiveDpi(this.List.Hwnd)
        if this.ListRowImageList && this.ListMetricsImageList
                && this.ListRowDpi == rowDpi && !forceRefresh
            return false

        statusImageList := IL_Create(2, 1, false)
        if !statusImageList
            return false
        rowHeightPixels := Max(1,
            Round(MappingWindow.ListRowHeight * rowDpi / 96))
        iconCellWidthPixels := Max(MappingWindow.ListStatusIconSlotDip,
            Round(MappingWindow.ListStatusIconSlotDip * rowDpi / 96))
        if !DllCall("comctl32\ImageList_SetIconSize", "Ptr",
                statusImageList,
                "Int", iconCellWidthPixels, "Int", rowHeightPixels, "Int") {
            IL_Destroy(statusImageList)
            return false
        }
        statusIconIndices := this.AddListStatusIcons(statusImageList, rowDpi,
            iconCellWidthPixels, rowHeightPixels)
        metricsImageList := IL_Create(1, 1, false)
        if !metricsImageList {
            IL_Destroy(statusImageList)
            return false
        }
        if !DllCall("comctl32\ImageList_SetIconSize", "Ptr",
                metricsImageList, "Int", 1, "Int", rowHeightPixels, "Int") {
            IL_Destroy(metricsImageList)
            IL_Destroy(statusImageList)
            return false
        }

        oldStatusImageList := this.ListRowImageList
        oldMetricsImageList := this.ListMetricsImageList
        try {
            this.List.SetImageList(metricsImageList, 1)
            this.List.IL := metricsImageList
            this.ListRowImageList := statusImageList
            this.ListMetricsImageList := metricsImageList
            this.ListRowDpi := rowDpi
            this.ListStatusIconIndices := statusIconIndices
            this.RefreshListStatusIcons()
        } catch {
            IL_Destroy(metricsImageList)
            IL_Destroy(statusImageList)
            return false
        }
        if oldStatusImageList
            try IL_Destroy(oldStatusImageList)
        if oldMetricsImageList
            try IL_Destroy(oldMetricsImageList)
        return true
    }

    AddListStatusIcons(imageList, rowDpi, cellWidth, cellHeight) {
        indices := Map()
        if !imageList || !this.App.HasOwnProp("SvgRenderer")
                || !IsObject(this.App.SvgRenderer)
            return indices
        iconSize := Max(14, Round(16 * rowDpi / 96))
        iconFiles := Map(
            1, "circle-check-big.svg",
            0, "circle-pause.svg")
        for enabled, iconFile in iconFiles {
            iconPath := GetApplicationAssetPath(
                "ui-icons\lucide\" iconFile)
            snapshot := this.App.SvgRenderer.RenderFile(iconPath, rowDpi,
                iconSize)
            if !snapshot
                continue
            snapshot := this.Interactions.TintIconSnapshot(snapshot,
                enabled ? MappingWindow.Colors.StatusEnabledIcon
                    : MappingWindow.Colors.StatusPausedIcon)
            if !snapshot
                continue
            iconHandle := this.CreateListStatusIcon(snapshot, cellWidth,
                cellHeight)
            if !iconHandle
                continue
            try iconIndex := IL_Add(imageList, "HICON:" iconHandle)
            finally DllCall("user32\DestroyIcon", "Ptr", iconHandle)
            if iconIndex > 0
                indices[enabled] := iconIndex
        }
        return indices
    }

    CreateListStatusIcon(snapshot, cellWidth, cellHeight) {
        if !IsObject(snapshot) || !snapshot.HasOwnProp("Width")
                || !snapshot.HasOwnProp("Height")
                || !snapshot.HasOwnProp("Pixels")
                || snapshot.Width <= 0 || snapshot.Height <= 0
                || snapshot.Width > cellWidth || snapshot.Height > cellHeight
                || snapshot.Pixels.Size < snapshot.Width * snapshot.Height * 4
            return 0
        screenDC := DllCall("user32\GetDC", "Ptr", 0, "Ptr")
        colorBitmap := 0
        maskBitmap := 0
        try {
            if !screenDC
                return 0
            bitmapInfo := Buffer(40, 0)
            NumPut("UInt", 40, bitmapInfo, 0)
            NumPut("Int", cellWidth, bitmapInfo, 4)
            NumPut("Int", -cellHeight, bitmapInfo, 8)
            NumPut("UShort", 1, bitmapInfo, 12)
            NumPut("UShort", 32, bitmapInfo, 14)
            colorBits := 0
            colorBitmap := DllCall("gdi32\CreateDIBSection", "Ptr",
                screenDC, "Ptr", bitmapInfo, "UInt", 0, "Ptr*", &colorBits,
                "Ptr", 0, "UInt", 0, "Ptr")
            if !colorBitmap || !colorBits
                return 0
            DllCall("ntdll\RtlZeroMemory", "Ptr", colorBits, "UPtr",
                cellWidth * cellHeight * 4)
            ; Keep the 20-DIP image slot, but bias the glyph one DIP left so
            ; the native ListView text does not crowd the icon.
            offsetX := Max(0, Floor((cellWidth - snapshot.Width) / 2)
                - Max(1, Round(cellWidth / 20)))
            offsetY := Floor((cellHeight - snapshot.Height) / 2)
            Loop snapshot.Height {
                row := A_Index - 1
                destination := colorBits
                    + ((offsetY + row) * cellWidth + offsetX) * 4
                source := snapshot.Pixels.Ptr + row * snapshot.Width * 4
                DllCall("ntdll\RtlMoveMemory", "Ptr", destination,
                    "Ptr", source, "UPtr", snapshot.Width * 4)
            }
            maskBitmap := this.CreateListStatusIconMask(screenDC, colorBits,
                cellWidth, cellHeight)
            if !maskBitmap
                return 0
            iconInfo := Buffer(A_PtrSize == 8 ? 32 : 20, 0)
            NumPut("Int", 1, iconInfo, 0)
            bitmapOffset := A_PtrSize == 8 ? 16 : 12
            NumPut("Ptr", maskBitmap, iconInfo, bitmapOffset)
            NumPut("Ptr", colorBitmap, iconInfo,
                bitmapOffset + A_PtrSize)
            return DllCall("user32\CreateIconIndirect", "Ptr", iconInfo,
                "Ptr")
        } finally {
            if maskBitmap
                try DllCall("gdi32\DeleteObject", "Ptr", maskBitmap)
            if colorBitmap
                try DllCall("gdi32\DeleteObject", "Ptr", colorBitmap)
            if screenDC
                try DllCall("user32\ReleaseDC", "Ptr", 0, "Ptr", screenDC)
        }
    }

    CreateListStatusIconMask(screenDC, colorBits, width, height) {
        maskStride := Floor((width + 31) / 32) * 4
        bitmapInfo := Buffer(48, 0)
        NumPut("UInt", 40, bitmapInfo, 0)
        NumPut("Int", width, bitmapInfo, 4)
        NumPut("Int", -height, bitmapInfo, 8)
        NumPut("UShort", 1, bitmapInfo, 12)
        NumPut("UShort", 1, bitmapInfo, 14)
        NumPut("UInt", 0x00000000, bitmapInfo, 40)
        NumPut("UInt", 0x00FFFFFF, bitmapInfo, 44)
        maskBits := 0
        maskBitmap := DllCall("gdi32\CreateDIBSection", "Ptr", screenDC,
            "Ptr", bitmapInfo, "UInt", 0, "Ptr*", &maskBits,
            "Ptr", 0, "UInt", 0, "Ptr")
        if !maskBitmap
            return 0
        if !maskBits {
            DllCall("gdi32\DeleteObject", "Ptr", maskBitmap)
            return 0
        }
        Loop maskStride * height
            NumPut("UChar", 0xFF, maskBits, A_Index - 1)
        Loop height {
            y := A_Index - 1
            Loop width {
                x := A_Index - 1
                alpha := NumGet(colorBits,
                    (y * width + x) * 4 + 3, "UChar")
                if alpha > 8 {
                    byteOffset := y * maskStride + (x >> 3)
                    bitMask := 0x80 >> (x & 7)
                    value := NumGet(maskBits, byteOffset, "UChar")
                    NumPut("UChar", value & ~bitMask, maskBits, byteOffset)
                }
            }
        }
        return maskBitmap
    }

    SetMappingStatusIcon(row, enabled) {
        if row < 1 || !IsObject(this.List) || !this.List.Hwnd
            return false
        stateKey := enabled ? 1 : 0
        ; The attached 1px list controls row height only. Status icons live in
        ; the independent 20px resource list and are custom-drawn, so native
        ; ListView layout cannot add an icon slot to the name column.
        nameCleared := this.SetListSubItemIcon(row,
            MappingWindow.NameColumn, 0)
        statusCleared := this.SetListSubItemIcon(row,
            MappingWindow.StatusColumn, 0)
        return nameCleared && statusCleared
    }

    SetListSubItemIcon(row, column, iconIndex, indent := 0) {
        listItem := Buffer(A_PtrSize == 8 ? 88 : 60, 0)
        mask := Win32.LVIF_IMAGE
        if indent > 0
            mask |= Win32.LVIF_INDENT
        NumPut("UInt", mask, listItem, 0)
        NumPut("Int", row - 1, listItem, 4)
        NumPut("Int", column - 1, listItem, 8)
        NumPut("Int", iconIndex > 0 ? iconIndex - 1 : -1, listItem,
            A_PtrSize == 8 ? 36 : 28)
        if indent > 0
            NumPut("Int", indent, listItem,
                A_PtrSize == 8 ? 48 : 36)
        return SendMessage(Win32.LVM_SETITEMW, 0, listItem.Ptr, ,
            this.List.Hwnd) != 0
    }

    GetListSubItemRect(row, column) {
        if row < 1 || column < 1 || !IsObject(this.List) || !this.List.Hwnd
            return ""
        rect := Buffer(16, 0)
        if column == MappingWindow.NameColumn {
            ; LVM_GETSUBITEMRECT treats the primary item column as the
            ; complete row. The mapping list displays that column after the
            ; sequence column, so derive its visual X position from the
            ; current native column order and keep the row's Y bounds.
            NumPut("Int", Win32.LVIR_BOUNDS, rect, 0)
            if !SendMessage(Win32.LVM_GETITEMRECT, row - 1, rect.Ptr, ,
                    this.List.Hwnd)
                return ""
            left := this.GetListDisplayColumnLeft(column)
            width := SendMessage(Win32.LVM_GETCOLUMNWIDTH, column - 1, 0, ,
                this.List.Hwnd)
            if left == "" || width <= 0
                return ""
            return {
                Left: left,
                Top: NumGet(rect, 4, "Int"),
                Right: left + width,
                Bottom: NumGet(rect, 12, "Int")
            }
        }
        NumPut("Int", Win32.LVIR_BOUNDS, rect, 0)
        NumPut("Int", column - 1, rect, 4)
        if !SendMessage(Win32.LVM_GETSUBITEMRECT, row - 1, rect.Ptr, ,
                this.List.Hwnd)
            return ""
        return {
            Left: NumGet(rect, 0, "Int"),
            Top: NumGet(rect, 4, "Int"),
            Right: NumGet(rect, 8, "Int"),
            Bottom: NumGet(rect, 12, "Int")
        }
    }

    GetListDisplayColumnLeft(column) {
        if column < 1 || column > MappingWindow.EnabledColumn
            return ""
        columnCount := MappingWindow.EnabledColumn
        order := Buffer(columnCount * 4, 0)
        if !SendMessage(Win32.LVM_GETCOLUMNORDERARRAY, columnCount,
                order.Ptr, , this.List.Hwnd)
            return ""
        left := 0
        Loop columnCount {
            logicalColumn := NumGet(order, (A_Index - 1) * 4, "Int") + 1
            if logicalColumn == column
                return left
            width := SendMessage(Win32.LVM_GETCOLUMNWIDTH,
                logicalColumn - 1, 0, , this.List.Hwnd)
            if width > 0
                left += width
        }
        return ""
    }

    GetListCellTextAvailableWidth(row, column) {
        if column == MappingWindow.NameColumn
                || column == MappingWindow.SourceColumn
                || column == MappingWindow.TargetColumn {
            textRect := this.GetLeftAlignedListTextRect(row, column)
            return IsObject(textRect)
                ? Max(0, textRect.Right - textRect.Left) : ""
        }
        cellRect := this.GetListSubItemRect(row, column)
        if !IsObject(cellRect)
            return ""
        cellWidth := cellRect.Right - cellRect.Left
        if cellWidth <= 0
            return 0
        dpi := this.GetListDpi()
        if column == MappingWindow.StatusColumn {
            iconWidth := Max(MappingWindow.ListStatusIconSlotDip,
                Round(MappingWindow.ListStatusIconSlotDip * dpi / 96))
            if this.ListRowImageList {
                measuredIconWidth := 0
                measuredIconHeight := 0
                if DllCall("comctl32\ImageList_GetIconSize", "Ptr",
                        this.ListRowImageList, "Int*", &measuredIconWidth,
                        "Int*", &measuredIconHeight, "Int")
                        && measuredIconWidth > 0
                    iconWidth := measuredIconWidth
            }
            gap := Max(2,
                Round(MappingWindow.ListStatusIconGapDip * dpi / 96))
            return Max(0, cellWidth - iconWidth - gap)
        }
        return ""
    }

    GetLeftAlignedListTextRect(row, column) {
        if column != MappingWindow.NameColumn
                && column != MappingWindow.SourceColumn
                && column != MappingWindow.TargetColumn
            return ""
        cellRect := this.GetListSubItemRect(row, column)
        if !IsObject(cellRect)
            return ""
        dpi := this.GetListDpi()
        inset := Max(1, Round(MappingWindow.ListTextInsetDip * dpi / 96))
        return {
            Left: cellRect.Left + inset,
            Top: cellRect.Top,
            Right: Max(cellRect.Left + inset, cellRect.Right - inset),
            Bottom: cellRect.Bottom,
            Cell: cellRect,
            Inset: inset
        }
    }

    DrawListSubItem(listView, notification) {
        subItemOffset := A_PtrSize == 8 ? 88 : 56
        column := NumGet(notification, subItemOffset, "Int") + 1
        if column == MappingWindow.SequenceColumn
            return this.DrawSequenceListSubItem(listView, notification)
        if column == MappingWindow.NameColumn
                || column == MappingWindow.SourceColumn
                || column == MappingWindow.TargetColumn
            return this.DrawLeftAlignedListSubItem(listView, notification,
                column)
        if column != MappingWindow.StatusColumn
            return
        itemSpecOffset := A_PtrSize == 8 ? 56 : 36
        row := NumGet(notification, itemSpecOffset, "UPtr") + 1
        if row < 1 || row > listView.GetCount()
            return Win32.CDRF_SKIPDEFAULT

        hdcOffset := A_PtrSize == 8 ? 32 : 16
        rectOffset := A_PtrSize == 8 ? 40 : 20
        hdc := NumGet(notification, hdcOffset, "Ptr")
        fallbackRect := {
            Left: NumGet(notification, rectOffset, "Int"),
            Top: NumGet(notification, rectOffset + 4, "Int"),
            Right: NumGet(notification, rectOffset + 8, "Int"),
            Bottom: NumGet(notification, rectOffset + 12, "Int")
        }
        cellRect := this.GetListSubItemRect(row, MappingWindow.StatusColumn)
        if !IsObject(cellRect)
            cellRect := fallbackRect
        left := cellRect.Left
        top := cellRect.Top
        right := cellRect.Right
        bottom := cellRect.Bottom
        if !hdc || right <= left || bottom <= top
            return Win32.CDRF_SKIPDEFAULT

        iconWidth := 0
        iconHeight := 0
        if this.ListRowImageList
            DllCall("comctl32\ImageList_GetIconSize", "Ptr",
                this.ListRowImageList, "Int*", &iconWidth, "Int*",
                &iconHeight, "Int")
        if iconWidth <= 0
            iconWidth := Max(MappingWindow.ListStatusIconSlotDip,
                Round(MappingWindow.ListStatusIconSlotDip
                    * this.GetListDpi() / 96))
        if iconHeight <= 0
            iconHeight := bottom - top

        text := listView.GetText(row, MappingWindow.StatusColumn)
        font := SendMessage(Win32.WM_GETFONT, 0, 0, , listView.Hwnd)
        previousFont := font ? DllCall("gdi32\SelectObject", "Ptr", hdc,
            "Ptr", font, "Ptr") : 0
        textExtent := Buffer(8, 0)
        textWidth := 0
        previousBkMode := 0
        previousTextColor := 0
        try {
            if text != ""
                DllCall("gdi32\GetTextExtentPoint32W", "Ptr", hdc,
                    "Str", text, "Int", StrLen(text), "Ptr", textExtent,
                    "Int")
            textWidth := NumGet(textExtent, 0, "Int")
            gap := Max(2, Round(MappingWindow.ListStatusIconGapDip
                * this.GetListDpi() / 96))
            groupWidth := iconWidth + (textWidth > 0 ? gap + textWidth : 0)
            groupX := left + Max(0, Floor((right - left - groupWidth) / 2))
            iconY := top + Max(0, Floor((bottom - top - iconHeight) / 2))
            stateKey := this.List.GetText(row, MappingWindow.EnabledColumn)
                == "1" ? 1 : 0
            iconIndex := this.ListStatusIconIndices.Has(stateKey)
                ? this.ListStatusIconIndices[stateKey] : 0
            if iconIndex && this.ListRowImageList
                DllCall("comctl32\ImageList_DrawEx", "Ptr",
                    this.ListRowImageList, "Int", iconIndex - 1, "Ptr", hdc,
                    "Int", groupX, "Int", iconY, "Int", iconWidth,
                    "Int", iconHeight, "UInt", 0xFFFFFFFF, "UInt",
                    0xFFFFFFFF, "UInt", 0x00000001, "Int") ; ILD_TRANSPARENT
            if textWidth > 0 {
                previousBkMode := DllCall("gdi32\SetBkMode", "Ptr", hdc,
                    "Int", 1, "Int") ; TRANSPARENT
                previousTextColor := DllCall("gdi32\SetTextColor", "Ptr",
                    hdc, "UInt", ColorRef(MappingWindow.Colors.Text), "UInt")
                textRect := Buffer(16, 0)
                NumPut("Int", groupX + iconWidth + gap, textRect, 0)
                NumPut("Int", top, textRect, 4)
                NumPut("Int", right, textRect, 8)
                NumPut("Int", bottom, textRect, 12)
                DllCall("user32\DrawTextW", "Ptr", hdc, "Str", text,
                    "Int", StrLen(text), "Ptr", textRect,
                    "UInt", 0x00000024 | 0x00000800, "Int")
            }
        } finally {
            if previousTextColor
                DllCall("gdi32\SetTextColor", "Ptr", hdc, "UInt",
                    previousTextColor, "UInt")
            if previousBkMode
                DllCall("gdi32\SetBkMode", "Ptr", hdc, "Int",
                    previousBkMode, "Int")
            if previousFont
                DllCall("gdi32\SelectObject", "Ptr", hdc, "Ptr",
                    previousFont, "Ptr")
        }
        return Win32.CDRF_SKIPDEFAULT
    }

    DrawSequenceListSubItem(listView, notification) {
        itemSpecOffset := A_PtrSize == 8 ? 56 : 36
        row := NumGet(notification, itemSpecOffset, "UPtr") + 1
        if row < 1 || row > listView.GetCount()
            return Win32.CDRF_SKIPDEFAULT
        mappingId := listView.GetText(row, MappingWindow.NameColumn)
        presetKey := HasMethod(this.App, "GetRuleColor")
            ? this.App.GetRuleColor(mappingId) : ""
        if presetKey == ""
            return
        cellRect := this.GetListSubItemRect(row,
            MappingWindow.SequenceColumn)
        hdcOffset := A_PtrSize == 8 ? 32 : 16
        hdc := NumGet(notification, hdcOffset, "Ptr")
        if !IsObject(cellRect) || !hdc
            return Win32.CDRF_SKIPDEFAULT

        text := listView.GetText(row, MappingWindow.SequenceColumn)
        font := SendMessage(Win32.WM_GETFONT, 0, 0, , listView.Hwnd)
        previousFont := font ? DllCall("gdi32\SelectObject", "Ptr", hdc,
            "Ptr", font, "Ptr") : 0
        previousBkMode := DllCall("gdi32\SetBkMode", "Ptr", hdc,
            "Int", 1, "Int")
        previousTextColor := DllCall("gdi32\SetTextColor", "Ptr", hdc,
            "UInt", ColorRef(MappingWindow.Colors.Text), "UInt")
        try {
            textExtent := TextVisualAlignment.MeasureText(hdc, text)
            dpi := this.GetListDpi()
            dotSize := Max(4, Round(MappingWindow.SequenceDotDiameterDip
                * dpi / 96))
            selectionInset := Max(2, Round(
                ListViewSelectionPresenter.HorizontalInsetDip * dpi / 96))
            layout := this.CalculateSequenceDotLayout(cellRect,
                textExtent.Width, dotSize, selectionInset)
            if !this.Interactions.Painter.FillEllipse(hdc, layout.DotLeft,
                    layout.DotTop, dotSize, dotSize,
                    RuleColorPalette.Color(presetKey)) {
                brush := DllCall("gdi32\CreateSolidBrush", "UInt",
                    ColorRef(RuleColorPalette.Color(presetKey)), "Ptr")
                if brush {
                    previousBrush := DllCall("gdi32\SelectObject", "Ptr",
                        hdc, "Ptr", brush, "Ptr")
                    nullPen := DllCall("gdi32\GetStockObject", "Int", 8,
                        "Ptr")
                    previousPen := nullPen ? DllCall("gdi32\SelectObject",
                        "Ptr", hdc, "Ptr", nullPen, "Ptr") : 0
                    try DllCall("gdi32\Ellipse", "Ptr", hdc,
                        "Int", layout.DotLeft, "Int", layout.DotTop,
                        "Int", layout.DotLeft + dotSize,
                        "Int", layout.DotTop + dotSize)
                    finally {
                        if previousPen
                            DllCall("gdi32\SelectObject", "Ptr", hdc,
                                "Ptr", previousPen, "Ptr")
                        if previousBrush
                            DllCall("gdi32\SelectObject", "Ptr", hdc,
                                "Ptr", previousBrush, "Ptr")
                        DllCall("gdi32\DeleteObject", "Ptr", brush)
                    }
                }
            }
            textRect := Buffer(16, 0)
            NumPut("Int", layout.TextLeft, textRect, 0)
            NumPut("Int", cellRect.Top, textRect, 4)
            NumPut("Int", Min(cellRect.Right,
                layout.TextLeft + textExtent.Width), textRect, 8)
            NumPut("Int", cellRect.Bottom, textRect, 12)
            if text != ""
                DllCall("user32\DrawTextW", "Ptr", hdc, "Str", text,
                    "Int", StrLen(text), "Ptr", textRect,
                    "UInt", 0x00000824, "Int")
        } finally {
            DllCall("gdi32\SetTextColor", "Ptr", hdc, "UInt",
                previousTextColor, "UInt")
            DllCall("gdi32\SetBkMode", "Ptr", hdc, "Int",
                previousBkMode, "Int")
            if previousFont
                DllCall("gdi32\SelectObject", "Ptr", hdc,
                    "Ptr", previousFont, "Ptr")
        }
        return Win32.CDRF_SKIPDEFAULT
    }

    CalculateSequenceDotLayout(cellRect, textWidth, dotSize,
            selectionInset) {
        cellWidth := cellRect.Right - cellRect.Left
        textLeft := cellRect.Left
            + Max(0, Floor((cellWidth - textWidth) / 2))
        return {
            TextLeft: textLeft,
            DotLeft: cellRect.Left + selectionInset,
            DotTop: cellRect.Top + Max(0, Floor(
                (cellRect.Bottom - cellRect.Top - dotSize) / 2))
        }
    }

    DrawLeftAlignedListSubItem(listView, notification, column) {
        itemSpecOffset := A_PtrSize == 8 ? 56 : 36
        row := NumGet(notification, itemSpecOffset, "UPtr") + 1
        if row < 1 || row > listView.GetCount()
            return Win32.CDRF_SKIPDEFAULT
        textBounds := this.GetLeftAlignedListTextRect(row, column)
        hdcOffset := A_PtrSize == 8 ? 32 : 16
        hdc := NumGet(notification, hdcOffset, "Ptr")
        if !IsObject(textBounds) || !hdc
            return Win32.CDRF_SKIPDEFAULT

        textRect := Buffer(16, 0)
        NumPut("Int", textBounds.Left, textRect, 0)
        NumPut("Int", textBounds.Top, textRect, 4)
        NumPut("Int", textBounds.Right, textRect, 8)
        NumPut("Int", textBounds.Bottom, textRect, 12)
        text := listView.GetText(row, column)
        font := SendMessage(Win32.WM_GETFONT, 0, 0, , listView.Hwnd)
        previousFont := font ? DllCall("gdi32\SelectObject", "Ptr", hdc,
            "Ptr", font, "Ptr") : 0
        previousBkMode := DllCall("gdi32\SetBkMode", "Ptr", hdc,
            "Int", 1, "Int")
        previousTextColor := DllCall("gdi32\SetTextColor", "Ptr", hdc,
            "UInt", ColorRef(MappingWindow.Colors.Text), "UInt")
        try {
            if text != ""
                DllCall("user32\DrawTextW", "Ptr", hdc, "Str", text,
                    "Int", StrLen(text), "Ptr", textRect,
                    "UInt", 0x00008824, "Int")
        } finally {
            DllCall("gdi32\SetTextColor", "Ptr", hdc, "UInt",
                previousTextColor, "UInt")
            DllCall("gdi32\SetBkMode", "Ptr", hdc, "Int",
                previousBkMode, "Int")
            if previousFont
                DllCall("gdi32\SelectObject", "Ptr", hdc, "Ptr",
                    previousFont, "Ptr")
        }
        return Win32.CDRF_SKIPDEFAULT
    }

    GetListDpi() {
        return UiScaleService.GetEffectiveDpi(this.List.Hwnd)
    }

    RefreshListStatusIcons() {
        if !IsObject(this.List) || !this.List.Hwnd
            return 0
        refreshed := 0
        Loop this.List.GetCount() {
            enabled := this.List.GetText(A_Index,
                MappingWindow.EnabledColumn) == "1"
            if this.SetMappingStatusIcon(A_Index, enabled)
                refreshed++
        }
        return refreshed
    }

    GetListRowHeightPixels() {
        if IsObject(this.List) && this.List.Hwnd && this.List.GetCount() {
            itemRect := Buffer(16, 0)
            NumPut("Int", 0, itemRect, 0) ; LVIR_BOUNDS
            if SendMessage(0x100E, 0, itemRect.Ptr, , this.List.Hwnd) {
                rowHeight := NumGet(itemRect, 12, "Int")
                    - NumGet(itemRect, 4, "Int")
                if rowHeight > 0
                    return rowHeight
            }
        }
        rowDpi := UiScaleService.GetEffectiveDpi(this.List.Hwnd)
        return Max(1, Round(MappingWindow.ListRowHeight * rowDpi / 96))
    }

    GetListFrameHeightPixels() {
        if !IsObject(this.List) || !this.List.Hwnd
            return 0
        windowRect := Buffer(16, 0)
        clientRect := Buffer(16, 0)
        if !DllCall("user32\GetWindowRect", "Ptr", this.List.Hwnd,
                "Ptr", windowRect, "Int")
                || !DllCall("user32\GetClientRect", "Ptr", this.List.Hwnd,
                    "Ptr", clientRect, "Int")
            return 0
        windowHeight := NumGet(windowRect, 12, "Int")
            - NumGet(windowRect, 4, "Int")
        clientHeight := NumGet(clientRect, 12, "Int")
            - NumGet(clientRect, 4, "Int")
        return Max(0, windowHeight - clientHeight)
    }

    AlignListHeightToWholeRows(height, layoutRound, roundUp := false) {
        scale := IsObject(layoutRound) && layoutRound.HasOwnProp("Scale")
            ? layoutRound.Scale : UiScaleService.GetEffectiveDpi(
                this.List.Hwnd) / 96
        scale := Max(0.01, scale)
        rowHeightPixels := this.GetListRowHeightPixels()
        frameHeightPixels := this.GetListFrameHeightPixels()
        outerHeightPixels := Max(frameHeightPixels + rowHeightPixels,
            Round(Max(1, height) * scale))
        rowSpacePixels := Max(rowHeightPixels,
            outerHeightPixels - frameHeightPixels)
        rowCount := roundUp
            ? Ceil(rowSpacePixels / rowHeightPixels)
            : Floor(rowSpacePixels / rowHeightPixels)
        rowCount := Max(1, rowCount)
        return (frameHeightPixels + rowCount * rowHeightPixels) / scale
    }

    ReleaseListRowImageList() {
        statusImageList := this.ListRowImageList
        metricsImageList := this.ListMetricsImageList
        this.ListRowImageList := 0
        this.ListMetricsImageList := 0
        this.ListRowDpi := 0
        this.ListStatusIconIndices := Map()
        if !statusImageList && !metricsImageList
            return false
        try this.List.SetImageList(0, 1)
        try this.List.IL := 0
        if statusImageList
            try IL_Destroy(statusImageList)
        if metricsImageList
            try IL_Destroy(metricsImageList)
        return true
    }

    OnResize(guiObj, minMax, width, height) {
        if minMax == -1
            return
        width := UiScaleService.ToDesign(width)
        height := UiScaleService.ToDesign(height)
        if minMax == 0 && width > 0 && height > 0 {
            this.LastNormalClientWidth := width
            this.LastNormalClientHeight := height
        }
        if width <= 0 || height <= 0
            return
        ; WM_SIZE is already delivered synchronously while the window surface
        ; is being resized. Commit that frame before returning so the newly
        ; exposed client area never displays the previous child layout.
        this.CancelPendingResize()
        this.ApplyLayout(width, height, false, true)
    }

    OnInteractiveResizeMessage(wParam, lParam, message, hwnd) {
        if this.Disposed || hwnd != this.Gui.Hwnd
            return
        this.Interactions.SetPointerFeedbackFrozen(
            message == Win32.WM_ENTERSIZEMOVE)
    }

    GetFixedVerticalLayoutHeight() {
        return MappingWindow.ListTop
            + MappingWindow.ListToEditorGap
            + MappingWindow.EditorHeadingBandMinHeight
            + MappingWindow.CaptureDetailGap
            + MappingWindow.MinStatusHeight
            + MappingWindow.StatusBottomMargin
    }

    SuspendListResizeRedraw() {
        return AtomicControlRedrawTransaction.Begin([this.List])
    }

    ResumeListResizeRedraw(transaction) {
        return AtomicControlRedrawTransaction.End(transaction)
    }

    ApplyLayout(width, height, force := false, interactive := false) {
        if this.Disposed || width <= 0 || height <= 0
            return false
        layoutRound := AtomicControlLayout.BeginRound(this.Gui)
        if !IsObject(layoutRound)
            return false
        this.EnsureListRowMetrics(layoutRound)
        contentWidth := width - 20
        editor := this.GetEditorColumnLayout(width)
        this.RefreshNameInputMetrics(layoutRound.Dpi)
        captureHeights := this.GetCaptureControlHeights(editor.SourceWidth,
            layoutRound)
        captureHeights.Button := Max(captureHeights.Button,
            this.NameInputHeight)
        statusLayout := this.GetStatusLayout(width, layoutRound)
        statusSizeChanged := true
        try {
            UiScaleService.GetControlDesignPos(this.Status, , ,
                &currentStatusWidth, &currentStatusHeight)
            statusSizeChanged := Round(currentStatusWidth)
                    != Round(statusLayout.Width)
                || Round(currentStatusHeight) != Round(statusLayout.Height)
        }
        fixedHeight := this.GetFixedVerticalLayoutHeight()
        minimumListHeight := this.AlignListHeightToWholeRows(
            MappingWindow.MinListHeight, layoutRound, true)
        requiredHeight := Max(MappingWindow.BaseMinClientHeight,
            fixedHeight
                + statusLayout.Extra
                + minimumListHeight
                + captureHeights.Button + captureHeights.Detail)
        if this.EnsureCaptureMinimumSize(requiredHeight, width, height)
            return false

        availableListHeight := height - fixedHeight
            - statusLayout.Extra
            - captureHeights.Button - captureHeights.Detail
        listHeight := Max(minimumListHeight,
            this.AlignListHeightToWholeRows(availableListHeight,
                layoutRound))
        signature := layoutRound.Dpi "|" width "|" height "|"
            . editor.SourceWidth "|"
            . editor.TargetWidth "|" editor.NameWidth "|"
            . captureHeights.Button "|" captureHeights.Detail "|"
            . statusLayout.Width "|" statusLayout.Height "|" listHeight
        toolbarPositions := this.GetToolbarButtonPositions(width)
        sectionY := MappingWindow.ListTop + listHeight
            + MappingWindow.ListToEditorGap
        headingY := sectionY + MappingWindow.EditorHeadingTopPadding
        modifierSidesWidth := Min(Max(1,
            this.ModifierSidesPreferredWidth),
            Floor(contentWidth * 0.46))
        labelY := headingY + 32
        controlY := sectionY + MappingWindow.EditorHeadingBandMinHeight
        detailY := controlY + captureHeights.Button
            + MappingWindow.CaptureDetailGap
        statusY := height - MappingWindow.StatusBottomMargin
            - statusLayout.Height
        columnWidths := this.CalculateProportionalColumnWidths(
            this.GetExpectedListContentWidth(contentWidth, listHeight))
        innerNameHeight := Min(captureHeights.Button,
            this.NameInputHeight)
        ; The shortened name field is top-aligned with the capture controls;
        ; its freed lower area is reserved for the two mapping commands.
        innerNameY := controlY
        commandLayout := this.GetCommandLayout(editor)
        commandY := innerNameY + innerNameHeight
            + MappingWindow.EditorToCommandGap
        entries := [
            {Control: this.AddButton, X: 10, Y: 15,
                Width: this.AddButtonWidth,
                Height: MappingWindow.CommandButtonHeight},
            {Control: this.PauseResumeButton, X: this.PauseButtonX, Y: 15,
                Width: this.PauseButtonWidth,
                Height: MappingWindow.CommandButtonHeight},
            {Control: this.DeleteButton, X: this.DeleteButtonX, Y: 15,
                Width: this.DeleteButtonWidth,
                Height: MappingWindow.CommandButtonHeight},
            {Control: this.SettingsButton, X: toolbarPositions.Settings,
                Y: 15, Width: this.SettingsButtonWidth,
                Height: MappingWindow.SettingsButtonHeight},
            {Control: this.SupportButton, X: toolbarPositions.Support,
                Y: 15, Width: this.SupportButtonWidth,
                Height: MappingWindow.SettingsButtonHeight},
            {Control: this.AboutButton, X: toolbarPositions.About, Y: 15,
                Width: this.AboutButtonWidth,
                Height: MappingWindow.SettingsButtonHeight},
            {Control: this.List, X: 10, Y: MappingWindow.ListTop,
                Width: contentWidth, Height: listHeight},
            {Control: this.SectionTitle, X: 10, Y: headingY,
                Width: contentWidth, Height: 24},
            {Control: this.DistinguishModifierSidesCheck,
                X: width - 10 - modifierSidesWidth, Y: headingY,
                Width: modifierSidesWidth, Height: 24},
            {Control: this.SourceLabel, X: 10, Y: labelY,
                Width: editor.SourceWidth, Height: 24},
            {Control: this.SourceButton, X: 10, Y: controlY,
                Width: editor.SourceWidth, Height: captureHeights.Button},
            {Control: this.ArrowText, X: 10 + editor.SourceWidth + 6,
                Y: controlY + (captureHeights.Button - 24) // 2,
                Width: editor.Gap - 12, Height: 24},
            {Control: this.TargetLabel, X: editor.TargetX, Y: labelY,
                Width: editor.TargetWidth, Height: 24},
            {Control: this.TargetButton, X: editor.TargetX, Y: controlY,
                Width: editor.TargetWidth, Height: captureHeights.Button},
            {Control: this.NameLabel, X: editor.NameX, Y: labelY,
                Width: editor.NameWidth, Height: 24},
            {Control: this.NameInput.Background, X: editor.NameX,
                Y: innerNameY, Width: editor.NameWidth,
                Height: innerNameHeight},
            {Control: this.NameEdit, X: editor.NameX, Y: innerNameY + 1,
                Width: editor.NameWidth, Height: Max(1,
                    innerNameHeight - 2)},
            {Control: this.SourceDetail, X: 10, Y: detailY,
                Width: editor.SourceWidth, Height: captureHeights.Detail},
            {Control: this.TargetDetail, X: editor.TargetX, Y: detailY,
                Width: editor.TargetWidth, Height: captureHeights.Detail},
            {Control: this.SaveButton, X: commandLayout.SaveButtonX,
                Y: commandY, Width: commandLayout.SaveButtonWidth,
                Height: MappingWindow.CommandButtonHeight},
            {Control: this.ClearButton, X: commandLayout.ClearButtonX,
                Y: commandY, Width: commandLayout.ClearButtonWidth,
                Height: MappingWindow.CommandButtonHeight},
            {Control: this.Status, X: 10, Y: statusY,
                Width: statusLayout.Width, Height: statusLayout.Height}
        ]
        for entry in this.ListHeader.BuildLayoutEntries(10, 60,
                [columnWidths.Sequence, columnWidths.Name,
                    columnWidths.Source, columnWidths.Target,
                    columnWidths.Scope, columnWidths.Status], contentWidth)
            entries.Push(entry)
        entries.Push(this.BuildDashedDividerLayoutEntry(sectionY,
            contentWidth))

        listRedrawTransaction := signature != this.LastLayoutSignature
            ? this.SuspendListResizeRedraw() : false
        try {
            result := AtomicControlLayout.Apply(this.Gui, entries, {
                ParentColor: MappingWindow.Colors.Window, ClearMargin: 2,
                Round: layoutRound
            })
            this.LastLayoutResult := result
            if result.Status == AtomicControlLayout.Applied && result.Changed
                this.LastChangedLayoutResult := result
            if result.Status != AtomicControlLayout.Applied
                    && result.Status != AtomicControlLayout.Unchanged
                return false
            if result.Status == AtomicControlLayout.Applied
                    && result.ChangedHwnds.Has(this.NameEdit.Hwnd)
                this.ApplyNameInputViewport()
            if result.Status == AtomicControlLayout.Applied
                    && result.ChangedHwnds.Has(this.Status.Hwnd) {
                this.NormalizeStatusViewport()
                if statusSizeChanged
                    this.RedrawStatusSurface()
            }
            this.ApplyColumnWidths(columnWidths, false)
            this.ListHeader.RefreshSurface()
            this.LastLayoutSignature := signature
            return result
        } finally {
            this.ResumeListResizeRedraw(listRedrawTransaction)
        }
    }

    GetEditorColumnLayout(width) {
        contentWidth := Max(1, width - 20)
        gap := 40
        minimumColumnWidth := 190
        available := Max(minimumColumnWidth * 3,
            contentWidth - gap * 2)
        sourceWidth := Max(minimumColumnWidth, Floor(available / 3))
        targetWidth := Max(minimumColumnWidth,
            Floor((available - sourceWidth) / 2))
        nameWidth := Max(minimumColumnWidth,
            available - sourceWidth - targetWidth)
        targetX := 10 + sourceWidth + gap
        nameX := targetX + targetWidth + gap
        return {
            Gap: gap,
            SourceWidth: sourceWidth,
            TargetX: targetX,
            TargetWidth: targetWidth,
            NameX: nameX,
            NameWidth: nameWidth
        }
    }

    GetListContentWidth(fallbackWidth) {
        clientRect := Buffer(16, 0)
        if !DllCall("user32\GetClientRect", "Ptr", this.List.Hwnd,
                "Ptr", clientRect, "Int")
            return Max(1, fallbackWidth)
        physicalWidth := NumGet(clientRect, 8, "Int")
            - NumGet(clientRect, 0, "Int")
        dpi := UiScaleService.GetEffectiveDpi(this.List.Hwnd)
        return Max(1, Floor(physicalWidth * 96 / dpi))
    }

    RefreshListColumnLayout() {
        if this.Disposed || !IsObject(this.List) || !this.List.Hwnd
            return false
        try UiScaleService.GetControlDesignPos(this.List, , , &outerWidth)
        catch
            return false
        if outerWidth <= 0
            return false
        listRedrawTransaction := AtomicControlRedrawTransaction.Begin(
            [this.List])
        try this.ConfigureColumns(this.GetListContentWidth(outerWidth),
            outerWidth, false)
        finally AtomicControlRedrawTransaction.End(listRedrawTransaction)
        return true
    }

    MeasureControlTextWidth(control, text) {
        deviceContext := DllCall("user32\GetDC", "Ptr", control.Hwnd, "Ptr")
        if !deviceContext
            return StrLen(String(text)) * 12
        fontHandle := SendMessage(0x0031, 0, 0, , control.Hwnd) ; WM_GETFONT
        previousFont := fontHandle ? DllCall("gdi32\SelectObject", "Ptr",
            deviceContext, "Ptr", fontHandle, "Ptr") : 0
        extent := Buffer(8, 0)
        try {
            text := String(text)
            if !DllCall("gdi32\GetTextExtentPoint32W", "Ptr",
                    deviceContext, "Str", text, "Int", StrLen(text),
                    "Ptr", extent, "Int")
                return StrLen(text) * 12
            windowDpi := UiScaleService.GetDesignMeasurementDpi(control.Hwnd)
            return Ceil(NumGet(extent, 0, "Int") * 96 / windowDpi)
        } finally {
            if previousFont
                DllCall("gdi32\SelectObject", "Ptr", deviceContext,
                    "Ptr", previousFont, "Ptr")
            DllCall("user32\ReleaseDC", "Ptr", control.Hwnd,
                "Ptr", deviceContext)
        }
    }

    RefreshModifierSidesPreferredWidth() {
        this.ModifierSidesPreferredWidth :=
            this.MeasureControlTextWidth(this.DistinguishModifierSidesCheck,
                this.DistinguishModifierSidesCheck.Text) + 22
        return this.ModifierSidesPreferredWidth
    }

    ApplyListColumnOrder() {
        if !IsObject(this.List) || !this.List.Hwnd
            return false
        displayOrder := [
            MappingWindow.SequenceColumn - 1,
            MappingWindow.NameColumn - 1,
            MappingWindow.SourceColumn - 1,
            MappingWindow.TargetColumn - 1,
            MappingWindow.ScopeColumn - 1,
            MappingWindow.StatusColumn - 1,
            MappingWindow.EnabledColumn - 1
        ]
        orderBuffer := Buffer(displayOrder.Length * 4, 0)
        for position, columnIndex in displayOrder
            NumPut("Int", columnIndex, orderBuffer, (position - 1) * 4)
        return SendMessage(Win32.LVM_SETCOLUMNORDERARRAY,
            displayOrder.Length, orderBuffer.Ptr, , this.List.Hwnd) != 0
    }

    ConfigureColumns(availableWidth, headerWidth, manageRedraw := true) {
        if IsObject(this.CellTooltip)
            this.CellTooltip.Hide()
        widths := this.CalculateProportionalColumnWidths(availableWidth)
        this.ApplyColumnWidths(widths, manageRedraw)
        if IsObject(this.ListHeader)
            this.ListHeader.SetBounds(10, 60,
                [widths.Sequence, widths.Name, widths.Source, widths.Target,
                    widths.Scope, widths.Status], Max(0, headerWidth))
    }

    ApplyColumnWidths(widths, manageRedraw := true) {
        if !IsObject(widths)
            return false
        definitions := [
            {Column: MappingWindow.NameColumn, Width: widths.Name,
                Options: ""},
            {Column: MappingWindow.SequenceColumn, Width: widths.Sequence,
                Options: "Integer Center"},
            {Column: MappingWindow.SourceColumn, Width: widths.Source,
                Options: "Left"},
            {Column: MappingWindow.TargetColumn, Width: widths.Target,
                Options: "Left"},
            {Column: MappingWindow.ScopeColumn, Width: widths.Scope,
                Options: "Center"},
            {Column: MappingWindow.StatusColumn, Width: widths.Status,
                Options: "Left"},
            {Column: MappingWindow.EnabledColumn, Width: 0, Options: ""}
        ]
        pending := []
        for definition in definitions {
            if !this.AppliedColumnWidths.Has(definition.Column)
                    || this.AppliedColumnWidths[definition.Column]
                        != definition.Width
                pending.Push(definition)
        }
        if !pending.Length
            return false
        changed := false
        if manageRedraw
            this.List.Opt("-Redraw")
        try {
            for definition in pending
                changed := this.ApplyColumnWidth(definition.Column,
                    definition.Width, definition.Options) || changed
        } finally {
            if manageRedraw
                this.List.Opt("+Redraw")
        }
        if changed && manageRedraw
            DllCall("user32\RedrawWindow", "Ptr", this.List.Hwnd,
                "Ptr", 0, "Ptr", 0, "UInt",
                AtomicControlLayout.RdwRefreshNoErase,
                "Int")
        return changed
    }

    CalculateProportionalColumnWidths(availableWidth) {
        sequenceWidth := 48
        sourceMinimum := MappingWindow.MinSourceColumnWidth
        targetMinimum := MappingWindow.MinTargetColumnWidth
        scopeMinimum := MappingWindow.ScopeColumnWidth
        nameMinimum := MappingWindow.MinNameColumnWidth
        statusWidth := MappingWindow.StatusColumnWidth
        minimumTotal := nameMinimum + sequenceWidth + sourceMinimum
            + targetMinimum + scopeMinimum + statusWidth
        extra := Max(0, Floor(availableWidth) - minimumTotal)
        sourceExtra := Floor(extra * 25 / 100)
        targetExtra := sourceExtra
        ; Scope stays at the compact four-character width. Allocate the
        ; released responsive space to the name column.
        scopeExtra := 0
        nameExtra := extra - sourceExtra - targetExtra
        return {
            Name: nameMinimum + nameExtra,
            Sequence: sequenceWidth,
            Source: sourceMinimum + sourceExtra,
            Target: targetMinimum + targetExtra,
            Scope: scopeMinimum + scopeExtra,
            Status: statusWidth
        }
    }

    ApplyColumnWidth(column, width, options := "") {
        if this.AppliedColumnWidths.Has(column)
                && this.AppliedColumnWidths[column] == width
            return false
        scaledWidth := UiScaleService.Scale(width)
        modifyOptions := options == "" ? scaledWidth
            : options " " scaledWidth
        this.List.ModifyCol(column, modifyOptions)
        this.AppliedColumnWidths[column] := width
        return true
    }

    GetExpectedListContentWidth(listWidth, listHeight) {
        rowContentHeight := this.List.GetCount() * MappingWindow.ListRowHeight
        verticalScrollWidth := rowContentHeight > listHeight ? 17 : 0
        return Max(1, listWidth - verticalScrollWidth)
    }

}
