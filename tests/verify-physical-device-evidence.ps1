[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$EvidencePath,
    [switch]$RequireHotplug,
    [ValidateRange(0, 16)][int]$MinimumCompositePairs = 1
)

$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
Import-Module (Join-Path $projectRoot 'tools\EvidenceSeal.psm1') -Force
Import-Module (Join-Path $projectRoot 'tools\BuildPathSafety.psm1') -Force
$resolvedPath = Assert-NoReparsePointInPath $EvidencePath `
    'Physical-device evidence'
if (-not (Test-Path -LiteralPath $resolvedPath -PathType Leaf)) {
    throw "Physical-device evidence is missing: $resolvedPath"
}
$evidenceSize = (Get-Item -LiteralPath $resolvedPath).Length
if ($evidenceSize -le 0 -or $evidenceSize -gt 16777216) {
    throw 'Physical-device evidence is empty or exceeds the 16 MiB limit.'
}
$lock = Get-Content -LiteralPath (Join-Path $projectRoot `
    'tools\toolchain.lock.json') -Raw -Encoding UTF8 | ConvertFrom-Json
$requiredAhkVersion = [string]$lock.tools.autoHotkey.version
$requiredRuntimeHash = [string]$lock.tools.autoHotkey.executableSha256
$collectorPath = Join-Path $PSScriptRoot 'gui\physical-device-evidence.ahk'
if (-not (Test-Path -LiteralPath $collectorPath -PathType Leaf)) {
    throw "Physical-device collector is missing: $collectorPath"
}
$requiredCollectorHash = (Get-FileHash -Algorithm SHA256 `
    -LiteralPath $collectorPath).Hash
$evidence = Get-Content -LiteralPath $resolvedPath -Raw -Encoding UTF8 |
    ConvertFrom-Json

function Assert-EvidenceCondition {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) { throw $Message }
}

function Get-NonNegativeInteger {
    param($Value, [string]$Field)
    try { $number = [long]$Value } catch {
        throw "Physical-device evidence field is not an integer: $Field"
    }
    if ($number -lt 0) {
        throw "Physical-device evidence field is negative: $Field"
    }
    return $number
}

function Get-BooleanValue {
    param($Value, [string]$Field)
    if ($Value -isnot [bool]) {
        throw "Physical-device evidence field is not Boolean: $Field"
    }
    return [bool]$Value
}

Assert-EvidenceCondition ([int]$evidence.schema -eq 1) `
    'Physical-device evidence schema is unsupported.'
Assert-EvidenceCondition ($evidence.status -ceq 'passed') `
    'Physical-device evidence status is not passed.'
Assert-EvidenceCondition (Get-BooleanValue $evidence.passed 'passed') `
    'Physical-device evidence does not report passed=true.'
Assert-EvidenceCondition `
    (Get-BooleanValue $evidence.acceptance_eligible 'acceptance_eligible') `
    'Physical-device evidence is not eligible for acceptance.'
Assert-EvidenceCondition `
    ($evidence.runtime.autohotkey -ceq $requiredAhkVersion -and
        $evidence.runtime.architecture -ceq 'x64') `
    'Physical-device evidence did not use the locked x64 runtime.'
Assert-EvidenceCondition `
    ([string]$evidence.runtime.executable_sha256 -ceq $requiredRuntimeHash) `
    'Physical-device evidence runtime hash is not the locked runtime.'
Assert-EvidenceCondition `
    ([string]$evidence.collector.script_sha256 -ceq $requiredCollectorHash) `
    'Physical-device evidence came from a different collector.'
$collectorProcessId = Get-NonNegativeInteger `
    $evidence.collector.process_id 'collector.process_id'
Assert-EvidenceCondition ($collectorProcessId -gt 0) `
    'Physical-device evidence collector process ID is invalid.'
Assert-EvidenceCondition `
    (-not (Get-BooleanValue $evidence.collector.list_only `
        'collector.list_only')) `
    'List-only physical-device evidence cannot be accepted.'
Assert-EvidenceSeal $evidence 'physical-device' $collectorProcessId | Out-Null

$createdUtc = [DateTimeOffset]::MinValue
Assert-EvidenceCondition `
    ([DateTimeOffset]::TryParseExact([string]$evidence.created_utc,
        'yyyy-MM-ddTHH:mm:ssZ', [Globalization.CultureInfo]::InvariantCulture,
        [Globalization.DateTimeStyles]::AssumeUniversal, [ref]$createdUtc)) `
    'Physical-device evidence created_utc is invalid.'
$duration = Get-NonNegativeInteger $evidence.duration_ms 'duration_ms'
Assert-EvidenceCondition ($duration -ge 5000 -and $duration -le 905000) `
    'Physical-device evidence duration is outside the accepted range.'

