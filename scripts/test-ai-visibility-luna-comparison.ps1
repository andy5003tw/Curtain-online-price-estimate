#requires -Version 7.0
[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$utf8NoBom = [Text.UTF8Encoding]::new($false)
$comparisonRunner = Join-Path $PSScriptRoot 'run-ai-visibility-luna-comparison.ps1'
$observationRunner = Join-Path $PSScriptRoot 'run-ai-visibility-observation.ps1'
$repoRoot = Split-Path -Parent $PSScriptRoot
$sourceQuestionSet = Join-Path $repoRoot 'Weekly SOP\config\ai-visibility-question-set.json'
$testRoot = Join-Path ([IO.Path]::GetTempPath()) ('curtain-ai-visibility-luna-' + [guid]::NewGuid().ToString('N'))

function Write-Json([string]$Path, [object]$Value) {
  $directory = Split-Path -Parent $Path
  if (-not (Test-Path -LiteralPath $directory)) { [void](New-Item -ItemType Directory -Path $directory -Force) }
  [IO.File]::WriteAllText($Path, (($Value | ConvertTo-Json -Depth 30) + [Environment]::NewLine), $utf8NoBom)
}
function Assert-True([bool]$Condition, [string]$Message) { if (-not $Condition) { throw $Message } }
function Get-RunnerResult([object[]]$Output) {
  $line = @($Output | ForEach-Object { [string]$_ } | Where-Object { $_.Trim().StartsWith('{') -and $_.Trim().EndsWith('}') } | Select-Object -Last 1)
  if ($line.Count -ne 1) { throw ('Runner did not return JSON: ' + ($Output -join ' ')) }
  return $line[0] | ConvertFrom-Json
}

try {
  $runtimeRoot = Join-Path $testRoot 'Weekly SOP'
  $inboxPath = Join-Path $runtimeRoot 'inbox\ai-visibility'
  $questionSetPath = Join-Path $runtimeRoot 'config\ai-visibility-question-set.json'
  [void](New-Item -ItemType Directory -Path (Split-Path -Parent $questionSetPath) -Force)
  Copy-Item -LiteralPath $sourceQuestionSet -Destination $questionSetPath
  $questionSet = Get-Content -LiteralPath $questionSetPath -Raw -Encoding UTF8 | ConvertFrom-Json
  $responses = @()
  for ($index = 0; $index -lt @($questionSet.questions).Count; $index++) {
    $question = @($questionSet.questions)[$index]
    $answer = if ([string]$question.brand_context -eq 'brand') { '宏森提供相關窗簾資訊。' } else { '可先確認尺寸、採光、材質與安裝條件。' }
    $annotations = if ($index -lt 2) { @([ordered]@{ type = 'url_citation'; url = 'https://online.hong-sen.com/'; title = '宏森窗簾' }) } else { @() }
    $responses += [ordered]@{
      id = "fixture-response-$index"; model = 'fixture-model'; status = 'completed'
      output = @([ordered]@{ type = 'message'; content = @([ordered]@{ type = 'output_text'; text = $answer; annotations = $annotations }) })
    }
  }
  $fixturePath = Join-Path $testRoot 'responses.json'
  Write-Json $fixturePath $responses
  $summaryPath = Join-Path $runtimeRoot 'latest\ai-visibility-summary.json'
  Write-Json $summaryPath ([ordered]@{ status = 'complete'; sentinel = 'saved-mini-summary-must-not-change' })
  $summaryShaBefore = (Get-FileHash -LiteralPath $summaryPath -Algorithm SHA256).Hash

  $baselineOutput = @(& pwsh -NoLogo -NoProfile -File $observationRunner -RuntimeRoot $runtimeRoot -QuestionSetPath $questionSetPath -InboxPath $inboxPath -Model 'gpt-5.4-mini' -ResponseFixturePath $fixturePath 2>&1)
  Assert-True ($LASTEXITCODE -eq 0) ('Baseline fixture failed: ' + ($baselineOutput -join ' '))
  $baseline = Get-RunnerResult $baselineOutput
  $comparisonOutput = @(& pwsh -NoLogo -NoProfile -File $comparisonRunner -RuntimeRoot $runtimeRoot -BaselineObservationPath $baseline.observation_path -QuestionSetPath $questionSetPath -InboxPath $inboxPath -ResponseFixturePath $fixturePath 2>&1)
  Assert-True ($LASTEXITCODE -eq 0) ('Luna comparison fixture failed: ' + ($comparisonOutput -join ' '))
  $result = Get-RunnerResult $comparisonOutput
  Assert-True ($result.status -eq 'complete' -and $result.luna_model -eq 'gpt-5.6-luna') 'Comparison did not identify the Luna candidate.'
  Assert-True ($result.latest_summary_unchanged -eq $true -and $result.luna_imported_into_latest_summary -eq $false) 'Comparison safety properties are incorrect.'
  Assert-True (@(Get-ChildItem -LiteralPath $inboxPath -Filter '*.json' -File).Count -eq 2) 'Comparison must preserve the baseline and write a separate candidate observation.'
  Assert-True ((Get-FileHash -LiteralPath $summaryPath -Algorithm SHA256).Hash -eq $summaryShaBefore) 'Comparison changed the saved latest summary.'
  $comparison = Get-Content -LiteralPath $result.comparison_path -Raw -Encoding UTF8 | ConvertFrom-Json
  Assert-True ($comparison.status -eq 'complete' -and $comparison.baseline.model -eq 'gpt-5.4-mini' -and $comparison.luna.model -eq 'gpt-5.6-luna') 'Comparison report model metadata is incorrect.'
  Assert-True ($comparison.safety.source_observations_are_distinct -eq $true -and $comparison.safety.latest_summary_unchanged -eq $true -and $comparison.safety.luna_imported_into_latest_summary -eq $false) 'Comparison report safety metadata is incorrect.'
  Assert-True (@($comparison.question_deltas).Count -eq 6) 'Comparison report must include all fixed questions.'
  Write-Host 'AI Visibility Luna comparison tests passed.'
} finally {
  if (Test-Path -LiteralPath $testRoot) { Remove-Item -LiteralPath $testRoot -Recurse -Force -ErrorAction SilentlyContinue }
}
