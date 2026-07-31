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
    'docs\validation-matrix.md',
    'CHANGELOG.md',
    'docs\CHANGELOG.en.md',
    'docs\changelog-template.md',
    'docs\en\changelog-template.md',
    '.github\SUPPORT.md',
    '.github\SUPPORT.en.md',
    '.github\ISSUE_TEMPLATE\bug_report.yml',
    '.github\ISSUE_TEMPLATE\bug_report_en.yml',
    '.github\ISSUE_TEMPLATE\feature_request.yml',
    '.github\ISSUE_TEMPLATE\feature_request_en.yml',
    '.github\ISSUE_TEMPLATE\improvement.yml',
    '.github\ISSUE_TEMPLATE\improvement_en.yml',
    '.github\ISSUE_TEMPLATE\config.yml'
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
            'key-mouse-remapper-assistant-$version-source',
            ($currentProductName + '.exe'), ($currentProductName + '.ahk'),
            ($currentProductName + '-CLI.ps1'))) {
        if (-not $buildText.Contains($requiredName)) {
            Add-Failure "Release build is missing current name: $requiredName"
        }
    }
}

$version = (Get-Content -LiteralPath (Join-Path $projectRoot 'VERSION') `
    -Raw -Encoding UTF8).Trim()
if ($version -notmatch `
        '^(?:0|[1-9]\d*)\.(?:0|[1-9]\d*)\.(?:0|[1-9]\d*)$') {
    Add-Failure "VERSION is not semantic version text: $version"
}
$packageName = "key-mouse-remapper-assistant-$version-windows-x64.zip"
$sourcePackageName = "key-mouse-remapper-assistant-$version-source.zip"
$releaseNotesRelativePath = "docs\release-notes\v$version.md"
$releaseNotesPath = Join-Path $projectRoot $releaseNotesRelativePath
if (-not (Test-Path -LiteralPath $releaseNotesPath -PathType Leaf)) {
    Add-Failure "Current release notes are missing: $releaseNotesRelativePath"
} else {
    $releaseNotes = Get-Content -LiteralPath $releaseNotesPath -Raw `
        -Encoding UTF8
    foreach ($marker in @("# 🎉 $currentProductName v$version",
            '## 📦 发布物说明', $packageName, $sourcePackageName,
            'v2.0.26 x64', '无需另行安装 AutoHotkey')) {
        if (-not $releaseNotes.Contains($marker)) {
            Add-Failure "Release notes are missing required marker: $marker"
        }
    }
    if ($releaseNotes.Contains('SHA256SUMS.txt')) {
        Add-Failure 'Current release notes must describe only the two ZIP packages.'
    }
    $assetHeadingIndex = $releaseNotes.LastIndexOf(
        '## 📦 发布物说明', [StringComparison]::Ordinal)
    if ($assetHeadingIndex -lt 0 -or
        $releaseNotes.Substring($assetHeadingIndex) -match
            '(?m)^## (?!📦 发布物说明)') {
        Add-Failure 'Release assets must be the final release-notes section.'
    }
    if ($releaseNotes -match
            '(?mi)^##\s+(?:✅\s*)?(?:验证范围|测试范围|Validation\s+Scope|Test\s+Coverage)\s*$') {
        Add-Failure 'Release notes must not contain a validation-scope section.'
    }
}

$changelogContracts = @(
    @{
        Path = 'CHANGELOG.md'
        Title = '# 📋 更新日志'
        Unreleased = '## 🚧 [未发布]'
        VersionHeading = "## 🎉 版本 [$version] - "
        AssetHeading = '### 📦 发布物说明'
    }
    @{
        Path = 'docs\CHANGELOG.en.md'
        Title = '# 📋 Changelog'
        Unreleased = '## 🚧 [Unreleased]'
        VersionHeading = "## 🎉 Version [$version] - "
        AssetHeading = '### 📦 Release Assets'
    }
)
foreach ($contract in $changelogContracts) {
    $changelogPath = Join-Path $projectRoot $contract.Path
    if (-not (Test-Path -LiteralPath $changelogPath -PathType Leaf)) {
        continue
    }
    $changelog = Get-Content -LiteralPath $changelogPath -Raw -Encoding UTF8
    foreach ($marker in @($contract.Title, $contract.Unreleased,
            $contract.VersionHeading, $contract.AssetHeading, $packageName,
            $sourcePackageName)) {
        if (-not $changelog.Contains($marker)) {
            Add-Failure "Changelog is missing '$marker': $($contract.Path)"
        }
    }
    $currentVersionIndex = $changelog.IndexOf($contract.VersionHeading,
        [StringComparison]::Ordinal)
    if ($currentVersionIndex -ge 0) {
        $nextVersionIndex = $changelog.IndexOf("`n## 🎉 ",
            $currentVersionIndex + $contract.VersionHeading.Length,
            [StringComparison]::Ordinal)
        $currentVersionText = if ($nextVersionIndex -ge 0) {
            $changelog.Substring($currentVersionIndex,
                $nextVersionIndex - $currentVersionIndex)
        } else { $changelog.Substring($currentVersionIndex) }
        $currentAssetIndex = $currentVersionText.IndexOf(
            $contract.AssetHeading, [StringComparison]::Ordinal)
        $currentAssetEnd = if ($currentAssetIndex -ge 0) {
            $currentVersionText.IndexOf("`n---", $currentAssetIndex,
                [StringComparison]::Ordinal)
        } else { -1 }
        $currentAssetText = if ($currentAssetIndex -ge 0 -and
                $currentAssetEnd -gt $currentAssetIndex) {
            $currentVersionText.Substring($currentAssetIndex,
                $currentAssetEnd - $currentAssetIndex)
        } elseif ($currentAssetIndex -ge 0) {
            $currentVersionText.Substring($currentAssetIndex)
        } else { '' }
        if ($currentAssetText.Contains('SHA256SUMS.txt')) {
            Add-Failure "Current changelog assets must list only two ZIP packages: $($contract.Path)"
        }
    }
    if ($changelog -match '(?m)^## \[(?:\d|未发布|Unreleased)') {
        Add-Failure "Legacy changelog headings must not return: $($contract.Path)"
    }
    if ($changelog -match
            '(?mi)^#{2,3}\s+(?:✅\s*)?(?:验证范围|测试范围|Validation\s+Scope|Test\s+Coverage)\s*$') {
        Add-Failure "Changelog must not contain validation scope: $($contract.Path)"
    }
}

