[CmdletBinding()]
param(
    [string]$AutoHotkeyPath = "",
    [switch]$SkipGui,
    [switch]$AllowDesktopInput,
    [ValidateRange(10000, 600000)]
    [int]$TestTimeoutMilliseconds = 120000
)

$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$toolchainLockPath = Join-Path $projectRoot 'tools\toolchain.lock.json'
$toolchainLock = Get-Content -LiteralPath $toolchainLockPath -Raw `
    -Encoding UTF8 | ConvertFrom-Json
$requiredAhkVersion = [string]$toolchainLock.tools.autoHotkey.version
$lockedLocalAhk = Join-Path $projectRoot `
    ('.tools\autoHotkey-{0}\AutoHotkey64.exe' -f $requiredAhkVersion)

if ($AutoHotkeyPath) {
    $candidates = @($AutoHotkeyPath)
} elseif ($env:AUTOHOTKEY_EXE) {
    $candidates = @($env:AUTOHOTKEY_EXE)
} else {
    $candidates = @(
        $lockedLocalAhk,
        'D:\Program Files\AutoHotkey\v2\AutoHotkey64.exe',
        "$env:ProgramFiles\AutoHotkey\v2\AutoHotkey64.exe"
    )
}
$candidates = $candidates |
    Where-Object { $_ -and (Test-Path -LiteralPath $_ -PathType Leaf) }
$ahkPath = $candidates | Select-Object -First 1
if (-not $ahkPath) {
    throw "AutoHotkey $requiredAhkVersion 64-bit was not found. " +
        'Run tools/bootstrap-toolchain.ps1 first.'
}
$ahkPath = (Resolve-Path -LiteralPath $ahkPath).Path
try {
    $actualAhkVersion = ([Version](Get-Item -LiteralPath $ahkPath).VersionInfo.FileVersion).
        ToString(3)
} catch {
    throw "Unable to read the AutoHotkey version from $ahkPath."
}
if ($actualAhkVersion -cne $requiredAhkVersion) {
    throw "AutoHotkey $requiredAhkVersion is required; found " +
        "$actualAhkVersion at $ahkPath."
}

function Invoke-AhkFile {
    param([string]$Path, [string[]]$Arguments = @())
    $startInfo = [System.Diagnostics.ProcessStartInfo]::new()
    $startInfo.FileName = $ahkPath
    $startInfo.UseShellExecute = $false
    $startInfo.CreateNoWindow = $true
    $startInfo.RedirectStandardOutput = $true
    $startInfo.RedirectStandardError = $true
    $startInfo.StandardOutputEncoding = [System.Text.Encoding]::Default
    $startInfo.StandardErrorEncoding = [System.Text.Encoding]::Default
    $commandArguments = @('/ErrorStdOut', $Path) + $Arguments
    $startInfo.Arguments = ($commandArguments | ForEach-Object {
        '"' + ([string]$_).Replace('"', '\"') + '"'
    }) -join ' '
    $process = [System.Diagnostics.Process]::Start($startInfo)
    $stdoutTask = $process.StandardOutput.ReadToEndAsync()
    $stderrTask = $process.StandardError.ReadToEndAsync()
    if (-not $process.WaitForExit($TestTimeoutMilliseconds)) {
        try { $process.Kill(); $process.WaitForExit() } catch {}
        throw "AutoHotkey test timed out after " +
            "$TestTimeoutMilliseconds ms: $Path"
    }
    $stdout = $stdoutTask.GetAwaiter().GetResult()
    $stderr = $stderrTask.GetAwaiter().GetResult()
    if ($process.ExitCode -ne 0 -or $stderr) {
        throw "AutoHotkey test failed: $Path`n$stderr`n$stdout"
    }
    Write-Host "PASS $([System.IO.Path]::GetFileName($Path))"
}

