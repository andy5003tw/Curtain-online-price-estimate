$ErrorActionPreference = 'Stop'
$utf8NoBom = [System.Text.UTF8Encoding]::new($false)
$snapshotHelper = Join-Path $PSScriptRoot 'seo-geo-queue-snapshot.ps1'
$cycleScript = Join-Path (Split-Path -Parent $PSScriptRoot) 'Weekly SOP\run-seo-geo-cycle.ps1'
$testRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("seo-geo-queue-snapshots-{0}" -f [guid]::NewGuid().ToString('N'))
$weeklyRoot = Join-Path $testRoot 'runtime'
$latestRoot = Join-Path $weeklyRoot 'latest'
$queuePath = Join-Path $latestRoot 'seo-geo-action-queue.json'
$statePath = Join-Path $latestRoot 'seo-geo-action-queue-state.json'

function Assert-True {
  param([bool]$Condition, [Parameter(Mandatory = $true)][string]$Message)
  if (-not $Condition) { throw $Message }
}

function Assert-BytesEqual {
  param([byte[]]$Expected, [byte[]]$Actual, [string]$Label)
  $expectedBase64 = [Convert]::ToBase64String($Expected)
  $actualBase64 = [Convert]::ToBase64String($Actual)
  Assert-True ($expectedBase64 -ceq $actualBase64) "$Label did not preserve exact raw bytes."
}

function Get-ExpectedArchivePath {
  param([string]$Sha256, [string]$FileName)
  return Join-Path $weeklyRoot "history\curtain-online\seo-geo-queue-snapshots\by-sha256\$Sha256.$FileName"
}

function Get-PairPath {
  param([string]$QueueSha256, [string]$StateSha256)
  return Join-Path $weeklyRoot "history\curtain-online\seo-geo-queue-snapshots\pairs\$QueueSha256`__$StateSha256.json"
}

