class EventViewerWindow {
    static MinimumWidth := 1020
    static MinimumHeight := 500
    static TimeColumn := 1
    static CategoryColumn := 2
    static EventColumn := 3
    static SourceColumn := 4
    static OutcomeColumn := 5
    static DetailColumn := 6
    static EventColumnWidth := 184
    static SortRefreshDelayMs := 50
    static SnapshotRefreshDelayMs := 50
    static MaximumSnapshotRebuildPasses := 3

    __New(ownerWindow) {
        this.OwnerWindow := ownerWindow
        this.App := ownerWindow.App
        this.Trace := this.App.Trace
        this.Gui := ""
        this.IconHandles := []
        this.Interactions := ""
        this.ListSelection := ""
        this.SubscriptionId := 0
        this.Paused := false
        this.RawObservationActive := false
        this.SnapshotLoading := false
        this.SnapshotDirty := false
        this.SnapshotRefreshPending := false
        this.SnapshotRefreshTimer := ObjBindMethod(this,
            "ApplyPendingSnapshotRefresh")
        this.SortRefreshPending := false
        this.SortRefreshTimer := ObjBindMethod(this, "ApplyPendingSort")
        this.DetailMode := "event"
        this.Disposed := false
        this.SequenceItemIds := Map()
        this.ItemIdSequences := Map()
        this.EntriesBySequence := Map()
        this.FilterValues := ["", "input", "runtime", "repository",
            "history", "system", "ui"]
        try this.Build()
        catch as buildError {
            this.Dispose()
            throw buildError
        }
    }

