[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
Import-Module (Join-Path $projectRoot 'tools\EvidenceSeal.psm1') -Force
$collectorPath = Join-Path $PSScriptRoot 'physical-device-evidence.ps1'
$outputPath = Join-Path $projectRoot `
    ('.build\physical-device-listonly-{0}.json' -f
        [guid]::NewGuid().ToString('N'))

try {
    & $collectorPath -ListOnly -OutputPath $outputPath -Force |
        Out-String | Out-Null
    $evidence = Get-Content -LiteralPath $outputPath -Raw -Encoding UTF8 |
        ConvertFrom-Json

    if ([int]$evidence.schema -ne 1 -or $evidence.status -ne 'listed') {
        throw 'List-only evidence schema or status is invalid.'
    }
    if ($evidence.passed -isnot [bool] -or [bool]$evidence.passed) {
        throw 'List-only evidence must contain the Boolean value passed=false.'
    }
    if ($evidence.acceptance_eligible -isnot [bool] -or
            [bool]$evidence.acceptance_eligible) {
        throw 'List-only evidence must not be eligible for acceptance.'
    }
    if ($evidence.runtime.autohotkey -ne '2.0.26' -or
            $evidence.runtime.architecture -ne 'x64') {
        throw 'Physical-device evidence did not use the locked x64 runtime.'
    }
    $lock = Get-Content -LiteralPath (Join-Path $projectRoot `
        'tools\toolchain.lock.json') -Raw -Encoding UTF8 | ConvertFrom-Json
    $collectorHash = (Get-FileHash -Algorithm SHA256 -LiteralPath `
        (Join-Path $PSScriptRoot 'gui\physical-device-evidence.ahk')).Hash
    if ($evidence.runtime.executable_sha256 -cne
            [string]$lock.tools.autoHotkey.executableSha256 -or
            $evidence.collector.script_sha256 -cne $collectorHash -or
            $evidence.collector.list_only -isnot [bool] -or
            -not [bool]$evidence.collector.list_only) {
        throw 'Physical-device evidence provenance is invalid.'
    }
    if (@($evidence.devices).Count -ne
            [int]$evidence.summary.enumerated_devices) {
        throw 'Enumerated device count does not match the device reports.'
    }
    if ([int]$evidence.summary.active_keyboards -ne 0 -or
            [int]$evidence.summary.active_mice -ne 0) {
        throw 'List-only evidence must not claim physically active devices.'
    }
    if ([int]$evidence.summary.error_count -ne @($evidence.errors).Count) {
        throw 'Evidence error count does not match the error reports.'
    }
    if ([int]$evidence.lifecycle.arrival -ne 0 -or
            [int]$evidence.lifecycle.removal -ne 0 -or
            [int]$evidence.lifecycle.rebound -ne 0) {
        throw 'Startup enumeration leaked into the hot-plug evidence baseline.'
    }
    if ([bool]$evidence.requirements.require_hotplug) {
        throw 'The list-only contract test unexpectedly requires hot-plug.'
    }
    Assert-EvidenceSeal $evidence 'physical-device' `
        ([int]$evidence.collector.process_id) | Out-Null
} finally {
    if (Test-Path -LiteralPath $outputPath -PathType Leaf) {
        Remove-Item -LiteralPath $outputPath -Force
    }
}

Write-Host 'Physical-device evidence contract checks passed.'
