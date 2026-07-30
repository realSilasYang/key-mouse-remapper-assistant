[CmdletBinding()]
param(
    [string]$AutoHotkeyPath = "",
    [string]$CompilerPath = "",
    [string]$AutoHotkeySourcePath = "",
    [string]$OutputRoot = ""
)

$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot 'BuildPathSafety.psm1') -Force
$projectRoot = Assert-SafeBuildRoot (Split-Path -Parent $PSScriptRoot) `
    'Project root'
$version = (Get-Content -LiteralPath (Join-Path $projectRoot 'VERSION') `
    -Raw -Encoding UTF8).Trim()
if ($version -notmatch '^(?:0|[1-9]\d*)\.(?:0|[1-9]\d*)\.(?:0|[1-9]\d*)$') {
    throw "VERSION is not semantic: $version"
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
$checksumsPath = Assert-OutputPath (Join-Path $OutputRoot 'SHA256SUMS.txt')
$versionedArtifactPattern =
    '^key-mouse-remapper-assistant-[0-9]+\.[0-9]+\.[0-9]+-windows-x64(?:\.zip)?$'
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
        [pscustomobject]@{ Path = $checksumsPath; Name = 'checksums.txt' })) {
    $outputsToBackup.Add($output)
}
$currentArtifactNames = @($packageName, "$packageName.zip")
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
foreach ($directory in @('app', 'assets', 'src', 'third_party', 'workers')) {
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
Copy-Item -LiteralPath (Join-Path $projectRoot '键鼠重映射小助手.ahk') `
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
    $compilerStartInfo.Arguments = ($compilerArguments | ForEach-Object {
        '"' + ([string]$_).Replace('"', '\"') + '"'
    }) -join ' '
    $compilerStartInfo.UseShellExecute = $false
    $compilerStartInfo.CreateNoWindow = $true
    $compilerStartInfo.RedirectStandardOutput = $true
    $compilerStartInfo.RedirectStandardError = $true
    $compilerProcess = [System.Diagnostics.Process]::Start($compilerStartInfo)
    $stdoutTask = $compilerProcess.StandardOutput.ReadToEndAsync()
    $stderrTask = $compilerProcess.StandardError.ReadToEndAsync()
    if (-not $compilerProcess.WaitForExit(120000)) {
        try { $compilerProcess.Kill(); $compilerProcess.WaitForExit() } catch {}
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
} finally {
    if ($substituteDrive) {
        $result = Start-Process -FilePath 'subst.exe' `
            -ArgumentList $substituteDrive, '/D' -PassThru -Wait `
            -WindowStyle Hidden
        if ($result.ExitCode -ne 0) {
            Write-Warning "Unable to remove temporary drive $substituteDrive."
        }
    }
}

New-Item -ItemType Directory -Force -Path $packageDirectory | Out-Null
Assert-SafeBuildRoot $packageDirectory 'Release package directory' | Out-Null
Copy-Item -LiteralPath $stageExecutable `
    -Destination (Join-Path $packageDirectory '键鼠重映射小助手.exe')
Copy-Item -LiteralPath (Join-Path $projectRoot '键鼠重映射小助手.ahk') `
    -Destination $packageDirectory
foreach ($cliFile in @('key-mouse-remapper-assistant-cli.ahk', '键鼠重映射小助手-CLI.ps1')) {
    Copy-Item -LiteralPath (Join-Path $projectRoot $cliFile) `
        -Destination $packageDirectory
}
foreach ($directory in @('app', 'assets', 'docs', 'src', 'third_party',
        'workers')) {
    $sourceDirectory = Join-Path $projectRoot $directory
    Assert-NoReparsePointTree $sourceDirectory `
        "Release source directory $directory" | Out-Null
    Copy-Item -LiteralPath $sourceDirectory `
        -Destination $packageDirectory -Recurse
}
foreach ($file in @('README.md', 'CHANGELOG.md', 'CONTRIBUTING.md',
        'CODE_OF_CONDUCT.md', 'SECURITY.md', 'LICENSE', 'VERSION',
        'THIRD_PARTY_NOTICES.md')) {
    Copy-Item -LiteralPath (Join-Path $projectRoot $file) `
        -Destination $packageDirectory
}
$packagedToolsDirectory = Join-Path $packageDirectory 'tools'
New-Item -ItemType Directory -Force -Path $packagedToolsDirectory | Out-Null
foreach ($toolFile in @('toolchain.lock.json')) {
    Copy-Item -LiteralPath (Join-Path $projectRoot ('tools\' + $toolFile)) `
        -Destination $packagedToolsDirectory
}
$runtimeDirectory = Join-Path $packageDirectory 'runtime'
New-Item -ItemType Directory -Force -Path $runtimeDirectory | Out-Null
Copy-Item -LiteralPath $AutoHotkeyPath `
    -Destination (Join-Path $runtimeDirectory 'AutoHotkey64.exe')
Copy-Item -LiteralPath $licensePath `
    -Destination (Join-Path $runtimeDirectory 'license.txt')
