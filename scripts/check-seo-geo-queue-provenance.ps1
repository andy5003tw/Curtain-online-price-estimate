[CmdletBinding()]
param(
  [Parameter(Mandatory = $true)]
  [string]$RuntimeRoot,
  [string]$RepoRoot,
  [switch]$FailOnStale
)

$ErrorActionPreference = 'Stop'

function Get-Sha256File {
  param([string]$Path)
  if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { return $null }
  return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()
}

function Get-Sha256Text {
  param([Parameter(Mandatory = $true)][string]$Text)
  $bytes = [System.Text.Encoding]::UTF8.GetBytes($Text)
  $hash = [System.Security.Cryptography.SHA256]::Create().ComputeHash($bytes)
  return ([System.BitConverter]::ToString($hash)).Replace('-', '').ToLowerInvariant()
}

function Read-Json {
  param([Parameter(Mandatory = $true)][string]$Path)
  return Get-Content -LiteralPath $Path -Raw -Encoding UTF8 | ConvertFrom-Json
}

function Resolve-RelativePath {
  param(
    [Parameter(Mandatory = $true)][string]$BasePath,
    [Parameter(Mandatory = $true)][string]$RelativePath
  )
  if ([System.IO.Path]::IsPathRooted($RelativePath)) { return $null }
  $separator = [System.IO.Path]::DirectorySeparatorChar
  $baseFull = [System.IO.Path]::GetFullPath($BasePath).TrimEnd($separator)
  $full = [System.IO.Path]::GetFullPath((Join-Path $baseFull ($RelativePath.Replace('/', $separator))))
  if ($full -eq $baseFull -or -not $full.StartsWith($baseFull + $separator, [System.StringComparison]::OrdinalIgnoreCase)) { return $null }
  return $full
}

function New-Result {
  param([bool]$Stale, [string[]]$Reasons, [object]$State)
  return [ordered]@{
    status = if ($Stale) { 'stale_plan' } else { 'current' }
    stale = $Stale
    reasons = @($Reasons)
    queue_id = if ($State) { [string]$State.queue_id } else { $null }
    cycle_key = if ($State) { [string]$State.cycle_key } else { $null }
  }
}

$runtimeFull = [System.IO.Path]::GetFullPath($RuntimeRoot)
$statePath = Join-Path $runtimeFull 'latest\seo-geo-action-queue-state.json'
if (-not (Test-Path -LiteralPath $statePath -PathType Leaf)) {
  $result = New-Result -Stale $true -Reasons @('queue_state_missing') -State $null
  $result | ConvertTo-Json -Depth 6 -Compress
  exit $(if ($FailOnStale) { 2 } else { 0 })
}

$state = Read-Json -Path $statePath
$reasons = @()

# After a receipt-backed implementation, the registry/action-history/source
# hashes necessarily differ from the queue's pre-change snapshot.  Accept only
# that exact, queue-bound after-state; any extra or unbound drift remains stale.
$implementationReceiptPath = Join-Path $runtimeFull 'latest\seo-geo-validation-receipt.json'
$implementationReceipt = $null
if (Test-Path -LiteralPath $implementationReceiptPath -PathType Leaf) {
  try {
    $candidate = Read-Json -Path $implementationReceiptPath
    if ([string]$candidate.schema_version -eq '2' -and
        [string]$candidate.status -eq 'passed' -and
        [string]$candidate.result -eq 'implemented' -and
        [string]$candidate.queue_id -eq [string]$state.queue_id -and
        [string]$candidate.cycle_key -eq [string]$state.cycle_key -and
        @($candidate.source_files_after).Count -eq @($state.source_files).Count -and
        -not [string]::IsNullOrWhiteSpace([string]$candidate.source_fingerprint_after)) {
      $implementationReceipt = $candidate
    }
  } catch {
    # A malformed optional receipt cannot acknowledge runtime drift.
    $implementationReceipt = $null
  }
}

function Test-SetEqual {
  param([object[]]$Left, [object[]]$Right)
  $leftSet = @($Left | ForEach-Object { ([string]$_).Trim() } | Where-Object { $_ } | Sort-Object -Unique)
  $rightSet = @($Right | ForEach-Object { ([string]$_).Trim() } | Where-Object { $_ } | Sort-Object -Unique)
  return $leftSet.Count -eq $rightSet.Count -and @($leftSet | Where-Object { $_ -notin $rightSet }).Count -eq 0
}