$templateContracts = @(
    @{
        Path = 'docs\changelog-template.md'
        Markers = @('# 📝 中文更新日志模板',
            '## 🎉 版本 [X.Y.Z] - YYYY-MM-DD', '### 📦 发布物说明',
            '模板默认不生成“重要说明”', '没有合格事项时连标题一起删除',
            '更新日志和 Release Notes 均不得包含“✅ 验证范围”章节')
    }
    @{
        Path = 'docs\en\changelog-template.md'
        Markers = @('# 📝 English Changelog Template',
            '## 🎉 Version [X.Y.Z] - YYYY-MM-DD', '### 📦 Release Assets',
            'does not generate', 'Remove the heading when no item qualifies',
            'Neither changelogs nor Release notes may contain a `✅ Validation Scope` section')
    }
)
foreach ($contract in $templateContracts) {
    $templatePath = Join-Path $projectRoot $contract.Path
    if (-not (Test-Path -LiteralPath $templatePath -PathType Leaf)) {
        continue
    }
    $template = Get-Content -LiteralPath $templatePath -Raw -Encoding UTF8
    foreach ($marker in $contract.Markers) {
        if (-not $template.Contains($marker)) {
            Add-Failure "Changelog template is missing '$marker': $($contract.Path)"
        }
    }
}

$releaseWorkflowPath = Join-Path $projectRoot '.github\workflows\release.yml'
if (Test-Path -LiteralPath $releaseWorkflowPath -PathType Leaf) {
    $releaseWorkflow = Get-Content -LiteralPath $releaseWorkflowPath -Raw `
        -Encoding UTF8
    if (-not $releaseWorkflow.Contains(
            'body_path: docs/release-notes/v${{ steps.release_meta.outputs.version }}.md') -or
        -not $releaseWorkflow.Contains(
            'dist/key-mouse-remapper-assistant-${{ steps.release_meta.outputs.version }}-windows-x64.zip') -or
        -not $releaseWorkflow.Contains(
            'dist/key-mouse-remapper-assistant-${{ steps.release_meta.outputs.version }}-source.zip') -or
        $releaseWorkflow.Contains('SHA256SUMS.txt') -or
        $releaseWorkflow.Contains('generate_release_notes: true')) {
        Add-Failure 'Release workflow must publish the versioned release-notes file.'
    }
}

$issueTemplateDirectory = Join-Path $projectRoot '.github\ISSUE_TEMPLATE'
$issueForms = @('bug_report.yml', 'bug_report_en.yml',
    'feature_request.yml', 'feature_request_en.yml', 'improvement.yml',
    'improvement_en.yml')
foreach ($issueFormName in $issueForms) {
    $issueFormPath = Join-Path $issueTemplateDirectory $issueFormName
    if (-not (Test-Path -LiteralPath $issueFormPath -PathType Leaf)) {
        continue
    }
    $issueForm = Get-Content -LiteralPath $issueFormPath -Raw -Encoding UTF8
    foreach ($marker in @('name:', 'description:', 'title:', 'labels:',
            'body:', 'validations:', 'required: true')) {
        if (-not $issueForm.Contains($marker)) {
            Add-Failure "Issue form is missing '$marker': $issueFormName"
        }
    }
    $ids = @([regex]::Matches($issueForm, '(?m)^\s+id:\s*([^\s]+)\s*$') |
        ForEach-Object { $_.Groups[1].Value })
    if ($ids.Count -ne @($ids | Sort-Object -Unique).Count) {
        Add-Failure "Issue form contains duplicate field ids: $issueFormName"
    }
    if ($issueForm -match '(?i)process-watchdog|watchdog\.ini|守护目标') {
        Add-Failure "Issue form contains copied watchdog domain text: $issueFormName"
    }
}
$issueConfigPath = Join-Path $issueTemplateDirectory 'config.yml'
if (Test-Path -LiteralPath $issueConfigPath -PathType Leaf) {
    $issueConfig = Get-Content -LiteralPath $issueConfigPath -Raw -Encoding UTF8
    foreach ($marker in @('blank_issues_enabled: false',
            'key-mouse-remapper-assistant/blob/main/.github/SUPPORT.md',
            'key-mouse-remapper-assistant/blob/main/.github/SUPPORT.en.md',
            'key-mouse-remapper-assistant/security/advisories/new')) {
        if (-not $issueConfig.Contains($marker)) {
            Add-Failure "Issue-template config is missing '$marker'."
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
