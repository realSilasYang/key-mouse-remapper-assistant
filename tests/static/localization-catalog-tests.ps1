$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSCommandPath))
$localizationRoot = Join-Path $projectRoot 'src\Localization'
$catalogFiles = @(Get-ChildItem -LiteralPath $localizationRoot `
    -Filter '*Strings.ahk' -File | Sort-Object Name)

if ($catalogFiles.Count -ne 12) {
    throw "Expected 12 localization catalogs, found $($catalogFiles.Count)."
}

$catalogPattern = 'catalog\.Set\(\s*"((?:``"|[^"])*)"'
$translationPattern = '(?<![A-Za-z0-9_])Tr\(\s*"((?:``"|[^"])*)"'
$regexOptions = [Text.RegularExpressions.RegexOptions]::Singleline
$catalogKeySets = @{}

foreach ($catalogFile in $catalogFiles) {
    $catalogText = Get-Content -LiteralPath $catalogFile.FullName `
        -Raw -Encoding UTF8
    $catalogKeys = @([regex]::Matches($catalogText, $catalogPattern,
            $regexOptions) | ForEach-Object { $_.Groups[1].Value })
    $duplicateKeys = @($catalogKeys | Group-Object -CaseSensitive |
        Where-Object Count -gt 1 | ForEach-Object Name)
    if ($duplicateKeys.Count -gt 0) {
        throw "$($catalogFile.Name) contains duplicate keys: " +
            ($duplicateKeys -join ', ')
    }
    $keySet = [System.Collections.Generic.HashSet[string]]::new(
        [System.StringComparer]::Ordinal)
    foreach ($key in $catalogKeys) {
        [void]$keySet.Add($key)
    }
    $catalogKeySets[$catalogFile.Name] = $keySet
}

$referenceName = 'EnglishStrings.ahk'
$referenceKeys = $catalogKeySets[$referenceName]
foreach ($catalogFile in $catalogFiles) {
    $keySet = $catalogKeySets[$catalogFile.Name]
    $missing = @($referenceKeys | Where-Object { -not $keySet.Contains($_) })
    $extra = @($keySet | Where-Object { -not $referenceKeys.Contains($_) })
    if ($missing.Count -gt 0 -or $extra.Count -gt 0) {
        throw "$($catalogFile.Name) key set differs from ${referenceName}: " +
            "missing [$($missing -join ', ')], extra [$($extra -join ', ')]."
    }
}

$sourceFiles = @(Get-ChildItem -LiteralPath (Join-Path $projectRoot 'app'),
    (Join-Path $projectRoot 'src') -Recurse -Filter '*.ahk' -File |
    Where-Object { $_.DirectoryName -ne $localizationRoot })
$sourceFiles += @(Get-ChildItem -LiteralPath $projectRoot -Filter '*.ahk' -File)
$usedKeys = [System.Collections.Generic.HashSet[string]]::new(
    [System.StringComparer]::Ordinal)
$dynamicKeys = [System.Collections.Generic.HashSet[string]]::new(
    [System.StringComparer]::Ordinal)
foreach ($sourceFile in $sourceFiles) {
    $sourceText = Get-Content -LiteralPath $sourceFile.FullName `
        -Raw -Encoding UTF8
    foreach ($match in [regex]::Matches($sourceText, $translationPattern,
            $regexOptions)) {
        [void]$usedKeys.Add($match.Groups[1].Value)
    }
    foreach ($match in [regex]::Matches($sourceText,
            '(?m)^[ \t]*;[ \t]*@localized-dynamic=(.+?)\r?$')) {
        [void]$dynamicKeys.Add($match.Groups[1].Value.Trim())
    }
}

$untranslated = @($usedKeys | Where-Object {
        -not $referenceKeys.Contains($_)
    } | Sort-Object)
if ($untranslated.Count -gt 0) {
    throw "Literal Tr() keys missing from localization catalogs: " +
        ($untranslated -join ', ')
}

$unused = @($referenceKeys | Where-Object {
        -not $usedKeys.Contains($_) -and -not $dynamicKeys.Contains($_)
    } | Sort-Object)
if ($unused.Count -gt 0) {
    throw "Localization catalog keys are unused: " + ($unused -join ', ')
}

Write-Host 'PASS localization-catalog-tests.ps1'
