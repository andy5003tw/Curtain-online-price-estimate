[CmdletBinding()]
param(
  [Parameter(Mandatory = $true)][string]$RuntimeRoot
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Read-Json {
  param([Parameter(Mandatory = $true)][string]$Path)
  if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { return $null }
  return Get-Content -LiteralPath $Path -Raw -Encoding UTF8 | ConvertFrom-Json
}

function Get-StringSet {
  param([object[]]$Values)
  return @($Values | ForEach-Object { ([string]$_).Trim() } | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Sort-Object -Unique)
}

function Test-SameSet {
  param([object[]]$Left, [object[]]$Right)
  $a = @(Get-StringSet -Values $Left)
  $b = @(Get-StringSet -Values $Right)
  return $a.Count -eq $b.Count -and @($a | Where-Object { $_ -notin $b }).Count -eq 0
}

function Get-NextRequirement {
  param([string]$Status)
  $requirements = @{
    observation_only = '等待新的 decision-ready GSC snapshot；不可建立或前進 Round。'
    active = '完成目前 Round、必要本機驗證與 queue-bound validation receipt。'
    awaiting_implemented_receipt = '寫入 queue-bound implemented lifecycle receipt。'
    implemented = '寫入 queue-bound local_validated lifecycle receipt。'
    local_validated = '執行已授權部署並以 deploy evidence 寫入 deployed receipt。'
    deployed = '完成 HTTP、canonical、JSON-LD、sitemap、redirect 驗證並寫入 live_verified receipt。'
    live_verified = '等待部署後七個完整資料日與對應 decision-ready 7d manifest，再寫入 observing_7d。'
    observing_7d = '等待部署後二十八個完整資料日與對應 decision-ready 28d manifest，決策後寫入 reviewed_28d。'
    reviewed_28d = '以 keep/refine/expand/replace 與摘要寫入 completed。'
    completed = 'Cycle 已完成；等待下一個 decision-ready strategy snapshot。'
  }
  if ($requirements.ContainsKey($Status)) { return $requirements[$Status] }
  return '狀態無法辨識；阻擋後續操作。'
}

$root = (Resolve-Path -LiteralPath $RuntimeRoot).Path
$weeklyRoot = if (Test-Path -LiteralPath (Join-Path $root 'latest\seo-geo-action-queue-state.json')) { $root } elseif (Test-Path -LiteralPath (Join-Path $root 'Weekly SOP\latest\seo-geo-action-queue-state.json')) { Join-Path $root 'Weekly SOP' } else { throw "Queue state not found under RuntimeRoot: $root" }
$latestRoot = Join-Path $weeklyRoot 'latest'
$plan = Read-Json -Path (Join-Path $latestRoot 'seo-geo-action-plan.json')
$queue = Read-Json -Path (Join-Path $latestRoot 'seo-geo-action-queue.json')
$state = Read-Json -Path (Join-Path $latestRoot 'seo-geo-action-queue-state.json')
$approval = Read-Json -Path (Join-Path $latestRoot 'seo-geo-single-page-approval.json')
$lifecycle = Read-Json -Path (Join-Path $latestRoot 'seo-geo-lifecycle-receipt.json')
$reasons = @()

if (-not $plan) { $reasons += 'strategy_snapshot_missing' }
if (-not $queue) { $reasons += 'approved_queue_missing' }
if (-not $state) { $reasons += 'lifecycle_state_missing' }
if ($queue -and $state -and ([string]$queue.queue_id -ne [string]$state.queue_id -or [string]$queue.cycle_key -ne [string]$state.cycle_key)) { $reasons += 'queue_state_identity_mismatch' }
if ($plan -and $queue -and (([string]$plan.queue_id -and [string]$plan.queue_id -ne [string]$queue.queue_id) -or ([string]$plan.cycle_key -and [string]$plan.cycle_key -ne [string]$queue.cycle_key))) { $reasons += 'plan_queue_identity_mismatch' }

[string[]]$queueActionIds = @()
if ($queue) {
  $queueActionIds = @((Get-StringSet -Values @($queue.rounds | ForEach-Object { @($_.action_ids) })))
}
$isApprovedOverride = $plan -and $queue -and [string]$plan.workflow_status -eq 'observation_only' -and [string]$queue.status -eq 'active' -and $queueActionIds.Count -gt 0
if ($isApprovedOverride) {
  if (-not $approval -or [string]$approval.status -ne 'approved' -or [string]$approval.queue_id -ne [string]$queue.queue_id -or [string]$approval.cycle_key -ne [string]$queue.cycle_key -or [string]$approval.action_id -notin $queueActionIds) {
    $reasons += 'approved_override_receipt_invalid'
  }
}

$knownStates = @('observation_only','active','awaiting_implemented_receipt','implemented','local_validated','deployed','live_verified','observing_7d','reviewed_28d','completed')
$effectiveStatus = if ($state) { [string]$state.status } else { 'inconsistent' }
if ($effectiveStatus -notin $knownStates) { $reasons += 'lifecycle_state_invalid' }
$preconditionGates = if ($state -and $state.PSObject.Properties.Name -contains 'precondition_gates') { $state.precondition_gates } else { $null }
if ($effectiveStatus -notin @('observation_only','active') -and (-not $preconditionGates -or [string]$preconditionGates.data_validated.status -notin @('passed','validated') -or [string]$preconditionGates.strategy_approved.status -notin @('passed','approved'))) {
  $reasons += 'precondition_gates_invalid'
}
$requiresLifecycleReceipt = $effectiveStatus -in @('implemented','local_validated','deployed','live_verified','observing_7d','reviewed_28d','completed')
if ($requiresLifecycleReceipt) {
  $stages = if ($lifecycle) { @($lifecycle.stages) } else { @() }
  $latestStage = if ($stages.Count) { $stages[-1] } else { $null }
  if (-not $latestStage -or [string]$lifecycle.queue_id -ne [string]$state.queue_id -or [string]$lifecycle.cycle_key -ne [string]$state.cycle_key -or [string]$latestStage.stage -ne $effectiveStatus -or -not (Test-SameSet -Left @($latestStage.evidence.action_ids) -Right $queueActionIds)) {
    $reasons += 'lifecycle_receipt_state_mismatch'
  }
}

$strategyStatus = if ($plan) { [string]$plan.workflow_status } else { 'missing' }
$effectiveSource = if ($reasons.Count) { 'inconsistent' } elseif ($requiresLifecycleReceipt) { 'lifecycle_state' } elseif ($isApprovedOverride) { 'approved_queue' } else { 'strategy_snapshot' }
if ($reasons.Count) { $effectiveStatus = 'inconsistent' }

[ordered]@{
  schema_version = 1
  generated_at = (Get-Date).ToUniversalTime().ToString('o')
  identity = [ordered]@{
    queue_id = if ($state) { [string]$state.queue_id } elseif ($queue) { [string]$queue.queue_id } else { $null }
    cycle_key = if ($state) { [string]$state.cycle_key } elseif ($queue) { [string]$queue.cycle_key } else { $null }
  }
  roles = [ordered]@{
    strategy_snapshot = 'immutable data/strategy snapshot; never rewritten by approval, implementation, deployment, or lifecycle receipts'
    approved_queue = 'approved execution contract; may be a single-page override of an observation_only strategy snapshot'
    lifecycle_state = 'authoritative current execution stage; may advance only through queue-bound receipts'
    precondition_gates = 'data_validated and strategy_approved are gates before Round advancement; they are not lifecycle stages'
  }
  strategy_snapshot = [ordered]@{
    status = $strategyStatus
    generated_at = if ($plan) { [string]$plan.generated_at } else { $null }
    queue_round_count = if ($plan) { [int]$plan.queue_round_count } else { $null }
  }
  approved_queue = [ordered]@{
    status = if ($queue) { [string]$queue.status } else { 'missing' }
    round_count = if ($queue) { @($queue.rounds).Count } else { 0 }
    action_ids = $queueActionIds
    approved_override = $isApprovedOverride
    approval_receipt_path = if ($approval) { 'latest/seo-geo-single-page-approval.json' } else { $null }
  }
  lifecycle = [ordered]@{
    status = if ($state) { [string]$state.status } else { 'missing' }
    completed_rounds = if ($state) { @($state.completed_rounds) } else { @() }
    receipt_path = if ($lifecycle) { 'latest/seo-geo-lifecycle-receipt.json' } else { $null }
    latest_stage = if ($lifecycle -and @($lifecycle.stages).Count) { [string]$lifecycle.stages[-1].stage } else { $null }
  }
  precondition_gates = [ordered]@{
    data_validated = if ($preconditionGates) { $preconditionGates.data_validated } else { $null }
    strategy_approved = if ($preconditionGates) { $preconditionGates.strategy_approved } else { $null }
  }
  effective = [ordered]@{
    status = $effectiveStatus
    source = $effectiveSource
    next_requirement = Get-NextRequirement -Status $effectiveStatus
  }
  consistency = [ordered]@{
    valid = ($reasons.Count -eq 0)
    reasons = @($reasons)
  }
} | ConvertTo-Json -Depth 12 -Compress
