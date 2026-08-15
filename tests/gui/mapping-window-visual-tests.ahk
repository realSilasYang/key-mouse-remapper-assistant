#Requires AutoHotkey v2.0 64-bit
#SingleInstance Off
#Warn All, StdOut

#Include ..\..\src\Localization\EnglishStrings.ahk
#Include ..\..\src\Localization\TraditionalHongKongStrings.ahk
#Include ..\..\src\Localization\TraditionalTaiwanStrings.ahk
#Include ..\..\src\Localization\JapaneseStrings.ahk
#Include ..\..\src\Localization\VietnameseStrings.ahk
#Include ..\..\src\Localization\KoreanStrings.ahk
#Include ..\..\src\Localization\SpanishStrings.ahk
#Include ..\..\src\Localization\FrenchStrings.ahk
#Include ..\..\src\Localization\PortugueseBrazilStrings.ahk
#Include ..\..\src\Localization\RussianStrings.ahk
#Include ..\..\src\Localization\GermanStrings.ahk
#Include ..\..\src\Localization\ItalianStrings.ahk
#Include ..\..\src\Localization\LocalizationService.ahk
#Include ..\..\src\UI\UiThemeService.ahk
#Include ..\..\src\UI\AhkV2Lexer.ahk
#Include ..\..\src\Core\BoundedFileReader.ahk
#Include ..\..\src\Core\JsonCodec.ahk
#Include ..\..\src\Core\Sha256.ahk
#Include ..\..\src\Core\CrossProcessWriteLock.ahk
#Include ..\..\src\Core\RuleSpec.ahk
#Include ..\..\src\Core\ScriptRuleSpec.ahk
#Include ..\..\src\Core\RuleCompiler.ahk
#Include ..\..\src\Core\ScriptRuleCompiler.ahk
#Include ..\..\src\Core\MappingCodeRepository.ahk
#Include ..\..\src\Platform\Win32.ahk
#Include ..\..\src\Platform\WindowHierarchy.ahk
#Include ..\..\src\UI\ThemeHelpers.ahk
#Include ..\..\src\UI\AtomicControlLayout.ahk
class SystemIntegrationService {
    static ApplicationUserModelId := "realSilasYang.KeyMouseRemapperAssistant"
}
#Include ..\..\src\UI\ApplicationIcon.ahk
#Include ..\..\src\UI\CleanupCollector.ahk
#Include ..\..\src\UI\SvgRenderLibrary.ahk
#Include ..\..\src\UI\RoundedButtonPainter.ahk
#Include ..\..\src\UI\ControlAccessibilityService.ahk
#Include ..\..\app\Windows\DarkTooltipWindow.ahk
#Include ..\..\src\UI\MappingUiInteractions.ahk
#Include ..\..\app\UI\DarkMessageBox.ahk
#Include ..\..\src\UI\ListViewPseudoHeader.ahk
#Include ..\..\app\UI\ListViewSelectionPresenter.ahk
#Include ..\..\app\Windows\ListCellTooltipWindow.ahk
#Include ..\..\app\Windows\MappingContextPopupWindow.ahk
#Include ..\..\app\Windows\MappingBlockEditor.ahk
#Include ..\..\app\Windows\MappingWindow.ahk

mappingWindowVisualExitCode := RunMappingWindowVisualTests()
ExitApp(IsNumber(mappingWindowVisualExitCode)
    ? mappingWindowVisualExitCode : 0)

RunMappingWindowVisualTests() {
    window := ""
    exitCode := 0
    try {
    LocalizationService.Configure("zh-CN", "")
    UiThemeService.Configure("dark")
    app := MappingWindowVisualTestApp()
    window := MappingWindowVisualProbe(app)
    app.Window := window
    ; Screen-pixel verification is only meaningful while no foreground window
    ; can cover the non-activating test window.
    window.Gui.Opt("+AlwaysOnTop")
    window.LoadRows([
        {Id: "visual-test", Source: "F24", Target: "F23",
            Scope: "全局", Enabled: true},
        {Id: "visual-test-2", Source: "F22", Target: "F21",
            Scope: "全局", Enabled: true}
    ])
    initialMaximum := window.GetWorkAreaMaximumClientSize()
    restoredInitialWidth := Min(window.MinClientWidth + 20,
        initialMaximum.Width)
    restoredInitialHeight := Min(680, initialMaximum.Height)
    window.SetInitialClientSize(restoredInitialWidth, restoredInitialHeight)
    window.ShowWithOptions("x40 y40")
    Sleep(150)
    MappingWindowVisualAssert(!DllCall("user32\IsIconic", "Ptr",
            window.Gui.Hwnd, "Int"),
        "The first visible main window started minimized.")
    window.Gui.GetClientPos(, , &initialWidth, &initialHeight)
    MappingWindowVisualAssert(initialWidth == restoredInitialWidth
            && initialHeight == restoredInitialHeight,
        "The first show ignored the restored custom client size.")
    MappingWindowVisualAssert(DllCall("user32\GetFocus", "Ptr")
            == window.Status.Hwnd,
        "The first visible main window automatically focused an input control.")
    AssertMainStatusCaretHidden(window, "the first visible main window")
    initialNameState := window.Interactions.Controls[window.NameEdit.Hwnd]
    initialNameStyle := DllCall("user32\GetWindowLongW", "Ptr",
        window.NameEdit.Hwnd, "Int", -16, "Int")
    MappingWindowVisualAssert(initialNameState.FocusCount == 0
            && !(initialNameStyle & 0x00010000),
        Format("The mapping name input received focus while the main window opened: count={1}, style={2:X}.",
            initialNameState.FocusCount, initialNameStyle))
    if EnvGet("MAPPING_WINDOW_EDITOR_ONLY") == "1" {
        ValidateMappingEditorCleanup(window)
        if EnvGet("MAPPING_WINDOW_UNDO_ONLY") == "1"
            return
        if EnvGet("MAPPING_WINDOW_SCRIPT_SAVE_ONLY") == "1" {
            ValidateScriptEditorSaveSnapshot(window)
            return
        }
        ValidateNewMappingEditorModes(window)
        ValidateMappingEditorTemplatePresentation(window)
        return
    }
    initialNameFormatRect := Buffer(16, 0)
    SendMessage(0x00B2, 0, initialNameFormatRect.Ptr, ,
        window.NameEdit.Hwnd)
    initialNameClientRect := Buffer(16, 0)
    MappingWindowVisualAssert(DllCall("user32\GetClientRect", "Ptr",
            window.NameEdit.Hwnd, "Ptr", initialNameClientRect, "Int"),
        "The initial mapping name viewport could not be inspected.")
    initialNameClientWidth := NumGet(initialNameClientRect, 8, "Int")
    initialNameClientHeight := NumGet(initialNameClientRect, 12, "Int")
    initialNameViewportHeight := NumGet(initialNameFormatRect, 12, "Int")
        - NumGet(initialNameFormatRect, 4, "Int")
    MappingWindowVisualAssert(
            NumGet(initialNameFormatRect, 0, "Int")
                == window.NameInputMetrics.HorizontalPaddingPx
            && initialNameClientWidth
                - NumGet(initialNameFormatRect, 8, "Int")
                    == window.NameInputMetrics.HorizontalPaddingPx
            && NumGet(initialNameFormatRect, 4, "Int")
                == window.NameInputMetrics.VerticalPaddingPx
            && initialNameClientHeight
                - NumGet(initialNameFormatRect, 12, "Int")
                    == window.NameInputMetrics.VerticalPaddingPx
            && initialNameViewportHeight
                == window.NameInputMetrics.LineHeightPx
                    * MappingWindow.NameInputVisibleLines,
        "The first visible mapping-name viewport lost its fixed padding or two-line height.")
    initialNameLineHeight := window.Interactions.GetTextInputCaretHeight(
        window.NameEdit.Hwnd, initialNameClientHeight)
    DllCall("user32\SetFocus", "Ptr", window.NameEdit.Hwnd, "Ptr")
    initialCaretPoint := Buffer(8, 0)
    MappingWindowVisualAssert(DllCall("user32\GetCaretPos", "Ptr",
            initialCaretPoint, "Int"),
        "The mapping name input did not create its first caret.")
    initialCaretInfo := Buffer(72, 0)
    NumPut("UInt", initialCaretInfo.Size, initialCaretInfo, 0)
    mappingGuiThreadId := DllCall("user32\GetWindowThreadProcessId",
        "Ptr", window.Gui.Hwnd, "Ptr", 0, "UInt")
    MappingWindowVisualAssert(DllCall("user32\GetGUIThreadInfo", "UInt",
            mappingGuiThreadId, "Ptr", initialCaretInfo, "Int"),
        "The mapping name input caret geometry could not be inspected.")
    MappingWindowVisualAssert(NumGet(initialCaretPoint, 0, "Int")
            == NumGet(initialNameFormatRect, 0, "Int")
            && NumGet(initialCaretPoint, 4, "Int")
                == NumGet(initialNameFormatRect, 4, "Int")
            && NumGet(initialCaretInfo, 48, "Ptr")
                == window.NameEdit.Hwnd
             && NumGet(initialCaretInfo, 68, "Int")
                 - NumGet(initialCaretInfo, 60, "Int")
                    == initialNameLineHeight,
        Format("The first mapping-name caret used incorrect geometry: x={1}, y={2}, left={3}, top={4}, height={5}, line={6}.",
            NumGet(initialCaretPoint, 0, "Int"),
            NumGet(initialCaretPoint, 4, "Int"),
            NumGet(initialNameFormatRect, 0, "Int"),
            NumGet(initialNameFormatRect, 4, "Int"),
            NumGet(initialCaretInfo, 68, "Int")
                - NumGet(initialCaretInfo, 60, "Int"),
            initialNameLineHeight))
    MappingWindowVisualAssert(window.ClearAutomaticControlFocus()
            && DllCall("user32\GetFocus", "Ptr") == window.Status.Hwnd,
        "The main window could not restore its neutral focus target.")
    Sleep(10)
    AssertMainStatusCaretHidden(window, "restored neutral focus")
    enabledStatusIconIndex := window.ListStatusIconIndices.Has(1)
        ? window.ListStatusIconIndices[1] : 0
    statusIconCellWidth := 0
    statusIconCellHeight := 0
    MappingWindowVisualAssert(DllCall("comctl32\ImageList_GetIconSize",
            "Ptr", window.ListRowImageList, "Int*", &statusIconCellWidth,
            "Int*", &statusIconCellHeight, "Int"),
        "The mapping status image-list size could not be inspected.")
    listDpi := DllCall("user32\GetDpiForWindow", "Ptr", window.List.Hwnd,
        "UInt")
    if !listDpi
        listDpi := 96
    statusCellRect := window.GetListSubItemRect(1,
        MappingWindow.StatusColumn)
    statusColumnWidthPixels := SendMessage(Win32.LVM_GETCOLUMNWIDTH,
        MappingWindow.StatusColumn - 1, 0, , window.List.Hwnd)
    MappingWindowVisualAssert(WinGetClass("ahk_id " window.Status.Hwnd)
            == "Edit"
            && window.Interactions.TextInputTargets.Has(window.Status.Hwnd)
            && window.List.GetText(1, MappingWindow.StatusColumn)
                == Tr("启用")
            && enabledStatusIconIndex > 0
            && GetMappingStatusIconIndex(window, 1) == 0
            && GetMappingStatusIconIndex(window, 2) == 0
            && window.ListStatusIconIndices.Has(1)
            && window.ListStatusIconIndices.Has(0)
            && window.ListStatusIconIndices[1]
                != window.ListStatusIconIndices[0]
            && GetMappingListIconIndex(window, 1,
                MappingWindow.NameColumn) == 0
            && GetMappingListIconIndex(window, 2,
                MappingWindow.NameColumn) == 0
            && GetMappingListIconIndex(window, 1,
                MappingWindow.SequenceColumn) == 0
            && GetMappingListIconIndex(window, 2,
                MappingWindow.SequenceColumn) == 0
            && statusIconCellWidth == Max(20, Round(20 * listDpi / 96))
            && IsObject(statusCellRect)
            && statusCellRect.Right - statusCellRect.Left
                == statusColumnWidthPixels,
        "The main status is not selectable or the enabled rule icon is missing.")
    AssertCenteredMappingStatusContent(window, 1, statusCellRect)
    AssertUniformMappingListTextInsets(window, 1)
    AssertMappingNameStartsAfterSequence(window, 1)
    window.List.Modify(1, "Select Focus Vis")
    window.ListSelection.RefreshItem(1)
    Sleep(20)
    window.ShowCallCount := 0
    window.ActivationSelectionRefreshCount := 0
    window.ActivationRedrawSuspendCount := 0
    window.ActivationRedrawResumeCount := 0
    MappingWindowVisualAssert(window.Activate(),
        "The tray activation path did not reactivate the visible main window.")
    Sleep(20)
    MappingWindowVisualAssert(window.ShowCallCount == 0,
        "Tray activation presented an already visible main window again.")
    MappingWindowVisualAssert(window.ActivationSelectionRefreshCount == 1,
        "Tray activation did not refresh the selected row after activation.")
    MappingWindowVisualAssert(window.ActivationRedrawSuspendCount == 1
            && window.ActivationRedrawResumeCount == 1,
        "Tray activation exposed the native ListView selection repaint.")
    reactivatedStatusRect := window.GetListSubItemRect(1,
        MappingWindow.StatusColumn)
    AssertCenteredMappingStatusContent(window, 1, reactivatedStatusRect)
    AssertRoundedMappingListSelection(window, 1)
    window.List.Modify(0, "-Select")
    MappingWindowVisualAssert(window.UpdateMappingRow({
            Id: "visual-test", Source: "F24", Target: "F23",
            Scope: "全局", Enabled: false}),
        "The status icon probe could not update the first rule.")
    pausedStatusIconIndex := window.ListStatusIconIndices.Has(0)
        ? window.ListStatusIconIndices[0] : 0
    MappingWindowVisualAssert(window.List.GetText(1,
            MappingWindow.StatusColumn) == Tr("暂停")
            && pausedStatusIconIndex > 0
            && pausedStatusIconIndex != enabledStatusIconIndex
            && GetMappingStatusIconIndex(window, 1) == 0
            && window.ListStatusIconIndices.Has(0)
            && window.ListStatusIconIndices[0]
                != window.ListStatusIconIndices[1]
            && GetMappingListIconIndex(window, 1,
                MappingWindow.NameColumn) == 0
            && GetMappingListIconIndex(window, 1,
                MappingWindow.SequenceColumn) == 0,
        "The paused rule did not receive a distinct status icon.")
    MappingWindowVisualAssert(window.UpdateMappingRow({
            Id: "visual-test", Source: "F24", Target: "F23",
            Scope: "全局", Enabled: true}),
        "The status icon probe could not restore the first rule.")
    MappingWindowVisualAssert(window.UpdateMappingRow({
            Id: "visual-test-renamed", Source: "F24", Target: "F23",
            Scope: "全局", Enabled: true}, "visual-test")
            && window.FindMappingRow("visual-test") == 0
            && window.FindMappingRow("visual-test-renamed") == 1,
        "Renaming a rule did not replace the row identified by its previous name.")
    MappingWindowVisualAssert(window.UpdateMappingRow({
            Id: "visual-test", Source: "F24", Target: "F23",
            Scope: "全局", Enabled: true}, "visual-test-renamed")
            && window.FindMappingRow("visual-test") == 1,
        "The renamed-row probe could not restore the visual fixture.")
    window.SetStatus("mouse-selectable main status text with enough content")
    SendMessage(Win32.EM_SETSEL, 0, 4, , window.Status.Hwnd)
    selectionStart := Buffer(4, 0)
    selectionEnd := Buffer(4, 0)
    SendMessage(Win32.EM_GETSEL, selectionStart.Ptr, selectionEnd.Ptr, ,
        window.Status.Hwnd)
    MappingWindowVisualAssert(NumGet(selectionStart, 0, "UInt") == 0
            && NumGet(selectionEnd, 0, "UInt") == 4,
        "The caret-free main status could not retain a text selection.")
    AssertMainStatusCaretHidden(window, "selected main status text")
    MappingWindowAssertMouseSelectableEdit(window.Status,
        "The caret-free main status", false)
    Sleep(10)
    AssertMainStatusCaretHidden(window, "mouse-selected main status text")
    AssertListCellTooltipUsesContentWidth(window)
    window.SetStatus(Tr("已保存，正在后台应用…"))
    MappingWindowVisualAssert(window.GetStatusLayout(initialWidth).Extra == 0,
        "The deferred-save progress text expanded the main-window status area.")
    persistentError := "persistent copyable error`nsecond detail line"
    window.SetStatus(persistentError, true)
    window.List.Modify(1, "Select Focus Vis")
    window.RefreshSelectionState()
    MappingWindowVisualAssert(window.StatusIsError
            && window.Status.Text == persistentError,
        "Selecting a rule replaced a persistent main-window error.")
    window.List.Modify(0, "-Select")
    window.SetStatus(app.GetSummaryText())
    for columnSpec in window.ListHeader.Columns
        MappingWindowVisualAssert(StrLower(columnSpec.HeaderAlign) == "center",
            "Every pseudo-header cell must be center-aligned.")
    sequenceAlignment := ReadListViewColumnAlignment(window.List,
        MappingWindow.SequenceColumn)
    nameAlignment := ReadListViewColumnAlignment(window.List,
        MappingWindow.NameColumn)
    sourceAlignment := ReadListViewColumnAlignment(window.List,
        MappingWindow.SourceColumn)
    targetAlignment := ReadListViewColumnAlignment(window.List,
        MappingWindow.TargetColumn)
    scopeAlignment := ReadListViewColumnAlignment(window.List,
        MappingWindow.ScopeColumn)
    statusAlignment := ReadListViewColumnAlignment(window.List,
        MappingWindow.StatusColumn)
    MappingWindowVisualAssert(sequenceAlignment == 2
            && scopeAlignment == 2
            && statusAlignment == 0
            && nameAlignment == 0
            && sourceAlignment == 0
            && targetAlignment == 0
            && GetMappingListItemIndent(window, 1,
                MappingWindow.StatusColumn) == 0,
        Format("Sequence and scope must use native center alignment; status must use its primary-item indent to center the icon-text group (actual formats {1}/{2}/{3}/{4}/{5}/{6}).",
            sequenceAlignment, nameAlignment, sourceAlignment,
            targetAlignment, scopeAlignment, statusAlignment))
    AssertMainCommandButtonGroups(window, initialWidth)
    MappingWindowVisualCheckpoint(window, "initial")

    clientRect := Buffer(16, 0)
    MappingWindowVisualAssert(DllCall("user32\GetClientRect", "Ptr",
        window.Gui.Hwnd, "Ptr", clientRect, "Int"),
        "Could not measure the main-window client area.")
    window.DeleteButton.GetPos(&leftToolbarX, , &leftToolbarWidth)
    window.SettingsButton.GetPos(&rightToolbarX)
    toolbarGapLeft := leftToolbarX + leftToolbarWidth
    MappingWindowVisualAssert(rightToolbarX - toolbarGapLeft >= 8,
        "The main toolbar has no uncovered background sample area.")
    sampleDpi := DllCall("user32\GetDpiForWindow", "Ptr", window.Gui.Hwnd,
        "UInt")
    if !sampleDpi
        sampleDpi := 96
    sampleX := Round((toolbarGapLeft + rightToolbarX) / 2
        * sampleDpi / 96)
    sampleY := Round(25 * sampleDpi / 96)
    sampleOwner := GetMappingWindowClientPointOwner(window.Gui.Hwnd,
        sampleX, sampleY)
    clientPixel := CaptureMappingWindowOwnDcPixel(window.Gui.Hwnd,
        sampleX, sampleY)
    backgroundPixel := CaptureMappingWindowClientPixel(window.Gui.Hwnd,
        sampleX, sampleY)
    firstPresentation := window.LastFirstVisiblePresentation
    MappingWindowVisualAssert(IsObject(firstPresentation)
            && firstPresentation.Visible
            && firstPresentation.FirstVisibleCompleted
            && firstPresentation.Uncloaked
            && !(FirstVisibleWindowPresenter.GetCloakState(
                window.Gui.Hwnd) & 1),
        Format("The first visible-frame transaction did not prepare and reveal the main window. visible={1}, prepared={2}, cloakApplied={3}, uncloaked={4}, cloakState={5}.",
            IsObject(firstPresentation) ? firstPresentation.Visible : -1,
            IsObject(firstPresentation)
                ? firstPresentation.FirstVisibleCompleted : -1,
            IsObject(firstPresentation)
                ? firstPresentation.CloakApplied : -1,
            IsObject(firstPresentation) ? firstPresentation.Uncloaked : -1,
            FirstVisibleWindowPresenter.GetCloakState(window.Gui.Hwnd)))
    if VerCompare(A_OSVersion, "10.0.17763") >= 0 {
        darkTitleAttribute := VerCompare(A_OSVersion, "10.0.18985") >= 0
            ? 20 : 19
        darkTitleValue := 0
        darkTitleResult := DllCall("dwmapi\DwmGetWindowAttribute", "Ptr",
            window.Gui.Hwnd, "Int", darkTitleAttribute,
            "Int*", &darkTitleValue, "Int", 4, "Int")
        MappingWindowVisualAssert(darkTitleResult >= 0
                && darkTitleValue == (UiThemeService.IsDark() ? 1 : 0),
            Format("The first visible frame did not retain its title-bar theme. result={1}, value={2}.",
                darkTitleResult, darkTitleValue))
    }
    observedPixel := sampleOwner == window.Gui.Hwnd
        ? backgroundPixel : clientPixel
    sampleMode := sampleOwner == window.Gui.Hwnd ? "screen" : "window DC"
    MappingWindowVisualAssert(observedPixel == ColorRef(
        MappingWindow.Colors.Window),
        Format("The direct-launch first frame exposed background {1:06X}; expected {2:06X}.",
            observedPixel, ColorRef(MappingWindow.Colors.Window))
            . " Client=" NumGet(clientRect, 8, "Int") "x"
            . NumGet(clientRect, 12, "Int") ", sample=" sampleX "," sampleY
            . ", mode=" sampleMode ", owner=" sampleOwner ", target="
            . window.Gui.Hwnd)

    sourceCaptureState := window.Interactions.Controls[
        window.SourceButton.Hwnd]
    targetCaptureState := window.Interactions.Controls[
        window.TargetButton.Hwnd]
    MappingWindowVisualAssert(window.SupportButton.Text == Tr("帮助")
            && window.AboutButton.Text == Tr("关于")
            && sourceCaptureState.TooltipText == Tr("演奏你的和弦！")
            && targetCaptureState.TooltipText == Tr("演奏你的和弦！"),
        "The main toolbar labels or capture tooltips are incorrect.")

    window.DistinguishModifierSidesCheck.GetPos(&modifierCheckX,
        &modifierCheckY, &modifierCheckWidth, &modifierCheckHeight)
    window.SectionTopDivider.GetPos(, &sectionDividerY, &sectionDividerWidth,
        &sectionDividerHeight)
    MappingWindowVisualAssert(window.DistinguishModifierSidesCheck.Value == 0,
        "Modifier-side distinction must default to disabled.")
    MappingWindowVisualAssert(modifierCheckX >= 10
            && modifierCheckX + modifierCheckWidth
                <= NumGet(clientRect, 8, "Int") - 10
            && modifierCheckHeight == 24,
        "The modifier-side option is clipped or outside the new-mapping row.")
    window.Gui.GetClientPos(, , &logicalClientWidth)
    expectedModifierWidth := window.MeasureControlTextWidth(
        window.DistinguishModifierSidesCheck,
        window.DistinguishModifierSidesCheck.Text) + 22
    MappingWindowVisualAssert(Abs(modifierCheckX + modifierCheckWidth
            - (logicalClientWidth - 10)) <= 1
            && Abs(modifierCheckWidth - expectedModifierWidth) <= 1,
        "The modifier-side component is not content-sized and right-aligned.")
    MappingWindowVisualAssert(modifierCheckY - sectionDividerY
            - sectionDividerHeight >= 8,
        "The new-mapping heading does not retain its upper spacing.")
    MappingWindowVisualAssert(!(WinGetStyle("ahk_id "
            window.DistinguishModifierSidesCheck.Hwnd) & 0x0200),
        "The modifier-side checkbox was moved to the right of its label.")
    MappingWindowVisualAssert(DllCall("user32\GetFocus", "Ptr")
            != window.DistinguishModifierSidesCheck.Hwnd,
        "The modifier-side checkbox unexpectedly owns keyboard focus.")
    dividerState := window.Interactions.Controls[
        window.SectionTopDivider.Hwnd]
    MappingWindowVisualAssert(dividerState.Kind == "divider"
            && dividerState.DashWidthDip == MappingWindow.DividerDashWidth
            && dividerState.DashGapDip == MappingWindow.DividerDashGap
            && dividerState.DashHeightDip == MappingWindow.DividerDashHeight
            && !window.HasOwnProp("DashedDividerSegments"),
        "The separator was not reduced to one owner-drawn surface.")
    AssertMappingWindowDashedDivider(window,
        "The new-mapping separator was not rendered as a dashed line.")

    sidedDisplay := Tr("左侧 Ctrl") " + " Tr("右侧 Shift") " + A"
    sidedCapture := {
        RawDisplay: "LCtrl + RShift + A",
        Display: sidedDisplay,
        DetailLines: Tr("按键名称：{1}`n虚拟键码：{2}`n扫描码：{3}",
            sidedDisplay, "A2 + A1 + 41", "01D + 136 + 01E")
    }
    window.PreviewCapture("source", sidedCapture)
    MappingWindowVisualAssert(window.SourceButton.Text
            == "Ctrl + Shift + A"
            && InStr(window.SourceDetail.Text, "Ctrl + Shift + A")
            && !InStr(window.SourceDetail.Text, Tr("左侧 Ctrl"))
            && !InStr(window.SourceDetail.Text, Tr("右侧 Shift")),
        "The unchecked option exposed left/right modifier names in capture.")
    window.SourceCapture := sidedCapture
    window.TargetCapture := sidedCapture
    window.FullWindowRedrawCount := 0
    window.TargetedLayoutRedrawCount := 0
    window.DistinguishModifierSidesCheck.Value := 1
    window.OnModifierSideDisplayChanged()
    MappingWindowVisualAssert(window.SourceButton.Text
            == sidedCapture.RawDisplay
            && window.TargetButton.Text == sidedCapture.RawDisplay
            && InStr(window.SourceDetail.Text, Tr("左侧 Ctrl"))
            && window.FullWindowRedrawCount == 0
            && window.TargetedLayoutRedrawCount == 0
            && DllCall("user32\GetFocus", "Ptr")
                != window.DistinguishModifierSidesCheck.Hwnd,
        "Enabling modifier-side distinction did not restore sided names.")
    window.DistinguishModifierSidesCheck.Value := 0
    window.OnModifierSideDisplayChanged()
    MappingWindowVisualAssert(window.SourceButton.Text
            == "Ctrl + Shift + A"
            && window.TargetButton.Text == "Ctrl + Shift + A"
            && sidedCapture.RawDisplay == "LCtrl + RShift + A"
            && window.FullWindowRedrawCount == 0
            && window.TargetedLayoutRedrawCount == 0
            && DllCall("user32\GetFocus", "Ptr")
                != window.DistinguishModifierSidesCheck.Hwnd,
        "Changing the display preference mutated or failed to refresh capture data.")
    window.ClearEditor(false)

    longCaptureParts := []
    Loop 40
        longCaptureParts.Push("Key" Format("{:02}", A_Index))
    longCaptureText := MappingWindowVisualJoin(longCaptureParts, " + ")
    window.PreviewCapture("source", {
        RawDisplay: longCaptureText,
        DetailLines: "按键名称：" longCaptureText
    })
    ; Previewing can raise the window minimum and therefore completes through
    ; the same coalesced WM_SIZE layout path used during live resizing.
    Sleep(50)
    window.SourceButton.GetPos(, &sourceCaptureY, &sourceCaptureWidth,
        &sourceCaptureHeight)
    window.TargetButton.GetPos(, , , &targetCaptureHeight)
    sourceCaptureState := window.Interactions.Controls[
        window.SourceButton.Hwnd]
    measuredCaptureTextHeight := window.Interactions.Painter
        .MeasureButtonTextHeight(window.SourceButton, longCaptureText,
            sourceCaptureWidth, sourceCaptureState)
    MappingWindowVisualAssert(sourceCaptureHeight
            > MappingWindow.MinCaptureButtonHeight
            && sourceCaptureHeight == targetCaptureHeight
            && sourceCaptureHeight >= measuredCaptureTextHeight + 16,
        "A long captured chord did not wrap and grow both capture buttons.")
    window.NameInput.Background.GetPos(, &wrappedNameY, ,
        &wrappedNameHeight)
    window.NameEdit.GetPos(, &wrappedNameEditY, , &wrappedNameEditHeight)
    nameEditStyle := DllCall("user32\GetWindowLongW", "Ptr",
        window.NameEdit.Hwnd, "Int", -16, "Int")
    wrappedNameText := "自动换行规则名称 自动换行规则名称 自动换行规则名称 "
        . "自动换行规则名称 自动换行规则名称 自动换行规则名称"
    window.NameEdit.Value := wrappedNameText
    window.OnNameInputChanged()
    wrappedNameLineCount := SendMessage(0x00BA, 0, 0, ,
        window.NameEdit.Hwnd)
    nameFormatRect := Buffer(16, 0)
    SendMessage(0x00B2, 0, nameFormatRect.Ptr, , window.NameEdit.Hwnd)
    nameClientRect := Buffer(16, 0)
    DllCall("user32\GetClientRect", "Ptr", window.NameEdit.Hwnd,
        "Ptr", nameClientRect, "Int")
    nameClientWidth := NumGet(nameClientRect, 8, "Int")
    nameClientHeight := NumGet(nameClientRect, 12, "Int")
    nameLineHeight := window.Interactions.GetTextInputCaretHeight(
        window.NameEdit.Hwnd, nameClientHeight)
    nameViewportHeight := NumGet(nameFormatRect, 12, "Int")
        - NumGet(nameFormatRect, 4, "Int")
    SendMessage(0x00B6, 0, -wrappedNameLineCount, ,
        window.NameEdit.Hwnd)
    wheelDownWParam := ((-120 & 0xFFFF) << 16)
    SendMessage(Win32.WM_MOUSEWHEEL, wheelDownWParam, 0, ,
        window.NameEdit.Hwnd)
    scrolledNameFirstLine := SendMessage(0x00CE, 0, 0, ,
        window.NameEdit.Hwnd)
    MappingWindowVisualAssert((nameEditStyle & 0x0004)
            && (nameEditStyle & 0x00000040)
            && !(nameEditStyle & 0x00000080)
            && !(nameEditStyle & 0x00100000)
            && !(nameEditStyle & 0x00001000)
            && wrappedNameLineCount > 2
            && scrolledNameFirstLine > 0,
        Format("The mapping name input did not provide hidden-scrollbar multiline scrolling: style={1:X}, lines={2}, first={3}.",
            nameEditStyle, wrappedNameLineCount, scrolledNameFirstLine))
    MappingWindowVisualAssert(nameViewportHeight == nameLineHeight * 2
            && NumGet(nameFormatRect, 0, "Int")
                == window.NameInputMetrics.HorizontalPaddingPx
            && nameClientWidth - NumGet(nameFormatRect, 8, "Int")
                == window.NameInputMetrics.HorizontalPaddingPx
            && NumGet(nameFormatRect, 4, "Int")
                == window.NameInputMetrics.VerticalPaddingPx
            && nameClientHeight - NumGet(nameFormatRect, 12, "Int")
                == window.NameInputMetrics.VerticalPaddingPx,
        Format("The mapping name viewport exposed a partial third line or lost padding: viewport={1}, line={2}, top={3}, bottom={4}, client={5}.",
            nameViewportHeight, nameLineHeight,
            NumGet(nameFormatRect, 4, "Int"),
            NumGet(nameFormatRect, 12, "Int"), nameClientHeight))
    MappingWindowVisualAssert(wrappedNameHeight
            == window.NameInputHeight
            && wrappedNameEditHeight == wrappedNameHeight - 2
            && wrappedNameEditY == wrappedNameY + 1
            && wrappedNameY == sourceCaptureY
                + Floor((sourceCaptureHeight - wrappedNameHeight) / 2),
        "The mapping name input did not retain its centered two-line viewport.")
    window.NameEdit.Value := ""
    window.CancelCaptureState()

    window.BeginCapture("source")
    SendMessage(Win32.WM_LBUTTONDOWN, 1, 8 | (8 << 16), ,
        window.SourceButton.Hwnd)
    SendMessage(Win32.WM_LBUTTONUP, 0, 8 | (8 << 16), ,
        window.SourceButton.Hwnd)
    Sleep(30)
    MappingWindowVisualAssert(!app.Capture.Active
            && app.Capture.StartCount == 1
            && app.Capture.CancelCount == 1
            && !window.Interactions.PendingButtonClicks.Has(
                window.SourceButton.Hwnd),
        "Clicking a capture button while recording did not only cancel capture.")

    window.BeginCapture("target")
    window.OnEscape()
    MappingWindowVisualAssert(!app.Capture.Active
            && app.Capture.CancelCount == 2
            && DllCall("user32\IsWindowVisible", "Ptr", window.Gui.Hwnd,
                "Int"),
        "Escape cancelled recording but also hid the main window.")

    window.BeginCapture("source")
    app.Capture.Cancel()
    window.SuppressEscapeAfterCapture(5000)
    window.OnEscape()
    MappingWindowVisualAssert(!app.Capture.Active
            && app.Capture.CancelCount == 3
            && DllCall("user32\IsWindowVisible", "Ptr", window.Gui.Hwnd,
            "Int"),
        "The GUI Escape event following Raw Input cancellation hid the window.")

    ValidateMainWindowResponsiveLayout(window)
    ValidateMainWindowResizeIsolation(window)
    ValidateMainWindowAppearanceRefreshIsolation(window)
    ValidateMainWindowLightTheme(window)
    ValidateSelectionRefreshIsolation(window)

    window.DistinguishModifierSidesCheck.Value := 1
    window.SourceCapture := {Display: "LCtrl + A", RawDisplay: "LCtrl + A"}
    window.TargetCapture := {Display: "F12", RawDisplay: "F12"}
    window.NameEdit.Value := "modifier-side propagation"
    window.SaveMapping()
    MappingWindowVisualAssert(app.AddMappingCount == 1
            && app.LastMappingName == "modifier-side propagation"
            && app.LastDistinguishModifierSides,
        "Saving did not pass the modifier-side option to the application.")
    MappingWindowVisualAssert(window.DistinguishModifierSidesCheck.Value == 0,
        "Clearing the editor did not restore the modifier-side default.")

    ClickMappingWindowListRow(window.List, 1)
    Sleep(30)
    pauseState := window.Interactions.Controls[
        window.PauseResumeButton.Hwnd]
    deleteState := window.Interactions.Controls[window.DeleteButton.Hwnd]
    addState := window.Interactions.Controls[window.AddButton.Hwnd]
    MappingWindowVisualAssert(window.GetSelectedRows().Length == 1,
        "A real pointer click did not select the mapping row.")
    AssertRoundedMappingListSelection(window, 1)
    MappingWindowVisualAssert(pauseState.Normal
            == MappingWindow.Colors.Pause
            && pauseState.Current == MappingWindow.Colors.Pause
            && pauseState.Interactive
            && deleteState.Normal == MappingWindow.Colors.Delete
            && deleteState.Current == MappingWindow.Colors.Delete
            && deleteState.Interactive,
        "A real row selection did not restore active pause/delete colors.")
    AssertMappingWindowButtonPixel(window.Interactions,
        window.PauseResumeButton,
        MappingWindow.Colors.Pause,
        "The selected-row pause button remained visually disabled.")
    AssertMappingWindowButtonPixel(window.Interactions, window.DeleteButton,
        MappingWindow.Colors.Delete,
        "The selected-row delete button remained visually disabled.")

    ; Exercise the native input fallback independently of AHK's high-level
    ; ListView selection events. The production failure left the row selected
    ; while these command states remained disabled.
    window.List.OnEvent("ItemSelect", window.SelectionChangedCallback, 0)
    window.List.OnEvent("ItemFocus", window.SelectionChangedCallback, 0)
    MappingWindowVisualAssert(MappingWindow.NameColumn == 1
            && MappingWindow.StatusColumn == 2
            && MappingWindow.SequenceColumn == 5,
        "The main mapping list must show sequence before name.")
    window.List.Modify(0, "-Select")
    window.RefreshSelectionState()
    ClickMappingWindowListRow(window.List, 1)
    Sleep(30)
    MappingWindowVisualAssert(pauseState.Interactive
            && deleteState.Interactive
            && pauseState.Current == MappingWindow.Colors.Pause
            && deleteState.Current == MappingWindow.Colors.Delete,
        "The native pointer-up fallback did not synchronize selection commands.")
    window.List.OnEvent("ItemSelect", window.SelectionChangedCallback)
    window.List.OnEvent("ItemFocus", window.SelectionChangedCallback)

    ; A command validates the real ListView selection before its subclass
    ; decides whether to consume the click. This prevents stale disabled state
    ; from swallowing pause/delete operations.
    window.Interactions.SetButtonAppearance(window.PauseResumeButton,
        MappingWindow.Colors.PauseDisabled,
        MappingWindow.Colors.DisabledButtonText, false)
    window.Interactions.SetButtonAppearance(window.DeleteButton,
        MappingWindow.Colors.DeleteDisabled,
        MappingWindow.Colors.DisabledButtonText, false)
    SendMessage(0x0200, 0, 8 | (8 << 16), ,
        window.PauseResumeButton.Hwnd)
    MappingWindowVisualAssert(pauseState.Interactive
            && deleteState.Interactive
            && pauseState.Normal == MappingWindow.Colors.Pause
            && deleteState.Normal == MappingWindow.Colors.Delete,
        "Command preflight did not recover a stale disabled state.")
    MappingWindowVisualAssert(InStr(window.AddButton.Text, "➕ ") == 1
            && InStr(window.PauseResumeButton.Text, "⏸️ ") == 1
            && InStr(window.DeleteButton.Text, "🗑️ ") == 1
            && addState.LeadingTextSlotDip == 20
            && pauseState.LeadingTextSlotDip == 20
            && deleteState.LeadingTextSlotDip == 20
            && addState.TextColor == MappingWindow.Colors.ButtonText
            && !addState.HasOwnProp("ButtonImage")
            && !pauseState.HasOwnProp("ButtonImage")
            && !deleteState.HasOwnProp("ButtonImage"),
        "Main commands do not use the reference character-icon slots.")

    ClickMappingWindowButton(window.PauseResumeButton)
    MappingWindowVisualAssert(app.ToggleCount == 1,
        "The active pause button did not invoke its mapping callback.")
    MappingWindowVisualAssert(window.List.GetText(1,
            MappingWindow.StatusColumn) == Tr("暂停")
            && GetMappingStatusIconIndex(window, 1) == 0
            && window.ListStatusIconIndices.Has(0)
            && window.ListStatusIconIndices[0]
                != enabledStatusIconIndex,
        "Pausing a rule did not update its visible status text and icon.")
    ClickMappingWindowButton(window.DeleteButton)
    MappingWindowVisualAssert(app.DeleteCount == 1,
        "The active delete button did not invoke its mapping callback.")

    window.List.Modify(0, "Select")
    window.RefreshSelectionState()
    MappingWindowVisualAssert(InStr(window.PauseResumeButton.Text,
            "🔄 ") == 1,
        "A mixed multi-selection did not expose the reverse-state command.")
    window.HandleListCommand(32, 0)
    window.HandleListCommand(32, 0x40000000)
    MappingWindowVisualAssert(app.ToggleCount == 2,
        "Space repeat suppression did not execute exactly one batch toggle.")
    window.HandleListCommand(46, 0)
    window.HandleListCommand(46, 0x40000000)
    MappingWindowVisualAssert(app.DeleteCount == 2,
        "Delete repeat suppression did not execute exactly one batch delete.")
    toggleCount := app.ToggleCount
    deleteCount := app.DeleteCount
    window.HandleListKeyDown(32, 0, Win32.WM_KEYDOWN,
        window.NameEdit.Hwnd)
    window.HandleListKeyDown(46, 0, Win32.WM_KEYDOWN,
        window.NameEdit.Hwnd)
    MappingWindowVisualAssert(app.ToggleCount == toggleCount
            && app.DeleteCount == deleteCount,
        "List shortcuts intercepted a text input.")
    MappingWindowVisualAssert(
            window.Interactions.TextInputTargets.Has(window.NameEdit.Hwnd)
            && window.Interactions.TextInputTargets[window.NameEdit.Hwnd]
                == window.NameEdit.Hwnd,
        "The mapping name input is not registered for text selection.")
    window.NameEdit.Value := "mouse-selectable mapping name"
    MappingWindowAssertMouseSelectableEdit(window.NameEdit,
        "The mapping name input")
    window.NameEdit.Value := ""

    window.List.Modify(0, "-Select")
    window.HandleListCommand(65, 0, true)
    MappingWindowVisualAssert(window.GetSelectedRows().Length == 2,
        "Ctrl+A did not select every mapping row.")
    app.RuleColors["visual-test"] := "sage"
    app.RuleColors["visual-test-2"] := "sage"

    contextState := window.ContextPopup.Interactions.Controls[
        window.ContextPopup.EditButton.Hwnd]
    optimizeContextState := window.ContextPopup.Interactions.Controls[
        window.ContextPopup.OptimizeButton.Hwnd]
    colorLabelState := window.ContextPopup.Interactions.Controls[
        window.ContextPopup.ColorLabel.Hwnd]
    MappingWindowVisualAssert(window.ContextPopup.WindowWidth
            >= MappingContextPopupWindow.MinWindowWidth
            && window.ContextPopup.WindowWidth
                <= MappingContextPopupWindow.MaxWindowWidth
            && window.ContextPopup.WindowHeight
                == MappingContextPopupWindow.Padding * 2
                    + MappingContextPopupWindow.ItemHeight * 2
                    + MappingContextPopupWindow.ItemGap
                    + MappingContextPopupWindow.ColorSectionTopGap
                    + MappingContextPopupWindow.ColorLabelHeight
                    + MappingContextPopupWindow.SwatchTopGap
                    + MappingContextPopupWindow.SwatchSize
            && contextState.TextAlign == "left"
            && contextState.TextInsetDip
                == MappingContextPopupWindow.TextInsetDip
            && contextState.RadiusDip
                == MappingContextPopupWindow.RowRadiusDip
            && contextState.HasOwnProp("ButtonImage")
            && optimizeContextState.HasOwnProp("ButtonImage")
            && window.ContextPopup.EditButton.Text
                == Tr("编辑映射代码") "（F2）"
            && window.ContextPopup.OptimizeButton.Text
                == Tr("AI 优化规则")
            && window.ContextPopup.MenuButtons.Length == 2
            && window.ContextPopup.ColorLabel.Text == Tr("设置序号圆点")
            && colorLabelState.Kind == "icon"
            && colorLabelState.HasOwnProp("ButtonImage")
            && colorLabelState.ButtonImage.SourcePath
                == GetApplicationAssetPath(
                    "ui-icons\lucide\palette.svg")
            && colorLabelState.TextColor
                == UiThemeService.GetPalette().Text
            && colorLabelState.ButtonImage.TintColor
                == UiThemeService.GetPalette().ThemeIcon
            && ContextPopupTitleFontMatchesMenu(window.ContextPopup)
            && window.ContextPopup.SwatchButtons.Length == 8
            && window.ContextPopup.SwatchButtons[1].Key == "sage"
            && window.ContextPopup.SwatchButtons[8].Key == ""
            && window.ContextPopup.SwatchButtons[8].Control.Text == "✕"
            && window.ContextPopup.Interactions.Controls[
                window.ContextPopup.SwatchButtons[8].Control.Hwnd]
                    .ClearMarkSizeDip == 16
            && window.ContextPopup.Interactions.Controls[
                window.ContextPopup.SwatchButtons[1].Control.Hwnd]
                    .Normal == "496B59",
        "The mapping context popup does not match the reference menu layout.")
    sequenceLayout := window.CalculateSequenceDotLayout(
        {Left: 0, Top: 0, Right: 48, Bottom: 36}, 8, 8,
        ListViewSelectionPresenter.HorizontalInsetDip)
    MappingWindowVisualAssert(sequenceLayout.TextLeft == 20
            && sequenceLayout.DotLeft
                == ListViewSelectionPresenter.HorizontalInsetDip
            && sequenceLayout.DotTop == 14,
        "The sequence dot shifted the centered sequence number.")
    window.Gui.Show()
    DllCall("user32\SetFocus", "Ptr", window.List.Hwnd, "Ptr")
    listFocus := DllCall("user32\GetFocus", "Ptr")
    window.OnListContextMenu(window.List, 1, true, 0, 0)
    MappingWindowVisualAssert(window.ContextPopup.IsVisible()
            && window.GetSelectedRows().Length == 2
            && window.ContextPopup.MappingIds.Length == 2
            && window.ContextPopup.SwatchButtons[1].Control.Text == "✓"
            && listFocus == window.List.Hwnd
            && DllCall("user32\GetFocus", "Ptr") == listFocus,
        "The mapping context popup lost the batch selection or stole focus.")
    SetTimer(window.ContextPopup.VisibilityTimer, 0)
    Sleep(40)
    AssertLeftAlignedContextPopupButton(window.ContextPopup,
        window.ContextPopup.EditButton)
    AssertContextPopupClearMarkCentered(window.ContextPopup)
    window.RefreshMappingColors(["visual-test"])
    AssertSequenceDotAlignedToSelection(window, 1, "sage")
    window.ContextPopup.MappingId := "visual-test"
    window.ContextPopup.MappingIds := ["visual-test", "visual-test-2"]
    window.ContextPopup.InvokeColor("mist")
    MappingWindowVisualAssert(app.RuleColorSaveCount == 1
            && app.LastRuleColorIds.Length == 2
            && app.RuleColors["visual-test"] == "mist"
            && app.RuleColors["visual-test-2"] == "mist"
            && !window.ContextPopup.IsVisible(),
        "The context color command did not update the selected rules once.")
    MappingWindowVisualAssert(window.ContextPopup.ShowForMapping(
            "visual-test") && window.ContextPopup.IsVisible()
            && DllCall("user32\GetFocus", "Ptr") == listFocus,
        "The mapping context popup stole focus from the main list.")
    window.ContextPopup.InvokeOptimize()
    MappingWindowVisualAssert(window.ContextOptimizeId == "visual-test"
            && !window.ContextPopup.IsVisible(),
        "The mapping context AI command did not target the clicked rule.")

    window.SelectOnlyRow(1)
    window.HandleListCommand(113, 0)
    window.HandleListCommand(113, 0x40000000)
    MappingWindowVisualAssert(IsObject(window.BlockEditor)
            && app.Repository.GetCount == 1,
        "F2 did not open exactly one editor for the focused mapping.")
    window.BlockEditor.Dispose(false)

    window.List.Modify(0, "-Select")
    window.RefreshSelectionState()
    MappingWindowVisualAssert(pauseState.Normal
            == MappingWindow.Colors.PauseDisabled && !pauseState.Interactive
            && deleteState.Normal == MappingWindow.Colors.DeleteDisabled
            && !deleteState.Interactive,
        "Clearing the selection did not restore disabled command colors.")

    ValidateMappingEditorCleanup(window)
    ValidateNewMappingEditorModes(window)
    ValidateScriptEditorSaveSnapshot(window)

    window.List.Modify(0, "-Select")
    MappingWindowVisualAssert(window.RemoveMappingRow("visual-test")
            && window.List.GetCount() == 1
            && window.List.GetText(1, MappingWindow.NameColumn)
                == "visual-test-2"
            && window.List.GetText(1, MappingWindow.SequenceColumn) == "1",
        "Incremental deletion did not preserve the remaining row and order.")
    window.SelectOnlyRow(1)
    window.RefreshSelectionState()
    MappingWindowVisualAssert(pauseState.Interactive
            && deleteState.Interactive,
        "Incremental deletion left commands disabled for the remaining row.")
    window.HandleListCommand(27, 0)
    MappingWindowVisualAssert(!window.GetSelectedRows().Length
            && DllCall("user32\IsWindowVisible", "Ptr", window.Gui.Hwnd,
                "Int"),
        "The first Escape did not only clear the list selection.")
    ValidateMainWindowActivation(window)
    expectedPersistedSize := window.GetPersistableClientSize()
    window.HandleListCommand(27, 0)
    MappingWindowVisualAssert(!DllCall("user32\IsWindowVisible", "Ptr",
            window.Gui.Hwnd, "Int"),
        "Escape did not hide the unselected main window.")
    MappingWindowVisualAssert(app.LayoutSaveCount == 1
            && app.SavedLayout.Width == expectedPersistedSize.Width
            && app.SavedLayout.Height == expectedPersistedSize.Height,
        "Hiding the main window did not persist its last normal client size.")

    ReportMappingWindowVisualResult("PASS mapping window visuals`n")
    } catch as testError {
        ReportMappingWindowVisualResult(testError.Message "`n"
            testError.Stack "`n", true)
        exitCode := 1
    } finally {
        if IsObject(window)
            try window.Dispose()
    }
    return exitCode
}

