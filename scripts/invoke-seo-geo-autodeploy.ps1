[CmdletBinding()]
param(
  [Parameter(Mandatory = $true)][string]$RuntimeRoot,
  [ValidateSet('Inspect', 'Execute')][string]$Mode = 'Inspect'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Read-Json([string]$Path) {
  if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { return $null }
  Get-Content -LiteralPath $Path -Raw -Encoding UTF8 | ConvertFrom-Json
}
function Get-Sha256([string]$Path) { (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant() }
function Get-StringSet([object[]]$Values) { @($Values | ForEach-Object { ([string]$_).Trim() } | Where-Object { $_ } | Sort-Object -Unique) }
function Test-SameSet([object[]]$Left, [object[]]$Right) {
  $a = @(Get-StringSet $Left); $b = @(Get-StringSet $Right)
  $a.Count -eq $b.Count -and @($a | Where-Object { $_ -notin $b }).Count -eq 0
}
function Write-JsonAtomic([string]$Path, [object]$Value) {
  $temp = "$Path.tmp.$([guid]::NewGuid().ToString('N'))"
  try {
    [System.IO.File]::WriteAllText($temp, ($Value | ConvertTo-Json -Depth 30) + [Environment]::NewLine, [System.Text.UTF8Encoding]::new($false))
    [System.IO.File]::Move($temp, $Path, $true)
  } finally { if (Test-Path -LiteralPath $temp) { Remove-Item -LiteralPath $temp -Force -ErrorAction SilentlyContinue } }
}
function Test-DeploymentManifest([string]$Path, [object]$Plan, [bool]$DryRun) {
  $manifest = Read-Json $Path
  if (-not $manifest -or [string]$manifest.status -ne $(if ($DryRun) { 'dry_run' } else { 'success' }) -or [bool]$manifest.dry_run -ne $DryRun) { throw 'Deployment manifest status does not match the expected stage.' }
  if ([string]$manifest.target_host -ne 'online.hong-sen.com' -or [string]$manifest.deployment_context.queue_id -ne [string]$Plan.queue_id -or [string]$manifest.deployment_context.cycle_key -ne [string]$Plan.cycle_key -or -not (Test-SameSet @($manifest.deployment_context.action_ids) @($Plan.action_ids))) { throw 'Deployment manifest identity is not bound to the current deploy plan.' }
  if ([int]$manifest.summary.failed -ne 0 -or @($manifest.files).Count -ne @($Plan.files).Count) { throw 'Deployment manifest has failed or missing files.' }
  foreach ($file in @($Plan.files)) {
    $match = @($manifest.files | Where-Object { [string]$_.relative_path -eq [string]$file.relative_path })
    if ($match.Count -ne 1 -or [string]$match[0].sha256 -ne [string]$file.sha256) { throw "Deployment manifest does not match deploy plan: $($file.relative_path)" }
  }
  return $manifest
}

$root = (Resolve-Path -LiteralPath $RuntimeRoot).Path
$weeklyRoot = if (Test-Path -LiteralPath (Join-Path $root 'latest\seo-geo-action-queue-state.json')) { $root } elseif (Test-Path -LiteralPath (Join-Path $root 'Weekly SOP\latest\seo-geo-action-queue-state.json')) { Join-Path $root 'Weekly SOP' } else { throw "Queue state not found under RuntimeRoot: $root" }
$latestRoot = Join-Path $weeklyRoot 'latest'
$projectionScript = Join-Path $PSScriptRoot 'get-seo-geo-ui-projection.ps1'
$planScript = Join-Path $PSScriptRoot 'new-seo-geo-deploy-plan.ps1'
$deployScript = Join-Path $PSScriptRoot 'deploy-ftp.ps1'
$lifecycleScript = Join-Path $PSScriptRoot 'invoke-seo-geo-lifecycle-next.ps1'
$liveVerifyScript = Join-Path $PSScriptRoot 'write-seo-geo-live-verification.ps1'
$planPath = Join-Path $latestRoot 'seo-geo-deploy-plan.json'
$dryRunPath = Join-Path $latestRoot 'seo-geo-deployment-dry-run-manifest.json'
$deployPath = Join-Path $latestRoot 'seo-geo-deployment-manifest.json'
$journalPath = Join-Path $latestRoot 'seo-geo-autodeploy-journal.json'
$lockPath = Join-Path $latestRoot '.seo-geo-autodeploy.lock'

$projection = (& $projectionScript -RuntimeRoot $weeklyRoot | ConvertFrom-Json)
if (-not [bool]$projection.consistent) { throw 'Auto-deploy is blocked because workflow consistency is not valid.' }
if ([string]$projection.state -ne 'local_validated') { throw "Auto-deploy only starts from local_validated; current=$($projection.state)" }
$plan = (& $planScript -RuntimeRoot $weeklyRoot -Mode Inspect | ConvertFrom-Json)
$ready = [bool]$plan.preflight.passed -and [string]$plan.status -eq 'ready' -and [bool]$projection.actions.AUTO_DEPLOY.enabled
if ($Mode -eq 'Inspect') {
  [ordered]@{ schema_version = 1; mode = 'inspect'; ready = $ready; state = $projection.state; reason = if ($ready) { 'Preflight passed; a user may start the protected auto-deploy.' } else { (@($plan.preflight.reasons) + @($projection.actions.AUTO_DEPLOY.reason) | Where-Object { $_ } | Select-Object -Unique) -join '；' }; identity = $projection.identity; stages = @('preflight','dry_run','ftp_deploy','record_deployed','live_verify','record_live_verified') } | ConvertTo-Json -Depth 8 -Compress
  return
}
if (-not $ready) { throw 'Auto-deploy preflight failed; no FTP action was started.' }

$lockStream = $null
try {
  try { $lockStream = [System.IO.File]::Open($lockPath, [System.IO.FileMode]::CreateNew, [System.IO.FileAccess]::ReadWrite, [System.IO.FileShare]::None) }
  catch { throw 'Auto-deploy is already running for this runtime. Wait for it to finish before retrying.' }
  $receiptPath = Join-Path $latestRoot 'seo-geo-validation-receipt.json'
  $fingerprint = Get-Sha256 $receiptPath
  $previous = Read-Json $journalPath
  if ($previous -and ([string]$previous.queue_id -ne [string]$plan.queue_id -or [string]$previous.cycle_key -ne [string]$plan.cycle_key -or [string]$previous.validation_receipt_sha256 -ne $fingerprint)) {
    throw 'Existing auto-deploy journal belongs to a different queue, cycle, or validation receipt; recovery is refused.'
  }
  $journal = [ordered]@{ schema_version = 1; queue_id = $plan.queue_id; cycle_key = $plan.cycle_key; action_ids = $plan.action_ids; validation_receipt_sha256 = $fingerprint; started_at = (Get-Date).ToUniversalTime().ToString('o'); status = 'running'; current_stage = 'preflight'; stages = @() }
  function Complete-Stage([string]$Stage, [string]$ManifestPath = '') {
    $entry = [ordered]@{ stage = $Stage; status = 'passed'; completed_at = (Get-Date).ToUniversalTime().ToString('o'); manifest_path = if ($ManifestPath) { $ManifestPath } else { $null }; manifest_sha256 = if ($ManifestPath) { Get-Sha256 $ManifestPath } else { $null } }
    $journal.stages = @($journal.stages) + @($entry); $journal.current_stage = $Stage; Write-JsonAtomic $journalPath $journal
  }
  function Fail-Stage([string]$Stage, [string]$Message) {
    $journal.status = 'failed'; $journal.current_stage = $Stage; $journal.failed_at = (Get-Date).ToUniversalTime().ToString('o'); $journal.error = $Message; Write-JsonAtomic $journalPath $journal
  }

  try {
    $plan = (& $planScript -RuntimeRoot $weeklyRoot -Mode Write -OutputPath $planPath | ConvertFrom-Json)
    if (-not [bool]$plan.preflight.passed -or [string]$plan.status -ne 'ready') { throw 'Deploy plan became blocked during execution preflight.' }
    Complete-Stage 'preflight' $planPath
    & $deployScript -Mode paths -LocalRoot $plan.output_root -DeployPlanPath $planPath -HostName $plan.ftp_host -RemoteRoot $plan.remote_root -ManifestPath $dryRunPath -QueueId $plan.queue_id -CycleKey $plan.cycle_key -ActionId ($plan.action_ids -join '|') -DryRun
    $null = Test-DeploymentManifest $dryRunPath $plan $true
    Complete-Stage 'dry_run' $dryRunPath
    & $deployScript -Mode paths -LocalRoot $plan.output_root -DeployPlanPath $planPath -HostName $plan.ftp_host -RemoteRoot $plan.remote_root -ManifestPath $deployPath -QueueId $plan.queue_id -CycleKey $plan.cycle_key -ActionId ($plan.action_ids -join '|')
    $null = Test-DeploymentManifest $deployPath $plan $false
    Complete-Stage 'ftp_deploy' $deployPath
    & $lifecycleScript -RuntimeRoot $weeklyRoot -Mode Advance | Out-Null
    if ($LASTEXITCODE -ne 0) { throw 'Failed to record deployed lifecycle receipt.' }
    Complete-Stage 'record_deployed' $deployPath
    & $liveVerifyScript -RuntimeRoot $weeklyRoot -Scope queue_targets | Out-Null
    if ($LASTEXITCODE -ne 0) { throw 'Live verification failed; deployed is retained and live_verified is not recorded.' }
    $livePath = Join-Path $latestRoot 'seo-geo-live-verification.json'
    Complete-Stage 'live_verify' $livePath
    & $lifecycleScript -RuntimeRoot $weeklyRoot -Mode Advance | Out-Null
    if ($LASTEXITCODE -ne 0) { throw 'Failed to record live_verified lifecycle receipt.' }
    Complete-Stage 'record_live_verified' $livePath
    $journal.status = 'completed'; $journal.completed_at = (Get-Date).ToUniversalTime().ToString('o'); Write-JsonAtomic $journalPath $journal
    [ordered]@{ schema_version = 1; status = 'completed'; final_state = 'live_verified'; journal_path = $journalPath } | ConvertTo-Json -Compress
  } catch {
    Fail-Stage $journal.current_stage $_.Exception.Message
    throw
  }
} finally {
  if ($lockStream) { $lockStream.Dispose() }
  if (Test-Path -LiteralPath $lockPath) { Remove-Item -LiteralPath $lockPath -Force -ErrorAction SilentlyContinue }
}
