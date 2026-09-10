#requires -Version 7.0
[CmdletBinding()]
param(
  [Parameter(Mandatory = $true)][string]$RuntimeRoot,
  [string]$QuestionSetPath = '',
  [string]$InboxPath = '',
  [string]$Model = '',
  [switch]$ImportAfterRun,
  [string]$ResponseFixturePath = '',
  [int]$TimeoutSec = 120,
  [int]$Retries = 2
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
    $json = $Value | ConvertTo-Json -Depth 50
    $null = $json | ConvertFrom-Json
    [IO.File]::WriteAllText($temp, $json + [Environment]::NewLine, $utf8NoBom)
    [IO.File]::Move($temp, $Path, $true)
  } finally {
    if (Test-Path -LiteralPath $temp) { Remove-Item -LiteralPath $temp -Force -ErrorAction SilentlyContinue }
  }
}
function Get-ResponseAnswer([object]$Response) {
  $parts = @()
  foreach ($output in @($Response.output)) {
    if ($null -eq $output -or $output.PSObject.Properties.Name -notcontains 'type' -or [string]$output.type -ne 'message' -or $output.PSObject.Properties.Name -notcontains 'content') { continue }
    foreach ($content in @($output.content)) {
      if ($null -ne $content -and $content.PSObject.Properties.Name -contains 'type' -and [string]$content.type -eq 'output_text' -and $content.PSObject.Properties.Name -contains 'text' -and -not [string]::IsNullOrWhiteSpace([string]$content.text)) { $parts += [string]$content.text }
    }
  }
  return ($parts -join "`n`n").Trim()
}
function Get-ResponseCitations([object]$Response) {
  $urls = @()
  foreach ($output in @($Response.output)) {
    if ($null -eq $output -or $output.PSObject.Properties.Name -notcontains 'type' -or [string]$output.type -ne 'message' -or $output.PSObject.Properties.Name -notcontains 'content') { continue }
    foreach ($content in @($output.content)) {
      if ($null -eq $content -or $content.PSObject.Properties.Name -notcontains 'annotations') { continue }
      foreach ($annotation in @($content.annotations)) {
        if ($null -ne $annotation -and $annotation.PSObject.Properties.Name -contains 'type' -and [string]$annotation.type -eq 'url_citation' -and $annotation.PSObject.Properties.Name -contains 'url' -and -not [string]::IsNullOrWhiteSpace([string]$annotation.url)) { $urls += [string]$annotation.url }
      }
    }
  }
  return @($urls | Sort-Object -Unique)
}
function Invoke-OpenAiResponse([object]$Question, [int]$Index) {
  if ($fixtureResponses.Count -gt 0) { return $fixtureResponses[$Index] }

  $body = [ordered]@{
    model = $Model
    store = $false
    instructions = '你是面向台灣使用者的一般資訊助理。請以繁體中文直接、自然地回答目前這一題，不要詢問評測目的。需要最新資訊或特定業者資料時使用網路搜尋，並在回答中保留來源引用。'
    input = [string]$Question.question
    tools = @([ordered]@{
      type = 'web_search'
      search_context_size = 'medium'
      user_location = [ordered]@{ type = 'approximate'; country = 'TW'; city = 'Taipei'; region = 'Taipei' }
    })
    tool_choice = 'auto'
  }
  $jsonBody = $body | ConvertTo-Json -Depth 15 -Compress
  $headers = @{ Authorization = "Bearer $apiKey"; 'Content-Type' = 'application/json' }
  $attempt = 0
  while ($true) {
    try {
      return Invoke-RestMethod -Method Post -Uri 'https://api.openai.com/v1/responses' -Headers $headers -Body $jsonBody -TimeoutSec $TimeoutSec
    } catch {
      $attempt += 1
      if ($attempt -gt $Retries) { throw "OpenAI Responses API failed for question_id=$($Question.question_id): $($_.Exception.Message)" }
      Start-Sleep -Seconds ([Math]::Min(8, 2 * $attempt))
    }
  }
}

