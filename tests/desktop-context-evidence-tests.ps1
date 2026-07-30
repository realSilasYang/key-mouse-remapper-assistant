[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
Import-Module (Join-Path $projectRoot 'tools\EvidenceSeal.psm1') -Force
$collectorPath = Join-Path $PSScriptRoot 'desktop-context-evidence.ps1'
$outputPath = Join-Path $projectRoot `
    ('.build\desktop-context-listonly-{0}.json' -f
        [guid]::NewGuid().ToString('N'))

try {
    & $collectorPath -ListOnly -OutputPath $outputPath -Force |
        Out-String | Out-Null
    $evidence = Get-Content -LiteralPath $outputPath -Raw -Encoding UTF8 |
        ConvertFrom-Json
    $lock = Get-Content -LiteralPath (Join-Path $projectRoot `
        'tools\toolchain.lock.json') -Raw -Encoding UTF8 | ConvertFrom-Json
    $ahkPath = Join-Path $projectRoot `
        ('.tools\autoHotkey-' + $lock.tools.autoHotkey.version + '\' +
            $lock.tools.autoHotkey.executable)
    $sourceCollector = Join-Path $PSScriptRoot `
        'gui\desktop-context-evidence.ahk'

    if ([int]$evidence.schema -ne 1 -or $evidence.status -cne 'listed') {
        throw 'List-only desktop evidence schema or status is invalid.'
    }
    if ($evidence.passed -isnot [bool] -or [bool]$evidence.passed -or
            $evidence.acceptance_eligible -isnot [bool] -or
            [bool]$evidence.acceptance_eligible) {
        throw 'List-only desktop evidence must be Boolean false and ineligible.'
    }
    if ($evidence.runtime.autohotkey -cne '2.0.26' -or
            $evidence.runtime.architecture -cne 'x64' -or
            $evidence.runtime.executable_sha256 -cne
                (Get-FileHash -Algorithm SHA256 $ahkPath).Hash) {
        throw 'Desktop evidence did not use the locked x64 runtime and hash.'
    }
    if ($evidence.collector.script_sha256 -cne
            (Get-FileHash -Algorithm SHA256 $sourceCollector).Hash -or
            $evidence.collector.list_only -isnot [bool] -or
            -not [bool]$evidence.collector.list_only) {
        throw 'Desktop evidence collector identity or list-only flag is invalid.'
    }
    if ($evidence.collector.integrity_known -isnot [bool] -or
            -not [bool]$evidence.collector.integrity_known -or
            [int]$evidence.collector.integrity_rid -lt 0x1000) {
        throw 'Desktop evidence collector integrity is unavailable.'
    }
    if ([long]$evidence.duration_ms -ne 0 -or
            @($evidence.samples).Count -ne 1 -or
            @($evidence.events).Count -ne 0 -or
            @($evidence.errors).Count -ne 0) {
        throw 'List-only desktop evidence contains an invalid observation set.'
    }
    if ([int]$evidence.summary.sample_count -ne 1 -or
            [int]$evidence.summary.event_count -ne 0 -or
            [int]$evidence.summary.error_count -ne 0) {
        throw 'List-only desktop evidence summary is inconsistent.'
    }
    foreach ($requirement in @('lock_cycle', 'rdp', 'sleep_resume',
            'elevated_focus', 'secure_desktop', 'layout_switch')) {
        if ($evidence.requirements.$requirement -isnot [bool] -or
                -not [bool]$evidence.requirements.$requirement) {
            throw "Default desktop evidence does not require $requirement."
        }
    }
    $foreground = $evidence.samples[0].foreground
    foreach ($sensitive in @('path', 'process_path', 'title', 'focused_text')) {
        if ($null -ne $foreground.PSObject.Properties[$sensitive]) {
            throw "List-only evidence leaked foreground field: $sensitive"
        }
    }
    $inputSource = $evidence.samples[0].input_source
    $hasLayout = -not [string]::IsNullOrWhiteSpace(
        [string]$inputSource.layout)
    if ($evidence.samples[0].session.session_id_known -isnot [bool] -or
            -not [bool]$evidence.samples[0].session.session_id_known -or
            $inputSource.available -isnot [bool] -or
            [bool]$inputSource.available -ne $hasLayout) {
        throw 'List-only evidence did not report session and HKL availability honestly.'
    }
    if ([bool]$inputSource.available -and
            ([long]$inputSource.thread_id -le 0 -or
                [string]$inputSource.layout -notmatch '^[A-F0-9]{8}$')) {
        throw 'List-only evidence reported an invalid available foreground HKL.'
    }
    Assert-EvidenceSeal $evidence 'desktop-context' `
        ([int]$evidence.collector.process_id) | Out-Null
} finally {
    if (Test-Path -LiteralPath $outputPath -PathType Leaf) {
        Remove-Item -LiteralPath $outputPath -Force
    }
}

Write-Host 'Desktop-context evidence contract checks passed.'
