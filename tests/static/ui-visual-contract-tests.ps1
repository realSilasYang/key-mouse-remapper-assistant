[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)

function Read-ProjectText {
    param([string]$RelativePath)
    Get-Content -LiteralPath (Join-Path $projectRoot $RelativePath) `
        -Raw -Encoding UTF8
}

function Assert-Matches {
    param(
        [string]$RelativePath,
        [string]$Pattern,
        [string]$Description
    )
    $text = Read-ProjectText $RelativePath
    if ($text -notmatch $Pattern) {
        throw "UI visual contract failed: $Description ($RelativePath)"
    }
}

function Assert-DoesNotMatch {
    param(
        [string]$RelativePath,
        [string]$Pattern,
        [string]$Description
    )
    $text = Read-ProjectText $RelativePath
    if ($text -match $Pattern) {
        throw "UI visual contract failed: $Description ($RelativePath)"
    }
}

function Assert-NoForbiddenFonts {
    $checkedRoots = @('app', 'src')
    $seguiAllowedFiles = @(
        'src\Localization\LocalizationService.ahk',
        'app\UI\DarkMessageBox.ahk'
    )
    foreach ($root in $checkedRoots) {
        $rootPath = Join-Path $projectRoot $root
        foreach ($file in Get-ChildItem -LiteralPath $rootPath -Recurse `
                -Filter '*.ahk' -File) {
            $relativePath = $file.FullName.Substring($projectRoot.Length + 1)
            $text = Get-Content -LiteralPath $file.FullName -Raw `
                -Encoding UTF8
            if ($text -match 'Segoe UI Symbol') {
                throw "UI visual contract failed: Segoe UI Symbol is not allowed ($relativePath)"
            }
            if ($text -match 'Segoe UI Emoji' -and
                    $relativePath -ne 'app\UI\DarkMessageBox.ahk') {
                throw "UI visual contract failed: Segoe UI Emoji is only allowed for dialog icons ($relativePath)"
            }
            if ($text -match 'Segoe UI' -and
                    $seguiAllowedFiles -notcontains $relativePath) {
                throw "UI visual contract failed: window code must use LocalizationService fonts instead of hard-coded Segoe UI ($relativePath)"
            }
            if ($relativePath -eq 'app\UI\DarkMessageBox.ahk') {
                $nonIconText = $text -replace 'Segoe UI Emoji', ''
                if ($nonIconText -match 'Segoe UI') {
                    throw "UI visual contract failed: dark dialogs may hard-code Segoe UI Emoji only for icons ($relativePath)"
                }
            }
        }
    }
}

Assert-NoForbiddenFonts

Assert-Matches 'src\Platform\Win32.ahk' `
    'WM_ERASEBKGND\s*:=\s*0x0014' `
    'Win32 constants must expose WM_ERASEBKGND for native background painting'
Assert-Matches 'src\UI\ThemeHelpers.ahk' `
    'class\s+NativeWindowBackgroundRegistry' `
    'native client background registry must exist'
Assert-Matches 'src\UI\ThemeHelpers.ahk' `
    '(?s)OnMessage\(Win32\.WM_ERASEBKGND,\s*this\.MessageCallback\).*?this\.Windows\[hwnd\]' `
    'native background drawing must route erase messages through per-window state'
Assert-Matches 'src\UI\ThemeHelpers.ahk' `
    'WM_ERASEBKGND' `
    'native background drawing must handle WM_ERASEBKGND'
Assert-Matches 'src\UI\ThemeHelpers.ahk' `
    'FillRect' `
    'native background drawing must fill with the application brush'
Assert-Matches 'src\UI\ThemeHelpers.ahk' `
    '(?s)OnMessage\(Win32\.WM_NCDESTROY,\s*this\.DestroyMessageCallback\).*?DeleteBrush' `
    'native background drawing must release each window brush at destruction'
Assert-Matches 'src\UI\ThemeHelpers.ahk' `
    '(?s)ApplyDarkWindow\(hwnd\).*?RegisterNativeWindowBackground\(hwnd,\s*UiThemeService\.Color\("Window"\)\)' `
    'all themed top-level windows must register the application background brush'
Assert-Matches 'src\UI\ThemeHelpers.ahk' `
    '(?s)ShowPreparedWindow\(.*?guiObj\.Show\("Hide " showOptions\).*?EndStableWindowUpdate\(hwnd, true\).*?guiObj\.Show\(\)' `
    'prepared windows must follow the reference hidden-layout then visible-show sequence'
Assert-Matches 'app\Windows\MappingWindow.ahk' `
    '(?s)this\.Gui := Gui\(.*?this\.Gui\.BackColor := MappingWindow\.Colors\.Window\s*RegisterNativeWindowBackground\(this\.Gui\.Hwnd' `
    'main window must register native background before first show'
Assert-Matches 'app\Windows\MappingWindow.ahk' `
    'UnregisterNativeWindowBackground\(this\.Gui\.Hwnd\)' `
    'main window must release native background resources'
Assert-Matches 'app\Windows\MappingWindow.ahk' `
    '(?s)FirstVisibleWindowPresenter\.Show\(this\.Gui,.*?ObjBindMethod\(this,\s*"PrepareFirstVisibleSurface"\).*?ObjBindMethod\(this,\s*"RefreshVisibleRoundedButtons"\)' `
    'direct launch must use the atomic first-visible presentation path'
Assert-Matches 'app\Windows\MappingWindow.ahk' `
    '(?s)PrepareFirstVisibleSurface\(\).*?RefreshCaptureLayout\(true\).*?UiThemeService\.ApplyProcessPreference\(\).*?ApplyNativeThemes\(false\).*?Gui\.BackColor\s*:=.*?RefreshVisibleRoundedButtons\(\).*?Win32\.RDW_LAYOUT_REFRESH' `
    'the cloaked first frame must prepare layout, theme and client background before reveal'
Assert-Matches 'src\Platform\Win32.ahk' `
    '(?s)class\s+FirstVisibleWindowPresenter.*?DWMWA_CLOAK.*?FlushComposition\(\).*?DwmFlush.*?guiObj\.Show\(showOptions\).*?prepareVisibleSurface\.Call\(\).*?this\.FlushComposition\(\).*?SetCloaked\(guiObj\.Hwnd,\s*false\)' `
    'the first visible presenter must reveal only after the real frame is prepared and flushed'
Assert-Matches 'src\Platform\Win32.ahk' `
    '(?s)EnsureWindowNotMinimized\(hwnd\).*?IsIconic.*?Win32\.SW_RESTORE.*?guiObj\.Show\(showOptions\).*?EnsureWindowNotMinimized\(guiObj\.Hwnd\).*?SetCloaked\(guiObj\.Hwnd,\s*false\).*?EnsureWindowNotMinimized\(guiObj\.Hwnd\)' `
    'all visible presentation paths must normalize inherited minimized startup state before and after reveal'
Assert-Matches 'app\KeyMouseRemapperAssistantApp.ahk' `
    '(?s)ShowMainWindowAfterReload\(\*\).*?return this\.Window\.Activate\(\)' `
    'all main-window wake paths must stay inside the mapping-window presentation boundary'
Assert-Matches 'app\KeyMouseRemapperAssistantApp.ahk' `
    '(?s)Shutdown\(\*\).*?TrySaveMainWindowLayout\(\).*?Window\.HideForShutdown\(\).*?Runtime\.Shutdown\(\).*?Window\.Dispose\(\)' `
    'shutdown and takeover must hide the complete window before releasing runtime or visual resources'
Assert-Matches 'app\Windows\MappingWindow.ahk' `
    '(?s)HideForShutdown\(\).*?ShowWindow.*?Win32\.SW_HIDE.*?CellTooltip\.Hide\(\).*?ContextPopup\.Hide\(\).*?IsWindowVisible' `
    'shutdown hiding must be synchronous and independent of later cleanup work'
Assert-Matches 'src\Core\DirectRuntimeSupport.ahk' `
    '(?s)ShowExistingApplicationWindow\(.*?if delivered\s*return showResult' `
    'current single-instance wake requests must return only the in-process presentation result'
Assert-DoesNotMatch 'src\Core\DirectRuntimeSupport.ahk' `
    'WinShow\(|WinRestore\(|WinActivate\(' `
    'single-instance support must not expose an unprepared main HWND directly'

Assert-Matches 'src\Localization\LocalizationService.ahk' `
    'static\s+GetLanguageSystemUiFontName' `
    'system UI font resolution must remain centralized'
Assert-Matches 'src\Localization\LocalizationService.ahk' `
    'static\s+GetUiFontName' `
    'selected content font resolution must remain centralized'

Assert-Matches 'src\UI\MappingUiInteractions.ahk' `
    '(?s)RegisterButton\(.*?control\.SetFont\("norm bold",\s*LocalizationService\.GetLanguageSystemUiFontName\(\)\)' `
    'owner-drawn buttons must follow the reference system UI bold font rule'

Assert-Matches 'app\UI\DarkMessageBox.ahk' `
    'CalculateDarkDialogLayout' `
    'dark dialogs must use the measured reference layout'
Assert-Matches 'app\UI\DarkMessageBox.ahk' `
    '(?s)CalculateDarkDialogLayout\(windowWidth, messageHeight, buttonWidths,\s*buttonTopGap := 20\).*?contentTop := 20.*?iconHeight := 30.*?buttonHeight := 30.*?buttonGap := 12' `
    'dark dialog vertical metrics must match the reference'
Assert-Matches 'app\UI\DarkMessageBox.ahk' `
    '(?s)static\s+IconX\s*:=\s*20\s*static\s+IconWidth\s*:=\s*30\s*static\s+MessageX\s*:=\s*60\s*static\s+ButtonHeight\s*:=\s*30' `
    'dark dialog icon, message and button columns must match the reference'
Assert-Matches 'app\UI\DarkMessageBox.ahk' `
    'WindowHeight:\s*buttonY\s*\+\s*buttonHeight\s*\+\s*15' `
    'dark dialog bottom padding must match the reference'
Assert-Matches 'app\UI\DarkMessageBox.ahk' `
    'windowWidth\s*:=\s*300' `
    'single-button dark dialog width must match the reference'
Assert-Matches 'app\UI\DarkMessageBox.ahk' `
    'windowWidth\s*:=\s*this\.AcceptEnter\s*\?\s*365\s*:\s*360' `
    'confirm dialog width must expand only for Save and Run'
Assert-Matches 'app\UI\DarkMessageBox.ahk' `
    'MeasureDarkDialogButtonWidth' `
    'dark dialog buttons must be measured before centering'
Assert-Matches 'app\UI\DarkMessageBox.ahk' `
    '(?s)MeasureDarkDialogButtonWidth\(.*?GetTextExtentPoint32W.*?textWidthDip.*?Max\([^,]+,\s*textWidthDip \+ 24\)' `
    'dark dialog buttons must measure rendered text and keep reference padding'
Assert-Matches 'app\UI\DarkMessageBox.ahk' `
    'LocalizationService\.GetUiFontName\(\)' `
    'dark dialog message text must use the selected content font'
Assert-Matches 'app\UI\DarkMessageBox.ahk' `
    'Segoe UI Emoji' `
    'dark dialog icons must use the same native emoji font as the reference'
Assert-Matches 'app\UI\DarkMessageBox.ahk' `
    'AddIcon\(Chr\(0x26A0\),\s*this\.WarningIconColor,\s*LocalizationService\.GetLanguageSystemUiFontName\(\)\)' `
    'confirm dialogs must render a theme-colored monochrome warning symbol'
Assert-Matches 'app\UI\DarkMessageBox.ahk' `
    'ShowPreparedWindow\(this\.Gui,\s*"Center w"' `
    'dark dialogs must use the prepared centered show path'
Assert-Matches 'app\UI\DarkMessageBox.ahk' `
    'CalculateDarkDialogLayout\(windowWidth, messageHeight,\s*\[primaryWidth, secondaryWidth\], 22\)' `
    'confirm dialogs must use the reference two-button top gap'

Assert-Matches 'app\Windows\SettingsWindow.ahk' `
    'AlignMenuColumn\(labels, itemWidths, clientWidth := 0\)' `
    'settings pages must keep the measured stacked-menu centering helper'
Assert-Matches 'app\Windows\SettingsWindow.ahk' `
    '(?s)AddMenuLabel\(index, y, text\).*?RegExReplace\(.*?\).*?AddSelectableMenuText.*?Gui\.Add\("Edit".*?ReadOnly -TabStop -Border' `
    'stacked settings labels must be selectable, borderless, and absent from tab navigation'
Assert-Matches 'app\Windows\SettingsWindow.ahk' `
    'RegisterTextInput\(control, "", "arrow"\)' `
    'selectable settings labels must retain the normal arrow cursor'
Assert-Matches 'app\Windows\SettingsWindow.ahk' `
    '(?s)tabGroupWidth :=.*?tabX := 15 \+ Floor\(\(\(this\.WindowWidth - 30\) - tabGroupWidth\) / 2\)' `
    'settings tab buttons must be centered as a measured group'
Assert-Matches 'app\Windows\SettingsWindow.ahk' `
    '(?s)startupGroupWidth := Min\(layout\.ContentWidth,\s*Max\(runAsAdministratorWidth, checkUpdatesWidth,\s*showAtStartupWidth\)\).*?RunAsAdministratorCheck.*?startupGroupX.*?y144.*?CheckUpdatesOnStartupCheck.*?startupGroupX.*?y176.*?ShowAtStartupCheck.*?startupGroupX.*?y208' `
    'administrator startup must be enabled above update and window options'
Assert-Matches 'app\Windows\SettingsWindow.ahk' `
    '(?s)tabIcons := \["monitor\.svg", "power\.svg".*?case 1: this\.BuildAppearanceTab\(\).*?case 2: this\.BuildStartupTab\(\)' `
    'Appearance must precede Startup in the settings tabs'
Assert-Matches 'app\Windows\SettingsWindow.ahk' `
    '(?s)ApplySparseMenuTopSpacing\(index\).*?bottom - top >= Floor\(this\.WindowHeight / 2\).*?control\.Move\(, controlY \+ SettingsWindow\.SparseMenuTopOffset\)' `
    'settings pages below half the window height must share extra top spacing'
Assert-Matches 'app\Windows\SettingsWindow.ahk' `
    '(?s)BuildStartupTab\(\).*?pageIndex := 2.*?ApplySparseMenuTopSpacing\(pageIndex\).*?this\.TabBuilt\[pageIndex\] := true.*?BuildAppearanceTab\(\).*?pageIndex := 1.*?AddMenuLabel\(pageIndex,.*?AlignAppearanceTabControls\(\).*?ApplySparseMenuTopSpacing\(pageIndex\).*?this\.TabBuilt\[pageIndex\] := true' `
    'Startup and Appearance controls must use their reordered tab pages'
Assert-Matches 'app\Windows\SettingsWindow.ahk' `
    '(?s)BuildAppearanceTab\(\).*?AddMenuIcon\(pageIndex, 68,\s*"languages\.svg".*?AddMenuIcon\(pageIndex, 136,\s*"type\.svg".*?AddMenuIcon\(pageIndex, 204,\s*"palette\.svg"' `
    'Appearance settings must use compact semantic Lucide icon rows'
Assert-Matches 'app\Windows\SettingsWindow.ahk' `
    '(?s)AddMenuIcon\(index, y, iconName, iconColor\).*?RegisterIconSurface.*?SetControlLucideIcon' `
    'settings menu icons must use the shared Lucide icon-surface renderer'
Assert-Matches 'src\UI\MappingUiInteractions.ahk' `
    '(?s)RegisterIconSurface\(control, backgroundColor, iconColor := ""\).*?TextInsetDip: 0' `
    'standalone icon surfaces must not inherit button text padding'
Assert-Matches 'app\Windows\SettingsWindow.ahk' `
    '(?s)this\.ActiveTab := index.*?if index == 2\s+this\.RefreshStartupTaskStatus\(\).*?SetTextNoErase\(this\.StartupTaskButton' `
    'Startup task state must resolve before the selected tab is presented'
Assert-Matches 'app\Windows\SettingsWindow.ahk' `
    '(?s)BuildAITab\(\).*?AddMenuLabel\(3,.*?AddSettingsEdit\(3, 0,.*?AlignAITabControls\(\).*?this\.TabBuilt\[3\] := true' `
    'AI settings must use the shared menu column'
Assert-Matches 'app\Windows\SettingsWindow.ahk' `
    '(?s)static\s+ClientHeight\s*:=\s*420.*?ValidationStatus := this\.Gui\.Add\("Text", "x25 y352.*?SaveButton := this\.AddActionButton\([^\r\n]*, 376,.*?CancelButton := this\.AddActionButton\([^\r\n]*, 376,' `
    'the settings window must reclaim the obsolete bottom result space'
Assert-Matches 'app\Windows\SettingsWindow.ahk' `
    '(?s)AIKeyInput := this\.AddSettingsEdit\(3, 0, 142,\s*inputWidth, this\.Original\.AIKey\)' `
    'the API key field must use a normal visible text edit'
Assert-DoesNotMatch 'app\Windows\SettingsWindow.ahk' `
    '(?s)AIKeyInput := this\.AddSettingsEdit\([^\)]*Password' `
    'the API key field must not use password masking'
Assert-Matches 'app\Windows\SettingsWindow.ahk' `
    '(?s)BuildAITab\(\).*?AITestConnectionButton.*?TestAIConnection.*?HandleAIConnectionTestResult.*?FormatAIConnectionFailure\(message\).*?SetAIConnectionStatus\(Tr\(' `
    'AI settings must test the full request path and report its actual result'
Assert-Matches 'app\Windows\SettingsWindow.ahk' `
    '(?s)AIConnectionStatusGap\s*:=\s*24.*?AIConnectionStatus :=.*?Gui\.Add\("Edit".*?ReadOnly Multi Wrap.*?RegisterTextInput\(this\.AIConnectionStatus\).*?statusX := testButtonX \+ testButtonWidth\s*\+ SettingsWindow\.AIConnectionStatusGap' `
    'AI connection results must be selectable wrapped text beside the test button'
Assert-DoesNotMatch 'app\Windows\SettingsWindow.ahk' `
    'AIConnectionStatusTimer|AIConnectionStatusGeneration|ClearAIConnectionStatus|AIAddressInput\.Edit\.Value := normalizedAddress' `
    'AI connection results must persist and connection testing must not rewrite parameters'
Assert-Matches 'src\Core\AIService.ahk' `
    '(?s)DescribeConnectionFailure\(message\).*?DescribeHttpFailure\(status.*?BuildHttpFailureContext.*?ParseServiceError.*?HasModelEvidence.*?IsModelScopedNotFound.*?DescribeTransportFailure\(errorNumber.*?winHttpCode == 12002.*?winHttpCode == 12007.*?winHttpCode == 12029' `
    'AI connection failures must preserve and classify concrete HTTP and transport causes'
Assert-Matches 'src\Core\AIService.ahk' `
    '(?s)MinimumRuleRequestTimeoutS := 600.*?MaximumTimeoutS := 3600.*?kind == "mapping"\s*\? Max\(normalized\.AITimeoutS,\s*AIService\.MinimumRuleRequestTimeoutS\).*?NotifyRequestStatus\(requestId, "connecting".*?NotifyRequestStatus\(requestId, "waiting".*?NotifyRequestStatus\(requestId, "response"' `
    'AI rule requests must allow long model work and expose concrete transport stages'
Assert-Matches 'app\Windows\MappingBlockEditor.ahk' `
    '(?s)HandleAiRequestStatus\(status, requestId.*?ElapsedSeconds.*?SetStatus\(phaseStatus.*?elapsedS\)\)' `
    'the mapping editor must show the AI phase and elapsed request time'
Assert-DoesNotMatch 'app\Windows\MappingBlockEditor.ahk' `
    'HandleAiRequestStatus[\s\S]*?TimeoutSeconds' `
    'the mapping editor must not expose the internal request timeout'
Assert-Matches 'src\UI\UiThemeService.ahk' `
    '(?s)Save:\s*palette\["Save"\].*?DarkPalette\(\).*?"Save", "3F6B5B".*?LightPalette\(\).*?"Save", "3F6B5B"' `
    'iconless Save buttons must use the exact semantic save color in both themes'
Assert-Matches 'app\Windows\SettingsWindow.ahk' `
    '(?s)SaveButton := this\.AddActionButton\(actionGroupX, 376,\s*Tr\([^\r\n]+\), colors\.Save' `
    'the settings Save button must use the semantic save color'
Assert-Matches 'app\Windows\SettingsWindow.ahk' `
    '(?s)class AIPromptsEditor.*?SaveButton := this\.AddButton\(432, 388, 80, Tr\([^\r\n]+\),\s*colors\.Save' `
    'the prompt-editor Save button must use the semantic save color'
Assert-Matches 'app\Windows\MappingBlockEditor.ahk' `
    '(?s)SaveButton := this\.AddCommandButton\(598, 512, 80,\s*Tr\([^\r\n]+\), colors\.Save.*?SetButtonAppearance\(this\.SaveButton,\s*colors\.Save' `
    'the mapping editor Save button must use the semantic save color'
Assert-Matches 'app\Windows\MappingBlockEditor.ahk' `
    '(?s)EditorWidth := 780.*?EditorHeight := 560.*?EditorMinimumWidth := 640.*?EditorMinimumHeight := 440.*?AIButtonWidth := 144.*?AiButton := this\.AddCommandButton\(446, 512,\s*MappingBlockEditor\.AIButtonWidth,\s*this\.GetAiButtonText\(\), colors\.AIButton,\s*ObjBindMethod\(this, "StartAiRequest"\)\)' `
    'the contextual AI command must have stable dimensions and a direct callback'
Assert-Matches 'app\Windows\MappingBlockEditor.ahk' `
    'ResolveAiOperation\(\) => this\.IsNew \? "generate" : "optimize"' `
    'new and existing editors must resolve different AI operations'
Assert-Matches 'app\Windows\MappingBlockEditor.ahk' `
    '(?s)GetAiButtonText\(\)\s*\{\s*return this\.IsNew \? Tr\("[^"]+"\) : Tr\("[^"]+"\)' `
    'the contextual AI command must identify generation or optimization'
Assert-Matches 'app\Windows\MappingBlockEditor.ahk' `
    '(?s)StartAiRequest\(\*\).*?PromptForAiPurpose\(operation\).*?AiRequestPurpose := purposeResult\.Value' `
    'the contextual AI command must collect and retain a per-request purpose'
Assert-Matches 'app\Windows\MappingBlockEditor.ahk' `
    '(?s)StartAiPipelineRequest\(.*?AIService\.Request\(.*?this\.AiRequestPurpose' `
    'every AI pipeline phase must transmit the retained request purpose'
Assert-DoesNotMatch 'app\Windows\MappingBlockEditor.ahk' `
    'ShowAiMenu|AiMenu\s*:=|aiMenu\.Add|aiMenu\.Show' `
    'the mapping editor must not retain the generate-or-optimize AI menu'
Assert-Matches 'src\Core\RuleCompiler.ahk' `
    '(?s)BuildManagedBlock\(.*?(?:MetadataCommentLine\("[^"]+"\).*?){5}' `
    'managed editor blocks must explain every persisted metadata field'
Assert-Matches 'src\Core\ScriptRuleCompiler.ahk' `
    '(?s)BuildBlock\(.*?(?:MetadataCommentLine\("[^"]+"\).*?){5}' `
    'script editor blocks must explain every persisted metadata field'
Assert-Matches 'src\Core\MappingCodeRepository.ahk' `
    '(?s)CreateBlankBlock\(\).*?BuildBlankManagedBlock.*?CreateBlankScriptCode\(\).*?ScriptCodePlaceholder.*?CreateBlankScriptBlock\(\).*?BuildBlankScriptBlock' `
    'new-rule editors must use explicit placeholders instead of concrete example rules'
Assert-Matches 'src\Core\AIService.ahk' `
    'Request\(settings, mode, operation, currentText, callback,' `
    'AI mapping requests must accept an explicit per-request purpose'
Assert-Matches 'src\Core\AIService.ahk' `
    'if purpose == ""' `
    'AI mapping requests must reject an empty per-request purpose'
Assert-Matches 'src\Core\AIService.ahk' `
    '(?s)BuildMessages\(settings, mode, operation, currentText, purpose\).*?taskData := Map\(.*?"purpose", purpose,.*?"current_editor_content_usage", operation == "generate".*?"current_editor_content", currentText\).*?user := prompt.*?JsonCodec\.Stringify\(taskData' `
    'AI user messages must isolate the purpose and current rule as untrusted structured data'
Assert-Matches 'app\Windows\MappingBlockEditor.ahk' `
    '(?s)HandleAiResult\(.*?operation := this\.ResolveAiOperation\(\).*?if operation == "optimize" \{.*?ReviewAiResult\(currentText, normalizedText\).*?\}\s*previousMode := this\.EditorMode.*?ReplaceEditorTextAtomically' `
    'AI generation must apply validated results directly while optimization retains review'
Assert-DoesNotMatch 'app\Windows\MappingBlockEditor.ahk' `
    '审阅 AI 生成结果' `
    'AI generation must not retain a result-preview branch'
Assert-Matches 'app\UI\DarkMessageBox.ahk' `
    '(?s)class DarkTextInputDialog.*?SendMessage\(0x00C5, 0, 0, ,\s*this\.TextEdit\.Hwnd\)' `
    'the per-request AI purpose editor must use the native maximum text capacity'
Assert-Matches 'app\Windows\SettingsWindow.ahk' `
    '(?s)for editControl in \[this\.GenerateEdit, this\.OptimizeEdit,\s*this\.SystemEdit\].*?SendMessage\(0x00C5, 0, 0, ,\s*editControl\.Hwnd\)' `
    'the AI prompt editors must use the native maximum text capacity'
Assert-DoesNotMatch 'app\Windows\MappingBlockEditor.ahk' `
    'MetadataPanel|MetadataTitle|MetadataRows|MetadataNote|BuildMetadataReference' `
    'the mapping editor must not retain a separate code-structure reference panel'
Assert-Matches 'app\Windows\MappingBlockEditor.ahk' `
    '(?s)editorHeight :=.*?BuildCodeEditorLayoutEntries\(14,\s*MappingBlockEditor\.CodeEditorTop,\s*contentWidth, editorHeight\)' `
    'new and existing rule editors must give the full content width to the code surface'
Assert-Matches 'app\Windows\MappingBlockEditor.ahk' `
    '(?s)BuildModeSelector\(\).*?MeasureControlTextWidth\(this\.ManagedModeButton.*?MeasureControlTextWidth\(this\.ScriptModeButton.*?ModeButtonHorizontalPadding.*?this\.ModeButtonWidth :=.*?ModeButtonMinimumWidth.*?ModeButtonMaximumWidth' `
    'mapping mode buttons must size to their localized labels without fixed excess whitespace'
Assert-Matches 'app\UI\DarkMessageBox.ahk' `
    '(?s)class DarkTextInputDialog.*?WindowHeight := 220.*?EditorHeight := 108.*?this\.Status :=.*?Hidden.*?ShowValidationError\(\).*?ErrorWindowHeight.*?OnTextChanged\(\*\).*?ClearValidationError\(\)' `
    'the AI-purpose editor must use validation space only while an error is visible'
Assert-Matches 'app\Windows\MappingBlockEditor.ahk' `
    '(?s)ReplaceEditorTextAtomically\(text\).*?0x000B, 0.*?ControlSetText\(text, this\.CodeEdit\).*?ApplyEditorTextFormatting\(canonicalText, true, false\).*?0x000B, 1' `
    'mode switches must replace and format RichEdit text before restoring redraw'
Assert-Matches 'app\Windows\MappingBlockEditor.ahk' `
    '(?s)EditorLineSpacingTwips := 340.*?ApplySynchronizedLineSpacing\(spacingRange\).*?SetRichTextLineSpacing\(codeStart,.*?SetRichTextLineSpacing\(gutterStart,.*?0x00000100.*?EditorLineSpacingTwips' `
    'the code surface and line-number gutter must use one exact base line height'
Assert-DoesNotMatch 'app\Windows\MappingBlockEditor.ahk' `
    'PFM_SPACEBEFORE|PFM_SPACEAFTER|CommentSpaceBeforeTwips|IsExplanatoryCommentLine' `
    'the editor must not add comment-specific vertical spacing'
foreach ($minimizableChildPath in @(
        'app\Windows\MappingBlockEditor.ahk',
        'app\Windows\EventViewerWindow.ahk',
        'app\Windows\SupportInfoWindow.ahk',
        'app\Windows\AboutWindow.ahk')) {
    Assert-Matches $minimizableChildPath `
        '(?s)Gui\("\+Owner.*?\+MinimizeBox' `
        'every minimizable child window must declare its capability explicitly'
}
Assert-Matches 'app\Windows\MappingContextPopupWindow.ahk' `
    '(?s)Gui\("\+Owner.*?-Caption.*?-MinimizeBox.*?-MaximizeBox' `
    'the captionless mapping popup must not retain minimize or maximize styles'
Assert-Matches 'src\Platform\WindowHierarchy.ahk' `
    '(?s)RestoreChildFromTaskbar\(childHwnd, maximize := false\).*?RestoreOwnerWindow\(ownerHwnd\).*?RestoreWindowFromTaskbar\(childHwnd, maximize\).*?PrepareChildRestore\(childHwnd\).*?ActivateOwnedWindow\(childHwnd\)' `
    'taskbar restore must restore the owner before rebuilding its child relationship'
Assert-Matches 'src\Platform\WindowHierarchy.ahk' `
    '(?s)ActivateTopOwned\(ownerGui\).*?FindRecoverableChild\(entry, currentHwnd\).*?RecoverOwnedChild\(currentHwnd, nextHwnd\).*?RecoverOwnedChild\(ownerHwnd, childHwnd\).*?SetNativeOwner\(childHwnd, 0\).*?RestoreOwnerWindow\(ownerHwnd\).*?SetNativeOwner\(childHwnd, ownerHwnd\).*?RestoreOwnedWindow\(childHwnd\)' `
    'main-window activation must recover a hidden modal child and its owner'
Assert-Matches 'app\Windows\MappingWindow.ahk' `
    '(?s)ShowWithOptions\(showOptions := ""\).*?IsOwnerLocked\(this\.Gui\)\s*&& WindowHierarchy\.ActivateTopOwned\(this\.Gui\)\s*return true' `
    'main-window presentation must only stop after an owned window was activated'
Assert-Matches 'app\Windows\MappingWindow.ahk' `
    '(?s)Activate\(\*\).*?IsOwnerLocked\(this\.Gui\).*?ActivateTopOwned\(this\.Gui\).*?return true.*?IsWindowVisible.*?if !visible && !this\.Show\(\)' `
    'main-window activation must preserve a recovered modal child and skip repeated presentation'
Assert-Matches 'app\Windows\MappingWindow.ahk' `
    '(?s)Activate\(\*\).*?preventSelectionFlash := visible.*?SetListActivationRedraw\(false\).*?WinActivate.*?finally.*?SetListActivationRedraw\(true\).*?RefreshSelectedListRows\(\)' `
    'main-window activation must suppress the native selection frame before restoring custom drawing'
Assert-Matches 'app\KeyMouseRemapperAssistantApp.ahk' `
    'A_TrayMenu\.Add\(Tr\("显示主界面"\), ObjBindMethod\(this\.Window, "Activate"\)\)' `
    'the tray restore entry must use the complete activation path'
Assert-Matches 'src\Platform\WindowHierarchy.ahk' `
    '(?s)MinimizeWindow\(hwnd\).*?Win32\.SW_MINIMIZE.*?IsWindowMinimized\(hwnd\)' `
    'independent child minimization must preserve the DWM thumbnail surface'
Assert-DoesNotMatch 'src\Platform\WindowHierarchy.ahk' `
    '(?s)MinimizeWindow\(hwnd\).*?Win32\.SW_HIDE.*?RestoreWindowFromTaskbar' `
    'independent child minimization must not hide and discard its DWM preview'
Assert-Matches 'src\Platform\WindowHierarchy.ahk' `
    '(?s)TaskbarRegistered :=\s*this\.Platform\.RegisterTaskbarTab\(childHwnd\).*?this\.Platform\.MinimizeWindow\(childHwnd\)' `
    'taskbar registration must complete while the child still has a rendered surface'
Assert-Matches 'app\KeyMouseRemapperAssistantApp.ahk' `
    '(?s)OnSystemCommand\(.*?SC_RESTORE.*?SC_MAXIMIZE.*?RestoreChildFromTaskbar\(hwnd,.*?return 0' `
    'system taskbar restore commands must be completed by the hierarchy manager'
Assert-Matches 'app\Windows\SettingsWindow.ahk' `
    '(?s)AIConnectionStatusTop\s*:=\s*48.*?AIConnectionStatusBottom\s*:=\s*296.*?LayoutAIConnectionStatus\(message\).*?EM_GETLINECOUNT.*?wrappedLineCount \* lineHeight.*?maximumHeight := SettingsWindow\.AIConnectionStatusBottom\s*- SettingsWindow\.AIConnectionStatusTop' `
    'long AI connection errors must wrap and grow upward from the result baseline'
Assert-Matches 'app\Windows\SettingsWindow.ahk' `
    '(?s)FormatAIConnectionFailure\(message\).*?Tr\([^\r\n]+,\s*AIService\.DescribeConnectionFailure\(message\)\)' `
    'AI connection failures must display the concrete classified cause'
Assert-DoesNotMatch 'app\Windows\MappingBlockEditor.ahk' `
    'AI 请求失败：\{1\}' `
    'AI rule requests must not expose raw service exceptions'
Assert-Matches 'app\Windows\MappingBlockEditor.ahk' `
    '(?s)this\.Status := this\.Gui\.Add\("Edit".*?ReadOnly Multi Wrap.*?RegisterTextInput\(this\.Status, "", "text", true\).*?GetStatusLayout\(height, aiButtonX, layoutRound\).*?MeasureTextHeight\(\s*this\.Status.*?EditorHeight' `
    'long mapping-editor statuses must be copyable, caret-free, wrapped, and included in editor layout'
Assert-Matches 'app\Windows\MappingBlockEditor.ahk' `
    '(?s)result\.Status == AtomicControlLayout\.Applied && result\.Changed\s*this\.RefreshCommandButtons\(\).*?RefreshCommandButtons\(\*\).*?this\.AiButton, this\.SaveButton, this\.CancelButton.*?this\.Interactions\.Redraw\(button\.Hwnd\)' `
    'status-driven layout repaint must redraw every unchanged editor command button'
Assert-Matches 'app\Windows\MappingBlockEditor.ahk' `
    '(?s)catch as validationError.*?SetStatus\(Tr\("[^\r\n"]+\{1\}".*?validationError\.Message\) "`n".*?Tr\("[^\r\n"]+"\), true\).*?return false' `
    'invalid AI rules must preserve the editor content and explain that outcome'
Assert-DoesNotMatch 'src\Core\RuleSpec.ahk' `
    'invalidFileNamePattern|Windows 文件名非法字符|不能以点号结尾|不能以空白字符开头或结尾' `
    'rule identifiers must not inherit restrictions from Windows file names'
Assert-Matches 'src\Core\RuleSpec.ahk' `
    '(?s)NormalizeId\(value.*?RegExReplace\(normalized,\s*"\^\[\\p\{Zs\}\\t\]\+\|\[\\p\{Zs\}\\t\]\+\$".*?RegExMatch\(normalized, "\[\\p\{C\}\\p\{Zl\}\\p\{Zp\}\]"\)' `
    'rule identifiers must trim harmless horizontal padding while retaining control-character validation'
Assert-Matches 'src\Core\AIService.ahk' `
    '(?s)TestConnection\(settings, callback\).*?"role", "user", "content", "hello".*?"connection-test".*?entry\.Target\.Url' `
    'AI connection testing must use a minimal request and return the successful target'
Assert-Matches 'app\Windows\SettingsWindow.ahk' `
    '(?s)promptRowWidth := promptLabelWidth \+ 12 \+ 80.*?promptRowX :=.*?Floor\(\(clientWidth - promptRowWidth\) / 2\).*?AIPromptsButton\.Move\(promptRowX \+ promptLabelWidth \+ 12\)' `
    'the merged AI prompt label and action must be centered as one row'
Assert-Matches 'app\Windows\SettingsWindow.ahk' `
    'tabLabels := \[Tr\(' `
    'the unified prompt editor must expose all three prompt labels'
Assert-Matches 'app\Windows\SettingsWindow.ahk' `
    'this\.SystemEdit\.Visible := index == 3' `
    'the unified prompt editor must switch among generation, optimization, and system instructions'
Assert-Matches 'app\Windows\SettingsWindow.ahk' `
    '(?s)class AIPromptsEditor.*?WindowWidth := 620.*?WindowHeight := 440.*?GenerateEdit :=.*?x16 y56 w588 h316 Multi WantTab Wrap VScroll -HScroll.*?OptimizeEdit :=.*?x16 y56 w588 h316 Multi WantTab Wrap VScroll -HScroll.*?SystemEdit :=.*?x16 y56 w588 h316 Multi WantTab Wrap VScroll -HScroll' `
    'all compact prompt views must share one non-overlapping wrapped editor area'
Assert-DoesNotMatch 'app\Windows\SettingsWindow.ahk' `
    'SystemHint' `
    'the system prompt editor must not retain the overlapping hint control'
Assert-Matches 'app\Windows\SettingsWindow.ahk' `
    '(?s)BuildRulesAndEventTab\(\).*?AddActionButton\(groupX, 68,.*?ChooseImportRulePackage.*?AddActionButton\(groupX, 108,.*?ChooseExportRulePackage.*?RuleEventDivider.*?y162.*?AddMenuLabel\(4, 182,.*?AddSettingsEdit\(4, 0, 206,.*?EscapeCancelCheck.*?y242.*?EventAutoScrollCheck.*?y274.*?AlignEventTabControls\(\).*?ApplySparseMenuTopSpacing\(4\).*?this\.TabBuilt\[4\] := true' `
    'rule-package actions and event settings must share one vertically arranged tab'

Write-Host 'PASS ui-visual-contract-tests.ps1'
