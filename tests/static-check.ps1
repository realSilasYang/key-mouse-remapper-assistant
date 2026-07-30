$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$entryPath = Join-Path $projectRoot '键鼠重映射小助手.ahk'
$entry = Get-Content -LiteralPath $entryPath -Raw -Encoding UTF8
$failures = [System.Collections.Generic.List[string]]::new()

foreach ($required in @(
    'README.md', 'CHANGELOG.md', 'LICENSE', 'VERSION', 'CONTRIBUTING.md',
    'THIRD_PARTY_NOTICES.md',
    'docs\architecture.md', 'docs\rulespec-v2.md', 'docs\migration.md',
    'docs\security-and-limits.md', 'docs\packaging.md', 'docs\cli.md',
    'docs\localization.md',
    'SECURITY.md', 'CODE_OF_CONDUCT.md', 'assets\app\key-mouse-remapper-assistant.ico',
    'key-mouse-remapper-assistant-cli.ahk', '键鼠重映射小助手-CLI.ps1',
    'docs\validation-matrix.md',
    'assets\app\key-mouse-remapper-assistant.png',
    'assets\app\key-mouse-remapper-assistant.svg', 'tools\build-release.ps1',
    'tests\release-artifact-tests.ps1', 'tests\font-assets-tests.ps1',
    'tools\toolchain.lock.json', '.github\workflows\ci.yml',
    '.github\workflows\release.yml', 'src\Platform\Win32.ahk',
    'src\Core\BoundedFileReader.ahk',
    'src\Process\WorkerEventBuffer.ahk',
    'src\UI\ListViewPseudoHeader.ahk',
    'src\Localization\EnglishStrings.ahk',
    'src\Localization\TraditionalHongKongStrings.ahk',
    'src\Localization\TraditionalTaiwanStrings.ahk',
    'src\Localization\JapaneseStrings.ahk',
    'src\Localization\VietnameseStrings.ahk',
    'src\Localization\KoreanStrings.ahk',
    'src\Localization\SpanishStrings.ahk',
    'src\Localization\FrenchStrings.ahk',
    'src\Localization\PortugueseBrazilStrings.ahk',
    'src\Localization\RussianStrings.ahk',
    'src\Localization\GermanStrings.ahk',
    'src\Localization\ItalianStrings.ahk',
    'app\UI\ListViewSelectionPresenter.ahk',
    'app\UI\DarkMessageBox.ahk',
    'app\Windows\DarkTooltipWindow.ahk',
    'app\Windows\MappingContextPopupWindow.ahk',
    'app\Windows\SupportInfoWindow.ahk',
    'app\Windows\HelpWindow.ahk',
    'app\Windows\DonationWindow.ahk',
    'src\UI\SvgRenderLibrary.ahk',
    'src\UI\ControlAccessibilityService.ahk',
    'assets\ui-icons\lucide\settings.svg',
    'assets\ui-icons\lucide\square-plus.svg',
    'assets\ui-icons\lucide\circle-pause.svg',
    'assets\ui-icons\lucide\play.svg',
    'assets\ui-icons\lucide\trash-2.svg',
    'assets\ui-icons\lucide\logs.svg',
    'assets\ui-icons\lucide\keyboard.svg',
    'assets\ui-icons\lucide\mouse.svg',
    'assets\ui-icons\lucide\arrow-right.svg',
    'assets\ui-icons\lucide\save.svg',
    'assets\ui-icons\lucide\eraser.svg',
    'assets\ui-icons\lucide\x.svg',
    'assets\ui-icons\lucide\pencil.svg',
    'assets\ui-icons\lucide\file-output.svg',
    'assets\ui-icons\lucide\circle-check-big.svg',
    'assets\ui-icons\lucide\circle-question-mark.svg',
    'assets\ui-icons\lucide\heart.svg',
    'assets\ui-icons\lucide\book-open.svg',
    'assets\ui-icons\lucide\message-square-text.svg',
    'assets\donate\微信个人收款码.png',
    'assets\donate\微信个人收款码-界面.png',
    'assets\donate\支付宝个人收款码.png',
    'assets\donate\支付宝个人收款码-界面.png',
    'assets\fonts\NotoSans-Variable.ttf', 'assets\fonts\NotoSansCJK.ttc',
    'assets\fonts\OFL-1.1.txt',
    'assets\fonts\metadata.json',
    'third_party\resvg\resvg.dll', 'third_party\resvg\VERSION.txt')) {
    if (-not (Test-Path -LiteralPath (Join-Path $projectRoot $required))) {
        $failures.Add("Missing required project file: $required")
    }
}

if ([regex]::Matches($entry, '(?m)^; === 重映射代码区域开始 ===\r?$').Count -ne 1 -or
    [regex]::Matches($entry, '(?m)^; === 重映射代码区域结束 ===\r?$').Count -ne 1) {
    $failures.Add('The entry must contain exactly one outer mapping region.')
}
$beginCount = [regex]::Matches($entry, '(?m)^; @mapping-begin\r?$').Count
$endCount = [regex]::Matches($entry, '(?m)^; @mapping-end\r?$').Count
if ($beginCount -eq 0 -or $beginCount -ne $endCount) {
    $failures.Add("Mapping block markers are unbalanced: $beginCount/$endCount")
}
if ($entry -match '(?m)^class\s+') {
    $failures.Add('Classes must live in app/ or src/, not the entry script.')
}

$interactionPath = Join-Path $projectRoot 'src\UI\MappingUiInteractions.ahk'
$interaction = Get-Content -LiteralPath $interactionPath -Raw -Encoding UTF8
$buttonPainter = Get-Content -LiteralPath (Join-Path $projectRoot `
    'src\UI\RoundedButtonPainter.ahk') -Raw -Encoding UTF8
$themePath = Join-Path $projectRoot 'src\UI\ThemeHelpers.ahk'
$theme = Get-Content -LiteralPath $themePath -Raw -Encoding UTF8
$themeServicePath = Join-Path $projectRoot 'src\UI\UiThemeService.ahk'
$themeService = Get-Content -LiteralPath $themeServicePath -Raw -Encoding UTF8
if ($interaction -notmatch 'SS_NOTIFY\(0x100\)' -or
    $interaction -notmatch 'control\.Opt\("\+0x100 \+0x10000"\)' -or
    $interaction -notmatch 'ActivateButtonFromKeyboard' -or
    $interaction -notmatch 'wParam == 0x0D \|\| wParam == 0x20' -or
    $interaction -notmatch '\), -50\)') {
    $failures.Add('Self-drawn buttons must retain SS_NOTIFY, tab focus, and 50ms keyboard feedback.')
}
$accessibility = Get-Content -LiteralPath (Join-Path $projectRoot `
    'src\UI\ControlAccessibilityService.ahk') -Raw -Encoding UTF8