    Build() {
        colors := UiThemeService.GetPalette()
        fontName := LocalizationService.GetUiFontName()
        systemFont := LocalizationService.GetLanguageSystemUiFontName()
        this.Gui := Gui("+Owner" this.OwnerWindow.Gui.Hwnd
            " +Resize +MinSize" EventViewerWindow.MinimumWidth "x"
            EventViewerWindow.MinimumHeight, Tr("事件查看器"))
        this.IconHandles := ApplyApplicationWindowIcon(this.Gui.Hwnd)
        this.Gui.BackColor := colors.Window
        this.Gui.MarginX := 0
        this.Gui.MarginY := 0
        this.Gui.SetFont("norm s10 c" colors.Text, fontName)
        this.Interactions := MappingUiInteractions(this.Gui, colors.Window,
            this.App.SvgRenderer)

        this.FilterLabel := this.Gui.Add("Text",
            "x12 y17 w54 h26 0x200 BackgroundTrans c" colors.Muted,
            Tr("筛选："))
        this.FilterDropDown := this.Gui.Add("DropDownList",
            "x66 y17 w150 Choose1 Background" colors.Input " c"
            colors.Text " -Border -E0x200", AddComboBoxDisplayPadding([
                Tr("全部事件"), Tr("输入事件"), Tr("规则运行"),
                Tr("规则仓储"), Tr("撤销历史"), Tr("系统事件"),
                Tr("界面事件")]))
        this.FilterDropDown.OnEvent("Change", ObjBindMethod(this,
            "OnFilterChanged"))
        ApplyDarkComboBoxTheme(this.FilterDropDown.Hwnd)

        this.PauseButton := this.AddButton(228, 15, 112,
            Tr("暂停刷新"), colors.Pause,
            ObjBindMethod(this, "TogglePaused"))
        this.ClearButton := this.AddButton(350, 15, 96, Tr("清空"),
            colors.Toolbar, ObjBindMethod(this, "Clear"), colors.ToolbarText)
        this.ExportButton := this.AddButton(456, 15, 128, Tr("导出事件"),
            colors.Primary, ObjBindMethod(this, "ChooseExport"))
        this.RawObservationButton := this.AddButton(594, 15, 144,
            Tr("原始观察"), colors.Toolbar,
            ObjBindMethod(this, "ToggleRawObservation"), colors.ToolbarText)
        this.VariableButton := this.AddButton(748, 15, 110,
            Tr("变量"), colors.Toolbar,
            ObjBindMethod(this, "ShowVariables"), colors.ToolbarText)
        this.DiagnosticButton := this.AddButton(868, 15, 120,
            Tr("诊断包"), colors.Toolbar,
            ObjBindMethod(this, "ChooseDiagnosticBundle"),
            colors.ToolbarText)
        this.ApplyCommandIcons()

        this.List := this.Gui.Add("ListView",
            "x12 y78 w876 h372 Report +ReadOnly -Multi -Hdr +LV0x10000"
            " -Border -E0x200 Background" colors.Surface " c" colors.Text,
            [Tr("时间"), Tr("类别"), Tr("事件"), Tr("来源 / 规则"),
                Tr("结果"), Tr("详情")])
        this.List.SetFont("s10 c" colors.Text, fontName)
        this.List.OnEvent("ItemSelect", ObjBindMethod(this,
            "OnListItemSelected"))
        this.HeaderLabels := [Tr("时间"), Tr("类别"), Tr("事件"),
            Tr("来源 / 规则"), Tr("结果"), Tr("详情")]
        this.ListHeader := ListViewPseudoHeader(this.Gui, this.List, [
            {Column: EventViewerWindow.TimeColumn,
                Label: this.HeaderLabels[1], SortOptions: "Logical"},
            {Column: EventViewerWindow.CategoryColumn,
                Label: this.HeaderLabels[2], SortOptions: "Logical"},
            {Column: EventViewerWindow.EventColumn,
                Label: this.HeaderLabels[3], SortOptions: "Logical"},
            {Column: EventViewerWindow.SourceColumn,
                Label: this.HeaderLabels[4], SortOptions: "Logical"},
            {Column: EventViewerWindow.OutcomeColumn,
                Label: this.HeaderLabels[5], SortOptions: "Logical"},
            {Column: EventViewerWindow.DetailColumn,
                Label: this.HeaderLabels[6], SortOptions: "Logical"}
        ], {
            BackgroundColor: colors.Toolbar,
            TextColor: colors.Muted,
            FontName: systemFont,
            CursorRegistrar: ObjBindMethod(this.Interactions,
                "RegisterHandCursor"),
            OnSortChanged: ObjBindMethod(this, "OnHeaderSortChanged")
        })
        this.Status := this.Gui.Add("Text",
            "x12 y466 w876 h24 Background" colors.Window " c" colors.Muted,
            "")
        this.DetailLabel := this.Gui.Add("Text",
            "x12 y382 w876 h22 0x200 Background" colors.Window " c"
            colors.Muted, Tr("事件详情"))
        this.DetailEdit := this.Gui.Add("Edit",
            "x12 y404 w876 h52 ReadOnly Multi VScroll -Wrap -Border"
            " -E0x200 Background" colors.Input " c" colors.Text, "")
        this.DetailEdit.SetFont("s10", fontName)
        this.Interactions.RegisterTextInput(this.DetailEdit)
        this.CellTooltip := ListCellTooltipWindow(this.List)
        this.ListSelection := ListViewSelectionPresenter(this.List,
            this.Interactions.Painter)
        this.Gui.OnEvent("Size", ObjBindMethod(this, "OnResize"))
        this.Gui.OnEvent("Close", ObjBindMethod(this, "RequestClose"))
        this.Gui.OnEvent("Escape", ObjBindMethod(this, "RequestClose"))
        this.SubscriptionId := this.Trace.Subscribe(
            ObjBindMethod(this, "OnTraceEntry"))
        this.LoadSnapshot()
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
        this.Interactions.SetButtonLucideIcon(this.PauseButton,
            this.Paused ? "play.svg" : "circle-pause.svg", 15, 6)
        this.Interactions.SetButtonLucideIcon(this.ClearButton,
            "eraser.svg", 15, 6)
        this.Interactions.SetButtonLucideIcon(this.ExportButton,
            "file-output.svg", 15, 6)
        this.Interactions.SetButtonLucideIcon(this.RawObservationButton,
            this.RawObservationActive ? "x.svg" : "target.svg", 15, 6)
        this.Interactions.SetButtonLucideIcon(this.VariableButton,
            "sliders-horizontal.svg", 15, 6)
        this.Interactions.SetButtonLucideIcon(this.DiagnosticButton,
            "circle-info.svg", 15, 6)
    }

