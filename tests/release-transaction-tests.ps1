[CmdletBinding()]
param(
    [string]$AutoHotkeyPath = "",
    [string]$CompilerPath = "",
    [string]$AutoHotkeySourcePath = ""
)

$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
Import-Module (Join-Path $projectRoot 'tools\BuildPathSafety.psm1') -Force
$projectRoot = Assert-SafeBuildRoot $projectRoot 'Project root'
$buildScript = Join-Path $projectRoot 'tools\build-release.ps1'
$artifactTest = Join-Path $projectRoot 'tests\release-artifact-tests.ps1'
$testRoot = Assert-SafeBuildChild $projectRoot `
    (Join-Path $projectRoot '.build\release-transaction-tests') `
    'Release transaction test root'
$outputRoot = Join-Path $testRoot 'output'
$stdoutPath = Join-Path $testRoot 'parallel-build.stdout.log'
$stderrPath = Join-Path $testRoot 'parallel-build.stderr.log'
$parallelSuccessMarker = '__KMR_RELEASE_TRANSACTION_CHILD_SUCCESS__'
$parallelProcess = $null
$obsoletePackageName =
    'key-mouse-remapper-assistant-99.98.97-windows-x64'
$obsoletePackageDirectory = Join-Path $outputRoot $obsoletePackageName
$obsoleteZipPath = Join-Path $outputRoot "$obsoletePackageName.zip"

function Invoke-TestReleaseBuild {
    $parameters = @{
        AutoHotkeyPath = $AutoHotkeyPath
        CompilerPath = $CompilerPath
        AutoHotkeySourcePath = $AutoHotkeySourcePath
        OutputRoot = $outputRoot
    }
    & $buildScript @parameters
}

