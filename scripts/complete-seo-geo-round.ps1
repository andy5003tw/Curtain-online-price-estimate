[CmdletBinding()]
param(
  [Parameter(Mandatory = $true)][string]$RuntimeRoot
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Get-Sha256([string]$Path) {
  (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()
}

function Write-JsonAtomic([string]$Path, [object]$Value) {
  $text = $Value | ConvertTo-Json -Depth 30
  $null = $text | ConvertFrom-Json
  $temp = "$Path.tmp.$([guid]::NewGuid().ToString('N'))"
  try {
    [System.IO.File]::WriteAllText($temp, $text + [Environment]::NewLine, [System.Text.UTF8Encoding]::new($false))
    [System.IO.File]::Move($temp, $Path, $true)
  } finally {
    if (Test-Path -LiteralPath $temp) { Remove-Item -LiteralPath $temp -Force -ErrorAction SilentlyContinue }
  }
}

function Assert-SameSet([object[]]$Actual, [object[]]$Expected, [string]$Label) {
  $a = @($Actual | ForEach-Object { ([string]$_).Trim() } | Where-Object { $_ } | Sort-Object -Unique)
  $b = @($Expected | ForEach-Object { ([string]$_).Trim() } | Where-Object { $_ } | Sort-Object -Unique)
  if ($a.Count -ne $b.Count -or @($a | Where-Object { $_ -notin $b }).Count -gt 0) {
    throw "$Label does not match."
  }
}

$root = (Resolve-Path -LiteralPath $RuntimeRoot).Path
$weeklyRoot = if (Test-Path -LiteralPath (Join-Path $root 'latest\seo-geo-action-queue-state.json')) { $root } elseif (Test-Path -LiteralPath (Join-Path $root 'Weekly SOP\latest\seo-geo-action-queue-state.json')) { Join-Path $root 'Weekly SOP' } else { throw "Queue state not found under RuntimeRoot: $root" }
$statePath = Join-Path $weeklyRoot 'latest\seo-geo-action-queue-state.json'
$queuePath = Join-Path $weeklyRoot 'latest\seo-geo-action-queue.json'
$receiptPath = Join-Path $weeklyRoot 'latest\seo-geo-validation-receipt.json'
$registryPath = Join-Path $weeklyRoot 'config\target-registry.json'
$historyPath = Join-Path $weeklyRoot 'history\curtain-online\seo-geo-action-history.json'

foreach ($path in @($statePath, $queuePath, $receiptPath, $registryPath, $historyPath)) {
  if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw "Required file is missing: $path" }
}

$state = Get-Content -LiteralPath $statePath -Raw -Encoding UTF8 | ConvertFrom-Json
$queue = Get-Content -LiteralPath $queuePath -Raw -Encoding UTF8 | ConvertFrom-Json
$receipt = Get-Content -LiteralPath $receiptPath -Raw -Encoding UTF8 | ConvertFrom-Json
$registry = Get-Content -LiteralPath $registryPath -Raw -Encoding UTF8 | ConvertFrom-Json
$history = Get-Content -LiteralPath $historyPath -Raw -Encoding UTF8 | ConvertFrom-Json

if ([int]$state.schema_version -ne 2 -or [int]$queue.schema_version -ne 2 -or [string]$state.status -ne 'active' -or [string]$queue.status -ne 'active') { throw 'Queue and state must both be active schema_version=2.' }
if ([string]$state.queue_id -ne [string]$queue.queue_id -or [string]$state.cycle_key -ne [string]$queue.cycle_key) { throw 'Queue/state identity mismatch.' }
$round = [int]$state.active_round
$stateRound = @($state.rounds | Where-Object { [int]$_.round -eq $round } | Select-Object -First 1)[0]
$queueRound = @($queue.rounds | Where-Object { [int]$_.round -eq $round } | Select-Object -First 1)[0]
if ($null -eq $stateRound -or $null -eq $queueRound) { throw "Active Round $round is missing." }

$actionIds = @($queueRound.action_ids)
Assert-SameSet -Actual $actionIds -Expected @($stateRound.action_ids) -Label 'Round action_ids'
if ([string]$receipt.status -ne 'passed' -or [int]$receipt.round -ne $round -or [string]$receipt.queue_id -ne [string]$state.queue_id -or [string]$receipt.cycle_key -ne [string]$state.cycle_key) { throw 'Validation receipt is not bound to the active queue round.' }
Assert-SameSet -Actual @($receipt.action_ids) -Expected $actionIds -Label 'Receipt action_ids'
if ([string]$receipt.result -notin @('implemented', 'no_change_verified')) { throw 'Validation receipt result is invalid.' }

$requiredCommands = @('node .agents/skills/curtain-online-seo-geo/scripts/keyword-owner-check.mjs', 'npm.cmd run build', 'npm.cmd run seo:check', 'npm.cmd run seo:preflight')
Assert-SameSet -Actual @($receipt.validation_results | ForEach-Object { if ([string]$_.status -ne 'passed' -or [int]$_.exit_code -ne 0) { throw "Validation did not pass: $($_.command)" }; $_.command }) -Expected $requiredCommands -Label 'Validation commands'

if ([string]$state.registry.sha256 -ne (Get-Sha256 $registryPath)) { throw 'Current target registry does not match the queue binding.' }
if ([string]$state.action_history.sha256 -ne (Get-Sha256 $historyPath)) { throw 'Current action history does not match the queue binding.' }
if ([int]$registry.schemaVersion -ne [int]$state.registry.version -or [int]$history.schema_version -ne 1) { throw 'Registry or action-history schema is invalid.' }

$now = (Get-Date).ToUniversalTime().ToString('o')
$localDate = (Get-Date).ToString('yyyy-MM-dd')
[object[]]$existing = @()
if ($history.PSObject.Properties.Name -contains 'actions') { $existing = @($history.actions) }
foreach ($actionId in $actionIds) {
  $action = @($queueRound.actions | Where-Object { [string]$_.action_id -eq [string]$actionId } | Select-Object -First 1)[0]
  $receiptFingerprint = @($receipt.action_fingerprints | Where-Object { [string]$_.action_id -eq [string]$actionId } | Select-Object -First 1)[0]
  $clusterId = if ($action.PSObject.Properties.Name -contains 'cluster_id') { [string]$action.cluster_id } else { [string]$action.clusterId }
  if ($null -eq $action -or $null -eq $receiptFingerprint -or [string]::IsNullOrWhiteSpace($clusterId) -or [string]::IsNullOrWhiteSpace([string]$action.page) -or ([string]$action.fingerprint).ToLowerInvariant() -ne ([string]$receiptFingerprint.fingerprint).ToLowerInvariant()) { throw "Action contract is incomplete: $actionId" }
  $keyMatches = @($existing | Where-Object { [string]$_.queue_id -eq [string]$state.queue_id -and [string]$_.cycle_key -eq [string]$state.cycle_key -and [int]$_.round -eq $round -and [string]$_.action_id -eq [string]$actionId })
  if ($keyMatches.Count -gt 0) { throw "Action history already contains this queue-bound Round: $actionId" }
  $target = @($registry.targets | Where-Object { [string]$_.clusterId -eq $clusterId } | Select-Object -First 1)[0]
  if ($null -eq $target) { throw "Registry target missing for $clusterId" }
  if ([string]$receipt.result -eq 'implemented') { $target.lastChangedAt = $localDate }
  $existing += [pscustomobject][ordered]@{
    action_id = [string]$actionId
    fingerprint = ([string]$action.fingerprint).ToLowerInvariant()
    cluster_id = $clusterId
    page = [string]$action.page
    result = [string]$receipt.result
    validated_at = $now
    queue_id = [string]$state.queue_id
    cycle_key = [string]$state.cycle_key
    round = $round
  }
}

$history | Add-Member -Force -NotePropertyName actions -NotePropertyValue @($existing)
$history | Add-Member -Force -NotePropertyName updated_at -NotePropertyValue $now
if ([string]$receipt.result -eq 'implemented') { $registry.updatedAt = $localDate }
$nextRound = $round + 1
$state.completed_rounds = @($state.completed_rounds + $round | Sort-Object -Unique)
$state.active_round = $nextRound
$state.next_round = $nextRound
$state | Add-Member -Force -NotePropertyName last_validated_round -NotePropertyValue $round
$state | Add-Member -Force -NotePropertyName last_validation_receipt -NotePropertyValue 'latest/seo-geo-validation-receipt.json'
$state | Add-Member -Force -NotePropertyName last_validated_at -NotePropertyValue $now
$state.status = if ($nextRound -gt [int]$state.total_rounds) { 'awaiting_implemented_receipt' } else { 'active' }
if ($state.status -eq 'awaiting_implemented_receipt') { $state | Add-Member -Force -NotePropertyName implementation_pending_at -NotePropertyValue $now }

# The durable history and registry are prerequisites: write them before state
# records the Round as complete, matching the UI transition order.
Write-JsonAtomic -Path $historyPath -Value $history
Write-JsonAtomic -Path $registryPath -Value $registry
Write-JsonAtomic -Path $statePath -Value $state
Write-Output "Round $round completed; state=$($state.status)"
