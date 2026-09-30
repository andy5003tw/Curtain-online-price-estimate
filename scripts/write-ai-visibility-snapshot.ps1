#requires -Version 7.0
[CmdletBinding()]
param(
  [Parameter(Mandatory = $true)][string]$RuntimeRoot,
  [Parameter(Mandatory = $true)][string]$InputPath,
  [string]$QuestionSetPath = '',
  [string]$ReviewPath = ''
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
function Get-Rate([int]$Numerator, [int]$Denominator) {
  if ($Denominator -eq 0) { return $null }
  return [math]::Round(100 * $Numerator / $Denominator, 2)
}
function Get-CitationHosts([object]$Row) {
  $hosts = @()
  foreach ($citation in @($Row.citation_urls)) {
    $hosts += ([uri][string]$citation).DnsSafeHost.ToLowerInvariant()
  }
  return @($hosts | Sort-Object -Unique)
}
function Get-VisibilitySlice([object[]]$Rows, [string[]]$OwnedDomains) {
  $rows = @($Rows)
  $sampleSize = $rows.Count
  $mentionCount = @($rows | Where-Object { $_.brand_mentioned }).Count
  $citationCount = @($rows | Where-Object { @($_.citation_hosts).Count -gt 0 }).Count
  $ownedCitationCount = @($rows | Where-Object { @($_.citation_hosts | Where-Object { $_ -in $OwnedDomains }).Count -gt 0 }).Count
  $externalCitationCount = @($rows | Where-Object { @($_.citation_hosts | Where-Object { $_ -notin $OwnedDomains }).Count -gt 0 }).Count
  return [ordered]@{
    sample_size = $sampleSize
    mention_count = $mentionCount; mention_rate = Get-Rate $mentionCount $sampleSize
    citation_count = $citationCount; citation_rate = Get-Rate $citationCount $sampleSize
    owned_citation_count = $ownedCitationCount; owned_citation_rate = Get-Rate $ownedCitationCount $sampleSize
    external_citation_count = $externalCitationCount; external_citation_rate = Get-Rate $externalCitationCount $sampleSize
  }
}

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

$inputSha = Get-Sha256 $inputPathResolved
$review = $null
$reviewPathResolved = ''
$reviewSha = ''
$reviewByQuestionId = @{}
if (-not [string]::IsNullOrWhiteSpace($ReviewPath)) {
  $reviewPathResolved = (Resolve-Path -LiteralPath $ReviewPath).Path
  $review = Read-Json $reviewPathResolved
  if ([int]$review.schema_version -ne 1 -or [string]$review.review_type -ne 'ai_visibility_human_accuracy_review') { throw 'Review must be schema_version=1 and review_type=ai_visibility_human_accuracy_review.' }
  Require-NonEmpty $review.reviewed_at 'reviewed_at'
  Require-NonEmpty $review.reviewer 'reviewer'
  if ([string]$review.source_observation.sha256 -ne $inputSha) { throw 'Review source_observation.sha256 does not match InputPath.' }
  $reviewRows = @($review.reviews)
  $reviewIds = @($reviewRows | ForEach-Object { [string]$_.question_id } | Sort-Object)
  if ($reviewRows.Count -ne $expected.Count -or ($reviewIds -join '|') -cne ($expectedIds -join '|')) { throw 'Review must contain one status for every fixed question_id.' }
  foreach ($reviewRow in $reviewRows) {
    $reviewAccuracy = [string]$reviewRow.accuracy
    if ($reviewAccuracy -notin @('correct','partial','incorrect')) { throw "Review accuracy must be correct, partial, or incorrect: $($reviewRow.question_id)." }
    Require-NonEmpty $reviewRow.accuracy_note "review.accuracy_note for $($reviewRow.question_id)"
    $reviewByQuestionId[[string]$reviewRow.question_id] = $reviewRow
  }
  $reviewSha = Get-Sha256 $reviewPathResolved
}

$normalized = @()
foreach ($question in $expected) {
  $row = @($actual | Where-Object { [string]$_.question_id -eq [string]$question.question_id })[0]
  if ($null -eq $row) { throw "Missing observation for question_id=$($question.question_id)." }
  foreach ($field in @('answer','region','device','brand_context')) { Require-NonEmpty $row.$field "observation.$field for $($question.question_id)" }
  if ([string]$row.region -ne [string]$question.region -or [string]$row.device -ne [string]$question.device -or [string]$row.brand_context -ne [string]$question.brand_context) { throw "Observation context must match fixed question context: $($question.question_id)." }
  if ($row.brand_mentioned -isnot [bool]) { throw "brand_mentioned must be Boolean: $($question.question_id)." }
  $sourceAccuracy = [string]$row.accuracy
  if ($sourceAccuracy -notin @('correct','partial','incorrect','unverified')) { throw "accuracy must be correct, partial, incorrect, or unverified: $($question.question_id)." }
  $accuracy = $sourceAccuracy
  $accuracyNote = [string]$row.accuracy_note
  $reviewRow = if ($null -ne $review) { $reviewByQuestionId[[string]$question.question_id] } else { $null }
  if ($null -ne $reviewRow) {
    $accuracy = [string]$reviewRow.accuracy
    $accuracyNote = [string]$reviewRow.accuracy_note
  }
  $citations = if ($null -eq $row.citation_urls) { @() } else { @($row.citation_urls) }
  foreach ($citation in $citations) { $uri = $null; if (-not [uri]::TryCreate([string]$citation, [UriKind]::Absolute, [ref]$uri) -or $uri.Scheme -notin @('http','https')) { throw "citation_urls must contain absolute http(s) URLs: $($question.question_id)" } }
  $normalized += [ordered]@{
    question_id = [string]$question.question_id; question = [string]$question.question; locale = [string]$questionSet.locale
    region = [string]$question.region; device = [string]$question.device; brand_context = [string]$question.brand_context
    answer = [string]$row.answer; brand_mentioned = [bool]$row.brand_mentioned; citation_urls = @($citations | ForEach-Object { [string]$_ })
    source_accuracy = $sourceAccuracy; accuracy = $accuracy; accuracy_note = $accuracyNote; accuracy_reviewed = ($null -ne $reviewRow)
  }
}

$questionSetSha = Get-Sha256 $questionSetPathResolved
$snapshotId = ('ai-visibility-{0}-{1}' -f $observedAt.ToString('yyyyMMddTHHmmssZ'), $inputSha.Substring(0, 12))
$historyRoot = Join-Path $root 'history\curtain-online\ai-visibility'
$snapshotPath = Join-Path $historyRoot ("snapshots\{0}\{1}.json" -f $monthKey, $snapshotId)
$receiptPath = Join-Path $historyRoot ("receipts\{0}.json" -f $snapshotId)
$monthlyPath = Join-Path $historyRoot ("monthly\{0}.json" -f $monthKey)
$latestRoot = Join-Path $root 'latest'
$summaryPath = Join-Path $latestRoot 'ai-visibility-summary.json'
$latestReceiptPath = Join-Path $latestRoot 'ai-visibility-receipt.json'

$ownedDomains = @('online.hong-sen.com', 'www.hong-sen.com')
foreach ($row in $normalized) { $row.citation_hosts = @(Get-CitationHosts $row) }
$overallVisibility = Get-VisibilitySlice $normalized $ownedDomains
$brandVisibility = Get-VisibilitySlice @($normalized | Where-Object { $_.brand_context -eq 'brand' }) $ownedDomains
$nonBrandVisibility = Get-VisibilitySlice @($normalized | Where-Object { $_.brand_context -eq 'non_brand' }) $ownedDomains
$domainCitationMetrics = [ordered]@{}
foreach ($domain in $ownedDomains) {
  $citedRows = @($normalized | Where-Object { $domain -in @($_.citation_hosts) })
  $domainCitationMetrics[$domain] = [ordered]@{
    cited_question_count = $citedRows.Count
    cited_question_rate = Get-Rate $citedRows.Count $normalized.Count
  }
}
$evaluated = @($normalized | Where-Object { $_.accuracy -in @('correct','partial','incorrect') })
$correctCount = @($evaluated | Where-Object { $_.accuracy -eq 'correct' }).Count
$partialCount = @($evaluated | Where-Object { $_.accuracy -eq 'partial' }).Count
$incorrectCount = @($evaluated | Where-Object { $_.accuracy -eq 'incorrect' }).Count
$metrics = [ordered]@{
  metrics_schema_version = 3
  sample_size = $overallVisibility.sample_size; mention_count = $overallVisibility.mention_count; mention_rate = $overallVisibility.mention_rate
  citation_count = $overallVisibility.citation_count; citation_rate = $overallVisibility.citation_rate
  brand = $brandVisibility; non_brand = $nonBrandVisibility
  citations = [ordered]@{
    measurement = 'Question-level: a question counts once when it has one or more matching citation URLs.'
    owned_domains = $ownedDomains
    owned = [ordered]@{ citation_count = $overallVisibility.owned_citation_count; citation_rate = $overallVisibility.owned_citation_rate }
    external = [ordered]@{ citation_count = $overallVisibility.external_citation_count; citation_rate = $overallVisibility.external_citation_rate }
    by_owned_domain = $domainCitationMetrics
  }
  accuracy_evaluated_count = $evaluated.Count; accuracy_correct_count = $correctCount; accuracy_partial_count = $partialCount; accuracy_incorrect_count = $incorrectCount
  accuracy_rate = Get-Rate $correctCount $evaluated.Count; accuracy_partial_rate = Get-Rate $partialCount $evaluated.Count
  accuracy_non_incorrect_rate = Get-Rate ($correctCount + $partialCount) $evaluated.Count
  accuracy_unverified_count = @($normalized | Where-Object { $_.accuracy -eq 'unverified' }).Count
}
$accuracyReviewProvenance = if ($null -eq $review) { $null } else { [ordered]@{ path = Get-RelativePath $root $reviewPathResolved; sha256 = $reviewSha; reviewed_at = [datetimeoffset]::Parse([string]$review.reviewed_at).ToUniversalTime().ToString('o'); reviewer = [string]$review.reviewer } }
$snapshot = [ordered]@{
  schema_version = 1; snapshot_id = $snapshotId; status = 'complete'; measurement_source = 'direct_ai_engine_observation'; gsc_inference_prohibited = $true
  question_set = [ordered]@{ id = [string]$questionSet.question_set_id; path = Get-RelativePath $root $questionSetPathResolved; sha256 = $questionSetSha; locale = [string]$questionSet.locale }
  run = [ordered]@{ run_id = [string]$input.run_id; engine = [string]$input.engine; model = [string]$input.model; observed_at = $observedAt.ToString('o'); date = $observedAt.ToString('yyyy-MM-dd') }
  source_input = [ordered]@{ path = Get-RelativePath $root $inputPathResolved; sha256 = $inputSha }
  accuracy_review = $accuracyReviewProvenance
  metrics = $metrics; observations = $normalized
}

$existingSnapshot = if (Test-Path -LiteralPath $snapshotPath -PathType Leaf) { Read-Json $snapshotPath } else { $null }
# Snapshot evidence is immutable for a given input except for a reporting-schema
# migration or a new review overlay.  Neither case alters the raw observation.
$existingMetricsSchemaVersion = 0
$existingReviewSha = ''
if ($null -ne $existingSnapshot -and $null -ne $existingSnapshot.metrics) {
  $existingVersionProperty = $existingSnapshot.metrics.PSObject.Properties['metrics_schema_version']
  if ($null -ne $existingVersionProperty) { $existingMetricsSchemaVersion = [int]$existingVersionProperty.Value }
}
if ($null -ne $existingSnapshot) {
  $existingReviewProperty = $existingSnapshot.PSObject.Properties['accuracy_review']
  if ($null -ne $existingReviewProperty -and $null -ne $existingReviewProperty.Value) {
    $existingReviewShaProperty = $existingReviewProperty.Value.PSObject.Properties['sha256']
    if ($null -ne $existingReviewShaProperty) { $existingReviewSha = [string]$existingReviewShaProperty.Value }
  }
}
if ($null -eq $existingSnapshot -or $existingMetricsSchemaVersion -lt 3 -or $existingReviewSha -ne $reviewSha) { Write-JsonAtomic $snapshotPath $snapshot }
$snapshotSha = Get-Sha256 $snapshotPath
$receipt = [ordered]@{
  schema_version = 1; receipt_type = 'ai_visibility_snapshot'; status = 'verified'; issued_at = (Get-Date).ToUniversalTime().ToString('o'); snapshot_id = $snapshotId
  measurement_source = 'direct_ai_engine_observation'; gsc_inference_prohibited = $true
  question_set = $snapshot.question_set; source_input = $snapshot.source_input
  accuracy_review = $accuracyReviewProvenance
  snapshot = [ordered]@{ path = Get-RelativePath $root $snapshotPath; sha256 = $snapshotSha }
  metrics = $metrics
}
Write-JsonAtomic $receiptPath $receipt
$receiptSha = Get-Sha256 $receiptPath

$monthly = if (Test-Path -LiteralPath $monthlyPath -PathType Leaf) { Read-Json $monthlyPath } else { [pscustomobject]@{ schema_version = 1; month = $monthKey; measurement_source = 'direct_ai_engine_observation'; gsc_inference_prohibited = $true; snapshots = @() } }
$prior = @($monthly.snapshots | Where-Object { [string]$_.snapshot_id -eq $snapshotId })
$monthlyEntry = [ordered]@{ snapshot_id = $snapshotId; observed_at = $snapshot.run.observed_at; engine = $snapshot.run.engine; model = $snapshot.run.model; snapshot_path = $receipt.snapshot.path; snapshot_sha256 = $snapshotSha; receipt_path = Get-RelativePath $root $receiptPath; receipt_sha256 = $receiptSha; accuracy_review = $accuracyReviewProvenance; metrics = $metrics }
$monthly.snapshots = @($monthly.snapshots | Where-Object { [string]$_.snapshot_id -ne $snapshotId }) + @($monthlyEntry)
$monthly | Add-Member -Force -NotePropertyName updated_at -NotePropertyValue ((Get-Date).ToUniversalTime().ToString('o'))
Write-JsonAtomic $monthlyPath $monthly
$monthlySha = Get-Sha256 $monthlyPath

$summary = [ordered]@{
  schema_version = 1; status = 'complete'; measurement_source = 'direct_ai_engine_observation'; gsc_inference_prohibited = $true; generated_at = (Get-Date).ToUniversalTime().ToString('o')
  latest_snapshot = [ordered]@{ id = $snapshotId; path = $receipt.snapshot.path; sha256 = $snapshotSha; observed_at = $snapshot.run.observed_at; engine = $snapshot.run.engine; model = $snapshot.run.model }
  accuracy_review = $accuracyReviewProvenance
  metrics = $metrics
  monthly_history = [ordered]@{ month = $monthKey; path = Get-RelativePath $root $monthlyPath; sha256 = $monthlySha; snapshot_count = @($monthly.snapshots).Count }
  receipt = [ordered]@{ path = Get-RelativePath $root $receiptPath; sha256 = $receiptSha }
}
Write-JsonAtomic $summaryPath $summary
Write-JsonAtomic $latestReceiptPath $receipt
[pscustomobject]@{
  status = 'complete'; idempotent = ($prior.Count -gt 0); snapshot_id = $snapshotId
  summary_path = (Get-RelativePath $root $summaryPath); summary_sha256 = (Get-Sha256 $summaryPath)
  mention_rate = $metrics.mention_rate; citation_rate = $metrics.citation_rate
  brand_mention_rate = $metrics.brand.mention_rate; brand_citation_rate = $metrics.brand.citation_rate
  non_brand_mention_rate = $metrics.non_brand.mention_rate; non_brand_citation_rate = $metrics.non_brand.citation_rate
  owned_citation_rate = $metrics.citations.owned.citation_rate; external_citation_rate = $metrics.citations.external.citation_rate
  accuracy_rate = $metrics.accuracy_rate; accuracy_partial_rate = $metrics.accuracy_partial_rate; accuracy_partial_count = $metrics.accuracy_partial_count; accuracy_unverified_count = $metrics.accuracy_unverified_count; monthly_snapshot_count = @($monthly.snapshots).Count
} | ConvertTo-Json -Compress