if ($interaction -notmatch 'ControlAccessibilityService\.RegisterButton' -or
    $interaction -notmatch 'ControlAccessibilityService\.ClearButton' -or
    $accessibility -notmatch 'IAccPropServices|RolePushButton' -or
    $accessibility -notmatch 'PropertyDefaultAction') {
    $failures.Add('Owner-drawn buttons must retain MSAA push-button and default-action semantics.')
}
if ($interaction -notmatch 'RegisterIconSurface\(' -or
    $interaction -notmatch 'SetControlLucideIcon\(' -or
    $interaction -notmatch 'TintIconSnapshot\(' -or
    $interaction -notmatch 'RefreshAutomaticIconTint\(' -or
    $interaction -notmatch 'tintColor := "none"' -or
    $buttonPainter -notmatch 'class TextVisualAlignment' -or
    $buttonPainter -notmatch 'MeasureInkBounds\(' -or
    $buttonPainter -notmatch 'CreateCenteredTextRect\(' -or
    $buttonPainter -notmatch 'multiline \? 0x00000810 : 0x00008824') {
    $failures.Add('Lucide controls must preserve semantic colors, support explicit tinting and multiline text, and align visible text ink with icon centers.')
}
if ($interaction -notmatch
        'RunClick\(hwnd,[\s\S]*?state\.Kind == "button" && !state\.Interactive' -or
    $interaction -notmatch 'MoveKeyboardFocus\(hwnd\)' -or
    $interaction -notmatch 'RegisterTextInput\(' -or
    $interaction -notmatch 'OnGlobalPointerDown\(' -or
    $interaction -notmatch 'TextInputTargets' -or
    $theme -notmatch 'EM_CHARFROMPOS' -or
    $theme -notmatch 'GetCenteredSingleLineEditHeight' -or
    $theme -match 'ShowCaret|HideCaret') {
    $failures.Add('Text inputs must use real global blur routing, pointer-based caret placement, and native-height vertical centering.')
}
if ($themeService -notmatch 'GetUxThemeFunction\(135\)' -or
    $themeService -notmatch 'GetUxThemeFunction\(133\)' -or
    $theme -notmatch 'DarkMode_Explorer' -or
    $theme -notmatch 'DarkMode_ItemsView' -or
    $theme -notmatch 'RedrawWindow' -or
    $themeService -notmatch 'LightPalette|F1F5F9') {
    $failures.Add('Native themes must cover both palettes, the process, controls, scrollbars, header, and redraw.')
}
if ($themeService -notmatch 'HandleSystemSettingChange' -or
    $themeService -notmatch 'static Color\(name\)') {
    $failures.Add('Theme roles and system-theme hot switching are incomplete.')
}
$mappingWindow = Get-Content -LiteralPath (Join-Path $projectRoot `
    'app\Windows\MappingWindow.ahk') -Raw -Encoding UTF8
$mappingEditor = Get-Content -LiteralPath (Join-Path $projectRoot `
    'app\Windows\MappingBlockEditor.ahk') -Raw -Encoding UTF8
$settingsWindow = Get-Content -LiteralPath (Join-Path $projectRoot `
    'app\Windows\SettingsWindow.ahk') -Raw -Encoding UTF8
$eventViewerWindow = Get-Content -LiteralPath (Join-Path $projectRoot `
    'app\Windows\EventViewerWindow.ahk') -Raw -Encoding UTF8
$supportInfoWindow = Get-Content -LiteralPath (Join-Path $projectRoot `
    'app\Windows\SupportInfoWindow.ahk') -Raw -Encoding UTF8
$helpWindow = Get-Content -LiteralPath (Join-Path $projectRoot `
    'app\Windows\HelpWindow.ahk') -Raw -Encoding UTF8
$donationWindow = Get-Content -LiteralPath (Join-Path $projectRoot `
    'app\Windows\DonationWindow.ahk') -Raw -Encoding UTF8
$contextPopupWindow = Get-Content -LiteralPath (Join-Path $projectRoot `
    'app\Windows\MappingContextPopupWindow.ahk') -Raw -Encoding UTF8
$applicationIcon = Get-Content -LiteralPath (Join-Path $projectRoot `
    'src\UI\ApplicationIcon.ahk') -Raw -Encoding UTF8
$guiInteractionTest = Get-Content -LiteralPath (Join-Path $projectRoot `
    'tests\gui\gui-interaction-smoke-tests.ahk') -Raw -Encoding UTF8
$localizedAppearanceTest = Get-Content -LiteralPath (Join-Path $projectRoot `
    'tests\gui\localized-appearance-smoke-tests.ahk') -Raw -Encoding UTF8
$testSupport = Get-Content -LiteralPath (Join-Path $projectRoot `
    'tests\TestSupport.ahk') -Raw -Encoding UTF8
$iconBuildScript = Get-Content -LiteralPath (Join-Path $projectRoot `
    'tools\build-icon.ps1') -Raw -Encoding UTF8
$localizationService = Get-Content -LiteralPath (Join-Path $projectRoot `
    'src\Localization\LocalizationService.ahk') -Raw -Encoding UTF8
$appController = Get-Content -LiteralPath (Join-Path $projectRoot `
    'app\KeyMouseRemapperAssistantApp.ahk') -Raw -Encoding UTF8
$keyCapture = Get-Content -LiteralPath (Join-Path $projectRoot `
    'src\Input\KeyCaptureSession.ahk') -Raw -Encoding UTF8
$inputWorkerEntry = Get-Content -LiteralPath (Join-Path $projectRoot `
    'workers\input-engine-worker.ahk') -Raw -Encoding UTF8
$inputWorker = Get-Content -LiteralPath (Join-Path $projectRoot `
    'src\Workers\InputEngineWorker.ahk') -Raw -Encoding UTF8
$workerController = Get-Content -LiteralPath (Join-Path $projectRoot `
    'src\Process\InputWorkerController.ahk') -Raw -Encoding UTF8
$workerEventBuffer = Get-Content -LiteralPath (Join-Path $projectRoot `
    'src\Process\WorkerEventBuffer.ahk') -Raw -Encoding UTF8
$authenticatedIpc = Get-Content -LiteralPath (Join-Path $projectRoot `
    'src\Core\AuthenticatedIpcProtocol.ahk') -Raw -Encoding UTF8
$namedPipeChannel = Get-Content -LiteralPath (Join-Path $projectRoot `
    'src\Platform\NamedPipeChannel.ahk') -Raw -Encoding UTF8
$mappingRepository = Get-Content -LiteralPath (Join-Path $projectRoot `
    'src\Core\MappingCodeRepository.ahk') -Raw -Encoding UTF8
$rulePackageService = Get-Content -LiteralPath (Join-Path $projectRoot `
    'src\Core\RulePackageService.ahk') -Raw -Encoding UTF8
