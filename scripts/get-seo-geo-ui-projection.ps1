[CmdletBinding()]
param(
  [Parameter(Mandatory = $true)][string]$RuntimeRoot
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

function Get-Health([string]$WeeklyRoot) {
  $required = @('get-seo-geo-effective-workflow.ps1','get-seo-geo-ui-projection.ps1','invoke-seo-geo-autodeploy.ps1')
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
  $effectiveScript = Join-Path $PSScriptRoot 'get-seo-geo-effective-workflow.ps1'
  $workflow = (& $effectiveScript -RuntimeRoot $weeklyRoot | ConvertFrom-Json)
  $state = Read-Json (Join-Path $latestRoot 'seo-geo-action-queue-state.json')
  $queue = Read-Json (Join-Path $latestRoot 'seo-geo-action-queue.json')
  $validation = Read-Json (Join-Path $latestRoot 'seo-geo-validation-receipt.json')
  $status = [string]$workflow.effective.status
  $consistent = [bool]$workflow.consistency.valid
  $validationReason = Test-ValidationReceipt $validation $workflow

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
  $actions.RUN_AI_VISIBILITY = New-Action '執行每月 AI Visibility' $true '選用操作，不影響正式 GSC baseline。'
  $actions.RUN_LUNA_COMPARISON = New-Action '執行 Luna 對照' $true '選用操作，不影響正式 GSC baseline。'
  $actions.ANALYZE_GSC_GENERATIVE_AI = New-Action '分析 GSC 生成式 AI Excel' $true '選用操作，不影響正式 GSC baseline。'

  $primaryId = 'GENERATE_PLAN'
  if (-not $consistent) {
    $reason = 'Workflow consistency 未通過：' + (@($workflow.consistency.reasons) -join '；')
    $primaryId = 'NONE'
  } elseif ($status -eq 'observation_only') {
    $primaryId = 'GENERATE_PLAN'
    $actions.GENERATE_PLAN = New-Action '更新／開啟 SEO/GEO 行動報告' $true '目前為 observation-only；需新的 decision-ready GSC snapshot。'
  } elseif ($status -eq 'active') {
    $activeRound = if ($state -and $state.PSObject.Properties.Name -contains 'active_round') { [int]$state.active_round } elseif ($state -and $state.PSObject.Properties.Name -contains 'next_round') { [int]$state.next_round } else { 1 }
    $totalRounds = if ($state -and $state.PSObject.Properties.Name -contains 'total_rounds') { [int]$state.total_rounds } else { 0 }
    if ($validationReason) {
      $primaryId = 'COPY_ROUND_PROMPT'
      $actions.COPY_ROUND_PROMPT = New-Action '複製本輪 AI 工作指令' $true ("Round {0}/{1}；{2}" -f $activeRound, $totalRounds, $validationReason)
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
      data_trust = [ordered]@{ consistent = $consistent; reasons = @($workflow.consistency.reasons); validation = if ($validationReason) { $validationReason } else { 'validation receipt 已通過。' } }
      queue = [ordered]@{ status = $workflow.approved_queue.status; rounds = $workflow.approved_queue.round_count; action_ids = @($workflow.approved_queue.action_ids) }
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
