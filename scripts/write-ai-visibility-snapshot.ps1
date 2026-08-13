#requires -Version 7.0
[CmdletBinding()]
param(
  [Parameter(Mandatory = $true)][string]$RuntimeRoot,
  [Parameter(Mandatory = $true)][string]$InputPath,
  [string]$QuestionSetPath = ''
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$utf8NoBom = [System.Text.UTF8Encoding]::new($false)

function Read-Json([string]$Path) {
  if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { throw "Required JSON file not found: $Path" }
  return Get-Content -LiteralPath $Path -Raw -Encoding UTF8 | ConvertFrom-Json
}
function Write-JsonAtomic([string]$Path, [object]$Value) {
  $directory = Split-Path -Parent $Path
  if (-not (Test-Path -LiteralPath $directory -PathType Container)) { [void](New-Item -ItemType Directory -Path $directory -Force) }
  $temp = "$Path.tmp.$([guid]::NewGuid().ToString('N'))"
  try {
    $text = $Value | ConvertTo-Json -Depth 40
    $null = $text | ConvertFrom-Json
    [System.IO.File]::WriteAllText($temp, $text + [Environment]::NewLine, $utf8NoBom)
    [System.IO.File]::Move($temp, $Path, $true)
  } finally { if (Test-Path -LiteralPath $temp) { Remove-Item -LiteralPath $temp -Force -ErrorAction SilentlyContinue } }
}
function Get-Sha256([string]$Path) { return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant() }
function Get-RelativePath([string]$Root, [string]$Path) { return ([IO.Path]::GetRelativePath($Root, $Path) -replace '\\', '/') }
function Require-NonEmpty([object]$Value, [string]$Label) { if ([string]::IsNullOrWhiteSpace([string]$Value)) { throw "$Label is required." } }

$root = (Resolve-Path -LiteralPath $RuntimeRoot).Path
$repoRoot = Split-Path -Parent $PSScriptRoot
if ([string]::IsNullOrWhiteSpace($QuestionSetPath)) { $QuestionSetPath = Join-Path $repoRoot 'Weekly SOP\config\ai-visibility-question-set.json' }
$questionSetPathResolved = (Resolve-Path -LiteralPath $QuestionSetPath).Path
$inputPathResolved = (Resolve-Path -LiteralPath $InputPath).Path
$input = Read-Json $inputPathResolved
$questionSet = Read-Json $questionSetPathResolved

if ([int]$questionSet.schema_version -ne 1 -or [string]::IsNullOrWhiteSpace([string]$questionSet.question_set_id)) { throw 'Question set must be schema_version=1 with question_set_id.' }
Require-NonEmpty $input.run_id 'run_id'
Require-NonEmpty $input.engine 'engine'
Require-NonEmpty $input.model 'model'
Require-NonEmpty $input.observed_at 'observed_at'
if ([string]$input.measurement_source -ne 'direct_ai_engine_observation') { throw 'measurement_source must be direct_ai_engine_observation; GSC-derived AI metrics are prohibited.' }
$observedAt = [datetimeoffset]::Parse([string]$input.observed_at).ToUniversalTime()
$monthKey = $observedAt.ToString('yyyy-MM')

$expected = @($questionSet.questions)
$actual = @($input.observations)
if ($actual.Count -ne $expected.Count) { throw "Observation count must exactly match the fixed question set ($($expected.Count))." }
$expectedIds = @($expected | ForEach-Object { [string]$_.question_id } | Sort-Object)
$actualIds = @($actual | ForEach-Object { [string]$_.question_id } | Sort-Object)
if (($expectedIds -join '|') -cne ($actualIds -join '|')) { throw 'Observations must contain every fixed question_id exactly once.' }

$normalized = @()
foreach ($question in $expected) {
  $row = @($actual | Where-Object { [string]$_.question_id -eq [string]$question.question_id })[0]
  if ($null -eq $row) { throw "Missing observation for question_id=$($question.question_id)." }
  foreach ($field in @('answer','region','device','brand_context')) { Require-NonEmpty $row.$field "observation.$field for $($question.question_id)" }
  if ([string]$row.region -ne [string]$question.region -or [string]$row.device -ne [string]$question.device -or [string]$row.brand_context -ne [string]$question.brand_context) { throw "Observation context must match fixed question context: $($question.question_id)." }
  if ($row.brand_mentioned -isnot [bool]) { throw "brand_mentioned must be Boolean: $($question.question_id)." }
  $accuracy = [string]$row.accuracy
  if ($accuracy -notin @('correct','incorrect','unverified')) { throw "accuracy must be correct, incorrect, or unverified: $($question.question_id)." }
  $citations = if ($null -eq $row.citation_urls) { @() } else { @($row.citation_urls) }
  foreach ($citation in $citations) { $uri = $null; if (-not [uri]::TryCreate([string]$citation, [UriKind]::Absolute, [ref]$uri) -or $uri.Scheme -notin @('http','https')) { throw "citation_urls must contain absolute http(s) URLs: $($question.question_id)" } }
  $normalized += [ordered]@{
    question_id = [string]$question.question_id; question = [string]$question.question; locale = [string]$questionSet.locale
    region = [string]$question.region; device = [string]$question.device; brand_context = [string]$question.brand_context
    answer = [string]$row.answer; brand_mentioned = [bool]$row.brand_mentioned; citation_urls = @($citations | ForEach-Object { [string]$_ })
    accuracy = $accuracy; accuracy_note = [string]$row.accuracy_note
  }
}

$inputSha = Get-Sha256 $inputPathResolved
$questionSetSha = Get-Sha256 $questionSetPathResolved
$snapshotId = ('ai-visibility-{0}-{1}' -f $observedAt.ToString('yyyyMMddTHHmmssZ'), $inputSha.Substring(0, 12))
$historyRoot = Join-Path $root 'history\curtain-online\ai-visibility'
$snapshotPath = Join-Path $historyRoot ("snapshots\{0}\{1}.json" -f $monthKey, $snapshotId)
$receiptPath = Join-Path $historyRoot ("receipts\{0}.json" -f $snapshotId)
$monthlyPath = Join-Path $historyRoot ("monthly\{0}.json" -f $monthKey)
$latestRoot = Join-Path $root 'latest'
$summaryPath = Join-Path $latestRoot 'ai-visibility-summary.json'
$latestReceiptPath = Join-Path $latestRoot 'ai-visibility-receipt.json'

$mentionCount = @($normalized | Where-Object { $_.brand_mentioned }).Count
$citationCount = @($normalized | Where-Object { @($_.citation_urls).Count -gt 0 }).Count
$evaluated = @($normalized | Where-Object { $_.accuracy -in @('correct','incorrect') })
$correctCount = @($evaluated | Where-Object { $_.accuracy -eq 'correct' }).Count
$metrics = [ordered]@{
  sample_size = $normalized.Count; mention_count = $mentionCount; mention_rate = [math]::Round(100 * $mentionCount / $normalized.Count, 2)
  citation_count = $citationCount; citation_rate = [math]::Round(100 * $citationCount / $normalized.Count, 2)
  accuracy_evaluated_count = $evaluated.Count; accuracy_correct_count = $correctCount
  accuracy_rate = if ($evaluated.Count -gt 0) { [math]::Round(100 * $correctCount / $evaluated.Count, 2) } else { $null }
  accuracy_unverified_count = @($normalized | Where-Object { $_.accuracy -eq 'unverified' }).Count
}
$snapshot = [ordered]@{
  schema_version = 1; snapshot_id = $snapshotId; status = 'complete'; measurement_source = 'direct_ai_engine_observation'; gsc_inference_prohibited = $true
  question_set = [ordered]@{ id = [string]$questionSet.question_set_id; path = Get-RelativePath $root $questionSetPathResolved; sha256 = $questionSetSha; locale = [string]$questionSet.locale }
  run = [ordered]@{ run_id = [string]$input.run_id; engine = [string]$input.engine; model = [string]$input.model; observed_at = $observedAt.ToString('o'); date = $observedAt.ToString('yyyy-MM-dd') }
  source_input = [ordered]@{ path = Get-RelativePath $root $inputPathResolved; sha256 = $inputSha }
  metrics = $metrics; observations = $normalized
}

if (-not (Test-Path -LiteralPath $snapshotPath -PathType Leaf)) { Write-JsonAtomic $snapshotPath $snapshot }
$snapshotSha = Get-Sha256 $snapshotPath
$receipt = [ordered]@{
  schema_version = 1; receipt_type = 'ai_visibility_snapshot'; status = 'verified'; issued_at = (Get-Date).ToUniversalTime().ToString('o'); snapshot_id = $snapshotId
  measurement_source = 'direct_ai_engine_observation'; gsc_inference_prohibited = $true
  question_set = $snapshot.question_set; source_input = $snapshot.source_input
  snapshot = [ordered]@{ path = Get-RelativePath $root $snapshotPath; sha256 = $snapshotSha }
  metrics = $metrics
}
Write-JsonAtomic $receiptPath $receipt
$receiptSha = Get-Sha256 $receiptPath

$monthly = if (Test-Path -LiteralPath $monthlyPath -PathType Leaf) { Read-Json $monthlyPath } else { [pscustomobject]@{ schema_version = 1; month = $monthKey; measurement_source = 'direct_ai_engine_observation'; gsc_inference_prohibited = $true; snapshots = @() } }
$prior = @($monthly.snapshots | Where-Object { [string]$_.snapshot_id -eq $snapshotId })
if ($prior.Count -eq 0) {
  $monthly.snapshots = @($monthly.snapshots) + @([ordered]@{ snapshot_id = $snapshotId; observed_at = $snapshot.run.observed_at; engine = $snapshot.run.engine; model = $snapshot.run.model; snapshot_path = $receipt.snapshot.path; snapshot_sha256 = $snapshotSha; receipt_path = Get-RelativePath $root $receiptPath; receipt_sha256 = $receiptSha; metrics = $metrics })
}
$monthly | Add-Member -Force -NotePropertyName updated_at -NotePropertyValue ((Get-Date).ToUniversalTime().ToString('o'))
Write-JsonAtomic $monthlyPath $monthly
$monthlySha = Get-Sha256 $monthlyPath

$summary = [ordered]@{
  schema_version = 1; status = 'complete'; measurement_source = 'direct_ai_engine_observation'; gsc_inference_prohibited = $true; generated_at = (Get-Date).ToUniversalTime().ToString('o')
  latest_snapshot = [ordered]@{ id = $snapshotId; path = $receipt.snapshot.path; sha256 = $snapshotSha; observed_at = $snapshot.run.observed_at; engine = $snapshot.run.engine; model = $snapshot.run.model }
  metrics = $metrics
  monthly_history = [ordered]@{ month = $monthKey; path = Get-RelativePath $root $monthlyPath; sha256 = $monthlySha; snapshot_count = @($monthly.snapshots).Count }
  receipt = [ordered]@{ path = Get-RelativePath $root $receiptPath; sha256 = $receiptSha }
}
Write-JsonAtomic $summaryPath $summary
Write-JsonAtomic $latestReceiptPath $receipt
[pscustomobject]@{ status = 'complete'; idempotent = ($prior.Count -gt 0); snapshot_id = $snapshotId; summary_path = (Get-RelativePath $root $summaryPath); summary_sha256 = (Get-Sha256 $summaryPath); mention_rate = $metrics.mention_rate; citation_rate = $metrics.citation_rate; accuracy_rate = $metrics.accuracy_rate; monthly_snapshot_count = @($monthly.snapshots).Count } | ConvertTo-Json -Compress
