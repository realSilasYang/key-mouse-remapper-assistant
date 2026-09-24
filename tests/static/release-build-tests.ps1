[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$buildScriptPath = Join-Path $projectRoot 'tools\build-release.ps1'
$runtimePath = Join-Path $projectRoot 'src\Core\DirectHotkeyRuntime.ahk'
$scriptRuntimePath = Join-Path $projectRoot 'src\Core\ScriptRuleRuntime.ahk'
$localizationPath = Join-Path $projectRoot `
    'src\Localization\LocalizationService.ahk'
$appPath = Join-Path $projectRoot 'app\KeyMouseRemapperAssistantApp.ahk'
$fontRestorePath = Join-Path $projectRoot 'tools\restore-font-assets.ps1'
$workflowPath = Join-Path $projectRoot '.github\workflows\ci.yml'
$entryCandidates = @(Get-ChildItem -LiteralPath $projectRoot -Filter '*.ahk' `
    -File | Where-Object { $_.Name -notlike '.*' } | Where-Object {
        $candidateSource = Get-Content -LiteralPath $_.FullName -Raw `
            -Encoding UTF8
        $candidateSource -match `
            '#Include\s+app\\KeyMouseRemapperAssistantApp\.ahk' -and
            $candidateSource -match 'LaunchPackagedSource\(\)'
    })
if ($entryCandidates.Count -ne 1) {
    throw ('Expected one non-temporary AHK application entry, found ' +
        "$($entryCandidates.Count).")
}
$entryPath = $entryCandidates[0].FullName
$launcherPath = Join-Path $projectRoot 'src\Platform\PackagedLauncher.ahk'
$buildScript = Get-Content -LiteralPath $buildScriptPath -Raw -Encoding UTF8
$runtime = Get-Content -LiteralPath $runtimePath -Raw -Encoding UTF8
$scriptRuntime = Get-Content -LiteralPath $scriptRuntimePath -Raw -Encoding UTF8
$localization = Get-Content -LiteralPath $localizationPath -Raw -Encoding UTF8
$app = Get-Content -LiteralPath $appPath -Raw -Encoding UTF8
$fontRestore = Get-Content -LiteralPath $fontRestorePath -Raw -Encoding UTF8
$workflow = Get-Content -LiteralPath $workflowPath -Raw -Encoding UTF8
$entry = Get-Content -LiteralPath $entryPath -Raw -Encoding UTF8
$launcher = Get-Content -LiteralPath $launcherPath -Raw -Encoding UTF8
$builtInRuleCount = [regex]::Matches($entry,
    '(?m)^; @mapping-begin\r?$').Count
$builtInRuleEndCount = [regex]::Matches($entry,
    '(?m)^; @mapping-end\r?$').Count
$builtInManagedRuleCount = [regex]::Matches($entry,
    '(?m)^; @spec-begin\r?$').Count
$builtInScriptRuleCount = [regex]::Matches($entry,
    '(?m)^; @script-code-begin\r?$').Count
if ($builtInRuleEndCount -ne $builtInRuleCount -or
        ($builtInManagedRuleCount + $builtInScriptRuleCount) -ne
            $builtInRuleCount) {
    throw ('The application entry does not contain complete built-in rules: ' +
        "begin=$builtInRuleCount, end=$builtInRuleEndCount, " +
        "managed=$builtInManagedRuleCount, script=$builtInScriptRuleCount.")
}
$customKeyboardWindowsKeyRule = [regex]::Match($entry,
    '(?ms)^; @mapping-begin\r?\n(?:(?!^; @mapping-end\r?$).)*' +
    '@名称=屏蔽外接键盘 Win 键' +
    '(?:(?!^; @mapping-end\r?$).)*^; @mapping-end\r?$')
$requiredInterceptionRuleParts = @(
    '@类型=规则块',
    '"block": true',
    '"backend": "interception"',
    '"number": 3',
    '"type": "keyboard"',
    '"name": "Win"')
