[CmdletBinding()]
param(
    [string]$ToolRoot = ""
)

$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot 'BuildPathSafety.psm1') -Force
$projectRoot = Assert-SafeBuildRoot (Split-Path -Parent $PSScriptRoot) `
    'Project root'
if (-not $ToolRoot) {
    $ToolRoot = Join-Path $projectRoot '.tools'
}
$ToolRoot = Assert-SafeBuildRoot $ToolRoot 'Tool root'
$lockPath = Join-Path $PSScriptRoot 'toolchain.lock.json'
$lock = Get-Content -LiteralPath $lockPath -Raw -Encoding UTF8 | ConvertFrom-Json
if ($lock.schemaVersion -ne 1) {
    throw 'Unsupported toolchain lock schema.'
}

New-Item -ItemType Directory -Force -Path $ToolRoot | Out-Null
Assert-SafeBuildRoot $ToolRoot 'Tool root' | Out-Null
$bootstrapLockPath = Assert-SafeBuildChild $ToolRoot `
    (Join-Path $ToolRoot '.bootstrap.lock') 'Toolchain bootstrap lock'
$bootstrapLock = $null
$lockDeadline = [DateTime]::UtcNow.AddSeconds(30)
do {
    try {
        $bootstrapLock = [IO.File]::Open($bootstrapLockPath,
            [IO.FileMode]::OpenOrCreate, [IO.FileAccess]::ReadWrite,
            [IO.FileShare]::None)
    } catch [IO.IOException] {
        if ([DateTime]::UtcNow -ge $lockDeadline) {
            throw 'Timed out waiting for another toolchain bootstrap process.'
        }
        Start-Sleep -Milliseconds 100
    }
} while ($null -eq $bootstrapLock)

