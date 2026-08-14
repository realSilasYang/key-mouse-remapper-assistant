[CmdletBinding()]
param(
    [string]$AutoHotkeyPath = "",
    [string]$CompilerPath = "",
    [string]$AutoHotkeySourcePath = "",
    [string]$OutputRoot = ""
)

$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot 'BuildPathSafety.psm1') -Force
Import-Module (Join-Path $PSScriptRoot 'WindowsProcessArguments.psm1') -Force
$projectRoot = Assert-SafeBuildRoot (Split-Path -Parent $PSScriptRoot) `
    'Project root'
$version = (Get-Content -LiteralPath (Join-Path $projectRoot 'VERSION') `
    -Raw -Encoding UTF8).Trim()
if ($version -notmatch '^(?:0|[1-9]\d*)\.(?:0|[1-9]\d*)\.(?:0|[1-9]\d*)$') {
    throw "VERSION is not semantic: $version"
}
$entrySourcePath = Join-Path $projectRoot '键鼠重映射小助手.ahk'
$entrySourceText = Get-Content -LiteralPath $entrySourcePath -Raw `
    -Encoding UTF8
$builtInRuleCount = [regex]::Matches($entrySourceText,
    '(?m)^; @mapping-begin\r?$').Count
$builtInRuleEndCount = [regex]::Matches($entrySourceText,
    '(?m)^; @mapping-end\r?$').Count
$builtInManagedRuleCount = [regex]::Matches($entrySourceText,
    '(?m)^; @spec-begin\r?$').Count
$builtInScriptRuleCount = [regex]::Matches($entrySourceText,
    '(?m)^; @script-code-begin\r?$').Count
if ($builtInRuleCount -ne 18 -or
        $builtInRuleEndCount -ne $builtInRuleCount -or
        ($builtInManagedRuleCount + $builtInScriptRuleCount) -ne
            $builtInRuleCount) {
    throw ('The application entry must contain exactly 18 complete ' +
        'built-in mappings.')
}
$entrySourceHash = (Get-FileHash -Algorithm SHA256 `
    -LiteralPath $entrySourcePath).Hash

function Get-BuiltInSingleLineAiPromptValues {
    $sourcePath = Join-Path $projectRoot 'src\Core\AIService.ahk'
    $sourceText = Get-Content -LiteralPath $sourcePath -Raw -Encoding UTF8
    $values = @{}
    $promptNames = [ordered]@{
        PromptEscaped = 'DefaultGeneratePrompt'
        OptimizePromptEscaped = 'DefaultOptimizePrompt'
    }
    foreach ($settingName in $promptNames.Keys) {
        $memberName = $promptNames[$settingName]
        $match = [regex]::Match($sourceText,
            '(?m)^\s*static\s+' + [regex]::Escape($memberName) +
            '\s*:=\s*"((?:""|[^"])*)"\s*$')
        if (-not $match.Success) {
            throw "Unable to identify the built-in AI prompt: $memberName"
        }
        $literal = $match.Groups[1].Value.Replace('""', '"')
        $values[$settingName] = $literal.Replace('\', '\\')
    }
    return $values
}

$builtInSingleLineAiPrompts = Get-BuiltInSingleLineAiPromptValues

function Get-LocalAiParameterValues {
    $settingsPath = Join-Path `
        ([Environment]::GetFolderPath('ApplicationData')) `
        'KeyMouseRemapperAssistant\settings.ini'
    if (-not (Test-Path -LiteralPath $settingsPath -PathType Leaf)) {
        return @()
    }
    try {
        $settingsText = Get-Content -LiteralPath $settingsPath -Raw `
            -Encoding UTF8
    } catch {
        throw 'Unable to inspect the local AI settings privacy boundary.'
    }
    $section = [regex]::Match($settingsText,
        '(?ms)^\[AI\]\s*\r?\n(.*?)(?=^\[|\z)')
    if (-not $section.Success) { return @() }
    $parameters = [Collections.Generic.List[object]]::new()
    foreach ($name in @('Address', 'Key', 'Model', 'PromptEscaped',
            'OptimizePromptEscaped', 'SystemPromptEscaped')) {
        $match = [regex]::Match($section.Groups[1].Value,
            '(?m)^' + [regex]::Escape($name) + '=(.*)$')
        if (-not $match.Success) { continue }
        $value = $match.Groups[1].Value.Trim()
        if ($value.Length -lt 4) { continue }
        if ($builtInSingleLineAiPrompts.ContainsKey($name) -and
                $value -ceq $builtInSingleLineAiPrompts[$name]) {
            continue
        }
        $parameters.Add([pscustomobject]@{ Name = $name; Value = $value })
    }
    return @($parameters)
}

function Assert-ReleaseContent {
    param(
        [Parameter(Mandatory = $true)][string]$Directory,
        [Parameter(Mandatory = $true)][string]$Label
    )

    $entryPath = Join-Path $Directory '键鼠重映射小助手.ahk'
    if (-not (Test-Path -LiteralPath $entryPath -PathType Leaf)) {
        throw "$Label does not contain the editable application entry."
    }
    $packagedEntryHash = (Get-FileHash -Algorithm SHA256 `
        -LiteralPath $entryPath).Hash
    if ($packagedEntryHash -cne $entrySourceHash) {
        throw "$Label does not contain the current built-in rules."
    }
    $packagedEntryText = Get-Content -LiteralPath $entryPath -Raw `
        -Encoding UTF8
    $packagedRuleCount = [regex]::Matches($packagedEntryText,
        '(?m)^; @mapping-begin\r?$').Count
    if ($packagedRuleCount -ne $builtInRuleCount) {
        throw "$Label changed the built-in rule count."
    }

    $files = @(Get-ChildItem -LiteralPath $Directory -Recurse -File -Force)
    $forbiddenStateNames = @(
        'settings.ini', 'runtime.ini', 'rule-appearance.json',
        'window-layout.ini'
    )
    foreach ($file in $files) {
        if ($file.Name.ToLowerInvariant() -in $forbiddenStateNames) {
            throw "$Label contains forbidden user state: $($file.Name)"
        }
    }

    $localAiParameters = @(Get-LocalAiParameterValues)
    if ($localAiParameters.Count -eq 0) { return }
    $textExtensions = @(
        '.ahk', '.json', '.md', '.ps1', '.psm1', '.svg', '.txt'
    )
    foreach ($file in $files) {
        if ([IO.Path]::GetExtension($file.Name).ToLowerInvariant() `
                -notin $textExtensions) {
            continue
        }
        try { $content = [IO.File]::ReadAllText($file.FullName) }
        catch { continue }
        foreach ($parameter in $localAiParameters) {
            if ($content.IndexOf($parameter.Value,
                    [StringComparison]::Ordinal) -ge 0) {
                throw "$Label contains the local AI $($parameter.Name)."
            }
        }
    }
}

