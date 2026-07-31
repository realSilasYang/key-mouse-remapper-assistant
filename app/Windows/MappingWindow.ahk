class MappingWindow {
    static MinClientWidth := 1040
    static ExpandedMinClientWidth := 1320
    static BaseMinClientHeight := 620
    static MinListHeight := 192
    static ListRowHeight := 36
    static ListLayoutFixedHeight := 212
    static MinSourceColumnWidth := 120
    static MinTargetColumnWidth := 140
    static ScopeColumnWidth := 155
    static MinPurposeColumnWidth := 240
    static MinCaptureButtonHeight := 52
    static MinCaptureDetailHeight := 68
    static MinStatusHeight := 24
    static StatusBottomMargin := 22
    static SettingsButtonWidth := 100
    static ExpandedSettingsButtonWidth := 170
    static SettingsButtonHeight := 30
    static CompactAddButtonWidth := 80
    static ExpandedAddButtonWidth := 112
    static CompactPauseButtonWidth := 96
    static ExpandedPauseButtonWidth := 140
    static CompactDeleteButtonWidth := 80
    static ExpandedDeleteButtonWidth := 104
    static SupportButtonWidth := 100
    static ExpandedSupportButtonWidth := 110
    static DonateButtonWidth := 70
    static ExpandedDonateButtonWidth := 120
    static ToolbarRightMargin := 10
    static SaveButtonWidth := 112
    static ExpandedSaveButtonWidth := 140
    static ClearButtonWidth := 112
    static CommandButtonGap := 8
    static CommandRightMargin := 14
    static ToolbarIconColor := "BABABC"
    static SequenceColumn := 1
    static SourceColumn := 2
    static TargetColumn := 3
    static ScopeColumn := 4
    static PurposeColumn := 5
    static MappingIdColumn := 6
    static EnabledColumn := 7
    static Colors := {
        Window: "1E1E1E", Surface: "252526", Input: "252526",
        Toolbar: "333333", Divider: "3A3A3A", Text: "FFFFFF",
        Muted: "B8BAB9", Hint: "AFAFAF", Primary: "0078D7",
        Add: "3F6B5B", Delete: "6B4B4B", DeleteDisabled: "554B4B",
        Disabled: "554B4B",
        Pause: "6B6244", PauseDisabled: "555148",
        ButtonText: "FFFFFF", DisabledButtonText: "D8D8D8",
        CodeGutter: "202020", CodeLineNumber: "858585",
        CodeComment: "858585", CodeVariable: "D17A2A",
        CodeValue: "6A8754"
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
        this.ThemeTimer := ""
        this.HoverHotkeyRegistered := false
        this.ListRowImageList := 0
        this.ListRowDpi := 0
        this.Disposed := false
        try {
        MappingWindow.Colors := UiThemeService.GetPalette()
        this.FontName := LocalizationService.GetUiFontName()
        this.SystemFontName := LocalizationService.GetLanguageSystemUiFontName()
        this.UpdateLanguageLayoutMetrics()
        this.Gui := Gui("+Resize +MinSize"
            this.MinClientWidth "x" MappingWindow.BaseMinClientHeight,
            Tr("键鼠重映射小助手"))
        this.IconHandles := ApplyApplicationWindowIcon(this.Gui.Hwnd)
        this.Gui.BackColor := MappingWindow.Colors.Window
        this.Gui.MarginX := 0
        this.Gui.MarginY := 0
        this.Gui.SetFont("s10 c" MappingWindow.Colors.Text, this.FontName)
        this.SourceCapture := ""
        this.TargetCapture := ""
        this.HasShown := false
        this.SortColumn := 0
        this.SortDescending := false
        this.SuppressSortStatus := false
        this.DragActive := false
        this.LastDragScrollTicks := 0
        this.Disposed := false
        this.BlockEditor := ""
        this.ContextPopup := ""
        this.HoverHotkeyRegistered := false
        this.RequiredClientHeight := MappingWindow.BaseMinClientHeight
        this.RequiredClientWidth := this.MinClientWidth
        this.LayoutResizeActive := false
        this.RedrawLockDepth := 0
        this.ContentColumnWidthsDirty := true
        this.StatusIsError := false
        this.DesiredSourceColumnWidth := MappingWindow.MinSourceColumnWidth
        this.DesiredTargetColumnWidth := MappingWindow.MinTargetColumnWidth
        this.AppliedColumnWidths := Map()
        this.ListRowImageList := 0
        this.ListRowDpi := 0
        this.ThemeTimer := ObjBindMethod(this, "ApplyNativeThemes")
        this.Interactions := MappingUiInteractions(this.Gui,
            MappingWindow.Colors.Window, this.App.SvgRenderer)
        this.BuildControls()
        this.ContextPopup := MappingContextPopupWindow(this)
        this.HoverHotIf := ObjBindMethod(this, "CanEditHoveredMapping")
        this.HoverF2Callback := ObjBindMethod(this, "EditHoveredMapping")
        this.RegisterHoveredEditHotkey()
        this.Gui.OnEvent("Size", ObjBindMethod(this, "OnResize"))
        this.Gui.OnEvent("Close", ObjBindMethod(this, "Hide"))
        this.Gui.OnEvent("Escape", ObjBindMethod(this, "OnEscape"))
        } catch as buildError {
            this.Dispose()
            throw buildError
        }
    }

    BuildControls() {
        colors := MappingWindow.Colors
        this.AddButton := this.AddCommandButton(10, 15,
            this.AddButtonWidth,
            this.GetAddButtonText(), colors.Add,
            ObjBindMethod(this, "OpenNewMappingEditor"), "", 30)
        this.PauseResumeButton := this.AddCommandButton(this.PauseButtonX,
            15,
            this.PauseButtonWidth,
            this.GetPauseButtonText(), colors.PauseDisabled,
            ObjBindMethod(this, "ToggleSelectedMapping"),
            colors.DisabledButtonText, 30)
        this.Interactions.SetButtonAppearance(this.PauseResumeButton,
            colors.PauseDisabled, colors.DisabledButtonText, false)
        this.DeleteButton := this.AddCommandButton(this.DeleteButtonX,
            15, this.DeleteButtonWidth,
            this.GetDeleteButtonText(), colors.DeleteDisabled,
            ObjBindMethod(this, "DeleteSelected"),
            colors.DisabledButtonText, 30)
        this.Interactions.SetButtonAppearance(this.DeleteButton,
            colors.DeleteDisabled, colors.DisabledButtonText, false)
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
            Tr("帮助信息"), colors.Toolbar,
            ObjBindMethod(this.App, "OpenHelpInfo"), "",
            MappingWindow.SettingsButtonHeight)
        this.DonateButton := this.AddCommandButton(
            toolbarPositions.Donate, 15, this.DonateButtonWidth,
            Tr("捐赠"), colors.Toolbar,
            ObjBindMethod(this.App, "OpenDonation"), "",
            MappingWindow.SettingsButtonHeight)
        this.ApplyCommandIcons()

        this.HeaderLabels := [Tr("序号"), Tr("来源按键"), Tr("映射结果"),
            Tr("生效范围"), Tr("设计目的")]
        this.Gui.SetFont("s12 c" colors.Text, this.FontName)
        this.List := this.Gui.Add("ListView",
            "x10 y88 w960 h324 Report +ReadOnly -Multi -Hdr Background" colors.Surface
            " c" colors.Text " +LV0x10000 -E0x200 -HScroll",
            [Tr("序号"), Tr("来源按键"), Tr("映射结果"),
                Tr("生效范围"), Tr("设计目的"), "内部编号", "启用状态"])
        this.EnsureListRowMetrics()
        this.List.OnEvent("ItemSelect", ObjBindMethod(this, "OnSelectionChanged"))
        this.List.OnEvent("DoubleClick", ObjBindMethod(this, "OnListDoubleClick"))
        this.List.OnEvent("ContextMenu", ObjBindMethod(this, "OnListContextMenu"))
        this.List.OnNotify(-109, ObjBindMethod(this, "OnListBeginDrag"))
        this.Interactions.SetFocusSink(this.List)
        this.CellTooltip := ListCellTooltipWindow(this.List,
            MappingWindow.SourceColumn, MappingWindow.PurposeColumn)
        this.ListSelection := ListViewSelectionPresenter(this.List,
            this.Interactions.Painter)
        this.ListHeader := ListViewPseudoHeader(this.Gui, this.List, [
            {Column: MappingWindow.SequenceColumn, Label: Tr("序号"),
                Align: "Center", SortOptions: "Integer", SkipAscending: true},
            {Column: MappingWindow.SourceColumn, Label: Tr("来源按键"),
                Align: "Center", SortOptions: "Logical"},
            {Column: MappingWindow.TargetColumn, Label: Tr("映射结果"),
                Align: "Center", SortOptions: "Logical"},
            {Column: MappingWindow.ScopeColumn, Label: Tr("生效范围"),
                Align: "Center", SortOptions: "Logical"},
            {Column: MappingWindow.PurposeColumn, Label: Tr("设计目的"),
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
            "x10 y396 w960 h1 Background" colors.Divider)
        this.SectionTitle := this.Gui.Add("Text",
            "x10 y400 w960 h24 Center 0x200 Background" colors.Window
                " c" colors.Text,
            Tr("新建映射"))
        this.SectionTitle.SetFont("s11 bold", this.SystemFontName)

        this.SourceLabel := this.Gui.Add("Text", "x10 y434 w80 h20 Background" colors.Window " c" colors.Muted,
            Tr("来源按键"))
        this.TargetLabel := this.Gui.Add("Text", "x334 y434 w80 h20 Background" colors.Window " c" colors.Muted,
            Tr("映射为"))
        this.PurposeLabel := this.Gui.Add("Text", "x654 y434 w80 h20 Background" colors.Window " c" colors.Muted,
            Tr("设计目的"))

        this.SourceButton := this.Gui.Add("Text",
            "x10 y458 w280 h52 Center +Wrap Background" colors.Toolbar " c" colors.Text,
            Tr("点击录制来源按键"))
        sourceCallback := ObjBindMethod(this, "BeginCapture", "source")
        if !this.Interactions.RegisterButton(this.SourceButton, colors.Toolbar,
            sourceCallback, "", "", true)
            this.SourceButton.OnEvent("Click", sourceCallback)
        this.ArrowText := this.Gui.Add("Text", "x300 y463 w28 h24 Center Background" colors.Window " c" colors.Hint,
            "")
        if !this.Interactions.RegisterIconSurface(this.ArrowText,
                colors.Window, colors.Hint)
            throw Error("无法注册映射方向图标。")
        if !this.Interactions.SetControlLucideIcon(this.ArrowText,
                "arrow-right.svg", 20, 0)
            throw Error("无法加载映射方向图标。")
        this.TargetButton := this.Gui.Add("Text",
            "x334 y458 w280 h52 Center +Wrap Background" colors.Toolbar " c" colors.Text,
            Tr("点击录制目标按键"))
        targetCallback := ObjBindMethod(this, "BeginCapture", "target")
        if !this.Interactions.RegisterButton(this.TargetButton, colors.Toolbar,
            targetCallback, "", "", true)
            this.TargetButton.OnEvent("Click", targetCallback)
        this.RefreshCaptureButtonIcons()
        this.PurposeInput := AddPaddedMultilineEdit(this.Gui,
            654, 458, 312, MappingWindow.MinCaptureButtonHeight,
            colors.Input, colors.Text)
        this.PurposeEdit := this.PurposeInput.Edit
        if !this.Interactions.RegisterTextInput(this.PurposeEdit,
                this.PurposeInput.Background)
            throw Error("无法注册设计目的输入框交互。")
        ApplyDarkControl(this.PurposeEdit.Hwnd)

        this.SourceDetail := this.Gui.Add("Text",
            "x10 y514 w280 h68 +Wrap Background" colors.Window " c" colors.Hint,
            this.GetCaptureDetail(""))
        this.TargetDetail := this.Gui.Add("Text",
            "x334 y514 w280 h68 +Wrap Background" colors.Window " c" colors.Hint,
            this.GetCaptureDetail(""))
        this.SourceDetail.SetFont("s9", this.FontName)
        this.TargetDetail.SetFont("s9", this.FontName)

        mappingClearButtonX := 980 - MappingWindow.CommandRightMargin
            - MappingWindow.ClearButtonWidth
        mappingSaveButtonX := mappingClearButtonX
            - MappingWindow.CommandButtonGap
            - this.SaveButtonWidth
        this.SaveButton := this.AddCommandButton(mappingSaveButtonX, 548,
            this.SaveButtonWidth,
            Tr("保存映射"), colors.Primary,
            ObjBindMethod(this, "SaveMapping"))
        this.ClearButton := this.AddCommandButton(mappingClearButtonX, 548,
            MappingWindow.ClearButtonWidth,
            Tr("清空"), colors.Toolbar,
            ObjBindMethod(this, "ClearEditor"))
        this.Interactions.SetButtonLucideIcon(this.ClearButton,
            "eraser.svg", 16, 7, MappingWindow.ToolbarIconColor)
        this.Status := this.Gui.Add("Text", "x10 y554 w700 h24 +Wrap Background" colors.Window " c" colors.Muted,
            Tr("准备就绪"))
    }

    AddCommandButton(x, y, width, text, color, callback, textColor := "",
            height := 32) {
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
        ; 与小助手主命令栏一致：新增、暂停/恢复、删除使用 Emoji 文本，
        ; 右侧工具命令才使用 Lucide。主题刷新时也要清掉旧图像状态。
        for button in [this.AddButton, this.PauseResumeButton,
                this.DeleteButton]
            this.Interactions.ClearButtonIcon(button)
        for item in [
            {Button: this.SettingsButton, Icon: "settings.svg",
                Tint: MappingWindow.ToolbarIconColor},
            {Button: this.SupportButton, Icon: "circle-question-mark.svg"},
            {Button: this.DonateButton, Icon: "heart.svg"}
        ] {
            this.Interactions.SetButtonLucideIcon(item.Button,
                item.Icon, 15, 6,
                item.HasOwnProp("Tint") ? item.Tint : "none")
        }
    }

    GetAddButtonText() => "➕ " Tr("新增")

    GetPauseButtonText(resume := false) {
        if resume
            return "▶️ " Tr("恢复")
        return "⏸️ " Tr("暂停")
    }

    GetDeleteButtonText() => "🗑️ " Tr("删除")

    GetToolbarButtonPositions(clientWidth) {
        donateX := clientWidth - MappingWindow.ToolbarRightMargin
            - this.DonateButtonWidth
        supportX := donateX - 10 - this.SupportButtonWidth
        settingsX := supportX - 10 - this.SettingsButtonWidth
        return {Settings: settingsX, Support: supportX, Donate: donateX}
    }

    RegisterHoveredEditHotkey() {
        try {
            HotIf(this.HoverHotIf)
            Hotkey("F2", this.HoverF2Callback, "On")
            this.HoverHotkeyRegistered := true
        } finally {
            HotIf()
        }
    }

    Dispose() {
        if this.Disposed
            return
        this.Disposed := true
        if this.HoverHotkeyRegistered {
            try {
                HotIf(this.HoverHotIf)
                Hotkey("F2", "Off")
            } finally {
                HotIf()
            }
            this.HoverHotkeyRegistered := false
        }
        if IsObject(this.BlockEditor)
            this.BlockEditor.Dispose(false)
        this.BlockEditor := ""
        if IsObject(this.CellTooltip)
            this.CellTooltip.Dispose()
        this.CellTooltip := ""
        if IsObject(this.ListSelection)
            this.ListSelection.Dispose()
        this.ListSelection := ""
        if IsObject(this.ContextPopup)
            this.ContextPopup.Dispose()
        this.ContextPopup := ""
        try SetTimer(this.ThemeTimer, 0)
        if IsObject(this.Interactions)
            this.Interactions.Dispose()
        if IsObject(this.ListHeader)
            this.ListHeader.Dispose()
        this.ListHeader := ""
        this.ReleaseListRowImageList()
        if IsObject(this.Gui)
            try this.Gui.Destroy()
        ReleaseApplicationWindowIcons(this.IconHandles)
        this.IconHandles := []
        this.ThemeTimer := ""
        this.HoverHotIf := ""
        this.HoverF2Callback := ""
    }

    LoadRows(mappings) {
        if IsObject(this.CellTooltip)
            this.CellTooltip.InvalidateMeasurements()
        for customOrder, mapping in mappings {
            enabled := !mapping.HasOwnProp("Enabled") || mapping.Enabled
            this.List.Add("", customOrder, mapping.Source, mapping.Target,
                this.GetScopeDisplay(mapping.Scope, enabled), mapping.Purpose,
                mapping.Id, enabled ? "1" : "0")
        }
        this.ContentColumnWidthsDirty := true
        try this.Gui.GetClientPos(, , &clientWidth)
        catch
            clientWidth := 980
        this.ConfigureColumns(clientWidth > 0 ? clientWidth : 980)
    }

    ReplaceRows(mappings, preferredId := "") {
        if Type(mappings) != "Array"
            return false
        SendMessage(Win32.WM_SETREDRAW, 0, 0, , this.List.Hwnd)
        try {
            this.List.Delete()
            this.LoadRows(mappings)
            if this.ListHeader.HasActiveSort()
                this.ListHeader.ApplyCurrentSort()
            if preferredId != "" {
                row := this.FindMappingRow(preferredId)
                if row
                    this.List.Modify(row, "Select Focus Vis")
            }
        } finally {
            SendMessage(Win32.WM_SETREDRAW, 1, 0, , this.List.Hwnd)
            DllCall("user32\RedrawWindow", "Ptr", this.List.Hwnd,
                "Ptr", 0, "Ptr", 0, "UInt", 0x0181, "Int")
        }
        this.UpdateSelectionButtons(this.List.GetNext())
        return true
    }

    AddMappingRow(mapping, customOrder) {
        enabled := !mapping.HasOwnProp("Enabled") || mapping.Enabled
        this.List.Add("", customOrder, mapping.Source, mapping.Target,
            this.GetScopeDisplay(mapping.Scope, enabled), mapping.Purpose,
            mapping.Id, enabled ? "1" : "0")
        this.ContentColumnWidthsDirty := true
        try this.Gui.GetClientPos(, , &clientWidth)
        catch
            clientWidth := 980
        this.ConfigureColumns(clientWidth > 0 ? clientWidth : 980)
        if this.SortColumn
            this.ApplyCurrentSort()
        row := this.FindMappingRow(mapping.Id)
        if row {
            this.SelectOnlyRow(row)
            this.UpdateSelectionButtons(row)
        }
        return row
    }

    UpdateMappingRow(mapping) {
        row := this.FindMappingRow(mapping.Id)
        if !row
            return false
        sequence := this.List.GetText(row, MappingWindow.SequenceColumn)
        enabled := !mapping.HasOwnProp("Enabled") || mapping.Enabled
        this.List.Modify(row, "", sequence, mapping.Source, mapping.Target,
            this.GetScopeDisplay(mapping.Scope, enabled), mapping.Purpose,
            mapping.Id, enabled ? "1" : "0")
        this.ContentColumnWidthsDirty := true
        this.UpdateSelectionButtons(row)
        return true
    }

    RemoveMappingRow(mappingId) {
        row := this.FindMappingRow(mappingId)
        if !row
            return false
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
        this.ContentColumnWidthsDirty := true
        this.UpdateSelectionButtons(this.List.GetNext())
        return true
    }

    SortByColumn(column, *) {
        return IsObject(this.ListHeader)
            ? this.ListHeader.SortByDisplayColumn(column) : false
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
        this.SortColumn := column
        this.SortDescending := descending
        if this.SuppressSortStatus
            return
        if !column {
            this.SetStatus(Tr("已恢复脚本中的自定义顺序。"))
            return
        }
        this.SetStatus(Tr("已临时按“{1}”{2}排列；不会改写脚本顺序。",
            this.HeaderLabels[column], descending ? Tr("降序") : Tr("升序")))
    }

    OnListBeginDrag(control, notification) {
        if this.Disposed || this.DragActive || control != this.List
            return
        selectedRow := this.List.GetNext()
        if !selectedRow
            return
        mappingId := this.List.GetText(selectedRow,
            MappingWindow.MappingIdColumn)
        if mappingId == ""
            return
        if IsObject(this.CellTooltip)
            this.CellTooltip.Hide()
        if this.SortColumn && !this.RestoreCustomOrder(false)
            return
        sourceRow := this.FindMappingRow(mappingId)
        if !sourceRow
            return
        this.SelectOnlyRow(sourceRow)
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
        targetIndex := dropInfo.InsertIndex
        if sourceRow < targetIndex
            targetIndex--
        targetIndex := Max(1, Min(this.List.GetCount(), targetIndex))
        if targetIndex == sourceRow {
            this.SetStatus(Tr("映射顺序没有变化。"))
            return
        }
        this.ApplyMappingMove(mappingId, sourceRow, targetIndex)
    }

    ApplyMappingMove(mappingId, sourceRow, targetIndex) {
        rowValues := this.ReadListRow(sourceRow)
        if !rowValues.Length || !this.MoveListRow(sourceRow, targetIndex,
                rowValues)
            return false
        if !this.App.MoveMappingTo(mappingId, targetIndex) {
            movedRow := this.FindMappingRow(mappingId)
            if movedRow
                this.MoveListRow(movedRow, sourceRow, rowValues)
            return false
        }
        this.UpdateSelectionButtons(targetIndex)
        this.SetStatus(Tr("已按拖动结果实时更新脚本顺序。"))
        return true
    }

    ReadListRow(row) {
        values := []
        if row < 1 || row > this.List.GetCount()
            return values
        Loop MappingWindow.EnabledColumn
            values.Push(this.List.GetText(row, A_Index))
        return values
    }

    MoveListRow(sourceRow, targetIndex, rowValues) {
        this.BeginStableUpdate()
        try {
            this.List.Delete(sourceRow)
            this.List.Insert(targetIndex, "", rowValues*)
            Loop this.List.GetCount()
                this.List.Modify(A_Index,
                    "Col" MappingWindow.SequenceColumn, A_Index)
            this.SelectOnlyRow(targetIndex)
        } catch {
            return false
        } finally {
            this.EndStableUpdate()
        }
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
            if this.List.GetText(A_Index, MappingWindow.MappingIdColumn)
                    == mappingId
                return A_Index
        }
        return 0
    }

    RefreshSortIndicators() {
        if IsObject(this.ListHeader)
            this.ListHeader.RefreshLabels()
    }

    Show(*) {
        return this.ShowWithOptions()
    }

    ShowWithOptions(showOptions := "") {
        if this.Disposed
            return
        if WindowHierarchy.IsOwnerLocked(this.Gui) {
            WindowHierarchy.ActivateTopOwned(this.Gui)
            return
        }
        if DllCall("user32\IsWindowVisible", "Ptr", this.Gui.Hwnd, "Int") {
            this.Gui.Show(showOptions)
            return
        }
        if this.HasShown {
            ; 已布局窗口从托盘恢复时直接交给原生 Show 路径。再次隐藏预布局会
            ; 使父客户区保留一个不带 WM_ERASEBKGND 的更新区域，最终露出白底。
            this.Gui.Show(showOptions)
            ; 窗口在隐藏期间可能丢失客户区表面。同步擦除并提交整棵窗口，避免
            ; 恢复后的首帧短暂显示黑底或尚未初始化的后台缓冲。
            this.RedrawStable(true)
            return
        }
        firstShowOptions := showOptions != "" ? showOptions
            : "w" this.MinClientWidth " h650"
        this.BeginStableUpdate()
        try {
            this.HasShown := true
            this.Gui.Show("Hide " firstShowOptions)
            this.RefreshCaptureLayout(true)
            this.ApplyNativeThemes(false)
        } finally {
            this.EndStableUpdate(true)
        }
        this.Gui.Show(showOptions)
        this.RedrawStable()
        SetTimer(this.ThemeTimer, -120)
        try this.App.ShowPendingToast()
    }

    ApplyNativeThemes(stabilize := true, *) {
        if this.Disposed
            return
        if stabilize
            this.BeginStableUpdate()
        try {
            ApplyDarkWindow(this.Gui.Hwnd)
            ApplyDarkListView(this.List.Hwnd)
            ApplyDarkControl(this.PurposeEdit.Hwnd)
        } finally {
            if stabilize
                this.EndStableUpdate()
        }
    }

    ApplyAppearance(*) {
        if this.Disposed
            return false
        this.BeginStableUpdate()
        try {
            MappingWindow.Colors := UiThemeService.GetPalette()
            colors := MappingWindow.Colors
            this.FontName := LocalizationService.GetUiFontName()
            this.SystemFontName := LocalizationService
                .GetLanguageSystemUiFontName()
            this.UpdateLanguageLayoutMetrics()
            this.Gui.Title := Tr("键鼠重映射小助手")
            this.Gui.SetFont("s10 c" colors.Text, this.FontName)
            this.Interactions.SetParentColor(colors.Window)

            for button in [this.AddButton, this.PauseResumeButton,
                    this.DeleteButton, this.SettingsButton, this.SupportButton,
                    this.DonateButton, this.SaveButton, this.ClearButton]
                button.SetFont("s10 bold", this.SystemFontName)
            this.Interactions.SetTextNoErase(this.AddButton,
                this.GetAddButtonText())
            this.Interactions.SetTextNoErase(this.SettingsButton,
                Tr("设置"))
            this.Interactions.SetTextNoErase(this.SupportButton,
                Tr("帮助信息"))
            this.Interactions.SetTextNoErase(this.DonateButton,
                Tr("捐赠"))
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
            this.Interactions.SetButtonAppearance(this.DonateButton,
                colors.Toolbar, colors.ToolbarText, true)
            this.Interactions.SetButtonAppearance(this.SaveButton,
                colors.Primary, colors.ButtonText, true)
            this.Interactions.SetButtonAppearance(this.ClearButton,
                colors.Toolbar, colors.ToolbarText, true)
            this.ApplyCommandIcons()
            this.RefreshCaptureButtonIcons()
            this.Interactions.SetButtonLucideIcon(this.ClearButton,
                "eraser.svg", 16, 7, MappingWindow.ToolbarIconColor)
            this.Interactions.SetIconSurfaceAppearance(this.ArrowText,
                colors.Window, colors.Hint)
            this.Interactions.SetControlLucideIcon(this.ArrowText,
                "arrow-right.svg", 20, 0)

            this.HeaderLabels := [Tr("序号"), Tr("来源按键"),
                Tr("映射结果"), Tr("生效范围"), Tr("设计目的")]
            this.ListHeader.SetLabels(this.HeaderLabels)
            this.ListHeader.ApplyAppearance(colors.Toolbar, colors.Muted,
                this.SystemFontName, 9)
            this.List.Opt("Background" colors.Surface " c" colors.Text)
            this.List.SetFont("s12 c" colors.Text, this.FontName)

            this.SectionTitle.Text := Tr("新建映射")
            this.SectionTitle.Opt("Background" colors.Window)
            this.SectionTitle.SetFont("s11 bold c" colors.Text,
                this.SystemFontName)
            this.SectionTopDivider.Opt("Background" colors.Divider)
            this.SourceLabel.Text := Tr("来源按键")
            this.TargetLabel.Text := Tr("映射为")
            this.PurposeLabel.Text := Tr("设计目的")
            for label in [this.SourceLabel, this.TargetLabel,
                    this.PurposeLabel] {
                label.Opt("Background" colors.Window)
                label.SetFont("s10 c" colors.Muted, this.FontName)
            }
            this.ArrowText.Opt("Background" colors.Window)
            this.ArrowText.SetFont("s15 c" colors.Hint, "Segoe UI Symbol")
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
            for detail in [this.SourceDetail, this.TargetDetail] {
                detail.Opt("Background" colors.Window)
                detail.SetFont("s9 c" colors.Hint, this.FontName)
            }
            this.PurposeInput.Background.Opt("Background" colors.Input)
            this.PurposeEdit.Opt("Background" colors.Input " c" colors.Text)
            this.PurposeEdit.SetFont("norm s10 c" colors.Text, this.FontName)
            SetMultilineEditPadding(this.PurposeEdit.Hwnd)
            this.Status.Opt("Background" colors.Window)
            this.Status.SetFont("s10 c" (this.StatusIsError
                ? colors.Error : colors.Muted), this.FontName)
            this.UpdateSelectionButtons(this.List.GetNext())
            this.ContextPopup.ApplyAppearance()
            this.ContentColumnWidthsDirty := true
            this.Gui.GetClientPos(, , &clientWidth, &clientHeight)
            this.OnResize(this.Gui, 0, clientWidth, clientHeight)
            this.ApplyNativeThemes(false)
            ; 与公共窗口初始化顺序一致：先许可原生主题，再提交应用客户区颜色。
            this.Gui.BackColor := colors.Window
        ; 语言和字体只需重绘子控件，但主题会替换顶层窗口的背景刷。
        ; 热切换解锁后只擦除并重绘一次整棵窗口树，
        ; 否则 Win32 会继续显示切换前缓存的客户区底色。
        } finally this.EndStableUpdate(true)
        return true
    }

    BeginStableUpdate() {
        this.RedrawLockDepth++
        if this.RedrawLockDepth == 1
            SendMessage(0x000B, 0, 0, , this.Gui.Hwnd) ; WM_SETREDRAW
    }

    EndStableUpdate(eraseBackground := false) {
        if this.RedrawLockDepth <= 0
            return
        this.RedrawLockDepth--
        if this.RedrawLockDepth == 0 {
            SendMessage(0x000B, 1, 0, , this.Gui.Hwnd) ; WM_SETREDRAW
            this.RedrawStable(eraseBackground)
        }
    }

    RedrawStable(eraseBackground := false) {
        if this.Disposed || !this.Gui.Hwnd
            return false
        ; 首次隐藏预布局需要擦除一次；后续事务提交保持无擦除以避免闪烁。
        flags := 0x0181 | (eraseBackground ? 0x0004 : 0)
        return !!DllCall("user32\RedrawWindow", "Ptr", this.Gui.Hwnd,
            "Ptr", 0, "Ptr", 0, "UInt", flags, "Int")
    }

    Hide(*) {
        return this.RequestHide()
    }

    RequestHide(force := false) {
        if !force && WindowHierarchy.IsOwnerLocked(this.Gui) {
            WindowHierarchy.ActivateTopOwned(this.Gui)
            return false
        }
        captureWasActive := this.App.Capture.Active
        this.App.Capture.Stop(false)
        if captureWasActive
            this.CancelCaptureState()
        if IsObject(this.CellTooltip)
            this.CellTooltip.Hide()
        if IsObject(this.ContextPopup)
            this.ContextPopup.Hide()
        try this.App.Toast.Hide()
        this.Gui.Hide()
        return true
    }

    OnEscape(*) {
        if WindowHierarchy.IsOwnerLocked(this.Gui) {
            WindowHierarchy.ActivateTopOwned(this.Gui)
            return
        }
        if this.App.Capture.Active {
            this.App.Capture.Cancel()
            return
        }
        focusedHwnd := DllCall("user32\GetFocus", "Ptr")
        if focusedHwnd == this.List.Hwnd && this.List.GetNext(0) > 0 {
            this.List.Modify(0, "-Select")
            this.SetStatus(this.App.GetSummaryText())
            return
        }
        this.RequestHide()
    }

    FocusSourceCapture(*) {
        this.BeginCapture("source")
    }

    OpenNewMappingEditor(*) {
        if IsObject(this.BlockEditor) {
            this.BlockEditor.Activate()
            return
        }
        if IsObject(this.ContextPopup) && this.ContextPopup.IsVisible() {
            this.ContextPopup.Hide()
            return
        }
        try this.App.Toast.Hide()
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
            StartLine: startLine}
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
        if this.App.Capture.Active {
            this.App.Capture.Cancel()
            return
        }
        this.RefreshCaptureButtonIcons(role)
        if !this.App.Capture.Start(role) {
            this.RefreshCaptureButtonIcons()
            this.SetStatus(Tr("无法启动按键录制，请重试。"), true)
            return
        }
        activeButton := role == "source" ? this.SourceButton : this.TargetButton
        idleButton := role == "source" ? this.TargetButton : this.SourceButton
        activeDetail := role == "source" ? this.SourceDetail : this.TargetDetail
        idleDetail := role == "source" ? this.TargetDetail : this.SourceDetail
        idleCapture := role == "source" ? this.TargetCapture : this.SourceCapture
        this.Interactions.SetButtonColor(activeButton, MappingWindow.Colors.Primary)
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

    PreviewCapture(role, capture) {
        activeButton := role == "source" ? this.SourceButton : this.TargetButton
        activeDetail := role == "source" ? this.SourceDetail : this.TargetDetail
        this.Interactions.ClearButtonIcon(activeButton)
        this.Interactions.SetTextNoErase(activeButton, capture.RawDisplay)
        this.Interactions.SetTextNoErase(activeDetail,
            this.GetCaptureDetail(capture))
        this.UpdateStatus(Tr("正在录制{1}按键：{2}",
            role == "source" ? Tr("来源") : Tr("目标"), capture.RawDisplay))
        this.RefreshCaptureLayout()
    }

    AcceptCapture(role, capture) {
        activeButton := role == "source" ? this.SourceButton : this.TargetButton
        this.Interactions.ClearButtonIcon(activeButton)
        if role == "source" {
            this.SourceCapture := capture
            this.SourceButton.Text := capture.RawDisplay
            this.SourceDetail.Text := this.GetCaptureDetail(capture)
            this.Interactions.SetButtonColor(this.SourceButton, MappingWindow.Colors.Add)
        } else {
            this.TargetCapture := capture
            this.TargetButton.Text := capture.RawDisplay
            this.TargetDetail.Text := this.GetCaptureDetail(capture)
            this.Interactions.SetButtonColor(this.TargetButton, MappingWindow.Colors.Add)
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
        this.Interactions.SetButtonColor(this.SourceButton,
            IsObject(this.SourceCapture) ? MappingWindow.Colors.Add : MappingWindow.Colors.Toolbar)
        this.Interactions.SetButtonColor(this.TargetButton,
            IsObject(this.TargetCapture) ? MappingWindow.Colors.Add : MappingWindow.Colors.Toolbar)
        this.RefreshCaptureButtonIcons()
        this.UpdateStatus(Tr("已取消按键录制。"))
        this.RefreshCaptureLayout()
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
            this.PurposeEdit.Value) {
            this.ClearEditor(false)
        }
    }

    ClearEditor(showStatus := true, *) {
        if this.App.Capture.Active
            this.App.Capture.Stop(false)
        this.SourceCapture := ""
        this.TargetCapture := ""
        this.PurposeEdit.Value := ""
        this.SourceButton.Text := Tr("点击录制来源按键")
        this.TargetButton.Text := Tr("点击录制目标按键")
        this.SourceDetail.Text := this.GetCaptureDetail("")
        this.TargetDetail.Text := this.GetCaptureDetail("")
        this.Interactions.SetButtonColor(this.SourceButton, MappingWindow.Colors.Toolbar)
        this.Interactions.SetButtonColor(this.TargetButton, MappingWindow.Colors.Toolbar)
        this.RefreshCaptureButtonIcons()
        if showStatus
            this.UpdateStatus(Tr("已清空新建区域。"))
        this.RefreshCaptureLayout()
    }

    DeleteSelected(*) {
        row := this.List.GetNext()
        if !row {
            this.SetStatus(Tr("请先选择要删除的映射。"), true)
            return
        }
        mappingId := this.List.GetText(row, MappingWindow.MappingIdColumn)
        if mappingId == "" {
            this.SetStatus(Tr("所选映射缺少代码块编号，无法删除。"), true)
            return
        }
        this.App.DeleteMapping(mappingId)
    }

    ToggleSelectedMapping(*) {
        row := this.List.GetNext()
        if !row {
            this.SetStatus(Tr("请先选择要暂停或恢复的映射。"), true)
            return
        }
        mappingId := this.List.GetText(row, MappingWindow.MappingIdColumn)
        if mappingId == "" {
            this.SetStatus(Tr("所选映射缺少代码块编号，无法修改状态。"), true)
            return
        }
        mapping := this.App.ToggleMappingEnabled(mappingId)
        if !IsObject(mapping)
            return
        sequence := this.List.GetText(row, MappingWindow.SequenceColumn)
        this.List.Modify(row, "", sequence, mapping.Source, mapping.Target,
            this.GetScopeDisplay(mapping.Scope, mapping.Enabled), mapping.Purpose,
            mapping.Id, mapping.Enabled ? "1" : "0")
        this.UpdateSelectionButtons(row)
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
        this.SelectOnlyRow(item)
        mappingId := this.List.GetText(item, MappingWindow.MappingIdColumn)
        if mappingId == ""
            return
        if IsObject(this.ListSelection)
            this.ListSelection.RefreshItem(item)
        this.ContextPopup.ShowForMapping(mappingId)
    }

    CanEditHoveredMapping(*) {
        if this.Disposed || !WinActive("ahk_id " this.Gui.Hwnd)
            return false
        return this.GetHoveredRow() > 0
    }

    EditHoveredMapping(*) {
        row := this.GetHoveredRow()
        if !row
            return
        this.SelectOnlyRow(row)
        this.OpenEditorForRow(row)
    }

    GetHoveredRow() {
        if this.Disposed || !this.List.Hwnd
            return 0
        point := Buffer(8, 0)
        if !DllCall("user32\GetCursorPos", "Ptr", point, "Int")
            || !DllCall("user32\ScreenToClient", "Ptr", this.List.Hwnd,
                "Ptr", point, "Int")
            return 0
        hitTest := Buffer(24, 0)
        NumPut("Int", NumGet(point, 0, "Int"), hitTest, 0)
        NumPut("Int", NumGet(point, 4, "Int"), hitTest, 4)
        itemIndex := DllCall("user32\SendMessageW", "Ptr", this.List.Hwnd,
            "UInt", 0x1039, "Ptr", 0, "Ptr", hitTest.Ptr, "Int")
        if itemIndex < 0 || !(NumGet(hitTest, 8, "UInt") & 0x0E)
            return 0
        return itemIndex + 1
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
        mappingId := this.List.GetText(row, MappingWindow.MappingIdColumn)
        if mappingId != ""
            this.OpenEditorForId(mappingId)
    }

    OpenEditorForId(mappingId) {
        if IsObject(this.BlockEditor) {
            this.BlockEditor.Activate()
            return
        }
        try this.App.Toast.Hide()
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
        } catch as editorError {
            if IsSet(editor)
                try editor.Dispose()
            this.BlockEditor := ""
            this.SetStatus(Tr("无法打开代码编辑器：{1}",
                editorError.Message), true)
        }
    }

    OnBlockEditorClosed(editor) {
        if IsObject(this.BlockEditor) && this.BlockEditor == editor
            this.BlockEditor := ""
    }

    OnSelectionChanged(*) {
        if IsObject(this.ContextPopup) && this.ContextPopup.IsVisible()
            this.ContextPopup.Hide()
        row := this.List.GetNext()
        this.UpdateSelectionButtons(row)
        if !row {
            this.SetStatus(this.App.GetSummaryText())
            return
        }
        pausedText := this.List.GetText(row, MappingWindow.EnabledColumn) == "0"
            ? " · " Tr("已暂停") : ""
        this.SetStatus(Tr("映射 · {1} -> {2}{3}",
            this.List.GetText(row, MappingWindow.SourceColumn),
            this.List.GetText(row, MappingWindow.TargetColumn), pausedText))
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

    OnDonationClosed(donationWindow) {
        this.App.OnDonationClosed(donationWindow)
    }

    OnRulePackageImportClosed(previewWindow) {
        this.App.OnRulePackageImportClosed(previewWindow)
    }

    UpdateSelectionButtons(row := 0) {
        this.UpdatePauseResumeButton(row)
        this.UpdateDeleteButton(row)
    }

    UpdateLanguageLayoutMetrics() {
        compact := LocalizationService.UsesCompactLayout()
        this.MinClientWidth := compact ? MappingWindow.MinClientWidth
            : MappingWindow.ExpandedMinClientWidth
        this.SettingsButtonWidth := compact
            ? MappingWindow.SettingsButtonWidth
            : MappingWindow.ExpandedSettingsButtonWidth
        this.SupportButtonWidth := compact
            ? MappingWindow.SupportButtonWidth
            : MappingWindow.ExpandedSupportButtonWidth
        this.DonateButtonWidth := compact
            ? MappingWindow.DonateButtonWidth
            : MappingWindow.ExpandedDonateButtonWidth
        this.SaveButtonWidth := compact ? MappingWindow.SaveButtonWidth
            : MappingWindow.ExpandedSaveButtonWidth
        this.AddButtonWidth := compact
            ? MappingWindow.CompactAddButtonWidth
            : MappingWindow.ExpandedAddButtonWidth
        this.PauseButtonWidth := compact
            ? MappingWindow.CompactPauseButtonWidth
            : MappingWindow.ExpandedPauseButtonWidth
        this.DeleteButtonWidth := compact
            ? MappingWindow.CompactDeleteButtonWidth
            : MappingWindow.ExpandedDeleteButtonWidth
        this.PauseButtonX := 10 + this.AddButtonWidth + 10
        this.DeleteButtonX := this.PauseButtonX
            + this.PauseButtonWidth + 10
    }

    UpdatePauseResumeButton(row := 0) {
        if row <= 0 {
            this.Interactions.SetTextNoErase(this.PauseResumeButton,
                this.GetPauseButtonText())
            this.Interactions.SetButtonAppearance(this.PauseResumeButton,
                MappingWindow.Colors.PauseDisabled,
                MappingWindow.Colors.DisabledButtonText, false)
            this.Interactions.ClearButtonIcon(this.PauseResumeButton)
            return
        }
        enabled := this.List.GetText(row, MappingWindow.EnabledColumn) != "0"
        this.Interactions.SetTextNoErase(this.PauseResumeButton,
            this.GetPauseButtonText(!enabled))
        this.Interactions.SetButtonAppearance(this.PauseResumeButton,
            MappingWindow.Colors.Pause, MappingWindow.Colors.ButtonText, true)
        this.Interactions.ClearButtonIcon(this.PauseResumeButton)
    }

    UpdateDeleteButton(row := 0) {
        this.Interactions.SetTextNoErase(this.DeleteButton,
            this.GetDeleteButtonText())
        this.Interactions.SetButtonAppearance(this.DeleteButton,
            row > 0 ? MappingWindow.Colors.Delete
                : MappingWindow.Colors.DeleteDisabled,
            row > 0 ? MappingWindow.Colors.ButtonText
                : MappingWindow.Colors.DisabledButtonText,
            row > 0)
    }

    GetScopeDisplay(scope, enabled) {
        scopeText := scope == "全局" ? Tr("全局") : scope
        return enabled ? scopeText : scopeText " · " Tr("已暂停")
    }

    GetCaptureDetail(capture) {
        return IsObject(capture) && capture.HasOwnProp("DetailLines")
            ? capture.DetailLines
            : ""
    }

    GetCaptureButtonText(capture, placeholder) {
        if !IsObject(capture)
            return placeholder
        return capture.HasOwnProp("RawDisplay") ? capture.RawDisplay : capture.Display
    }

    SetStatus(text, isError := false) {
        this.UpdateStatus(text, isError)
        this.RefreshCaptureLayout()
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
        if !IsObject(capture) && activeRole != role
            return this.Interactions.SetButtonLucideIcons(button,
                "keyboard.svg", "mouse.svg", 17, 8)
        this.Interactions.ClearButtonIcon(button)
        return true
    }

    IsPointerOverButton(controlHwnd := 0) {
        return !!this.GetPointerButtonHwnd(controlHwnd)
    }

    SuppressNextPointerButtonActivation() {
        buttonHwnd := this.GetPointerButtonHwnd()
        return buttonHwnd
            && this.Interactions.SuppressNextButtonActivation(buttonHwnd)
    }

    FinalizePointerButtonCancellation() {
        return this.Interactions.ScheduleSuppressedButtonActivationReset()
    }

    GetPointerButtonHwnd(controlHwnd := 0) {
        if !controlHwnd {
            try MouseGetPos(, , , &controlHwnd, 2)
            catch
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

    UpdateStatus(text, isError := false) {
        this.StatusIsError := !!isError
        this.Status.Text := text
        this.Status.SetFont("c" (isError ? MappingWindow.Colors.Error
            : MappingWindow.Colors.Muted))
    }

    GetStatusLayout(width) {
        clearButtonX := width - MappingWindow.CommandRightMargin
            - MappingWindow.ClearButtonWidth
        saveButtonX := clearButtonX - MappingWindow.CommandButtonGap
            - this.SaveButtonWidth
        statusWidth := Max(1, saveButtonX - 20)
        textHeight := this.Interactions.Painter.MeasureTextHeight(this.Status,
            this.Status.Text, statusWidth)
        statusHeight := Max(MappingWindow.MinStatusHeight, textHeight + 4)
        return {
            Width: statusWidth,
            Height: statusHeight,
            Extra: Max(0, statusHeight - MappingWindow.MinStatusHeight),
            SaveButtonX: saveButtonX,
            ClearButtonX: clearButtonX
        }
    }

    RefreshCaptureLayout(force := false, *) {
        if this.Disposed
            return false
        try this.Gui.GetClientPos(, , &width, &height)
        catch
            return false
        if width <= 0 || height <= 0
            return false
        contentWidth := width - 20
        columnGap := 40
        inputWidth := Max(190, Floor((contentWidth - 2 * columnGap) / 3))
        captureHeights := this.GetCaptureControlHeights(inputWidth)
        statusLayout := this.GetStatusLayout(width)
        this.SourceButton.GetPos(, , &currentWidth, &currentButtonHeight)
        this.SourceDetail.GetPos(, , , &currentDetailHeight)
        this.Status.GetPos(, , &currentStatusWidth, &currentStatusHeight)
        if !force && currentWidth == inputWidth
            && currentButtonHeight == captureHeights.Button
            && currentDetailHeight == captureHeights.Detail
            && currentStatusWidth == statusLayout.Width
            && currentStatusHeight == statusLayout.Height
            return false
        oldBounds := this.GetCaptureLayoutBounds()
        oldCommandBounds := this.GetCommandLayoutBounds()
        this.OnResize(this.Gui, 0, width, height)
        this.RedrawCaptureLayout(oldBounds,
            this.GetCaptureLayoutBounds())
        this.RedrawCommandLayout(oldCommandBounds,
            this.GetCommandLayoutBounds())
        return true
    }

    GetControlRectInClient(control) {
        try controlHwnd := control.Hwnd
        catch
            return false
        if !controlHwnd || !DllCall("user32\IsWindow", "Ptr",
                controlHwnd, "Int")
            return false
        rect := Buffer(16, 0)
        if !DllCall("user32\GetWindowRect", "Ptr", controlHwnd,
                "Ptr", rect, "Int")
            return false
        DllCall("user32\MapWindowPoints", "Ptr", 0,
            "Ptr", this.Gui.Hwnd, "Ptr", rect, "UInt", 2, "Int")
        return {
            Left: NumGet(rect, 0, "Int"),
            Top: NumGet(rect, 4, "Int"),
            Right: NumGet(rect, 8, "Int"),
            Bottom: NumGet(rect, 12, "Int")
        }
    }

    GetCaptureLayoutBounds() {
        bounds := false
        controls := [
            this.SectionTopDivider, this.SectionTitle,
            this.SourceLabel, this.TargetLabel, this.PurposeLabel,
            this.SourceButton,
            this.ArrowText, this.TargetButton,
            this.PurposeInput.Background, this.PurposeEdit,
            this.SourceDetail, this.TargetDetail
        ]
        for control in controls {
            rect := this.GetControlRectInClient(control)
            if !rect
                continue
            if !bounds {
                bounds := {
                    Left: rect.Left, Top: rect.Top,
                    Right: rect.Right, Bottom: rect.Bottom
                }
                continue
            }
            bounds.Left := Min(bounds.Left, rect.Left)
            bounds.Top := Min(bounds.Top, rect.Top)
            bounds.Right := Max(bounds.Right, rect.Right)
            bounds.Bottom := Max(bounds.Bottom, rect.Bottom)
        }
        if !bounds
            return false

        ; ListView 缩小时，它旧下缘腾出的窄带也属于布局变化区域。
        listRect := this.GetControlRectInClient(this.List)
        if listRect {
            bounds.Left := Min(bounds.Left, listRect.Left)
            bounds.Top := Min(bounds.Top, listRect.Bottom)
            bounds.Right := Max(bounds.Right, listRect.Right)
        }
        return bounds
    }

    GetCommandLayoutBounds() {
        bounds := false
        for control in [this.Status, this.SaveButton, this.ClearButton] {
            rect := this.GetControlRectInClient(control)
            if !rect
                continue
            if !bounds {
                bounds := {
                    Left: rect.Left, Top: rect.Top,
                    Right: rect.Right, Bottom: rect.Bottom
                }
                continue
            }
            bounds.Left := Min(bounds.Left, rect.Left)
            bounds.Top := Min(bounds.Top, rect.Top)
            bounds.Right := Max(bounds.Right, rect.Right)
            bounds.Bottom := Max(bounds.Bottom, rect.Bottom)
        }
        return bounds
    }

    RedrawCaptureLayout(oldBounds, newBounds) {
        return this.RedrawLayoutBounds(oldBounds, newBounds)
    }

    RedrawCommandLayout(oldBounds, newBounds) {
        return this.RedrawLayoutBounds(oldBounds, newBounds)
    }

    RedrawLayoutBounds(oldBounds, newBounds) {
        if !oldBounds && !newBounds
            return false
        if oldBounds && newBounds {
            bounds := {
                Left: Min(oldBounds.Left, newBounds.Left),
                Top: Min(oldBounds.Top, newBounds.Top),
                Right: Max(oldBounds.Right, newBounds.Right),
                Bottom: Max(oldBounds.Bottom, newBounds.Bottom)
            }
        } else {
            sourceBounds := oldBounds ? oldBounds : newBounds
            bounds := {
                Left: sourceBounds.Left, Top: sourceBounds.Top,
                Right: sourceBounds.Right, Bottom: sourceBounds.Bottom
            }
        }

        ; 擦除圆角抗锯齿边缘，并同步刷新该区域内的新旧子控件位置。
        redrawRect := Buffer(16, 0)
        NumPut("Int", Max(0, bounds.Left - 2), redrawRect, 0)
        NumPut("Int", Max(0, bounds.Top - 2), redrawRect, 4)
        NumPut("Int", bounds.Right + 2, redrawRect, 8)
        NumPut("Int", bounds.Bottom + 2, redrawRect, 12)
        return !!DllCall("user32\RedrawWindow", "Ptr", this.Gui.Hwnd,
            "Ptr", redrawRect, "Ptr", 0,
            "UInt", Win32.RDW_LAYOUT_REFRESH, "Int")
    }

    GetCaptureControlHeights(inputWidth) {
        buttonTextHeight := 0
        for control in [this.SourceButton, this.TargetButton] {
            buttonTextHeight := Max(buttonTextHeight,
                this.Interactions.Painter.MeasureTextHeight(control,
                    control.Text, inputWidth, 19))
        }
        detailTextHeight := 0
        for control in [this.SourceDetail, this.TargetDetail] {
            detailTextHeight := Max(detailTextHeight,
                this.Interactions.Painter.MeasureTextHeight(control,
                    control.Text, inputWidth))
        }
        return {
            Button: Max(MappingWindow.MinCaptureButtonHeight,
                buttonTextHeight + 16),
            Detail: Max(MappingWindow.MinCaptureDetailHeight,
                detailTextHeight + 4)
        }
    }

    EnsureCaptureMinimumSize(requiredHeight, currentWidth, currentHeight) {
        if requiredHeight != this.RequiredClientHeight
                || this.MinClientWidth != this.RequiredClientWidth {
            this.RequiredClientHeight := requiredHeight
            this.RequiredClientWidth := this.MinClientWidth
            this.Gui.Opt("+MinSize" this.MinClientWidth "x" requiredHeight)
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
            this.Gui.Show(showOptions)
            this.ApplyNativeThemes()
        } finally {
            this.LayoutResizeActive := false
        }
        return true
    }

    EnsureListRowMetrics() {
        if this.Disposed || !IsObject(this.List) || !this.List.Hwnd
            return false
        rowDpi := DllCall("user32\GetDpiForWindow", "Ptr", this.List.Hwnd,
            "UInt")
        if !rowDpi
            rowDpi := 96
        if this.ListRowImageList && this.ListRowDpi == rowDpi
            return false

        imageList := IL_Create(1, 1, false)
        if !imageList
            return false
        rowHeightPixels := Max(1,
            Round(MappingWindow.ListRowHeight * rowDpi / 96))
        if !DllCall("comctl32\ImageList_SetIconSize", "Ptr", imageList,
                "Int", 1, "Int", rowHeightPixels, "Int") {
            IL_Destroy(imageList)
            return false
        }

        oldImageList := this.ListRowImageList
        try {
            this.List.SetImageList(imageList, 1)
            this.List.IL := imageList
            this.ListRowImageList := imageList
            this.ListRowDpi := rowDpi
        } catch {
            IL_Destroy(imageList)
            return false
        }
        if oldImageList
            try IL_Destroy(oldImageList)
        return true
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
        rowDpi := DllCall("user32\GetDpiForWindow", "Ptr", this.List.Hwnd,
            "UInt")
        if !rowDpi
            rowDpi := 96
        return Max(1, Round(MappingWindow.ListRowHeight * rowDpi / 96))
    }

    GetListNonClientHeightPixels() {
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

    AlignListHeightToWholeRows(proposedHeight) {
        rowHeightPixels := this.GetListRowHeightPixels()
        nonClientHeight := this.GetListNonClientHeightPixels()
        layoutDpi := DllCall("user32\GetDpiForWindow", "Ptr", this.List.Hwnd,
            "UInt")
        if !layoutDpi
            layoutDpi := 96
        proposedOuterPixels := Max(1,
            Round(proposedHeight * layoutDpi / 96))
        proposedClientPixels := Max(1,
            proposedOuterPixels - nonClientHeight)
        minimumOuterPixels := Max(1,
            Round(MappingWindow.MinListHeight * layoutDpi / 96))
        minimumClientPixels := Max(1,
            minimumOuterPixels - nonClientHeight)
        minimumRows := Max(1, Ceil(minimumClientPixels / rowHeightPixels))
        visibleRows := Max(minimumRows,
            Floor(proposedClientPixels / rowHeightPixels))
        alignedOuterPixels := visibleRows * rowHeightPixels + nonClientHeight
        return Max(MappingWindow.MinListHeight,
            Round(alignedOuterPixels * 96 / layoutDpi))
    }

    MoveListToWholeRows(x, y, width, proposedHeight) {
        alignedHeight := this.AlignListHeightToWholeRows(proposedHeight)
        this.List.Move(x, y, width, alignedHeight)

        ; DPI 换算可能把逻辑高度舍入到相邻物理像素。最后直接校正 HWND
        ; 的物理高度，确保原生客户区始终恰好容纳整数行。
        clientRect := Buffer(16, 0)
        windowRect := Buffer(16, 0)
        rowHeightPixels := this.GetListRowHeightPixels()
        if DllCall("user32\GetClientRect", "Ptr", this.List.Hwnd,
                "Ptr", clientRect, "Int")
                && DllCall("user32\GetWindowRect", "Ptr", this.List.Hwnd,
                    "Ptr", windowRect, "Int") {
            clientHeight := NumGet(clientRect, 12, "Int")
                - NumGet(clientRect, 4, "Int")
            remainder := Mod(clientHeight, rowHeightPixels)
            if remainder {
                outerWidth := NumGet(windowRect, 8, "Int")
                    - NumGet(windowRect, 0, "Int")
                outerHeight := NumGet(windowRect, 12, "Int")
                    - NumGet(windowRect, 4, "Int")
                targetHeight := outerHeight - remainder
                DllCall("user32\SetWindowPos", "Ptr", this.List.Hwnd,
                    "Ptr", 0, "Int", 0, "Int", 0, "Int", outerWidth,
                    "Int", targetHeight, "UInt", 0x0016, "Int")
            }
        }
        this.List.GetPos(, , , &actualHeight)
        return actualHeight
    }

    ReleaseListRowImageList() {
        imageList := this.ListRowImageList
        this.ListRowImageList := 0
        this.ListRowDpi := 0
        if !imageList
            return false
        try this.List.SetImageList(0, 1)
        try this.List.IL := 0
        try IL_Destroy(imageList)
        return true
    }

    OnResize(guiObj, minMax, width, height) {
        if minMax == -1 {
            try this.App.Toast.HideNow()
            return
        }
        this.EnsureListRowMetrics()
        contentWidth := width - 20
        columnGap := 40
        inputWidth := Max(190, Floor((contentWidth - 2 * columnGap) / 3))
        captureHeights := this.GetCaptureControlHeights(inputWidth)
        statusLayout := this.GetStatusLayout(width)
        minimumListHeight := this.AlignListHeightToWholeRows(
            MappingWindow.MinListHeight)
        requiredHeight := Max(MappingWindow.BaseMinClientHeight,
            MappingWindow.ListLayoutFixedHeight
                + statusLayout.Extra
                + minimumListHeight
                + captureHeights.Button + captureHeights.Detail)
        if this.EnsureCaptureMinimumSize(requiredHeight, width, height)
            return

        this.AddButton.Move(10, 15, this.AddButtonWidth, 30)
        this.PauseResumeButton.Move(this.PauseButtonX, 15,
            this.PauseButtonWidth, 30)
        this.DeleteButton.Move(this.DeleteButtonX, 15,
            this.DeleteButtonWidth, 30)
        toolbarPositions := this.GetToolbarButtonPositions(width)
        this.SettingsButton.Move(toolbarPositions.Settings,
            15, this.SettingsButtonWidth,
            MappingWindow.SettingsButtonHeight)
        this.SupportButton.Move(toolbarPositions.Support,
            15, this.SupportButtonWidth,
            MappingWindow.SettingsButtonHeight)
        this.DonateButton.Move(toolbarPositions.Donate,
            15, this.DonateButtonWidth,
            MappingWindow.SettingsButtonHeight)
        proposedListHeight := Max(MappingWindow.MinListHeight,
            height - MappingWindow.ListLayoutFixedHeight
                - statusLayout.Extra
                - captureHeights.Button - captureHeights.Detail)
        ; 先收敛列宽，避免旧列宽临时触发横向滚动条并改变可用客户区高度。
        this.ConfigureColumns(width)
        listHeight := this.MoveListToWholeRows(10, 88, contentWidth,
            proposedListHeight)
        sectionY := 88 + listHeight + 10
        this.SectionTopDivider.Move(10, sectionY - 4, contentWidth, 1)
        this.SectionTitle.Move(10, sectionY, contentWidth, 24)

        labelY := sectionY + 32
        controlY := sectionY + 56
        secondX := 10 + inputWidth + columnGap
        thirdX := secondX + inputWidth + columnGap
        purposeWidth := width - 10 - thirdX

        this.SourceLabel.Move(10, labelY)
        this.SourceButton.Move(10, controlY, inputWidth, captureHeights.Button)
        this.ArrowText.Move(10 + inputWidth + 6,
            controlY + (captureHeights.Button - 24) // 2, columnGap - 12, 24)
        this.TargetLabel.Move(secondX, labelY)
        this.TargetButton.Move(secondX, controlY, inputWidth, captureHeights.Button)
        this.PurposeLabel.Move(thirdX, labelY)
        MovePaddedMultilineEdit(this.PurposeInput, thirdX, controlY,
            purposeWidth, captureHeights.Button)
        detailY := controlY + captureHeights.Button + 4
        MoveAndRefreshResizableText(this.SourceDetail, 10, detailY,
            inputWidth, captureHeights.Detail)
        MoveAndRefreshResizableText(this.TargetDetail, secondX, detailY,
            inputWidth, captureHeights.Detail)

        commandY := height - 52
        this.SaveButton.Move(statusLayout.SaveButtonX, commandY,
            this.SaveButtonWidth, 32)
        this.ClearButton.Move(statusLayout.ClearButtonX, commandY,
            MappingWindow.ClearButtonWidth, 32)
        statusY := height - MappingWindow.StatusBottomMargin
            - statusLayout.Height
        MoveAndRefreshResizableText(this.Status, 10, statusY,
            statusLayout.Width, statusLayout.Height)
        try this.App.Toast.Reposition()
    }

    ConfigureColumns(width) {
        if IsObject(this.CellTooltip)
            this.CellTooltip.Hide()
        usable := Max(1, width - 38)
        sequenceWidth := 48
        scopeWidth := MappingWindow.ScopeColumnWidth
        if this.ContentColumnWidthsDirty
            this.MeasureContentColumnWidths()
        pairAvailable := Max(
            MappingWindow.MinSourceColumnWidth
                + MappingWindow.MinTargetColumnWidth,
            usable - sequenceWidth - scopeWidth
                - MappingWindow.MinPurposeColumnWidth)
        contentWidths := this.FitContentColumnWidths(pairAvailable)
        sourceWidth := contentWidths.Source
        targetWidth := contentWidths.Target
        purposeWidth := Max(MappingWindow.MinPurposeColumnWidth,
            usable - sequenceWidth - sourceWidth - targetWidth - scopeWidth)
        this.ApplyColumnWidth(MappingWindow.SequenceColumn, sequenceWidth,
            "Integer Center")
        this.ApplyColumnWidth(MappingWindow.SourceColumn, sourceWidth,
            "Center")
        this.ApplyColumnWidth(MappingWindow.TargetColumn, targetWidth,
            "Center")
        this.ApplyColumnWidth(MappingWindow.ScopeColumn, scopeWidth,
            "Center")
        this.ApplyColumnWidth(MappingWindow.PurposeColumn, purposeWidth)
        this.ApplyColumnWidth(MappingWindow.MappingIdColumn, 0)
        this.ApplyColumnWidth(MappingWindow.EnabledColumn, 0)
        if IsObject(this.ListHeader)
            this.ListHeader.SetBounds(10, 60,
                [sequenceWidth, sourceWidth, targetWidth, scopeWidth,
                    purposeWidth], Max(0, width - 20))
    }

    ApplyColumnWidth(column, width, options := "") {
        columnDpi := DllCall("user32\GetDpiForWindow", "Ptr", this.List.Hwnd,
            "UInt")
        if !columnDpi
            columnDpi := 96
        currentPixels := SendMessage(0x101D, column - 1, 0, ,
            this.List.Hwnd) ; LVM_GETCOLUMNWIDTH
        expectedPixels := Round(width * columnDpi / 96)
        if this.AppliedColumnWidths.Has(column)
                && this.AppliedColumnWidths[column] == width
                && currentPixels == expectedPixels
            return false
        modifyOptions := options == "" ? width : options " " width
        this.List.ModifyCol(column, modifyOptions)
        this.AppliedColumnWidths[column] := width
        return true
    }

    MeasureContentColumnWidths() {
        try {
            this.List.ModifyCol(MappingWindow.SourceColumn, "AutoHdr")
            this.List.ModifyCol(MappingWindow.TargetColumn, "AutoHdr")
            this.DesiredSourceColumnWidth := Max(
                MappingWindow.MinSourceColumnWidth,
                this.GetColumnLogicalWidth(MappingWindow.SourceColumn) + 16)
            this.DesiredTargetColumnWidth := Max(
                MappingWindow.MinTargetColumnWidth,
                this.GetColumnLogicalWidth(MappingWindow.TargetColumn) + 16)
            this.ContentColumnWidthsDirty := false
            return true
        } catch {
            return false
        }
    }

    GetColumnLogicalWidth(column) {
        widthPixels := SendMessage(0x101D, column - 1, 0, ,
            this.List.Hwnd) ; LVM_GETCOLUMNWIDTH
        columnDpi := DllCall("user32\GetDpiForWindow", "Ptr", this.List.Hwnd,
            "UInt")
        if !columnDpi
            columnDpi := 96
        return Max(1, Ceil(widthPixels * 96 / columnDpi))
    }

    FitContentColumnWidths(availableWidth) {
        sourceMinimum := MappingWindow.MinSourceColumnWidth
        targetMinimum := MappingWindow.MinTargetColumnWidth
        sourceDesired := Max(sourceMinimum, this.DesiredSourceColumnWidth)
        targetDesired := Max(targetMinimum, this.DesiredTargetColumnWidth)
        if sourceDesired + targetDesired <= availableWidth {
            return {Source: sourceDesired, Target: targetDesired}
        }

        flexibleWidth := Max(0,
            availableWidth - sourceMinimum - targetMinimum)
        sourceNeed := sourceDesired - sourceMinimum
        targetNeed := targetDesired - targetMinimum
        totalNeed := sourceNeed + targetNeed
        sourceExtra := totalNeed > 0
            ? Round(flexibleWidth * sourceNeed / totalNeed) : 0
        sourceExtra := Min(sourceNeed, sourceExtra)
        targetExtra := Min(targetNeed, flexibleWidth - sourceExtra)
        return {
            Source: sourceMinimum + sourceExtra,
            Target: targetMinimum + targetExtra
        }
    }
}
