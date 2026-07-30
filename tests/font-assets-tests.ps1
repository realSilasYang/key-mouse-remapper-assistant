$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$fontRoot = Join-Path $projectRoot 'assets\fonts'
$metadataPath = Join-Path $fontRoot 'metadata.json'
$metadata = Get-Content -LiteralPath $metadataPath -Raw -Encoding UTF8 |
    ConvertFrom-Json

$expectedFiles = @(
    'NotoSans-Variable.ttf',
    'NotoSansCJK.ttc'
)
if ($metadata.schemaVersion -ne 1 -or @($metadata.fonts).Count -ne 2) {
    throw 'Font metadata schema or entry count is invalid.'
}
$listedFiles = @()
foreach ($font in $metadata.fonts) {
    $relativePath = [string]$font.path
    if ($relativePath -notmatch '^assets/fonts/[A-Za-z0-9._-]+$' -or
        [string]$font.sha256 -notmatch '^[A-F0-9]{64}$' -or
        [string]$font.license -cne 'OFL-1.1') {
        throw "Invalid font metadata entry: $($font.name)"
    }
    $fileName = Split-Path -Leaf $relativePath
    $listedFiles += $fileName
    $fontPath = Join-Path $fontRoot $fileName
    if (-not (Test-Path -LiteralPath $fontPath -PathType Leaf)) {
        throw "Font asset is missing: $fileName"
    }
    $actualHash = (Get-FileHash -Algorithm SHA256 `
        -LiteralPath $fontPath).Hash
    if ($actualHash -cne [string]$font.sha256) {
        throw "Font asset hash mismatch: $fileName"
    }
}
$actualFiles = @(Get-ChildItem -LiteralPath $fontRoot -File |
    Where-Object Extension -in @('.ttf', '.ttc', '.otf') |
    Select-Object -ExpandProperty Name | Sort-Object)
if (($actualFiles -join "`n") -cne (($expectedFiles | Sort-Object) -join "`n") -or
    (($listedFiles | Sort-Object) -join "`n") -cne
        (($expectedFiles | Sort-Object) -join "`n")) {
    throw 'Font files and metadata do not describe the same fixed asset set.'
}
$oflText = Get-Content -LiteralPath (Join-Path $fontRoot 'OFL-1.1.txt') `
    -Raw -Encoding UTF8
if ($oflText -notmatch 'SIL OPEN FONT LICENSE Version 1\.1') {
    throw 'Font license notices are incomplete.'
}
$cjkFont = @($metadata.fonts | Where-Object {
        $_.path -eq 'assets/fonts/NotoSansCJK.ttc'
    })
if ($cjkFont.Count -ne 1 -or $cjkFont[0].faceCount -ne 5 -or
    [string]$cjkFont[0].sourceSha256 -notmatch '^[A-F0-9]{64}$' -or
    @($cjkFont[0].transformation.sourceFaceIndices).Count -ne 5 -or
    $cjkFont[0].transformation.glyphSubsetting -ne $false) {
    throw 'The reduced Noto Sans CJK collection is not fully documented.'
}
foreach ($forbiddenFile in @('PingFang.ttc', 'SF-Pro-Text-Regular.otf',
        'SF-Pro-Text-Bold.otf', 'AppleSDGothicNeo-Regular.ttf',
        'HaranoAjiGothic-Regular.otf', 'COMMERCIAL-LICENSE-NOTICE.md')) {
    if (Test-Path -LiteralPath (Join-Path $fontRoot $forbiddenFile)) {
        throw "Non-public font asset remains: $forbiddenFile"
    }
}
Write-Host 'Font asset checks passed: 2 fixed OFL files and metadata.'