$usingDefaultOutputRoot = -not $OutputRoot
if ($usingDefaultOutputRoot) {
    $OutputRoot = Join-Path $projectRoot 'dist'
}
$OutputRoot = Assert-SafeBuildRoot $OutputRoot 'Release output root'

if (-not $AutoHotkeyPath -or -not $CompilerPath) {
    $tools = & (Join-Path $PSScriptRoot 'bootstrap-toolchain.ps1')
    if (-not $AutoHotkeyPath) { $AutoHotkeyPath = $tools.AutoHotkeyPath }
    if (-not $CompilerPath) { $CompilerPath = $tools.CompilerPath }
    if (-not $AutoHotkeySourcePath) {
        $AutoHotkeySourcePath = $tools.AutoHotkeySourcePath
    }
}
$AutoHotkeyPath = [System.IO.Path]::GetFullPath($AutoHotkeyPath)
$CompilerPath = [System.IO.Path]::GetFullPath($CompilerPath)
Assert-NoReparsePointInPath $AutoHotkeyPath 'AutoHotkey executable' | Out-Null
Assert-NoReparsePointInPath $CompilerPath 'Ahk2Exe executable' | Out-Null
$lock = Get-Content -LiteralPath (Join-Path $PSScriptRoot 'toolchain.lock.json') `
    -Raw -Encoding UTF8 | ConvertFrom-Json
if (-not $AutoHotkeySourcePath) {
    $candidateSourcePath = Join-Path `
        (Split-Path -Parent (Split-Path -Parent $AutoHotkeyPath)) `
        ('cache\' + $lock.tools.autoHotkey.sourceArchive)
    if (Test-Path -LiteralPath $candidateSourcePath -PathType Leaf) {
        $AutoHotkeySourcePath = $candidateSourcePath
    } else {
        $tools = & (Join-Path $PSScriptRoot 'bootstrap-toolchain.ps1')
        $AutoHotkeySourcePath = $tools.AutoHotkeySourcePath
    }
}
$AutoHotkeySourcePath = [System.IO.Path]::GetFullPath($AutoHotkeySourcePath)
Assert-NoReparsePointInPath $AutoHotkeySourcePath `
    'AutoHotkey source archive' | Out-Null

function Assert-ToolHash {
    param([string]$Name, [string]$Path, [string]$ExpectedHash)
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        throw "$Name was not found: $Path"
    }
    $actualHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $Path).Hash
    if ($actualHash -ne $ExpectedHash) {
        throw "$Name hash mismatch: $actualHash"
    }
}
Assert-ToolHash 'AutoHotkey' $AutoHotkeyPath `
    $lock.tools.autoHotkey.executableSha256
Assert-ToolHash 'Ahk2Exe' $CompilerPath $lock.tools.ahk2Exe.executableSha256

$licensePath = Join-Path (Split-Path -Parent $AutoHotkeyPath) `
    $lock.tools.autoHotkey.licenseFile
Assert-ToolHash 'AutoHotkey license' $licensePath `
    $lock.tools.autoHotkey.licenseSha256
Assert-ToolHash 'AutoHotkey source archive' $AutoHotkeySourcePath `
    $lock.tools.autoHotkey.sourceSha256

function Assert-OutputPath {
    param([string]$Path)
    return Assert-SafeBuildChild $OutputRoot $Path 'Release output path'
}

