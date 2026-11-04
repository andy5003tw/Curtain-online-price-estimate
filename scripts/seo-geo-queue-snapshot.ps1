function Get-SeoGeoBytesSha256 {
  param([Parameter(Mandatory = $true)][byte[]]$Bytes)

  $sha = [System.Security.Cryptography.SHA256]::Create()
  try {
    return ([System.BitConverter]::ToString($sha.ComputeHash($Bytes))).Replace('-', '').ToLowerInvariant()
  } finally {
    $sha.Dispose()
  }
}

function Ensure-SeoGeoSnapshotDirectory {
  param([Parameter(Mandatory = $true)][string]$Path)

  if (-not (Test-Path -LiteralPath $Path -PathType Container)) {
    [void](New-Item -ItemType Directory -Path $Path -Force)
  }
}

function Assert-SeoGeoSnapshotBytes {
  param(
    [Parameter(Mandatory = $true)][string]$Path,
    [Parameter(Mandatory = $true)][string]$ExpectedSha256,
    [Parameter(Mandatory = $true)][string]$Label
  )

  if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
    throw "$Label snapshot is missing: $Path"
  }
  $actualSha256 = Get-SeoGeoBytesSha256 -Bytes ([System.IO.File]::ReadAllBytes($Path))
  if ($actualSha256 -cne $ExpectedSha256) {
    throw "$Label snapshot SHA-256 mismatch at $Path (expected=$ExpectedSha256 actual=$actualSha256)."
  }
}

function Write-SeoGeoImmutableSnapshotBytes {
  param(
    [Parameter(Mandatory = $true)][string]$Path,
    [Parameter(Mandatory = $true)][byte[]]$Bytes,
    [Parameter(Mandatory = $true)][string]$ExpectedSha256,
    [Parameter(Mandatory = $true)][string]$Label
  )

  if (Test-Path -LiteralPath $Path -PathType Leaf) {
    Assert-SeoGeoSnapshotBytes -Path $Path -ExpectedSha256 $ExpectedSha256 -Label $Label
    return
  }

  Ensure-SeoGeoSnapshotDirectory -Path (Split-Path -Parent $Path)
  $temporaryPath = "$Path.$([guid]::NewGuid().ToString('N')).tmp"
  $stream = $null
  try {
    $stream = [System.IO.FileStream]::new($temporaryPath, [System.IO.FileMode]::CreateNew, [System.IO.FileAccess]::Write, [System.IO.FileShare]::None)
    $stream.Write($Bytes, 0, $Bytes.Length)
    $stream.Flush($true)
  } finally {
    if ($null -ne $stream) { $stream.Dispose() }
  }

  try {
    # File.Move without overwrite makes the SHA-addressed archive immutable,
    # including when two queue generators race to save the same version.
    [System.IO.File]::Move($temporaryPath, $Path)
  } catch {
    if (Test-Path -LiteralPath $Path -PathType Leaf) {
      Assert-SeoGeoSnapshotBytes -Path $Path -ExpectedSha256 $ExpectedSha256 -Label $Label
    } else {
      throw
    }
  } finally {
    if (Test-Path -LiteralPath $temporaryPath -PathType Leaf) {
      Remove-Item -LiteralPath $temporaryPath -Force -ErrorAction SilentlyContinue
    }
  }

  Assert-SeoGeoSnapshotBytes -Path $Path -ExpectedSha256 $ExpectedSha256 -Label $Label
}