    Show() {
        if this.Disposed
            return
        ShowPreparedWindow(this.Gui, "w1100 h650",
            ObjBindMethod(this, "ApplyNativeThemes"))
    }

    ApplyNativeThemes(*) {
        if this.Disposed
            return false
        ApplyDarkWindow(this.Gui.Hwnd)
        ApplyDarkListView(this.List.Hwnd)
        ApplyDarkComboBoxTheme(this.FilterDropDown.Hwnd)
        ApplyDarkControl(this.DetailEdit.Hwnd)
        return true
    }

    Activate() {
        if this.Disposed
            return
        return ActivatePreparedWindow(this.Gui)
    }

    GetFilterCategory() {
        index := this.FilterDropDown.Value
        return index >= 1 && index <= this.FilterValues.Length
            ? this.FilterValues[index] : ""
    }

    OnFilterChanged(*) => this.LoadSnapshot()

    LoadSnapshot() {
        if this.Disposed
            return false
        if this.SnapshotLoading {
            this.SnapshotDirty := true
            return false
        }
        this.CancelPendingSort()
        this.CancelPendingSnapshotRefresh()
        this.SnapshotLoading := true
        rebuildPasses := 0
        deferredRefreshRequired := false
        SendMessage(Win32.WM_SETREDRAW, 0, 0, , this.List.Hwnd)
        try {
            Loop {
                rebuildPasses++
                this.SnapshotDirty := false
                this.List.Delete()
                this.SequenceItemIds.Clear()
                this.ItemIdSequences.Clear()
                this.EntriesBySequence.Clear()
                this.DetailEdit.Value := ""
                for entry in this.Trace.Snapshot(this.GetFilterCategory())
                    this.AddEntry(entry, false)
                ; Input hooks can interrupt the GUI thread while it is
                ; populating the ListView. Rebuild before exposing stale rows.
                this.SnapshotLoading := false
                if !this.SnapshotDirty
                    break
                if rebuildPasses >= EventViewerWindow.MaximumSnapshotRebuildPasses {
                    deferredRefreshRequired := true
                    break
                }
                this.SnapshotLoading := true
            }
            if this.ListHeader.HasActiveSort()
                this.ListHeader.ApplyCurrentSort()
        } finally {
            this.SnapshotLoading := false
            SendMessage(Win32.WM_SETREDRAW, 1, 0, , this.List.Hwnd)
            DllCall("user32\RedrawWindow", "Ptr", this.List.Hwnd,
                "Ptr", 0, "Ptr", 0, "UInt", 0x0181, "Int")
        }
        if this.DetailMode == "variables"
            this.RefreshVariableSnapshot()
        this.UpdateStatus()
        this.ScrollToLatest()
        if deferredRefreshRequired
            this.ScheduleSnapshotRefresh()
        return true
    }

    ScheduleSnapshotRefresh() {
        if this.Disposed || this.Paused || this.SnapshotRefreshPending
            return false
        this.SnapshotRefreshPending := true
        SetTimer(this.SnapshotRefreshTimer,
            -EventViewerWindow.SnapshotRefreshDelayMs)
        return true
    }

    ApplyPendingSnapshotRefresh(*) {
        try SetTimer(this.SnapshotRefreshTimer, 0)
        this.SnapshotRefreshPending := false
        if this.Disposed || this.Paused
            return false
        return this.LoadSnapshot()
    }

    CancelPendingSnapshotRefresh() {
        if IsObject(this.SnapshotRefreshTimer)
            try SetTimer(this.SnapshotRefreshTimer, 0)
        this.SnapshotRefreshPending := false
        return true
    }

    OnTraceEntry(entry) {
        if this.Disposed || this.Paused
            return
        if this.SnapshotLoading {
            this.SnapshotDirty := true
            return
        }
        if entry.HasOwnProp("EvictedSequence") && entry.EvictedSequence
                && !this.RemoveSequence(entry.EvictedSequence) {
            this.LoadSnapshot()
            this.UpdateStatus()
            return
        }
        category := this.GetFilterCategory()
        if category != "" && entry.Category != category {
            this.UpdateStatus()
            return
        }
        this.AddEntry(entry)
        if this.DetailMode == "variables"
                && entry.Category == "runtime"
                && entry.Event == "action_executed"
            this.RefreshVariableSnapshot()
        this.UpdateStatus()
    }

