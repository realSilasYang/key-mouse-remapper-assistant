[CmdletBinding()]
param(
    [string]$ImageMagickPath = ""
)

$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
Import-Module (Join-Path $PSScriptRoot 'BuildPathSafety.psm1') -Force
$assetDirectory = Assert-SafeBuildRoot (Join-Path $projectRoot 'assets\app') `
    'Application icon directory'
$svgPath = Assert-SafeBuildChild $assetDirectory `
    (Join-Path $assetDirectory 'key-mouse-remapper-assistant.svg') 'Icon SVG source'
$pngPath = Assert-SafeBuildChild $assetDirectory `
    (Join-Path $assetDirectory 'key-mouse-remapper-assistant.png') 'Icon PNG output'
$iconPath = Assert-SafeBuildChild $assetDirectory `
    (Join-Path $assetDirectory 'key-mouse-remapper-assistant.ico') 'Icon ICO output'

$magick = @(
    $ImageMagickPath,
    (Get-Command magick.exe -ErrorAction SilentlyContinue |
        Select-Object -ExpandProperty Source)
) | Where-Object { $_ -and (Test-Path -LiteralPath $_ -PathType Leaf) } |
    Select-Object -First 1
if (-not $magick) {
    throw 'ImageMagick 7 was not found. Pass -ImageMagickPath explicitly.'
}
$magick = [IO.Path]::GetFullPath([string]$magick)

$hashAlgorithm = [Security.Cryptography.SHA256]::Create()
try {
    $mutexHash = (($hashAlgorithm.ComputeHash(
        [Text.Encoding]::UTF8.GetBytes($assetDirectory.ToLowerInvariant())) |
        ForEach-Object { $_.ToString('x2') }) -join '').ToUpperInvariant()
} finally { $hashAlgorithm.Dispose() }
$mutex = [Threading.Mutex]::new($false,
    ('Global\KeyMouseRemapperAssistant.Icon.' + $mutexHash))
