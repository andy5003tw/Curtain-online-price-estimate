[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$utf8NoBom = [Text.UTF8Encoding]::new($false)
$runner = Join-Path $PSScriptRoot 'run-ai-visibility-observation.ps1'
$repoRoot = Split-Path -Parent $PSScriptRoot
$questionSetPath = Join-Path $repoRoot 'Weekly SOP\config\ai-visibility-question-set.json'
$testRoot = Join-Path ([IO.Path]::GetTempPath()) ('curtain-ai-visibility-auto-' + [guid]::NewGuid().ToString('N'))

function Write-Json([string]$Path, [object]$Value) {
  $directory = Split-Path -Parent $Path
  if (-not (Test-Path -LiteralPath $directory)) { [void](New-Item -ItemType Directory -Path $directory -Force) }
  [IO.File]::WriteAllText($Path, (($Value | ConvertTo-Json -Depth 30) + [Environment]::NewLine), $utf8NoBom)
}
function Assert-True([bool]$Condition, [string]$Message) { if (-not $Condition) { throw $Message } }

try {
  $runtimeRoot = Join-Path $testRoot 'Weekly SOP'
  $inboxPath = Join-Path $runtimeRoot 'inbox\ai-visibility'
  [void](New-Item -ItemType Directory -Path $runtimeRoot -Force)
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
  $output = @(& pwsh -NoLogo -NoProfile -File $runner -RuntimeRoot $runtimeRoot -QuestionSetPath $questionSetPath -InboxPath $inboxPath -Model 'fixture-model' -ResponseFixturePath $fixturePath -ImportAfterRun 2>&1)
  Assert-True ($LASTEXITCODE -eq 0) ('AI Visibility automation fixture failed: ' + ($output -join ' '))
  Assert-True (@(Get-ChildItem -LiteralPath $inboxPath -Filter '*.json' -File).Count -eq 1) 'Automation did not write exactly one inbox observation.'
  $summaryPath = Join-Path $runtimeRoot 'latest\ai-visibility-summary.json'
  Assert-True (Test-Path -LiteralPath $summaryPath -PathType Leaf) 'Automation did not import the observation into latest summary.'
  $summary = Get-Content -LiteralPath $summaryPath -Raw -Encoding UTF8 | ConvertFrom-Json
  Assert-True ([int]$summary.metrics.sample_size -eq 6 -and [decimal]$summary.metrics.mention_rate -eq 33.33 -and [decimal]$summary.metrics.citation_rate -eq 33.33) 'Automation summary metrics are incorrect.'
  Assert-True ([decimal]$summary.metrics.brand.mention_rate -eq 100 -and [decimal]$summary.metrics.brand.citation_rate -eq 100 -and [decimal]$summary.metrics.non_brand.mention_rate -eq 0 -and [decimal]$summary.metrics.non_brand.citation_rate -eq 0) 'Automation summary does not split fixed brand and non-brand questions.'
  Assert-True ([decimal]$summary.metrics.citations.owned.citation_rate -eq 33.33 -and [decimal]$summary.metrics.citations.external.citation_rate -eq 0) 'Automation summary does not classify owned and external citations.'
  Assert-True ($null -eq $summary.metrics.accuracy_rate -and [int]$summary.metrics.accuracy_unverified_count -eq 6) 'Automated answers must remain unverified until human accuracy review.'
  Write-Host 'AI Visibility automation tests passed.'
} finally {
  if (Test-Path -LiteralPath $testRoot) { Remove-Item -LiteralPath $testRoot -Recurse -Force -ErrorAction SilentlyContinue }
}