try {
$cacheRoot = Assert-SafeBuildChild $ToolRoot (Join-Path $ToolRoot 'cache') `
    'Toolchain cache'
New-Item -ItemType Directory -Force -Path $cacheRoot | Out-Null
Assert-SafeBuildRoot $cacheRoot 'Toolchain cache' | Out-Null

function Assert-LockedFileName {
    param([string]$Value, [string]$Description)
    if ([string]::IsNullOrWhiteSpace($Value) -or
            [IO.Path]::GetFileName($Value) -cne $Value -or
            $Value -in @('.', '..')) {
        throw "$Description must be a plain file name."
    }
}

function Get-LockedArchive {
    param(
        [string]$FileName,
        [string]$Uri,
        [string]$ExpectedHash,
        [string]$Description
    )

    Assert-LockedFileName $FileName ($Description + ' archive')
    if ($ExpectedHash -notmatch '^[A-Fa-f0-9]{64}$') {
        throw "$Description archive has an invalid SHA-256 lock value."
    }
    $downloadUri = $null
    if (-not [Uri]::TryCreate($Uri, [UriKind]::Absolute,
            [ref]$downloadUri) -or $downloadUri.Scheme -cne 'https') {
        throw "$Description archive URL must use HTTPS."
    }
    $archivePath = Assert-SafeBuildChild $cacheRoot `
        (Join-Path $cacheRoot $FileName) ($Description + ' archive')
    if ((Test-Path -LiteralPath $archivePath) -and
            -not (Test-Path -LiteralPath $archivePath -PathType Leaf)) {
        throw "$Description archive path is not a file: $archivePath"
    }
    if (Test-Path -LiteralPath $archivePath -PathType Leaf) {
        $existingHash = (Get-FileHash -Algorithm SHA256 `
            -LiteralPath $archivePath).Hash
        if ($existingHash -cne $ExpectedHash.ToUpperInvariant()) {
            throw "$Description archive hash mismatch: $existingHash"
        }
        return $archivePath
    }

    $temporaryPath = Assert-SafeBuildChild $cacheRoot `
        (Join-Path $cacheRoot ('.download-' + [guid]::NewGuid().ToString('N'))) `
        ($Description + ' temporary download')
    try {
        Invoke-WebRequest -UseBasicParsing -Uri $downloadUri.AbsoluteUri `
            -OutFile $temporaryPath
        $actualHash = (Get-FileHash -Algorithm SHA256 `
            -LiteralPath $temporaryPath).Hash
        if ($actualHash -cne $ExpectedHash.ToUpperInvariant()) {
            throw "$Description archive hash mismatch: $actualHash"
        }
        Move-Item -LiteralPath $temporaryPath -Destination $archivePath
    } finally {
        if (Test-Path -LiteralPath $temporaryPath) {
            Remove-Item -LiteralPath $temporaryPath -Force
        }
    }
    return $archivePath
}

function Resolve-LockedTool {
    param([Parameter(Mandatory = $true)][string]$Name)

    $definition = $lock.tools.PSObject.Properties[$Name].Value
    if ([string]$definition.version -notmatch '^[A-Za-z0-9._-]+$') {
        throw "$Name has an invalid locked version."
    }
    Assert-LockedFileName ([string]$definition.executable) `
        "$Name executable"
    $targetDirectory = Assert-SafeBuildChild $ToolRoot `
        (Join-Path $ToolRoot ("{0}-{1}" -f $Name, $definition.version)) `
        "$Name install directory"
    if (Test-Path -LiteralPath $targetDirectory) {
        Assert-SafeBuildRoot $targetDirectory `
            "$Name install directory" | Out-Null
    }
    $targetExecutable = Join-Path $targetDirectory $definition.executable
    if (Test-Path -LiteralPath $targetExecutable -PathType Leaf) {
        Assert-NoReparsePointTree $targetDirectory `
            "$Name install directory" | Out-Null
        $existingHash = (Get-FileHash -Algorithm SHA256 `
            -LiteralPath $targetExecutable).Hash
        if ($existingHash -eq $definition.executableSha256) {
            return $targetExecutable
        }
        throw "$Name exists but its executable hash does not match the lock file."
    }

    if (Test-Path -LiteralPath $targetDirectory) {
        Assert-SafeBuildChild $ToolRoot $targetDirectory `
            "$Name incomplete install directory" | Out-Null
        Remove-Item -LiteralPath $targetDirectory -Recurse -Force
    }
    $archivePath = Get-LockedArchive ([string]$definition.archive) `
        ([string]$definition.url) ([string]$definition.sha256) $Name

    $stagingDirectory = Assert-SafeBuildChild $ToolRoot `
        (Join-Path $ToolRoot ('.extract-{0}-{1}' -f $Name,
            [guid]::NewGuid().ToString('N'))) "$Name extraction directory"
    $installDirectory = Assert-SafeBuildChild $ToolRoot `
        (Join-Path $ToolRoot ('.install-{0}-{1}' -f $Name,
            [guid]::NewGuid().ToString('N'))) "$Name staged install directory"
    try {
        New-Item -ItemType Directory -Path $stagingDirectory | Out-Null
        Expand-Archive -LiteralPath $archivePath -DestinationPath $stagingDirectory
        Assert-NoReparsePointTree $stagingDirectory `
            "$Name extracted archive" | Out-Null
        $matches = @(Get-ChildItem -LiteralPath $stagingDirectory -Recurse -File |
            Where-Object { $_.Name -ceq $definition.executable })
        if ($matches.Count -ne 1) {
            throw "$Name archive must contain exactly one $($definition.executable)."
        }
        $sourceDirectory = $matches[0].Directory.FullName
        if (Test-BuildPathEqual $stagingDirectory $sourceDirectory) {
            Assert-SafeBuildRoot $sourceDirectory `
                "$Name extracted source directory" | Out-Null
        } else {
            Assert-SafeBuildChild $stagingDirectory $sourceDirectory `
                "$Name extracted source directory" | Out-Null
        }
        New-Item -ItemType Directory -Path $installDirectory | Out-Null
        foreach ($sourceItem in @(Get-ChildItem -LiteralPath $sourceDirectory `
                -Force)) {
            Copy-Item -LiteralPath $sourceItem.FullName `
                -Destination $installDirectory -Recurse -Force
        }
        $stagedExecutable = Join-Path $installDirectory $definition.executable
        if (-not (Test-Path -LiteralPath $stagedExecutable -PathType Leaf)) {
            throw "$Name staged install omitted its executable."
        }
        $stagedHash = (Get-FileHash -Algorithm SHA256 `
            -LiteralPath $stagedExecutable).Hash
        if ($stagedHash -cne
                ([string]$definition.executableSha256).ToUpperInvariant()) {
            throw "$Name executable hash mismatch after extraction: $stagedHash"
        }
        Move-Item -LiteralPath $installDirectory -Destination $targetDirectory
    } finally {
        if (Test-Path -LiteralPath $stagingDirectory) {
            Remove-Item -LiteralPath $stagingDirectory -Recurse -Force
        }
        if (Test-Path -LiteralPath $installDirectory) {
            Remove-Item -LiteralPath $installDirectory -Recurse -Force
        }
    }

    $actualHash = (Get-FileHash -Algorithm SHA256 `
        -LiteralPath $targetExecutable).Hash
    if ($actualHash -ne $definition.executableSha256) {
        throw "$Name executable hash mismatch after extraction: $actualHash"
    }
    return $targetExecutable
}

$autoHotkeyPath = Resolve-LockedTool 'autoHotkey'
$compilerPath = Resolve-LockedTool 'ahk2Exe'
$licensePath = Join-Path (Split-Path -Parent $autoHotkeyPath) `
    $lock.tools.autoHotkey.licenseFile
if (-not (Test-Path -LiteralPath $licensePath -PathType Leaf)) {
    throw 'AutoHotkey license is missing from the resolved runtime.'
}
$licenseHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $licensePath).Hash
if ($licenseHash -ne $lock.tools.autoHotkey.licenseSha256) {
    throw "AutoHotkey license hash mismatch: $licenseHash"
}
$sourceArchivePath = Get-LockedArchive `
    ([string]$lock.tools.autoHotkey.sourceArchive) `
    ([string]$lock.tools.autoHotkey.sourceUrl) `
    ([string]$lock.tools.autoHotkey.sourceSha256) 'AutoHotkey source'

[pscustomobject]@{
    AutoHotkeyPath = $autoHotkeyPath
    CompilerPath = $compilerPath
    LicensePath = $licensePath
    AutoHotkeySourcePath = $sourceArchivePath
    LockPath = $lockPath
}
} finally {
    if ($null -ne $bootstrapLock) { $bootstrapLock.Dispose() }
}
