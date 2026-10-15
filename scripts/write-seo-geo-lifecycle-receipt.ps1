[CmdletBinding()]
param(
  [Parameter(Mandatory = $true)][string]$RuntimeRoot,
  [Parameter(Mandatory = $true)][ValidateSet('implemented', 'local_validated', 'deployed', 'live_verified', 'observing_7d', 'reviewed_28d', 'completed')][string]$Stage,
  [Parameter(Mandatory = $true, ParameterSetName = 'Json')][string]$EvidenceJson,
  [Parameter(Mandatory = $true, ParameterSetName = 'File')][string]$EvidencePath
)

$ErrorActionPreference = 'Stop'
$root = (Resolve-Path -LiteralPath $RuntimeRoot).Path
$weeklyRoot = if (Test-Path -LiteralPath (Join-Path $root 'latest\seo-geo-action-queue-state.json')) { $root } elseif (Test-Path -LiteralPath (Join-Path $root 'Weekly SOP\latest\seo-geo-action-queue-state.json')) { Join-Path $root 'Weekly SOP' } else { throw "Queue state not found under RuntimeRoot: $root" }
$statePath = Join-Path $weeklyRoot 'latest\seo-geo-action-queue-state.json'
$queuePath = Join-Path $weeklyRoot 'latest\seo-geo-action-queue.json'
$localReceiptPath = Join-Path $weeklyRoot 'latest\seo-geo-validation-receipt.json'
$lifecyclePath = Join-Path $weeklyRoot 'latest\seo-geo-lifecycle-receipt.json'
$state = Get-Content -LiteralPath $statePath -Raw -Encoding UTF8 | ConvertFrom-Json
$queue = Get-Content -LiteralPath $queuePath -Raw -Encoding UTF8 | ConvertFrom-Json
if ([int]$state.schema_version -ne 2 -or [int]$queue.schema_version -ne 2) { throw 'Queue/state schema_version must be 2.' }
if ([string]$state.queue_id -ne [string]$queue.queue_id -or [string]$state.cycle_key -ne [string]$queue.cycle_key) { throw 'Queue/state identity mismatch.' }
$evidenceText = if ($PSCmdlet.ParameterSetName -eq 'File') {
  if (-not (Test-Path -LiteralPath $EvidencePath -PathType Leaf)) { throw "EvidencePath does not exist: $EvidencePath" }
  Get-Content -LiteralPath $EvidencePath -Raw -Encoding UTF8
} else { $EvidenceJson }
try { $evidence = $evidenceText | ConvertFrom-Json } catch { throw "Lifecycle evidence is invalid JSON: $($_.Exception.Message)" }

