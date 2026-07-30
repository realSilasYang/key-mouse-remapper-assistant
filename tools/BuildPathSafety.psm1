Set-StrictMode -Version 2.0

function Get-NormalizedBuildPath {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [string]$Description = 'Path'
    )

    if ([string]::IsNullOrWhiteSpace($Path)) {
        throw "$Description cannot be empty or whitespace."
    }
    try {
        return [IO.Path]::GetFullPath($Path)
    } catch {
        throw "$Description is invalid: $Path"
    }
}

function Test-BuildPathEqual {
    param(
        [Parameter(Mandatory = $true)][string]$Left,
        [Parameter(Mandatory = $true)][string]$Right
    )

    $leftPath = (Get-NormalizedBuildPath $Left).TrimEnd('\', '/')
    $rightPath = (Get-NormalizedBuildPath $Right).TrimEnd('\', '/')
    return $leftPath.Equals($rightPath,
        [StringComparison]::OrdinalIgnoreCase)
}

function Test-BuildPathWithin {
    param(
        [Parameter(Mandatory = $true)][string]$Root,
        [Parameter(Mandatory = $true)][string]$Path
    )

    $rootPath = (Get-NormalizedBuildPath $Root).TrimEnd('\', '/')
    $candidate = Get-NormalizedBuildPath $Path
    $prefix = $rootPath + [IO.Path]::DirectorySeparatorChar
    return $candidate.StartsWith($prefix,
        [StringComparison]::OrdinalIgnoreCase)
}

function Assert-NoReparsePointInPath {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [string]$Description = 'Path'
    )

    $fullPath = Get-NormalizedBuildPath $Path $Description
    $cursor = $fullPath
    while ($cursor -and -not (Test-Path -LiteralPath $cursor)) {
        $parent = Split-Path -Parent $cursor
        if (-not $parent -or (Test-BuildPathEqual $parent $cursor)) {
            $cursor = $null
        } else {
            $cursor = $parent
        }
    }
    while ($cursor) {
        $item = Get-Item -LiteralPath $cursor -Force -ErrorAction Stop
        if (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) {
            throw "$Description traverses a reparse point: $($item.FullName)"
        }
        $parent = Split-Path -Parent $cursor
        if (-not $parent -or (Test-BuildPathEqual $parent $cursor)) { break }
        $cursor = $parent
    }
    return $fullPath
}

function Assert-SafeBuildRoot {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [string]$Description = 'Build directory'
    )

    $fullPath = Get-NormalizedBuildPath $Path $Description
    $pathRoot = [IO.Path]::GetPathRoot($fullPath)
    if (-not $pathRoot -or (Test-BuildPathEqual $fullPath $pathRoot)) {
        throw "$Description cannot be a volume or share root: $fullPath"
    }
    if ((Test-Path -LiteralPath $fullPath) -and
            -not (Test-Path -LiteralPath $fullPath -PathType Container)) {
        throw "$Description is not a directory: $fullPath"
    }
    return Assert-NoReparsePointInPath $fullPath $Description
}

function Assert-SafeBuildChild {
    param(
        [Parameter(Mandatory = $true)][string]$Root,
        [Parameter(Mandatory = $true)][string]$Path,
        [string]$Description = 'Build path'
    )

    $safeRoot = Assert-SafeBuildRoot $Root ($Description + ' root')
    $fullPath = Get-NormalizedBuildPath $Path $Description
    if (-not (Test-BuildPathWithin $safeRoot $fullPath)) {
        throw "$Description must be a strict child of $safeRoot`: $fullPath"
    }
    return Assert-NoReparsePointInPath $fullPath $Description
}

function Assert-NoReparsePointTree {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [string]$Description = 'Source tree'
    )

    $root = Assert-NoReparsePointInPath $Path $Description
    if (-not (Test-Path -LiteralPath $root -PathType Container)) {
        throw "$Description is not a directory: $root"
    }
    $pending = New-Object 'Collections.Generic.Stack[string]'
    $pending.Push($root)
    while ($pending.Count -gt 0) {
        $directory = $pending.Pop()
        foreach ($item in @(Get-ChildItem -LiteralPath $directory -Force)) {
            if (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) {
                throw "$Description contains a reparse point: $($item.FullName)"
            }
            if ($item.PSIsContainer) { $pending.Push($item.FullName) }
        }
    }
    return $root
}

Export-ModuleMember -Function Get-NormalizedBuildPath, Test-BuildPathEqual,
    Test-BuildPathWithin, Assert-NoReparsePointInPath, Assert-SafeBuildRoot,
    Assert-SafeBuildChild, Assert-NoReparsePointTree
