$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$failures = [System.Collections.Generic.List[string]]::new()
$currentProductName = -join @([char]0x952E, [char]0x9F20, [char]0x91CD,
    [char]0x6620, [char]0x5C04, [char]0x5C0F, [char]0x52A9,
    [char]0x624B)
$oldProductName = -join @([char]0x952E, [char]0x9F20, [char]0x91CD,
    [char]0x6620, [char]0x5C04)

function Add-Failure([string]$Message) {
    $failures.Add($Message)
}

$gitignorePath = Join-Path $projectRoot '.gitignore'
if (-not (Test-Path -LiteralPath $gitignorePath -PathType Leaf)) {
    Add-Failure '.gitignore is missing.'
} else {
    $gitignore = Get-Content -LiteralPath $gitignorePath -Raw -Encoding UTF8
    foreach ($ignored in @('.tools/', '.build/', 'dist/')) {
        if (-not $gitignore.Contains($ignored)) {
            Add-Failure ".gitignore must exclude $ignored"
        }
    }
}

$requiredFiles = @(
    ($currentProductName + '.ahk'),
    ($currentProductName + '-CLI.ps1'),
    'key-mouse-remapper-assistant-cli.ahk',
    'app\KeyMouseRemapperAssistantApp.ahk',
    'assets\app\key-mouse-remapper-assistant.svg',
    'assets\app\key-mouse-remapper-assistant.png',
    'assets\app\key-mouse-remapper-assistant.ico',
    'README.md',
    'docs\architecture.md',
    'docs\rulespec-v2.md',
    'docs\migration.md',
    'docs\security-and-limits.md',
    'docs\packaging.md',
    'docs\cli.md',
    'docs\localization.md',
    'docs\validation-matrix.md'
)
foreach ($relativePath in $requiredFiles) {
    if (-not (Test-Path -LiteralPath (Join-Path $projectRoot $relativePath) `
            -PathType Leaf)) {
        Add-Failure "Required project file is missing: $relativePath"
    }
}

$forbiddenPaths = @(
    ($oldProductName + '.ahk'),
    ($oldProductName + '-CLI.ps1'),
    'key-mouse-remapper-cli.ahk',
    'app\KeyMouseRemapperApp.ahk',
    'native',
    'workers\raw-mapping-worker.ahk',
    'docs\karabiner-roadmap.md',
    'assets\fonts\PingFang.ttc',
    'assets\fonts\SF-Pro-Text-Regular.otf',
    'assets\fonts\SF-Pro-Text-Bold.otf',
    'assets\fonts\AppleSDGothicNeo-Regular.ttf',
    'assets\fonts\HaranoAjiGothic-Regular.otf',
    'assets\fonts\COMMERCIAL-LICENSE-NOTICE.md'
)
foreach ($relativePath in $forbiddenPaths) {
    if (Test-Path -LiteralPath (Join-Path $projectRoot $relativePath)) {
        Add-Failure "Obsolete project path remains: $relativePath"
    }
}
$duplicateReadmes = @(Get-ChildItem -LiteralPath (Join-Path $projectRoot 'docs') `
    -Filter 'README.*.md' -File -ErrorAction SilentlyContinue)
if ($duplicateReadmes.Count) {
    Add-Failure ('Duplicated localized READMEs remain: ' +
        (($duplicateReadmes | ForEach-Object Name) -join ', '))
}

$mainEntry = Join-Path $projectRoot ($currentProductName + '.ahk')
if (Test-Path -LiteralPath $mainEntry -PathType Leaf) {
    $entryText = Get-Content -LiteralPath $mainEntry -Raw -Encoding UTF8
    if (-not $entryText.Contains($currentProductName) -or
        -not $entryText.Contains('KeyMouseRemapperAssistantApp')) {
        Add-Failure 'The main entry does not use the current product name.'
    }
}
$buildScriptPath = Join-Path $projectRoot 'tools\build-release.ps1'
if (Test-Path -LiteralPath $buildScriptPath -PathType Leaf) {
    $buildText = Get-Content -LiteralPath $buildScriptPath -Raw -Encoding UTF8
    foreach ($requiredName in @('key-mouse-remapper-assistant-$version-windows-x64',
            ($currentProductName + '.exe'), ($currentProductName + '.ahk'),
            ($currentProductName + '-CLI.ps1'))) {
        if (-not $buildText.Contains($requiredName)) {
            Add-Failure "Release build is missing current name: $requiredName"
        }
    }
}

$productionRoots = @(($currentProductName + '.ahk'), 'key-mouse-remapper-assistant-cli.ahk',
    'app', 'src', 'workers')
$productionFiles = [System.Collections.Generic.List[System.IO.FileInfo]]::new()
foreach ($relativeRoot in $productionRoots) {
    $path = Join-Path $projectRoot $relativeRoot
    if (Test-Path -LiteralPath $path -PathType Leaf) {
        $productionFiles.Add((Get-Item -LiteralPath $path))
    } elseif (Test-Path -LiteralPath $path -PathType Container) {
        foreach ($file in Get-ChildItem -LiteralPath $path -Recurse -File `
                -Include '*.ahk', '*.ps1') {
            $productionFiles.Add($file)
        }
    }
}
$obsoleteArchitecturePattern = '(?i)RawMappingWorker|RawOutputSession|' +
    'ManagedHotkeyBackend|LowLevelInputService|DeviceFilterBackend|' +
    'DeviceDriverClient|WH_KEYBOARD_LL|WH_MOUSE_LL|SetWindowsHookEx|' +
    'InstallKeybdHook|InstallMouseHook|--raw-worker|KMR_RAW_OUTPUT|raw_ahk'
foreach ($file in $productionFiles) {
    $text = Get-Content -LiteralPath $file.FullName -Raw -Encoding UTF8
    if ($text -match $obsoleteArchitecturePattern) {
        Add-Failure "Obsolete input architecture remains in production: $($file.FullName)"
    }
}

foreach ($script in Get-ChildItem -LiteralPath $projectRoot -Recurse `
        -Include '*.ahk', '*.ps1' -File | Where-Object {
            $_.FullName -notmatch '\\(?:\.tools|\.build|dist)\\' -and
            $_.Name -notmatch '^\.syntax-check-[0-9a-f]+\.ahk(?:\.active)?$'
        }) {
    $text = Get-Content -LiteralPath $script.FullName -Raw -Encoding UTF8
    if ($text -match '(?i)(api[_-]?key|password|secret)\s*[:=]\s*["''][^"'']{8,}') {
        Add-Failure "Possible committed secret: $($script.FullName)"
    }
}

$markdownFiles = @(Get-ChildItem -LiteralPath $projectRoot -Recurse `
    -Filter '*.md' -File | Where-Object {
        $_.FullName -notmatch '\\(?:\.tools|\.build|dist|third_party)\\'
    })
$projectRootPrefix = $projectRoot.TrimEnd('\') + '\'
foreach ($markdownFile in $markdownFiles) {
    $markdown = Get-Content -LiteralPath $markdownFile.FullName -Raw `
        -Encoding UTF8
    $matches = [regex]::Matches($markdown,
        '(?:\]\((?<target>[^)]+)\)|(?:href|src)="(?<target>[^"]+)")')
    foreach ($match in $matches) {
        $target = $match.Groups['target'].Value.Trim().Trim('<', '>')
        if ($target -eq '' -or $target.StartsWith('#') -or
            $target -match '^[a-z][a-z0-9+.-]*:') {
            continue
        }
        $pathPart = ($target -split '#', 2)[0]
        if ($pathPart -eq '') {
            continue
        }
        try {
            $decodedPath = [Uri]::UnescapeDataString($pathPart)
            $resolved = [IO.Path]::GetFullPath((Join-Path `
                $markdownFile.DirectoryName $decodedPath))
        } catch {
            Add-Failure "Invalid Markdown link '$target' in $($markdownFile.FullName)"
            continue
        }
        if (-not $resolved.StartsWith($projectRootPrefix,
                [StringComparison]::OrdinalIgnoreCase) -and
            $resolved -cne $projectRoot) {
            Add-Failure "Markdown link escapes the repository: '$target' in $($markdownFile.FullName)"
        } elseif (-not (Test-Path -LiteralPath $resolved)) {
            Add-Failure "Broken Markdown link '$target' in $($markdownFile.FullName)"
        }
    }
}

if ($failures.Count) {
    $failures | ForEach-Object { Write-Error $_ }
    exit 1
}
Write-Host 'Repository checks passed.'