GetMappingStatusIconIndex(window, row) {
    return GetMappingListIconIndex(window, row, MappingWindow.StatusColumn)
}

GetMappingListIconIndex(window, row, column) {
    listItem := Buffer(A_PtrSize == 8 ? 88 : 60, 0)
    NumPut("UInt", Win32.LVIF_IMAGE, listItem, 0)
    NumPut("Int", row - 1, listItem, 4)
    NumPut("Int", column - 1, listItem, 8)
    if !SendMessage(Win32.LVM_GETITEMW, 0, listItem.Ptr, ,
            window.List.Hwnd)
        return 0
    nativeIndex := NumGet(listItem, A_PtrSize == 8 ? 36 : 28, "Int")
    return nativeIndex >= 0 ? nativeIndex + 1 : 0
}

GetMappingListItemIndent(window, row, column) {
    listItem := Buffer(A_PtrSize == 8 ? 88 : 60, 0)
    NumPut("UInt", Win32.LVIF_INDENT, listItem, 0)
    NumPut("Int", row - 1, listItem, 4)
    NumPut("Int", column - 1, listItem, 8)
    if !SendMessage(Win32.LVM_GETITEMW, 0, listItem.Ptr, , window.List.Hwnd)
        return 0
    return NumGet(listItem, A_PtrSize == 8 ? 48 : 36, "Int")
}

AssertCenteredMappingStatusContent(window, row, cellRect) {
    DllCall("user32\UpdateWindow", "Ptr", window.List.Hwnd, "Int")
    DllCall("gdi32\GdiFlush", "Int")
    deviceContext := DllCall("user32\GetDC", "Ptr", window.List.Hwnd,
        "Ptr")
    MappingWindowVisualAssert(deviceContext,
        "The mapping status cell could not be sampled.")
    textColor := ColorRef(MappingWindow.Colors.Text)
    enabledIconColor := ColorRef(MappingWindow.Colors.StatusEnabledIcon)
    pausedIconColor := ColorRef(MappingWindow.Colors.StatusPausedIcon)
    listDpi := DllCall("user32\GetDpiForWindow", "Ptr", window.List.Hwnd,
        "UInt")
    if !listDpi
        listDpi := 96
    horizontalSampleInset := Max(3, Round(10 * listDpi / 96))
    minimumX := cellRect.Right
    maximumX := cellRect.Left
    visiblePixels := 0
    try {
        y := cellRect.Top + 3
        while y < cellRect.Bottom - 3 {
            x := cellRect.Left + horizontalSampleInset
            while x < cellRect.Right - horizontalSampleInset {
                pixel := DllCall("gdi32\GetPixel", "Ptr", deviceContext,
                    "Int", x, "Int", y, "UInt")
                if MappingWindowPixelNearColor(pixel, textColor)
                        || MappingWindowPixelNearColor(pixel,
                            enabledIconColor)
                        || MappingWindowPixelNearColor(pixel,
                            pausedIconColor) {
                    minimumX := Min(minimumX, x)
                    maximumX := Max(maximumX, x)
                    visiblePixels++
                }
                x++
            }
            y++
        }
    } finally DllCall("user32\ReleaseDC", "Ptr", window.List.Hwnd,
        "Ptr", deviceContext)
    contentCenter := (minimumX + maximumX) / 2
    cellCenter := (cellRect.Left + cellRect.Right - 1) / 2
    tolerance := Max(3, Round(4 * listDpi / 96))
    MappingWindowVisualAssert(visiblePixels > 0
            && Abs(contentCenter - cellCenter) <= tolerance,
        Format("The visible status icon-text group is not centered in its cell: content={1}-{2}, cell={3}-{4}.",
            minimumX, maximumX, cellRect.Left, cellRect.Right))
}

GetMappingListVisibleContentBounds(window, row, column) {
    cellRect := window.GetListSubItemRect(row, column)
    if !IsObject(cellRect)
        return ""
    deviceContext := DllCall("user32\GetDC", "Ptr", window.List.Hwnd,
        "Ptr")
    if !deviceContext
        return ""
    textColor := ColorRef(MappingWindow.Colors.Text)
    minimumX := cellRect.Right
    maximumX := cellRect.Left
    visiblePixels := 0
    try {
        y := cellRect.Top + 3
        while y < cellRect.Bottom - 3 {
            x := cellRect.Left + 3
            while x < cellRect.Right - 3 {
                pixel := DllCall("gdi32\GetPixel", "Ptr", deviceContext,
                    "Int", x, "Int", y, "UInt")
                if MappingWindowPixelNearColor(pixel, textColor) {
                    minimumX := Min(minimumX, x)
                    maximumX := Max(maximumX, x)
                    visiblePixels++
                }
                x++
            }
            y++
        }
    } finally DllCall("user32\ReleaseDC", "Ptr", window.List.Hwnd,
        "Ptr", deviceContext)
    return visiblePixels ? {
        Left: minimumX, Right: maximumX, Cell: cellRect,
        Inset: minimumX - cellRect.Left
    } : ""
}

MappingWindowPixelNearColor(pixel, target, tolerance := 24) {
    if pixel == 0xFFFFFFFF
        return false
    return Abs((pixel & 0xFF) - (target & 0xFF)) <= tolerance
        && Abs(((pixel >> 8) & 0xFF) - ((target >> 8) & 0xFF)) <= tolerance
        && Abs(((pixel >> 16) & 0xFF) - ((target >> 16) & 0xFF))
            <= tolerance
}

AssertUniformMappingListTextInsets(window, row) {
    name := source := target := ""
    Loop 4 {
        window.List.Redraw()
        DllCall("user32\UpdateWindow", "Ptr", window.List.Hwnd, "Int")
        DllCall("gdi32\GdiFlush", "Int")
        name := GetMappingListVisibleContentBounds(window, row,
            MappingWindow.NameColumn)
        source := GetMappingListVisibleContentBounds(window, row,
            MappingWindow.SourceColumn)
        target := GetMappingListVisibleContentBounds(window, row,
            MappingWindow.TargetColumn)
        if IsObject(name) && IsObject(source) && IsObject(target)
            break
        Sleep(20)
    }
    MappingWindowVisualAssert(IsObject(name) && IsObject(source)
            && IsObject(target)
            && Max(name.Inset, source.Inset, target.Inset)
                - Min(name.Inset, source.Inset, target.Inset) <= 2,
        Format("The left-aligned mapping columns use inconsistent text insets: name={1}, source={2}, target={3}.",
            IsObject(name) ? name.Inset : -1,
            IsObject(source) ? source.Inset : -1,
            IsObject(target) ? target.Inset : -1))
}

AssertMappingNameStartsAfterSequence(window, row) {
    sequenceCell := window.GetListSubItemRect(row,
        MappingWindow.SequenceColumn)
    nameCell := window.GetListSubItemRect(row, MappingWindow.NameColumn)
    visibleName := GetMappingListVisibleContentBounds(window, row,
        MappingWindow.NameColumn)
    MappingWindowVisualAssert(IsObject(sequenceCell)
            && IsObject(nameCell) && IsObject(visibleName)
            && nameCell.Left >= sequenceCell.Right
            && visibleName.Left >= nameCell.Left
            && visibleName.Left < nameCell.Right,
        Format("The mapping name overlaps the sequence column: sequence={1}-{2}, name={3}-{4}, text={5}.",
            IsObject(sequenceCell) ? sequenceCell.Left : -1,
            IsObject(sequenceCell) ? sequenceCell.Right : -1,
            IsObject(nameCell) ? nameCell.Left : -1,
            IsObject(nameCell) ? nameCell.Right : -1,
            IsObject(visibleName) ? visibleName.Left : -1))
}

AssertLeftAlignedContextPopupButton(popup, button) {
    clientRect := Buffer(16, 0)
    MappingWindowVisualAssert(DllCall("user32\GetClientRect",
        "Ptr", button.Hwnd, "Ptr", clientRect, "Int"),
        "The context-menu button geometry could not be inspected.")
    width := NumGet(clientRect, 8, "Int")
    height := NumGet(clientRect, 12, "Int")
    windowContext := DllCall("user32\GetDC", "Ptr", button.Hwnd, "Ptr")
    memoryContext := windowContext ? DllCall("gdi32\CreateCompatibleDC",
        "Ptr", windowContext, "Ptr") : 0
    bitmap := memoryContext ? DllCall("gdi32\CreateCompatibleBitmap", "Ptr",
        windowContext, "Int", width, "Int", height, "Ptr") : 0
    previousBitmap := bitmap ? DllCall("gdi32\SelectObject", "Ptr",
        memoryContext, "Ptr", bitmap, "Ptr") : 0
    MappingWindowVisualAssert(windowContext && memoryContext && bitmap,
        "The context-menu button surface could not be inspected.")
    dpi := DllCall("user32\GetDpiForWindow", "Ptr", button.Hwnd, "UInt")
    if !dpi
        dpi := 96
    expectedLeft := Max(1, Round(
        MappingContextPopupWindow.TextInsetDip * dpi / 96))
    buttonState := popup.Interactions.Controls[button.Hwnd]
    leadingInkAllowance := Max(4, Round(4 * dpi / 96))
    if buttonState.HasOwnProp("ButtonImage")
            && IsObject(buttonState.ButtonImage)
        leadingInkAllowance := Max(leadingInkAllowance, Round(
            buttonState.ButtonImage.SizeDip * dpi / 96))
    minimumX := width
    visiblePixels := 0
    textColor := ColorRef(buttonState.TextColor)
    try {
        MappingWindowVisualAssert(popup.Interactions.Painter.Draw(
                memoryContext, width, height, buttonState),
            "The context-menu button could not be rendered for inspection.")
        y := 3
        while y < height - 3 {
            x := 0
            while x < width {
                pixel := DllCall("gdi32\GetPixel", "Ptr", memoryContext,
                    "Int", x, "Int", y, "UInt")
                if MappingWindowPixelNearColor(pixel, textColor, 32) {
                    minimumX := Min(minimumX, x)
                    visiblePixels++
                }
                x++
            }
            y++
        }
    } finally {
        if previousBitmap
            DllCall("gdi32\SelectObject", "Ptr", memoryContext,
                "Ptr", previousBitmap, "Ptr")
        if bitmap
            DllCall("gdi32\DeleteObject", "Ptr", bitmap, "Int")
        if memoryContext
            DllCall("gdi32\DeleteDC", "Ptr", memoryContext, "Int")
        if windowContext
            DllCall("user32\ReleaseDC", "Ptr", button.Hwnd,
                "Ptr", windowContext)
    }
    MappingWindowVisualAssert(visiblePixels > 0
            && minimumX >= expectedLeft
            && minimumX <= expectedLeft + leadingInkAllowance,
        Format("The context-menu edit action is not left aligned: firstPixel={1}, expected={2}, buttonWidth={3}.",
            minimumX, expectedLeft, width))
}

AssertContextPopupClearMarkCentered(popup) {
    button := popup.SwatchButtons[popup.SwatchButtons.Length].Control
    clientRect := Buffer(16, 0)
    MappingWindowVisualAssert(DllCall("user32\GetClientRect",
        "Ptr", button.Hwnd, "Ptr", clientRect, "Int"),
        "The clear swatch bounds could not be inspected.")
    width := NumGet(clientRect, 8, "Int")
    height := NumGet(clientRect, 12, "Int")
    windowContext := DllCall("user32\GetDC", "Ptr", button.Hwnd, "Ptr")
    memoryContext := windowContext ? DllCall("gdi32\CreateCompatibleDC",
        "Ptr", windowContext, "Ptr") : 0
    bitmap := memoryContext ? DllCall("gdi32\CreateCompatibleBitmap", "Ptr",
        windowContext, "Int", width, "Int", height, "Ptr") : 0
    previousBitmap := bitmap ? DllCall("gdi32\SelectObject", "Ptr",
        memoryContext, "Ptr", bitmap, "Ptr") : 0
    MappingWindowVisualAssert(windowContext && memoryContext && bitmap,
        "The clear swatch surface could not be inspected.")
    buttonState := popup.Interactions.Controls[button.Hwnd]
    textColor := ColorRef(buttonState.TextColor)
    minimumX := width
    minimumY := height
    maximumX := -1
    maximumY := -1
    try {
        MappingWindowVisualAssert(popup.Interactions.Painter.Draw(
                memoryContext, width, height, buttonState),
            "The clear swatch could not be rendered for inspection.")
        Loop height {
            y := A_Index - 1
            Loop width {
                x := A_Index - 1
                pixel := DllCall("gdi32\GetPixel", "Ptr", memoryContext,
                    "Int", x, "Int", y, "UInt")
                if !MappingWindowPixelNearColor(pixel, textColor, 56)
                    continue
                minimumX := Min(minimumX, x)
                minimumY := Min(minimumY, y)
                maximumX := Max(maximumX, x)
                maximumY := Max(maximumY, y)
            }
        }
    } finally {
        if previousBitmap
            DllCall("gdi32\SelectObject", "Ptr", memoryContext,
                "Ptr", previousBitmap, "Ptr")
        if bitmap
            DllCall("gdi32\DeleteObject", "Ptr", bitmap, "Int")
        if memoryContext
            DllCall("gdi32\DeleteDC", "Ptr", memoryContext, "Int")
        if windowContext
            DllCall("user32\ReleaseDC", "Ptr", button.Hwnd,
                "Ptr", windowContext)
    }
    inkCenterX := (minimumX + maximumX) / 2
    inkCenterY := (minimumY + maximumY) / 2
    dpi := DllCall("user32\GetDpiForWindow", "Ptr", button.Hwnd, "UInt")
    if !dpi
        dpi := 96
    minimumMargin := Max(2, Round(2 * dpi / 96))
    MappingWindowVisualAssert(maximumX >= minimumX
            && maximumY >= minimumY
            && Abs(inkCenterX - (width - 1) / 2) <= 2
            && Abs(inkCenterY - (height - 1) / 2) <= 2,
        Format("The clear mark is not visually centered: bounds={1},{2}-{3},{4}, control={5}x{6}.",
            minimumX, minimumY, maximumX, maximumY, width, height))
    MappingWindowVisualAssert(minimumX >= minimumMargin
            && minimumY >= minimumMargin
            && maximumX <= width - 1 - minimumMargin
            && maximumY <= height - 1 - minimumMargin,
        Format("The clear mark does not retain its surrounding inset: bounds={1},{2}-{3},{4}, control={5}x{6}, margin={7}.",
            minimumX, minimumY, maximumX, maximumY, width, height,
            minimumMargin))
}

