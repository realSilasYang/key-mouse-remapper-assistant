[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$EvidencePath
)

$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
Import-Module (Join-Path $projectRoot 'tools\EvidenceSeal.psm1') -Force
Import-Module (Join-Path $projectRoot 'tools\BuildPathSafety.psm1') -Force
$resolvedPath = Assert-NoReparsePointInPath $EvidencePath `
    'Desktop-context evidence'
if (-not (Test-Path -LiteralPath $resolvedPath -PathType Leaf)) {
    throw "Desktop-context evidence is missing: $resolvedPath"
}
$evidenceSize = (Get-Item -LiteralPath $resolvedPath).Length
if ($evidenceSize -le 0 -or $evidenceSize -gt 16777216) {
    throw 'Desktop-context evidence is empty or exceeds the 16 MiB limit.'
}
$lock = Get-Content -LiteralPath (Join-Path $projectRoot `
    'tools\toolchain.lock.json') -Raw -Encoding UTF8 | ConvertFrom-Json
$requiredVersion = [string]$lock.tools.autoHotkey.version
$requiredRuntimeHash = [string]$lock.tools.autoHotkey.executableSha256
$collectorPath = Join-Path $PSScriptRoot 'gui\desktop-context-evidence.ahk'
$requiredCollectorHash = (Get-FileHash -Algorithm SHA256 `
    -LiteralPath $collectorPath).Hash
$evidence = Get-Content -LiteralPath $resolvedPath -Raw -Encoding UTF8 |
    ConvertFrom-Json

function Assert-EvidenceCondition {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) { throw $Message }
}

function Get-RequiredProperty {
    param($Object, [string]$Name, [string]$Path)
    if ($null -eq $Object) {
        throw "Desktop-context evidence object is missing: $Path"
    }
    $property = $Object.PSObject.Properties[$Name]
    if ($null -eq $property) {
        throw "Desktop-context evidence field is missing: $Path.$Name"
    }
    return $property.Value
}

function Get-NonNegativeInteger {
    param($Value, [string]$Field)
    try { $number = [long]$Value } catch {
        throw "Desktop-context evidence field is not an integer: $Field"
    }
    if ($number -lt 0) {
        throw "Desktop-context evidence field is negative: $Field"
    }
    return $number
}

function Get-BooleanValue {
    param($Value, [string]$Field)
    if ($Value -isnot [bool]) {
        throw "Desktop-context evidence field is not Boolean: $Field"
    }
    return [bool]$Value
}

function Assert-UtcTimestamp {
    param([string]$Value, [string]$Field)
    $parsed = [DateTimeOffset]::MinValue
    $valid = [DateTimeOffset]::TryParseExact($Value,
        'yyyy-MM-ddTHH:mm:ssZ', [Globalization.CultureInfo]::InvariantCulture,
        [Globalization.DateTimeStyles]::AssumeUniversal, [ref]$parsed)
    Assert-EvidenceCondition $valid `
        "Desktop-context evidence timestamp is invalid: $Field"
    return $parsed
}

