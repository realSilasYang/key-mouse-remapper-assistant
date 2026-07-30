[CmdletBinding()]
param(
    [string]$AutoHotkeyPath = "",
    [string]$CompilerPath = "",
    [string]$AutoHotkeySourcePath = ""
)

$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$firstRoot = Join-Path $projectRoot '.build\repro-first'
$secondRoot = Join-Path $projectRoot '.build\repro-second'
$alternateRoot = Join-Path $projectRoot '.build\repro-alternate-drive'
$occupiedTarget = Join-Path $projectRoot '.build\repro-occupied-drive'
$occupiedDrive = $null
try {
    $first = & (Join-Path $projectRoot 'tools\build-release.ps1') `
        -AutoHotkeyPath $AutoHotkeyPath -CompilerPath $CompilerPath `
        -AutoHotkeySourcePath $AutoHotkeySourcePath `
        -OutputRoot $firstRoot
    $second = & (Join-Path $projectRoot 'tools\build-release.ps1') `
        -AutoHotkeyPath $AutoHotkeyPath -CompilerPath $CompilerPath `
        -AutoHotkeySourcePath $AutoHotkeySourcePath `
        -OutputRoot $secondRoot
    $firstHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $first.ZipPath).Hash
    $secondHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $second.ZipPath).Hash
    if ($firstHash -ne $secondHash) {
        throw "Release ZIP is not reproducible: $firstHash != $secondHash"
    }
    foreach ($build in @($first, $second)) {
        $buildManifest = Get-Content -LiteralPath (Join-Path `
            $build.PackageDirectory 'build-manifest.json') -Raw `
            -Encoding UTF8 | ConvertFrom-Json
        if ($buildManifest.inputBackend -cne 'raw-input' -or
                $buildManifest.requiresDriver -ne $false -or
                $buildManifest.suppressesOriginalInput -ne $false -or
                $null -ne $buildManifest.nativeDriver) {
            throw 'Portable reproducibility build has invalid input metadata.'
        }
    }

    New-Item -ItemType Directory -Force -Path $occupiedTarget | Out-Null
    $occupiedNames = @(Get-PSDrive -PSProvider FileSystem |
        ForEach-Object { $_.Name.ToUpperInvariant() })
    foreach ($letterCode in 90..80) {
        $letter = [char]$letterCode
        if ($letter -in $occupiedNames) { continue }
        $process = Start-Process -FilePath 'subst.exe' `
            -ArgumentList "$letter`:", $occupiedTarget -PassThru -Wait `
            -WindowStyle Hidden
        if ($process.ExitCode -eq 0) {
            $occupiedDrive = "$letter`:"
            break
        }
    }
    if (-not $occupiedDrive) {
        throw 'Unable to reserve an alternate build drive for reproducibility testing.'
    }
    $alternate = & (Join-Path $projectRoot 'tools\build-release.ps1') `
        -AutoHotkeyPath $AutoHotkeyPath -CompilerPath $CompilerPath `
        -AutoHotkeySourcePath $AutoHotkeySourcePath `
        -OutputRoot $alternateRoot
    $alternateHash = (Get-FileHash -Algorithm SHA256 `
        -LiteralPath $alternate.ZipPath).Hash
    if ($firstHash -ne $alternateHash) {
        throw "Release ZIP depends on build drive: $firstHash != $alternateHash"
    }
    $alternateManifest = Get-Content -LiteralPath (Join-Path `
        $alternate.PackageDirectory 'build-manifest.json') -Raw `
        -Encoding UTF8 | ConvertFrom-Json
    if ($alternateManifest.inputBackend -cne 'raw-input' -or
            $alternateManifest.requiresDriver -ne $false -or
            $null -ne $alternateManifest.nativeDriver) {
        throw 'Alternate-drive build changed input metadata.'
    }
    Write-Host "Reproducible build passed: $firstHash"
} finally {
    if ($occupiedDrive) {
        $process = Start-Process -FilePath 'subst.exe' `
            -ArgumentList $occupiedDrive, '/D' -PassThru -Wait `
            -WindowStyle Hidden
        if ($process.ExitCode -ne 0) {
            Write-Warning "Unable to release test drive $occupiedDrive."
        }
    }
    foreach ($path in @($firstRoot, $secondRoot, $alternateRoot,
            $occupiedTarget)) {
        $full = [System.IO.Path]::GetFullPath($path)
        $prefix = [System.IO.Path]::GetFullPath(
            (Join-Path $projectRoot '.build')).TrimEnd('\') + '\'
        if (($full + '\').StartsWith($prefix,
                [System.StringComparison]::OrdinalIgnoreCase) -and
            (Test-Path -LiteralPath $full)) {
            Remove-Item -LiteralPath $full -Recurse -Force
        }
    }
    $buildRoot = Join-Path $projectRoot '.build'
    if ((Test-Path -LiteralPath $buildRoot -PathType Container) -and
        -not (Get-ChildItem -LiteralPath $buildRoot -Force)) {
        Remove-Item -LiteralPath $buildRoot -Force
    }
}