ContextPopupTitleFontMatchesMenu(popup) {
    menuFont := SendMessage(Win32.WM_GETFONT, 0, 0, ,
        popup.EditButton.Hwnd)
    titleFont := SendMessage(Win32.WM_GETFONT, 0, 0, ,
        popup.ColorLabel.Hwnd)
    if !menuFont || !titleFont
        return false
    menuLogFont := Buffer(92, 0)
    titleLogFont := Buffer(92, 0)
    if DllCall("gdi32\GetObjectW", "Ptr", menuFont,
            "Int", menuLogFont.Size, "Ptr", menuLogFont, "Int") <= 0
            || DllCall("gdi32\GetObjectW", "Ptr", titleFont,
                "Int", titleLogFont.Size, "Ptr", titleLogFont, "Int") <= 0
        return false
    return NumGet(menuLogFont, 0, "Int")
            == NumGet(titleLogFont, 0, "Int")
        && NumGet(menuLogFont, 16, "Int")
            == NumGet(titleLogFont, 16, "Int")
}

AssertSequenceDotAlignedToSelection(window, row, presetKey) {
    DllCall("user32\UpdateWindow", "Ptr", window.List.Hwnd, "Int")
    DllCall("gdi32\GdiFlush", "Int")
    cellRect := window.GetListSubItemRect(row,
        MappingWindow.SequenceColumn)
    MappingWindowVisualAssert(IsObject(cellRect),
        "The sequence cell bounds could not be inspected.")
    dpi := window.GetListDpi()
    expectedLeft := cellRect.Left + Max(2, Round(
        ListViewSelectionPresenter.HorizontalInsetDip * dpi / 96))
    deviceContext := DllCall("user32\GetDC", "Ptr", window.List.Hwnd,
        "Ptr")
    MappingWindowVisualAssert(deviceContext,
        "The sequence-dot surface could not be inspected.")
    targetColor := ColorRef(RuleColorPalette.Color(presetKey))
    minimumX := cellRect.Right
    visiblePixels := 0
    try {
        y := cellRect.Top
        while y < cellRect.Bottom {
            x := cellRect.Left
            while x < Min(cellRect.Right, expectedLeft + 16) {
                pixel := DllCall("gdi32\GetPixel", "Ptr", deviceContext,
                    "Int", x, "Int", y, "UInt")
                if MappingWindowPixelNearColor(pixel, targetColor, 24) {
                    minimumX := Min(minimumX, x)
                    visiblePixels++
                }
                x++
            }
            y++
        }
    } finally DllCall("user32\ReleaseDC", "Ptr", window.List.Hwnd,
        "Ptr", deviceContext)
    MappingWindowVisualAssert(visiblePixels > 0
            && minimumX >= expectedLeft
            && minimumX <= expectedLeft + 2,
        Format("The sequence dot is clipped or not aligned to the selection background: firstPixel={1}, expected={2}.",
            minimumX, expectedLeft))
}

AssertRoundedMappingListSelection(window, row) {
    firstCell := window.GetListSubItemRect(row,
        MappingWindow.SequenceColumn)
    lastCell := window.GetListSubItemRect(row,
        MappingWindow.StatusColumn)
    MappingWindowVisualAssert(IsObject(firstCell) && IsObject(lastCell),
        "The selected mapping row bounds could not be measured.")
    dpi := DllCall("user32\GetDpiForWindow", "Ptr", window.List.Hwnd,
        "UInt")
    if !dpi
        dpi := 96
    horizontalInset := Max(2, Round(
        ListViewSelectionPresenter.HorizontalInsetDip * dpi / 96))
    verticalInset := Max(1, Round(
        ListViewSelectionPresenter.VerticalInsetDip * dpi / 96))
    radius := Max(3, Round(
        ListViewSelectionPresenter.RadiusDip * dpi / 96))
    surface := ColorRef(MappingWindow.Colors.Surface)
    leftCorner := CaptureMappingWindowOwnDcPixel(window.List.Hwnd,
        firstCell.Left + horizontalInset,
        firstCell.Top + verticalInset)
    rightCorner := CaptureMappingWindowOwnDcPixel(window.List.Hwnd,
        lastCell.Right - horizontalInset - 1,
        lastCell.Top + verticalInset)
    selectedInterior := CaptureMappingWindowOwnDcPixel(window.List.Hwnd,
        firstCell.Left + horizontalInset + radius,
        firstCell.Top + verticalInset + 1)
    topOuter := CaptureMappingWindowOwnDcPixel(window.List.Hwnd,
        firstCell.Left + horizontalInset + radius, firstCell.Top)
    bottomOuter := CaptureMappingWindowOwnDcPixel(window.List.Hwnd,
        firstCell.Left + horizontalInset + radius, firstCell.Bottom - 1)
    leftOuter := CaptureMappingWindowOwnDcPixel(window.List.Hwnd,
        firstCell.Left + 1, Floor((firstCell.Top + firstCell.Bottom) / 2))
    rightOuter := CaptureMappingWindowOwnDcPixel(window.List.Hwnd,
        lastCell.Right - 2, Floor((lastCell.Top + lastCell.Bottom) / 2))
    MappingWindowVisualAssert(leftCorner == surface
            && rightCorner == surface
            && selectedInterior != surface
            && topOuter == surface && bottomOuter == surface
            && leftOuter == surface && rightOuter == surface,
        Format("The selected mapping row is not rounded or retained a rectangular focus border: corners={1:06X}/{2:06X}, interior={3:06X}, outer={4:06X}/{5:06X}/{6:06X}/{7:06X}, surface={8:06X}.",
            leftCorner, rightCorner, selectedInterior, topOuter, bottomOuter,
            leftOuter, rightOuter, surface))
}

AssertMainStatusCaretHidden(window, context) {
    info := Buffer(72, 0)
    NumPut("UInt", info.Size, info, 0)
    guiThreadId := DllCall("user32\GetWindowThreadProcessId",
        "Ptr", window.Gui.Hwnd, "Ptr", 0, "UInt")
    MappingWindowVisualAssert(DllCall("user32\GetGUIThreadInfo", "UInt",
            guiThreadId, "Ptr", info, "Int"),
        "Could not inspect the caret state for " context ".")
    MappingWindowVisualAssert(!(NumGet(info, 4, "UInt") & 0x00000001),
        "The main status caret is still blinking after " context ".")
}

ValidateMainWindowActivation(window) {
    DllCall("user32\ShowWindow", "Ptr", window.Gui.Hwnd,
        "Int", Win32.SW_MINIMIZE, "Int")
    Sleep(150)
    MappingWindowVisualAssert(DllCall("user32\IsIconic", "Ptr",
            window.Gui.Hwnd, "Int"),
        "The activation probe could not first minimize the main window.")
    activationResult := window.Activate()
    Sleep(150)
    MappingWindowVisualAssert(activationResult
            && !DllCall("user32\IsIconic", "Ptr", window.Gui.Hwnd,
                "Int"),
        "The unified main-window activation path did not restore a minimized window.")
}

ReportMappingWindowVisualResult(message, isError := false) {
    try {
        FileAppend(message, isError ? "**" : "*")
        return true
    } catch {
        return false
    }
}

ValidateMainWindowResizeIsolation(window) {
    probe := MappingWindowResizeIsolationProbe
    probe.Install(window.Gui.Hwnd, window.AddButton.Hwnd,
        window.List.Hwnd, [
            window.SettingsButton.Hwnd, window.SupportButton.Hwnd,
            window.AboutButton.Hwnd, window.SectionTopDivider.Hwnd,
            window.SourceButton.Hwnd, window.ArrowText.Hwnd,
            window.TargetButton.Hwnd, window.SaveButton.Hwnd,
            window.ClearButton.Hwnd
        ])
    try {
        window.Gui.GetClientPos(, , &baseWidth, &baseHeight)
        saveState := window.Interactions.Controls[window.SaveButton.Hwnd]
        window.Interactions.HoveredHwnd := window.SaveButton.Hwnd
        saveState.Current := saveState.Hover
        window.OnInteractiveResizeMessage(0, 0,
            Win32.WM_ENTERSIZEMOVE, window.Gui.Hwnd)
        MappingWindowVisualAssert(window.Interactions.PointerFeedbackFrozen,
            "Interactive resize did not freeze button pointer feedback.")
        MappingWindowVisualAssert(window.Interactions.HoveredHwnd == 0
                && saveState.Current == saveState.Normal,
            "Interactive resize carried a stale saved-mapping hover surface.")
        window.OnInteractiveResizeMessage(0, 0,
            Win32.WM_EXITSIZEMOVE, window.Gui.Hwnd)
        MappingWindowVisualAssert(!window.Interactions.PointerFeedbackFrozen,
            "Interactive resize did not restore button pointer feedback.")
        probe.Reset()
        blockedBefore := AtomicControlLayoutEraseGuard.BlockedEraseCount
        result := window.ApplyLayout(baseWidth + 80, baseHeight + 40,
            false, true)
        MappingWindowVisualAssert(IsObject(result)
                && result.Status == AtomicControlLayout.Applied
                && result.Mode == AtomicControlLayout.ModeDeferred
                && result.Repainted,
            "The main-window resize isolation transaction did not apply.")
        MappingWindowVisualAssert(probe.RootSuspendCount == 0,
            "Interactive resize paused the parent window redraw.")
        MappingWindowVisualAssert(probe.ListSuspendCount == 1,
            "The main ListView was not suspended exactly once during resize.")
        for surfaceHwnd in probe.MovingHwnds
            MappingWindowVisualAssert(
                probe.SurfaceSuspendCounts.Has(surfaceHwnd)
                    && probe.SurfaceSuspendCounts[surfaceHwnd] == 0,
                "Interactive resize suspended an owner-drawn surface.")
        MappingWindowVisualAssert(probe.StableButtonPaintCount == 0,
            "A stable left-side button repainted during right-side resize.")
        MappingWindowVisualAssert(
            AtomicControlLayoutEraseGuard.BlockedEraseCount
                > blockedBefore
                && AtomicControlLayoutEraseGuard.BlockedEraseCount
                    - blockedBefore >= probe.MovingEraseCount,
            "A moving button exposed an unprotected background erase.")
        MappingWindowVisualAssert(
            AtomicControlRedrawTransaction.ActiveHwndCounts.Count == 0,
            "The main-window resize leaked a child redraw transaction.")
        MappingWindowVisualAssert(probe.MovingEraseCount == 0,
            "A moved owner-draw surface received an unprotected erase.")
        AssertMappingWindowDashedDivider(window,
            "The separator lost its stable dashed pixels after resize.")
    } finally {
        probe.Uninstall()
        window.ApplyLayout(baseWidth, baseHeight, true, false)
    }
}

ValidateMainWindowAppearanceRefreshIsolation(window) {
    probe := MappingWindowResizeIsolationProbe
    probe.Install(window.Gui.Hwnd, window.AddButton.Hwnd,
        window.List.Hwnd, [])
    try {
        probe.Reset()
        MappingWindowVisualAssert(window.ApplyAppearance(),
            "The main-window appearance refresh failed.")
        MappingWindowVisualAssert(probe.RootSuspendCount == 0,
            "The main-window appearance refresh paused top-level redraw.")
        MappingWindowVisualAssert(DllCall("user32\IsWindowVisible", "Ptr",
                window.Gui.Hwnd, "Int"),
            "The main window became invisible during appearance refresh.")
    } finally probe.Uninstall()
}

ValidateMainWindowLightTheme(window) {
    darkStatusImageList := window.ListRowImageList
    oldCellTooltipHwnd := IsObject(window.CellTooltip.Gui)
        ? window.CellTooltip.Gui.Hwnd : 0
    UiThemeService.Configure("light")
    try {
        MappingWindowVisualAssert(window.ApplyAppearance(),
            "The main window could not apply the light theme.")
        colors := UiThemeService.GetPalette()
        tooltipStyle := UiThemeService.GetTooltipStyle()
        dividerState := window.Interactions.Controls[
            window.SectionTopDivider.Hwnd]
        settingsState := window.Interactions.Controls[
            window.SettingsButton.Hwnd]
        supportState := window.Interactions.Controls[
            window.SupportButton.Hwnd]
        aboutState := window.Interactions.Controls[window.AboutButton.Hwnd]
        addState := window.Interactions.Controls[window.AddButton.Hwnd]
        sourceState := window.Interactions.Controls[window.SourceButton.Hwnd]
        targetState := window.Interactions.Controls[window.TargetButton.Hwnd]
        arrowState := window.Interactions.Controls[window.ArrowText.Hwnd]
        MappingWindowVisualAssert(
                MappingWindow.Colors.Window == colors.Window
                && dividerState.BackgroundColor == colors.Window
                && dividerState.LineColor == colors.DividerAccent
                && window.ListRowImageList
                && window.ListRowImageList != darkStatusImageList,
            "The light main-window divider or status icons retained dark-theme colors.")
        MappingWindowVisualAssert(tooltipStyle.Background == "E2E8F0"
                && tooltipStyle.Text == "0F172A"
                && tooltipStyle.FontSize == 10
                && tooltipStyle.MarginX == 12
                && tooltipStyle.MarginY == 8
                && !IsObject(window.CellTooltip.Gui),
            "The light rule-preview tooltip did not adopt the shared style or invalidate its dark window.")
        window.CellTooltip.PendingCell := "light-theme-style"
        window.CellTooltip.PendingText := "完整规则预览"
        window.CellTooltip.ShowPending()
        MappingWindowVisualAssert(IsObject(window.CellTooltip.Gui)
                && window.CellTooltip.Gui.Hwnd != oldCellTooltipHwnd
                && window.CellTooltip.Gui.MarginX == tooltipStyle.MarginX
                && window.CellTooltip.Gui.MarginY == tooltipStyle.MarginY,
            "The light rule-preview tooltip was not rebuilt with the shared spacing.")
        window.CellTooltip.Hide()
        MappingWindowVisualAssert(addState.Hover
                == window.Interactions.DarkenColor(colors.Add, 0.88)
                && settingsState.Hover
                    == window.Interactions.LightenColor(colors.Toolbar),
            "The light button hover colors reduce text contrast.")
        MappingWindowVisualAssert(
                settingsState.ButtonImage.TintColor == colors.Muted
                && supportState.ButtonImage.TintColor == colors.DisplayIcon
                && aboutState.ButtonImage.TintColor == colors.RulesEventIcon,
            "A light main-toolbar icon lacks its explicit semantic color.")
        for state in [sourceState, targetState]
            MappingWindowVisualAssert(state.Normal == colors.Toolbar
                    && state.TextColor == colors.Text
                    && state.ButtonImage.TintColor
                        == colors.RulesEventIcon
                    && state.TrailingButtonImage.TintColor
                        == colors.LanguageIcon,
                "An idle light capture button has mismatched text or icon colors.")
        MappingWindowVisualAssert(arrowState.ButtonImage.TintColor
                == colors.RulesEventIcon,
            "The light mapping-direction icon retained its SVG source color.")
        window.RefreshCaptureButtonIcon(window.SourceButton, "source", {}, "")
        MappingWindowVisualAssert(sourceState.Normal == colors.Add
                && sourceState.TextColor == colors.ButtonText,
            "A completed light capture uses low-contrast button text.")
        window.RefreshCaptureButtonIcon(window.SourceButton, "source", "",
            "source")
        MappingWindowVisualAssert(sourceState.Normal == colors.Primary
                && sourceState.TextColor == colors.ButtonText,
            "An active light capture uses low-contrast button text.")
        window.RefreshCaptureButtonIcon(window.SourceButton, "source", "", "")
    } finally {
        UiThemeService.Configure("dark")
        window.ApplyAppearance()
    }
    for state in [settingsState, supportState, aboutState]
        MappingWindowVisualAssert(state.ButtonImage.TintMode == "none",
            "A dark main-toolbar icon was flattened to the button text color.")
    for state in [sourceState, targetState]
        MappingWindowVisualAssert(state.ButtonImage.TintMode == "none"
                && state.TrailingButtonImage.TintMode == "none",
            "Dark capture icons were flattened to the button text color.")
    MappingWindowVisualAssert(arrowState.ButtonImage.TintMode == "none",
        "The dark mapping-direction icon was flattened to the hint color.")
}

ValidateMainWindowResponsiveLayout(window) {
    MappingWindowVisualAssert(DllCall("user32\IsWindowVisible", "Ptr",
            window.Gui.Hwnd, "Int")
            && !DllCall("user32\IsIconic", "Ptr", window.Gui.Hwnd,
                "Int"),
        "The responsive-layout probe did not start with a visible window.")
    window.Gui.GetClientPos(, , &baseWidth, &baseHeight)
    window.List.GetPos(&baseListX, &baseListY, &baseListWidth,
        &baseListHeight)
    window.SourceButton.GetPos(&baseSourceX, &baseSourceY,
        &baseSourceWidth, &baseSourceHeight)
    window.TargetButton.GetPos(&baseTargetX, , &baseTargetWidth,
        &baseTargetHeight)
    window.NameInput.Background.GetPos(&baseNameX, ,
        &baseNameWidth, &baseNameHeight)
    window.SourceDetail.GetPos(, , , &baseDetailHeight)
    window.Status.GetPos(, , , &baseStatusHeight)
    window.SaveButton.GetPos(&baseSaveX, &baseSaveY, &baseSaveWidth,
        &baseSaveHeight)
    window.ClearButton.GetPos(, , , &baseClearHeight)
    window.AddButton.GetPos(, , , &baseTopCommandHeight)
    MappingWindowVisualAssert(baseSaveHeight == baseClearHeight
            && baseClearHeight == baseTopCommandHeight
            && baseSaveHeight == MappingWindow.CommandButtonHeight,
        "The footer commands do not share the main command-button geometry.")
    window.RefreshVisibleRoundedButtons()
    DllCall("gdi32\GdiFlush", "Int")
    FirstVisibleWindowPresenter.FlushComposition()
    baseSaveSignature := CaptureMappingWindowControlSignature(
        window.SaveButton)
    baseClearSignature := CaptureMappingWindowControlSignature(
        window.ClearButton)
    baseHeaderSignatures := []
    for cell in window.ListHeader.Cells
        baseHeaderSignatures.Push(
            CaptureMappingWindowControlSignature(cell))
    saveButtonState := window.Interactions.Controls[window.SaveButton.Hwnd]
    clearButtonState := window.Interactions.Controls[window.ClearButton.Hwnd]
    MappingWindowVisualAssert(saveButtonState.HasOwnProp("ButtonImage")
            && clearButtonState.HasOwnProp("ButtonImage"),
        "The footer commands do not share the icon-backed owner-draw path.")
    MappingWindowVisualAssert(saveButtonState.ButtonImage.TintColor
            == MappingWindow.Colors.Success
            && clearButtonState.ButtonImage.TintColor
                == MappingWindow.Colors.Danger,
        "The footer icons do not use semantic success and danger colors.")
    MappingWindowVisualAssert(saveButtonState.Normal == clearButtonState.Normal
            && saveButtonState.TextColor == clearButtonState.TextColor
            && saveButtonState.RadiusDip == clearButtonState.RadiusDip,
        "The save command does not share the clear command's visual style.")
    window.AboutButton.GetPos(&oldAboutX, &oldAboutY, &oldAboutWidth,
        &oldAboutHeight)
    baseColumns := ReadMappingWindowColumnWidths(window)
    MappingWindowVisualAssert(baseColumns.Source == baseColumns.Target,
        "The source and target list columns do not start with equal widths.")

    ; The earlier wrapped-text checks may grow this window close to the work
    ; area limit. Exercise four shrinking frames so the sampled CS_PARENTDC
    ; surface stays above the taskbar exclusion on every DPI.
    for heightDelta in [4, 8, 12, 16, 20, 24, 20, 16, 12, 8, 4,
            8, 12, 16, 20, 24, 20, 16, 12, 8, 4] {
        oldSaveRect := AtomicControlLayout.GetControlBounds(
            window.SaveButton.Hwnd, window.Gui.Hwnd)
        oldClearRect := AtomicControlLayout.GetControlBounds(
            window.ClearButton.Hwnd, window.Gui.Hwnd)
        requestedTallHeight := baseHeight - heightDelta
        MappingWindowVisualAssert(ResizeMappingWindowClient(
                window.Gui.Hwnd, baseWidth, requestedTallHeight),
            "Could not resize the main-window client area vertically.")
        window.Gui.GetClientPos(, , &tallWidth, &tallHeight)
        frameSaveSignature := CaptureMappingWindowControlSignature(
            window.SaveButton)
        MappingWindowVisualAssert(frameSaveSignature == baseSaveSignature,
            "The native resize frame returned with an incomplete saved-mapping button surface.")
        frameClearSignature := CaptureMappingWindowControlSignature(
            window.ClearButton)
        MappingWindowVisualAssert(frameClearSignature == baseClearSignature,
            "The native resize frame returned with an incomplete clear button surface.")
        for headerIndex, cell in window.ListHeader.Cells
            MappingWindowVisualAssert(
                CaptureMappingWindowControlSignature(cell)
                    == baseHeaderSignatures[headerIndex],
                "The native resize frame lost a pseudo-header surface.")
        window.CancelPendingResize()
        window.FullWindowRedrawCount := 0
        window.ApplyLayout(tallWidth, tallHeight, false, true)
        Sleep(10)
        appliedLayoutResult := window.LastChangedLayoutResult
        MappingWindowVisualAssert(IsObject(appliedLayoutResult)
                && appliedLayoutResult.Status == AtomicControlLayout.Applied
                && appliedLayoutResult.Mode
                    == AtomicControlLayout.ModeDeferred
                && appliedLayoutResult.Repainted
                && window.FullWindowRedrawCount == 0,
            Format("A live-resize frame did not use the deferred local repaint transaction: status={1}, mode={2}, changed={3}, repainted={4}, reason={5}, full={6}.",
                IsObject(appliedLayoutResult)
                    ? appliedLayoutResult.Status : "none",
                IsObject(appliedLayoutResult)
                    ? appliedLayoutResult.Mode : "none",
                IsObject(appliedLayoutResult)
                    ? appliedLayoutResult.Changed : -1,
                IsObject(appliedLayoutResult)
                    ? appliedLayoutResult.Repainted : -1,
                IsObject(appliedLayoutResult)
                    ? appliedLayoutResult.Reason : "",
                window.FullWindowRedrawCount))
        unchangedLayoutResult := window.ApplyLayout(tallWidth, tallHeight,
            true, true)
        MappingWindowVisualAssert(IsObject(unchangedLayoutResult)
                && unchangedLayoutResult.Status
                    == AtomicControlLayout.Unchanged
                && !unchangedLayoutResult.Changed
                && !unchangedLayoutResult.Repainted
                && AtomicControlLayoutEraseGuard.ActiveHwndCounts.Count == 0,
            "An unchanged live-resize frame did not take the no-work path.")
        window.List.GetPos(, , , &tallListHeight)
        window.SourceButton.GetPos(, &tallSourceY, , &tallSourceHeight)
        window.TargetButton.GetPos(, , , &tallTargetHeight)
        window.NameInput.Background.GetPos(, , , &tallNameHeight)
        window.SourceDetail.GetPos(, , , &tallDetailHeight)
        window.SaveButton.GetPos(, , &tallSaveWidth, &tallCommandHeight)
        currentSaveSignature := CaptureMappingWindowControlSignature(
            window.SaveButton)
        currentClearSignature := CaptureMappingWindowControlSignature(
            window.ClearButton)
        MappingWindowVisualAssert(Abs((tallListHeight - baseListHeight)
                    - (tallHeight - baseHeight)) <= 1
                && Abs((tallSourceY - baseSourceY)
                    - (tallHeight - baseHeight)) <= 1,
            "A continuous vertical resize step did not go entirely to the rule list.")
            MappingWindowVisualAssert(tallSourceHeight == baseSourceHeight
                && tallTargetHeight == baseTargetHeight
                && tallNameHeight == baseNameHeight
                && tallDetailHeight == baseDetailHeight,
            "A continuous vertical resize step changed the editor region height.")
        MappingWindowVisualAssert(currentSaveSignature == baseSaveSignature,
            "A vertical resize changed the saved-mapping button shape.")
        MappingWindowVisualAssert(currentClearSignature == baseClearSignature,
            "A vertical resize changed the clear button shape.")
        for headerIndex, cell in window.ListHeader.Cells
            MappingWindowVisualAssert(
                CaptureMappingWindowControlSignature(cell)
                    == baseHeaderSignatures[headerIndex],
                "A vertical resize lost a pseudo-header surface.")
        AssertMappingWindowOldSurfaceClear(window.Gui.Hwnd,
            window.SaveButton.Hwnd, oldSaveRect,
            MappingWindow.Colors.Window,
            "A vertical resize left a saved-mapping button edge in its old position.")
        AssertMappingWindowOldSurfaceClear(window.Gui.Hwnd,
            window.ClearButton.Hwnd, oldClearRect,
            MappingWindow.Colors.Window,
            "A vertical resize left a clear button edge in its old position.")
    }
    MappingWindowVisualAssert(Abs((tallListHeight - baseListHeight)
                - (tallHeight - baseHeight)) <= 1
            && Abs((tallSourceY - baseSourceY)
                - (tallHeight - baseHeight)) <= 1,
        "Vertical resizing did not assign all additional height to the rule list.")
    MappingWindowVisualAssert(tallSourceHeight == baseSourceHeight
            && tallTargetHeight == baseTargetHeight
            && tallNameHeight == baseNameHeight
            && tallDetailHeight == baseDetailHeight,
        "Vertical resizing changed the new-mapping region height.")
    MappingWindowVisualAssert(tallListHeight >= MappingWindow.MinListHeight
            && tallSourceHeight >= MappingWindow.MinCaptureButtonHeight
            && tallDetailHeight >= MappingWindow.MinCaptureDetailHeight
            && baseStatusHeight >= MappingWindow.MinStatusHeight
            && tallCommandHeight <= MappingWindow.CommandRegionMinHeight,
        "A main-window region violated its explicit minimum height.")
    MappingWindowVisualCheckpoint(window, "tall")

    maximumSize := window.GetWorkAreaMaximumClientSize()
    maximumWideDelta := Min(480, maximumSize.Width - baseWidth)
    MappingWindowVisualAssert(maximumWideDelta >= 30,
        "The desktop work area is too narrow for responsive-width verification.")
    wideDeltas := []
    wideStepCount := Min(4, Max(1, Floor(maximumWideDelta / 30)))
    Loop wideStepCount {
        widthDelta := Floor(maximumWideDelta * A_Index / wideStepCount)
        if !wideDeltas.Length || widthDelta != wideDeltas[wideDeltas.Length]
            wideDeltas.Push(widthDelta)
    }
    previousSourceWidth := baseSourceWidth
    previousTargetWidth := baseTargetWidth
    previousNameWidth := baseNameWidth
    previousColumns := baseColumns
    for widthDelta in wideDeltas {
        requestedWideWidth := baseWidth + widthDelta
        MappingWindowVisualAssert(ResizeMappingWindowClient(
                window.Gui.Hwnd, requestedWideWidth, baseHeight),
            "Could not resize the main-window client area horizontally.")
        Sleep(40)
        window.Gui.GetClientPos(, , &wideWidth, &wideHeight)
        window.List.GetPos(&wideListX, &wideListY, &wideListWidth,
            &wideListHeight)
        window.SourceButton.GetPos(&wideSourceX, &wideSourceY,
            &wideSourceWidth, &wideSourceHeight)
        window.TargetButton.GetPos(&wideTargetX, &wideTargetY,
            &wideTargetWidth, &wideTargetHeight)
        window.NameInput.Background.GetPos(&wideNameX, &wideNameY,
            &wideNameWidth, &wideNameHeight)
        window.AboutButton.GetPos(&wideAboutX, , &wideAboutWidth)
        wideColumns := ReadMappingWindowColumnWidths(window)
        MappingWindowVisualAssert(wideColumns.Source == wideColumns.Target,
            "The source and target list columns diverged during resizing.")
        AssertMainCommandButtonGroups(window, wideWidth)
        MappingWindowVisualAssert(wideListX == 10
                && Abs(wideListX + wideListWidth - (wideWidth - 10)) <= 1
                && Abs(wideNameX + wideNameWidth
                    - (wideWidth - 10)) <= 1
                && Abs(wideAboutX + wideAboutWidth
                    - (wideWidth - 10)) <= 1,
            "A continuous horizontal resize step left unused client width.")
        MappingWindowVisualAssert(wideSourceWidth > previousSourceWidth
                && wideTargetWidth > previousTargetWidth
                && wideNameWidth > previousNameWidth
                && wideColumns.Source > previousColumns.Source
                && wideColumns.Target > previousColumns.Target
                && wideColumns.Scope == previousColumns.Scope
                && wideColumns.Name > previousColumns.Name,
            Format("A continuous horizontal resize step failed to grow every content column. Width={1}; editor {2}/{3}/{4} -> {5}/{6}/{7}; list {8}/{9}/{10}/{11} -> {12}/{13}/{14}/{15}.",
                wideWidth,
                previousSourceWidth, previousTargetWidth,
                previousNameWidth, wideSourceWidth, wideTargetWidth,
                wideNameWidth, previousColumns.Source,
                previousColumns.Target, previousColumns.Scope,
                previousColumns.Name, wideColumns.Source,
                wideColumns.Target, wideColumns.Scope,
                wideColumns.Name))
        expectedStepColumnWidth := window.GetListContentWidth(wideListWidth)
        MappingWindowVisualAssert(Abs(wideColumns.Total
                    - expectedStepColumnWidth) <= 2,
            "A horizontal resize step left ListView client width unused.")
        previousSourceWidth := wideSourceWidth
        previousTargetWidth := wideTargetWidth
        previousNameWidth := wideNameWidth
        previousColumns := wideColumns
    }
    MappingWindowVisualAssert(wideListX == 10
            && Abs(wideListX + wideListWidth - (wideWidth - 10)) <= 1
            && Abs(wideNameX + wideNameWidth - (wideWidth - 10)) <= 1
            && Abs(wideAboutX + wideAboutWidth - (wideWidth - 10)) <= 1,
        "Horizontal resizing left unused client width.")
    MappingWindowVisualAssert(wideSourceWidth > baseSourceWidth
            && wideTargetWidth > baseTargetWidth
            && wideNameWidth > baseNameWidth
            && wideColumns.Source > baseColumns.Source
            && wideColumns.Target > baseColumns.Target
            && wideColumns.Scope == baseColumns.Scope
            && wideColumns.Name > baseColumns.Name,
        "Horizontal resizing did not proportionally grow every content column.")
    expectedColumnWidth := window.GetListContentWidth(wideListWidth)
    MappingWindowVisualAssert(Abs(wideColumns.Total - expectedColumnWidth) <= 2,
        "The visible ListView columns did not consume the available width.")

    staleSampleX := Round(oldAboutX + oldAboutWidth / 2)
    staleSampleY := Round(oldAboutY + oldAboutHeight / 2)
    MappingWindowVisualAssert(CaptureMappingWindowOwnDcPixel(window.Gui.Hwnd,
            staleSampleX, staleSampleY)
            == ColorRef(MappingWindow.Colors.Window)
            && MappingWindowScreenPixelMatchesWhenVisible(window.Gui.Hwnd,
                staleSampleX, staleSampleY, MappingWindow.Colors.Window),
        "Moving toolbar buttons left stale pixels in the old bounds.")
    window.Gui.Show("NA x0 y0")
    Sleep(50)
    MappingWindowVisualCheckpoint(window, "wide")

    toolbarSignatures := [
        CaptureMappingWindowControlSignature(window.SettingsButton),
        CaptureMappingWindowControlSignature(window.SupportButton),
        CaptureMappingWindowControlSignature(window.AboutButton)
    ]
    window.BeginCapture("source")
    Sleep(50)
    window.SourceButton.GetPos(&captureSourceX, &captureSourceY,
        &captureSourceWidth, &captureSourceHeight)
    window.TargetButton.GetPos(&captureTargetX, &captureTargetY,
        &captureTargetWidth, &captureTargetHeight)
    window.NameInput.Background.GetPos(&captureNameX, &captureNameY,
        &captureNameWidth, &captureNameHeight)
    MappingWindowVisualAssert(captureSourceX == wideSourceX
            && captureSourceY == wideSourceY
            && captureSourceWidth == wideSourceWidth
            && captureSourceHeight == wideSourceHeight
            && captureTargetX == wideTargetX
            && captureTargetY == wideTargetY
            && captureTargetWidth == wideTargetWidth
            && captureTargetHeight == wideTargetHeight
            && captureNameX == wideNameX
            && captureNameY == wideNameY
            && captureNameWidth == wideNameWidth
            && captureNameHeight == wideNameHeight,
        "Starting capture after a width change triggered a second layout.")
    MappingWindowVisualAssert(
            CaptureMappingWindowControlSignature(window.SettingsButton)
                == toolbarSignatures[1]
            && CaptureMappingWindowControlSignature(window.SupportButton)
                == toolbarSignatures[2]
            && CaptureMappingWindowControlSignature(window.AboutButton)
                == toolbarSignatures[3]
            && MappingWindowScreenPixelMatchesWhenVisible(window.Gui.Hwnd,
                staleSampleX, staleSampleY, MappingWindow.Colors.Window),
        "Starting capture after resizing corrupted or duplicated toolbar painting.")
    MappingWindowVisualCheckpoint(window, "capture")
    window.App.Capture.Cancel()
    Sleep(50)
    MappingWindowVisualAssert(
            CaptureMappingWindowControlSignature(window.SettingsButton)
                == toolbarSignatures[1]
            && CaptureMappingWindowControlSignature(window.SupportButton)
                == toolbarSignatures[2]
            && CaptureMappingWindowControlSignature(window.AboutButton)
                == toolbarSignatures[3],
        "Ending capture after resizing corrupted toolbar painting.")
    MappingWindowVisualCheckpoint(window, "capture-ended")

    window.Gui.Show("NA w" baseWidth " h" baseHeight)
    Sleep(100)
    window.Gui.GetClientPos(, , &restoredWidth, &restoredHeight)
    window.List.GetPos(, , , &restoredListHeight)
    MappingWindowVisualAssert(restoredWidth == baseWidth
            && restoredHeight == baseHeight
            && restoredListHeight == baseListHeight,
        "Returning to the previous client size did not restore its layout.")
}