function Normalize-Ahk2ExeVersionPadding {
    param([Parameter(Mandatory = $true)][string]$ExecutablePath)

    $bytes = [IO.File]::ReadAllBytes($ExecutablePath)
    $singleByteEncoding = [Text.Encoding]::GetEncoding(28591)
    $binaryText = $singleByteEncoding.GetString($bytes)
    $rootKey = 'VS_VERSION_INFO'
    $rootPatternBytes = [Text.Encoding]::Unicode.GetBytes(
        $rootKey + [char]0)
    $rootPattern = $singleByteEncoding.GetString($rootPatternBytes)
    $rootKeyOffset = $binaryText.IndexOf($rootPattern,
        [StringComparison]::Ordinal)
    if ($rootKeyOffset -lt 6 -or $binaryText.IndexOf($rootPattern,
            $rootKeyOffset + 1, [StringComparison]::Ordinal) -ge 0) {
        throw 'Compiled executable must contain exactly one VS_VERSION_INFO resource.'
    }
    $keyCounts = @{}
    $normalizeBlock = $null
    $normalizeBlock = {
        param([int]$StructureOffset, [int]$ContainingEnd)

        if ($StructureOffset -lt 0 -or $StructureOffset + 6 -gt $ContainingEnd) {
            throw 'Compiled executable contains a truncated version-resource structure.'
        }
        $structureLength = [BitConverter]::ToUInt16($bytes, $StructureOffset)
        $valueLength = [BitConverter]::ToUInt16($bytes, $StructureOffset + 2)
        $valueType = [BitConverter]::ToUInt16($bytes, $StructureOffset + 4)
        $structureEnd = $StructureOffset + $structureLength
        if ($structureLength -lt 8 -or $structureEnd -gt $ContainingEnd) {
            throw 'Compiled executable contains an invalid version-resource length.'
        }
        $keyCharacters = [Collections.Generic.List[char]]::new()
        $cursor = $StructureOffset + 6
        $keyTerminated = $false
        while ($cursor + 1 -lt $structureEnd) {
            $codeUnit = [BitConverter]::ToUInt16($bytes, $cursor)
            $cursor += 2
            if ($codeUnit -eq 0) {
                $keyTerminated = $true
                break
            }
            $keyCharacters.Add([char]$codeUnit)
        }
        if (-not $keyTerminated) {
            throw 'Compiled executable contains an unterminated version-resource key.'
        }
        $key = $keyCharacters -join ''
        if ($keyCounts.ContainsKey($key)) {
            $keyCounts[$key]++
        } else {
            $keyCounts[$key] = 1
        }
        if (($key -ceq 'VarFileInfo' -and
                ($valueLength -ne 0 -or $valueType -ne 1)) -or
            ($key -ceq 'Translation' -and
                ($valueLength -ne 4 -or $valueType -ne 0))) {
            throw "Compiled executable has an invalid $key version-resource structure."
        }
        $valueOffset = ($cursor + 3) -band (-bnot 3)
        if ($valueOffset -gt $structureEnd) {
            throw "Compiled executable has invalid padding after version key $key."
        }
        for ($paddingOffset = $cursor; $paddingOffset -lt $valueOffset;
                $paddingOffset++) {
            $bytes[$paddingOffset] = 0
        }
        $valueBytes = if ($valueType -eq 1) { $valueLength * 2 } else {
            $valueLength
        }
        $valueEnd = $valueOffset + $valueBytes
        if ($valueEnd -gt $structureEnd) {
            throw "Compiled executable has invalid value length for version key $key."
        }
        $childrenOffset = ($valueEnd + 3) -band (-bnot 3)
        if ($childrenOffset -gt $structureEnd) {
            throw "Compiled executable has invalid value alignment for version key $key."
        }
        for ($paddingOffset = $valueEnd; $paddingOffset -lt $childrenOffset;
                $paddingOffset++) {
            $bytes[$paddingOffset] = 0
        }
        $cursor = $childrenOffset
        while ($cursor + 6 -le $structureEnd) {
            $childLength = [BitConverter]::ToUInt16($bytes, $cursor)
            if ($childLength -eq 0) { break }
            $childEnd = & $normalizeBlock $cursor $structureEnd
            $nextChild = ($childEnd + 3) -band (-bnot 3)
            if ($nextChild -gt $structureEnd) {
                throw "Compiled executable has invalid child alignment for version key $key."
            }
            for ($paddingOffset = $childEnd; $paddingOffset -lt $nextChild;
                    $paddingOffset++) {
                $bytes[$paddingOffset] = 0
            }
            $cursor = $nextChild
        }
        for ($paddingOffset = $cursor; $paddingOffset -lt $structureEnd;
                $paddingOffset++) {
            $bytes[$paddingOffset] = 0
        }
        return $structureEnd
    }
    $rootOffset = $rootKeyOffset - 6
    $parsedRootEnd = & $normalizeBlock $rootOffset $bytes.Length
    if ($parsedRootEnd -le $rootOffset -or
            -not $keyCounts.ContainsKey($rootKey) -or
            $keyCounts[$rootKey] -ne 1) {
        throw 'Compiled executable contains an invalid VS_VERSION_INFO root.'
    }
    foreach ($requiredKey in @('VarFileInfo', 'Translation')) {
        if (-not $keyCounts.ContainsKey($requiredKey) -or
                $keyCounts[$requiredKey] -ne 1) {
            throw "Compiled executable must contain exactly one $requiredKey version-resource key."
        }
    }
    [IO.File]::WriteAllBytes($ExecutablePath, $bytes)
}

New-Item -ItemType Directory -Force -Path $OutputRoot | Out-Null
Assert-SafeBuildRoot $OutputRoot 'Release output root' | Out-Null
$packageName = "key-mouse-remapper-assistant-$version-windows-x64"
$packageDirectory = Assert-OutputPath (Join-Path $OutputRoot $packageName)
$zipPath = Assert-OutputPath (Join-Path $OutputRoot "$packageName.zip")
$sourcePackageName = "key-mouse-remapper-assistant-$version-source"
$sourcePackageDirectory = Assert-OutputPath `
    (Join-Path $OutputRoot $sourcePackageName)
$sourceZipPath = Assert-OutputPath `
    (Join-Path $OutputRoot "$sourcePackageName.zip")
