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
#Include ..\..\src\Core\AIService.ahk
#Include ..\..\src\Core\DirectRuntimeSupport.ahk
#Include ..\..\src\Core\ApplicationVersionInfo.ahk
#Include ..\..\src\Config\AppSettingsService.ahk
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
#Include ..\..\app\UI\DarkMessageBox.ahk
#Include ..\..\app\Windows\DarkTooltipWindow.ahk
#Include ..\..\src\UI\MappingUiInteractions.ahk
#Include ..\..\src\UI\ListViewPseudoHeader.ahk
#Include ..\..\app\UI\ListViewSelectionPresenter.ahk
#Include ..\..\app\Windows\ListCellTooltipWindow.ahk
#Include ..\..\app\Windows\SettingsWindow.ahk
#Include ..\..\app\Windows\AboutWindow.ahk
#Include ..\..\app\Windows\DonationWindow.ahk
#Include ..\..\app\Windows\SupportInfoWindow.ahk
#Include ..\..\app\Windows\EventViewerWindow.ahk
#Include ..\..\app\Windows\RulePackageImportWindow.ahk
#Include ..\..\app\Windows\HelpWindow.ahk

auxiliaryVisualExitCode := RunAuxiliaryWindowVisualTests()
ExitApp(IsNumber(auxiliaryVisualExitCode) ? auxiliaryVisualExitCode : 0)

