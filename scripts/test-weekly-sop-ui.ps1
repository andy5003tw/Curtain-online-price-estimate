[CmdletBinding()]
param(
  [string]$RuntimeRoot = 'Weekly SOP',
  [switch]$SkipBehaviorFixtures
)

$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
$weeklyRoot = Join-Path $repoRoot $RuntimeRoot
$htaPath = Join-Path $weeklyRoot 'Weekly SOP Launcher.hta'
$planPath = Join-Path $weeklyRoot 'latest\seo-geo-action-plan.json'
$queuePath = Join-Path $weeklyRoot 'latest\seo-geo-action-queue-state.json'
$projectionWriter = Join-Path $repoRoot 'scripts\get-seo-geo-effective-workflow.ps1'
$cycleTest = Join-Path $repoRoot 'scripts\test-seo-geo-cycle.ps1'
$aiVisibilityTest = Join-Path $repoRoot 'scripts\test-ai-visibility.ps1'
$aiVisibilityImporter = Join-Path $repoRoot 'scripts\import-latest-ai-visibility.ps1'
$aiVisibilityRunner = Join-Path $repoRoot 'scripts\run-ai-visibility-observation.ps1'
$aiVisibilityAutomationTest = Join-Path $repoRoot 'scripts\test-ai-visibility-automation.ps1'
$aiVisibilityLunaComparison = Join-Path $repoRoot 'scripts\run-ai-visibility-luna-comparison.ps1'
$aiVisibilityLunaComparisonTest = Join-Path $repoRoot 'scripts\test-ai-visibility-luna-comparison.ps1'
$lifecycleNext = Join-Path $repoRoot 'scripts\invoke-seo-geo-lifecycle-next.ps1'

function Assert-True {
  param([bool]$Condition, [string]$Message)
  if (-not $Condition) { throw $Message }
}

Assert-True (Test-Path -LiteralPath $htaPath -PathType Leaf) "Weekly SOP HTA not found: $htaPath"
Assert-True (Test-Path -LiteralPath $planPath -PathType Leaf) "Action plan not found: $planPath"
Assert-True (Test-Path -LiteralPath $queuePath -PathType Leaf) "Queue state not found: $queuePath"
Assert-True (Test-Path -LiteralPath $projectionWriter -PathType Leaf) "Effective workflow projection writer not found: $projectionWriter"
Assert-True (Test-Path -LiteralPath $cycleTest -PathType Leaf) "SEO/GEO state behavior fixture is missing: $cycleTest"
Assert-True (Test-Path -LiteralPath $aiVisibilityTest -PathType Leaf) "AI Visibility state behavior fixture is missing: $aiVisibilityTest"
Assert-True (Test-Path -LiteralPath $aiVisibilityImporter -PathType Leaf) "AI Visibility one-click importer is missing: $aiVisibilityImporter"
Assert-True (Test-Path -LiteralPath $aiVisibilityRunner -PathType Leaf) "AI Visibility API runner is missing: $aiVisibilityRunner"
Assert-True (Test-Path -LiteralPath $aiVisibilityAutomationTest -PathType Leaf) "AI Visibility automation fixture is missing: $aiVisibilityAutomationTest"
Assert-True (Test-Path -LiteralPath $lifecycleNext -PathType Leaf) "Smart lifecycle controller is missing: $lifecycleNext"