$obsoleteChecksumsPath = Assert-OutputPath `
    (Join-Path $OutputRoot 'SHA256SUMS.txt')
$versionedArtifactPattern =
    '^key-mouse-remapper-assistant-[0-9]+\.[0-9]+\.[0-9]+-(?:windows-x64|source)(?:\.zip)?$'
$legacyTargets = @()
if ($usingDefaultOutputRoot) {
    $legacyTargets = @(
        (Assert-OutputPath (Join-Path $OutputRoot `
            "key-mouse-remapper-$version-windows-x64")),
        (Assert-OutputPath (Join-Path $OutputRoot `
            "key-mouse-remapper-$version-windows-x64.zip")),
        (Assert-OutputPath (Join-Path $OutputRoot `
            "key-remapper-$version-windows-x64")),
        (Assert-OutputPath (Join-Path $OutputRoot `
            "key-remapper-$version-windows-x64.zip")),
        (Assert-OutputPath (Join-Path $OutputRoot 'final'))
    )
}
$backupRoot = Assert-OutputPath (Join-Path $OutputRoot `
    ('.release-backup-' + [guid]::NewGuid().ToString('N')))
$previousOutputs = [Collections.Generic.List[object]]::new()

$scratchRoot = Join-Path $projectRoot ('.build\release-' +
    [guid]::NewGuid().ToString('N'))
$fullScratchRoot = Assert-SafeBuildChild $projectRoot $scratchRoot `
    'Release scratch directory'
if (Test-Path -LiteralPath $scratchRoot) {
    Remove-Item -LiteralPath $scratchRoot -Recurse -Force
}
New-Item -ItemType Directory -Force -Path $scratchRoot | Out-Null
$fullScratchRoot = Assert-SafeBuildRoot $scratchRoot `
    'Release scratch directory'

$releaseMutexHashAlgorithm = [Security.Cryptography.SHA256]::Create()
try {
    $releaseMutexHash = (($releaseMutexHashAlgorithm.ComputeHash(
        [Text.Encoding]::UTF8.GetBytes($OutputRoot.ToLowerInvariant())) |
        ForEach-Object { $_.ToString('x2') }) -join '').ToUpperInvariant()
} finally { $releaseMutexHashAlgorithm.Dispose() }
$releaseMutex = [Threading.Mutex]::new($false,
    ('Global\KeyMouseRemapperAssistant.Release.' + $releaseMutexHash))
$releaseMutexAcquired = $false
$releaseTransactionStarted = $false
$releaseCompleted = $false
$releaseFailure = $null
$rollbackErrors = [Collections.Generic.List[string]]::new()
try {
try { $releaseMutexAcquired = $releaseMutex.WaitOne(30000) }
catch [Threading.AbandonedMutexException] { $releaseMutexAcquired = $true }
if (-not $releaseMutexAcquired) {
    throw "Timed out waiting for another release build targeting $OutputRoot"
}
$releaseTransactionStarted = $true
New-Item -ItemType Directory -Path $backupRoot | Out-Null
$outputsToBackup = [Collections.Generic.List[object]]::new()
foreach ($output in @(
        [pscustomobject]@{ Path = $packageDirectory; Name = 'package' },
        [pscustomobject]@{ Path = $zipPath; Name = 'archive.zip' },
        [pscustomobject]@{ Path = $sourcePackageDirectory;
            Name = 'source-package' },
        [pscustomobject]@{ Path = $sourceZipPath;
            Name = 'source-archive.zip' },
        [pscustomobject]@{ Path = $obsoleteChecksumsPath;
            Name = 'obsolete-checksums.txt' })) {
    $outputsToBackup.Add($output)
}
$currentArtifactNames = @($packageName, "$packageName.zip",
    $sourcePackageName, "$sourcePackageName.zip")
$obsoleteVersionTargets = @(Get-ChildItem -LiteralPath $OutputRoot -Force |
    Where-Object {
        $_.Name -match $versionedArtifactPattern -and
        $_.Name -notin $currentArtifactNames
    } |
    Sort-Object Name |
    ForEach-Object {
        Assert-OutputPath $_.FullName
    })
for ($obsoleteIndex = 0; $obsoleteIndex -lt $obsoleteVersionTargets.Count;
        $obsoleteIndex++) {
    $outputsToBackup.Add([pscustomobject]@{
        Path = $obsoleteVersionTargets[$obsoleteIndex]
        Name = "obsolete-version-$obsoleteIndex"
    })
}
for ($legacyIndex = 0; $legacyIndex -lt $legacyTargets.Count;
        $legacyIndex++) {
    $outputsToBackup.Add([pscustomobject]@{
        Path = $legacyTargets[$legacyIndex]
        Name = "legacy-$legacyIndex"
    })
}
foreach ($output in $outputsToBackup) {
    if (-not (Test-Path -LiteralPath $output.Path)) { continue }
    $backupPath = Assert-SafeBuildChild $backupRoot `
        (Join-Path $backupRoot $output.Name) 'Previous release backup'
    Move-Item -LiteralPath $output.Path -Destination $backupPath
    $previousOutputs.Add([pscustomobject]@{
        Path = $output.Path
        BackupPath = $backupPath
    })
}
$stageRoot = Join-Path $scratchRoot 'stage'
New-Item -ItemType Directory -Force -Path $stageRoot | Out-Null
foreach ($directory in @('app', 'assets', 'docs', 'src', 'third_party')) {
    $sourceDirectory = Join-Path $projectRoot $directory
    Assert-NoReparsePointTree $sourceDirectory `
        "Release source directory $directory" | Out-Null
    Copy-Item -LiteralPath $sourceDirectory `
        -Destination $stageRoot -Recurse
}
$packagedLauncherPath = Join-Path $stageRoot `
    'src\Platform\PackagedLauncher.ahk'
$packagedLauncherText = Get-Content -LiteralPath $packagedLauncherPath `
    -Raw -Encoding UTF8
$runtimeHashPlaceholder = '__PACKAGED_RUNTIME_SHA256__'
if ([regex]::Matches($packagedLauncherText,
        [regex]::Escape($runtimeHashPlaceholder)).Count -ne 1) {
    throw 'Packaged runtime hash placeholder is missing or duplicated.'
}
$packagedLauncherText = $packagedLauncherText.Replace(
    $runtimeHashPlaceholder, $lock.tools.autoHotkey.executableSha256)
[System.IO.File]::WriteAllText($packagedLauncherPath,
    $packagedLauncherText, [System.Text.UTF8Encoding]::new($false))
$stageSource = Join-Path $stageRoot 'KeyMouseRemapperAssistantLauncher.ahk'
Copy-Item -LiteralPath $entrySourcePath `
    -Destination $stageSource
$stageToolDirectory = Join-Path $scratchRoot 'toolchain'
New-Item -ItemType Directory -Force -Path $stageToolDirectory | Out-Null
$stageAhk = Join-Path $stageToolDirectory 'AutoHotkey64.exe'
$stageCompiler = Join-Path $stageToolDirectory 'Ahk2Exe.exe'
Copy-Item -LiteralPath $AutoHotkeyPath -Destination $stageAhk
Copy-Item -LiteralPath $CompilerPath -Destination $stageCompiler
$stageExecutable = Join-Path $scratchRoot 'KeyMouseRemapperAssistant.exe'

$substituteDrive = $null
$mappedProjectRoot = $projectRoot
$compilerProcess = $null
$compilationFailure = $null
$compilationCleanupErrors = [Collections.Generic.List[string]]::new()
try {
    if (($stageSource + $stageExecutable + $stageCompiler + $stageAhk) `
            -match '[^\x00-\x7F]') {
        $occupied = @(Get-PSDrive -PSProvider FileSystem |
            ForEach-Object { $_.Name.ToUpperInvariant() })
        foreach ($letterCode in 90..80) {
            $letter = [char]$letterCode
            if ($letter -in $occupied) { continue }
            $result = Start-Process -FilePath 'subst.exe' `
                -ArgumentList "$letter`:", $scratchRoot -PassThru -Wait `
                -WindowStyle Hidden
            if ($result.ExitCode -eq 0) {
                $substituteDrive = "$letter`:"
                $mappedProjectRoot = "$substituteDrive\"
                break
            }
        }
        if (-not $substituteDrive) {
            throw 'Unable to allocate an ASCII build drive.'
        }
    }

    function ConvertTo-CompilerPath {
        param([string]$Path)
        $fullPath = [System.IO.Path]::GetFullPath($Path)
        $fullScratchPrefix = $fullScratchRoot.TrimEnd('\') + '\'
        if ($substituteDrive -and $fullPath.StartsWith($fullScratchPrefix,
                [System.StringComparison]::OrdinalIgnoreCase)) {
            return $mappedProjectRoot + $fullPath.Substring($fullScratchPrefix.Length)
        }
        if ($fullPath -match '[^\x00-\x7F]') {
            throw "Compiler path is not ASCII: $fullPath"
        }
        return $fullPath
    }

    $compilerArguments = @(
        '/in', (ConvertTo-CompilerPath $stageSource),
        '/out', (ConvertTo-CompilerPath $stageExecutable),
        '/icon', (ConvertTo-CompilerPath `
            (Join-Path $stageRoot 'assets\app\key-mouse-remapper-assistant.ico')),
        '/base', (ConvertTo-CompilerPath $stageAhk),
        '/silent', 'verbose'
    )
    $compilerStartInfo = [System.Diagnostics.ProcessStartInfo]::new()
    $compilerStartInfo.FileName = ConvertTo-CompilerPath $stageCompiler
    $compilerStartInfo.Arguments = Join-WindowsProcessArguments `
        $compilerArguments
    $compilerStartInfo.UseShellExecute = $false
    $compilerStartInfo.CreateNoWindow = $true
    $compilerStartInfo.RedirectStandardOutput = $true
    $compilerStartInfo.RedirectStandardError = $true
    $compilerProcess = [System.Diagnostics.Process]::Start($compilerStartInfo)
    $stdoutTask = $compilerProcess.StandardOutput.ReadToEndAsync()
    $stderrTask = $compilerProcess.StandardError.ReadToEndAsync()
    if (-not $compilerProcess.WaitForExit(120000)) {
        try {
            if (-not $compilerProcess.HasExited) {
                $compilerProcess.Kill()
            }
            if (-not $compilerProcess.WaitForExit(10000)) {
                throw 'Ahk2Exe did not exit within 10 seconds after termination.'
            }
        } catch {
            throw [InvalidOperationException]::new(
                'Ahk2Exe timed out after 120 seconds and could not be terminated: ' +
                $_.Exception.Message, $_.Exception)
        }
        throw 'Ahk2Exe timed out after 120 seconds.'
    }
    $compilerOutput = @(
        $stderrTask.GetAwaiter().GetResult(),
        $stdoutTask.GetAwaiter().GetResult()
    ) | Where-Object { $_ }
    if ($compilerProcess.ExitCode -ne 0 -or
        -not (Test-Path -LiteralPath $stageExecutable -PathType Leaf)) {
        throw "Ahk2Exe failed with exit code $($compilerProcess.ExitCode):`n$($compilerOutput -join "`n")"
    }
    Normalize-Ahk2ExeVersionPadding $stageExecutable
} catch {
    $compilationFailure = $_.Exception
} finally {
    if ($null -ne $compilerProcess) {
        try { $compilerProcess.Dispose() }
        catch {
            $compilationCleanupErrors.Add(
                "Unable to dispose the Ahk2Exe process: $($_.Exception.Message)")
        }
    }
    if ($substituteDrive) {
        try {
            $result = Start-Process -FilePath 'subst.exe' `
                -ArgumentList $substituteDrive, '/D' -PassThru -Wait `
                -WindowStyle Hidden
            if ($result.ExitCode -ne 0) {
                throw "subst.exe exited with code $($result.ExitCode)."
            }
        } catch {
            $compilationCleanupErrors.Add(
                "Unable to remove temporary drive $substituteDrive`: " +
                $_.Exception.Message)
        }
    }
}
if ($null -ne $compilationFailure) {
    if ($compilationCleanupErrors.Count -gt 0) {
        throw [InvalidOperationException]::new(
            ('Release compilation failed: ' + $compilationFailure.Message +
            ' Compilation cleanup also failed: ' +
            ($compilationCleanupErrors -join '; ')), $compilationFailure)
    }
    throw $compilationFailure
}
if ($compilationCleanupErrors.Count -gt 0) {
    throw ('Release compilation cleanup failed: ' +
        ($compilationCleanupErrors -join '; '))
}

New-Item -ItemType Directory -Force -Path $packageDirectory | Out-Null
Assert-SafeBuildRoot $packageDirectory 'Release package directory' | Out-Null
Copy-Item -LiteralPath $stageExecutable `
    -Destination (Join-Path $packageDirectory '键鼠重映射小助手.exe')
Copy-Item -LiteralPath $entrySourcePath `
    -Destination $packageDirectory
foreach ($directory in @('app', 'assets', 'docs', 'src', 'third_party')) {
    $sourceDirectory = Join-Path $projectRoot $directory
    Assert-NoReparsePointTree $sourceDirectory `
        "Release source directory $directory" | Out-Null
    Copy-Item -LiteralPath $sourceDirectory `
        -Destination $packageDirectory -Recurse
}
foreach ($file in @('CHANGELOG.md', 'README.md', 'LICENSE', 'VERSION',
        'THIRD_PARTY_NOTICES.md')) {
    Copy-Item -LiteralPath (Join-Path $projectRoot $file) `
        -Destination $packageDirectory
}
$packagedToolsDirectory = Join-Path $packageDirectory 'tools'
New-Item -ItemType Directory -Force -Path $packagedToolsDirectory | Out-Null
foreach ($toolFile in @('toolchain.lock.json',
        'WindowsProcessArguments.psm1')) {
    Copy-Item -LiteralPath (Join-Path $projectRoot ('tools\' + $toolFile)) `
        -Destination $packagedToolsDirectory
}
$runtimeDirectory = Join-Path $packageDirectory 'runtime'
New-Item -ItemType Directory -Force -Path $runtimeDirectory | Out-Null
Copy-Item -LiteralPath (Join-Path $projectRoot 'runtime\application-update.ps1') `
    -Destination $runtimeDirectory
Copy-Item -LiteralPath (Join-Path $projectRoot `
        'runtime\application-update.strings.json') `
    -Destination $runtimeDirectory
Copy-Item -LiteralPath $AutoHotkeyPath `
    -Destination (Join-Path $runtimeDirectory 'AutoHotkey64.exe')
Copy-Item -LiteralPath $licensePath `
    -Destination (Join-Path $runtimeDirectory 'license.txt')
$runtimeSourceDirectory = Join-Path $runtimeDirectory 'sources'
New-Item -ItemType Directory -Force -Path $runtimeSourceDirectory | Out-Null
Copy-Item -LiteralPath $AutoHotkeySourcePath `
    -Destination (Join-Path $runtimeSourceDirectory `
        $lock.tools.autoHotkey.sourceArchive)

function ConvertTo-StableJsonString {
    param([AllowEmptyString()][string]$Value)

    $builder = [Text.StringBuilder]::new()
    [void]$builder.Append('"')
    foreach ($character in $Value.ToCharArray()) {
        $code = [int]$character
        switch ($code) {
            8 { [void]$builder.Append('\b'); continue }
            9 { [void]$builder.Append('\t'); continue }
            10 { [void]$builder.Append('\n'); continue }
            12 { [void]$builder.Append('\f'); continue }
            13 { [void]$builder.Append('\r'); continue }
            34 { [void]$builder.Append('\"'); continue }
            92 { [void]$builder.Append('\\'); continue }
        }
        if ($code -lt 0x20) {
            [void]$builder.Append(('\u{0:x4}' -f $code))
        } else {
            [void]$builder.Append($character)
        }
    }
    [void]$builder.Append('"')
    return $builder.ToString()
}
$manifestJson = (@(
    '{'
    '  "schemaVersion": 1,'
    '  "packageKind": "portable-runtime",'
    ('  "version": ' + (ConvertTo-StableJsonString $version) + ',')
    '  "platform": "windows-x64",'
    '  "entry": "键鼠重映射小助手.exe",'
    '  "editableSource": "键鼠重映射小助手.ahk",'
    ('  "builtInRuleCount": ' + $builtInRuleCount + ',')
    '  "bundlesUserSettings": false,'
    ('  "autoHotkey": ' +
        (ConvertTo-StableJsonString $lock.tools.autoHotkey.version) + ',')
    ('  "autoHotkeySha256": ' +
        (ConvertTo-StableJsonString `
            $lock.tools.autoHotkey.executableSha256) + ',')
    ('  "autoHotkeySourceCommit": ' +
        (ConvertTo-StableJsonString `
            $lock.tools.autoHotkey.sourceCommit) + ',')
    ('  "autoHotkeySourceSha256": ' +
        (ConvertTo-StableJsonString `
            $lock.tools.autoHotkey.sourceSha256) + ',')
    ('  "ahk2Exe": ' +
        (ConvertTo-StableJsonString $lock.tools.ahk2Exe.version) + ',')
    ('  "ahk2ExeSha256": ' +
        (ConvertTo-StableJsonString $lock.tools.ahk2Exe.executableSha256) + ',')
    '  "inputBackend": "direct-ahk-hotkeys",'
    '  "inputRecording": "raw-input",'
    '  "requiresDriver": false,'
    '  "suppressesOriginalInput": true'
    '}'
) -join "`n") + "`n"
[System.IO.File]::WriteAllText(
    (Join-Path $packageDirectory 'build-manifest.json'), $manifestJson,
    [System.Text.UTF8Encoding]::new($false))