    RemoveSequence(sequence) {
        previousCritical := A_IsCritical
        Critical("On")
        try {
            sequenceKey := String(sequence)
            if !this.SequenceItemIds.Has(sequenceKey)
                return true
            itemId := this.SequenceItemIds[sequenceKey]
            rowIndex := SendMessage(0x10B5, itemId, 0, ,
                this.List.Hwnd) ; LVM_MAPIDTOINDEX
            if rowIndex < 0 {
                this.SequenceItemIds.Delete(sequenceKey)
                return false
            }
            if IsObject(this.CellTooltip)
                this.CellTooltip.Hide()
            this.List.Delete(rowIndex + 1)
            this.SequenceItemIds.Delete(sequenceKey)
            this.ItemIdSequences.Delete(String(itemId))
            this.EntriesBySequence.Delete(sequenceKey)
            return true
        } finally {
            Critical(previousCritical)
        }
    }

    HasSequence(sequence) {
        sequenceKey := String(sequence)
        if !this.SequenceItemIds.Has(sequenceKey)
            return false
        return SendMessage(0x10B5, this.SequenceItemIds[sequenceKey], 0, ,
            this.List.Hwnd) >= 0 ; LVM_MAPIDTOINDEX
    }

    AddEntry(entry, applySort := true) {
        previousCritical := A_IsCritical
        Critical("On")
        try {
            sourceAndRule := entry.Source
            if entry.RuleId != ""
                sourceAndRule .= (sourceAndRule == "" ? "" : " · ")
                    . entry.RuleId
            row := this.List.Add("", SubStr(entry.Timestamp, 12, 12),
                this.GetCategoryLabel(entry.Category), entry.Event,
                sourceAndRule, entry.Outcome, entry.Detail)
            itemId := SendMessage(0x10B4, row - 1, 0, ,
                this.List.Hwnd) ; LVM_MAPINDEXTOID
            if itemId < 0 {
                this.List.Delete(row)
                throw Error("无法建立事件查看器行标识。")
            }
            this.SequenceItemIds[String(entry.Sequence)] := itemId
            this.ItemIdSequences[String(itemId)] := String(entry.Sequence)
            this.EntriesBySequence[String(entry.Sequence)] := entry
        } finally {
            Critical(previousCritical)
        }
        if applySort && this.ListHeader.HasActiveSort()
            this.ScheduleActiveSort()
        else if applySort
            this.ScrollToLatest(row)
    }

    ScheduleActiveSort() {
        if this.Disposed || !this.ListHeader.HasActiveSort()
            return false
        if this.SortRefreshPending
            return true
        this.SortRefreshPending := true
        SetTimer(this.SortRefreshTimer,
            -EventViewerWindow.SortRefreshDelayMs)
        return true
    }

    ApplyPendingSort(*) {
        try SetTimer(this.SortRefreshTimer, 0)
        this.SortRefreshPending := false
        if this.Disposed || this.SnapshotLoading
                || !this.ListHeader.HasActiveSort()
            return false
        previousCritical := A_IsCritical
        Critical("On")
        try return this.ListHeader.ApplyCurrentSort()
        finally Critical(previousCritical)
    }

    CancelPendingSort() {
        if IsObject(this.SortRefreshTimer)
            try SetTimer(this.SortRefreshTimer, 0)
        this.SortRefreshPending := false
        return true
    }

    OnHeaderSortChanged(column, *) {
        if column == 0
            this.LoadSnapshot()
    }

    OnListItemSelected(control, row, selected) {
        if this.Disposed || !selected || row < 1
            return
        itemId := SendMessage(0x10B4, row - 1, 0, ,
            this.List.Hwnd) ; LVM_MAPINDEXTOID
        itemKey := String(itemId)
        if itemId < 0 || !this.ItemIdSequences.Has(itemKey)
            return
        sequenceKey := this.ItemIdSequences[itemKey]
        if !this.EntriesBySequence.Has(sequenceKey)
            return
        this.DetailMode := "event"
        this.DetailLabel.Text := Tr("事件详情")
        this.DetailEdit.Value := this.FormatEntryDetails(
            this.EntriesBySequence[sequenceKey])
        try SendMessage(0x00B1, 0, 0, , this.DetailEdit.Hwnd) ; EM_SETSEL
    }