if ($appController -notmatch 'OnExit\(this\.ExitCallback,\s*0\)' -or
        $inputWorker -notmatch 'OnExit\(this\.ExitCallback,\s*0\)') {
    $failures.Add('Manual application and worker shutdown must unregister global OnExit callbacks.')
}
$shellIdentityCallIndex = $entry.IndexOf('ConfigureApplicationShellIdentity()')
$appConstructionIndex = $entry.IndexOf('global App := KeyMouseRemapperAssistantApp()')
if ($applicationIcon -notmatch
        'return\s+"realSilasYang\.KeyMouseRemapperAssistant"' -or
    $applicationIcon -notmatch 'SetCurrentProcessExplicitAppUserModelID' -or
    $applicationIcon -notmatch 'GetSystemMetrics' -or
    $shellIdentityCallIndex -lt 0 -or $appConstructionIndex -lt 0 -or
    $shellIdentityCallIndex -ge $appConstructionIndex) {
    $failures.Add('The process must declare its stable shell identity before constructing the first application window and load system-sized icon frames.')
}
if ($iconBuildScript -match 'master(?:\.normalized)?\.png' -or
    $iconBuildScript -notmatch 'key-mouse-remapper-assistant\.png' -or
    $iconBuildScript -notmatch 'key-mouse-remapper-assistant\.svg') {
    $failures.Add('Icon generation must use only the canonical SVG, PNG, and ICO asset names.')
}
if ($mappingEditor -notmatch 'SetCodeText\(text\)' -or
    $mappingEditor -notmatch 'BeginStableWindowUpdate\(this\.Gui\.Hwnd\)[\s\S]{0,1000}ControlSetText\(String\(text\)' -or
    $guiInteractionTest -match 'ControlSetText\(fontEditor\.' -or
    $theme -notmatch 'KEY_MOUSE_REMAPPER_GUI_TEST_OFFSCREEN' -or
    $guiInteractionTest -notmatch 'AssertTestWindowOffscreen\(' -or
    $localizedAppearanceTest -notmatch 'AssertTestWindowOffscreen\(' -or
    $testSupport -notmatch 'ShowOffscreenTestMappingWindow\(') {
    $failures.Add('GUI tests must stay offscreen, and programmatic RichEdit replacement must publish only a fully formatted frame.')
}
if ($settingsWindow -match 'this\.Title\s*:=' -or
    $settingsWindow -notmatch 'CompactWidth\s*:=\s*520' -or
    $settingsWindow -notmatch 'ExpandedWidth\s*:=\s*680' -or
    $settingsWindow -notmatch 'ClientHeight\s*:=\s*330' -or
    $settingsWindow -notmatch 'BuildAboutTab' -or
    $settingsWindow -notmatch 'SuspendTabRedraw' -or
    $settingsWindow -notmatch 'CenterOverOwner' -or
    $settingsWindow -notmatch 'CalculateCenteredPosition' -or
    $settingsWindow -notmatch 'MonitorFromWindow' -or
    $settingsWindow -notmatch 'GetMonitorInfoW' -or
    $settingsWindow -notmatch 'Tr\("通用"\).*Tr\("录制"\).*Tr\("事件"\).*Tr\("关于"\)' -or
    $settingsWindow -notmatch 'Tr\("保存"\)' -or
    $settingsWindow -notmatch 'Tr\("取消"\)' -or
    $settingsWindow -notmatch 'RefreshFontDropDown' -or
    $settingsWindow -notmatch 'ApplyApplicationWindowIcon') {
    $failures.Add('SettingsWindow must follow the latest compact assistant layout and controls.')
}
if ($localizationService -notmatch 'AddFontResourceExW' -or
    $localizationService -notmatch 'RemoveFontResourceExW' -or
    $localizationService -notmatch 'FailedPrivateUiFonts' -or
    $localizationService -notmatch 'Primary:\s*"Noto Sans CJK SC"' -or
    $localizationService -notmatch 'Primary:\s*"Noto Sans CJK JP"' -or
    $localizationService -notmatch 'Primary:\s*"Noto Sans CJK KR"' -or
    $localizationService -notmatch 'Primary:\s*"Noto Sans"' -or
    $localizationService -match
        'PingFang|SF Pro Text|AppleSDGothic|Harano Aji' -or
    $appController -notmatch 'ShutdownUiFonts') {
    $failures.Add('Language-aware private UI font loading and shutdown cleanup are incomplete.')
}
if ($theme -notmatch 'AddComboBoxDisplayPadding' -or
    $theme -notmatch 'ApplyDarkComboBoxTheme' -or
    $theme -notmatch 'DarkComboBoxListThemeRegistry' -or
    $theme -notmatch 'UnregisterMessageIfUnused' -or
    $theme -notmatch 'OnMessage\(0x0134, this\.MessageCallback, 0\)' -or
    $theme -notmatch 'RemoveComboBoxBorder') {
    $failures.Add('Settings drop-downs must match the assistant padding, border, and popup theming.')
}
$preparedSecondaryWindows = [ordered]@{
    'event viewer' = $eventViewerWindow
    'settings' = $settingsWindow
    'mapping editor' = $mappingEditor
}
foreach ($windowName in $preparedSecondaryWindows.Keys) {
    $windowText = $preparedSecondaryWindows[$windowName]
    if ($windowText -notmatch 'ShowPreparedWindow\(' -or
        $windowText -notmatch 'ApplyDarkWindow\(') {
        $failures.Add("$windowName must use the shared themed first-show pipeline.")
    }
}
$listViewWindows = [ordered]@{
    'main mapping list' = $mappingWindow
    'event viewer list' = $eventViewerWindow
}
foreach ($listName in $listViewWindows.Keys) {
    $windowText = $listViewWindows[$listName]
    if ($windowText -notmatch 'ListViewPseudoHeader\(' -or
        $windowText -notmatch 'ListViewSelectionPresenter\(') {
        $failures.Add("$listName must share pseudo headers and rounded selection rendering.")
    }
}
if ($eventViewerWindow -match '\[Tr\("序号"\),\s*Tr\("时间"\)' -or
    $eventViewerWindow -notmatch 'static\s+DetailColumn\s*:=\s*6' -or
    $eventViewerWindow -notmatch 'static\s+EventColumnWidth\s*:=\s*184' -or
    $eventViewerWindow -notmatch '" -Border -E0x200 Background"' -or
    $eventViewerWindow -notmatch 'LVM_MAPINDEXTOID' -or
    $eventViewerWindow -notmatch 'LVM_MAPIDTOINDEX') {
    $failures.Add('The event viewer must expose six borderless columns and keep sequence IDs internal while giving the removed width to Event.')
}
if ($mappingWindow -notmatch
        'if\s+!this\.Interactions\.RegisterTextInput\(this\.PurposeEdit' -or
    $mappingEditor -notmatch
        'if\s+!this\.Interactions\.RegisterTextInput\(this\.CodeEdit') {
    $failures.Add('Every editable surface must fail closed when shared caret and blur routing cannot attach.')
}
$runtimeSourceFiles = @(Get-ChildItem -LiteralPath @(
        (Join-Path $projectRoot 'app'), (Join-Path $projectRoot 'src')) `
        -Recurse -File -Filter '*.ahk')
$runtimeSourceText = ($runtimeSourceFiles | ForEach-Object {
        Get-Content -LiteralPath $_.FullName -Raw -Encoding UTF8
    }) -join "`n"
$productionAhkFiles = @($runtimeSourceFiles) + @(
    Get-ChildItem -LiteralPath (Join-Path $projectRoot 'workers') `
        -File -Filter '*.ahk') + @(
    Get-Item -LiteralPath $entryPath,
        (Join-Path $projectRoot 'key-mouse-remapper-assistant-cli.ahk'))
$productionAhkText = ($productionAhkFiles | ForEach-Object {
        Get-Content -LiteralPath $_.FullName -Raw -Encoding UTF8
    }) -join "`n"
$directFileReadFiles = @($productionAhkFiles | Where-Object {
        (Get-Content -LiteralPath $_.FullName -Raw -Encoding UTF8) -match
            '\bFileRead\s*\('
    })
$expectedSvgReader = Join-Path $projectRoot 'src\UI\SvgRenderLibrary.ahk'
$svgReaderSource = if ($directFileReadFiles.Count -eq 1) {
    Get-Content -LiteralPath $directFileReadFiles[0].FullName -Raw -Encoding UTF8
} else { '' }
if ($runtimeSourceText -match '\bIniRead\s*\(' -or
        $directFileReadFiles.Count -ne 1 -or
        $directFileReadFiles[0].FullName -cne $expectedSvgReader -or
        $svgReaderSource -notmatch 'MaximumInputBytes' -or
        $svgReaderSource -notmatch
            'IsValidSourceBuffer\(svgData, sourceSize\)') {
    $failures.Add('Persistent runtime text must use BoundedFileReader; only the independently size-bounded SVG binary reader may call FileRead directly.')
}
if ($runtimeSourceText -match '\bContextMenuPresenter\b' -or
    $runtimeSourceText -match '(?m)^\s*\w*(?:Context)?Menu\s*:=\s*Menu\(') {
    $failures.Add('Runtime windows must not reintroduce blocking native context menus.')
}
if ($runtimeSourceText -match '💾|🧹|✖|✏|→') {
    $failures.Add('Runtime controls must use Lucide assets except for the assistant-style main Add/Pause/Delete Emoji commands.')
}
$lucideContracts = [ordered]@{
    'main window' = @($mappingWindow, 'settings.svg|keyboard.svg|mouse.svg|arrow-right.svg|save.svg|eraser.svg')
    'mapping editor' = @($mappingEditor, 'save.svg|x.svg')
    'event viewer' = @($eventViewerWindow, 'circle-pause.svg|play.svg|eraser.svg|file-output.svg')
    'settings window' = @($settingsWindow, 'save.svg|x.svg')
    'mapping context popup' = @($contextPopupWindow, 'pencil.svg')
}
if ($mappingWindow -match 'square-plus\.svg|circle-pause\.svg|play\.svg|trash-2\.svg') {
    $failures.Add('Main Add/Pause/Delete commands must use the same Emoji text treatment as the assistant, not Lucide images.')
}
if ($mappingWindow -match '\bEventButton\b' -or
    $mappingWindow -notmatch 'GetToolbarButtonPositions\(clientWidth\)') {
    $failures.Add('The main toolbar must expose Event Viewer only through Help Info.')
}
foreach ($contractName in $lucideContracts.Keys) {
    $windowSource = $lucideContracts[$contractName][0]
    foreach ($iconName in $lucideContracts[$contractName][1].Split('|')) {
        if ($windowSource -notmatch [regex]::Escape($iconName)) {
            $failures.Add("Missing semantic Lucide icon in ${contractName}: $iconName")
        }
    }
}
$mappingWindowConstructor = [regex]::Match($mappingWindow,
    '__New\(app\)\s*\{(?<body>[\s\S]*?)\r?\n    BuildControls\(\)')
if (-not $mappingWindowConstructor.Success -or
    $mappingWindowConstructor.Groups['body'].Value -notmatch
        'this\.DragActive\s*:=\s*false') {
    $failures.Add('MappingWindow must initialize drag state in its constructor.')
}
if ($mappingWindow -notmatch 'SetTimer\(this\.ThemeTimer,\s*-120\)' -or
    $mappingEditor -notmatch 'SetTimer\(this\.ThemeTimer,\s*-120\)') {
    $failures.Add('Native dark themes must be reapplied after ListView and RichEdit are shown.')
}
if ($mappingWindow -notmatch 'RestoreCustomOrder\(showStatus' -or
    $mappingWindow -notmatch 'ListViewPseudoHeader\(' -or
    $mappingWindow -notmatch 'SequenceColumn\s*:=\s*1' -or
    $mappingWindow -notmatch 'SkipAscending:\s*true' -or
    $mappingWindow -notmatch 'RestoreSortOptions:\s*"Integer Center"' -or
    $mappingWindow -notmatch 'this\.List\.Add\("",\s*customOrder') {
    $failures.Add('Pseudo headers must expose an assistant-style centered sequence column with descending/default cycling.')
}
if ($keyCapture -match 'InputHook\(|SetWindowsHookEx|GetAsyncKeyState|HotIf\(' -or
        $keyCapture -notmatch 'ObserveRawInputEvent\(' -or
        $keyCapture -notmatch 'SelectCaptureDevice\(' -or
        $keyCapture -notmatch 'this\.App\.Runtime\.Backend\.Suspend\(\)') {
    $failures.Add('Recording must consume Raw Input identities without installing a second hook path.')
}
if ($inputWorkerEntry -notmatch '(?m)^#NoTrayIcon\r?$' -or
    $inputWorkerEntry -notmatch '(?m)^#SingleInstance Off\r?$' -or
    $inputWorkerEntry -notmatch
        'if\s+!WorkerBootstrap\.ApplyFromArguments\(A_Args\)' -or
    $inputWorkerEntry -notmatch 'WorkerEventBuffer\.ahk' -or
    $inputWorker -notmatch 'ParentTimeoutMs\s*:=\s*15000' -or
    $workerController -notmatch 'WorkerTimeoutMs\s*:=\s*15000' -or
    $workerController -notmatch 'activeState\s*:=\s*state[\s\S]{0,160}WriteMessage\(state,\s*"heartbeat"' -or
    $workerEventBuffer -notmatch 'class WorkerEventBuffer' -or
    $inputWorker -notmatch 'FlushObservationEvents\(' -or
    $authenticatedIpc -notmatch 'TrySendMessage\(' -or
    $namedPipeChannel -notmatch 'TryWrite\(' -or
    $workerController -match
        'ProfileSwitchTimer|SwitchProfile|KMR_PROFILE_PATH') {
    $failures.Add('The trayless Raw Input worker must tolerate observation backpressure and remain authenticated and supervised.')
}
if ($keyCapture -notmatch 'HandleRawDown\(' -or
        $keyCapture -notmatch 'HandleRawUp\(' -or
        $keyCapture -notmatch 'HandleDeviceRemoval\(' -or
        $keyCapture -notmatch 'CompletePendingCapture\(\)' -or
        $keyCapture -notmatch 'this\.HeldKeys\.Count' -or
        $keyCapture -notmatch 'RecordedKeys') {
    $failures.Add('Raw Input recording must accumulate unique keys and finish on release or device removal.')
}
if ($mappingRepository -notmatch 'ToggleEnabled\(mappingId\)' -or
    $mappingRepository -notmatch 'ValidateCommentOnlyRegion\(regionBody\)' -or
    $mappingWindow -notmatch 'ToggleSelectedMapping') {
    $failures.Add('Selected managed mappings must pause via RuleSpec, and the mapping region must reject executable AHK.')
}
if ($mappingWindow -match 'MoveUpButton|MoveDownButton|MoveSelected' -or
    $mappingWindow -notmatch 'OnNotify\(-109' -or
    $mappingWindow -notmatch '0x10A6' -or
    $mappingRepository -notmatch 'MoveTo\(mappingId, targetIndex\)' -or
    $mappingWindow -notmatch 'ApplyMappingMove\(mappingId, sourceRow, targetIndex\)') {
    $failures.Add('ListView drag sorting must replace the old move-up and move-down controls.')
}
if ($mappingWindow -notmatch 'AutoScrollListDuringDrag' -or
    $mappingWindow -notmatch 'MoveListRow\(sourceRow, targetIndex, rowValues\)' -or
    $mappingWindow -notmatch 'CellTooltip\.Hide\(\)') {
    $failures.Add('Drag sorting must auto-scroll, roll back UI failures, and close transient tooltips.')
}
$tooltipWindow = Get-Content -LiteralPath (Join-Path $projectRoot `
    'app\Windows\ListCellTooltipWindow.ahk') -Raw -Encoding UTF8
if ($tooltipWindow -notmatch 'IsCellClipped' -or
    $tooltipWindow -notmatch 'GetTextExtentPoint32W' -or
    $tooltipWindow -notmatch '0x1039' -or
    $tooltipWindow -notmatch 'MinimumColumn' -or
    $tooltipWindow -notmatch 'MaximumColumn' -or
    $tooltipWindow -notmatch 'WidthCache') {
    $failures.Add('Clipped ListView cells must expose measured full-text hover hints.')
}
$buttonTooltipWindow = Get-Content -LiteralPath (Join-Path $projectRoot `
    'app\Windows\DarkTooltipWindow.ahk') -Raw -Encoding UTF8
if ($interaction -notmatch 'SetButtonTooltip\(' -or
    $interaction -notmatch 'EnsureTooltip\(\)\.Schedule' -or
    $buttonTooltipWindow -notmatch '\+E0x08000020' -or
    $buttonTooltipWindow -notmatch 'GetWorkArea' -or
    $buttonTooltipWindow -notmatch 'NoActivate') {
    $failures.Add('Owner-drawn buttons must use the shared DPI-aware, non-activating themed tooltip.')
}
$appController = Get-Content -LiteralPath (Join-Path $projectRoot `
    'app\KeyMouseRemapperAssistantApp.ahk') -Raw -Encoding UTF8
if ($mappingWindow -notmatch
        'this\.GetAddButtonText\(\)[\s\S]{0,160}ObjBindMethod\(this, "OpenNewMappingEditor"\)' -or
    $mappingWindow -notmatch 'MappingBlockEditor\(this, mapping, true\)' -or
    $mappingEditor -notmatch 'this\.IsNew\s*:=\s*isNew' -or
    $mappingEditor -notmatch 'this\.OwnerWindow\.App\.AddMappingBlock' -or
    $mappingRepository -notmatch 'CreateBlankBlock\(\)' -or
    $mappingRepository -notmatch 'AppendBlock\(blockText\)' -or
    $appController -notmatch 'AddMappingBlock\(blockText\)' -or
    $appController -notmatch 'this\.Window\.AddMappingRow\(mapping, this\.MappingCount\)') {
    $failures.Add('The toolbar Add command must open a blank mapping editor and append valid code to source and ListView.')
}
if ($mappingRepository -notmatch 'StartLine:' -or
    $mappingRepository -notmatch 'GetAppendStartLine\(\)' -or
    $mappingEditor -notmatch 'LineNumberEdit' -or
    $mappingEditor -notmatch 'ClassRICHEDIT50W[\s\S]{0,100}\+0x00000886' -or
    $mappingEditor -notmatch 'SyncLineNumberScroll\(\)' -or
    $mappingEditor -notmatch 'ApplySyntaxHighlighting\(' -or
    $mappingEditor -notmatch 'RegisterFocusRedirect\(this\.LineNumberEdit' -or
    $mappingEditor -notmatch 'CodeComment|CodeVariable|CodeValue' -or
    $themeService -notmatch 'CodeLineNumber|CodeComment|CodeVariable|CodeValue') {
    $failures.Add('Mapping editors must expose source line numbers and themed comment/metadata syntax highlighting.')
}
$toolbarButtonPositions = @(
    $mappingWindow.IndexOf('this.AddButton :='),
    $mappingWindow.IndexOf('this.PauseResumeButton :='),
    $mappingWindow.IndexOf('this.DeleteButton :=')
)
$toolbarButtonOrderValid = $toolbarButtonPositions[0] -ge 0
for ($toolbarIndex = 1; $toolbarIndex -lt $toolbarButtonPositions.Count;
        $toolbarIndex++) {
    $toolbarButtonOrderValid = $toolbarButtonOrderValid -and
        $toolbarButtonPositions[$toolbarIndex - 1] -lt
            $toolbarButtonPositions[$toolbarIndex]
}
if ($mappingWindow -match 'ReloadButton|🔄 重新加载' -or
    $appController -notmatch 'A_TrayMenu\.Add\(Tr\("重新加载"\)' -or
    -not $toolbarButtonOrderValid -or
    $mappingWindow -notmatch 'PauseDisabled' -or
    $mappingWindow -notmatch 'DeleteDisabled' -or
    $mappingWindow -notmatch 'SetButtonAppearance\(this\.PauseResumeButton' -or
    $mappingWindow -notmatch 'SetButtonAppearance\(this\.DeleteButton' -or
    $mappingWindow -notmatch 'this\.SettingsButton\.Move\(' -or
    $mappingWindow -notmatch 'SettingsButtonWidth\s*:=\s*100' -or
    $mappingWindow -notmatch 'SettingsButtonHeight\s*:=\s*30' -or
    $mappingWindow -notmatch 'Icon:\s*"settings\.svg"' -or
    $mappingWindow -notmatch 'Icon:\s*"circle-question-mark\.svg"' -or
    $mappingWindow -notmatch 'Icon:\s*"heart\.svg"' -or
    $mappingWindow -notmatch 'GetToolbarButtonPositions\(clientWidth\)' -or
    $mappingWindow -notmatch 'donateX := clientWidth[\s\S]{0,320}Support: supportX, Donate: donateX' -or
    $mappingWindow -notmatch 'GetAddButtonText\(\).*➕' -or
    $mappingWindow -notmatch 'GetPauseButtonText\(resume\s*:=\s*false\)' -or
    $mappingWindow -notmatch 'GetDeleteButtonText\(\).*🗑' -or
    $mappingWindow -notmatch 'ClearButtonIcon\(this\.PauseResumeButton\)') {
    $failures.Add('The toolbar must preserve assistant-style mapping commands and the right-side Settings, Help, Donate group, while the tray retains Reload.')
}
if ($supportInfoWindow -notmatch [regex]::Escape(
        'https://github.com/realSilasYang/key-mouse-remapper-assistant/issues/new/choose') -or
    $supportInfoWindow -notmatch 'book-open\.svg' -or
    $supportInfoWindow -notmatch 'logs\.svg' -or
    $supportInfoWindow -notmatch 'message-square-text\.svg' -or
    $supportInfoWindow -notmatch 'this\.Dispose\(false\)[\s\S]{0,120}this\.App\.OpenHelp' -or
    $supportInfoWindow -notmatch 'this\.Dispose\(false\)[\s\S]{0,120}this\.App\.OpenEventViewer' -or
    $helpWindow -notmatch 'ReadOnly Multi VScroll' -or
    $helpWindow -notmatch 'RegisterTextInput\(this\.TextEdit\)' -or
    $helpWindow -notmatch 'HideCaret' -or
    $helpWindow -notmatch 'ApplyDarkControl\(this\.TextEdit\.Hwnd\)' -or
    $donationWindow -notmatch 'MessageText\.GetPos' -or
    $donationWindow -notmatch 'Center \+0x80 BackgroundTrans' -or
    $donationWindow -notmatch '微信个人收款码-界面\.png' -or
    $donationWindow -notmatch '支付宝个人收款码-界面\.png' -or
    $donationWindow -notmatch 'MissingQrTexts' -or
    $appController -notmatch 'OpenHelpInfo\(' -or
    $appController -notmatch 'OpenHelp\(' -or
    $appController -notmatch 'OpenDonation\(' -or
    $appController -notmatch 'this\.SupportInfo\.ApplyAppearance\(' -or
    $appController -notmatch 'this\.Help\.ApplyAppearance\(' -or
    $appController -notmatch 'this\.Donation\.ApplyAppearance\(' -or
    $appController -notmatch 'this\.SupportInfo\.Dispose\(false\)' -or
    $appController -notmatch 'this\.Help\.Dispose\(false\)' -or
    $appController -notmatch 'this\.Donation\.Dispose\(false\)') {
    $failures.Add('Help routing, the built-in guide, donation QR resources, or their owned-window lifecycle is incomplete.')
}
if ($appController -notmatch 'A_TrayMenu\.Default\s*:=\s*Tr\("显示主界面"\)' -or
    $appController -notmatch 'A_TrayMenu\.ClickCount\s*:=\s*1') {
    $failures.Add('The tray icon must restore the main window with one click through its default menu item.')
}
if ($appController -notmatch 'ScheduleReload\(' -or
    $appController -notmatch 'this\.ReloadTimer\s*:=\s*ObjBindMethod' -or
    $appController -match 'SetTimer\(\(\*\)\s*=>\s*Reload' -or
    $appController -match '正在重新加载|; reloading\.') {
    $failures.Add('Script-changing commands must hot reload automatically without user-facing manual reload instructions.')
}
$moveMappingBody = [regex]::Match($appController,
    'MoveMappingTo\(mappingId, targetIndex\)\s*\{(?<body>[\s\S]*?)\r?\n    ToggleMappingEnabled\(')
if (-not $moveMappingBody.Success -or
    $moveMappingBody.Groups['body'].Value -match 'ScheduleReload|NotifyAfterReload' -or
    $moveMappingBody.Groups['body'].Value -match 'ShowToast') {
    $failures.Add('Drag sorting must update in place and must not reload the application.')
}
$historyService = Get-Content -LiteralPath (Join-Path $projectRoot `
    'src\Core\PersistentHistoryService.ahk') -Raw -Encoding UTF8
$eventTraceService = Get-Content -LiteralPath (Join-Path $projectRoot `
    'src\Core\EventTraceService.ahk') -Raw -Encoding UTF8
$historyToast = Get-Content -LiteralPath (Join-Path $projectRoot `
    'app\Windows\HistoryToastWindow.ahk') -Raw -Encoding UTF8
$localizationService = Get-Content -LiteralPath (Join-Path $projectRoot `
    'src\Localization\LocalizationService.ahk') -Raw -Encoding UTF8
if ($appController -notmatch 'OnGlobalKeyDown' -or
    $appController -notmatch 'IsGlobalModifierDown' -or
    $appController -match 'GetKeyState\("Ctrl",\s*"P"\)' -or
    $appController -notmatch 'PerformUndo' -or
    $appController -notmatch 'PerformRedo' -or
    $historyService -notmatch 'KEY_MOUSE_REMAPPER_HISTORY_V2' -or
    $historyService -notmatch 'SHORTCUT_REMAPPER_HISTORY_V2' -or
    $historyService -notmatch 'PersistStacks|RollBackAppliedState' -or
    $historyService -notmatch 'SerializeAction|DeserializeAction' -or
    $historyService -notmatch 'SetPendingNotification' -or
    $historyService -notmatch 'MaximumNotificationBytes' -or
    $historyService -notmatch 'BoundedFileReader\.ReadUtf8\(claimedPath' -or
    $eventTraceService -notmatch 'MaximumEntryTextCharacters' -or
    $eventTraceService -notmatch 'AddTextCharacters' -or
    $localizationService -notmatch 'GetLanguageChoices') {
    $failures.Add('Persistent global undo/redo, notifications, and multilingual settings are incomplete.')
}
$notifyAfterReloadCalls = [regex]::Matches($appController,
    '(?m)^\s*this\.NotifyAfterReload\(').Count
if ($notifyAfterReloadCalls -ne 2 -or
    $appController -match 'PendingToastTimer' -or
    ($appController -notmatch 'this\.ShowPendingToast\(\)' -and
        $mappingWindow -notmatch 'this\.App\.ShowPendingToast\(\)') -or
    $appController -notmatch 'BuildHistoryNotification\(entry, true\)' -or
    $appController -notmatch 'BuildHistoryNotification\(entry, false\)' -or
    $localizationService -match 'Ctrl\+Z 可撤销|Ctrl\+Shift\+Z 可重做|↶ 已撤销|↷ 已重做') {
    $failures.Add('Only successful undo and redo may queue a post-reload history result toast.')
}
if ($historyToast -notmatch '\+E0x08080000' -or
    $historyToast -notmatch 'LayoutText\(text, ownerGui,' -or
    $historyToast -notmatch 'ClientToScreen' -or
    $historyToast -notmatch 'CreateRoundRectRgn' -or
    $historyToast -notmatch 'BeginAnimation\("show"[\s\S]{0,100}160\)' -or
    $historyToast -notmatch 'BeginAnimation\("hide"[\s\S]{0,100}140\)' -or
    $historyToast -notmatch 'SetTimer\(this\.HideTimer, -3000\)' -or
    $historyToast -notmatch 'wasVisible \? 176 : 0' -or
    $historyToast -notmatch 'this\.OwnerWindow\.Status\.Hwnd' -or
    $historyToast -notmatch 'startY\s*:=\s*targetY\s*-\s*startOffset' -or
    $historyToast -notmatch 'Reposition\(\*\)') {
    $failures.Add('History feedback must match the assistant measured, rounded, animated three-second toast.')
}
$resizeBody = [regex]::Match($mappingWindow,
    'OnResize\(guiObj,\s*minMax,\s*width,\s*height\)\s*\{(?<body>[\s\S]*?)\r?\n    ConfigureColumns\(')
if ($mappingWindow -match '\+E0x02000000' -or
    $mappingWindow -notmatch 'BeginStableUpdate\(\)' -or
    $mappingWindow -notmatch 'WM_SETREDRAW' -or
    $mappingWindow -notmatch 'GetCaptureLayoutBounds\(\)' -or
    $mappingWindow -notmatch 'GetStatusLayout\(width\)' -or
    $mappingWindow -notmatch 'MinStatusHeight\s*:=\s*24' -or
    $mappingWindow -notmatch '\+Wrap Background' -or
    $mappingWindow -notmatch 'statusLayout\.Extra' -or
    $mappingWindow -notmatch 'StatusBottomMargin' -or
    $mappingWindow -notmatch 'RedrawCaptureLayout\(oldBounds, newBounds\)' -or
    $mappingWindow -notmatch 'Win32\.RDW_LAYOUT_REFRESH' -or
    $mappingWindow -notmatch
        'oldBounds\s*:=\s*this\.GetCaptureLayoutBounds\(\)' -or
    -not $resizeBody.Success -or
    $resizeBody.Groups['body'].Value -match 'this\.BeginStableUpdate\(\)' -or
    $resizeBody.Groups['body'].Value -match 'this\.EndStableUpdate\(' -or
    $theme -notmatch 'MoveAndRefreshResizableText\(control,' -or
    $resizeBody.Groups['body'].Value -notmatch
        'MoveAndRefreshResizableText\(this\.SourceDetail' -or
    $resizeBody.Groups['body'].Value -notmatch
        'MoveAndRefreshResizableText\(this\.TargetDetail' -or
    $resizeBody.Groups['body'].Value -notmatch
        'MoveAndRefreshResizableText\(this\.Status') {
    $failures.Add('Resize must use direct moves and targeted Static refreshes without composited whole-window redraw locks.')
}
if ($mappingWindow -match 'SectionDivider' -or
    $mappingWindow -match 'BackgroundTrans' -or
    $mappingWindow -notmatch 'ListLayoutFixedHeight\s*:=\s*212' -or
    $mappingWindow -notmatch 'sectionY\s*:=\s*88\s*\+\s*listHeight\s*\+\s*10') {
    $failures.Add('The divider must be removed and its vertical space returned to the main ListView.')
}
if ($mappingWindow -match 'SectionBottomDivider' -or
    $mappingWindow -notmatch
        'SectionTopDivider\.Move\(10,\s*sectionY\s*-\s*4' -or
    $mappingWindow -notmatch
        'labelY\s*:=\s*sectionY\s*\+\s*32') {
    $failures.Add('The new-mapping section must use spacing, one top divider, the centered title, then spacing.')
}
if ($mappingWindow -notmatch 'ListRowHeight\s*:=\s*36' -or
    $mappingWindow -notmatch 'EnsureListRowMetrics\(\)' -or
    $mappingWindow -notmatch 'ImageList_SetIconSize' -or
    $mappingWindow -notmatch 'ReleaseListRowImageList\(\)' -or
    $mappingWindow -notmatch 'ListViewSelectionPresenter\(' -or
    $mappingWindow -notmatch 'SetFont\("s12') {
    $failures.Add('The main ListView must own and release assistant-style row-height metrics.')
}
if ($mappingWindow -notmatch 'AlignListHeightToWholeRows\(proposedHeight\)' -or
    $mappingWindow -notmatch 'MoveListToWholeRows\(' -or
    $mappingWindow -notmatch '0x100E' -or
    $mappingWindow -notmatch 'GetClientRect' -or
    $mappingWindow -notmatch 'Mod\(clientHeight,\s*rowHeightPixels\)') {
    $failures.Add('The ListView viewport height must align to whole native rows at the active DPI.')
}
if ($mappingWindow -notmatch 'MeasureContentColumnWidths\(\)' -or
    $mappingWindow -notmatch 'ModifyCol\(MappingWindow\.SourceColumn,\s*"AutoHdr"\)' -or
    $mappingWindow -notmatch 'ModifyCol\(MappingWindow\.TargetColumn,\s*"AutoHdr"\)' -or
    $mappingWindow -notmatch 'FitContentColumnWidths\(availableWidth\)') {
    $failures.Add('Source and target columns must size from their longest visible content.')
}
if ($mappingWindow -notmatch
        'if\s+this\.HasShown\s*\{[\s\S]{0,500}this\.Gui\.Show\(showOptions\)[\s\S]{0,500}return' -or
    $mappingWindow -notmatch 'this\.EndStableUpdate\(true\)' -or
    $mappingWindow -notmatch 'RedrawStable\(eraseBackground\s*:=\s*false\)' -or
    $mappingWindow -notmatch 'eraseBackground\s*\?\s*0x0004\s*:\s*0' -or
    $mappingWindow -notmatch 'PurposeEdit\.SetFont') {
    $failures.Add('First layout must erase once, while tray restore must directly show the existing window and preserve input appearance.')
}
if ($mappingWindow -notmatch 'ApplyAppearance\(\*\)[\s\S]{0,8000}finally\s+this\.EndStableUpdate\(true\)') {
    $failures.Add('Appearance hot switching must erase the old top-level background exactly once.')
}
if ($mappingWindow -notmatch 'GetCaptureDetail\(capture\)[\s\S]{0,180}\?\s*capture\.DetailLines\s*\r?\n\s*:\s*""' -or
    $mappingWindow -notmatch 'activeDetail\.Text\s*:=\s*""') {
    $failures.Add('Capture details must stay empty until an actual key is recorded.')
}
if ($entry -notmatch '#Include src\\Core\\MappingCodeRepository\.ahk' -or
    $entry -notmatch '#Include app\\Windows\\MappingWindow\.ahk' -or
    $entry -notmatch '#Include src\\UI\\ListViewPseudoHeader\.ahk' -or
    $entry -notmatch '#Include app\\Windows\\SupportInfoWindow\.ahk' -or
    $entry -notmatch '#Include app\\Windows\\HelpWindow\.ahk' -or
    $entry -notmatch '#Include app\\Windows\\DonationWindow\.ahk') {
    $failures.Add('The modular entrypoint is missing required includes.')
}
$buildScript = Get-Content -LiteralPath (Join-Path $projectRoot `
    'tools\build-release.ps1') -Raw -Encoding UTF8
$releaseArtifactTests = Get-Content -LiteralPath (Join-Path $projectRoot `
    'tests\release-artifact-tests.ps1') -Raw -Encoding UTF8
$releaseWorkflow = Get-Content -LiteralPath (Join-Path $projectRoot `
    '.github\workflows\release.yml') -Raw -Encoding UTF8
$eventViewerWindow = Get-Content -LiteralPath (Join-Path $projectRoot `
    'app\Windows\EventViewerWindow.ahk') -Raw -Encoding UTF8
$rawInputBackend = Get-Content -LiteralPath (Join-Path $projectRoot `
    'src\Core\RawInputBackend.ahk') -Raw -Encoding UTF8
$repositoryCheck = Get-Content -LiteralPath (Join-Path $projectRoot `
    'tests\repository-check.ps1') -Raw -Encoding UTF8
$runAhkTests = Get-Content -LiteralPath (Join-Path $projectRoot `
    'tests\run-ahk-tests.ps1') -Raw -Encoding UTF8
$runtimePolicyText = (@(
    'README.md', 'CONTRIBUTING.md', 'docs\validation-matrix.md'
) | ForEach-Object {
    Get-Content -LiteralPath (Join-Path $projectRoot $_) -Raw -Encoding UTF8
}) -join "`n"
$toolchainLock = Get-Content -LiteralPath (Join-Path $projectRoot `
    'tools\toolchain.lock.json') -Raw -Encoding UTF8 | ConvertFrom-Json
if ($buildScript -notmatch "release-'\s*\+\s*\r?\n?\s*\[guid\]::NewGuid" -or
    $buildScript -notmatch 'finally\s*\{[\s\S]*?Remove-Item[^\r\n]*\$scratchRoot' -or
    $releaseWorkflow -notmatch 'Verify reproducible release' -or
    $releaseWorkflow -notmatch 'reproducible-build\.ps1' -or
    $repositoryCheck -notmatch '\^\\\.syntax-check-' -or
    $runAhkTests -notmatch '\$syntaxProbeMarker') {
    $failures.Add('Release builds must use isolated scratch paths, clean failures, and verify reproducibility on tags.')
}
if ($buildScript -notmatch 'key-mouse-remapper-\$version-windows-x64' -or
    $buildScript -notmatch 'key-remapper-\$version-windows-x64' -or
    $buildScript -notmatch 'Join-Path \$OutputRoot ''final''' -or
    $releaseArtifactTests -notmatch 'obsolete product artifact') {
    $failures.Add('Default release builds must remove and reject obsolete pre-rename artifacts.')
}
if ($buildScript -match
        'IncludeNativeDriver|MicrosoftSignedDriverDirectory|nativeDriver|KmrInput' -or
        $releaseWorkflow -match
        'Windows Driver Kit|MicrosoftSignedDriverDirectory|KmrInput' -or
        $buildScript -notmatch "inputBackend\s*=\s*'raw-input'" -or
        $buildScript -notmatch 'requiresDriver\s*=\s*\$false' -or
        $releaseArtifactTests -notmatch "backend -ne 'raw-input'") {
    $failures.Add('Release paths must package Raw Input only and reject obsolete driver infrastructure.')
}
if ($rawInputBackend -notmatch 'class RawInputBackend extends IInputBackend' -or
        $rawInputBackend -notmatch 'device_identification' -or
        $rawInputBackend -notmatch 'device_specific_suppression' -or
        $keyCapture -notmatch 'SelectCaptureDevice\(' -or
        $keyCapture -notmatch 'DeviceId') {
    $failures.Add('Raw Input must remain the sole device-aware backend and capture must bind a physical device.')
}
if ($productionAhkText -match
        'RawMappingWorker|RawOutputSession|ManagedHotkeyBackend|LowLevelInputService|DeviceFilterBackend|DeviceDriverClient|WH_KEYBOARD_LL|WH_MOUSE_LL|SetWindowsHookEx|InputHook\(|InstallKeybdHook|InstallMouseHook|--raw-worker|KMR_RAW_OUTPUT|raw_ahk' -or
        $mappingRepository -notmatch 'ValidateCommentOnlyRegion\(regionBody\)' -or
        $rulePackageService -match 'mode\s*==\s*"raw"') {
    $failures.Add('Production code must not contain a driver, hook, raw AHK worker, or executable mapping fallback.')
}
if ($eventViewerWindow -notmatch 'ScheduleActiveSort\(\)' -or
        $eventViewerWindow -notmatch 'SortRefreshPending' -or
        $eventViewerWindow -notmatch 'CancelPendingSort\(\)') {
    $failures.Add('The live event viewer must coalesce active pseudo-header sorts instead of sorting the full ListView for every incoming event.')
}
if ($runAhkTests -notmatch 'TestTimeoutMilliseconds\s*=\s*120000' -or
    $runAhkTests -notmatch 'Local\\KeyMouseRemapperAssistant\.GuiTestSuite' -or
    $runAhkTests -notmatch '\$guiMutex\.WaitOne' -or
    $runAhkTests -notmatch '\$guiMutex\.ReleaseMutex' -or
    $runAhkTests -notmatch 'AllowDesktopInput' -or
    $runAhkTests -notmatch '--skip-desktop-input') {
    $failures.Add('GUI test suites must serialize shared desktop input and retain a realistic configurable timeout.')
}
if ([string]$toolchainLock.tools.autoHotkey.version -cne '2.0.26' -or
    $runtimePolicyText -match '(?im)^.*AutoHotkey.*2\.0\.(?!26\b)\d+.*$' -or
    $runAhkTests -notmatch 'toolchain\.lock\.json' -or
    $runAhkTests -notmatch '\$actualAhkVersion\s+-cne\s+\$requiredAhkVersion') {
    $failures.Add('All supported development and validation paths must require only the locked AutoHotkey 2.0.26 runtime.')
}
$saveSettingsBody = [regex]::Match($appController,
    'SaveSettings\(candidate\)\s*\{(?<body>[\s\S]*?)\r?\n    CreateHistoryAction\(')
if (-not $saveSettingsBody.Success -or
    $saveSettingsBody.Groups['body'].Value -match 'ScheduleReload' -or
    $appController -notmatch 'ApplySettingsHot' -or
    $appController -notmatch 'HandleSystemSettingChange' -or
    $buildScript -notmatch "'third_party'") {
    $failures.Add('Display settings must apply transactionally in place and releases must include UI runtime assets.')
}
$pseudoHeader = Get-Content -LiteralPath (Join-Path $projectRoot `
    'src\UI\ListViewPseudoHeader.ahk') -Raw -Encoding UTF8
$contextPopup = Get-Content -LiteralPath (Join-Path $projectRoot `
    'app\Windows\MappingContextPopupWindow.ahk') -Raw -Encoding UTF8
if ($pseudoHeader -notmatch 'WM_LBUTTONDBLCLK' -or
    $pseudoHeader -notmatch 'WM_SETREDRAW' -or
    $pseudoHeader -notmatch 'case 0x007B, 0x0301' -or
    $contextPopup -notmatch '\+E0x08000000' -or
    $contextPopup -notmatch 'NoActivate' -or
    $contextPopup -notmatch 'ApplyRoundedRegion' -or
    $contextPopup -notmatch 'MappingUiInteractions') {
    $failures.Add('Pseudo-header input protection or non-modal themed context actions are incomplete.')
}
$repositoryWrite = [regex]::Match($mappingRepository,
    'WriteValidatedFile\(updatedText, expectedText\?\)[\s\S]*?\r?\n    ValidateScriptSyntax')
if (-not $repositoryWrite.Success -or
    $repositoryWrite.Value -notmatch 'ReadScriptText\(\) != expectedText' -or
    $mappingRepository -notmatch 'MaximumScriptBytes' -or
    $mappingRepository -notmatch 'ValidateCommentOnlyRegion' -or
    $mappingRepository -notmatch 'mode != "managed"' -or
    $mappingRepository -notmatch '重复元数据') {
    $failures.Add('Repository writes must reject concurrent edits and inconsistent mapping metadata.')
}
$rulePackageExport = [regex]::Match($rulePackageService,
    'ExportTo\(filePath,[\s\S]*?\r?\n    Parse\(text\)')
if (-not $rulePackageExport.Success -or
    $rulePackageExport.Value -notmatch 'MaximumPackageCharacters' -or
    $rulePackageExport.Value -notmatch 'WriteAtomic') {
    $failures.Add('Rule-package export must enforce its own readable package-size limit before writing.')
}
if ($entry -notmatch 'if A_IsCompiled[\s\S]{0,120}LaunchPackagedSource\(\)') {
    $failures.Add('The compiled entry must hand off to editable packaged source.')
}
$packagedLauncher = Get-Content -LiteralPath (Join-Path $projectRoot `
    'src\Platform\PackagedLauncher.ahk') -Raw -Encoding UTF8
if ($packagedLauncher -notmatch 'ShellExecuteW' -or
    $packagedLauncher -notmatch '"WStr", runtimePath, "WStr", parameters' -or
    $packagedLauncher -notmatch '"WStr", "open"' -or
    $packagedLauncher -notmatch '__PACKAGED_RUNTIME_SHA256__' -or
    $packagedLauncher -notmatch 'ComputeFileSha256\(runtimePath\)' -or
    $packagedLauncher -notmatch 'RunWait\(' -or
    $buildScript -notmatch '\.Replace\([\s\S]*?runtimeHashPlaceholder' -or
    $entry -match 'if !A_IsAdmin' -or
    $appController -notmatch 'RestartElevated' -or
    $appController -notmatch '"WStr", "runas"') {
    $failures.Add('Normal startup must use least privilege and expose only explicit optional elevation.')
}

function Test-ActiveSyntaxProbe {
    param([System.IO.FileInfo]$Probe)
    $markerPath = $Probe.FullName + '.active'
    if (-not (Test-Path -LiteralPath $markerPath -PathType Leaf)) {
        return $false
    }
    try {
        $ownerProcessId = [int](Get-Content -LiteralPath $markerPath -Raw `
            -Encoding UTF8)
    } catch {
        return $false
    }
    return $null -ne (Get-Process -Id $ownerProcessId `
        -ErrorAction SilentlyContinue)
}
$unexpected = @(Get-ChildItem -LiteralPath $projectRoot -Recurse -File |
    Where-Object {
        if ($_.Name -match '^\.syntax-check-.*\.ahk$') {
            return -not (Test-ActiveSyntaxProbe $_)
        }
        return $_.Name -match '\.codex-.*\.ahk$|\.tmp$'
    })
$orphanProbeMarkers = @(Get-ChildItem -LiteralPath $projectRoot `
    -Filter '.syntax-check-*.ahk.active' -File | Where-Object {
        $probePath = $_.FullName.Substring(0,
            $_.FullName.Length - '.active'.Length)
        if (Test-Path -LiteralPath $probePath -PathType Leaf) {
            return $false
        }
        try {
            $ownerProcessId = [int](Get-Content -LiteralPath $_.FullName `
                -Raw -Encoding UTF8)
        } catch {
            return $true
        }
        return $null -eq (Get-Process -Id $ownerProcessId `
            -ErrorAction SilentlyContinue)
    })
$unexpected += $orphanProbeMarkers
if ($unexpected.Count) {
    $failures.Add('Temporary files remain in the project: ' +
        (($unexpected | ForEach-Object FullName) -join ', '))
}

if ($failures.Count) {
    $failures | ForEach-Object { Write-Error $_ }
    exit 1
}
Write-Host "Static checks passed: $beginCount mapping blocks."