$hta = Get-Content -LiteralPath $htaPath -Raw -Encoding UTF8
foreach ($id in @('zoneDataTrust', 'zoneOwnerPortfolio', 'zoneDecision', 'zoneStrategy', 'zoneImplementation', 'zonePerformance')) {
  Assert-True ($hta -match ('id="' + [regex]::Escape($id) + '"')) "Missing six-zone UI panel: $id"
}
foreach ($id in @('btnSeoGeoNextSmart', 'btnOpenSeoGeoActionPlan', 'btnImportAiVisibility', 'btnRunAiVisibilityLunaComparison')) {
  Assert-True ($hta -match ('id="' + [regex]::Escape($id) + '"')) "Missing SEO/GEO action button: $id"
}
foreach ($id in @('btnFetchGscLatest')) {
  Assert-True ($hta -match ('id="' + [regex]::Escape($id) + '"')) "Missing GSC report action button: $id"
}
$reportActions = [regex]::Match($hta, '(?s)<div class="report-actions">\s*<button id="btnFetchGscLatest".*?</div>').Value
Assert-True (([regex]::Matches($reportActions, '<button\b')).Count -eq 1) 'GSC report panel must expose exactly one API update button.'
foreach ($marker in @('function fetchLatestGscReports', 'fetch-gsc-latest.ps1', '-Window "both"', 'gsc-latest-fetch.json', 'No new finalized GSC period is available', 'credentials\\gsc-oauth-client.json', '更新最新 GSC 資料')) {
  Assert-True ($hta.Contains($marker)) "Missing GSC API fetch UI marker: $marker"
}
$primaryActions = [regex]::Match($hta, '(?s)<div class="seo-geo-actions">\s*<button id="btnSeoGeoNextSmart".*?</div>').Value
Assert-True (([regex]::Matches($primaryActions, '<button\b')).Count -eq 2) 'Primary SEO/GEO panel must contain exactly the next-step and report buttons.'
foreach ($marker in @('function executeCurrentSeoGeoNextStep', 'function invokeLifecycleNext', 'function getLifecycleNextInspection', 'invoke-seo-geo-lifecycle-next.ps1', '執行目前下一步', '查看目前 SEO/GEO 報表', '正式上傳網站（FTP 部署）')) {
  Assert-True ($hta.Contains($marker)) "Missing smart SEO/GEO UI marker: $marker"
}
foreach ($marker in @('function renderSixZoneDashboard', 'diagnosticDimensionText', 'getEffectiveWorkflowProjection', 'strategy snapshot=', 'effective workflow=', 'single_page_alignment_review', 'observation_only', 'awaiting_implemented_receipt', 'btnLifecycleImplemented', 'btnLifecycleLocalValidated', 'btnSeoGeoDeployDryRun', 'btnSeoGeoDeploy', 'btnSeoGeoLiveVerify', 'btnImportAiVisibility', 'btnImportAiVisibilityInbox', 'btnImportAiVisibilityManual', 'btnRunAiVisibilityLunaComparison', 'runSeoGeoDeployment', 'runSeoGeoLiveVerification', 'runAiVisibilityAutomation', 'runAiVisibilityLunaComparison', 'run-ai-visibility-observation.ps1', 'run-ai-visibility-luna-comparison.ps1', 'importLatestAiVisibilityObservation', 'import-latest-ai-visibility.ps1', 'importAiVisibilityObservation', 'direct_ai_engine_observation', '品牌題：提及率=', '非品牌題：提及率=', '引用來源（按題計）', '自有網域：online.hong-sen.com=', 'accuracy（完全正確）=', 'accuracy review=', 'gsc_inference_prohibited', 'workflow consistency gate', 'queue_sha256', 'validation_receipt_sha256', 'write-seo-geo-workflow-transition.ps1', 'PowerShell transaction', 'function buildPostGscSubmissionReminder', '下一步操作提醒', '固定 6 題', 'observing_7d', 'decision_ready 7d manifest')) {
  Assert-True ($hta.Contains($marker)) "Missing UI safety/render marker: $marker"
}
Assert-True (-not $hta.Contains('persistValidatedRoundArtifacts')) 'HTA must not retain duplicate JavaScript Round persistence.'
Assert-True (Test-Path -LiteralPath $aiVisibilityLunaComparison -PathType Leaf) 'Missing Luna comparison runner.'
Assert-True (Test-Path -LiteralPath $aiVisibilityLunaComparisonTest -PathType Leaf) 'Missing Luna comparison test.'
Assert-True (-not $hta.Contains('writeJsonAtomic(statePath, state)')) 'HTA must not directly persist queue state.'
Assert-True (-not $hta.Contains('AI Visibility：尚無固定問題集 receipt')) 'AI Visibility UI must render direct-observation metrics or an explicit data-unavailable reason, not the obsolete placeholder.'

