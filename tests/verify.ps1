[CmdletBinding()]
param(
    [string]$AutoHotkeyPath = "",
    [switch]$SkipGui,
    [switch]$AllowDesktopInput
)

$ErrorActionPreference = 'Stop'
& (Join-Path $PSScriptRoot 'powershell-5.1-compatibility-tests.ps1')
& (Join-Path $PSScriptRoot 'build-path-safety-tests.ps1')
& (Join-Path $PSScriptRoot 'static-check.ps1')
& (Join-Path $PSScriptRoot 'icon-tests.ps1')
& (Join-Path $PSScriptRoot 'font-assets-tests.ps1')
& (Join-Path $PSScriptRoot 'repository-check.ps1')
& (Join-Path $PSScriptRoot 'cli-launcher-tests.ps1')
& (Join-Path $PSScriptRoot 'evidence-seal-tests.ps1')
& (Join-Path $PSScriptRoot 'physical-device-evidence-tests.ps1')
& (Join-Path $PSScriptRoot 'physical-device-evidence-verifier-tests.ps1')
& (Join-Path $PSScriptRoot 'desktop-context-evidence-tests.ps1')
& (Join-Path $PSScriptRoot 'desktop-context-evidence-verifier-tests.ps1')
& (Join-Path $PSScriptRoot 'run-ahk-tests.ps1') `
    -AutoHotkeyPath $AutoHotkeyPath -SkipGui:$SkipGui `
    -AllowDesktopInput:$AllowDesktopInput
if ($AllowDesktopInput) {
    Write-Host 'All required verification suites passed, including desktop input.'
} else {
    Write-Host ('All non-intrusive verification suites passed. ' +
        'Desktop-input assertions were skipped.')
}
