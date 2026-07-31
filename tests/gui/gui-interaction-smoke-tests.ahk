#Requires AutoHotkey v2.0 64-bit
#SingleInstance Off
#Warn All, StdOut

#Include ..\TestSupport.ahk
#Include ..\..\src\Core\CommandLine.ahk
#Include ..\..\src\Platform\PackagedLauncher.ahk
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
#Include ..\..\src\Config\AppDataPaths.ahk
#Include ..\..\src\Config\AppSettingsService.ahk
#Include ..\..\src\Core\JsonCodec.ahk
#Include ..\..\src\Core\Sha256.ahk
#Include ..\..\src\Core\HmacSha256.ahk
#Include ..\..\src\Core\AuthenticatedIpcProtocol.ahk
#Include ..\..\src\Core\CrossProcessWriteLock.ahk
#Include ..\..\src\Core\CrashRecoveryService.ahk
#Include ..\..\src\Core\ApplicationControlQueue.ahk
#Include ..\..\src\Core\StartupHealthService.ahk
#Include ..\..\src\Core\OutputRecoveryJournal.ahk
#Include ..\..\src\Core\RuleSpec.ahk
#Include ..\..\src\Core\DeviceIdentityService.ahk
#Include ..\..\src\Core\InputEvent.ahk
#Include ..\..\src\Core\RuleTimingResolver.ahk
#Include ..\..\src\Core\RuleSpecMigrationService.ahk
#Include ..\..\src\Core\RuleCompiler.ahk
#Include ..\..\src\Core\EventTraceService.ahk
#Include ..\..\src\Core\DiagnosticBundleService.ahk
#Include ..\..\src\Core\ScopedVariableStore.ahk
#Include ..\..\src\Core\RuleConditionEvaluator.ahk
#Include ..\..\src\Core\RuleConflictAnalyzer.ahk
#Include ..\..\src\Core\RuleSimulationService.ahk
#Include ..\..\src\Core\ManagedRuleStateMachine.ahk
#Include ..\..\src\Core\RuleScheduler.ahk
#Include ..\..\src\Core\OutputLedger.ahk
#Include ..\..\src\Core\InputBackend.ahk
#Include ..\..\src\Platform\Win32.ahk
#Include ..\..\src\Input\RawInputService.ahk
#Include ..\..\src\Core\RawInputBackend.ahk
#Include ..\..\src\Core\ManagedRuleRuntime.ahk
#Include ..\..\src\Core\RulePackageService.ahk
#Include ..\..\src\Core\MappingCodeRepository.ahk
#Include ..\..\src\Core\PersistentHistoryService.ahk
#Include ..\..\src\Platform\NamedPipeChannel.ahk
#Include ..\..\src\Platform\WindowsContextService.ahk
#Include ..\..\src\Platform\WindowHierarchy.ahk
#Include ..\..\src\UI\ThemeHelpers.ahk
#Include ..\..\src\UI\ApplicationIcon.ahk
#Include ..\..\src\Core\ApplicationVersionInfo.ahk
#Include ..\..\src\UI\SvgRenderLibrary.ahk
#Include ..\..\src\UI\RoundedButtonPainter.ahk
#Include ..\..\src\UI\ControlAccessibilityService.ahk
#Include ..\..\app\Windows\DarkTooltipWindow.ahk
#Include ..\..\src\UI\MappingUiInteractions.ahk
#Include ..\..\app\UI\DarkMessageBox.ahk
#Include ..\..\src\UI\ListViewPseudoHeader.ahk
#Include ..\..\src\Input\KeyCaptureSession.ahk
#Include ..\..\app\UI\ListViewSelectionPresenter.ahk
#Include ..\..\app\Windows\ListCellTooltipWindow.ahk
#Include ..\..\app\Windows\HistoryToastWindow.ahk
#Include ..\..\app\Windows\MappingContextPopupWindow.ahk
#Include ..\..\app\Windows\EventViewerWindow.ahk
#Include ..\..\app\Windows\SupportInfoWindow.ahk
#Include ..\..\app\Windows\HelpWindow.ahk
#Include ..\..\app\Windows\DonationWindow.ahk
#Include ..\..\app\Windows\RulePackageImportWindow.ahk
#Include ..\..\app\Windows\SettingsWindow.ahk
#Include ..\..\app\Windows\MappingBlockEditor.ahk
#Include ..\..\app\Windows\MappingWindow.ahk
#Include ..\..\src\Process\WorkerBootstrap.ahk
#Include ..\..\src\Process\InputWorkerController.ahk
#Include ..\..\app\KeyMouseRemapperAssistantApp.ahk

ReadMappingIdOrder(listView) {
    order := ""
    Loop listView.GetCount()
        order .= (A_Index == 1 ? "" : "|") listView.GetText(A_Index,
            MappingWindow.MappingIdColumn)
    return order
}

ReadListColumn(listView, column) {
    values := ""
    Loop listView.GetCount()
        values .= (A_Index == 1 ? "" : "|") listView.GetText(A_Index, column)
    return values
}

GetListColumnFormat(listView, zeroBasedColumn) {
    headerHwnd := SendMessage(0x101F, 0, 0, , listView.Hwnd) ; LVM_GETHEADER
    if !headerHwnd
        return -1
    headerItem := Buffer(A_PtrSize == 8 ? 72 : 48, 0)
    NumPut("UInt", 0x0004, headerItem, 0) ; HDI_FORMAT
    if !SendMessage(0x120B, zeroBasedColumn, headerItem.Ptr, headerHwnd)
        return -1
    return NumGet(headerItem, A_PtrSize == 8 ? 28 : 20, "Int")
}

AssertSequenceColumnCentered(listView, context) {
    columnFormat := GetListColumnFormat(listView,
        MappingWindow.SequenceColumn - 1)
    AssertTrue(columnFormat >= 0 && (columnFormat & 0x0003) == 0x0002,
        context "后序号列不再居中")
}

GetListRowHeight(listView, row := 1) {
    itemRect := Buffer(16, 0)
    NumPut("Int", 0, itemRect, 0) ; LVIR_BOUNDS
    if !SendMessage(0x100E, row - 1, itemRect.Ptr, listView.Hwnd)
        return 0
    return NumGet(itemRect, 12, "Int") - NumGet(itemRect, 4, "Int")
}

GetListClientHeight(listView) {
    clientRect := Buffer(16, 0)
    if !DllCall("user32\GetClientRect", "Ptr", listView.Hwnd,
            "Ptr", clientRect, "Int")
        return 0
    return NumGet(clientRect, 12, "Int") - NumGet(clientRect, 4, "Int")
}

GetListClientWidth(listView) {
    clientRect := Buffer(16, 0)
    if !DllCall("user32\GetClientRect", "Ptr", listView.Hwnd,
            "Ptr", clientRect, "Int")
        return 0
    return NumGet(clientRect, 8, "Int")
}

AssertControlTextFits(control, context) {
    clientRect := Buffer(16, 0)
    AssertTrue(DllCall("user32\GetClientRect", "Ptr", control.Hwnd,
        "Ptr", clientRect, "Int"), context "：无法读取控件宽度")
    deviceContext := DllCall("user32\GetDC", "Ptr", control.Hwnd, "Ptr")
    AssertTrue(deviceContext, context "：无法取得控件绘图上下文")
    font := SendMessage(0x0031, 0, 0, , control.Hwnd) ; WM_GETFONT
    previousFont := font ? DllCall("gdi32\SelectObject",
        "Ptr", deviceContext, "Ptr", font, "Ptr") : 0
    extent := Buffer(8, 0)
    try {
        AssertTrue(DllCall("gdi32\GetTextExtentPoint32W",
            "Ptr", deviceContext, "Str", control.Text,
            "Int", StrLen(control.Text), "Ptr", extent, "Int"),
            context "：无法测量文字")
        controlDpi := DllCall("user32\GetDpiForWindow", "Ptr", control.Hwnd,
            "UInt")
        if !controlDpi
            controlDpi := 96
        requiredWidth := NumGet(extent, 0, "Int")
            + Max(4, Round(4 * controlDpi / 96))
        availableWidth := NumGet(clientRect, 8, "Int")
        AssertTrue(requiredWidth <= availableWidth,
            context "：文字会被裁切（需要 " requiredWidth
                "px，实际 " availableWidth "px）")
    } finally {
        if previousFont
            DllCall("gdi32\SelectObject", "Ptr", deviceContext,
                "Ptr", previousFont)
        DllCall("user32\ReleaseDC", "Ptr", control.Hwnd,
            "Ptr", deviceContext)
    }
}

GetListColumnTotalWidth(listView) {
    totalWidth := 0
    Loop listView.GetCount("Column")
        totalWidth += SendMessage(0x101D, A_Index - 1, 0, , listView.Hwnd)
    return totalWidth
}

GetListItemBottom(listView, row) {
    itemRect := Buffer(16, 0)
    NumPut("Int", 0, itemRect, 0) ; LVIR_BOUNDS
    if !SendMessage(0x100E, row - 1, itemRect.Ptr, listView.Hwnd)
        return -1
    return NumGet(itemRect, 12, "Int")
}

GetGuiThreadCaretHwnd(targetHwnd := 0) {
    infoSize := A_PtrSize == 8 ? 72 : 48
    caretOffset := A_PtrSize == 8 ? 48 : 28
    threadInfo := Buffer(infoSize, 0)
    NumPut("UInt", infoSize, threadInfo, 0)
    threadId := targetHwnd
        ? DllCall("user32\GetWindowThreadProcessId", "Ptr", targetHwnd,
            "Ptr", 0, "UInt") : 0
    if !DllCall("user32\GetGUIThreadInfo", "UInt", threadId,
            "Ptr", threadInfo, "Int")
        return 0
    return NumGet(threadInfo, caretOffset, "Ptr")
}

FocusOffscreenControl(control, timeoutMs := 300) {
    hwnd := control.Hwnd
    if !hwnd || !DllCall("user32\IsWindowEnabled", "Ptr", hwnd, "Int")
        return false
    rootHwnd := DllCall("user32\GetAncestor", "Ptr", hwnd,
        "UInt", 2, "Ptr") ; GA_ROOT
    if !rootHwnd || !DllCall("user32\IsWindowEnabled", "Ptr", rootHwnd,
            "Int")
        return false
    deadline := A_TickCount + timeoutMs
    loop {
        DllCall("user32\SetActiveWindow", "Ptr", rootHwnd, "Ptr")
        DllCall("user32\SetFocus", "Ptr", hwnd, "Ptr")
        if DllCall("user32\GetFocus", "Ptr") == hwnd
            return true
        if A_TickCount >= deadline
            return false
        Sleep(10)
    }
}

GetEditSelection(editHwnd) {
    selectionStart := Buffer(4, 0)
    selectionEnd := Buffer(4, 0)
    SendMessage(Win32.EM_GETSEL, selectionStart.Ptr, selectionEnd.Ptr, ,
        editHwnd)
    return {
        Start: NumGet(selectionStart, 0, "UInt"),
        End: NumGet(selectionEnd, 0, "UInt")
    }
}

CreateSortTestMappings() {
    return [
        {Id: "custom-first", Source: "F9", Target: "F2", Scope: "窗口 B",
            Purpose: "目的乙"},
        {Id: "custom-second", Source: "F1", Target: "F8", Scope: "窗口 C",
            Purpose: "目的甲"},
        {Id: "custom-third", Source: "F5", Target: "F4", Scope: "窗口 A",
            Purpose: "目的丙"}
    ]
}

CreateGuiKeyboardIdentity(vk, sc, deviceId := "gui-keyboard") {
    normalizedVk := vk
    switch sc & 0x1FF {
        case 0x01D: keyName := "LCtrl", normalizedVk := 0xA2
        case 0x11D: keyName := "RCtrl", normalizedVk := 0xA3
        case 0x02A: keyName := "LShift", normalizedVk := 0xA0
        case 0x036: keyName := "RShift", normalizedVk := 0xA1
        case 0x038: keyName := "LAlt", normalizedVk := 0xA4
        case 0x138: keyName := "RAlt", normalizedVk := 0xA5
        default:
            keyName := GetKeyName(Format("sc{:03X}", sc & 0x1FF))
    }
    return KeyIdentity.Create("keyboard", keyName, normalizedVk, sc,
        (sc & 0x100) != 0, deviceId, deviceId, 1, 6)
}

SendGuiRawKey(session, vk, sc, phase, deviceId := "gui-keyboard") {
    event := InputEvent.Create(CreateGuiKeyboardIdentity(vk, sc, deviceId),
        phase, false, false, "raw-input")
    return session.ObserveRawInputEvent(event)
}

BuildGuiKeyboardCapture(session, vk, sc,
        deviceId := "gui-keyboard") {
    keyInfo := session.CreateRawKeyInfo(
        CreateGuiKeyboardIdentity(vk, sc, deviceId))
    return session.BuildCaptureFromInfo(keyInfo, [])
}

SendGuiDeviceRemoval(session, deviceId := "gui-keyboard") {
    device := Map("id", deviceId, "stable_id", deviceId,
        "display_name", deviceId, "type", "keyboard")
    event := InputEvent.Create(KeyIdentity.Create("device", deviceId),
        "removal", false, false, "raw-input-device", "",
        Map("device", device))
    return session.ObserveRawInputEvent(event)
}

CreateViewportTestMappings(count := 24) {
    mappings := []
    Loop count {
        mappings.Push({
            Id: "viewport-" A_Index,
            Source: "F" (Mod(A_Index, 24) + 1),
            Target: "F" (Mod(A_Index + 7, 24) + 1),
            Scope: "全局",
            Purpose: "列表整行视口测试 " A_Index
        })
    }
    return mappings
}

