# Restore the LFS-tracked fonts from the latest verified source release when
# GitHub LFS is unavailable. Only metadata-declared files with matching hashes
# are allowed to replace the checkout's pointer files.

[CmdletBinding()]
param(
    [string]$Repository = "",
    [string]$ReleaseTag = "",
    [string]$DestinationRoot = "",
    [string]$MetadataPath = "",
    [string]$ArchivePath = "",
    [string]$CacheDirectory = ""
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
Add-Type -AssemblyName System.IO.Compression.FileSystem

$projectRoot = Split-Path -Parent $PSScriptRoot
if (-not $DestinationRoot) { $DestinationRoot = $projectRoot }
if (-not $MetadataPath) {
    $MetadataPath = Join-Path $projectRoot 'assets\fonts\metadata.json'
}
if (-not $CacheDirectory) {
    $CacheDirectory = Join-Path $projectRoot '.tools\font-assets'
}
if (-not $Repository) {
    $Repository = if ($env:GITHUB_REPOSITORY) {
        $env:GITHUB_REPOSITORY
    } else {
        'realSilasYang/key-mouse-remapper-assistant'
    }
}

$destinationRootPath = [IO.Path]::GetFullPath($DestinationRoot)
$metadataFullPath = [IO.Path]::GetFullPath($MetadataPath)
if (-not (Test-Path -LiteralPath $destinationRootPath -PathType Container)) {
    throw "Font destination root does not exist: $destinationRootPath"
}
if (-not (Test-Path -LiteralPath $metadataFullPath -PathType Leaf)) {
    throw "Font metadata does not exist: $metadataFullPath"
}
$metadata = Get-Content -LiteralPath $metadataFullPath -Raw -Encoding UTF8 |
    ConvertFrom-Json
if ($metadata.schemaVersion -ne 1 -or -not $metadata.fonts -or
        $metadata.fonts.Count -eq 0) {
    throw 'Font metadata schema is invalid or contains no fonts.'
}

$destinationPrefix = $destinationRootPath.TrimEnd('\') + '\'
$fontRecords = @()
foreach ($font in $metadata.fonts) {
    $relativePath = ([string]$font.path).Replace('\', '/')
    $expectedHash = ([string]$font.sha256).ToUpperInvariant()
    if ($relativePath -notmatch '^assets/fonts/[^/]+\.(?:ttc|ttf|otf)$' -or
            $expectedHash -notmatch '^[0-9A-F]{64}$') {
        throw "Font metadata entry is invalid: $relativePath"
    }
    $destinationPath = [IO.Path]::GetFullPath((Join-Path `
        $destinationRootPath ($relativePath.Replace('/', '\'))))
    if (-not $destinationPath.StartsWith($destinationPrefix,
            [StringComparison]::OrdinalIgnoreCase)) {
        throw "Font destination escaped the repository root: $relativePath"
    }
    $fontRecords += [pscustomobject]@{
        RelativePath = $relativePath
        ExpectedHash = $expectedHash
        DestinationPath = $destinationPath
    }
}

function Test-FontFiles {
    foreach ($record in $fontRecords) {
        if (-not (Test-Path -LiteralPath $record.DestinationPath `
                -PathType Leaf)) {
            return $false
        }
        if ((Get-FileHash -LiteralPath $record.DestinationPath `
                -Algorithm SHA256).Hash -cne $record.ExpectedHash) {
            return $false
        }
    }
    return $true
}

if (Test-FontFiles) {
    Write-Host 'Font assets already match metadata.'
    return
}

$cachePath = [IO.Path]::GetFullPath($CacheDirectory)
New-Item -ItemType Directory -Force -Path $cachePath | Out-Null
$resolvedArchivePath = if ($ArchivePath) {
    [IO.Path]::GetFullPath($ArchivePath)
} else {
    Join-Path $cachePath 'release-source.zip'
}

function Get-ArchiveEntryHash {
    param(
        [IO.Compression.ZipArchive]$Archive,
        [string]$RelativePath
    )

    $entry = $Archive.GetEntry($RelativePath)
    if ($null -eq $entry) { return "" }
    $stream = $entry.Open()
    $sha = [Security.Cryptography.SHA256]::Create()
    try {
        return ([BitConverter]::ToString($sha.ComputeHash($stream))).Replace(
            '-', '')
    } finally {
        $sha.Dispose()
        $stream.Dispose()
    }
}

function Test-FontArchive {
    param([string]$Path)

    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        return $false
    }
    try {
        $archive = [IO.Compression.ZipFile]::OpenRead($Path)
        try {
            foreach ($record in $fontRecords) {
                if ((Get-ArchiveEntryHash $archive $record.RelativePath) -cne
                        $record.ExpectedHash) {
                    return $false
                }
            }
            return $true
        } finally {
            $archive.Dispose()
        }
    } catch {
        return $false
    }
}

function Download-FontArchive {
    if ($ArchivePath) {
        throw "Provided source archive does not match metadata: $resolvedArchivePath"
    }
    $gh = Get-Command gh -ErrorAction SilentlyContinue
    if (-not $gh) {
        throw 'GitHub CLI is required to restore fonts from a Release.'
    }
    $downloadDirectory = Join-Path $cachePath `
        ('.download-' + [Guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $downloadDirectory | Out-Null
    try {
        $arguments = @('release', 'download')
        if ($ReleaseTag) { $arguments += $ReleaseTag }
        $arguments += @('--repo', $Repository, '--pattern',
            'key-mouse-remapper-assistant-*-source.zip', '--dir',
            $downloadDirectory)
        & $gh.Source @arguments
        $downloads = @(Get-ChildItem -LiteralPath $downloadDirectory `
            -Filter '*.zip' -File)
        if ($LASTEXITCODE -ne 0 -or $downloads.Count -ne 1) {
            throw "Unable to download one source ZIP from $Repository."
        }
        if (Test-Path -LiteralPath $resolvedArchivePath) {
            Remove-Item -LiteralPath $resolvedArchivePath -Force
        }
        Move-Item -LiteralPath $downloads[0].FullName `
            -Destination $resolvedArchivePath
    } finally {
        if (Test-Path -LiteralPath $downloadDirectory) {
            Remove-Item -LiteralPath $downloadDirectory -Recurse -Force
        }
    }
}

if (-not (Test-FontArchive $resolvedArchivePath)) {
    Download-FontArchive
    if (-not (Test-FontArchive $resolvedArchivePath)) {
        throw 'Downloaded source archive does not contain the expected fonts.'
    }
}

$scratchRoot = Join-Path $cachePath `
    ('.restore-' + [Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $scratchRoot | Out-Null
try {
    $archive = [IO.Compression.ZipFile]::OpenRead($resolvedArchivePath)
    try {
        foreach ($record in $fontRecords) {
            $entry = $archive.GetEntry($record.RelativePath)
            if ($null -eq $entry) {
                throw "Source archive omitted $($record.RelativePath)."
            }
            $stagedPath = Join-Path $scratchRoot `
                ([IO.Path]::GetFileName($record.RelativePath))
            $input = $entry.Open()
            $output = [IO.File]::Create($stagedPath)
            try { $input.CopyTo($output) }
            finally {
                $output.Dispose()
                $input.Dispose()
            }
            if ((Get-FileHash -LiteralPath $stagedPath -Algorithm SHA256).Hash `
                    -cne $record.ExpectedHash) {
                throw "Restored font hash mismatch: $($record.RelativePath)"
            }
            $destinationDirectory = Split-Path -Parent $record.DestinationPath
            New-Item -ItemType Directory -Force -Path $destinationDirectory |
                Out-Null
            Move-Item -LiteralPath $stagedPath `
                -Destination $record.DestinationPath -Force
        }
    } finally {
        $archive.Dispose()
    }
} finally {
    if (Test-Path -LiteralPath $scratchRoot) {
        Remove-Item -LiteralPath $scratchRoot -Recurse -Force
    }
}

if (-not (Test-FontFiles)) {
    throw 'Restored font assets failed final metadata verification.'
}
Write-Host "Restored and verified $($fontRecords.Count) font assets."
