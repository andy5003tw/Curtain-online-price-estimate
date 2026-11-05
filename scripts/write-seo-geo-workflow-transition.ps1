[CmdletBinding()]
param(
  [Parameter(Mandatory = $true)][string]$RuntimeRoot,
  [Parameter(Mandatory = $true)][ValidateSet('data_validated', 'strategy_approved', 'round_validated', 'implemented', 'local_validated', 'deployed', 'live_verified', 'observing_7d', 'reviewed_28d', 'completed')][string]$Transition,
  [string]$EvidenceJson,
  [string]$EvidencePath,
  [string[]]$Page,
  [string]$ApprovedBy,
  [string]$Reason,
  [string]$RepoRoot,
  [string]$OperationId,
  [switch]$Recover,
  [switch]$TestFailAfterExecutor
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Read-Json([string]$Path) {
  if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { return $null }
  return Get-Content -LiteralPath $Path -Raw -Encoding UTF8 | ConvertFrom-Json
}

function Write-JsonAtomic([string]$Path, [object]$Value) {
  $text = $Value | ConvertTo-Json -Depth 40
  $null = $text | ConvertFrom-Json
  $temp = "$Path.tmp.$([guid]::NewGuid().ToString('N'))"
  try {
    [System.IO.File]::WriteAllText($temp, $text + [Environment]::NewLine, [System.Text.UTF8Encoding]::new($false))
    [System.IO.File]::Move($temp, $Path, $true)
  } finally {
    if (Test-Path -LiteralPath $temp) { Remove-Item -LiteralPath $temp -Force -ErrorAction SilentlyContinue }
  }
}

function Get-Sha256Text([string]$Value) {
  $bytes = [System.Text.Encoding]::UTF8.GetBytes($Value)
  return ([System.Security.Cryptography.SHA256]::Create().ComputeHash($bytes) | ForEach-Object { $_.ToString('x2') }) -join ''
}

function Get-WorkflowPaths {
  param([string]$TransitionName)
  $paths = @($statePath)
  switch ($TransitionName) {
    'strategy_approved' { $paths += @($queuePath, $approvalPath, $roundPromptPath, $slimPromptPath, $aiPromptPath) }
    'round_validated' { $paths += @($queuePath, $registryPath, $historyPath) }
    { $_ -in @('implemented','local_validated','deployed','live_verified','observing_7d','reviewed_28d','completed') } { $paths += $lifecyclePath }
  }
  return @($paths | Select-Object -Unique)
}

function Restore-WorkflowJournal {
  param([object]$Journal)
  if ($null -eq $Journal -or @($Journal.targets).Count -eq 0) { return $false }
  foreach ($target in @($Journal.targets)) {
    $path = [string]$target.path
    if ([bool]$target.existed) {
      if (-not (Test-Path -LiteralPath ([string]$target.backup) -PathType Leaf)) { throw "Workflow recovery backup is missing: $($target.backup)" }
      [System.IO.File]::Copy([string]$target.backup, $path, $true)
    } elseif (Test-Path -LiteralPath $path) {
      Remove-Item -LiteralPath $path -Force
    }
  }
  $Journal.status = 'recovered'
  $Journal.recovered_at = (Get-Date).ToUniversalTime().ToString('o')
  Write-JsonAtomic -Path $journalPath -Value $Journal
  return $true
}

function New-WorkflowJournal {
  param([string[]]$Paths, [string]$Id, [string]$Fingerprint)
  $transactionId = [guid]::NewGuid().ToString('N')
  $backupRoot = Join-Path $latestRoot ('.seo-geo-workflow-backups\' + $transactionId)
  New-Item -ItemType Directory -Path $backupRoot -Force | Out-Null
  $targets = @()
  for ($i = 0; $i -lt $Paths.Count; $i++) {
    $path = $Paths[$i]
    $exists = Test-Path -LiteralPath $path -PathType Leaf
    $backup = Join-Path $backupRoot ("target-$i.bak")
    if ($exists) { [System.IO.File]::Copy($path, $backup, $true) }
    $targets += [ordered]@{ path = $path; existed = $exists; backup = $backup }
  }
  $journal = [ordered]@{
    schema_version = 1
    transaction_id = $transactionId
    operation_id = $Id
    operation_fingerprint = $Fingerprint
    transition = $Transition
    queue_id = [string]$state.queue_id
    cycle_key = [string]$state.cycle_key
    status = 'prepared'
    prepared_at = (Get-Date).ToUniversalTime().ToString('o')
    targets = $targets
  }
  Write-JsonAtomic -Path $journalPath -Value $journal
  return $journal
}

function Test-PreconditionGates {
  param([object]$CurrentState, [object]$CurrentQueue)
  $gates = if ($CurrentState.PSObject.Properties.Name -contains 'precondition_gates') { $CurrentState.precondition_gates } else { $null }
  $dataStatus = if ($gates -and $gates.PSObject.Properties.Name -contains 'data_validated') { [string]$gates.data_validated.status } else { '' }
  $strategyStatus = if ($gates -and $gates.PSObject.Properties.Name -contains 'strategy_approved') { [string]$gates.strategy_approved.status } else { '' }
  $dataFallback = $CurrentState.snapshot -and [bool]$CurrentState.snapshot.'7d'.decision_ready -and [bool]$CurrentState.snapshot.'28d'.decision_ready
  $approval = Read-Json -Path $approvalPath
  $strategyFallback = ([string]$CurrentQueue.status -eq 'active' -and @($CurrentQueue.rounds).Count -gt 0 -and (
    ([string]$approval.status -eq 'approved' -and [string]$approval.queue_id -eq [string]$CurrentQueue.queue_id) -or
    ([string]$CurrentQueue.mode -in @('actionable','performance_actionable'))
  ))
  if ($dataStatus -notin @('passed','validated') -and -not $dataFallback) { throw 'Precondition gate data_validated is not satisfied.' }
  if ($strategyStatus -notin @('passed','approved') -and -not $strategyFallback) { throw 'Precondition gate strategy_approved is not satisfied.' }
}

function Set-DataValidatedGate {
  if (-not $state.snapshot -or -not [bool]$state.snapshot.'7d'.decision_ready -or -not [bool]$state.snapshot.'28d'.decision_ready) {
    throw 'data_validated requires decision-ready 7d and 28d snapshot bindings.'
  }
  if (-not ($state.PSObject.Properties.Name -contains 'precondition_gates')) {
    $state | Add-Member -NotePropertyName precondition_gates -NotePropertyValue ([pscustomobject]@{})
  }
  $state.precondition_gates | Add-Member -Force -NotePropertyName data_validated -NotePropertyValue ([ordered]@{
    status = 'passed'; assessed_at = (Get-Date).ToUniversalTime().ToString('o'); source = 'workflow_writer'; snapshot = $state.snapshot
  })
  Write-JsonAtomic -Path $statePath -Value $state
}

function Set-StrategyApprovedGate {
  $updated = Read-Json -Path $statePath
  if (-not ($updated.PSObject.Properties.Name -contains 'precondition_gates')) {
    $updated | Add-Member -NotePropertyName precondition_gates -NotePropertyValue ([pscustomobject]@{})
  }
  $updated.precondition_gates | Add-Member -Force -NotePropertyName strategy_approved -NotePropertyValue ([ordered]@{
    status = 'passed'; approved_at = (Get-Date).ToUniversalTime().ToString('o'); source = 'user_single_page_approval'; receipt_path = 'latest/seo-geo-single-page-approval.json'
  })
  Write-JsonAtomic -Path $statePath -Value $updated
}

$root = (Resolve-Path -LiteralPath $RuntimeRoot).Path
$weeklyRoot = if (Test-Path -LiteralPath (Join-Path $root 'latest\seo-geo-action-queue-state.json')) { $root } elseif (Test-Path -LiteralPath (Join-Path $root 'Weekly SOP\latest\seo-geo-action-queue-state.json')) { Join-Path $root 'Weekly SOP' } else { throw "Queue state not found under RuntimeRoot: $root" }
$latestRoot = Join-Path $weeklyRoot 'latest'
$statePath = Join-Path $latestRoot 'seo-geo-action-queue-state.json'
$queuePath = Join-Path $latestRoot 'seo-geo-action-queue.json'
$approvalPath = Join-Path $latestRoot 'seo-geo-single-page-approval.json'
$lifecyclePath = Join-Path $latestRoot 'seo-geo-lifecycle-receipt.json'
$registryPath = Join-Path $weeklyRoot 'config\target-registry.json'
$historyPath = Join-Path $weeklyRoot 'history\curtain-online\seo-geo-action-history.json'
$roundPromptPath = Join-Path $latestRoot 'seo-geo-action-plan.round-1.slim.ai.md'
$slimPromptPath = Join-Path $latestRoot 'seo-geo-action-plan.slim.ai.md'
$aiPromptPath = Join-Path $latestRoot 'seo-geo-action-plan.ai.md'
$journalPath = Join-Path $latestRoot 'seo-geo-workflow-recovery-journal.json'
$operationIndexPath = Join-Path $weeklyRoot 'history\curtain-online\seo-geo-workflow-operation-index.json'
$lockPath = Join-Path $latestRoot 'seo-geo-workflow.lock'
$lockStream = $null

try {
  try { $lockStream = [System.IO.File]::Open($lockPath, [System.IO.FileMode]::CreateNew, [System.IO.FileAccess]::ReadWrite, [System.IO.FileShare]::None) }
  catch { throw "Workflow writer lock is held: $lockPath. Wait for the current transaction or run the writer again after it exits." }
  $lockBody = [System.Text.Encoding]::UTF8.GetBytes((@{ pid = $PID; acquired_at = (Get-Date).ToUniversalTime().ToString('o'); transition = $Transition } | ConvertTo-Json -Compress))
  $lockStream.Write($lockBody, 0, $lockBody.Length); $lockStream.Flush()

  $previousJournal = Read-Json -Path $journalPath
  if ($previousJournal -and [string]$previousJournal.status -in @('prepared','committing')) { [void](Restore-WorkflowJournal -Journal $previousJournal) }
  if ($Recover) { [pscustomobject]@{ status = 'recovered'; recovery_required = [bool]$previousJournal; transition = $Transition } | ConvertTo-Json -Compress; return }

  $state = Read-Json -Path $statePath
  $queue = Read-Json -Path $queuePath
  if (-not $state -or -not $queue -or [int]$state.schema_version -ne 2 -or [int]$queue.schema_version -ne 2) { throw 'Queue/state schema_version must be 2.' }
  if ([string]$state.queue_id -ne [string]$queue.queue_id -or [string]$state.cycle_key -ne [string]$queue.cycle_key) { throw 'Queue/state identity mismatch.' }

  $pageMaterial = @($Page | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }) -join "`n"
  $evidenceMaterial = if (-not [string]::IsNullOrWhiteSpace($EvidenceJson)) { $EvidenceJson } elseif (-not [string]::IsNullOrWhiteSpace($EvidencePath)) { Get-Content -LiteralPath $EvidencePath -Raw -Encoding UTF8 } else { "$pageMaterial`n$ApprovedBy`n$Reason" }
  $fingerprint = Get-Sha256Text -Value ("$Transition`n$($state.queue_id)`n$($state.cycle_key)`n$evidenceMaterial")
  $resolvedOperationId = if ([string]::IsNullOrWhiteSpace($OperationId)) { "$Transition-$($fingerprint.Substring(0, 24))" } else { $OperationId.Trim() }
  $operationIndex = Read-Json -Path $operationIndexPath
  if (-not $operationIndex) { $operationIndex = [pscustomobject]@{ schema_version = 1; operations = @() } }
  $existing = $operationIndex.operations | Where-Object { [string]$_.operation_id -eq $resolvedOperationId } | Select-Object -First 1
  if ($existing) {
    if ([string]$existing.operation_fingerprint -ne $fingerprint) { throw "OperationId is already bound to different input: $resolvedOperationId" }
    [pscustomobject]@{ status = 'idempotent'; idempotent = $true; transition = $Transition; operation_id = $resolvedOperationId; queue_id = $state.queue_id; cycle_key = $state.cycle_key } | ConvertTo-Json -Compress
    return
  }

  if ($Transition -in @('round_validated','implemented','local_validated','deployed','live_verified','observing_7d','reviewed_28d','completed')) { Test-PreconditionGates -CurrentState $state -CurrentQueue $queue }
  $journal = New-WorkflowJournal -Paths (Get-WorkflowPaths -TransitionName $Transition) -Id $resolvedOperationId -Fingerprint $fingerprint
  try {
    $journal.status = 'committing'; $journal.committing_at = (Get-Date).ToUniversalTime().ToString('o'); Write-JsonAtomic -Path $journalPath -Value $journal
    switch ($Transition) {
      'data_validated' { Set-DataValidatedGate }
      'strategy_approved' {
        $approval = Read-Json -Path $approvalPath
        $alreadyApproved = $approval -and [string]$approval.status -eq 'approved' -and [string]$approval.queue_id -eq [string]$queue.queue_id -and [string]$approval.cycle_key -eq [string]$queue.cycle_key
        if (-not $alreadyApproved) {
          if (@($Page | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }).Count -eq 0 -or [string]::IsNullOrWhiteSpace($ApprovedBy) -or [string]::IsNullOrWhiteSpace($Reason)) { throw 'strategy_approved requires Page, ApprovedBy, and Reason.' }
          $approvalWriter = Join-Path $PSScriptRoot 'approve-seo-geo-single-page-review.ps1'
          if ([string]::IsNullOrWhiteSpace($RepoRoot)) { & $approvalWriter -RuntimeRoot $weeklyRoot -Page $Page -ApprovedBy $ApprovedBy -Reason $Reason }
          else { & $approvalWriter -RuntimeRoot $weeklyRoot -Page $Page -ApprovedBy $ApprovedBy -Reason $Reason -RepoRoot $RepoRoot }
          if (-not $?) { throw 'strategy_approved writer failed.' }
        }
        Set-StrategyApprovedGate
      }
      'round_validated' {
        $roundWriter = Join-Path $PSScriptRoot 'complete-seo-geo-round.ps1'
        & $roundWriter -RuntimeRoot $weeklyRoot
        if (-not $?) { throw 'round_validated writer failed.' }
      }
      default {
        $lifecycleWriter = Join-Path $PSScriptRoot 'write-seo-geo-lifecycle-receipt.ps1'
        if (-not [string]::IsNullOrWhiteSpace($EvidencePath)) {
          & $lifecycleWriter -RuntimeRoot $weeklyRoot -Stage $Transition -EvidencePath $EvidencePath
        } elseif (-not [string]::IsNullOrWhiteSpace($EvidenceJson)) {
          & $lifecycleWriter -RuntimeRoot $weeklyRoot -Stage $Transition -EvidenceJson $EvidenceJson
        } else { throw "$Transition requires EvidenceJson or EvidencePath." }
        if (-not $?) { throw "Lifecycle writer failed for $Transition." }
      }
    }
    if ($TestFailAfterExecutor) { throw 'Test failure injected after executor.' }
    $journal.status = 'committed'; $journal.committed_at = (Get-Date).ToUniversalTime().ToString('o'); Write-JsonAtomic -Path $journalPath -Value $journal
    $operationIndex.operations = @($operationIndex.operations) + @([ordered]@{ operation_id = $resolvedOperationId; operation_fingerprint = $fingerprint; transition = $Transition; queue_id = $state.queue_id; cycle_key = $state.cycle_key; committed_at = $journal.committed_at; journal_path = 'latest/seo-geo-workflow-recovery-journal.json' })
    $operationIndex | Add-Member -Force -NotePropertyName updated_at -NotePropertyValue $journal.committed_at
    Write-JsonAtomic -Path $operationIndexPath -Value $operationIndex
    [pscustomobject]@{ status = 'committed'; idempotent = $false; transition = $Transition; operation_id = $resolvedOperationId; queue_id = $state.queue_id; cycle_key = $state.cycle_key; journal = 'latest/seo-geo-workflow-recovery-journal.json' } | ConvertTo-Json -Compress
  } catch {
    $failure = $_
    [void](Restore-WorkflowJournal -Journal $journal)
    throw $failure
  }
} finally {
  if ($lockStream) { $lockStream.Dispose() }
  if (Test-Path -LiteralPath $lockPath) { Remove-Item -LiteralPath $lockPath -Force -ErrorAction SilentlyContinue }
}
