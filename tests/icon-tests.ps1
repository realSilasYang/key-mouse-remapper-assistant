$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$iconPath = Join-Path $projectRoot 'assets\app\key-mouse-remapper-assistant.ico'
$pngPath = Join-Path $projectRoot 'assets\app\key-mouse-remapper-assistant.png'

$icon = [System.IO.File]::ReadAllBytes($iconPath)
if ([BitConverter]::ToUInt16($icon, 0) -ne 0 -or
    [BitConverter]::ToUInt16($icon, 2) -ne 1) {
    throw 'ICO header is invalid.'
}
$frameCount = [BitConverter]::ToUInt16($icon, 4)
$sizes = for ($index = 0; $index -lt $frameCount; $index++) {
    $offset = 6 + (16 * $index)
    $width = if ($icon[$offset] -eq 0) { 256 } else { [int]$icon[$offset] }
    $height = if ($icon[$offset + 1] -eq 0) { 256 } else { [int]$icon[$offset + 1] }
    "$width`x$height"
}
$expected = @('256x256', '128x128', '64x64', '48x48', '40x40',
    '32x32', '24x24', '20x20', '16x16')
$missing = @($expected | Where-Object { $_ -notin $sizes })
if ($missing.Count) {
    throw "ICO is missing frames: $($missing -join ', ')"
}

$png = [System.IO.File]::ReadAllBytes($pngPath)
$signature = '89504E470D0A1A0A'
if ([BitConverter]::ToString($png[0..7]).Replace('-', '') -ne $signature) {
    throw 'Icon source is not a PNG.'
}
$width = ([int]$png[16] -shl 24) -bor ([int]$png[17] -shl 16) -bor
    ([int]$png[18] -shl 8) -bor [int]$png[19]
$height = ([int]$png[20] -shl 24) -bor ([int]$png[21] -shl 16) -bor
    ([int]$png[22] -shl 8) -bor [int]$png[23]
if ($width -ne $height -or $width -lt 1024 -or $png[25] -ne 6) {
    throw "Icon PNG must be a square RGBA image of at least 1024 px; got ${width}x${height}."
}
Add-Type -AssemblyName System.Drawing
$pngBitmap = [System.Drawing.Bitmap]::new($pngPath)
try {
    $transparentCorners = @(
        $pngBitmap.GetPixel(0, 0).A,
        $pngBitmap.GetPixel($pngBitmap.Width - 1, 0).A,
        $pngBitmap.GetPixel(0, $pngBitmap.Height - 1).A,
        $pngBitmap.GetPixel($pngBitmap.Width - 1,
            $pngBitmap.Height - 1).A
    )
    if (@($transparentCorners | Where-Object { $_ -ne 0 }).Count) {
        throw 'Icon PNG corners must remain fully transparent.'
    }
} finally { $pngBitmap.Dispose() }

for ($index = 0; $index -lt $frameCount; $index++) {
    $entryOffset = 6 + (16 * $index)
    $frameWidth = if ($icon[$entryOffset] -eq 0) {
        256
    } else { [int]$icon[$entryOffset] }
    $frameHeight = if ($icon[$entryOffset + 1] -eq 0) {
        256
    } else { [int]$icon[$entryOffset + 1] }
    $frameOffset = [BitConverter]::ToUInt32($icon, $entryOffset + 12)
    $headerSize = [BitConverter]::ToUInt32($icon, $frameOffset)
    $bitCount = [BitConverter]::ToUInt16($icon, $frameOffset + 14)
    $compression = [BitConverter]::ToUInt32($icon, $frameOffset + 16)
    if ($headerSize -ne 40 -or $bitCount -ne 32 -or $compression -ne 0) {
        throw "ICO frame ${frameWidth}x${frameHeight} is not an uncompressed 32-bit DIB."
    }
    $pixelOffset = $frameOffset + $headerSize
    $stride = $frameWidth * 4
    $lastRow = $frameHeight - 1
    $lastColumn = $frameWidth - 1
    $frameCorners = @(
        $icon[$pixelOffset + 3],
        $icon[$pixelOffset + ($lastColumn * 4) + 3],
        $icon[$pixelOffset + ($lastRow * $stride) + 3],
        $icon[$pixelOffset + ($lastRow * $stride) +
            ($lastColumn * 4) + 3]
    )
    if (@($frameCorners | Where-Object { $_ -gt 32 }).Count) {
        throw "ICO frame ${frameWidth}x${frameHeight} has a non-transparent background corner."
    }
    $centerX = [Math]::Floor($frameWidth / 2)
    $centerRow = $frameHeight - 1 - [Math]::Floor($frameHeight / 2)
    if ($icon[$pixelOffset + ($centerRow * $stride) +
            ($centerX * 4) + 3] -eq 0) {
        throw "ICO frame ${frameWidth}x${frameHeight} has no opaque center mark."
    }
}
Write-Host "Icon checks passed: $($sizes -join ', ')."