function Get-SourceEntriesFingerprint {
  param([object[]]$Entries)
  $parts = @($Entries | Sort-Object { [string]$_.path } | ForEach-Object {
    $path = [string]$_.path
    $hash = [string]$_.sha256
    "$path=$(if ([string]::IsNullOrWhiteSpace($hash)) { 'missing' } else { $hash })"
  })
  return Get-Sha256Text -Text ($parts -join "`n")
}

function Test-PendingImplementationReceipt {
  param([object]$Receipt, [object]$State)
  if (-not $Receipt -or [string]$State.status -ne 'active') { return $false }
  if ([string]$Receipt.source_fingerprint_before -ne [string]$State.source_fingerprint) { return $false }
  $round = [int]$Receipt.round
  $stateRound = @($State.rounds | Where-Object { [int]$_.round -eq $round } | Select-Object -First 1)[0]
  if (-not $stateRound -or -not (Test-SetEqual -Left @($Receipt.action_ids) -Right @($stateRound.action_ids))) { return $false }
  $statePaths = @($State.source_files | ForEach-Object { [string]$_.path })
  $receiptPaths = @($Receipt.source_files_after | ForEach-Object { [string]$_.path })
  if (-not (Test-SetEqual -Left $receiptPaths -Right $statePaths)) { return $false }
  return $true
}

function Test-ImplementedRuntimeAcknowledgement {
  param([object]$Receipt, [object]$State, [string]$WeeklyRoot)
  if (-not $Receipt) { return $false }
  $expectedActionIds = @($State.rounds | ForEach-Object { @($_.action_ids) })
  if (-not (Test-SetEqual -Left @($Receipt.action_ids) -Right $expectedActionIds)) { return $false }
  $historyPath = Join-Path $WeeklyRoot 'history\curtain-online\seo-geo-action-history.json'
  $registryPath = Join-Path $WeeklyRoot 'config\target-registry.json'
  try {
    $history = Read-Json -Path $historyPath
    $registry = Read-Json -Path $registryPath
    foreach ($actionId in @($Receipt.action_ids)) {
      $receiptAction = @($Receipt.action_fingerprints | Where-Object { [string]$_.action_id -eq [string]$actionId } | Select-Object -First 1)[0]
      $historyAction = @($history.actions | Where-Object { [string]$_.queue_id -eq [string]$State.queue_id -and [string]$_.cycle_key -eq [string]$State.cycle_key -and [string]$_.action_id -eq [string]$actionId -and [string]$_.result -eq 'implemented' } | Select-Object -First 1)[0]
      $clusterId = if ($historyAction) { [string]$historyAction.cluster_id } else { '' }
      $target = @($registry.targets | Where-Object { [string]$_.clusterId -eq $clusterId } | Select-Object -First 1)[0]
      if (-not $receiptAction -or -not $historyAction -or -not $target -or
          ([string]$historyAction.fingerprint).ToLowerInvariant() -ne ([string]$receiptAction.fingerprint).ToLowerInvariant() -or
          [string]::IsNullOrWhiteSpace([string]$target.lastChangedAt)) { return $false }
    }
    return $true
  } catch { return $false }
}

$implementedRuntimeAcknowledged = Test-ImplementedRuntimeAcknowledgement -Receipt $implementationReceipt -State $state -WeeklyRoot $runtimeFull
$pendingRuntimeAcknowledged = Test-PendingImplementationReceipt -Receipt $implementationReceipt -State $state
$runtimeAcknowledged = $implementedRuntimeAcknowledged -or $pendingRuntimeAcknowledged

function Test-RuntimeBinding {
  param(
    [Parameter(Mandatory = $true)][string]$Label,
    [object]$Binding,
    [string]$PathProperty = 'path',
    [string]$ShaProperty = 'sha256'
  )
  if (-not $Binding -or [string]::IsNullOrWhiteSpace([string]$Binding.$PathProperty) -or [string]::IsNullOrWhiteSpace([string]$Binding.$ShaProperty)) {
    $script:reasons += $Label + '_binding_missing'
    return $null
  }
  $relative = [string]$Binding.$PathProperty
  $fullPath = Resolve-RelativePath -BasePath $runtimeFull -RelativePath $relative
  $actual = if ($fullPath) { Get-Sha256File -Path $fullPath } else { $null }
  if (-not $actual) {
    $script:reasons += $Label + '_file_missing'
  } elseif ($actual -ne ([string]$Binding.$ShaProperty).ToLowerInvariant()) {
    $script:reasons += $Label + '_sha_mismatch'
  }
  return $fullPath
}