$minimumKeyboards = Get-NonNegativeInteger `
    $evidence.requirements.minimum_keyboards 'requirements.minimum_keyboards'
$minimumMice = Get-NonNegativeInteger `
    $evidence.requirements.minimum_mice 'requirements.minimum_mice'
$evidenceRequiresHotplug = Get-BooleanValue `
    $evidence.requirements.require_hotplug 'requirements.require_hotplug'
Assert-EvidenceCondition ($minimumKeyboards -ge 2 -and $minimumMice -ge 2) `
    'Acceptance evidence must require at least two keyboards and two mice.'
Assert-EvidenceCondition ($evidenceRequiresHotplug -eq [bool]$RequireHotplug) `
    'Physical-device evidence hot-plug mode does not match the verifier mode.'

$devices = @($evidence.devices)
$enumeratedDevices = Get-NonNegativeInteger `
    $evidence.summary.enumerated_devices 'summary.enumerated_devices'
Assert-EvidenceCondition ($devices.Count -eq $enumeratedDevices) `
    'Enumerated device count does not match the device reports.'

$stableIds = @{}
$activeKeyboardIds = [Collections.Generic.List[string]]::new()
$activeMouseIds = [Collections.Generic.List[string]]::new()
$hotplugIds = [Collections.Generic.List[string]]::new()
$compositePairs = @{}
$lifecycleTotals = @{ arrival = 0L; removal = 0L; rebound = 0L }

foreach ($report in $devices) {
    $device = $report.device
    $stableId = [string]$device.stable_id
    Assert-EvidenceCondition (-not [string]::IsNullOrWhiteSpace($stableId)) `
        'A physical-device report has no stable device ID.'
    Assert-EvidenceCondition (-not $stableIds.ContainsKey($stableId)) `
        "Physical-device evidence contains duplicate stable ID: $stableId"
    $stableIds[$stableId] = $true

    $phaseValues = @{}
    $phaseTotal = 0L
    foreach ($phase in @('down', 'up', 'move', 'wheel', 'arrival', 'removal')) {
        $value = Get-NonNegativeInteger $report.phases.$phase `
            "devices[$stableId].phases.$phase"
        $phaseValues[$phase] = $value
        $phaseTotal += $value
    }
    $eventCount = Get-NonNegativeInteger $report.events `
        "devices[$stableId].events"
    Assert-EvidenceCondition ($eventCount -ge $phaseTotal) `
        "Device event count is smaller than its phase total: $stableId"

    $deviceLifecycle = @{}
    foreach ($phase in @('arrival', 'removal', 'rebound')) {
        $value = Get-NonNegativeInteger $report.lifecycle.$phase `
            "devices[$stableId].lifecycle.$phase"
        $deviceLifecycle[$phase] = $value
        $lifecycleTotals[$phase] += $value
    }
    if ($deviceLifecycle.removal -gt 0 -and
            ($deviceLifecycle.arrival + $deviceLifecycle.rebound) -gt 0) {
        $hotplugIds.Add($stableId)
    }

    $type = [string]$device.type
    if ($type -ceq 'keyboard' -and $phaseValues.down -gt 0 -and
            $phaseValues.up -gt 0) {
        $activeKeyboardIds.Add($stableId)
    }
    if ($type -ceq 'mouse' -and ($phaseValues.move -gt 0 -or
            $phaseValues.wheel -gt 0 -or ($phaseValues.down -gt 0 -and
                $phaseValues.up -gt 0))) {
        $activeMouseIds.Add($stableId)
    }

    $vendorId = [string]$device.vendor_id
    $productId = [string]$device.product_id
    if ($vendorId -and $productId -and $type -in @('keyboard', 'mouse')) {
        $pairId = "$vendorId`:$productId"
        if (-not $compositePairs.ContainsKey($pairId)) {
            $compositePairs[$pairId] = @{ keyboard = $false; mouse = $false }
        }
        $compositePairs[$pairId][$type] = $true
    }
}