RunAuxiliaryWindowVisualTests() {
    ownerWindow := ""
    confirmVisualDialog := ""
    textInputVisualDialog := ""
    comparisonVisualDialog := ""
    settingsVisualDialog := ""
    promptsEditorDialog := ""
    promptEditorDialog := ""
    aboutVisualDialog := ""
    donationVisualDialog := ""
    supportVisualDialog := ""
    eventVisualDialog := ""
    packageVisualDialog := ""
    helpVisualDialog := ""
    exitCode := 0
    try {
        LocalizationService.Configure("zh-CN", "")
        ValidateUiFontPriority()
        UiThemeService.Configure("dark")
        MappingWindow.Colors := UiThemeService.GetPalette()
        ownerWindow := AuxiliaryVisualOwner()

        confirmVisualDialog := DarkConfirmDialog("test", "test", Tr("保存"),
            Tr("取消"), ownerWindow.Gui)
        confirmVisualDialog.ConfirmButton.GetPos(, , &confirmButtonWidth)
        confirmVisualDialog.CancelButton.GetPos(, , &confirmCancelWidth)
        confirmState := confirmVisualDialog.Interactions.Controls[
            confirmVisualDialog.ConfirmButton.Hwnd]
        confirmCancelState := confirmVisualDialog.Interactions.Controls[
            confirmVisualDialog.CancelButton.Hwnd]
        warningDeviceContext := DllCall("user32\GetDC", "Ptr",
            confirmVisualDialog.TypeIcon.Hwnd, "Ptr")
        warningColor := 0xFFFFFFFF
        if warningDeviceContext {
            SendMessage(0x0138, warningDeviceContext,
                confirmVisualDialog.TypeIcon.Hwnd, ,
                confirmVisualDialog.Gui.Hwnd) ; WM_CTLCOLORSTATIC
            warningColor := DllCall("gdi32\GetTextColor", "Ptr",
                warningDeviceContext, "UInt") & 0xFFFFFF
            DllCall("user32\ReleaseDC", "Ptr",
                confirmVisualDialog.TypeIcon.Hwnd, "Ptr",
                warningDeviceContext)
        }
        AuxiliaryVisualAssert(confirmButtonWidth == 80
                && confirmCancelWidth == 80
                && !confirmState.HasOwnProp("ButtonImage")
                && !confirmCancelState.HasOwnProp("ButtonImage")
                && confirmState.Normal == "3F6B5B"
                && confirmVisualDialog.TypeIcon.Text == Chr(0x26A0)
                && confirmVisualDialog.WarningIconColor
                    == MappingWindow.Colors.Warning
                && warningColor == ColorRef(MappingWindow.Colors.Warning),
            "The shared confirm dialog commands or yellow warning icon are incorrect.")
        confirmVisualDialog.Dispose(false)
        confirmVisualDialog := ""

        confirmVisualDialog := DarkConfirmDialog("test", "test",
            Tr("保存并运行"), Tr("取消"), ownerWindow.Gui)
        confirmVisualDialog.OnKeyDown(0x0D, 0, Win32.WM_KEYDOWN,
            confirmVisualDialog.Gui.Hwnd)
        AuxiliaryVisualAssert(confirmVisualDialog.WindowWidth == 365
                && confirmVisualDialog.Accepted
                && confirmVisualDialog.Disposed
                && confirmVisualDialog.KeyDownCallback == "",
            "The managed-script confirmation is not wider or Enter did not accept it.")
        confirmVisualDialog := ""
        if EnvGet("AUXILIARY_CONFIRM_ONLY") == "1"
            return

        textInputVisualDialog := DarkTextInputDialog(
            Tr("我是来帮你的，你要干什么？！"), Tr("生成重映射规则"),
            Tr("生成"), Tr("取消"), Tr("请输入规则目的。"),
            ownerWindow.Gui, "上次失败时输入的规则目的")
        textInputVisualDialog.TextEdit.GetPos(, , &purposeInputWidth,
            &purposeInputHeight)
        textInputVisualDialog.ConfirmButton.GetPos(, &compactConfirmY)
        inputConfirmState := textInputVisualDialog.Interactions.Controls[
            textInputVisualDialog.ConfirmButton.Hwnd]
        inputCancelState := textInputVisualDialog.Interactions.Controls[
            textInputVisualDialog.CancelButton.Hwnd]
        AuxiliaryVisualAssert(purposeInputWidth == 420
                && textInputVisualDialog.TextEdit.Value
                    == "上次失败时输入的规则目的"
                && purposeInputHeight == DarkTextInputDialog.EditorHeight
                && purposeInputHeight == 108
                && DarkTextInputDialog.WindowHeight == 220
                && textInputVisualDialog.CurrentWindowHeight == 220
                && !textInputVisualDialog.Status.Visible
                && compactConfirmY == DarkTextInputDialog.CompactButtonY
                && textInputVisualDialog.Interactions.TextInputTargets.Has(
                    textInputVisualDialog.TextEdit.Hwnd)
                && !inputConfirmState.HasOwnProp("ButtonImage")
                && !inputCancelState.HasOwnProp("ButtonImage"),
            "The AI-purpose dialog does not expose a compact selectable input.")
        textInputVisualDialog.TextEdit.Value := "  "
        AuxiliaryVisualAssert(!textInputVisualDialog.Confirm()
                && textInputVisualDialog.Status.Text
                    == Tr("请输入规则目的。")
                && textInputVisualDialog.Status.Visible
                && textInputVisualDialog.CurrentWindowHeight
                    == DarkTextInputDialog.ErrorWindowHeight,
            "The AI-purpose dialog accepted an empty purpose.")
        textInputVisualDialog.ConfirmButton.GetPos(, &errorConfirmY)
        AuxiliaryVisualAssert(errorConfirmY == DarkTextInputDialog.ErrorButtonY
                && textInputVisualDialog.ClearValidationError()
                && !textInputVisualDialog.Status.Visible
                && textInputVisualDialog.CurrentWindowHeight
                    == DarkTextInputDialog.WindowHeight,
            "The AI-purpose dialog retained empty validation space.")
        textInputVisualDialog.TextEdit.Value := "让 CapsLock 配合方向键移动光标"
        AuxiliaryVisualAssert(textInputVisualDialog.Confirm()
                && textInputVisualDialog.Accepted
                && textInputVisualDialog.Value
                    == "让 CapsLock 配合方向键移动光标",
            "The AI-purpose dialog did not return the entered purpose.")
        textInputVisualDialog := ""

        comparisonVisualDialog := DarkTextComparisonDialog(
            "; @mapping-begin`n; @名称=旧规则`nF24::Send('{F23}')",
            "; @mapping-begin`n; @名称=新规则`nF24::MsgBox('new')`nreturn",
            Tr("审阅 AI 优化结果"), ownerWindow.Gui)
        comparisonVisualDialog.CurrentEdit.GetPos(&currentReviewX,
            &currentReviewY, &currentReviewWidth, &currentReviewHeight)
        comparisonVisualDialog.ProposedEdit.GetPos(&proposedReviewX,
            &proposedReviewY, &proposedReviewWidth, &proposedReviewHeight)
        reviewStats := DarkTextComparisonDialog.CalculateLineStats(
            comparisonVisualDialog.CurrentText,
            comparisonVisualDialog.ProposedText)
        currentReviewStyle := WinGetStyle("ahk_id "
            comparisonVisualDialog.CurrentEdit.Hwnd)
        proposedReviewStyle := WinGetStyle("ahk_id "
            comparisonVisualDialog.ProposedEdit.Hwnd)
        currentToken := AhkV2Lexer(
            comparisonVisualDialog.CurrentText).GetTokens()[1]
        currentSyntaxFormat := AuxiliaryReadRichTextFormat(
            comparisonVisualDialog.CurrentEdit.Hwnd, currentToken.Start)
        currentDifferenceFormat := AuxiliaryReadRichTextFormat(
            comparisonVisualDialog.CurrentEdit.Hwnd,
            comparisonVisualDialog.LineDiff.CurrentRanges[1].Start)
        proposedDifferenceFormat := AuxiliaryReadRichTextFormat(
            comparisonVisualDialog.ProposedEdit.Hwnd,
            comparisonVisualDialog.LineDiff.ProposedRanges[1].Start)
        comparisonColors := UiThemeService.GetPalette()
        AuxiliaryVisualAssert(currentReviewX < proposedReviewX
                && currentReviewY == proposedReviewY
                && currentReviewWidth == proposedReviewWidth
                && currentReviewHeight == proposedReviewHeight
                && (currentReviewStyle & 0x0800)
                && (proposedReviewStyle & 0x0800)
                && comparisonVisualDialog.Interactions.TextInputTargets.Has(
                    comparisonVisualDialog.CurrentEdit.Hwnd)
                && comparisonVisualDialog.Interactions.TextInputTargets.Has(
                    comparisonVisualDialog.ProposedEdit.Hwnd)
                && reviewStats.CurrentLines == 3
                && reviewStats.ProposedLines == 4
                && reviewStats.ChangedLines == 3
                && comparisonVisualDialog.CurrentSyntaxTokenCount > 0
                && comparisonVisualDialog.ProposedSyntaxTokenCount > 0
                && comparisonVisualDialog.LineDiff.CurrentRanges.Length > 0
                && comparisonVisualDialog.LineDiff.ProposedRanges.Length > 0
                && (currentSyntaxFormat.Mask & 0x40000000)
                && currentSyntaxFormat.TextColor == ColorRef(
                    comparisonVisualDialog.ResolveSyntaxColor(
                        currentToken.Kind, comparisonColors))
                && (currentDifferenceFormat.Mask & 0x04000000)
                && currentDifferenceFormat.BackgroundColor
                    == ColorRef(comparisonColors.CodeDiffRemoved)
                && (proposedDifferenceFormat.Mask & 0x04000000)
                && proposedDifferenceFormat.BackgroundColor
                    == ColorRef(comparisonColors.CodeDiffAdded),
            "The AI optimization review is not a syntax- and diff-highlighted side-by-side comparison.")
        comparisonVisualDialog.Dispose(false)
        comparisonVisualDialog := ""

        settingsVisualDialog := SettingsWindow(ownerWindow, 3)
        settingsVisualDialog.Show()
        Sleep(30)
        AuxiliaryVisualAssert(settingsVisualDialog.ActiveTab == 3
                && !settingsVisualDialog.TabBuilt[1]
                && !settingsVisualDialog.TabBuilt[2]
                && !settingsVisualDialog.HasOwnProp("StartupTaskButton"),
            "Direct AI-settings navigation built another settings tab.")
        appearanceTabState := settingsVisualDialog.Interactions.Controls[
            settingsVisualDialog.TabButtons[1].Hwnd]
        startupTabState := settingsVisualDialog.Interactions.Controls[
            settingsVisualDialog.TabButtons[2].Hwnd]
        aiTabState := settingsVisualDialog.Interactions.Controls[
            settingsVisualDialog.TabButtons[3].Hwnd]
        rulesEventTabState := settingsVisualDialog.Interactions.Controls[
            settingsVisualDialog.TabButtons[4].Hwnd]
        AuxiliaryVisualAssert(appearanceTabState.HasOwnProp("ButtonImage")
                && InStr(appearanceTabState.ButtonImage.SourcePath,
                    "monitor.svg")
                && appearanceTabState.ButtonImage.TintColor
                    == settingsVisualDialog.GetTabIconColor(1)
                && startupTabState.HasOwnProp("ButtonImage")
                && InStr(startupTabState.ButtonImage.SourcePath,
                    "power.svg")
                && startupTabState.ButtonImage.TintColor
                    == settingsVisualDialog.GetTabIconColor(2)
                && aiTabState.HasOwnProp("ButtonImage")
                && aiTabState.ButtonImage.TintColor
                    == settingsVisualDialog.GetTabIconColor(3, true)
                && rulesEventTabState.HasOwnProp("ButtonImage")
                && InStr(rulesEventTabState.ButtonImage.SourcePath,
                    "file-output.svg")
                && rulesEventTabState.ButtonImage.TintColor
                    == settingsVisualDialog.GetTabIconColor(4),
            "The Appearance or AI tab icon lacks its semantic color.")
        AuxiliaryVisualAssert(settingsVisualDialog.TabButtons[1].Text
                == Tr("显示")
                && settingsVisualDialog.TabButtons[2].Text == Tr("启动"),
            "Appearance and Startup tabs are not in the requested order.")
        AuxiliaryVisualAssert(settingsVisualDialog.AIPromptsButton.Text
                == Tr("编辑")
                && !settingsVisualDialog.HasOwnProp("AISystemPromptButton")
                && !settingsVisualDialog.HasOwnProp("AIPromptInput")
                && !settingsVisualDialog.HasOwnProp("AIOptimizePromptInput"),
            "AI prompts were not merged into one compact Edit action.")
        AuxiliaryVisualAssert(
            !settingsVisualDialog.Interactions.Controls[
                settingsVisualDialog.AIPromptsButton.Hwnd]
                .HasOwnProp("ButtonImage"),
            "The AI prompt action still exposes an icon.")
        settingsVisualDialog.AIPromptsButton.GetPos(&promptsButtonX,
            &promptsButtonY, &promptsButtonWidth, &promptsButtonHeight)
        settingsVisualDialog.AIPromptsLabel.GetPos(&promptsLabelX,
            &promptsLabelY, &promptsLabelWidth, &promptsLabelHeight)
        settingsVisualDialog.AITimeoutInput.Background.GetPos(&timeoutInputX,
            , &timeoutInputWidth)
        settingsVisualDialog.AITestConnectionButton.GetPos(&testButtonX,
            &testButtonY, &testButtonWidth, &testButtonHeight)
        settingsVisualDialog.AIAddressInput.Background.GetPos(&addressInputX,
            , &addressInputWidth)
        settingsVisualDialog.AIKeyInput.Background.GetPos(&keyInputX, ,
            &keyInputWidth)
        keyEditStyle := DllCall("user32\GetWindowLongPtrW", "Ptr",
            settingsVisualDialog.AIKeyInput.Edit.Hwnd, "Int", -16, "Ptr")
        settingsVisualDialog.AIModelInput.Background.GetPos(&modelInputX, ,
            &modelInputWidth)
        settingsVisualDialog.AIParametersDivider.GetPos(, &dividerY, ,
            &dividerHeight)
        settingsVisualDialog.AIConnectionStatus.GetPos(, &connectionStatusY,
            &connectionStatusWidth, &connectionStatusHeight)
        settingsVisualDialog.AIConnectionStatus.GetPos(&connectionStatusX)
        connectionStatusStyle := DllCall("user32\GetWindowLongPtrW", "Ptr",
            settingsVisualDialog.AIConnectionStatus.Hwnd, "Int", -16, "Ptr")
        settingsClientWidth := settingsVisualDialog.GetActualClientWidth()
        settingsVisualDialog.Gui.GetClientPos(, , , &settingsClientHeight)
        settingsVisualDialog.ValidationStatus.GetPos(, &validationStatusY)
        settingsVisualDialog.SaveButton.GetPos(, &settingsSaveY)
        settingsVisualDialog.CancelButton.GetPos(, &settingsCancelY)
        aiFields := [
            {Label: settingsVisualDialog.AIAddressLabel,
                Control: settingsVisualDialog.AIAddressInput.Background},
            {Label: settingsVisualDialog.AIKeyLabel,
                Control: settingsVisualDialog.AIKeyInput.Background},
            {Label: settingsVisualDialog.AIModelLabel,
                Control: settingsVisualDialog.AIModelInput.Background},
            {Label: settingsVisualDialog.AITimeoutLabel,
                Control: settingsVisualDialog.AITimeoutInput.Background}
        ]
        AssertStackedMenuColumn(settingsVisualDialog, aiFields,
            settingsClientWidth, "AI settings")
        promptGroupWidth := promptsLabelWidth + 12 + promptsButtonWidth
        promptGroupX := Floor((settingsClientWidth - promptGroupWidth) / 2)
        AuxiliaryVisualAssert(promptsButtonWidth == 80
                && promptsLabelX == promptGroupX
                && promptsButtonX == promptsLabelX + promptsLabelWidth + 12
                && promptsButtonY + Floor(promptsButtonHeight / 2)
                    == promptsLabelY + Floor(promptsLabelHeight / 2)
                && !RegExMatch(settingsVisualDialog.AIPromptsLabel.Text,
                    "[:：]$")
                && settingsVisualDialog.AIPromptsLabel.Text
                    == RegExReplace(Tr("提示词："), "[:：]$")
                && timeoutInputX == addressInputX
                && timeoutInputWidth == 96
                && keyInputX == addressInputX
                && modelInputX == addressInputX
                && addressInputWidth == keyInputWidth
                && keyInputWidth == modelInputWidth
                && !(keyEditStyle & 0x20)
                && settingsVisualDialog.AIAddressLabel.Text
                    == RegExReplace(Tr("API 地址："), "[:：]$")
                && settingsVisualDialog.AIKeyLabel.Text
                    == RegExReplace(Tr("API 密钥："), "[:：]$")
                && settingsVisualDialog.AIModelLabel.Text
                    == RegExReplace(Tr("模型名称："), "[:：]$")
                && testButtonX == timeoutInputX + 108
                && testButtonY == 266
                && testButtonWidth == 96 && testButtonHeight == 30
                && settingsVisualDialog.AITestConnectionButton.Text
                    == Tr("测试连接")
                && connectionStatusX
                    == testButtonX + testButtonWidth
                        + SettingsWindow.AIConnectionStatusGap
                && connectionStatusX + connectionStatusWidth
                    == settingsClientWidth
                        - SettingsWindow.AIConnectionStatusRightMargin
                && connectionStatusY == testButtonY
                && connectionStatusHeight == 30
                && WinGetClass("ahk_id "
                    settingsVisualDialog.AIConnectionStatus.Hwnd) == "Edit"
                && !!(connectionStatusStyle & 0x0004)
                && !!(connectionStatusStyle & 0x0800)
                && !(connectionStatusStyle & 0x10000)
                && connectionStatusY + connectionStatusHeight < dividerY
                && dividerHeight == 1 && dividerY < promptsButtonY
                && promptsButtonY + promptsButtonHeight < validationStatusY
                && SettingsWindow.ClientHeight == 420
                && settingsClientHeight == SettingsWindow.ClientHeight
                && validationStatusY == 352
                && settingsSaveY == 376 && settingsCancelY == 376,
            "The AI settings stacked menu geometry is inconsistent.")
        settingsSaveState := settingsVisualDialog.Interactions.Controls[
            settingsVisualDialog.SaveButton.Hwnd]
        AuxiliaryVisualAssert(!settingsSaveState.HasOwnProp("ButtonImage")
                && settingsSaveState.Normal == "3F6B5B",
            "The iconless settings Save button does not use the save color.")
        for field in aiFields {
            AssertSelectableSettingsText(field.Label,
                "AI settings label")
            AssertRegisteredSelectableEdit(settingsVisualDialog.Interactions,
                field.Label, "AI settings label")
        }
        AssertSelectableSettingsText(settingsVisualDialog.AIPromptsLabel,
            "AI prompt label")
        AssertRegisteredSelectableEdit(settingsVisualDialog.Interactions,
            settingsVisualDialog.AIPromptsLabel, "AI prompt label")
        AuxiliaryVisualAssert(WinGetClass("ahk_id "
                settingsVisualDialog.TabButtons[3].Hwnd) != "Edit",
            "A settings tab was converted into selectable menu text.")
        settingsVisualDialog.AIAddressInput.Edit.Value := ""
        AuxiliaryVisualAssert(!settingsVisualDialog.TestAIConnection()
                && settingsVisualDialog.AIConnectionStatus.Text
                    == Tr("请填写 API 地址。"),
            "Connection testing did not validate the API address.")
        settingsVisualDialog.AIAddressInput.Edit.Value :=
            "https://example.test/v1"
        settingsVisualDialog.AIKeyInput.Edit.Value := "secret-key"
        settingsVisualDialog.AIModelInput.Edit.Value := "demo"
        for field in [settingsVisualDialog.AIAddressInput,
                settingsVisualDialog.AIKeyInput,
                settingsVisualDialog.AIModelInput,
                settingsVisualDialog.AITimeoutInput]
            AssertRegisteredSelectableEdit(settingsVisualDialog.Interactions,
                field.Edit, "AI parameter input")
        AssertRegisteredSelectableEdit(settingsVisualDialog.Interactions,
            settingsVisualDialog.AIConnectionStatus,
            "AI connection result")
        originalAIAddress := settingsVisualDialog.AIAddressInput.Edit.Value
        originalAIKey := settingsVisualDialog.AIKeyInput.Edit.Value
        originalAIModel := settingsVisualDialog.AIModelInput.Edit.Value
        originalAITimeout := settingsVisualDialog.AITimeoutInput.Edit.Value
        ownerWindow.App.FailAIConnectionSettingsSave := true
        AuxiliaryVisualAssert(!settingsVisualDialog.TestAIConnection()
                && ownerWindow.App.SaveAIConnectionSettingsCount == 1
                && ownerWindow.App.AIService.NextRequestId == 0
                && InStr(settingsVisualDialog.AIConnectionStatus.Text,
                    Tr("AI 参数未保存：")),
            "Connection testing continued after AI parameter persistence failed.")
        ownerWindow.App.FailAIConnectionSettingsSave := false
        AuxiliaryVisualAssert(settingsVisualDialog.TestAIConnection()
                && settingsVisualDialog.AIConnectionTestBusy
                && ownerWindow.App.SaveAIConnectionSettingsCount == 2
                && ownerWindow.App.Settings.AIAddress == originalAIAddress
                && ownerWindow.App.Settings.AIKey == originalAIKey
                && ownerWindow.App.Settings.AIModel == originalAIModel
                && String(ownerWindow.App.Settings.AITimeoutS)
                    == String(originalAITimeout)
                && settingsVisualDialog.AIConnectionStatus.Text
                    == Tr("正在测试 AI 连接…")
                && settingsVisualDialog.ResolveAIConnectionStatusColor(
                    "Muted") == UiThemeService.GetPalette().Muted
                && settingsVisualDialog.ResolveAIConnectionStatusColor(
                    "Muted") != "000000"
                && !settingsVisualDialog.HasOwnProp(
                    "AIConnectionStatusTimer")
                && !settingsVisualDialog.Interactions.Controls[
                    settingsVisualDialog.AITestConnectionButton.Hwnd]
                    .Interactive,
            "Connection testing did not enter its non-blocking busy state.")
        singleLineFormatRect := Buffer(16, 0)
        SendMessage(0x00B2, 0, singleLineFormatRect.Ptr, ,
            settingsVisualDialog.AIConnectionStatus.Hwnd)
        singleLineClientRect := Buffer(16, 0)
        DllCall("user32\GetClientRect", "Ptr",
            settingsVisualDialog.AIConnectionStatus.Hwnd,
            "Ptr", singleLineClientRect)
        singleLineTopPadding := NumGet(singleLineFormatRect, 4, "Int")
        singleLineBottomPadding := NumGet(singleLineClientRect, 12, "Int")
            - NumGet(singleLineFormatRect, 12, "Int")
        singleLineMeasuredHeight := settingsVisualDialog.Interactions.Painter
            .MeasureTextHeight(settingsVisualDialog.AIConnectionStatus,
                settingsVisualDialog.AIConnectionStatus.Text,
                connectionStatusWidth)
        singleLineTextWidth := settingsVisualDialog.MeasureControlTextWidth(
            settingsVisualDialog.AIConnectionStatus,
            settingsVisualDialog.AIConnectionStatus.Text)
        AuxiliaryVisualAssert(singleLineTopPadding > 0
                && Abs(singleLineTopPadding - singleLineBottomPadding) <= 1
                && singleLineMeasuredHeight + 4 <= 30,
            "The one-line AI connection status is not vertically centered: "
                . "top=" singleLineTopPadding ", bottom="
                . singleLineBottomPadding ", text="
                . singleLineMeasuredHeight ", width=" connectionStatusWidth
                . ", required=" singleLineTextWidth ".")
        ownerWindow.App.AIService.Complete(false,
            'AI 服务返回 HTTP 401：{"error":{"message":"Invalid API key"}}',
            "")
        settingsVisualDialog.AIConnectionStatus.GetPos(,
            &failedConnectionStatusY, , &failedConnectionStatusHeight)
        AuxiliaryVisualAssert(!settingsVisualDialog.AIConnectionTestBusy
                && settingsVisualDialog.AIConnectionStatus.Text == Tr(
                    "AI 连接测试失败：{1}",
                    "API 密钥：身份验证失败，密钥或访问令牌无效、已过期或未被接受（HTTP 401）。")
                && settingsVisualDialog.AIAddressInput.Edit.Value
                    == originalAIAddress
                && settingsVisualDialog.AIKeyInput.Edit.Value == originalAIKey
                && settingsVisualDialog.AIModelInput.Edit.Value
                    == originalAIModel
                && settingsVisualDialog.AITimeoutInput.Edit.Value
                    == originalAITimeout
                && ownerWindow.App.Settings.AIAddress == originalAIAddress
                && ownerWindow.App.Settings.AIKey == originalAIKey
                && ownerWindow.App.Settings.AIModel == originalAIModel
                && failedConnectionStatusY < testButtonY
                && failedConnectionStatusHeight > testButtonHeight
                && failedConnectionStatusY + failedConnectionStatusHeight
                    == 296,
            "Connection errors leaked raw details or did not wrap upward.")
        azureVisualFailure := settingsVisualDialog.FormatAIConnectionFailure(
            AIService.DescribeHttpFailure(404,
                '{"error":{"code":"DeploymentNotFound","message":"Resource not found"}}',
                {Provider: "azure", Protocol: "openai-chat",
                    TargetUrl: "https://example.openai.azure.com/openai/v1/chat/completions",
                    TargetInference: "explicit",
                    ConfiguredModel: "gpt-5-min", ModelLocation: "body"}))
        settingsVisualDialog.SetAIConnectionStatus(azureVisualFailure, "Error")
        settingsVisualDialog.AIConnectionStatus.GetPos(,
            &azureStatusY, &azureStatusWidth, &azureStatusHeight)
        azureLineCount := SendMessage(0x00BA, 0, 0, ,
            settingsVisualDialog.AIConnectionStatus.Hwnd)
        azureLineHeight := settingsVisualDialog.Interactions.Painter
            .MeasureTextHeight(settingsVisualDialog.AIConnectionStatus,
                "中Ag", Max(1, azureStatusWidth - 2))
        azureRequiredHeight := Max(30, azureLineCount * azureLineHeight + 4)
        azureMaximumHeight := SettingsWindow.AIConnectionStatusBottom
            - SettingsWindow.AIConnectionStatusTop
        AuxiliaryVisualAssert(azureRequiredHeight <= azureMaximumHeight
                && azureStatusHeight >= azureRequiredHeight
                && azureStatusY >= SettingsWindow.AIConnectionStatusTop
                && azureStatusY + azureStatusHeight
                    == SettingsWindow.AIConnectionStatusBottom,
            "The detailed provider error is clipped instead of growing upward: "
                . "lines=" azureLineCount ", lineHeight=" azureLineHeight
                . ", required=" azureRequiredHeight ", actual="
                . azureStatusHeight ".")
        AuxiliaryVisualAssert(settingsVisualDialog.TestAIConnection()
                && settingsVisualDialog.AIConnectionTestBusy,
            "Connection testing could not restart after a failed request.")
        ownerWindow.App.AIService.Complete(true, "",
            "https://example.test/v1/chat/completions")
        AuxiliaryVisualAssert(!settingsVisualDialog.AIConnectionTestBusy
                && settingsVisualDialog.AIAddressInput.Edit.Value
                    == originalAIAddress
                && settingsVisualDialog.AIKeyInput.Edit.Value == originalAIKey
                && settingsVisualDialog.AIModelInput.Edit.Value
                    == originalAIModel
                && settingsVisualDialog.AITimeoutInput.Edit.Value
                    == originalAITimeout
                && ownerWindow.App.SaveAIConnectionSettingsCount == 3
                && ownerWindow.App.Settings.AIAddress == originalAIAddress
                && ownerWindow.App.Settings.AIKey == originalAIKey
                && ownerWindow.App.Settings.AIModel == originalAIModel
                && settingsVisualDialog.AIConnectionStatus.Text
                    == Tr("AI 连接测试成功。")
                && settingsVisualDialog.Interactions.Controls[
                    settingsVisualDialog.AITestConnectionButton.Hwnd]
                    .Interactive,
            "Connection testing did not report success or retain its parameters.")
        reloadedAISettingsDialog := SettingsWindow(ownerWindow, 3)
        try AuxiliaryVisualAssert(
                reloadedAISettingsDialog.AIAddressInput.Edit.Value
                    == originalAIAddress
                && reloadedAISettingsDialog.AIKeyInput.Edit.Value
                    == originalAIKey
                && reloadedAISettingsDialog.AIModelInput.Edit.Value
                    == originalAIModel
                && reloadedAISettingsDialog.AITimeoutInput.Edit.Value
                    == originalAITimeout,
            "Saved AI connection parameters were not restored in a new window.")
        finally reloadedAISettingsDialog.Dispose()
        AuxiliaryVisualAssert(settingsVisualDialog.SetAIConnectionStatus(
                "persistent result", "Success"),
            "The persistent AI connection result could not be set.")
        Sleep(100)
        AuxiliaryVisualAssert(
                settingsVisualDialog.AIConnectionStatus.Text
                    == "persistent result"
                && !settingsVisualDialog.HasOwnProp(
                    "AIConnectionStatusTimer"),
            "The AI connection result still disappears automatically.")
        AuxiliaryVisualAssert(settingsVisualDialog.SwitchTab(1)
                && settingsVisualDialog.HasOwnProp("LanguageLabel")
                && !settingsVisualDialog.HasOwnProp("StartupTaskButton"),
            "The Appearance tab is not the first settings tab.")
        for label in [settingsVisualDialog.LanguageLabel,
                settingsVisualDialog.FontLabel,
                settingsVisualDialog.ThemeLabel]
            AssertSelectableSettingsText(label, "Display settings label")
        settingsVisualDialog.LanguageLabel.GetPos(&languageLabelX,
            &languageLabelY)
        settingsVisualDialog.FontLabel.GetPos(&fontLabelX, &fontLabelY)
        settingsVisualDialog.ThemeLabel.GetPos(&themeLabelX, &themeLabelY)
        settingsVisualDialog.LanguageIcon.GetPos(&languageIconX,
            &languageIconY)
        settingsVisualDialog.FontIcon.GetPos(&fontIconX, &fontIconY)
        settingsVisualDialog.ThemeIcon.GetPos(&themeIconX, &themeIconY)
        languageIconState := settingsVisualDialog.Interactions.Controls[
            settingsVisualDialog.LanguageIcon.Hwnd]
        fontIconState := settingsVisualDialog.Interactions.Controls[
            settingsVisualDialog.FontIcon.Hwnd]
        themeIconState := settingsVisualDialog.Interactions.Controls[
            settingsVisualDialog.ThemeIcon.Hwnd]
        AuxiliaryVisualAssert(languageLabelY
                == 68 + SettingsWindow.SparseMenuTopOffset
                && fontLabelY == 136 + SettingsWindow.SparseMenuTopOffset
                && themeLabelY == 204 + SettingsWindow.SparseMenuTopOffset,
            "The compact Appearance menu has incorrect vertical spacing.")
        AuxiliaryVisualAssert(languageIconX == languageLabelX - 28
                && fontIconX == fontLabelX - 28
                && themeIconX == themeLabelX - 28
                && languageIconY == languageLabelY
                && fontIconY == fontLabelY && themeIconY == themeLabelY,
            "The Appearance Lucide icons are misaligned with their labels.")
        AuxiliaryVisualAssert(languageIconState.Kind == "icon"
                && fontIconState.Kind == "icon"
                && themeIconState.Kind == "icon"
                && languageIconState.TextInsetDip == 0
                && fontIconState.TextInsetDip == 0
                && themeIconState.TextInsetDip == 0,
            "The Appearance icons are not zero-inset icon surfaces.")
        AuxiliaryVisualAssert(languageIconState.ButtonImage.TintColor
                    == UiThemeService.Color("LanguageIcon")
                && fontIconState.ButtonImage.TintColor
                    == UiThemeService.Color("FontIcon")
                && themeIconState.ButtonImage.TintColor
                    == UiThemeService.Color("ThemeIcon"),
            "The Appearance Lucide icons lack their semantic colors.")
        AuxiliaryVisualAssert(settingsVisualDialog.SwitchTab(2)
                && settingsVisualDialog.HasOwnProp("StartupTaskButton")
                && settingsVisualDialog.StartupTaskButtonReady
                && settingsVisualDialog.StartupTaskButton.Text == Tr("开启"),
            "The Startup tab was not built after Appearance.")
        for label in [settingsVisualDialog.ShortcutLabel,
                settingsVisualDialog.StartupTaskLabel,
                settingsVisualDialog.ShortcutFeedback]
            AssertSelectableSettingsText(label, "Startup settings label")
        settingsVisualDialog.ShortcutLabel.GetPos(, &shortcutLabelY)
        settingsVisualDialog.StartupTaskButton.GetPos(, &startupTaskY, ,
            &startupTaskHeight)
        settingsVisualDialog.RunAsAdministratorCheck.GetPos(
            &runAsAdministratorX, &runAsAdministratorY, ,
            &runAsAdministratorHeight)
        settingsVisualDialog.CheckUpdatesOnStartupCheck.GetPos(
            &checkUpdatesX, &checkUpdatesY, , &checkUpdatesHeight)
        settingsVisualDialog.ShowAtStartupCheck.GetPos(
            &showAtStartupX, &showAtStartupY)
        AuxiliaryVisualAssert(settingsVisualDialog
                    .RunAsAdministratorCheck.Value == 1
                && runAsAdministratorX == checkUpdatesX
                && checkUpdatesX == showAtStartupX
                && runAsAdministratorY - startupTaskY - startupTaskHeight
                    > checkUpdatesY - runAsAdministratorY
                        - runAsAdministratorHeight
                && checkUpdatesY >= runAsAdministratorY
                    + runAsAdministratorHeight
                && showAtStartupY >= checkUpdatesY + checkUpdatesHeight,
            "The administrator startup option is not first, selected, or aligned.")
        AuxiliaryVisualAssert(shortcutLabelY
                == 62 + SettingsWindow.SparseMenuTopOffset,
            "The sparse Startup menu lacks the shared top spacing.")
        Loop 4 {
            AuxiliaryVisualAssert(settingsVisualDialog.SwitchTab(A_Index),
                "Could not switch to settings tab " A_Index ".")
            ValidateAuxiliaryWindow(settingsVisualDialog.Gui,
                "settings tab " A_Index)
        }
        settingsVisualDialog.ImportRulePackageButton.GetPos(&importPackageX,
            &importPackageY, &importPackageWidth, &importPackageHeight)
        settingsVisualDialog.ExportRulePackageButton.GetPos(&exportPackageX,
            &exportPackageY, &exportPackageWidth)
        settingsVisualDialog.RuleEventDivider.GetPos(, &ruleDividerY)
        settingsVisualDialog.EventCapacityLabel.GetPos(, &eventLabelY)
        settingsVisualDialog.EventCapacityInput.Background.GetPos(,
            &eventInputY, , &eventInputHeight)
        settingsVisualDialog.EscapeCancelCheck.GetPos(, &escapeCancelY, ,
            &escapeCancelHeight)
        settingsVisualDialog.EventAutoScrollCheck.GetPos(, &eventAutoScrollY)
        AssertSelectableSettingsText(settingsVisualDialog.EventCapacityLabel,
            "Event settings label")
        AuxiliaryVisualAssert(importPackageX == exportPackageX
                && importPackageWidth == exportPackageWidth
                && importPackageY == 68
                && exportPackageY - importPackageY - importPackageHeight == 6
                && ruleDividerY - exportPackageY - importPackageHeight == 20
                && eventLabelY - ruleDividerY == 20
                && escapeCancelY - eventInputY - eventInputHeight == 6
                && eventAutoScrollY - escapeCancelY - escapeCancelHeight == 6,
            "The rule/event page top spacing or event gaps are inconsistent.")
        appearanceFields := [
            {Label: settingsVisualDialog.LanguageLabel,
                Control: settingsVisualDialog.LanguageDropDown},
            {Label: settingsVisualDialog.FontLabel,
                Control: settingsVisualDialog.FontDropDown},
            {Label: settingsVisualDialog.ThemeLabel,
                Control: settingsVisualDialog.ThemeDropDown}
        ]
        eventFields := [
            {Label: settingsVisualDialog.EventCapacityLabel,
                Control: settingsVisualDialog.EventCapacityInput.Background}
        ]
        AssertStackedMenuColumn(settingsVisualDialog, appearanceFields,
            settingsClientWidth, "Appearance settings",
            [settingsVisualDialog.LanguageIcon,
                settingsVisualDialog.FontIcon,
                settingsVisualDialog.ThemeIcon], 28)
        AssertStackedMenuColumn(settingsVisualDialog, eventFields,
            settingsClientWidth, "Event settings",
            [settingsVisualDialog.EscapeCancelCheck,
                settingsVisualDialog.EventAutoScrollCheck])
        ValidateSettingsFontDropDown(settingsVisualDialog)
        settingsVisualDialog.SwitchTab(3)
        promptsEditorDialog := AIPromptsEditor(settingsVisualDialog,
            AIService.DefaultGeneratePrompt, AIService.DefaultOptimizePrompt,
            AIService.DefaultSystemPrompt)
        AuxiliaryVisualAssert(promptsEditorDialog.GenerateEdit.Value
                == AIService.DefaultGeneratePrompt
                && promptsEditorDialog.OptimizeEdit.Value
                    == AIService.DefaultOptimizePrompt
                && promptsEditorDialog.SystemEdit.Value
                    == AIService.DefaultSystemPrompt
                && promptsEditorDialog.PromptTabButtons[1].Text == Tr("生成")
                && promptsEditorDialog.PromptTabButtons[2].Text == Tr("优化")
                && promptsEditorDialog.PromptTabButtons[3].Text
                    == Tr("系统说明")
                && promptsEditorDialog.ActivePromptTab == 1,
            "The combined AI prompt editor did not expose all three drafts.")
        promptsEditorDialog.GenerateEdit.GetPos(, &generatePromptY,
            &generatePromptWidth, &generatePromptHeight)
        promptsEditorDialog.OptimizeEdit.GetPos(, &optimizePromptY,
            &optimizePromptWidth, &optimizePromptHeight)
        promptsEditorDialog.SystemEdit.GetPos(, &systemPromptY,
            &systemPromptEditWidth, &systemPromptHeight)
        promptsEditorDialog.SaveButton.GetPos(, &promptSaveY,
            &promptsSaveWidth)
        promptsEditorDialog.CancelButton.GetPos(, , &promptsCancelWidth)
        promptsSaveState := promptsEditorDialog.Interactions.Controls[
            promptsEditorDialog.SaveButton.Hwnd]
        promptsCancelState := promptsEditorDialog.Interactions.Controls[
            promptsEditorDialog.CancelButton.Hwnd]
        AuxiliaryVisualAssert(AIPromptsEditor.WindowWidth == 620
                && AIPromptsEditor.WindowHeight == 440
                && generatePromptWidth
                == AIPromptsEditor.WindowWidth - 32
                && optimizePromptWidth == generatePromptWidth
                && systemPromptEditWidth == generatePromptWidth
                && optimizePromptY == generatePromptY
                && systemPromptY == generatePromptY
                && optimizePromptHeight == generatePromptHeight
                && systemPromptHeight == generatePromptHeight
                && generatePromptY + generatePromptHeight < promptSaveY
                && promptsSaveWidth == 80 && promptsCancelWidth == 80
                && !promptsSaveState.HasOwnProp("ButtonImage")
                && !promptsCancelState.HasOwnProp("ButtonImage")
                && promptsSaveState.Normal == "3F6B5B",
            "The compact AI prompt editor overlaps or has incorrect geometry.")
        AuxiliaryVisualAssert(AuxiliaryEditHasCollapsedSelection(
                promptsEditorDialog.GenerateEdit)
                && AuxiliaryEditHasCollapsedSelection(
                    promptsEditorDialog.OptimizeEdit)
                && AuxiliaryEditHasCollapsedSelection(
                    promptsEditorDialog.SystemEdit),
            "The AI prompt editor still selects all text on entry.")
        for editControl in [promptsEditorDialog.GenerateEdit,
                promptsEditorDialog.OptimizeEdit,
                promptsEditorDialog.SystemEdit]
            AssertRegisteredSelectableEdit(promptsEditorDialog.Interactions,
                editControl, "AI prompt editor")
        generateEditStyle := DllCall("user32\GetWindowLongPtrW", "Ptr",
            promptsEditorDialog.GenerateEdit.Hwnd, "Int", -16, "Ptr")
        optimizeEditStyle := DllCall("user32\GetWindowLongPtrW", "Ptr",
            promptsEditorDialog.OptimizeEdit.Hwnd, "Int", -16, "Ptr")
        systemEditStyle := DllCall("user32\GetWindowLongPtrW", "Ptr",
            promptsEditorDialog.SystemEdit.Hwnd, "Int", -16, "Ptr")
        systemEditExStyle := DllCall("user32\GetWindowLongPtrW", "Ptr",
            promptsEditorDialog.SystemEdit.Hwnd, "Int", -20, "Ptr")
        AuxiliaryVisualAssert(promptsEditorDialog.SwitchPromptTab(2)
                && promptsEditorDialog.OptimizeEdit.Visible
                && !promptsEditorDialog.GenerateEdit.Visible
                && !promptsEditorDialog.SystemEdit.Visible
                && promptsEditorDialog.SwitchPromptTab(3)
                && promptsEditorDialog.SystemEdit.Visible
                && !promptsEditorDialog.OptimizeEdit.Visible,
            "The combined AI prompt labels do not switch the shared editor.")
        for editStyle in [generateEditStyle, optimizeEditStyle,
                systemEditStyle]
            AuxiliaryVisualAssert(!!(editStyle & 0x00200000)
                    && !(editStyle & 0x00100000)
                    && !(editStyle & 0x0080),
                "An AI prompt editor does not wrap or has a horizontal scrollbar.")
        AuxiliaryVisualAssert(!(systemEditStyle & 0x00800000)
                && !(systemEditExStyle & 0x00000200)
                && !!(systemEditStyle & 0x00200000),
            "The AI system prompt editor geometry or vertical scrollbar is incorrect.")
        promptsEditorDialog.Dispose(false)
        promptsEditorDialog := ""
        AssertAuxiliaryWindowBackground(settingsVisualDialog.Gui, "settings")
        UiThemeService.Configure("light")
        settingsVisualDialog.ApplyAppearance()
        lightSettingsColors := UiThemeService.GetPalette()
        AuxiliaryVisualAssert(
                appearanceTabState.ButtonImage.TintColor
                    == lightSettingsColors.DisplayIcon
                && startupTabState.ButtonImage.TintColor
                    == lightSettingsColors.StartupIcon
                && aiTabState.ButtonImage.TintColor
                    == UiThemeService.Color("TabActiveText")
                && rulesEventTabState.ButtonImage.TintColor
                    == lightSettingsColors.RulesEventIcon
                && languageIconState.ButtonImage.TintColor
                    == lightSettingsColors.LanguageIcon
                && fontIconState.ButtonImage.TintColor
                    == lightSettingsColors.FontIcon
                && themeIconState.ButtonImage.TintColor
                    == lightSettingsColors.ThemeIcon,
            "The light settings theme retained dark-theme category icon colors.")
        AssertAuxiliaryWindowBackground(settingsVisualDialog.Gui,
            "light settings")
        UiThemeService.Configure("dark")
        settingsVisualDialog.ApplyAppearance()
        darkSettingsColors := UiThemeService.GetPalette()
        AuxiliaryVisualAssert(aiTabState.ButtonImage.TintColor
                == darkSettingsColors.AI,
            "The active dark settings-tab icon was flattened to white.")
        AssertAuxiliaryWindowBackground(settingsVisualDialog.Gui,
            "restored settings")
        settingsVisualDialog.Dispose(false)
        settingsVisualDialog := ""

        aboutVisualDialog := AboutWindow(ownerWindow)
        aboutVisualDialog.Show()
        Sleep(30)
        ValidateAuxiliaryWindow(aboutVisualDialog.Gui, "about")
        ValidateMinimizableChildTaskbarRestore(aboutVisualDialog.Gui,
            ownerWindow, "about")
        AssertAuxiliaryWindowBackground(aboutVisualDialog.Gui, "about")
        AuxiliaryVisualAssert(aboutVisualDialog.Gui.Title == Tr("关于"),
            "The About window title is incorrect.")
        updateState := aboutVisualDialog.Interactions.Controls[
            aboutVisualDialog.UpdateButton.Hwnd]
        donationState := aboutVisualDialog.Interactions.Controls[
            aboutVisualDialog.DonationButton.Hwnd]
        projectState := aboutVisualDialog.Interactions.Controls[
            aboutVisualDialog.ProjectButton.Hwnd]
        AuxiliaryVisualAssert(updateState.Normal == UiThemeService.Color("Toolbar")
                && updateState.TextColor
                    == UiThemeService.Color("ToolbarText"),
            "The update action still uses an emphasized button style.")
        AuxiliaryVisualAssert(donationState.TooltipText
                == Tr("快揭不开锅了（≥Д≤）")
                && projectState.TooltipText == Tr("点个 star 吧~"),
            "The About actions do not expose the requested tooltips.")
        aboutVisualDialog.UpdateButton.GetPos(&updateX, , &updateWidth)
        aboutVisualDialog.DonationButton.GetPos(&donationX, , &donationWidth)
        aboutVisualDialog.ProjectButton.GetPos(&projectX)
        AuxiliaryVisualAssert(updateX + updateWidth < donationX
                && donationX + donationWidth < projectX,
            "The About actions are not ordered as update, donation, project.")
        UiThemeService.Configure("light")
        aboutVisualDialog.ApplyAppearance()
        lightAboutColors := UiThemeService.GetPalette()
        AuxiliaryVisualAssert(
                updateState.ButtonImage.TintColor == lightAboutColors.Primary
                && donationState.ButtonImage.TintColor
                    == lightAboutColors.Danger
                && projectState.ButtonImage.TintColor
                    == lightAboutColors.RulesEventIcon,
            "The light About window retained low-contrast SVG icon colors.")
        AssertAuxiliaryWindowBackground(aboutVisualDialog.Gui, "light about")
        UiThemeService.Configure("dark")
        aboutVisualDialog.ApplyAppearance()
        AuxiliaryVisualAssert(donationState.ButtonImage.TintMode == "none"
                && projectState.ButtonImage.TintMode == "none",
            "Dark About actions were flattened to white icons.")
        aboutVisualDialog.Dispose(false)
        aboutVisualDialog := ""

        donationVisualDialog := DonationWindow(ownerWindow)
        donationVisualDialog.Show()
        Sleep(30)
        ValidateAuxiliaryWindow(donationVisualDialog.Gui, "donation")
        donationVisualDialog.MessageText.GetPos(, &donationMessageY, ,
            &donationMessageHeight)
        donationVisualDialog.QrLabels[1].GetPos(, &donationLabelY)
        AuxiliaryVisualAssert(InStr(donationVisualDialog.MessageText.Text,
                    "请选择扶贫方式（≥Д≤）")
                && !donationVisualDialog.HasOwnProp("Divider")
                && donationLabelY - donationMessageY
                    - donationMessageHeight == 10,
            "The donation window retained its divider or nearby whitespace.")
        darkQrPath := donationVisualDialog.QrPictureSpecs[1].CurrentPath
        AuxiliaryVisualAssert(InStr(darkQrPath, "-界面.png")
                && !InStr(darkQrPath, "-浅色界面.png"),
            "The dark donation window did not use its dark QR asset.")
        UiThemeService.Configure("light")
        donationVisualDialog.ApplyAppearance()
        lightQrPath := donationVisualDialog.QrPictureSpecs[1].CurrentPath
        AuxiliaryVisualAssert(InStr(lightQrPath, "-浅色界面.png")
                && lightQrPath != darkQrPath,
            "The light donation window did not switch to its light QR asset.")
        AssertAuxiliaryWindowBackground(donationVisualDialog.Gui,
            "light donation")
        UiThemeService.Configure("dark")
        donationVisualDialog.ApplyAppearance()
        donationVisualDialog.Dispose(false)
        donationVisualDialog := ""

        supportVisualDialog := SupportInfoWindow(ownerWindow)
        supportVisualDialog.Show()
        Sleep(30)
        ValidateAuxiliaryWindow(supportVisualDialog.Gui, "support")
        ValidateMinimizableChildTaskbarRestore(supportVisualDialog.Gui,
            ownerWindow, "support")
        feedbackState := supportVisualDialog.Interactions.Controls[
            supportVisualDialog.FeedbackButton.Hwnd]
        AuxiliaryVisualAssert(supportVisualDialog.Gui.Title == Tr("帮助")
                && feedbackState.TooltipText == Tr("找作者对线"),
            "The Help window label or feedback tooltip is incorrect.")
        guideState := supportVisualDialog.Interactions.Controls[
            supportVisualDialog.GuideButton.Hwnd]
        eventButtonState := supportVisualDialog.Interactions.Controls[
            supportVisualDialog.EventButton.Hwnd]
        UiThemeService.Configure("light")
        supportVisualDialog.ApplyAppearance()
        lightSupportColors := UiThemeService.GetPalette()
        AuxiliaryVisualAssert(
                guideState.ButtonImage.TintColor
                    == lightSupportColors.DisplayIcon
                && eventButtonState.ButtonImage.TintColor
                    == lightSupportColors.CodeType
                && feedbackState.ButtonImage.TintColor
                    == lightSupportColors.RulesEventIcon,
            "The light Help window retained low-contrast SVG icon colors.")
        UiThemeService.Configure("dark")
        supportVisualDialog.ApplyAppearance()
        AuxiliaryVisualAssert(guideState.ButtonImage.TintMode == "none"
                && eventButtonState.ButtonImage.TintMode == "none"
                && feedbackState.ButtonImage.TintMode == "none",
            "Dark Help actions were flattened to white icons.")
        supportVisualDialog.Dispose(false)
        supportVisualDialog := ""

        eventVisualDialog := EventViewerWindow(ownerWindow)
        eventVisualDialog.Show()
        Sleep(30)
        ValidateAuxiliaryWindow(eventVisualDialog.Gui, "event viewer")
        AssertAuxiliaryWindowBackground(eventVisualDialog.Gui, "event viewer")
        AuxiliaryVisualAssert(eventVisualDialog.Gui.Title == "事件查看",
            "The event window still uses the old title.")
        AssertControlPrecedes(eventVisualDialog.List, eventVisualDialog.DetailLabel,
            "The event list overlaps the detail section.")
        AssertControlPrecedes(eventVisualDialog.DetailEdit, eventVisualDialog.Status,
            "The event detail editor overlaps the status line.")
        ValidateEventViewerRowState(eventVisualDialog)
        AssertRegisteredSelectableEdit(eventVisualDialog.Interactions,
            eventVisualDialog.DetailEdit, "event detail")
        ValidateEventViewerWindowHierarchy(eventVisualDialog, ownerWindow)
        pauseEventState := eventVisualDialog.Interactions.Controls[
            eventVisualDialog.PauseButton.Hwnd]
        clearEventState := eventVisualDialog.Interactions.Controls[
            eventVisualDialog.ClearButton.Hwnd]
        exportEventState := eventVisualDialog.Interactions.Controls[
            eventVisualDialog.ExportButton.Hwnd]
        rawEventState := eventVisualDialog.Interactions.Controls[
            eventVisualDialog.RawObservationButton.Hwnd]
        UiThemeService.Configure("light")
        eventVisualDialog.ApplyAppearance()
        lightEventColors := UiThemeService.GetPalette()
        AuxiliaryVisualAssert(
                pauseEventState.ButtonImage.TintColor
                    == lightEventColors.ButtonText
                && clearEventState.ButtonImage.TintColor
                    == lightEventColors.Danger
                && exportEventState.ButtonImage.TintColor
                    == lightEventColors.ButtonText
                && rawEventState.ButtonImage.TintColor
                    == lightEventColors.DisplayIcon,
            "The light Event window retained low-contrast SVG icon colors.")
        UiThemeService.Configure("dark")
        eventVisualDialog.ApplyAppearance()
        AuxiliaryVisualAssert(pauseEventState.ButtonImage.TintMode == "none"
                && clearEventState.ButtonImage.TintMode == "none"
                && exportEventState.ButtonImage.TintMode == "none"
                && rawEventState.ButtonImage.TintMode == "none",
            "Dark Event actions were flattened to white icons.")
        eventVisualDialog.Dispose(false)
        eventVisualDialog := ""

        packageVisualDialog := RulePackageImportWindow(ownerWindow,
            "visual-package.json", Map("visual", true))
        packageVisualDialog.Show()
        Sleep(30)
        packageVisualDialog.CancelButton.GetPos(, , &packageCancelWidth)
        packageCancelState := packageVisualDialog.Interactions.Controls[
            packageVisualDialog.CancelButton.Hwnd]
        packageSelectAllState := packageVisualDialog.Interactions.Controls[
            packageVisualDialog.SelectAllButton.Hwnd]
        packageClearState := packageVisualDialog.Interactions.Controls[
            packageVisualDialog.ClearButton.Hwnd]
        AuxiliaryVisualAssert(packageCancelWidth == 80
                && !packageCancelState.HasOwnProp("ButtonImage"),
            "The package Cancel command is not a compact text button.")
        ValidateAuxiliaryWindow(packageVisualDialog.Gui, "package preview")
        AssertAuxiliaryWindowBackground(packageVisualDialog.Gui, "package preview")
        AssertControlPrecedes(packageVisualDialog.List, packageVisualDialog.ImportButton,
            "The package list overlaps its command row.")
        AssertControlPrecedes(packageVisualDialog.ImportButton, packageVisualDialog.Status,
            "The package commands overlap the status text.")
        UiThemeService.Configure("light")
        packageVisualDialog.ApplyAppearance()
        AuxiliaryVisualAssert(
                packageSelectAllState.ButtonImage.TintColor
                    == UiThemeService.Color("StatusEnabledIcon")
                && packageClearState.ButtonImage.TintColor
                    == UiThemeService.Color("Danger"),
            "The light package preview retained low-contrast SVG icon colors.")
        AssertAuxiliaryWindowBackground(packageVisualDialog.Gui,
            "light package preview")
        UiThemeService.Configure("dark")
        packageVisualDialog.ApplyAppearance()
        AuxiliaryVisualAssert(
                packageSelectAllState.ButtonImage.TintMode == "none"
                && packageClearState.ButtonImage.TintMode == "none",
            "Dark package actions were flattened to white icons.")
        AssertAuxiliaryWindowBackground(packageVisualDialog.Gui,
            "restored package preview")
        packageVisualDialog.Dispose(false)
        packageVisualDialog := ""

        helpVisualDialog := HelpWindow(ownerWindow)
        helpVisualDialog.Show()
        Sleep(30)
        ValidateAuxiliaryWindow(helpVisualDialog.Gui, "help")
        AssertAuxiliaryWindowBackground(helpVisualDialog.Gui, "help")
        AuxiliaryVisualAssert(InStr(helpVisualDialog.TextEdit.Value,
                "Ctrl+Shift+Z") > 0,
            "The help window omits the redo shortcut documentation.")
        AssertRegisteredSelectableEdit(helpVisualDialog.Interactions,
            helpVisualDialog.TextEdit, "help text")
        helpVisualDialog.Dispose(false)
        helpVisualDialog := ""

        ReportAuxiliaryVisualResult("PASS auxiliary window visuals`n")
    } catch as testError {
        ReportAuxiliaryVisualResult(testError.Message "`n"
            testError.Stack "`n", true)
        exitCode := 1
    } finally {
        for candidate in [helpVisualDialog, packageVisualDialog,
            eventVisualDialog, supportVisualDialog, donationVisualDialog,
                aboutVisualDialog,
                promptEditorDialog, settingsVisualDialog,
                promptsEditorDialog,
                comparisonVisualDialog, textInputVisualDialog,
                confirmVisualDialog] {
            if IsObject(candidate)
                try candidate.Dispose(false)
        }
        if IsObject(ownerWindow)
            try ownerWindow.Dispose()
    }
    return exitCode
}

