[CmdletBinding()]
param(
  [Parameter(Mandatory = $true)][string]$RuntimeRoot,
  [Parameter(Mandatory = $true)][string[]]$Page,
  [Parameter(Mandatory = $true)][string]$ApprovedBy,
  [Parameter(Mandatory = $true)][string]$Reason,
  [string]$RepoRoot
)

$ErrorActionPreference = 'Stop'
$root = (Resolve-Path -LiteralPath $RuntimeRoot).Path
$weeklyRoot = if (Test-Path -LiteralPath (Join-Path $root 'latest\seo-geo-action-queue-state.json')) { $root } elseif (Test-Path -LiteralPath (Join-Path $root 'Weekly SOP\latest\seo-geo-action-queue-state.json')) { Join-Path $root 'Weekly SOP' } else { throw "Queue state not found under RuntimeRoot: $root" }
$repoFull = if ([string]::IsNullOrWhiteSpace($RepoRoot)) { Split-Path -Parent $PSScriptRoot } else { (Resolve-Path -LiteralPath $RepoRoot).Path }
$latestRoot = Join-Path $weeklyRoot 'latest'
$queuePath = Join-Path $latestRoot 'seo-geo-action-queue.json'
$statePath = Join-Path $latestRoot 'seo-geo-action-queue-state.json'
$receiptPath = Join-Path $latestRoot 'seo-geo-single-page-approval.json'
$slimPromptPath = Join-Path $latestRoot 'seo-geo-action-plan.slim.ai.md'
$aiPromptPath = Join-Path $latestRoot 'seo-geo-action-plan.ai.md'
$provenanceChecker = Join-Path $PSScriptRoot 'check-seo-geo-queue-provenance.ps1'
$utf8NoBom = [System.Text.UTF8Encoding]::new($false)

function Read-Json {
  param([Parameter(Mandatory = $true)][string]$Path)
  if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { throw "Required JSON does not exist: $Path" }
  return Get-Content -LiteralPath $Path -Raw -Encoding UTF8 | ConvertFrom-Json
}

function Normalize-Page {
  param([Parameter(Mandatory = $true)][string]$Value)
  $uri = [uri]$Value
  $path = $uri.AbsolutePath
  if (-not $path.EndsWith('/')) { $path += '/' }
  return ('https://online.hong-sen.com' + $path).ToLowerInvariant()
}

function Write-FilesTransaction {
  param([Parameter(Mandatory = $true)][hashtable]$Files)
  $old = @{}
  $temps = @{}
  $committed = @()
  try {
    foreach ($path in $Files.Keys) {
      $old[$path] = if (Test-Path -LiteralPath $path -PathType Leaf) { [System.IO.File]::ReadAllText($path, [System.Text.Encoding]::UTF8) } else { $null }
      $temp = $path + '.tmp.' + [guid]::NewGuid().ToString('N')
      [System.IO.File]::WriteAllText($temp, [string]$Files[$path], $utf8NoBom)
      $temps[$path] = $temp
    }
    foreach ($path in $Files.Keys) {
      [System.IO.File]::Move([string]$temps[$path], $path, $true)
      $committed += $path
    }
  } catch {
    foreach ($path in $committed) {
      if ($null -eq $old[$path]) {
        if (Test-Path -LiteralPath $path) { [System.IO.File]::Delete($path) }
      } else {
        [System.IO.File]::WriteAllText($path, [string]$old[$path], $utf8NoBom)
      }
    }
    throw
  } finally {
    foreach ($temp in $temps.Values) { if (Test-Path -LiteralPath $temp) { [System.IO.File]::Delete($temp) } }
  }
}