SendHeaderPointerClick(headerControl, downMessage) {
    clientRect := Buffer(16, 0)
    AssertTrue(DllCall("user32\GetClientRect", "Ptr", headerControl.Hwnd,
        "Ptr", clientRect, "Int"), "无法读取伪表头尺寸")
    x := Max(0, (NumGet(clientRect, 8, "Int") - 1) // 2)
    y := Max(0, (NumGet(clientRect, 12, "Int") - 1) // 2)
    point := ((y & 0xFFFF) << 16) | (x & 0xFFFF)
    SendMessage(downMessage, 1, point, headerControl.Hwnd)
    SendMessage(0x0202, 0, point, headerControl.Hwnd) ; WM_LBUTTONUP
    Sleep(20)
}

CaptureClipboardWithRetry(attempts := 20) {
    lastError := ""
    Loop attempts {
        try return ClipboardAll()
        catch as clipboardError
            lastError := clipboardError
        Sleep(25)
    }
    throw lastError
}

BuildLongCapture(session) {
    modifierSpecs := [
        ["LCtrl", 0xA2, 0x01D], ["RCtrl", 0xA3, 0x11D],
        ["LShift", 0xA0, 0x02A], ["RShift", 0xA1, 0x036],
        ["LAlt", 0xA4, 0x038], ["RAlt", 0xA5, 0x138],
        ["LWin", 0x5B, 0x15B], ["RWin", 0x5C, 0x15C]
    ]
    modifiers := []
    for spec in modifierSpecs {
        modifiers.Push(session.CreateKeyInfo("keyboard", spec[1],
            spec[2], spec[3], Format("sc{:03X}", spec[3])))
    }
    primaryKey := session.CreateKeyInfo("keyboard", "Media_Play_Pause",
        0xB3, 0x022, "Media_Play_Pause")
    return session.BuildCaptureFromInfo(primaryKey, modifiers)
}

AssertCaptureButtonIconState(window, button, shouldShow, context) {
    state := window.Interactions.Controls[button.Hwnd]
    if shouldShow {
        AssertTrue(state.HasOwnProp("ButtonImage")
            && RegExMatch(state.ButtonImage.SourcePath,
                "i)\\keyboard\.svg$")
            && state.HasOwnProp("TrailingButtonImage")
            && RegExMatch(state.TrailingButtonImage.SourcePath,
                "i)\\mouse\.svg$"),
            context "没有显示键盘、文字、鼠标双图标组合")
    } else {
        AssertTrue(!state.HasOwnProp("ButtonImage")
            && !state.HasOwnProp("TrailingButtonImage"),
            context "仍显示仅限初始状态的录制图标")
    }
}

AssertTextInputRegistrationRollback() {
    probeGui := Gui("+ToolWindow")
    interactions := MappingUiInteractions(probeGui, "FFFFFF")
    probeInput := probeGui.Add("Edit", "w120", "")
    inputHwnd := probeInput.Hwnd
    try {
        AssertTrue(!interactions.RegisterTextInput(probeInput, {}),
            "无效命中控件错误通过了文本输入注册")
        AssertTrue(!interactions.Controls.Has(inputHwnd)
                && !interactions.TextInputTargets.Has(inputHwnd),
            "文本输入注册失败后遗留内部控件状态")
        wasStillAttached := DllCall("comctl32\RemoveWindowSubclass",
            "Ptr", inputHwnd, "Ptr", interactions.SubclassCallback,
            "UPtr", MappingUiInteractions.SubclassId, "Int")
        AssertTrue(!wasStillAttached,
            "文本输入注册失败后遗留原生窗口子类")
        AssertTrue(interactions.Dispose()
                && interactions.DrawCallback == ""
                && interactions.ClickCallback == ""
                && interactions.PointerDownCallback == ""
                && !interactions.SubclassCallback,
            "交互层完整卸载后仍保留绑定回调引用")
    } finally {
        interactions.Dispose()
        probeGui.Destroy()
    }
}

AssertSubclassCallbackRetentionOnDetachFailure() {
    probeGui := Gui("+ToolWindow")
    interactions := MappingUiInteractions(probeGui, "FFFFFF")
    probeText := probeGui.Add("Text", "w120", "probe")
    probeHwnd := probeText.Hwnd
    try {
        AssertTrue(interactions.RegisterTextCursor(probeText),
            "子类回调保留测试无法注册文本光标")
        AssertTrue(DllCall("comctl32\RemoveWindowSubclass", "Ptr", probeHwnd,
            "Ptr", interactions.SubclassCallback, "UPtr",
            MappingUiInteractions.SubclassId, "Int"),
            "子类回调保留测试无法预先移除原生子类")
        AssertTrue(!interactions.Dispose(),
            "存活窗口的原生脱离失败被错误报告为完整清理")
        AssertTrue(interactions.SubclassCallback
                && interactions.AttachedHwnds.Has(probeHwnd),
            "原生脱离失败后释放了仍可能被窗口调用的回调")
        probeGui.Destroy()
        AssertTrue(interactions.Dispose()
                && !interactions.SubclassCallback
                && !interactions.AttachedHwnds.Count,
            "窗口销毁后的重试没有释放保留的子类回调")
    } finally {
        try probeGui.Destroy()
        try interactions.Dispose()
    }
}

AssertButtonAccessibilityAndTooltipLifecycle() {
    probeGui := Gui("+ToolWindow")
    interactions := MappingUiInteractions(probeGui, "FFFFFF")
    button := probeGui.Add("Text", "w140 h30 Center 0x200", "probe")
    try {
        AssertTrue(interactions.RegisterButton(button, "336699", (*) => 0,
                "", "", false, "FFFFFF"),
            "无法注册无障碍按钮探针")
        AssertTrue(ControlAccessibilityService.ActiveButtons.Has(button.Hwnd),
            "自绘按钮没有登记 MSAA 按钮角色")
        AssertTrue(interactions.SetButtonTooltip(button, "probe tooltip")
                && interactions.Controls[button.Hwnd].TooltipText
                    == "probe tooltip",
            "按钮提示没有进入共享交互状态")
        interactions.Dispose()
        AssertTrue(!ControlAccessibilityService.ActiveButtons.Has(button.Hwnd)
                && !IsObject(interactions.Tooltip),
            "按钮销毁后仍保留无障碍属性或提示窗口")
    } finally {
        try interactions.Dispose()
        try probeGui.Destroy()
    }
}

AssertDarkConfirmDialogLayoutAndOwnership() {
    owner := Gui("+ToolWindow")
    message := "A long diagnostic confirmation message must wrap without "
        . "overlapping either action button. "
        . "Paths, window titles, commands, code, and variable values are "
        . "summarized before export."
    dialog := ""
    try {
        dialog := DarkConfirmDialog(message, "Confirm", "Export diagnostics",
            "Cancel", owner)
        AssertTrue(!DllCall("user32\IsWindowEnabled", "Ptr", owner.Hwnd,
                "Int"),
            "深色确认框没有禁用直接上级")
        dialog.MessageText.GetPos(&messageX, &messageY, &messageWidth,
            &messageHeight)
        dialog.ConfirmButton.GetPos(&confirmX, &confirmY, &confirmWidth,
            &confirmHeight)
        dialog.CancelButton.GetPos(&cancelX, &cancelY, &cancelWidth,
            &cancelHeight)
        AssertTrue(messageWidth > 0 && messageHeight > 34
                && confirmY >= messageY + messageHeight
                && cancelY == confirmY
                && confirmX >= 0
                && cancelX + cancelWidth <= dialog.WindowWidth,
            "深色确认框长文本或按钮布局发生重叠/越界")
        AssertControlTextFits(dialog.ConfirmButton, "深色确认框主按钮")
        AssertControlTextFits(dialog.CancelButton, "深色确认框取消按钮")
        dialog.Dispose(false)
        AssertTrue(DllCall("user32\IsWindowEnabled", "Ptr", owner.Hwnd,
                "Int"),
            "深色确认框销毁后没有恢复直接上级")
    } finally {
        if IsObject(dialog)
            try dialog.Dispose(false)
        try owner.Destroy()
    }
}

AssertPseudoHeaderDispose() {
    probeGui := Gui("+ToolWindow")
    probeList := probeGui.Add("ListView", "w240 h100", ["one", "two"])
    header := ListViewPseudoHeader(probeGui, probeList, [
        {Column: 1, Label: "one"},
        {Column: 2, Label: "two"}
    ], {
        BackgroundColor: "FFFFFF", TextColor: "000000",
        FontName: "Segoe UI", FontSize: 9
    })
    firstCellHwnd := header.Cells[1].Hwnd
    try {
        AssertTrue(header.Dispose() && header.Disposed
                && !header.Cells.Length && !header.CellCallbacks.Count,
            "Pseudo-header disposal retained bound control callbacks")
        wasStillAttached := DllCall("comctl32\RemoveWindowSubclass",
            "Ptr", firstCellHwnd,
            "Ptr", ListViewPseudoHeader.InputGuardCallback,
            "UPtr", ListViewPseudoHeader.InputGuardSubclassId, "Int")
        AssertTrue(!wasStillAttached,
            "Pseudo-header disposal retained its native input subclass")
    } finally {
        try header.Dispose()
        probeGui.Destroy()
    }
}

AssertDarkComboRegistryInvalidationCleanup() {
    probeGui := Gui("+ToolWindow")
    probeCombo := probeGui.Add("DropDownList", "w120", ["one", "two"])
    handles := GetComboBoxThemeHandles(probeCombo.Hwnd)
    try {
        AssertTrue(handles.List
                && DarkComboBoxListThemeRegistry.Register(handles.List,
                    handles.Combo),
            "失效下拉列表清理测试无法注册主题句柄")
        probeGui.Destroy()
        DarkComboBoxListThemeRegistry.HandleListColor(0, handles.List)
        AssertTrue(!DarkComboBoxListThemeRegistry.IsRegistered(handles.List)
                && !DarkComboBoxListThemeRegistry.MessageRegistered
                && DarkComboBoxListThemeRegistry.MessageCallback == "",
            "最后一个失效下拉列表清理后仍保留全局消息回调")
    } finally {
        DarkComboBoxListThemeRegistry.Unregister(handles.List)
        try probeGui.Destroy()
    }
}

AssertSessionNotificationUnregisterRetry() {
    probe := SessionNotificationRetryProbe()
    AssertTrue(!probe.UnregisterSessionNotifications()
            && probe.SessionNotificationsRegistered,
        "WTS 注销失败后提前丢失了可重试状态")
    AssertTrue(probe.UnregisterSessionNotifications()
            && !probe.SessionNotificationsRegistered
            && probe.UnregisterCallCount == 2,
        "WTS 注销失败后的第二次清理没有成功重试")
}

EnvSet("KEY_MOUSE_REMAPPER_GUI_TEST_OFFSCREEN", "1")
EnableDarkProcessMode()
AssertTextInputRegistrationRollback()
AssertSubclassCallbackRetentionOnDetachFailure()
AssertButtonAccessibilityAndTooltipLifecycle()
AssertDarkConfirmDialogLayoutAndOwnership()
AssertPseudoHeaderDispose()
AssertDarkComboRegistryInvalidationCleanup()
AssertSessionNotificationUnregisterRetry()
app := TestKeyMouseRemapperAssistantApp()
guiTestFailure := ""
try {
    ShowOffscreenTestMappingWindow(app.Window, 860, 620, false)
    app.Window.RefreshCaptureLayout()
    AssertEqual("", app.Window.SourceDetail.Text,
        "尚未录制来源按键时仍显示详情占位内容")
    AssertEqual("", app.Window.TargetDetail.Text,
        "尚未录制目标按键时仍显示详情占位内容")
    AssertCaptureButtonIconState(app.Window, app.Window.SourceButton, true,
        "初始来源按钮")
    AssertCaptureButtonIconState(app.Window, app.Window.TargetButton, true,
        "初始目标按钮")
    AssertTrue(app.Window.HasOwnProp("DragActive")
        && !app.Window.DragActive,
        "拖拽状态没有在窗口构造时初始化")
    app.Window.OnListBeginDrag(app.Window.List, 0)
    windowExStyle := DllCall("user32\GetWindowLongPtrW", "Ptr",
        app.Window.Gui.Hwnd, "Int", -20, "Ptr")
    AssertTrue((windowExStyle & 0x02000000) == 0,
        "主窗口缩放路径仍启用会放大闪烁的 WS_EX_COMPOSITED")
    app.Window.BeginStableUpdate()
    AssertEqual(1, app.Window.RedrawLockDepth,
        "稳定更新没有登记窗口重绘锁")
    app.Window.EndStableUpdate()
    AssertEqual(0, app.Window.RedrawLockDepth,
        "稳定更新结束后仍遗留窗口重绘锁")
    app.ReloadScheduled := false
    app.LastToast := "EMPTY_HISTORY_SENTINEL"
    AssertTrue(!app.PerformUndo(), "空历史错误执行了撤销")
    AssertTrue(!app.ReloadScheduled
        && app.LastToast == "EMPTY_HISTORY_SENTINEL",
        "空历史错误显示提示或请求重新加载")
    applyCountBeforeControl := app.ManagedApplyCount
    app.ControlQueue.Publish("apply", A_ScriptFullPath,
        Map("reason", "gui-smoke"))
    AssertTrue(app.PollExternalControlQueue()
            && app.ManagedApplyCount > applyCountBeforeControl
            && !app.ReloadScheduled,
        "外部 managed 规则变更没有直接热应用")
    AssertEqual(0, app.ControlQueue.ConsumeFor(A_ScriptFullPath).Length,
        "已应用的外部控制请求没有从队列移除")
    app.ReloadScheduled := false

    sessionTraceBefore := app.Trace.Count
    AssertTrue(app.OnSessionChange(7, 42, 0x02B1,
            app.Window.Gui.Hwnd),
        "WTS 锁屏通知没有进入应用处理链")
    sessionTrace := app.Trace.Snapshot()
    sessionEntry := sessionTrace[sessionTrace.Length]
    AssertTrue(app.Trace.Count > sessionTraceBefore
            && sessionEntry.Category == "system"
            && sessionEntry.Event == "session_lock"
            && sessionEntry.Source == "42"
            && sessionEntry.Data["notification"] == 7
            && sessionEntry.Data.Has("lock_known")
            && sessionEntry.Data.Has("protocol"),
        "WTS 通知没有写入结构化事件")
    AssertTrue(app.SessionChangeEventName(3) == "session_remote_connect"
            && app.SessionChangeEventName(8) == "session_unlock"
            && app.SessionChangeEventName(99) == "session_change_unknown",
        "WTS 会话通知名称映射不完整")

    ShowOffscreenTestMappingWindow(app.Window, 860, 620)
    Sleep(40)
    AssertTestWindowOffscreen(app.Window.Gui.Hwnd, "主窗口")
    AssertEqual(ColorRef(MappingWindow.Colors.Window),
        ReadTestClientPixel(app.Window.Gui.Hwnd, 500, 430),
        "GUI 测试首帧绕过正式显示管线并露出错误背景")
    AssertTrue(FocusOffscreenControl(app.Window.PurposeEdit),
        "气泡测试前设计目的输入框没有取得焦点")
    AssertTrue(app.Toast.Show("已撤销：新增映射：LShift -> F23"),
        "撤销结果气泡无法显示")
    AssertEqual("show", app.Toast.AnimationPhase, "气泡没有开始入场动画")
    Sleep(220)
    AssertTrue(DllCall("user32\IsWindowVisible", "Ptr", app.Toast.Gui.Hwnd,
            "Int") && app.Toast.AnimationPhase == "idle"
        && app.Toast.CurrentAlpha == 255, "气泡入场动画没有完整结束")
    toastExStyle := DllCall("user32\GetWindowLongPtrW", "Ptr",
        app.Toast.Gui.Hwnd, "Int", -20, "Ptr")
    focusAfterToast := DllCall("user32\GetFocus", "Ptr")
    focusRootAfterToast := focusAfterToast
        ? DllCall("user32\GetAncestor", "Ptr", focusAfterToast,
            "UInt", 2, "Ptr")
        : 0
    AssertTrue((toastExStyle & 0x08000000) != 0
            && (toastExStyle & 0x00080000) != 0
            && focusRootAfterToast != app.Toast.Gui.Hwnd
            && DllCall("user32\GetForegroundWindow", "Ptr")
                != app.Toast.Gui.Hwnd,
        "撤销结果气泡缺少 NOACTIVATE/分层样式或抢走了输入焦点")
    AssertEqual("已撤销：新增映射：LShift -> F23", app.Toast.TextControl.Text,
        "气泡没有保留具体动作内容")
    ownerClient := Buffer(16, 0)
    ownerOrigin := Buffer(8, 0)
    toastRect := Buffer(16, 0)
    statusBounds := Buffer(16, 0)
    DllCall("user32\GetClientRect", "Ptr", app.Window.Gui.Hwnd,
        "Ptr", ownerClient)
    DllCall("user32\ClientToScreen", "Ptr", app.Window.Gui.Hwnd,
        "Ptr", ownerOrigin)
    DllCall("user32\GetWindowRect", "Ptr", app.Toast.Gui.Hwnd,
        "Ptr", toastRect)
    DllCall("user32\GetWindowRect", "Ptr", app.Window.Status.Hwnd,
        "Ptr", statusBounds)
    toastTextRect := Buffer(16, 0)
    DllCall("user32\GetWindowRect", "Ptr", app.Toast.TextControl.Hwnd,
        "Ptr", toastTextRect)
    ownerLeft := NumGet(ownerOrigin, 0, "Int")
    ownerTop := NumGet(ownerOrigin, 4, "Int")
    ownerRight := ownerLeft + NumGet(ownerClient, 8, "Int")
    ownerBottom := ownerTop + NumGet(ownerClient, 12, "Int")
    dpi := DllCall("user32\GetDpiForWindow", "Ptr", app.Window.Gui.Hwnd,
        "UInt")
    if !dpi
        dpi := 96
    expectedToastGap := Max(1, Round(3 * dpi / 96))
    AssertTrue(NumGet(toastRect, 0, "Int")
            == NumGet(statusBounds, 0, "Int")
        && NumGet(statusBounds, 4, "Int")
            - NumGet(toastRect, 12, "Int") == expectedToastGap
        && NumGet(toastRect, 0, "Int") >= ownerLeft
        && NumGet(toastRect, 8, "Int") <= ownerRight
        && NumGet(toastRect, 12, "Int") <= ownerBottom,
        "气泡没有左对齐并紧贴主窗口状态栏上方")
    AssertTrue(NumGet(toastTextRect, 8, "Int")
            - NumGet(toastTextRect, 0, "Int") > Round(120 * dpi / 96)
        && NumGet(toastTextRect, 8, "Int") < NumGet(toastRect, 8, "Int"),
        "气泡没有按真实文本宽度测量或文本超出窗口")
    AssertEqual("设置：界面语言、主题", app.FormatHistoryAction(
        app.CreateHistoryAction("settings", "", ["ui-language", "theme"])),
        "设置历史没有列出实际变化字段")
    regionProbe := DllCall("gdi32\CreateRectRgn", "Int", 0, "Int", 0,
        "Int", 1, "Int", 1, "Ptr")
    try AssertTrue(DllCall("user32\GetWindowRgn", "Ptr", app.Toast.Gui.Hwnd,
        "Ptr", regionProbe, "Int") > 0, "气泡没有应用圆角窗口区域")
    finally DllCall("gdi32\DeleteObject", "Ptr", regionProbe)
    app.Toast.Hide()
    AssertEqual("hide", app.Toast.AnimationPhase, "气泡没有开始退场动画")
    Sleep(50)
    AssertTrue(DllCall("user32\IsWindowVisible", "Ptr", app.Toast.Gui.Hwnd,
            "Int") && app.Toast.CurrentAlpha < 255,
        "气泡退场时没有可见的位移淡出过程")
    Sleep(150)
    AssertTrue(!DllCall("user32\IsWindowVisible", "Ptr", app.Toast.Gui.Hwnd,
        "Int"), "气泡退场动画结束后没有隐藏")
    app.Toast.Show("已撤销：新增映射：LShift -> F23")
    app.Toast.AnimationStartedTicks -= app.Toast.AnimationDurationMs
    app.Toast.AdvanceAnimation()
    firstHideDeadline := app.Toast.HideDeadlineTicks
    Sleep(10)
    app.Toast.Show("已重做：暂停映射：LShift -> F23")
    app.Toast.AnimationStartedTicks -= app.Toast.AnimationDurationMs
    app.Toast.AdvanceAnimation()
    secondHideDeadline := app.Toast.HideDeadlineTicks
    currentToastTicks := DllCall("kernel32\GetTickCount64", "UInt64")
    AssertTrue(DllCall("user32\IsWindowVisible", "Ptr", app.Toast.Gui.Hwnd,
            "Int") && secondHideDeadline > firstHideDeadline
            && secondHideDeadline - currentToastTicks >= 2900,
        "连续提示没有重新计算三秒停留时间")
    app.Toast.HideNow()
    AssertTrue(!DllCall("user32\IsWindowVisible", "Ptr", app.Toast.Gui.Hwnd,
        "Int"), "气泡立即隐藏后仍然可见")
    app.Window.Gui.Show("Hide")
    app.Window.Gui.GetClientPos(, , , &layoutClientHeight)
    app.Window.List.GetPos(, &listY, , &baseListHeight)
    app.Window.SectionTitle.GetPos(, &sectionTitleY)
    app.Window.SourceButton.GetPos(, &sourceButtonY, , &sourceButtonHeight)
    app.Window.SourceDetail.GetPos(, &sourceDetailY, , &sourceDetailHeight)
    app.Window.SaveButton.GetPos(, &saveButtonY)
    AssertTrue(sourceDetailY >= sourceButtonY + sourceButtonHeight
        && sourceDetailY + sourceDetailHeight <= saveButtonY,
        "按键编码详情与录制按钮或底部命令区重叠")
    AssertTrue(sourceButtonHeight >= MappingWindow.MinCaptureButtonHeight
        && sourceDetailHeight >= MappingWindow.MinCaptureDetailHeight,
        "录制区域没有使用增高后的基础尺寸")
    AssertEqual(listY + baseListHeight + 10, sectionTitleY,
        "新建映射标题没有保持紧凑的列表后间距")
    app.Window.SectionTopDivider.GetPos(&sectionDividerX,
        &sectionTopDividerY, &sectionDividerWidth, &sectionDividerHeight)
    app.Window.SourceLabel.GetPos(, &sourceLabelY)
    app.Window.SectionTitle.GetPos(&sectionTitleX, , &sectionTitleWidth,
        &sectionTitleHeight)
    sectionTitleStyle := DllCall("user32\GetWindowLongPtrW", "Ptr",
        app.Window.SectionTitle.Hwnd, "Int", -16, "Ptr")
    AssertTrue(sectionDividerX == 10
            && sectionDividerWidth == sectionTitleWidth
            && sectionDividerHeight == 1
            && sectionTopDividerY == listY + baseListHeight + 6
            && sectionTitleY == sectionTopDividerY + 4
            && sourceLabelY == sectionTitleY + sectionTitleHeight + 8
            && (sectionTitleStyle & 0x3) == 0x1,
        "新建区域没有按间距、分隔线、标题、间距的顺序布局")
    AssertTrue(!app.Window.HasOwnProp("SectionBottomDivider"),
        "新建映射标题下方仍保留下分隔线控件")
    expectedListHeight := app.Window.AlignListHeightToWholeRows(
        Max(MappingWindow.MinListHeight,
            layoutClientHeight - MappingWindow.ListLayoutFixedHeight
                - sourceButtonHeight - sourceDetailHeight))
    AssertEqual(expectedListHeight, baseListHeight,
        "ListView 没有把回收的高度向下对齐到完整原生行")
    for alignmentColumn in [2, 3, 4] {
        AssertEqual("Center", app.Window.ListHeader.Columns[alignmentColumn].Align,
            "伪表头指定字段没有居中：" alignmentColumn)
        columnInfo := Buffer(A_PtrSize == 8 ? 56 : 44, 0)
        NumPut("UInt", 0x1, columnInfo, 0) ; LVCF_FMT
        AssertTrue(SendMessage(0x105F, alignmentColumn - 1,
                columnInfo.Ptr, , app.Window.List.Hwnd) != 0,
            "无法读取 ListView 列格式：" alignmentColumn)
        AssertEqual(0x2, NumGet(columnInfo, 4, "Int") & 0x3,
            "ListView 指定字段没有使用原生居中格式：" alignmentColumn)
    }
    sourceButtonFont := SendMessage(0x0031, 0, 0, , app.Window.SourceButton.Hwnd)
    sourceDetailFont := SendMessage(0x0031, 0, 0, , app.Window.SourceDetail.Hwnd)
    oldCaptureBounds := app.Window.GetCaptureLayoutBounds()
    app.Window.TargetButton.GetPos(, &oldTargetY, , &oldTargetHeight)
    oldTargetProbeY := oldTargetY + oldTargetHeight // 2
    longCapture := BuildLongCapture(app.Capture)
    app.Window.AcceptCapture("source", longCapture)
    newCaptureBounds := app.Window.GetCaptureLayoutBounds()
    app.Window.SourceButton.GetPos(, &longButtonY, , &longButtonHeight)
    app.Window.TargetButton.GetPos(, &longTargetY, , &longTargetHeight)
    app.Window.SourceDetail.GetPos(, &longDetailY, , &longDetailHeight)
    app.Window.SaveButton.GetPos(, &longSaveY)
    app.Window.List.GetPos(, , , &longListHeight)
    app.Window.Status.GetPos(, &longStatusY, &longStatusWidth,
        &longStatusHeight)
    app.Window.Gui.GetClientPos(, , , &longClientHeight)
    expectedLongStatusHeight := Max(MappingWindow.MinStatusHeight,
        app.Window.Interactions.Painter.MeasureTextHeight(app.Window.Status,
            app.Window.Status.Text, longStatusWidth) + 4)
    AssertEqual(longCapture.RawDisplay, app.Window.SourceButton.Text,
        "超长组合键按钮文字被替换或截短")
    AssertTrue(longButtonHeight > MappingWindow.MinCaptureButtonHeight,
        "超长组合键没有增高录制按钮")
    AssertTrue(longDetailHeight > MappingWindow.MinCaptureDetailHeight,
        "超长组合键没有增高逐行详情区")
    AssertTrue(longDetailY >= longButtonY + longButtonHeight
        && longDetailY + longDetailHeight <= longSaveY,
        "超长组合键详情与按钮或命令区重叠")
    AssertTrue(longListHeight >= MappingWindow.MinListHeight,
        "超长组合键挤占了列表最低可用高度")
    AssertTrue(longStatusHeight > MappingWindow.MinStatusHeight
            && longStatusHeight == expectedLongStatusHeight,
        "超长录制状态没有按完整换行文本动态增高")
    AssertTrue(longStatusY >= longDetailY + longDetailHeight
            && longStatusY + longStatusHeight
                == longClientHeight - MappingWindow.StatusBottomMargin,
        "动态状态栏与按键详情重叠或超出窗口底部")
    AssertTrue(oldTargetProbeY > longTargetY + longTargetHeight,
        "残影测试点仍落在移动后的目标按钮范围内")
    AssertTrue(oldCaptureBounds && newCaptureBounds
            && newCaptureBounds.Top < oldCaptureBounds.Top,
        "录制区动态增高没有生成覆盖新旧控件位置的重绘边界")
    AssertTrue(app.Window.RedrawCaptureLayout(oldCaptureBounds,
        newCaptureBounds), "录制区新旧边界无法执行同步定向重绘")
    AssertEqual(sourceButtonFont,
        SendMessage(0x0031, 0, 0, , app.Window.SourceButton.Hwnd),
        "超长组合键错误缩小了按钮字体")
    AssertEqual(sourceDetailFont,
        SendMessage(0x0031, 0, 0, , app.Window.SourceDetail.Hwnd),
        "超长组合键错误缩小了详情字体")
    AssertTrue(app.Window.Interactions.Controls[app.Window.SourceButton.Hwnd].Multiline,
        "录制按钮自绘文本没有启用多行模式")
    app.Window.SetStatus(Tr("准备就绪"))
    app.Window.Status.GetPos(, , , &shortStatusHeight)
    AssertEqual(MappingWindow.MinStatusHeight, shortStatusHeight,
        "短状态恢复后没有收回多余状态栏高度")
    app.Window.ClearEditor(false)
    AssertEqual("", app.Window.SourceDetail.Text,
        "清空后仍残留来源按键详情")
    AssertEqual("", app.Window.TargetDetail.Text,
        "清空后仍残留目标按键详情")
    AssertTrue(app.NormalizeSignature("左侧 Ctrl")
        != app.NormalizeSignature("右侧 Ctrl"),
        "冲突检测仍然合并左右 Ctrl")
    AssertTrue(app.NormalizeSignature("左侧 Shift")
        != app.NormalizeSignature("右侧 Shift"),
        "冲突检测仍然合并左右 Shift")
    AssertEqual(app.NormalizeSignature("左 Ctrl"),
        app.NormalizeSignature("左侧 Ctrl"), "旧版左侧名称兼容失败")
    AssertTrue((ControlGetStyle(app.Window.SourceButton) & 0x100) != 0,
        "来源按钮必须使用 SS_NOTIFY 接收命中")
    AssertTrue(app.Window.Interactions.Controls.Has(app.Window.SourceButton.Hwnd),
        "来源按钮未注册到自绘交互层")
    AssertTrue(!app.Window.HasOwnProp("MoveUpButton")
        && !app.Window.HasOwnProp("MoveDownButton")
        && !app.Window.HasOwnProp("MoveSelected"),
        "上移或下移按钮相关界面状态没有彻底移除")
    AssertTrue(!app.Window.HasOwnProp("ReloadButton"),
        "主工具栏仍保留需要用户手动操作的重新加载按钮")
    AssertEqual(app.Window.GetAddButtonText(), app.Window.AddButton.Text,
        "新增按钮仍保留冗余名称")
    AssertEqual(app.Window.GetPauseButtonText(),
        app.Window.PauseResumeButton.Text,
        "暂停按钮仍保留冗余名称")
    AssertEqual(app.Window.GetDeleteButtonText(), app.Window.DeleteButton.Text,
        "删除按钮仍保留冗余名称")
    AssertEqual("设置", app.Window.SettingsButton.Text,
        "设置按钮名称错误")
    AssertTrue(!app.Window.HasOwnProp("EventButton"),
        "主界面仍保留与帮助信息重复的事件查看器按钮")
    AssertEqual("帮助信息", app.Window.SupportButton.Text,
        "帮助信息按钮名称错误")
    AssertEqual("捐赠", app.Window.DonateButton.Text,
        "捐赠按钮名称错误")
    app.Window.AddButton.GetPos(&addButtonX, , &addButtonWidth,
        &addButtonHeight)
    app.Window.PauseResumeButton.GetPos(&pauseButtonX)
    app.Window.DeleteButton.GetPos(&deleteButtonX)
    app.Window.SettingsButton.GetPos(&settingsButtonX, &settingsButtonY,
        &settingsButtonWidth, &settingsButtonHeight)
    app.Window.SupportButton.GetPos(&supportButtonX, , &supportButtonWidth,
        &supportButtonHeight)
    app.Window.DonateButton.GetPos(&donateButtonX, , &donateButtonWidth,
        &donateButtonHeight)
    app.Window.Gui.GetClientPos(, , &toolbarClientWidth)
    AssertTrue(addButtonX < pauseButtonX && pauseButtonX < deleteButtonX
        && deleteButtonX < settingsButtonX
        && settingsButtonX < supportButtonX
        && supportButtonX < donateButtonX,
        "主工具栏命令没有按功能组和小助手右侧工具顺序排列")
    AssertTrue(donateButtonX + donateButtonWidth
            == toolbarClientWidth - MappingWindow.ToolbarRightMargin
        && settingsButtonWidth == MappingWindow.SettingsButtonWidth
        && settingsButtonHeight == MappingWindow.SettingsButtonHeight
        && settingsButtonWidth <= 140
        && settingsButtonHeight == addButtonHeight
        && supportButtonHeight == addButtonHeight
        && donateButtonHeight == addButtonHeight,
        "右侧工具按钮没有使用紧凑规格或捐赠按钮未贴齐命令栏右侧")
    for toolbarIconSpec in [
        {Button: app.Window.SettingsButton, Icon: "settings.svg"},
        {Button: app.Window.SupportButton, Icon: "circle-question-mark.svg"},
        {Button: app.Window.DonateButton, Icon: "heart.svg"}
    ] {
        toolbarIconState := app.Window.Interactions.Controls[
            toolbarIconSpec.Button.Hwnd]
        AssertTrue(toolbarIconState.HasOwnProp("ButtonImage")
            && RegExMatch(toolbarIconState.ButtonImage.SourcePath,
                "i)\\" toolbarIconSpec.Icon "$"),
            "主工具栏缺少语义化彩色图标：" toolbarIconSpec.Icon)
    }
    app.Window.Interactions.RunClick(app.Window.SupportButton.Hwnd)
    AssertTrue(IsObject(app.SupportInfo)
            && !DllCall("user32\IsWindowEnabled", "Ptr",
                app.Window.Gui.Hwnd, "Int"),
        "帮助信息按钮没有打开同款分流窗口或建立 Owner 层级")
    AssertTestWindowOffscreen(app.SupportInfo.Gui.Hwnd, "帮助信息分流窗口")
    app.SupportInfo.RequestClose()
    AssertTrue(!IsObject(app.SupportInfo)
            && DllCall("user32\IsWindowEnabled", "Ptr",
                app.Window.Gui.Hwnd, "Int"),
        "帮助信息窗口关闭后没有释放引用或恢复主窗口")
    app.Window.Interactions.RunClick(app.Window.DonateButton.Hwnd)
    AssertTrue(IsObject(app.Donation)
            && app.Donation.QrPictures.Length == 2
            && !DllCall("user32\IsWindowEnabled", "Ptr",
                app.Window.Gui.Hwnd, "Int"),
        "捐赠按钮没有打开二维码窗口或建立 Owner 层级")
    AssertTestWindowOffscreen(app.Donation.Gui.Hwnd, "捐赠窗口")
    app.Donation.RequestClose()
    AssertTrue(!IsObject(app.Donation)
            && DllCall("user32\IsWindowEnabled", "Ptr",
                app.Window.Gui.Hwnd, "Int"),
        "捐赠窗口关闭后没有释放引用或恢复主窗口")
    app.ReloadScheduled := false
    app.Window.Interactions.RunClick(app.Window.AddButton.Hwnd)
    AssertTrue(IsObject(app.Window.BlockEditor)
            && app.Window.BlockEditor.IsNew,
        "顶部新增按钮没有打开新增模式 mapping 编辑器")
    newMappingEditor := app.Window.BlockEditor
    AssertTestWindowOffscreen(newMappingEditor.Gui.Hwnd, "新增映射编辑器")
    blankMappingText := newMappingEditor.Canonicalize(
        newMappingEditor.GetCodeText())
    AssertTrue(InStr(blankMappingText, "; @schema=2")
            && InStr(blankMappingText, "; @mode=managed")
            && RegExMatch(blankMappingText, "m)^; @id=[^`r`n]+$")
            && InStr(blankMappingText, "; @spec-begin")
            && InStr(blankMappingText, "; @spec-end")
            && RegExMatch(blankMappingText,
                "m)^; @generated-sha256=[A-Fa-f0-9]{64}$")
            && InStr(blankMappingText, "; @generated-begin")
            && InStr(blankMappingText, "; @generated-end")
            && !app.Capture.Active,
        "新增编辑器没有预填完整 RuleSpec v2 包络或错误启动了按键录制")
    Loop Parse blankMappingText, "`n", "`r"
        AssertTrue(A_LoopField == "" || SubStr(LTrim(A_LoopField), 1, 1) == ";",
            "新增编辑器模板包含可执行 AHK：" A_LoopField)
    AssertEqual("元数据说明", newMappingEditor.MetadataTitle.Text,
        "新增编辑器没有显示元数据说明标题")
    AssertEqual(8, newMappingEditor.MetadataRows.Length,
        "新增编辑器没有逐项解释精简后的元数据")
    metadataExplanationText := ""
    for metadataDisplayRow in newMappingEditor.MetadataRows
        metadataExplanationText .= metadataDisplayRow.Name " "
            . metadataDisplayRow.DescriptionControl.Text "`n"
    AssertTrue(InStr(metadataExplanationText, "@schema")
            && InStr(metadataExplanationText, "RuleSpec 外壳")
            && InStr(metadataExplanationText, "@id")
            && InStr(metadataExplanationText, "@spec-begin")
            && InStr(metadataExplanationText, "@generated-sha256")
            && InStr(metadataExplanationText, "SHA-256")
            && InStr(newMappingEditor.MetadataNote.Text, "不会保存到代码"),
        "新增编辑器的元数据说明不完整")
    AssertTrue(!InStr(blankMappingText, newMappingEditor.MetadataTitle.Text)
            && !InStr(blankMappingText, "唯一编号")
            && !InStr(blankMappingText, "不会保存到代码"),
        "仅显示的元数据说明进入了可保存代码")
    lineNumberText := newMappingEditor.Canonicalize(
        ControlGetText(newMappingEditor.LineNumberEdit))
    AssertEqual(149, newMappingEditor.StartLine,
        "新增编辑器没有采用仓储预测的源码起始行")
    AssertTrue(RegExMatch(lineNumberText, "^149`n150")
            && RegExMatch(lineNumberText, "160$"),
        "新增编辑器没有显示与模板行数一致的连续源码行号")
    gutterStyle := DllCall("user32\GetWindowLongPtrW", "Ptr",
        newMappingEditor.LineNumberEdit.Hwnd, "Int", -16, "Ptr")
    AssertTrue((gutterStyle & 0x0800) != 0
            && (gutterStyle & 0x0080) != 0
            && (gutterStyle & 0x00010000) == 0,
        "行号栏没有保持只读、禁止软换行或仍可通过 Tab 聚焦")
    AssertTrue(FocusOffscreenControl(newMappingEditor.CodeEdit),
        "行号栏测试前代码区没有取得焦点")
    SendMessage(Win32.WM_LBUTTONDOWN, 1, 0,
        newMappingEditor.LineNumberEdit.Hwnd)
    SendMessage(Win32.WM_LBUTTONUP, 0, 0,
        newMappingEditor.LineNumberEdit.Hwnd)
    AssertEqual(newMappingEditor.CodeEdit.Hwnd,
        DllCall("user32\GetFocus", "Ptr"),
        "鼠标点击只读行号栏后没有把焦点保留在代码区")
    newMappingEditor.Gui.GetClientPos(, , &newEditorWidth, &newEditorHeight)
    AssertTrue(newEditorWidth >= MappingBlockEditor.NewEditorMinimumWidth
            && newEditorWidth <= MappingBlockEditor.NewEditorWidth,
        "新增编辑器宽度超出响应式设计范围：" newEditorWidth)
    AssertTrue(newEditorHeight >= MappingBlockEditor.NewEditorMinimumHeight
            && newEditorHeight <= MappingBlockEditor.NewEditorHeight,
        "新增编辑器高度超出响应式设计范围：" newEditorHeight)
    newMappingEditor.CodeEdit.GetPos(&newEditorCodeX, &newEditorCodeY,
        &newEditorCodeWidth, &newEditorCodeHeight)
    newMappingEditor.LineNumberEdit.GetPos(&gutterX, &gutterY,
        &gutterWidth, &gutterHeight)
    newMappingEditor.LineNumberDivider.GetPos(&gutterDividerX,
        &gutterDividerY, &gutterDividerWidth, &gutterDividerHeight)
    AssertTrue(gutterX == 14 && gutterY == newEditorCodeY
            && gutterX + gutterWidth == gutterDividerX
            && gutterDividerX + gutterDividerWidth == newEditorCodeX
            && gutterHeight == newEditorCodeHeight
            && gutterDividerHeight == newEditorCodeHeight,
        "行号栏、分隔线与代码区没有形成连续编辑表面")
    newMappingEditor.MetadataTitle.GetPos(&metadataX, &metadataY,
        &metadataWidth, &metadataTitleHeight)
    AssertTrue(metadataX >= newEditorCodeX + newEditorCodeWidth
            + MappingBlockEditor.MetadataPanelGap
            && metadataY == newEditorCodeY && metadataWidth >= 250,
        "代码编辑区与元数据说明区没有形成稳定的左右分栏")
    previousRowBottom := metadataY + metadataTitleHeight
    for metadataGeometryRow in newMappingEditor.MetadataRows {
        metadataGeometryRow.NameControl.GetPos(&rowNameX, &rowY,
            &rowNameWidth, &metadataRowHeight)
        metadataGeometryRow.DescriptionControl.GetPos(&rowDescriptionX,
            &descriptionY, &metadataDescriptionWidth, &descriptionHeight)
        AssertTrue(rowY >= previousRowBottom && descriptionY == rowY
                && rowNameX == metadataX
                && rowDescriptionX >= rowNameX + rowNameWidth
                && metadataDescriptionWidth > 0
                && descriptionHeight == metadataRowHeight,
            "元数据说明行发生重叠或列布局错误："
                metadataGeometryRow.Name)
        previousRowBottom := rowY + metadataRowHeight
    }
    newMappingEditor.MetadataNote.GetPos(&noteX, &metadataNoteY,
        &noteWidth, &metadataNoteHeight)
    AssertTrue(noteX == metadataX && metadataNoteY >= previousRowBottom
            && noteWidth == metadataWidth
            && metadataNoteY + metadataNoteHeight
                <= newEditorCodeY + newEditorCodeHeight,
        "元数据说明脚注越出代码编辑区或覆盖字段说明")
    newMappingEditor.Gui.Show(GetOffscreenTestWindowOptions(880, 500))
    Sleep(80)
    newMappingEditor.CodeEdit.GetPos(, , &minimumCodeWidth,
        &minimumCodeHeight)
    newMappingEditor.LineNumberEdit.GetPos(, , &minimumGutterWidth)
    newMappingEditor.MetadataTitle.GetPos(&minimumMetadataX, ,
        &minimumMetadataWidth)
    newMappingEditor.MetadataNote.GetPos(, &minimumNoteY, ,
        &minimumNoteHeight)
    AssertTrue(minimumCodeWidth + minimumGutterWidth
                + MappingBlockEditor.GutterSeparatorWidth >= 480
            && minimumMetadataWidth >= 250
            && minimumMetadataX >= 14 + minimumGutterWidth
                + MappingBlockEditor.GutterSeparatorWidth + minimumCodeWidth
                + MappingBlockEditor.MetadataPanelGap
            && minimumNoteY + minimumNoteHeight <= 46 + minimumCodeHeight,
        "新增编辑器最小尺寸下元数据说明区发生裁切或覆盖")
    LocalizationService.Configure("en-US", "auto")
    newMappingEditor.ApplyAppearance()
    AssertEqual("Metadata reference", newMappingEditor.MetadataTitle.Text,
        "元数据说明标题没有随语言原位切换")
    AssertTrue(InStr(newMappingEditor.MetadataRows[1].DescriptionControl.Text,
            "RuleSpec envelope")
            && InStr(newMappingEditor.MetadataNote.Text, "display-only"),
        "元数据说明内容没有随语言原位切换")
    LocalizationService.Configure("zh-CN", "auto")
    newMappingEditor.ApplyAppearance()
    variableFormat := ReadCharacterFormat(newMappingEditor.CodeEdit.Hwnd,
        InStr(blankMappingText, "@id") - 1)
    valueFormat := ReadCharacterFormat(newMappingEditor.CodeEdit.Hwnd,
        InStr(blankMappingText, "@id=") + 2)
    lineNumberFormat := ReadCharacterFormat(
        newMappingEditor.LineNumberEdit.Hwnd, 0)
    AssertEqual(ColorRef(MappingWindow.Colors.CodeVariable),
        variableFormat.Color, "元数据变量名没有使用参考图橙色")
    AssertEqual(ColorRef(MappingWindow.Colors.CodeValue),
        valueFormat.Color, "元数据变量值没有使用参考图绿色")
    AssertEqual(ColorRef(MappingWindow.Colors.CodeLineNumber),
        lineNumberFormat.Color, "源码行号没有使用参考图灰色")
    newBlockText := "; @mapping-begin`r`n"
        . "; @schema=2`r`n"
        . "; @mode=managed`r`n"
        . "; @id=editor-created`r`n"
        . "; @spec-begin`r`n"
        . "; {`"schema`":2,`"id`":`"editor-created`",`"enabled`":true}`r`n"
        . "; @spec-end`r`n"
        . "; @generated-sha256=" Format("{:064}", 0) "`r`n"
        . "; @generated-begin`r`n"
        . "; 此规则由托管运行时注册。`r`n"
        . "; @generated-end`r`n"
        . "; @mapping-end"
    AssertTrue(newMappingEditor.SetCodeText(newBlockText),
        "新增编辑器无法原子替换代码文本")
    newMappingEditor.Save()
    AssertTrue(!IsObject(app.Window.BlockEditor),
        "新增 mapping 保存后编辑器没有关闭")
    AssertTrue(newMappingEditor.NativeFinalizeTimer == ""
            && newMappingEditor.ThemeTimer == ""
            && newMappingEditor.FormatTimer == ""
            && newMappingEditor.ScrollTimer == ""
            && newMappingEditor.CommandCallback == ""
            && newMappingEditor.KeyDownCallback == ""
            && newMappingEditor.NativeDestroyCallback == "",
        "mapping 编辑器关闭后仍保留绑定回调引用")
    AssertEqual(1, app.Repository.AppendBlockCount,
        "新增 mapping 没有调用完整代码块追加接口")
    AssertTrue(InStr(app.Repository.LastBlockText, "; @id=editor-created")
            && app.Window.FindMappingRow("editor-created") > 0,
        "新增 mapping 没有同时进入源码仓储和 ListView")
    AssertTrue(!app.ReloadScheduled && app.MappingCount == 1,
        "新增 managed mapping 后没有更新计数或错误请求了脚本重载")
    app.Window.List.Delete()
    app.MappingCount := 0
    app.ReloadScheduled := false
    app.Window.UpdateSelectionButtons()
    inactivePauseState := app.Window.Interactions.Controls[
        app.Window.PauseResumeButton.Hwnd]
    AssertTrue(inactivePauseState.Normal == MappingWindow.Colors.PauseDisabled
        && inactivePauseState.TextColor
            == MappingWindow.Colors.DisabledButtonText
        && !inactivePauseState.Interactive,
        "无选中项时暂停按钮没有采用小助手的灰化禁用态")
    inactiveDeleteState := app.Window.Interactions.Controls[
        app.Window.DeleteButton.Hwnd]
    AssertTrue(inactiveDeleteState.Normal
            == MappingWindow.Colors.DeleteDisabled
        && inactiveDeleteState.TextColor
            == MappingWindow.Colors.DisabledButtonText
        && !inactiveDeleteState.Interactive,
        "无选中项时删除按钮没有采用小助手的灰化禁用态")
    app.Window.Interactions.RunClick(app.Window.DeleteButton.Hwnd)
    AssertEqual(0, app.Repository.RemoveCount,
        "已经灰化的按钮仍执行了队列中的延迟点击")
    AssertTrue(app.Window.Interactions.Controls.Has(app.Window.SettingsButton.Hwnd),
        "设置按钮未接入自绘交互层")
    for textButton in [app.Window.AddButton,
            app.Window.PauseResumeButton, app.Window.DeleteButton] {
        textButtonState := app.Window.Interactions.Controls[textButton.Hwnd]
        AssertTrue(!textButtonState.HasOwnProp("ButtonImage"),
            "小助手同款 Emoji 主命令按钮仍残留 Lucide 图像")
    }
    AssertEqual(app.Window.GetAddButtonText(), app.Window.AddButton.Text,
        "新增按钮没有使用小助手同款 Emoji 文本")
    AssertEqual(app.Window.GetPauseButtonText(),
        app.Window.PauseResumeButton.Text,
        "暂停按钮没有使用小助手同款 Emoji 文本")
    AssertEqual(app.Window.GetDeleteButtonText(), app.Window.DeleteButton.Text,
        "删除按钮没有使用小助手同款 Emoji 文本")
    for iconContract in [
        {Control: app.Window.SettingsButton, Icon: "settings.svg",
            Tint: StrLower(MappingWindow.ToolbarIconColor)},
        {Control: app.Window.ClearButton, Icon: "eraser.svg",
            Tint: StrLower(MappingWindow.ToolbarIconColor)}
    ] {
        iconState := app.Window.Interactions.Controls[iconContract.Control.Hwnd]
        expectedTint := iconContract.HasOwnProp("Tint")
            ? iconContract.Tint : "none"
        AssertTrue(iconState.HasOwnProp("ButtonImage")
            && IsObject(iconState.ButtonImage)
            && iconState.ButtonImage.TintMode == expectedTint
            && RegExMatch(iconState.ButtonImage.SourcePath,
                "i)\\" iconContract.Icon "$"),
            "按钮图标或颜色没有符合小助手规范：" iconContract.Icon)
    }
    AssertTrue(!app.Window.Interactions.Controls[
            app.Window.SaveButton.Hwnd].HasOwnProp("ButtonImage"),
        "保存映射作为表单提交动作不应附加图标")
    for button in [app.Window.AddButton, app.Window.PauseResumeButton,
            app.Window.DeleteButton, app.Window.SettingsButton,
            app.Window.SupportButton, app.Window.DonateButton,
            app.Window.SaveButton, app.Window.ClearButton] {
        AssertTrue(app.Window.Interactions.Controls[button.Hwnd]
                .TooltipText == "",
            "主窗口按钮不应显示基准项目不存在的悬浮文案")
    }
    arrowState := app.Window.Interactions.Controls[app.Window.ArrowText.Hwnd]
    AssertTrue(arrowState.Kind == "icon"
        && RegExMatch(arrowState.ButtonImage.SourcePath,
            "i)\\arrow-right\.svg$"),
        "映射方向提示没有使用非交互 Lucide 图标")
    contextPopup := app.Window.ContextPopup
    AssertTrue(IsObject(contextPopup)
            && contextPopup.Interactions.Controls.Has(
                contextPopup.EditButton.Hwnd),
        "映射右键操作窗没有接入共享自绘交互层")
    popupButtonState := contextPopup.Interactions.Controls[
        contextPopup.EditButton.Hwnd]
    AssertTrue(popupButtonState.Hover == UiThemeService.Color("MenuHover")
        && RegExMatch(popupButtonState.ButtonImage.SourcePath,
            "i)\\pencil\.svg$"),
        "映射右键操作窗没有采用菜单悬浮色")
    AssertTrue(FocusOffscreenControl(app.Window.List),
        "右键弹层测试前列表没有取得焦点")
    Sleep(20)
    contextFocusBefore := DllCall("user32\GetFocus", "Ptr")
    contextForegroundBefore := DllCall("user32\GetForegroundWindow", "Ptr")
    contextSuspendedBefore := A_IsSuspended
    AssertTrue(contextPopup.ShowForMapping("popup-focus-test"),
        "映射右键操作窗无法显示")
    Sleep(20)
    popupExStyle := DllCall("user32\GetWindowLongPtrW", "Ptr",
        contextPopup.Gui.Hwnd, "Int", -20, "Ptr")
    AssertTrue(contextPopup.IsVisible()
            && (popupExStyle & 0x08000000) != 0
            && contextFocusBefore == DllCall("user32\GetFocus", "Ptr")
            && contextForegroundBefore
                == DllCall("user32\GetForegroundWindow", "Ptr")
            && contextSuspendedBefore == A_IsSuspended,
        "映射右键操作窗抢占了焦点、前台窗口或脚本输入状态")
    popupRegionProbe := DllCall("gdi32\CreateRectRgn", "Int", 0,
        "Int", 0, "Int", 1, "Int", 1, "Ptr")
    try popupRegionType := DllCall("user32\GetWindowRgn", "Ptr",
        contextPopup.Gui.Hwnd, "Ptr", popupRegionProbe, "Int")
    finally DllCall("gdi32\DeleteObject", "Ptr", popupRegionProbe)
    AssertTrue(popupRegionType > 0,
        "映射右键操作窗没有应用稳定的圆角窗口区域")
    contextPopup.Hide()
    app.Window.PurposeEdit.Value := ""
    AssertTrue(FocusOffscreenControl(app.Window.PurposeEdit),
        "右键弹层测试前设计目的输入框没有取得焦点")
    AssertTrue(contextPopup.ShowForMapping("popup-keyboard-test"),
        "键盘连通性测试无法显示映射右键操作窗")
    AssertEqual(app.Window.PurposeEdit.Hwnd,
        DllCall("user32\GetFocus", "Ptr"),
        "右键弹层显示后改变了设计目的输入框焦点")
    ; 自动化窗口按约定放在屏幕外，Windows 会拒绝把它激活为前台窗口；
    ; 这里直接向仍持有焦点的 Edit 发送文本，验证非模态弹层没有禁用
    ; Owner 线程或阻塞普通控件输入。
    ControlSendText("K", app.Window.PurposeEdit)
    Sleep(20)
    AssertEqual("K", app.Window.PurposeEdit.Value,
        "映射右键操作窗显示期间普通键盘输入被阻塞")
    contextPopup.Hide()
    app.Window.ApplyNativeThemes()
    if !DllCall("uxtheme\GetWindowTheme", "Ptr", app.Window.List.Hwnd, "Ptr") {
        Sleep(30)
        app.Window.ApplyNativeThemes()
    }
    AssertTrue(DllCall("uxtheme\GetWindowTheme", "Ptr",
        app.Window.List.Hwnd, "Ptr"), "ListView 没有应用原生深色主题")
    listHeader := SendMessage(0x101F, 0, 0, , app.Window.List.Hwnd)
    AssertTrue(listHeader && DllCall("uxtheme\GetWindowTheme", "Ptr",
        listHeader, "Ptr"), "ListView 原生表头没有应用主题")
    AssertTrue(DllCall("uxtheme\GetWindowTheme", "Ptr",
        app.Window.PurposeEdit.Hwnd, "Ptr"), "多行 Edit 没有应用原生深色主题")

    app.OpenSettings()
    AssertTrue(IsObject(app.SettingsWindow), "中文设置窗口没有打开")
    darkSettings := app.SettingsWindow
    AssertTestWindowOffscreen(darkSettings.Gui.Hwnd, "深色设置窗口")
    AssertEqual(SettingsWindow.CompactWidth, darkSettings.WindowWidth,
        "中文设置窗口没有采用小助手的 520px 紧凑宽度")
    AssertEqual("键鼠重映射小助手设置", darkSettings.Gui.Title,
        "中文设置窗口没有使用产品级标题")
    AssertEqual(4, darkSettings.TabButtons.Length,
        "设置窗口没有建立四个自定义选项卡")
    AssertEqual("界面语言：", darkSettings.LanguageLabel.Text,
        "中文语言标签格式错误")
    AssertEqual("界面内容字体：", darkSettings.FontLabel.Text,
        "中文字体标签格式错误")
    AssertEqual("主题：", darkSettings.ThemeLabel.Text,
        "中文主题标签格式错误")
    AssertEqual("保存", darkSettings.SaveButton.Text,
        "中文保存按钮仍包含旧版 Emoji 或冗余文案")
    AssertTrue(darkSettings.ShowAtStartupCheck.Value == 1,
        "通用页没有加载启动窗口设置")
    darkSettings.SwitchTab(2)
    AssertTrue(darkSettings.TabBuilt[2]
            && darkSettings.EscapeCancelsCheck.Value == 1,
        "录制设置页没有延迟构建或加载配置")
    darkSettings.SwitchTab(3)
    AssertTrue(darkSettings.TabBuilt[3]
            && darkSettings.EventCapacityInput.Edit.Value == "1000"
            && darkSettings.EventAutoScrollCheck.Value == 1,
        "事件设置页没有延迟构建或加载配置")
    AssertEqual("事件缓冲区容量（条）：",
        darkSettings.EventCapacityLabel.Text,
        "事件容量标签内容不完整")
    AssertControlTextFits(darkSettings.EventCapacityLabel,
        "中文事件容量标签")
    darkSettings.Gui.GetClientPos(, , &settingsClientWidth)
    darkSettings.EventCapacityLabel.GetPos(&eventLabelX, &eventLabelY,
        &eventLabelWidth, &eventLabelHeight)
    darkSettings.EventCapacityInput.Background.GetPos(&eventInputX, ,
        &eventInputWidth)
    darkSettings.EventAutoScrollCheck.GetPos(&eventCheckX, &eventCheckY,
        &eventCheckWidth, &eventCheckHeight)
    AssertTrue(Abs((eventLabelX + eventInputX + eventInputWidth) / 2
            - settingsClientWidth / 2) <= 1
            && eventInputX - eventLabelX - eventLabelWidth == 12
            && Abs(eventCheckX + eventCheckWidth / 2
                - settingsClientWidth / 2) <= 1,
        "中文事件设置控件没有水平居中")
    contentCenterY := (46 + 255) / 2
    eventContentCenterY := (eventLabelY + eventCheckY
        + eventCheckHeight) / 2
    AssertTrue(Abs(eventContentCenterY - contentCenterY) <= 3,
        "中文事件设置内容没有在可用区域垂直居中")
    darkSettings.SwitchTab(4)
    AssertTrue(darkSettings.TabBuilt[4]
            && darkSettings.AboutName.Text == "键鼠重映射小助手"
            && InStr(darkSettings.VersionValue.Text, "v0.1.0")
            && InStr(darkSettings.RuntimeValue.Text, "AutoHotkey 2.0.26")
            && !darkSettings.SaveButton.Visible
            && !darkSettings.CancelButton.Visible,
        "关于页没有按小助手结构构建或仍显示设置操作按钮")
    AssertTrue((ControlGetStyle(darkSettings.AboutName) & 0x80) != 0,
        "关于页产品名没有禁止原生助记前缀，英文 & 会被吞掉")
    darkSettings.SwitchTab(1)
    darkComboHandles := GetComboBoxThemeHandles(
        darkSettings.FontDropDown.Hwnd)
    AssertTrue(darkComboHandles.List
            && DarkComboBoxListThemeRegistry.IsRegistered(darkComboHandles.List),
        "中文设置下拉列表没有完整接入深色主题注册表")
    darkSettings.RequestClose()
    AssertTrue(!IsObject(app.SettingsWindow),
        "中文设置窗口取消后没有释放应用引用")
    AssertTrue(darkSettings.FontDropDownCommandHandler == "",
        "设置窗口关闭后仍保留消息绑定回调引用")
    AssertTrue(!DarkComboBoxListThemeRegistry.IsRegistered(
            darkComboHandles.List),
        "设置窗口关闭后仍残留暗色下拉列表主题注册")

    app.Window.LoadRows([{
        Id: "width-short", Source: "F1", Target: "F2", Scope: "全局",
        Purpose: "短字段"
    }])
    app.Window.OnListContextMenu(app.Window.List, 1, true, 0, 0)
    Sleep(20)
    AssertTrue(app.Window.ContextPopup.IsVisible()
            && app.Window.List.GetNext() == 1
            && IsObject(app.Window.ListSelection)
            && app.Window.ListSelection.RefreshItem(1),
        "真实条目右键没有保留圆角选中行或显示非模态操作窗")
    app.Window.ContextPopup.Hide()
    shortSourceWidth := app.Window.GetColumnLogicalWidth(
        MappingWindow.SourceColumn)
    shortTargetWidth := app.Window.GetColumnLogicalWidth(
        MappingWindow.TargetColumn)
    AssertEqual(app.Window.ListRowImageList,
        SendMessage(0x1002, 1, 0, , app.Window.List.Hwnd),
        "用于增高行距的小图像列表没有附着到 ListView")
    AssertTrue(GetListRowHeight(app.Window.List) >= MappingWindow.ListRowHeight,
        "ListView 原生项目高度没有随行距规格增大")

    app.Window.List.Delete()
    app.Window.LoadRows(CreateViewportTestMappings())
    ShowOffscreenTestMappingWindow(app.Window, 930, 710)
    Sleep(40)
    viewportRowHeight := GetListRowHeight(app.Window.List)
    listClientHeight := GetListClientHeight(app.Window.List)
    AssertTrue(viewportRowHeight > 0 && listClientHeight > 0
            && Mod(listClientHeight, viewportRowHeight) == 0,
        "ListView 客户区高度没有对齐到完整原生行")
    app.Window.List.GetPos(, , , &alignedListHeight)
    AssertTrue(alignedListHeight >= MappingWindow.MinListHeight,
        "整行对齐错误突破了 ListView 最低高度")
    lastViewportRow := app.Window.List.GetCount()
    AssertTrue(SendMessage(0x1013, lastViewportRow - 1, 0, ,
        app.Window.List.Hwnd), "无法滚动到 ListView 最后一行") ; LVM_ENSUREVISIBLE
    Sleep(30)
    AssertEqual(listClientHeight,
        GetListItemBottom(app.Window.List, lastViewportRow),
        "滚动到底后最后一行底边没有贴合 ListView 客户区底边")
    AssertEqual(0, app.Window.RedrawLockDepth,
        "窗口缩放结束后遗留了整窗重绘锁")

    app.Window.List.Delete()
    app.Window.LoadRows([{
        Id: "width-source", Source: "LCtrl + LShift + LAlt + Media_Play_Pause",
        Target: "F2", Scope: "全局", Purpose: "超长来源字段"
    }])
    AssertTrue(app.Window.GetColumnLogicalWidth(MappingWindow.SourceColumn)
            > shortSourceWidth,
        "来源按键列没有按最长来源内容动态增宽")

    app.Window.List.Delete()
    app.Window.LoadRows([{
        Id: "width-target", Source: "F1",
        Target: "LCtrl + LShift + LAlt + Media_Play_Pause",
        Scope: "全局", Purpose: "超长映射结果字段"
    }])
    AssertTrue(app.Window.GetColumnLogicalWidth(MappingWindow.TargetColumn)
            > shortTargetWidth,
        "映射结果列没有按最长结果内容动态增宽")

    app.Window.List.Delete()
    sortTestMappings := CreateSortTestMappings()
    app.Repository.SeedMappings(sortTestMappings)
    app.Window.LoadRows(sortTestMappings)
    app.Window.List.ModifyCol(MappingWindow.SourceColumn, 20)
    AssertTrue(app.Window.CellTooltip.IsCellClipped(1,
        MappingWindow.SourceColumn,
        app.Window.List.GetText(1, MappingWindow.SourceColumn)),
        "被截断的 ListView 单元格没有识别为可悬浮查看")
    app.Window.List.ModifyCol(MappingWindow.PurposeColumn, 20)
    AssertTrue(app.Window.CellTooltip.IsCellClipped(1,
        MappingWindow.PurposeColumn,
        app.Window.List.GetText(1, MappingWindow.PurposeColumn)),
        "设计目的列被截断时没有纳入完整内容悬浮范围")
    app.Window.ConfigureColumns(860)
    customMappingOrder := "custom-first|custom-second|custom-third"
    app.Window.List.Modify(1, "Select Focus")
    app.Window.OnSelectionChanged()
    AssertEqual(app.Window.GetPauseButtonText(),
        app.Window.PauseResumeButton.Text,
        "启用映射被选中时按钮文案错误")
    activePauseState := app.Window.Interactions.Controls[
        app.Window.PauseResumeButton.Hwnd]
    AssertTrue(activePauseState.Normal == MappingWindow.Colors.Pause
        && activePauseState.TextColor == MappingWindow.Colors.ButtonText
        && activePauseState.Interactive,
        "选中映射后暂停按钮没有采用小助手的金棕色可用态")
    activeDeleteState := app.Window.Interactions.Controls[
        app.Window.DeleteButton.Hwnd]
    AssertTrue(activeDeleteState.Normal == MappingWindow.Colors.Delete
        && activeDeleteState.TextColor == MappingWindow.Colors.ButtonText
        && activeDeleteState.Interactive,
        "选中映射后删除按钮没有采用小助手的红色可用态")
    app.ReloadScheduled := false
    app.Window.Interactions.RunClick(app.Window.PauseResumeButton.Hwnd)
    AssertEqual(1, app.Repository.ToggleCount, "暂停按钮没有调用仓储")
    AssertEqual("0", app.Window.List.GetText(1,
        MappingWindow.EnabledColumn), "暂停状态没有写入列表")
    AssertTrue(InStr(app.Window.List.GetText(1,
            MappingWindow.ScopeColumn), "已暂停")
        && app.Window.PauseResumeButton.Text
            == app.Window.GetPauseButtonText(true)
        && !app.Window.Interactions.Controls[
            app.Window.PauseResumeButton.Hwnd].HasOwnProp("ButtonImage"),
        "暂停后的状态提示或恢复按钮错误")
    AssertTrue(!app.ReloadScheduled, "暂停 managed 映射错误请求了脚本重载")
    app.Window.Interactions.RunClick(app.Window.PauseResumeButton.Hwnd)
    AssertEqual(2, app.Repository.ToggleCount, "恢复按钮没有调用仓储")
    AssertEqual("1", app.Window.List.GetText(1,
        MappingWindow.EnabledColumn), "恢复状态没有写入列表")
    AssertTrue(!InStr(app.Window.List.GetText(1,
            MappingWindow.ScopeColumn), "已暂停")
        && app.Window.PauseResumeButton.Text == app.Window.GetPauseButtonText()
        && !app.Window.Interactions.Controls[
            app.Window.PauseResumeButton.Hwnd].HasOwnProp("ButtonImage"),
        "恢复后的状态提示或暂停按钮错误")
    app.ReloadScheduled := false
    AssertTrue(app.Window.ApplyMappingMove("custom-third", 3, 1),
        "拖拽排序没有提交")
    AssertEqual("custom-third|custom-first|custom-second",
        ReadMappingIdOrder(app.Window.List), "拖拽后 ListView 没有即时更新")
    AssertEqual("1|2|3", ReadListColumn(app.Window.List,
        MappingWindow.SequenceColumn),
        "拖拽后可见序号列没有即时重编号")
    AssertEqual("custom-third", app.Window.List.GetText(
        app.Window.List.GetNext(), MappingWindow.MappingIdColumn),
        "拖拽后的条目没有保持选中")
    AssertEqual(1, app.Repository.MoveCount, "拖拽没有写回脚本仓储")
    AssertTrue(app.Repository.LastMoveId == "custom-third"
        && app.Repository.LastMoveIndex == 1, "拖拽落点没有原样传给脚本仓储")
    AssertTrue(!app.ReloadScheduled, "纯排序仍请求重新加载窗口")
    AssertEqual("EMPTY_HISTORY_SENTINEL", app.LastToast,
        "普通拖拽成功错误显示了撤销/重做结果气泡")
    AssertTrue(InStr(app.Window.Status.Text, "实时更新"),
        "拖拽后状态栏没有保留实时更新结果")
    AssertTrue(app.Window.ApplyMappingMove("custom-third", 1, 3),
        "向下拖拽排序没有提交")
    AssertEqual(customMappingOrder, ReadMappingIdOrder(app.Window.List),
        "向下拖拽后 ListView 没有即时恢复目标顺序")
    AssertEqual(2, app.Repository.MoveCount, "连续拖拽没有持续写回脚本仓储")
    AssertTrue(!app.ReloadScheduled, "连续拖拽仍请求重新加载窗口")
    app.ReloadScheduled := false
    app.LastToast := ""
    app.ControlModifierDown := true
    app.ShiftModifierDown := false
    AssertEqual(0, app.OnGlobalKeyDown(0x5A, 0, 0x0100,
        app.Window.List.Hwnd), "Ctrl+Z 没有进入全局撤销路径")
    AssertTrue(!app.ReloadScheduled && app.LastToast != "",
        "managed 顺序撤销没有原位热应用并立即显示结果")
    AssertEqual("已撤销：调整映射顺序：F5 -> F4", app.LastToast,
        "撤销提示没有显示具体动作和映射目标")
    app.ReloadScheduled := false
    app.LastToast := ""
    app.ShiftModifierDown := true
    AssertEqual(0, app.OnGlobalKeyDown(0x5A, 0, 0x0100,
        app.Window.List.Hwnd), "Ctrl+Shift+Z 没有进入全局重做路径")
    AssertTrue(!app.ReloadScheduled && app.LastToast != "",
        "managed 顺序重做没有原位热应用并立即显示结果")
    AssertEqual("已重做：调整映射顺序：F5 -> F4", app.LastToast,
        "重做提示没有显示具体动作和映射目标")
    app.ReloadScheduled := false
    for headerControl in app.Window.ListHeader.Cells {
        headerStyle := DllCall("user32\GetWindowLongPtrW", "Ptr",
            headerControl.Hwnd, "Int", -16, "Ptr")
        AssertTrue(!(headerStyle & 0x00010000),
            "伪表头仍可通过 Tab 获得键盘选择")
        AssertEqual(0, SendMessage(0x0301, 0, 0, headerControl.Hwnd),
            "伪表头没有拒绝 WM_COPY")
        AssertTrue(FocusOffscreenControl(app.Window.PurposeEdit),
            "伪表头焦点测试前输入框没有取得焦点")
        DllCall("user32\SetFocus", "Ptr", headerControl.Hwnd, "Ptr")
        AssertEqual(app.Window.List.Hwnd,
            DllCall("user32\GetFocus", "Ptr"),
            "伪表头没有把真实键盘焦点稳定交给 ListView")
        AssertTrue(!app.Window.Interactions.SetTextNoErase(headerControl,
            headerControl.Text), "未变化的伪表头仍触发了重绘")
    }
    AssertEqual("1|2|3", ReadListColumn(app.Window.List,
        MappingWindow.SequenceColumn), "序号列没有显示自定义顺序")
    app.Window.ListHeader.Cells[1].GetPos(&sequenceHeaderX, ,
        &sequenceHeaderWidth)
    AssertTrue(sequenceHeaderX == 10 && sequenceHeaderWidth == 48,
        "序号伪表头没有采用小助手的首列位置和 48px 宽度")
    AssertSequenceColumnCentered(app.Window.List, "初始显示")
    AssertTrue(app.Window.SortByColumn(MappingWindow.SequenceColumn)
        && app.Window.SortColumn == MappingWindow.SequenceColumn
        && app.Window.SortDescending
        && ReadListColumn(app.Window.List, MappingWindow.SequenceColumn)
            == "3|2|1"
        && InStr(app.Window.ListHeader.Cells[1].Text, "↓")
        && !InStr(app.Window.ListHeader.Cells[1].Text, "↑"),
        "序号表头首次点击没有跳过冗余升序并直接进入降序")
    AssertSequenceColumnCentered(app.Window.List, "序号降序")
    AssertTrue(app.Window.SortByColumn(MappingWindow.SequenceColumn)
        && app.Window.SortColumn == 0
        && !app.Window.SortDescending
        && ReadMappingIdOrder(app.Window.List) == customMappingOrder
        && ReadListColumn(app.Window.List, MappingWindow.SequenceColumn)
            == "1|2|3"
        && !InStr(app.Window.ListHeader.Cells[1].Text, "↑")
        && !InStr(app.Window.ListHeader.Cells[1].Text, "↓"),
        "序号表头第二次点击没有恢复自定义顺序")
    AssertSequenceColumnCentered(app.Window.List, "序号恢复自定义顺序")
    for sortColumn in [MappingWindow.SourceColumn,
            MappingWindow.TargetColumn, MappingWindow.ScopeColumn,
            MappingWindow.PurposeColumn] {
        AssertTrue(app.Window.SortByColumn(sortColumn)
            && app.Window.SortColumn == sortColumn
            && !app.Window.SortDescending
            && InStr(app.Window.ListHeader.Cells[sortColumn].Text, "↑"),
            "伪表头第一次点击没有进入升序")
        AssertTrue(app.Window.SortByColumn(sortColumn)
            && app.Window.SortDescending
            && InStr(app.Window.ListHeader.Cells[sortColumn].Text, "↓"),
            "伪表头第二次点击没有进入降序")
        AssertTrue(app.Window.SortByColumn(sortColumn)
            && app.Window.SortColumn == 0
            && !app.Window.SortDescending
            && ReadMappingIdOrder(app.Window.List) == customMappingOrder
            && !InStr(app.Window.ListHeader.Cells[sortColumn].Text, "↑")
            && !InStr(app.Window.ListHeader.Cells[sortColumn].Text, "↓"),
            "伪表头第三次点击没有恢复自定义顺序")
        AssertTrue(app.Window.SortByColumn(sortColumn)
            && app.Window.SortColumn == sortColumn
            && !app.Window.SortDescending
            && InStr(app.Window.ListHeader.Cells[sortColumn].Text, "↑"),
            "伪表头第四次点击没有重新进入升序")
        AssertTrue(app.Window.SortByColumn(sortColumn)
            && app.Window.SortByColumn(sortColumn)
            && app.Window.SortColumn == 0
            && ReadMappingIdOrder(app.Window.List) == customMappingOrder,
            "伪表头重复循环后没有再次恢复自定义顺序")
    }

    SendHeaderPointerClick(app.Window.ListHeader.Cells[3],
        0x0201) ; WM_LBUTTONDOWN
    AssertTrue(app.Window.SortColumn == MappingWindow.TargetColumn
        && !app.Window.SortDescending,
        "伪表头鼠标单击没有进入升序")
    clipboardAvailable := true
    try clipboardSnapshot := CaptureClipboardWithRetry()
    catch
        clipboardAvailable := false
    if clipboardAvailable {
        try {
            clipboardSentinel := "MAPPING_HEADER_CLIPBOARD_SENTINEL"
            A_Clipboard := clipboardSentinel
            AssertTrue(ClipWait(1), "无法写入剪贴板测试哨兵")
            SendHeaderPointerClick(app.Window.ListHeader.Cells[3],
                0x0203) ; WM_LBUTTONDBLCLK
            AssertEqual(clipboardSentinel, A_Clipboard,
                "伪表头快速点击仍复制了字段文字")
        } finally {
            A_Clipboard := clipboardSnapshot
        }
    } else {
        SendHeaderPointerClick(app.Window.ListHeader.Cells[3],
            0x0203) ; WM_LBUTTONDBLCLK
    }
    AssertTrue(app.Window.SortColumn == MappingWindow.TargetColumn
        && app.Window.SortDescending,
        "伪表头快速第二次单击没有进入降序")
    SendHeaderPointerClick(app.Window.ListHeader.Cells[3], 0x0201)
    AssertTrue(app.Window.SortColumn == 0
        && ReadMappingIdOrder(app.Window.List) == customMappingOrder,
        "伪表头快速第三次单击没有恢复自定义顺序")

    app.Window.PurposeInput.Background.GetPos(, &purposeOuterY, ,
        &purposeOuterHeight)
    app.Window.PurposeEdit.GetPos(, &purposeInnerY, , &purposeInnerHeight)
    app.Window.SourceButton.GetPos(, , , &purposeSourceHeight)
    purposeStyle := ControlGetStyle(app.Window.PurposeEdit)
    AssertTrue(purposeOuterY == purposeInnerY - 1
            && purposeInnerHeight == purposeOuterHeight - 2
            && purposeOuterHeight == purposeSourceHeight
            && (purposeStyle & 0x0004) != 0,
        "设计目的输入框没有与录制区等高并启用两行输入")
    app.Window.PurposeEdit.Value := "第一行`r`n第二行"
    AssertEqual(2, SendMessage(0x00BA, 0, 0, ,
        app.Window.PurposeEdit.Hwnd), "设计目的输入框不能完整容纳两行文字")
    app.Window.PurposeEdit.Value := "ABCDEFGHIJ"
    AssertTrue(FocusOffscreenControl(app.Window.PurposeEdit),
        "输入框没有取得焦点")
    focusedCaretHwnd := 0
    Loop 30 {
        focusedCaretHwnd := GetGuiThreadCaretHwnd(
            app.Window.PurposeEdit.Hwnd)
        if focusedCaretHwnd
            break
        Sleep(10)
    }
    AssertEqual(app.Window.PurposeEdit.Hwnd, focusedCaretHwnd,
        "输入框取得焦点后没有创建原生 caret")
    AssertTrue(PlaceEditCaretAtClientPoint(app.Window.PurposeEdit, 1, 1),
        "无法按输入框客户区坐标放置 caret")
    clickSelection := GetEditSelection(app.Window.PurposeEdit.Hwnd)
    AssertTrue(clickSelection.Start <= 1
            && clickSelection.End == clickSelection.Start,
        "点击输入框左侧背景仍把 caret 强制送到文本末尾")
    AssertTrue(FocusOffscreenControl(app.Window.PurposeEdit),
        "失焦测试前输入框没有取得焦点")
    app.Window.Interactions.OnGlobalPointerDown(1, 0,
        Win32.WM_LBUTTONDOWN, app.Window.SectionTitle.Hwnd)
    Sleep(20)
    AssertEqual(app.Window.List.Hwnd, DllCall("user32\GetFocus", "Ptr"),
        "点击普通文字或窗口空白区域后输入框没有真正失焦")
    AssertTrue(GetGuiThreadCaretHwnd(app.Window.PurposeEdit.Hwnd)
            != app.Window.PurposeEdit.Hwnd,
        "输入框失焦后原生 caret 仍在闪烁")
    AssertTrue(FocusOffscreenControl(app.Window.PurposeEdit),
        "录制按钮测试前输入框没有取得焦点")
    app.Window.Interactions.RunClick(app.Window.SourceButton.Hwnd)
    AssertEqual(app.Window.SourceButton.Hwnd,
        DllCall("user32\GetFocus", "Ptr"), "自绘按钮没有让输入框失焦")
    AssertTrue(app.Capture.Active, "点击来源按钮后没有进入录制")
    AssertCaptureButtonIconState(app.Window, app.Window.SourceButton, false,
        "录制中的来源按钮")
    AssertCaptureButtonIconState(app.Window, app.Window.TargetButton, true,
        "来源录制期间的空闲目标按钮")
    AssertEqual("", app.Window.SourceDetail.Text,
        "尚未按下来源按键时提前显示了详情内容")
    AssertTrue(app.Runtime.Backend.Suspended
            && app.Capture.SuspensionOwned,
        "录制开始后没有独占暂停 managed 输入后端")
    SendGuiRawKey(app.Capture, 0x11, 0x01D, "down")
    AssertTrue(app.Capture.Active && !IsObject(app.Window.SourceCapture),
        "左 Ctrl 实时预览错误完成了录制")
    AssertEqual("LCtrl", app.Window.SourceButton.Text,
        "左 Ctrl 按下后按钮没有立即显示")
    AssertCaptureButtonIconState(app.Window, app.Window.SourceButton, false,
        "实时预览中的来源按钮")
    AssertEqual("按键名称：左侧 Ctrl`n虚拟键码：VK A2`n扫描码：SC 01D",
        app.Window.SourceDetail.Text, "左 Ctrl 按下后详情没有立即显示")
    SendGuiRawKey(app.Capture, 0x10, 0x036, "down")
    AssertTrue(app.Capture.Active && !IsObject(app.Window.SourceCapture),
        "组合修饰键实时预览错误完成了录制")
    AssertEqual("LCtrl + RShift", app.Window.SourceButton.Text,
        "右 Shift 按下后按钮没有实时追加")
    AssertTrue(InStr(app.Window.SourceDetail.Text,
        "虚拟键码：VK A2 + VK A1"), "组合修饰键 VK 没有实时追加")
    SendGuiRawKey(app.Capture, 0x41, 0x01E, "down")
    AssertTrue(app.Capture.Active && !IsObject(app.Window.SourceCapture),
        "字母仍按下时错误提前完成实时录制")
    AssertTrue(app.Runtime.Backend.Suspended
            && app.Capture.SuspensionOwned,
        "按键尚未全部弹起时错误恢复了 managed 输入后端")
    AssertEqual("LCtrl + RShift + A", app.Window.SourceButton.Text,
        "字母按下后没有实时显示完整组合")
    SendGuiRawKey(app.Capture, 0x41, 0x01E, "up")
    AssertTrue(app.Capture.Active && !IsObject(app.Window.SourceCapture),
        "修饰键仍按下时错误完成录制")
    SendGuiRawKey(app.Capture, 0x10, 0x036, "up")
    AssertTrue(app.Capture.Active && !IsObject(app.Window.SourceCapture),
        "最后一枚 Ctrl 弹起前错误完成录制")
    SendGuiRawKey(app.Capture, 0x11, 0x01D, "up")
    AssertTrue(!app.Capture.Active && IsObject(app.Window.SourceCapture),
        "全部按键弹起后没有完成实时录制")
    AssertTrue(!app.Runtime.Backend.Suspended
            && !app.Capture.SuspensionOwned,
        "录制全部完成后没有恢复 managed 输入后端")
    AssertEqual("LCtrl + RShift + A", app.Window.SourceButton.Text,
        "完成录制后按钮没有保留完整组合")
    AssertEqual("LCtrl + RShift + A", app.Window.SourceCapture.RawDisplay,
        "最终捕获结果与实时预览不一致")
    AssertTrue(InStr(app.Window.Status.Text, "已录制")
            && InStr(app.Window.Status.Text, "VK ")
            && InStr(app.Window.Status.Text, "SC "),
        "多键录制完成后状态栏仍停留在录制预览状态")
    completedCaptureStatus := app.Window.Status.Text
    staleCapturePreview := BuildGuiKeyboardCapture(app.Capture,
        0x11, 0x01D)
    app.OnCapturePreview("source", staleCapturePreview)
    AssertEqual(completedCaptureStatus, app.Window.Status.Text,
        "录制完成后迟到的预览回调覆盖了完成态状态栏")
    AssertCaptureButtonIconState(app.Window, app.Window.SourceButton, false,
        "已录制的来源按钮")
    AssertCaptureButtonIconState(app.Window, app.Window.TargetButton, true,
        "来源录制完成后的初始目标按钮")

    leftShiftCapture := BuildGuiKeyboardCapture(app.Capture,
        0x10, 0x02A)
    app.Window.AcceptCapture("source", leftShiftCapture)
    AssertEqual("LShift", app.Window.SourceButton.Text,
        "来源按钮把规范名称显示成了中文阅读名称")
    AssertEqual("按键名称：左侧 Shift`n虚拟键码：VK A0`n扫描码：SC 02A",
        app.Window.SourceDetail.Text, "左 Shift 没有逐行显示阅读信息")

    app.Window.Interactions.RunClick(app.Window.TargetButton.Hwnd)
    AssertTrue(app.Capture.Active, "点击目标按钮后没有进入录制")
    AssertCaptureButtonIconState(app.Window, app.Window.SourceButton, false,
        "目标录制期间已完成的来源按钮")
    AssertCaptureButtonIconState(app.Window, app.Window.TargetButton, false,
        "录制中的目标按钮")
    f23VK := GetKeyVK("F23")
    f23SC := GetKeySC("F23")
    SendGuiRawKey(app.Capture, f23VK, f23SC, "down")
    AssertTrue(app.Capture.Active && !IsObject(app.Window.TargetCapture),
        "F23 仍按下时错误提前完成录制")
    SendGuiRawKey(app.Capture, f23VK, f23SC, "up")
    AssertEqual("F23", app.Window.TargetCapture.Display, "目标按键没有显示")
    AssertEqual("F23", app.Window.TargetButton.Text,
        "目标按钮没有显示规范按键名称")
    AssertEqual(app.Window.TargetCapture.DetailLines, app.Window.TargetDetail.Text,
        "目标录制详情没有保持显示")
    AssertCaptureButtonIconState(app.Window, app.Window.TargetButton, false,
        "已录制的目标按钮")
    AssertTrue(InStr(app.Window.Status.Text, "VK ")
        && InStr(app.Window.Status.Text, "SC "),
        "录制状态没有显示完整编码信息")

    app.Window.PurposeEdit.Value := "GUI 交互冒烟"
    app.ReloadScheduled := false
    app.Window.Interactions.RunClick(app.Window.SaveButton.Hwnd)
    AssertEqual(1, app.Repository.AppendCount, "保存按钮没有调用仓储")
    AssertTrue(!app.ReloadScheduled, "managed 映射保存后错误请求了重新加载")
    AssertEqual("GUI 交互冒烟", app.Repository.LastPurpose, "设计目的没有传给仓储")
    AssertTrue(!IsObject(app.Window.SourceCapture), "保存后没有清空来源录制")
    AssertCaptureButtonIconState(app.Window, app.Window.SourceButton, true,
        "保存后清空的来源按钮")
    AssertCaptureButtonIconState(app.Window, app.Window.TargetButton, true,
        "保存后清空的目标按钮")
    app.Window.Interactions.RunClick(app.Window.SourceButton.Hwnd)
    AssertCaptureButtonIconState(app.Window, app.Window.SourceButton, false,
        "取消前录制中的来源按钮")
    app.Capture.Cancel()
    AssertCaptureButtonIconState(app.Window, app.Window.SourceButton, true,
        "取消录制后的来源按钮")
    AssertCaptureButtonIconState(app.Window, app.Window.TargetButton, true,
        "取消录制后的目标按钮")
    app.Window.Interactions.RunClick(app.Window.SourceButton.Hwnd)
    AssertTrue(app.Capture.Active, "按钮退出录制测试无法重新开始录制")
    app.Window.Interactions.RunClick(app.Window.SourceButton.Hwnd)
    AssertTrue(!app.Capture.Active,
        "录制期间再次点击按钮没有退出录制")
    AssertCaptureButtonIconState(app.Window, app.Window.SourceButton, true,
        "按钮退出录制后的来源按钮")
    AssertTrue(app.Window.Interactions.SuppressNextButtonActivation(
            app.Window.SourceButton.Hwnd),
        "录制取消无法标记同一次按钮激活")
    AssertTrue(!app.Window.Interactions.QueueClick(
            app.Window.SourceButton.Hwnd)
            && !app.Capture.Active,
        "录制取消的鼠标抬起又重新启动了录制")
    AssertTrue(app.Window.Interactions.QueueClick(
            app.Window.SourceButton.Hwnd),
        "被吞掉的按钮激活影响了后续独立点击")
    Sleep(20)
    AssertTrue(app.Capture.Active,
        "录制按钮在取消点击后无法重新开始录制")
    app.Capture.Cancel()
    AssertTrue(app.Window.Interactions.SuppressNextButtonActivation(
            app.Window.SourceButton.Hwnd)
            && app.Window.Interactions.ScheduleSuppressedButtonActivationReset(1),
        "无法安排未送达鼠标抬起后的按钮抑制清理")
    Sleep(10)
    AssertTrue(app.Window.Interactions.QueueClick(
            app.Window.SourceButton.Hwnd),
        "未送达鼠标抬起留下的标记吞掉了下一次点击")
    Sleep(20)
    AssertTrue(app.Capture.Active,
        "按钮抑制自动清理后无法重新录制")
    app.Capture.Cancel()
    AssertTrue(app.Window.IsPointerOverButton(
            app.Window.SourceButton.Hwnd)
        && app.Window.IsPointerOverButton(
            app.Window.SaveButton.Hwnd)
        && app.Window.IsPointerOverButton(
            app.Window.DeleteButton.Hwnd)
        && !app.Window.IsPointerOverButton(
            app.Window.SectionTitle.Hwnd),
        "录制取消的按钮命中范围错误，非按钮区域也被排除")
    app.Window.Interactions.RunClick(app.Window.SourceButton.Hwnd)
    SendGuiRawKey(app.Capture, 0x41, 0x01E, "down")
    SendGuiRawKey(app.Capture, 0x42, 0x030, "down")
    SendGuiRawKey(app.Capture, 0x41, 0x01E, "up")
    SendGuiRawKey(app.Capture, 0x43, 0x02E, "down")
    AssertEqual("A + B + C", app.Window.SourceButton.Text,
        "GUI 连续多键录制仍忽略与峰值数量相同的后按键")
    AssertCaptureButtonIconState(app.Window, app.Window.SourceButton, false,
        "连续多键实时预览中的来源按钮")
    SendGuiRawKey(app.Capture, 0x43, 0x02E, "up")
    SendGuiRawKey(app.Capture, 0x42, 0x030, "up")
    AssertTrue(!app.Capture.Active
            && app.Window.SourceCapture.RawDisplay == "A + B + C",
        "GUI 连续多键手势没有在所有实体键释放后完整完成")
    app.Window.ClearEditor(false)

    app.Window.Interactions.RunClick(app.Window.SourceButton.Hwnd)
    f24VK := GetKeyVK("F24")
    f24SC := GetKeySC("F24")
    SendGuiRawKey(app.Capture, f24VK, f24SC, "down")
    SendGuiDeviceRemoval(app.Capture)
    AssertTrue(!app.Capture.Active,
        "GUI 录制没有从捕获设备移除事件中恢复")
    AssertTrue(!app.Capture.Active
            && app.Window.SourceCapture.RawDisplay == "F24",
        "捕获设备移除后 GUI 仍停在蓝色录制状态")
    app.Window.ClearEditor(false)
    AssertTrue(app.PerformUndo(), "managed 映射新增无法撤销")
    AssertTrue(!app.ReloadScheduled,
        "managed 映射撤销错误请求了脚本重载")
    AssertTrue(app.PerformRedo(), "managed 映射新增无法重做")
    AssertTrue(!app.ReloadScheduled,
        "managed 映射重做错误请求了脚本重载")

    app.Window.Interactions.RunClick(app.Window.TargetButton.Hwnd)
    AssertEqual(1, app.OnAppCommand(0, 14 << 16, 0,
        app.Window.Gui.Hwnd), "WM_APPCOMMAND 没有被捕获会话接管")
    AssertEqual("Media_Play_Pause", app.Window.TargetCapture.KeyName,
        "多媒体消息没有进入统一捕获模型")
    AssertEqual(14, app.Window.TargetCapture.AppCommand,
        "多媒体命令编号没有保留")
    AssertTrue(InStr(app.Window.TargetDetail.Text, "按键名称：Media_Play_Pause")
        && InStr(app.Window.TargetDetail.Text, "`n虚拟键码：")
        && InStr(app.Window.TargetDetail.Text, "`n扫描码："),
        "多媒体键没有逐行显示按键与编码信息")
    AssertTrue(InStr(app.Window.Status.Text, "CMD 14"),
        "多媒体命令编号没有显示在状态区")
    app.Window.ClearEditor(false)
    AssertCaptureButtonIconState(app.Window, app.Window.SourceButton, true,
        "手动清空后的来源按钮")
    AssertCaptureButtonIconState(app.Window, app.Window.TargetButton, true,
        "手动清空后的目标按钮")

    originalHistory := app.History
    failingHistoryStub := RejectingHistory()
    app.History := failingHistoryStub
    mappingStateBeforeFailure := app.Repository.ReadRegionBody()
    mutationFailed := false
    try app.RunMappingMutation("失败事务",
        ObjBindMethod(app.Repository, "Append", leftShiftCapture,
            BuildGuiKeyboardCapture(app.Capture,
                GetKeyVK("F22"), GetKeySC("F22")),
            "失败事务"))
    catch
        mutationFailed := true
    AssertTrue(mutationFailed
            && app.Repository.ReadRegionBody() == mappingStateBeforeFailure,
        "历史提交失败后映射修改没有补偿回滚")
    settingsBeforeFailure := app.SettingsService.GetSnapshot()
    candidateTheme := app.Settings.Theme == "light" ? "dark" : "light"
    AssertTrue(!app.SaveSettings({UiLanguage: app.Settings.UiLanguage,
        UiFont: app.Settings.UiFont, Theme: candidateTheme}),
        "历史提交失败时设置保存错误报告成功")
    AssertEqual(settingsBeforeFailure, app.SettingsService.GetSnapshot(),
        "历史提交失败后设置文件没有补偿回滚")
    app.History := originalHistory

    app.Runtime.Backend.Suspend()
    try {
        AssertTrue(app.Capture.Start("source"), "预先挂起时无法启动录制")
        AssertTrue(app.Runtime.Backend.Suspended
                && !app.Capture.SuspensionOwned,
            "录制错误接管了调用方原有的后端挂起状态")
        app.Capture.Stop(false)
        AssertTrue(app.Runtime.Backend.Suspended,
            "停止录制错误恢复了调用方的后端挂起状态")
    } finally {
        app.Capture.Stop(false)
        app.Runtime.Backend.Resume()
    }

    fillerComments := ""
    Loop 48
        fillerComments .= "; 第 " A_Index " 条滚动同步测试注释`r`n"
    fontMapping := {
        Id: "font-test", Source: "F20", Target: "F21", StartLine: 149,
        Block: "; @mapping-begin`r`n; @schema=2`r`n"
            . "; @mode=managed`r`n; @id=font-test`r`n"
            . "; @spec-begin`r`n; {`r`n"
            . ";   `"description`": `"逐行验证中文字体`",`r`n"
            . ";   `"value`": `"a;b`"`r`n; }`r`n"
            . "; @spec-end`r`n"
            . "; @generated-sha256=" Format("{:064}", 0) "`r`n"
            . "; @generated-begin`r`n; 普通说明注释`r`n"
            . fillerComments . "; @generated-end`r`n; @mapping-end"
    }
    fontEditor := MappingBlockEditor(app.Window, fontMapping)
    try {
        fontEditor.Show()
        AssertTestWindowOffscreen(fontEditor.Gui.Hwnd, "字体与高亮编辑器")
        AssertTrue(!fontEditor.Interactions.Controls[
                fontEditor.SaveButton.Hwnd].HasOwnProp("ButtonImage")
            && !fontEditor.Interactions.Controls[
                fontEditor.CancelButton.Hwnd].HasOwnProp("ButtonImage"),
            "映射编辑器保存/取消按钮不应附加图标")
        SetTimer(fontEditor.FormatTimer, 0)
        fontEditor.ApplyEditorFonts(true)
        editorText := fontEditor.Canonicalize(fontEditor.GetCodeText())
        latinFormat := ReadCharacterFormat(fontEditor.CodeEdit.Hwnd,
            InStr(editorText, "@schema") - 1)
        cjkFormat := ReadCharacterFormat(fontEditor.CodeEdit.Hwnd,
            InStr(editorText, "逐行验证") - 1)
        commentFormat := ReadCharacterFormat(fontEditor.CodeEdit.Hwnd,
            InStr(editorText, "普通说明注释") - 1)
        quotedSemicolonFormat := ReadCharacterFormat(fontEditor.CodeEdit.Hwnd,
            InStr(editorText, "a;b"))
        AssertEqual(fontEditor.CodeFontName, latinFormat.Face,
            "英文代码没有使用首个可用的首选等宽字体")
        AssertEqual("SimSun", cjkFormat.Face, "中文没有使用宋体")
        AssertEqual(260, latinFormat.Height, "英文代码字号错误")
        AssertEqual(260, cjkFormat.Height, "中文代码字号错误")
        AssertTrue(!latinFormat.Bold, "英文代码错误继承了粗体")
        AssertTrue(!cjkFormat.Bold, "中文代码错误继承了粗体")
        AssertEqual(ColorRef(MappingWindow.Colors.CodeVariable),
            latinFormat.Color, "已有映射编辑器没有高亮元数据变量名")
        AssertEqual(ColorRef(MappingWindow.Colors.CodeComment),
            cjkFormat.Color, "注释化 RuleSpec JSON 没有使用注释高亮")
        AssertEqual(ColorRef(MappingWindow.Colors.CodeComment),
            commentFormat.Color, "普通 AHK 注释没有使用灰色高亮")
        AssertEqual(ColorRef(MappingWindow.Colors.CodeComment),
            quotedSemicolonFormat.Color,
            "注释化 RuleSpec JSON 字符串没有保持注释高亮")
        existingLineNumbers := fontEditor.Canonicalize(
            ControlGetText(fontEditor.LineNumberEdit))
        AssertTrue(RegExMatch(existingLineNumbers, "^149`n150")
                && InStr(existingLineNumbers,
                    String(149 + fontEditor.LineNumberCount - 1)),
            "已有映射编辑器没有显示真实源码起始行或完整行号")
        SendMessage(0x00B6, 0, 24, , fontEditor.CodeEdit.Hwnd)
        fontEditor.SyncLineNumberScroll()
        AssertEqual(SendMessage(0x00CE, 0, 0, , fontEditor.CodeEdit.Hwnd),
            SendMessage(0x00CE, 0, 0, , fontEditor.LineNumberEdit.Hwnd),
            "代码区滚动后行号栏没有同步首个可见行")
        previousLineCount := fontEditor.LineNumberCount
        AssertTrue(fontEditor.SetCodeText(fontEditor.GetCodeText()
            . "`r`n; 新增的实时高亮注释"),
            "编辑器无法在单次重绘事务内更新代码")
        AssertEqual(previousLineCount + 1, fontEditor.LineNumberCount,
            "编辑器换行后没有实时刷新行号")
        liveCommentText := fontEditor.Canonicalize(fontEditor.GetCodeText())
        liveCommentFormat := ReadCharacterFormat(fontEditor.CodeEdit.Hwnd,
            InStr(liveCommentText, "新增的实时高亮注释") - 1)
        AssertEqual(ColorRef(MappingWindow.Colors.CodeComment),
            liveCommentFormat.Color, "输入后的注释没有实时语法高亮")
        AssertTrue(fontEditor.ApplyNativeThemes(),
            "代码区和行号栏没有共同应用当前原生主题")
    } finally {
        fontEditor.Dispose(false)
    }
    previewSpec := RuleSpec.Normalize(Map("schema", 2,
        "id", "preview-rule", "enabled", JsonBoolean(true),
        "description", "preview",
        "display", Map("source", "F20", "target", "F21",
            "scope", "全局", "purpose", "preview"),
        "from", Map("hotkey", "F20", "event", "down",
            "key", Map("name", "F20")), "conditions", [],
        "to", [Map("type", "send", "value", "F21")]))
    previewMapping := {Mode: "managed", Enabled: true,
        Spec: previewSpec, Descriptor: RuleCompiler.Compile(previewSpec)}
    previewPackagePath := app.TestRoot "\preview-package.json"
    app.PackageService.ExportTo(previewPackagePath, [previewMapping])
    AssertTrue(app.ImportRulePackageFrom(previewPackagePath),
        "规则包导入没有打开安全预览")
    importPreview := app.PackageImportPreview
    AssertTestWindowOffscreen(importPreview.Gui.Hwnd, "规则包导入预览")
    AssertTrue(IsObject(importPreview)
            && importPreview.List.GetCount() == 1
            && importPreview.GetSelectedIds().Length == 1
            && InStr(importPreview.SummaryText.Text, "generated_input")
            && !DllCall("user32\IsWindowEnabled", "Ptr",
                app.Window.Gui.Hwnd, "Int"),
        "规则包预览缺少逐规则选择、权限摘要或窗口层级")
    AssertTrue(!importPreview.Interactions.Controls[
            importPreview.ImportButton.Hwnd].HasOwnProp("ButtonImage")
        && !importPreview.Interactions.Controls[
            importPreview.CancelButton.Hwnd].HasOwnProp("ButtonImage")
        && RegExMatch(importPreview.Interactions.Controls[
            importPreview.SelectAllButton.Hwnd].ButtonImage.SourcePath,
            "i)\\circle-check-big\.svg$")
        && RegExMatch(importPreview.Interactions.Controls[
            importPreview.ClearButton.Hwnd].ButtonImage.SourcePath,
            "i)\\x\.svg$"),
        "规则包表单动作和选择工具的图标边界不正确")
    importPreview.ClearSelection()
    AssertTrue(importPreview.GetSelectedIds().Length == 0,
        "规则包预览无法取消全部规则选择")
    importPreview.SelectAll()
    AssertTrue(importPreview.GetSelectedIds().Length == 1,
        "规则包预览无法恢复全部规则选择")
    importPreview.RequestClose()
    AssertTrue(!IsObject(app.PackageImportPreview)
            && DllCall("user32\IsWindowEnabled", "Ptr",
                app.Window.Gui.Hwnd, "Int"),
        "关闭规则包预览后没有释放应用引用或恢复主窗口")
    AssertTrue(app.OpenEventViewer(), "事件查看器无法打开："
        app.Window.Status.Text)
    viewer := app.EventViewer
    AssertTestWindowOffscreen(viewer.Gui.Hwnd, "事件查看器")
    AssertTrue(IsObject(viewer)
        && DllCall("user32\IsWindowVisible", "Ptr", viewer.Gui.Hwnd, "Int"),
        "事件查看器打开后不可见")
    AssertTrue(DllCall("user32\IsWindowEnabled", "Ptr",
        app.Window.Gui.Hwnd, "Int"), "事件查看器错误禁用了主窗口")
    AssertTrue(IsObject(viewer.ListSelection)
            && viewer.ListSelection.Attached,
        "事件查看器没有初始化圆角列表选中态")
    AssertEqual(ColorRef(UiThemeService.GetPalette().Surface),
        SendMessage(0x1000, 0, 0, , viewer.List.Hwnd),
        "事件查看器首帧没有采用当前主题的列表背景色")
    listStyle := DllCall("user32\GetWindowLongPtr", "Ptr", viewer.List.Hwnd,
        "Int", -16, "Ptr")
    listExStyle := DllCall("user32\GetWindowLongPtr", "Ptr", viewer.List.Hwnd,
        "Int", -20, "Ptr")
    AssertTrue(!(listStyle & 0x00800000) && !(listExStyle & 0x00000200),
        "事件查看器 ListView 仍保留白色原生边框")
    AssertEqual(6, viewer.List.GetCount("Column"),
        "事件查看器没有彻底移除可见序号列")
    AssertEqual(EventViewerWindow.EventColumnWidth,
        Round(SendMessage(0x101D, EventViewerWindow.EventColumn - 1, 0, ,
            viewer.List.Hwnd) * 96 / DllCall("user32\GetDpiForWindow", "Ptr",
                viewer.List.Hwnd, "UInt")),
        "事件查看器没有把序号列空间交给事件列")
    visibleEventCount := viewer.List.GetCount()
    guiUnifiedEvent := InputEvent.Create(KeyIdentity.Create("keyboard",
        "LShift", 0xA0, 0x02A), "down", false, false, "gui-test")
    app.TraceEvent("input", "gui_test_key", {Source: "LShift",
        Outcome: "observed", Detail: "VK A0 / SC 02A",
        Data: guiUnifiedEvent})
    AssertEqual(visibleEventCount + 1, viewer.List.GetCount(),
        "事件查看器没有实时追加事件")
    viewer.OnListItemSelected(viewer.List, viewer.List.GetCount(), true)
    AssertTrue(InStr(viewer.DetailEdit.Value, "LShift")
            && InStr(viewer.DetailEdit.Value, "0xA0")
            && InStr(viewer.DetailEdit.Value, "QPC:"),
        "事件查看器选中项没有显示统一输入事件详情")
    app.VariableStore.Set("gui_test", 7, "transient")
    AssertTrue(viewer.ShowVariables()
            && viewer.DetailMode == "variables"
            && viewer.DetailLabel.Text == Tr("变量快照")
            && InStr(viewer.DetailEdit.Value, '"gui_test": 7')
            && InStr(viewer.DetailEdit.Value, "persistent:")
            && InStr(viewer.DetailEdit.Value, "builtin:"),
        "事件查看器没有显示完整变量作用域快照")
    viewer.OnListItemSelected(viewer.List, viewer.List.GetCount(), true)
    AssertTrue(viewer.DetailMode == "event"
            && viewer.DetailLabel.Text == Tr("事件详情"),
        "选择事件后没有从变量快照切回事件详情")
    AssertTrue(viewer.ToggleRawObservation()
            && viewer.RawObservationActive
            && app.RawObservationStarts == 1,
        "事件查看器无法进入原始观察模式")
    AssertTrue(viewer.ToggleRawObservation()
            && !viewer.RawObservationActive
            && app.RawObservationStops == 1,
        "事件查看器无法退出原始观察模式")
    viewer.TogglePaused()
    pausedEventCount := viewer.List.GetCount()
    app.TraceEvent("input", "gui_test_paused", {Source: "A"})
    AssertEqual(pausedEventCount, viewer.List.GetCount(),
        "暂停刷新后列表仍实时变化")
    viewer.TogglePaused()
    AssertTrue(viewer.List.GetCount() > pausedEventCount,
        "恢复刷新后没有补齐暂停期间事件")
    viewer.FilterDropDown.Value := 2
    viewer.OnFilterChanged()
    AssertTrue(viewer.List.GetCount() >= 2,
        "输入事件筛选没有显示匹配记录")
    Loop viewer.List.GetCount()
        AssertEqual(Tr("输入"), viewer.List.GetText(A_Index,
            EventViewerWindow.CategoryColumn),
            "类别筛选混入其它事件")
    app.Trace.Record("system", "filtered_status_test")
    AssertEqual(Tr(
            "显示 {1} 条 · 缓冲区 {2}/{3} · 已丢弃 {4} 条 · {5}",
            viewer.List.GetCount(), app.Trace.Count, app.Trace.Capacity,
            app.Trace.DroppedCount, Tr("实时刷新")), viewer.Status.Text,
        "筛选外事件到达后事件查看器状态栏没有实时更新")
    eventExportPath := app.TestRoot "\gui-events.jsonl"
    AssertTrue(viewer.ExportTo(eventExportPath)
            && FileExist(eventExportPath), "事件查看器无法导出筛选结果")
    firstExportedEvent := JsonCodec.Parse(StrSplit(Trim(
        FileRead(eventExportPath, "UTF-8"), "`r`n"), "`n", "`r")[1])
    AssertEqual("input", firstExportedEvent["category"],
        "事件查看器导出没有遵循当前筛选")
    viewer.ApplyAppearance()
    AssertEqual(Tr("事件查看器"), viewer.Gui.Title,
        "事件查看器主题刷新破坏了标题")
    AssertEqual(EventViewerWindow.DetailColumn,
        viewer.CellTooltip.MaximumColumn,
        "事件查看器详情列没有纳入通用截断悬浮提示")
    AssertTrue(viewer.ListHeader.SortByDisplayColumn(
            EventViewerWindow.EventColumn),
        "事件查看器事件列无法进入临时升序展示")
    capacityBurstStarted := A_TickCount
    Loop app.Trace.Capacity + 5
        app.Trace.Record("input", "capacity_test", {Source: "Key" A_Index})
    capacityBurstElapsed := A_TickCount - capacityBurstStarted
    AssertTrue(capacityBurstElapsed < 30000,
        "事件查看器临时排序下的容量事件突发耗时过长："
            capacityBurstElapsed " ms")
    viewer.ApplyPendingSort()
    AssertEqual(app.Trace.Capacity, viewer.List.GetCount(),
        "事件查看器实时列表超过了有界事件缓冲区容量")
    AssertEqual(viewer.List.GetCount(), viewer.SequenceItemIds.Count,
        "事件查看器内部序列索引与可见行数不一致")
    for traceSnapshotEntry in app.Trace.Snapshot("input")
        AssertTrue(viewer.HasSequence(traceSnapshotEntry.Sequence),
            "事件查看器淘汰旧行后与事件缓冲区快照不一致")
    originalViewerTrace := viewer.Trace
    churningTrace := ChurningViewerTrace(viewer,
        originalViewerTrace.Snapshot("input"),
        EventViewerWindow.MaximumSnapshotRebuildPasses + 2)
    viewer.Trace := churningTrace
    viewer.LoadSnapshot()
    viewer.Trace := originalViewerTrace
    AssertEqual(EventViewerWindow.MaximumSnapshotRebuildPasses,
        churningTrace.SnapshotCalls,
        "事件持续到达时事件查看器没有限制单次快照重建轮数")
    AssertTrue(viewer.SnapshotRefreshPending,
        "有界快照重建退出后没有安排最终一致性刷新")
    viewer.CancelPendingSnapshotRefresh()
    viewer.Clear()
    AssertTrue(viewer.List.GetCount() == 0 && app.Trace.Count == 0,
        "清空事件后查看器自身又立即添加了一条记录")
    viewerTooltip := viewer.CellTooltip
    viewer.RequestClose()
    AssertTrue(!IsObject(app.EventViewer)
            && app.Trace.Subscribers.Count == 0,
        "事件查看器关闭后没有解除订阅或应用仍持有旧引用")
    AssertTrue(viewer.SortRefreshTimer == ""
            && viewer.SnapshotRefreshTimer == ""
            && viewerTooltip.ShowTimer == ""
            && viewerTooltip.MouseMoveCallback == ""
            && viewerTooltip.MouseLeaveCallback == ""
            && viewerTooltip.MouseWheelCallback == "",
        "事件查看器关闭后仍保留定时器或消息绑定回调引用")
    AssertTrue(app.OpenEventViewer(), "事件查看器第二次打开失败")
    reopenedViewer := app.EventViewer
    AssertTestWindowOffscreen(reopenedViewer.Gui.Hwnd, "重新打开的事件查看器")
    AssertTrue(IsObject(reopenedViewer)
            && DllCall("user32\IsWindowVisible", "Ptr",
                reopenedViewer.Gui.Hwnd, "Int")
            && IsObject(reopenedViewer.ListSelection)
            && reopenedViewer.ListSelection.Attached,
        "事件查看器第二次打开后窗口或圆角列表呈现未恢复")
    AssertEqual(ColorRef(UiThemeService.GetPalette().Surface),
        SendMessage(0x1000, 0, 0, , reopenedViewer.List.Hwnd),
        "事件查看器第二次打开时列表背景回退到错误主题")
    reopenedViewer.RequestClose()
    AssertTrue(!IsObject(app.EventViewer)
            && app.Trace.Subscribers.Count == 0,
        "第二个事件查看器关闭后遗留订阅或应用引用")

    safeModeApp := SafeModeGuiTestApp()
    try {
        AssertTrue(safeModeApp.SafeMode,
            "安全模式 GUI 测试没有进入安全模式")
        safeModeApp.Start()
        AssertTrue(safeModeApp.ApplicationCallbacksRegistered
                && safeModeApp.ExitCallbackRegistered
                && safeModeApp.MessageRegistrations.Length == 7,
            "应用消息与退出回调没有作为完整事务登记")
        AssertTrue(safeModeApp.Runtime.ApplyCount == 0
                && safeModeApp.RawInput.StartCount == 0,
            "安全模式启动仍激活了映射或输入观察")
        safeModeApp.ApplyManagedRulesHot()
        AssertEqual(0, safeModeApp.Runtime.ApplyCount,
            "安全模式下热应用重新激活了映射")
        expectedSafeModeStatus := Tr(
            "安全模式：已停用所有映射和输入观察。连续启动失败 {1} 次。",
            safeModeApp.StartupState.ConsecutiveFailures)
        AssertEqual(expectedSafeModeStatus, safeModeApp.Window.Status.Text,
            "安全模式主窗口没有显示完整本地化状态")
        recoveryMenuPresent := true
        try A_TrayMenu.Disable(Tr("恢复最后正常配置"))
        catch
            recoveryMenuPresent := false
        AssertTrue(recoveryMenuPresent,
            "有恢复快照时托盘没有提供恢复入口")
        if recoveryMenuPresent
            A_TrayMenu.Enable(Tr("恢复最后正常配置"))
    } finally {
        safeModeApp.Shutdown()
    }
    AssertTrue(!safeModeApp.ApplicationCallbacksRegistered
            && !safeModeApp.ExitCallbackRegistered
            && !safeModeApp.MessageRegistrations.Length,
        "应用关闭后仍保留消息或退出回调注册状态")

    WriteTestSuccess("gui-interaction-smoke")
} catch as guiTestError {
    guiTestFailure := guiTestError.Message "`n" guiTestError.Stack
} finally {
    app.Shutdown()
}
if guiTestFailure != "" {
    FileAppend(guiTestFailure "`n", "**")
    ExitApp(1)
}
ExitApp(0)