AssertMappingWindowOldSurfaceClear(parentHwnd, controlHwnd, oldRect,
        backgroundColor, message) {
    if EnvGet("KEY_MOUSE_REMAPPER_GUI_TEST_OFFSCREEN") == "1"
        return
    newRect := AtomicControlLayout.GetControlBounds(controlHwnd, parentHwnd)
    if !IsObject(oldRect) || !IsObject(newRect)
        throw Error(message " (unable to read physical rectangles)")
    try expectedColor := ColorRef(backgroundColor)
    catch
        throw Error(message " (invalid background color)")
    hdc := DllCall("user32\GetDC", "Ptr", parentHwnd, "Ptr")
    if !hdc
        throw Error(message " (unable to acquire parent DC)")
    try {
        y := oldRect.Top
        while y < oldRect.Bottom {
            x := oldRect.Left
            while x < oldRect.Right {
                if (x < newRect.Left || x >= newRect.Right
                        || y < newRect.Top || y >= newRect.Bottom) {
                    pixel := DllCall("gdi32\GetPixel", "Ptr", hdc,
                        "Int", x, "Int", y, "UInt")
                    if pixel != expectedColor
                        throw Error(message " at (" x "," y ")")
                }
                x += 3
            }
            y += 3
        }
    } finally DllCall("user32\ReleaseDC", "Ptr", parentHwnd, "Ptr", hdc)
}

AssertMainCommandButtonGroups(window, clientWidth) {
    window.AddButton.GetPos(&addX, , &addWidth)
    window.PauseResumeButton.GetPos(&pauseX, , &pauseWidth)
    window.DeleteButton.GetPos(&deleteX, , &deleteWidth)
    window.SettingsButton.GetPos(&settingsX, , &settingsWidth)
    window.SupportButton.GetPos(&supportX, , &supportWidth)
    window.AboutButton.GetPos(&aboutX, , &aboutWidth)

    MappingWindowVisualAssert(addWidth == pauseWidth
            && pauseWidth == deleteWidth
            && addWidth == MappingWindow.CompactActionButtonWidth,
        "The primary command group is not uniformly compact.")
    MappingWindowVisualAssert(settingsWidth == supportWidth
            && supportWidth == aboutWidth
            && settingsWidth == MappingWindow.CompactToolbarButtonWidth,
        "The auxiliary command group is not uniformly compact.")
    MappingWindowVisualAssert(pauseX - (addX + addWidth)
            == MappingWindow.TopButtonGap
            && deleteX - (pauseX + pauseWidth)
                == MappingWindow.TopButtonGap
            && supportX - (settingsX + settingsWidth)
                == MappingWindow.TopButtonGap
            && aboutX - (supportX + supportWidth)
                == MappingWindow.TopButtonGap,
        "A command-button group has inconsistent internal spacing.")
    MappingWindowVisualAssert(Abs(aboutX + aboutWidth
                - (clientWidth - MappingWindow.ToolbarRightMargin)) <= 1,
        "The auxiliary command group lost its right-edge alignment.")
}

ReadMappingWindowColumnWidths(window) {
    dpi := DllCall("user32\GetDpiForWindow", "Ptr", window.List.Hwnd,
        "UInt")
    if !dpi
        dpi := 96
    widths := []
    Loop 6
        widths.Push(Round(SendMessage(Win32.LVM_GETCOLUMNWIDTH,
            A_Index - 1, 0, , window.List.Hwnd) * 96 / dpi))
    return {
        Name: widths[MappingWindow.NameColumn],
        Sequence: widths[MappingWindow.SequenceColumn],
        Source: widths[MappingWindow.SourceColumn],
        Target: widths[MappingWindow.TargetColumn],
        Scope: widths[MappingWindow.ScopeColumn],
        Status: widths[MappingWindow.StatusColumn],
        Total: widths[1] + widths[2] + widths[3] + widths[4] + widths[5]
            + widths[6]
    }
}

ReadListViewColumnAlignment(listView, column) {
    columnData := Buffer(A_PtrSize == 8 ? 56 : 44, 0)
    NumPut("UInt", 1, columnData, 0) ; LVCF_FMT
    if !SendMessage(0x105F, column - 1, columnData.Ptr, , listView.Hwnd)
        throw Error("Could not read the ListView column format.")
    return NumGet(columnData, 4, "Int") & 3 ; LVCFMT_JUSTIFYMASK
}

ClickMappingWindowButton(button) {
    point := 8 | (8 << 16)
    SendMessage(Win32.WM_LBUTTONDOWN, 1, point, , button.Hwnd)
    SendMessage(Win32.WM_LBUTTONUP, 0, point, , button.Hwnd)
    Sleep(30)
}

ClickMappingWindowListRow(listView, row) {
    itemRect := Buffer(16, 0)
    NumPut("Int", 0, itemRect, 0) ; LVIR_BOUNDS
    MappingWindowVisualAssert(SendMessage(0x100E, row - 1,
            itemRect.Ptr, , listView.Hwnd),
        "Could not measure the ListView row for a real pointer click.")
    x := Max(8, NumGet(itemRect, 0, "Int") + 12)
    y := (NumGet(itemRect, 4, "Int")
        + NumGet(itemRect, 12, "Int")) // 2
    point := (x & 0xFFFF) | ((y & 0xFFFF) << 16)
    PostMessage(Win32.WM_LBUTTONDOWN, 1, point, , listView.Hwnd)
    PostMessage(Win32.WM_LBUTTONUP, 0, point, , listView.Hwnd)
}

ValidateSelectionRefreshIsolation(window) {
    originalWindowRect := Buffer(16, 0)
    MappingWindowVisualAssert(DllCall("user32\GetWindowRect", "Ptr",
            window.Gui.Hwnd, "Ptr", originalWindowRect, "Int"),
        "The selection-refresh window bounds could not be read.")
    originalWindowX := NumGet(originalWindowRect, 0, "Int")
    originalWindowY := NumGet(originalWindowRect, 4, "Int")
    windowHeight := NumGet(originalWindowRect, 12, "Int") - originalWindowY
    monitor := DllCall("user32\MonitorFromWindow", "Ptr", window.Gui.Hwnd,
        "UInt", 2, "Ptr")
    monitorInfo := Buffer(40, 0)
    NumPut("UInt", 40, monitorInfo, 0)
    MappingWindowVisualAssert(monitor && DllCall("user32\GetMonitorInfoW",
            "Ptr", monitor, "Ptr", monitorInfo, "Int"),
        "The selection-refresh monitor work area could not be read.")
    workBottom := NumGet(monitorInfo, 32, "Int")
    visibleWindowY := Min(originalWindowY, workBottom - windowHeight)
    if visibleWindowY != originalWindowY
        DllCall("user32\SetWindowPos", "Ptr", window.Gui.Hwnd, "Ptr", 0,
            "Int", originalWindowX, "Int", visibleWindowY,
            "Int", 0, "Int", 0, "UInt", 0x0015, "Int")
    window.List.Modify(0, "-Select")
    SetTimer(window.SelectionTimer, 0)
    window.RefreshSelectionState()
    window.SelectionRefreshCount := 0
    window.LayoutCallCount := 0
    window.FullWindowRedrawCount := 0
    rows := [1, 2, 1, 2, 1, 2]
    for row in rows {
        ClickMappingWindowListRow(window.List, row)
        Sleep(30)
        selectedRows := window.GetSelectedRows()
        expectedSource := window.List.GetText(row,
            MappingWindow.SourceColumn)
        expectedTarget := window.List.GetText(row,
            MappingWindow.TargetColumn)
        MappingWindowVisualAssert(selectedRows.Length == 1
                && selectedRows[1] == row
                && InStr(window.Status.Text, expectedSource)
                && InStr(window.Status.Text, expectedTarget),
            "Rapid rule switching did not settle on the current row.")
        MappingWindowVisualAssert(window.SelectionRefreshCount == A_Index,
            Format("One rule click produced duplicate selection refreshes: expected={1}, actual={2}.",
                A_Index, window.SelectionRefreshCount))
        MappingWindowVisualAssert(window.LayoutCallCount == 0
                && window.FullWindowRedrawCount == 0,
            Format("Switching rules refreshed the main-window layout: layout={1}, full={2}.",
                window.LayoutCallCount, window.FullWindowRedrawCount))
    }
    originalSource := window.List.GetText(2, MappingWindow.SourceColumn)
    originalTarget := window.List.GetText(2, MappingWindow.TargetColumn)
    longSource := "Ctrl + Shift + Alt + Win + "
        . "an intentionally oversized selection status value "
        . "that must remain a local status repaint"
    longTarget := "another oversized target value whose wrapping must not "
        . "start a whole-window layout transaction"
    try {
        window.Gui.GetClientPos(, , &clientWidth, &clientHeight)
        longStatusText := Tr("映射 · {1} -> {2}", longSource, longTarget)
        longStatusLayout := window.GetStatusLayout(clientWidth, "",
            longStatusText)
        longStatusY := clientHeight - MappingWindow.StatusBottomMargin
            - longStatusLayout.Height
        window.Status.GetPos(, &baselineStatusY)
        baselineSignature := CaptureMappingWindowOwnDcRegionSignature(
            window.Gui.Hwnd, 10, longStatusY + 1, 620,
            baselineStatusY - 3, 2)
        window.List.Modify(2, "Col" MappingWindow.SourceColumn, longSource)
        window.List.Modify(2, "Col" MappingWindow.TargetColumn, longTarget)
        ClickMappingWindowListRow(window.List, 1)
        Sleep(30)
        window.Status.GetPos(, &statusYBefore, , &statusHeightBefore)
        statusBottomBefore := statusYBefore + statusHeightBefore
        window.SelectionRefreshCount := 0
        window.LayoutCallCount := 0
        window.FullWindowRedrawCount := 0
        ClickMappingWindowListRow(window.List, 2)
        Sleep(30)
        window.Gui.GetClientPos(, , &clientWidth)
        requiredStatusHeight := window.GetStatusLayout(clientWidth).Height
        window.Status.GetPos(, &statusYAfter, , &statusHeightAfter)
        MappingWindowVisualAssert(requiredStatusHeight > statusHeightBefore,
            "The oversized rule did not exercise wrapped status text.")
        MappingWindowVisualAssert(window.SelectionRefreshCount == 1
                && window.LayoutCallCount == 0
                && window.FullWindowRedrawCount == 0
                && statusHeightAfter == requiredStatusHeight
                && statusYAfter + statusHeightAfter == statusBottomBefore,
            Format("A wrapped rule selection refreshed the main-window layout: selection={1}, layout={2}, full={3}, status={4}/{5}, required={6}.",
                window.SelectionRefreshCount, window.LayoutCallCount,
                window.FullWindowRedrawCount, statusHeightBefore,
                statusHeightAfter, requiredStatusHeight))
        ClickMappingWindowListRow(window.List, 1)
        Sleep(30)
        try DllCall("dwmapi\DwmFlush", "Int")
        window.Status.GetPos(, &collapsedStatusY, , &collapsedStatusHeight)
        collapsedSignature := CaptureMappingWindowOwnDcRegionSignature(
            window.Gui.Hwnd, 10, longStatusY + 1, 620,
            collapsedStatusY - 3, 2)
        MappingWindowVisualAssert(collapsedStatusHeight == statusHeightBefore
                && collapsedStatusY + collapsedStatusHeight
                    == statusBottomBefore
                && window.LayoutCallCount == 0
                && window.FullWindowRedrawCount == 0
                && collapsedSignature == baselineSignature,
            "The transient status did not collapse cleanly after selecting a short rule.")
    } finally {
        window.List.Modify(2, "Col" MappingWindow.SourceColumn,
            originalSource)
        window.List.Modify(2, "Col" MappingWindow.TargetColumn,
            originalTarget)
        if visibleWindowY != originalWindowY
            DllCall("user32\SetWindowPos", "Ptr", window.Gui.Hwnd,
                "Ptr", 0, "Int", originalWindowX, "Int", originalWindowY,
                "Int", 0, "Int", 0, "UInt", 0x0015, "Int")
    }
}

AssertMappingWindowButtonPixel(interactions, button, expectedColor, message) {
    rect := Buffer(16, 0)
    MappingWindowVisualAssert(DllCall("user32\GetClientRect", "Ptr",
        button.Hwnd, "Ptr", rect, "Int"),
        "Could not measure a command button.")
    width := NumGet(rect, 8, "Int")
    height := NumGet(rect, 12, "Int")
    x := Max(1, NumGet(rect, 8, "Int") - 10)
    y := NumGet(rect, 12, "Int") // 2
    memoryContext := DllCall("gdi32\CreateCompatibleDC", "Ptr", 0, "Ptr")
    bitmapInfo := Buffer(40, 0)
    NumPut("UInt", 40, bitmapInfo, 0)
    NumPut("Int", width, bitmapInfo, 4)
    NumPut("Int", -height, bitmapInfo, 8)
    NumPut("UShort", 1, bitmapInfo, 12)
    NumPut("UShort", 32, bitmapInfo, 14)
    pixelAddress := 0
    bitmap := memoryContext ? DllCall("gdi32\CreateDIBSection",
        "Ptr", memoryContext, "Ptr", bitmapInfo, "UInt", 0,
        "Ptr*", &pixelAddress, "Ptr", 0, "UInt", 0, "Ptr") : 0
    previousBitmap := bitmap ? DllCall("gdi32\SelectObject", "Ptr",
        memoryContext, "Ptr", bitmap, "Ptr") : 0
    MappingWindowVisualAssert(memoryContext && bitmap && previousBitmap,
        "Could not create an offscreen command-button surface.")
    try {
        state := interactions.Controls[button.Hwnd]
        MappingWindowVisualAssert(interactions.Painter.Draw(memoryContext,
            width, height, state),
            "Could not render a command button offscreen.")
        actualColor := DllCall("gdi32\GetPixel", "Ptr", memoryContext,
            "Int", x, "Int", y, "UInt")
    } finally {
        if previousBitmap
            DllCall("gdi32\SelectObject", "Ptr", memoryContext,
                "Ptr", previousBitmap, "Ptr")
        if bitmap
            DllCall("gdi32\DeleteObject", "Ptr", bitmap, "Int")
        if memoryContext
            DllCall("gdi32\DeleteDC", "Ptr", memoryContext, "Int")
    }
    MappingWindowVisualAssert(actualColor == ColorRef(expectedColor),
        message " Observed=" Format("{1:06X}", actualColor)
            ", expected=" Format("{1:06X}", ColorRef(expectedColor)))
}

AssertMappingWindowDashedDivider(window, message) {
    control := window.SectionTopDivider
    state := window.Interactions.Controls[control.Hwnd]
    rect := Buffer(16, 0)
    MappingWindowVisualAssert(DllCall("user32\GetClientRect", "Ptr",
            control.Hwnd, "Ptr", rect, "Int"),
        message " The divider bounds were unavailable.")
    width := NumGet(rect, 8, "Int")
    height := NumGet(rect, 12, "Int")
    dpi := DllCall("user32\GetDpiForWindow", "Ptr", control.Hwnd, "UInt")
    if !dpi
        dpi := 96
    dashWidth := Max(1, Round(state.DashWidthDip * dpi / 96))
    dashGap := Max(1, Round(state.DashGapDip * dpi / 96))
    dashHeight := Max(1, Round(state.DashHeightDip * dpi / 96))
    lineY := Max(0, Floor((height - dashHeight) / 2))
    dashSampleX := Min(width - 1, Max(0, Floor(dashWidth / 2)))
    gapSampleX := Min(width - 1,
        dashWidth + Max(0, Floor(dashGap / 2)))
    linePixel := CaptureMappingWindowOwnDcPixel(control.Hwnd,
        dashSampleX, lineY)
    gapPixel := CaptureMappingWindowOwnDcPixel(control.Hwnd,
        gapSampleX, lineY)
    MappingWindowVisualAssert(width > dashWidth + dashGap
            && linePixel == ColorRef(state.LineColor)
            && gapPixel == ColorRef(state.BackgroundColor),
        message " line=" Format("{1:06X}", linePixel)
            ", gap=" Format("{1:06X}", gapPixel))
}

ValidateMappingEditorCleanup(window) {
    mapping := {
        Id: "这是一个用于确认编辑窗口能够完整显示超长规则名称而不会回退显示来源按键和映射结果的规则名称，并且在窗口宽度不足时能够自动换行、为后面的代码编辑区域留出稳定间距、不会发生文字裁切或控件重叠的完整回归测试名称",
        Source: "不应出现在标题中的来源按键",
        Target: "不应出现在标题中的映射结果",
        Block: "; @mapping visual-test`nF24::F23",
        StartLine: 1
    }
    editor := MappingBlockEditor(window, mapping)
    window.BlockEditor := editor
    AssertMappingEditorInitialCaret(editor, "the hidden edit-rule editor",
        false)
    editor.Show()
    editor.Title.GetPos(, &titleY, &titleWidth, &titleHeight)
    editor.CodeEdit.GetPos(, &codeY)
    MappingWindowVisualAssert(editor.Title.Text == mapping.Id
            && !InStr(editor.Title.Text, mapping.Source)
            && !InStr(editor.Title.Text, mapping.Target)
            && titleHeight == editor.GetTitleHeight(titleWidth)
            && titleHeight > MappingBlockEditor.TitleMinimumHeight
            && titleY + titleHeight
                + MappingBlockEditor.TitleBottomGap == codeY,
        "The edit-rule title does not show the complete rule name above the editor.")
    AssertMappingEditorInitialCaret(editor, "the visible edit-rule editor")
    MappingWindowVisualAssert(editor.RichEditModule != 0
            && WindowHierarchy.IsOwnerLocked(window.Gui),
        "The mapping editor did not acquire its native resources.")
    ValidateMappingEditorNativeUndo(editor)
    ValidateMappingEditorSingleStepWheel(editor)
    editor.SaveButton.GetPos(, , &editorSaveWidth)
    editor.CancelButton.GetPos(, , &editorCancelWidth)
    editorSaveState := editor.Interactions.Controls[editor.SaveButton.Hwnd]
    editorCancelState := editor.Interactions.Controls[
        editor.CancelButton.Hwnd]
    MappingWindowVisualAssert(editorSaveWidth == 80
            && editorCancelWidth == 80
            && editor.ResolveAiOperation() == "optimize"
            && editor.GetAiPurposeQuestion("optimize")
                == Tr("说点什么吧，我什么都会做的 T_T")
            && editor.AiButton.Text == Tr("AI 优化规则")
            && !editor.HasOwnProp("AiMenu")
            && !editorSaveState.HasOwnProp("ButtonImage")
            && !editorCancelState.HasOwnProp("ButtonImage")
            && editorSaveState.Normal == "3F6B5B",
        "The mapping editor Save/Cancel commands are not compact text buttons.")
    editor.SetAISettingsLink("请先在设置中填写 AI 服务地址。")
    editor.AISettingsLink.GetPos(, , &aiLinkWidth)
    editor.Status.GetPos(, , &aiStatusWidth)
    expectedAiLinkWidth := editor.MeasureControlTextWidth(
        editor.AISettingsLink, editor.AISettingsLink.Text) + 1
    MappingWindowVisualAssert(aiLinkWidth == expectedAiLinkWidth
            && aiLinkWidth < aiStatusWidth,
        "The AI-settings link still occupies the full status row.")
    MappingWindowVisualAssert(!IsControlFontUnderlined(
            editor.AISettingsLink.Hwnd),
        "The AI-settings link is underlined before pointer hover.")
    editor.OnAISettingsLinkMouse(0, 0, Win32.WM_MOUSEMOVE,
        editor.AISettingsLink.Hwnd)
    MappingWindowVisualAssert(editor.AISettingsLinkHovered
            && IsControlFontUnderlined(editor.AISettingsLink.Hwnd),
        "The AI-settings link did not underline on pointer hover.")
    editor.OnAISettingsLinkMouse(0, 0, Win32.WM_MOUSELEAVE,
        editor.AISettingsLink.Hwnd)
    MappingWindowVisualAssert(!editor.AISettingsLinkHovered
            && !IsControlFontUnderlined(editor.AISettingsLink.Hwnd),
        "The AI-settings link kept its underline after pointer leave.")
    editor.Dispose(false)
    MappingWindowVisualAssert(editor.RichEditModule == 0
            && editor.OwnerLease == "" && !IsObject(window.BlockEditor)
            && !WindowHierarchy.IsOwnerLocked(window.Gui),
        "Explicit editor disposal left native resources or its owner lease.")

    editor := MappingBlockEditor(window, mapping)
    window.BlockEditor := editor
    editor.Show()
    editorHwnd := editor.EditorHwnd
    MappingWindowVisualAssert(DllCall("user32\DestroyWindow", "Ptr",
            editorHwnd, "Int") != 0,
        "Could not exercise native mapping-editor destruction.")
    Sleep(30)
    MappingWindowVisualAssert(editor.Disposed && editor.RichEditModule == 0
            && editor.OwnerLease == "" && editor.EditorHwnd == 0
            && !IsObject(window.BlockEditor)
            && !WindowHierarchy.IsOwnerLocked(window.Gui),
        "Native editor destruction left callbacks, resources or its owner lease.")

    editor := MappingBlockEditor(window, mapping)
    window.BlockEditor := editor
    editor.Show()
    codeHwnd := editor.CodeEditHwnd
    MappingWindowVisualAssert(DllCall("user32\DestroyWindow", "Ptr",
            codeHwnd, "Int") != 0,
        "Could not invalidate the editor control during formatting cleanup.")
    MappingWindowVisualAssert(!editor.SetRichTextFont(0, 1,
            editor.CodeFontName, 1) && !editor.ApplyEditorFonts()
            && !editor.RefreshEditorPresentation()
            && !editor.RefreshEditorViewport(),
        "A queued formatting callback used a destroyed RichEdit control.")
    editor.Dispose(false)
    MappingWindowVisualAssert(!IsObject(window.BlockEditor)
            && !WindowHierarchy.IsOwnerLocked(window.Gui),
        "Destroyed-control cleanup leaked the editor owner lease.")
}

ValidateMappingEditorNativeUndo(editor) {
    originalText := editor.Canonicalize(editor.GetCodeText())
    marker := " undo-history-probe"
    selection := Buffer(8, 0)
    textLength := StrLen(originalText)
    NumPut("Int", textLength, selection, 0)
    NumPut("Int", textLength, selection, 4)
    SendMessage(0x0437, 0, selection.Ptr, ,
        editor.CodeEditHwnd) ; EM_EXSETSEL
    DllCall("user32\SendMessageW", "Ptr", editor.CodeEditHwnd,
        "UInt", 0x00C2, "Ptr", 1, "WStr", marker, "Ptr") ; EM_REPLACESEL
    editor.CancelPresentationTimers()
    MappingWindowVisualAssert(editor.RefreshEditorPresentation(),
        "The undo probe could not apply syntax highlighting.")
    editedText := editor.Canonicalize(editor.GetCodeText())
    canUndo := SendMessage(0x00C6, 0, 0, ,
        editor.CodeEditHwnd) ; EM_CANUNDO
    undoResult := SendMessage(0x00C7, 0, 0, ,
        editor.CodeEditHwnd) ; EM_UNDO
    undoneText := editor.Canonicalize(editor.GetCodeText())
    canRedo := SendMessage(0x0455, 0, 0, ,
        editor.CodeEditHwnd) ; EM_CANREDO
    redoResult := editor.HandleCodeEditorShortcut(0x5A,
        true, true, false) == 0
    redoneText := editor.Canonicalize(editor.GetCodeText())
    MappingWindowVisualAssert(editedText == originalText marker
            && canUndo && undoResult && undoneText == originalText
            && canRedo && redoResult && redoneText == editedText,
        "Syntax highlighting polluted the native text undo/redo history.")

    lineStart := InStr(redoneText, "`n", false, -1)
    lineStart := lineStart ? lineStart : 1
    NumPut("Int", StrLen(redoneText), selection, 0)
    NumPut("Int", StrLen(redoneText), selection, 4)
    SendMessage(0x0437, 0, selection.Ptr, , editor.CodeEditHwnd)
    deleteResult := editor.HandleCodeEditorShortcut(0x59,
        true, false, false) == 0
    deletedText := editor.Canonicalize(editor.GetCodeText())
    deleteUndoResult := SendMessage(0x00C7, 0, 0, ,
        editor.CodeEditHwnd)
    restoredText := editor.Canonicalize(editor.GetCodeText())
    MappingWindowVisualAssert(deleteResult
            && deletedText == SubStr(redoneText, 1, lineStart - 1)
            && deleteUndoResult && restoredText == redoneText,
        "Ctrl+Y did not delete the current line as one undoable edit.")

    multiLineText := "first`nsecond`nthird`nfourth"
    editor.ReplaceEditorTextAtomically(multiLineText)
    secondLineStart := StrLen("first`n")
    thirdLineMiddle := StrLen("first`nsecond`nthi")
    NumPut("Int", secondLineStart, selection, 0)
    NumPut("Int", thirdLineMiddle, selection, 4)
    SendMessage(0x0437, 0, selection.Ptr, , editor.CodeEditHwnd)
    editor.HandleCodeEditorShortcut(0x59, true, false, false)
    selectedLinesDeletedText := editor.Canonicalize(editor.GetCodeText())
    selectedLinesUndoResult := SendMessage(0x00C7, 0, 0, ,
        editor.CodeEditHwnd)
    selectedLinesRestoredText := editor.Canonicalize(editor.GetCodeText())
    MappingWindowVisualAssert(selectedLinesDeletedText == "first`nfourth"
            && selectedLinesUndoResult
            && selectedLinesRestoredText == multiLineText,
        "Ctrl+Y did not delete all selected lines as one undoable edit.")
}

IsControlFontUnderlined(hwnd) {
    fontHandle := SendMessage(Win32.WM_GETFONT, 0, 0, , hwnd)
    if !fontHandle
        return false
    logFont := Buffer(92, 0)
    if DllCall("gdi32\GetObjectW", "Ptr", fontHandle, "Int", logFont.Size,
            "Ptr", logFont, "Int") <= 0
        return false
    return NumGet(logFont, 21, "UChar") != 0
}