function Save-SeoGeoQueueSnapshot {
  param(
    [Parameter(Mandatory = $true)][string]$WeeklyRoot,
    [Parameter(Mandatory = $true)][string]$QueuePath,
    [Parameter(Mandatory = $true)][string]$StatePath
  )

  $snapshotRoot = Join-Path $WeeklyRoot 'history\curtain-online\seo-geo-queue-snapshots'
  $byShaRoot = Join-Path $snapshotRoot 'by-sha256'
  $pairRoot = Join-Path $snapshotRoot 'pairs'
  $records = [ordered]@{ queue = $null; state = $null }

  foreach ($item in @(
    [PSCustomObject]@{ key = 'queue'; source = 'latest/seo-geo-action-queue.json'; file_name = 'seo-geo-action-queue.json'; path = $QueuePath; label = 'queue' },
    [PSCustomObject]@{ key = 'state'; source = 'latest/seo-geo-action-queue-state.json'; file_name = 'seo-geo-action-queue-state.json'; path = $StatePath; label = 'queue state' }
  )) {
    if (-not (Test-Path -LiteralPath $item.path -PathType Leaf)) { continue }

    # Read and hash the raw bytes. Do not deserialize/re-serialize historical
    # queue data: whitespace, BOM, and line endings are part of its evidence SHA.
    $bytes = [System.IO.File]::ReadAllBytes($item.path)
    $sha256 = Get-SeoGeoBytesSha256 -Bytes $bytes
    $fileName = "$sha256.$($item.file_name)"
    $archivePath = Join-Path $byShaRoot $fileName
    $archiveRelativePath = "history/curtain-online/seo-geo-queue-snapshots/by-sha256/$fileName"
    Write-SeoGeoImmutableSnapshotBytes -Path $archivePath -Bytes $bytes -ExpectedSha256 $sha256 -Label $item.label
    $records[$item.key] = [ordered]@{
      source = $item.source
      path = $archiveRelativePath
      sha256 = $sha256
    }
  }

  if ($null -eq $records.queue -and $null -eq $records.state) { return }

  $queueKey = if ($records.queue) { [string]$records.queue.sha256 } else { 'missing' }
  $stateKey = if ($records.state) { [string]$records.state.sha256 } else { 'missing' }
  $pairPath = Join-Path $pairRoot "$queueKey`__$stateKey.json"
  if (Test-Path -LiteralPath $pairPath -PathType Leaf) {
    try {
      $existingPair = [System.IO.File]::ReadAllText($pairPath, [System.Text.Encoding]::UTF8) | ConvertFrom-Json -ErrorAction Stop
    } catch {
      throw "Existing queue snapshot pair manifest is invalid and will not be overwritten: $pairPath ($($_.Exception.Message))"
    }
    if ([int]$existingPair.schema_version -ne 1 -or [string]$existingPair.snapshot_type -cne 'seo_geo_queue_state_raw_bytes') {
      throw "Existing queue snapshot pair manifest has an unsupported contract and will not be overwritten: $pairPath"
    }

    foreach ($key in @('queue', 'state')) {
      $expected = $records[$key]
      $actual = $existingPair.files.$key
      if (($null -eq $expected) -ne ($null -eq $actual)) {
        throw "Existing queue snapshot pair manifest has a different $key presence and will not be overwritten: $pairPath"
      }
      if ($expected) {
        if ([string]$actual.path -cne [string]$expected.path -or [string]$actual.sha256 -cne [string]$expected.sha256) {
          throw "Existing queue snapshot pair manifest has a different $key binding and will not be overwritten: $pairPath"
        }
        $expectedArchivePath = Join-Path $WeeklyRoot ([string]$expected.path.Replace('/', '\'))
        Assert-SeoGeoSnapshotBytes -Path $expectedArchivePath -ExpectedSha256 ([string]$expected.sha256) -Label "$key pair"
      }
    }
    return
  }

  $pair = [ordered]@{
    schema_version = 1
    snapshot_type = 'seo_geo_queue_state_raw_bytes'
    archived_at = (Get-Date).ToUniversalTime().ToString('o')
    files = $records
  }
  $utf8NoBom = [System.Text.UTF8Encoding]::new($false)
  $pairBytes = $utf8NoBom.GetBytes(($pair | ConvertTo-Json -Depth 6))
  $pairSha256 = Get-SeoGeoBytesSha256 -Bytes $pairBytes
  Write-SeoGeoImmutableSnapshotBytes -Path $pairPath -Bytes $pairBytes -ExpectedSha256 $pairSha256 -Label 'queue pair manifest'

  # Verify the committed manifest and both archived members before latest files
  # are allowed to change.
  $writtenPair = [System.IO.File]::ReadAllText($pairPath, [System.Text.Encoding]::UTF8) | ConvertFrom-Json -ErrorAction Stop
  foreach ($key in @('queue', 'state')) {
    if ($records[$key]) {
      $memberPath = Join-Path $WeeklyRoot ([string]$writtenPair.files.$key.path.Replace('/', '\'))
      Assert-SeoGeoSnapshotBytes -Path $memberPath -ExpectedSha256 ([string]$records[$key].sha256) -Label "$key pair"
    }
  }
}