    FormatEntryDetails(entry) {
        lines := []
        lines.Push(Tr("事件：{1}", entry.Event))
        lines.Push(Tr("类别：{1}", this.GetCategoryLabel(entry.Category)))
        lines.Push(Tr("时间：{1}", entry.Timestamp))
        lines.Push("Tick: " entry.Tick " ms")
        if entry.Source != ""
            lines.Push(Tr("来源：{1}", entry.Source))
        if entry.RuleId != ""
            lines.Push("Rule ID: " entry.RuleId)
        if entry.Outcome != ""
            lines.Push(Tr("结果：{1}", entry.Outcome))
        if entry.Detail != ""
            lines.Push(Tr("详情：{1}", entry.Detail))
        if Type(entry.Data) == "Map" && entry.Data.Count {
            if entry.Data.Has("identity")
                this.AppendInputIdentityDetails(lines, entry.Data)
            lines.Push("")
            lines.Push("JSON:")
            lines.Push(JsonCodec.Stringify(entry.Data, true, true))
        }
        return this.JoinLines(lines)
    }

    AppendInputIdentityDetails(lines, unifiedEvent) {
        identity := unifiedEvent["identity"]
        lines.Push("")
        lines.Push(Tr("按键名称：{1}", identity["name"]))
        lines.Push("Kind: " identity["kind"])
        lines.Push("VK: " (identity["vk_hex"] == "" ? "--"
            : "0x" identity["vk_hex"]))
        lines.Push("SC: " (identity["sc_hex"] == "" ? "---"
            : "0x" identity["sc_hex"]))
        lines.Push("Extended: "
            (identity["extended"].Value ? "true" : "false"))
        if identity["device_id"] != ""
            lines.Push("Device ID: " identity["device_id"])
        if identity["device_handle"] != ""
            lines.Push("Device handle: " identity["device_handle"])
        if identity["usage_page"] || identity["usage"]
            lines.Push(Format("Usage: 0x{:04X} / 0x{:04X}",
                identity["usage_page"], identity["usage"]))
        lines.Push("Phase: " unifiedEvent["phase"])
        lines.Push("Repeat: "
            (unifiedEvent["repeat"].Value ? "true" : "false"))
        lines.Push("Injected: "
            (unifiedEvent["injected"].Value ? "true" : "false"))
        lines.Push("Origin: " unifiedEvent["origin"])
        lines.Push("QPC: " unifiedEvent["qpc"] " / "
            unifiedEvent["qpc_frequency"] " Hz")
    }

    JoinLines(lines) {
        result := ""
        for index, line in lines
            result .= (index > 1 ? "`r`n" : "") line
        return result
    }

    ShowVariables(*) {
        this.DetailMode := "variables"
        this.DetailLabel.Text := Tr("变量快照")
        return this.RefreshVariableSnapshot()
    }

    RefreshVariableSnapshot() {
        if this.Disposed || this.DetailMode != "variables"
            return false
        context := this.App.ContextService.Build(
            this.App.VariableStore, this.App.GetInputDevices())
        scopes := this.App.VariableStore.GetSnapshot(context["builtin"])
        lines := []
        for scopeName in ["transient", "persistent", "builtin"] {
            lines.Push("")
            lines.Push(scopeName ":")
            lines.Push(JsonCodec.Stringify(scopes[scopeName], true, true))
        }
        this.DetailEdit.Value := this.JoinLines(lines)
        try SendMessage(0x00B1, 0, 0, , this.DetailEdit.Hwnd)
        return true
    }

    ScrollToLatest(row := 0) {
        if this.Disposed || !this.App.Settings.EventViewerAutoScroll
                || this.ListHeader.HasActiveSort()
            return false
        if !row
            row := this.List.GetCount()
        if row < 1
            return false
        this.List.Modify(row, "Vis")
        return true
    }

