#requires -Version 7.0
[CmdletBinding()]
param(
  [Parameter(Mandatory = $true)][string]$RuntimeRoot,
  [string]$InboxPath = '',
  [string]$QuestionSetPath = ''
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$root = (Resolve-Path -LiteralPath $RuntimeRoot).Path
$repoRoot = Split-Path -Parent $PSScriptRoot
$writer = Join-Path $PSScriptRoot 'write-ai-visibility-snapshot.ps1'
if (-not (Test-Path -LiteralPath $writer -PathType Leaf)) { throw "AI Visibility writer not found: $writer" }

if ([string]::IsNullOrWhiteSpace($InboxPath)) { $InboxPath = Join-Path $root 'inbox\ai-visibility' }
if ([string]::IsNullOrWhiteSpace($QuestionSetPath)) { $QuestionSetPath = Join-Path $root 'config\ai-visibility-question-set.json' }
if (-not (Test-Path -LiteralPath $QuestionSetPath -PathType Leaf)) { throw "AI Visibility question set not found: $QuestionSetPath" }

if (-not (Test-Path -LiteralPath $InboxPath -PathType Container)) {
  [void](New-Item -ItemType Directory -Path $InboxPath -Force)
  throw "AI Visibility inbox is empty. Put a complete observation JSON in: $InboxPath"
}

$candidates = @(Get-ChildItem -LiteralPath $InboxPath -File -Filter '*.json' |
  Sort-Object -Property @{ Expression = 'LastWriteTimeUtc'; Descending = $true }, @{ Expression = 'Name'; Descending = $true })
if ($candidates.Count -eq 0) { throw "AI Visibility inbox is empty. Put a complete observation JSON in: $InboxPath" }

$selected = $candidates[0]
Write-Host "AI Visibility auto-selected: $($selected.FullName)"
& $writer -RuntimeRoot $root -InputPath $selected.FullName -QuestionSetPath $QuestionSetPath
