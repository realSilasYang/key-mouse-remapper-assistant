[CmdletBinding()]
param([Parameter(Mandatory = $true)][string]$OutputRoot)

$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$version = (Get-Content -LiteralPath (Join-Path $projectRoot 'VERSION') `
    -Raw -Encoding UTF8).Trim()
$outputRoot = [System.IO.Path]::GetFullPath($OutputRoot)
$packageName = "key-mouse-remapper-assistant-$version-windows-x64"
$productName = -join @([char]0x952E, [char]0x9F20, [char]0x91CD,
    [char]0x6620, [char]0x5C04, [char]0x5C0F, [char]0x52A9,
    [char]0x624B)
$guiExecutable = "$productName.exe"
$editableSource = "$productName.ahk"
$cliLauncher = "$productName-CLI.ps1"
$packageDirectory = Join-Path $outputRoot $packageName
$zipPath = Join-Path $outputRoot "$packageName.zip"
$checksumsPath = Join-Path $outputRoot 'SHA256SUMS.txt'

foreach ($requiredPath in @($packageDirectory, $zipPath, $checksumsPath)) {
    if (-not (Test-Path -LiteralPath $requiredPath)) {
        throw "Release artifact is missing: $requiredPath"
    }
}

$legacyArtifactNames = @(
    "key-mouse-remapper-$version-windows-x64",
    "key-mouse-remapper-$version-windows-x64.zip",
    "key-remapper-$version-windows-x64",
    "key-remapper-$version-windows-x64.zip",
    'final'
)
foreach ($legacyArtifactName in $legacyArtifactNames) {
    $legacyArtifactPath = Join-Path $outputRoot $legacyArtifactName
    if (Test-Path -LiteralPath $legacyArtifactPath) {
        throw "Release output contains an obsolete product artifact: $legacyArtifactPath"
    }
}
$versionedArtifactPattern =
    '^key-mouse-remapper-assistant-[0-9]+\.[0-9]+\.[0-9]+-windows-x64(?:\.zip)?$'
$currentArtifactNames = @($packageName, "$packageName.zip")
$obsoleteVersionArtifacts = @(Get-ChildItem -LiteralPath $outputRoot -Force |
    Where-Object {
        $_.Name -match $versionedArtifactPattern -and
        $_.Name -notin $currentArtifactNames
    })
if ($obsoleteVersionArtifacts.Count) {
    throw "Release output contains another product version: " +
        $obsoleteVersionArtifacts[0].FullName
}

$requiredFiles = @(
    $guiExecutable, $editableSource, $cliLauncher,
    'key-mouse-remapper-assistant-cli.ahk', 'build-manifest.json', 'runtime\AutoHotkey64.exe',
    'runtime\license.txt', 'tools\toolchain.lock.json',
    'README.md', 'LICENSE', 'THIRD_PARTY_NOTICES.md',
    'docs\validation-matrix.md',
    'third_party\resvg\resvg.dll',
    'assets\app\key-mouse-remapper-assistant.ico',
    'assets\app\key-mouse-remapper-assistant.png',
    'assets\app\key-mouse-remapper-assistant.svg',
    'assets\fonts\NotoSans-Variable.ttf',
    'assets\fonts\NotoSansCJK.ttc', 'assets\fonts\OFL-1.1.txt',
    'assets\fonts\metadata.json',
    'assets\ui-icons\lucide\circle-question-mark.svg',
    'assets\ui-icons\lucide\heart.svg',
    'assets\ui-icons\lucide\book-open.svg',
    'assets\ui-icons\lucide\message-square-text.svg',
    'assets\donate\微信个人收款码.png',
    'assets\donate\微信个人收款码-界面.png',
    'assets\donate\支付宝个人收款码.png',
    'assets\donate\支付宝个人收款码-界面.png'
)
foreach ($relativePath in $requiredFiles) {
    if (-not (Test-Path -LiteralPath (Join-Path $packageDirectory $relativePath) `
            -PathType Leaf)) {
        throw "Release package is missing $relativePath."
    }
}
$applicationIconPaths = @(
    'assets\app\key-mouse-remapper-assistant.ico',
    'assets\app\key-mouse-remapper-assistant.png',
    'assets\app\key-mouse-remapper-assistant.svg'
)
foreach ($relativePath in $applicationIconPaths) {
    $sourcePath = Join-Path $projectRoot $relativePath
    $packagedPath = Join-Path $packageDirectory $relativePath
    if ((Get-FileHash -Algorithm SHA256 -LiteralPath $sourcePath).Hash -cne
            (Get-FileHash -Algorithm SHA256 -LiteralPath $packagedPath).Hash) {
        throw "Packaged application icon differs from source: $relativePath"
    }
}
$fontMetadata = Get-Content -LiteralPath (Join-Path $packageDirectory `
    'assets\fonts\metadata.json') -Raw -Encoding UTF8 | ConvertFrom-Json
foreach ($font in $fontMetadata.fonts) {
    $fontPath = Join-Path $packageDirectory `
        ([string]$font.path).Replace('/', '\')
    if (-not (Test-Path -LiteralPath $fontPath -PathType Leaf) -or
        (Get-FileHash -Algorithm SHA256 -LiteralPath $fontPath).Hash `
            -cne [string]$font.sha256) {
        throw "Packaged font hash mismatch: $($font.path)"
    }
}

$manifest = Get-Content -LiteralPath (Join-Path $packageDirectory `
    'build-manifest.json') -Raw -Encoding UTF8 | ConvertFrom-Json
if ($manifest.schemaVersion -ne 1 -or $manifest.version -ne $version -or
    $manifest.entry -ne $guiExecutable -or
    $manifest.editableSource -ne $editableSource -or
    $manifest.cli -ne $cliLauncher -or
    $manifest.inputBackend -ne 'raw-input' -or
    $manifest.requiresDriver -ne $false -or
    $manifest.suppressesOriginalInput -ne $false -or
    $null -ne $manifest.nativeDriver -or
    [string]$manifest.autoHotkeySha256 -notmatch '^[A-Fa-f0-9]{64}$') {
    throw 'build-manifest.json has invalid release metadata.'
}
$runtimeHash = (Get-FileHash -Algorithm SHA256 -LiteralPath `
    (Join-Path $packageDirectory 'runtime\AutoHotkey64.exe')).Hash
if ($runtimeHash -cne ([string]$manifest.autoHotkeySha256).ToUpperInvariant()) {
    throw 'Packaged runtime does not match build-manifest.json.'
}
foreach ($forbiddenPath in @('driver', 'native',
        'src\Input\LowLevelInputService.ahk',
        'src\Core\ManagedHotkeyBackend.ahk',
        'src\Core\DeviceFilterBackend.ahk',
        'src\Platform\DeviceDriverClient.ahk',
        'assets\fonts\PingFang.ttc',
        'assets\fonts\SF-Pro-Text-Regular.otf',
        'assets\fonts\SF-Pro-Text-Bold.otf',
        'assets\fonts\AppleSDGothicNeo-Regular.ttf',
        'assets\fonts\HaranoAjiGothic-Regular.otf',
        'assets\fonts\COMMERCIAL-LICENSE-NOTICE.md')) {
    if (Test-Path -LiteralPath (Join-Path $packageDirectory $forbiddenPath)) {
        throw "Release package contains obsolete input infrastructure: $forbiddenPath"
    }
}

$zipHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $zipPath).Hash
$exePath = Join-Path $packageDirectory $guiExecutable
$exeHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $exePath).Hash
$checksumText = Get-Content -LiteralPath $checksumsPath -Raw -Encoding UTF8
$expectedChecksumText = "$zipHash  $packageName.zip`n" +
    "$exeHash  $packageName/$guiExecutable`n"
if ($checksumText.Replace("`r`n", "`n") -cne $expectedChecksumText) {
    throw 'SHA256SUMS.txt does not match the release ZIP and executable.'
}

$validation = Start-Process -FilePath $exePath `
    -ArgumentList '--startup-validation' -PassThru -Wait -WindowStyle Hidden
if ($validation.ExitCode -ne 0) {
    throw "Packaged GUI startup validation failed: $($validation.ExitCode)"
}
$capabilities = (& (Join-Path $packageDirectory $cliLauncher) `
    capabilities) | Out-String | ConvertFrom-Json
if ($LASTEXITCODE -ne 0 -or $capabilities.backend -ne 'raw-input' -or
        -not $capabilities.device_identification -or
        $capabilities.requires_driver -or
        $capabilities.suppresses_simple_hotkeys) {
    throw 'Packaged CLI startup validation failed.'
}

$extractRoot = Join-Path $projectRoot ('.build\artifact-check-' +
    [guid]::NewGuid().ToString('N'))
try {
    Expand-Archive -LiteralPath $zipPath -DestinationPath $extractRoot
    $sourceFiles = @(Get-ChildItem -LiteralPath $packageDirectory `
        -Recurse -File | Sort-Object FullName)
    $extractedFiles = @(Get-ChildItem -LiteralPath $extractRoot `
        -Recurse -File | Sort-Object FullName)
    if ($sourceFiles.Count -ne $extractedFiles.Count) {
        throw 'ZIP file count differs from the release directory.'
    }
    foreach ($sourceFile in $sourceFiles) {
        $relativePath = $sourceFile.FullName.Substring(
            $packageDirectory.Length + 1)
        $extractedPath = Join-Path $extractRoot $relativePath
        if (-not (Test-Path -LiteralPath $extractedPath -PathType Leaf) -or
            (Get-FileHash -Algorithm SHA256 -LiteralPath $sourceFile.FullName).Hash `
                -cne (Get-FileHash -Algorithm SHA256 `
                    -LiteralPath $extractedPath).Hash) {
            throw "ZIP content differs from release directory: $relativePath"
        }
    }

    $tamperedRuntime = Join-Path $extractRoot 'runtime\AutoHotkey64.exe'
    $tamperStream = [System.IO.File]::Open($tamperedRuntime,
        [System.IO.FileMode]::Open, [System.IO.FileAccess]::ReadWrite,
        [System.IO.FileShare]::Read)
    try {
        $tamperStream.Position = $tamperStream.Length - 1
        $originalByte = $tamperStream.ReadByte()
        $tamperStream.Position = $tamperStream.Length - 1
        $tamperStream.WriteByte($originalByte -bxor 0x01)
        $tamperStream.Flush()
    } finally {
        $tamperStream.Dispose()
    }
    $tamperedValidation = Start-Process -FilePath `
        (Join-Path $extractRoot $guiExecutable) `
        -ArgumentList '--startup-validation' -PassThru -Wait `
        -WindowStyle Hidden
    if ($tamperedValidation.ExitCode -eq 0) {
        throw 'Packaged GUI accepted a tampered AutoHotkey runtime.'
    }
    $powerShellPath = (Get-Process -Id $PID).Path
    $tamperedCli = Start-Process -FilePath $powerShellPath `
        -ArgumentList @('-NoProfile', '-NonInteractive', '-ExecutionPolicy',
            'Bypass', '-File',
            ('"' + (Join-Path $extractRoot $cliLauncher) + '"'),
            'capabilities') `
        -PassThru -Wait -WindowStyle Hidden
    if ($tamperedCli.ExitCode -eq 0) {
        throw 'Packaged CLI accepted a tampered AutoHotkey runtime.'
    }
} finally {
    $fullExtractRoot = [System.IO.Path]::GetFullPath($extractRoot)
    $buildPrefix = [System.IO.Path]::GetFullPath(
        (Join-Path $projectRoot '.build')).TrimEnd('\') + '\'
    if (($fullExtractRoot + '\').StartsWith($buildPrefix,
            [System.StringComparison]::OrdinalIgnoreCase) -and
        (Test-Path -LiteralPath $fullExtractRoot)) {
        Remove-Item -LiteralPath $fullExtractRoot -Recurse -Force
    }
}

Write-Host "Release artifact checks passed: $zipHash"
