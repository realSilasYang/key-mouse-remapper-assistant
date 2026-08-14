$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$projectRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$helperPath = Join-Path $projectRoot 'runtime\application-update.ps1'
. $helperPath -Mode Check -UiLanguage en-US

function Assert-UpdateTest {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) {
        throw $Message
    }
}

$testRoot = Join-Path $env:TEMP `
    ('KeyMouseRemapperUpdateFunctionTest-' + [Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $testRoot | Out-Null
try {
    $sourcePath = Join-Path $testRoot 'old.ahk'
    $destinationPath = Join-Path $testRoot 'new.ahk'
    $start = $script:RemappingRegionStart
    $end = $script:RemappingRegionEnd
    $oldText = "old-prefix`r`n$start`r`n; old-user-rule`r`n$end`r`nold-suffix`r`n"
    $newText = "new-prefix`n$start`n; new-default-rule`n$end`nnew-suffix`n"
    [System.IO.File]::WriteAllText($sourcePath, $oldText,
        [System.Text.UTF8Encoding]::new($false))
    [System.IO.File]::WriteAllText($destinationPath, $newText,
        [System.Text.UTF8Encoding]::new($false))

    Merge-RemappingRegion -SourcePath $sourcePath `
        -DestinationPath $destinationPath
    $merged = [System.IO.File]::ReadAllText($destinationPath)
    Assert-UpdateTest ($merged.Contains('new-prefix')) `
        'Mapping migration replaced new source code outside the managed region.'
    Assert-UpdateTest ($merged.Contains('; old-user-rule')) `
        'Mapping migration did not preserve the existing remapping region.'
    Assert-UpdateTest (-not $merged.Contains('; new-default-rule')) `
        'Mapping migration retained the replacement package mapping region.'
    Assert-UpdateTest ($merged.Contains('new-suffix')) `
        'Mapping migration replaced the new source suffix.'

    $invalidPath = Join-Path $testRoot 'invalid.ahk'
    [System.IO.File]::WriteAllText($invalidPath,
        "$start`n$start`n$end`n", [System.Text.UTF8Encoding]::new($false))
    $rejected = $false
    try {
        [void](Get-RemappingRegionParts `
            ([System.IO.File]::ReadAllText($invalidPath)))
    } catch {
        $rejected = $true
    }
    Assert-UpdateTest $rejected `
        'Duplicate remapping source markers were not rejected.'

    Assert-UpdateTest ((ConvertTo-CanonicalManagedRelativePath `
            'app/Core.ahk') -ceq 'app\Core.ahk') `
        'Forward-slash update paths were not normalized.'
    foreach ($unsafeManagedPath in @(
            'app\.\Core.ahk', 'app\..\Core.ahk', 'app\\Core.ahk',
            'app\', 'app\Core.ahk.', 'NUL.txt', 'settings.ini')) {
        $rejected = $false
        try {
            [void](ConvertTo-CanonicalManagedRelativePath $unsafeManagedPath)
        } catch {
            $rejected = $true
        }
        Assert-UpdateTest $rejected `
            "Unsafe managed update path was accepted: $unsafeManagedPath"
    }
    $rejected = $false
    try {
        Assert-NoOverlappingPaths @('app\Core.ahk', 'APP\CORE.AHK')
    } catch {
        $rejected = $true
    }
    Assert-UpdateTest $rejected `
        'Case-insensitive duplicate managed paths were not rejected.'

    $reparseTarget = Join-Path $testRoot 'reparse-target'
    $reparsePath = Join-Path $testRoot 'managed-link'
    New-Item -ItemType Directory -Path $reparseTarget | Out-Null
    New-Item -ItemType Junction -Path $reparsePath `
        -Target $reparseTarget | Out-Null
    $rejected = $false
    try {
        [void](Resolve-PathUnderRoot $testRoot 'managed-link\outside.txt')
    } catch {
        $rejected = $true
    }
    Assert-UpdateTest $rejected `
        'Managed path traversal through a junction was not rejected.'

    $archiveSource = Join-Path $testRoot 'archive-source'
    $archiveStage = Join-Path $testRoot 'archive-stage'
    $safeArchive = Join-Path $testRoot 'safe.zip'
    New-Item -ItemType Directory -Path $archiveSource, $archiveStage |
        Out-Null
    [System.IO.File]::WriteAllText((Join-Path $archiveSource 'entry.txt'),
        'bounded archive content', [System.Text.UTF8Encoding]::new($false))
    Compress-Archive -Path (Join-Path $archiveSource '*') `
        -DestinationPath $safeArchive
    Assert-SafeUpdateArchive -ArchivePath $safeArchive `
        -DestinationRoot $archiveStage -MaximumExpandedBytes 1024
    $rejected = $false
    try {
        Assert-SafeUpdateArchive -ArchivePath $safeArchive `
            -DestinationRoot $archiveStage -MaximumExpandedBytes 4
    } catch {
        $rejected = $true
    }
    Assert-UpdateTest $rejected `
        'An archive exceeding the expanded-size limit was accepted.'

    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $unsafeArchive = Join-Path $testRoot 'unsafe.zip'
    $zip = [System.IO.Compression.ZipFile]::Open($unsafeArchive,
        [System.IO.Compression.ZipArchiveMode]::Create)
    try {
        [void]$zip.CreateEntry('../outside.txt')
    } finally {
        $zip.Dispose()
    }
    $rejected = $false
    try {
        Assert-SafeUpdateArchive -ArchivePath $unsafeArchive `
            -DestinationRoot $archiveStage
    } catch {
        $rejected = $true
    }
    Assert-UpdateTest $rejected `
        'An archive containing a traversal path was accepted.'

    if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
        throw 'Git is required for the source-update transaction tests.'
    }
    $gitRoot = Join-Path $testRoot 'git-source'
    New-Item -ItemType Directory -Path $gitRoot | Out-Null
    Invoke-Git @('-C', $gitRoot, 'init', '--quiet') | Out-Null
    Invoke-Git @('-C', $gitRoot, 'config', 'user.name', 'Update Test') |
        Out-Null
    Invoke-Git @('-C', $gitRoot, 'config', 'user.email',
        'update-test@example.invalid') | Out-Null
    $gitEntry = Join-Path $gitRoot 'entry.ahk'
    $otherTracked = Join-Path $gitRoot 'other.txt'
    $baseEntry = "prefix`n$start`n; base mapping`n$end`nsuffix`n"
    $mappedEntry = "prefix`n$start`n; user mapping`n$end`nsuffix`n"
    [System.IO.File]::WriteAllText($gitEntry, $baseEntry,
        [System.Text.UTF8Encoding]::new($false))
    [System.IO.File]::WriteAllText($otherTracked, 'base',
        [System.Text.UTF8Encoding]::new($false))
    Invoke-Git @('-C', $gitRoot, 'add', '--', 'entry.ahk', 'other.txt') |
        Out-Null
    Invoke-Git @('-C', $gitRoot, 'commit', '--quiet', '-m', 'base') |
        Out-Null
    $previousCommit = ([string](Invoke-Git @('-C', $gitRoot,
        'rev-parse', 'HEAD')).Output[0]).Trim()

    [System.IO.File]::WriteAllText($gitEntry, $mappedEntry,
        [System.Text.UTF8Encoding]::new($false))
    $gitTransaction = Prepare-GitSourceTransaction -Root $gitRoot `
        -PreviousCommit $previousCommit -EntryRelativePath 'entry.ahk' `
        -EditablePath $gitEntry -BackupDirectory $testRoot
    Assert-UpdateTest (([System.IO.File]::ReadAllText($gitEntry)).Contains(
            '; base mapping')) `
        'A mapping-only Git entry was not prepared from HEAD.'
    Assert-UpdateTest ($gitTransaction.MappingRegionBody.Contains(
            '; user mapping')) `
        'The mapping-only Git transaction did not retain the user mapping.'
    $rollbackError = $null
    try { throw 'simulated rollback' } catch { $rollbackError = $_ }
    Restore-GitSourceTransaction $gitTransaction $rollbackError
    Assert-UpdateTest ([System.IO.File]::ReadAllText($gitEntry) -ceq
            $mappedEntry) `
        'Rolling back a prepared Git source did not restore the user mapping.'

    $outsideModifiedEntry = "changed-prefix`n$start`n; user mapping`n$end`nsuffix`n"
    [System.IO.File]::WriteAllText($gitEntry, $outsideModifiedEntry,
        [System.Text.UTF8Encoding]::new($false))
    $rejected = $false
    try {
        [void](Prepare-GitSourceTransaction -Root $gitRoot `
            -PreviousCommit $previousCommit -EntryRelativePath 'entry.ahk' `
            -EditablePath $gitEntry -BackupDirectory $testRoot)
    } catch {
        $rejected = $true
    }
    Assert-UpdateTest $rejected `
        'A Git entry modified outside the managed mapping region was accepted.'
    Assert-UpdateTest ([System.IO.File]::ReadAllText($gitEntry) -ceq
            $outsideModifiedEntry) `
        'Rejecting an outside-region edit did not restore the original entry.'

    [System.IO.File]::WriteAllText($gitEntry, $mappedEntry,
        [System.Text.UTF8Encoding]::new($false))
    [System.IO.File]::WriteAllText($otherTracked, 'locally modified',
        [System.Text.UTF8Encoding]::new($false))
    $rejected = $false
    try {
        [void](Prepare-GitSourceTransaction -Root $gitRoot `
            -PreviousCommit $previousCommit -EntryRelativePath 'entry.ahk' `
            -EditablePath $gitEntry -BackupDirectory $testRoot)
    } catch {
        $rejected = $true
    }
    Assert-UpdateTest $rejected `
        'A Git update with another modified tracked file was accepted.'
    Assert-UpdateTest ([System.IO.File]::ReadAllText($gitEntry) -ceq
            $mappedEntry) `
        'Rejecting another tracked edit did not restore the mapping entry.'
    Assert-UpdateTest ([System.IO.File]::ReadAllText($otherTracked) -ceq
            'locally modified') `
        'Rejecting another tracked edit destroyed that local modification.'
} finally {
    if (Test-Path -LiteralPath $testRoot) {
        Remove-Item -LiteralPath $testRoot -Recurse -Force
    }
}

Write-Host 'PASS application-update-tests.ps1'