function Assert-AhkFileFails {
    param(
        [string]$Path,
        [string[]]$Arguments = @(),
        [string]$ExpectedError = ''
    )
    $startInfo = [System.Diagnostics.ProcessStartInfo]::new()
    $startInfo.FileName = $ahkPath
    $startInfo.UseShellExecute = $false
    $startInfo.CreateNoWindow = $true
    $startInfo.RedirectStandardOutput = $true
    $startInfo.RedirectStandardError = $true
    $startInfo.StandardOutputEncoding = [System.Text.Encoding]::Default
    $startInfo.StandardErrorEncoding = [System.Text.Encoding]::Default
    $commandArguments = @('/ErrorStdOut', $Path) + $Arguments
    $startInfo.Arguments = ($commandArguments | ForEach-Object {
        '"' + ([string]$_).Replace('"', '\"') + '"'
    }) -join ' '
    $process = [System.Diagnostics.Process]::Start($startInfo)
    $stdoutTask = $process.StandardOutput.ReadToEndAsync()
    $stderrTask = $process.StandardError.ReadToEndAsync()
    if (-not $process.WaitForExit($TestTimeoutMilliseconds)) {
        try { $process.Kill(); $process.WaitForExit() } catch {}
        throw "Expected-failure AutoHotkey test timed out: $Path"
    }
    $stdout = $stdoutTask.GetAwaiter().GetResult()
    $stderr = $stderrTask.GetAwaiter().GetResult()
    if ($process.ExitCode -eq 0 -or [string]::IsNullOrWhiteSpace($stderr) -or
            ($ExpectedError -and $stderr -notlike "*$ExpectedError*")) {
        throw "AutoHotkey file did not fail as expected: $Path`n$stderr`n$stdout"
    }
    Write-Host "PASS rejected unbootstrapped $([System.IO.Path]::GetFileName($Path))"
}

$entryPaths = @(
    (Join-Path $projectRoot '键鼠重映射小助手.ahk'),
    (Join-Path $projectRoot 'key-mouse-remapper-assistant-cli.ahk'),
    (Join-Path $projectRoot 'workers\input-engine-worker.ahk')
)
foreach ($entryPath in $entryPaths) {
    $syntaxProbeDirectory = Split-Path -Parent $entryPath
    $syntaxProbePath = Join-Path $syntaxProbeDirectory `
        ('.syntax-check-{0}.ahk' -f [guid]::NewGuid().ToString('N'))
    $syntaxProbeMarker = $syntaxProbePath + '.active'
    try {
        [System.IO.File]::WriteAllText($syntaxProbeMarker, [string]$PID,
            [System.Text.UTF8Encoding]::new($false))
        Copy-Item -LiteralPath $entryPath -Destination $syntaxProbePath
        $syntaxArguments = if ($entryPath -like '*key-mouse-remapper-assistant-cli.ahk') {
            @('help')
        } else {
            @('--syntax-check')
        }
        Invoke-AhkFile $syntaxProbePath $syntaxArguments
    } finally {
        if (Test-Path -LiteralPath $syntaxProbePath) {
            Remove-Item -LiteralPath $syntaxProbePath -Force
        }
        if (Test-Path -LiteralPath $syntaxProbeMarker) {
            Remove-Item -LiteralPath $syntaxProbeMarker -Force
        }
    }
}
Assert-AhkFileFails (Join-Path $projectRoot `
    'workers\input-engine-worker.ahk') @() 'KMR_WORKER_BOOTSTRAP_REQUIRED'
foreach ($testFile in Get-ChildItem -LiteralPath (Join-Path $PSScriptRoot 'core') `
        -Filter '*-tests.ahk' -File | Sort-Object Name) {
    $testArguments = @()
    if ($testFile.Name -ceq 'key-capture-session-tests.ahk' -and
            -not $AllowDesktopInput) {
        $testArguments = @('--skip-desktop-input')
        Write-Host ('SKIP injected desktop-input assertions in ' +
            $testFile.Name + '; pass -AllowDesktopInput to enable them.')
    }
    Invoke-AhkFile $testFile.FullName $testArguments
}
if (-not $SkipGui) {
    $guiMutex = [System.Threading.Mutex]::new($false,
        'Local\KeyMouseRemapperAssistant.GuiTestSuite')
    $ownsGuiMutex = $false
    try {
        try {
            $ownsGuiMutex = $guiMutex.WaitOne([TimeSpan]::FromMinutes(5))
        } catch [System.Threading.AbandonedMutexException] {
            $ownsGuiMutex = $true
        }
        if (-not $ownsGuiMutex) {
            throw 'Timed out waiting for the shared desktop GUI test mutex.'
        }
        foreach ($testFile in Get-ChildItem -LiteralPath `
                (Join-Path $PSScriptRoot 'gui') -Filter '*-tests.ahk' `
                -File | Sort-Object Name) {
            Invoke-AhkFile $testFile.FullName
        }
    } finally {
        if ($ownsGuiMutex) {
            $guiMutex.ReleaseMutex()
        }
        $guiMutex.Dispose()
    }
}
