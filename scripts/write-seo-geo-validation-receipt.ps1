[CmdletBinding()]
param(
  [Parameter(Mandatory = $true)]
  [string]$RuntimeRoot,

  [Parameter(Mandatory = $true)]
  [string]$QueueId,

  [Parameter(Mandatory = $true)]
  [string]$CycleKey,

  [Parameter(Mandatory = $true)]
  [ValidateRange(1, 2147483647)]
  [int]$Round,

  [Parameter(Mandatory = $true)]
  [ValidateSet('implemented', 'no_change_verified')]
  [string]$Result,

  [string[]]$ChangedFiles = @(),

  [Parameter(Mandatory = $true)]
  [string]$ValidationResultsJson
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Get-PropertyValue {
  param(
    [AllowNull()]
    [object]$InputObject,
    [Parameter(Mandatory = $true)]
    [string]$Name
  )

  if ($null -eq $InputObject) {
    return $null
  }
  $property = $InputObject.PSObject.Properties[$Name]
  if ($null -eq $property) {
    return $null
  }
  return $property.Value
}

function Get-NormalizedStrings {
  param(
    [AllowNull()]
    [object]$Values,
    [switch]$SplitLines
  )

  $result = @()
  foreach ($value in @($Values)) {
    if ($null -eq $value) {
      continue
    }
    $parts = if ($SplitLines) { @(([string]$value) -split '\r?\n') } else { @([string]$value) }
    foreach ($part in $parts) {
      $normalized = ([string]$part).Trim()
      if (-not [string]::IsNullOrWhiteSpace($normalized)) {
        $result += $normalized
      }
    }
  }
  return @($result | Sort-Object -Unique)
}

function Test-SameStringSet {
  param(
    [AllowNull()]
    [object]$Left,
    [AllowNull()]
    [object]$Right
  )

  $leftValues = @(Get-NormalizedStrings -Values $Left)
  $rightValues = @(Get-NormalizedStrings -Values $Right)
  if ($leftValues.Count -ne $rightValues.Count) {
    return $false
  }
  for ($index = 0; $index -lt $leftValues.Count; $index++) {
    if ($leftValues[$index] -cne $rightValues[$index]) {
      return $false
    }
  }
  return $true
}

function Get-RoundItem {
  param(
    [AllowNull()]
    [object]$Items,
    [Parameter(Mandatory = $true)]
    [int]$RoundNumber
  )

  return @($Items | Where-Object { [int](Get-PropertyValue -InputObject $_ -Name 'round') -eq $RoundNumber } | Select-Object -First 1)[0]
}

function Get-FileSha256 {
  param([Parameter(Mandatory = $true)][string]$Path)
  return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()
}

function Get-TextSha256 {
  param([Parameter(Mandatory = $true)][string]$Text)

  $sha = [System.Security.Cryptography.SHA256]::Create()
  try {
    $bytes = [System.Text.Encoding]::UTF8.GetBytes($Text)
    return ([System.BitConverter]::ToString($sha.ComputeHash($bytes))).Replace('-', '').ToLowerInvariant()
  } finally {
    $sha.Dispose()
  }
}

function Test-Sha256 {
  param([AllowNull()][object]$Value)
  return ([string]$Value) -cmatch '^[0-9a-fA-F]{64}$'
}

function Get-PortableRelativePath {
  param(
    [Parameter(Mandatory = $true)][string]$BasePath,
    [Parameter(Mandatory = $true)][string]$Path
  )

  $baseFullPath = [System.IO.Path]::GetFullPath($BasePath).TrimEnd('\') + '\'
  $targetFullPath = [System.IO.Path]::GetFullPath($Path)
  $baseUri = [System.Uri]::new($baseFullPath)
  $targetUri = [System.Uri]::new($targetFullPath)
  return [System.Uri]::UnescapeDataString($baseUri.MakeRelativeUri($targetUri).ToString()).Replace('\', '/')
}

function Get-NormalizedPortablePath {
  param(
    [AllowNull()][object]$Value,
    [Parameter(Mandatory = $true)][string]$Label,
    [switch]$AllowParent
  )

  $path = ([string]$Value).Trim().Replace('\', '/').TrimStart('/')
  if ([string]::IsNullOrWhiteSpace($path) -or [System.IO.Path]::IsPathRooted($path)) {
    throw "$Label must be a portable relative path."
  }
  if (-not $AllowParent -and @($path -split '/' | Where-Object { $_ -eq '..' }).Count -gt 0) {
    throw "$Label cannot escape its root: $path"
  }
  return $path
}

function Get-NormalizedSourceFiles {
  param(
    [AllowNull()][object]$Entries,
    [Parameter(Mandatory = $true)][string]$Label
  )

  $normalized = @()
  $seen = @{}
  foreach ($entry in @($Entries)) {
    if ($null -eq $entry) { continue }
    $path = Get-NormalizedPortablePath -Value (Get-PropertyValue -InputObject $entry -Name 'path') -Label "$Label.path"
    $sha256 = ([string](Get-PropertyValue -InputObject $entry -Name 'sha256')).Trim().ToLowerInvariant()
    if (-not (Test-Sha256 -Value $sha256)) {
      throw "$Label has an invalid sha256 for '$path'."
    }
    if ($seen.ContainsKey($path)) {
      throw "$Label contains duplicate path '$path'."
    }
    $seen[$path] = $true
    $normalized += [pscustomobject][ordered]@{
      path = $path
      sha256 = $sha256
    }
  }
  if ($normalized.Count -eq 0) {
    throw "$Label must contain the complete owner source inventory."
  }
  return @($normalized | Sort-Object path)
}

function Get-SourceFingerprintFromEntries {
  param([Parameter(Mandatory = $true)][object[]]$Entries)
  $parts = @($Entries | Sort-Object path | ForEach-Object { "$($_.path)=$($_.sha256)" })
  return Get-TextSha256 -Text ($parts -join "`n")
}

function Get-NormalizedRegistryBinding {
  param(
    [AllowNull()][object]$Binding,
    [Parameter(Mandatory = $true)][string]$Label
  )

  if ($null -eq $Binding) { throw "$Label is required." }
  $path = Get-NormalizedPortablePath -Value (Get-PropertyValue -InputObject $Binding -Name 'path') -Label "$Label.path" -AllowParent
  $sha256 = ([string](Get-PropertyValue -InputObject $Binding -Name 'sha256')).Trim().ToLowerInvariant()
  if (-not (Test-Sha256 -Value $sha256)) { throw "$Label.sha256 must be a SHA-256 hash." }
  $versionValue = Get-PropertyValue -InputObject $Binding -Name 'version'
  if ($null -eq $versionValue -or [int]$versionValue -lt 1) { throw "$Label.version must be at least 1." }
  $owners = @()
  $seenOwners = @{}
  foreach ($owner in @((Get-PropertyValue -InputObject $Binding -Name 'owners'))) {
    if ($null -eq $owner) { continue }
    $clusterId = ([string](Get-PropertyValue -InputObject $owner -Name 'cluster_id')).Trim()
    $ownerUrl = ([string](Get-PropertyValue -InputObject $owner -Name 'owner_url')).Trim()
    $sourceFiles = @(Get-NormalizedStrings -Values (Get-PropertyValue -InputObject $owner -Name 'source_files') | ForEach-Object {
      Get-NormalizedPortablePath -Value $_ -Label "$Label.owners.source_files"
    })
    if ([string]::IsNullOrWhiteSpace($clusterId) -or [string]::IsNullOrWhiteSpace($ownerUrl) -or $sourceFiles.Count -eq 0) {
      throw "$Label.owners contains an incomplete owner binding."
    }
    $ownerKey = "$clusterId`0$ownerUrl"
    if ($seenOwners.ContainsKey($ownerKey)) { throw "$Label.owners contains duplicate owner '$clusterId'." }
    $seenOwners[$ownerKey] = $true
    $owners += [pscustomobject][ordered]@{
      cluster_id = $clusterId
      owner_url = $ownerUrl
      source_files = @($sourceFiles | Sort-Object -Unique)
    }
  }
  if ($owners.Count -eq 0) { throw "$Label.owners must bind the active registry owners." }
  return [pscustomobject][ordered]@{
    path = $path
    sha256 = $sha256
    version = [int]$versionValue
    owners = @($owners | Sort-Object cluster_id, owner_url)
  }
}

function Get-NormalizedBaselineBinding {
  param(
    [AllowNull()][object]$Binding,
    [Parameter(Mandatory = $true)][string]$Label
  )

  if ($null -eq $Binding) { throw "$Label is required." }
  $path = Get-NormalizedPortablePath -Value (Get-PropertyValue -InputObject $Binding -Name 'path') -Label "$Label.path"
  $sha256 = ([string](Get-PropertyValue -InputObject $Binding -Name 'sha256')).Trim().ToLowerInvariant()
  if (-not (Test-Sha256 -Value $sha256)) { throw "$Label.sha256 must be a SHA-256 hash." }
  return [pscustomobject][ordered]@{ path = $path; sha256 = $sha256 }
}

function Get-NormalizedWindowBinding {
  param(
    [AllowNull()][object]$Binding,
    [Parameter(Mandatory = $true)][string]$Label
  )

  if ($null -eq $Binding) { throw "$Label is required." }
  $runId = ([string](Get-PropertyValue -InputObject $Binding -Name 'run_id')).Trim()
  $inputSha = ([string](Get-PropertyValue -InputObject $Binding -Name 'sha256')).Trim().ToLowerInvariant()
  $manifestPath = Get-NormalizedPortablePath -Value (Get-PropertyValue -InputObject $Binding -Name 'manifest_path') -Label "$Label.manifest_path"
  $manifestSha = ([string](Get-PropertyValue -InputObject $Binding -Name 'manifest_sha256')).Trim().ToLowerInvariant()
  $dataConfidence = ([string](Get-PropertyValue -InputObject $Binding -Name 'data_confidence')).Trim()
  $decisionReadyValue = Get-PropertyValue -InputObject $Binding -Name 'decision_ready'
  $bootstrappedValue = Get-PropertyValue -InputObject $Binding -Name 'bootstrapped'
  if ([string]::IsNullOrWhiteSpace($runId)) { throw "$Label.run_id is required." }
  if (-not (Test-Sha256 -Value $inputSha)) { throw "$Label.sha256 must be a SHA-256 hash." }
  if (-not (Test-Sha256 -Value $manifestSha)) { throw "$Label.manifest_sha256 must be a SHA-256 hash." }
  if ([string]::IsNullOrWhiteSpace($dataConfidence)) { throw "$Label.data_confidence is required." }
  if ($null -eq $decisionReadyValue -or $null -eq $bootstrappedValue) { throw "$Label decision flags are required." }
  return [pscustomobject][ordered]@{
    run_id = $runId
    sha256 = $inputSha
    manifest_path = $manifestPath
    manifest_sha256 = $manifestSha
    query_baseline = Get-NormalizedBaselineBinding -Binding (Get-PropertyValue -InputObject $Binding -Name 'query_baseline') -Label "$Label.query_baseline"
    page_baseline = Get-NormalizedBaselineBinding -Binding (Get-PropertyValue -InputObject $Binding -Name 'page_baseline') -Label "$Label.page_baseline"
    data_confidence = $dataConfidence
    decision_ready = [bool]$decisionReadyValue
    bootstrapped = [bool]$bootstrappedValue
  }
}

function Get-NormalizedSnapshotBinding {
  param(
    [AllowNull()][object]$Binding,
    [Parameter(Mandatory = $true)][string]$Label
  )

  if ($null -eq $Binding) { throw "$Label is required." }
  $seven = Get-NormalizedWindowBinding -Binding (Get-PropertyValue -InputObject $Binding -Name '7d') -Label "$Label.7d"
  $twentyEight = Get-NormalizedWindowBinding -Binding (Get-PropertyValue -InputObject $Binding -Name '28d') -Label "$Label.28d"
  if (-not $seven.decision_ready -or -not $twentyEight.decision_ready) {
    throw "$Label must bind decision-ready 7d and 28d snapshots for an implementation receipt."
  }
  return [pscustomobject][ordered]@{ '7d' = $seven; '28d' = $twentyEight }
}

function Test-EquivalentContract {
  param(
    [AllowNull()][object]$Left,
    [AllowNull()][object]$Right
  )
  return (($Left | ConvertTo-Json -Depth 20 -Compress) -ceq ($Right | ConvertTo-Json -Depth 20 -Compress))
}

function Get-NormalizedActionFingerprints {
  param(
    [AllowNull()][object]$Values,
    [Parameter(Mandatory = $true)][string]$Label
  )

  $entries = @()
  $valueArray = @($Values)
  if ($valueArray.Count -eq 1 -and $null -ne $valueArray[0] -and
      $null -eq (Get-PropertyValue -InputObject $valueArray[0] -Name 'action_id')) {
    foreach ($property in $valueArray[0].PSObject.Properties) {
      $entries += [pscustomobject]@{ action_id = [string]$property.Name; fingerprint = [string]$property.Value }
    }
  } else {
    $entries = $valueArray
  }

  $normalized = @()
  $seen = @{}
  foreach ($entry in $entries) {
    if ($null -eq $entry) { continue }
    $actionId = ([string](Get-PropertyValue -InputObject $entry -Name 'action_id')).Trim()
    $fingerprint = ([string](Get-PropertyValue -InputObject $entry -Name 'fingerprint')).Trim().ToLowerInvariant()
    if ([string]::IsNullOrWhiteSpace($actionId)) { throw "$Label contains an empty action_id." }
    if (-not (Test-Sha256 -Value $fingerprint)) { throw "$Label has an invalid fingerprint for '$actionId'." }
    if ($seen.ContainsKey($actionId)) { throw "$Label contains duplicate action_id '$actionId'." }
    $seen[$actionId] = $true
    $normalized += [pscustomobject][ordered]@{ action_id = $actionId; fingerprint = $fingerprint }
  }
  return @($normalized | Sort-Object action_id)
}

function Test-PathWithinRoot {
  param(
    [Parameter(Mandatory = $true)][string]$Path,
    [Parameter(Mandatory = $true)][string]$Root
  )

  $fullPath = [System.IO.Path]::GetFullPath($Path).TrimEnd('\')
  $fullRoot = [System.IO.Path]::GetFullPath($Root).TrimEnd('\')
  return $fullPath.Equals($fullRoot, [System.StringComparison]::OrdinalIgnoreCase) -or
    $fullPath.StartsWith($fullRoot + '\', [System.StringComparison]::OrdinalIgnoreCase)
}

function Write-JsonAtomic {
  param(
    [Parameter(Mandatory = $true)][string]$Path,
    [Parameter(Mandatory = $true)][object]$Value
  )

  $directory = Split-Path -Parent $Path
  if (-not (Test-Path -LiteralPath $directory -PathType Container)) {
    [void](New-Item -ItemType Directory -Path $directory -Force)
  }

  $json = $Value | ConvertTo-Json -Depth 20
  $null = $json | ConvertFrom-Json
  $tempPath = Join-Path $directory ('.' + [System.IO.Path]::GetFileName($Path) + '.' + [guid]::NewGuid().ToString('N') + '.tmp')
  $backupPath = Join-Path $directory ('.' + [System.IO.Path]::GetFileName($Path) + '.' + [guid]::NewGuid().ToString('N') + '.bak')
  $utf8NoBom = [System.Text.UTF8Encoding]::new($false)

  [System.IO.File]::WriteAllText($tempPath, $json + [Environment]::NewLine, $utf8NoBom)
  try {
    if (Test-Path -LiteralPath $Path -PathType Leaf) {
      [System.IO.File]::Replace($tempPath, $Path, $backupPath, $true)
      Remove-Item -LiteralPath $backupPath -Force -ErrorAction SilentlyContinue
    } else {
      [System.IO.File]::Move($tempPath, $Path)
    }
  } finally {
    Remove-Item -LiteralPath $tempPath -Force -ErrorAction SilentlyContinue
  }
}

$resolvedRuntimeRoot = (Resolve-Path -LiteralPath $RuntimeRoot).Path
$directStatePath = Join-Path $resolvedRuntimeRoot 'latest\seo-geo-action-queue-state.json'
$nestedWeeklyRoot = Join-Path $resolvedRuntimeRoot 'Weekly SOP'
$nestedStatePath = Join-Path $nestedWeeklyRoot 'latest\seo-geo-action-queue-state.json'

if (Test-Path -LiteralPath $directStatePath -PathType Leaf) {
  $weeklyRoot = $resolvedRuntimeRoot
  $statePath = $directStatePath
} elseif (Test-Path -LiteralPath $nestedStatePath -PathType Leaf) {
  $weeklyRoot = $nestedWeeklyRoot
  $statePath = $nestedStatePath
} else {
  throw "Queue state not found under RuntimeRoot: $resolvedRuntimeRoot"
}

$scriptProjectRoot = Split-Path -Parent $PSScriptRoot
$runtimeProjectRoot = if ((Split-Path -Leaf $weeklyRoot) -ieq 'Weekly SOP') { Split-Path -Parent $weeklyRoot } else { $weeklyRoot }
$projectRoot = if (Test-Path -LiteralPath (Join-Path $runtimeProjectRoot 'src') -PathType Container) {
  $runtimeProjectRoot
} else {
  $scriptProjectRoot
}

$queuePath = Join-Path $weeklyRoot 'latest\seo-geo-action-queue.json'
if (-not (Test-Path -LiteralPath $queuePath -PathType Leaf)) {
  throw "Queue JSON not found: $queuePath"
}
$state = Get-Content -LiteralPath $statePath -Raw -Encoding UTF8 | ConvertFrom-Json
$queue = Get-Content -LiteralPath $queuePath -Raw -Encoding UTF8 | ConvertFrom-Json

foreach ($contractItem in @(
  [pscustomobject]@{ Name = 'queue state'; Value = $state },
  [pscustomobject]@{ Name = 'queue JSON'; Value = $queue }
)) {
  if ([int](Get-PropertyValue -InputObject $contractItem.Value -Name 'schema_version') -ne 2) {
    throw "$($contractItem.Name) schema_version must be 2."
  }
  if ([string](Get-PropertyValue -InputObject $contractItem.Value -Name 'status') -cne 'active') {
    throw "$($contractItem.Name) must be active before writing an implementation receipt."
  }
  if ([string](Get-PropertyValue -InputObject $contractItem.Value -Name 'queue_id') -cne $QueueId) {
    throw "QueueId does not match $($contractItem.Name)."
  }
  if ([string](Get-PropertyValue -InputObject $contractItem.Value -Name 'cycle_key') -cne $CycleKey) {
    throw "CycleKey does not match $($contractItem.Name)."
  }
}
if ([int](Get-PropertyValue -InputObject $state -Name 'active_round') -ne $Round) {
  throw "Round does not match active_round $($state.active_round)."
}

$fixedReceiptRelativePath = 'latest/seo-geo-validation-receipt.json'
$configuredReceiptPath = Get-NormalizedPortablePath -Value (Get-PropertyValue -InputObject $state -Name 'receipt_path') -Label 'state.receipt_path'
if ($configuredReceiptPath -cne $fixedReceiptRelativePath) {
  throw "Queue receipt_path must be '$fixedReceiptRelativePath'."
}
$receiptPath = Join-Path $weeklyRoot 'latest\seo-geo-validation-receipt.json'

# The state and queue must bind the same registry, GSC snapshots, and complete
# owner source inventory. These checks happen before receipt generation so a
# stale or mixed-cycle handoff can never overwrite an existing valid receipt.
$stateRegistry = Get-NormalizedRegistryBinding -Binding (Get-PropertyValue -InputObject $state -Name 'registry') -Label 'state.registry'
$queueRegistry = Get-NormalizedRegistryBinding -Binding (Get-PropertyValue -InputObject $queue -Name 'registry') -Label 'queue.registry'
if (-not (Test-EquivalentContract -Left $stateRegistry -Right $queueRegistry)) {
  throw 'Registry binding disagrees between queue state and queue JSON.'
}

$stateSnapshot = Get-NormalizedSnapshotBinding -Binding (Get-PropertyValue -InputObject $state -Name 'snapshot') -Label 'state.snapshot'
$queueSnapshot = Get-NormalizedSnapshotBinding -Binding (Get-PropertyValue -InputObject $queue -Name 'snapshot') -Label 'queue.snapshot'
if (-not (Test-EquivalentContract -Left $stateSnapshot -Right $queueSnapshot)) {
  throw '7d/28d snapshot binding disagrees between queue state and queue JSON.'
}

$stateSourceFiles = @(Get-NormalizedSourceFiles -Entries (Get-PropertyValue -InputObject $state -Name 'source_files') -Label 'state.source_files')
$queueSourceFiles = @(Get-NormalizedSourceFiles -Entries (Get-PropertyValue -InputObject $queue -Name 'source_files') -Label 'queue.source_files')
if (-not (Test-EquivalentContract -Left $stateSourceFiles -Right $queueSourceFiles)) {
  throw 'source_files disagrees between queue state and queue JSON.'
}
$registrySourcePaths = @(Get-NormalizedStrings -Values @($stateRegistry.owners | ForEach-Object { $_.source_files }))
$inventorySourcePaths = @($stateSourceFiles | ForEach-Object { $_.path })
if (-not (Test-SameStringSet -Left $registrySourcePaths -Right $inventorySourcePaths)) {
  throw 'registry.owners source_files do not cover the bound source_files inventory.'
}
$sourceFingerprintBefore = ([string](Get-PropertyValue -InputObject $state -Name 'source_fingerprint')).Trim().ToLowerInvariant()
$queueSourceFingerprint = ([string](Get-PropertyValue -InputObject $queue -Name 'source_fingerprint')).Trim().ToLowerInvariant()
if (-not (Test-Sha256 -Value $sourceFingerprintBefore) -or $queueSourceFingerprint -cne $sourceFingerprintBefore) {
  throw 'source_fingerprint is invalid or disagrees between queue state and queue JSON.'
}
$boundSourceFingerprint = Get-SourceFingerprintFromEntries -Entries $stateSourceFiles
if ($boundSourceFingerprint -cne $sourceFingerprintBefore) {
  throw 'source_fingerprint does not match the bound source_files inventory.'
}
foreach ($provenanceContract in @(
  [pscustomobject]@{ Name = 'state'; Value = $state; Registry = $stateRegistry; Snapshot = $stateSnapshot; SourceFiles = $stateSourceFiles },
  [pscustomobject]@{ Name = 'queue'; Value = $queue; Registry = $queueRegistry; Snapshot = $queueSnapshot; SourceFiles = $queueSourceFiles }
)) {
  $provenance = Get-PropertyValue -InputObject $provenanceContract.Value -Name 'provenance'
  if ($null -eq $provenance) { throw "$($provenanceContract.Name).provenance is required." }
  $provenanceRegistry = Get-NormalizedRegistryBinding -Binding (Get-PropertyValue -InputObject $provenance -Name 'registry') -Label "$($provenanceContract.Name).provenance.registry"
  $provenanceSnapshot = Get-NormalizedSnapshotBinding -Binding (Get-PropertyValue -InputObject $provenance -Name 'snapshot') -Label "$($provenanceContract.Name).provenance.snapshot"
  $provenanceSourceFiles = @(Get-NormalizedSourceFiles -Entries (Get-PropertyValue -InputObject $provenance -Name 'source_files') -Label "$($provenanceContract.Name).provenance.source_files")
  $provenanceSourceFingerprint = ([string](Get-PropertyValue -InputObject $provenance -Name 'source_fingerprint')).Trim().ToLowerInvariant()
  if (-not (Test-EquivalentContract -Left $provenanceRegistry -Right $provenanceContract.Registry) -or
      -not (Test-EquivalentContract -Left $provenanceSnapshot -Right $provenanceContract.Snapshot) -or
      -not (Test-EquivalentContract -Left $provenanceSourceFiles -Right $provenanceContract.SourceFiles) -or
      $provenanceSourceFingerprint -cne $sourceFingerprintBefore) {
    throw "$($provenanceContract.Name).provenance disagrees with its top-level binding."
  }
}

$promptRound = Get-RoundItem -Items (Get-PropertyValue -InputObject $state -Name 'prompt_files') -RoundNumber $Round
$stateRound = Get-RoundItem -Items (Get-PropertyValue -InputObject $state -Name 'rounds') -RoundNumber $Round
$queueRound = Get-RoundItem -Items (Get-PropertyValue -InputObject $queue -Name 'rounds') -RoundNumber $Round
if ($null -eq $stateRound -or $null -eq $queueRound) {
  throw "Round $Round is missing from queue state or queue JSON."
}

$actionIdSources = @()
foreach ($actionSource in @(
  [pscustomobject]@{ Name = 'prompt_files'; Values = (Get-PropertyValue -InputObject $promptRound -Name 'action_ids') },
  [pscustomobject]@{ Name = 'state.rounds'; Values = (Get-PropertyValue -InputObject $stateRound -Name 'action_ids') },
  [pscustomobject]@{ Name = 'queue.rounds'; Values = (Get-PropertyValue -InputObject $queueRound -Name 'action_ids') }
)) {
  $ids = @(Get-NormalizedStrings -Values $actionSource.Values)
  if ($ids.Count -gt 0) { $actionIdSources += [pscustomobject]@{ Name = $actionSource.Name; Values = $ids } }
}
$queueActions = @((Get-PropertyValue -InputObject $queueRound -Name 'actions'))
$queueActionIds = @(Get-NormalizedStrings -Values @($queueActions | ForEach-Object { Get-PropertyValue -InputObject $_ -Name 'action_id' }))
if ($queueActionIds.Count -gt 0) {
  $actionIdSources += [pscustomobject]@{ Name = 'queue.actions'; Values = $queueActionIds }
}
if ($actionIdSources.Count -lt 3) {
  throw "Round $Round is missing action_ids in one or more state/queue contracts."
}
$actionIds = @($actionIdSources[0].Values)
foreach ($source in @($actionIdSources | Select-Object -Skip 1)) {
  if (-not (Test-SameStringSet -Left $actionIds -Right $source.Values)) {
    throw "Round $Round action_ids disagree between $($actionIdSources[0].Name) and $($source.Name)."
  }
}

$queueActionFingerprints = @(Get-NormalizedActionFingerprints -Values $queueActions -Label 'queue.actions')
if (-not (Test-SameStringSet -Left $actionIds -Right @($queueActionFingerprints | ForEach-Object { $_.action_id }))) {
  throw "Round $Round action fingerprint mapping does not cover the bound action_ids."
}
foreach ($fingerprintSource in @(
  [pscustomobject]@{ Name = 'state.rounds.action_fingerprints'; Values = (Get-PropertyValue -InputObject $stateRound -Name 'action_fingerprints') },
  [pscustomobject]@{ Name = 'prompt_files.action_fingerprints'; Values = (Get-PropertyValue -InputObject $promptRound -Name 'action_fingerprints') }
)) {
  if ($null -ne $fingerprintSource.Values) {
    $rawFingerprintValues = @($fingerprintSource.Values)
    $primitiveFingerprints = @(Get-NormalizedStrings -Values $rawFingerprintValues | ForEach-Object { $_.ToLowerInvariant() })
    $allPrimitive = @($rawFingerprintValues | Where-Object { $_ -isnot [string] }).Count -eq 0
    if ($allPrimitive) {
      foreach ($fingerprint in $primitiveFingerprints) {
        if (-not (Test-Sha256 -Value $fingerprint)) { throw "$($fingerprintSource.Name) contains an invalid fingerprint." }
      }
      if (-not (Test-SameStringSet -Left @($queueActionFingerprints | ForEach-Object { $_.fingerprint }) -Right $primitiveFingerprints)) {
        throw "Round $Round action_fingerprints disagree between queue.actions and $($fingerprintSource.Name)."
      }
    } else {
      $normalizedFingerprints = @(Get-NormalizedActionFingerprints -Values $fingerprintSource.Values -Label $fingerprintSource.Name)
      if (-not (Test-EquivalentContract -Left $queueActionFingerprints -Right $normalizedFingerprints)) {
        throw "Round $Round action_fingerprints disagree between queue.actions and $($fingerprintSource.Name)."
      }
    }
  }
}

$stateRequired = @(Get-NormalizedStrings -Values (Get-PropertyValue -InputObject $stateRound -Name 'required_validations') -SplitLines)
$queueRequired = @(Get-NormalizedStrings -Values (Get-PropertyValue -InputObject $queueRound -Name 'required_validations') -SplitLines)
$promptRequired = @(Get-NormalizedStrings -Values (Get-PropertyValue -InputObject $promptRound -Name 'required_validations') -SplitLines)
$fixedRequiredValidations = @(
  'node .agents/skills/curtain-online-seo-geo/scripts/keyword-owner-check.mjs',
  'npm.cmd run build',
  'npm.cmd run seo:check',
  'npm.cmd run seo:preflight'
)
foreach ($requiredSource in @(
  [pscustomobject]@{ Name = 'state.rounds'; Values = $stateRequired },
  [pscustomobject]@{ Name = 'queue.rounds'; Values = $queueRequired },
  [pscustomobject]@{ Name = 'prompt_files'; Values = $promptRequired }
)) {
  if (-not (Test-SameStringSet -Left $fixedRequiredValidations -Right $requiredSource.Values)) {
    throw "Round $Round required_validations are missing or invalid in $($requiredSource.Name)."
  }
}

try {
  $parsedValidationResults = $ValidationResultsJson | ConvertFrom-Json
} catch {
  throw "ValidationResultsJson is not valid JSON: $($_.Exception.Message)"
}
$validationResultValues = Get-PropertyValue -InputObject $parsedValidationResults -Name 'validation_results'
if ($null -eq $validationResultValues) { $validationResultValues = $parsedValidationResults }
$normalizedValidationResults = @()
$seenCommands = @{}
foreach ($validationResult in @($validationResultValues)) {
  if ($null -eq $validationResult) { continue }
  $command = ([string](Get-PropertyValue -InputObject $validationResult -Name 'command')).Trim()
  $validationStatus = ([string](Get-PropertyValue -InputObject $validationResult -Name 'status')).Trim().ToLowerInvariant()
  $exitCodeValue = Get-PropertyValue -InputObject $validationResult -Name 'exit_code'
  if ([string]::IsNullOrWhiteSpace($command)) { throw 'Every validation result must include command.' }
  if ($seenCommands.ContainsKey($command)) { throw "ValidationResultsJson contains duplicate command: $command" }
  $seenCommands[$command] = $true
  if ($validationStatus -cne 'passed' -or $null -eq $exitCodeValue -or [int]$exitCodeValue -ne 0) {
    throw "Validation result must be passed with exit_code 0: $command"
  }
  $normalizedValidationResults += [ordered]@{ command = $command; status = 'passed'; exit_code = 0 }
}
foreach ($requiredValidation in $fixedRequiredValidations) {
  if (-not $seenCommands.ContainsKey($requiredValidation)) {
    throw "Missing required validation result: $requiredValidation"
  }
}

# Re-hash every owner source file from the bound inventory. ChangedFiles is an
# attestation list only; it never defines the fingerprint scope.
$sourceFilesAfter = @()
$sourceFileBeforeByPath = @{}
foreach ($sourceFile in $stateSourceFiles) {
  $sourceFileBeforeByPath[$sourceFile.path] = $sourceFile.sha256
  $fullPath = [System.IO.Path]::GetFullPath((Join-Path $projectRoot $sourceFile.path.Replace('/', '\')))
  if (-not (Test-PathWithinRoot -Path $fullPath -Root $projectRoot)) {
    throw "Bound source file escapes the project boundary: $($sourceFile.path)"
  }
  if (-not (Test-Path -LiteralPath $fullPath -PathType Leaf)) {
    throw "Bound source file no longer exists: $($sourceFile.path)"
  }
  $sourceFilesAfter += [pscustomobject][ordered]@{
    path = $sourceFile.path
    sha256 = Get-FileSha256 -Path $fullPath
  }
}
$sourceFilesAfter = @($sourceFilesAfter | Sort-Object path)
$sourceFingerprintAfter = Get-SourceFingerprintFromEntries -Entries $sourceFilesAfter

$normalizedChangedFiles = @(Get-NormalizedStrings -Values $ChangedFiles)
if ($Result -ceq 'implemented' -and $normalizedChangedFiles.Count -eq 0) {
  throw "Result 'implemented' requires at least one ChangedFiles entry."
}
if ($Result -ceq 'no_change_verified' -and $normalizedChangedFiles.Count -gt 0) {
  throw "Result 'no_change_verified' cannot include ChangedFiles."
}

$storedChangedFiles = @()
$namedChangedSource = $false
foreach ($changedFile in $normalizedChangedFiles) {
  $resolvedChangedPath = if ([System.IO.Path]::IsPathRooted($changedFile)) {
    [System.IO.Path]::GetFullPath($changedFile)
  } else {
    [System.IO.Path]::GetFullPath((Join-Path $projectRoot $changedFile))
  }
  if (-not (Test-PathWithinRoot -Path $resolvedChangedPath -Root $projectRoot)) {
    throw "Changed file is outside the project boundary: $changedFile"
  }
  if (-not (Test-Path -LiteralPath $resolvedChangedPath -PathType Leaf)) {
    throw "Changed file does not exist: $changedFile"
  }
  $storedPath = Get-NormalizedPortablePath -Value (Get-PortableRelativePath -BasePath $projectRoot -Path $resolvedChangedPath) -Label 'ChangedFiles'
  if (-not $sourceFileBeforeByPath.ContainsKey($storedPath)) {
    throw "Changed file is not part of the bound owner source inventory: $storedPath"
  }
  $storedChangedFiles += $storedPath
  $currentHash = @($sourceFilesAfter | Where-Object { $_.path -ceq $storedPath } | Select-Object -First 1)[0].sha256
  if ($currentHash -cne $sourceFileBeforeByPath[$storedPath]) { $namedChangedSource = $true }
}
$storedChangedFiles = @($storedChangedFiles | Sort-Object -Unique)

if ($Result -ceq 'implemented') {
  if ($sourceFingerprintAfter -ceq $sourceFingerprintBefore) {
    throw "Result 'implemented' requires source_fingerprint_after to differ from source_fingerprint_before."
  }
  if (-not $namedChangedSource) {
    throw "Result 'implemented' requires at least one named ChangedFiles entry to differ from its bound hash."
  }
} elseif ($sourceFingerprintAfter -cne $sourceFingerprintBefore) {
  throw "Result 'no_change_verified' requires source_fingerprint_after to equal source_fingerprint_before."
}

$receipt = [ordered]@{
  schema_version = 2
  queue_id = $QueueId
  cycle_key = $CycleKey
  round = $Round
  action_ids = $actionIds
  action_fingerprints = $queueActionFingerprints
  status = 'passed'
  result = $Result
  changed_files = $storedChangedFiles
  validation_results = $normalizedValidationResults
  registry = $stateRegistry
  snapshot = $stateSnapshot
  source_files_before = $stateSourceFiles
  source_files_after = $sourceFilesAfter
  source_fingerprint_before = $sourceFingerprintBefore
  source_fingerprint_after = $sourceFingerprintAfter
  generated_at = (Get-Date).ToUniversalTime().ToString('o')
}

Write-JsonAtomic -Path $receiptPath -Value $receipt
Write-Output "Validation receipt written: $receiptPath"
