#requires -Version 7.0
[CmdletBinding()]
param(
  [Parameter(Mandatory = $true)][string]$RuntimeRoot,
  [string]$BaselineObservationPath = '',
  [string]$QuestionSetPath = '',
  [string]$InboxPath = '',
  [string]$Model = 'gpt-5.6-luna',
  [string]$ResponseFixturePath = '',
  [int]$TimeoutSec = 120,
  [int]$Retries = 2,
  [string]$ComparisonOutputPath = ''
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$utf8NoBom = [Text.UTF8Encoding]::new($false)
$ownedDomains = @('online.hong-sen.com', 'www.hong-sen.com')

function Read-Json([string]$Path) {
  if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { throw "Required JSON file not found: $Path" }
  return Get-Content -LiteralPath $Path -Raw -Encoding UTF8 | ConvertFrom-Json
}

function Write-JsonAtomic([string]$Path, [object]$Value) {
  $directory = Split-Path -Parent $Path
  if (-not (Test-Path -LiteralPath $directory -PathType Container)) { [void](New-Item -ItemType Directory -Path $directory -Force) }
  $temp = "$Path.tmp.$([guid]::NewGuid().ToString('N'))"
  try {
    $json = $Value | ConvertTo-Json -Depth 50
    $null = $json | ConvertFrom-Json
    [IO.File]::WriteAllText($temp, $json + [Environment]::NewLine, $utf8NoBom)
    [IO.File]::Move($temp, $Path, $true)
  } finally {
    if (Test-Path -LiteralPath $temp) { Remove-Item -LiteralPath $temp -Force -ErrorAction SilentlyContinue }
  }
}

function Get-Sha256([string]$Path) {
  return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()
}

function Get-RelativePath([string]$BasePath, [string]$Path) {
  return [IO.Path]::GetRelativePath($BasePath, $Path).Replace('\', '/')
}

function Get-AnswerSha256([string]$Answer) {
  $bytes = $utf8NoBom.GetBytes($Answer)
  return ([Convert]::ToHexString([Security.Cryptography.SHA256]::HashData($bytes))).ToLowerInvariant()
}

function Get-QuestionIds([object]$Observation) {
  return @($Observation.observations | ForEach-Object { [string]$_.question_id })
}

function Get-CitationDomains([object]$ObservationRow) {
  $domains = @()
  foreach ($url in @($ObservationRow.citation_urls)) {
    try { $domains += ([Uri]([string]$url)).Host.ToLowerInvariant() } catch { }
  }
  return @($domains | Sort-Object -Unique)
}

function Get-ComparisonMetrics([object]$Observation) {
  $rows = @($Observation.observations)
  if ($rows.Count -eq 0) { throw 'Observation must contain at least one question.' }
  $brandRows = @($rows | Where-Object { [string]$_.brand_context -eq 'brand' })
  $nonBrandRows = @($rows | Where-Object { [string]$_.brand_context -ne 'brand' })
  function Get-GroupMetrics([object[]]$GroupRows) {
    $sampleSize = $GroupRows.Count
    $mentioned = @($GroupRows | Where-Object { [bool]$_.brand_mentioned }).Count
    $cited = @($GroupRows | Where-Object { @($_.citation_urls).Count -gt 0 }).Count
    return [ordered]@{
      sample_size = $sampleSize
      mention_count = $mentioned
      mention_rate = if ($sampleSize -gt 0) { [Math]::Round(100 * $mentioned / $sampleSize, 2) } else { $null }
      citation_count = $cited
      citation_rate = if ($sampleSize -gt 0) { [Math]::Round(100 * $cited / $sampleSize, 2) } else { $null }
    }
  }
  $ownedCited = @($rows | Where-Object { @((Get-CitationDomains $_) | Where-Object { $_ -in $ownedDomains }).Count -gt 0 }).Count
  $externalCited = @($rows | Where-Object { @((Get-CitationDomains $_) | Where-Object { $_ -notin $ownedDomains }).Count -gt 0 }).Count
  $byOwnedDomain = [ordered]@{}
  foreach ($domain in $ownedDomains) {
    $count = @($rows | Where-Object { (Get-CitationDomains $_) -contains $domain }).Count
    $byOwnedDomain[$domain] = [ordered]@{
      cited_question_count = $count
      cited_question_rate = [Math]::Round(100 * $count / $rows.Count, 2)
    }
  }
  $mentionedTotal = @($rows | Where-Object { [bool]$_.brand_mentioned }).Count
  $citedTotal = @($rows | Where-Object { @($_.citation_urls).Count -gt 0 }).Count
  return [ordered]@{
    sample_size = $rows.Count
    mention_count = $mentionedTotal
    mention_rate = [Math]::Round(100 * $mentionedTotal / $rows.Count, 2)
    citation_count = $citedTotal
    citation_rate = [Math]::Round(100 * $citedTotal / $rows.Count, 2)
    brand = Get-GroupMetrics $brandRows
    non_brand = Get-GroupMetrics $nonBrandRows
    citations = [ordered]@{
      owned = [ordered]@{ citation_count = $ownedCited; citation_rate = [Math]::Round(100 * $ownedCited / $rows.Count, 2) }
      external = [ordered]@{ citation_count = $externalCited; citation_rate = [Math]::Round(100 * $externalCited / $rows.Count, 2) }
      by_owned_domain = $byOwnedDomain
    }
  }
}

function Get-BaselinePath([string]$Root) {
  $receiptPath = Join-Path $Root 'latest\ai-visibility-receipt.json'
  $receipt = Read-Json $receiptPath
  if ([string]$receipt.status -ne 'verified' -or [string]$receipt.measurement_source -ne 'direct_ai_engine_observation') {
    throw 'The current AI Visibility receipt is not a verified direct observation; provide -BaselineObservationPath explicitly.'
  }
  $relative = [string]$receipt.source_input.path
  if ([string]::IsNullOrWhiteSpace($relative)) { throw 'The current AI Visibility receipt does not identify its source observation.' }
  return Join-Path $Root ($relative.Replace('/', [IO.Path]::DirectorySeparatorChar))
}

$root = (Resolve-Path -LiteralPath $RuntimeRoot).Path
if ($Model -ne 'gpt-5.6-luna') { throw 'Luna comparison requires -Model gpt-5.6-luna so the comparison remains unambiguous.' }
if ([string]::IsNullOrWhiteSpace($QuestionSetPath)) { $QuestionSetPath = Join-Path $root 'config\ai-visibility-question-set.json' }
if ([string]::IsNullOrWhiteSpace($InboxPath)) { $InboxPath = Join-Path $root 'inbox\ai-visibility' }
if ([string]::IsNullOrWhiteSpace($BaselineObservationPath)) { $BaselineObservationPath = Get-BaselinePath $root }
if ([string]::IsNullOrWhiteSpace($ComparisonOutputPath)) { $ComparisonOutputPath = Join-Path $root 'latest\ai-visibility-luna-comparison.json' }

$baselinePath = (Resolve-Path -LiteralPath $BaselineObservationPath).Path
$baseline = Read-Json $baselinePath
if ([string]$baseline.measurement_source -ne 'direct_ai_engine_observation') { throw 'Baseline must be a direct AI engine observation.' }
if ([string]$baseline.model -notmatch '^gpt-5\.4-mini') { throw "Baseline must be the saved gpt-5.4-mini observation, got '$($baseline.model)'." }
$questionSet = Read-Json $QuestionSetPath
$questionIds = @($questionSet.questions | ForEach-Object { [string]$_.question_id })
if ($questionIds.Count -eq 0) { throw 'Question set contains no questions.' }
if (@(Compare-Object -ReferenceObject ($questionIds | Sort-Object) -DifferenceObject ((Get-QuestionIds $baseline) | Sort-Object)).Count -gt 0) {
  throw 'Baseline question IDs do not exactly match the fixed question set.'
}

$latestSummaryPath = Join-Path $root 'latest\ai-visibility-summary.json'
$latestSummaryShaBefore = if (Test-Path -LiteralPath $latestSummaryPath -PathType Leaf) { Get-Sha256 $latestSummaryPath } else { $null }
$runner = Join-Path $PSScriptRoot 'run-ai-visibility-observation.ps1'
if (-not (Test-Path -LiteralPath $runner -PathType Leaf)) { throw "Runner not found: $runner" }
$runnerArgs = @('-RuntimeRoot', $root, '-QuestionSetPath', $QuestionSetPath, '-InboxPath', $InboxPath, '-Model', $Model, '-TimeoutSec', $TimeoutSec, '-Retries', $Retries)
if (-not [string]::IsNullOrWhiteSpace($ResponseFixturePath)) { $runnerArgs += @('-ResponseFixturePath', $ResponseFixturePath) }

Write-Host 'Running the same fixed AI Visibility question set with gpt-5.6-luna. The current latest summary will not be imported or replaced.'
$runOutput = @(& pwsh -NoLogo -NoProfile -File $runner @runnerArgs 2>&1 | ForEach-Object { [string]$_ })
if ($LASTEXITCODE -ne 0) { throw ('Luna observation failed: ' + ($runOutput -join [Environment]::NewLine)) }
$runJson = @($runOutput | Where-Object { $_.Trim().StartsWith('{') -and $_.Trim().EndsWith('}') } | Select-Object -Last 1)
if ($runJson.Count -ne 1) { throw ('Could not read the Luna runner result: ' + ($runOutput -join [Environment]::NewLine)) }
$run = $runJson[0] | ConvertFrom-Json
$candidatePath = (Resolve-Path -LiteralPath ([string]$run.observation_path)).Path
$candidate = Read-Json $candidatePath
if ([string]$candidate.model -ne $Model -or [string]$candidate.measurement_source -ne 'direct_ai_engine_observation') { throw 'Candidate observation does not identify the expected Luna direct observation.' }
if ($candidatePath -eq $baselinePath) { throw 'Candidate observation unexpectedly overwrote the baseline.' }
if (@(Compare-Object -ReferenceObject ($questionIds | Sort-Object) -DifferenceObject ((Get-QuestionIds $candidate) | Sort-Object)).Count -gt 0) {
  throw 'Luna question IDs do not exactly match the fixed question set.'
}

$latestSummaryShaAfter = if (Test-Path -LiteralPath $latestSummaryPath -PathType Leaf) { Get-Sha256 $latestSummaryPath } else { $null }
$summaryUnchanged = $latestSummaryShaBefore -eq $latestSummaryShaAfter
if (-not $summaryUnchanged) { throw 'Safety gate failed: the current ai-visibility-summary.json changed during the Luna comparison.' }

$baselineById = @{}
foreach ($row in @($baseline.observations)) { $baselineById[[string]$row.question_id] = $row }
$candidateById = @{}
foreach ($row in @($candidate.observations)) { $candidateById[[string]$row.question_id] = $row }
$questionDeltas = @()
foreach ($questionId in $questionIds) {
  $before = $baselineById[$questionId]
  $after = $candidateById[$questionId]
  $questionDeltas += [ordered]@{
    question_id = $questionId
    brand_context = [string]$after.brand_context
    baseline = [ordered]@{
      brand_mentioned = [bool]$before.brand_mentioned
      citation_domains = @(Get-CitationDomains $before)
      answer_sha256 = Get-AnswerSha256 ([string]$before.answer)
      accuracy = [string]$before.accuracy
    }
    luna = [ordered]@{
      brand_mentioned = [bool]$after.brand_mentioned
      citation_domains = @(Get-CitationDomains $after)
      answer_sha256 = Get-AnswerSha256 ([string]$after.answer)
      accuracy = [string]$after.accuracy
    }
  }
}

$comparison = [ordered]@{
  schema_version = 1
  status = 'complete'
  comparison_type = 'fixed-question-set_model_ab_direct_observation'
  created_at = [datetimeoffset]::UtcNow.ToString('o')
  question_set = [ordered]@{
    path = Get-RelativePath $root ((Resolve-Path -LiteralPath $QuestionSetPath).Path)
    sha256 = Get-Sha256 $QuestionSetPath
    question_count = $questionIds.Count
  }
  baseline = [ordered]@{
    model = [string]$baseline.model
    observation_path = Get-RelativePath $root $baselinePath
    observation_sha256 = Get-Sha256 $baselinePath
    observed_at = [string]$baseline.observed_at
    metrics = Get-ComparisonMetrics $baseline
  }
  luna = [ordered]@{
    model = [string]$candidate.model
    observation_path = Get-RelativePath $root $candidatePath
    observation_sha256 = Get-Sha256 $candidatePath
    observed_at = [string]$candidate.observed_at
    metrics = Get-ComparisonMetrics $candidate
  }
  safety = [ordered]@{
    source_observations_are_distinct = $candidatePath -ne $baselinePath
    question_ids_match_fixed_set = $true
    latest_summary_path = Get-RelativePath $root $latestSummaryPath
    latest_summary_sha256_before = $latestSummaryShaBefore
    latest_summary_sha256_after = $latestSummaryShaAfter
    latest_summary_unchanged = $summaryUnchanged
    luna_imported_into_latest_summary = $false
  }
  question_deltas = $questionDeltas
  next_step = 'Review Luna answers manually before making any model-default change. This comparison does not overwrite the saved gpt-5.4-mini summary, receipt, or human accuracy review.'
}
Write-JsonAtomic -Path $ComparisonOutputPath -Value $comparison

[pscustomobject]@{
  status = 'complete'
  baseline_model = [string]$baseline.model
  luna_model = [string]$candidate.model
  questions = $questionIds.Count
  luna_observation_path = $candidatePath
  comparison_path = $ComparisonOutputPath
  latest_summary_unchanged = $summaryUnchanged
  luna_imported_into_latest_summary = $false
} | ConvertTo-Json -Compress
