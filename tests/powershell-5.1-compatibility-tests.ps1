[CmdletBinding()]
param([switch]$ParseOnly)

$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot

if (-not $ParseOnly) {
    $windowsPowerShell = Join-Path $env:SystemRoot `
        'System32\WindowsPowerShell\v1.0\powershell.exe'
    if (-not (Test-Path -LiteralPath $windowsPowerShell -PathType Leaf)) {
        throw 'Windows PowerShell 5.1 is required for compatibility validation.'
    }
    & $windowsPowerShell -NoProfile -ExecutionPolicy Bypass `
        -File $PSCommandPath -ParseOnly
    if ($LASTEXITCODE -ne 0) {
        throw "PowerShell 5.1 compatibility validation failed: $LASTEXITCODE"
    }
    Write-Host 'PASS powershell-5.1-compatibility-tests.ps1'
    return
}

if ($PSVersionTable.PSVersion.Major -ne 5 -or
        $PSVersionTable.PSVersion.Minor -ne 1) {
    throw "Expected Windows PowerShell 5.1, got $($PSVersionTable.PSVersion)."
}

$excludedPrefixes = @('.build', '.tools', 'dist') | ForEach-Object {
    [IO.Path]::GetFullPath((Join-Path $projectRoot $_)).TrimEnd('\') + '\'
}
$scripts = Get-ChildItem -LiteralPath $projectRoot -Recurse -File |
    Where-Object {
        $candidate = $_
        $candidate.Extension -in @('.ps1', '.psm1') -and
        -not @($excludedPrefixes | Where-Object {
            $candidate.FullName.StartsWith($_,
                [StringComparison]::OrdinalIgnoreCase)
        }).Count
    }
$failures = @()
foreach ($script in $scripts) {
    $tokens = $null
    $parseErrors = $null
    [Management.Automation.Language.Parser]::ParseFile($script.FullName,
        [ref]$tokens, [ref]$parseErrors) | Out-Null
    foreach ($parseError in @($parseErrors)) {
        $relativePath = $script.FullName.Substring($projectRoot.Length + 1)
        $failures += "${relativePath}:$($parseError.Extent.StartLineNumber): " +
            $parseError.Message
    }
}
if ($failures.Count) {
    throw "PowerShell 5.1 parse failures:`n$($failures -join "`n")"
}