ReadCharacterFormat(hwnd, position) {
    selection := Buffer(8, 0)
    NumPut("Int", position, selection, 0)
    NumPut("Int", position + 1, selection, 4)
    SendMessage(0x0437, 0, selection.Ptr, , hwnd)
    characterFormat := Buffer(116, 0)
    NumPut("UInt", 116, characterFormat, 0)
    SendMessage(0x043A, 1, characterFormat.Ptr, , hwnd)
    return {
        Height: NumGet(characterFormat, 12, "Int"),
        CharacterSet: NumGet(characterFormat, 24, "UChar"),
        Face: StrGet(characterFormat.Ptr + 26, 32, "UTF-16"),
        Color: NumGet(characterFormat, 20, "UInt"),
        Weight: NumGet(characterFormat, 90, "UShort"),
        Bold: (NumGet(characterFormat, 8, "UInt") & 0x1) != 0
    }
}

class TestKeyMouseRemapperAssistantApp extends KeyMouseRemapperAssistantApp {
    __New() {
        this.TestRoot := A_Temp "\key-mouse-remapper-assistant-gui-" A_TickCount "-"
            . Format("{:08X}", Random(0, 0xFFFFFFFF))
        DirCreate(this.TestRoot)
        settingsPath := this.TestRoot "\settings.ini"
        FileAppend("[Appearance]`r`nUiLanguage=zh-CN`r`n",
            settingsPath, "UTF-8-RAW")
        super.__New(settingsPath,
            this.TestRoot "\history.dat", this.TestRoot "\notification.txt")
        this.Capture.Stop(false)
        this.Capture := DeterministicGuiKeyCaptureSession(this)
        this.Repository := FakeMappingRepository()
        this.ReloadScheduled := false
        this.LastToast := ""
        this.ControlModifierDown := false
        this.ShiftModifierDown := false
        this.RawObservationStarts := 0
        this.RawObservationStops := 0
        this.ManagedApplyCount := 0
    }

