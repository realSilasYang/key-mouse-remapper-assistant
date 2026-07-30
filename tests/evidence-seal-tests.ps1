[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version 2.0
$projectRoot = Split-Path -Parent $PSScriptRoot
Import-Module (Join-Path $projectRoot 'tools\EvidenceSeal.psm1') -Force

function Assert-Rejected {
    param([scriptblock]$Action, [string]$Message)

    $rejected = $false
    try { & $Action | Out-Null } catch { $rejected = $true }
    if (-not $rejected) { throw $Message }
}

$orderedOne = [ordered]@{ z = 1; nested = [ordered]@{ b = 2; a = 3 } }
$orderedTwo = [ordered]@{ nested = [ordered]@{ a = 3; b = 2 }; z = 1 }
if ((Get-EvidenceDocumentSha256 $orderedOne) -cne
        (Get-EvidenceDocumentSha256 $orderedTwo)) {
    throw 'Canonical evidence hashing depends on dictionary insertion order.'
}

$rootSealOne = [ordered]@{ value = 1; seal = [ordered]@{ token = 'one' } }
$rootSealTwo = [ordered]@{ seal = [ordered]@{ token = 'two' }; value = 1 }
if ((Get-EvidenceDocumentSha256 $rootSealOne) -cne
        (Get-EvidenceDocumentSha256 $rootSealTwo)) {
    throw 'The root seal was unexpectedly included in the evidence hash.'
}

$nestedSealOne = [ordered]@{ nested = [ordered]@{ seal = 'one' } }
$nestedSealTwo = [ordered]@{ nested = [ordered]@{ seal = 'two' } }
if ((Get-EvidenceDocumentSha256 $nestedSealOne) -ceq
        (Get-EvidenceDocumentSha256 $nestedSealTwo)) {
    throw 'A nested field named seal was omitted from the evidence hash.'
}

$sealed = [ordered]@{ nested = [ordered]@{ seal = 'original' } }
Add-EvidenceSeal $sealed 'desktop-context' $PID | Out-Null
Assert-EvidenceSeal $sealed 'desktop-context' $PID | Out-Null
$sealed.nested.seal = 'tampered'
Assert-Rejected {
    Assert-EvidenceSeal $sealed 'desktop-context' $PID
} 'Nested seal-field tampering was accepted.'

$nonStringKey = [Collections.Specialized.OrderedDictionary]::new()
$nonStringKey.Add(1, 'value')
Assert-Rejected {
    Get-EvidenceDocumentSha256 $nonStringKey
} 'A non-string evidence dictionary key was accepted.'

Assert-Rejected {
    Get-EvidenceDocumentSha256 ([ordered]@{ value = [double]::NaN })
} 'NaN was accepted as canonical JSON evidence.'
Assert-Rejected {
    Get-EvidenceDocumentSha256 ([ordered]@{ value = [double]::PositiveInfinity })
} 'Infinity was accepted as canonical JSON evidence.'

$cycle = [Collections.Specialized.OrderedDictionary]::new()
$cycle.Add('self', $cycle)
Assert-Rejected {
    Get-EvidenceDocumentSha256 $cycle
} 'A cyclic evidence graph was accepted.'

Assert-Rejected {
    Get-EvidenceDocumentSha256 ([IO.FileInfo]::new($PSCommandPath))
} 'An object with executable property getters was accepted as evidence.'

$preserved = [ordered]@{
    value = [IO.FileInfo]::new($PSCommandPath)
    seal = 'original-seal'
}
Assert-Rejected {
    Add-EvidenceSeal $preserved 'desktop-context' $PID
} 'An unsupported evidence object was sealed.'
if ([string]$preserved.seal -cne 'original-seal') {
    throw 'A failed reseal operation destroyed the previous seal.'
}

$wrongCaseSeal = [ordered]@{ Seal = 'ambiguous'; value = 1 }
Assert-Rejected {
    Add-EvidenceSeal $wrongCaseSeal 'desktop-context' $PID
} 'A differently-cased root seal field was accepted.'

Write-Host 'Evidence seal canonicalization checks passed.'
