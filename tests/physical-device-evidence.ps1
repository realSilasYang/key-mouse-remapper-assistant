[CmdletBinding()]
param(
    [string]$OutputPath = '',
    [ValidateRange(5, 900)][int]$DurationSeconds = 60,
    [ValidateRange(1, 16)][int]$MinimumKeyboards = 2,
    [ValidateRange(1, 16)][int]$MinimumMice = 2,
    [switch]$RequireHotplug,
    [switch]$ListOnly,
    [switch]$Force
)

$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
Import-Module (Join-Path $projectRoot 'tools\EvidenceSeal.psm1') -Force
Import-Module (Join-Path $projectRoot 'tools\BuildPathSafety.psm1') -Force
$lockPath = Join-Path $projectRoot 'tools\toolchain.lock.json'
$lock = Get-Content -LiteralPath $lockPath -Raw -Encoding UTF8 |
    ConvertFrom-Json
$runtimeDirectory = Join-Path $projectRoot `
    ('.tools\autoHotkey-' + $lock.tools.autoHotkey.version)
$runtimePath = Join-Path $runtimeDirectory $lock.tools.autoHotkey.executable
if (-not (Test-Path -LiteralPath $runtimePath -PathType Leaf)) {
    throw "Locked AutoHotkey runtime is missing: $runtimePath"
}
$runtimeHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $runtimePath).Hash
if ($runtimeHash -ne $lock.tools.autoHotkey.executableSha256) {
    throw "Locked AutoHotkey runtime hash mismatch: $runtimeHash"
}
$scriptPath = Join-Path $PSScriptRoot 'gui\physical-device-evidence.ahk'
if (-not (Test-Path -LiteralPath $scriptPath -PathType Leaf)) {
    throw "Physical-device collector is missing: $scriptPath"
}
$collectorHash = (Get-FileHash -Algorithm SHA256 `
    -LiteralPath $scriptPath).Hash

if (-not $OutputPath) {
    $stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
    $OutputPath = Join-Path $projectRoot `
        ".build\physical-device-evidence-$stamp.json"
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
    $scriptPath,
    '--output', $OutputPath,
    '--duration', [string]$DurationSeconds,
    '--min-keyboards', [string]$MinimumKeyboards,
    '--min-mice', [string]$MinimumMice,
    '--runtime-sha256', $runtimeHash,
    '--collector-sha256', $collectorHash
)
if ($RequireHotplug) { $arguments += '--require-hotplug' }
if ($ListOnly) { $arguments += '--list-only' }

$startInfo = [System.Diagnostics.ProcessStartInfo]::new()
$startInfo.FileName = $runtimePath
$startInfo.UseShellExecute = $false
$startInfo.CreateNoWindow = $true
$startInfo.RedirectStandardOutput = $true
$startInfo.RedirectStandardError = $true
$startInfo.Arguments = ($arguments | ForEach-Object {
    '"' + ([string]$_).Replace('"', '\"') + '"'
}) -join ' '
$process = [System.Diagnostics.Process]::Start($startInfo)
$stdoutTask = $process.StandardOutput.ReadToEndAsync()
$stderrTask = $process.StandardError.ReadToEndAsync()
$timeoutMilliseconds = ($DurationSeconds + 30) * 1000
if (-not $process.WaitForExit($timeoutMilliseconds)) {
    try { $process.Kill(); $process.WaitForExit() } catch {}
    throw "Physical-device collector timed out after $timeoutMilliseconds ms."
}
$collectorExitCode = $process.ExitCode
$collectorStdout = $stdoutTask.GetAwaiter().GetResult()
$collectorStderr = $stderrTask.GetAwaiter().GetResult()
if ($collectorStdout.Trim()) { Write-Host $collectorStdout.TrimEnd() }
if ($collectorStderr.Trim()) { Write-Error $collectorStderr.TrimEnd() }
if (-not (Test-Path -LiteralPath $OutputPath -PathType Leaf)) {
    throw "Physical-device collector produced no evidence file " +
        "(exit $collectorExitCode)."
}
$evidence = Get-Content -LiteralPath $OutputPath -Raw -Encoding UTF8 |
    ConvertFrom-Json
if ([int]$evidence.collector.process_id -ne $process.Id -or
        [string]$evidence.runtime.autohotkey -cne
            [string]$lock.tools.autoHotkey.version -or
        [string]$evidence.runtime.executable_sha256 -cne $runtimeHash -or
        [string]$evidence.collector.script_sha256 -cne $collectorHash) {
    throw 'Physical-device evidence identity does not match the launched collector.'
}
Add-EvidenceSeal $evidence 'physical-device' $process.Id | Out-Null
$sealedTemporary = $OutputPath + '.seal-' + [guid]::NewGuid().ToString('N')
$sealedTemporary = Assert-SafeBuildChild $outputDirectory $sealedTemporary `
    'Temporary sealed evidence path'
try {
    [IO.File]::WriteAllText($sealedTemporary,
        ($evidence | ConvertTo-Json -Depth 32),
        [Text.UTF8Encoding]::new($false))
    Move-Item -LiteralPath $sealedTemporary -Destination $OutputPath -Force
} finally {
    if (Test-Path -LiteralPath $sealedTemporary) {
        Remove-Item -LiteralPath $sealedTemporary -Force
    }
}
if ($ListOnly -and ([bool]$evidence.passed -or
        [bool]$evidence.acceptance_eligible)) {
    throw 'List-only evidence must never be accepted as physical-device proof.'
}
[pscustomobject]@{
    Status = $evidence.status
    Passed = [bool]$evidence.passed
    AcceptanceEligible = [bool]$evidence.acceptance_eligible
    OutputPath = $OutputPath
    EnumeratedDevices = $evidence.summary.enumerated_devices
    ActiveKeyboards = $evidence.summary.active_keyboards
    ActiveMice = $evidence.summary.active_mice
    CompositePairs = $evidence.summary.composite_pairs
    HeldKeysAtFinish = $evidence.summary.held_keys_at_finish
    ErrorCount = $evidence.summary.error_count
    Runtime = $evidence.runtime.autohotkey
} | Format-List

if ($collectorExitCode -ne 0) {
    exit $collectorExitCode
}