    IsGlobalModifierDown(keyName) {
        return keyName == "Ctrl" ? this.ControlModifierDown
            : (keyName == "Shift" ? this.ShiftModifierDown : false)
    }

    ScheduleReload(*) {
        this.ReloadScheduled := true
    }

    ApplyManagedRulesHot() {
        this.ManagedApplyCount++
        this.RuntimeReport := {Applied: this.Repository.Load().Length,
            Registrations: 0, Issues: []}
        return this.RuntimeReport
    }

    ShowToast(text) {
        this.LastToast := String(text)
        return true
    }

    BeginRawObservation() {
        this.RawObservationStarts++
        return true
    }

    EndRawObservation(*) {
        this.RawObservationStops++
        return true
    }

    Shutdown(*) {
        super.Shutdown()
        if DirExist(this.TestRoot)
            try DirDelete(this.TestRoot, true)
    }
}

class SessionNotificationRetryProbe extends KeyMouseRemapperAssistantApp {
    __New() {
        this.SessionNotificationsRegistered := true
        this.UnregisterCallCount := 0
        this.Window := {Gui: {Hwnd: 1}}
    }

    UnregisterSessionNotificationNative(*) {
        this.UnregisterCallCount++
        return this.UnregisterCallCount >= 2
    }

    TraceEvent(*) {
    }
}

