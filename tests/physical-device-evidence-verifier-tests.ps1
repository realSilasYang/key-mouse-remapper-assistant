[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
Import-Module (Join-Path $projectRoot 'tools\EvidenceSeal.psm1') -Force
$verifierPath = Join-Path $PSScriptRoot 'verify-physical-device-evidence.ps1'
$lock = Get-Content -LiteralPath (Join-Path $projectRoot `
    'tools\toolchain.lock.json') -Raw -Encoding UTF8 | ConvertFrom-Json
$collectorHash = (Get-FileHash -Algorithm SHA256 -LiteralPath `
    (Join-Path $PSScriptRoot 'gui\physical-device-evidence.ahk')).Hash
$testRoot = Join-Path $projectRoot `
    ('.build\physical-evidence-verifier-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Force -Path $testRoot | Out-Null

function New-DeviceReport {
    param(
        [string]$Id,
        [string]$Type,
        [int]$Down = 0,
        [int]$Up = 0,
        [int]$Move = 0,
        [int]$Wheel = 0,
        [int]$Arrival = 0,
        [int]$Removal = 0,
        [int]$Rebound = 0,
        [string]$Vendor = '25A7',
        [string]$Product = 'FA10'
    )
    $events = $Down + $Up + $Move + $Wheel + $Arrival + $Removal
    return [ordered]@{
        device = [ordered]@{ stable_id = $Id; id = $Id; type = $Type;
            vendor_id = $Vendor; product_id = $Product }
        events = $events
        phases = [ordered]@{ down = $Down; up = $Up; move = $Move;
            wheel = $Wheel; arrival = $Arrival; removal = $Removal }
        names = @()
        lifecycle = [ordered]@{ arrival = $Arrival; removal = $Removal;
            rebound = $Rebound }
    }
}

function New-Evidence {
    param([bool]$Hotplug)
    $keyboardOne = New-DeviceReport -Id 'keyboard-one' -Type keyboard `
        -Down 4 -Up 4 -Arrival ([int]$Hotplug) -Removal ([int]$Hotplug) `
        -Rebound ([int]$Hotplug) -Product FA10
    $keyboardTwo = New-DeviceReport -Id 'keyboard-two' -Type keyboard `
        -Down 3 -Up 3 -Product FA61
    $mouseOne = New-DeviceReport -Id 'mouse-one' -Type mouse -Move 12 `
        -Down 1 -Up 1 -Product FA10
    $mouseTwo = New-DeviceReport -Id 'mouse-two' -Type mouse -Move 9 `
        -Wheel 2 -Product FA61
    return [ordered]@{
        schema = 1
        status = 'passed'
        passed = $true
        acceptance_eligible = $true
        created_utc = '20260729T100000Z'
        runtime = [ordered]@{ autohotkey = '2.0.26'; architecture = 'x64';
            executable_sha256 = [string]$lock.tools.autoHotkey.executableSha256 }
        collector = [ordered]@{ script_sha256 = $collectorHash;
            process_id = 1234; list_only = $false }
        duration_ms = 60000
        requirements = [ordered]@{ minimum_keyboards = 2; minimum_mice = 2;
            require_hotplug = $Hotplug }
        summary = [ordered]@{ enumerated_devices = 4; active_keyboards = 2;
            active_mice = 2; held_keys_at_finish = 0; composite_pairs = 2;
            hotplug_passed = $true; error_count = 0 }
        lifecycle = [ordered]@{ arrival = [int]$Hotplug;
            removal = [int]$Hotplug; rebound = [int]$Hotplug }
        devices = @($keyboardOne, $keyboardTwo, $mouseOne, $mouseTwo)
        errors = @()
    }
}

function Write-Evidence {
    param($Evidence, [string]$Name)
    $path = Join-Path $testRoot $Name
    Add-EvidenceSeal $Evidence 'physical-device' `
        ([int]$Evidence.collector.process_id) | Out-Null
    $Evidence | ConvertTo-Json -Depth 12 |
        Set-Content -LiteralPath $path -Encoding UTF8
    return $path
}

function Assert-Rejected {
    param([scriptblock]$Action, [string]$Message)
    $rejected = $false
    try { & $Action | Out-Null } catch { $rejected = $true }
    if (-not $rejected) { throw $Message }
}

try {
    $activityPath = Write-Evidence (New-Evidence $false) 'activity.json'
    $activity = & $verifierPath -EvidencePath $activityPath
    if (-not $activity.Passed -or $activity.ActiveKeyboardIds.Count -ne 2 -or
            $activity.ActiveMouseIds.Count -ne 2 -or
            $activity.CompositePairs -ne 2) {
        throw 'Valid physical activity evidence did not pass verification.'
    }

    $edited = Get-Content -LiteralPath $activityPath -Raw -Encoding UTF8 |
        ConvertFrom-Json
    $edited.summary.active_keyboards = 3
    $edited | ConvertTo-Json -Depth 12 |
        Set-Content -LiteralPath $activityPath -Encoding UTF8
    Assert-Rejected { & $verifierPath -EvidencePath $activityPath } `
        'Physical evidence edited after sealing was accepted.'

    $hotplugPath = Write-Evidence (New-Evidence $true) 'hotplug.json'
    $hotplug = & $verifierPath -EvidencePath $hotplugPath -RequireHotplug
    if (-not $hotplug.Passed -or
            $hotplug.HotplugDeviceIds -notcontains 'keyboard-one') {
        throw 'Valid same-device hot-plug evidence did not pass verification.'
    }

    $listed = New-Evidence $false
    $listed.status = 'listed'
    $listed.passed = $false
    $listed.acceptance_eligible = $false
    $listed.collector.list_only = $true
    $listedPath = Write-Evidence $listed 'listed.json'
    Assert-Rejected { & $verifierPath -EvidencePath $listedPath } `
        'List-only evidence was accepted.'

    $tamperedCounts = New-Evidence $false
    $tamperedCounts.summary.active_keyboards = 3
    $tamperedPath = Write-Evidence $tamperedCounts 'tampered-counts.json'
    Assert-Rejected { & $verifierPath -EvidencePath $tamperedPath } `
        'Tampered active-device counts were accepted.'

    $staleCollector = New-Evidence $false
    $staleCollector.collector.script_sha256 = '0' * 64
    $stalePath = Write-Evidence $staleCollector 'stale-collector.json'
    Assert-Rejected { & $verifierPath -EvidencePath $stalePath } `
        'Evidence from a different physical-device collector was accepted.'

    $splitHotplug = New-Evidence $true
    $splitHotplug.devices[0].lifecycle.rebound = 0
    $splitHotplug.devices[0].lifecycle.arrival = 0
    $splitHotplug.devices[0].phases.arrival = 0
    $splitHotplug.devices[0].events--
    $splitHotplug.devices[1].lifecycle.rebound = 1
    $splitHotplug.devices[1].lifecycle.arrival = 1
    $splitHotplug.devices[1].phases.arrival = 1
    $splitHotplug.devices[1].events++
    $splitPath = Write-Evidence $splitHotplug 'split-hotplug.json'
    Assert-Rejected {
        & $verifierPath -EvidencePath $splitPath -RequireHotplug
    } 'Cross-device hot-plug events were accepted.'
} finally {
    if (Test-Path -LiteralPath $testRoot) {
        Remove-Item -LiteralPath $testRoot -Recurse -Force
    }
}

Write-Host 'Physical-device evidence verifier checks passed.'
