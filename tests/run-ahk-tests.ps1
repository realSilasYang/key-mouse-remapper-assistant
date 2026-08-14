[CmdletBinding()]
param(
    [string]$AutoHotkeyPath = "",
    [switch]$SkipGui,
    [switch]$IncludeGui,
    [switch]$AllowDesktopInput,
    [ValidateRange(10000, 600000)]
    [int]$TestTimeoutMilliseconds = 120000
)

$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
Import-Module (Join-Path $projectRoot 'tools\WindowsProcessArguments.psm1') `
    -Force
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
    $startInfo.Arguments = Join-WindowsProcessArguments $commandArguments
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
    $stdoutHasAhkError = $stdout -match
        '(?m)^.+\(\d+\)\s*:\s*==>(?![ \t]*Warning:)[ \t]*'
    if ($process.ExitCode -ne 0 -or $stderr -or $stdoutHasAhkError) {
        throw "AutoHotkey test failed: $Path`n$stderr`n$stdout"
    }
    Write-Host "PASS $([System.IO.Path]::GetFileName($Path))"
}

if (-not ('sample.ahk (3) : ==> Unexpected token' -match
        '(?m)^.+\(\d+\)\s*:\s*==>(?![ \t]*Warning:)[ \t]*') -or
        ('sample.ahk (3) : ==> Warning: test' -match
        '(?m)^.+\(\d+\)\s*:\s*==>(?![ \t]*Warning:)[ \t]*')) {
    throw 'AutoHotkey stdout diagnostic classification is invalid.'
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
    $startInfo.Arguments = Join-WindowsProcessArguments $commandArguments
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
    (Join-Path $projectRoot '键鼠重映射小助手.ahk')
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
        Invoke-AhkFile $syntaxProbePath @('--syntax-check')
    } finally {
        if (Test-Path -LiteralPath $syntaxProbePath) {
            Remove-Item -LiteralPath $syntaxProbePath -Force
        }
        if (Test-Path -LiteralPath $syntaxProbeMarker) {
            Remove-Item -LiteralPath $syntaxProbeMarker -Force
        }
    }
}
Invoke-AhkFile (Join-Path $projectRoot 'src\Input\CaptureInputGuardWorker.ahk') `
    @('--syntax-check')

$desktopInputTests = @(
    'capture-input-guard-integration-tests.ahk',
    'direct-hotkey-output-integration-tests.ahk'
)
foreach ($testFile in Get-ChildItem -LiteralPath `
        (Join-Path $PSScriptRoot 'core') -Filter '*-tests.ahk' `
        -File | Sort-Object Name) {
    if (-not $AllowDesktopInput -and $testFile.Name -in $desktopInputTests) {
        Write-Host "SKIP $($testFile.Name) (pass -AllowDesktopInput to enable)"
        continue
    }
    Invoke-AhkFile $testFile.FullName
}

$runGui = $IncludeGui -and -not $SkipGui
if ($runGui) {
    $guiMutex = [System.Threading.Mutex]::new($false,
        'Local\KeyMouseRemapperAssistant.GuiTestSuite')
    $ownsGuiMutex = $false
    $offscreenChanged = $false
    $previousOffscreenSetting = $env:KEY_MOUSE_REMAPPER_GUI_TEST_OFFSCREEN
    try {
        try {
            $ownsGuiMutex = $guiMutex.WaitOne([TimeSpan]::FromMinutes(5))
        } catch [System.Threading.AbandonedMutexException] {
            $ownsGuiMutex = $true
        }
        if (-not $ownsGuiMutex) {
            throw 'Timed out waiting for the shared desktop GUI test mutex.'
        }
        $env:KEY_MOUSE_REMAPPER_GUI_TEST_OFFSCREEN = '1'
        $offscreenChanged = $true
        foreach ($testFile in Get-ChildItem -LiteralPath `
                (Join-Path $PSScriptRoot 'gui') -Filter '*-tests.ahk' `
                -File | Sort-Object Name) {
            Invoke-AhkFile $testFile.FullName
        }
    } finally {
        if ($offscreenChanged) {
            if ($null -eq $previousOffscreenSetting) {
                Remove-Item Env:KEY_MOUSE_REMAPPER_GUI_TEST_OFFSCREEN `
                    -ErrorAction SilentlyContinue
            } else {
                $env:KEY_MOUSE_REMAPPER_GUI_TEST_OFFSCREEN = `
                    $previousOffscreenSetting
            }
        }
        if ($ownsGuiMutex) {
            $guiMutex.ReleaseMutex()
        }
        $guiMutex.Dispose()
    }
} else {
    Write-Host 'SKIP GUI tests (pass -IncludeGui to run the full visual suite)'
}