$updateManifestJson = (@(
    '{'
    '  "schemaVersion": 1,'
    '  "packageKind": "compiled",'
    ('  "version": ' + (ConvertTo-StableJsonString $version) + ',')
    '  "entry": "键鼠重映射小助手.exe",'
    ('  "builtInRuleCount": ' + $builtInRuleCount + ',')
    '  "bundlesUserSettings": false,'
    '  "managedPaths": ['
    '    "键鼠重映射小助手.exe",'
    '    "键鼠重映射小助手.ahk",'
    '    "app",'
    '    "assets",'
    '    "src",'
    '    "third_party",'
    '    "tools",'
    '    "runtime",'
    '    "docs",'
    '    "CHANGELOG.md",'
    '    "README.md",'
    '    "LICENSE",'
    '    "VERSION",'
    '    "THIRD_PARTY_NOTICES.md",'
    '    "build-manifest.json",'
    '    "update-manifest.json"'
    '  ]'
    '}'
) -join "`n") + "`n"
[System.IO.File]::WriteAllText(
    (Join-Path $packageDirectory 'update-manifest.json'),
    $updateManifestJson, [System.Text.UTF8Encoding]::new($false))

# 源码版保持仓库的可运行布局，但不夹带本机工具链、编译 EXE、便携运行时或构建产物。
# 它与便携版分别归档，避免用户为审阅源码下载重复的运行时副本。
New-Item -ItemType Directory -Force -Path $sourcePackageDirectory |
    Out-Null