Assert-EvidenceCondition ([int](Get-RequiredProperty $evidence 'schema' `
            'evidence') -eq 1) `
    'Desktop-context evidence schema is unsupported.'
Assert-EvidenceCondition ((Get-RequiredProperty $evidence 'status' `
            'evidence') -ceq 'passed') `
    'Desktop-context evidence status is not passed.'
Assert-EvidenceCondition (Get-BooleanValue `
        (Get-RequiredProperty $evidence 'passed' 'evidence') 'passed') `
    'Desktop-context evidence does not report passed=true.'
Assert-EvidenceCondition (Get-BooleanValue `
        (Get-RequiredProperty $evidence 'acceptance_eligible' 'evidence') `
        'acceptance_eligible') `
    'Desktop-context evidence is not eligible for acceptance.'
$createdUtc = Assert-UtcTimestamp ([string](Get-RequiredProperty $evidence `
        'created_utc' 'evidence')) 'created_utc'

$runtime = Get-RequiredProperty $evidence 'runtime' 'evidence'
Assert-EvidenceCondition `
    ((Get-RequiredProperty $runtime 'autohotkey' 'runtime') -ceq
        $requiredVersion -and
     (Get-RequiredProperty $runtime 'architecture' 'runtime') -ceq 'x64' -and
     (Get-RequiredProperty $runtime 'executable_sha256' 'runtime') -ceq
        $requiredRuntimeHash) `
    'Desktop-context evidence did not use the locked x64 runtime.'

$collector = Get-RequiredProperty $evidence 'collector' 'evidence'
Assert-EvidenceCondition `
    ((Get-RequiredProperty $collector 'script_sha256' 'collector') -ceq
        $requiredCollectorHash) `
    'Desktop-context evidence was produced by a stale or unknown collector.'
Assert-EvidenceCondition (-not (Get-BooleanValue `
        (Get-RequiredProperty $collector 'list_only' 'collector') `
        'collector.list_only')) `
    'List-only desktop-context evidence cannot be accepted.'
Assert-EvidenceCondition (Get-BooleanValue `
        (Get-RequiredProperty $collector 'integrity_known' 'collector') `
        'collector.integrity_known') `
    'Collector integrity level is unknown.'
$collectorIntegrity = Get-NonNegativeInteger `
    (Get-RequiredProperty $collector 'integrity_rid' 'collector') `
    'collector.integrity_rid'
Assert-EvidenceCondition ($collectorIntegrity -ge 0x1000) `
    'Collector integrity RID is invalid.'
$collectorProcessId = Get-NonNegativeInteger `
    (Get-RequiredProperty $collector 'process_id' 'collector') `
    'collector.process_id'
Assert-EvidenceCondition ($collectorProcessId -gt 0) `
    'Collector process ID is invalid.'
Assert-EvidenceSeal $evidence 'desktop-context' $collectorProcessId | Out-Null

$duration = Get-NonNegativeInteger `
    (Get-RequiredProperty $evidence 'duration_ms' 'evidence') 'duration_ms'
Assert-EvidenceCondition ($duration -ge 60000 -and $duration -le 1805000) `
    'Desktop-context evidence duration is outside the accepted range.'

$requirements = Get-RequiredProperty $evidence 'requirements' 'evidence'
foreach ($requirement in @('lock_cycle', 'rdp', 'sleep_resume',
        'elevated_focus', 'secure_desktop', 'layout_switch')) {
    Assert-EvidenceCondition (Get-BooleanValue `
            (Get-RequiredProperty $requirements $requirement 'requirements') `
            "requirements.$requirement") `
        "Acceptance evidence must require $requirement."
}

$samples = @(Get-RequiredProperty $evidence 'samples' 'evidence')
$events = @(Get-RequiredProperty $evidence 'events' 'evidence')
$errors = @(Get-RequiredProperty $evidence 'errors' 'evidence')
Assert-EvidenceCondition ($samples.Count -gt 0) `
    'Desktop-context evidence contains no raw samples.'
Assert-EvidenceCondition ($errors.Count -eq 0) `
    'Desktop-context evidence contains collector errors.'

$lockedSessions = @{}
$unlockedSessions = @{}
$layouts = @{}
$hasRdp = $false
$hasElevatedFocus = $false
$hasSecureDesktop = $false
$previousSampleTick = -1L

for ($index = 0; $index -lt $samples.Count; $index++) {
    $sample = $samples[$index]
    $path = "samples[$index]"
    $sequence = Get-NonNegativeInteger `
        (Get-RequiredProperty $sample 'sequence' $path) "$path.sequence"
    Assert-EvidenceCondition ($sequence -eq $index + 1) `
        "Desktop-context sample sequence is not contiguous: $path"
    $tick = Get-NonNegativeInteger `
        (Get-RequiredProperty $sample 'tick_ms' $path) "$path.tick_ms"
    Assert-EvidenceCondition ($tick -ge $previousSampleTick -and
            $tick -le $duration) `
        "Desktop-context sample timeline is invalid: $path"
    $previousSampleTick = $tick
    Assert-UtcTimestamp ([string](Get-RequiredProperty $sample 'utc' $path)) `
        "$path.utc" | Out-Null

    $session = Get-RequiredProperty $sample 'session' $path
    $sessionIdKnown = Get-BooleanValue `
        (Get-RequiredProperty $session 'session_id_known' "$path.session") `
        "$path.session.session_id_known"
    Assert-EvidenceCondition $sessionIdKnown `
        "Desktop-context sample has no current process session ID: $path"
    $sessionId = Get-NonNegativeInteger `
        (Get-RequiredProperty $session 'session_id' "$path.session") `
        "$path.session.session_id"
    $lockKnown = Get-BooleanValue `
        (Get-RequiredProperty $session 'lock_known' "$path.session") `
        "$path.session.lock_known"
    $lockedValue = Get-RequiredProperty $session 'locked' "$path.session"
    if ($lockKnown) {
        $locked = Get-BooleanValue $lockedValue "$path.session.locked"
        if ($locked) { $lockedSessions[[string]$sessionId] = $true }
        else { $unlockedSessions[[string]$sessionId] = $true }
    } else {
        Assert-EvidenceCondition ($null -eq $lockedValue) `
            "Unknown lock state must use JSON null: $path"
    }
    $remote = Get-BooleanValue `
        (Get-RequiredProperty $session 'remote' "$path.session") `
        "$path.session.remote"
    $protocol = [string](Get-RequiredProperty $session 'protocol' `
        "$path.session")
    if ($remote -and $protocol -ceq 'rdp') {
        $protocolType = Get-NonNegativeInteger `
            (Get-RequiredProperty $session 'protocol_type' "$path.session") `
            "$path.session.protocol_type"
        if ($protocolType -eq 2) { $hasRdp = $true }
    }

    $inputSource = Get-RequiredProperty $sample 'input_source' $path
    Assert-EvidenceCondition (Get-BooleanValue `
            (Get-RequiredProperty $inputSource 'available' `
                "$path.input_source") "$path.input_source.available") `
        "Desktop-context sample has no available foreground HKL: $path"
    $layout = [string](Get-RequiredProperty $inputSource 'layout' `
        "$path.input_source")
    Assert-EvidenceCondition ($layout -match '^[0-9A-F]{8}$') `
        "Desktop-context sample has an invalid foreground HKL: $path"
    $layouts[$layout] = $true

    $foreground = Get-RequiredProperty $sample 'foreground' $path
    foreach ($sensitiveField in @('path', 'process_path', 'title',
            'focused_text')) {
        Assert-EvidenceCondition ($null -eq
                $foreground.PSObject.Properties[$sensitiveField]) `
            "Desktop-context sample contains sensitive field: $path.foreground.$sensitiveField"
    }
    [void](Get-RequiredProperty $foreground 'process' "$path.foreground")
    [void](Get-NonNegativeInteger (Get-RequiredProperty $foreground `
        'process_id' "$path.foreground") "$path.foreground.process_id")
    $focusedHwnd = Get-NonNegativeInteger `
        (Get-RequiredProperty $foreground 'focused_hwnd' "$path.foreground") `
        "$path.foreground.focused_hwnd"
    $integrityKnown = Get-BooleanValue `
        (Get-RequiredProperty $foreground 'integrity_known' `
            "$path.foreground") "$path.foreground.integrity_known"
    if ($integrityKnown) {
        $integrityRid = Get-NonNegativeInteger `
            (Get-RequiredProperty $foreground 'integrity_rid' `
                "$path.foreground") "$path.foreground.integrity_rid"
        if ($integrityRid -ge 0x3000 -and
                $integrityRid -gt $collectorIntegrity -and $focusedHwnd -gt 0) {
            $hasElevatedFocus = $true
        }
    }
    $desktopState = [string](Get-RequiredProperty $session 'desktop_state' `
        "$path.session")
    $desktopError = Get-NonNegativeInteger `
        (Get-RequiredProperty $session 'desktop_error' "$path.session") `
        "$path.session.desktop_error"
    if ($lockKnown -and -not $locked -and $desktopState -ceq 'unavailable' `
            -and $desktopError -eq 5) {
        $hasSecureDesktop = $true
    }
}

$hasLockCycle = $false
foreach ($sessionId in $lockedSessions.Keys) {
    if ($unlockedSessions.ContainsKey($sessionId)) {
        $hasLockCycle = $true
        break
    }
}
$hasLayoutSwitch = $layouts.Count -ge 2
$hasSleepResume = $false
$suspendTick = -1L
$previousEventTick = -1L
for ($index = 0; $index -lt $events.Count; $index++) {
    $event = $events[$index]
    $path = "events[$index]"
    $tick = Get-NonNegativeInteger `
        (Get-RequiredProperty $event 'tick_ms' $path) "$path.tick_ms"
    Assert-EvidenceCondition ($tick -ge $previousEventTick -and
            $tick -le $duration) `
        "Desktop-context event timeline is invalid: $path"
    $previousEventTick = $tick
    Assert-UtcTimestamp ([string](Get-RequiredProperty $event 'utc' $path)) `
        "$path.utc" | Out-Null
    $type = [string](Get-RequiredProperty $event 'type' $path)
    Assert-EvidenceCondition ($type -in @('session', 'power')) `
        "Desktop-context event type is invalid: $path"
    if ($type -ceq 'power') {
        $phase = [string](Get-RequiredProperty $event 'phase' $path)
        Assert-EvidenceCondition ($phase -in @('suspend', 'resume')) `
            "Desktop-context power phase is invalid: $path"
        if ($phase -ceq 'suspend') { $suspendTick = $tick }
        elseif ($suspendTick -ge 0 -and $tick -gt $suspendTick) {
            $hasSleepResume = $true
        }
    } else {
        [void](Get-NonNegativeInteger (Get-RequiredProperty $event `
            'session_id' $path) "$path.session_id")
        [void](Get-RequiredProperty $event 'name' $path)
    }
}