ValidateMappingEditorTemplatePresentation(window) {
    managedText := window.App.Repository.CreateBlankEditorText("managed")
    repositoryProbe := MappingCodeRepository(
        A_Temp "\kmra-editor-template-probe.ahk")
    blankScriptCode := repositoryProbe.CreateBlankScriptCode()
    MappingWindowVisualAssert(blankScriptCode
            == ScriptRuleCompiler.ScriptCodePlaceholder
            && !InStr(blankScriptCode, "#Requires"),
        "The repository script template still contains concrete code.")
    mapping := {Id: "", Source: "", Target: "", Mode: "managed",
        Block: managedText, EditorText: managedText, StartLine: 1}
    editor := MappingBlockEditor(window, mapping, true, (*) => true)
    window.BlockEditor := editor
    try {
        editor.Show()
        ValidateMappingEditorTaskbarRestore(editor, window)
        MappingWindowVisualAssert(
                editor.ManagedModeButton.Text == Tr("规则块")
                && editor.ScriptModeButton.Text
                    == Tr("受托管脚本"),
            "The mapping modes still expose internal implementation names.")
        AssertMappingEditorCodeLayout(editor, "managed editor")
        MappingWindowVisualAssert(InStr(managedText,
                "; @名称=<请填写规则名称>")
                && InStr(managedText,
                    "; <请在这里填写 RuleSpec JSON>")
                && !InStr(managedText, "F24")
                && !InStr(managedText, "F23"),
            "The managed template still contains a concrete example rule.")
        switchResult := editor.SwitchEditorMode("script")
        MappingWindowVisualAssert(switchResult,
            Format("The focused editor test could not switch to script mode: mode={1}, dirty={2}, status={3}, revision={4}/{5}.",
                editor.EditorMode, editor.IsDirty(), editor.Status.Text,
                editor.LastFormattedRevision, editor.EditorRevision))
        scriptText := editor.Canonicalize(editor.GetCodeText())
        AssertMappingEditorCodeLayout(editor, "script editor")
        MappingWindowVisualAssert(InStr(scriptText,
                ";  <请在这里编写完整的 AHK v2 脚本>")
                && !InStr(scriptText, "#Requires"),
            "The script template still contains concrete AHK code.")
        placeholderStart := InStr(scriptText,
            ScriptRuleCompiler.ScriptCodePlaceholder, true) - 1
        placeholderColor := MappingWindowReadRichEditColor(
            editor.CodeEditHwnd, placeholderStart,
            placeholderStart + StrLen(ScriptRuleCompiler.ScriptCodePlaceholder))
        MappingWindowVisualAssert(placeholderColor
                == ColorRef(MappingWindow.Colors.CodeOperator)
                && editor.LastFormattedRevision == editor.EditorRevision,
            Format("The script template became visible before syntax formatting completed: color={1:X}/{2:X}, revision={3}/{4}.",
                placeholderColor, ColorRef(MappingWindow.Colors.CodeOperator),
                editor.LastFormattedRevision, editor.EditorRevision))
        MappingWindowVisualAssert(editor.SwitchEditorMode("managed"),
            "The focused editor test could not switch back to managed mode.")
        restoredText := editor.Canonicalize(editor.GetCodeText())
        metadataStart := InStr(restoredText, "; @名称", true) - 1
        MappingWindowVisualAssert(MappingWindowReadRichEditColor(
                editor.CodeEditHwnd, metadataStart,
                metadataStart + StrLen("; @名称"))
                == ColorRef(MappingWindow.Colors.CodeVariable)
                && editor.LastFormattedRevision == editor.EditorRevision,
            "The managed template became visible before syntax formatting completed.")
    } finally editor.Dispose(false)
    MappingWindowVisualAssert(!IsObject(window.BlockEditor)
            && !WindowHierarchy.IsOwnerLocked(window.Gui),
        "The focused mapping-editor test leaked its owner lease.")
}

ValidateMappingEditorTaskbarRestore(editor, ownerWindow) {
    childHwnd := editor.Gui.Hwnd
    ownerHwnd := ownerWindow.Gui.Hwnd
    style := DllCall("user32\GetWindowLongPtrW", "Ptr", childHwnd,
        "Int", Win32.GWL_STYLE, "Ptr")
    originalExtendedStyle := DllCall("user32\GetWindowLongPtrW",
        "Ptr", childHwnd, "Int", Win32.GWL_EXSTYLE, "Ptr")
    MappingWindowVisualAssert(style & Win32.WS_MINIMIZEBOX,
        "The mapping editor does not expose a minimize button.")
    MappingWindowVisualAssert(WindowHierarchy.MinimizeChildIndependently(
            childHwnd),
        "The mapping editor could not be minimized independently.")
    Sleep(50)
    minimizedExtendedStyle := DllCall("user32\GetWindowLongPtrW",
        "Ptr", childHwnd, "Int", Win32.GWL_EXSTYLE, "Ptr")
    suspendedState := WindowHierarchy.Manager.OwnerLocks[ownerHwnd]
        .SuspendedChildren[childHwnd]
    nativeOwner := DllCall("user32\GetWindowLongPtrW", "Ptr", childHwnd,
        "Int", Win32.GWLP_HWNDPARENT, "Ptr")
    MappingWindowVisualAssert(DllCall("user32\IsIconic", "Ptr", childHwnd,
            "Int") && nativeOwner == 0
            && (minimizedExtendedStyle & Win32.WS_EX_APPWINDOW)
            && !(minimizedExtendedStyle & Win32.WS_EX_TOOLWINDOW)
            && suspendedState.TaskbarRegistered
            && DllCall("user32\IsWindowEnabled", "Ptr", ownerHwnd, "Int"),
        "The minimized mapping editor did not acquire a taskbar identity.")
    DllCall("user32\ShowWindow", "Ptr", ownerHwnd,
        "Int", Win32.SW_MINIMIZE, "Int")
    MappingWindowVisualAssert(DllCall("user32\IsIconic", "Ptr", ownerHwnd,
            "Int"),
        "The mapping editor restore test could not minimize its owner.")
    restoreResult := WindowHierarchy.RestoreChildFromTaskbar(childHwnd)
    restoredOwnerProbe := DllCall("user32\GetWindowLongPtrW", "Ptr",
        childHwnd, "Int", Win32.GWLP_HWNDPARENT, "Ptr")
    ownerEntry := WindowHierarchy.Manager.OwnerLocks[ownerHwnd]
    MappingWindowVisualAssert(restoreResult,
        Format("The taskbar could not restore the mapping editor: iconic={1}, visible={2}, owner={3}, suspended={4}.",
            DllCall("user32\IsIconic", "Ptr", childHwnd, "Int"),
            DllCall("user32\IsWindowVisible", "Ptr", childHwnd, "Int"),
            restoredOwnerProbe,
            ownerEntry.SuspendedChildren.Has(childHwnd)))
    Sleep(50)
    restoredExtendedStyle := DllCall("user32\GetWindowLongPtrW",
        "Ptr", childHwnd, "Int", Win32.GWL_EXSTYLE, "Ptr")
    nativeOwner := DllCall("user32\GetWindowLongPtrW", "Ptr", childHwnd,
        "Int", Win32.GWLP_HWNDPARENT, "Ptr")
    MappingWindowVisualAssert(!DllCall("user32\IsIconic", "Ptr", childHwnd,
            "Int") && DllCall("user32\IsWindowVisible", "Ptr", childHwnd,
            "Int") && nativeOwner == ownerHwnd
            && !DllCall("user32\IsIconic", "Ptr", ownerHwnd, "Int")
            && DllCall("user32\IsWindowVisible", "Ptr", ownerHwnd, "Int")
            && restoredExtendedStyle == originalExtendedStyle
            && !DllCall("user32\IsWindowEnabled", "Ptr", ownerHwnd,
                "Int"),
        "The mapping editor taskbar restore did not rebuild its owner state.")

    DllCall("user32\ShowWindow", "Ptr", childHwnd,
        "Int", Win32.SW_HIDE, "Int")
    DllCall("user32\ShowWindow", "Ptr", ownerHwnd,
        "Int", Win32.SW_MINIMIZE, "Int")
    MappingWindowVisualAssert(!DllCall("user32\IsWindowVisible",
            "Ptr", childHwnd, "Int")
            && DllCall("user32\IsIconic", "Ptr", ownerHwnd, "Int")
            && ownerWindow.Activate()
            && DllCall("user32\IsWindowVisible", "Ptr", childHwnd, "Int")
            && !DllCall("user32\IsIconic", "Ptr", ownerHwnd, "Int"),
        "The main-window entry could not recover a hidden modal editor.")
}

