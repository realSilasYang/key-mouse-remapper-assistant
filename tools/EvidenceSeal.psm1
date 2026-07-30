Set-StrictMode -Version 2.0
Add-Type -AssemblyName System.Security

$script:EvidenceSealEntropy = [Text.Encoding]::UTF8.GetBytes(
    'KeyMouseRemapperAssistant|EvidenceSeal|v1')

function Test-EvidenceAncestorReference {
    param($Value, [Collections.Generic.List[object]]$Ancestors)

    foreach ($ancestor in $Ancestors) {
        if ([object]::ReferenceEquals($ancestor, $Value)) { return $true }
    }
    return $false
}

function ConvertTo-EvidenceCanonicalJson {
    param(
        $Value,
        [int]$Depth = 0,
        [ref]$NodeCount = ([ref]0),
        [Collections.Generic.List[object]]$Ancestors = $null
    )

    if ($Depth -gt 64) { throw 'Evidence exceeds the canonical depth limit.' }
    if ($null -eq $Ancestors) {
        $Ancestors = [Collections.Generic.List[object]]::new()
    }
    $NodeCount.Value++
    if ($NodeCount.Value -gt 200000) {
        throw 'Evidence exceeds the canonical node limit.'
    }
    if ($null -eq $Value) { return 'null' }
    if ($Value -is [DateTime]) {
        return ConvertTo-Json -InputObject `
            $Value.ToUniversalTime().ToString('o') -Compress
    }
    if ($Value -is [DateTimeOffset]) {
        return ConvertTo-Json -InputObject `
            $Value.ToUniversalTime().ToString('o') -Compress
    }
    if ($Value -is [single] -and ([single]::IsNaN($Value) -or
            [single]::IsInfinity($Value))) {
        throw 'Evidence contains a non-finite floating-point value.'
    }
    if ($Value -is [double] -and ([double]::IsNaN($Value) -or
            [double]::IsInfinity($Value))) {
        throw 'Evidence contains a non-finite floating-point value.'
    }
    if ($Value -is [string] -or $Value -is [char] -or
            $Value -is [bool] -or $Value -is [byte] -or
            $Value -is [sbyte] -or $Value -is [int16] -or
            $Value -is [uint16] -or $Value -is [int32] -or
            $Value -is [uint32] -or $Value -is [int64] -or
            $Value -is [uint64] -or $Value -is [single] -or
            $Value -is [double] -or $Value -is [decimal]) {
        return ConvertTo-Json -InputObject $Value -Compress
    }
    if ($Value -is [Collections.IDictionary]) {
        if (Test-EvidenceAncestorReference $Value $Ancestors) {
            throw 'Evidence contains a cyclic object graph.'
        }
        $Ancestors.Add($Value)
        try {
            $values = [Collections.Generic.Dictionary[string, object]]::new(
                [StringComparer]::Ordinal)
            foreach ($rawKey in $Value.Keys) {
                if ($rawKey -isnot [string]) {
                    throw 'Evidence dictionary keys must be strings.'
                }
                $key = [string]$rawKey
                if ($values.ContainsKey($key)) {
                    throw "Evidence contains a duplicate dictionary key: $key"
                }
                $values.Add($key, $Value[$rawKey])
            }
            [string[]]$keys = @($values.Keys)
            [Array]::Sort($keys, [StringComparer]::Ordinal)
            $parts = [Collections.Generic.List[string]]::new()
            foreach ($key in $keys) {
                if ($Depth -eq 0 -and $key -ceq 'seal') { continue }
                $encodedKey = ConvertTo-Json -InputObject $key -Compress
                $encodedValue = ConvertTo-EvidenceCanonicalJson $values[$key] `
                    ($Depth + 1) $NodeCount $Ancestors
                $parts.Add($encodedKey + ':' + $encodedValue)
            }
            return '{' + ($parts -join ',') + '}'
        } finally {
            $Ancestors.RemoveAt($Ancestors.Count - 1)
        }
    }
    if ($Value -is [Collections.IEnumerable] -and
            $Value -isnot [string]) {
        if (Test-EvidenceAncestorReference $Value $Ancestors) {
            throw 'Evidence contains a cyclic object graph.'
        }
        $Ancestors.Add($Value)
        try {
            $parts = [Collections.Generic.List[string]]::new()
            foreach ($item in $Value) {
                $parts.Add((ConvertTo-EvidenceCanonicalJson $item `
                    ($Depth + 1) $NodeCount $Ancestors))
            }
            return '[' + ($parts -join ',') + ']'
        } finally {
            $Ancestors.RemoveAt($Ancestors.Count - 1)
        }
    }
    if ($Value.GetType().FullName -cne
            'System.Management.Automation.PSCustomObject') {
        throw ('Evidence contains an unsupported value type: ' +
            $Value.GetType().FullName)
    }
    if (Test-EvidenceAncestorReference $Value $Ancestors) {
        throw 'Evidence contains a cyclic object graph.'
    }
    $Ancestors.Add($Value)
    try {
    $properties = @($Value.PSObject.Properties |
        Where-Object MemberType -eq 'NoteProperty')
    if ($properties.Count -ne @($Value.PSObject.Properties).Count) {
        throw 'Evidence objects may contain only data properties.'
    }
    [string[]]$names = @($properties | ForEach-Object Name)
    [Array]::Sort($names, [StringComparer]::Ordinal)
    $parts = [Collections.Generic.List[string]]::new()
    foreach ($name in $names) {
        if ($Depth -eq 0 -and $name -ceq 'seal') { continue }
        $encodedName = ConvertTo-Json -InputObject $name -Compress
        $encodedValue = ConvertTo-EvidenceCanonicalJson `
            $Value.PSObject.Properties[$name].Value ($Depth + 1) $NodeCount `
            $Ancestors
        $parts.Add($encodedName + ':' + $encodedValue)
    }
    return '{' + ($parts -join ',') + '}'
    } finally {
        $Ancestors.RemoveAt($Ancestors.Count - 1)
    }
}