class SafeModeGuiTestApp extends KeyMouseRemapperAssistantApp {
    __New() {
        this.TestRoot := A_Temp "\key-mouse-remapper-assistant-safe-gui-" A_TickCount
            . "-" Format("{:08X}", Random(0, 0xFFFFFFFF))
        DirCreate(this.TestRoot)
        settingsPath := this.TestRoot "\settings.ini"
        historyPath := this.TestRoot "\history.dat"
        notificationPath := this.TestRoot "\notification.txt"
        variablePath := this.TestRoot "\variables.json"
        controlPath := this.TestRoot "\control.json"
        healthPath := this.TestRoot "\startup-health.json"
        recoveryPath := this.TestRoot "\last-known-good.json"
        outputPath := this.TestRoot "\output-recovery.json"
        crashPath := this.TestRoot "\crash-diagnostics.json"

        healthySession := StartupHealthService(healthPath, recoveryPath)
        healthySession.Begin(A_ScriptFullPath)
        healthySession.MarkRunning()
        healthySession.MarkStable("known-good-mapping")
        healthySession.MarkClean()
        Loop 3 {
            failedSession := StartupHealthService(healthPath, recoveryPath)
            failedSession.Begin(A_ScriptFullPath)
            failedSession.RecordStartupFailure("injected startup failure "
                A_Index)
        }

        super.__New(settingsPath, historyPath, notificationPath,
            variablePath, controlPath, healthPath,
            recoveryPath, outputPath, crashPath)
        this.Settings.ShowMainWindowAtStartup := false
        this.Capture.Stop(false)
        this.Repository := FakeMappingRepository()
        this.Runtime := SafeModeRuntimeProbe()
        this.RawInput := SafeModeInputProbe()
    }