ValidateNewMappingEditorModes(window) {
    managedText := window.App.Repository.CreateBlankEditorText("managed")
    mapping := {Id: "", Source: "", Target: "", Mode: "managed",
        Block: managedText, EditorText: managedText, StartLine: 1}
    aiReviewProbe := MappingWindowAiReviewProbe()
    purposePromptProbe := MappingWindowAiPurposePromptProbe(
        "让 CapsLock 配合方向键移动光标")
    editor := MappingBlockEditor(window, mapping, true, (*) => true,
        ObjBindMethod(purposePromptProbe, "Prompt"),
        ObjBindMethod(aiReviewProbe, "Review"))
    window.BlockEditor := editor
    AssertMappingEditorInitialCaret(editor, "the hidden add-rule editor",
        false)
    editor.Show()
    AssertMappingEditorInitialCaret(editor, "the visible add-rule editor")
    editor.AiButton.GetPos(, , &aiButtonWidth)
    editor.SaveButton.GetPos(, , &saveButtonWidth)
    aiButtonState := editor.Interactions.Controls[editor.AiButton.Hwnd]
    purposeResult := editor.PromptForAiPurpose("generate")
    MappingWindowVisualAssert(aiButtonWidth == MappingBlockEditor.AIButtonWidth
            && aiButtonWidth == 144
            && aiButtonWidth > saveButtonWidth
            && editor.AiButton.Text == Tr("AI 生成规则")
            && MappingBlockEditor.EditorWidth == 780
            && MappingBlockEditor.EditorHeight == 560
            && MappingBlockEditor.EditorMinimumWidth == 640
            && MappingBlockEditor.EditorMinimumHeight == 440
            && purposeResult.Accepted
            && purposeResult.Value == "让 CapsLock 配合方向键移动光标"
            && purposePromptProbe.LastInitialValue == ""
            && editor.AiPurposeRetryText
                == "让 CapsLock 配合方向键移动光标"
            && editor.GetAiPurposeQuestion("generate")
                == Tr("我是来帮你的，你要干什么？！")
            && editor.ResolveAiOperation() == "generate"
            && editor.ResolveAiRequestMode("generate") == "auto"
            && !editor.HasOwnProp("AiMenu")
            && aiButtonState.Normal == MappingWindow.Colors.AIButton
            && aiButtonState.TextColor == MappingWindow.Colors.AIButtonText
            && aiButtonState.HasOwnProp("ButtonImage")
            && aiButtonState.ButtonImage.TintColor
                == MappingWindow.Colors.AIIcon,
        Format("The contextual AI button is incorrect: width={1}/{2}, save={3}, text={4}/{5}, operation={6}, normal={7}/{8}, textColor={9}/{10}.",
            aiButtonWidth, MappingBlockEditor.AIButtonWidth,
            saveButtonWidth, editor.AiButton.Text, Tr("AI 生成规则"),
            editor.ResolveAiOperation(), aiButtonState.Normal,
            MappingWindow.Colors.AIButton, aiButtonState.TextColor,
            MappingWindow.Colors.AIButtonText))
    generatedSpec := Map("id", "visual-ai-generated",
        "display", Map("source", "F24", "target", "F23",
            "scope", "全局"),
        "from", Map("key", Map("name", "F24")),
        "to", [Map("type", "send", "value", "{F23}")])
    normalizedAiText := editor.NormalizeAiRule(
        RuleCompiler.BuildManagedBlock(generatedSpec))
    MappingWindowVisualAssert(IsObject(
            RuleCompiler.ParseManagedSpec(normalizedAiText)),
        "The AI result path did not normalize a digest-free rule locally.")
    looseManagedText := MappingWindowMakeLooseAiBlock(
        RuleCompiler.BuildManagedBlock(generatedSpec, "`n"))
    looseManagedResult := editor.NormalizeAiRuleResult(looseManagedText)
    MappingWindowVisualAssert(looseManagedResult.Mode == "managed"
            && RuleCompiler.ParseManagedSpec(looseManagedResult.Text)["id"]
                == "visual-ai-generated",
        "The AI result path did not repair loose markers, metadata, or JSON prefixes.")
    generatedScriptSpec := Map("id", "visual-ai-script",
        "display", Map("source", "F22", "target", "复杂脚本逻辑",
            "scope", "全局"),
        "code", "F22::MsgBox('AI script')")
    normalizedAiScript := editor.NormalizeAiRuleResult(
        ScriptRuleCompiler.BuildBlock(generatedScriptSpec))
    MappingWindowVisualAssert(normalizedAiScript.Mode == "script"
            && IsObject(ScriptRuleCompiler.ParseSpec(normalizedAiScript.Text)),
        "The unified AI result path did not detect a generated script.")
    looseScriptText := MappingWindowMakeLooseAiBlock(
        ScriptRuleCompiler.BuildBlock(generatedScriptSpec, "`n"), true)
    looseScriptResult := editor.NormalizeAiRuleResult(looseScriptText)
    MappingWindowVisualAssert(looseScriptResult.Mode == "script"
            && ScriptRuleCompiler.ParseSpec(looseScriptResult.Text)["code"]
                == generatedScriptSpec["code"],
        "The AI result path did not repair loose script markers, type, or source prefixes.")
    aiPunctuationName := "窗口<>:" Chr(34) "/\|?*规则."
    punctuationAiSpec := RuleSpec.Clone(generatedSpec)
    punctuationAiSpec["id"] := aiPunctuationName
    normalizedPunctuationAiText := editor.NormalizeAiRule(
        RuleCompiler.BuildManagedBlock(punctuationAiSpec))
    MappingWindowVisualAssert(
            RuleCompiler.ParseManagedSpec(normalizedPunctuationAiText)["id"]
                == aiPunctuationName,
        "The AI result path still rejects file-name punctuation in rule names.")
    repairableAiSpec := RuleSpec.Clone(generatedSpec)
    repairableAiSpec["enabled"] := "true"
    repairableAiSpec["priority"] := "2"
    repairableAiSpec["from"]["key"] := "F24"
    repairableAiSpec["from"]["modifiers"] := "Ctrl"
    repairableAiSpec["from"]["optional_modifiers"] := "any"
    repairableAiSpec["conditions"] := Map("type", "all",
        "conditions", Map("type", "application", "field", "process",
            "operator", "in", "value", "notepad.exe"))
    repairableAiSpec["to"] := Map("type", "send", "value", "{F23}")
    repairableAiSpec["timing"] := Map("held_threshold_ms", "250")
    repairableAiBlock := MappingWindowReplaceManagedSpecBody(
        RuleCompiler.BuildManagedBlock(generatedSpec, "`n"),
        repairableAiSpec)
    indentedAiBlock := "  " StrReplace(repairableAiBlock, "`n", "`n  ")
    wrappedAiBlock := JsonCodec.Stringify(Map("content", indentedAiBlock),
        false, false)
    repairedAiResult := editor.NormalizeAiRuleResult(wrappedAiBlock)
    repairedAiSpec := RuleCompiler.ParseManagedSpec(repairedAiResult.Text)
    MappingWindowVisualAssert(repairedAiResult.Mode == "managed"
            && repairedAiSpec["priority"] == 2
            && Type(repairedAiSpec["from"]["key"]) == "Map"
            && repairedAiSpec["from"]["key"]["name"] == "F24"
            && Type(repairedAiSpec["from"]["modifiers"]) == "Array"
            && repairedAiSpec["from"]["modifiers"][1] == "Ctrl"
            && Type(repairedAiSpec["from"]["optional_modifiers"])
                == "Array"
            && repairedAiSpec["from"]["optional_modifiers"][1] == "any"
            && Type(repairedAiSpec["to"]) == "Array"
            && Type(repairedAiSpec["conditions"]) == "Array"
            && Type(repairedAiSpec["conditions"][1]["conditions"])
                == "Array"
            && Type(repairedAiSpec["conditions"][1]["conditions"][1]["value"])
                == "Array"
            && repairedAiSpec["timing"]["held_threshold_ms"] == 250,
        "The AI result path did not repair unambiguous JSON shape errors.")
    embeddedMetadataAiBlock := MappingWindowReplaceManagedSpecBody(
        RuleCompiler.BuildManagedBlock(generatedSpec, "`n"), generatedSpec,
        true)
    embeddedMetadataAiResult := editor.NormalizeAiRuleResult(
        embeddedMetadataAiBlock)
    MappingWindowVisualAssert(
            RuleCompiler.ParseManagedSpec(embeddedMetadataAiResult.Text)["id"]
                == generatedSpec["id"],
        "The AI result path did not remove matching embedded metadata.")
    comprehensiveAiSpec := RuleSpec.Clone(generatedSpec)
    comprehensiveAiSpec.Delete("from")
    comprehensiveAiSpec["from"] := Map("code", "KeyA",
        "modifiers", "Ctrl + Shift", "event", "DOWN")
    comprehensiveAiSpec.Delete("to")
    comprehensiveAiSpec["actions"] := Map("type", "Delay",
        "durationMs", "150", "repeat", "Once", "repeatIntervalMs", "0")
    comprehensiveAiSpec["condition"] := Map("type", "All",
        "condition", [
            Map("type", "application", "field", "PROCESS",
                "operator", "==", "value", "notepad.exe"),
            Map("type", "window", "field", "TITLE",
                "operator", "not exists", "value", JsonNull(),
                "caseSensitive", "false")])
    comprehensiveAiSpec["heldThresholdMs"] := "300"
    comprehensiveAiBlock := MappingWindowReplaceManagedSpecBody(
        RuleCompiler.BuildManagedBlock(generatedSpec, "`n"),
        comprehensiveAiSpec)
    comprehensiveAiResult := editor.NormalizeAiRuleResult(
        comprehensiveAiBlock)
    comprehensiveSpec := RuleCompiler.ParseManagedSpec(
        comprehensiveAiResult.Text)
    comprehensiveConditions := comprehensiveSpec["conditions"][1][
        "conditions"]
    MappingWindowVisualAssert(
            comprehensiveSpec["from"]["key"]["name"] == "A"
            && comprehensiveSpec["from"]["modifiers"].Length == 2
            && comprehensiveSpec["from"]["modifiers"][1] == "Ctrl"
            && comprehensiveSpec["from"]["modifiers"][2] == "Shift"
            && comprehensiveSpec["to"][1]["type"] == "sleep"
            && comprehensiveSpec["to"][1]["value"] == "150"
            && comprehensiveSpec["to"][1]["repeat"] == "once"
            && !comprehensiveSpec["to"][1].Has("repeat_interval_ms")
            && comprehensiveConditions[1]["field"] == "process"
            && !comprehensiveConditions[1].Has("operator")
            && comprehensiveConditions[2]["operator"] == "not_exists"
            && !comprehensiveConditions[2].Has("value")
            && !comprehensiveConditions[2].Has("case_sensitive")
            && comprehensiveSpec["timing"]["held_threshold_ms"] == 300,
        "The AI result path did not normalize the comprehensive managed-rule boundary fixture.")
    duplicateAliasAiSpec := RuleSpec.Clone(generatedSpec)
    duplicateAliasAiSpec["stopProcessing"] := "true"
    duplicateAliasAiSpec["stop_processing"] := JsonBoolean(true)
    duplicateAliasAiSpec["heldThresholdMs"] := "250"
    duplicateAliasAiSpec["timing"] := Map("held_threshold_ms", 250,
        "heldThresholdMs", "250")
    duplicateAliasAiSpec["from"]["event"] := "down"
    duplicateAliasAiSpec["from"]["key"]["event"] := "DOWN"
    duplicateAliasAiSpec["from"]["key"]["keyName"] := "F24"
    duplicateAliasAiSpec["to"][1]["repeatIntervalMs"] := "0"
    duplicateAliasAiSpec["to"][1]["repeat_interval_ms"] := 0
    duplicateAliasAiBlock := MappingWindowReplaceManagedSpecBody(
        RuleCompiler.BuildManagedBlock(generatedSpec, "`n"),
        duplicateAliasAiSpec)
    duplicateAliasAiResult := editor.NormalizeAiRuleResult(
        duplicateAliasAiBlock)
    duplicateAliasSpec := RuleCompiler.ParseManagedSpec(
        duplicateAliasAiResult.Text)
    MappingWindowVisualAssert(
            duplicateAliasSpec["from"]["key"]["name"] == "F24"
            && !duplicateAliasSpec["from"]["key"].Has("event")
            && duplicateAliasSpec["timing"]["held_threshold_ms"] == 250
            && !duplicateAliasSpec["to"][1].Has("repeat_interval_ms"),
        "Equivalent canonical and aliased AI fields were not collapsed safely.")
    simultaneousStringAiSpec := RuleSpec.Clone(generatedSpec)
    simultaneousStringAiSpec["from"] := Map(
        "simultaneous", "Ctrl + KeyK")
    simultaneousStringAiBlock := MappingWindowReplaceManagedSpecBody(
        RuleCompiler.BuildManagedBlock(generatedSpec, "`n"),
        simultaneousStringAiSpec)
    simultaneousStringAiResult := editor.NormalizeAiRuleResult(
        simultaneousStringAiBlock)
    simultaneousStringSpec := RuleCompiler.ParseManagedSpec(
        simultaneousStringAiResult.Text)
    MappingWindowVisualAssert(
            simultaneousStringSpec["from"]["simultaneous"].Length == 2
            && simultaneousStringSpec["from"]["simultaneous"][1]["name"]
                == "Ctrl"
            && simultaneousStringSpec["from"]["simultaneous"][2]["name"]
                == "K",
        "The AI result path did not normalize a delimited simultaneous source.")
    shorthandConditionAiSpec := RuleSpec.Clone(generatedSpec)
    shorthandConditionAiSpec["conditions"] := [
        Map("type", "application", "application", "notepad.exe"),
        Map("window", Map("title", "编辑器", "class", "Notepad")),
        Map("type", "session", "state", "unlocked")]
    shorthandConditionAiBlock := MappingWindowReplaceManagedSpecBody(
        RuleCompiler.BuildManagedBlock(generatedSpec, "`n"),
        shorthandConditionAiSpec)
    shorthandConditionAiResult := editor.NormalizeAiRuleResult(
        shorthandConditionAiBlock)
    shorthandConditionSpec := RuleCompiler.ParseManagedSpec(
        shorthandConditionAiResult.Text)
    shorthandConditions := shorthandConditionSpec["conditions"]
    MappingWindowVisualAssert(
            shorthandConditions[1]["type"] == "application"
            && shorthandConditions[1]["field"] == "process"
            && shorthandConditions[1]["value"] == "notepad.exe"
            && shorthandConditions[2]["type"] == "all"
            && shorthandConditions[2]["conditions"].Length == 2
            && shorthandConditions[2]["conditions"][1]["type"] == "window"
            && shorthandConditions[2]["conditions"][1]["field"] == "title"
            && shorthandConditions[2]["conditions"][2]["field"] == "class"
            && shorthandConditions[3]["type"] == "session"
            && shorthandConditions[3]["field"] == "state"
            && shorthandConditions[3]["value"] == "unlocked",
        "The AI result path did not normalize unambiguous condition shorthands.")
    misplacedSourceAiSpec := RuleSpec.Clone(generatedSpec)
    misplacedSourceAiSpec["from"]["key"]["event"] := "up"
    misplacedSourceAiSpec["from"]["key"]["repeat"] := "ignore"
    misplacedSourceAiSpec["from"]["key"]["modifiers"] := []
    misplacedSourceAiSpec["from"]["key"]["optional_modifiers"] := []
    misplacedSourceAiSpec["from"]["key"]["tap_count"] := "1"
    misplacedSourceAiBlock := MappingWindowReplaceManagedSpecBody(
        RuleCompiler.BuildManagedBlock(generatedSpec, "`n"),
        misplacedSourceAiSpec)
    misplacedSourceAiResult := editor.NormalizeAiRuleResult(
        misplacedSourceAiBlock)
    misplacedSourceSpec := RuleCompiler.ParseManagedSpec(
        misplacedSourceAiResult.Text)
    MappingWindowVisualAssert(
            misplacedSourceSpec["from"]["event"] == "up"
            && misplacedSourceSpec["from"]["repeat"] == "ignore"
            && !misplacedSourceSpec["from"]["key"].Has("event")
            && !misplacedSourceSpec["from"]["key"].Has("repeat")
            && !misplacedSourceSpec["from"]["key"].Has("modifiers")
            && !misplacedSourceSpec["from"]["key"].Has(
                "optional_modifiers")
            && !misplacedSourceSpec["from"]["key"].Has("tap_count"),
        "The AI result path did not hoist misplaced source fields out of from.key.")
    shorthandActionAiSpec := RuleSpec.Clone(generatedSpec)
    shorthandActionAiSpec["to"] := [
        Map("send", "{ArrowDown}"),
        Map("key_down", "ArrowUp"),
        Map("key_up", "ArrowUp"),
        Map("text", "hello"),
        Map("mouse", "Move 10 20"),
        Map("app_command", "VolumeUp"),
        Map("type", "sleep", "sleep", "125"),
        Map("window_minimize", JsonBoolean(true)),
        Map("window_close", JsonNull()),
        Map("lock_workstation", Map())]
    shorthandActionAiBlock := MappingWindowReplaceManagedSpecBody(
        RuleCompiler.BuildManagedBlock(generatedSpec, "`n"),
        shorthandActionAiSpec)
    shorthandActionAiResult := editor.NormalizeAiRuleResult(
        shorthandActionAiBlock)
    shorthandActions := RuleCompiler.ParseManagedSpec(
        shorthandActionAiResult.Text)["to"]
    MappingWindowVisualAssert(shorthandActions.Length == 10
            && shorthandActions[1]["type"] == "send"
            && shorthandActions[1]["value"] == "{Down}"
            && shorthandActions[2]["type"] == "key_down"
            && shorthandActions[2]["value"] == "Up"
            && shorthandActions[3]["type"] == "key_up"
            && shorthandActions[3]["value"] == "Up"
            && shorthandActions[4]["type"] == "text"
            && shorthandActions[5]["type"] == "mouse"
            && shorthandActions[6]["type"] == "app_command"
            && shorthandActions[7]["type"] == "sleep"
            && shorthandActions[7]["value"] == "125"
            && shorthandActions[8]["type"] == "window_minimize"
            && shorthandActions[9]["type"] == "window_close"
            && shorthandActions[10]["type"] == "lock_workstation",
        "The AI result path did not normalize supported action shorthands.")
    aliasedKeyAiSpec := RuleSpec.Clone(generatedSpec)
    aliasedKeyAiSpec["from"]["key"] := Map("name",
        "Ctrl + ArrowUp")
    aliasedKeyAiBlock := MappingWindowReplaceManagedSpecBody(
        RuleCompiler.BuildManagedBlock(generatedSpec, "`n"),
        aliasedKeyAiSpec)
    aliasedKeyAiResult := editor.NormalizeAiRuleResult(aliasedKeyAiBlock)
    aliasedKeySpec := RuleCompiler.ParseManagedSpec(aliasedKeyAiResult.Text)
    MappingWindowVisualAssert(
            aliasedKeySpec["from"]["key"]["name"] == "Up"
            && aliasedKeySpec["from"]["modifiers"].Length == 1
            && aliasedKeySpec["from"]["modifiers"][1] == "Ctrl",
        "The AI result path did not split and normalize a web-style key chord.")
    simultaneousChordAiSpec := RuleSpec.Clone(generatedSpec)
    simultaneousChordAiSpec["from"]["key"] := Map("name",
        "CapsLock + KeyI")
    simultaneousChordAiBlock := MappingWindowReplaceManagedSpecBody(
        RuleCompiler.BuildManagedBlock(generatedSpec, "`n"),
        simultaneousChordAiSpec)
    simultaneousChordResult := editor.NormalizeAiRuleResult(
        simultaneousChordAiBlock)
    simultaneousChordSpec := RuleCompiler.ParseManagedSpec(
        simultaneousChordResult.Text)
    MappingWindowVisualAssert(
            !simultaneousChordSpec["from"].Has("key")
            && simultaneousChordSpec["from"]["simultaneous"].Length == 2
            && simultaneousChordSpec["from"]["simultaneous"][1]["name"]
                == "CapsLock"
            && simultaneousChordSpec["from"]["simultaneous"][2]["name"]
                == "I",
        "The AI result path did not convert a non-modifier chord to simultaneous keys.")
    wheelAliasAiSpec := RuleSpec.Clone(generatedSpec)
    wheelAliasAiSpec["from"]["key"] := Map("name", "MouseWheelUp")
    wheelAliasAiBlock := MappingWindowReplaceManagedSpecBody(
        RuleCompiler.BuildManagedBlock(generatedSpec, "`n"),
        wheelAliasAiSpec)
    wheelAliasResult := editor.NormalizeAiRuleResult(wheelAliasAiBlock)
    wheelAliasSpec := RuleCompiler.ParseManagedSpec(wheelAliasResult.Text)
    MappingWindowVisualAssert(
            wheelAliasSpec["from"]["key"]["name"] == "WheelUp"
            && wheelAliasSpec["from"]["key"]["kind"] == "wheel",
        "The AI result path did not normalize a mouse-wheel key alias.")
    simultaneousAliasAiSpec := RuleSpec.Clone(generatedSpec)
    simultaneousAliasAiSpec["from"].Delete("key")
    simultaneousAliasAiSpec["from"]["simultaneous"] := [
        "ArrowLeft", "ArrowRight"]
    simultaneousAliasAiBlock := MappingWindowReplaceManagedSpecBody(
        RuleCompiler.BuildManagedBlock(generatedSpec, "`n"),
        simultaneousAliasAiSpec)
    simultaneousAliasResult := editor.NormalizeAiRuleResult(
        simultaneousAliasAiBlock)
    simultaneousAliasSpec := RuleCompiler.ParseManagedSpec(
        simultaneousAliasResult.Text)
    MappingWindowVisualAssert(
            simultaneousAliasSpec["from"]["simultaneous"][1]["name"]
                == "Left"
            && simultaneousAliasSpec["from"]["simultaneous"][2]["name"]
                == "Right",
        "The AI result path did not normalize aliases in a simultaneous source.")
    actionAliasAiSpec := RuleSpec.Clone(generatedSpec)
    actionAliasAiSpec["to"] := [
        Map("type", "send", "value", "^{ArrowDown}"),
        Map("type", "key_down", "value", "ArrowUp"),
        Map("type", "key_up", "value", "ArrowUp")]
    actionAliasAiBlock := MappingWindowReplaceManagedSpecBody(
        RuleCompiler.BuildManagedBlock(generatedSpec, "`n"),
        actionAliasAiSpec)
    actionAliasResult := editor.NormalizeAiRuleResult(actionAliasAiBlock)
    actionAliasSpec := RuleCompiler.ParseManagedSpec(actionAliasResult.Text)
    MappingWindowVisualAssert(
            actionAliasSpec["to"][1]["value"] == "^{Down}"
            && actionAliasSpec["to"][2]["value"] == "Up"
            && actionAliasSpec["to"][3]["value"] == "Up",
        "The AI result path did not normalize aliases in output actions.")
    ambiguousAiSpec := RuleSpec.Clone(generatedSpec)
    ambiguousAiSpec["from"]["modifiers"] := 42
    ambiguousAiBlock := MappingWindowReplaceManagedSpecBody(
        RuleCompiler.BuildManagedBlock(generatedSpec, "`n"), ambiguousAiSpec)
    ambiguousAiRejected := false
    try editor.NormalizeAiRuleResult(ambiguousAiBlock)
    catch
        ambiguousAiRejected := true
    conflictingSourceAiSpec := RuleSpec.Clone(generatedSpec)
    conflictingSourceAiSpec["from"]["event"] := "down"
    conflictingSourceAiSpec["from"]["key"]["event"] := "up"
    conflictingSourceAiBlock := MappingWindowReplaceManagedSpecBody(
        RuleCompiler.BuildManagedBlock(generatedSpec, "`n"),
        conflictingSourceAiSpec)
    conflictingSourceAiRejected := false
    try editor.NormalizeAiRuleResult(conflictingSourceAiBlock)
    catch
        conflictingSourceAiRejected := true
    conflictingActionAiSpec := RuleSpec.Clone(generatedSpec)
    conflictingActionAiSpec["to"] := [Map("type", "sleep",
        "value", 100, "sleep", 200)]
    conflictingActionAiBlock := MappingWindowReplaceManagedSpecBody(
        RuleCompiler.BuildManagedBlock(generatedSpec, "`n"),
        conflictingActionAiSpec)
    conflictingActionAiRejected := false
    try editor.NormalizeAiRuleResult(conflictingActionAiBlock)
    catch
        conflictingActionAiRejected := true
    conflictingEmbeddedAiSpec := RuleSpec.Clone(generatedSpec)
    conflictingEmbeddedAiSpec["id"] := "conflicting-embedded-name"
    conflictingEmbeddedAiBlock := MappingWindowReplaceManagedSpecBody(
        RuleCompiler.BuildManagedBlock(generatedSpec, "`n"),
        conflictingEmbeddedAiSpec, true)
    conflictingEmbeddedAiRejected := false
    try editor.NormalizeAiRuleResult(conflictingEmbeddedAiBlock)
    catch
        conflictingEmbeddedAiRejected := true
    duplicateAiBlocksRejected := false
    try editor.NormalizeAiRuleResult(normalizedAiText "`n" normalizedAiText)
    catch
        duplicateAiBlocksRejected := true
    invalidKeyAiSpec := RuleSpec.Clone(generatedSpec)
    invalidKeyAiSpec["from"]["key"] := Map("name", "DefinitelyNotAKey")
    invalidKeyAiBlock := MappingWindowReplaceManagedSpecBody(
        RuleCompiler.BuildManagedBlock(generatedSpec, "`n"), invalidKeyAiSpec)
    invalidKeyMessage := ""
    try editor.NormalizeAiRuleResult(invalidKeyAiBlock)
    catch as invalidKeyError
        invalidKeyMessage := invalidKeyError.Message
    MappingWindowVisualAssert(ambiguousAiRejected
            && conflictingSourceAiRejected
            && conflictingActionAiRejected
            && conflictingEmbeddedAiRejected
            && duplicateAiBlocksRejected
            && InStr(invalidKeyMessage, "DefinitelyNotAKey"),
        "The AI result path accepted ambiguous data, multiple blocks, or hid the invalid key name.")
    originalAiText := editor.GetCodeText()
    editor.AiRequestId := 700
    editor.AiRequestRevision := editor.EditorRevision
    editor.AiRepairAttempts := MappingBlockEditor.AIMaximumRepairAttempts
    MappingWindowVisualAssert(!editor.HandleAiResult(true, "",
            "AI returned prose instead of a rule block.", 700)
            && editor.GetCodeText() == originalAiText
            && aiReviewProbe.CallCount == 0
            && editor.StatusIsError
            && InStr(editor.Status.Text, Tr("已保留原内容，AI 结果未应用。")),
        "An invalid AI result reached review or changed the editor content.")
    retryPurposeResult := editor.PromptForAiPurpose("generate")
    MappingWindowVisualAssert(retryPurposeResult.Accepted
            && purposePromptProbe.LastInitialValue
                == "让 CapsLock 配合方向键移动光标",
        "A failed AI generation did not restore its previous purpose input.")
    window.App.Runtime.Direct.RejectNext := true
    editor.AiRequestId := 704
    editor.AiRequestRevision := editor.EditorRevision
    editor.AiRepairAttempts := MappingBlockEditor.AIMaximumRepairAttempts
    MappingWindowVisualAssert(!editor.HandleAiResult(true, "",
            normalizedAiText, 704)
            && editor.GetCodeText() == originalAiText
            && window.App.Runtime.Direct.CallCount == 1
            && InStr(editor.Status.Text, "managed preflight rejected"),
        "A managed AI result that failed runtime preflight changed the editor.")
    editor.Gui.GetClientPos(, , &invalidWidth, &invalidHeight)
    editor.CodeEdit.GetPos(, &invalidCodeY, , &invalidCodeHeight)
    editor.Status.GetPos(&invalidStatusX, &invalidStatusY,
        &invalidStatusWidth, &invalidStatusHeight)
    editor.AiButton.GetPos(&invalidAiX, &invalidAiY,
        &invalidAiWidth, &invalidAiHeight)
    MappingWindowVisualAssert(invalidStatusHeight > 24
            && invalidCodeY + invalidCodeHeight < invalidStatusY
            && invalidStatusX + invalidStatusWidth < invalidAiX
            && invalidStatusY + invalidStatusHeight <= invalidHeight,
        Format("The invalid-AI status overlaps another editor surface: codeBottom={1}, status={2}/{3}/{4}/{5}, ai={6}/{7}/{8}/{9}, clientHeight={10}.",
            invalidCodeY + invalidCodeHeight, invalidStatusX, invalidStatusY,
            invalidStatusWidth, invalidStatusHeight, invalidAiX, invalidAiY,
            invalidAiWidth, invalidAiHeight, invalidHeight))
    AssertMappingWindowButtonPixel(editor.Interactions, editor.AiButton,
        MappingWindow.Colors.AIButton,
        "The invalid-AI status erased the AI command button.")
    AssertMappingWindowButtonPixel(editor.Interactions, editor.SaveButton,
        MappingWindow.Colors.Save,
        "The invalid-AI status erased the Save button.")
    AssertMappingWindowButtonPixel(editor.Interactions, editor.CancelButton,
        MappingWindow.Colors.Toolbar,
        "The invalid-AI status erased the Cancel button.")
    editor.Gui.Show("NA w" (invalidWidth + 160) " h" invalidHeight)
    Sleep(30)
    editor.Gui.GetClientPos(, , &stretchedWidth, &stretchedHeight)
    editor.CodeEdit.GetPos(, &stretchedCodeY, , &stretchedCodeHeight)
    editor.Status.GetPos(&stretchedStatusX, &stretchedStatusY,
        &stretchedStatusWidth, &stretchedStatusHeight)
    editor.AiButton.GetPos(&stretchedAiX)
    MappingWindowVisualAssert(stretchedWidth > invalidWidth
            && stretchedStatusHeight >= 24
            && stretchedStatusHeight <= invalidStatusHeight
            && stretchedCodeY + stretchedCodeHeight < stretchedStatusY
            && stretchedStatusX + stretchedStatusWidth < stretchedAiX
            && stretchedStatusY + stretchedStatusHeight <= stretchedHeight,
        Format("Stretching the invalid-AI status caused overlap: client={1}/{2}, codeBottom={3}, status={4}/{5}/{6}/{7}, aiX={8}.",
            stretchedWidth, stretchedHeight,
            stretchedCodeY + stretchedCodeHeight, stretchedStatusX,
            stretchedStatusY, stretchedStatusWidth, stretchedStatusHeight,
            stretchedAiX))
    editor.Gui.Show("NA w" invalidWidth " h" invalidHeight)
    Sleep(30)
    generationPipelineService := MappingWindowVisualAiServiceProbe()
    window.App.Settings := {}
    window.App.AIService := generationPipelineService
    editor.AiRequestId := 701
    editor.AiRequestRevision := editor.EditorRevision
    editor.AiRequestPurpose := "把 F24 映射为 F23"
    editor.AiRequestEditorText := originalAiText
    editor.AiPipelinePhase := "draft"
    editor.AiRepairAttempts := 0
    editor.AiReviewAttempts := 0
    editor.AiBusy := true
    editor.HandleAiRequestStatus({Stage: "waiting",
        ProviderName: "OpenAI", TargetIndex: 2, TargetCount: 3,
        ElapsedSeconds: 47, TimeoutSeconds: 600,
        CompatibilityMode: true, Phase: "draft"}, 701)
    MappingWindowVisualAssert(StrReplace(editor.Status.Text, "`r", "")
            == "AI 正在生成规则，请稍候…`n当前等待时间：47 秒",
        "The mapping editor did not display the two-line AI wait status.")
    MappingWindowVisualAssert(editor.HandleAiResult(true, "",
            normalizedAiText, 701)
            && editor.Canonicalize(editor.GetCodeText())
                == editor.Canonicalize(originalAiText)
            && editor.AiBusy
            && generationPipelineService.CallCount == 1
            && generationPipelineService.Phase == "review"
            && generationPipelineService.CandidateText
                == normalizedAiText
            && aiReviewProbe.CallCount == 0
            && editor.AiPurposeRetryText != "",
        "AI generation skipped its semantic review or changed the editor before review.")
    MappingWindowVisualAssert(editor.HandleAiResult(true, "",
            normalizedAiText, generationPipelineService.RequestId)
            && editor.Canonicalize(editor.GetCodeText())
                == editor.Canonicalize(normalizedAiText)
            && !editor.AiBusy
            && aiReviewProbe.CallCount == 0
            && editor.AiPurposeRetryText == "",
        "A locally and semantically reviewed generation was not applied.")
    boundedRepairService := MappingWindowVisualAiServiceProbe()
    window.App.AIService := boundedRepairService
    boundedRepairOriginal := editor.GetCodeText()
    editor.AiRequestId := 702
    editor.AiRequestRevision := editor.EditorRevision
    editor.AiRequestPurpose := "把不存在的按键映射到 F23"
    editor.AiPurposeRetryText := editor.AiRequestPurpose
    editor.AiRequestEditorText := boundedRepairOriginal
    editor.AiRequiredResponseMode := ""
    editor.AiFormatFallbackAttempted := false
    editor.AiPipelinePhase := "draft"
    editor.AiRepairAttempts := 0
    editor.AiReviewAttempts := 0
    MappingWindowVisualAssert(editor.HandleAiResult(true, "",
            invalidKeyAiBlock, 702)
            && boundedRepairService.CallCount == 1
            && boundedRepairService.Phase == "repair"
            && boundedRepairService.CandidateText == invalidKeyAiBlock
            && InStr(boundedRepairService.ValidationFeedback,
                "DefinitelyNotAKey")
            && editor.GetCodeText() == boundedRepairOriginal,
        "A locally invalid AI draft was not sent back with precise repair context.")
    MappingWindowVisualAssert(editor.HandleAiResult(true, "",
            invalidKeyAiBlock, boundedRepairService.RequestId)
            && boundedRepairService.CallCount == 2
            && editor.AiRepairAttempts
                == MappingBlockEditor.AIMaximumRepairAttempts
            && editor.GetCodeText() == boundedRepairOriginal,
        "The second bounded AI repair attempt was not issued.")
    MappingWindowVisualAssert(!editor.HandleAiResult(true, "",
            invalidKeyAiBlock, boundedRepairService.RequestId)
            && boundedRepairService.CallCount == 2
            && !editor.AiBusy
            && editor.GetCodeText() == boundedRepairOriginal
            && editor.AiPurposeRetryText == editor.AiRequestPurpose
            && InStr(editor.Status.Text, "经过自动修复后仍未通过"),
        "Repeated invalid AI repairs looped, changed the editor, or lost the purpose input.")
    commentOnlyScriptSpec := RuleSpec.Clone(generatedScriptSpec)
    commentOnlyScriptSpec["code"] := "; F22::MsgBox('never runs')"
    commentOnlyScriptText := ScriptRuleCompiler.BuildBlock(
        commentOnlyScriptSpec)
    editor.AiRequestId := 706
    editor.AiRequestRevision := editor.EditorRevision
    editor.AiRepairAttempts := MappingBlockEditor.AIMaximumRepairAttempts
    MappingWindowVisualAssert(!editor.HandleAiResult(true, "",
            commentOnlyScriptText, 706)
            && editor.EditorMode == "managed"
            && editor.Canonicalize(editor.GetCodeText())
                == editor.Canonicalize(normalizedAiText)
            && window.App.Runtime.Scripts.CallCount == 0
            && InStr(editor.Status.Text, "没有可执行语句或热键"),
        "A comment-only AI script was accepted as an executable rule.")
    ineffectiveAltScript := "#HotIf WinActive('ahk_exe WINWORD.EXE')`n"
        . "~*LAlt::return`n"
        . "*LAlt Up::ReleaseAlt('LAlt')`n"
        . "#HotIf`n"
        . "ReleaseAlt(keyName, *) {`n"
        . "    SendEvent('{Blind}{' keyName ' up}')`n"
        . "}"
    ineffectiveAltRejected := false
    ineffectiveAltMessage := ""
    try editor.ValidateAiScriptBehavior(ineffectiveAltScript)
    catch as ineffectiveAltError {
        ineffectiveAltRejected := true
        ineffectiveAltMessage := ineffectiveAltError.Message
    }
    effectiveAltScript := "#HotIf WinActive('ahk_exe WINWORD.EXE')`n"
        . "~*LAlt::SendEvent('{Blind}{vkE8}')`n"
        . "~*RAlt::SendEvent('{Blind}{vkE8}')`n"
        . "#HotIf"
    MappingWindowVisualAssert(ineffectiveAltRejected
            && InStr(ineffectiveAltMessage, "{Blind}{vkE8}")
            && editor.ValidateAiScriptBehavior(effectiveAltScript),
        "The AI script preflight did not reject ineffective Alt menu suppression.")
    managedDirectiveRejected := false
    try editor.ValidateAiScriptBehavior(
        "#Requires AutoHotkey v2.0`nF24::F23")
    catch as managedDirectiveError
        managedDirectiveRejected := InStr(managedDirectiveError.Message,
            "#Requires") != 0
    MappingWindowVisualAssert(managedDirectiveRejected,
        "The AI script preflight accepted a directive supplied by the managed worker.")
    window.App.Runtime.Scripts.RejectNext := true
    editor.AiRequestId := 705
    editor.AiRequestRevision := editor.EditorRevision
    editor.AiRepairAttempts := MappingBlockEditor.AIMaximumRepairAttempts
    MappingWindowVisualAssert(!editor.HandleAiResult(true, "",
            normalizedAiScript.Text, 705)
            && editor.EditorMode == "managed"
            && editor.Canonicalize(editor.GetCodeText())
                == editor.Canonicalize(normalizedAiText)
            && window.App.Runtime.Scripts.CallCount == 1
            && InStr(editor.Status.Text, "script preflight rejected"),
        "A script AI result that failed syntax preflight changed the editor.")
    malformedAiService := MappingWindowVisualAiServiceProbe()
    window.App.Settings := {}
    window.App.AIService := malformedAiService
    malformedOriginalText := editor.GetCodeText()
    editor.AiRequestId := 709
    editor.AiRequestRevision := editor.EditorRevision
    editor.AiRequestPurpose := "把不存在的按键映射到 F23"
    editor.AiRequestEditorText := malformedOriginalText
    editor.AiRequiredResponseMode := ""
    editor.AiFormatFallbackAttempted := false
    editor.AiRepairAttempts := MappingBlockEditor.AIMaximumRepairAttempts
    MappingWindowVisualAssert(!editor.HandleAiResult(true, "",
            invalidKeyAiBlock, 709)
            && !editor.AiBusy
            && malformedAiService.CallCount == 0
            && editor.GetCodeText() == malformedOriginalText
            && editor.StatusIsError
            && InStr(editor.Status.Text, "DefinitelyNotAKey"),
        "An invalid key name was misclassified as a request for a script.")
    fallbackAiService := MappingWindowVisualAiServiceProbe()
    window.App.AIService := fallbackAiService
    modifierFallbackSpec := Map("id", "visual-ai-alt-fallback",
        "display", Map("source", "Alt", "target", "吞掉单按 Alt",
            "scope", "Office"),
        "from", Map("key", Map("name", "Alt"), "repeat", "ignore"),
        "to_if_alone", [Map("type", "sleep", "value", 1)],
        "to_if_held_down", [Map("type", "key_down", "value", "Alt")],
        "to_after_key_up", [Map("type", "key_up", "value", "Alt")],
        "timing", Map("held_threshold_ms", 180))
    modifierFallbackText := RuleCompiler.BuildManagedBlock(
        modifierFallbackSpec)
    fallbackOriginalText := editor.GetCodeText()
    editor.AiRequestId := 707
    editor.AiRequestRevision := editor.EditorRevision
    editor.AiRequestPurpose := "吞掉单按 Alt，保留 Alt 组合键"
    editor.AiRequestEditorText := fallbackOriginalText
    editor.AiRequiredResponseMode := ""
    editor.AiFormatFallbackAttempted := false
    editor.AiRepairAttempts := 0
    editor.AiReviewAttempts := 0
    editor.AiPipelinePhase := "draft"
    MappingWindowVisualAssert(editor.HandleAiResult(true, "",
            modifierFallbackText, 707)
            && editor.AiBusy
            && editor.AiRequestId == fallbackAiService.RequestId
            && editor.AiRequiredResponseMode == "script"
            && editor.GetCodeText() == fallbackOriginalText
            && fallbackAiService.CallCount == 1
            && fallbackAiService.Mode == "script"
            && fallbackAiService.Operation == "generate"
            && fallbackAiService.Phase == "repair"
            && InStr(fallbackAiService.ValidationFeedback,
                "规则块能力不足")
            && fallbackAiService.Purpose
                == "吞掉单按 Alt，保留 Alt 组合键",
        "An infeasible managed AI result did not retry once as a managed script.")
    MappingWindowVisualAssert(editor.HandleAiResult(true, "",
            normalizedAiScript.Text, fallbackAiService.RequestId)
            && editor.AiBusy
            && fallbackAiService.CallCount == 2
            && fallbackAiService.Phase == "review"
            && fallbackAiService.Mode == "script"
            && editor.EditorMode == "managed"
            && editor.Canonicalize(editor.GetCodeText())
                == editor.Canonicalize(fallbackOriginalText),
        "The managed-script repair did not enter semantic review.")
    MappingWindowVisualAssert(editor.HandleAiResult(true, "",
            normalizedAiScript.Text, fallbackAiService.RequestId)
            && editor.EditorMode == "script"
            && editor.Canonicalize(editor.GetCodeText())
                == editor.Canonicalize(normalizedAiScript.Text),
        "The automatic managed-script retry did not apply its validated result.")
    MappingWindowVisualAssert(editor.SwitchEditorMode("managed")
            && editor.EditorMode == "managed",
        "The editor could not reset after the automatic script fallback test.")
    sequenceFallbackAiService := MappingWindowVisualAiServiceProbe()
    window.App.AIService := sequenceFallbackAiService
    sequenceFallbackSpec := RuleSpec.Clone(generatedSpec)
    sequenceFallbackSpec["from"].Delete("key")
    sequenceFallbackSpec["from"]["sequence"] := [
        Map("name", "A"), Map("name", "B")]
    sequenceFallbackText := MappingWindowReplaceManagedSpecBody(
        RuleCompiler.BuildManagedBlock(generatedSpec, "`n"),
        sequenceFallbackSpec)
    sequenceFallbackOriginalText := editor.GetCodeText()
    editor.AiRequestId := 708
    editor.AiRequestRevision := editor.EditorRevision
    editor.AiRequestPurpose := "依次按 A、B 后发送 F23"
    editor.AiRequestEditorText := sequenceFallbackOriginalText
    editor.AiRequiredResponseMode := ""
    editor.AiFormatFallbackAttempted := false
    editor.AiRepairAttempts := 0
    editor.AiReviewAttempts := 0
    editor.AiPipelinePhase := "draft"
    MappingWindowVisualAssert(editor.HandleAiResult(true, "",
            sequenceFallbackText, 708)
            && editor.AiBusy
            && editor.AiRequestId == sequenceFallbackAiService.RequestId
            && editor.AiRequiredResponseMode == "script"
            && editor.GetCodeText() == sequenceFallbackOriginalText
            && sequenceFallbackAiService.CallCount == 1
            && sequenceFallbackAiService.Mode == "script"
            && sequenceFallbackAiService.Operation == "generate"
            && sequenceFallbackAiService.Phase == "repair"
            && sequenceFallbackAiService.Purpose
                == "依次按 A、B 后发送 F23",
        "A managed sequence rejected during normalization did not retry as a script.")
    MappingWindowVisualAssert(editor.HandleAiResult(true, "",
            normalizedAiScript.Text, sequenceFallbackAiService.RequestId)
            && editor.AiBusy
            && sequenceFallbackAiService.CallCount == 2
            && sequenceFallbackAiService.Phase == "review"
            && editor.EditorMode == "managed",
        "The sequence fallback repair did not enter semantic review.")
    MappingWindowVisualAssert(editor.HandleAiResult(true, "",
            normalizedAiScript.Text, sequenceFallbackAiService.RequestId)
            && editor.EditorMode == "script"
            && editor.Canonicalize(editor.GetCodeText())
                == editor.Canonicalize(normalizedAiScript.Text),
        "The normalization-stage script retry did not apply its validated result.")
    MappingWindowVisualAssert(editor.SwitchEditorMode("managed")
            && editor.EditorMode == "managed",
        "The editor could not reset after the sequence fallback test.")
    editor.AiRequestId := 703
    editor.AiRequestRevision := editor.EditorRevision
    editor.AiReviewAttempts :=
        MappingBlockEditor.AIMaximumSemanticReviewAttempts
    MappingWindowVisualAssert(editor.HandleAiResult(true, "",
            normalizedAiScript.Text, 703)
            && editor.EditorMode == "script"
            && editor.Canonicalize(editor.GetCodeText())
                == editor.Canonicalize(normalizedAiScript.Text)
            && aiReviewProbe.CallCount == 0,
        "Direct AI script generation did not switch the editor mode.")
    MappingWindowVisualAssert(editor.SwitchEditorMode("managed")
            && editor.EditorMode == "managed",
        "The editor could not return to its manual managed template after AI auto-detection.")
    MappingWindowVisualAssert(IsObject(editor.ManagedModeButton)
            && IsObject(editor.ScriptModeButton),
        "The new mapping editor did not create its mode selector.")
    editor.ManagedModeButton.GetPos(, &managedModeY, &managedModeWidth,
        &managedModeHeight)
    editor.ScriptModeButton.GetPos(, &scriptModeY, &scriptModeWidth,
        &scriptModeHeight)
    editor.CodeEdit.GetPos(, &modeCodeY)
    managedModeTextWidth := editor.MeasureControlTextWidth(
        editor.ManagedModeButton, editor.ManagedModeButton.Text)
    scriptModeTextWidth := editor.MeasureControlTextWidth(
        editor.ScriptModeButton, editor.ScriptModeButton.Text)
    MappingWindowVisualAssert(editor.ManagedModeButton.Text == Tr("规则块")
            && editor.ScriptModeButton.Text
                == Tr("受托管脚本")
            && managedModeWidth == editor.ModeButtonWidth
            && scriptModeWidth == editor.ModeButtonWidth
            && editor.ModeButtonWidth
                >= MappingBlockEditor.ModeButtonMinimumWidth
            && editor.ModeButtonWidth
                < MappingBlockEditor.ModeButtonMaximumWidth
            && managedModeTextWidth <= managedModeWidth
                - MappingBlockEditor.ModeButtonHorizontalPadding
            && scriptModeTextWidth <= scriptModeWidth
                - MappingBlockEditor.ModeButtonHorizontalPadding
            && managedModeY == scriptModeY
            && managedModeHeight == scriptModeHeight
            && modeCodeY - (managedModeY + managedModeHeight)
                == MappingBlockEditor.ModeSelectorBottomGap,
        "The mapping modes still expose internal implementation names.")
    AssertMappingEditorCodeLayout(editor, "managed editor")
    MappingWindowVisualAssert(InStr(managedText,
            "; 给这条规则起一个容易辨认的名称；它会显示在主界面中。`r`n"
                . "; @名称=<请填写规则名称>")
            && InStr(managedText,
                "; 下面填写规则的详细设置。请用完整的 RuleSpec JSON 替换占位文字。`r`n"
                    . "; @spec-begin")
            && InStr(managedText,
                "; <请在这里填写 RuleSpec JSON>")
            && !InStr(managedText, "F24")
            && !InStr(managedText, "F23"),
        "The managed template does not contain its inline guidance.")
    codeClientRect := Buffer(16, 0)
    gutterClientRect := Buffer(16, 0)
    codeFormatRect := Buffer(16, 0)
    gutterFormatRect := Buffer(16, 0)
    DllCall("user32\GetClientRect", "Ptr", editor.CodeEditHwnd,
        "Ptr", codeClientRect, "Int")
    DllCall("user32\GetClientRect", "Ptr", editor.LineNumberEditHwnd,
        "Ptr", gutterClientRect, "Int")
    SendMessage(0x00B2, 0, codeFormatRect.Ptr, ,
        editor.CodeEditHwnd) ; EM_GETRECT
    SendMessage(0x00B2, 0, gutterFormatRect.Ptr, ,
        editor.LineNumberEditHwnd)
    maximumLineOffset := 0
    linePositionDetails := ""
    Loop Min(18, editor.LineNumberCount) {
        lineIndex := A_Index - 1
        codeLineY := MappingWindowReadRichEditLineY(
            editor.CodeEditHwnd, lineIndex)
        gutterLineY := MappingWindowReadRichEditLineY(
            editor.LineNumberEditHwnd, lineIndex)
        lineOffset := Abs(codeLineY - gutterLineY)
        maximumLineOffset := Max(maximumLineOffset, lineOffset)
        linePositionDetails .= Format(" {1}:{2}/{3}",
            lineIndex + 1, codeLineY, gutterLineY)
    }
    MappingWindowVisualAssert(
            NumGet(codeClientRect, 12, "Int")
                == NumGet(gutterClientRect, 12, "Int")
            && NumGet(codeFormatRect, 4, "Int")
                == NumGet(gutterFormatRect, 4, "Int")
            && NumGet(codeFormatRect, 12, "Int")
                == NumGet(gutterFormatRect, 12, "Int")
            && maximumLineOffset <= 1,
        Format("The code surface and gutter height relationship is inconsistent: client={1}/{2}, format={3}-{4}/{5}-{6}, maxLineOffset={7}px:{8}",
            NumGet(codeClientRect, 12, "Int"),
            NumGet(gutterClientRect, 12, "Int"),
            NumGet(codeFormatRect, 4, "Int"),
            NumGet(codeFormatRect, 12, "Int"),
            NumGet(gutterFormatRect, 4, "Int"),
            NumGet(gutterFormatRect, 12, "Int"),
            maximumLineOffset, linePositionDetails))
    longMixedText := ""
    Loop 320 {
        longMixedText .= (A_Index > 1 ? "`n" : "")
            . (Mod(A_Index, 2)
                ? "; 中文说明行用于验证混合字体高度"
                : "; @测试字段=ASCII-value")
    }
    MappingWindowVisualAssert(editor.ReplaceEditorTextAtomically(
            longMixedText),
        "The long mixed-font geometry probe could not be formatted.")
    longMaximumOffset := 0
    longPositionDetails := ""
    for lineIndex in [0, 79, 159, 239, 319] {
        codeLineY := MappingWindowReadRichEditLineY(
            editor.CodeEditHwnd, lineIndex)
        gutterLineY := MappingWindowReadRichEditLineY(
            editor.LineNumberEditHwnd, lineIndex)
        lineOffset := Abs(codeLineY - gutterLineY)
        longMaximumOffset := Max(longMaximumOffset, lineOffset)
        longPositionDetails .= Format(" {1}:{2}/{3}",
            lineIndex + 1, codeLineY, gutterLineY)
    }
    MappingWindowVisualAssert(longMaximumOffset <= 1,
        Format("The code surface and gutter accumulate vertical drift across 320 mixed-font lines: max={1}px:{2}",
            longMaximumOffset, longPositionDetails))
    MappingWindowVisualAssert(editor.ReplaceEditorTextAtomically(
            managedText),
        "The managed template could not be restored after geometry testing.")
    MappingWindowVisualAssert(SendMessage(0x00D5, 0, 0, ,
            editor.LineNumberEditHwnd)
            == MappingBlockEditor.MaximumLineNumberCharacters,
        "The line-number gutter retained the RichEdit default text limit.")
    MappingWindowVisualAssert(SendMessage(0x00D5, 0, 0, ,
            editor.CodeEditHwnd)
            == MappingCodeRepository.MaximumBlockCharacters,
        "The RuleSpec editor did not expose the repository block limit.")
    MappingWindowVisualAssert(
            editor.Interactions.TextInputTargets.Has(editor.CodeEditHwnd)
            && editor.Interactions.TextInputTargets[editor.CodeEditHwnd]
                == editor.CodeEditHwnd,
        "The mapping code editor is not registered for text selection.")
    MappingWindowAssertMouseSelectableEdit(editor.CodeEdit,
        "The mapping code editor")
    scriptSwitchResult := editor.SwitchEditorMode("script")
    scriptSwitchText := editor.Canonicalize(editor.GetCodeText())
    MappingWindowVisualAssert(scriptSwitchResult
            && editor.EditorMode == "script"
            && editor.GetAiPurposeQuestion("generate")
                == Tr("我是来帮你的，你要干什么？！")
            && InStr(scriptSwitchText,
                ";  <请在这里编写完整的 AHK v2 脚本>")
            && !InStr(scriptSwitchText, "#Requires"),
        Format("The new mapping editor did not switch to the AHK v2 template: result={1}, mode={2}, textLength={3}, status={4}.",
            scriptSwitchResult, editor.EditorMode,
            StrLen(scriptSwitchText), editor.Status.Text))
    AssertMappingEditorCodeLayout(editor, "script editor")
    templatePlaceholderStart := InStr(scriptSwitchText,
        ScriptRuleCompiler.ScriptCodePlaceholder, true) - 1
    MappingWindowVisualAssert(MappingWindowReadRichEditColor(
            editor.CodeEditHwnd, templatePlaceholderStart,
            templatePlaceholderStart
                + StrLen(ScriptRuleCompiler.ScriptCodePlaceholder))
            == ColorRef(MappingWindow.Colors.CodeOperator)
            && editor.LastFormattedRevision == editor.EditorRevision,
        "Mode switching exposed the script template before syntax formatting completed.")
    MappingWindowVisualAssert(SendMessage(0x00D5, 0, 0, ,
            editor.CodeEditHwnd) == MappingCodeRepository.MaximumBlockCharacters,
        "The AHK v2 editor did not expose the script-block limit.")
    scriptSpec := ScriptRuleSpec.Normalize(Map("id", "visual-script",
        "display", Map("source", "旧触发键", "target", "测试结果",
            "scope", "全局"),
        "code", "#Requires AutoHotkey v2.0`nclass Worker {`n"
            . "    Run() => MsgBox('ready')`n}`nF24::Worker().Run()"
            . "`nkeys := []`nstates := Map()`n::btw::by the way"))
    scriptText := ScriptRuleCompiler.BuildBlock(scriptSpec, "`n")
    MappingWindowVisualAssert(InStr(scriptText,
            "; 给这条规则起一个容易辨认的名称；它会显示在主界面中。`n"
                . "; @名称=visual-script")
            && InStr(scriptText,
                "; 下面是一份完整的 AHK v2 脚本；小助手会单独启动和停止它。`n"
                    . "; @script-code-begin"),
        "The script editor block does not explain its persisted fields.")
    quote := Chr(34)
    ControlSetText(scriptText, editor.CodeEdit)
    MappingWindowVisualAssert(editor.ApplyEditorFonts(true),
        "The script editor could not apply AHK v2 syntax formatting.")
    scriptTokens := editor.SyntaxLexer.GetTokens(, 0, StrLen(scriptText))
    for expectedToken in [
        ["; @来源按键", "MetadataKey"],
        ["=旧触发键", "MetadataValue"],
        ["=受托管独立脚本", "MetadataValue"],
        ["=visual-script", "MetadataValue"],
        ["#Requires", "Directive"],
        ["AutoHotkey v2.0", "DirectiveValue"],
        ["class", "Keyword"],
        ["Worker", "Type"],
        ["keys", "Identifier"],
        ["states", "Identifier"],
        ["MsgBox", "Function"],
        ["F24::", "Hotkey"],
        ["'ready'", "String"],
        ["::btw::", "Hotstring"]
    ] {
        MappingWindowVisualAssert(MappingWindowHasLexerToken(scriptText,
                scriptTokens, expectedToken[1], expectedToken[2]),
            "The editor did not produce the expected " expectedToken[2]
                " token: " expectedToken[1])
    }
    directiveStart := InStr(scriptText, "#Requires", true) - 1
    MappingWindowVisualAssert(MappingWindowReadRichEditColor(
            editor.CodeEditHwnd, directiveStart,
            directiveStart + StrLen("#Requires"))
            == ColorRef(MappingWindow.Colors.CodeDirective),
        "The RichEdit control did not render the script directive color.")
    directiveValueStart := InStr(scriptText, "AutoHotkey v2.0", true) - 1
    MappingWindowVisualAssert(MappingWindowReadRichEditColor(
            editor.CodeEditHwnd, directiveValueStart,
            directiveValueStart + StrLen("AutoHotkey v2.0"))
            == ColorRef(MappingWindow.Colors.CodeString),
        "The RichEdit control did not render the directive value color.")
    metadataStart := InStr(scriptText, "; @来源按键", true) - 1
    MappingWindowVisualAssert(MappingWindowReadRichEditColor(
            editor.CodeEditHwnd, metadataStart,
            metadataStart + StrLen("; @来源按键"))
            == ColorRef(MappingWindow.Colors.CodeVariable),
        "The RichEdit control did not highlight Chinese metadata.")
    identifierStart := InStr(scriptText, "states :=", true) - 1
    MappingWindowVisualAssert(MappingWindowReadRichEditColor(
            editor.CodeEditHwnd, identifierStart,
            identifierStart + StrLen("states"))
            == ColorRef(MappingWindow.Colors.CodeVariable),
        "The RichEdit control left an AHK variable in the base text color.")
    keysStart := InStr(scriptText, "keys :=", true) - 1
    MappingWindowVisualAssert(MappingWindowReadRichEditColor(
            editor.CodeEditHwnd, keysStart, keysStart + StrLen("keys"))
            == ColorRef(MappingWindow.Colors.CodeVariable),
        "The RichEdit control left an AHK collection variable in the base text color.")
    valueStart := InStr(scriptText, "旧触发键", true) - 1
    valueRange := Buffer(8, 0)
    NumPut("Int", valueStart, valueRange, 0)
    NumPut("Int", valueStart + StrLen("旧触发键"), valueRange, 4)
    editor.OnImeComposition(0, 0, 0x010D, editor.CodeEditHwnd)
    SendMessage(0x0437, 0, valueRange.Ptr, , editor.CodeEditHwnd)
    SendMessage(0x00C2, 1, StrPtr("新触发键"), , editor.CodeEditHwnd)
    expectedEditedText := StrReplace(scriptText, "旧触发键", "新触发键",
        true, , 1)
    formattingBeforeImeEnd := editor.FormattingPassCount
    Sleep(220)
    MappingWindowVisualAssert(editor.FormattingPassCount
            == formattingBeforeImeEnd,
        "IME composition triggered editor formatting before commit.")
    editor.OnImeComposition(0, 0, 0x010E, editor.CodeEditHwnd)
    Sleep(320)
    MappingWindowVisualAssert(editor.Canonicalize(editor.GetCodeText())
            == expectedEditedText,
        "Metadata formatting changed the script source text.")
    MappingWindowVisualAssert(editor.LastFormattedStart >= 0
            && editor.LastFormattedEnd > editor.LastFormattedStart
            && editor.LastFormattedEnd < StrLen(expectedEditedText),
        Format("A metadata edit reformatted the whole script document: range={1}-{2}, length={3}, pending={4}-{5}, revision={6}/{7}.",
            editor.LastFormattedStart, editor.LastFormattedEnd,
            StrLen(expectedEditedText), editor.PendingFormatStart,
            editor.PendingFormatEnd, editor.LastFormattedRevision,
            editor.EditorRevision))
    completedMetadataPasses := editor.FormattingPassCount
    Sleep(320)
    MappingWindowVisualAssert(editor.FormattingPassCount
            == completedMetadataPasses,
        "Metadata editing started a formatting or scroll feedback loop.")
    MappingWindowVisualAssert(editor.SwitchEditorMode("managed")
            && editor.EditorMode == "managed"
            && InStr(editor.GetCodeText(), "; @类型=规则块"),
        "The new mapping editor did not restore the RuleSpec template.")
    MappingWindowVisualAssert(SendMessage(0x00D5, 0, 0, ,
            editor.CodeEditHwnd)
            == MappingCodeRepository.MaximumBlockCharacters,
        "Switching back to RuleSpec did not restore its text limit.")
    managedVisualText := "; @mapping-begin`n"
        . "; @名称=visual-managed`n; @类型=规则块`n"
        . "; @来源按键=F24`n; @映射结果=F23`n"
        . "; @生效范围=全局`n"
        . "; @spec-begin`n; {`n"
        . ";   " quote "from" quote ": {`n;     "
        . quote "key" quote ": {" quote "name" quote ": "
        . quote "F24" quote "}`n;   },`n"
        . ";   " quote "to" quote ": [{" quote "type" quote ": "
        . quote "send" quote ", " quote "value" quote ": "
        . quote "{F23}" quote "}],`n"
        . ";   " quote "enabled" quote ": true,`n;   "
        . quote "priority" quote ": 2`n"
        . "; }`n; @spec-end`n"
        . "; @generated-begin`n; @generated-end`n; @mapping-end"
    ControlSetText(managedVisualText, editor.CodeEdit)
    MappingWindowVisualAssert(editor.ApplyEditorFonts(true),
        "The RuleSpec editor could not apply managed syntax formatting.")
    managedVisualTokens := editor.SyntaxLexer.GetTokens(, 0,
        StrLen(managedVisualText))
    for expectedToken in [
        ["; @来源按键", "MetadataKey"],
        [quote "from" quote, "Property"],
        [quote "F24" quote, "String"], ["true", "Literal"],
        ["2", "Number"]
    ] {
        MappingWindowVisualAssert(MappingWindowHasLexerToken(
                managedVisualText, managedVisualTokens, expectedToken[1],
                expectedToken[2]),
            "The RuleSpec editor did not highlight " expectedToken[2]
                ": " expectedToken[1])
    }
    managedPropertyStart := InStr(managedVisualText,
        quote "from" quote, true) - 1
    MappingWindowVisualAssert(MappingWindowReadRichEditColor(
            editor.CodeEditHwnd, managedPropertyStart,
            managedPropertyStart + StrLen(quote "from" quote))
            == ColorRef(MappingWindow.Colors.CodeProperty),
        "The RuleSpec JSON property did not render with syntax color.")
    managedStringStart := InStr(managedVisualText,
        quote "F24" quote, true) - 1
    MappingWindowVisualAssert(MappingWindowReadRichEditColor(
            editor.CodeEditHwnd, managedStringStart,
            managedStringStart + StrLen(quote "F24" quote))
            == ColorRef(MappingWindow.Colors.CodeString),
        "The RuleSpec JSON string did not render with syntax color.")
    largeEditorText := ""
    Loop 1000
        largeEditorText .= "; long editor viewport formatting " A_Index
            . " F24::F23`r`n"
    Loop 500
        largeEditorText .= "W"
    SendMessage(0x000B, 0, 0, , editor.CodeEditHwnd) ; WM_SETREDRAW
    try {
        ControlSetText(largeEditorText, editor.CodeEdit)
        detailRange := editor.GetFormatRange(
            editor.Canonicalize(largeEditorText), false)
        MappingWindowVisualAssert(detailRange.End - detailRange.Start
                < StrLen(editor.Canonicalize(largeEditorText)),
            "Large editor content still requested detailed full-document formatting.")
        MappingWindowVisualAssert(editor.ApplyEditorFonts(true),
            "Large editor content could not be formatted.")
    } finally {
        SendMessage(0x000B, 1, 0, , editor.CodeEditHwnd)
        DllCall("user32\InvalidateRect", "Ptr", editor.CodeEditHwnd,
            "Ptr", 0, "Int", 0)
    }
    firstLargeLineLength := InStr(editor.Canonicalize(largeEditorText),
        "`n") - 1
    firstLargeLineColor := MappingWindowReadRichEditColor(
        editor.CodeEditHwnd, 0, firstLargeLineLength)
    firstLargeCharacterColor := MappingWindowReadRichEditColor(
        editor.CodeEditHwnd, 0, 1)
    firstLargeLineTokens := editor.SyntaxLexer.GetTokens(, 0,
        firstLargeLineLength)
    firstLargeTokenSummary := ""
    if firstLargeLineTokens.Length
        firstLargeTokenSummary := "/" firstLargeLineTokens[1].Kind "/"
            firstLargeLineTokens[1].Start "-"
            firstLargeLineTokens[1].End
    expectedLargeLineColor := ColorRef(MappingWindow.Colors.CodeComment)
    MappingWindowVisualAssert(firstLargeLineColor
            == expectedLargeLineColor,
        "Large editor content did not retain syntax highlighting. Actual="
            Format("0x{:06X}", firstLargeLineColor) " Expected="
            Format("0x{:06X}", expectedLargeLineColor) " Range="
            detailRange.Start "-" detailRange.End " First="
            Format("0x{:06X}", firstLargeCharacterColor) " Tokens="
            firstLargeLineTokens.Length firstLargeTokenSummary)
    ValidateMappingEditorSingleStepWheel(editor)
    ValidateMappingEditorScrollBarCursor(editor)
    completedPasses := editor.FormattingPassCount
    completedReads := editor.EditorTextReadCount
    completedLexedLines := editor.SyntaxLexer.TotalLexedLineCount
    MappingWindowVisualAssert(!editor.RefreshEditorViewport()
            && !editor.RefreshEditorViewport(),
        "An unchanged large-file viewport was formatted repeatedly.")
    MappingWindowVisualAssert(editor.EditorTextReadCount == completedReads,
        "Scrolling reread the unchanged large editor document.")
    MappingWindowVisualAssert(editor.SyntaxLexer.TotalLexedLineCount
            == completedLexedLines,
        "Scrolling re-lexed the unchanged large editor document.")
    Sleep(350)
    MappingWindowVisualAssert(editor.FormattingPassCount == completedPasses,
        "Queued callbacks repeatedly reformatted an unchanged large viewport.")
    editor.Gui.GetClientPos(, , &editorWidth, &editorHeight)
    editor.Gui.Show("NA w" (editorWidth + 80) " h" (editorHeight + 50))
    Sleep(30)
    editor.Gui.GetClientPos(, , &resizedEditorWidth, &resizedEditorHeight)
    editorResizeResult := editor.LastChangedLayoutResult
    MappingWindowVisualAssert(IsObject(editorResizeResult)
            && editorResizeResult.Status == AtomicControlLayout.Applied
            && editorResizeResult.Mode == AtomicControlLayout.ModeDeferred
            && editorResizeResult.Repainted,
        "The mapping editor did not use the atomic resize transaction.")
    editorResizeNoop := editor.OnResize(editor.Gui, 0,
        resizedEditorWidth, resizedEditorHeight)
    MappingWindowVisualAssert(IsObject(editorResizeNoop)
            && editorResizeNoop.Status == AtomicControlLayout.Unchanged
            && !editorResizeNoop.Repainted,
        "The unchanged mapping-editor layout requested repainting.")
    editor.Dispose(false)
    MappingWindowVisualAssert(!IsObject(window.BlockEditor)
            && !WindowHierarchy.IsOwnerLocked(window.Gui),
        "The mode-aware mapping editor leaked its owner lease.")

    optimizationMapping := {Id: "visual-ai-generated", Source: "F24",
        Target: "F23", Mode: "managed", Block: normalizedAiText,
        EditorText: normalizedAiText, StartLine: 1}
    optimizationReviewProbe := MappingWindowAiReviewProbe()
    optimizationPurposeProbe := MappingWindowAiPurposePromptProbe(
        "保留原意并优化规则")
    optimizationEditor := MappingBlockEditor(window, optimizationMapping,
        false, (*) => true, ObjBindMethod(optimizationPurposeProbe, "Prompt"),
        ObjBindMethod(optimizationReviewProbe, "Review"))
    window.BlockEditor := optimizationEditor
    optimizationEditor.Show()
    optimizedSpec := RuleSpec.Clone(generatedSpec)
    optimizedSpec["id"] := "visual-ai-optimized"
    optimizedText := optimizationEditor.NormalizeAiRule(
        RuleCompiler.BuildManagedBlock(optimizedSpec))
    optimizationOriginalText := optimizationEditor.GetCodeText()
    optimizationPurposeResult := optimizationEditor.PromptForAiPurpose(
        "optimize")
    optimizationAiService := MappingWindowVisualAiServiceProbe()
    window.App.AIService := optimizationAiService
    optimizationEditor.AiRequestId := 801
    optimizationEditor.AiRequestRevision := optimizationEditor.EditorRevision
    optimizationEditor.AiRequestPurpose := "保留原意并优化规则"
    optimizationEditor.AiRequestEditorText := optimizationOriginalText
    optimizationEditor.AiPipelinePhase := "draft"
    optimizationEditor.AiRepairAttempts := 0
    optimizationEditor.AiReviewAttempts := 0
    MappingWindowVisualAssert(optimizationEditor.HandleAiResult(true, "",
            optimizedText, 801)
            && optimizationEditor.GetCodeText() == optimizationOriginalText
            && optimizationAiService.CallCount == 1
            && optimizationAiService.Phase == "review"
            && optimizationReviewProbe.CallCount == 0
            && optimizationPurposeResult.Accepted,
        "AI optimization skipped semantic review or changed the existing rule early.")
    MappingWindowVisualAssert(!optimizationEditor.HandleAiResult(true, "",
            optimizedText, optimizationAiService.RequestId)
            && optimizationEditor.GetCodeText() == optimizationOriginalText
            && optimizationReviewProbe.CallCount == 1,
        "Rejecting AI optimization changed the existing rule.")
    retryOptimizationPurpose := optimizationEditor.PromptForAiPurpose(
        "optimize")
    MappingWindowVisualAssert(retryOptimizationPurpose.Accepted
            && optimizationPurposeProbe.LastInitialValue
                == "保留原意并优化规则",
        "A rejected AI optimization did not restore its previous purpose input.")
    optimizationReviewProbe.Accepted := true
    optimizationEditor.AiRequestId := 802
    optimizationEditor.AiRequestRevision := optimizationEditor.EditorRevision
    optimizationEditor.AiPipelinePhase := "draft"
    optimizationEditor.AiReviewAttempts := 0
    MappingWindowVisualAssert(optimizationEditor.HandleAiResult(true, "",
            optimizedText, 802)
            && optimizationEditor.GetCodeText() == optimizationOriginalText
            && optimizationAiService.CallCount == 2
            && optimizationReviewProbe.CallCount == 1,
        "The accepted optimization skipped its semantic review phase.")
    MappingWindowVisualAssert(optimizationEditor.HandleAiResult(true, "",
            optimizedText, optimizationAiService.RequestId)
            && optimizationEditor.Canonicalize(
                optimizationEditor.GetCodeText())
                == optimizationEditor.Canonicalize(optimizedText)
            && optimizationReviewProbe.CallCount == 2
            && optimizationEditor.AiPurposeRetryText == "",
        "Accepting AI optimization did not replace the existing rule.")
    optimizationEditor.Dispose(false)
    MappingWindowVisualAssert(!IsObject(window.BlockEditor)
            && !WindowHierarchy.IsOwnerLocked(window.Gui),
        "The AI optimization editor leaked its owner lease.")
}