Assert-SafeBuildRoot $sourcePackageDirectory `
    'Release source package directory' | Out-Null
$sourcePackageFiles = @(
    '.editorconfig', '.gitattributes', '.gitignore',
    'CHANGELOG.md', 'LICENSE', 'README.md', 'THIRD_PARTY_NOTICES.md', 'VERSION',
    '键鼠重映射小助手.ahk'
)
foreach ($relativePath in $sourcePackageFiles) {
    $sourcePath = Join-Path $projectRoot $relativePath
    Assert-NoReparsePointInPath $sourcePath `
        "Release source file $relativePath" | Out-Null
    Copy-Item -LiteralPath $sourcePath -Destination $sourcePackageDirectory
}
foreach ($directory in @('app', 'assets', 'docs', 'src',
        'tests', 'third_party', 'tools', 'runtime')) {
    $sourceDirectory = Join-Path $projectRoot $directory
    Assert-NoReparsePointTree $sourceDirectory `
        "Release source directory $directory" | Out-Null
    Copy-Item -LiteralPath $sourceDirectory `
        -Destination $sourcePackageDirectory -Recurse
}
$sourceUpdateManifestJson = (@(
    '{'
    '  "schemaVersion": 1,'
    '  "packageKind": "source",'
    ('  "version": ' + (ConvertTo-StableJsonString $version) + ',')
    '  "entry": "键鼠重映射小助手.ahk",'
    ('  "builtInRuleCount": ' + $builtInRuleCount + ',')
    '  "bundlesUserSettings": false,'
    '  "managedPaths": ['
    '    ".editorconfig",'
    '    ".gitattributes",'
    '    ".gitignore",'
    '    "键鼠重映射小助手.ahk",'
    '    "app",'
    '    "assets",'
    '    "src",'
    '    "third_party",'
    '    "tools",'
    '    "runtime",'
    '    "docs",'
    '    "tests",'
    '    "CHANGELOG.md",'
    '    "README.md",'
    '    "LICENSE",'
    '    "VERSION",'
    '    "THIRD_PARTY_NOTICES.md",'
    '    "update-manifest.json"'
    '  ]'
    '}'
) -join "`n") + "`n"
[System.IO.File]::WriteAllText(
    (Join-Path $sourcePackageDirectory 'update-manifest.json'),
    $sourceUpdateManifestJson, [System.Text.UTF8Encoding]::new($false))