    Shutdown(*) {
        super.Shutdown()
        if DirExist(this.TestRoot)
            try DirDelete(this.TestRoot, true)
    }
}

class SafeModeRuntimeProbe {
    __New() {
        this.ApplyCount := 0
        this.ResetCount := 0
        this.ShutdownCount := 0
        this.OutputLedger := {Keys: Map()}
    }

    ApplyMappings(*) {
        this.ApplyCount++
        return {RegistrationCount: 0}
    }

    ResetActiveState(*) {
        this.ResetCount++
        return 0
    }

    Shutdown() {
        this.ShutdownCount++
    }
}

class SafeModeInputProbe {
    __New() {
        this.StartCount := 0
        this.ShutdownCount := 0
    }

    Start() {
        this.StartCount++
    }

    Shutdown() {
        this.ShutdownCount++
    }

    GetDevices() => []
}

class DeterministicGuiKeyCaptureSession extends KeyCaptureSession {
}

class FakeMappingRepository {
    __New() {
        this.AppendCount := 0
        this.AppendBlockCount := 0
        this.LastPurpose := ""
        this.LastBlockText := ""
        this.ToggleCount := 0
        this.MoveCount := 0
        this.RemoveCount := 0
        this.LastMoveId := ""
        this.LastMoveIndex := 0
        this.EnabledStates := Map()
        this.StateVersion := 0
        this.Mappings := []
        this.StateSnapshots := Map()
        this.SaveCurrentSnapshot()
    }