function Get-EvidenceTextSha256 {
    param([Parameter(Mandatory = $true)][string]$Text)

    $sha = [Security.Cryptography.SHA256]::Create()
    try {
        $bytes = [Text.Encoding]::UTF8.GetBytes($Text)
        return (($sha.ComputeHash($bytes) | ForEach-Object {
            $_.ToString('x2')
        }) -join '').ToUpperInvariant()
    } finally { $sha.Dispose() }
}

function Get-EvidenceDocumentSha256 {
    param([Parameter(Mandatory = $true)]$Evidence)

    $nodes = 0
    return Get-EvidenceTextSha256 `
        (ConvertTo-EvidenceCanonicalJson $Evidence 0 ([ref]$nodes))
}

function Get-EvidenceMachineId {
    $machineGuid = [string](Get-ItemPropertyValue -LiteralPath `
        'HKLM:\SOFTWARE\Microsoft\Cryptography' -Name MachineGuid)
    $systemUuid = ''
    try {
        $systemUuid = [string](Get-CimInstance Win32_ComputerSystemProduct).UUID
    } catch {}
    return Get-EvidenceTextSha256 `
        ('KeyMouseRemapperAssistantEvidenceSeal|v1|' + $machineGuid + '|' + $systemUuid)
}

function Get-EvidenceUserSid {
    return [Security.Principal.WindowsIdentity]::GetCurrent().User.Value
}

function Assert-EvidenceExactProperties {
    param($Value, [string[]]$Expected, [string]$Description)

    if ($null -eq $Value) { throw "$Description is missing." }
    $actual = if ($Value -is [Collections.IDictionary]) {
        foreach ($key in $Value.Keys) {
            if ($key -isnot [string]) {
                throw "$Description contains a non-string field name."
            }
        }
        @($Value.Keys | ForEach-Object { [string]$_ } | Sort-Object)
    } else {
        @($Value.PSObject.Properties.Name | Sort-Object)
    }
    $wanted = @($Expected | Sort-Object)
    if (($actual -join "`n") -cne ($wanted -join "`n")) {
        throw "$Description contains missing or unsupported fields."
    }
}

function Get-EvidenceExactMember {
    param($Value, [string]$Name, [string]$Description)

    if ($null -eq $Value) { throw "$Description is missing." }
    if ($Value -is [Collections.IDictionary]) {
        $matches = @($Value.Keys | Where-Object {
            $_ -is [string] -and [string]$_ -ceq $Name
        })
        if ($matches.Count -ne 1) {
            throw "$Description.$Name is missing."
        }
        return $Value[$matches[0]]
    }
    $matches = @($Value.PSObject.Properties | Where-Object {
        $_.Name -ceq $Name
    })
    if ($matches.Count -ne 1) { throw "$Description.$Name is missing." }
    return $matches[0].Value
}

function Test-EvidenceIntegerEqual {
    param($Value, [int]$Expected)

    if ($Value -isnot [int] -and $Value -isnot [long]) { return $false }
    return [long]$Value -eq [long]$Expected
}

function Add-EvidenceSeal {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]$Evidence,
        [Parameter(Mandatory = $true)][ValidateSet(
            'desktop-context', 'physical-device')]
        [string]$Scope,
        [Parameter(Mandatory = $true)][int]$CollectorProcessId
    )

    if ($CollectorProcessId -le 0) {
        throw 'Evidence collector process ID must be positive.'
    }
    $rootNames = if ($Evidence -is [Collections.IDictionary]) {
        @($Evidence.Keys | Where-Object { $_ -is [string] } |
            ForEach-Object { [string]$_ })
    } elseif ($null -ne $Evidence) {
        @($Evidence.PSObject.Properties | ForEach-Object Name)
    } else { @() }
    if (@($rootNames | Where-Object {
            $_ -ieq 'seal' -and $_ -cne 'seal'
        }).Count -gt 0) {
        throw 'Evidence contains a differently-cased root seal field.'
    }
    $payload = [ordered]@{
        schema = 1
        scope = $Scope
        machine_id = Get-EvidenceMachineId
        user_sid = Get-EvidenceUserSid
        collector_process_id = $CollectorProcessId
        sealed_utc = [DateTime]::UtcNow.ToString("yyyyMMdd'T'HHmmss'Z'")
        evidence_sha256 = Get-EvidenceDocumentSha256 $Evidence
    }
    $payloadJson = $payload | ConvertTo-Json -Compress
    $protected = [Security.Cryptography.ProtectedData]::Protect(
        [Text.Encoding]::UTF8.GetBytes($payloadJson),
        $script:EvidenceSealEntropy,
        [Security.Cryptography.DataProtectionScope]::CurrentUser)
    $seal = [ordered]@{
        schema = 1
        protection = 'dpapi-current-user'
        protected_payload = [Convert]::ToBase64String($protected)
    }
    if ($Evidence -is [Collections.IDictionary]) {
        $Evidence['seal'] = $seal
    } else {
        $Evidence | Add-Member -NotePropertyName seal `
            -NotePropertyValue ([pscustomobject]$seal) -Force
    }
    return $Evidence
}