$runtimeSourceDirectory = Join-Path $runtimeDirectory 'sources'
New-Item -ItemType Directory -Force -Path $runtimeSourceDirectory | Out-Null
Copy-Item -LiteralPath $AutoHotkeySourcePath `
    -Destination (Join-Path $runtimeSourceDirectory `
        $lock.tools.autoHotkey.sourceArchive)

$manifest = [ordered]@{
    schemaVersion = 1
    packageKind = 'portable-source-runtime'
    version = $version
    platform = 'windows-x64'
    entry = '键鼠重映射小助手.exe'
    editableSource = '键鼠重映射小助手.ahk'
    cli = '键鼠重映射小助手-CLI.ps1'
    autoHotkey = $lock.tools.autoHotkey.version
    autoHotkeySha256 = $lock.tools.autoHotkey.executableSha256
    autoHotkeySourceCommit = $lock.tools.autoHotkey.sourceCommit
    autoHotkeySourceSha256 = $lock.tools.autoHotkey.sourceSha256
    ahk2Exe = $lock.tools.ahk2Exe.version
    ahk2ExeSha256 = $lock.tools.ahk2Exe.executableSha256
    inputBackend = 'raw-input'
    requiresDriver = $false
    suppressesOriginalInput = $false
}
$manifestJson = ($manifest | ConvertTo-Json -Depth 4) + "`n"
[System.IO.File]::WriteAllText(
    (Join-Path $packageDirectory 'build-manifest.json'), $manifestJson,
    [System.Text.UTF8Encoding]::new($false))

Add-Type -AssemblyName System.IO.Compression
function New-DeterministicArchive {
    param([string]$SourceDirectory, [string]$ArchivePath)
    $stream = [System.IO.File]::Open($ArchivePath,
        [System.IO.FileMode]::CreateNew)
    try {
        $archive = [System.IO.Compression.ZipArchive]::new($stream,
            [System.IO.Compression.ZipArchiveMode]::Create, $false,
            [System.Text.Encoding]::UTF8)
        try {
            $files = [Collections.Generic.List[object]]::new()
            foreach ($file in @(Get-ChildItem -LiteralPath $SourceDirectory `
                    -Recurse -File)) {
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
            foreach ($fileEntry in $files) {
                $file = $fileEntry.File
                $relativePath = $fileEntry.RelativePath
                $entry = $archive.CreateEntry($relativePath,
                    [System.IO.Compression.CompressionLevel]::Optimal)
                $entry.LastWriteTime = [DateTimeOffset]::new(1980, 1, 1,
                    0, 0, 0, [TimeSpan]::Zero)
                $input = [System.IO.File]::OpenRead($file.FullName)
                $output = $entry.Open()
                try { $input.CopyTo($output) }
                finally { $output.Dispose(); $input.Dispose() }
            }
        } finally { $archive.Dispose() }
    } finally { $stream.Dispose() }
}

Assert-NoReparsePointTree $packageDirectory `
    'Release package directory' | Out-Null
New-DeterministicArchive $packageDirectory $zipPath
$zipHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $zipPath).Hash
$exePath = Join-Path $packageDirectory '键鼠重映射小助手.exe'
$exeHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $exePath).Hash
$checksumLines = @(
    "$zipHash  $([System.IO.Path]::GetFileName($zipPath))"
    "$exeHash  $packageName/键鼠重映射小助手.exe"
)
[System.IO.File]::WriteAllText($checksumsPath,
    ($checksumLines -join "`n") + "`n",
    [System.Text.UTF8Encoding]::new($false))
$releaseCompleted = $true

} finally {
    $rollbackErrors = [Collections.Generic.List[string]]::new()
    if ($releaseTransactionStarted -and -not $releaseCompleted) {
        foreach ($target in @($packageDirectory, $zipPath, $checksumsPath)) {
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
    if ($rollbackErrors.Count -gt 0) {
        $failureContext = if ($releaseCompleted) {
            'Release build completed but final cleanup was incomplete: '
        } else {
            'Release build failed and previous-output rollback was incomplete: '
        }
        throw ($failureContext + ($rollbackErrors -join '; ') +
            ". Recoverable backup path: $backupRoot")
    }
}

Write-Host "Release package: $zipPath"
Write-Host "Executable: $exePath"
[pscustomobject]@{
    Version = $version
    PackageDirectory = $packageDirectory
    ZipPath = $zipPath
    ExecutablePath = $exePath
    ChecksumsPath = $checksumsPath
    ZipSha256 = $zipHash
    ExecutableSha256 = $exeHash
}
