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
    static DetailEditHeight := 96
    static SortRefreshDelayMs := 50
    static SnapshotRefreshDelayMs := 50
    static MaximumSnapshotRebuildPasses := 3
    static EventLabels := Map(
        "startup", "程序启动",
        "reload_marker_cleanup_failed", "重载标记清理失败",
        "rules_applied", "规则已应用",
        "rules_changed", "规则已更改",
        "history_undo", "已撤销规则更改",
        "history_redo", "已重做规则更改",
        "rule_matched", "规则已匹配",
        "rule_held", "已识别长按",
        "rule_released", "来源键已释放",
        "rule_alone_cancelled", "单独短按已取消",
        "cycle_repeat_suppressed", "重复输入已抑制",
        "action_executed", "动作已执行",
        "action_failed", "动作执行失败",
        "condition_rejected", "规则条件不匹配",
        "condition_failed", "规则条件检查失败",
        "output_cleanup_abandoned", "输出清理已放弃",
        "output_cleanup_failed", "输出清理失败",
        "resume_state_recovered", "输入状态已恢复",
        "raw_input", "原始输入",
        "raw_key_down", "按键已按下",
        "raw_key_up", "按键已释放",
        "raw_wheel", "滚轮输入",
        "app_command", "应用命令输入",
        "capture_started", "按键录制已开始",
        "capture_completed", "按键录制已完成",
        "capture_cancelled", "按键录制已取消",
        "capture_rejected", "按键录制已拒绝",
        "capture_resume_failed", "录制后恢复重映射失败",
        "capture_device_lost", "录制设备已断开",
        "update", "更新操作",
        "update_check", "更新检查",
        "update_install", "更新安装",
        "system_theme_refresh_failed", "系统主题刷新失败",
        "input_devices_recovered", "输入设备已恢复",
        "input_devices_recovery_failed", "输入设备恢复失败",
        "power_suspend", "系统即将休眠",
        "power_suspend_failed", "休眠前输入恢复失败",
        "power_resume", "系统已唤醒",
        "power_resume_failed", "唤醒后输入恢复失败",
        "session_lock", "会话已锁定",
        "session_lock_failed", "会话锁定时输入恢复失败",
        "session_unlock", "会话已解锁",
        "session_unlock_failed", "会话解锁时输入恢复失败",
        "session_notification_registration_failed", "会话通知注册失败")
    static OutcomeLabels := Map(
        "ok", "成功", "error", "失败",
        "current", "已是最新版本", "available", "发现新版本",
        "started", "已开始", "cancelled", "已取消",
        "rejected", "已拒绝", "source", "来源键",
        "target", "目标键", "down", "按下", "up", "释放",
        "wheel", "滚动", "held", "长按",
        "other_input", "检测到其他输入",
        "unsupported_source_chord", "不支持的来源组合键",
        "modifier_change", "修饰键状态已改变",
        "held_during_reconfigure", "重新配置时来源键仍被按住",
        "send", "发送按键", "mouse", "发送鼠标操作",
        "app_command", "发送应用命令", "text", "输入文本",
        "sleep", "等待", "window_minimize", "最小化窗口",
        "window_close", "关闭窗口",
        "lock_workstation", "锁定工作站",
        "key_down", "按下目标键", "key_up", "释放目标键",
        "to", "按下时执行", "to_if_alone", "单独短按时执行",
        "to_if_held_down", "识别长按时执行",
        "to_after_key_up", "来源键释放后执行",
        "output_cleanup", "清理输出状态")
    static DetailLabels := Map(
        "to", "按下时执行",
        "to_if_alone", "单独短按时执行",
        "to_if_held_down", "识别长按时执行",
        "to_after_key_up", "来源键释放后执行",
        "output_cleanup", "清理输出状态",
        "all_conditions_matched", "全部条件均匹配",
        "all_matched", "全部子条件均匹配",
        "no_child_matched", "没有子条件匹配",
        "not_matched", "反向条件匹配",
        "not_rejected", "反向条件不匹配",
        "application_matched", "应用条件匹配",
        "application_rejected", "应用条件不匹配",
        "process_matched", "进程条件匹配",
        "process_rejected", "进程条件不匹配",
        "window_matched", "窗口条件匹配",
        "window_rejected", "窗口条件不匹配",
        "session_matched", "会话条件匹配",
        "session_rejected", "会话条件不匹配",
        "input_source_matched", "输入法条件匹配",
        "input_source_rejected", "输入法条件不匹配",
        "ShowAfterReload remained set after startup.",
            "程序启动后仍残留重载显示标记")

    __New(ownerWindow) {
        this.OwnerWindow := ownerWindow
        this.App := ownerWindow.App
        this.Trace := this.App.Trace
        this.Gui := ""
        this.OwnerLease := ""
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
        this.Disposed := false
        this.LastLayoutResult := ""
        this.LastLayoutSignature := ""
        this.AppliedColumnWidths := []
        this.SequenceItemIds := Map()
        this.ItemIdSequences := Map()
        this.EntriesBySequence := Map()
        this.RuleDisplays := Map()
        this.DetailSequence := ""
        this.FilterValues := ["runtime", "input", "repository", "system", ""]
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
        this.Gui := Gui("+Owner" this.OwnerWindow.Gui.Hwnd
            " +Resize +MinimizeBox +MinSize"
            EventViewerWindow.MinimumWidth "x"
            EventViewerWindow.MinimumHeight, Tr("事件查看"))
        this.IconHandles := ApplyApplicationWindowIcon(this.Gui.Hwnd)
        this.OwnerLease := WindowHierarchy.Acquire(this.OwnerWindow.Gui,
            this.Gui.Hwnd)
        if !this.OwnerLease
            throw Error("无法建立事件查看窗口层级。")
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
                Tr("规则运行"), Tr("输入事件"), Tr("规则仓储"),
                Tr("系统事件"), Tr("全部事件")]))
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
        colors := UiThemeService.GetPalette()
        this.Interactions.SetButtonLucideIcon(this.PauseButton,
            this.Paused ? "play.svg" : "circle-pause.svg", 15, 6,
            UiThemeService.ButtonIconColor(colors.ButtonText))
        this.Interactions.SetButtonLucideIcon(this.ClearButton,
            "eraser.svg", 15, 6,
            UiThemeService.ButtonIconColor(colors.Danger))
        this.Interactions.SetButtonLucideIcon(this.ExportButton,
            "file-output.svg", 15, 6,
            UiThemeService.ButtonIconColor(colors.ButtonText))
        this.Interactions.SetButtonLucideIcon(this.RawObservationButton,
            this.RawObservationActive ? "x.svg" : "target.svg", 15, 6,
            UiThemeService.ButtonIconColor(this.RawObservationActive
                ? colors.ButtonText : colors.DisplayIcon))
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
        this.RefreshRuleDisplays()
        this.CancelPendingSort()
        this.CancelPendingSnapshotRefresh()
        if IsObject(this.CellTooltip)
            this.CellTooltip.Hide()
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
                this.ClearDetails()
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
            SetTimer(this.SnapshotRefreshTimer, 0)
        this.SnapshotRefreshPending := false
        return true
    }

    OnTraceEntry(entry) {
        if entry.Event == "rules_changed"
            this.RefreshRuleDisplays()
        previousCritical := A_IsCritical
        Critical("On")
        try {
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
            this.UpdateStatus()
        } finally Critical(previousCritical ? previousCritical : "Off")
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
            if this.DetailSequence == sequenceKey
                this.ClearDetails()
            this.List.Delete(rowIndex + 1)
            this.SequenceItemIds.Delete(sequenceKey)
            this.ItemIdSequences.Delete(String(itemId))
            this.EntriesBySequence.Delete(sequenceKey)
            return true
        } finally {
            Critical(previousCritical)
        }
    }

    AddEntry(entry, applySort := true) {
        previousCritical := A_IsCritical
        Critical("On")
        try {
            row := this.List.Add("",
                EventViewerWindow.FormatLocalTimestamp(entry.Timestamp),
                this.GetCategoryLabel(entry.Category),
                this.GetEventLabel(entry.Event),
                this.FormatSourceAndRule(entry),
                this.GetOutcomeLabel(entry.Outcome),
                this.GetDetailLabel(entry.Detail))
            itemId := SendMessage(0x10B4, row - 1, 0, ,
                this.List.Hwnd) ; LVM_MAPINDEXTOID
            if itemId < 0 {
                this.List.Delete(row)
                throw Error("无法建立事件查看行标识。")
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
        if IsObject(this.CellTooltip)
            this.CellTooltip.Hide()
        previousCritical := A_IsCritical
        Critical("On")
        try return this.ListHeader.ApplyCurrentSort()
        finally Critical(previousCritical)
    }

    CancelPendingSort() {
        if IsObject(this.SortRefreshTimer)
            SetTimer(this.SortRefreshTimer, 0)
        this.SortRefreshPending := false
        return true
    }

    OnHeaderSortChanged(column, *) {
        if IsObject(this.CellTooltip)
            this.CellTooltip.Hide()
        if column == 0
            this.LoadSnapshot()
    }

    OnListItemSelected(control, row, selected) {
        if this.Disposed || row < 1
            return
        itemId := SendMessage(0x10B4, row - 1, 0, ,
            this.List.Hwnd) ; LVM_MAPINDEXTOID
        itemKey := String(itemId)
        if itemId < 0 || !this.ItemIdSequences.Has(itemKey) {
            if !selected
                this.ClearDetails()
            return
        }
        sequenceKey := this.ItemIdSequences[itemKey]
        if !selected {
            if this.DetailSequence == sequenceKey && !this.List.GetNext()
                this.ClearDetails()
            return
        }
        if !this.EntriesBySequence.Has(sequenceKey)
            return
        this.DetailSequence := sequenceKey
        this.DetailLabel.Text := Tr("事件详情")
        this.DetailEdit.Value := this.FormatEntryDetails(
            this.EntriesBySequence[sequenceKey])
        try SendMessage(0x00B1, 0, 0, , this.DetailEdit.Hwnd) ; EM_SETSEL
    }

    ClearDetails() {
        this.DetailSequence := ""
        this.DetailEdit.Value := ""
    }

    RefreshVisibleEntryLocalization() {
        if this.Disposed
            return false
        if IsObject(this.CellTooltip)
            this.CellTooltip.Hide()
        for sequenceKey, itemId in this.SequenceItemIds {
            if !this.EntriesBySequence.Has(sequenceKey)
                continue
            rowIndex := SendMessage(0x10B5, itemId, 0, ,
                this.List.Hwnd) ; LVM_MAPIDTOINDEX
            if rowIndex >= 0 {
                entry := this.EntriesBySequence[sequenceKey]
                this.List.Modify(rowIndex + 1,
                    "Col" EventViewerWindow.CategoryColumn,
                    this.GetCategoryLabel(entry.Category),
                    this.GetEventLabel(entry.Event),
                    this.FormatSourceAndRule(entry),
                    this.GetOutcomeLabel(entry.Outcome),
                    this.GetDetailLabel(entry.Detail))
            }
        }
        if this.DetailSequence != ""
                && this.EntriesBySequence.Has(this.DetailSequence)
            this.DetailEdit.Value := this.FormatEntryDetails(
                this.EntriesBySequence[this.DetailSequence])
        return true
    }

    OnTraceCapacityChanged() {
        if this.Disposed
            return false
        if this.Paused {
            this.UpdateStatus()
            return true
        }
        try return this.LoadSnapshot()
        catch {
            try this.ScheduleSnapshotRefresh()
            return false
        }
    }

    FormatEntryDetails(entry) {
        lines := []
        lines.Push(Tr("事件：{1}", this.GetEventLabel(entry.Event)))
        lines.Push(Tr("类别：{1}", this.GetCategoryLabel(entry.Category)))
        lines.Push(Tr("时间：{1}", entry.Timestamp))
        lines.Push("运行计时：" entry.Tick " 毫秒")
        if entry.Source != ""
            lines.Push(Tr("来源：{1}", this.GetSourceLabel(entry.Source)))
        if entry.RuleId != "" {
            lines.Push("规则：" this.GetRuleDisplay(entry.RuleId))
            lines.Push(Tr("名称") "：" entry.RuleId)
        }
        if entry.Outcome != ""
            lines.Push(Tr("结果：{1}",
                this.GetOutcomeLabel(entry.Outcome)))
        if entry.Detail != ""
            lines.Push(Tr("详情：{1}", this.GetDetailLabel(entry.Detail)))
        if Type(entry.Data) == "Map" && entry.Data.Count {
            if entry.Data.Has("identity")
                this.AppendInputIdentityDetails(lines, entry.Data)
            lines.Push("")
            lines.Push("原始数据（JSON）：")
            lines.Push(JsonCodec.Stringify(entry.Data, true, true))
        }
        return this.JoinLines(lines)
    }

    AppendInputIdentityDetails(lines, unifiedEvent) {
        identity := unifiedEvent["identity"]
        lines.Push("")
        lines.Push(Tr("按键名称：{1}", identity["name"]))
        lines.Push("输入类型：" this.GetInputKindLabel(identity["kind"]))
        lines.Push("VK: " (identity["vk_hex"] == "" ? "--"
            : "0x" identity["vk_hex"]))
        lines.Push("SC: " (identity["sc_hex"] == "" ? "---"
            : "0x" identity["sc_hex"]))
        lines.Push("扩展键："
            (identity["extended"].Value ? "是" : "否"))
        if identity["device_id"] != ""
            lines.Push("设备编号：" identity["device_id"])
        if identity["device_handle"] != ""
            lines.Push("设备句柄：" identity["device_handle"])
        if identity["usage_page"] || identity["usage"]
            lines.Push(Format("HID 用法：0x{:04X} / 0x{:04X}",
                identity["usage_page"], identity["usage"]))
        lines.Push("阶段：" this.GetOutcomeLabel(unifiedEvent["phase"]))
        lines.Push("重复输入："
            (unifiedEvent["repeat"].Value ? "是" : "否"))
        lines.Push("注入输入："
            (unifiedEvent["injected"].Value ? "是" : "否"))
        lines.Push("输入来源：" this.GetInputOriginLabel(
            unifiedEvent["origin"]))
        lines.Push("高精度计时：" unifiedEvent["qpc"] " / "
            unifiedEvent["qpc_frequency"] " Hz")
    }

    RefreshRuleDisplays() {
        if !this.App.HasOwnProp("Repository")
                || !IsObject(this.App.Repository)
            return false
        try mappings := this.App.Repository.Load()
        catch
            return false
        for mapping in mappings {
            this.RuleDisplays[String(mapping.Id)] := {
                Source: String(mapping.Source),
                Target: String(mapping.Target),
                Name: String(mapping.Id),
                Display: this.BuildRuleDisplay(mapping)
            }
        }
        return true
    }

    BuildRuleDisplay(mapping) {
        source := Trim(String(mapping.Source))
        target := Trim(String(mapping.Target))
        if source != "" && target != ""
            return source " → " target
        if source != ""
            return source
        if target != ""
            return target
        name := Trim(String(mapping.Id))
        return name != "" ? name : "未知规则"
    }

    FormatSourceAndRule(entry) {
        source := this.GetSourceLabel(entry.Source)
        if entry.RuleId == ""
            return source
        ruleKey := String(entry.RuleId)
        if !this.RuleDisplays.Has(ruleKey)
            return source != "" ? source : "未知规则"
        rule := this.RuleDisplays[ruleKey]
        if source == "" || StrLower(source) == StrLower(rule.Source)
            return rule.Display
        return source " · " rule.Display
    }

    GetRuleDisplay(ruleId) {
        ruleKey := String(ruleId)
        return this.RuleDisplays.Has(ruleKey)
            ? this.RuleDisplays[ruleKey].Display : "未知规则"
    }

    GetEventLabel(eventName) {
        eventKey := StrLower(Trim(String(eventName)))
        return EventViewerWindow.EventLabels.Has(eventKey)
            ? EventViewerWindow.EventLabels[eventKey] : "其他事件"
    }

    GetOutcomeLabel(outcome) {
        outcomeText := Trim(String(outcome))
        if outcomeText == ""
            return ""
        outcomeKey := StrLower(outcomeText)
        return EventViewerWindow.OutcomeLabels.Has(outcomeKey)
            ? EventViewerWindow.OutcomeLabels[outcomeKey] : "其他结果"
    }

    GetDetailLabel(detail) {
        detailText := String(detail)
        if detailText == ""
            return ""
        detailKey := Trim(detailText)
        if EventViewerWindow.DetailLabels.Has(detailKey)
            return EventViewerWindow.DetailLabels[detailKey]
        if SubStr(detailKey, 1, 8) == "negated_" {
            originalReason := SubStr(detailKey, 9)
            if EventViewerWindow.DetailLabels.Has(originalReason)
                return "取反后："
                    . EventViewerWindow.DetailLabels[originalReason]
        }
        if RegExMatch(detailKey, "^[a-z][a-z0-9_]*$")
            return "其他详情"
        return detailText
    }

    GetSourceLabel(source) {
        sourceText := String(source)
        switch StrLower(sourceText) {
            case "source": return "来源键"
            case "target": return "目标键"
            default: return sourceText
        }
    }

    GetInputKindLabel(kind) {
        switch StrLower(String(kind)) {
            case "keyboard": return "键盘"
            case "mouse": return "鼠标"
            case "app-command": return "应用命令"
            default: return "其他输入"
        }
    }

    GetInputOriginLabel(origin) {
        switch StrLower(String(origin)) {
            case "raw-input": return "原始输入"
            case "raw-input-device": return "原始输入设备"
            case "hook": return "输入钩子"
            case "synthetic": return "模拟输入"
            default: return "其他来源"
        }
    }

    JoinLines(lines) {
        result := ""
        for index, line in lines
            result .= (index > 1 ? "`r`n" : "") line
        return result
    }

    ScrollToLatest(row := 0) {
        if this.Disposed || !this.App.Settings.EventViewerAutoScroll
                || this.ListHeader.HasActiveSort()
            return false
        if !row
            row := this.List.GetCount()
        if row < 1
            return false
        if IsObject(this.CellTooltip)
            this.CellTooltip.Hide()
        this.List.Modify(row, "Vis")
        return true
    }

    static FormatLocalTimestamp(timestamp) {
        timestamp := String(timestamp)
        if !RegExMatch(timestamp,
                "^(\d{4})-(\d{2})-(\d{2})T(\d{2}):(\d{2}):(\d{2})\.(\d{3})Z$",
                &parts)
            return SubStr(timestamp, 12, 12)
        utcTime := Buffer(16, 0)
        localTime := Buffer(16, 0)
        NumPut("UShort", Integer(parts[1]), utcTime, 0)
        NumPut("UShort", Integer(parts[2]), utcTime, 2)
        NumPut("UShort", Integer(parts[3]), utcTime, 6)
        NumPut("UShort", Integer(parts[4]), utcTime, 8)
        NumPut("UShort", Integer(parts[5]), utcTime, 10)
        NumPut("UShort", Integer(parts[6]), utcTime, 12)
        NumPut("UShort", Integer(parts[7]), utcTime, 14)
        converted := false
        try converted := DllCall(
            "kernel32\SystemTimeToTzSpecificLocalTimeEx",
            "Ptr", 0, "Ptr", utcTime, "Ptr", localTime, "Int")
        if !converted {
            try converted := DllCall(
                "kernel32\SystemTimeToTzSpecificLocalTime",
                "Ptr", 0, "Ptr", utcTime, "Ptr", localTime, "Int")
        }
        if !converted
            return SubStr(timestamp, 12, 12)
        return Format("{:02}:{:02}:{:02}.{:03}",
            NumGet(localTime, 8, "UShort"),
            NumGet(localTime, 10, "UShort"),
            NumGet(localTime, 12, "UShort"),
            NumGet(localTime, 14, "UShort"))
    }

    GetCategoryLabel(category) {
        switch category {
            case "input": return Tr("输入")
            case "runtime": return Tr("运行时")
            case "repository": return Tr("仓储")
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
        previousCritical := A_IsCritical
        Critical("On")
        try {
            this.CancelPendingSort()
            this.CancelPendingSnapshotRefresh()
            if IsObject(this.CellTooltip)
                this.CellTooltip.Hide()
            this.Trace.Clear()
            this.List.Delete()
            this.SequenceItemIds.Clear()
            this.ItemIdSequences.Clear()
            this.EntriesBySequence.Clear()
            this.ClearDetails()
            this.UpdateStatus()
        } finally Critical(previousCritical ? previousCritical : "Off")
    }

    ChooseExport(*) {
        suggested := A_Desktop "\key-mouse-remapper-assistant-events-"
            . FormatTime(, "yyyyMMdd-HHmmss") ".jsonl"
        filePath := FileSelect("S16", suggested, Tr("导出事件"),
            "JSON Lines (*.jsonl)")
        return filePath == "" ? false : this.ExportTo(filePath)
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
        if minMax == -1 || this.Disposed || width <= 0 || height <= 0
            return
        layoutRound := AtomicControlLayout.BeginRound(this.Gui)
        if !IsObject(layoutRound)
            return false
        listWidth := Max(200, width - 24)
        statusY := height - 34
        detailHeight := EventViewerWindow.DetailEditHeight
        detailEditY := statusY - detailHeight - 10
        detailLabelY := detailEditY - 24
        listHeight := Max(180, detailLabelY - 88)
        widths := this.CalculateColumnWidths(listWidth)
        entries := [
            {Control: this.List, X: 12, Y: 78,
                Width: listWidth, Height: listHeight},
            {Control: this.DetailLabel, X: 12, Y: detailLabelY,
                Width: listWidth, Height: 22},
            {Control: this.DetailEdit, X: 12, Y: detailEditY,
                Width: listWidth, Height: detailHeight},
            {Control: this.Status, X: 12, Y: statusY,
                Width: listWidth, Height: 24}
        ]
        for entry in this.ListHeader.BuildLayoutEntries(12, 50, widths,
                listWidth)
            entries.Push(entry)
        ; Keep the native ListView surface closed while its outer rectangle,
        ; pseudo-header and columns are committed as one resize transaction.
        signature := layoutRound.Dpi "|" width "|" height "|" listWidth "|"
            . detailEditY "|" detailLabelY "|" statusY "|"
            . this.JoinColumnWidths(widths)
        listResizeSuspended := (signature != this.LastLayoutSignature
            || this.HasPendingColumnWidths(widths))
            ? this.SuspendListResizeRedraw() : false
        try {
            result := AtomicControlLayout.Apply(this.Gui, entries, {
                ParentColor: UiThemeService.GetPalette().Window,
                ClearMargin: 2, Round: layoutRound
            })
            this.LastLayoutResult := result
            if result.Status != AtomicControlLayout.Applied
                    && result.Status != AtomicControlLayout.Unchanged
                return false
            this.ApplyColumnWidths(widths, false)
            this.LastLayoutSignature := signature
            return result
        } finally this.ResumeListResizeRedraw(listResizeSuspended)
    }

    SuspendListResizeRedraw() {
        return AtomicControlRedrawTransaction.Begin([this.List])
    }

    ResumeListResizeRedraw(transaction) {
        return AtomicControlRedrawTransaction.End(transaction)
    }

    JoinColumnWidths(widths) {
        value := ""
        for width in widths
            value .= (value == "" ? "" : ",") String(width)
        return value
    }

    HasPendingColumnWidths(widths) {
        for index, columnWidth in widths {
            if index > this.AppliedColumnWidths.Length
                    || this.AppliedColumnWidths[index] != columnWidth
                return true
        }
        return false
    }

    ConfigureColumns(width) {
        widths := this.CalculateColumnWidths(width)
        this.ApplyColumnWidths(widths)
        return widths
    }

    CalculateColumnWidths(width) {
        timeWidth := 106
        categoryWidth := 82
        eventWidth := EventViewerWindow.EventColumnWidth
        sourceWidth := Max(280, Floor(width * 0.32))
        outcomeWidth := 100
        detailWidth := Max(180, width - timeWidth - categoryWidth
            - eventWidth - sourceWidth - outcomeWidth - 4)
        return [timeWidth, categoryWidth, eventWidth, sourceWidth,
            outcomeWidth, detailWidth]
    }

    ApplyColumnWidths(widths, manageRedraw := true) {
        pending := []
        for index, columnWidth in widths {
            if index > this.AppliedColumnWidths.Length
                    || this.AppliedColumnWidths[index] != columnWidth
                pending.Push({Index: index, Width: columnWidth})
        }
        if !pending.Length
            return false
        if manageRedraw
            this.List.Opt("-Redraw")
        try {
            for item in pending {
                this.List.ModifyCol(item.Index, item.Width)
                while this.AppliedColumnWidths.Length < item.Index
                    this.AppliedColumnWidths.Push(0)
                this.AppliedColumnWidths[item.Index] := item.Width
            }
        } finally {
            if manageRedraw
                this.List.Opt("+Redraw")
        }
        if manageRedraw
            DllCall("user32\RedrawWindow", "Ptr", this.List.Hwnd,
                "Ptr", 0, "Ptr", 0, "UInt",
                AtomicControlLayout.RdwRefreshNoErase,
                "Int")
        return true
    }

    ApplyAppearance() {
        if this.Disposed
            return false
        BeginStableWindowUpdate(this.Gui.Hwnd)
        try {
        colors := UiThemeService.GetPalette()
        fontName := LocalizationService.GetUiFontName()
        systemFont := LocalizationService.GetLanguageSystemUiFontName()
        this.Gui.Title := Tr("事件查看")
        this.Gui.BackColor := colors.Window
        this.Interactions.SetParentColor(colors.Window)
        if IsObject(this.CellTooltip)
            this.CellTooltip.InvalidateTheme()
        this.FilterLabel.Text := Tr("筛选：")
        this.FilterLabel.Opt("c" colors.Muted)
        selectedFilter := this.FilterDropDown.Value
        UnregisterDarkComboBoxTheme(this.FilterDropDown.Hwnd)
        this.FilterDropDown.Delete()
        this.FilterDropDown.Add(AddComboBoxDisplayPadding([
            Tr("规则运行"), Tr("输入事件"), Tr("规则仓储"),
            Tr("系统事件"), Tr("全部事件")]))
        this.FilterDropDown.Value := selectedFilter
        this.HeaderLabels := [Tr("时间"), Tr("类别"), Tr("事件"),
            Tr("来源 / 规则"), Tr("结果"), Tr("详情")]
        this.ListHeader.SetLabels(this.HeaderLabels)
        this.ListHeader.ApplyAppearance(colors.Toolbar, colors.Muted,
            systemFont, 9)
        this.List.Opt("Background" colors.Surface " c" colors.Text)
        this.List.SetFont("s10 c" colors.Text, fontName)
        this.DetailLabel.Text := Tr("事件详情")
        this.DetailLabel.Opt("Background" colors.Window " c" colors.Muted)
        this.DetailEdit.Opt("Background" colors.Input " c" colors.Text)
        this.DetailEdit.SetFont("s10", fontName)
        this.Status.Opt("Background" colors.Window " c" colors.Muted)
        this.Interactions.SetTextNoErase(this.ClearButton, Tr("清空"))
        this.Interactions.SetTextNoErase(this.ExportButton, Tr("导出事件"))
        this.Interactions.SetTextNoErase(this.RawObservationButton,
            this.RawObservationActive ? Tr("退出观察") : Tr("原始观察"))
        this.Interactions.SetButtonAppearance(this.ClearButton,
            colors.Toolbar, colors.ToolbarText, true)
        this.Interactions.SetButtonAppearance(this.ExportButton,
            colors.Primary, colors.ButtonText, true)
        this.Interactions.SetButtonAppearance(this.RawObservationButton,
            this.RawObservationActive ? colors.Pause : colors.Toolbar,
            this.RawObservationActive ? colors.ButtonText
                : colors.ToolbarText, true)
        this.Interactions.SetTextNoErase(this.PauseButton,
            this.Paused ? Tr("恢复刷新") : Tr("暂停刷新"))
        this.Interactions.SetButtonAppearance(this.PauseButton,
            this.Paused ? colors.Add : colors.Pause,
            colors.ButtonText, true)
        this.ApplyCommandIcons()
        for button in [this.PauseButton, this.ClearButton, this.ExportButton,
                this.RawObservationButton]
            button.SetFont("s10 bold", systemFont)
        if this.Paused {
            this.RefreshVisibleEntryLocalization()
            this.UpdateStatus()
        } else
            this.LoadSnapshot()
        this.ApplyNativeThemes()
        } finally EndStableWindowUpdate(this.Gui.Hwnd, true)
        return true
    }

    RequestClose(*) => this.Dispose()

    Dispose(*) {
        if this.Disposed
            return
        this.Disposed := true
        cleanup := CleanupCollector("事件查看")
        cleanup.Run("停止排序计时器",
            () => this.CancelPendingSort())
        cleanup.Run("停止刷新计时器",
            () => this.CancelPendingSnapshotRefresh())
        if this.RawObservationActive {
            if cleanup.Run("停止原始输入观察",
                    () => this.App.EndRawObservation())
                this.RawObservationActive := false
        }
        if this.SubscriptionId
            if cleanup.Run("取消事件订阅",
                () => this.Trace.Unsubscribe(this.SubscriptionId))
                this.SubscriptionId := 0
        closeContext := ""
        if this.OwnerLease {
            try {
                closeContext := WindowHierarchy.Release(this.OwnerLease)
                this.OwnerLease := ""
            } catch as ownerError {
                cleanup.Failures.Push("释放父窗口关系：" ownerError.Message)
            }
        }
        if IsObject(this.CellTooltip)
                && cleanup.Run("释放单元格提示",
                    () => this.CellTooltip.Dispose())
            this.CellTooltip := ""
        if IsObject(this.ListSelection)
                && cleanup.Run("释放列表选择器",
                    () => this.ListSelection.Dispose())
            this.ListSelection := ""
        if this.HasOwnProp("ListHeader") && IsObject(this.ListHeader)
                && cleanup.Run("释放列表表头",
                    () => this.ListHeader.Dispose())
            this.ListHeader := ""
        if IsObject(this.Interactions)
                && cleanup.Run("释放交互服务",
                    () => this.Interactions.Dispose())
            this.Interactions := ""
        if this.HasOwnProp("FilterDropDown")
            cleanup.Run("注销筛选框主题", () =>
                UnregisterDarkComboBoxTheme(this.FilterDropDown.Hwnd))
        if IsObject(this.Gui)
                && cleanup.Run("销毁窗口", () => this.Gui.Destroy())
            this.Gui := ""
        if cleanup.Run("释放窗口图标",
                () => ReleaseApplicationWindowIcons(this.IconHandles))
            this.IconHandles := []
        if !this.SnapshotRefreshPending
            this.SnapshotRefreshTimer := ""
        if !this.SortRefreshPending
            this.SortRefreshTimer := ""
        cleanup.Run("通知父窗口",
            () => this.OwnerWindow.OnEventViewerClosed(this))
        cleanup.Run("恢复父窗口",
            () => WindowHierarchy.CompleteClose(closeContext))
        cleanup.Complete()
        return true
    }
}