AssertMappingEditorCodeLayout(editor, context) {
    editor.Gui.GetClientPos(, , &clientWidth)
    editor.Title.GetPos(, &titleY, &titleWidth, &titleHeight)
    editor.LineNumberEdit.GetPos(&gutterX, &gutterY, &gutterWidth)
    editor.LineNumberDivider.GetPos(&dividerX, &dividerY, &dividerWidth)
    editor.CodeEdit.GetPos(&codeX, &codeY, &codeWidth)
    MappingWindowVisualAssert(!editor.HasOwnProp("MetadataTitle")
            && !editor.HasOwnProp("MetadataRows")
            && !editor.HasOwnProp("MetadataNote")
            && gutterX == 14
            && titleHeight == editor.GetTitleHeight(titleWidth)
            && gutterY == titleY + titleHeight
                + MappingBlockEditor.TitleBottomGap
            && dividerY == gutterY
            && codeY == gutterY
            && dividerX == gutterX + gutterWidth
            && codeX == dividerX + dividerWidth
            && codeX + codeWidth == clientWidth - 14,
        Format("The {1} does not occupy the full editor width: client={2}, gutter={3}/{4}, divider={5}/{6}, code={7}/{8}.",
            context, clientWidth, gutterX, gutterWidth, dividerX,
            dividerWidth, codeX, codeWidth))
}

ValidateScriptEditorSaveSnapshot(window) {
    scriptSpec := ScriptRuleSpec.Normalize(Map("id", "script-save-test",
        "display", Map("source", "旧按键", "target", "测试结果",
            "scope", "全局"),
        "code", "#Requires AutoHotkey v2.0`nF24::RunAction()`n`n"
            . "RunAction() {`n    MsgBox('ready')`n}`n"))
    scriptText := ScriptRuleCompiler.BuildBlock(scriptSpec, "`n")
    mapping := {Id: "script-save-test", Source: "旧按键",
        Target: "测试结果", Mode: "script", Block: "",
        EditorText: scriptText, StartLine: 1}
    confirmProbe := MappingWindowVisualConfirmProbe()
    editor := MappingBlockEditor(window, mapping, false,
        ObjBindMethod(confirmProbe, "Confirm"))
    window.BlockEditor := editor
    editor.Show()
    editedText := StrReplace(scriptText, "@来源按键=旧按键",
        "@来源按键=新按键", true, , 1)
    ControlSetText(editedText, editor.CodeEdit)
    window.App.LastSavedEditorText := ""
    editor.Save()
    MappingWindowVisualAssert(
            editor.Canonicalize(window.App.LastSavedEditorText)
                == editor.Canonicalize(editedText)
            && window.App.LastSavedEditorMode == "script"
            && window.App.LastSavedMappingId == "script-save-test"
            && confirmProbe.CallCount == 0
            && window.App.DeferredStartCount == 1
            && window.App.DeferredStartedAfterEditorClosed,
        Format("Saving a Chinese metadata edit changed or rejected the source text: text={1}, canonical={2}, length={3}/{4}, mode={5}, id={6}.",
            window.App.LastSavedEditorText == editedText,
            editor.Canonicalize(window.App.LastSavedEditorText)
                == editor.Canonicalize(editedText),
            StrLen(window.App.LastSavedEditorText), StrLen(editedText),
            window.App.LastSavedEditorMode,
            window.App.LastSavedMappingId))
    MappingWindowVisualAssert(!IsObject(window.BlockEditor)
            && !WindowHierarchy.IsOwnerLocked(window.Gui),
        "Saving a script editor leaked its owner lease.")

    newConfirmProbe := MappingWindowVisualConfirmProbe()
    newMapping := {Id: "", Source: "", Target: "", Mode: "script",
        Block: "", EditorText: scriptText, StartLine: 1}
    newEditor := MappingBlockEditor(window, newMapping, true,
        ObjBindMethod(newConfirmProbe, "Confirm"))
    window.BlockEditor := newEditor
    newEditor.Show()
    window.App.LastSavedEditorText := ""
    newEditor.Save()
    MappingWindowVisualAssert(newConfirmProbe.CallCount == 1
            && window.App.LastSavedEditorMode == "script"
            && editor.Canonicalize(window.App.LastSavedEditorText)
                == editor.Canonicalize(scriptText)
            && !IsObject(window.BlockEditor),
        "Adding a managed script did not show exactly one run confirmation before saving.")

    placeholderConfirmProbe := MappingWindowVisualConfirmProbe()
    placeholderMapping := {Id: "", Source: "", Target: "", Mode: "script",
        Block: "", EditorText: ScriptRuleCompiler.BuildBlankScriptBlock(
            "`n"), StartLine: 1}
    placeholderEditor := MappingBlockEditor(window, placeholderMapping, true,
        ObjBindMethod(placeholderConfirmProbe, "Confirm"))
    window.BlockEditor := placeholderEditor
    placeholderEditor.Show()
    window.App.LastSavedEditorText := ""
    placeholderEditor.Save()
    MappingWindowVisualAssert(placeholderConfirmProbe.CallCount == 0
            && window.App.LastSavedEditorText == ""
            && IsObject(window.BlockEditor)
            && InStr(placeholderEditor.Status.Text, "代码占位文字"),
        "An unchanged script placeholder reached the run confirmation.")
    placeholderEditor.Dispose()
}

class MappingWindowVisualConfirmProbe {
    __New() {
        this.CallCount := 0
    }

    Confirm(*) {
        this.CallCount++
        return true
    }
}

ValidateMappingEditorSingleStepWheel(editor) {
    codeHwnd := editor.CodeEditHwnd
    gutterHwnd := editor.LineNumberEditHwnd
    originalText := editor.GetCodeText()
    wheelText := ""
    Loop 80
        wheelText .= "wheel line " A_Index "`n"
    editor.ReplaceEditorTextAtomically(wheelText)
    SendMessage(0x00B6, 0, -0x7FFF, , codeHwnd) ; EM_LINESCROLL
    editor.SyncLineNumberScroll()
    initialCodeLine := SendMessage(0x00CE, 0, 0, , codeHwnd)
    wheelDownWParam := ((-120 & 0xFFFF) << 16)
    SendMessage(Win32.WM_MOUSEWHEEL, wheelDownWParam, 0, , codeHwnd)
    oneStepCodeLine := SendMessage(0x00CE, 0, 0, , codeHwnd)
    oneStepGutterLine := SendMessage(0x00CE, 0, 0, , gutterHwnd)
    wheelUpWParam := ((120 & 0xFFFF) << 16)
    SendMessage(Win32.WM_MOUSEWHEEL, wheelUpWParam, 0, , gutterHwnd)
    restoredCodeLine := SendMessage(0x00CE, 0, 0, , codeHwnd)
    restoredGutterLine := SendMessage(0x00CE, 0, 0, , gutterHwnd)
    MappingWindowVisualAssert(initialCodeLine == 0
            && oneStepCodeLine == 2 && oneStepGutterLine == 2
            && restoredCodeLine == 0 && restoredGutterLine == 0,
        Format("The code editor did not scroll exactly two synchronized lines per wheel notch: initial={1}, down={2}/{3}, up={4}/{5}.",
            initialCodeLine, oneStepCodeLine, oneStepGutterLine,
            restoredCodeLine, restoredGutterLine))
    editor.ReplaceEditorTextAtomically(originalText)
}

ValidateMappingEditorScrollBarCursor(editor) {
    interactions := editor.Interactions
    codeHwnd := editor.CodeEditHwnd
    arrowCursor := DllCall("user32\LoadCursor", "Ptr", 0,
        "Ptr", Win32.IDC_ARROW, "Ptr")
    textCursor := DllCall("user32\LoadCursor", "Ptr", 0,
        "Ptr", Win32.IDC_IBEAM, "Ptr")
    interactions.SetCursor("text")
    MappingWindowVisualAssert(DllCall("user32\GetCursor", "Ptr")
            == textCursor,
        "The text editor did not retain its I-beam cursor over content.")
    for hitTestCode in [Win32.HTHSCROLL, Win32.HTVSCROLL] {
        result := SendMessage(Win32.WM_SETCURSOR, codeHwnd,
            hitTestCode, , codeHwnd)
        MappingWindowVisualAssert(result == 1
                && DllCall("user32\GetCursor", "Ptr") == arrowCursor,
            "A text-input scrollbar retained the I-beam cursor for hit-test "
                hitTestCode ".")
    }
    for objectId in [Win32.OBJID_HSCROLL, Win32.OBJID_VSCROLL] {
        rectangle := interactions.GetVisibleScrollBarRectangle(codeHwnd,
            objectId)
        MappingWindowVisualAssert(IsObject(rectangle),
            "The mapping editor did not expose its native scrollbar geometry.")
        centerX := Floor((rectangle.Left + rectangle.Right) / 2)
        centerY := Floor((rectangle.Top + rectangle.Bottom) / 2)
        MappingWindowVisualAssert(
            interactions.IsPointerOverTextInputScrollBar(codeHwnd,
                centerX, centerY),
            "Scrollbar geometry was not recognized as an arrow-cursor area.")
    }
}

MappingWindowHasLexerToken(source, tokens, text, kind) {
    for token in tokens {
        if token.Kind == kind && SubStr(source, token.Start + 1,
                token.End - token.Start) == text
            return true
    }
    return false
}

MappingWindowReadRichEditColor(hwnd, startPosition, endPosition) {
    previousSelection := Buffer(8, 0)
    selection := Buffer(8, 0)
    characterFormat := Buffer(116, 0)
    SendMessage(0x0434, 0, previousSelection.Ptr, , hwnd) ; EM_EXGETSEL
    NumPut("Int", startPosition, selection, 0)
    NumPut("Int", endPosition, selection, 4)
    SendMessage(0x0437, 0, selection.Ptr, , hwnd) ; EM_EXSETSEL
    NumPut("UInt", 116, characterFormat, 0)
    try {
        SendMessage(0x043A, 1, characterFormat.Ptr, , hwnd)
        return NumGet(characterFormat, 20, "UInt") & 0xFFFFFF
    } finally {
        SendMessage(0x0437, 0, previousSelection.Ptr, , hwnd)
    }
}

MappingWindowReadRichEditLineY(hwnd, lineIndex) {
    characterIndex := SendMessage(0x00BB, lineIndex, 0, , hwnd)
    if characterIndex < 0
        return -0x7FFFFFFF
    packedPosition := SendMessage(0x00D6, characterIndex, 0, , hwnd)
    if (packedPosition & 0xFFFFFFFF) == 0xFFFFFFFF
        return -0x7FFFFFFF
    y := (packedPosition >> 16) & 0xFFFF
    return y & 0x8000 ? y - 0x10000 : y
}

AssertMappingEditorInitialCaret(editor, context, expectTabStop := true) {
    selection := Buffer(8, 0)
    SendMessage(0x0434, 0, selection.Ptr, ,
        editor.CodeEditHwnd) ; EM_EXGETSEL
    firstVisibleLine := SendMessage(0x00CE, 0, 0, ,
        editor.CodeEditHwnd) ; EM_GETFIRSTVISIBLELINE
    style := DllCall("user32\GetWindowLongW", "Ptr", editor.CodeEditHwnd,
        "Int", -16, "Int")
    MappingWindowVisualAssert(NumGet(selection, 0, "Int") == 0
            && NumGet(selection, 4, "Int") == 0
            && firstVisibleLine == 0
            && !!(style & 0x00010000) == !!expectTabStop,
        Format("{1} did not start unselected with its caret at the beginning: selection={2}-{3}, firstLine={4}, tabStop={5}/{6}.",
            context, NumGet(selection, 0, "Int"),
            NumGet(selection, 4, "Int"), firstVisibleLine,
            !!(style & 0x00010000), !!expectTabStop))
}

AssertListCellTooltipUsesContentWidth(window) {
    cellTooltip := window.CellTooltip
    try {
        cellTooltip.PendingCell := "width-test-short"
        cellTooltip.PendingText := "PowerPoint"
        cellTooltip.ShowPending()
        cellTooltip.TextControl.GetPos(, , &shortWidth)
        cellTooltip.PendingCell := "width-test-long"
        cellTooltip.PendingText := "Word / Excel / PowerPoint"
        cellTooltip.ShowPending()
        cellTooltip.TextControl.GetPos(, , &longWidth)
        MappingWindowVisualAssert(shortWidth > 0 && longWidth > shortWidth
                && longWidth < 420,
            Format("The list-cell tooltip still uses a fixed width: short={1}, long={2}.",
                shortWidth, longWidth))

        dpi := window.GetListDpi()
        textInset := Max(1,
            Round(MappingWindow.ListTextInsetDip * dpi / 96))
        for column in [MappingWindow.NameColumn,
                MappingWindow.SourceColumn, MappingWindow.TargetColumn] {
            cellRect := window.GetListSubItemRect(1, column)
            actualWidth := window.GetListCellTextAvailableWidth(1, column)
            expectedWidth := cellRect.Right - cellRect.Left - textInset * 2
            MappingWindowVisualAssert(actualWidth == expectedWidth,
                Format("Column {1} tooltip width does not match its custom-drawn text bounds: actual={2}, expected={3}.",
                    column, actualWidth, expectedWidth))
        }

        nameRect := window.GetListSubItemRect(1, MappingWindow.NameColumn)
        nameColumnWidth := SendMessage(Win32.LVM_GETCOLUMNWIDTH,
            MappingWindow.NameColumn - 1, 0, , window.List.Hwnd)
        sequenceColumnWidth := SendMessage(Win32.LVM_GETCOLUMNWIDTH,
            MappingWindow.SequenceColumn - 1, 0, , window.List.Hwnd)
        MappingWindowVisualAssert(nameRect.Left == sequenceColumnWidth
                && nameRect.Right - nameRect.Left == nameColumnWidth,
            Format("The reordered primary name column returned incorrect bounds: left={1}/{2}, width={3}/{4}.",
                nameRect.Left, sequenceColumnWidth,
                nameRect.Right - nameRect.Left, nameColumnWidth))

        statusRect := window.GetListSubItemRect(1,
            MappingWindow.StatusColumn)
        statusIconWidth := 0
        statusIconHeight := 0
        MappingWindowVisualAssert(DllCall("comctl32\ImageList_GetIconSize",
                "Ptr", window.ListRowImageList, "Int*", &statusIconWidth,
                "Int*", &statusIconHeight, "Int"),
            "The status icon slot could not be measured for tooltip clipping.")
        statusGap := Max(2,
            Round(MappingWindow.ListStatusIconGapDip * dpi / 96))
        statusAvailable := window.GetListCellTextAvailableWidth(1,
            MappingWindow.StatusColumn)
        MappingWindowVisualAssert(statusAvailable
                == statusRect.Right - statusRect.Left
                    - statusIconWidth - statusGap,
            Format("The status tooltip width ignores its icon slot or gap: actual={1}, cell={2}, icon={3}, gap={4}.",
                statusAvailable, statusRect.Right - statusRect.Left,
                statusIconWidth, statusGap))

        legacyRect := Buffer(16, 0)
        NumPut("Int", 2, legacyRect, 0) ; LVIR_LABEL
        NumPut("Int", MappingWindow.NameColumn - 1, legacyRect, 4)
        MappingWindowVisualAssert(SendMessage(Win32.LVM_GETSUBITEMRECT,
                0, legacyRect.Ptr, , window.List.Hwnd),
            "The legacy primary-column tooltip bounds could not be inspected.")
        legacyAvailable := NumGet(legacyRect, 8, "Int")
            - NumGet(legacyRect, 0, "Int")
            - Max(1, Round(8 * dpi / 96))
        actualAvailable := window.GetListCellTextAvailableWidth(1,
            MappingWindow.NameColumn)
        clippedProbe := "i"
        while cellTooltip.MeasureTextWidth(clippedProbe) <= actualAvailable
            clippedProbe .= "i"
        probeWidth := cellTooltip.MeasureTextWidth(clippedProbe)
        MappingWindowVisualAssert(legacyAvailable > actualAvailable
                && probeWidth <= legacyAvailable
                && cellTooltip.IsCellClipped(1, MappingWindow.NameColumn,
                    clippedProbe),
            Format("A visibly clipped reordered name is still missed: text={1}, actual={2}, legacy={3}.",
                probeWidth, actualAvailable, legacyAvailable))

        originalName := window.List.GetText(1, MappingWindow.NameColumn)
        OnMessage(0x02A3, cellTooltip.MouseLeaveCallback, 0)
        try {
            window.List.Modify(1, "Col" MappingWindow.NameColumn,
                clippedProbe)
            pointerX := nameRect.Right - 2
            pointerY := Floor((nameRect.Top + nameRect.Bottom) / 2)
            pointerPosition := (pointerX & 0xFFFF)
                | ((pointerY & 0xFFFF) << 16)
            hitCell := cellTooltip.HitTestCell(pointerPosition)
            MappingWindowVisualAssert(IsObject(hitCell)
                    && hitCell.Row == 1
                    && hitCell.Column == MappingWindow.NameColumn,
                "The reordered custom-drawn name cell is not hover-testable across its full width.")
            cellTooltip.OnMouseMove(0, pointerPosition,
                Win32.WM_MOUSEMOVE, window.List.Hwnd)
            MappingWindowVisualAssert(cellTooltip.PendingCell != ""
                    && cellTooltip.PendingText == clippedProbe,
                "A visibly clipped mapping name was not queued for its full-content hover tip.")
            cellTooltip.ShowPending()
            offscreen := EnvGet("KEY_MOUSE_REMAPPER_GUI_TEST_OFFSCREEN") == "1"
            if offscreen && cellTooltip.VisibleCell == "" {
                MappingWindowVisualAssert(cellTooltip.PendingCell == ""
                        && cellTooltip.PendingText == ""
                        && cellTooltip.VisibleCell == "",
                    "A hidden mapping list did not clear its pending hover tip.")
            } else {
                MappingWindowVisualAssert(cellTooltip.VisibleCell != ""
                        && cellTooltip.PendingText == clippedProbe
                        && IsObject(cellTooltip.Gui)
                        && (offscreen || DllCall("user32\IsWindowVisible",
                            "Ptr", cellTooltip.Gui.Hwnd, "Int")),
                    "A visibly clipped mapping name did not show its full-content hover tip.")
            }
        } finally {
            OnMessage(0x02A3, cellTooltip.MouseLeaveCallback)
            cellTooltip.Hide()
            window.List.Modify(1, "Col" MappingWindow.NameColumn,
                originalName)
        }
    } finally cellTooltip.Hide()
}