Assert-ReleaseContent $packageDirectory 'Portable release package'
Assert-ReleaseContent $sourcePackageDirectory 'Source release package'

if (-not ('KeyMouseRemapperAssistant.Build.DeterministicZipCrc32V2' `
        -as [type])) {
    Add-Type -TypeDefinition @'
using System;
using System.IO;

namespace KeyMouseRemapperAssistant.Build
{
    public static class DeterministicZipCrc32V2
    {
        private static readonly uint[] Table = CreateTable();

        private static uint[] CreateTable()
        {
            uint[] table = new uint[256];
            for (int index = 0; index < table.Length; index++)
            {
                uint value = (uint)index;
                for (int bit = 0; bit < 8; bit++)
                    value = (value & 1U) != 0U
                        ? 0xEDB88320U ^ (value >> 1)
                        : value >> 1;
                table[index] = value;
            }
            return table;
        }

        public static uint ComputeFile(string path)
        {
            uint crc = 0xFFFFFFFFU;
            byte[] buffer = new byte[1024 * 1024];
            using (FileStream stream = File.OpenRead(path))
            {
                int count;
                while ((count = stream.Read(buffer, 0, buffer.Length)) > 0)
                    crc = Update(crc, buffer, count);
            }
            return Complete(crc);
        }

        public static uint Update(uint crc, byte[] buffer, int count)
        {
            if (buffer == null)
                throw new ArgumentNullException("buffer");
            if (count < 0 || count > buffer.Length)
                throw new ArgumentOutOfRangeException("count");
            for (int index = 0; index < count; index++)
                crc = Table[(int)((crc ^ buffer[index]) & 0xFFU)] ^
                    (crc >> 8);
            return crc;
        }

        public static uint Complete(uint crc)
        {
            return ~crc;
        }
    }
}
'@
}
function New-DeterministicArchive {
    param([string]$SourceDirectory, [string]$ArchivePath)

    $utf8 = [Text.UTF8Encoding]::new($false, $true)
    $files = [Collections.Generic.List[object]]::new()
    foreach ($file in @(Get-ChildItem -LiteralPath $SourceDirectory `
            -Recurse -File -Force)) {
        $files.Add([pscustomobject]@{
            File = $file
            RelativePath = $file.FullName.Substring(
                $SourceDirectory.Length + 1).Replace('\', '/')
        })
    }
    $files.Sort([Comparison[object]]{
        param($left, $right)
        return [StringComparer]::Ordinal.Compare(
            [string]$left.RelativePath, [string]$right.RelativePath)
    })
    if ($files.Count -gt [uint16]::MaxValue) {
        throw 'Release package has too many files for a ZIP32 archive.'
    }

    $stream = [System.IO.File]::Open($ArchivePath,
        [System.IO.FileMode]::CreateNew)
    $writer = [IO.BinaryWriter]::new($stream, $utf8, $true)
    try {
        $entries = [Collections.Generic.List[object]]::new()
        foreach ($fileEntry in $files) {
            $file = $fileEntry.File
            if ($file.Length -gt [uint32]::MaxValue -or
                    $stream.Position -gt [uint32]::MaxValue) {
                throw 'Release package is too large for a ZIP32 archive.'
            }
            $nameBytes = $utf8.GetBytes([string]$fileEntry.RelativePath)
            if (-not $nameBytes.Length -or
                    $nameBytes.Length -gt [uint16]::MaxValue) {
                throw "Invalid ZIP entry name: $($fileEntry.RelativePath)"
            }
            $entry = [pscustomobject]@{
                NameBytes = $nameBytes
                Crc32 = `
                    [KeyMouseRemapperAssistant.Build.DeterministicZipCrc32V2]::ComputeFile(
                        $file.FullName)
                Size = [uint32]$file.Length
                Offset = [uint32]$stream.Position
            }
            $entries.Add($entry)

            $writer.Write([uint32]0x04034B50)
            $writer.Write([uint16]20)
            $writer.Write([uint16]0x0800)
            $writer.Write([uint16]0)
            $writer.Write([uint16]0)
            $writer.Write([uint16]0x0021)
            $writer.Write([uint32]$entry.Crc32)
            $writer.Write([uint32]$entry.Size)
            $writer.Write([uint32]$entry.Size)
            $writer.Write([uint16]$nameBytes.Length)
            $writer.Write([uint16]0)
            $writer.Write($nameBytes)

            $input = [IO.File]::OpenRead($file.FullName)
            try {
                $buffer = [byte[]]::new(1024 * 1024)
                $written = [long]0
                $writtenCrc = [uint32]::MaxValue
                while (($count = $input.Read($buffer, 0, $buffer.Length)) `
                        -gt 0) {
                    $writtenCrc = `
                        [KeyMouseRemapperAssistant.Build.DeterministicZipCrc32V2]::Update(
                            $writtenCrc, $buffer, $count)
                    $writer.Write($buffer, 0, $count)
                    $written += $count
                }
                $writtenCrc = `
                    [KeyMouseRemapperAssistant.Build.DeterministicZipCrc32V2]::Complete(
                        $writtenCrc)
                if ($written -ne $entry.Size -or
                        $writtenCrc -ne $entry.Crc32) {
                    throw "ZIP source changed during build: $($file.FullName)"
                }
            } finally { $input.Dispose() }
        }

        if ($stream.Position -gt [uint32]::MaxValue) {
            throw 'Release package is too large for a ZIP32 archive.'
        }
        $centralDirectoryOffset = [uint32]$stream.Position
        foreach ($entry in $entries) {
            $writer.Write([uint32]0x02014B50)
            $writer.Write([uint16]20)
            $writer.Write([uint16]20)
            $writer.Write([uint16]0x0800)
            $writer.Write([uint16]0)
            $writer.Write([uint16]0)
            $writer.Write([uint16]0x0021)
            $writer.Write([uint32]$entry.Crc32)
            $writer.Write([uint32]$entry.Size)
            $writer.Write([uint32]$entry.Size)
            $writer.Write([uint16]$entry.NameBytes.Length)
            $writer.Write([uint16]0)
            $writer.Write([uint16]0)
            $writer.Write([uint16]0)
            $writer.Write([uint16]0)
            $writer.Write([uint32]0)
            $writer.Write([uint32]$entry.Offset)
            $writer.Write($entry.NameBytes)
        }
        $centralDirectorySize = $stream.Position - $centralDirectoryOffset
        if ($centralDirectorySize -gt [uint32]::MaxValue -or
                $stream.Position -gt [uint32]::MaxValue) {
            throw 'Release package is too large for a ZIP32 archive.'
        }
        $writer.Write([uint32]0x06054B50)
        $writer.Write([uint16]0)
        $writer.Write([uint16]0)
        $writer.Write([uint16]$entries.Count)
        $writer.Write([uint16]$entries.Count)
        $writer.Write([uint32]$centralDirectorySize)
        $writer.Write([uint32]$centralDirectoryOffset)
        $writer.Write([uint16]0)
        $writer.Flush()
    } finally {
        $writer.Dispose()
        $stream.Dispose()
    }
}

