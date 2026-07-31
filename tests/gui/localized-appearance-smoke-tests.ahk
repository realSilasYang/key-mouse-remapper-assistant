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

AssertSettingsFieldAligned(labelControl, dropDownControl, fieldName) {
    labelControl.GetPos(&labelX, &labelY, &labelWidth, &labelHeight)
    dropDownControl.GetPos(&dropDownX, &dropDownY,
        &dropDownWidth, &dropDownHeight)
    AssertTrue(Abs((labelY + labelHeight / 2)
        - (dropDownY + dropDownHeight / 2)) <= 2,
        fieldName "标签与下拉框没有垂直居中")
    AssertTrue(dropDownX >= labelX + labelWidth
        && dropDownWidth >= 200,
        fieldName "标签、间距或下拉框宽度不符合紧凑布局")
}

AssertButtonTextFits(button, extraContentWidthDip, context) {
    clientRect := Buffer(16, 0)
    AssertTrue(DllCall("user32\GetClientRect", "Ptr", button.Hwnd,
        "Ptr", clientRect, "Int"), context "：无法读取按钮宽度")
    deviceContext := DllCall("user32\GetDC", "Ptr", button.Hwnd, "Ptr")
    AssertTrue(deviceContext, context "：无法取得按钮绘图上下文")
    font := DllCall("user32\SendMessageW", "Ptr", button.Hwnd,
        "UInt", 0x0031, "Ptr", 0, "Ptr", 0, "Ptr")
    previousFont := font ? DllCall("gdi32\SelectObject",
        "Ptr", deviceContext, "Ptr", font, "Ptr") : 0
    extent := Buffer(8, 0)
    try {
        AssertTrue(DllCall("gdi32\GetTextExtentPoint32W",
            "Ptr", deviceContext, "Str", button.Text,
            "Int", StrLen(button.Text), "Ptr", extent, "Int"),
            context "：无法测量按钮文字")
        dpi := DllCall("user32\GetDpiForWindow", "Ptr", button.Hwnd,
            "UInt")
        if !dpi
            dpi := 96
        inset := Max(4, Round(6 * dpi / 96))
        extraWidth := Round(extraContentWidthDip * dpi / 96)
        availableWidth := NumGet(clientRect, 8, "Int")
        requiredWidth := NumGet(extent, 0, "Int") + extraWidth + inset * 2
        AssertTrue(requiredWidth <= availableWidth,
            context "：按钮文字会被省略（需要 " requiredWidth
                "px，实际 " availableWidth "px）")
    } finally {
        if previousFont
            DllCall("gdi32\SelectObject", "Ptr", deviceContext,
                "Ptr", previousFont)
        DllCall("user32\ReleaseDC", "Ptr", button.Hwnd,
            "Ptr", deviceContext)
    }
}

EnvSet("KEY_MOUSE_REMAPPER_GUI_TEST_OFFSCREEN", "1")
testRoot := A_Temp "\key-mouse-remapper-assistant-localized-gui-" A_TickCount "-"
    . Format("{:08X}", Random(0, 0xFFFFFFFF))
DirCreate(testRoot)
settingsPath := testRoot "\settings.ini"
FileAppend("[Appearance]`r`nUiLanguage=en-US`r`nUiFont=auto`r`n"
    . "Theme=light`r`n", settingsPath, "UTF-8-RAW")