$root = (Resolve-Path -LiteralPath $RuntimeRoot).Path
$repoRoot = Split-Path -Parent $PSScriptRoot
if ([string]::IsNullOrWhiteSpace($QuestionSetPath)) { $QuestionSetPath = Join-Path $root 'config\ai-visibility-question-set.json' }
if ([string]::IsNullOrWhiteSpace($InboxPath)) { $InboxPath = Join-Path $root 'inbox\ai-visibility' }
if ([string]::IsNullOrWhiteSpace($Model)) { $Model = if ($env:OPENAI_AI_VISIBILITY_MODEL) { $env:OPENAI_AI_VISIBILITY_MODEL } else { 'gpt-5.4-mini' } }

$questionSet = Read-Json $QuestionSetPath
$questions = @($questionSet.questions)
if ([int]$questionSet.schema_version -ne 1 -or $questions.Count -eq 0) { throw 'AI Visibility question set must be schema_version=1 and contain questions.' }

$fixtureResponses = @()
if (-not [string]::IsNullOrWhiteSpace($ResponseFixturePath)) {
  $fixtureResponses = @(Read-Json $ResponseFixturePath)
  if ($fixtureResponses.Count -ne $questions.Count) { throw 'Response fixture count must match the AI Visibility question count.' }
  $apiKey = 'fixture-only'
} else {
  $apiKey = [string]$env:OPENAI_API_KEY
  if ([string]::IsNullOrWhiteSpace($apiKey)) { throw 'OPENAI_API_KEY is not set. Configure it, reopen the launcher, and retry AI Visibility automation.' }
}

$observedAt = [datetimeoffset]::UtcNow
$runId = 'ai-visibility-openai-{0}-{1}' -f $observedAt.ToString('yyyyMMddTHHmmssZ'), ([guid]::NewGuid().ToString('N').Substring(0, 8))
$observations = @()
for ($index = 0; $index -lt $questions.Count; $index++) {
  $question = $questions[$index]
  Write-Host ("AI Visibility question {0}/{1}: {2}" -f ($index + 1), $questions.Count, $question.question_id)
  $response = Invoke-OpenAiResponse -Question $question -Index $index
  if ([string]$response.status -and [string]$response.status -ne 'completed') { throw "OpenAI response was not completed for question_id=$($question.question_id)." }
  $answer = Get-ResponseAnswer $response
  if ([string]::IsNullOrWhiteSpace($answer)) { throw "OpenAI response contained no answer for question_id=$($question.question_id)." }
  $observations += [ordered]@{
    question_id = [string]$question.question_id
    region = [string]$question.region
    device = [string]$question.device
    brand_context = [string]$question.brand_context
    answer = $answer
    brand_mentioned = [bool]($answer -match '(?i)宏森|Hong[\s-]*Sen')
    citation_urls = @(Get-ResponseCitations $response)
    accuracy = 'unverified'
    accuracy_note = 'Automated direct API observation; factual accuracy awaits human review.'
    response_id = [string]$response.id
    response_model = [string]$response.model
  }
}

$observation = [ordered]@{
  schema_version = 1
  run_id = $runId
  engine = if ($fixtureResponses.Count -gt 0) { 'OpenAI Responses API fixture' } else { 'OpenAI Responses API' }
  model = $Model
  observed_at = $observedAt.ToString('o')
  measurement_source = 'direct_ai_engine_observation'
  observations = $observations
}
$safeModel = ($Model -replace '[^A-Za-z0-9._-]+', '-')
$outputPath = Join-Path $InboxPath ("{0}-{1}.json" -f $observedAt.ToString('yyyyMMddTHHmmssZ'), $safeModel)
Write-JsonAtomic -Path $outputPath -Value $observation
Write-Host "AI Visibility observation written: $outputPath"

if ($ImportAfterRun) {
  $writer = Join-Path $PSScriptRoot 'write-ai-visibility-snapshot.ps1'
  & $writer -RuntimeRoot $root -InputPath $outputPath -QuestionSetPath $QuestionSetPath
}

[pscustomobject]@{
  status = 'complete'
  engine = $observation.engine
  model = $Model
  questions = $questions.Count
  observation_path = $outputPath
  imported = [bool]$ImportAfterRun
} | ConvertTo-Json -Compress