Assert-NoReparsePointTree $packageDirectory `
    'Release package directory' | Out-Null
Assert-NoReparsePointTree $sourcePackageDirectory `
    'Release source package directory' | Out-Null
New-DeterministicArchive $packageDirectory $zipPath
New-DeterministicArchive $sourcePackageDirectory $sourceZipPath
$zipHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $zipPath).Hash
$sourceZipHash = (Get-FileHash -Algorithm SHA256 `
    -LiteralPath $sourceZipPath).Hash
$exePath = Join-Path $packageDirectory '键鼠重映射小助手.exe'
$exeHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $exePath).Hash
$releaseCompleted = $true

} catch {
    $releaseFailure = $_.Exception
} finally {
    if ($releaseTransactionStarted -and -not $releaseCompleted) {
        foreach ($target in @($packageDirectory, $zipPath,
                $sourcePackageDirectory, $sourceZipPath)) {
            try {
                $safeTarget = Assert-OutputPath $target
                if (Test-Path -LiteralPath $safeTarget) {
                    Remove-Item -LiteralPath $safeTarget -Recurse -Force
                }
            } catch { $rollbackErrors.Add($_.Exception.Message) }
        }
        foreach ($previousOutput in $previousOutputs) {
            try {
                if (Test-Path -LiteralPath $previousOutput.BackupPath) {
                    Move-Item -LiteralPath $previousOutput.BackupPath `
                        -Destination $previousOutput.Path
                }
            } catch { $rollbackErrors.Add($_.Exception.Message) }
        }
    }
    if ($releaseTransactionStarted -and
            ($releaseCompleted -or $rollbackErrors.Count -eq 0) -and
            (Test-Path -LiteralPath $backupRoot)) {
        try { Remove-Item -LiteralPath $backupRoot -Recurse -Force }
        catch { $rollbackErrors.Add($_.Exception.Message) }
    }
    if (Test-Path -LiteralPath $scratchRoot) {
        try {
            Assert-SafeBuildChild $projectRoot $scratchRoot `
                'Release scratch directory' | Out-Null
            Remove-Item -LiteralPath $scratchRoot -Recurse -Force
        } catch { $rollbackErrors.Add($_.Exception.Message) }
    }
    $scratchParent = Split-Path -Parent $scratchRoot
    if ((Test-Path -LiteralPath $scratchParent -PathType Container) -and
        -not (Get-ChildItem -LiteralPath $scratchParent -Force)) {
        try { Remove-Item -LiteralPath $scratchParent -Force }
        catch { $rollbackErrors.Add($_.Exception.Message) }
    }
    if ($releaseMutexAcquired) {
        try { $releaseMutex.ReleaseMutex() }
        catch { $rollbackErrors.Add($_.Exception.Message) }
    }
    try { $releaseMutex.Dispose() }
    catch { $rollbackErrors.Add($_.Exception.Message) }
}

if ($null -ne $releaseFailure) {
    if ($rollbackErrors.Count -gt 0) {
        throw [InvalidOperationException]::new(
            ('Release build failed: ' + $releaseFailure.Message +
            ' Previous-output rollback or final cleanup also failed: ' +
            ($rollbackErrors -join '; ') +
            ". Recoverable backup path: $backupRoot"), $releaseFailure)
    }
    throw $releaseFailure
}
if ($rollbackErrors.Count -gt 0) {
    throw ('Release build completed but final cleanup was incomplete: ' +
        ($rollbackErrors -join '; ') +
        ". Recoverable backup path: $backupRoot")
}

Write-Host "Release package: $zipPath"
Write-Host "Source package: $sourceZipPath"
Write-Host "Executable: $exePath"
[pscustomobject]@{
    Version = $version
    PackageDirectory = $packageDirectory
    ZipPath = $zipPath
    SourcePackageDirectory = $sourcePackageDirectory
    SourceZipPath = $sourceZipPath
    ExecutablePath = $exePath
    ZipSha256 = $zipHash
    SourceZipSha256 = $sourceZipHash
    ExecutableSha256 = $exeHash
}