ReportAuxiliaryVisualResult(message, isError := false) {
    try {
        FileAppend(message, isError ? "**" : "*")
        return true
    } catch {
        return false
    }
}

ValidateUiFontPriority() {
    latinSpec := {Primary: "SF Pro Text", Fallback: "Noto Sans",
        System: "Segoe UI"}
    expectedSpecs := Map(
        "zh-CN", {Primary: "PingFang SC", Fallback: "Noto Sans CJK SC",
            System: "Microsoft YaHei UI"},
        "zh-HK", {Primary: "PingFang HK", Fallback: "Noto Sans CJK HK",
            System: "Microsoft JhengHei UI"},
        "zh-TW", {Primary: "PingFang TC", Fallback: "Noto Sans CJK TC",
            System: "Microsoft JhengHei UI"},
        "ja-JP", {Primary: "Harano Aji Gothic",
            Fallback: "Noto Sans CJK JP",
            System: "Yu Gothic UI"},
        "ko-KR", {Primary: "AppleSDGothicNeoR00",
            Fallback: "Noto Sans CJK KR",
            System: "Malgun Gothic"},
        "en-US", latinSpec, "vi-VN", latinSpec, "es-ES", latinSpec,
        "fr-FR", latinSpec, "pt-BR", latinSpec, "ru-RU", latinSpec,
        "de-DE", latinSpec, "it-IT", latinSpec)
    for language, expected in expectedSpecs {
        actual := LocalizationService.GetLanguageUiFontSpec(language)
        AuxiliaryVisualAssert(actual.Primary == expected.Primary
                && actual.Fallback == expected.Fallback
                && actual.System == expected.System,
            language " font priority differs from the reference project.")
        LocalizationService.InstalledUiFonts := [expected.System,
            expected.Fallback, expected.Primary]
        AuxiliaryVisualAssert(LocalizationService.ResolveUiFontSpec(actual)
                == expected.Primary,
            language " did not prefer the reference primary font.")
        LocalizationService.InstalledUiFonts := [expected.System,
            expected.Fallback]
        AuxiliaryVisualAssert(LocalizationService.ResolveUiFontSpec(actual)
                == expected.Fallback,
            language " did not use the Noto fallback before the system font.")
    }
    LocalizationService.InstalledUiFonts := ""
    installedFonts := LocalizationService.GetInstalledUiFontNames()
    AuxiliaryVisualAssert(installedFonts.Length > 0,
        "No installed font was available for font-selection tests.")
    explicitFont := installedFonts[1]
    ValidateUiFontPersistence(explicitFont)
    LocalizationService.Configure("en-US", explicitFont)
    LocalizationService.Configure("ja-JP")
    AuxiliaryVisualAssert(LocalizationService.GetUiFontName() == explicitFont,
        "A language change overrode the explicitly selected content font.")
    LocalizationService.ConfigureUiFont("auto")
    LocalizationService.Configure("ko-KR")
    AuxiliaryVisualAssert(LocalizationService.GetUiFontName()
            == LocalizationService.GetLanguageDefaultUiFontName("ko-KR"),
        "The automatic content font did not follow the new language.")
    AuxiliaryVisualAssert(LocalizationService.NormalizeRequestedUiFont(
            "__Missing_Font__", "auto") == "auto",
        "A missing explicit font did not fall back to automatic selection.")
    LocalizationService.Configure("zh-CN", "auto")
}

