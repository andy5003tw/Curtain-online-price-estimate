[CmdletBinding()]
param(
  [Parameter(Mandatory = $true)][string]$RuntimeRoot,
  [string]$RepoRoot = ''
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Read-Json([string]$Path) {
  if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { return $null }
  Get-Content -LiteralPath $Path -Raw -Encoding UTF8 | ConvertFrom-Json
}

function New-Action([string]$Label, [bool]$Enabled, [string]$Reason) {
  [ordered]@{ label = $Label; enabled = $Enabled; reason = $Reason }
}

function Test-ValidationReceipt([object]$Receipt, [object]$Workflow) {
  if (-not $Receipt) { return '尚未建立 validation receipt。' }
  if ([string]$Receipt.status -ne 'passed') { return 'validation receipt 尚未通過。' }
  if ([string]$Receipt.queue_id -ne [string]$Workflow.identity.queue_id -or [string]$Receipt.cycle_key -ne [string]$Workflow.identity.cycle_key) { return 'validation receipt 不屬於目前 queue／cycle。' }
  return ''
}

function Get-ActiveRoundGate([string]$WeeklyRoot, [object]$Workflow, [int]$Round) {
  $gateScript = Join-Path $PSScriptRoot 'seo-geo-round-gate.mjs'
  if (-not (Test-Path -LiteralPath $gateScript -PathType Leaf)) { throw 'Round receipt gate script is missing.' }
  $output = @(& node $gateScript --runtime-root $WeeklyRoot 2>&1)
  if ($LASTEXITCODE -ne 0) { throw 'Round receipt gate could not read its input.' }
  $gate = ($output -join [Environment]::NewLine) | ConvertFrom-Json -ErrorAction Stop
  if (-not $gate -or [int]$gate.schema_version -ne 1 -or [string]$gate.health -ne 'ok' -or $gate.passed -isnot [bool] -or [string]::IsNullOrWhiteSpace([string]$gate.reason) -or [int]$gate.round -ne $Round -or [string]$gate.queue_id -ne [string]$Workflow.identity.queue_id -or [string]$gate.cycle_key -ne [string]$Workflow.identity.cycle_key) { throw 'Round receipt gate result does not match the current queue and round.' }
  return $gate
}

function Test-ContainsRound([object[]]$Values, [int]$Round) {
  foreach ($value in $Values) {
    $number = 0.0
    if ([double]::TryParse([string]$value, [ref]$number) -and $number -eq $Round) { return $true }
  }
  return $false
}

function Get-Health([string]$WeeklyRoot) {
  $required = @('get-seo-geo-effective-workflow.ps1','get-seo-geo-ui-projection.ps1','check-seo-geo-queue-provenance.ps1','seo-geo-round-gate.mjs','invoke-seo-geo-autodeploy.ps1')
  $missing = @($required | Where-Object { -not (Test-Path -LiteralPath (Join-Path $PSScriptRoot $_) -PathType Leaf) })
  [ordered]@{
    pwsh = [ordered]@{ available = $true; version = $PSVersionTable.PSVersion.ToString() }
    scripts = [ordered]@{ healthy = ($missing.Count -eq 0); missing = $missing }
    runtime_root = $WeeklyRoot
  }
}

try {
  $root = (Resolve-Path -LiteralPath $RuntimeRoot).Path
  $weeklyRoot = if (Test-Path -LiteralPath (Join-Path $root 'latest\seo-geo-action-queue-state.json')) { $root } elseif (Test-Path -LiteralPath (Join-Path $root 'Weekly SOP\latest\seo-geo-action-queue-state.json')) { Join-Path $root 'Weekly SOP' } else { throw "Queue state not found under RuntimeRoot: $root" }
  $latestRoot = Join-Path $weeklyRoot 'latest'
  $resolvedRepoRoot = if ($RepoRoot) { (Resolve-Path -LiteralPath $RepoRoot).Path } else { Split-Path -Parent $weeklyRoot }
  $effectiveScript = Join-Path $PSScriptRoot 'get-seo-geo-effective-workflow.ps1'
  $workflow = (& $effectiveScript -RuntimeRoot $weeklyRoot | ConvertFrom-Json)
  $state = Read-Json (Join-Path $latestRoot 'seo-geo-action-queue-state.json')
  $queue = Read-Json (Join-Path $latestRoot 'seo-geo-action-queue.json')
  $validation = Read-Json (Join-Path $latestRoot 'seo-geo-validation-receipt.json')
  $status = [string]$workflow.effective.status
  $consistent = [bool]$workflow.consistency.valid
  $consistencyReasons = @($workflow.consistency.reasons)
  $validationReason = Test-ValidationReceipt $validation $workflow

  if ($consistent -and (-not $state -or -not $queue -or [string]$state.queue_id -ne [string]$workflow.identity.queue_id -or [string]$state.cycle_key -ne [string]$workflow.identity.cycle_key -or [string]$state.status -ne $status -or [string]$queue.queue_id -ne [string]$state.queue_id -or [string]$queue.cycle_key -ne [string]$state.cycle_key)) {
    $consistent = $false
    $consistencyReasons += 'queue_state_changed_during_projection'
  }

  try {
    $provenanceScript = Join-Path $PSScriptRoot 'check-seo-geo-queue-provenance.ps1'
    if (-not (Test-Path -LiteralPath $provenanceScript -PathType Leaf)) { throw 'Queue provenance checker is missing.' }
    $provenance = (& $provenanceScript -RuntimeRoot $weeklyRoot -RepoRoot $resolvedRepoRoot | ConvertFrom-Json -ErrorAction Stop)
    if (-not $provenance -or $provenance.PSObject.Properties.Name -notcontains 'stale') { throw 'Queue provenance result is invalid.' }
    if ([bool]$provenance.stale) {
      $consistent = $false
      $consistencyReasons += @($provenance.reasons)
    }
  } catch {
    $consistent = $false
    $consistencyReasons += 'provenance_check_failed:' + $_.Exception.Message
  }
  $activeRound = if ($state -and $state.PSObject.Properties.Name -contains 'active_round' -and [int]$state.active_round -ne 0) { [int]$state.active_round } elseif ($state -and $state.PSObject.Properties.Name -contains 'next_round' -and [int]$state.next_round -ne 0) { [int]$state.next_round } else { 1 }
  $totalRounds = if ($state -and $state.PSObject.Properties.Name -contains 'total_rounds' -and [int]$state.total_rounds -ne 0) { [int]$state.total_rounds } elseif ($state -and $state.PSObject.Properties.Name -contains 'prompt_files' -and $null -ne $state.prompt_files) { @($state.prompt_files).Count } else { 0 }
  $isObservation = $status -eq 'observation_only'
  $isAwaitingImplemented = $status -eq 'awaiting_implemented_receipt'
  $isLocalValidated = $status -in @('awaiting_implemented_receipt','implemented','local_validated','deployed','live_verified','observing_7d','reviewed_28d','completed')
  $copiedRounds = if ($state -and $state.PSObject.Properties.Name -contains 'copied_rounds') { @($state.copied_rounds) } else { @() }
  $completedRounds = if ($state -and $state.PSObject.Properties.Name -contains 'completed_rounds') { @($state.completed_rounds) } else { @() }
  $isCopiedPending = -not $isObservation -and -not $isLocalValidated -and (Test-ContainsRound $copiedRounds $activeRound) -and -not (Test-ContainsRound $completedRounds $activeRound)
  # Send the queue panel and its action consumers one coherent, compact view
  # of the state/queue objects used for this projection.
  $stateSnapshot = if ($state) { $state | Select-Object queue_id,cycle_key,status,generated_at,active_round,next_round,total_rounds,completed_rounds,copied_rounds,prompt_files } else { $null }
  $queueSnapshot = if ($queue) { $queue | Select-Object rounds,technical_tasks,optional_opportunities } else { $null }
  $roundGate = [ordered]@{ passed = $false; reason = if ($status -eq 'observation_only') { 'observation_only 不需執行 Round' } else { '本輪已完成本機驗證' }; round = $activeRound }
  if ($status -eq 'active' -and -not $consistent) { $roundGate.reason = '流程資料不一致，無法驗證 Round receipt。' }
  if ($status -eq 'active' -and $consistent) {
    try {
      if ($activeRound -lt 1 -or $activeRound -gt $totalRounds) { throw 'Active Round is outside the queue range.' }
      $roundGate = Get-ActiveRoundGate $weeklyRoot $workflow $activeRound
    }
    catch {
      $consistent = $false
      $consistencyReasons += 'round_gate_failed:' + $_.Exception.Message
      $roundGate = [ordered]@{ passed = $false; reason = 'Round receipt gate 無法讀取；已停止操作。'; round = $activeRound }
    }
  }

  $actions = [ordered]@{}
  $actions.FETCH_GSC = New-Action '更新最新 GSC 資料' $true '重新匯入資料後會重新建立 projection。'
  $actions.GENERATE_PLAN = New-Action '產生 SEO/GEO 優化建議' $false '等待目前資料可信度與 workflow 狀態確認。'
  $actions.OPEN_PLAN = New-Action '查看目前 SEO/GEO 優化報表' (Test-Path -LiteralPath (Join-Path $latestRoot 'seo-geo-action-plan.html')) '此操作唯讀，不會變更 workflow。'
  $actions.COPY_ROUND_PROMPT = New-Action '複製本輪 AI 工作指令' $false '沒有可複製的 active Round。'
  $actions.ADVANCE_ROUND = New-Action '驗證通過並前進' $false '等待 queue-bound validation receipt。'
  $actions.APPROVE_SINGLE_PAGE = New-Action '核准單頁優化並建立 Round' $false '目前沒有可核准的單頁 review。'
  $actions.DEPLOY_DRY_RUN = New-Action '部署預演（不實際上傳）' $false '只可在 local_validated 後使用。'
  $actions.DEPLOY = New-Action '正式上傳' $false '請使用受保護的一鍵部署流程。'
  $actions.AUTO_DEPLOY = New-Action '開始自動部署至上線驗證' $false '只可在 local_validated、資料一致且 FTP 設定完整時使用。'
  $actions.LIVE_VERIFY = New-Action '驗證網站已正確上線' $false '等待 deployment manifest。'
  $actions.ADVANCE_LIFECYCLE = New-Action '記錄下一 lifecycle evidence' $false '等待必要 evidence。'
  $primaryId = 'GENERATE_PLAN'
  if (-not $consistent) {
    $reason = 'Workflow consistency 未通過：' + ($consistencyReasons -join '；')
    $primaryId = 'NONE'
  } elseif ($status -eq 'observation_only') {
    $primaryId = 'GENERATE_PLAN'
    $actions.GENERATE_PLAN = New-Action '更新／開啟 SEO/GEO 行動報告' $true '目前為 observation-only；需新的 decision-ready GSC snapshot。'
  } elseif ($status -eq 'active') {
    if (-not [bool]$roundGate.passed) {
      $primaryId = 'COPY_ROUND_PROMPT'
      $actions.COPY_ROUND_PROMPT = New-Action '複製本輪 AI 工作指令' $true ("Round {0}/{1}；{2}" -f $activeRound, $totalRounds, $roundGate.reason)
    } else {
      $primaryId = 'ADVANCE_ROUND'
      $actions.ADVANCE_ROUND = New-Action '驗證通過並前進' $true 'validation receipt 已通過；writer 會再次驗證後才前進。'
    }
  } elseif ($status -eq 'local_validated') {
    $planReason = ''
    try {
      $deployPlan = (& (Join-Path $PSScriptRoot 'new-seo-geo-deploy-plan.ps1') -RuntimeRoot $weeklyRoot -Mode Inspect | ConvertFrom-Json)
      if (-not [bool]$deployPlan.preflight.passed -or [string]$deployPlan.status -ne 'ready') { $planReason = (@($deployPlan.preflight.reasons) | Where-Object { $_ } | Select-Object -Unique) -join '；' }
    } catch { $planReason = $_.Exception.Message }
    $hasFtpConfig = -not [string]::IsNullOrWhiteSpace([string]$env:FTP_USER) -and (-not [string]::IsNullOrWhiteSpace([string]$env:FTP_PASS) -or -not [string]::IsNullOrWhiteSpace([string]$env:FTP_PASSWORD))
    $enabled = $hasFtpConfig -and -not $validationReason -and -not $planReason
    $primaryId = 'AUTO_DEPLOY'
    $reason = if ($validationReason) { $validationReason } elseif ($planReason) { $planReason } elseif (-not $hasFtpConfig) { '缺少 FTP_USER 或 FTP_PASS。' } else { '會依序執行 dry-run、受驗證 FTP 上傳、manifest 驗證與 live verification。' }
    $actions.AUTO_DEPLOY = New-Action '開始自動部署至上線驗證' $enabled $reason
    $actions.DEPLOY_DRY_RUN = New-Action '部署預演（不實際上傳）' $enabled $reason
  } elseif ($status -eq 'deployed') {
    $primaryId = 'LIVE_VERIFY'
    $actions.LIVE_VERIFY = New-Action '驗證網站已正確上線' $true 'deployment 已記錄；尚缺 live verification。'
  } elseif ($status -in @('implemented','live_verified','observing_7d','reviewed_28d','awaiting_implemented_receipt')) {
    $inspectionScript = Join-Path $PSScriptRoot 'invoke-seo-geo-lifecycle-next.ps1'
    $inspection = (& $inspectionScript -RuntimeRoot $weeklyRoot -Mode Inspect | ConvertFrom-Json)
    $primaryId = 'ADVANCE_LIFECYCLE'
    $actions.ADVANCE_LIFECYCLE = New-Action ([string]$inspection.label) ([bool]$inspection.ready) ([string]$inspection.reason)
  } else {
    $primaryId = 'NONE'
    $reason = '目前 workflow 狀態無法辨識，已停止所有寫入型操作。'
  }

  if (-not $consistent) {
    foreach ($id in @('GENERATE_PLAN','COPY_ROUND_PROMPT','ADVANCE_ROUND','APPROVE_SINGLE_PAGE','DEPLOY_DRY_RUN','DEPLOY','AUTO_DEPLOY','LIVE_VERIFY','ADVANCE_LIFECYCLE')) {
      $actions[$id] = New-Action ([string]$actions[$id].label) $false $reason
    }
  }
  $primary = if ($primaryId -eq 'NONE') { New-Action '目前沒有可安全執行的下一步' $false $reason } else { $actions[$primaryId] }
  [ordered]@{
    schema_version = 1
    generated_at = (Get-Date).ToUniversalTime().ToString('o')
    consistent = $consistent
    state = $status
    primary_action = [ordered]@{ id = $primaryId; label = $primary.label; enabled = $primary.enabled; reason = $primary.reason }
    actions = $actions
    identity = $workflow.identity
    panels = [ordered]@{
      data_trust = [ordered]@{ consistent = $consistent; reasons = @($consistencyReasons); validation = if ($status -eq 'active') { [string]$roundGate.reason } elseif ($validationReason) { $validationReason } else { 'validation receipt 已通過。' } }
      queue = [ordered]@{
        status = $workflow.approved_queue.status; rounds = $workflow.approved_queue.round_count; action_ids = @($workflow.approved_queue.action_ids)
        active_round = $activeRound; total_rounds = $totalRounds
        is_observation = $isObservation; is_local_validated = $isLocalValidated; is_awaiting_implemented = $isAwaitingImplemented; is_copied_pending = $isCopiedPending
        state_snapshot = $stateSnapshot; queue_snapshot = $queueSnapshot
        receipt_gate = $roundGate
      }
      deployment = [ordered]@{ status = $status; next_requirement = $workflow.effective.next_requirement; auto_deploy = $actions.AUTO_DEPLOY }
      measurement = [ordered]@{ lifecycle = $workflow.lifecycle.status; next_requirement = $workflow.effective.next_requirement }
      health = Get-Health $weeklyRoot
    }
  } | ConvertTo-Json -Depth 16 -Compress -EscapeHandling EscapeNonAscii
} catch {
  [ordered]@{
    schema_version = 1; generated_at = (Get-Date).ToUniversalTime().ToString('o'); consistent = $false; state = 'projection_error'
    primary_action = [ordered]@{ id = 'NONE'; label = '流程資料讀取失敗'; enabled = $false; reason = $_.Exception.Message }
    actions = @{}; panels = [ordered]@{ health = [ordered]@{ error = $_.Exception.Message } }
  } | ConvertTo-Json -Depth 8 -Compress -EscapeHandling EscapeNonAscii
  exit 1
}