    ApplyBehaviorSettings() {
        if this.Disposed
            return false
        this.LoadSnapshot()
        return true
    }

    GetCategoryLabel(category) {
        switch category {
            case "input": return Tr("输入")
            case "runtime": return Tr("运行时")
            case "repository": return Tr("仓储")
            case "history": return Tr("历史")
            case "system": return Tr("系统")
            case "ui": return Tr("界面")
            default: return String(category)
        }
    }

    TogglePaused(*) {
        this.Paused := !this.Paused
        if this.Paused
            this.CancelPendingSnapshotRefresh()
        colors := UiThemeService.GetPalette()
        this.Interactions.SetTextNoErase(this.PauseButton,
            this.Paused ? Tr("恢复刷新") : Tr("暂停刷新"))
        this.Interactions.SetButtonAppearance(this.PauseButton,
            this.Paused ? colors.Add : colors.Pause,
            colors.ButtonText, true)
        this.ApplyCommandIcons()
        if !this.Paused
            this.LoadSnapshot()
        this.UpdateStatus()
    }

    ToggleRawObservation(*) {
        try {
            if this.RawObservationActive
                this.App.EndRawObservation()
            else
                this.App.BeginRawObservation()
            this.RawObservationActive := !this.RawObservationActive
        } catch as observationError {
            this.Status.Opt("c" UiThemeService.GetPalette().Error)
            this.Status.Text := Tr("原始观察切换失败：{1}",
                observationError.Message)
            return false
        }
        colors := UiThemeService.GetPalette()
        this.Interactions.SetTextNoErase(this.RawObservationButton,
            this.RawObservationActive ? Tr("退出观察") : Tr("原始观察"))
        this.Interactions.SetButtonAppearance(this.RawObservationButton,
            this.RawObservationActive ? colors.Pause : colors.Toolbar,
            this.RawObservationActive ? colors.ButtonText
                : colors.ToolbarText, true)
        this.ApplyCommandIcons()
        this.UpdateStatus()
        return true
    }

    Clear(*) {
        this.CancelPendingSort()
        this.CancelPendingSnapshotRefresh()
        this.Trace.Clear()
        this.List.Delete()
        this.SequenceItemIds.Clear()
        this.ItemIdSequences.Clear()
        this.EntriesBySequence.Clear()
        this.DetailEdit.Value := ""
        if this.DetailMode == "variables"
            this.RefreshVariableSnapshot()
        this.UpdateStatus()
    }

    ChooseExport(*) {
        suggested := A_Desktop "\key-mouse-remapper-assistant-events-"
            . FormatTime(, "yyyyMMdd-HHmmss") ".jsonl"
        filePath := FileSelect("S16", suggested, Tr("导出事件"),
            "JSON Lines (*.jsonl)")
        return filePath == "" ? false : this.ExportTo(filePath)
    }

    ChooseDiagnosticBundle(*) {
        try preview := this.App.CreateDiagnosticPreview()
        catch as previewError {
            this.Status.Opt("c" UiThemeService.GetPalette().Error)
            this.Status.Text := Tr("诊断包导出失败：{1}",
                previewError.Message)
            return false
        }
        counts := preview.Counts
        textAndCommands := counts["text_actions"] + counts["run_commands"]
        message := Tr("将导出 {1} 条事件；已脱敏窗口标题 {2}、路径 {3}、"
            . "文本/命令 {4}、代码 {5}、变量值 {6} 项。是否继续？",
            preview.EventCount, counts["window_titles"], counts["paths"],
            textAndCommands, counts["raw_code"], counts["variable_values"])
        if !ShowDarkConfirmBox(message, Tr("诊断包预览"),
                Tr("导出诊断包"), Tr("取消"), this.Gui)
            return false
        suggested := A_Desktop "\key-mouse-remapper-assistant-diagnostic-"
            . FormatTime(, "yyyyMMdd-HHmmss") ".json"
        filePath := FileSelect("S16", suggested, Tr("导出诊断包"),
            "JSON (*.json)")
        if filePath == ""
            return false
        try this.App.ExportDiagnosticPreview(preview, filePath)
        catch as exportError {
            this.Status.Opt("c" UiThemeService.GetPalette().Error)
            this.Status.Text := Tr("诊断包导出失败：{1}",
                exportError.Message)
            return false
        }
        this.Status.Opt("c" UiThemeService.GetPalette().Muted)
        this.Status.Text := Tr("诊断包已导出：{1}", filePath)
        return true
    }