ValidateUiFontPersistence(explicitFont) {
    settingsPath := A_Temp "\kmra-font-settings-" A_TickCount "-"
        . Format("{:08X}", Random(0, 0xFFFFFFFF)) ".ini"
    try {
        service := AppSettingsService(settingsPath)
        settings := service.Load()
        AuxiliaryVisualAssert(settings.RunAsAdministrator,
            "Administrator startup did not default to enabled.")
        settings.UiFont := explicitFont
        settings.RunAsAdministrator := false
        settings.AIPrompt := "generate line 1`r`ngenerate=line 2\\literal"
        settings.AIOptimizePrompt := "optimize line 1`noptimize=line 2\\literal"
        settings.AISystemPrompt := "line 1`nline 2\\literal"
        settings.AIAddress := "https://example.test/v1"
        settings.AIKey := "secret-key"
        settings.AIModel := "demo-model"
        settings.AITimeoutS := 37
        saved := service.Save(settings)
        reloaded := AppSettingsService(settingsPath).Load()
        AuxiliaryVisualAssert(saved.UiFont == explicitFont
                && reloaded.UiFont == explicitFont
                && !saved.RunAsAdministrator
                && !reloaded.RunAsAdministrator
                && InStr(service.GetSnapshot(),
                    "RunAsAdministrator=0"),
            "The selected content font did not survive a settings reload.")
        AuxiliaryVisualAssert(reloaded.AISystemPrompt
                == "line 1`nline 2\\literal",
            "The multiline AI system prompt did not survive a settings reload.")
        AuxiliaryVisualAssert(reloaded.AIPrompt
                == "generate line 1`r`ngenerate=line 2\\literal"
                && reloaded.AIOptimizePrompt
                    == "optimize line 1`noptimize=line 2\\literal"
                && InStr(service.GetSnapshot(), "PromptEscaped=")
                && InStr(service.GetSnapshot(), "OptimizePromptEscaped="),
            "Multiline generate/optimize prompts did not survive a settings reload.")
        AuxiliaryVisualAssert(reloaded.AIAddress
                == "https://example.test/v1"
                && reloaded.AIKey == "secret-key"
                && reloaded.AIModel == "demo-model"
                && reloaded.AITimeoutS == 37,
            "AI connection parameters did not survive a settings reload.")
        service.WriteSnapshot("[AI]`r`n"
            . "Prompt=legacy=generate\\literal`r`n"
            . "OptimizePrompt=legacy=optimize\\literal`r`n")
        legacyReloaded := AppSettingsService(settingsPath).Load()
        AuxiliaryVisualAssert(legacyReloaded.AIPrompt
                == "legacy=generate\\literal"
                && legacyReloaded.AIOptimizePrompt
                    == "legacy=optimize\\literal",
            "Legacy single-line AI prompts no longer migrate on load.")
    } finally {
        if FileExist(settingsPath)
            FileDelete(settingsPath)
    }
}

