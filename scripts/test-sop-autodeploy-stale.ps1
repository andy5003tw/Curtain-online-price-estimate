[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
$coordinatorSource = Join-Path $PSScriptRoot 'invoke-seo-geo-autodeploy.ps1'
$pwshPath = Join-Path $PSHOME 'pwsh.exe'

function Assert-True {
  param([bool]$Condition, [string]$Message)
  if (-not $Condition) { throw $Message }
}

function Write-Utf8NoBom {
  param([string]$Path, [string]$Text)
  $parent = Split-Path -Parent $Path
  if (-not (Test-Path -LiteralPath $parent -PathType Container)) {
    New-Item -ItemType Directory -Path $parent -Force | Out-Null
  }
  [System.IO.File]::WriteAllText($Path, $Text, [System.Text.UTF8Encoding]::new($false))
}

function Assert-TempPath {
  param([string]$Path, [string]$TempRoot)
  $absolutePath = [System.IO.Path]::GetFullPath($Path)
  $absoluteTempRoot = [System.IO.Path]::GetFullPath($TempRoot).TrimEnd([char[]]@('\','/')) + [System.IO.Path]::DirectorySeparatorChar
  if (-not $absolutePath.StartsWith($absoluteTempRoot, [System.StringComparison]::OrdinalIgnoreCase)) {
    throw "Refusing path outside the dedicated system temp root: $absolutePath"
  }
  return $absolutePath
}

function New-TestScenario {
  param(
    [string]$ScenarioRoot,
    [ValidateSet('blocked', 'receipt_changed')][string]$AfterDryRun
  )
  $scriptsRoot = Join-Path $ScenarioRoot 'scripts'
  $runtimeRoot = Join-Path $ScenarioRoot 'runtime'
  $latestRoot = Join-Path $runtimeRoot 'latest'
  $outputRoot = Join-Path $ScenarioRoot 'repo-out'
  New-Item -ItemType Directory -Path $scriptsRoot, $latestRoot, $outputRoot -Force | Out-Null
  Copy-Item -LiteralPath $coordinatorSource -Destination (Join-Path $scriptsRoot 'invoke-seo-geo-autodeploy.ps1')

  Write-Utf8NoBom (Join-Path $latestRoot 'seo-geo-action-queue-state.json') '{"status":"local_validated"}'
  Write-Utf8NoBom (Join-Path $latestRoot 'seo-geo-validation-receipt.json') '{"fixture":"receipt"}'
  Write-Utf8NoBom (Join-Path $ScenarioRoot 'scenario.json') (@{ after_dry_run = $AfterDryRun } | ConvertTo-Json -Compress)
  Write-Utf8NoBom (Join-Path $ScenarioRoot 'deploy-calls.txt') ''

  $projectionStub = @'
param([Parameter(Mandatory=$true)][string]$RuntimeRoot)
[ordered]@{
  consistent = $true
  state = 'local_validated'
  actions = [ordered]@{ AUTO_DEPLOY = [ordered]@{ enabled = $true; reason = 'fixture ready' } }
  identity = [ordered]@{ queue_id = 'fixture-queue'; cycle_key = 'fixture-cycle'; action_ids = @('fixture-action') }
} | ConvertTo-Json -Depth 8 -Compress
'@
  Write-Utf8NoBom (Join-Path $scriptsRoot 'get-seo-geo-ui-projection.ps1') $projectionStub

  $planStub = @'
[CmdletBinding()]
param(
  [Parameter(Mandatory=$true)][string]$RuntimeRoot,
  [ValidateSet('Inspect','Write')][string]$Mode = 'Inspect',
  [string]$OutputPath = ''
)
$ErrorActionPreference = 'Stop'
$latest = Join-Path $RuntimeRoot 'latest'
$scenarioPath = Join-Path (Split-Path -Parent $RuntimeRoot) 'scenario.json'
$scenario = Get-Content -LiteralPath $scenarioPath -Raw | ConvertFrom-Json
$counterPath = Join-Path $latest 'plan-inspect-count.txt'
$inspectCount = 0
if (Test-Path -LiteralPath $counterPath -PathType Leaf) {
  $inspectCount = [int](Get-Content -LiteralPath $counterPath -Raw)
}
if ($Mode -eq 'Inspect') {
  $inspectCount += 1
  [System.IO.File]::WriteAllText($counterPath, [string]$inspectCount, [System.Text.UTF8Encoding]::new($false))
}
$blockedAfterDryRun = $Mode -eq 'Inspect' -and $inspectCount -ge 2 -and [string]$scenario.after_dry_run -eq 'blocked'
$ready = -not $blockedAfterDryRun
$receiptPath = Join-Path $latest 'seo-geo-validation-receipt.json'
$receiptSha = (Get-FileHash -LiteralPath $receiptPath -Algorithm SHA256).Hash.ToLowerInvariant()
$plan = [ordered]@{
  schema_version = 1
  status = if ($ready) { 'ready' } else { 'blocked' }
  preflight = [ordered]@{
    passed = $ready
    reasons = if ($ready) { @() } else { @('fixture provenance drift after dry-run') }
  }
  output_root = Join-Path (Split-Path -Parent $RuntimeRoot) 'repo-out'
  ftp_host = 'ftp.hong-sen.com'
  remote_root = 'online.hong-sen.com'
  target_host = 'online.hong-sen.com'
  queue_id = 'fixture-queue'
  cycle_key = 'fixture-cycle'
  action_ids = @('fixture-action')
  validation_receipt = [ordered]@{ path = 'latest/seo-geo-validation-receipt.json'; sha256 = $receiptSha }
  files = @([ordered]@{ relative_path = 'cases/index.html'; sha256 = ('c'.PadRight(64, 'c')) })
}
if ($Mode -eq 'Write') {
  if (-not $OutputPath) { throw 'Fixture requires OutputPath in Write mode.' }
  $planJson = $plan | ConvertTo-Json -Depth 12 -Compress
  [System.IO.File]::WriteAllText($OutputPath, $planJson, [System.Text.UTF8Encoding]::new($false))
}
$plan | ConvertTo-Json -Depth 12 -Compress
'@
  Write-Utf8NoBom (Join-Path $scriptsRoot 'new-seo-geo-deploy-plan.ps1') $planStub

  $deployStub = @'
[CmdletBinding()]
param(
  [string]$Mode,
  [string]$LocalRoot,
  [string]$DeployPlanPath,
  [string]$HostName,
  [string]$RemoteRoot,
  [string]$ManifestPath,
  [string]$QueueId,
  [string]$CycleKey,
  [string]$ActionId,
  [switch]$DryRun
)
$ErrorActionPreference = 'Stop'
$scenarioRoot = Split-Path -Parent $LocalRoot
$callLog = Join-Path $scenarioRoot 'deploy-calls.txt'
$callKind = if ($DryRun) { 'dry-run' } else { 'ftp' }
[System.IO.File]::AppendAllText($callLog, $callKind + [Environment]::NewLine, [System.Text.UTF8Encoding]::new($false))
if (-not $DryRun) { throw 'Unexpected FTP deploy invocation; fixture never connects to FTP.' }
$plan = Get-Content -LiteralPath $DeployPlanPath -Raw | ConvertFrom-Json
$actions = @($ActionId -split '\|')
$manifest = [ordered]@{
  schema_version = 1
  status = 'dry_run'
  dry_run = $true
  target_host = 'online.hong-sen.com'
  deployment_context = [ordered]@{ queue_id = $QueueId; cycle_key = $CycleKey; action_ids = $actions }
  summary = [ordered]@{ failed = 0 }
  files = @($plan.files | ForEach-Object {
    [ordered]@{ relative_path = [string]$_.relative_path; sha256 = [string]$_.sha256; result = 'would_upload' }
  })
}
$json = $manifest | ConvertTo-Json -Depth 12 -Compress
[System.IO.File]::WriteAllText($ManifestPath, $json, [System.Text.UTF8Encoding]::new($false))
$scenario = Get-Content -LiteralPath (Join-Path $scenarioRoot 'scenario.json') -Raw | ConvertFrom-Json
if ([string]$scenario.after_dry_run -eq 'receipt_changed') {
  $receiptPath = Join-Path $scenarioRoot 'runtime\latest\seo-geo-validation-receipt.json'
  [System.IO.File]::WriteAllText($receiptPath, '{"fixture":"receipt changed during dry-run"}', [System.Text.UTF8Encoding]::new($false))
}
'@
  Write-Utf8NoBom (Join-Path $scriptsRoot 'deploy-ftp.ps1') $deployStub

  $forbiddenStub = @'
throw 'This later stage must not run in the stale-preflight fixture.'
'@
  Write-Utf8NoBom (Join-Path $scriptsRoot 'invoke-seo-geo-lifecycle-next.ps1') $forbiddenStub
  Write-Utf8NoBom (Join-Path $scriptsRoot 'write-seo-geo-live-verification.ps1') $forbiddenStub

  return [ordered]@{
    root = $ScenarioRoot
    runtime = $runtimeRoot
    scripts = $scriptsRoot
    call_log = Join-Path $ScenarioRoot 'deploy-calls.txt'
    journal = Join-Path $latestRoot 'seo-geo-autodeploy-journal.json'
    inspect_count = Join-Path $latestRoot 'plan-inspect-count.txt'
  }
}

function Invoke-And-AssertScenario {
  param([string]$ScenarioName, [ValidateSet('blocked', 'receipt_changed')][string]$AfterDryRun)
  $scenarioRoot = Join-Path $tempRoot $ScenarioName
  $scenario = New-TestScenario -ScenarioRoot $scenarioRoot -AfterDryRun $AfterDryRun
  $coordinator = Join-Path $scenario.scripts 'invoke-seo-geo-autodeploy.ps1'
  $output = @(& $pwshPath -NoLogo -NoProfile -ExecutionPolicy Bypass -File $coordinator -RuntimeRoot $scenario.runtime -Mode Execute 2>&1)
  $exitCode = $LASTEXITCODE
  Assert-True ($exitCode -ne 0) "$ScenarioName scenario should stop before actual FTP and return failure."
  Assert-True (Test-Path -LiteralPath $scenario.journal -PathType Leaf) "$ScenarioName scenario did not persist an auto-deploy journal."
  $journal = Get-Content -LiteralPath $scenario.journal -Raw -Encoding UTF8 | ConvertFrom-Json
  Assert-True ([string]$journal.status -eq 'failed') "$ScenarioName journal status must be failed."
  Assert-True ([string]$journal.current_stage -eq 'dry_run') "$ScenarioName journal must stop after the dry-run stage."
  Assert-True (@($journal.stages | Where-Object { [string]$_.stage -eq 'dry_run' -and [string]$_.status -eq 'passed' }).Count -eq 1) "$ScenarioName journal must record its verified dry-run."
  Assert-True ([int](Get-Content -LiteralPath $scenario.inspect_count -Raw) -eq 2) "$ScenarioName must perform the initial and post-dry-run inspections."
  $calls = @(Get-Content -LiteralPath $scenario.call_log -Encoding UTF8 | Where-Object { $_ })
  Assert-True ($calls.Count -eq 1 -and [string]$calls[0] -eq 'dry-run') "$ScenarioName should call only the local dry-run stub; calls=$($calls -join ',')."
  Assert-True ($calls -notcontains 'ftp') "$ScenarioName unexpectedly called the non-dry-run deployment stub."
  if ($AfterDryRun -eq 'blocked') {
    Assert-True ([string]$journal.error -match 'blocked after dry-run') ('Blocked provenance scenario has the wrong journal error: ' + [string]$journal.error)
  } else {
    Assert-True ([string]$journal.error -match 'validation receipt changed after dry-run') ('Receipt drift scenario has the wrong journal error: ' + [string]$journal.error)
  }
  Write-Host ("PASS {0}: dry-run recorded, second deploy skipped, journal failed at dry_run." -f $ScenarioName)
}

Assert-True (Test-Path -LiteralPath $coordinatorSource -PathType Leaf) "Coordinator not found: $coordinatorSource"
Assert-True (Test-Path -LiteralPath $pwshPath -PathType Leaf) "PowerShell 7 executable not found: $pwshPath"

$tempRoot = [System.IO.Path]::GetFullPath([System.IO.Path]::Combine([System.IO.Path]::GetTempPath(), ('curtain-sop-autodeploy-stale-' + [guid]::NewGuid().ToString('N'))))
$tempAllowedRoot = [System.IO.Path]::GetFullPath([System.IO.Path]::GetTempPath())
[void](Assert-TempPath -Path $tempRoot -TempRoot $tempAllowedRoot)
try {
  New-Item -ItemType Directory -Path $tempRoot -Force | Out-Null
  Assert-TempPath -Path $tempRoot -TempRoot $tempAllowedRoot | Out-Null
  Invoke-And-AssertScenario -ScenarioName 'provenance-drift' -AfterDryRun 'blocked'
  Invoke-And-AssertScenario -ScenarioName 'receipt-drift' -AfterDryRun 'receipt_changed'
  Write-Host 'PASS SOP auto-deploy stale-preflight integration tests (offline stubs only).'
} finally {
  if (Test-Path -LiteralPath $tempRoot -PathType Container) {
    $resolvedTempRoot = (Resolve-Path -LiteralPath $tempRoot).Path
    $safeResolvedTempRoot = Assert-TempPath -Path $resolvedTempRoot -TempRoot $tempAllowedRoot
    if ([System.IO.Path]::GetFullPath($safeResolvedTempRoot) -ne [System.IO.Path]::GetFullPath($tempRoot)) {
      throw "Refusing to clean a temp path that resolved unexpectedly: $safeResolvedTempRoot"
    }
    Remove-Item -LiteralPath $safeResolvedTempRoot -Recurse -Force
  }
}