$interceptionRuleComplete = $customKeyboardWindowsKeyRule.Success
foreach ($part in $requiredInterceptionRuleParts) {
    $interceptionRuleComplete = $interceptionRuleComplete -and
        $customKeyboardWindowsKeyRule.Value.Contains($part)
}
if (-not $interceptionRuleComplete) {
    throw 'The built-in external-keyboard Windows-key block rule is incomplete.'
}
if ($entry -notmatch
        '#Include\s+app\\KeyMouseRemapperAssistantApp\.ahk' -or
        $entry -notmatch 'LaunchPackagedSource\(\)' -or
        $entry -notmatch '#Include\s+src\\Core\\InterceptionService\.ahk' -or
        $entry -notmatch '#Include\s+src\\Core\\InterceptionMappingRuntime\.ahk' -or
        $app -match 'OpenInterceptionDevices|InterceptionDevices' -or
        (Get-Content -LiteralPath (Join-Path $projectRoot 'app\Windows\SupportInfoWindow.ahk') -Raw -Encoding UTF8) -match 'Interception.*设备识别' -or
        $app -notmatch 'HasActiveInterceptionRule') {
    throw 'The fixed AHK entry no longer has the application entry contract.'
}
$interceptionServicePath = Join-Path $projectRoot 'src\Core\InterceptionService.ahk'
$interceptionRuntimePath = Join-Path $projectRoot 'src\Core\InterceptionMappingRuntime.ahk'
foreach ($requiredPath in @($interceptionServicePath, $interceptionRuntimePath,
        (Join-Path $projectRoot 'third_party\interception\library\x64\interception.dll'),
        (Join-Path $projectRoot 'third_party\interception\command-line-installer\install-interception.exe'),
        (Join-Path $projectRoot 'third_party\interception\library\interception.h'),
        (Join-Path $projectRoot 'third_party\interception\licenses\non-commercial-usage\LGPL 3.0.txt'))) {
    if (-not (Test-Path -LiteralPath $requiredPath -PathType Leaf)) {
        throw "Interception integration asset is missing: $requiredPath"
    }
}
$interceptionService = Get-Content -LiteralPath $interceptionServicePath -Raw -Encoding UTF8
$interceptionWindow = Get-Content -LiteralPath (Join-Path $projectRoot 'app\Windows\InterceptionDeviceWindow.ahk') -Raw -Encoding UTF8
$applicationClass = Get-Content -LiteralPath (Join-Path $projectRoot 'app\KeyMouseRemapperAssistantApp.ahk') -Raw -Encoding UTF8
foreach ($requiredText in @(
        '"create_context"', '"get_hardware_id"',
        '"wait_with_timeout"', 'official_index', 'StartIdentify',
        'InstallDriver', 'CopyKeyboardConfig')) {
    if ($interceptionService -notmatch [regex]::Escape($requiredText) -and
            $interceptionWindow -notmatch [regex]::Escape($requiredText)) {
        throw "Interception integration contract is incomplete: $requiredText"
    }
}
if ($applicationClass -notmatch 'InterceptionDriverStartupTimer' -or
        $applicationClass -notmatch 'SetTimer\(this\.InterceptionDriverStartupTimer,\s*-1000\)' -or
        $applicationClass -notmatch 'CheckInterceptionOnStartup' -or
        $applicationClass -notmatch 'CheckInterceptionDriverAtStartup\(\)' -or
        $interceptionService -notmatch 'RunWait\("\*RunAs "') {
    throw 'Startup driver detection or elevated official installer launch is missing.'
}
if ($app -notmatch 'this\.Interception\.Shutdown\(\)' -or
        (Get-Content -LiteralPath (Join-Path $projectRoot 'src\Core\AIService.ahk') -Raw -Encoding UTF8) -notmatch
            'CurrentInterceptionReminder' -or
        (Get-Content -LiteralPath (Join-Path $projectRoot 'src\Core\AIService.ahk') -Raw -Encoding UTF8) -notmatch
            'interception_keyboard_device_range') {
    throw 'Interception lifecycle or AI capability contract is incomplete.'
}

$tokens = $null
$parseErrors = $null
[System.Management.Automation.Language.Parser]::ParseFile(
    $buildScriptPath, [ref]$tokens, [ref]$parseErrors) | Out-Null