try {
  if (-not (Test-Path -LiteralPath $snapshotHelper -PathType Leaf)) { throw "Snapshot helper missing: $snapshotHelper" }
  if (-not (Test-Path -LiteralPath $cycleScript -PathType Leaf)) { throw "Cycle script missing: $cycleScript" }
  . $snapshotHelper
  [void](New-Item -ItemType Directory -Path $latestRoot -Force)

  # Include a UTF-8 BOM, CRLFs, and trailing whitespace so the test catches
  # accidental ConvertFrom-Json/ConvertTo-Json normalization.
  $queueTextV1 = "`u{FEFF}{`r`n  `"queue_id`": `"fixture-v1`"`r`n}  `r`n"
  $stateTextV1 = "{`r`n  `"queue_id`": `"fixture-v1`",`r`n  `"status`": `"active`"`r`n}`r`n"
  $queueBytesV1 = [System.Text.Encoding]::UTF8.GetBytes($queueTextV1)
  $stateBytesV1 = $utf8NoBom.GetBytes($stateTextV1)
  [System.IO.File]::WriteAllBytes($queuePath, $queueBytesV1)
  [System.IO.File]::WriteAllBytes($statePath, $stateBytesV1)
  $queueShaV1 = Get-SeoGeoBytesSha256 -Bytes $queueBytesV1
  $stateShaV1 = Get-SeoGeoBytesSha256 -Bytes $stateBytesV1

  Save-SeoGeoQueueSnapshot -WeeklyRoot $weeklyRoot -QueuePath $queuePath -StatePath $statePath
  $queueArchiveV1 = Get-ExpectedArchivePath -Sha256 $queueShaV1 -FileName 'seo-geo-action-queue.json'
  $stateArchiveV1 = Get-ExpectedArchivePath -Sha256 $stateShaV1 -FileName 'seo-geo-action-queue-state.json'
  $pairManifestV1 = Get-PairPath -QueueSha256 $queueShaV1 -StateSha256 $stateShaV1
  Assert-True (Test-Path -LiteralPath $queueArchiveV1 -PathType Leaf) 'Queue bytes were not saved under their SHA-256.'
  Assert-True (Test-Path -LiteralPath $stateArchiveV1 -PathType Leaf) 'Queue-state bytes were not saved under their SHA-256.'
  Assert-True (Test-Path -LiteralPath $pairManifestV1 -PathType Leaf) 'Queue/state pair manifest was not written.'
  Assert-BytesEqual -Expected $queueBytesV1 -Actual ([System.IO.File]::ReadAllBytes($queueArchiveV1)) -Label 'Queue archive v1'
  Assert-BytesEqual -Expected $stateBytesV1 -Actual ([System.IO.File]::ReadAllBytes($stateArchiveV1)) -Label 'Queue-state archive v1'
  $pairV1 = [System.IO.File]::ReadAllText($pairManifestV1, [System.Text.Encoding]::UTF8) | ConvertFrom-Json
  Assert-True ([string]$pairV1.snapshot_type -ceq 'seo_geo_queue_state_raw_bytes' -and [string]$pairV1.files.queue.sha256 -ceq $queueShaV1 -and [string]$pairV1.files.state.sha256 -ceq $stateShaV1) 'Pair manifest is missing the raw queue/state SHA bindings.'
  $pairBytesV1 = [System.IO.File]::ReadAllBytes($pairManifestV1)
  $pairTimestampV1 = (Get-Item -LiteralPath $pairManifestV1).LastWriteTimeUtc

  # Re-saving an identical pair must verify it in place rather than replace it.
  Save-SeoGeoQueueSnapshot -WeeklyRoot $weeklyRoot -QueuePath $queuePath -StatePath $statePath
  Assert-BytesEqual -Expected $pairBytesV1 -Actual ([System.IO.File]::ReadAllBytes($pairManifestV1)) -Label 'Idempotent pair manifest'
  Assert-True ((Get-Item -LiteralPath $pairManifestV1).LastWriteTimeUtc -eq $pairTimestampV1) 'Identical pair manifest was rewritten.'

  # A second queue/state version remains independently retrievable by SHA.
  $queueTextV2 = "{`n  `"queue_id`": `"fixture-v2`"`n}`n"
  $stateTextV2 = "{`n  `"queue_id`": `"fixture-v2`",`n  `"status`": `"observation_only`"`n}`n"
  $queueBytesV2 = $utf8NoBom.GetBytes($queueTextV2)
  $stateBytesV2 = $utf8NoBom.GetBytes($stateTextV2)
  [System.IO.File]::WriteAllBytes($queuePath, $queueBytesV2)
  [System.IO.File]::WriteAllBytes($statePath, $stateBytesV2)
  $queueShaV2 = Get-SeoGeoBytesSha256 -Bytes $queueBytesV2
  $stateShaV2 = Get-SeoGeoBytesSha256 -Bytes $stateBytesV2
  Save-SeoGeoQueueSnapshot -WeeklyRoot $weeklyRoot -QueuePath $queuePath -StatePath $statePath
  $queueArchiveV2 = Get-ExpectedArchivePath -Sha256 $queueShaV2 -FileName 'seo-geo-action-queue.json'
  $stateArchiveV2 = Get-ExpectedArchivePath -Sha256 $stateShaV2 -FileName 'seo-geo-action-queue-state.json'
  Assert-BytesEqual -Expected $queueBytesV1 -Actual ([System.IO.File]::ReadAllBytes($queueArchiveV1)) -Label 'Retained queue archive v1'
  Assert-BytesEqual -Expected $stateBytesV1 -Actual ([System.IO.File]::ReadAllBytes($stateArchiveV1)) -Label 'Retained queue-state archive v1'
  Assert-BytesEqual -Expected $queueBytesV2 -Actual ([System.IO.File]::ReadAllBytes($queueArchiveV2)) -Label 'Queue archive v2'
  Assert-BytesEqual -Expected $stateBytesV2 -Actual ([System.IO.File]::ReadAllBytes($stateArchiveV2)) -Label 'Queue-state archive v2'

  # If a SHA-addressed object is damaged, archiving fails closed and leaves
  # both latest files byte-for-byte untouched.
  $queueLatestBeforeFailure = [System.IO.File]::ReadAllBytes($queuePath)
  $stateLatestBeforeFailure = [System.IO.File]::ReadAllBytes($statePath)
  [System.IO.File]::WriteAllBytes($queueArchiveV2, $utf8NoBom.GetBytes('tampered'))
  $failedClosed = $false
  try {
    Save-SeoGeoQueueSnapshot -WeeklyRoot $weeklyRoot -QueuePath $queuePath -StatePath $statePath
  } catch {
    $failedClosed = $_.Exception.Message -match 'SHA-256 mismatch'
  }
  Assert-True $failedClosed 'A corrupt SHA-addressed queue snapshot was not rejected.'
  Assert-BytesEqual -Expected $queueLatestBeforeFailure -Actual ([System.IO.File]::ReadAllBytes($queuePath)) -Label 'Queue latest after archive failure'
  Assert-BytesEqual -Expected $stateLatestBeforeFailure -Actual ([System.IO.File]::ReadAllBytes($statePath)) -Label 'Queue-state latest after archive failure'

  # Guard the integration point: the immutable snapshot call must happen
  # before either latest queue file is replaced by the cycle generator.
  $cycleText = [System.IO.File]::ReadAllText($cycleScript, [System.Text.Encoding]::UTF8)
  $snapshotIndex = $cycleText.IndexOf('Save-SeoGeoQueueSnapshot -WeeklyRoot $weeklyRoot -QueuePath $outputQueueJson -StatePath $outputQueueStateJson', [StringComparison]::Ordinal)
  $queueWriteIndex = $cycleText.IndexOf('Write-Utf8NoBom -Path $outputQueueJson -Text $queueJsonText', [StringComparison]::Ordinal)
  $stateWriteIndex = $cycleText.IndexOf('Write-Utf8NoBom -Path $outputQueueStateJson -Text $queueStateJsonText', [StringComparison]::Ordinal)
  Assert-True ($snapshotIndex -ge 0 -and $snapshotIndex -lt $queueWriteIndex -and $snapshotIndex -lt $stateWriteIndex) 'Cycle generator does not snapshot existing raw queue/state bytes before replacing latest.'

  Write-Host 'PASS SEO/GEO queue snapshots: raw bytes, SHA retention, idempotency, corruption fail-closed, latest-write ordering'
} finally {
  $tempRoot = [System.IO.Path]::GetFullPath([System.IO.Path]::GetTempPath()).TrimEnd('\', '/') + [System.IO.Path]::DirectorySeparatorChar
  $testRootFull = [System.IO.Path]::GetFullPath($testRoot)
  if ($testRootFull.StartsWith($tempRoot, [StringComparison]::OrdinalIgnoreCase) -and (Test-Path -LiteralPath $testRootFull -PathType Container)) {
    Remove-Item -LiteralPath $testRootFull -Recurse -Force
  }
}
