[CmdletBinding()]
param(
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$CliArguments
)

$ErrorActionPreference = 'Stop'
$utf8 = [System.Text.UTF8Encoding]::new($false)
[Console]::InputEncoding = $utf8
[Console]::OutputEncoding = $utf8
$OutputEncoding = $utf8
$projectRoot = $PSScriptRoot
Import-Module (Join-Path $projectRoot 'tools\WindowsProcessArguments.psm1') `
    -Force
$toolchainLock = Get-Content -LiteralPath `
    (Join-Path $projectRoot 'tools\toolchain.lock.json') -Raw -Encoding UTF8 |
    ConvertFrom-Json
$requiredAhkVersion = [string]$toolchainLock.tools.autoHotkey.version
$packagedRuntime = Join-Path $projectRoot 'runtime\AutoHotkey64.exe'
if (Test-Path -LiteralPath $packagedRuntime -PathType Leaf) {
    $manifestPath = Join-Path $projectRoot 'build-manifest.json'
    if (-not (Test-Path -LiteralPath $manifestPath -PathType Leaf)) {
        throw 'The packaged runtime exists but build-manifest.json is missing.'
    }
    $manifest = Get-Content -LiteralPath $manifestPath -Raw -Encoding UTF8 |
        ConvertFrom-Json
    $expectedHash = [string]$manifest.autoHotkeySha256
    if ($expectedHash -notmatch '^[A-Fa-f0-9]{64}$') {
        throw 'The packaged runtime hash in build-manifest.json is invalid.'
    }
    $actualHash = (Get-FileHash -Algorithm SHA256 `
        -LiteralPath $packagedRuntime).Hash
    if ($actualHash -cne $expectedHash.ToUpperInvariant()) {
        throw 'The packaged AutoHotkey runtime failed SHA-256 verification.'
    }
    $runtime = $packagedRuntime
} else {
    $lockedLocalRuntime = Join-Path $projectRoot `
        ('.tools\autoHotkey-{0}\AutoHotkey64.exe' -f $requiredAhkVersion)
    $candidates = @(
        $lockedLocalRuntime,
        'D:\Program Files\AutoHotkey\v2\AutoHotkey64.exe',
        (Join-Path $env:ProgramFiles 'AutoHotkey\v2\AutoHotkey64.exe')
    )
    $runtime = $candidates |
        Where-Object { $_ -and (Test-Path -LiteralPath $_ -PathType Leaf) } |
        Where-Object {
            try {
                ([Version](Get-Item -LiteralPath $_).VersionInfo.FileVersion).
                    ToString(3) -ceq $requiredAhkVersion
            } catch { $false }
        } |
        Select-Object -First 1
    if (-not $runtime) {
        throw "AutoHotkey $requiredAhkVersion 64-bit was not found."
    }
}

$startInfo = [System.Diagnostics.ProcessStartInfo]::new()
$startInfo.FileName = $runtime
$startInfo.UseShellExecute = $false
$startInfo.RedirectStandardOutput = $true
$startInfo.RedirectStandardError = $true
$startInfo.StandardOutputEncoding = $utf8
$startInfo.StandardErrorEncoding = $utf8
$startInfo.Arguments = Join-WindowsProcessArguments `
    (@('/ErrorStdOut',
        (Join-Path $projectRoot 'key-mouse-remapper-assistant-cli.ahk')) +
        $CliArguments)
$process = [System.Diagnostics.Process]::Start($startInfo)
$stdoutTask = $process.StandardOutput.ReadToEndAsync()
$stderrTask = $process.StandardError.ReadToEndAsync()
$process.WaitForExit()
$stdout = $stdoutTask.GetAwaiter().GetResult()
$stderr = $stderrTask.GetAwaiter().GetResult()
if ($stdout) { Write-Output $stdout.TrimEnd("`r", "`n") }
if ($stderr) { [Console]::Error.Write($stderr) }
exit $process.ExitCode