AssertStackedMenuColumn(settingsWindow, fields, clientWidth, context,
        extraControls := "", labelInset := 0) {
    menuWidth := 1
    for field in fields {
        menuWidth := Max(menuWidth,
            settingsWindow.MeasureControlTextWidth(field.Label,
                field.Label.Text) + labelInset + 2)
        field.Control.GetPos(, , &controlWidth)
        menuWidth := Max(menuWidth, controlWidth)
    }
    if IsObject(extraControls) {
        for control in extraControls {
            control.GetPos(, , &controlWidth)
            menuWidth := Max(menuWidth, controlWidth)
        }
    }
    menuWidth := Min(menuWidth,
        clientWidth - settingsWindow.Layout.ContentX * 2)
    expectedX := Max(settingsWindow.Layout.ContentX,
        Floor((clientWidth - menuWidth) / 2))
    for field in fields {
        field.Label.GetPos(&labelX, &labelY)
        field.Control.GetPos(&controlX, &controlY)
        labelStyle := DllCall("user32\GetWindowLongPtrW",
            "Ptr", field.Label.Hwnd, "Int", -16, "Ptr")
        AuxiliaryVisualAssert(labelX == expectedX + labelInset
                && controlX == expectedX && controlY > labelY
                && (labelStyle & 0x3) == 0
                && !RegExMatch(field.Label.Text, "[:：]$"),
            context " is not a centered, left-aligned stacked menu.")
    }
    if IsObject(extraControls) {
        for control in extraControls {
            control.GetPos(&controlX)
            AuxiliaryVisualAssert(controlX == expectedX,
                context " has a misaligned auxiliary control.")
        }
    }
}

