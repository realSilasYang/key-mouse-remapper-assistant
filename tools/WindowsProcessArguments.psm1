function ConvertTo-WindowsProcessArgument {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [AllowEmptyString()]
        [string]$Argument
    )

    if ($Argument.Length -gt 0 -and $Argument -notmatch '[\s"]') {
        return $Argument
    }

    $builder = [System.Text.StringBuilder]::new()
    [void]$builder.Append([char]'"')
    $backslashCount = 0
    foreach ($character in $Argument.ToCharArray()) {
        if ($character -eq [char]'\') {
            $backslashCount++
            continue
        }
        if ($character -eq [char]'"') {
            [void]$builder.Append([char]'\', 2 * $backslashCount + 1)
            [void]$builder.Append([char]'"')
            $backslashCount = 0
            continue
        }
        if ($backslashCount) {
            [void]$builder.Append([char]'\', $backslashCount)
            $backslashCount = 0
        }
        [void]$builder.Append($character)
    }
    if ($backslashCount) {
        [void]$builder.Append([char]'\', 2 * $backslashCount)
    }
    [void]$builder.Append([char]'"')
    return $builder.ToString()
}

function Join-WindowsProcessArguments {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [AllowEmptyCollection()]
        [object[]]$ArgumentList
    )

    return (($ArgumentList | ForEach-Object {
        ConvertTo-WindowsProcessArgument -Argument ([string]$_)
    }) -join ' ')
}

Export-ModuleMember -Function ConvertTo-WindowsProcessArgument,
    Join-WindowsProcessArguments
