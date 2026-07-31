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

function Get-ReproducibilityDifference {
    param([string]$FirstDirectory, [string]$SecondDirectory)

    $firstFiles = @{}
    foreach ($file in Get-ChildItem -LiteralPath $FirstDirectory -Recurse -File) {
        $relative = $file.FullName.Substring($FirstDirectory.Length + 1)
        $firstFiles[$relative] = $file.FullName
    }
    $secondFiles = @{}
    foreach ($file in Get-ChildItem -LiteralPath $SecondDirectory -Recurse -File) {
        $relative = $file.FullName.Substring($SecondDirectory.Length + 1)
        $secondFiles[$relative] = $file.FullName
    }
    $details = [Collections.Generic.List[string]]::new()
    $relativePaths = @(@($firstFiles.Keys) + @($secondFiles.Keys) |
        Sort-Object -Unique)
    foreach ($relative in $relativePaths) {
        if (-not $firstFiles.ContainsKey($relative)) {
            $details.Add("Only in second package: $relative")
            continue
        }
        if (-not $secondFiles.ContainsKey($relative)) {
            $details.Add("Only in first package: $relative")
            continue
        }
        $firstFileHash = (Get-FileHash -Algorithm SHA256 `
            -LiteralPath $firstFiles[$relative]).Hash
        $secondFileHash = (Get-FileHash -Algorithm SHA256 `
            -LiteralPath $secondFiles[$relative]).Hash
        if ($firstFileHash -eq $secondFileHash) { continue }
        $details.Add("Different file: $relative $firstFileHash != $secondFileHash")
        if ([IO.Path]::GetExtension($relative) -cne '.exe') { continue }
        $firstBytes = [IO.File]::ReadAllBytes($firstFiles[$relative])
        $secondBytes = [IO.File]::ReadAllBytes($secondFiles[$relative])
        if ($firstBytes.Length -ne $secondBytes.Length) {
            $details.Add("Executable lengths differ: $($firstBytes.Length) != $($secondBytes.Length)")
            continue
        }
        $differenceCount = 0
        $samples = [Collections.Generic.List[string]]::new()
        for ($offset = 0; $offset -lt $firstBytes.Length; $offset++) {
            if ($firstBytes[$offset] -eq $secondBytes[$offset]) { continue }
            $differenceCount++
            if ($samples.Count -lt 32) {
                $samples.Add(('{0:X8}:{1:X2}/{2:X2}' -f $offset,
                    $firstBytes[$offset], $secondBytes[$offset]))
            }
        }
        $details.Add("Executable byte differences: $differenceCount; samples: " +
            ($samples -join ', '))
    }
    if (-not $details.Count) {
        return 'Package files are identical; ZIP container bytes differ.'
    }
    return $details -join "`n"
}

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
        $difference = Get-ReproducibilityDifference `
            $first.PackageDirectory $second.PackageDirectory
        throw "Release ZIP is not reproducible: $firstHash != $secondHash`n$difference"
    }
    $firstSourceHash = (Get-FileHash -Algorithm SHA256 `
        -LiteralPath $first.SourceZipPath).Hash
    $secondSourceHash = (Get-FileHash -Algorithm SHA256 `
        -LiteralPath $second.SourceZipPath).Hash
    if ($firstSourceHash -ne $secondSourceHash) {
        $difference = Get-ReproducibilityDifference `
            $first.SourcePackageDirectory $second.SourcePackageDirectory
        throw "Source ZIP is not reproducible: $firstSourceHash != " +
            "$secondSourceHash`n$difference"
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
    $alternateSourceHash = (Get-FileHash -Algorithm SHA256 `
        -LiteralPath $alternate.SourceZipPath).Hash
    if ($firstSourceHash -ne $alternateSourceHash) {
        throw "Source ZIP depends on build drive: $firstSourceHash != " +
            $alternateSourceHash
    }
    $alternateManifest = Get-Content -LiteralPath (Join-Path `
        $alternate.PackageDirectory 'build-manifest.json') -Raw `
        -Encoding UTF8 | ConvertFrom-Json
    if ($alternateManifest.inputBackend -cne 'raw-input' -or
            $alternateManifest.requiresDriver -ne $false -or
            $null -ne $alternateManifest.nativeDriver) {
        throw 'Alternate-drive build changed input metadata.'
    }
    Write-Host "Reproducible builds passed: $firstHash / $firstSourceHash"
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