app := ""
testFailure := ""
try {
    app := LocalizedAppearanceTestApp(settingsPath,
        testRoot "\history.dat", testRoot "\notification.txt")
    ShowOffscreenTestMappingWindow(app.Window, 980, 650)
    Sleep(80)
    AssertTestWindowOffscreen(app.Window.Gui.Hwnd, "本地化主窗口")
    AssertEqual("Keyboard & Mouse Remapper Assistant", app.Window.Gui.Title,
        "英文窗口标题没有应用")
    AssertEqual(app.Window.GetDeleteButtonText(),
        app.Window.DeleteButton.Text,
        "英文删除按钮没有热更新文本")
    AssertTrue(InStr(app.Window.AddButton.Text, "Add")
        && InStr(app.Window.SettingsButton.Text, "Settings"),
        "英文按钮文本没有应用")
    AssertEqual(MappingWindow.ExpandedSettingsButtonWidth,
        app.Window.SettingsButtonWidth, "英文设置按钮宽度错误")
    AssertEqual(MappingWindow.ExpandedSaveButtonWidth,
        app.Window.SaveButtonWidth, "英文保存按钮宽度错误")
    AssertTrue(!app.Window.HasOwnProp("EventButton"),
        "英文主界面仍保留重复的事件查看器按钮")
    AssertEqual(MappingWindow.ExpandedSupportButtonWidth,
        app.Window.SupportButtonWidth, "英文帮助按钮宽度错误")
    AssertEqual(MappingWindow.ExpandedDonateButtonWidth,
        app.Window.DonateButtonWidth, "英文捐赠按钮宽度错误")
    AssertButtonTextFits(app.Window.AddButton, 0,
        "英文新增按钮")
    AssertButtonTextFits(app.Window.PauseResumeButton, 0,
        "英文暂停按钮")
    AssertButtonTextFits(app.Window.DeleteButton, 0,
        "英文删除按钮")
    AssertButtonTextFits(app.Window.SettingsButton, 21,
        "英文设置按钮")
    AssertButtonTextFits(app.Window.SupportButton, 21,
        "英文帮助信息按钮")
    AssertButtonTextFits(app.Window.DonateButton, 21,
        "英文捐赠按钮")
    AssertButtonTextFits(app.Window.SaveButton, 23,
        "英文保存映射按钮")
    AssertButtonTextFits(app.Window.ClearButton, 23,
        "英文清空按钮")
    AssertTrue(InStr(app.Window.ListHeader.Cells[1].Text, "No.")
        && InStr(app.Window.ListHeader.Cells[2].Text, "Source key")
        && InStr(app.Window.ListHeader.Cells[5].Text, "Purpose"),
        "英文伪表头没有应用")
    for languageCode in LocalizationService.GetSupportedLanguageCodes() {
        LocalizationService.Configure(languageCode, "auto")
        app.Window.ApplyAppearance()
        ShowOffscreenTestMappingWindow(app.Window,
            app.Window.MinClientWidth)
        Sleep(30)
        AssertEqual(Tr("键鼠重映射小助手"), app.Window.Gui.Title,
            languageCode " 主窗口标题没有热切换")
        AssertEqual(app.Window.GetAddButtonText(), app.Window.AddButton.Text,
            languageCode " 新增按钮没有热切换")
        AssertEqual(Tr("设置"), app.Window.SettingsButton.Text,
            languageCode " 设置按钮没有热切换")
        AssertEqual(Tr("帮助信息"), app.Window.SupportButton.Text,
            languageCode " 帮助按钮没有热切换")
        AssertEqual(Tr("捐赠"), app.Window.DonateButton.Text,
            languageCode " 捐赠按钮没有热切换")
        AssertTrue(InStr(app.Window.ListHeader.Cells[2].Text,
                Tr("来源按键"))
            && InStr(app.Window.ListHeader.Cells[5].Text,
                Tr("设计目的")),
            languageCode " 伪表头没有热切换")
        for buttonSpec in [
            {Button: app.Window.AddButton, Extra: 0, Name: "add"},
            {Button: app.Window.PauseResumeButton, Extra: 0,
                Name: "pause"},
            {Button: app.Window.DeleteButton, Extra: 0, Name: "delete"},
            {Button: app.Window.SettingsButton, Extra: 21, Name: "settings"},
            {Button: app.Window.SupportButton, Extra: 21, Name: "help"},
            {Button: app.Window.DonateButton, Extra: 21, Name: "donate"},
            {Button: app.Window.SaveButton, Extra: 23, Name: "save"},
            {Button: app.Window.ClearButton, Extra: 23, Name: "clear"}
        ]
            AssertButtonTextFits(buttonSpec.Button, buttonSpec.Extra,
                languageCode " " buttonSpec.Name "按钮")

        app.OpenSettings()
        AssertTrue(IsObject(app.SettingsWindow),
            languageCode " 设置窗口无法打开")
        localizedSettings := app.SettingsWindow
        AssertTestWindowOffscreen(localizedSettings.Gui.Hwnd,
            languageCode " 设置窗口")
        localizedSettings.SwitchTab(3)
        AssertButtonTextFits(localizedSettings.EventCapacityLabel, 0,
            languageCode " 事件容量标签")
        localizedSettings.Gui.GetClientPos(, , &localizedSettingsWidth)
        localizedSettings.EventCapacityLabel.GetPos(&localizedEventLabelX)
        localizedSettings.EventCapacityInput.Background.GetPos(
            &localizedEventInputX, , &localizedEventInputWidth)
        AssertTrue(Abs((localizedEventLabelX + localizedEventInputX
                + localizedEventInputWidth) / 2
                - localizedSettingsWidth / 2) <= 1,
            languageCode " 事件设置字段组没有水平居中")
        localizedSettings.RequestClose()
    }
    LocalizationService.Configure("en-US", "auto")
    app.Window.ApplyAppearance()
    AssertEqual("F1F5F9", MappingWindow.Colors.Window,
        "浅色窗口调色板没有应用")
    initialPurposeFont := GetControlFontFace(app.Window.PurposeEdit)
    LocalizationService.Configure("zh-CN", "auto")
    app.Window.ApplyAppearance()
    ShowOffscreenTestMappingWindow(app.Window, MappingWindow.MinClientWidth)
    Sleep(80)
    AssertEqual(LocalizationService.GetUiFontName(),
        GetControlFontFace(app.Window.PurposeEdit),
        "界面字体热切换没有更新设计目的输入框")
    LocalizationService.Configure("en-US", "auto")
    app.Window.ApplyAppearance()
    app.Window.Gui.GetClientPos(, , &expandedClientWidth)
    AssertTrue(expandedClientWidth >= MappingWindow.ExpandedMinClientWidth,
        "切换 English 后主窗口没有扩展到可容纳按钮的最小宽度")
    AssertEqual(app.Window.GetDeleteButtonText(),
        app.Window.DeleteButton.Text,
        "切换 English 后删除按钮仍为中文")
    AssertButtonTextFits(app.Window.SettingsButton, 21,
        "热切换后的英文设置按钮")
    AssertButtonTextFits(app.Window.SaveButton, 23,
        "热切换后的英文保存映射按钮")
    AssertEqual(initialPurposeFont, GetControlFontFace(app.Window.PurposeEdit),
        "恢复界面语言后设计目的输入框仍保留旧字体")
    AssertEqual(ColorRef(MappingWindow.Colors.Surface),
        SendMessage(0x1000, 0, 0, , app.Window.List.Hwnd),
        "浅色 ListView 原生背景没有应用")
    AssertEqual("Undone: Reorder mappings：F5 -> F4",
        app.FormatHistoryResult(
            app.CreateHistoryAction("reorder", "F5 -> F4"), true),
        "英文撤销提示没有使用当前语言格式化具体动作")
    AssertEqual("Redone: Settings：UI language, Theme",
        app.FormatHistoryResult(app.CreateHistoryAction("settings", "",
            ["ui-language", "theme"]), false),
        "英文重做提示没有列出具体设置字段")

    app.OpenSettings()
    AssertTrue(IsObject(app.SettingsWindow), "英文设置窗口没有打开")
    AssertEqual("Keyboard & Mouse Remapper Assistant settings",
        app.SettingsWindow.Gui.Title,
        "设置窗口标题没有本地化")
    AssertEqual(5, app.SettingsWindow.LanguageDropDown.Value,
        "设置窗口没有选中 English")
    AssertEqual(2, app.SettingsWindow.ThemeDropDown.Value,
        "设置窗口没有选中浅色主题")
    settingsDialog := app.SettingsWindow
    AssertTestWindowOffscreen(settingsDialog.Gui.Hwnd, "本地化设置窗口")
    settingsDialog.Gui.GetClientPos(, , &settingsClientWidth,
        &settingsClientHeight)
    AssertEqual(SettingsWindow.ExpandedWidth, settingsDialog.WindowWidth,
        "英文设置窗口没有使用小助手的扩展宽度")
    AssertEqual(SettingsWindow.ExpandedWidth, settingsClientWidth,
        "英文设置窗口实际客户区宽度错误")
    AssertEqual(SettingsWindow.ClientHeight, settingsClientHeight,
        "设置窗口实际客户区高度错误")
    AssertTrue(!settingsDialog.HasOwnProp("Title"),
        "设置窗口仍保留页面内重复大标题")
    AssertEqual("Language:", settingsDialog.LanguageLabel.Text,
        "语言标签没有采用小助手字段格式")
    AssertEqual("Content font:", settingsDialog.FontLabel.Text,
        "字体标签没有采用小助手字段格式")
    AssertEqual("Theme:", settingsDialog.ThemeLabel.Text,
        "主题标签没有采用小助手字段格式")
    AssertSettingsFieldAligned(settingsDialog.LanguageLabel,
        settingsDialog.LanguageDropDown, "语言")
    AssertSettingsFieldAligned(settingsDialog.FontLabel,
        settingsDialog.FontDropDown, "字体")
    AssertSettingsFieldAligned(settingsDialog.ThemeLabel,
        settingsDialog.ThemeDropDown, "主题")
    settingsDialog.LanguageLabel.GetPos(&generalLeft)
    settingsDialog.LanguageDropDown.GetPos(&generalInputX, ,
        &generalInputWidth)
    AssertTrue(generalLeft == settingsDialog.Layout.ContentX
            && generalInputX + generalInputWidth
                == settingsDialog.Layout.ContentRight,
        "设置通用页没有使用左右对称的完整内容区")

    comboPadding := GetComboBoxDisplayPadding()
    AssertEqual("English", Trim(settingsDialog.LanguageDropDown.Text,
        comboPadding), "语言下拉框内边距破坏了显示值")
    AssertTrue(SubStr(settingsDialog.LanguageDropDown.Text, 1, 1)
        == comboPadding
        && SubStr(settingsDialog.LanguageDropDown.Text, -1) == comboPadding,
        "语言下拉框没有小助手同款左右内边距")
    for themedDropDown in [settingsDialog.LanguageDropDown,
            settingsDialog.FontDropDown, settingsDialog.ThemeDropDown] {
        comboStyle := DllCall("user32\GetWindowLongPtrW", "Ptr",
            themedDropDown.Hwnd, "Int", -16, "Ptr")
        comboExStyle := DllCall("user32\GetWindowLongPtrW", "Ptr",
            themedDropDown.Hwnd, "Int", -20, "Ptr")
        AssertTrue(!(comboStyle & 0x00800000)
            && !(comboExStyle & (0x00000001 | 0x00000200 | 0x00020000)),
            "设置下拉框仍保留原生凸起边框")
        comboHandles := GetComboBoxThemeHandles(themedDropDown.Hwnd)
        AssertTrue(comboHandles.Combo
            && DllCall("uxtheme\GetWindowTheme", "Ptr",
                comboHandles.Combo, "Ptr"),
            "设置下拉框收起区没有应用原生主题")
        AssertTrue(comboHandles.List
            && DarkComboBoxListThemeRegistry.IsRegistered(comboHandles.List),
            "设置下拉框弹出列表没有注册主题着色")
    }

    settingsDialog.SwitchTab(3)
    AssertButtonTextFits(settingsDialog.EventCapacityLabel, 0,
        "事件缓冲区容量标签")
    settingsDialog.EventCapacityLabel.GetPos(&eventLabelX, ,
        &eventLabelWidth)
    settingsDialog.EventCapacityInput.Background.GetPos(&eventInputX, ,
        &eventInputWidth)
    eventGroupCenter := (eventLabelX + eventInputX + eventInputWidth) / 2
    AssertTrue(Abs(eventGroupCenter - settingsClientWidth / 2) <= 1
            && eventInputX - (eventLabelX + eventLabelWidth) == 12,
        "事件设置字段组没有在窗口中水平居中或间距错误")
    settingsDialog.EventAutoScrollCheck.GetPos(&eventCheckX, ,
        &eventCheckWidth)
    AssertTrue(Abs(eventCheckX + eventCheckWidth / 2
            - settingsClientWidth / 2) <= 1,
        "事件设置复选框没有在窗口中水平居中")

    settingsDialog.SaveButton.GetPos(&saveX, &saveY,
        &saveWidth, &saveHeight)
    settingsDialog.CancelButton.GetPos(&cancelX, &cancelY,
        &cancelWidth, &cancelHeight)
    settingsDialog.ValidationStatus.GetPos(, &validationY, ,
        &validationHeight)
    AssertTrue(saveWidth == 80 && saveHeight == 28
        && cancelWidth == 80 && cancelHeight == 28
        && cancelX - (saveX + saveWidth) == 10,
        "设置操作按钮没有采用 80x28 尺寸与 10px 间距")
    AssertTrue(saveY + saveHeight <= settingsClientHeight
            && cancelY + cancelHeight <= settingsClientHeight
            && validationY + validationHeight <= settingsClientHeight,
        "设置操作区超出窗口客户区")
    settingsDialog.SwitchTab(4)
    settingsDialog.ReleasesButton.GetPos(, &releasesY, , &releasesHeight)
    settingsDialog.ProjectButton.GetPos(, &projectY, , &projectHeight)
    AssertTrue(releasesY + releasesHeight <= settingsClientHeight
            && projectY + projectHeight <= settingsClientHeight,
        "设置关于页按钮超出窗口客户区")
    releasesState := settingsDialog.Interactions.Controls[
        settingsDialog.ReleasesButton.Hwnd]
    projectState := settingsDialog.Interactions.Controls[
        settingsDialog.ProjectButton.Hwnd]
    AssertTrue(RegExMatch(releasesState.ButtonImage.SourcePath,
            "i)\\refresh-cw-action\.svg$")
        && releasesState.TooltipText == ""
        && RegExMatch(projectState.ButtonImage.SourcePath,
            "i)\\external-link\.svg$")
        && projectState.TooltipText == SettingsWindow.ProjectHomeUrl,
        "关于页更新图标、项目外链图标或悬浮提示与基准不一致")
    settingsDialog.SwitchTab(1)
    centeredPosition := SettingsWindow.CalculateCenteredPosition(680, 330,
        100, 100, 900, 700, 0, 0, 1920, 1040)
    edgePosition := SettingsWindow.CalculateCenteredPosition(680, 330,
        1700, 900, 1900, 1000, 0, 0, 1920, 1040)
    AssertTrue(centeredPosition.X == 160 && centeredPosition.Y == 235
            && edgePosition.X == 1240 && edgePosition.Y == 710,
        "设置窗口没有相对所有者居中并限制在显示器工作区")
    AssertEqual("Save", settingsDialog.SaveButton.Text,
        "保存按钮仍包含旧版 Emoji 或冗余文案")
    AssertEqual("Cancel", settingsDialog.CancelButton.Text,
        "取消按钮仍包含旧版 Emoji")
    saveState := settingsDialog.Interactions.Controls[
        settingsDialog.SaveButton.Hwnd]
    cancelState := settingsDialog.Interactions.Controls[
        settingsDialog.CancelButton.Hwnd]
    AssertTrue(!saveState.HasOwnProp("ButtonImage")
        && !cancelState.HasOwnProp("ButtonImage"),
        "设置保存/取消按钮不应附加装饰图标")
    AssertEqual(UiThemeService.GetPalette().ButtonText, saveState.TextColor,
        "浅色主题主按钮文字没有保持白色对比度")
    AssertEqual(UiThemeService.GetPalette().ToolbarText, cancelState.TextColor,
        "浅色主题次按钮文字颜色错误")
    AssertEqual(settingsDialog.Interactions.DarkenColor(saveState.Normal),
        saveState.Pressed, "保存按钮没有使用小助手的下沉按压色")
    AssertTrue(!DllCall("user32\IsWindowEnabled", "Ptr",
        app.Window.Gui.Hwnd, "Int"), "设置窗口打开时主窗口仍可交互")
    selectedFont := settingsDialog.FontValues[
        settingsDialog.FontDropDown.Value]
    AssertTrue(settingsDialog.RefreshFontDropDown()
        && settingsDialog.FontValues[settingsDialog.FontDropDown.Value]
            == selectedFont,
        "字体列表展开刷新后没有保留当前选择")

    settingsDialog.ThemeDropDown.Value := 3
    settingsDialog.RequestClose()
    AssertTrue(!IsObject(app.SettingsWindow),
        "取消设置后应用仍持有旧引用")
    AssertTrue(DllCall("user32\IsWindowEnabled", "Ptr",
        app.Window.Gui.Hwnd, "Int"), "设置窗口关闭后主窗口没有恢复交互")

    AssertTrue(app.OpenHelpInfo(), "帮助信息窗口无法打开")
    supportDialog := app.SupportInfo
    AssertTestWindowOffscreen(supportDialog.Gui.Hwnd, "帮助信息窗口")
    AssertEqual(Tr("帮助信息"), supportDialog.Gui.Title,
        "帮助信息窗口标题错误")
    AssertTrue(!DllCall("user32\IsWindowEnabled", "Ptr",
        app.Window.Gui.Hwnd, "Int"),
        "帮助信息窗口打开时主窗口仍可交互")
    for supportSpec in [
        {Button: supportDialog.GuideButton, Text: Tr("使用说明"),
            Icon: "book-open.svg"},
        {Button: supportDialog.EventButton, Text: Tr("事件查看器"),
            Icon: "logs.svg"},
        {Button: supportDialog.FeedbackButton, Text: Tr("提交反馈"),
            Icon: "message-square-text.svg"}
    ] {
        AssertEqual(supportSpec.Text, supportSpec.Button.Text,
            "帮助信息分流按钮文本错误")
        supportState := supportDialog.Interactions.Controls[
            supportSpec.Button.Hwnd]
        AssertTrue(supportState.HasOwnProp("ButtonImage")
            && RegExMatch(supportState.ButtonImage.SourcePath,
                "i)\\" supportSpec.Icon "$"),
            "帮助信息分流按钮缺少彩色语义图标：" supportSpec.Icon)
        AssertButtonTextFits(supportSpec.Button, 23,
            "帮助信息分流按钮 " supportSpec.Icon)
    }
    AssertEqual("https://github.com/realSilasYang/key-mouse-remapper-assistant/issues/new/choose",
        SupportInfoWindow.FeedbackUrl, "帮助信息反馈地址错误")

    AssertTrue(supportDialog.OpenGuide(),
        "帮助信息窗口无法切换到使用说明")
    AssertTrue(!IsObject(app.SupportInfo) && IsObject(app.Help),
        "帮助分流窗口没有释放，或使用说明未被应用持有")
    helpDialog := app.Help
    AssertTestWindowOffscreen(helpDialog.Gui.Hwnd, "使用说明窗口")
    AssertEqual(Tr("使用说明"), helpDialog.Gui.Title,
        "使用说明窗口标题错误")
    AssertTrue(InStr(helpDialog.TextEdit.Value, Tr("一、快速上手"))
        && InStr(helpDialog.TextEdit.Value,
            Tr("五、后台运行与问题排查")),
        "使用说明缺少本地化的完整章节")
    AssertTrue((ControlGetStyle(helpDialog.TextEdit) & 0x0800) != 0,
        "使用说明文本区不是只读控件")
    AssertTrue(!DllCall("user32\IsWindowEnabled", "Ptr",
        app.Window.Gui.Hwnd, "Int"),
        "使用说明打开时主窗口错误恢复交互")
    helpDialog.RequestClose()
    AssertTrue(!IsObject(app.Help)
        && DllCall("user32\IsWindowEnabled", "Ptr",
            app.Window.Gui.Hwnd, "Int"),
        "使用说明关闭后应用引用或 Owner 锁未释放")

    AssertTrue(app.OpenHelpInfo(), "帮助信息窗口第二次打开失败")
    supportDialog := app.SupportInfo
    AssertTrue(supportDialog.OpenEventViewer(),
        "帮助信息窗口无法切换到事件查看器")
    AssertTrue(!IsObject(app.SupportInfo) && IsObject(app.EventViewer)
        && DllCall("user32\IsWindowEnabled", "Ptr",
            app.Window.Gui.Hwnd, "Int"),
        "帮助分流到事件查看器后窗口层级未正确恢复")
    app.EventViewer.RequestClose()

    AssertTrue(app.OpenDonation(), "捐赠窗口无法打开")
    donationDialog := app.Donation
    AssertTestWindowOffscreen(donationDialog.Gui.Hwnd, "捐赠窗口")
    AssertEqual(Tr("支持开源项目"), donationDialog.Gui.Title,
        "捐赠窗口标题错误")
    AssertTrue(donationDialog.QrPictures.Length == 2
        && donationDialog.QrLabels.Length == 2
        && donationDialog.MissingQrTexts.Length == 0,
        "捐赠窗口没有加载两张发行包二维码")
    AssertEqual(Tr("微信支付"), donationDialog.QrLabels[1].Text,
        "微信支付标签错误")
    AssertEqual(Tr("支付宝"), donationDialog.QrLabels[2].Text,
        "支付宝标签错误")
    AssertEqual(Tr("如果小助手为您节省了排查问题和恢复程序的时间，欢迎通过下方二维码打赏作者！`n请选择扶贫方式："),
        donationDialog.MessageText.Text, "捐赠窗口文案未与基准保持一致")
    AssertTrue((ControlGetStyle(donationDialog.MessageText) & 0x80) != 0,
        "捐赠说明没有禁止原生助记前缀，英文 & 会被吞掉")
    AssertTrue(!DllCall("user32\IsWindowEnabled", "Ptr",
        app.Window.Gui.Hwnd, "Int"),
        "捐赠窗口打开时主窗口仍可交互")
    donationDialog.RequestClose()
    AssertTrue(!IsObject(app.Donation)
        && DllCall("user32\IsWindowEnabled", "Ptr",
            app.Window.Gui.Hwnd, "Int"),
        "捐赠窗口关闭后应用引用或 Owner 锁未释放")
    AssertTrue(app.OpenDonation(), "捐赠窗口第二次打开失败")
    AssertTrue(app.Donation.QrPictures.Length == 2,
        "捐赠窗口第二次打开后二维码未恢复")
    app.Donation.RequestClose()

    mainHwndBeforeHotApply := app.Window.Gui.Hwnd
    AssertTrue(app.SaveSettings({UiLanguage: "en-US", UiFont: "auto",
        Theme: "dark"}), "深色主题无法原位保存")
    AssertTrue(app.Window.Gui.Hwnd == mainHwndBeforeHotApply
        && DllCall("user32\IsWindow", "Ptr", mainHwndBeforeHotApply, "Int"),
        "界面设置热切换重建或关闭了主窗口")
    AssertEqual(0, app.ReloadRequests,
        "纯界面设置错误请求了脚本重新加载")
    AssertEqual("1E1E1E", MappingWindow.Colors.Window,
        "深色主题没有即时更新主窗口调色板")
    AssertColorRefNear(ColorRef(MappingWindow.Colors.Window),
        ReadTestClientPixel(app.Window.Gui.Hwnd, 500, 430),
        "主题热切换后主窗口客户区仍显示旧背景色")
    Loop 3 {
        restoreCycle := A_Index
        AssertTrue(app.Window.RequestHide(true)
                && !DllCall("user32\IsWindowVisible", "Ptr",
                    app.Window.Gui.Hwnd, "Int"),
            "主窗口第 " restoreCycle " 次无法隐藏到托盘")
        app.Window.Show()
        Sleep(120)
        AssertTrue(DllCall("user32\IsWindowVisible", "Ptr",
                app.Window.Gui.Hwnd, "Int"),
            "托盘第 " restoreCycle " 次恢复后主窗口仍不可见")
        AssertColorRefNear(ColorRef(MappingWindow.Colors.Window),
            ReadTestClientPixel(app.Window.Gui.Hwnd, 500, 430),
            "托盘第 " restoreCycle " 次恢复后父客户区露出错误背景")
    }
    AssertEqual("Keyboard & Mouse Remapper Assistant", app.Window.Gui.Title,
        "主题热切换破坏了当前界面语言")

    AssertTrue(app.PerformUndo(), "界面设置无法原位撤销")
    AssertTrue(app.Window.Gui.Hwnd == mainHwndBeforeHotApply
            && MappingWindow.Colors.Window == "F1F5F9"
            && app.ReloadRequests == 0,
        "撤销界面设置时重建了窗口、错误重载或没有恢复浅色主题")
    AssertEqual("Undone: Settings：Theme",
        app.Toast.TextControl.Text, "界面设置撤销气泡没有显示具体字段")
    AssertColorRefNear(ColorRef(MappingWindow.Colors.Window),
        ReadTestClientPixel(app.Window.Gui.Hwnd, 500, 430),
        "撤销主题后主窗口客户区仍显示旧背景色")
    app.Toast.HideNow()

    AssertTrue(app.PerformRedo(), "界面设置无法原位重做")
    AssertTrue(app.Window.Gui.Hwnd == mainHwndBeforeHotApply
            && MappingWindow.Colors.Window == "1E1E1E"
            && app.ReloadRequests == 0,
        "重做界面设置时重建了窗口、错误重载或没有恢复深色主题")
    AssertEqual("Redone: Settings：Theme",
        app.Toast.TextControl.Text, "界面设置重做气泡没有显示具体字段")
    app.Toast.HideNow()

    AssertTrue(app.SaveSettings({UiLanguage: "en-US", UiFont: "auto",
        Theme: "auto"}), "跟随系统主题无法原位保存")
    Sleep(300)
    app.SystemThemeApplyCount := 0
    app.OnSystemSettingChange()
    Sleep(100)
    app.OnSystemSettingChange()
    Sleep(180)
    AssertEqual(0, app.SystemThemeApplyCount,
        "连续系统主题消息没有重置去抖计时")
    Sleep(120)
    AssertEqual(1, app.SystemThemeApplyCount,
        "系统主题消息没有合并为一次原位刷新")
    AssertEqual(0, app.ReloadRequests,
        "系统主题刷新错误请求了脚本重新加载")
    if A_Args.Length && A_Args[1] == "--visual-probe" {
        visualMode := A_Args.Length >= 2 ? A_Args[2] : "main"
        visualWindow := app.Window
        switch visualMode {
            case "settings":
                app.OpenSettings()
                visualWindow := app.SettingsWindow
            case "events":
                app.OpenEventViewer()
                visualWindow := app.EventViewer
            case "support":
                app.OpenHelpInfo()
                visualWindow := app.SupportInfo
            case "guide":
                app.OpenHelp()
                visualWindow := app.Help
            case "donation":
                app.OpenDonation()
                visualWindow := app.Donation
        }
        if visualWindow != app.Window {
            visualWindow.Gui.Opt("-Owner")
            app.Window.Gui.Hide()
        }
        visualWindow.Gui.Title := "键鼠重映射小助手 - 视觉回归 - " visualMode
        if visualWindow == app.Window
            app.Window.ShowWithOptions("x100 y100")
        else
            visualWindow.Gui.Show("x100 y100")
        Sleep(300000)
    }
    WriteTestSuccess("localized-appearance-smoke")
} catch as localizedError {
    testFailure := localizedError.Message "`n" localizedError.Stack
} finally {
    if IsObject(app)
        app.Shutdown()
    if DirExist(testRoot)
        DirDelete(testRoot, true)
}
if testFailure != "" {
    FileAppend(testFailure "`n", "**")
    ExitApp(1)
}
ExitApp(0)

class LocalizedAppearanceTestApp extends KeyMouseRemapperAssistantApp {
    __New(settingsPath, historyPath, notificationPath) {
        this.ReloadRequests := 0
        this.SystemThemeApplyCount := 0
        super.__New(settingsPath, historyPath, notificationPath)
        this.Repository := LocalizedFakeRepository()
    }

    ScheduleReload(*) {
        this.ReloadRequests++
    }

    ApplySystemThemeChange(*) {
        this.SystemThemeApplyCount++
        return true
    }
}

class LocalizedFakeRepository {
    Load() => []
    ReadRegionBody() => ""
}