MappingWindowAssertMouseSelectableEdit(control, context,
        verifyHitTarget := true) {
    hwnd := control.Hwnd
    if EnvGet("KEY_MOUSE_REMAPPER_GUI_TEST_OFFSCREEN") == "1" {
        oldStart := Buffer(4, 0)
        oldEnd := Buffer(4, 0)
        newStart := Buffer(4, 0)
        newEnd := Buffer(4, 0)
        SendMessage(Win32.EM_GETSEL, oldStart.Ptr, oldEnd.Ptr, , hwnd)
        textLength := SendMessage(0x000E, 0, 0, , hwnd) ; WM_GETTEXTLENGTH
        selectionEnd := Min(textLength, 8)
        try {
            DllCall("user32\SetFocus", "Ptr", hwnd, "Ptr")
            SendMessage(Win32.EM_SETSEL, 0, selectionEnd, , hwnd)
            SendMessage(Win32.EM_GETSEL, newStart.Ptr, newEnd.Ptr, , hwnd)
            MappingWindowVisualAssert(!textLength
                    || NumGet(newEnd, 0, "UInt")
                        > NumGet(newStart, 0, "UInt"),
                context " does not retain a control-level text selection in offscreen mode.")
        } finally SendMessage(Win32.EM_SETSEL,
            NumGet(oldStart, 0, "UInt"), NumGet(oldEnd, 0, "UInt"), , hwnd)
        return true
    }
    windowRect := Buffer(16, 0)
    DllCall("user32\GetWindowRect", "Ptr", hwnd, "Ptr", windowRect, "Int")
    screenX := Floor((NumGet(windowRect, 0, "Int")
        + NumGet(windowRect, 8, "Int")) / 2)
    screenY := Floor((NumGet(windowRect, 4, "Int")
        + NumGet(windowRect, 12, "Int")) / 2)
    hitHwnd := DllCall("user32\WindowFromPoint", "Int64",
        (screenX & 0xFFFFFFFF) | (screenY << 32), "Ptr")
    expectedRoot := DllCall("user32\GetAncestor", "Ptr", hwnd,
        "UInt", 2, "Ptr")
    hitRoot := hitHwnd ? DllCall("user32\GetAncestor", "Ptr", hitHwnd,
        "UInt", 2, "Ptr") : 0
    ; A different foreground window can cover the non-activating probe while
    ; the test process is still allowed to send control messages. In that
    ; case a real screen drag cannot be verified, so leave the control-level
    ; selection checks to the focused-window run.
    if hitRoot != expectedRoot
        return true
    if verifyHitTarget && hitRoot == expectedRoot {
        try hitClass := WinGetClass("ahk_id " hitHwnd)
        catch
            hitClass := "unknown"
        MappingWindowVisualAssert(hitHwnd == hwnd,
            Format("{1} is covered by another control: expected={2}, hit={3}, class={4}.",
                context, hwnd, hitHwnd, hitClass))
    }

    oldStart := Buffer(4, 0)
    oldEnd := Buffer(4, 0)
    newStart := Buffer(4, 0)
    newEnd := Buffer(4, 0)
    SendMessage(Win32.EM_GETSEL, oldStart.Ptr, oldEnd.Ptr, , hwnd)
    clientRect := Buffer(16, 0)
    DllCall("user32\GetClientRect", "Ptr", hwnd, "Ptr", clientRect, "Int")
    width := NumGet(clientRect, 8, "Int")
    height := NumGet(clientRect, 12, "Int")
    textLength := SendMessage(0x000E, 0, 0, , hwnd) ; WM_GETTEXTLENGTH
    dragEndIndex := Min(textLength, 8)
    startPosition := SendMessage(0x00D6, 0, 0, , hwnd) ; EM_POSFROMCHAR
    endPosition := SendMessage(0x00D6, dragEndIndex, 0, , hwnd)
    if textLength > 0
            && (startPosition & 0xFFFFFFFF) != 0xFFFFFFFF
            && (endPosition & 0xFFFFFFFF) != 0xFFFFFFFF {
        startX := MappingWindowSignedWord(startPosition) + 1
        startY := MappingWindowSignedWord(startPosition >> 16) + 8
        endX := MappingWindowSignedWord(endPosition) + 1
        endY := MappingWindowSignedWord(endPosition >> 16) + 8
        startX := Min(Max(1, startX), width - 2)
        startY := Min(Max(1, startY), height - 2)
        endX := Min(Max(1, endX), width - 2)
        endY := Min(Max(1, endY), height - 2)
    } else {
        startX := Min(Max(4, Floor(width / 8)), width - 4)
        endX := Max(startX + 8, width - 6)
        startY := Max(2, Floor(height / 2))
        endY := startY
    }
    try {
        DllCall("user32\SetFocus", "Ptr", hwnd, "Ptr")
        SendMessage(Win32.EM_SETSEL, 0, 0, , hwnd)
        SendMessage(Win32.WM_LBUTTONDOWN, 1,
            startX | (startY << 16), , hwnd)
        SendMessage(Win32.WM_MOUSEMOVE, 1,
            endX | (endY << 16), , hwnd)
        SendMessage(Win32.WM_LBUTTONUP, 0,
            endX | (endY << 16), , hwnd)
        Sleep(30)
        SendMessage(Win32.EM_GETSEL, newStart.Ptr, newEnd.Ptr, , hwnd)
        MappingWindowVisualAssert(DllCall("user32\GetFocus", "Ptr") == hwnd
                && NumGet(newEnd, 0, "UInt")
                    > NumGet(newStart, 0, "UInt"),
            Format("{1} does not retain mouse drag selection: focus={2}/{3}, selection={4}-{5}, points={6},{7}-{8},{9}.",
                context, DllCall("user32\GetFocus", "Ptr"), hwnd,
                NumGet(newStart, 0, "UInt"), NumGet(newEnd, 0, "UInt"),
                startX, startY, endX, endY))
    } finally SendMessage(Win32.EM_SETSEL,
        NumGet(oldStart, 0, "UInt"), NumGet(oldEnd, 0, "UInt"), , hwnd)
}

MappingWindowSignedWord(value) {
    value &= 0xFFFF
    return value & 0x8000 ? value - 0x10000 : value
}

MappingWindowVisualAssert(value, message) {
    if !value
        throw Error(message)
}

MappingWindowVisualJoin(values, separator) {
    result := ""
    for index, value in values
        result .= (index == 1 ? "" : separator) value
    return result
}

CaptureMappingWindowClientPixel(hwnd, x, y) {
    point := Buffer(8, 0)
    NumPut("Int", x, "Int", y, point)
    if !DllCall("user32\ClientToScreen", "Ptr", hwnd, "Ptr", point,
            "Int")
        return 0xFFFFFFFF
    screenDc := DllCall("user32\GetDC", "Ptr", 0, "Ptr")
    try {
        if !screenDc
            return 0xFFFFFFFF
        return DllCall("gdi32\GetPixel", "Ptr", screenDc,
            "Int", NumGet(point, 0, "Int"),
            "Int", NumGet(point, 4, "Int"), "UInt")
    } finally {
        if screenDc
            DllCall("user32\ReleaseDC", "Ptr", 0, "Ptr", screenDc)
    }
}

MappingWindowScreenPixelMatchesWhenVisible(hwnd, x, y, expectedColor) {
    if GetMappingWindowClientPointOwner(hwnd, x, y) != hwnd
        return true
    return CaptureMappingWindowClientPixel(hwnd, x, y)
        == ColorRef(expectedColor)
}

GetMappingWindowClientPointOwner(hwnd, x, y) {
    point := Buffer(8, 0)
    NumPut("Int", x, "Int", y, point)
    if !DllCall("user32\ClientToScreen", "Ptr", hwnd, "Ptr", point,
            "Int")
        return 0
    packedPoint := (NumGet(point, 4, "Int") << 32)
        | (NumGet(point, 0, "UInt") & 0xFFFFFFFF)
    pointWindow := DllCall("user32\WindowFromPoint", "Int64", packedPoint,
        "Ptr")
    return pointWindow ? DllCall("user32\GetAncestor", "Ptr", pointWindow,
        "UInt", 2, "Ptr") : 0
}

CaptureMappingWindowOwnDcPixel(hwnd, x, y) {
    clientDc := DllCall("user32\GetDC", "Ptr", hwnd, "Ptr")
    try return clientDc ? DllCall("gdi32\GetPixel", "Ptr", clientDc,
        "Int", x, "Int", y, "UInt") : 0xFFFFFFFF
    finally {
        if clientDc
            DllCall("user32\ReleaseDC", "Ptr", hwnd, "Ptr", clientDc)
    }
}

CaptureMappingWindowOwnDcRegionSignature(hwnd, left, top, right, bottom,
        step := 2) {
    clientDc := DllCall("user32\GetDC", "Ptr", hwnd, "Ptr")
    if !clientDc
        return ""
    signature := ""
    try {
        y := top
        while y < bottom {
            x := left
            while x < right {
                signature .= Format("{:06X}", DllCall("gdi32\GetPixel",
                    "Ptr", clientDc, "Int", x, "Int", y, "UInt"))
                x += step
            }
            y += step
        }
    } finally DllCall("user32\ReleaseDC", "Ptr", hwnd, "Ptr", clientDc)
    return signature
}

CaptureMappingWindowControlSignature(control) {
    rect := Buffer(16, 0)
    if !DllCall("user32\GetClientRect", "Ptr", control.Hwnd, "Ptr", rect,
            "Int")
        return ""
    width := NumGet(rect, 8, "Int")
    height := NumGet(rect, 12, "Int")
    deviceContext := DllCall("user32\GetDC", "Ptr", control.Hwnd, "Ptr")
    if !deviceContext
        return ""
    signature := ""
    try {
        y := 3
        while y < height - 2 {
            x := 3
            while x < width - 2 {
                signature .= Format("{:06X}", DllCall("gdi32\GetPixel",
                    "Ptr", deviceContext, "Int", x, "Int", y, "UInt"))
                x += 7
            }
            y += 5
        }
    } finally DllCall("user32\ReleaseDC", "Ptr", control.Hwnd,
        "Ptr", deviceContext)
    return signature
}

ResizeMappingWindowClient(hwnd, logicalWidth, logicalHeight) {
    if !hwnd || logicalWidth <= 0 || logicalHeight <= 0
        return false
    if DllCall("user32\IsIconic", "Ptr", hwnd, "Int") {
        DllCall("user32\ShowWindow", "Ptr", hwnd,
            "Int", Win32.SW_RESTORE, "Int")
        Sleep(50)
        if DllCall("user32\IsIconic", "Ptr", hwnd, "Int")
            return false
    }
    dpi := DllCall("user32\GetDpiForWindow", "Ptr", hwnd, "UInt")
    if !dpi
        dpi := 96
    style := DllCall("user32\GetWindowLongPtrW", "Ptr", hwnd,
        "Int", -16, "Ptr")
    extendedStyle := DllCall("user32\GetWindowLongPtrW", "Ptr", hwnd,
        "Int", -20, "Ptr")
    frame := Buffer(16, 0)
    adjusted := DllCall("user32\AdjustWindowRectExForDpi", "Ptr", frame,
        "UInt", style, "Int", false, "UInt", extendedStyle,
        "UInt", dpi, "Int")
    if !adjusted
        adjusted := DllCall("user32\AdjustWindowRectEx", "Ptr", frame,
            "UInt", style, "Int", false, "UInt", extendedStyle, "Int")
    if !adjusted
        return false
    frameWidth := NumGet(frame, 8, "Int") - NumGet(frame, 0, "Int")
    frameHeight := NumGet(frame, 12, "Int") - NumGet(frame, 4, "Int")
    outerWidth := Round(logicalWidth * dpi / 96) + frameWidth
    outerHeight := Round(logicalHeight * dpi / 96) + frameHeight
    resized := !!DllCall("user32\SetWindowPos", "Ptr", hwnd, "Ptr", 0,
        "Int", 0, "Int", 0, "Int", outerWidth, "Int", outerHeight,
        "UInt", 0x0016, "Int") ; SWP_NOMOVE | SWP_NOZORDER | SWP_NOACTIVATE
    if !resized || !DllCall("user32\IsIconic", "Ptr", hwnd, "Int")
        return resized
    DllCall("user32\ShowWindow", "Ptr", hwnd,
        "Int", Win32.SW_RESTORE, "Int")
    Sleep(50)
    if DllCall("user32\IsIconic", "Ptr", hwnd, "Int")
        return false
    return !!DllCall("user32\SetWindowPos", "Ptr", hwnd, "Ptr", 0,
        "Int", 0, "Int", 0, "Int", outerWidth, "Int", outerHeight,
        "UInt", 0x0016, "Int")
}

MappingWindowVisualCheckpoint(window, stage) {
    checkpointPath := EnvGet("MAPPING_WINDOW_VISUAL_CHECKPOINT")
    if checkpointPath == ""
        return false
    output := FileOpen(checkpointPath, "w", "UTF-8-RAW")
    if !IsObject(output)
        return false
    output.Write(stage "|" window.Gui.Hwnd)
    output.Close()
    try holdMilliseconds := Max(0,
        Integer(EnvGet("MAPPING_WINDOW_VISUAL_HOLD_MS")))
    catch
        holdMilliseconds := 0
    if holdMilliseconds
        Sleep(holdMilliseconds)
    return true
}

class MappingWindowVisualProbe extends MappingWindow {
    Show(*) {
        if this.HasOwnProp("ShowCallCount")
            this.ShowCallCount++
        return super.Show()
    }

    SetListActivationRedraw(enabled) {
        if enabled {
            if this.HasOwnProp("ActivationRedrawResumeCount")
                this.ActivationRedrawResumeCount++
        } else if this.HasOwnProp("ActivationRedrawSuspendCount")
            this.ActivationRedrawSuspendCount++
        return super.SetListActivationRedraw(enabled)
    }

    RefreshSelectedListRows(*) {
        if this.HasOwnProp("ActivationSelectionRefreshCount")
            this.ActivationSelectionRefreshCount++
        return super.RefreshSelectedListRows()
    }

    RefreshSelectionState(*) {
        if this.HasOwnProp("SelectionRefreshCount")
            this.SelectionRefreshCount++
        return super.RefreshSelectionState()
    }

    ApplyLayout(width, height, force := false, interactive := false) {
        if this.HasOwnProp("LayoutCallCount")
            this.LayoutCallCount++
        return super.ApplyLayout(width, height, force, interactive)
    }

    RedrawStable(eraseBackground := false, updateImmediately := true) {
        if this.HasOwnProp("FullWindowRedrawCount")
            this.FullWindowRedrawCount++
        return super.RedrawStable(eraseBackground, updateImmediately)
    }

    OptimizeMappingById(mappingId) {
        this.ContextOptimizeId := mappingId
        return true
    }
}

class MappingWindowAiReviewProbe {
    __New() {
        this.Accepted := false
        this.CallCount := 0
        this.LastCurrentText := ""
        this.LastProposedText := ""
    }

    Review(currentText, proposedText, title, ownerGui) {
        this.CallCount++
        this.LastCurrentText := String(currentText)
        this.LastProposedText := String(proposedText)
        return this.Accepted
    }
}

class MappingWindowAiPurposePromptProbe {
    __New(value) {
        this.Value := String(value)
        this.CallCount := 0
        this.LastInitialValue := ""
    }

    Prompt(message, title, confirmText, cancelText, emptyMessage, ownerGui,
            initialValue := "") {
        this.CallCount++
        this.LastInitialValue := String(initialValue)
        return {Accepted: true, Value: this.Value}
    }
}

class MappingWindowResizeIsolationProbe {
    static SubclassId := 0x4D575249
    static RootHwnd := 0
    static StableButtonHwnd := 0
    static ListHwnd := 0
    static MovingHwnds := []
    static RootSuspendCount := 0
    static ListSuspendCount := 0
    static StableButtonPaintCount := 0
    static MovingEraseCount := 0
    static SurfaceSuspendCounts := Map()
    static CallbackPointer := 0

    static Install(rootHwnd, stableButtonHwnd, listHwnd, movingHwnds) {
        this.Uninstall()
        this.RootHwnd := rootHwnd
        this.StableButtonHwnd := stableButtonHwnd
        this.ListHwnd := listHwnd
        this.MovingHwnds := movingHwnds.Clone()
        this.CallbackPointer := CallbackCreate(ObjBindMethod(this,
            "WindowProc"),, 6)
        try {
            hwnds := [rootHwnd, stableButtonHwnd, listHwnd]
            for movingHwnd in movingHwnds
                hwnds.Push(movingHwnd)
            for hwnd in hwnds {
                if !DllCall("comctl32\SetWindowSubclass", "Ptr", hwnd,
                        "Ptr", this.CallbackPointer, "UPtr",
                        this.SubclassId, "UPtr", 0, "Int")
                    throw Error("Unable to install resize isolation probe.")
            }
        } catch as installError {
            this.Uninstall()
            throw installError
        }
        this.Reset()
    }

    static Reset() {
        this.RootSuspendCount := 0
        this.ListSuspendCount := 0
        this.StableButtonPaintCount := 0
        this.MovingEraseCount := 0
        this.SurfaceSuspendCounts := Map()
        for hwnd in this.MovingHwnds
            this.SurfaceSuspendCounts[hwnd] := 0
    }

    static Uninstall() {
        if this.CallbackPointer {
            hwnds := [this.RootHwnd, this.StableButtonHwnd, this.ListHwnd]
            for movingHwnd in this.MovingHwnds
                hwnds.Push(movingHwnd)
            for hwnd in hwnds {
                if hwnd && DllCall("user32\IsWindow", "Ptr", hwnd, "Int")
                    DllCall("comctl32\RemoveWindowSubclass", "Ptr", hwnd,
                        "Ptr", this.CallbackPointer, "UPtr",
                        this.SubclassId, "Int")
            }
            CallbackFree(this.CallbackPointer)
        }
        this.CallbackPointer := 0
        this.RootHwnd := 0
        this.StableButtonHwnd := 0
        this.ListHwnd := 0
        this.MovingHwnds := []
    }

    static WindowProc(hwnd, message, wParam, lParam, subclassId,
            referenceData) {
        if message == Win32.WM_SETREDRAW && !wParam {
            if hwnd == this.RootHwnd
                this.RootSuspendCount++
            else if hwnd == this.ListHwnd
                this.ListSuspendCount++
            else if this.SurfaceSuspendCounts.Has(hwnd)
                this.SurfaceSuspendCounts[hwnd]++
        }
        if hwnd == this.StableButtonHwnd
                && (message == 0x000F || message == Win32.WM_ERASEBKGND)
            this.StableButtonPaintCount++
        if message == Win32.WM_ERASEBKGND {
            for movingHwnd in this.MovingHwnds {
                if hwnd == movingHwnd {
                    this.MovingEraseCount++
                    break
                }
            }
        }
        return DllCall("comctl32\DefSubclassProc", "Ptr", hwnd,
            "UInt", message, "UPtr", wParam, "Ptr", lParam, "Ptr")
    }
}

class MappingWindowVisualTestApp {
    __New() {
        this.MappingCount := 2
        this.ToggleCount := 0
        this.DeleteCount := 0
        this.AddMappingCount := 0
        this.LastMappingName := ""
        this.LastDistinguishModifierSides := false
        this.LayoutSaveCount := 0
        this.SavedLayout := ""
        this.LastSavedEditorText := ""
        this.LastSavedEditorMode := ""
        this.LastSavedMappingId := ""
        this.DeferredStartCount := 0
        this.DeferredStartedAfterEditorClosed := false
        this.RuleColors := Map()
        this.RuleColorSaveCount := 0
        this.LastRuleColorIds := []
        this.Capture := MappingWindowVisualCapture(this)
        this.SvgRenderer := SvgRenderLibrary(GetApplicationRootFilePath(
            "third_party\resvg\resvg.dll"))
        this.Repository := MappingWindowVisualRepository()
        this.Runtime := MappingWindowVisualRuntimeProbe()
        this.AIService := MappingWindowVisualAiServiceProbe()
        this.Window := ""
    }

    GetSummaryText() => "2 mappings"
    OpenSettings(*) => true
    OpenHelpInfo(*) => true
    OpenAbout(*) => true
    UndoMappingChange(*) => true
    RedoMappingChange(*) => true

    GetRuleColor(mappingId) {
        return this.RuleColors.Has(mappingId)
            ? RuleColorPalette.NormalizeKey(this.RuleColors[mappingId]) : ""
    }

    GetCommonRuleColor(mappingIds) {
        if Type(mappingIds) != "Array" || !mappingIds.Length
            return ""
        commonKey := this.GetRuleColor(mappingIds[1])
        for index, mappingId in mappingIds {
            if index > 1 && this.GetRuleColor(mappingId) != commonKey
                return ""
        }
        return commonKey
    }

    SetRuleColors(mappingIds, presetKey) {
        this.RuleColorSaveCount++
        this.LastRuleColorIds := mappingIds.Clone()
        presetKey := RuleColorPalette.NormalizeKey(presetKey)
        for mappingId in mappingIds {
            if presetKey == "" {
                if this.RuleColors.Has(mappingId)
                    this.RuleColors.Delete(mappingId)
            } else
                this.RuleColors[mappingId] := presetKey
        }
        return true
    }

    UpdateMappingEditorText(mappingId, editorText, mode := "managed") {
        this.LastSavedMappingId := mappingId
        this.LastSavedEditorText := editorText
        this.LastSavedEditorMode := mode
        return {Ok: true, DeferredApply: mode == "script"}
    }

    StartPendingScriptApply(*) {
        this.DeferredStartCount++
        this.DeferredStartedAfterEditorClosed := !IsObject(
            this.Window.BlockEditor)
            && !WindowHierarchy.IsOwnerLocked(this.Window.Gui)
        return true
    }

    AddMappingEditorText(editorText, mode := "managed") {
        this.LastSavedMappingId := ""
        this.LastSavedEditorText := editorText
        this.LastSavedEditorMode := mode
        return {Ok: true}
    }

    TrySaveMainWindowLayout(*) {
        this.LayoutSaveCount++
        this.SavedLayout := this.Window.GetPersistableClientSize()
        return IsObject(this.SavedLayout)
    }

    AddMapping(sourceCapture, targetCapture, name,
            distinguishModifierSides := true) {
        this.AddMappingCount++
        this.LastMappingName := String(name)
        this.LastDistinguishModifierSides := !!distinguishModifierSides
        return true
    }

    ToggleMappingsEnabled(mappingIds) {
        this.ToggleCount++
        toggled := []
        for mappingId in mappingIds {
            row := this.Window.FindMappingRow(mappingId)
            enabled := this.Window.List.GetText(row,
                MappingWindow.EnabledColumn) == "0"
            mapping := mappingId == "visual-test"
                ? {Id: mappingId, Source: "F24", Target: "F23",
                    Scope: "全局", Enabled: enabled}
                : {Id: mappingId, Source: "F22", Target: "F21",
                    Scope: "全局", Enabled: enabled}
            toggled.Push(mapping)
            this.Window.UpdateMappingRow(mapping)
        }
        return toggled
    }

    DeleteMappings(mappingIds) {
        this.DeleteCount++
        return mappingIds
    }
}

class MappingWindowVisualRuntimeProbe {
    __New() {
        this.Direct := MappingWindowVisualDirectRuntimeProbe()
        this.Scripts := MappingWindowVisualScriptRuntimeProbe()
    }
}

class MappingWindowVisualDirectRuntimeProbe {
    __New() {
        this.CallCount := 0
        this.RejectNext := false
    }

    BuildRegistration(descriptor) {
        this.CallCount++
        if this.RejectNext {
            this.RejectNext := false
            throw Error("managed preflight rejected")
        }
        return {Descriptor: descriptor, DownHotkey: descriptor.Hotkey,
            UpHotkey: ""}
    }
}

class MappingWindowVisualScriptRuntimeProbe {
    __New() {
        this.CallCount := 0
        this.RejectNext := false
    }

    ValidateSpec(spec) {
        this.CallCount++
        if this.RejectNext {
            this.RejectNext := false
            throw Error("script preflight rejected")
        }
        return ScriptRuleSpec.Normalize(spec)
    }
}

class MappingWindowVisualAiServiceProbe {
    __New() {
        this.CallCount := 0
        this.RequestId := 9706
        this.Mode := ""
        this.Operation := ""
        this.CurrentText := ""
        this.Purpose := ""
        this.Phase := ""
        this.CandidateText := ""
        this.ValidationFeedback := ""
        this.Requests := []
    }

    Request(settings, mode, operation, currentText, callback, purpose,
            phase := "draft", candidateText := "",
            validationFeedback := "", statusCallback := "") {
        this.CallCount++
        this.RequestId++
        this.Mode := mode
        this.Operation := operation
        this.CurrentText := currentText
        this.Purpose := purpose
        this.Phase := phase
        this.CandidateText := candidateText
        this.ValidationFeedback := validationFeedback
        this.Requests.Push({Mode: mode, Operation: operation,
            CurrentText: currentText, Purpose: purpose, Phase: phase,
            CandidateText: candidateText,
            ValidationFeedback: validationFeedback,
            StatusCallback: statusCallback,
            RequestId: this.RequestId})
        return {Ok: true, RequestId: this.RequestId}
    }
}

class MappingWindowVisualCapture {
    __New(app) {
        this.App := app
        this.Active := false
        this.Role := ""
        this.StartCount := 0
        this.CancelCount := 0
    }

    Start(role) {
        if this.Active
            return false
        this.Active := true
        this.Role := role
        this.StartCount++
        return true
    }

    Stop(*) {
        wasActive := this.Active
        this.Active := false
        this.Role := ""
        return wasActive
    }

    Cancel(*) {
        if !this.Active
            return false
        this.Active := false
        this.Role := ""
        this.CancelCount++
        this.App.Window.CancelCaptureState()
        return true
    }

    PreviewHeldModifiers(*) => false
}

class MappingWindowVisualRepository {
    __New() {
        this.GetCount := 0
    }

    GetById(mappingId) {
        this.GetCount++
        return {Id: mappingId, Source: "F24", Target: "F23",
            Block: "; @mapping visual-test`nF24::F23", StartLine: 1}
    }

    CreateBlankEditorText(mode := "managed") {
        if mode == "script"
            return ScriptRuleCompiler.BuildBlankScriptBlock("`r`n")
        return RuleCompiler.BuildBlankManagedBlock("`r`n")
    }

    GetAppendStartLine() => 1
}

MappingWindowReplaceManagedSpecBody(blockText, specValue,
        includeEmbeddedMetadata := false) {
    persistedSpec := RuleSpec.Clone(specValue)
    if !includeEmbeddedMetadata {
        persistedSpec.Delete("id")
        persistedSpec.Delete("display")
    }
    jsonText := JsonCodec.Stringify(persistedSpec, true, true)
    commentedJson := ""
    Loop Parse jsonText, "`n", "`r"
        commentedJson .= (A_Index > 1 ? "`n" : "") "; " A_LoopField
    beginMarker := "; @spec-begin`n"
    beginPosition := InStr(blockText, beginMarker, true)
    endPosition := InStr(blockText, "; @spec-end", true,
        beginPosition + StrLen(beginMarker))
    if !beginPosition || !endPosition
        throw Error("Test fixture does not contain a managed spec section.")
    contentStart := beginPosition + StrLen(beginMarker)
    return SubStr(blockText, 1, contentStart - 1) commentedJson "`n"
        . SubStr(blockText, endPosition)
}

MappingWindowMakeLooseAiBlock(blockText, scriptMode := false) {
    result := ""
    region := ""
    metadataAliases := Map("名称", "name", "类型", "type",
        "来源按键", "source_key", "映射结果", "mapping_result",
        "生效范围", "scope")
    Loop Parse blockText, "`n", "`r" {
        line := A_LoopField
        if RegExMatch(line, "^; (@(?:mapping|spec|generated|script-code)-(?:begin|end))$",
                &marker) {
            markerName := StrLower(marker[1])
            line := marker[1]
            if markerName == "@spec-begin"
                region := "spec"
            else if markerName == "@script-code-begin"
                region := "script"
            else if markerName == "@spec-end"
                    || markerName == "@script-code-end"
                region := ""
        } else if RegExMatch(line, "^; @([^=]+)=(.*)$", &metadata)
                && metadataAliases.Has(metadata[1]) {
            metadataValue := metadata[2]
            if scriptMode && metadata[1] == "类型"
                metadataValue := "受托管脚本（AHK v2）"
            line := "@" metadataAliases[metadata[1]] "=" metadataValue
        } else if region == "spec" && SubStr(line, 1, 2) == "; " {
            line := SubStr(line, 3)
        } else if region == "script" && SubStr(line, 1, 3) == ";  " {
            line := SubStr(line, 4)
        }
        result .= (A_Index > 1 ? "`n" : "") line
    }
    return result
}
