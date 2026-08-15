[CmdletBinding()]
param(
    [string]$AutoHotkeyPath = "",
    [switch]$SkipGui,
    [switch]$IncludeGui,
    [switch]$AllowDesktopInput
)

$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot

function Assert-PowerShellScriptParses {
    param([string]$Path)

    $resolvedPath = (Resolve-Path -LiteralPath $Path).Path
    $tokens = $null
    $errors = $null
    [System.Management.Automation.Language.Parser]::ParseFile(
        $resolvedPath, [ref]$tokens, [ref]$errors) | Out-Null
    if ($errors.Count -gt 0) {
        $message = ($errors | ForEach-Object { $_.ToString() }) -join "`n"
        throw "PowerShell script failed to parse: $resolvedPath`n$message"
    }
    Write-Host "PASS $([System.IO.Path]::GetFileName($resolvedPath))"
}

& (Join-Path $PSScriptRoot 'run-ahk-tests.ps1') `
    -AutoHotkeyPath $AutoHotkeyPath -SkipGui:$SkipGui `
    -IncludeGui:$IncludeGui `
    -AllowDesktopInput:$AllowDesktopInput
Write-Host 'SKIP brittle source-based UI contracts (covered by GUI behavior tests)'
& (Join-Path $PSScriptRoot 'static\application-update-tests.ps1')
& (Join-Path $PSScriptRoot 'static\localization-catalog-tests.ps1')
& (Join-Path $PSScriptRoot 'static\release-build-tests.ps1')
& (Join-Path $PSScriptRoot 'static\font-asset-restore-tests.ps1')
Assert-PowerShellScriptParses (Join-Path $projectRoot `
    'runtime\application-update.ps1')
Get-Content -LiteralPath (Join-Path $projectRoot `
        'runtime\application-update.strings.json') -Raw -Encoding UTF8 |
    ConvertFrom-Json | Out-Null
Write-Host 'PASS application-update.strings.json'
Write-Host 'Direct runtime verification passed.'