function Get-ReleaseSnapshot {
    param([string]$Root)

    if (-not (Test-Path -LiteralPath $Root -PathType Container)) {
        throw "Release output root is missing: $Root"
    }
    $snapshot = [ordered]@{}
    foreach ($file in @(Get-ChildItem -LiteralPath $Root -Recurse -File |
            Sort-Object FullName)) {
        $relativePath = $file.FullName.Substring($Root.Length).TrimStart('\')
        $snapshot[$relativePath] =
            (Get-FileHash -Algorithm SHA256 -LiteralPath $file.FullName).Hash
    }
    return $snapshot
}

function Assert-SnapshotsEqual {
    param(
        [System.Collections.IDictionary]$Expected,
        [System.Collections.IDictionary]$Actual,
        [string]$Context
    )

    if ($Expected.Count -ne $Actual.Count) {
        throw "$Context changed the release file count: " +
            "$($Expected.Count) != $($Actual.Count)"
    }
    foreach ($relativePath in $Expected.Keys) {
        if (-not $Actual.Contains($relativePath) -or
                $Actual[$relativePath] -cne $Expected[$relativePath]) {
            throw "$Context changed release output: $relativePath"
        }
    }
}

function Get-ReleaseScratchNames {
    $buildRoot = Join-Path $projectRoot '.build'
    if (-not (Test-Path -LiteralPath $buildRoot -PathType Container)) {
        return @()
    }
    return @(Get-ChildItem -LiteralPath $buildRoot -Directory -Force |
        Where-Object { $_.Name -match '^release-[0-9a-f]{32}$' } |
        ForEach-Object { $_.Name } | Sort-Object)
}

function Assert-NoTransactionResidue {
    $backups = @(Get-ChildItem -LiteralPath $outputRoot -Force `
        -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -like '.release-backup-*' })
    if ($backups.Count) {
        throw "Release transaction left a backup: $($backups[0].FullName)"
    }
}

function ConvertTo-PowerShellLiteral {
    param([string]$Value)
    return "'" + $Value.Replace("'", "''") + "'"
}

try {
    if (Test-Path -LiteralPath $testRoot) {
        Remove-Item -LiteralPath $testRoot -Recurse -Force
    }
    New-Item -ItemType Directory -Path $obsoletePackageDirectory -Force |
        Out-Null
    [IO.File]::WriteAllText(
        (Join-Path $obsoletePackageDirectory 'obsolete.txt'), 'obsolete',
        [Text.UTF8Encoding]::new($false))
    [IO.File]::WriteAllText($obsoleteZipPath, 'obsolete',
        [Text.UTF8Encoding]::new($false))
    $baselineBuild = Invoke-TestReleaseBuild
    foreach ($obsoletePath in @($obsoletePackageDirectory, $obsoleteZipPath)) {
        if (Test-Path -LiteralPath $obsoletePath) {
            throw "Release build retained an obsolete version: $obsoletePath"
        }
    }
    Assert-NoTransactionResidue
    $baselineSnapshot = Get-ReleaseSnapshot $outputRoot

    $normalizedOutputRoot = [IO.Path]::GetFullPath($outputRoot)
    $hashAlgorithm = [Security.Cryptography.SHA256]::Create()
    try {
        $mutexHash = (($hashAlgorithm.ComputeHash(
            [Text.Encoding]::UTF8.GetBytes(
                $normalizedOutputRoot.ToLowerInvariant())) |
            ForEach-Object { $_.ToString('x2') }) -join '').ToUpperInvariant()
    } finally { $hashAlgorithm.Dispose() }
    $releaseMutex = [Threading.Mutex]::new($false,
        ('Global\KeyMouseRemapperAssistant.Release.' + $mutexHash))
    $mutexAcquired = $false
    try {
        try { $mutexAcquired = $releaseMutex.WaitOne(5000) }
        catch [Threading.AbandonedMutexException] {
            $mutexAcquired = $true
        }
        if (-not $mutexAcquired) {
            throw 'Unable to acquire the release mutex for contention testing.'
        }

        $command = "`$ErrorActionPreference = 'Stop'; try { & " +
            (ConvertTo-PowerShellLiteral $buildScript) +
            ' -OutputRoot ' + (ConvertTo-PowerShellLiteral $outputRoot)
        foreach ($optionalPath in @(
                [pscustomobject]@{ Name = '-AutoHotkeyPath';
                    Value = $AutoHotkeyPath },
                [pscustomobject]@{ Name = '-CompilerPath';
                    Value = $CompilerPath },
                [pscustomobject]@{ Name = '-AutoHotkeySourcePath';
                    Value = $AutoHotkeySourcePath })) {
            if ([string]::IsNullOrWhiteSpace($optionalPath.Value)) {
                continue
            }
            $command += ' ' + $optionalPath.Name + ' ' +
                (ConvertTo-PowerShellLiteral $optionalPath.Value)
        }
        $command += '; [Console]::Out.WriteLine(' +
            (ConvertTo-PowerShellLiteral $parallelSuccessMarker) +
            '); exit 0 } catch { ' +
            '[Console]::Error.WriteLine(($_ | Out-String)); exit 1 }'
        $encodedCommand = [Convert]::ToBase64String(
            [Text.Encoding]::Unicode.GetBytes($command))
        $arguments = @('-NoLogo', '-NoProfile', '-NonInteractive',
            '-ExecutionPolicy', 'Bypass', '-EncodedCommand', $encodedCommand)
        $scratchBeforeParallel = @(Get-ReleaseScratchNames)
        $parallelProcess = Start-Process `
            -FilePath (Join-Path $PSHOME 'powershell.exe') `
            -ArgumentList ($arguments -join ' ') -PassThru `
            -WindowStyle Hidden -RedirectStandardOutput $stdoutPath `
            -RedirectStandardError $stderrPath

        $scratchObserved = $false
        $deadline = [DateTime]::UtcNow.AddSeconds(20)
        while ([DateTime]::UtcNow -lt $deadline -and
                -not $parallelProcess.HasExited) {
            $scratchNow = @(Get-ReleaseScratchNames)
            if (@($scratchNow | Where-Object {
                    $_ -notin $scratchBeforeParallel }).Count) {
                $scratchObserved = $true
                break
            }
            Start-Sleep -Milliseconds 100
            $parallelProcess.Refresh()
        }
        if (-not $scratchObserved) {
            throw 'Parallel release build did not reach the lock boundary.'
        }
        Start-Sleep -Milliseconds 750
        $parallelProcess.Refresh()
        if ($parallelProcess.HasExited) {
            throw 'Parallel release build bypassed the held release mutex.'
        }
        Assert-SnapshotsEqual $baselineSnapshot `
            (Get-ReleaseSnapshot $outputRoot) 'Held release mutex'
    } finally {
        if ($mutexAcquired) { $releaseMutex.ReleaseMutex() }
        $releaseMutex.Dispose()
    }

    if (-not $parallelProcess.WaitForExit(120000)) {
        throw 'Parallel release build did not finish after the mutex was released.'
    }
    $parallelProcess.WaitForExit()
    $parallelProcess.Refresh()
    $parallelOutput = if (Test-Path -LiteralPath $stdoutPath) {
        Get-Content -LiteralPath $stdoutPath -Raw -Encoding UTF8
    } else { '' }
    if (-not $parallelOutput.Contains($parallelSuccessMarker)) {
        $parallelError = if (Test-Path -LiteralPath $stderrPath) {
            Get-Content -LiteralPath $stderrPath -Raw -Encoding UTF8
        } else { '' }
        throw "Parallel release build failed with exit code " +
            "$($parallelProcess.ExitCode). stdout: $parallelOutput " +
            "stderr: $parallelError"
    }
    $parallelProcess.Dispose()
    $parallelProcess = $null

    Assert-SnapshotsEqual $baselineSnapshot `
        (Get-ReleaseSnapshot $outputRoot) 'Serialized release build'
    Assert-NoTransactionResidue
    & $artifactTest -OutputRoot $outputRoot
    Write-Host 'PASS release-transaction-tests.ps1'
} finally {
    if ($null -ne $parallelProcess) {
        try {
            if (-not $parallelProcess.HasExited) {
                $parallelProcess.Kill()
                $parallelProcess.WaitForExit()
            }
        } finally { $parallelProcess.Dispose() }
    }
    if (Test-Path -LiteralPath $testRoot) {
        Import-Module (Join-Path $projectRoot `
            'tools\BuildPathSafety.psm1') -Force
        Assert-SafeBuildChild $projectRoot $testRoot `
            'Release transaction test root' | Out-Null
        Remove-Item -LiteralPath $testRoot -Recurse -Force
    }
    $buildRoot = Join-Path $projectRoot '.build'
    if ((Test-Path -LiteralPath $buildRoot -PathType Container) -and
            -not (Get-ChildItem -LiteralPath $buildRoot -Force)) {
        Remove-Item -LiteralPath $buildRoot -Force
    }
}