    Load() => this.CloneMappings(this.Mappings)

    SeedMappings(mappings) {
        this.Mappings := this.CloneMappings(mappings)
        this.EnabledStates := Map()
        for mapping in this.Mappings
            this.EnabledStates[mapping.Id] := mapping.Enabled
        this.SaveCurrentSnapshot()
    }

    CreateMappingId(*) => "test-mapping"

    AppendManagedSpec(spec) {
        this.AppendCount++
        this.LastPurpose := spec["display"]["purpose"]
        mapping := {
            Id: spec["id"], Source: spec["display"]["source"],
            Target: spec["display"]["target"],
            Scope: spec["display"]["scope"],
            Purpose: spec["display"]["purpose"], Enabled: true,
            SourceSpec: spec["from"]["hotkey"], TargetSend: "",
            Mode: "managed", Schema: 2, Spec: spec,
            Descriptor: RuleCompiler.Compile(spec), Block: ""
        }
        this.Mappings.Push(mapping)
        this.EnabledStates[mapping.Id] := true
        this.AdvanceState()
        return mapping
    }

    ReadRegionBody() {
        if !this.StateSnapshots.Has(this.StateVersion)
            this.SaveCurrentSnapshot()
        return "fake-state-" this.StateVersion
    }

    WriteRegionBody(state, expectedState?) {
        if IsSet(expectedState) && this.ReadRegionBody() != expectedState
            throw Error("测试仓储检测到并发历史冲突")
        if !RegExMatch(String(state), "^fake-state-(\d+)$", &match)
            throw Error("测试仓储收到无法识别的历史快照")
        targetVersion := Integer(match[1])
        if !this.StateSnapshots.Has(targetVersion)
            throw Error("测试仓储找不到指定的历史快照")
        snapshot := this.StateSnapshots[targetVersion]
        this.StateVersion := targetVersion
        this.Mappings := this.CloneMappings(snapshot.Mappings)
        this.EnabledStates := this.CloneEnabledStates(snapshot.EnabledStates)
        return true
    }