$snapshot = $state.snapshot
foreach ($window in @('7d', '28d')) {
  $windowBinding = if ($snapshot) { $snapshot.$window } else { $null }
  if (-not $windowBinding) {
    $reasons += "snapshot_${window}_binding_missing"
    continue
  }
  $manifestBinding = [PSCustomObject]@{ path = [string]$windowBinding.manifest_path; sha256 = [string]$windowBinding.manifest_sha256 }
  $manifestPath = Test-RuntimeBinding -Label "snapshot_${window}_manifest" -Binding $manifestBinding
  if ($manifestPath -and (Test-Path -LiteralPath $manifestPath -PathType Leaf)) {
    try {
      $manifest = Read-Json -Path $manifestPath
      if ([string]::IsNullOrWhiteSpace([string]$windowBinding.sha256) -or [string]::IsNullOrWhiteSpace([string]$manifest.input_sha256)) {
        $reasons += "snapshot_${window}_input_binding_missing"
      } elseif (([string]$windowBinding.sha256).ToLowerInvariant() -ne ([string]$manifest.input_sha256).ToLowerInvariant()) {
        $reasons += "snapshot_${window}_input_sha_mismatch"
      }
    } catch {
      $reasons += "snapshot_${window}_manifest_invalid"
    }
  }
  [void](Test-RuntimeBinding -Label "snapshot_${window}_query" -Binding $windowBinding.query_baseline)
  [void](Test-RuntimeBinding -Label "snapshot_${window}_page" -Binding $windowBinding.page_baseline)
  [void](Test-RuntimeBinding -Label "snapshot_${window}_query_page" -Binding $windowBinding.query_page_baseline)
  if ($windowBinding.PSObject.Properties.Name -contains 'comparison_query_baseline') {
    [void](Test-RuntimeBinding -Label "snapshot_${window}_comparison_query" -Binding $windowBinding.comparison_query_baseline)
  }
  foreach ($kind in @('date', 'date_page', 'device_page', 'country_page', 'device_query')) {
    $diagnostic = if ($windowBinding.diagnostic_history) { $windowBinding.diagnostic_history.$kind } else { $null }
    if (-not $diagnostic -or -not $diagnostic.snapshot) {
      $reasons += "snapshot_${window}_diagnostic_${kind}_binding_missing"
      continue
    }
    [void](Test-RuntimeBinding -Label "snapshot_${window}_diagnostic_${kind}" -Binding $diagnostic.snapshot)
    if ($diagnostic.daily_history -and [string]$diagnostic.daily_history.status -eq 'available') {
      [void](Test-RuntimeBinding -Label "snapshot_${window}_diagnostic_${kind}_daily" -Binding $diagnostic.daily_history)
    }
  }
}

if (-not $runtimeAcknowledged) {
  [void](Test-RuntimeBinding -Label 'action_history' -Binding $state.action_history)
}

$registry = $state.registry
if (-not $registry -or [string]::IsNullOrWhiteSpace([string]$registry.path) -or [string]::IsNullOrWhiteSpace([string]$registry.sha256)) {
  $reasons += 'registry_binding_missing'
} else {
  $registryPath = Resolve-RelativePath -BasePath $runtimeFull -RelativePath ([string]$registry.path)
  $currentRegistrySha = if ($registryPath) { Get-Sha256File -Path $registryPath } else { $null }
  if (-not $currentRegistrySha) {
    $reasons += 'registry_file_missing'
  } elseif (-not $runtimeAcknowledged -and $currentRegistrySha -ne ([string]$registry.sha256).ToLowerInvariant()) {
    $reasons += 'registry_sha_mismatch'
  }
}

