[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
Import-Module (Join-Path $projectRoot 'tools\EvidenceSeal.psm1') -Force
$verifierPath = Join-Path $PSScriptRoot `
    'verify-desktop-context-evidence.ps1'
$testRoot = Join-Path $projectRoot `
    ('.build\desktop-evidence-verifier-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Force -Path $testRoot | Out-Null
$lock = Get-Content -LiteralPath (Join-Path $projectRoot `
    'tools\toolchain.lock.json') -Raw -Encoding UTF8 | ConvertFrom-Json
$collectorHash = (Get-FileHash -Algorithm SHA256 -LiteralPath `
    (Join-Path $PSScriptRoot 'gui\desktop-context-evidence.ahk')).Hash

function New-Session {
    param(
        [int]$SessionId,
        [bool]$Locked,
        [bool]$Remote = $false,
        [string]$Protocol = 'console',
        [string]$DesktopState = 'accessible',
        [int]$DesktopError = 0
    )
    return [ordered]@{
        state = if ($Locked) { 'locked' } else { 'active' }
        locked = $Locked
        lock_known = $true
        lock_source = 'wts_session_info_ex'
        lock_error = 0
        remote = $Remote
        remote_known = $true
        remote_source = 'wts_client_protocol'
        protocol = $Protocol
        protocol_type = if ($Protocol -eq 'rdp') { 2 } else { 0 }
        connection_state = 'active'
        connection_state_code = 0
        desktop_state = $DesktopState
        desktop_error = $DesktopError
        session_id = $SessionId
        session_id_known = $true
        session_error = 0
    }
}

function New-Sample {
    param(
        [int]$Sequence,
        [long]$Tick,
        $Session,
        [string]$Layout,
        [int]$IntegrityRid = 0x2000,
        [int]$FocusedHwnd = 100
    )
    return [ordered]@{
        sequence = $Sequence
        tick_ms = $Tick
        utc = '2026-07-29T10:00:00Z'
        reason = 'test'
        session = $Session
        input_source = [ordered]@{
            layout = $Layout
            language_id = $Layout.Substring(4, 4)
            available = $true
            thread_id = 100
        }
        foreground = [ordered]@{
            process = 'test.exe'
            process_id = 100
            hwnd = 100
            thread_id = 100
            focused_hwnd = $FocusedHwnd
            focused_class = 'Edit'
            focus_source = 'get_gui_thread_info'
            integrity_known = $true
            integrity_rid = $IntegrityRid
            integrity_error = 0
        }
    }
}

function New-Evidence {
    $samples = @(
        (New-Sample 1 0 (New-Session 1 $false) '00000409'),
        (New-Sample 2 5000 (New-Session 1 $true) '00000409'),
        (New-Sample 3 10000 (New-Session 1 $false $true 'rdp') '00000804'),
        (New-Sample 4 20000 (New-Session 1 $false) '00000804' 0x3000 200),
        (New-Sample 5 30000 `
            (New-Session 1 $false $false 'console' 'unavailable' 5) `
            '00000804')
    )
    $events = @(
        [ordered]@{ type = 'power'; phase = 'suspend'; name = 'suspend';
            code = 4; tick_ms = 35000; utc = '2026-07-29T10:00:00Z' },
        [ordered]@{ type = 'power'; phase = 'resume';
            name = 'resume_automatic'; code = 18; tick_ms = 45000;
            utc = '2026-07-29T10:00:00Z' }
    )
    return [ordered]@{
        schema = 1
        status = 'passed'
        passed = $true
        acceptance_eligible = $true
        created_utc = '2026-07-29T10:00:00Z'
        runtime = [ordered]@{
            autohotkey = '2.0.26'
            architecture = 'x64'
            executable_sha256 = [string]$lock.tools.autoHotkey.executableSha256
        }
        collector = [ordered]@{
            script_sha256 = $collectorHash
            process_id = 1234
            integrity_known = $true
            integrity_rid = 0x2000
            integrity_error = 0
            list_only = $false
        }
        duration_ms = 60000
        requirements = [ordered]@{
            lock_cycle = $true
            rdp = $true
            sleep_resume = $true
            elevated_focus = $true
            secure_desktop = $true
            layout_switch = $true
        }
        summary = [ordered]@{
            passed = $true
            lock_cycle = $true
            rdp = $true
            sleep_resume = $true
            elevated_focus = $true
            secure_desktop = $true
            layout_switch = $true
            distinct_layouts = 2
            sample_count = 5
            event_count = 2
            error_count = 0
        }
        samples = $samples
        events = $events
        errors = @()
    }
}

function Copy-Evidence {
    param($Evidence)
    return $Evidence | ConvertTo-Json -Depth 20 | ConvertFrom-Json
}

function Write-Evidence {
    param($Evidence, [string]$Name)
    $path = Join-Path $testRoot $Name
    Add-EvidenceSeal $Evidence 'desktop-context' `
        ([int]$Evidence.collector.process_id) | Out-Null
    $Evidence | ConvertTo-Json -Depth 20 |
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
    $valid = New-Evidence
    $validPath = Write-Evidence $valid 'valid.json'
    $result = & $verifierPath -EvidencePath $validPath
    if (-not $result.Passed -or $result.Samples -ne 5 -or
            $result.Layouts.Count -ne 2 -or
            $result.SessionIds -notcontains '1') {
        throw 'Valid desktop-context evidence did not pass verification.'
    }

    $listed = Copy-Evidence $valid
    $listed.status = 'listed'
    $listed.passed = $false
    $listed.acceptance_eligible = $false
    $listed.collector.list_only = $true
    $listedPath = Write-Evidence $listed 'listed.json'
    Assert-Rejected { & $verifierPath -EvidencePath $listedPath } `
        'List-only desktop evidence was accepted.'

    $forgedSummary = Copy-Evidence $valid
    $forgedSummary.samples[2].session.remote = $false
    $forgedSummary.samples[2].session.protocol = 'console'
    $forgedSummary.samples[2].session.protocol_type = 0
    $forgedPath = Write-Evidence $forgedSummary 'forged-summary.json'
    Assert-Rejected { & $verifierPath -EvidencePath $forgedPath } `
        'A passing summary with no raw RDP proof was accepted.'

    $splitSession = Copy-Evidence $valid
    $splitSession.samples[1].session.session_id = 2
    $splitPath = Write-Evidence $splitSession 'split-session.json'
    Assert-Rejected { & $verifierPath -EvidencePath $splitPath } `
        'Lock and unlock from different sessions were accepted.'

    $reversedPower = Copy-Evidence $valid
    $reversedPower.events[0].phase = 'resume'
    $reversedPower.events[1].phase = 'suspend'
    $reversedPath = Write-Evidence $reversedPower 'reversed-power.json'
    Assert-Rejected { & $verifierPath -EvidencePath $reversedPath } `
        'A reversed power cycle was accepted.'

    $lockedSecureDesktop = Copy-Evidence $valid
    $lockedSecureDesktop.samples[4].session.locked = $true
    $lockedSecurePath = Write-Evidence $lockedSecureDesktop `
        'locked-secure-desktop.json'
    Assert-Rejected { & $verifierPath -EvidencePath $lockedSecurePath } `
        'Lock-screen desktop failure was accepted as UAC secure desktop.'

    $sameIntegrity = Copy-Evidence $valid
    $sameIntegrity.samples[3].foreground.integrity_rid = 0x2000
    $sameIntegrityPath = Write-Evidence $sameIntegrity 'same-integrity.json'
    Assert-Rejected { & $verifierPath -EvidencePath $sameIntegrityPath } `
        'Same-integrity focus was accepted as elevated focus.'

    $shortRun = Copy-Evidence $valid
    $shortRun.duration_ms = 59999
    $shortPath = Write-Evidence $shortRun 'short.json'
    Assert-Rejected { & $verifierPath -EvidencePath $shortPath } `
        'A desktop collection shorter than one minute was accepted.'

    $staleCollector = Copy-Evidence $valid
    $staleCollector.collector.script_sha256 = '0' * 64
    $stalePath = Write-Evidence $staleCollector 'stale-collector.json'
    Assert-Rejected { & $verifierPath -EvidencePath $stalePath } `
        'Evidence from a stale collector was accepted.'

    $sensitive = Copy-Evidence $valid
    $sensitive.samples[0].foreground | Add-Member -NotePropertyName title `
        -NotePropertyValue 'sensitive title'
    $sensitivePath = Write-Evidence $sensitive 'sensitive.json'
    Assert-Rejected { & $verifierPath -EvidencePath $sensitivePath } `
        'Evidence containing a foreground title was accepted.'

    $unavailableLayout = Copy-Evidence $valid
    $unavailableLayout.samples[0].input_source.available = $false
    $unavailableLayoutPath = Write-Evidence $unavailableLayout `
        'unavailable-layout.json'
    Assert-Rejected {
        & $verifierPath -EvidencePath $unavailableLayoutPath
    } 'Acceptance evidence with an unavailable foreground HKL was accepted.'

    $tamperedSummary = Copy-Evidence $valid
    $tamperedSummary.summary.sample_count = 6
    $tamperedPath = Write-Evidence $tamperedSummary 'tampered-count.json'
    Assert-Rejected { & $verifierPath -EvidencePath $tamperedPath } `
        'A tampered desktop summary count was accepted.'
} finally {
    if (Test-Path -LiteralPath $testRoot) {
        Remove-Item -LiteralPath $testRoot -Recurse -Force
    }
}

Write-Host 'Desktop-context evidence verifier checks passed.'