AssertSelectableSettingsText(control, context) {
    style := DllCall("user32\GetWindowLongPtrW", "Ptr", control.Hwnd,
        "Int", -16, "Ptr")
    AuxiliaryVisualAssert(WinGetClass("ahk_id " control.Hwnd) == "Edit"
            && (style & 0x0800) != 0
            && (style & 0x10000) == 0,
        context " is not selectable read-only text outside tab navigation.")
    arrowCursor := DllCall("user32\LoadCursor", "Ptr", 0,
        "Ptr", Win32.IDC_ARROW, "Ptr")
    cursorResult := SendMessage(Win32.WM_SETCURSOR, control.Hwnd,
        Win32.HTCLIENT, , control.Hwnd)
    AuxiliaryVisualAssert(cursorResult == 1
            && DllCall("user32\GetCursor", "Ptr") == arrowCursor,
        context " does not retain the normal arrow cursor.")
}

AssertRegisteredSelectableEdit(interactions, control, context) {
    hwnd := control.Hwnd
    className := WinGetClass("ahk_id " hwnd)
    AuxiliaryVisualAssert(RegExMatch(className, "i)(?:^Edit$|RichEdit)")
            && interactions.TextInputTargets.Has(hwnd)
            && interactions.TextInputTargets[hwnd] == hwnd,
        context " is not registered as a selectable text box.")
    oldStart := Buffer(4, 0)
    oldEnd := Buffer(4, 0)
    newStart := Buffer(4, 0)
    newEnd := Buffer(4, 0)
    SendMessage(Win32.EM_GETSEL, oldStart.Ptr, oldEnd.Ptr, , hwnd)
    textLength := SendMessage(0x000E, 0, 0, , hwnd) ; WM_GETTEXTLENGTH
    try {
        SendMessage(Win32.EM_SETSEL, 0, -1, , hwnd)
        SendMessage(Win32.EM_GETSEL, newStart.Ptr, newEnd.Ptr, , hwnd)
        AuxiliaryVisualAssert(NumGet(newStart, 0, "UInt") == 0
                && NumGet(newEnd, 0, "UInt") == textLength,
            context " does not permit a native text selection.")
        if textLength > 1 && DllCall("user32\IsWindowVisible", "Ptr", hwnd,
                "Int") {
            rootHwnd := DllCall("user32\GetAncestor", "Ptr", hwnd,
                "UInt", 2, "Ptr") ; GA_ROOT
            if rootHwnd {
                DllCall("user32\SetActiveWindow", "Ptr", rootHwnd, "Ptr")
                DllCall("user32\BringWindowToTop", "Ptr", rootHwnd, "Int")
                Sleep(10)
            }
            windowRect := Buffer(16, 0)
            DllCall("user32\GetWindowRect", "Ptr", hwnd,
                "Ptr", windowRect, "Int")
            screenX := Floor((NumGet(windowRect, 0, "Int")
                + NumGet(windowRect, 8, "Int")) / 2)
            screenY := Floor((NumGet(windowRect, 4, "Int")
                + NumGet(windowRect, 12, "Int")) / 2)
            rootPoint := Buffer(8, 0)
            NumPut("Int", screenX, "Int", screenY, rootPoint)
            DllCall("user32\ScreenToClient", "Ptr", rootHwnd,
                "Ptr", rootPoint, "Int")
            rootX := NumGet(rootPoint, 0, "Int")
            rootY := NumGet(rootPoint, 4, "Int")
            hitHwnd := DllCall("user32\ChildWindowFromPointEx",
                "Ptr", rootHwnd, "Int64",
                (rootX & 0xFFFFFFFF) | (rootY << 32), "UInt", 0, "Ptr")
            try hitClass := WinGetClass("ahk_id " hitHwnd)
            catch
                hitClass := ""
            try hitText := WinGetText("ahk_id " hitHwnd)
            catch
                hitText := ""
            AuxiliaryVisualAssert(hitHwnd == hwnd,
                context " is covered by another control: hwnd=" hitHwnd
                    ", class=" hitClass ", text=" hitText ".")
            clientRect := Buffer(16, 0)
            DllCall("user32\GetClientRect", "Ptr", hwnd,
                "Ptr", clientRect, "Int")
            width := NumGet(clientRect, 8, "Int")
            height := NumGet(clientRect, 12, "Int")
            startX := Min(Max(4, Floor(width / 8)), width - 4)
            endX := Max(startX + 8, width - 6)
            pointerY := Max(2, Floor(height / 2))
            selectionSucceeded := false
            Loop 3 {
                if rootHwnd {
                    DllCall("user32\SetActiveWindow", "Ptr", rootHwnd,
                        "Ptr")
                    DllCall("user32\BringWindowToTop", "Ptr", rootHwnd,
                        "Int")
                }
                DllCall("user32\SetFocus", "Ptr", hwnd, "Ptr")
                Sleep(10)
                SendMessage(Win32.EM_SETSEL, 0, 0, , hwnd)
                SendMessage(Win32.WM_LBUTTONDOWN, 1,
                    startX | (pointerY << 16), , hwnd)
                Sleep(5)
                SendMessage(Win32.WM_MOUSEMOVE, 1,
                    endX | (pointerY << 16), , hwnd)
                Sleep(5)
                SendMessage(Win32.WM_LBUTTONUP, 0,
                    endX | (pointerY << 16), , hwnd)
                Sleep(30)
                SendMessage(Win32.EM_GETSEL, newStart.Ptr, newEnd.Ptr, , hwnd)
                selectionSucceeded := DllCall("user32\GetFocus", "Ptr")
                        == hwnd
                    && NumGet(newEnd, 0, "UInt")
                        > NumGet(newStart, 0, "UInt")
                if selectionSucceeded
                    break
            }
            AuxiliaryVisualAssert(selectionSucceeded,
                context " does not retain focus and mouse drag selection.")
        }
    } finally SendMessage(Win32.EM_SETSEL,
        NumGet(oldStart, 0, "UInt"), NumGet(oldEnd, 0, "UInt"), , hwnd)
}

