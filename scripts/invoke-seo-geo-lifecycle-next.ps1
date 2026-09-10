[CmdletBinding()]
param(
  [Parameter(Mandatory = $true)][string]$RuntimeRoot,
  [ValidateSet('Inspect', 'Advance')][string]$Mode = 'Inspect',
  [ValidateSet('keep', 'refine', 'expand', 'replace')][string]$Decision,
  [string]$Summary = ''
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Read-Json([string]$Path) {
  if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { return $null }
  return Get-Content -LiteralPath $Path -Raw -Encoding UTF8 | ConvertFrom-Json
}

function Get-Sha256([string]$Path) {
  return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()
}

function Get-StringSet([object[]]$Values) {
  return @($Values | ForEach-Object { ([string]$_).Trim() } | Where-Object { $_ } | Sort-Object -Unique)
}

function Test-SameStringSet([object[]]$Actual, [object[]]$Expected) {
  $actualSet = @(Get-StringSet $Actual)
  $expectedSet = @(Get-StringSet $Expected)
  return $actualSet.Count -eq $expectedSet.Count -and @($actualSet | Where-Object { $_ -notin $expectedSet }).Count -eq 0
}

function New-Inspection {
  param(
    [string]$CurrentStatus,
    [string]$NextStage,
    [bool]$Ready,
    [bool]$NeedsInput,
    [string]$Label,
    [string]$Reason,
    [string]$EarliestDate = '',
    [string]$DataEndDate = ''
  )
  return [ordered]@{
    schema_version = 1
    mode = $Mode.ToLowerInvariant()
    current_status = $CurrentStatus
    next_stage = $NextStage
    ready = $Ready
    needs_input = $NeedsInput
    label = $Label
    reason = $Reason
    earliest_date = if ($EarliestDate) { $EarliestDate } else { $null }
    data_end_date = if ($DataEndDate) { $DataEndDate } else { $null }
  }
}

function Test-Binding {
  param([object]$Manifest, [object]$Context, [object[]]$ActionIds)
  if (-not $Manifest -or -not $Context) { return $false }
  return [string]$Context.queue_id -eq [string]$state.queue_id -and
    [string]$Context.cycle_key -eq [string]$state.cycle_key -and
    (Test-SameStringSet @($Context.action_ids) $ActionIds)
}

function Test-ValidationReceipt {
  if (-not (Test-Path -LiteralPath $validationPath -PathType Leaf)) { return '尚未產生 validation receipt' }
  $receipt = Read-Json $validationPath
  if (-not $receipt -or [string]$receipt.status -ne 'passed') { return 'validation receipt 尚未通過' }
  if ([string]$receipt.queue_id -ne [string]$state.queue_id -or [string]$receipt.cycle_key -ne [string]$state.cycle_key) { return 'validation receipt 屬於其他 queue／cycle' }
  $lastRound = if ($state.PSObject.Properties.Name -contains 'last_validated_round') { [int]$state.last_validated_round } else { [int]$state.total_rounds }
  $receiptActionIds = @(Get-StringSet @($queue.rounds | Where-Object { [int]$_.round -eq $lastRound } | ForEach-Object { @($_.action_ids) }))
  if ($receiptActionIds.Count -eq 0) { $receiptActionIds = $actionIds }
  if (-not (Test-SameStringSet @($receipt.action_ids) $receiptActionIds)) { return 'validation receipt 未綁定最後完成的 Round action IDs' }
  return ''
}

function Test-DeploymentManifest {
  if (-not (Test-Path -LiteralPath $deploymentPath -PathType Leaf)) { return '尚未完成正式 FTP 部署' }
  $manifest = Read-Json $deploymentPath
  if (-not $manifest -or [int]$manifest.schema_version -ne 1 -or [string]$manifest.status -ne 'success' -or [bool]$manifest.dry_run) { return '正式 deployment manifest 尚未成功' }
  if ([string]$manifest.target_host -ne 'online.hong-sen.com') { return 'deployment manifest host 不正確' }
  if (-not (Test-Binding $manifest $manifest.deployment_context $actionIds)) { return 'deployment manifest 屬於舊 queue 或 action IDs 不一致' }
  if ([int]$manifest.summary.selected -le 0 -or [int]$manifest.summary.failed -ne 0 -or ([int]$manifest.summary.uploaded + [int]$manifest.summary.skipped) -ne [int]$manifest.summary.selected) { return 'deployment manifest 上傳摘要不完整' }
  if (@($manifest.files).Count -ne [int]$manifest.summary.selected) { return 'deployment manifest 檔案數與摘要不一致' }
  return ''
}

function Get-ExpectedProductRedirects {
  $targets = @(Get-StringSet @($queue.rounds | ForEach-Object { @($_.targets) }))
  $owners = if ($queue.provenance -and $queue.provenance.registry) { @($queue.provenance.registry.owners) } else { @($queue.registry.owners) }
  return @($owners | Where-Object {
    [string]$_.cluster_id -match '^product-(P\d+)$' -and [string]$_.owner_url -in $targets
  } | ForEach-Object {
    [pscustomobject]@{ product_id = ([regex]::Match([string]$_.cluster_id, '^product-(P\d+)$')).Groups[1].Value; target_url = [string]$_.owner_url }
  })
}

function Test-LiveManifest {
  if (-not (Test-Path -LiteralPath $livePath -PathType Leaf)) { return '尚未執行 live verify' }
  $manifest = Read-Json $livePath
  if (-not $manifest -or [int]$manifest.schema_version -ne 1 -or [string]$manifest.status -ne 'passed' -or [string]$manifest.scope -ne 'queue_targets') { return 'live verification manifest 尚未通過' }
  if ([string]$manifest.host -ne 'online.hong-sen.com' -or -not (Test-Binding $manifest $manifest $actionIds)) { return 'live verification manifest 屬於舊 queue 或 host 不正確' }
  $required = @('http','title','meta_description','h1','canonical','faq_parity','json_ld','internal_links','cta','robots','sitemap')
  if (@($manifest.pages).Count -eq 0) { return 'live verification manifest 沒有 target pages' }
  foreach ($page in @($manifest.pages)) {
    foreach ($name in $required) {
      $check = @($page.checks | Where-Object { [string]$_.name -eq $name })
      if ($check.Count -ne 1 -or -not [bool]$check[0].passed) { return "live verify 未通過：$name / $($page.url)" }
    }
  }
  $expectedRedirects = @(Get-ExpectedProductRedirects)
  foreach ($expected in $expectedRedirects) {
    $redirect = @($manifest.redirect_checks | Where-Object { [string]$_.product_id -eq [string]$expected.product_id })
    if ($redirect.Count -ne 1 -or -not [bool]$redirect[0].passed -or [string]$redirect[0].target_url -ne [string]$expected.target_url) { return "舊產品網址 redirect 尚未驗證：$($expected.product_id)" }
  }
  return ''
}

function Test-GscWindow {
  param([ValidateSet('7d', '28d')][string]$Window, [datetime]$RequiredDate)
  $path = Join-Path $latestRoot "$Window\weekly-sop-last-run.json"
  if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { return [pscustomobject]@{ reason = "尚未匯入 $Window GSC manifest"; manifest = $null; path = $path } }
  $manifest = Read-Json $path
  $manifestWindow = if ($manifest -and $manifest.PSObject.Properties.Name -contains 'resolved_window') { [string]$manifest.resolved_window } elseif ($manifest -and $manifest.PSObject.Properties.Name -contains 'window') { [string]$manifest.window } else { '' }
  if (-not $manifest -or [string]$manifest.status -ne 'success' -or $manifestWindow -ne $Window -or -not [bool]$manifest.decision_ready) { return [pscustomobject]@{ reason = "$Window GSC manifest 尚未 decision-ready"; manifest = $manifest; path = $path } }
  $endDate = [datetime]::MinValue
  if (-not [datetime]::TryParse([string]$manifest.end_date, [ref]$endDate)) { return [pscustomobject]@{ reason = "$Window GSC manifest 缺少有效 end_date"; manifest = $manifest; path = $path } }
  if ($endDate.Date -lt $RequiredDate.Date) { return [pscustomobject]@{ reason = "$Window 資料截至 $($endDate.ToString('yyyy-MM-dd'))；最早需涵蓋 $($RequiredDate.ToString('yyyy-MM-dd'))"; manifest = $manifest; path = $path } }
  return [pscustomobject]@{ reason = ''; manifest = $manifest; path = $path }
}

$root = (Resolve-Path -LiteralPath $RuntimeRoot).Path
$weeklyRoot = if (Test-Path -LiteralPath (Join-Path $root 'latest\seo-geo-action-queue-state.json')) { $root } elseif (Test-Path -LiteralPath (Join-Path $root 'Weekly SOP\latest\seo-geo-action-queue-state.json')) { Join-Path $root 'Weekly SOP' } else { throw "Queue state not found under RuntimeRoot: $root" }
$latestRoot = Join-Path $weeklyRoot 'latest'
$statePath = Join-Path $latestRoot 'seo-geo-action-queue-state.json'
$queuePath = Join-Path $latestRoot 'seo-geo-action-queue.json'
$validationPath = Join-Path $latestRoot 'seo-geo-validation-receipt.json'
$deploymentPath = Join-Path $latestRoot 'seo-geo-deployment-manifest.json'
$livePath = Join-Path $latestRoot 'seo-geo-live-verification.json'
$lifecyclePath = Join-Path $latestRoot 'seo-geo-lifecycle-receipt.json'
$state = Read-Json $statePath
$queue = Read-Json $queuePath
if (-not $state -or -not $queue -or [int]$state.schema_version -ne 2 -or [int]$queue.schema_version -ne 2) { throw 'Queue/state schema_version must be 2.' }
if ([string]$state.queue_id -ne [string]$queue.queue_id -or [string]$state.cycle_key -ne [string]$queue.cycle_key) { throw 'Queue/state identity mismatch.' }
$actionIds = @(Get-StringSet @($queue.rounds | ForEach-Object { @($_.action_ids) }))
if ($actionIds.Count -eq 0 -and [string]$state.status -ne 'observation_only') { throw 'Current executable queue has no action IDs.' }
$currentStatus = [string]$state.status
$nextStage = @{ awaiting_implemented_receipt = 'implemented'; implemented = 'local_validated'; local_validated = 'deployed'; deployed = 'live_verified'; live_verified = 'observing_7d'; observing_7d = 'reviewed_28d'; reviewed_28d = 'completed' }[$currentStatus]

$inspection = $null
$windowResult = $null
switch ($currentStatus) {
  'observation_only' { $inspection = New-Inspection $currentStatus '' $false $false '本輪只需觀察' '目前為 observation_only；等待安全的新 GSC snapshot。' }
  'awaiting_implemented_receipt' {
    $receiptReason = Test-ValidationReceipt
    $inspection = New-Inspection $currentStatus $nextStage (-not $receiptReason) $false '記錄已完成修改' $(if ($receiptReason) { $receiptReason } else { 'validation receipt 已通過，可建立 implemented evidence。' })
  }
  'implemented' {
    $receiptReason = Test-ValidationReceipt
    $inspection = New-Inspection $currentStatus $nextStage (-not $receiptReason) $false '記錄本機檢查通過' $(if ($receiptReason) { $receiptReason } else { '將從 passed validation commands 建立驗收摘要。' })
  }
  'local_validated' {
    $manifestReason = Test-DeploymentManifest
    $inspection = New-Inspection $currentStatus $nextStage (-not $manifestReason) $false '記錄網站已上傳' $(if ($manifestReason) { $manifestReason } else { '正式 deployment manifest 已綁定目前 queue。' })
  }
  'deployed' {
    $manifestReason = Test-LiveManifest
    $inspection = New-Inspection $currentStatus $nextStage (-not $manifestReason) $false '記錄網站已上線驗證' $(if ($manifestReason) { $manifestReason } else { 'live verify 與 redirects 均已通過。' })
  }
  'live_verified' {
    if ([string]::IsNullOrWhiteSpace([string]$state.deployed_at)) { $inspection = New-Inspection $currentStatus $nextStage $false $false '等待 7 天完整資料' 'state 缺少 deployed_at。' }
    else {
      $required = ([datetime]::Parse([string]$state.deployed_at)).Date.AddDays(7)
      $windowResult = Test-GscWindow '7d' $required
      $inspection = New-Inspection $currentStatus $nextStage (-not $windowResult.reason) $false $(if ($windowResult.reason) { '等待 7 天完整資料' } else { '記錄開始觀察 7 天成效' }) $(if ($windowResult.reason) { $windowResult.reason } else { '7d manifest 已 decision-ready 且涵蓋完整部署後 7 日。' }) $required.ToString('yyyy-MM-dd') $(if ($windowResult.manifest) { [string]$windowResult.manifest.end_date } else { '' })
    }
  }
  'observing_7d' {
    if ([string]::IsNullOrWhiteSpace([string]$state.deployed_at)) { $inspection = New-Inspection $currentStatus $nextStage $false $false '等待 28 天完整資料' 'state 缺少 deployed_at。' }
    else {
      $required = ([datetime]::Parse([string]$state.deployed_at)).Date.AddDays(28)
      $windowResult = Test-GscWindow '28d' $required
      $inspection = New-Inspection $currentStatus $nextStage (-not $windowResult.reason) (-not $windowResult.reason) $(if ($windowResult.reason) { '等待 28 天完整資料' } else { '記錄完成 28 天成效檢討' }) $(if ($windowResult.reason) { $windowResult.reason } else { '資料已完整；請選擇策略決策並輸入摘要。' }) $required.ToString('yyyy-MM-dd') $(if ($windowResult.manifest) { [string]$windowResult.manifest.end_date } else { '' })
    }
  }
  'reviewed_28d' { $inspection = New-Inspection $currentStatus $nextStage $true $false '記錄本次優化完成' '將沿用 28d review 的決策與摘要。' }
  'completed' { $inspection = New-Inspection $currentStatus '' $false $false '本次優化已完成' '等待下一期 GSC 資料。' }
  default { $inspection = New-Inspection $currentStatus '' $false $false '目前無 lifecycle 動作' "狀態 $currentStatus 由 Round 流程處理。" }
}

if ($Mode -eq 'Inspect') {
  $inspection | ConvertTo-Json -Depth 8 -Compress
  exit 0
}
if (-not [bool]$inspection.ready -or [string]::IsNullOrWhiteSpace([string]$inspection.next_stage)) { throw "目前不可前進：$($inspection.reason)" }
if ($inspection.needs_input -and ([string]::IsNullOrWhiteSpace($Decision) -or [string]::IsNullOrWhiteSpace($Summary))) { throw '28d review requires Decision and a non-empty Summary.' }

$evidence = [ordered]@{
  queue_id = [string]$state.queue_id
  cycle_key = [string]$state.cycle_key
  queue_sha256 = Get-Sha256 $queuePath
  action_ids = $actionIds
}
$validation = Read-Json $validationPath
switch ($nextStage) {
  'implemented' {
    $evidence.validation_receipt_sha256 = Get-Sha256 $validationPath
    $evidence.implemented_at = if ($validation.generated_at) { [string]$validation.generated_at } else { (Get-Date).ToUniversalTime().ToString('o') }
    $changed = @(Get-StringSet @($validation.changed_files))
    $evidence.implementation_summary = if ($changed.Count) { '已驗證修改檔案：' + ($changed -join '、') } else { 'validation receipt 已證明本輪修改完成。' }
  }
  'local_validated' {
    $evidence.validation_receipt_sha256 = Get-Sha256 $validationPath
    $evidence.validated_at = if ($validation.generated_at) { [string]$validation.generated_at } else { (Get-Date).ToUniversalTime().ToString('o') }
    $passed = @($validation.validation_results | Where-Object { [string]$_.status -eq 'passed' -and [int]$_.exit_code -eq 0 } | ForEach-Object { [string]$_.command })
    $evidence.validation_summary = if ($passed.Count) { 'Passed: ' + ($passed -join '；') } else { 'validation receipt status=passed。' }
  }
  'deployed' {
    $manifest = Read-Json $deploymentPath
    $evidence.validation_receipt_sha256 = Get-Sha256 $validationPath
    $evidence.uploaded = [int]$manifest.summary.uploaded
    $evidence.skipped = [int]$manifest.summary.skipped
    $evidence.failed = [int]$manifest.summary.failed
    $evidence.command = 'pwsh scripts/deploy-ftp.ps1 -Mode quick'
    $evidence.completed_at = [string]$manifest.completed_at
    $evidence.target_host = [string]$manifest.target_host
    $evidence.deployment_manifest = [ordered]@{ path = 'latest/seo-geo-deployment-manifest.json'; sha256 = Get-Sha256 $deploymentPath }
  }
  'live_verified' {
    $manifest = Read-Json $livePath
    $evidence.verified_at = [string]$manifest.verified_at
    $evidence.host = [string]$manifest.host
    $evidence.live_verification_manifest = [ordered]@{ path = 'latest/seo-geo-live-verification.json'; sha256 = Get-Sha256 $livePath }
    $checks = @()
    foreach ($name in @('http','canonical','json_ld','sitemap')) {
      $items = @($manifest.pages | ForEach-Object { @($_.checks | Where-Object { [string]$_.name -eq $name }) })
      $checks += [ordered]@{ name = $name; status = 'passed'; evidence = (($items | ForEach-Object { [string]$_.evidence }) -join ' | ') }
    }
    $redirects = @()
    if ($manifest.PSObject.Properties.Name -contains 'redirect_checks') { $redirects = @($manifest.redirect_checks) }
    $redirectEvidence = if ($redirects.Count) { ($redirects | ForEach-Object { "$($_.legacy_url) -> $($_.target_url) ($($_.status_code))" }) -join ' | ' } else { '目前 queue 沒有需要驗證的舊產品 ID 路徑。' }
    $checks += [ordered]@{ name = 'redirects'; status = 'passed'; evidence = $redirectEvidence }
    $evidence.checks = $checks
  }
  'observing_7d' {
    $manifestPath = Join-Path $latestRoot '7d\weekly-sop-last-run.json'
    $manifest = Read-Json $manifestPath
    $evidence.observed_through_date = [string]$manifest.end_date
    $evidence.gsc_manifest = [ordered]@{ path = 'latest/7d/weekly-sop-last-run.json'; sha256 = Get-Sha256 $manifestPath }
  }
  'reviewed_28d' {
    $manifestPath = Join-Path $latestRoot '28d\weekly-sop-last-run.json'
    $manifest = Read-Json $manifestPath
    $evidence.gsc_end_date = [string]$manifest.end_date
    $evidence.gsc_manifest = [ordered]@{ path = 'latest/28d/weekly-sop-last-run.json'; sha256 = Get-Sha256 $manifestPath }
    $evidence.decision = $Decision
    $evidence.review_summary = $Summary.Trim()
    $evidence.summary = $Summary.Trim()
  }
  'completed' {
    $history = Read-Json $lifecyclePath
    $review = @($history.stages | Where-Object { [string]$_.stage -eq 'reviewed_28d' } | Select-Object -Last 1)
    if ($review.Count -ne 1) { throw '找不到 reviewed_28d lifecycle evidence。' }
    $evidence.decision = [string]$review[0].evidence.decision
    $reviewSummary = if (-not [string]::IsNullOrWhiteSpace([string]$review[0].evidence.review_summary)) { [string]$review[0].evidence.review_summary } else { [string]$review[0].evidence.summary }
    if ([string]::IsNullOrWhiteSpace($reviewSummary)) { throw 'reviewed_28d evidence 缺少摘要。' }
    $evidence.summary = $reviewSummary
  }
}

$writer = Join-Path (Split-Path -Parent $PSScriptRoot) 'scripts\write-seo-geo-workflow-transition.ps1'
$evidenceJson = $evidence | ConvertTo-Json -Depth 20 -Compress
$output = @(& $writer -RuntimeRoot $weeklyRoot -Transition $nextStage -EvidenceJson $evidenceJson 2>&1)
if (-not $?) { throw ($output -join [Environment]::NewLine) }
$inspection['result'] = 'advanced'
$inspection['evidence_source'] = switch ($nextStage) {
  { $_ -in @('implemented','local_validated') } { 'latest/seo-geo-validation-receipt.json'; break }
  'deployed' { 'latest/seo-geo-deployment-manifest.json'; break }
  'live_verified' { 'latest/seo-geo-live-verification.json'; break }
  'observing_7d' { 'latest/7d/weekly-sop-last-run.json'; break }
  'reviewed_28d' { 'latest/28d/weekly-sop-last-run.json'; break }
  'completed' { 'latest/seo-geo-lifecycle-receipt.json'; break }
}
$inspection['writer_output'] = $output
$inspection | ConvertTo-Json -Depth 10 -Compress