$plan = Get-Content -LiteralPath $planPath -Raw -Encoding UTF8 | ConvertFrom-Json
$state = Get-Content -LiteralPath $queuePath -Raw -Encoding UTF8 | ConvertFrom-Json
$inspectionText = @(& pwsh -NoLogo -NoProfile -File $lifecycleNext -RuntimeRoot $weeklyRoot -Mode Inspect 2>&1)
Assert-True ($LASTEXITCODE -eq 0) ('Smart lifecycle Inspect failed: ' + ($inspectionText -join ' '))
$inspection = ($inspectionText -join "`n") | ConvertFrom-Json
Assert-True ([string]$inspection.current_status -eq [string]$state.status) 'Smart lifecycle Inspect does not match authoritative queue state.'
if ([string]$state.status -eq 'live_verified') {
  Assert-True (-not [bool]$inspection.ready -and [string]$inspection.next_stage -eq 'observing_7d' -and -not [string]::IsNullOrWhiteSpace([string]$inspection.earliest_date)) 'P003 live_verified state must wait for or record a complete 7d window.'
}
$projectionText = @(& pwsh -NoLogo -NoProfile -File $projectionWriter -RuntimeRoot $weeklyRoot 2>&1)
Assert-True ($LASTEXITCODE -eq 0) ('Effective workflow projection failed: ' + ($projectionText -join ' '))
$projection = ($projectionText -join "`n") | ConvertFrom-Json
Assert-True ([bool]$projection.consistency.valid) ('Effective workflow projection is inconsistent: ' + (@($projection.consistency.reasons) -join ', '))
Assert-True ([string]$projection.strategy_snapshot.status -eq [string]$plan.workflow_status) 'Effective workflow projection does not preserve the immutable strategy snapshot status.'
Assert-True ([string]$projection.effective.status -eq [string]$state.status) 'Effective workflow projection does not match the authoritative lifecycle state.'
Assert-True ($state.PSObject.Properties.Name -contains 'precondition_gates') 'Queue state is missing precondition gates.'
if ([string]$state.status -notin @('observation_only', 'active')) {
  Assert-True ([string]$projection.precondition_gates.data_validated.status -in @('passed', 'validated')) 'Lifecycle state must expose passed data_validated gate.'
  Assert-True ([string]$projection.precondition_gates.strategy_approved.status -in @('passed', 'approved')) 'Lifecycle state must expose passed strategy_approved gate.'
}
foreach ($field in @('freshness', 'observations', 'diagnostics', 'query_delta', 'ctr_benchmark', 'review_windows', 'optional_opportunities', 'alignment_candidates')) {
  Assert-True ($plan.PSObject.Properties.Name -contains $field) "Action plan missing UI contract field: $field"
}
Assert-True ($null -ne $plan.diagnostics.history -or $null -ne $plan.snapshot.'28d'.diagnostic_history) 'Action plan has no diagnostic history binding for the data-trust zone.'

if ([string]$state.status -eq 'observation_only') {
  Assert-True ([int]$state.total_rounds -eq 0) 'observation_only state must have zero executable Rounds.'
  Assert-True ($hta -match 'observation_only 不產生實作指令') 'UI must disable implementation copy in observation_only mode.'
  Assert-True ($hta -match '無 executable Round；複製、前進、部署與 lifecycle 寫入均保持 disabled') 'Six-zone implementation panel must state the observation-only deployment boundary.'
}

if (-not $SkipBehaviorFixtures) {
  # The HTA is a host UI, so lifecycle behavior is exercised through the same
  # PowerShell writers that its controls call.  This covers approved-plan
  # projection, transaction rollback, receipt after-state, manifest SHA rejection
  # and partial-live-contract rejection in an isolated runtime fixture.
  $behaviorOutput = @(& pwsh -NoLogo -NoProfile -File $cycleTest 2>&1)
  Assert-True ($LASTEXITCODE -eq 0) ('Weekly SOP state behavior fixture failed: ' + ($behaviorOutput -join "`n"))
  Assert-True (($behaviorOutput -join "`n") -match 'SEO/GEO cycle tests passed') 'State behavior fixture did not report successful completion.'
  $aiOutput = @(& pwsh -NoLogo -NoProfile -File $aiVisibilityTest 2>&1)
  Assert-True ($LASTEXITCODE -eq 0) ('AI Visibility state behavior fixture failed: ' + ($aiOutput -join "`n"))
  Assert-True (($aiOutput -join "`n") -match 'AI Visibility tests passed') 'AI Visibility fixture did not report successful completion.'
  $aiAutomationOutput = @(& pwsh -NoLogo -NoProfile -File $aiVisibilityAutomationTest 2>&1)
  Assert-True ($LASTEXITCODE -eq 0) ('AI Visibility automation fixture failed: ' + ($aiAutomationOutput -join "`n"))
  Assert-True (($aiAutomationOutput -join "`n") -match 'AI Visibility automation tests passed') 'AI Visibility automation fixture did not report successful completion.'
  $aiLunaComparisonOutput = @(& pwsh -NoLogo -NoProfile -File $aiVisibilityLunaComparisonTest 2>&1)
  Assert-True ($LASTEXITCODE -eq 0) ('AI Visibility Luna comparison fixture failed: ' + ($aiLunaComparisonOutput -join "`n"))
  Assert-True (($aiLunaComparisonOutput -join "`n") -match 'AI Visibility Luna comparison tests passed') 'AI Visibility Luna comparison fixture did not report successful completion.'
}

Write-Host ('Weekly SOP six-zone UI static + state behavior test passed.' + $(if ($SkipBehaviorFixtures) { ' (behavior fixture skipped)' } else { '' }))
