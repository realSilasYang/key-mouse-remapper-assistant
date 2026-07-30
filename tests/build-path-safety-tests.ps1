[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version 2.0
$projectRoot = Split-Path -Parent $PSScriptRoot
Import-Module (Join-Path $projectRoot 'tools\BuildPathSafety.psm1') -Force
$testRoot = Join-Path $projectRoot `
    ('.build\path-safety-' + [guid]::NewGuid().ToString('N'))
$outsideRoot = Join-Path $projectRoot `
    ('.build\path-safety-outside-' + [guid]::NewGuid().ToString('N'))
$junctionPath = Join-Path $testRoot 'nested\redirect'

function Assert-Fails {
    param([scriptblock]$Action, [string]$Expected, [string]$Description)
    try {
        & $Action
        throw "Expected failure did not occur: $Description"
    } catch {
        if ($_.Exception.Message -like 'Expected failure did not occur:*') {
            throw
        }
        if ($_.Exception.Message -notlike $Expected) {
            throw "Unexpected failure for $Description`: $($_.Exception.Message)"
        }
    }
}

try {
    New-Item -ItemType Directory -Force -Path `
        (Join-Path $testRoot 'nested') | Out-Null
    New-Item -ItemType Directory -Force -Path $outsideRoot | Out-Null

    $safeRoot = Assert-SafeBuildRoot $testRoot 'Test root'
    $safeChild = Assert-SafeBuildChild $safeRoot `
        (Join-Path $safeRoot 'nested\artifact.bin') 'Test artifact'
    if (-not (Test-BuildPathWithin $safeRoot $safeChild)) {
        throw 'A normal strict child was rejected.'
    }
    Assert-Fails { Assert-SafeBuildRoot '   ' 'Whitespace root' } `
        '*cannot be empty or whitespace*' 'whitespace root'
    Assert-Fails {
        Assert-SafeBuildRoot ([IO.Path]::GetPathRoot($projectRoot)) `
            'Volume root'
    } '*cannot be a volume or share root*' 'volume root'
    Assert-Fails {
        Assert-SafeBuildChild $safeRoot (Split-Path -Parent $safeRoot) `
            'Escaped path'
    } '*must be a strict child*' 'parent traversal'

    $fileRoot = Join-Path $testRoot 'not-a-directory'
    [IO.File]::WriteAllText($fileRoot, 'file')
    Assert-Fails { Assert-SafeBuildRoot $fileRoot 'File root' } `
        '*is not a directory*' 'file used as directory root'

    New-Item -ItemType Junction -Path $junctionPath -Target $outsideRoot |
        Out-Null
    Assert-Fails { Assert-SafeBuildRoot $junctionPath 'Junction root' } `
        '*traverses a reparse point*' 'junction root'
    Assert-Fails { Assert-SafeBuildChild $safeRoot `
            (Join-Path $junctionPath 'escaped.bin') 'Junction child' } `
        '*traverses a reparse point*' 'child below a junction'
    Assert-Fails { Assert-NoReparsePointTree $safeRoot 'Junction tree' } `
        '*contains a reparse point*' 'tree containing a junction'

    Write-Host 'PASS build-path-safety-tests.ps1'
} finally {
    if (Test-Path -LiteralPath $junctionPath) {
        Remove-Item -LiteralPath $junctionPath -Force
    }
    foreach ($path in @($testRoot, $outsideRoot)) {
        if (Test-Path -LiteralPath $path) {
            Remove-Item -LiteralPath $path -Recurse -Force
        }
    }
}
