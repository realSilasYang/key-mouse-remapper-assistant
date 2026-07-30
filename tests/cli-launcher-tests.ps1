[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$launchers = @(Get-ChildItem -LiteralPath $projectRoot -Filter '*-CLI.ps1' -File)
if ($launchers.Count -ne 1) {
    throw "Expected exactly one CLI launcher, found $($launchers.Count)."
}
$launcher = $launchers[0].FullName

$capabilityText = (& $launcher capabilities --pretty) | Out-String
if ($LASTEXITCODE -ne 0) {
    throw "CLI capabilities failed with exit code $LASTEXITCODE."
}
$capabilities = $capabilityText | ConvertFrom-Json
if ($capabilities.backend -ne 'raw-input' -or
    -not $capabilities.available -or
    -not $capabilities.device_identification -or
    $capabilities.requires_driver -or
    $capabilities.device_specific_suppression -or
    $capabilities.suppresses_simple_hotkeys) {
    throw 'CLI capability JSON or UTF-8 output is invalid.'
}

$listText = (& $launcher list --pretty) | Out-String
if ($LASTEXITCODE -ne 0) {
    throw "CLI list failed with exit code $LASTEXITCODE."
}
$rules = $listText | ConvertFrom-Json
if ($rules.count -lt 1 -or
    @($rules.rules | Where-Object purpose -match '[\u4e00-\u9fff]').Count -lt 1) {
    throw 'CLI list did not preserve Chinese JSON text.'
}

$versionText = (& $launcher version --pretty) | Out-String
if ($LASTEXITCODE -ne 0) {
    throw "CLI version failed with exit code $LASTEXITCODE."
}
$version = $versionText | ConvertFrom-Json
if ($version.runtime -ne '2.0.26') {
    throw "CLI launcher used unexpected AutoHotkey $($version.runtime)."
}

Write-Host 'CLI launcher checks passed.'