if ([string]::IsNullOrWhiteSpace($ApprovedBy) -or [string]::IsNullOrWhiteSpace($Reason)) { throw 'ApprovedBy and Reason must be non-empty.' }
$requestedPages = @($Page | ForEach-Object { $_ -split '\|' } | ForEach-Object { if (-not [string]::IsNullOrWhiteSpace($_)) { Normalize-Page -Value $_ } } | Select-Object -Unique)
if ($requestedPages.Count -eq 0 -or $requestedPages.Count -gt 6) { throw 'Approve between 1 and 6 explicitly selected single-page reviews.' }
if (-not (Test-Path -LiteralPath $provenanceChecker -PathType Leaf)) { throw "Provenance checker not found: $provenanceChecker" }
$provenanceOutput = @(& pwsh -NoLogo -NoProfile -File $provenanceChecker -RuntimeRoot $weeklyRoot -RepoRoot $repoFull -FailOnStale 2>&1)
if ($LASTEXITCODE -ne 0) { throw "Cannot approve a stale queue: $($provenanceOutput -join ' ')" }
$provenance = ($provenanceOutput | Select-Object -Last 1) | ConvertFrom-Json
if ([bool]$provenance.stale -or [string]$provenance.status -ne 'current') { throw "Cannot approve a stale queue: $($provenance.reasons -join ', ')" }

$queue = Read-Json -Path $queuePath
$state = Read-Json -Path $statePath
if ([int]$queue.schema_version -ne 2 -or [int]$state.schema_version -ne 2) { throw 'Queue/state schema_version must be 2.' }
if ([string]$queue.queue_id -ne [string]$state.queue_id -or [string]$queue.cycle_key -ne [string]$state.cycle_key) { throw 'Queue/state identity mismatch.' }
if ([string]$queue.status -ne 'observation_only' -or [string]$state.status -ne 'observation_only' -or @($queue.rounds).Count -ne 0 -or [int]$state.total_rounds -ne 0) { throw 'Single-page approval requires an observation_only queue with zero executable Rounds.' }

$actions = @()
foreach ($normalizedPage in $requestedPages) {
  $matches = @($queue.optional_opportunities | Where-Object { (Normalize-Page -Value ([string]$_.page)) -eq $normalizedPage -and [string]$_.review_type -in @('single_page_p0_review', 'single_page_alignment_review') -and [bool]$_.requires_user_approval })
  if ($matches.Count -ne 1) { throw "Expected exactly one approval-only single-page opportunity for: $normalizedPage" }
  $actions += $matches[0]
}

$rounds = @()
$stateRounds = @()
$promptFiles = @()
$promptTexts = @{}
for ($index = 0; $index -lt $actions.Count; $index++) {
  $action = $actions[$index]
  $roundNumber = $index + 1
  $validations = @($action.required_validations)
  if ($validations.Count -eq 0) { $validations = @('node .agents/skills/curtain-online-seo-geo/scripts/keyword-owner-check.mjs', 'npm.cmd run build', 'npm.cmd run seo:check', 'npm.cmd run seo:preflight') }
  $requiredSource = @($action.requiredSource | Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_) } | Select-Object -Unique)
  $rounds += [PSCustomObject][ordered]@{
    round = $roundNumber; type = 'single-page-approved'; priority = $roundNumber
    title = "Round $roundNumber approved single-page review: $($action.page)"
    targetCount = 1; targets = @([string]$action.page); ownerKeywords = @($action.ownerKeywords)
    action_ids = @([string]$action.action_id); action_fingerprints = @([string]$action.fingerprint)
    requiredSource = $requiredSource; required_validations = $validations; validationCommands = $validations; actions = @($action)
  }
  $promptRelative = "latest/seo-geo-action-plan.round-$roundNumber.slim.ai.md"
  $stateRounds += [PSCustomObject]@{ round = $roundNumber; action_ids = @([string]$action.action_id); action_fingerprints = @([string]$action.fingerprint); required_validations = $validations }
  $promptFiles += [PSCustomObject]@{ round = $roundNumber; path = $promptRelative; targetCount = 1; targets = @([string]$action.page); action_ids = @([string]$action.action_id); action_fingerprints = @([string]$action.fingerprint); required_validations = $validations }
  $prompt = @('PLEASE IMPLEMENT THIS PLAN:', '', "# Curtain Online SEO/GEO Round $roundNumber 單頁核准執行指令", '', "- 使用者已核准頁面：$($action.page)", "- 核准者：$($ApprovedBy.Trim())", "- 核准理由：$($Reason.Trim())", "- Queue：$($queue.queue_id)", "- Cycle：$($queue.cycle_key)", '', '## Boundary', '', '- 只實作本頁與本 action，不新增其他頁、詞或 Round。', '- 不直接修改 out/；不得略過驗證或自行手寫 validation receipt。', '', '## Action', '', "- action_id：$($action.action_id)", "- page：$($action.page)", "- owner keywords：$(@($action.ownerKeywords) -join '；')", "- action type：$($action.actionType)", "- reason：$($action.reason)", '', '## Required Source', '')
  foreach ($source in $requiredSource) { $prompt += ('- `{0}`' -f $source) }
  $prompt += @('', '## Validation', '')
  foreach ($validation in $validations) { $prompt += ('- `{0}`' -f $validation) }
  $prompt += @('', '## Receipt', '', "- 驗證全數通過後，使用 scripts/write-seo-geo-validation-receipt.ps1，固定綁定 Queue $($queue.queue_id)、Cycle $($queue.cycle_key)、Round $roundNumber。")
  $promptTexts[$promptRelative] = ($prompt -join [Environment]::NewLine) + [Environment]::NewLine
}

