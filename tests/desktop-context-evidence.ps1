[CmdletBinding()]
param(
    [string]$OutputPath = '',
    [ValidateRange(60, 1800)][int]$DurationSeconds = 300,
    [switch]$ListOnly,
    [switch]$Force
)

$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
Import-Module (Join-Path $projectRoot 'tools\EvidenceSeal.psm1') -Force
Import-Module (Join-Path $projectRoot 'tools\BuildPathSafety.psm1') -Force
Import-Module (Join-Path $projectRoot 'tools\WindowsProcessArguments.psm1') `
    -Force
$lockPath = Join-Path $projectRoot 'tools\toolchain.lock.json'
$lock = Get-Content -LiteralPath $lockPath -Raw -Encoding UTF8 |
    ConvertFrom-Json
$requiredVersion = [string]$lock.tools.autoHotkey.version
$runtimeDirectory = Join-Path $projectRoot `
    ('.tools\autoHotkey-' + $requiredVersion)
$runtimePath = Join-Path $runtimeDirectory $lock.tools.autoHotkey.executable
if (-not (Test-Path -LiteralPath $runtimePath -PathType Leaf)) {
    throw "Locked AutoHotkey runtime is missing: $runtimePath"
}
$runtimeHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $runtimePath).Hash
if ($runtimeHash -ne $lock.tools.autoHotkey.executableSha256) {
    throw "Locked AutoHotkey runtime hash mismatch: $runtimeHash"
}

$collectorPath = Join-Path $PSScriptRoot 'gui\desktop-context-evidence.ahk'
if (-not (Test-Path -LiteralPath $collectorPath -PathType Leaf)) {
    throw "Desktop-context collector is missing: $collectorPath"
}
$collectorHash = (Get-FileHash -Algorithm SHA256 `
    -LiteralPath $collectorPath).Hash

if (-not $OutputPath) {
    $stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
    $OutputPath = Join-Path $projectRoot `
        ".build\desktop-context-evidence-$stamp.json"
}
$OutputPath = Get-NormalizedBuildPath $OutputPath 'Evidence output path'
$outputDirectory = Assert-SafeBuildRoot (Split-Path -Parent $OutputPath) `
    'Evidence output directory'
$OutputPath = Assert-SafeBuildChild $outputDirectory $OutputPath `
    'Evidence output path'
if ((Test-Path -LiteralPath $OutputPath) -and -not $Force) {
    throw "Evidence output already exists; use -Force to replace it: $OutputPath"
}
New-Item -ItemType Directory -Force -Path $outputDirectory | Out-Null
Assert-SafeBuildRoot $outputDirectory 'Evidence output directory' | Out-Null

$arguments = @(
    '/ErrorStdOut',
    $collectorPath,
    '--output', $OutputPath,
    '--duration', [string]$DurationSeconds,
    '--runtime-sha256', $runtimeHash,
    '--collector-sha256', $collectorHash
)
if ($ListOnly) { $arguments += '--list-only' }

$startInfo = [System.Diagnostics.ProcessStartInfo]::new()
$startInfo.FileName = $runtimePath
$startInfo.UseShellExecute = $false
$startInfo.CreateNoWindow = $true
$startInfo.RedirectStandardOutput = $true
$startInfo.RedirectStandardError = $true
$startInfo.Arguments = Join-WindowsProcessArguments $arguments
$process = [System.Diagnostics.Process]::Start($startInfo)
$stdoutTask = $process.StandardOutput.ReadToEndAsync()
$stderrTask = $process.StandardError.ReadToEndAsync()
$timeoutMilliseconds = if ($ListOnly) { 30000 } else {
    ($DurationSeconds + 45) * 1000
}
if (-not $process.WaitForExit($timeoutMilliseconds)) {
    try { $process.Kill(); $process.WaitForExit() } catch {}
    throw "Desktop-context collector timed out after $timeoutMilliseconds ms."
}
$collectorExitCode = $process.ExitCode
$collectorStdout = $stdoutTask.GetAwaiter().GetResult()
$collectorStderr = $stderrTask.GetAwaiter().GetResult()
if ($collectorStdout.Trim()) { Write-Host $collectorStdout.TrimEnd() }
if ($collectorStderr.Trim()) { Write-Error $collectorStderr.TrimEnd() }
if (-not (Test-Path -LiteralPath $OutputPath -PathType Leaf)) {
    throw "Desktop-context collector produced no evidence file " +
        "(exit $collectorExitCode)."
}
$evidence = Get-Content -LiteralPath $OutputPath -Raw -Encoding UTF8 |
    ConvertFrom-Json
if ([int]$evidence.collector.process_id -ne $process.Id -or
        [string]$evidence.runtime.autohotkey -cne $requiredVersion -or
        [string]$evidence.runtime.executable_sha256 -cne $runtimeHash -or
        [string]$evidence.collector.script_sha256 -cne $collectorHash) {
    throw 'Desktop-context evidence identity does not match the launched collector.'
}
Add-EvidenceSeal $evidence 'desktop-context' $process.Id | Out-Null
$sealedTemporary = $OutputPath + '.seal-' + [guid]::NewGuid().ToString('N')
$sealedTemporary = Assert-SafeBuildChild $outputDirectory $sealedTemporary `
    'Temporary sealed evidence path'
try {
    [IO.File]::WriteAllText($sealedTemporary,
        ($evidence | ConvertTo-Json -Depth 64),
        [Text.UTF8Encoding]::new($false))
    Move-Item -LiteralPath $sealedTemporary -Destination $OutputPath -Force
} finally {
    if (Test-Path -LiteralPath $sealedTemporary) {
        Remove-Item -LiteralPath $sealedTemporary -Force
    }
}
if ($ListOnly -and ([bool]$evidence.passed -or
        [bool]$evidence.acceptance_eligible)) {
    throw 'List-only evidence must never be accepted as desktop proof.'
}
[pscustomobject]@{
    Status = $evidence.status
    Passed = [bool]$evidence.passed
    AcceptanceEligible = [bool]$evidence.acceptance_eligible
    OutputPath = $OutputPath
    DurationMilliseconds = $evidence.duration_ms
    Samples = $evidence.summary.sample_count
    Events = $evidence.summary.event_count
    LockCycle = [bool]$evidence.summary.lock_cycle
    Rdp = [bool]$evidence.summary.rdp
    SleepResume = [bool]$evidence.summary.sleep_resume
    ElevatedFocus = [bool]$evidence.summary.elevated_focus
    SecureDesktop = [bool]$evidence.summary.secure_desktop
    LayoutSwitch = [bool]$evidence.summary.layout_switch
    ErrorCount = $evidence.summary.error_count
    Runtime = $evidence.runtime.autohotkey
} | Format-List

if ($collectorExitCode -ne 0) {
    exit $collectorExitCode
}
