[CmdletBinding()]
param(
    [switch]$IncludeDist
)

$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot 'BuildPathSafety.psm1') -Force
$projectRoot = Assert-SafeBuildRoot (Split-Path -Parent $PSScriptRoot) `
    'Project root'
$relativeTargets = @(
    '.build'
)
if ($IncludeDist) {
    $relativeTargets += 'dist'
}

foreach ($relativeTarget in $relativeTargets) {
    $target = Assert-SafeBuildChild $projectRoot `
        (Join-Path $projectRoot $relativeTarget) 'Clean target'
    if (Test-Path -LiteralPath $target) {
        Assert-NoReparsePointInPath $target 'Clean target' | Out-Null
        Remove-Item -LiteralPath $target -Recurse -Force
        Write-Host "Removed $target"
    }
}