    ExportTo(filePath) {
        try this.Trace.ExportJsonLines(filePath, this.GetFilterCategory())
        catch as exportError {
            this.Status.Opt("c" UiThemeService.GetPalette().Error)
            this.Status.Text := Tr("事件导出失败：{1}", exportError.Message)
            return false
        }
        this.Status.Opt("c" UiThemeService.GetPalette().Muted)
        this.Status.Text := Tr("事件已导出：{1}", filePath)
        return true
    }

    UpdateStatus() {
        stateText := this.Paused ? Tr("已暂停刷新") : Tr("实时刷新")
        if this.RawObservationActive
            stateText .= " · " Tr("原始观察中")
        this.Status.Opt("c" UiThemeService.GetPalette().Muted)
        this.Status.Text := Tr(
            "显示 {1} 条 · 缓冲区 {2}/{3} · 已丢弃 {4} 条 · {5}",
            this.List.GetCount(), this.Trace.Count, this.Trace.Capacity,
            this.Trace.DroppedCount, stateText)
    }

    OnResize(guiObj, minMax, width, height) {
        if minMax == -1
            return
        listWidth := Max(200, width - 24)
        listHeight := Max(180, Floor((height - 150) * 0.58))
        this.List.Move(12, 78, listWidth, listHeight)
        widths := this.ConfigureColumns(listWidth)
        this.ListHeader.SetBounds(12, 50, widths, listWidth)
        detailLabelY := 88 + listHeight
        detailEditY := detailLabelY + 24
        detailHeight := Max(52, height - detailEditY - 44)
        this.DetailLabel.Move(12, detailLabelY, listWidth, 22)
        this.DetailEdit.Move(12, detailEditY, listWidth, detailHeight)
        this.Status.Move(12, height - 34, listWidth, 24)
    }

    ConfigureColumns(width) {
        timeWidth := 106
        categoryWidth := 82
        eventWidth := EventViewerWindow.EventColumnWidth
        sourceWidth := Max(150, Floor(width * 0.20))
        outcomeWidth := 100
        detailWidth := Max(180, width - timeWidth - categoryWidth
            - eventWidth - sourceWidth - outcomeWidth - 4)
        widths := [timeWidth, categoryWidth, eventWidth, sourceWidth,
            outcomeWidth, detailWidth]
        for index, columnWidth in widths
            this.List.ModifyCol(index, columnWidth)
        return widths
    }