$sourceFiles = @($state.source_files)
$repoRoot = if ([string]::IsNullOrWhiteSpace($RepoRoot)) { Split-Path -Parent $runtimeFull } else { [System.IO.Path]::GetFullPath($RepoRoot) }
if ($sourceFiles.Count -eq 0 -or [string]::IsNullOrWhiteSpace([string]$state.source_fingerprint)) {
  $reasons += 'source_binding_missing'
} else {
  $parts = @()
  $expectedSourceFiles = if ($runtimeAcknowledged) { @($implementationReceipt.source_files_after) } else { $sourceFiles }
  $expectedFingerprint = if ($runtimeAcknowledged) { [string]$implementationReceipt.source_fingerprint_after } else { [string]$state.source_fingerprint }
  foreach ($sourceFile in @($expectedSourceFiles | Sort-Object { [string]$_.path })) {
    $relativePath = [string]$sourceFile.path
    if ([string]::IsNullOrWhiteSpace($relativePath)) {
      $reasons += 'source_path_missing'
      continue
    }
    $sourcePath = Resolve-RelativePath -BasePath $repoRoot -RelativePath $relativePath
    $currentSha = if ($sourcePath) { Get-Sha256File -Path $sourcePath } else { $null }
    if (-not $currentSha) {
      $reasons += 'source_file_missing:' + $relativePath
    } elseif ($currentSha -ne ([string]$sourceFile.sha256).ToLowerInvariant()) {
      $reasons += 'source_sha_mismatch:' + $relativePath
    }
    $parts += ($relativePath + '=' + $(if ($currentSha) { $currentSha } else { 'missing' }))
  }
  $currentFingerprint = Get-Sha256Text -Text ($parts -join "`n")
  if ($currentFingerprint -ne $expectedFingerprint.ToLowerInvariant()) {
    $reasons += 'source_fingerprint_mismatch'
  }
}

