[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$projectRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$testRoot = Join-Path $projectRoot `
    ('.build\font-restore-tests-' + [Guid]::NewGuid().ToString('N'))
$projectPrefix = [IO.Path]::GetFullPath($projectRoot).TrimEnd('\') + '\'
$testFullPath = [IO.Path]::GetFullPath($testRoot)
if (-not $testFullPath.StartsWith($projectPrefix,
        [StringComparison]::OrdinalIgnoreCase)) {
    throw "Font restore test path escaped the project root: $testFullPath"
}

function Write-TestBytes {
    param([string]$Path, [byte[]]$Bytes)

    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $Path) |
        Out-Null
    [IO.File]::WriteAllBytes($Path, $Bytes)
}

try {
    $sourceRoot = Join-Path $testFullPath 'source'
    $destinationRoot = Join-Path $testFullPath 'destination'
    $metadataPath = Join-Path $testFullPath 'metadata.json'
    $archivePath = Join-Path $testFullPath 'fonts.zip'
    New-Item -ItemType Directory -Force -Path $sourceRoot,
        $destinationRoot | Out-Null

    $firstBytes = [Text.Encoding]::UTF8.GetBytes('font-one')
    $secondBytes = [Text.Encoding]::UTF8.GetBytes('font-two')
    $firstRelative = 'assets/fonts/Test-Regular.ttf'
    $secondRelative = 'assets/fonts/Test-Collection.ttc'
    Write-TestBytes (Join-Path $sourceRoot `
        ($firstRelative -replace '/', '\')) $firstBytes
    Write-TestBytes (Join-Path $sourceRoot `
        ($secondRelative -replace '/', '\')) $secondBytes
    Write-TestBytes (Join-Path $destinationRoot `
        ($firstRelative -replace '/', '\')) `
        ([Text.Encoding]::ASCII.GetBytes('version https://git-lfs'))
    Write-TestBytes (Join-Path $destinationRoot `
        ($secondRelative -replace '/', '\')) `
        ([Text.Encoding]::ASCII.GetBytes('version https://git-lfs'))

    $metadata = [ordered]@{
        schemaVersion = 1
        fonts = @(
            [ordered]@{
                path = $firstRelative
                sha256 = (Get-FileHash -LiteralPath (Join-Path $sourceRoot `
                    ($firstRelative -replace '/', '\')) `
                    -Algorithm SHA256).Hash
            },
            [ordered]@{
                path = $secondRelative
                sha256 = (Get-FileHash -LiteralPath (Join-Path $sourceRoot `
                    ($secondRelative -replace '/', '\')) `
                    -Algorithm SHA256).Hash
            }
        )
    }
    [IO.File]::WriteAllText($metadataPath,
        ($metadata | ConvertTo-Json -Depth 5),
        [Text.UTF8Encoding]::new($false))
    Compress-Archive -Path (Join-Path $sourceRoot '*') `
        -DestinationPath $archivePath

    & (Join-Path $projectRoot 'tools\restore-font-assets.ps1') `
        -DestinationRoot $destinationRoot -MetadataPath $metadataPath `
        -ArchivePath $archivePath
    foreach ($font in $metadata.fonts) {
        $restoredPath = Join-Path $destinationRoot `
            ($font.path -replace '/', '\')
        if ((Get-FileHash -LiteralPath $restoredPath -Algorithm SHA256).Hash `
                -ne $font.sha256) {
            throw "Restored test font hash mismatch: $($font.path)"
        }
    }

    $metadata.fonts[0].sha256 = '0' * 64
    [IO.File]::WriteAllText($metadataPath,
        ($metadata | ConvertTo-Json -Depth 5),
        [Text.UTF8Encoding]::new($false))
    $rejected = $false
    try {
        & (Join-Path $projectRoot 'tools\restore-font-assets.ps1') `
            -DestinationRoot $destinationRoot -MetadataPath $metadataPath `
            -ArchivePath $archivePath
    } catch {
        $rejected = $true
    }
    if (-not $rejected) {
        throw 'A font archive that disagrees with metadata was accepted.'
    }
} finally {
    if (Test-Path -LiteralPath $testFullPath) {
        Remove-Item -LiteralPath $testFullPath -Recurse -Force
    }
}

Write-Host 'PASS font-asset-restore-tests.ps1'
