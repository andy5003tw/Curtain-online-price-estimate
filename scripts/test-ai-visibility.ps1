[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$utf8NoBom = [System.Text.UTF8Encoding]::new($false)
$repoRoot = Split-Path -Parent $PSScriptRoot
$writer = Join-Path $PSScriptRoot 'write-ai-visibility-snapshot.ps1'
$autoImporter = Join-Path $PSScriptRoot 'import-latest-ai-visibility.ps1'
$testRoot = Join-Path ([IO.Path]::GetTempPath()) ('curtain-ai-visibility-' + [guid]::NewGuid().ToString('N'))
$runtimeRoot = Join-Path $testRoot 'runtime'

function Write-Json([string]$Path, [object]$Value) {
  $directory = Split-Path -Parent $Path
  if (-not (Test-Path -LiteralPath $directory -PathType Container)) { [void](New-Item -ItemType Directory -Path $directory -Force) }
  [IO.File]::WriteAllText($Path, (($Value | ConvertTo-Json -Depth 20) + [Environment]::NewLine), $utf8NoBom)
}
function Read-Json([string]$Path) { Get-Content -LiteralPath $Path -Raw -Encoding UTF8 | ConvertFrom-Json }
function Assert-True([bool]$Condition, [string]$Message) { if (-not $Condition) { throw $Message } }
function Invoke-Writer([string]$InputPath, [string]$QuestionSetPath, [string]$ReviewPath = '') {
  $output = if ([string]::IsNullOrWhiteSpace($ReviewPath)) {
    @(& pwsh -NoLogo -NoProfile -File $writer -RuntimeRoot $runtimeRoot -InputPath $InputPath -QuestionSetPath $QuestionSetPath 2>&1)
  } else {
    @(& pwsh -NoLogo -NoProfile -File $writer -RuntimeRoot $runtimeRoot -InputPath $InputPath -QuestionSetPath $QuestionSetPath -ReviewPath $ReviewPath 2>&1)
  }
  return [pscustomobject]@{ ExitCode = [int]$LASTEXITCODE; Output = @($output | ForEach-Object { [string]$_ }) }
}

try {
  [void](New-Item -ItemType Directory -Path $runtimeRoot -Force)
  $questionSetPath = Join-Path $runtimeRoot 'config\question-set.json'
  $questionSet = [ordered]@{
    schema_version = 1; question_set_id = 'fixture-zh-tw-v1'; locale = 'zh-TW'
    questions = @(
      [ordered]@{ question_id = 'brand_desktop'; question = '宏森窗簾怎麼線上估價？'; region = 'Taipei, Taiwan'; device = 'desktop'; brand_context = 'brand' }
      [ordered]@{ question_id = 'brand_mobile'; question = '宏森窗簾蛇形窗簾適合客廳嗎？'; region = 'Taipei, Taiwan'; device = 'mobile'; brand_context = 'brand' }
      [ordered]@{ question_id = 'nonbrand_desktop'; question = '台北窗簾估價要準備什麼？'; region = 'Taipei, Taiwan'; device = 'desktop'; brand_context = 'non_brand' }
      [ordered]@{ question_id = 'nonbrand_mobile'; question = '蛇形窗簾和布簾差在哪裡？'; region = 'Taipei, Taiwan'; device = 'mobile'; brand_context = 'non_brand' }
    )
  }
  Write-Json $questionSetPath $questionSet
  $input1Path = Join-Path $runtimeRoot 'input-1.json'
  $input1 = [ordered]@{
    run_id = 'fixture-run-1'; engine = 'fixture-engine'; model = 'fixture-model-v1'; observed_at = '2026-08-13T10:00:00Z'; measurement_source = 'direct_ai_engine_observation'
    observations = @(
      [ordered]@{ question_id = 'brand_desktop'; region = 'Taipei, Taiwan'; device = 'desktop'; brand_context = 'brand'; answer = '宏森窗簾提供線上估價。'; brand_mentioned = $true; citation_urls = @('https://online.hong-sen.com/calculator/'); accuracy = 'correct'; accuracy_note = 'fixture review' }
      [ordered]@{ question_id = 'brand_mobile'; region = 'Taipei, Taiwan'; device = 'mobile'; brand_context = 'brand'; answer = '可依空間需求評估。'; brand_mentioned = $true; citation_urls = @('https://online.hong-sen.com/products/s-fold-curtains/'); accuracy = 'correct'; accuracy_note = 'fixture review' }
      [ordered]@{ question_id = 'nonbrand_desktop'; region = 'Taipei, Taiwan'; device = 'desktop'; brand_context = 'non_brand'; answer = '需準備尺寸。'; brand_mentioned = $true; citation_urls = @(); accuracy = 'incorrect'; accuracy_note = 'fixture review' }
      [ordered]@{ question_id = 'nonbrand_mobile'; region = 'Taipei, Taiwan'; device = 'mobile'; brand_context = 'non_brand'; answer = '依布料及軌道比較。'; brand_mentioned = $false; citation_urls = @(); accuracy = 'unverified'; accuracy_note = 'needs human review' }
    )
  }
  Write-Json $input1Path $input1
  $first = Invoke-Writer $input1Path $questionSetPath
  Assert-True ($first.ExitCode -eq 0) ('AI visibility writer rejected valid direct observations: ' + ($first.Output -join ' '))
  $summaryPath = Join-Path $runtimeRoot 'latest\ai-visibility-summary.json'
  $receiptPath = Join-Path $runtimeRoot 'latest\ai-visibility-receipt.json'
  $summary = Read-Json $summaryPath
  $receipt = Read-Json $receiptPath
  Assert-True ($summary.measurement_source -eq 'direct_ai_engine_observation' -and [bool]$summary.gsc_inference_prohibited) 'AI visibility summary does not prohibit GSC inference.'
  Assert-True ($summary.metrics.sample_size -eq 4 -and $summary.metrics.mention_rate -eq 75 -and $summary.metrics.citation_rate -eq 50 -and $summary.metrics.accuracy_rate -eq 66.67) 'AI visibility rates were not calculated from direct observations.'
  Assert-True ($summary.metrics.metrics_schema_version -eq 3 -and $summary.metrics.brand.mention_rate -eq 100 -and $summary.metrics.non_brand.mention_rate -eq 50) 'AI visibility does not split brand and non-brand mention rates.'
  Assert-True ($summary.metrics.citations.owned.citation_rate -eq 50 -and $summary.metrics.citations.external.citation_rate -eq 0 -and $summary.metrics.citations.by_owned_domain.'online.hong-sen.com'.cited_question_rate -eq 50 -and $summary.metrics.citations.by_owned_domain.'www.hong-sen.com'.cited_question_rate -eq 0) 'AI visibility does not classify owned and external citation rates by domain.'
  Assert-True ($summary.metrics.accuracy_evaluated_count -eq 3 -and $summary.metrics.accuracy_unverified_count -eq 1) 'Accuracy denominator did not exclude unverified answers.'
  Assert-True ($receipt.question_set.sha256 -and $receipt.source_input.sha256 -and $receipt.snapshot.sha256) 'AI visibility receipt lacks question-set/input/snapshot SHA provenance.'
  $snapshot = Read-Json (Join-Path $runtimeRoot ([string]$summary.latest_snapshot.path -replace '/', '\\'))
  Assert-True (@($snapshot.observations | Where-Object { $_.PSObject.Properties.Name -contains 'engine' -or $_.PSObject.Properties.Name -contains 'model' }).Count -eq 0) 'Snapshot must retain engine/model at run level, not fabricate per-answer metadata.'
  Assert-True (@($snapshot.observations | Where-Object { [string]::IsNullOrWhiteSpace([string]$_.answer) -or $null -eq $_.brand_mentioned }).Count -eq 0) 'Snapshot did not retain answer/mention evidence for every fixed question.'

  $repeat = Invoke-Writer $input1Path $questionSetPath
  Assert-True ($repeat.ExitCode -eq 0 -and (($repeat.Output -join "`n") -match '"idempotent":true')) 'Repeated identical AI observation did not return idempotent success.'
  $monthPath = Join-Path $runtimeRoot 'history\curtain-online\ai-visibility\monthly\2026-08.json'
  Assert-True (@((Read-Json $monthPath).snapshots).Count -eq 1) 'Idempotent observation duplicated monthly history.'

  $input2Path = Join-Path $runtimeRoot 'input-2.json'
  $input2 = $input1.PSObject.Copy(); $input2.run_id = 'fixture-run-2'; $input2.observed_at = '2026-08-20T10:00:00Z'; $input2.observations[3].brand_mentioned = $true; $input2.observations[3].citation_urls = @('https://online.hong-sen.com/products/s-fold-curtains/')
  Write-Json $input2Path $input2
  $second = Invoke-Writer $input2Path $questionSetPath
  Assert-True ($second.ExitCode -eq 0) 'Second direct AI observation was rejected.'
  Assert-True (@((Read-Json $monthPath).snapshots).Count -eq 2) 'Monthly history did not accumulate a distinct dated snapshot.'

  $invalidPath = Join-Path $runtimeRoot 'invalid.json'
  $invalid = $input1.PSObject.Copy(); $invalid.measurement_source = 'gsc_inferred'; Write-Json $invalidPath $invalid
  $summaryHash = (Get-FileHash -LiteralPath $summaryPath -Algorithm SHA256).Hash
  $invalidResult = Invoke-Writer $invalidPath $questionSetPath
  Assert-True ($invalidResult.ExitCode -ne 0) 'Writer accepted GSC-inferred AI metrics.'
  Assert-True ((Get-FileHash -LiteralPath $summaryPath -Algorithm SHA256).Hash -eq $summaryHash) 'Rejected inferred metrics changed the latest summary.'

  $inboxPath = Join-Path $runtimeRoot 'inbox\ai-visibility'
  [void](New-Item -ItemType Directory -Path $inboxPath -Force)
  $autoInputPath = Join-Path $inboxPath 'latest-observation.json'
  Copy-Item -LiteralPath $input2Path -Destination $autoInputPath
  $autoOutput = @(& pwsh -NoLogo -NoProfile -File $autoImporter -RuntimeRoot $runtimeRoot -InboxPath $inboxPath -QuestionSetPath $questionSetPath 2>&1)
  Assert-True ($LASTEXITCODE -eq 0) ('AI Visibility one-click importer rejected the latest inbox observation: ' + ($autoOutput -join ' '))
  Assert-True (($autoOutput -join "`n") -match 'AI Visibility auto-selected:' -and ($autoOutput -join "`n") -match '"status":"complete"') 'AI Visibility one-click importer did not report the selected file and completed snapshot.'

  $reviewPath = Join-Path $runtimeRoot 'reviews\fixture-review.json'
  $review = [ordered]@{
    schema_version = 1; review_type = 'ai_visibility_human_accuracy_review'; reviewed_at = '2026-08-21T10:00:00Z'; reviewer = 'fixture reviewer'
    source_observation = [ordered]@{ sha256 = (Get-FileHash -LiteralPath $input2Path -Algorithm SHA256).Hash.ToLowerInvariant() }
    reviews = @(
      [ordered]@{ question_id = 'brand_desktop'; accuracy = 'correct'; accuracy_note = 'fully verified' }
      [ordered]@{ question_id = 'brand_mobile'; accuracy = 'partial'; accuracy_note = 'needs a condition' }
      [ordered]@{ question_id = 'nonbrand_desktop'; accuracy = 'partial'; accuracy_note = 'not fully evidenced' }
      [ordered]@{ question_id = 'nonbrand_mobile'; accuracy = 'incorrect'; accuracy_note = 'fixture error' }
    )
  }
  Write-Json $reviewPath $review
  $reviewed = Invoke-Writer $input2Path $questionSetPath $reviewPath
  Assert-True ($reviewed.ExitCode -eq 0) ('AI visibility writer rejected a valid reviewed observation: ' + ($reviewed.Output -join ' '))
  $reviewedSummary = Read-Json $summaryPath
  Assert-True ($reviewedSummary.metrics.accuracy_evaluated_count -eq 4 -and $reviewedSummary.metrics.accuracy_correct_count -eq 1 -and $reviewedSummary.metrics.accuracy_partial_count -eq 2 -and $reviewedSummary.metrics.accuracy_incorrect_count -eq 1 -and $reviewedSummary.metrics.accuracy_rate -eq 25 -and $reviewedSummary.metrics.accuracy_unverified_count -eq 0) 'AI visibility review did not produce the expected accuracy distribution.'
  Assert-True ($reviewedSummary.accuracy_review.sha256 -eq (Get-FileHash -LiteralPath $reviewPath -Algorithm SHA256).Hash.ToLowerInvariant()) 'AI visibility review provenance is missing or incorrect.'
  Write-Host 'AI Visibility tests passed.'
} finally {
  if (Test-Path -LiteralPath $testRoot) { Remove-Item -LiteralPath $testRoot -Recurse -Force -ErrorAction SilentlyContinue }
}