if ($parseErrors.Count -gt 0) {
    throw ('Release build script failed to parse: ' +
        (($parseErrors | ForEach-Object { $_.ToString() }) -join '; '))
}
if ($runtime -notmatch '"suppresses_original_input",\s*JsonBoolean\(true\)') {
    throw 'The direct runtime no longer declares original-input suppression.'
}
if ($buildScript -notmatch
        "'  `"suppressesOriginalInput`": true'") {
    throw 'The release manifest contradicts the direct runtime suppression capability.'
}
$compiledHandoff = [regex]::Match($entry,
    '(?m)^\s*if\s+A_IsCompiled\s*\r?\n' +
    '\s*ExitApp\(LaunchPackagedSource\(\)\s*\?\s*0\s*:\s*1\)')
$mainAppCreation = [regex]::Match($entry,
    '(?m)^\s*global\s+App\s*:=\s*KeyMouseRemapperAssistantApp\(\)')
if (-not $compiledHandoff.Success -or -not $mainAppCreation.Success -or
        $compiledHandoff.Index -ge $mainAppCreation.Index) {
    throw 'The compiled entry no longer hands off before creating the main app.'
}
if ($launcher -notmatch 'runtime\\AutoHotkey64\.exe' -or
        $launcher -notmatch 'QuoteCommandLineArgument\(runtimePath\)') {
    throw 'The packaged launcher no longer uses its fixed AHK runtime.'
}
if ($buildScript -notmatch
        "Join-Path \`$runtimeDirectory 'AutoHotkey64\.exe'") {
    throw 'The release package no longer includes the fixed AHK runtime.'
}
if ($buildScript -notmatch 'builtInRuleCount' -or
        $buildScript -notmatch 'bundlesUserSettings.*false' -or
        $buildScript -notmatch 'Assert-ReleaseContent' -or
        $buildScript -notmatch 'Get-LocalAiParameterValues' -or
        $buildScript -notmatch 'PromptEscaped' -or
        $buildScript -notmatch 'OptimizePromptEscaped' -or
        $buildScript -notmatch 'SystemPromptEscaped' -or
        $buildScript -notmatch 'IndexOf\(\$parameter\.Value' -or
        $buildScript -notmatch 'settings\.ini.*runtime\.ini.*rule-appearance\.json' -or
        $buildScript -notmatch 'window-layout\.ini') {
    throw 'The release build no longer enforces its built-in-rule and privacy contract.'
}
if ($buildScript -notmatch
        "SystemPromptEscaped\s*=\s*'DefaultSystemPrompt'") {
    throw 'The release build mistakes the built-in system prompt for local AI data.'
}
if ($scriptRuntime -notmatch
        'QuoteRuntimeCommandArgument\(this\.InterpreterPath\)') {
    throw 'Script-rule workers no longer use the application interpreter.'
}
if ($localization -match
        'AddFontResourceExW|RemoveFontResourceExW|FR_PRIVATE|GetUiFontAssetDirectory|EnsurePackagedUiFontAvailable' -or
        $app -match 'LocalizationService\.ShutdownUiFonts') {
    throw 'Runtime fonts must come only from Windows-installed families.'
}
if ($buildScript -notmatch '\$fontPackageName\s*=\s*''fonts''' -or
        $buildScript -notmatch 'Assert-FontPackageContent' -or
        $buildScript -notmatch '\$packagedFontDirectory' -or
        $buildScript -notmatch '\$sourceFontDirectory' -or
        $buildScript -notmatch 'New-DeterministicArchive\s+\$fontPackageDirectory\s+\$fontZipPath') {
    throw 'The release build no longer creates a separate fonts.zip.'
}
if ($fontRestore -notmatch "'fonts\.zip'" -or
        $fontRestore -match 'key-mouse-remapper-assistant-\*-source\.zip' -or
        $workflow -notmatch '\.tools/font-assets' -or
        $workflow -notmatch 'Restore release-verified font assets') {
    throw 'CI no longer restores font assets from fonts.zip.'
}

$localizedReadmes = @(
    'README.md',
    'docs\README.zh-HK.md',
    'docs\README.zh-TW.md',
    'docs\README.en.md',
    'docs\README.ja.md',
    'docs\README.vi.md',
    'docs\README.ko.md',
    'docs\README.es.md',
    'docs\README.fr.md',
    'docs\README.pt-BR.md',
    'docs\README.ru.md',
    'docs\README.de.md',
    'docs\README.it.md'
)
foreach ($relativePath in $localizedReadmes) {
    $readmePath = Join-Path $projectRoot $relativePath
    if (-not (Test-Path -LiteralPath $readmePath -PathType Leaf)) {
        throw "Localized README is missing: $relativePath"
    }
    $readme = Get-Content -LiteralPath $readmePath -Raw -Encoding UTF8
    $levelOneCount = [regex]::Matches($readme, '(?m)^# ').Count
    $levelTwoCount = [regex]::Matches($readme, '(?m)^## ').Count
    $stackedPreviewPattern =
        '(?s)<p align="center">\s*' +
        '<img src="(?:docs/)?images/' +
        'key-mouse-remapper-assistant-overview\.png"[^>]*' +
        'width="100%">\s*</p>\s*' +
        '<p align="center">\s*' +
        '<img src="(?:docs/)?images/' +
        'key-mouse-remapper-assistant-overview-light\.png"[^>]*' +
        'width="100%">\s*</p>'
    if ($levelOneCount -ne 5 -or $levelTwoCount -ne 12 -or
            $readme -notmatch
                'docs/images/key-mouse-remapper-assistant-overview\.png|images/key-mouse-remapper-assistant-overview\.png' -or
            $readme -notmatch
                'key-mouse-remapper-assistant-overview-light\.png' -or
            $readme -notmatch $stackedPreviewPattern -or
            $readme -notmatch 'fonts\.zip' -or
            $readme -notmatch '(?m)^# Star History$') {
        throw "Localized README structure is incomplete: $relativePath"
    }
}
$releaseVersion = (Get-Content -LiteralPath (Join-Path $projectRoot 'VERSION') `
    -Raw -Encoding UTF8).Trim()
$releaseNotesPath = Join-Path $projectRoot `
    "docs\release-notes\v$releaseVersion.md"
$releaseNotes = Get-Content -LiteralPath $releaseNotesPath -Raw `
    -Encoding UTF8
if ($releaseNotes -match '(?i)sha-?256|sha256sums') {
    throw 'Release Notes must not publish SHA-256 values or checksum assets.'
}
if (-not $releaseNotes.Contains('fonts.zip')) {
    throw 'Release Notes do not describe the optional font package boundary.'
}
if ($buildScript -notmatch "'CHANGELOG\.md'" -or
        $buildScript -notmatch "'docs'" -or
        $buildScript -notmatch "'tests'") {
    throw 'Release packages no longer include the documented public files.'
}
if ($buildScript -notmatch
        "foreach \(\`$directory in @\('app', 'assets', 'docs', 'src', 'third_party'\)\)") {
    throw 'The portable package no longer copies the localized documentation.'
}

Write-Host 'PASS release-build-tests.ps1'