$mutexAcquired = $false
$temporaryPaths = [Collections.Generic.List[string]]::new()
$backupPaths = [Collections.Generic.List[string]]::new()
$operationError = $null
$cleanupErrors = [Collections.Generic.List[string]]::new()
try {
    try { $mutexAcquired = $mutex.WaitOne(30000) }
    catch [Threading.AbandonedMutexException] { $mutexAcquired = $true }
    if (-not $mutexAcquired) {
        throw 'Timed out waiting for another application icon build.'
    }

    $token = [guid]::NewGuid().ToString('N')
    $renderedPng = Assert-SafeBuildChild $assetDirectory `
        (Join-Path $assetDirectory ('.icon-render-' + $token + '.png')) `
        'Temporary rendered icon'
    $normalizedPng = Assert-SafeBuildChild $assetDirectory `
        (Join-Path $assetDirectory ('.icon-normalized-' + $token + '.png')) `
        'Temporary normalized icon'
    $generatedIcon = Assert-SafeBuildChild $assetDirectory `
        (Join-Path $assetDirectory ('.icon-output-' + $token + '.ico')) `
        'Temporary ICO output'
    $temporaryPaths.Add($renderedPng)
    $temporaryPaths.Add($normalizedPng)
    $temporaryPaths.Add($generatedIcon)

    $replacePng = Test-Path -LiteralPath $svgPath -PathType Leaf
    if ($replacePng) {
        & $magick -background none $svgPath -resize '2312x2312!' -strip `
            -define 'png:exclude-chunks=date,time' "PNG32:$renderedPng"
        if ($LASTEXITCODE -ne 0 -or
                -not (Test-Path -LiteralPath $renderedPng -PathType Leaf)) {
            throw 'Unable to render the icon PNG.'
        }
        $sourcePng = $renderedPng
    } elseif (Test-Path -LiteralPath $pngPath -PathType Leaf) {
        $sourcePng = $pngPath
    } else {
        throw 'Neither the SVG source nor the icon PNG was found.'
    }

    & $magick $sourcePng -background none -alpha on -resize '1024x1024!' `
        -strip -define 'png:exclude-chunks=date,time' "PNG32:$normalizedPng"
    if ($LASTEXITCODE -ne 0 -or
            -not (Test-Path -LiteralPath $normalizedPng -PathType Leaf)) {
        throw 'Unable to normalize the icon PNG.'
    }
    & $magick $normalizedPng -define `
        'icon:auto-resize=256,128,64,48,40,32,24,20,16' $generatedIcon
    if ($LASTEXITCODE -ne 0 -or
            -not (Test-Path -LiteralPath $generatedIcon -PathType Leaf)) {
        throw 'Unable to build the multi-resolution ICO.'
    }

    $frameText = & $magick identify -format '%wx%h|' $generatedIcon
    if ($LASTEXITCODE -ne 0) { throw 'Unable to inspect the generated ICO.' }
    $frames = @($frameText -split '\|' | Where-Object { $_ })
    $expectedFrames = @('256x256', '128x128', '64x64', '48x48',
        '40x40', '32x32', '24x24', '20x20', '16x16')
    $missingFrames = @($expectedFrames | Where-Object { $_ -notin $frames })
    if ($missingFrames.Count) {
        throw "ICO is missing frames: $($missingFrames -join ', ')"
    }

    $commits = [Collections.Generic.List[object]]::new()
    if ($replacePng) {
        $commits.Add([pscustomobject]@{
            Temporary = $renderedPng
            Target = $pngPath
            Backup = $pngPath + '.icon-backup-' + $token
            BackedUp = $false
            Installed = $false
        })
    }
    $commits.Add([pscustomobject]@{
        Temporary = $generatedIcon
        Target = $iconPath
        Backup = $iconPath + '.icon-backup-' + $token
        BackedUp = $false
        Installed = $false
    })
    try {
        foreach ($commit in $commits) {
            if (Test-Path -LiteralPath $commit.Target) {
                Move-Item -LiteralPath $commit.Target -Destination $commit.Backup
                $commit.BackedUp = $true
                $backupPaths.Add($commit.Backup)
            }
            Move-Item -LiteralPath $commit.Temporary -Destination $commit.Target
            $commit.Installed = $true
        }
    } catch {
        $commitError = $_.Exception
        for ($index = $commits.Count - 1; $index -ge 0; $index--) {
            $commit = $commits[$index]
            try {
                if ($commit.Installed -and
                        (Test-Path -LiteralPath $commit.Target)) {
                    Remove-Item -LiteralPath $commit.Target -Force
                }
                if ($commit.BackedUp -and
                        (Test-Path -LiteralPath $commit.Backup)) {
                    Move-Item -LiteralPath $commit.Backup `
                        -Destination $commit.Target
                }
            } catch { $cleanupErrors.Add($_.Exception.Message) }
        }
        if ($cleanupErrors.Count) {
            throw ($commitError.Message + ' Rollback was incomplete: ' +
                ($cleanupErrors -join '; '))
        }
        throw $commitError
    }

    foreach ($backupPath in $backupPaths) {
        if (Test-Path -LiteralPath $backupPath) {
            Remove-Item -LiteralPath $backupPath -Force
        }
    }
} catch {
    $operationError = $_.Exception
} finally {
    foreach ($temporaryPath in $temporaryPaths) {
        if (Test-Path -LiteralPath $temporaryPath) {
            try { Remove-Item -LiteralPath $temporaryPath -Force }
            catch { $cleanupErrors.Add($_.Exception.Message) }
        }
    }
    if ($mutexAcquired) {
        try { $mutex.ReleaseMutex() }
        catch { $cleanupErrors.Add($_.Exception.Message) }
    }
    try { $mutex.Dispose() }
    catch { $cleanupErrors.Add($_.Exception.Message) }
}

if ($null -ne $operationError) {
    if ($cleanupErrors.Count) {
        throw ($operationError.Message + ' Cleanup was incomplete: ' +
            ($cleanupErrors -join '; '))
    }
    throw $operationError
}
if ($cleanupErrors.Count) {
    throw ('Icon build completed but cleanup was incomplete: ' +
        ($cleanupErrors -join '; '))
}

Write-Host "Icon PNG: $pngPath"
Write-Host "Windows icon: $iconPath"