    GetById(mappingId) {
        for mapping in this.Mappings {
            if mapping.Id == mappingId
                return this.CloneMapping(mapping)
        }
        throw Error("找不到测试映射：" mappingId)
    }

    CreateBlankBlock() {
        return "; @mapping-begin`r`n"
            . "; @schema=2`r`n; @mode=managed`r`n"
            . "; @id=user-template`r`n; @spec-begin`r`n"
            . "; {`"schema`":2,`"id`":`"user-template`"}`r`n"
            . "; @spec-end`r`n"
            . "; @generated-sha256=" Format("{:064}", 0) "`r`n"
            . "; @generated-begin`r`n"
            . "; 此规则由托管运行时注册。`r`n"
            . "; @generated-end`r`n"
            . "; @mapping-end"
    }

    GetAppendStartLine() => 149

    AppendBlock(blockText) {
        this.AppendBlockCount++
        this.LastBlockText := String(blockText)
        mapping := {
            Id: "editor-created", Source: "F17", Target: "F18",
            Scope: "全局", Purpose: "顶部新增编辑器", Enabled: true,
            SourceSpec: "F17", TargetSend: "{F18}", Mode: "managed",
            Block: blockText
        }
        this.Mappings.Push(mapping)
        this.EnabledStates[mapping.Id] := true
        this.AdvanceState()
        return mapping
    }

    ToggleEnabled(mappingId) {
        this.ToggleCount++
        enabled := this.EnabledStates.Has(mappingId)
            ? !this.EnabledStates[mappingId] : false
        this.EnabledStates[mappingId] := enabled
        for mapping in this.Mappings {
            if mapping.Id != mappingId
                continue
            mapping.Enabled := enabled
            this.AdvanceState()
            return this.CloneMapping(mapping)
        }
        throw Error("找不到测试映射：" mappingId)
    }

    MoveTo(mappingId, targetIndex) {
        this.MoveCount++
        this.LastMoveId := mappingId
        this.LastMoveIndex := targetIndex
        sourceIndex := 0
        for index, mapping in this.Mappings {
            if mapping.Id == mappingId {
                sourceIndex := index
                break
            }
        }
        if !sourceIndex
            throw Error("找不到测试映射：" mappingId)
        targetIndex := Max(1, Min(this.Mappings.Length, targetIndex))
        if sourceIndex == targetIndex
            return false
        mapping := this.Mappings.RemoveAt(sourceIndex)
        this.Mappings.InsertAt(targetIndex, mapping)
        this.AdvanceState()
        return true
    }

    Remove(mappingId) {
        this.RemoveCount++
        for index, mapping in this.Mappings {
            if mapping.Id != mappingId
                continue
            removed := this.Mappings.RemoveAt(index)
            if this.EnabledStates.Has(mappingId)
                this.EnabledStates.Delete(mappingId)
            this.AdvanceState()
            return this.CloneMapping(removed)
        }
        throw Error("找不到测试映射：" mappingId)
    }

    Append(sourceCapture, targetCapture, purpose) {
        this.AppendCount++
        this.LastPurpose := purpose
        mapping := {
            Id: "test-mapping",
            Source: sourceCapture.Display,
            Target: targetCapture.Display,
            Scope: "全局",
            Purpose: purpose,
            Enabled: true,
            Mode: "managed",
            SourceSpec: sourceCapture.SourceSpec,
            TargetSend: targetCapture.TargetSend,
            Block: ""
        }
        this.Mappings.Push(mapping)
        this.EnabledStates[mapping.Id] := true
        this.AdvanceState()
        return mapping
    }

    AdvanceState() {
        this.StateVersion++
        this.SaveCurrentSnapshot()
    }

    SaveCurrentSnapshot() {
        this.StateSnapshots[this.StateVersion] := {
            Mappings: this.CloneMappings(this.Mappings),
            EnabledStates: this.CloneEnabledStates(this.EnabledStates)
        }
    }

    CloneMappings(mappings) {
        result := []
        for mapping in mappings
            result.Push(this.CloneMapping(mapping))
        return result
    }

    CloneMapping(mapping) {
        clone := {
            Id: mapping.Id,
            Source: mapping.Source,
            Target: mapping.Target,
            Scope: mapping.HasOwnProp("Scope") ? mapping.Scope : "全局",
            Purpose: mapping.HasOwnProp("Purpose") ? mapping.Purpose : "",
            Enabled: mapping.HasOwnProp("Enabled") ? !!mapping.Enabled : true,
            SourceSpec: mapping.HasOwnProp("SourceSpec")
                ? mapping.SourceSpec : "",
            TargetSend: mapping.HasOwnProp("TargetSend")
                ? mapping.TargetSend : "",
            Block: mapping.HasOwnProp("Block") ? mapping.Block : ""
        }
        for propertyName in ["Mode", "Schema", "Spec", "Descriptor",
                "StartLine"] {
            if mapping.HasOwnProp(propertyName)
                clone.%propertyName% := mapping.%propertyName%
        }
        return clone
    }

    CloneEnabledStates(states) {
        result := Map()
        for mappingId, enabled in states
            result[mappingId] := enabled
        return result
    }
}

class ChurningViewerTrace {
    __New(viewer, entries, dirtyPasses) {
        this.Viewer := viewer
        this.Entries := entries
        this.DirtyPasses := dirtyPasses
        this.SnapshotCalls := 0
        this.Count := entries.Length
        this.Capacity := Max(entries.Length, 1)
        this.DroppedCount := 0
    }

    Snapshot(*) {
        this.SnapshotCalls++
        if this.SnapshotCalls <= this.DirtyPasses
            this.Viewer.OnTraceEntry({})
        return this.Entries
    }
}

class RejectingHistory {
    Commit(*) {
        throw Error("注入的历史提交失败")
    }
}