ValidateSettingsFontDropDown(settingsWindow) {
    AuxiliaryVisualAssert(settingsWindow.FontValues.Length > 6,
        "The settings font drop-down did not enumerate installed fonts.")
    settingsWindow.FontDropDown.Value := Min(3,
        settingsWindow.FontValues.Length)
    selectedFontBeforeRefresh := settingsWindow.FontValues[
        settingsWindow.FontDropDown.Value]
    expectedTopIndex := Min(5, settingsWindow.FontValues.Length - 1)
    SendMessage(Win32.CB_SETTOPINDEX, expectedTopIndex, 0,
        settingsWindow.FontDropDown.Hwnd)
    fontControlId := DllCall("user32\GetDlgCtrlID", "Ptr",
        settingsWindow.FontDropDown.Hwnd, "Int")
    DllCall("user32\SendMessageW", "Ptr", settingsWindow.Gui.Hwnd,
        "UInt", Win32.WM_COMMAND, "Ptr", fontControlId
            | (Win32.CBN_CLOSEUP << 16),
        "Ptr", settingsWindow.FontDropDown.Hwnd, "Ptr")
    AuxiliaryVisualAssert(settingsWindow.FontDropDownTopIndex
            == expectedTopIndex,
        "The settings font drop-down did not capture its scroll position.")

    LocalizationService.InstalledUiFonts := ["__Stale_Font_Cache__"]
    DllCall("user32\SendMessageW", "Ptr", settingsWindow.Gui.Hwnd,
        "UInt", Win32.WM_COMMAND, "Ptr", fontControlId
            | (Win32.CBN_DROPDOWN << 16),
        "Ptr", settingsWindow.FontDropDown.Hwnd, "Ptr")
    staleFontPresent := false
    for fontValue in settingsWindow.FontValues {
        if fontValue == "__Stale_Font_Cache__" {
            staleFontPresent := true
            break
        }
    }
    AuxiliaryVisualAssert(!staleFontPresent
            && settingsWindow.FontValues[
                settingsWindow.FontDropDown.Value] == selectedFontBeforeRefresh
            && SendMessage(Win32.CB_GETTOPINDEX, 0, 0,
                settingsWindow.FontDropDown.Hwnd) == expectedTopIndex,
        "The settings font drop-down did not refresh while preserving state.")
}

ValidateEventViewerWindowHierarchy(viewer, ownerWindow) {
    AuxiliaryVisualAssert(WindowHierarchy.IsOwnerLocked(ownerWindow.Gui),
        "The event window did not register its owner relationship.")
    AuxiliaryVisualAssert(!DllCall("user32\IsWindowEnabled",
        "Ptr", ownerWindow.Gui.Hwnd, "Int"),
        "The owner remained enabled while the event window was open.")

    ValidateMinimizableChildTaskbarRestore(viewer.Gui, ownerWindow,
        "event viewer")
    AuxiliaryVisualAssert(WindowHierarchy.IsOwnerLocked(ownerWindow.Gui),
        "Restoring the event window did not rebuild its owner relationship.")
    AuxiliaryVisualAssert(!DllCall("user32\IsWindowEnabled",
        "Ptr", ownerWindow.Gui.Hwnd, "Int"),
        "Restoring the event window did not reapply the owner lock.")
}

ValidateMinimizableChildTaskbarRestore(childGui, ownerWindow, label) {
    childHwnd := childGui.Hwnd
    ownerHwnd := ownerWindow.Gui.Hwnd
    style := DllCall("user32\GetWindowLongPtrW", "Ptr", childHwnd,
        "Int", Win32.GWL_STYLE, "Ptr")
    originalExtendedStyle := DllCall("user32\GetWindowLongPtrW",
        "Ptr", childHwnd, "Int", Win32.GWL_EXSTYLE, "Ptr")
    AuxiliaryVisualAssert(style & Win32.WS_MINIMIZEBOX,
        "The " label " child window does not expose a minimize button.")
    AuxiliaryVisualAssert(WindowHierarchy.FindOwnerHwnd(childHwnd)
            == ownerHwnd,
        "The " label " child window is not tracked by its owner.")
    ; Offscreen CI desktops do not provide a real taskbar restore contract.
    ; The platform-neutral restore sequence is covered by the core hierarchy
    ; test; exercise the native Explorer interaction only on a visible desktop.
    if EnvGet("KEY_MOUSE_REMAPPER_GUI_TEST_OFFSCREEN") == "1"
        return true

    AuxiliaryVisualAssert(WindowHierarchy.MinimizeChildIndependently(
            childHwnd),
        "The hierarchy manager rejected the " label " minimization.")
    Sleep(50)
    minimizedExtendedStyle := DllCall("user32\GetWindowLongPtrW",
        "Ptr", childHwnd, "Int", Win32.GWL_EXSTYLE, "Ptr")
    suspendedState := WindowHierarchy.Manager.OwnerLocks[ownerHwnd]
        .SuspendedChildren[childHwnd]
    nativeOwner := DllCall("user32\GetWindowLongPtrW", "Ptr", childHwnd,
        "Int", Win32.GWLP_HWNDPARENT, "Ptr")
    AuxiliaryVisualAssert(DllCall("user32\IsIconic", "Ptr", childHwnd,
            "Int") && nativeOwner == 0
            && (minimizedExtendedStyle & Win32.WS_EX_APPWINDOW)
            && !(minimizedExtendedStyle & Win32.WS_EX_TOOLWINDOW)
            && suspendedState.TaskbarRegistered,
        "The " label " minimized child did not acquire a taskbar identity.")
    AuxiliaryVisualAssert(DllCall("user32\IsWindowEnabled",
            "Ptr", ownerHwnd, "Int"),
        "Minimizing the " label " child did not release its owner.")

    restoreResult := WindowHierarchy.RestoreChildFromTaskbar(childHwnd)
    restoredOwnerProbe := DllCall("user32\GetWindowLongPtrW", "Ptr",
        childHwnd, "Int", Win32.GWLP_HWNDPARENT, "Ptr")
    ownerEntry := WindowHierarchy.Manager.OwnerLocks[ownerHwnd]
    AuxiliaryVisualAssert(restoreResult,
        Format("The taskbar could not restore the {1} child window: iconic={2}, visible={3}, owner={4}, suspended={5}.",
            label, DllCall("user32\IsIconic", "Ptr", childHwnd, "Int"),
            DllCall("user32\IsWindowVisible", "Ptr", childHwnd, "Int"),
            restoredOwnerProbe,
            ownerEntry.SuspendedChildren.Has(childHwnd)))
    restoreDeadline := A_TickCount + 1000
    Loop {
        restoredExtendedStyle := DllCall("user32\GetWindowLongPtrW",
            "Ptr", childHwnd, "Int", Win32.GWL_EXSTYLE, "Ptr")
        nativeOwner := DllCall("user32\GetWindowLongPtrW", "Ptr", childHwnd,
            "Int", Win32.GWLP_HWNDPARENT, "Ptr")
        restoredIconic := DllCall("user32\IsIconic", "Ptr", childHwnd,
            "Int")
        restoredVisible := DllCall("user32\IsWindowVisible", "Ptr",
            childHwnd, "Int")
        if !restoredIconic && restoredVisible && nativeOwner == ownerHwnd
                && restoredExtendedStyle == originalExtendedStyle
            break
        if A_TickCount >= restoreDeadline
            break
        Sleep(10)
    }
    AuxiliaryVisualAssert(!restoredIconic && restoredVisible
            && nativeOwner == ownerHwnd
            && restoredExtendedStyle == originalExtendedStyle,
        Format("The {1} taskbar restore did not restore its window state: iconic={2}, visible={3}, owner={4}/{5}, exstyle={6:X}/{7:X}.",
            label, restoredIconic, restoredVisible, nativeOwner, ownerHwnd,
            restoredExtendedStyle, originalExtendedStyle))
    AuxiliaryVisualAssert(!DllCall("user32\IsWindowEnabled",
            "Ptr", ownerHwnd, "Int"),
        "Restoring the " label " child did not reapply its owner lock.")
}

ValidateEventViewerRowState(viewer) {
    AuxiliaryVisualAssert(viewer.GetEventLabel("rules_applied") == "规则已应用"
            && viewer.GetEventLabel("rule_matched") == "规则已匹配"
            && viewer.GetOutcomeLabel("ok") == "成功"
            && viewer.GetOutcomeLabel("up") == "释放"
            && viewer.GetEventLabel("future_event") == "其他事件"
            && viewer.GetOutcomeLabel("future_outcome") == "其他结果"
            && viewer.GetDetailLabel("negated_application_rejected")
                == "取反后：应用条件不匹配",
        "The common runtime event vocabulary is not native Chinese.")
    firstEntry := CreateAuxiliaryVisualEntry(1, "action_executed",
        "", "f1-bandicam", "send", "to_if_held_down")
    viewer.AddEntry(firstEntry, false)
    viewer.OnListItemSelected(viewer.List, 1, true)
    AuxiliaryVisualAssert(viewer.DetailSequence == "1"
            && InStr(viewer.DetailEdit.Value, "动作已执行") > 0
            && !InStr(viewer.DetailEdit.Value, "to_if_held_down"),
        "Selecting an event did not populate its detail state.")
    AuxiliaryVisualAssert(
        viewer.List.GetText(1, EventViewerWindow.EventColumn) == "动作已执行"
            && InStr(viewer.List.GetText(1,
                EventViewerWindow.SourceColumn), "F1（按下时长） → ") == 1
            && !InStr(viewer.List.GetText(1,
                EventViewerWindow.SourceColumn), "f1-bandicam")
            && viewer.List.GetText(1,
                EventViewerWindow.OutcomeColumn) == "发送按键"
            && viewer.List.GetText(1,
                EventViewerWindow.DetailColumn) == "识别长按时执行",
        "The event row exposes raw runtime identifiers.")
    AuxiliaryVisualAssert(firstEntry.Event == "action_executed"
            && firstEntry.Outcome == "send"
            && firstEntry.Detail == "to_if_held_down",
        "Presentation localization mutated the raw trace entry.")

    viewerResizeResult := viewer.OnResize(viewer.Gui, 0, 1100, 900)
    AuxiliaryVisualAssert(IsObject(viewerResizeResult)
            && viewerResizeResult.Status == AtomicControlLayout.Applied
            && viewerResizeResult.Mode == AtomicControlLayout.ModeDeferred
            && viewerResizeResult.Repainted,
        "The event viewer did not use the atomic resize transaction.")
    viewerResizeNoop := viewer.OnResize(viewer.Gui, 0, 1100, 900)
    AuxiliaryVisualAssert(IsObject(viewerResizeNoop)
            && viewerResizeNoop.Status == AtomicControlLayout.Unchanged
            && !viewerResizeNoop.Repainted,
        "The unchanged event-viewer layout requested repainting.")
    viewer.List.GetPos(, , &listWidth, &listHeight)
    viewer.DetailEdit.GetPos(, , , &detailHeight)
    AuxiliaryVisualAssert(detailHeight <= 100 && listHeight >= 600,
        "The event detail area still consumes excess vertical space.")
    sourceWidth := SendMessage(Win32.LVM_GETCOLUMNWIDTH,
        EventViewerWindow.SourceColumn - 1, 0, , viewer.List.Hwnd)
    detailWidth := SendMessage(Win32.LVM_GETCOLUMNWIDTH,
        EventViewerWindow.DetailColumn - 1, 0, , viewer.List.Hwnd)
    AuxiliaryVisualAssert(sourceWidth >= Floor(listWidth * 0.31)
            && detailWidth >= 180,
        "The source/rule column is too narrow for readable rule labels.")
    AssertControlPrecedes(viewer.List, viewer.DetailLabel,
        "The resized event list overlaps the detail section.")
    AssertControlPrecedes(viewer.DetailEdit, viewer.Status,
        "The resized event detail editor overlaps the status line.")

    viewer.CellTooltip.Dispose()
    tooltipSpy := AuxiliaryVisualTooltipSpy()
    viewer.CellTooltip := tooltipSpy
    AuxiliaryVisualAssert(viewer.ListHeader.SortByDisplayColumn(1),
        "Could not activate event viewer sorting.")
    AuxiliaryVisualAssert(tooltipSpy.HideCount > 0,
        "Header sorting left the previous cell tooltip visible.")
    hideCount := tooltipSpy.HideCount
    viewer.ApplyPendingSort()
    AuxiliaryVisualAssert(tooltipSpy.HideCount > hideCount,
        "Deferred sorting left the previous cell tooltip visible.")

    viewer.Clear()
    AuxiliaryVisualAssert(viewer.DetailSequence == ""
            && viewer.DetailEdit.Value == "" && viewer.List.GetCount() == 0,
        "Clearing events left stale row or detail state.")
    AuxiliaryVisualAssert(viewer.Trace.ClearWasCritical,
        "Event clearing was interruptible by a trace callback.")
    secondEntry := CreateAuxiliaryVisualEntry(2, "second_event")
    viewer.AddEntry(secondEntry, false)
    viewer.OnListItemSelected(viewer.List, 1, true)
    AuxiliaryVisualAssert(viewer.RemoveSequence(2),
        "Could not remove an evicted event row.")
    AuxiliaryVisualAssert(viewer.DetailSequence == ""
            && viewer.DetailEdit.Value == "" && viewer.List.GetCount() == 0,
        "Evicting the detailed event left stale detail state.")

    frozenEntry := CreateAuxiliaryVisualEntry(3, "rule_held")
    viewer.AddEntry(frozenEntry, false)
    viewer.Paused := true
    currentEntry := CreateAuxiliaryVisualEntry(4, "rule_released")
    viewer.Trace.SnapshotEntries := [currentEntry]
    viewer.ApplyAppearance()
    AuxiliaryVisualAssert(viewer.List.GetCount() == 1
            && viewer.List.GetText(1, EventViewerWindow.EventColumn)
                == "已识别长按"
            && viewer.SequenceItemIds.Has("3")
            && !viewer.SequenceItemIds.Has("4"),
        "Appearance refresh replaced the event viewer's paused snapshot.")
    viewer.Paused := false
    AuxiliaryVisualAssert(viewer.OnTraceCapacityChanged()
            && viewer.List.GetCount() == 1
            && viewer.List.GetText(1, EventViewerWindow.EventColumn)
                == "来源键已释放"
            && viewer.SequenceItemIds.Has("4"),
        "A trace-capacity change did not rebuild the active event snapshot.")
}