$compositePairCount = @($compositePairs.GetEnumerator() | Where-Object {
    $_.Value.keyboard -and $_.Value.mouse
}).Count
$summaryKeyboards = Get-NonNegativeInteger `
    $evidence.summary.active_keyboards 'summary.active_keyboards'
$summaryMice = Get-NonNegativeInteger `
    $evidence.summary.active_mice 'summary.active_mice'
$summaryPairs = Get-NonNegativeInteger `
    $evidence.summary.composite_pairs 'summary.composite_pairs'
$heldKeys = Get-NonNegativeInteger `
    $evidence.summary.held_keys_at_finish 'summary.held_keys_at_finish'
$errorCount = Get-NonNegativeInteger `
    $evidence.summary.error_count 'summary.error_count'

Assert-EvidenceCondition ($summaryKeyboards -eq $activeKeyboardIds.Count -and
        $summaryMice -eq $activeMouseIds.Count) `
    'Active keyboard or mouse summary does not match the device reports.'
Assert-EvidenceCondition ($summaryKeyboards -ge $minimumKeyboards -and
        $summaryMice -ge $minimumMice) `
    'Physical-device evidence did not activate the required device counts.'
Assert-EvidenceCondition ($summaryPairs -eq $compositePairCount -and
        $summaryPairs -ge $MinimumCompositePairs) `
    'Physical-device evidence did not prove the required composite pairs.'
Assert-EvidenceCondition ($heldKeys -eq 0) `
    'Physical-device evidence finished with held keys.'
Assert-EvidenceCondition ($errorCount -eq 0 -and @($evidence.errors).Count -eq 0) `
    'Physical-device evidence contains collector errors.'

foreach ($phase in @('arrival', 'removal', 'rebound')) {
    $summaryValue = Get-NonNegativeInteger $evidence.lifecycle.$phase `
        "lifecycle.$phase"
    Assert-EvidenceCondition ($summaryValue -eq $lifecycleTotals[$phase]) `
        "Lifecycle summary does not match device reports: $phase"
}
$hotplugPassed = Get-BooleanValue `
    $evidence.summary.hotplug_passed 'summary.hotplug_passed'
Assert-EvidenceCondition $hotplugPassed `
    'Physical-device evidence reports a failed hot-plug requirement.'
if ($RequireHotplug) {
    Assert-EvidenceCondition ($hotplugIds.Count -gt 0) `
        'No stable device completed both removal and return/rebind.'
}

[pscustomobject]@{
    EvidencePath = $resolvedPath
    Sha256 = (Get-FileHash -Algorithm SHA256 -LiteralPath $resolvedPath).Hash
    CreatedUtc = $createdUtc.UtcDateTime
    DurationMilliseconds = $duration
    ActiveKeyboardIds = @($activeKeyboardIds)
    ActiveMouseIds = @($activeMouseIds)
    CompositePairs = $compositePairCount
    HotplugDeviceIds = @($hotplugIds)
    Runtime = $requiredAhkVersion
    Passed = $true
}
