[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
Import-Module (Join-Path $projectRoot 'tools\WindowsProcessArguments.psm1') `
    -Force
$launchers = @(Get-ChildItem -LiteralPath $projectRoot -Filter '*-CLI.ps1' -File)
if ($launchers.Count -ne 1) {
    throw "Expected exactly one CLI launcher, found $($launchers.Count)."
}
$launcher = $launchers[0].FullName

$lock = Get-Content -LiteralPath `
    (Join-Path $projectRoot 'tools\toolchain.lock.json') -Raw -Encoding UTF8 |
    ConvertFrom-Json
$runtime = Join-Path $projectRoot ('.tools\autoHotkey-{0}\{1}' -f
    $lock.tools.autoHotkey.version, $lock.tools.autoHotkey.executable)
$probeRoot = Join-Path ([System.IO.Path]::GetTempPath()) `
    ('kmr-argv-' + [Guid]::NewGuid().ToString('N'))
$probeScript = Join-Path $probeRoot 'argument-echo.ahk'
$roundTripArguments = @(
    '',
    'plain',
    'two words',
    'quote"inside',
    'C:\folder with space\',
    'slashes\\"quote',
    'trailing\\'
)
try {
    [void](New-Item -ItemType Directory -Path $probeRoot)
    [System.IO.File]::WriteAllText($probeScript, @'
#Requires AutoHotkey v2.0 64-bit
#SingleInstance Off
for argument in A_Args
    FileAppend(StrLen(argument) ":" argument "`n", "*")
ExitApp(0)
'@, [System.Text.UTF8Encoding]::new($false))
    $probeInfo = [System.Diagnostics.ProcessStartInfo]::new()
    $probeInfo.FileName = $runtime
    $probeInfo.UseShellExecute = $false
    $probeInfo.CreateNoWindow = $true
    $probeInfo.RedirectStandardOutput = $true
    $probeInfo.RedirectStandardError = $true
    $probeInfo.Arguments = Join-WindowsProcessArguments `
        (@('/ErrorStdOut', $probeScript) + $roundTripArguments)
    $probe = [System.Diagnostics.Process]::Start($probeInfo)
    $probeStdoutTask = $probe.StandardOutput.ReadToEndAsync()
    $probeStderrTask = $probe.StandardError.ReadToEndAsync()
    if (-not $probe.WaitForExit(10000)) {
        try { $probe.Kill(); $probe.WaitForExit() } catch {}
        throw 'Windows argument quoting probe timed out.'
    }
    $probeStdout = $probeStdoutTask.GetAwaiter().GetResult()
    $probeStderr = $probeStderrTask.GetAwaiter().GetResult()
    if ($probe.ExitCode -ne 0 -or $probeStderr) {
        throw "Windows argument quoting probe failed: $probeStderr"
    }
    $actualArguments = @($probeStdout.TrimEnd("`r", "`n") -split "`r?`n")
    $expectedArguments = @($roundTripArguments | ForEach-Object {
        "$($_.Length):$_"
    })
    if (($actualArguments -join "`n") -cne ($expectedArguments -join "`n")) {
        throw "Windows argument quoting changed argv.`nExpected: " +
            ($expectedArguments -join ' | ') + "`nActual: " +
            ($actualArguments -join ' | ')
    }
} finally {
    if (Test-Path -LiteralPath $probeRoot) {
        Remove-Item -LiteralPath $probeRoot -Recurse -Force
    }
}

$capabilityText = (& $launcher capabilities --pretty) | Out-String
if ($LASTEXITCODE -ne 0) {
    throw "CLI capabilities failed with exit code $LASTEXITCODE."
}
$capabilities = $capabilityText | ConvertFrom-Json
if ($capabilities.backend -ne 'raw-input' -or
    -not $capabilities.available -or
    -not $capabilities.device_identification -or
    $capabilities.requires_driver -or
    $capabilities.device_specific_suppression -or
    $capabilities.suppresses_simple_hotkeys) {
    throw 'CLI capability JSON or UTF-8 output is invalid.'
}

$listText = (& $launcher list --pretty) | Out-String
if ($LASTEXITCODE -ne 0) {
    throw "CLI list failed with exit code $LASTEXITCODE."
}
$rules = $listText | ConvertFrom-Json
if ($rules.count -lt 1 -or
    @($rules.rules | Where-Object purpose -match '[\u4e00-\u9fff]').Count -lt 1) {
    throw 'CLI list did not preserve Chinese JSON text.'
}

$versionText = (& $launcher version --pretty) | Out-String
if ($LASTEXITCODE -ne 0) {
    throw "CLI version failed with exit code $LASTEXITCODE."
}
$version = $versionText | ConvertFrom-Json
if ($version.runtime -ne '2.0.26') {
    throw "CLI launcher used unexpected AutoHotkey $($version.runtime)."
}

Write-Host 'CLI launcher checks passed.'