CreateAuxiliaryVisualEntry(sequence, eventName, source := "visual-test",
        ruleId := "", outcome := "ok", detail := "visual detail") {
    return {
        Sequence: sequence,
        Timestamp: "2026-08-02T12:34:56.789Z",
        Category: "runtime",
        Event: eventName,
        Source: source,
        RuleId: ruleId,
        Outcome: outcome,
        Detail: detail,
        Tick: 123,
        Data: Map()
    }
}

ValidateAuxiliaryWindow(guiObj, label) {
    guiObj.GetClientPos(, , &clientWidth, &clientHeight)
    AuxiliaryVisualAssert(clientWidth > 0 && clientHeight > 0,
        label " has no client area.")
    for controlHwnd, control in guiObj {
        if !control.Visible
            continue
        control.GetPos(&x, &y, &width, &height)
        AuxiliaryVisualAssert(x >= 0 && y >= 0 && width >= 0 && height >= 0
                && x + width <= clientWidth + 1
                && y + height <= clientHeight + 1,
            label " contains an out-of-bounds control: " controlHwnd
                " at " x "," y " " width "x" height
                " in " clientWidth "x" clientHeight ".")
    }
}

AssertAuxiliaryWindowBackground(guiObj, label) {
    windowContext := DllCall("user32\GetDC", "Ptr", guiObj.Hwnd, "Ptr")
    memoryContext := windowContext ? DllCall("gdi32\CreateCompatibleDC",
        "Ptr", windowContext, "Ptr") : 0
    bitmap := memoryContext ? DllCall("gdi32\CreateCompatibleBitmap", "Ptr",
        windowContext, "Int", 8, "Int", 8, "Ptr") : 0
    previousBitmap := bitmap ? DllCall("gdi32\SelectObject", "Ptr",
        memoryContext, "Ptr", bitmap, "Ptr") : 0
    try {
        if memoryContext
            SendMessage(Win32.WM_ERASEBKGND, memoryContext, 0, , guiObj.Hwnd)
        pixel := memoryContext ? DllCall("gdi32\GetPixel", "Ptr",
            memoryContext, "Int", 4, "Int", 4, "UInt") : 0xFFFFFFFF
    } finally {
        if previousBitmap
            DllCall("gdi32\SelectObject", "Ptr", memoryContext,
                "Ptr", previousBitmap, "Ptr")
        if bitmap
            DllCall("gdi32\DeleteObject", "Ptr", bitmap, "Int")
        if memoryContext
            DllCall("gdi32\DeleteDC", "Ptr", memoryContext, "Int")
        if windowContext
            DllCall("user32\ReleaseDC", "Ptr", guiObj.Hwnd,
                "Ptr", windowContext)
    }
    expectedColor := UiThemeService.Color("Window")
    AuxiliaryVisualAssert(guiObj.BackColor == expectedColor
            && pixel == ColorRef(expectedColor),
        label " exposed a non-theme client background: "
            Format("{1:06X}", pixel) ".")
}

AssertControlPrecedes(upperControl, lowerControl, message) {
    upperControl.GetPos(, &upperY, , &upperHeight)
    lowerControl.GetPos(, &lowerY)
    AuxiliaryVisualAssert(upperY + upperHeight <= lowerY, message)
}

AuxiliaryEditHasCollapsedSelection(editControl) {
    startPosition := Buffer(4, 0)
    endPosition := Buffer(4, 0)
    SendMessage(Win32.EM_GETSEL, startPosition.Ptr, endPosition.Ptr, ,
        editControl.Hwnd)
    return NumGet(startPosition, 0, "UInt")
        == NumGet(endPosition, 0, "UInt")
}

AuxiliaryReadRichTextFormat(hwnd, position) {
    savedSelection := Buffer(8, 0)
    SendMessage(0x0434, 0, savedSelection.Ptr, , hwnd) ; EM_EXGETSEL
    selection := Buffer(8, 0)
    NumPut("Int", position, selection, 0)
    NumPut("Int", position + 1, selection, 4)
    SendMessage(0x0437, 0, selection.Ptr, , hwnd) ; EM_EXSETSEL
    format := Buffer(116, 0)
    NumPut("UInt", format.Size, format, 0)
    try SendMessage(0x043A, 1, format.Ptr, , hwnd) ; EM_GETCHARFORMAT
    finally SendMessage(0x0437, 0, savedSelection.Ptr, , hwnd)
    return {
        Mask: NumGet(format, 4, "UInt"),
        TextColor: NumGet(format, 20, "UInt"),
        BackgroundColor: NumGet(format, 96, "UInt")
    }
}

AuxiliaryVisualAssert(value, message) {
    if !value
        throw Error(message)
}

class MappingWindow {
    static Colors := {}
}

class AuxiliaryVisualOwner {
    __New() {
        this.App := AuxiliaryVisualApp()
        this.App.OwnerWindow := this
        this.Gui := Gui("+Resize", "Auxiliary visual owner")
        this.Gui.BackColor := UiThemeService.Color("Window")
        this.Gui.Show("Hide w1200 h760")
        this.Status := this.Gui.Add("Text", "x10 y730 w1100 h20", "")
    }

    OnSettingsClosed(*) => true
    OnAboutClosed(*) => true
    OnDonationClosed(*) => true
    OnSupportInfoClosed(*) => true
    OnEventViewerClosed(*) => true
    OnRulePackageImportClosed(*) => true
    OnHelpClosed(*) => true

    Dispose() {
        try this.App.SvgRenderer.Dispose()
        try this.Gui.Destroy()
    }
}

class AuxiliaryVisualApp {
    __New() {
        this.Settings := {
            UiLanguage: "zh-CN", UiFont: "auto", Theme: "dark",
            ShowAtStartup: false, RunAsAdministrator: true,
            CheckUpdatesOnStartup: true,
            EscapeCancelsRecording: true, EventBufferCapacity: 1000,
            EventViewerAutoScroll: true,
            AIAddress: "", AIKey: "", AIModel: "", AITimeoutS: 600,
            AIPrompt: "生成符合要求的完整键鼠重映射持久化规则块。",
            AIOptimizePrompt: "优化当前键鼠重映射规则。",
            AISystemPrompt: AIService.DefaultSystemPrompt
        }
        this.SvgRenderer := SvgRenderLibrary(GetApplicationRootFilePath(
            "third_party\resvg\resvg.dll"))
        this.AIService := AuxiliaryVisualAIService()
        this.Trace := AuxiliaryVisualTrace()
        this.Repository := AuxiliaryVisualRepository()
        this.UpdateService := AuxiliaryVisualUpdateService()
        this.PackageService := AuxiliaryVisualPackageService()
        this.SaveAIConnectionSettingsCount := 0
        this.FailAIConnectionSettingsSave := false
    }

    SaveAIConnectionSettings(settings) {
        this.SaveAIConnectionSettingsCount++
        if this.FailAIConnectionSettingsSave
            throw Error("planned AI settings persistence failure")
        this.Settings.AIAddress := settings.AIAddress
        this.Settings.AIKey := settings.AIKey
        this.Settings.AIModel := settings.AIModel
        this.Settings.AITimeoutS := settings.AITimeoutS
        return true
    }

    GetStartupTaskState(*) => {Status: "missing"}
    BeginRawObservation(*) => true
    EndRawObservation(*) => true
    OpenDonation(*) => true
    BeginApplicationUpdateCheck(*) => false
    CompleteRulePackageImport(*) => {Imported: 1}
}

class AuxiliaryVisualAIService {
    __New() {
        this.NextRequestId := 0
        this.PendingCallback := ""
        this.PendingRequestId := 0
        this.LastSettings := ""
    }

    TestConnection(settings, callback) {
        this.LastSettings := settings
        this.PendingCallback := callback
        this.PendingRequestId := ++this.NextRequestId
        return {Ok: true, RequestId: this.PendingRequestId}
    }

    Complete(ok, message, successfulAddress) {
        if !this.PendingRequestId || !IsObject(this.PendingCallback)
            return false
        requestId := this.PendingRequestId
        callback := this.PendingCallback
        this.PendingRequestId := 0
        this.PendingCallback := ""
        callback.Call(ok, message, successfulAddress, requestId)
        return true
    }

    Cancel(requestId) {
        if requestId != this.PendingRequestId
            return false
        this.PendingRequestId := 0
        this.PendingCallback := ""
        return true
    }
}

class AuxiliaryVisualRepository {
    Load(*) {
        return [{
            Id: "f1-bandicam",
            Source: "F1（按下时长）",
            Target: "短按保留 F1 / 长按录屏"
        }]
    }
}

class AuxiliaryVisualUpdateService {
    IsChecking(*) => false
}

class AuxiliaryVisualTrace {
    __New() {
        this.Capacity := 1000
        this.Count := 0
        this.DroppedCount := 0
        this.SnapshotEntries := []
        this.ClearWasCritical := false
    }

    Subscribe(*) => 1
    Unsubscribe(*) => true
    Snapshot(*) => this.SnapshotEntries.Clone()
    Clear(*) {
        this.ClearWasCritical := !!A_IsCritical
        return true
    }
    ExportJsonLines(*) => true
}

class AuxiliaryVisualTooltipSpy {
    __New() {
        this.HideCount := 0
    }

    Hide(*) {
        this.HideCount++
        return true
    }

    InvalidateTheme(*) => this.Hide()

    Dispose(*) => true
}

class AuxiliaryVisualPackageService {
    Preview(*) {
        return Map(
            "source", Map("name", "visual package"),
            "version", "1.0.0",
            "total_count", 1,
            "selected_count", 1,
            "permissions", [],
            "rules", [Map("id", "visual-rule", "mode", "managed",
                "permissions", [], "selected", JsonBoolean(true))])
    }
}