function Resolve-WeeklyRelativePath {
  param([Parameter(Mandatory = $true)][string]$RelativePath)
  if ([System.IO.Path]::IsPathRooted($RelativePath)) { throw 'Evidence paths must be relative to Weekly SOP.' }
  $base = [System.IO.Path]::GetFullPath($weeklyRoot).TrimEnd('\')
  $full = [System.IO.Path]::GetFullPath((Join-Path $base ($RelativePath.Replace('/', '\'))))
  if (-not $full.StartsWith($base + '\', [System.StringComparison]::OrdinalIgnoreCase)) { throw "Evidence path escapes Weekly SOP: $RelativePath" }
  return $full
}

function Assert-Sha256 {
  param([string]$Value, [string]$Label)
  if ($Value -notmatch '^[a-fA-F0-9]{64}$') { throw "$Label requires a 64-character SHA-256." }
}

function Get-NormalizedStringSet {
  param([object[]]$Values)
  return @($Values | ForEach-Object { ([string]$_).Trim() } | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Sort-Object -Unique)
}

function Assert-SameStringSet {
  param([object[]]$Actual, [object[]]$Expected, [string]$Label)
  $actualSet = @(Get-NormalizedStringSet -Values $Actual)
  $expectedSet = @(Get-NormalizedStringSet -Values $Expected)
  if ($actualSet.Count -ne $expectedSet.Count -or (@($actualSet | Where-Object { $_ -notin $expectedSet }).Count -gt 0)) {
    throw "$Label does not match the current queue action_ids."
  }
}

function Assert-QueueBoundEvidence {
  param([object]$Value)
  if ([string]$Value.queue_id -ne [string]$state.queue_id -or [string]$Value.cycle_key -ne [string]$state.cycle_key) {
    throw 'Lifecycle evidence queue_id/cycle_key does not bind the current queue.'
  }
  Assert-Sha256 -Value ([string]$Value.queue_sha256) -Label 'Lifecycle evidence queue_sha256'
  $queueSha = (Get-FileHash -LiteralPath $queuePath -Algorithm SHA256).Hash.ToLowerInvariant()
  if ($queueSha -ne ([string]$Value.queue_sha256).ToLowerInvariant()) {
    throw 'Lifecycle evidence queue_sha256 does not match current queue JSON.'
  }
  $expectedActionIds = @($queue.rounds | ForEach-Object { @($_.action_ids) } | Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_) })
  if ($expectedActionIds.Count -eq 0) { throw 'Current queue has no executable action_ids for lifecycle receipt binding.' }
  Assert-SameStringSet -Actual @($Value.action_ids) -Expected $expectedActionIds -Label 'Lifecycle evidence action_ids'
  return [pscustomobject]@{ queue_id = [string]$state.queue_id; cycle_key = [string]$state.cycle_key; queue_sha256 = $queueSha; action_ids = (Get-NormalizedStringSet -Values $expectedActionIds) }
}

function Assert-LocalValidationReceipt {
  param([object]$Value, [string]$Label)
  if (-not (Test-Path -LiteralPath $localReceiptPath -PathType Leaf)) { throw "$Label requires latest/seo-geo-validation-receipt.json." }
  Assert-Sha256 -Value ([string]$Value.validation_receipt_sha256) -Label "$Label validation_receipt_sha256"
  $actualSha = (Get-FileHash -LiteralPath $localReceiptPath -Algorithm SHA256).Hash.ToLowerInvariant()
  if ($actualSha -ne ([string]$Value.validation_receipt_sha256).ToLowerInvariant()) { throw "$Label validation_receipt_sha256 does not match current local receipt." }
  $local = Get-Content -LiteralPath $localReceiptPath -Raw -Encoding UTF8 | ConvertFrom-Json
  if ([string]$local.queue_id -ne [string]$state.queue_id -or [string]$local.cycle_key -ne [string]$state.cycle_key -or [string]$local.status -ne 'passed') { throw "$Label local validation receipt does not bind the current queue." }
  $lastRound = if ($state.PSObject.Properties.Name -contains 'last_validated_round') { [int]$state.last_validated_round } else { [int]$state.total_rounds }
  $expectedReceiptActionIds = @($queue.rounds | Where-Object { [int]$_.round -eq $lastRound } | ForEach-Object { @($_.action_ids) })
  if ($expectedReceiptActionIds.Count -eq 0) { $expectedReceiptActionIds = @($queue.rounds | ForEach-Object { @($_.action_ids) }) }
  Assert-SameStringSet -Actual @($local.action_ids) -Expected $expectedReceiptActionIds -Label "$Label local receipt action_ids"
  return $actualSha
}

function Assert-GscManifestEvidence {
  param([object]$Value, [ValidateSet('7d', '28d')][string]$Window)
  if (-not $Value -or [string]::IsNullOrWhiteSpace([string]$Value.path) -or [string]::IsNullOrWhiteSpace([string]$Value.sha256)) { throw "$Window evidence requires gsc_manifest.path and gsc_manifest.sha256." }
  Assert-Sha256 -Value ([string]$Value.sha256) -Label "$Window gsc_manifest.sha256"
  $manifestPath = Resolve-WeeklyRelativePath -RelativePath ([string]$Value.path)
  if (-not (Test-Path -LiteralPath $manifestPath -PathType Leaf)) { throw "$Window GSC manifest does not exist: $($Value.path)" }
  $actual = (Get-FileHash -LiteralPath $manifestPath -Algorithm SHA256).Hash.ToLowerInvariant()
  if ($actual -ne ([string]$Value.sha256).ToLowerInvariant()) { throw "$Window GSC manifest SHA does not match current file." }
  $manifest = Get-Content -LiteralPath $manifestPath -Raw -Encoding UTF8 | ConvertFrom-Json
  $manifestWindow = if ($manifest.PSObject.Properties.Name -contains 'resolved_window') { [string]$manifest.resolved_window } else { [string]$manifest.window }
  if ($manifestWindow -ne $Window -or [string]$manifest.status -ne 'success') { throw "$Window GSC manifest has the wrong window or status." }
  if (-not [bool]$manifest.decision_ready) { throw "$Window GSC manifest must be decision_ready." }
  return $manifest
}

function Assert-DeploymentManifestEvidence {
  param([object]$Value, [object]$Binding)
  if (-not $Value -or [string]::IsNullOrWhiteSpace([string]$Value.path) -or [string]::IsNullOrWhiteSpace([string]$Value.sha256)) {
    throw 'deployed evidence requires deployment_manifest.path and deployment_manifest.sha256.'
  }
  Assert-Sha256 -Value ([string]$Value.sha256) -Label 'deployment_manifest.sha256'
  $manifestPath = Resolve-WeeklyRelativePath -RelativePath ([string]$Value.path)
  if (-not (Test-Path -LiteralPath $manifestPath -PathType Leaf)) { throw "Deployment manifest does not exist: $($Value.path)" }
  $actualSha = (Get-FileHash -LiteralPath $manifestPath -Algorithm SHA256).Hash.ToLowerInvariant()
  if ($actualSha -ne ([string]$Value.sha256).ToLowerInvariant()) { throw 'deployment_manifest.sha256 does not match the current manifest.' }
  $manifest = Get-Content -LiteralPath $manifestPath -Raw -Encoding UTF8 | ConvertFrom-Json
  if ([int]$manifest.schema_version -ne 1 -or [string]$manifest.status -ne 'success' -or [bool]$manifest.dry_run) { throw 'Deployment manifest must be schema_version=1, status=success, and dry_run=false.' }
  if ([string]$manifest.target_host -ne 'online.hong-sen.com') { throw 'Deployment manifest target_host must be online.hong-sen.com.' }
  if ([string]$manifest.deployment_context.queue_id -ne [string]$Binding.queue_id -or [string]$manifest.deployment_context.cycle_key -ne [string]$Binding.cycle_key) { throw 'Deployment manifest queue/cycle binding does not match current queue.' }
  Assert-SameStringSet -Actual @($manifest.deployment_context.action_ids) -Expected @($Binding.action_ids) -Label 'Deployment manifest action_ids'
  if ([int]$manifest.summary.selected -le 0 -or [int]$manifest.summary.failed -ne 0 -or ([int]$manifest.summary.uploaded + [int]$manifest.summary.skipped) -ne [int]$manifest.summary.selected) { throw 'Deployment manifest summary is incomplete or failed.' }
  $files = @($manifest.files)
  if ($files.Count -ne [int]$manifest.summary.selected) { throw 'Deployment manifest files do not cover selected count.' }
  foreach ($file in $files) {
    if ([string]::IsNullOrWhiteSpace([string]$file.relative_path) -or [string]$file.result -notin @('uploaded', 'skipped_same_size') -or [int64]$file.size_bytes -lt 0) { throw 'Deployment manifest file record is incomplete.' }
    Assert-Sha256 -Value ([string]$file.sha256) -Label "Deployment manifest file SHA for $($file.relative_path)"
  }
  return [pscustomobject]@{ path = [string]$Value.path; sha256 = $actualSha; manifest = $manifest }
}

function Assert-LiveVerificationManifestEvidence {
  param([object]$Value, [object]$Binding)
  if (-not $Value -or [string]::IsNullOrWhiteSpace([string]$Value.path) -or [string]::IsNullOrWhiteSpace([string]$Value.sha256)) { throw 'live_verified evidence requires live_verification_manifest.path and live_verification_manifest.sha256.' }
  Assert-Sha256 -Value ([string]$Value.sha256) -Label 'live_verification_manifest.sha256'
  $manifestPath = Resolve-WeeklyRelativePath -RelativePath ([string]$Value.path)
  if (-not (Test-Path -LiteralPath $manifestPath -PathType Leaf)) { throw "Live verification manifest does not exist: $($Value.path)" }
  $actualSha = (Get-FileHash -LiteralPath $manifestPath -Algorithm SHA256).Hash.ToLowerInvariant()
  if ($actualSha -ne ([string]$Value.sha256).ToLowerInvariant()) { throw 'live_verification_manifest.sha256 does not match current manifest.' }
  $manifest = Get-Content -LiteralPath $manifestPath -Raw -Encoding UTF8 | ConvertFrom-Json
  if ([int]$manifest.schema_version -ne 1 -or [string]$manifest.status -ne 'passed' -or [string]$manifest.scope -ne 'queue_targets' -or [string]$manifest.host -ne 'online.hong-sen.com') { throw 'Live verification manifest must be a passed queue_targets audit for online.hong-sen.com.' }
  if ([string]$manifest.queue_id -ne [string]$Binding.queue_id -or [string]$manifest.cycle_key -ne [string]$Binding.cycle_key) { throw 'Live verification manifest queue/cycle binding does not match current queue.' }
  Assert-SameStringSet -Actual @($manifest.action_ids) -Expected @($Binding.action_ids) -Label 'Live verification manifest action_ids'
  $required = @('http','title','meta_description','h1','canonical','faq_parity','json_ld','internal_links','cta','robots','sitemap')
  foreach ($page in @($manifest.pages)) {
    foreach ($name in $required) {
      $check = @($page.checks | Where-Object { [string]$_.name -eq $name })
      if ($check.Count -ne 1 -or -not [bool]$check[0].passed) { throw "Live verification manifest does not prove passed $name for $($page.url)." }
    }
  }
  if (@($manifest.pages).Count -eq 0) { throw 'Live verification manifest contains no target pages.' }
  $targets = @($queue.rounds | ForEach-Object { @($_.targets) } | Sort-Object -Unique)
  $owners = if ($queue.provenance -and $queue.provenance.registry) { @($queue.provenance.registry.owners) } else { @($queue.registry.owners) }
  foreach ($owner in $owners) {
    $productMatch = [regex]::Match([string]$owner.cluster_id, '^product-(P\d+)$')
    if (-not $productMatch.Success -or [string]$owner.owner_url -notin $targets) { continue }
    $productId = $productMatch.Groups[1].Value
    $redirect = @($manifest.redirect_checks | Where-Object { [string]$_.product_id -eq $productId })
    if ($redirect.Count -ne 1 -or -not [bool]$redirect[0].passed -or [string]$redirect[0].target_url -ne [string]$owner.owner_url -or [int]$redirect[0].status_code -notin @(301, 308)) {
      throw "Live verification manifest does not prove the legacy redirect for $productId."
    }
  }
  return [pscustomobject]@{ path = [string]$Value.path; sha256 = $actualSha }
}

function Write-LifecycleAndStateTransaction {
  param([string]$LifecycleJson, [string]$StateJson)
  $encoding = [System.Text.UTF8Encoding]::new($false)
  $lifecycleExisted = Test-Path -LiteralPath $lifecyclePath -PathType Leaf
  $oldLifecycle = if ($lifecycleExisted) { [System.IO.File]::ReadAllText($lifecyclePath, [System.Text.Encoding]::UTF8) } else { $null }
  $oldState = [System.IO.File]::ReadAllText($statePath, [System.Text.Encoding]::UTF8)
  $lifecycleTemp = $lifecyclePath + '.tmp.' + [guid]::NewGuid().ToString('N')
  $stateTemp = $statePath + '.tmp.' + [guid]::NewGuid().ToString('N')
  try {
    [System.IO.File]::WriteAllText($lifecycleTemp, $LifecycleJson + [Environment]::NewLine, $encoding)
    [System.IO.File]::WriteAllText($stateTemp, $StateJson + [Environment]::NewLine, $encoding)
    [System.IO.File]::Move($lifecycleTemp, $lifecyclePath, $true)
    try {
      [System.IO.File]::Move($stateTemp, $statePath, $true)
    } catch {
      if ($lifecycleExisted) { [System.IO.File]::WriteAllText($lifecyclePath, $oldLifecycle, $encoding) } elseif (Test-Path -LiteralPath $lifecyclePath) { [System.IO.File]::Delete($lifecyclePath) }
      [System.IO.File]::WriteAllText($statePath, $oldState, $encoding)
      throw
    }
  } finally {
    if (Test-Path -LiteralPath $lifecycleTemp) { [System.IO.File]::Delete($lifecycleTemp) }
    if (Test-Path -LiteralPath $stateTemp) { [System.IO.File]::Delete($stateTemp) }
  }
}

$predecessor = @{ implemented = 'awaiting_implemented_receipt'; local_validated = 'implemented'; deployed = 'local_validated'; live_verified = 'deployed'; observing_7d = 'live_verified'; reviewed_28d = 'observing_7d'; completed = 'reviewed_28d' }[$Stage]
if ([string]$state.status -ne $predecessor) { throw "Stage '$Stage' requires state '$predecessor'; current state is '$($state.status)'." }
$queueBinding = Assert-QueueBoundEvidence -Value $evidence
if ($Stage -eq 'implemented') {
  $validationReceiptSha = Assert-LocalValidationReceipt -Value $evidence -Label 'implemented'
  if ([string]::IsNullOrWhiteSpace([string]$evidence.implemented_at)) { throw 'implemented evidence requires implemented_at.' }
}
if ($Stage -eq 'local_validated') {
  $validationReceiptSha = Assert-LocalValidationReceipt -Value $evidence -Label 'local_validated'
  if ([string]::IsNullOrWhiteSpace([string]$evidence.validated_at) -or [string]::IsNullOrWhiteSpace([string]$evidence.validation_summary)) { throw 'local_validated evidence requires validated_at and validation_summary.' }
}
if ($Stage -eq 'deployed') {
  $validationReceiptSha = Assert-LocalValidationReceipt -Value $evidence -Label 'deployed'
  if ($null -eq $evidence.uploaded -or $null -eq $evidence.skipped -or $null -eq $evidence.failed -or [int]$evidence.uploaded -lt 0 -or [int]$evidence.skipped -lt 0 -or [int]$evidence.failed -ne 0) { throw 'deployed evidence requires non-negative uploaded/skipped and failed=0.' }
  if ([string]::IsNullOrWhiteSpace([string]$evidence.command) -or [string]::IsNullOrWhiteSpace([string]$evidence.completed_at) -or [string]::IsNullOrWhiteSpace([string]$evidence.target_host)) { throw 'deployed evidence requires command, completed_at, and target_host.' }
  if (([string]$evidence.target_host).Trim().ToLowerInvariant() -ne 'online.hong-sen.com') { throw 'deployed target_host must be online.hong-sen.com.' }
  $deploymentManifest = Assert-DeploymentManifestEvidence -Value $evidence.deployment_manifest -Binding $queueBinding
}
if ($Stage -eq 'live_verified') {
  $liveVerificationManifest = Assert-LiveVerificationManifestEvidence -Value $evidence.live_verification_manifest -Binding $queueBinding
  $checks = @($evidence.checks)
  $requiredChecks = @('http', 'canonical', 'json_ld', 'sitemap', 'redirects')
  foreach ($requiredCheck in $requiredChecks) {
    $matches = @($checks | Where-Object { ([string]$_.name).ToLowerInvariant() -eq $requiredCheck })
    if ($matches.Count -ne 1 -or ([string]$matches[0].status).ToLowerInvariant() -ne 'passed' -or [string]::IsNullOrWhiteSpace([string]$matches[0].evidence)) { throw "live_verified requires one passed '$requiredCheck' check with evidence." }
  }
  if ([string]::IsNullOrWhiteSpace([string]$evidence.verified_at) -or ([string]$evidence.host).Trim().ToLowerInvariant() -ne 'online.hong-sen.com') { throw 'live_verified requires verified_at and host=online.hong-sen.com.' }
}
if ($Stage -eq 'observing_7d') {
  $through = [datetime]::MinValue
  if (-not [datetime]::TryParse([string]$evidence.observed_through_date, [ref]$through)) { throw 'observing_7d evidence requires observed_through_date.' }
  $deployedAt = [datetime]::Parse([string]$state.deployed_at)
  if ($through.Date -lt $deployedAt.Date.AddDays(7)) { throw 'observing_7d requires seven complete days after deployed_at.' }
  $manifest = Assert-GscManifestEvidence -Value $evidence.gsc_manifest -Window '7d'
  if ([string]$manifest.end_date -ne $through.ToString('yyyy-MM-dd')) { throw 'observing_7d observed_through_date must equal the bound GSC manifest end_date.' }
}
if ($Stage -eq 'reviewed_28d') {
  $gscEnd = [datetime]::MinValue
  if (-not [datetime]::TryParse([string]$evidence.gsc_end_date, [ref]$gscEnd)) { throw 'reviewed_28d evidence requires gsc_end_date.' }
  $deployedAt = [datetime]::Parse([string]$state.deployed_at)
  if ($gscEnd.Date -lt $deployedAt.Date.AddDays(28)) { throw 'reviewed_28d requires a complete 28-day post-deploy window.' }
  $manifest = Assert-GscManifestEvidence -Value $evidence.gsc_manifest -Window '28d'
  if ([string]$manifest.end_date -ne $gscEnd.ToString('yyyy-MM-dd')) { throw 'reviewed_28d gsc_end_date must equal the bound GSC manifest end_date.' }
  if ([string]$evidence.decision -notin @('keep', 'refine', 'expand', 'replace')) { throw 'reviewed_28d requires decision=keep/refine/expand/replace.' }
}
if ($Stage -eq 'completed') {
  if ([string]$evidence.decision -notin @('keep', 'refine', 'expand', 'replace') -or [string]::IsNullOrWhiteSpace([string]$evidence.summary)) { throw 'completed requires decision=keep/refine/expand/replace and a non-empty summary.' }
}

$now = (Get-Date).ToUniversalTime().ToString('o')
$targetPages = @($queue.rounds | ForEach-Object { @($_.targets) } | Select-Object -Unique)
$history = if (Test-Path -LiteralPath $lifecyclePath) { Get-Content -LiteralPath $lifecyclePath -Raw -Encoding UTF8 | ConvertFrom-Json } else { [pscustomobject]@{ schema_version = 2; queue_id = $state.queue_id; cycle_key = $state.cycle_key; target_pages = $targetPages; snapshot = $state.snapshot; registry = $state.registry; action_history = $state.action_history; stages = @() } }
if ([string]$history.queue_id -ne [string]$state.queue_id -or [string]$history.cycle_key -ne [string]$state.cycle_key) {
  $archiveDir = Join-Path $weeklyRoot 'history\curtain-online\lifecycle-receipts'
  [System.IO.Directory]::CreateDirectory($archiveDir) | Out-Null
  $archiveName = (([string]$history.queue_id + '__' + [string]$history.cycle_key) -replace '[^A-Za-z0-9._-]', '_') + '.json'
  $archivePath = Join-Path $archiveDir $archiveName
  if (-not (Test-Path -LiteralPath $archivePath -PathType Leaf)) {
    [System.IO.File]::WriteAllText($archivePath, (($history | ConvertTo-Json -Depth 20) + [Environment]::NewLine), [System.Text.UTF8Encoding]::new($false))
  }
  $history = [pscustomobject]@{ schema_version = 2; queue_id = $state.queue_id; cycle_key = $state.cycle_key; target_pages = $targetPages; snapshot = $state.snapshot; registry = $state.registry; action_history = $state.action_history; stages = @() }
}
$history.stages = @($history.stages) + @([pscustomobject]@{ stage = $Stage; recorded_at = $now; queue_id = $state.queue_id; cycle_key = $state.cycle_key; binding = $queueBinding; evidence = $evidence })
if ($history.PSObject.Properties.Name -contains 'updated_at') { $history.updated_at = $now } else { $history | Add-Member -NotePropertyName updated_at -NotePropertyValue $now }
$json = $history | ConvertTo-Json -Depth 20
$null = $json | ConvertFrom-Json
$state.status = $Stage
if ($state.PSObject.Properties.Name -contains 'lifecycle_receipt_path') { $state.lifecycle_receipt_path = 'latest/seo-geo-lifecycle-receipt.json' } else { $state | Add-Member -NotePropertyName lifecycle_receipt_path -NotePropertyValue 'latest/seo-geo-lifecycle-receipt.json' }
if ($state.PSObject.Properties.Name -contains ($Stage + '_at')) { $state.($Stage + '_at') = $now } else { $state | Add-Member -NotePropertyName ($Stage + '_at') -NotePropertyValue $now }
if ($Stage -eq 'deployed') { $state.deployed_at = $now }
if ($Stage -eq 'deployed') { $state | Add-Member -Force -NotePropertyName deployment_manifest_path -NotePropertyValue ([string]$deploymentManifest.path) }
if ($Stage -eq 'live_verified') { $state | Add-Member -Force -NotePropertyName live_verification_manifest_path -NotePropertyValue ([string]$liveVerificationManifest.path) }
$stateJson = $state | ConvertTo-Json -Depth 20
$null = $stateJson | ConvertFrom-Json
Write-LifecycleAndStateTransaction -LifecycleJson $json -StateJson $stateJson
Write-Output "Lifecycle receipt recorded: $Stage"