    ApplyAppearance() {
        if this.Disposed
            return false
        BeginStableWindowUpdate(this.Gui.Hwnd)
        try {
        colors := UiThemeService.GetPalette()
        fontName := LocalizationService.GetUiFontName()
        systemFont := LocalizationService.GetLanguageSystemUiFontName()
        this.Gui.Title := Tr("事件查看器")
        this.Gui.BackColor := colors.Window
        this.Interactions.SetParentColor(colors.Window)
        this.FilterLabel.Text := Tr("筛选：")
        this.FilterLabel.Opt("c" colors.Muted)
        selectedFilter := this.FilterDropDown.Value
        UnregisterDarkComboBoxTheme(this.FilterDropDown.Hwnd)
        this.FilterDropDown.Delete()
        this.FilterDropDown.Add(AddComboBoxDisplayPadding([
            Tr("全部事件"), Tr("输入事件"), Tr("规则运行"),
                Tr("规则仓储"), Tr("撤销历史"), Tr("系统事件"),
                Tr("界面事件")]))
        this.FilterDropDown.Value := selectedFilter
        this.HeaderLabels := [Tr("时间"), Tr("类别"), Tr("事件"),
            Tr("来源 / 规则"), Tr("结果"), Tr("详情")]
        this.ListHeader.SetLabels(this.HeaderLabels)
        this.ListHeader.ApplyAppearance(colors.Toolbar, colors.Muted,
            systemFont, 9)
        this.List.Opt("Background" colors.Surface " c" colors.Text)
        this.List.SetFont("s10 c" colors.Text, fontName)
        this.DetailLabel.Text := this.DetailMode == "variables"
            ? Tr("变量快照") : Tr("事件详情")
        this.DetailLabel.Opt("Background" colors.Window " c" colors.Muted)
        this.DetailEdit.Opt("Background" colors.Input " c" colors.Text)
        this.DetailEdit.SetFont("s10", fontName)
        this.Status.Opt("Background" colors.Window " c" colors.Muted)
        this.Interactions.SetTextNoErase(this.ClearButton, Tr("清空"))
        this.Interactions.SetTextNoErase(this.ExportButton, Tr("导出事件"))
        this.Interactions.SetTextNoErase(this.RawObservationButton,
            this.RawObservationActive ? Tr("退出观察") : Tr("原始观察"))
        this.Interactions.SetTextNoErase(this.DiagnosticButton, Tr("诊断包"))
        this.Interactions.SetTextNoErase(this.VariableButton, Tr("变量"))
        this.Interactions.SetButtonAppearance(this.ClearButton,
            colors.Toolbar, colors.ToolbarText, true)
        this.Interactions.SetButtonAppearance(this.ExportButton,
            colors.Primary, colors.ButtonText, true)
        this.Interactions.SetButtonAppearance(this.RawObservationButton,
            this.RawObservationActive ? colors.Pause : colors.Toolbar,
            this.RawObservationActive ? colors.ButtonText
                : colors.ToolbarText, true)
        this.Interactions.SetButtonAppearance(this.DiagnosticButton,
            colors.Toolbar, colors.ToolbarText, true)
        this.Interactions.SetButtonAppearance(this.VariableButton,
            colors.Toolbar, colors.ToolbarText, true)
        this.Interactions.SetTextNoErase(this.PauseButton,
            this.Paused ? Tr("恢复刷新") : Tr("暂停刷新"))
        this.Interactions.SetButtonAppearance(this.PauseButton,
            this.Paused ? colors.Add : colors.Pause,
            colors.ButtonText, true)
        this.ApplyCommandIcons()
        for button in [this.PauseButton, this.ClearButton, this.ExportButton,
                this.RawObservationButton, this.VariableButton]
            button.SetFont("s10 bold", systemFont)
        this.DiagnosticButton.SetFont("s10 bold", systemFont)
        this.LoadSnapshot()
        this.ApplyNativeThemes()
        } finally EndStableWindowUpdate(this.Gui.Hwnd, true)
        return true
    }

    RequestClose(*) => this.Dispose()

    Dispose() {
        if this.Disposed
            return
        this.Disposed := true
        this.CancelPendingSort()
        this.CancelPendingSnapshotRefresh()
        if this.RawObservationActive {
            try this.App.EndRawObservation()
            this.RawObservationActive := false
        }
        if this.SubscriptionId
            try this.Trace.Unsubscribe(this.SubscriptionId)
        this.SubscriptionId := 0
        if IsObject(this.CellTooltip)
            try this.CellTooltip.Dispose()
        if IsObject(this.ListSelection)
            try this.ListSelection.Dispose()
        this.ListSelection := ""
        if this.HasOwnProp("ListHeader") && IsObject(this.ListHeader)
            try this.ListHeader.Dispose()
        this.ListHeader := ""
        if IsObject(this.Interactions)
            try this.Interactions.Dispose()
        this.Interactions := ""
        if this.HasOwnProp("FilterDropDown")
            try UnregisterDarkComboBoxTheme(this.FilterDropDown.Hwnd)
        if IsObject(this.Gui)
            try this.Gui.Destroy()
        ReleaseApplicationWindowIcons(this.IconHandles)
        this.IconHandles := []
        this.Gui := ""
        this.CellTooltip := ""
        this.SnapshotRefreshTimer := ""
        this.SortRefreshTimer := ""
        this.OwnerWindow.OnEventViewerClosed(this)
    }
}