# New queues bind monitor-only routes as an independent source inventory. Old
# queues have no such fields and retain their previous behavior. A queue-bound
# implementation receipt may acknowledge an exact changed path only when that
# path also belongs to the owner inventory; monitor-only-exclusive files must
# continue to match the queue snapshot.
$provenance = $state.provenance
$monitorPropertyNames = @('monitor_only_source_sets', 'monitor_only_source_files', 'monitor_only_source_fingerprint')
$monitorBindingPresent = $false
if ($provenance) {
  $monitorBindingPresent = @($monitorPropertyNames | Where-Object { $provenance.PSObject.Properties.Name -contains $_ }).Count -gt 0
}
if ($monitorBindingPresent) {
  $monitorSets = if ($provenance.PSObject.Properties.Name -contains 'monitor_only_source_sets') { @($provenance.monitor_only_source_sets) } else { @() }
  $monitorFiles = if ($provenance.PSObject.Properties.Name -contains 'monitor_only_source_files') { @($provenance.monitor_only_source_files) } else { @() }
  $monitorFingerprint = if ($provenance.PSObject.Properties.Name -contains 'monitor_only_source_fingerprint') { [string]$provenance.monitor_only_source_fingerprint } else { '' }
  if ($provenance.PSObject.Properties.Name -notcontains 'monitor_only_source_sets' -or
      $provenance.PSObject.Properties.Name -notcontains 'monitor_only_source_files' -or
      [string]::IsNullOrWhiteSpace($monitorFingerprint) -or $monitorFiles.Count -eq 0 -or $monitorSets.Count -eq 0) {
    $reasons += 'monitor_only_source_binding_missing'
  } else {
    $monitorByPath = @{}
    $monitorPaths = @()
    foreach ($entry in $monitorFiles) {
      $relativePath = ([string]$entry.path).Replace('\', '/')
      $expectedSha = ([string]$entry.sha256).ToLowerInvariant()
      if ([string]::IsNullOrWhiteSpace($relativePath) -or [System.IO.Path]::IsPathRooted($relativePath) -or
          $relativePath -match '(^|/)\.\.?(/|$)' -or [string]::IsNullOrWhiteSpace($expectedSha)) {
        $reasons += 'monitor_only_source_path_or_hash_invalid'
        continue
      }
      if ($monitorByPath.ContainsKey($relativePath)) {
        $reasons += 'monitor_only_source_path_duplicate:' + $relativePath
        continue
      }
      $monitorByPath[$relativePath] = $expectedSha
      $monitorPaths += $relativePath
    }

    $setPaths = @()
    foreach ($sourceSet in $monitorSets) {
      $setFiles = @($sourceSet.source_files)
      if ([string]::IsNullOrWhiteSpace([string]$sourceSet.asset_id) -or [string]::IsNullOrWhiteSpace([string]$sourceSet.page) -or $setFiles.Count -eq 0) {
        $reasons += 'monitor_only_source_set_incomplete'
        continue
      }
      if ((Get-SourceEntriesFingerprint -Entries $setFiles) -ne ([string]$sourceSet.source_fingerprint).ToLowerInvariant()) {
        $reasons += 'monitor_only_source_set_fingerprint_mismatch:' + [string]$sourceSet.asset_id
      }
      foreach ($entry in $setFiles) {
        $relativePath = ([string]$entry.path).Replace('\', '/')
        $setPaths += $relativePath
        if (-not $monitorByPath.ContainsKey($relativePath)) {
          $reasons += 'monitor_only_source_set_file_unbound:' + $relativePath
        } elseif (([string]$entry.sha256).ToLowerInvariant() -ne [string]$monitorByPath[$relativePath]) {
          $reasons += 'monitor_only_source_set_hash_mismatch:' + $relativePath
        }
      }
    }
    if (-not (Test-SetEqual -Left $monitorPaths -Right $setPaths)) {
      $reasons += 'monitor_only_source_inventory_mismatch'
    }
    if ((Get-SourceEntriesFingerprint -Entries $monitorFiles) -ne $monitorFingerprint.ToLowerInvariant()) {
      $reasons += 'monitor_only_source_binding_fingerprint_mismatch'
    }

    $ownerPaths = @{}
    foreach ($entry in @($sourceFiles)) {
      $path = ([string]$entry.path).Replace('\', '/')
      if ($path) { $ownerPaths[$path] = $true }
    }
    $receiptAfterByPath = @{}
    if ($runtimeAcknowledged) {
      foreach ($entry in @($implementationReceipt.source_files_after)) {
        $path = ([string]$entry.path).Replace('\', '/')
        if ($path) { $receiptAfterByPath[$path] = ([string]$entry.sha256).ToLowerInvariant() }
      }
    }

    $expectedCurrentEntries = @()
    $currentEntries = @()
    foreach ($relativePath in @($monitorByPath.Keys | Sort-Object)) {
      $expectedSha = [string]$monitorByPath[$relativePath]
      $sourcePath = Resolve-RelativePath -BasePath $repoRoot -RelativePath $relativePath
      $currentSha = if ($sourcePath) { Get-Sha256File -Path $sourcePath } else { $null }
      $acknowledgedSha = if ($runtimeAcknowledged -and $ownerPaths.ContainsKey($relativePath) -and $receiptAfterByPath.ContainsKey($relativePath)) {
        [string]$receiptAfterByPath[$relativePath]
      } else { '' }
      if (-not $currentSha) {
        $reasons += 'monitor_only_source_file_missing:' + $relativePath
      } elseif ($currentSha -ne $expectedSha) {
        if (-not $acknowledgedSha -or $currentSha -ne $acknowledgedSha) {
          $reasons += 'monitor_only_source_sha_mismatch:' + $relativePath
        } else {
          $expectedSha = $acknowledgedSha
        }
      }
      $expectedCurrentEntries += [PSCustomObject]@{ path = $relativePath; sha256 = $expectedSha }
      $currentEntries += [PSCustomObject]@{ path = $relativePath; sha256 = $currentSha }
    }
    $currentMonitorFingerprint = Get-SourceEntriesFingerprint -Entries $currentEntries
    $authorizedMonitorFingerprint = Get-SourceEntriesFingerprint -Entries $expectedCurrentEntries
    if ($currentMonitorFingerprint -ne $authorizedMonitorFingerprint) {
      $reasons += 'monitor_only_source_fingerprint_mismatch'
    }
  }
}

if ($provenance -and $provenance.PSObject.Properties.Name -contains 'manual_deployment_evidence_fingerprint') {
  $expectedManualFingerprint = [string]$provenance.manual_deployment_evidence_fingerprint
  $reader = Join-Path $PSScriptRoot 'manual-deploy-evidence-reader.mjs'
  if ($expectedManualFingerprint -notmatch '^[0-9a-f]{64}$' -or -not (Test-Path -LiteralPath $reader -PathType Leaf)) {
    $reasons += 'manual_deployment_evidence_binding_invalid'
  } else {
    try {
      $manualJson = (& node $reader --weekly-root $runtimeFull | Out-String)
      if ($LASTEXITCODE -ne 0) { $reasons += 'manual_deployment_evidence_rejected' }
      elseif ((Get-Sha256Text -Text $manualJson) -ne $expectedManualFingerprint) { $reasons += 'manual_deployment_evidence_fingerprint_mismatch' }
    } catch { $reasons += 'manual_deployment_evidence_unavailable' }
  }
}

$result = New-Result -Stale ($reasons.Count -gt 0) -Reasons $reasons -State $state
$result | ConvertTo-Json -Depth 6 -Compress
if ($FailOnStale -and $result.stale) { exit 2 }