Assert-EvidenceCondition $hasLockCycle `
    'Raw samples do not prove lock and unlock in the same session.'
Assert-EvidenceCondition $hasRdp `
    'Raw samples do not prove an actual WTS RDP protocol.'
Assert-EvidenceCondition $hasSleepResume `
    'Raw events do not prove an ordered suspend and resume cycle.'
Assert-EvidenceCondition $hasElevatedFocus `
    'Raw samples do not prove focus in a higher-integrity process.'
Assert-EvidenceCondition $hasSecureDesktop `
    'Raw samples do not prove an unlocked UAC secure-desktop candidate.'
Assert-EvidenceCondition $hasLayoutSwitch `
    'Raw samples do not prove two foreground keyboard layouts.'

$summary = Get-RequiredProperty $evidence 'summary' 'evidence'
$recomputed = [ordered]@{
    passed = $true
    lock_cycle = $hasLockCycle
    rdp = $hasRdp
    sleep_resume = $hasSleepResume
    elevated_focus = $hasElevatedFocus
    secure_desktop = $hasSecureDesktop
    layout_switch = $hasLayoutSwitch
}
foreach ($name in $recomputed.Keys) {
    $summaryValue = Get-BooleanValue `
        (Get-RequiredProperty $summary $name 'summary') "summary.$name"
    Assert-EvidenceCondition ($summaryValue -eq $recomputed[$name]) `
        "Desktop-context summary does not match raw evidence: $name"
}
Assert-EvidenceCondition ((Get-NonNegativeInteger `
        (Get-RequiredProperty $summary 'distinct_layouts' 'summary') `
        'summary.distinct_layouts') -eq $layouts.Count) `
    'Distinct-layout summary does not match raw samples.'
Assert-EvidenceCondition ((Get-NonNegativeInteger `
        (Get-RequiredProperty $summary 'sample_count' 'summary') `
        'summary.sample_count') -eq $samples.Count) `
    'Sample-count summary does not match raw samples.'
Assert-EvidenceCondition ((Get-NonNegativeInteger `
        (Get-RequiredProperty $summary 'event_count' 'summary') `
        'summary.event_count') -eq $events.Count) `
    'Event-count summary does not match raw events.'
Assert-EvidenceCondition ((Get-NonNegativeInteger `
        (Get-RequiredProperty $summary 'error_count' 'summary') `
        'summary.error_count') -eq 0) `
    'Error-count summary is nonzero.'

[pscustomobject]@{
    EvidencePath = $resolvedPath
    Sha256 = (Get-FileHash -Algorithm SHA256 -LiteralPath $resolvedPath).Hash
    CreatedUtc = $createdUtc.UtcDateTime
    DurationMilliseconds = $duration
    Samples = $samples.Count
    Events = $events.Count
    SessionIds = @($lockedSessions.Keys | Where-Object {
        $unlockedSessions.ContainsKey($_)
    })
    Layouts = @($layouts.Keys | Sort-Object)
    CollectorIntegrityRid = $collectorIntegrity
    Runtime = $requiredVersion
    Passed = $true
}