function Assert-EvidenceSeal {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]$Evidence,
        [Parameter(Mandatory = $true)][ValidateSet(
            'desktop-context', 'physical-device')]
        [string]$Scope,
        [Parameter(Mandatory = $true)][int]$CollectorProcessId
    )

    $seal = Get-EvidenceExactMember $Evidence 'seal' 'Evidence'
    Assert-EvidenceExactProperties $seal @('schema', 'protection',
        'protected_payload') 'Evidence seal'
    $sealSchema = Get-EvidenceExactMember $seal 'schema' 'Evidence seal'
    $protection = Get-EvidenceExactMember $seal 'protection' 'Evidence seal'
    $protectedPayload = Get-EvidenceExactMember $seal 'protected_payload' `
        'Evidence seal'
    if (-not (Test-EvidenceIntegerEqual $sealSchema 1) -or
            $protection -isnot [string] -or
            [string]$protection -cne 'dpapi-current-user' -or
            $protectedPayload -isnot [string] -or
            [string]::IsNullOrWhiteSpace($protectedPayload) -or
            ([string]$protectedPayload).Length -gt 32768) {
        throw 'Evidence seal metadata is invalid.'
    }
    try {
        $protected = [Convert]::FromBase64String([string]$protectedPayload)
        if ($protected.Length -le 0 -or $protected.Length -gt 16384) {
            throw 'Protected evidence payload has an invalid size.'
        }
        $plain = [Security.Cryptography.ProtectedData]::Unprotect(
            $protected, $script:EvidenceSealEntropy,
            [Security.Cryptography.DataProtectionScope]::CurrentUser)
        $strictUtf8 = [Text.UTF8Encoding]::new($false, $true)
        $payload = $strictUtf8.GetString($plain) | ConvertFrom-Json
    } catch {
        throw 'Evidence seal cannot be authenticated for the current user.'
    }
    Assert-EvidenceExactProperties $payload @('schema', 'scope', 'machine_id',
        'user_sid', 'collector_process_id', 'sealed_utc', 'evidence_sha256') `
        'Protected evidence payload'
    $payloadSchema = Get-EvidenceExactMember $payload 'schema' 'Protected payload'
    $payloadScope = Get-EvidenceExactMember $payload 'scope' 'Protected payload'
    $payloadMachine = Get-EvidenceExactMember $payload 'machine_id' `
        'Protected payload'
    $payloadSid = Get-EvidenceExactMember $payload 'user_sid' 'Protected payload'
    $payloadPid = Get-EvidenceExactMember $payload 'collector_process_id' `
        'Protected payload'
    $payloadTime = Get-EvidenceExactMember $payload 'sealed_utc' `
        'Protected payload'
    $payloadHash = Get-EvidenceExactMember $payload 'evidence_sha256' `
        'Protected payload'
    if (-not (Test-EvidenceIntegerEqual $payloadSchema 1) -or
            $payloadScope -isnot [string] -or
            [string]$payloadScope -cne $Scope -or
            -not (Test-EvidenceIntegerEqual $payloadPid $CollectorProcessId) -or
            $payloadMachine -isnot [string] -or
            [string]$payloadMachine -notmatch '^[A-F0-9]{64}$' -or
            [string]$payloadMachine -cne (Get-EvidenceMachineId) -or
            $payloadSid -isnot [string] -or
            [string]$payloadSid -cne (Get-EvidenceUserSid) -or
            $payloadTime -isnot [string] -or
            $payloadHash -isnot [string] -or
            [string]$payloadHash -notmatch '^[A-F0-9]{64}$') {
        throw 'Evidence seal belongs to another scope, collector, machine, or user.'
    }
    $sealedUtc = [DateTimeOffset]::MinValue
    if (-not [DateTimeOffset]::TryParseExact([string]$payloadTime,
            "yyyyMMdd'T'HHmmss'Z'", [Globalization.CultureInfo]::InvariantCulture,
            [Globalization.DateTimeStyles]::AssumeUniversal, [ref]$sealedUtc) -or
            $sealedUtc -gt [DateTimeOffset]::UtcNow.AddMinutes(5)) {
        throw 'Evidence seal timestamp is invalid or in the future.'
    }
    $actualHash = Get-EvidenceDocumentSha256 $Evidence
    if ([string]$payloadHash -cne $actualHash) {
        throw 'Evidence content does not match its protected seal.'
    }
    return $payload
}

Export-ModuleMember -Function ConvertTo-EvidenceCanonicalJson,
    Get-EvidenceTextSha256, Get-EvidenceDocumentSha256,
    Get-EvidenceMachineId, Get-EvidenceUserSid, Add-EvidenceSeal,
    Assert-EvidenceSeal
