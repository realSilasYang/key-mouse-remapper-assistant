[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$buildScriptPath = Join-Path $projectRoot 'tools\build-release.ps1'
$runtimePath = Join-Path $projectRoot 'src\Core\DirectHotkeyRuntime.ahk'
$scriptRuntimePath = Join-Path $projectRoot 'src\Core\ScriptRuleRuntime.ahk'
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
if ($builtInRuleCount -ne 18 -or
        $builtInRuleEndCount -ne $builtInRuleCount -or
        ($builtInManagedRuleCount + $builtInScriptRuleCount) -ne
            $builtInRuleCount) {
    throw ('The application entry does not contain complete built-in rules: ' +
        "begin=$builtInRuleCount, end=$builtInRuleEndCount, " +
        "managed=$builtInManagedRuleCount, script=$builtInScriptRuleCount.")
}
if ($entry -notmatch
        '#Include\s+app\\KeyMouseRemapperAssistantApp\.ahk' -or
        $entry -notmatch 'LaunchPackagedSource\(\)') {
    throw 'The fixed AHK entry no longer has the application entry contract.'
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
if ($scriptRuntime -notmatch
        'QuoteRuntimeCommandArgument\(this\.InterpreterPath\)') {
    throw 'Script-rule workers no longer use the application interpreter.'
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
    if ($levelOneCount -ne 5 -or $levelTwoCount -ne 12 -or
            $readme -notmatch
                'docs/images/key-mouse-remapper-assistant-overview\.png|images/key-mouse-remapper-assistant-overview\.png' -or
            $readme -notmatch '(?m)^# Star History$') {
        throw "Localized README structure is incomplete: $relativePath"
    }
}
$releaseNotesPath = Join-Path $projectRoot `
    'docs\release-notes\v1.0.0.md'
$releaseNotes = Get-Content -LiteralPath $releaseNotesPath -Raw `
    -Encoding UTF8
if ($releaseNotes -match '(?i)sha-?256|sha256sums') {
    throw 'Release Notes must not publish SHA-256 values or checksum assets.'
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