$queue.status = 'active'
$queue.rounds = $rounds
$queue.optional_opportunities = @($queue.optional_opportunities | Where-Object { [string]$_.action_id -notin @($actions | ForEach-Object { [string]$_.action_id }) })
foreach ($observation in @($queue.observations)) { if ((Normalize-Page -Value ([string]$observation.page)) -in $requestedPages) { $observation.disposition = 'queued'; $observation.reason = '使用者已核准單頁 review，已建立正式單頁 executable Round。' } }

$state.status = 'active'
$state.active_round = 1
$state.next_round = 1
$state.completed_rounds = @()
$state.copied_rounds = @()
$state.total_rounds = $rounds.Count
$state.rounds = $stateRounds
$state.prompt_files = $promptFiles
$state.note = 'Explicitly approved single-page reviews; each Round requires a matching passed validation receipt before advancing.'
$state | Add-Member -NotePropertyName single_page_approval_receipt_path -NotePropertyValue 'latest/seo-geo-single-page-approval.json' -Force

$now = (Get-Date).ToUniversalTime().ToString('o')
$receipt = [ordered]@{
  schema_version = 1
  status = 'approved'
  approved_at = $now
  approved_by = $ApprovedBy.Trim()
  reason = $Reason.Trim()
  queue_id = [string]$queue.queue_id
  cycle_key = [string]$queue.cycle_key
  page = [string]$actions[0].page
  action_id = [string]$actions[0].action_id
  action_fingerprint = [string]$actions[0].fingerprint
  round = 1
  approvals = @($actions | ForEach-Object { [ordered]@{ page = [string]$_.page; action_id = [string]$_.action_id; action_fingerprint = [string]$_.fingerprint; review_type = [string]$_.review_type } })
  provenance = $provenance
}

$files = @{}
$files[$queuePath] = ($queue | ConvertTo-Json -Depth 20) + [Environment]::NewLine
$files[$statePath] = ($state | ConvertTo-Json -Depth 20) + [Environment]::NewLine
$files[$receiptPath] = ($receipt | ConvertTo-Json -Depth 10) + [Environment]::NewLine
$promptTexts.GetEnumerator() | ForEach-Object { $files[(Join-Path $weeklyRoot $_.Key)] = $_.Value }
$files[$slimPromptPath] = $promptTexts['latest/seo-geo-action-plan.round-1.slim.ai.md']
$files[$aiPromptPath] = $promptTexts['latest/seo-geo-action-plan.round-1.slim.ai.md']
Write-FilesTransaction -Files $files

[PSCustomObject]@{ status = 'approved'; queue_id = $queue.queue_id; cycle_key = $queue.cycle_key; pages = @($actions | ForEach-Object { [string]$_.page }); total_rounds = $rounds.Count; receipt = 'latest/seo-geo-single-page-approval.json'; prompt = 'latest/seo-geo-action-plan.round-1.slim.ai.md' } | ConvertTo-Json -Depth 5 -Compress
