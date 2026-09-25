param(
  [ValidateSet('auto', 'weekly', 'monthly')]
  [string]$Mode = 'auto',
  [string]$RuntimeRoot = '',
  [string]$RegistryPath = ''
)

$ErrorActionPreference = 'Stop'

$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
[Console]::OutputEncoding = $utf8NoBom
$OutputEncoding = $utf8NoBom

function Ensure-Dir {
  param([string]$Path)
  if (-not (Test-Path -LiteralPath $Path)) {
    New-Item -ItemType Directory -Path $Path | Out-Null
  }
}

function Read-Utf8Text {
  param([string]$Path)
  return [System.IO.File]::ReadAllText($Path, [System.Text.Encoding]::UTF8)
}

function Write-Utf8NoBom {
  param(
    [string]$Path,
    [string]$Text
  )
  Ensure-Dir -Path (Split-Path -Parent $Path)
  [System.IO.File]::WriteAllText($Path, $Text, $utf8NoBom)
}

function Read-JsonIfExists {
  param([string]$Path)
  if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { return $null }
  return (Read-Utf8Text -Path $Path | ConvertFrom-Json)
}

function Get-Sha256Text {
  param([string]$Text)
  $sha = [System.Security.Cryptography.SHA256]::Create()
  try {
    $bytes = [System.Text.Encoding]::UTF8.GetBytes([string]$Text)
    return ([System.BitConverter]::ToString($sha.ComputeHash($bytes))).Replace('-', '').ToLowerInvariant()
  } finally {
    $sha.Dispose()
  }
}

function Get-Sha256File {
  param([string]$Path)
  if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { return $null }
  $stream = [System.IO.File]::OpenRead($Path)
  $sha = [System.Security.Cryptography.SHA256]::Create()
  try {
    return ([System.BitConverter]::ToString($sha.ComputeHash($stream))).Replace('-', '').ToLowerInvariant()
  } finally {
    $sha.Dispose()
    $stream.Dispose()
  }
}

function Get-RelativePortablePath {
  param(
    [string]$BasePath,
    [string]$Path
  )
  if ([string]::IsNullOrWhiteSpace($Path)) { return $null }
  $baseFull = [System.IO.Path]::GetFullPath($BasePath).TrimEnd('\', '/') + [System.IO.Path]::DirectorySeparatorChar
  $pathFull = [System.IO.Path]::GetFullPath($Path)
  $baseUri = [System.Uri]$baseFull
  $pathUri = [System.Uri]$pathFull
  if ($baseUri.Scheme -ne $pathUri.Scheme) { return $pathFull.Replace('\', '/') }
  return [System.Uri]::UnescapeDataString($baseUri.MakeRelativeUri($pathUri).ToString()).Replace('\', '/')
}

function Resolve-RuntimePath {
  param(
    [string]$WeeklyRoot,
    [string]$Value
  )
  if ([string]::IsNullOrWhiteSpace($Value)) { return $null }
  if ([System.IO.Path]::IsPathRooted($Value)) { return [System.IO.Path]::GetFullPath($Value) }
  return [System.IO.Path]::GetFullPath((Join-Path $WeeklyRoot ($Value.Replace('/', '\'))))
}

function Resolve-ManifestPath {
  param(
    [string]$WeeklyRoot,
    [string]$Value
  )
  if ([string]::IsNullOrWhiteSpace($Value)) { return $null }
  return Resolve-RuntimePath -WeeklyRoot $WeeklyRoot -Value $Value
}

function Get-WindowFreshness {
  param(
    [string]$WeeklyRoot,
    [string]$LatestDir,
    [string]$Window,
    [int]$MaxAgeDays,
    [string]$ExpectedHost
  )

  $manifestPath = Join-Path $LatestDir 'weekly-sop-last-run.json'
  if (-not (Test-Path -LiteralPath $manifestPath -PathType Leaf)) {
    return [PSCustomObject]@{
      window = $Window
      fresh = $false
      status = 'missing'
      text = "Missing latest $Window manifest"
      age_days = $null
      run_time = $null
      manifest_path = $manifestPath
      report_folder = $null
      missing_reports = @()
    }
  }

  try {
    $manifest = Read-JsonIfExists -Path $manifestPath
  } catch {
    return [PSCustomObject]@{
      window = $Window
      fresh = $false
      status = 'invalid'
      text = "Invalid latest $Window manifest: $($_.Exception.Message)"
      age_days = $null
      run_time = $null
      manifest_path = $manifestPath
      report_folder = $null
      missing_reports = @()
    }
  }

  if (-not $manifest -or $manifest.status -ne 'success') {
    return [PSCustomObject]@{
      window = $Window
      fresh = $false
      status = 'not-success'
      text = "Latest $Window manifest status is $($manifest.status)"
      age_days = $null
      run_time = $manifest.run_time
      manifest_path = $manifestPath
      report_folder = (Resolve-ManifestPath -WeeklyRoot $WeeklyRoot -Value ([string]$manifest.report_folder))
      missing_reports = @()
    }
  }

  $manifestHost = ([string]$manifest.expected_host).Trim().TrimEnd('.').ToLowerInvariant()
  $foreignRows = if ($manifest.host_counts) { [int]$manifest.host_counts.foreign } else { -1 }
  $targetRows = if ($manifest.host_counts) { [int]$manifest.host_counts.target } else { 0 }
  if ($manifestHost -ne $ExpectedHost -or $foreignRows -ne 0 -or $targetRows -le 0) {
    return [PSCustomObject]@{
      window = $Window
      fresh = $false
      status = 'invalid-host'
      text = "Latest $Window failed host validation (expected=$ExpectedHost manifest=$manifestHost target=$targetRows foreign=$foreignRows)"
      age_days = $null
      run_time = $manifest.run_time
      manifest_path = $manifestPath
      report_folder = (Resolve-ManifestPath -WeeklyRoot $WeeklyRoot -Value ([string]$manifest.report_folder))
      missing_reports = @()
    }
  }

  $runTime = [datetime]::MinValue
  if (-not [datetime]::TryParse([string]$manifest.run_time, [ref]$runTime)) {
    return [PSCustomObject]@{
      window = $Window
      fresh = $false
      status = 'invalid-time'
      text = "Latest $Window manifest has invalid run_time: $($manifest.run_time)"
      age_days = $null
      run_time = $manifest.run_time
      manifest_path = $manifestPath
      report_folder = (Resolve-ManifestPath -WeeklyRoot $WeeklyRoot -Value ([string]$manifest.report_folder))
      missing_reports = @()
    }
  }

  $missingReports = @()
  if ($manifest.latest_reports) {
    foreach ($prop in $manifest.latest_reports.PSObject.Properties) {
      $resolvedReport = Resolve-ManifestPath -WeeklyRoot $WeeklyRoot -Value ([string]$prop.Value)
      if (-not (Test-Path -LiteralPath $resolvedReport -PathType Leaf)) {
        $missingReports += $resolvedReport
      }
    }
  }

  $endDate = [datetime]::MinValue
  $hasCompleteRange = [bool]$manifest.date_range_complete -and [datetime]::TryParseExact([string]$manifest.end_date, 'yyyy-MM-dd', [Globalization.CultureInfo]::InvariantCulture, [Globalization.DateTimeStyles]::None, [ref]$endDate)
  $ageAnchor = if ($hasCompleteRange) { $endDate } else { $runTime }
  $ageDays = [int][Math]::Floor(((Get-Date).Date - $ageAnchor.Date).TotalDays)
  $isFresh = ($ageDays -le $MaxAgeDays -and $missingReports.Count -eq 0)
  $dataConfidence = if ([string]::IsNullOrWhiteSpace([string]$manifest.data_confidence)) { 'unknown' } else { [string]$manifest.data_confidence }
  $bootstrapped = [bool]($manifest.baseline -and $manifest.baseline.bootstrapped)
  $queryPageAvailable = [bool]$manifest.query_page_available
  $diagnosticReasons = @()
  foreach ($kind in @('date', 'date_page', 'device_page', 'country_page', 'device_query')) {
    $binding = if ($manifest.diagnostic_dimensions) { $manifest.diagnostic_dimensions.$kind } else { $null }
    if (-not $binding -or -not [bool]$binding.available -or [int]$binding.row_count -le 0 -or [string]::IsNullOrWhiteSpace([string]$binding.path) -or [string]::IsNullOrWhiteSpace([string]$binding.sha256)) {
      $diagnosticReasons += "$kind binding unavailable"
      continue
    }
    $diagnosticPath = Resolve-ManifestPath -WeeklyRoot $WeeklyRoot -Value ([string]$binding.path)
    if (-not $diagnosticPath -or -not (Test-Path -LiteralPath $diagnosticPath -PathType Leaf)) {
      $diagnosticReasons += "$kind file missing"
    } elseif ((Get-Sha256File -Path $diagnosticPath) -ne ([string]$binding.sha256).ToLowerInvariant()) {
      $diagnosticReasons += "$kind SHA mismatch"
    }
  }
  $dateBinding = if ($manifest.diagnostic_dimensions) { $manifest.diagnostic_dimensions.date } else { $null }
  if ($hasCompleteRange -and $dateBinding -and [bool]$dateBinding.available) {
    $datePath = Resolve-ManifestPath -WeeklyRoot $WeeklyRoot -Value ([string]$dateBinding.path)
    if ($datePath -and (Test-Path -LiteralPath $datePath -PathType Leaf)) {
      $expectedDates = @()
      $cursor = [datetime]::ParseExact([string]$manifest.start_date, 'yyyy-MM-dd', [Globalization.CultureInfo]::InvariantCulture)
      while ($cursor -le $endDate) { $expectedDates += $cursor.ToString('yyyy-MM-dd'); $cursor = $cursor.AddDays(1) }
      $actualDates = @(Import-Csv -LiteralPath $datePath -Encoding UTF8 | ForEach-Object { [string]$_.date } | Where-Object { $_ -match '^\d{4}-\d{2}-\d{2}$' } | Sort-Object -Unique)
      $missingDates = @($expectedDates | Where-Object { $_ -notin $actualDates })
      if ($missingDates.Count -gt 0) { $diagnosticReasons += "date coverage missing $($missingDates -join ',')" }
    }
  }
  $diagnosticsComplete = ($diagnosticReasons.Count -eq 0)
  $decisionReady = ($dataConfidence -eq 'decision_ready' -and -not $bootstrapped -and $hasCompleteRange -and $queryPageAvailable -and $diagnosticsComplete)
  $status = if ($missingReports.Count -gt 0) { 'missing-report' } elseif ($ageDays -gt $MaxAgeDays) { 'stale' } else { 'fresh' }
  $text = if ($isFresh) {
    "Latest $Window is fresh ($ageDays days old)"
  } elseif ($missingReports.Count -gt 0) {
    "Latest $Window has missing report files"
  } else {
    "Latest $Window is stale ($ageDays days old; max $MaxAgeDays)"
  }

  return [PSCustomObject]@{
    window = $Window
    fresh = $isFresh
    status = $status
    text = $text
    age_days = $ageDays
    run_time = $manifest.run_time
    data_confidence = $dataConfidence
    decision_ready = $decisionReady
    bootstrapped = $bootstrapped
    start_date = [string]$manifest.start_date
    end_date = [string]$manifest.end_date
    snapshot_family_id = [string]$manifest.snapshot_family_id
    query_page_available = $queryPageAvailable
    diagnostics_complete = $diagnosticsComplete
    diagnostic_reasons = $diagnosticReasons
    date_range_complete = $hasCompleteRange
    run_id = [string]$manifest.run_id
    input_sha256 = ([string]$manifest.input_sha256).ToLowerInvariant()
    manifest_sha256 = Get-Sha256File -Path $manifestPath
    manifest = $manifest
    manifest_path = $manifestPath
    report_folder = (Resolve-ManifestPath -WeeklyRoot $WeeklyRoot -Value ([string]$manifest.report_folder))
    missing_reports = $missingReports
  }
}

function Parse-Number {
  param([string]$Value)
  if ([string]::IsNullOrWhiteSpace($Value)) { return 0.0 }
  $clean = ([string]$Value).Trim().TrimEnd('%').Replace(',', '').Replace('pp', '').Replace('n/a', '').Trim()
  $parsed = 0.0
  if ([double]::TryParse($clean, [System.Globalization.NumberStyles]::Float, [System.Globalization.CultureInfo]::InvariantCulture, [ref]$parsed)) {
    return $parsed
  }
  return 0.0
}

function Format-Int {
  param([double]$Value)
  return ('{0:N0}' -f $Value)
}

function Format-Decimal {
  param([double]$Value)
  if ($Value -le 0) { return '0.00' }
  return ('{0:N2}' -f $Value)
}

function Format-Ctr {
  param([double]$Value)
  return ('{0:N2}%' -f $Value)
}

function Escape-MdCell {
  param([string]$Value)
  if ($null -eq $Value) { return '' }
  return ([string]$Value).Replace('|', '\|').Replace("`r", ' ').Replace("`n", '<br>')
}

function Escape-Html {
  param([string]$Value)
  if ($null -eq $Value) { return '' }
  return [System.Net.WebUtility]::HtmlEncode([string]$Value)
}

function Remove-MdCode {
  param([string]$Value)
  if ($null -eq $Value) { return '' }
  return ([string]$Value).Trim().Trim('`').Trim()
}

function Split-MarkdownTableLine {
  param([string]$Line)
  $trimmed = $Line.Trim()
  if ($trimmed.StartsWith('|')) { $trimmed = $trimmed.Substring(1) }
  if ($trimmed.EndsWith('|')) { $trimmed = $trimmed.Substring(0, $trimmed.Length - 1) }
  return @($trimmed -split '\|' | ForEach-Object { $_.Trim() })
}

function Get-MarkdownTable {
  param(
    [string]$Text,
    [string]$HeadingPrefix
  )

  $lines = @($Text -split "`r?`n")
  $headingIndex = -1
  for ($i = 0; $i -lt $lines.Count; $i++) {
    if ($lines[$i] -like "$HeadingPrefix*") {
      $headingIndex = $i
      break
    }
  }
  if ($headingIndex -lt 0) { return @() }

  $tableLines = @()
  for ($i = $headingIndex + 1; $i -lt $lines.Count; $i++) {
    $line = $lines[$i]
    if ($line.Trim().StartsWith('|')) {
      $tableLines += $line
      continue
    }
    if ($tableLines.Count -gt 0) { break }
  }
  if ($tableLines.Count -lt 3) { return @() }

  $headers = Split-MarkdownTableLine -Line $tableLines[0]
  $rows = @()
  foreach ($line in $tableLines[2..($tableLines.Count - 1)]) {
    $cells = Split-MarkdownTableLine -Line $line
    if ($cells.Count -lt 2) { continue }
    $row = [ordered]@{}
    for ($i = 0; $i -lt $headers.Count; $i++) {
      $row[$headers[$i]] = if ($i -lt $cells.Count) { $cells[$i] } else { '' }
    }
    $rows += [PSCustomObject]$row
  }
  return $rows
}

function Get-FirstMarkdownTable {
  param([string]$Text)
  $lines = @($Text -split "`r?`n")
  $start = -1
  for ($i = 0; $i -lt $lines.Count - 1; $i++) {
    if ($lines[$i].Trim().StartsWith('|') -and $lines[$i + 1].Trim().StartsWith('| ---')) {
      $start = $i
      break
    }
  }
  if ($start -lt 0) { return @() }

  $tableLines = @()
  for ($i = $start; $i -lt $lines.Count; $i++) {
    $line = $lines[$i]
    if ($line.Trim().StartsWith('|')) {
      $tableLines += $line
      continue
    }
    if ($tableLines.Count -gt 0) { break }
  }
  if ($tableLines.Count -lt 3) { return @() }

  $headers = Split-MarkdownTableLine -Line $tableLines[0]
  $rows = @()
  foreach ($line in $tableLines[2..($tableLines.Count - 1)]) {
    $cells = Split-MarkdownTableLine -Line $line
    if ($cells.Count -lt 2) { continue }
    $row = [ordered]@{}
    for ($i = 0; $i -lt $headers.Count; $i++) {
      $row[$headers[$i]] = if ($i -lt $cells.Count) { $cells[$i] } else { '' }
    }
    $rows += [PSCustomObject]$row
  }
  return $rows
}

function Normalize-PageUrl {
  param([string]$Page)
  $value = Remove-MdCode -Value $Page
  if ([string]::IsNullOrWhiteSpace($value)) { return '' }
  $value = $value -replace '#home$', ''
  if ($value -eq 'https://online.hong-sen.com') { return 'https://online.hong-sen.com/' }
  try {
    $uri = [System.Uri]$value
    $normalized = $uri.GetLeftPart([System.UriPartial]::Path)
    if ($normalized -eq 'https://online.hong-sen.com') { return 'https://online.hong-sen.com/' }
    if (-not $normalized.EndsWith('/')) { $normalized += '/' }
    return $normalized
  } catch {
    return $value
  }
}

function Get-NormalizedBaselineRows {
  param([string]$Path, [hashtable]$CanonicalAliasMap = @{})
  if ([string]::IsNullOrWhiteSpace($Path) -or -not (Test-Path -LiteralPath $Path -PathType Leaf)) { return @() }
  $rows = @()
  foreach ($row in @(Import-Csv -LiteralPath $Path -Encoding utf8)) {
    $page = [string]$row.page
    if ($page -and $page -ne '(all pages)') {
      $page = Normalize-PageUrl -Page $page
      if ($CanonicalAliasMap.ContainsKey($page)) { $page = [string]$CanonicalAliasMap[$page] }
    }
    $rows += [PSCustomObject]@{
      query       = ([string]$row.query).Trim()
      page        = $page
      clicks      = [int](Parse-Number -Value $row.clicks)
      impressions = [int](Parse-Number -Value $row.impressions)
      ctr         = [double](Parse-Number -Value $row.ctr)
      position    = [double](Parse-Number -Value $row.position)
    }
  }
  return $rows
}

function Get-BaselinePathFromManifest {
  param(
    [string]$WeeklyRoot,
    [object]$Manifest,
    [ValidateSet('query', 'page', 'query_page')]
    [string]$Kind,
    [bool]$Required = $false
  )
  $value = $null
  if ($Manifest -and $Manifest.baseline) {
    $value = switch ($Kind) {
      'query' { [string]$Manifest.baseline.query }
      'page' { [string]$Manifest.baseline.page }
      'query_page' { [string]$Manifest.baseline.query_page }
    }
  }
  $path = Resolve-ManifestPath -WeeklyRoot $WeeklyRoot -Value $value
  if ($Required -and ([string]::IsNullOrWhiteSpace($path) -or -not (Test-Path -LiteralPath $path -PathType Leaf))) {
    throw "Missing normalized current $Kind baseline referenced by manifest: $value"
  }
  return $path
}

function Get-DiagnosticRowsFromManifest {
  param([string]$WeeklyRoot, [object]$Manifest, [string]$Kind)
  if (-not $Manifest -or -not $Manifest.diagnostic_dimensions) { return @() }
  $binding = $Manifest.diagnostic_dimensions.$Kind
  if (-not $binding -or -not [bool]$binding.available -or [string]::IsNullOrWhiteSpace([string]$binding.path)) { return @() }
  $path = Resolve-ManifestPath -WeeklyRoot $WeeklyRoot -Value ([string]$binding.path)
  if (-not $path -or -not (Test-Path -LiteralPath $path -PathType Leaf)) { return @() }
  if (-not [string]::IsNullOrWhiteSpace([string]$binding.sha256)) {
    $actual = Get-Sha256File -Path $path
    if ($actual -ne ([string]$binding.sha256).ToLowerInvariant()) { throw "Diagnostic dimension $Kind SHA mismatch: $($binding.path)" }
  }
  return @(Import-Csv -LiteralPath $path -Encoding UTF8 | ForEach-Object {
    [PSCustomObject]@{
      date = [string]$_.date; device = [string]$_.device; country = [string]$_.country; query = ([string]$_.query).Trim(); page = Normalize-PageUrl -Page ([string]$_.page)
      clicks = [int](Parse-Number -Value $_.clicks); impressions = [int](Parse-Number -Value $_.impressions); ctr = [double](Parse-Number -Value $_.ctr); position = [double](Parse-Number -Value $_.position)
    }
  })
}

function Update-DiagnosticHistoryFromManifest {
  param([string]$WeeklyRoot, [object]$Freshness)
  $result = [ordered]@{}
  if (-not $Freshness -or -not $Freshness.manifest) { return $result }
  $window = [string]$Freshness.window
  $startDate = [string]$Freshness.start_date
  $endDate = [string]$Freshness.end_date
  foreach ($kind in @('date', 'date_page', 'device_page', 'country_page', 'device_query')) {
    $binding = if ($Freshness.manifest.diagnostic_dimensions) { $Freshness.manifest.diagnostic_dimensions.$kind } else { $null }
    if (-not $binding -or -not [bool]$binding.available) { continue }
    $sourcePath = Resolve-ManifestPath -WeeklyRoot $WeeklyRoot -Value ([string]$binding.path)
    if (-not $sourcePath -or -not (Test-Path -LiteralPath $sourcePath -PathType Leaf)) { continue }
    $snapshotPath = Join-Path $WeeklyRoot ("history\curtain-online\$window\diagnostics\snapshots\${startDate}_${endDate}\$kind.csv")
    $snapshotDir = Split-Path -Parent $snapshotPath
    if (-not (Test-Path -LiteralPath $snapshotDir -PathType Container)) { [void](New-Item -ItemType Directory -Path $snapshotDir -Force) }
    if (-not (Test-Path -LiteralPath $snapshotPath -PathType Leaf) -or (Get-Sha256File -Path $snapshotPath) -ne (Get-Sha256File -Path $sourcePath)) {
      Copy-Item -LiteralPath $sourcePath -Destination $snapshotPath -Force
    }
    $sourceRows = @(Import-Csv -LiteralPath $snapshotPath -Encoding UTF8)
    $datedRows = @($sourceRows | Where-Object { [string]$_.date -match '^\d{4}-\d{2}-\d{2}$' })
    $dailyPath = Join-Path $WeeklyRoot "history\curtain-online\$window\diagnostics\daily\$kind.csv"
    $dailyStatus = 'available'
    $dailyReason = $null
    if ($datedRows.Count -gt 0) {
      $keyColumns = switch ($kind) { 'date' { @('date') } 'date_page' { @('date','page') } 'device_page' { @('date','device','page') } 'country_page' { @('date','country','page') } 'device_query' { @('date','device','query') } }
      $merged = @{}
      if (Test-Path -LiteralPath $dailyPath -PathType Leaf) {
        foreach ($row in @(Import-Csv -LiteralPath $dailyPath -Encoding UTF8)) { $merged[(($keyColumns | ForEach-Object { [string]$row.$_ }) -join "`u{001f}")] = $row }
      }
      foreach ($row in $datedRows) { $merged[(($keyColumns | ForEach-Object { [string]$row.$_ }) -join "`u{001f}")] = $row }
      $dailyDir = Split-Path -Parent $dailyPath
      if (-not (Test-Path -LiteralPath $dailyDir -PathType Container)) { [void](New-Item -ItemType Directory -Path $dailyDir -Force) }
      @($merged.Values | Sort-Object @($keyColumns | ForEach-Object { @{ Expression = [string]$_; Descending = $false } })) | Export-Csv -LiteralPath $dailyPath -NoTypeInformation -Encoding UTF8
    } else {
      $dailyStatus = 'unavailable'
      $dailyReason = 'legacy diagnostic snapshot has no Date column; immutable snapshot retained'
    }
    $dailyRows = if (Test-Path -LiteralPath $dailyPath -PathType Leaf) { @(Import-Csv -LiteralPath $dailyPath -Encoding UTF8) } else { @() }
    $dailyDates = @($dailyRows | ForEach-Object { [string]$_.date } | Where-Object { $_ -match '^\d{4}-\d{2}-\d{2}$' } | Sort-Object -Unique)
    $result[$kind] = [ordered]@{
      snapshot = [ordered]@{ path = Get-RelativePortablePath -BasePath $WeeklyRoot -Path $snapshotPath; sha256 = Get-Sha256File -Path $snapshotPath; row_count = $sourceRows.Count; start_date = $startDate; end_date = $endDate; source_manifest_path = Get-RelativePortablePath -BasePath $WeeklyRoot -Path $Freshness.manifest_path; source_manifest_sha256 = [string]$Freshness.manifest_sha256 }
      daily_history = [ordered]@{ status = $dailyStatus; reason = $dailyReason; path = if (Test-Path -LiteralPath $dailyPath -PathType Leaf) { Get-RelativePortablePath -BasePath $WeeklyRoot -Path $dailyPath } else { $null }; sha256 = if (Test-Path -LiteralPath $dailyPath -PathType Leaf) { Get-Sha256File -Path $dailyPath } else { $null }; row_count = $dailyRows.Count; start_date = if ($dailyDates.Count) { $dailyDates[0] } else { $null }; end_date = if ($dailyDates.Count) { $dailyDates[-1] } else { $null } }
    }
  }
  return $result
}

function Get-DiagnosticDailyRows {
  param([string]$WeeklyRoot, [object]$HistoryBinding, [string]$Kind)
  $binding = if ($HistoryBinding) { $HistoryBinding.$Kind } else { $null }
  if (-not $binding -or -not $binding.daily_history -or [string]::IsNullOrWhiteSpace([string]$binding.daily_history.path)) { return @() }
  $path = Resolve-ManifestPath -WeeklyRoot $WeeklyRoot -Value ([string]$binding.daily_history.path)
  if (-not $path -or -not (Test-Path -LiteralPath $path -PathType Leaf)) { return @() }
  return @(Import-Csv -LiteralPath $path -Encoding UTF8 | ForEach-Object { [PSCustomObject]@{ date=[string]$_.date; device=[string]$_.device; country=[string]$_.country; query=([string]$_.query).Trim(); page=Normalize-PageUrl -Page ([string]$_.page); clicks=[int](Parse-Number -Value $_.clicks); impressions=[int](Parse-Number -Value $_.impressions); ctr=[double](Parse-Number -Value $_.ctr); position=[double](Parse-Number -Value $_.position) } })
}

function Measure-DiagnosticMetrics {
  param([object[]]$Rows)
  $impressions = [double](($Rows | Measure-Object impressions -Sum).Sum)
  $clicks = [double](($Rows | Measure-Object clicks -Sum).Sum)
  $weightedPosition = [double](($Rows | ForEach-Object { [double]$_.position * [double]$_.impressions } | Measure-Object -Sum).Sum)
  return [PSCustomObject]@{ clicks=[int]$clicks; impressions=[int]$impressions; ctr=if($impressions -gt 0){[Math]::Round(100*$clicks/$impressions,2)}else{0.0}; position=if($impressions -gt 0){[Math]::Round($weightedPosition/$impressions,2)}else{0.0} }
}

function Get-PeriodDiagnosticResult {
  param([object[]]$Rows, [string[]]$AvailableDates, [string]$StartDate, [string]$EndDate, [string]$Page)
  $expected = @(); $cursor=[datetime]::ParseExact($StartDate,'yyyy-MM-dd',[Globalization.CultureInfo]::InvariantCulture); $end=[datetime]::ParseExact($EndDate,'yyyy-MM-dd',[Globalization.CultureInfo]::InvariantCulture)
  while($cursor -le $end){$expected += $cursor.ToString('yyyy-MM-dd');$cursor=$cursor.AddDays(1)}
  $missing=@($expected|Where-Object{$_ -notin $AvailableDates})
  if($missing.Count){return [PSCustomObject]@{available=$false;reason="data unavailable: daily history missing $($missing -join ',')";start_date=$StartDate;end_date=$EndDate;clicks=$null;impressions=$null;ctr=$null;position=$null}}
  $periodRows=@($Rows|Where-Object{$_.date -ge $StartDate -and $_.date -le $EndDate -and ([string]::IsNullOrWhiteSpace($Page) -or $_.page -eq $Page)})
  $metrics=Measure-DiagnosticMetrics -Rows $periodRows
  return [PSCustomObject]@{available=$true;reason=$null;start_date=$StartDate;end_date=$EndDate;clicks=$metrics.clicks;impressions=$metrics.impressions;ctr=$metrics.ctr;position=$metrics.position}
}

function Format-DiagnosticResult {
  param([object]$Result)
  if(-not $Result -or -not [bool]$Result.available){return [string]$Result.reason}
  return "clicks=$($Result.clicks), impressions=$($Result.impressions), CTR=$($Result.ctr)%, position=$($Result.position)"
}

function New-SitewideDailyAnalysis {
  param([object[]]$Rows)
  $days=@($Rows|Where-Object{$_.date -match '^\d{4}-\d{2}-\d{2}$'}|Sort-Object date)
  $output=@();$previous=$null
  foreach($row in $days){$metrics=Measure-DiagnosticMetrics -Rows @($row);$output += [PSCustomObject]@{date=$row.date;clicks=$metrics.clicks;impressions=$metrics.impressions;ctr=$metrics.ctr;position=$metrics.position;clicks_delta=if($previous){$metrics.clicks-$previous.clicks}else{$null};impressions_delta=if($previous){$metrics.impressions-$previous.impressions}else{$null};ctr_delta_pp=if($previous){[Math]::Round($metrics.ctr-$previous.ctr,2)}else{$null};position_delta=if($previous){[Math]::Round($metrics.position-$previous.position,2)}else{$null}};$previous=$metrics}
  return [PSCustomObject]@{available=($output.Count -gt 0);start_date=if($output.Count){$output[0].date}else{$null};end_date=if($output.Count){$output[-1].date}else{$null};day_count=$output.Count;days=$output;reason=if($output.Count){$null}else{'data unavailable: Date daily history is empty'}}
}

function Get-DevicePageDifferences {
  param([object[]]$Rows)
  $result=@()
  foreach($group in @($Rows|Where-Object{$_.page}|Group-Object page)){$total=[double](($group.Group|Measure-Object impressions -Sum).Sum);$devices=@($group.Group|Group-Object device|ForEach-Object{$m=Measure-DiagnosticMetrics -Rows $_.Group;[PSCustomObject]@{device=$_.Name;clicks=$m.clicks;impressions=$m.impressions;share=if($total){[Math]::Round(100*$m.impressions/$total,2)}else{0};ctr=$m.ctr;position=$m.position}}|Sort-Object impressions -Descending);$positionGap=if($devices.Count -gt 1){[Math]::Round((($devices.position|Measure-Object -Maximum).Maximum-(($devices.position|Measure-Object -Minimum).Minimum)),2)}else{0};$ctrGap=if($devices.Count -gt 1){[Math]::Round((($devices.ctr|Measure-Object -Maximum).Maximum-(($devices.ctr|Measure-Object -Minimum).Minimum)),2)}else{0};$result += [PSCustomObject]@{page=$group.Name;total_impressions=[int]$total;dominant_device=if($devices.Count){$devices[0].device}else{$null};position_gap=$positionGap;ctr_gap_pp=$ctrGap;anomaly=($total -ge 50 -and ($positionGap -ge 5 -or $ctrGap -ge 3));devices=$devices}}
  return @($result|Sort-Object total_impressions -Descending)
}

function Get-CountryPageAnomalies {
  param([object[]]$Rows)
  $result=@()
  foreach($group in @($Rows|Where-Object{$_.page}|Group-Object page)){$total=[double](($group.Group|Measure-Object impressions -Sum).Sum);$countries=@($group.Group|Group-Object country|ForEach-Object{$m=Measure-DiagnosticMetrics -Rows $_.Group;[PSCustomObject]@{country=$_.Name;clicks=$m.clicks;impressions=$m.impressions;share=if($total){[Math]::Round(100*$m.impressions/$total,2)}else{0};ctr=$m.ctr;position=$m.position}}|Sort-Object impressions -Descending);$nonTarget=@($countries|Where-Object{$_.country -and $_.country -ne 'twn' -and $_.impressions -ge 20 -and $_.share -ge 20});if($nonTarget.Count){$result += [PSCustomObject]@{page=$group.Name;total_impressions=[int]$total;anomaly=$true;reason="non-TWN country share >=20% with >=20 impressions";countries=$countries}}}
  return @($result|Sort-Object total_impressions -Descending)
}

function Convert-OwnerUrl {
  param(
    [string]$OwnerUrl,
    [string]$ExpectedHost
  )
  if ([string]::IsNullOrWhiteSpace($OwnerUrl)) { return '' }
  if ([System.Uri]::IsWellFormedUriString($OwnerUrl, [System.UriKind]::Absolute)) {
    return Normalize-PageUrl -Page $OwnerUrl
  }
  $baseUri = [System.Uri]("https://$ExpectedHost/")
  return Normalize-PageUrl -Page ([System.Uri]::new($baseUri, $OwnerUrl).AbsoluteUri)
}

function Get-RegistryOwners {
  param(
    [string]$Path,
    [string]$ExpectedHost
  )
  $registry = Read-JsonIfExists -Path $Path
  if (-not $registry -or -not $registry.targets) { throw "Missing or invalid target registry: $Path" }

  $owners = @()
  $ownerUrls = @{}
  $keywords = @{}
  $order = 1
  foreach ($target in @($registry.targets | Where-Object { ([string]$_.status).ToLowerInvariant() -eq 'active' })) {
    $keyword = ([string]$target.primaryKeyword).Trim()
    $ownerPage = Convert-OwnerUrl -OwnerUrl ([string]$target.ownerUrl) -ExpectedHost $ExpectedHost
    if ([string]::IsNullOrWhiteSpace($keyword) -or [string]::IsNullOrWhiteSpace($ownerPage)) {
      throw "Active registry target is missing primaryKeyword or ownerUrl: $($target.clusterId)"
    }
    if ($ownerUrls.ContainsKey($ownerPage)) { throw "Duplicate active owner URL in target registry: $ownerPage" }
    if ($keywords.ContainsKey($keyword)) { throw "Duplicate active primary keyword in target registry: $keyword" }
    $ownerUrls[$ownerPage] = $true
    $keywords[$keyword] = $true
    $owners += [PSCustomObject]@{
      order          = $order
      clusterId      = [string]$target.clusterId
      layer          = [string]$target.layer
      primaryKeyword = $keyword
      variants       = @($target.variants | ForEach-Object { ([string]$_).Trim() } | Where-Object { $_ })
      intent          = [string]$target.intent
      ownerPath       = [string]$target.ownerUrl
      ownerPage       = $ownerPage
      pageType        = [string]$target.pageType
      priority        = [string]$target.priority
      schemaProfile   = [string]$target.schemaProfile
      businessValue   = [string]$target.businessValue
      lastChangedAt   = [string]$target.lastChangedAt
      canonicalAliases = @($target.canonicalAliases)
      status          = [string]$target.status
    }
    $order++
  }
  if ($owners.Count -eq 0) { throw "Target registry has no active owners: $Path" }
  return [PSCustomObject]@{
    registry = $registry
    owners = $owners
  }
}

function Get-MonitorOnlyAssets {
  param(
    [object]$Registry,
    [string]$ExpectedHost,
    [hashtable]$OwnerUrls
  )
  $assets = @()
  $ids = @{}
  $urls = @{}
  $order = 1
  foreach ($asset in @($Registry.monitorOnlyAssets)) {
    $id = ([string]$asset.id).Trim()
    $label = ([string]$asset.label).Trim()
    $page = Convert-OwnerUrl -OwnerUrl ([string]$asset.url) -ExpectedHost $ExpectedHost
    if (-not $id -or -not $label -or -not $page) {
      throw 'monitorOnlyAssets requires id, label, and url.'
    }
    if ($ids.ContainsKey($id) -or $urls.ContainsKey($page)) {
      throw "Duplicate monitor-only asset id or URL: $id / $page"
    }
    if ($OwnerUrls.ContainsKey($page)) {
      throw "Monitor-only asset overlaps an active keyword owner: $page"
    }
    $ids[$id] = $true
    $urls[$page] = $true
    $assets += [PSCustomObject]@{
      order = $order
      id = $id
      label = $label
      type = ([string]$asset.type).Trim()
      page = $page
      monitoringTerms = @($asset.monitoringTerms | ForEach-Object { ([string]$_).Trim() } | Where-Object { $_ })
    }
    $order++
  }
  return $assets
}

function Get-DynamicMonitorOnlyAssets {
  param(
    [object[]]$StaticAssets,
    [object[]]$PageRows,
    [hashtable]$OwnerUrls,
    [string]$ExpectedHost,
    [int]$MaximumDynamic = 5
  )
  $used = @{}
  foreach ($asset in $StaticAssets) { $used[[string]$asset.page] = $true }
  $candidates = @($PageRows | Where-Object {
    $page = [string]$_.page
    $page -and -not $OwnerUrls.ContainsKey($page) -and -not $used.ContainsKey($page) -and [int]$_.impressions -gt 0 -and
      ($page -like '*/about/' -or $page -like '*/blog/*' -or $page -like '*/location/*' -or $page -like '*/calculator/*')
  } | Sort-Object impressions -Descending | Select-Object -First $MaximumDynamic)
  $order = @($StaticAssets).Count + 1
  $dynamic = @()
  foreach ($row in $candidates) {
    $uri = [System.Uri]([string]$row.page)
    $slug = $uri.AbsolutePath.Trim('/').Replace('/', '-')
    $type = if ($uri.AbsolutePath -like '/about/*' -or $uri.AbsolutePath -eq '/about/') { 'brand' } elseif ($uri.AbsolutePath -like '/blog/*') { 'blog_pillar' } elseif ($uri.AbsolutePath -like '/location/*') { 'geo' } else { 'calculator' }
    $dynamic += [PSCustomObject]@{
      order = $order; id = "dynamic-$slug"; label = "依 28d 流量動態監控：$($uri.AbsolutePath)"; type = $type; page = [string]$row.page
      monitoringTerms = @(); selection_reason = "28d impressions=$([int]$row.impressions); position=$(Format-Decimal -Value ([double]$row.position))"
    }
    $order++
  }
  return $dynamic
}

function Index-RowsByPage {
  param([object[]]$Rows)
  $map = @{}
  foreach ($row in $Rows) {
    if (-not $row.page) { continue }
    if (-not $map.ContainsKey($row.page)) {
      $map[$row.page] = [PSCustomObject]@{ query = ''; page = [string]$row.page; clicks = [int]$row.clicks; impressions = [int]$row.impressions; ctr = [double]$row.ctr; position = [double]$row.position }
    } else {
      $current = $map[$row.page]
      $oldImpressions = [int]$current.impressions
      $newImpressions = [int]$row.impressions
      $totalImpressions = $oldImpressions + $newImpressions
      $current.clicks = [int]$current.clicks + [int]$row.clicks
      $current.position = if ($totalImpressions -gt 0) { (($oldImpressions * [double]$current.position) + ($newImpressions * [double]$row.position)) / $totalImpressions } else { 0.0 }
      $current.impressions = $totalImpressions
      $current.ctr = if ($totalImpressions -gt 0) { 100.0 * [int]$current.clicks / $totalImpressions } else { 0.0 }
    }
  }
  return $map
}

function Get-CanonicalAliasMap {
  param([object[]]$Owners, [string]$ExpectedHost)
  $map = @{}
  foreach ($owner in $Owners) {
    $canonical = [string]$owner.ownerPage
    $aliases = @($owner.canonicalAliases)
    if ([string]$owner.clusterId -match '^product-(P\d+)$') { $aliases += "/products/$($Matches[1])/" }
    foreach ($alias in @($aliases | Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_) })) {
      $normalized = Convert-OwnerUrl -OwnerUrl ([string]$alias) -ExpectedHost $ExpectedHost
      if ($normalized -and $normalized -ne $canonical) { $map[$normalized] = $canonical }
    }
  }
  return $map
}

function Get-QueryDelta {
  param(
    [object[]]$CurrentRows,
    [object[]]$PreviousRows,
    [string]$CurrentStartDate,
    [string]$CurrentEndDate,
    [string]$ComparisonStartDate,
    [string]$ComparisonEndDate,
    [string]$ComparisonType,
    [string]$WeeklyRoot,
    [int]$MinimumImpressions = 5,
    [int]$Limit = 25
  )
  if (@($PreviousRows).Count -eq 0) {
    return [PSCustomObject]@{ available = $false; new_count = 0; lost_count = 0; signal_count = 0; noise_count = 0; pending_confirmation_count = 0; new_queries = @(); lost_queries = @(); pending_queries = @(); noise_queries = @(); current_start_date = $CurrentStartDate; current_end_date = $CurrentEndDate; comparison_start_date = $ComparisonStartDate; comparison_end_date = $ComparisonEndDate; comparison_type = $ComparisonType; minimum_impressions = $MinimumImpressions; requires_consecutive_periods = $true; reason = 'comparison query baseline unavailable' }
  }
  $current = Index-RowsByQuery -Rows $CurrentRows
  $previous = Index-RowsByQuery -Rows $PreviousRows
  $rawNew = @($current.Keys | Where-Object { -not $previous.ContainsKey($_) } | ForEach-Object { $current[$_] } | Sort-Object impressions -Descending)
  $rawLost = @($previous.Keys | Where-Object { -not $current.ContainsKey($_) } | ForEach-Object { $previous[$_] } | Sort-Object impressions -Descending)

  $historyPath = Join-Path $WeeklyRoot 'history\curtain-online\query-delta-history.json'
  $history = if (Test-Path -LiteralPath $historyPath -PathType Leaf) { Read-JsonIfExists -Path $historyPath } else { $null }
  if (-not $history) { $history = [PSCustomObject]@{ schema_version = 1; entries = @() } }
  $priorEntry = @($history.entries | Where-Object { [string]$_.current_end_date -lt $CurrentEndDate } | Sort-Object current_end_date -Descending | Select-Object -First 1)[0]
  $priorNew = @($priorEntry.candidate_new_queries | ForEach-Object { [string]$_ })
  $priorLost = @($priorEntry.candidate_lost_queries | ForEach-Object { [string]$_ })
  $signalsNew = @()
  $signalsLost = @()
  $pending = @()
  $noise = @()
  foreach ($row in $rawNew) {
    if ([int]$row.impressions -lt $MinimumImpressions) {
      $noise += [PSCustomObject]@{ change = 'new'; signal_class = 'emerging_noise'; query = [string]$row.query; page = [string]$row.page; clicks = [int]$row.clicks; impressions = [int]$row.impressions; ctr = [double]$row.ctr; position = [double]$row.position }
    } elseif ($priorNew -contains [string]$row.query) {
      $signalsNew += $row
    } else {
      $pending += [PSCustomObject]@{ change = 'new'; signal_class = 'awaiting_second_period'; query = [string]$row.query; page = [string]$row.page; clicks = [int]$row.clicks; impressions = [int]$row.impressions; ctr = [double]$row.ctr; position = [double]$row.position }
    }
  }
  foreach ($row in $rawLost) {
    if ([int]$row.impressions -lt $MinimumImpressions) {
      $noise += [PSCustomObject]@{ change = 'lost'; signal_class = 'disappearing_noise'; query = [string]$row.query; page = [string]$row.page; clicks = [int]$row.clicks; impressions = [int]$row.impressions; ctr = [double]$row.ctr; position = [double]$row.position }
    } elseif ($priorLost -contains [string]$row.query) {
      $signalsLost += $row
    } else {
      $pending += [PSCustomObject]@{ change = 'lost'; signal_class = 'awaiting_second_period'; query = [string]$row.query; page = [string]$row.page; clicks = [int]$row.clicks; impressions = [int]$row.impressions; ctr = [double]$row.ctr; position = [double]$row.position }
    }
  }

  $entryKey = "$CurrentStartDate~$CurrentEndDate|$ComparisonStartDate~$ComparisonEndDate"
  $history.entries = @($history.entries | Where-Object { [string]$_.entry_key -ne $entryKey }) + @([PSCustomObject]@{
    entry_key = $entryKey; generated_at = (Get-Date).ToUniversalTime().ToString('o')
    current_start_date = $CurrentStartDate; current_end_date = $CurrentEndDate
    comparison_start_date = $ComparisonStartDate; comparison_end_date = $ComparisonEndDate; comparison_type = $ComparisonType
    minimum_impressions = $MinimumImpressions
    candidate_new_queries = @($rawNew | Where-Object { [int]$_.impressions -ge $MinimumImpressions } | ForEach-Object { [string]$_.query })
    candidate_lost_queries = @($rawLost | Where-Object { [int]$_.impressions -ge $MinimumImpressions } | ForEach-Object { [string]$_.query })
  })
  $history | Add-Member -NotePropertyName updated_at -NotePropertyValue ((Get-Date).ToUniversalTime().ToString('o')) -Force
  Write-Utf8NoBom -Path $historyPath -Text ($history | ConvertTo-Json -Depth 10)

  return [PSCustomObject]@{
    available = $true
    current_start_date = $CurrentStartDate; current_end_date = $CurrentEndDate
    comparison_start_date = $ComparisonStartDate; comparison_end_date = $ComparisonEndDate
    comparison_type = if ([string]::IsNullOrWhiteSpace($ComparisonType)) { 'unknown_legacy' } else { $ComparisonType }
    minimum_impressions = $MinimumImpressions; requires_consecutive_periods = $true
    raw_new_count = $rawNew.Count; raw_lost_count = $rawLost.Count
    new_count = $signalsNew.Count; lost_count = $signalsLost.Count; signal_count = $signalsNew.Count + $signalsLost.Count
    noise_count = $noise.Count; pending_confirmation_count = $pending.Count
    new_queries = @($signalsNew | Select-Object -First $Limit); lost_queries = @($signalsLost | Select-Object -First $Limit)
    pending_queries = @($pending | Sort-Object impressions -Descending | Select-Object -First $Limit)
    noise_queries = @($noise | Sort-Object impressions -Descending | Select-Object -First $Limit)
    reason = 'manifest-bound current/comparison periods; minimum impressions plus two-period confirmation'
  }
}

function Index-RowsByQuery {
  param([object[]]$Rows)
  $map = @{}
  foreach ($row in $Rows) {
    $key = ([string]$row.query).Trim()
    if ($key -and -not $map.ContainsKey($key)) {
      $map[$key] = $row
    }
  }
  return $map
}

function Get-QueryTerms {
  param([object]$Owner)
  $terms = @([string]$Owner.primaryKeyword) + @($Owner.variants)
  return @($terms |
    ForEach-Object { ([string]$_).Trim() } |
    Where-Object { $_ } |
    Select-Object -Unique)
}

function Get-BestQueryMetric {
  param(
    [string[]]$Terms,
    [hashtable]$Map7d,
    [hashtable]$Map28d,
    [string]$Mode
  )
  $matches = @()
  foreach ($term in $Terms) {
    if ($Mode -eq 'monthly' -and $Map28d.ContainsKey($term)) {
      $matches += [PSCustomObject]@{ term = $term; window = '28d'; row = $Map28d[$term]; weight = 2 }
    }
    if ($Map7d.ContainsKey($term)) {
      $matches += [PSCustomObject]@{ term = $term; window = '7d'; row = $Map7d[$term]; weight = 1 }
    }
  }
  if ($matches.Count -eq 0) { return $null }
  return @($matches | Sort-Object -Property @{ Expression = { $_.weight }; Descending = $true }, @{ Expression = { $_.row.impressions }; Descending = $true } | Select-Object -First 1)[0]
}

function Get-OwnerQueryPageAnalysis {
  param(
    [object]$Owner,
    [object[]]$Rows
  )
  $terms = @((Get-QueryTerms -Owner $Owner) | ForEach-Object { ([string]$_).Trim() } | Where-Object { $_ })
  if ($terms.Count -eq 0 -or @($Rows).Count -eq 0) {
    return [PSCustomObject]@{ available = $false; total_impressions = 0; owner_impressions = 0; owner_share = 0.0; competing_pages = @(); cannibalization = $false; alignment_eligible = $false; reason = 'Query × Page baseline unavailable.' }
  }
  $termSet = @{}
  foreach ($term in $terms) { $termSet[$term] = $true }
  $byPage = @{}
  foreach ($row in $Rows) {
    $query = ([string]$row.query).Trim()
    $page = [string]$row.page
    if (-not $termSet.ContainsKey($query) -or [string]::IsNullOrWhiteSpace($page)) { continue }
    if (-not $byPage.ContainsKey($page)) { $byPage[$page] = 0 }
    $byPage[$page] += [int]$row.impressions
  }
  $total = [int](($byPage.Values | Measure-Object -Sum).Sum)
  $ownerPage = [string]$Owner.ownerPage
  $ownerImpressions = if ($byPage.ContainsKey($ownerPage)) { [int]$byPage[$ownerPage] } else { 0 }
  $ownerShare = if ($total -gt 0) { [Math]::Round(($ownerImpressions * 100.0 / $total), 2) } else { 0.0 }
  $pages = @($byPage.GetEnumerator() | ForEach-Object {
    [PSCustomObject]@{
      page = [string]$_.Key
      impressions = [int]$_.Value
      share = if ($total -gt 0) { [Math]::Round(([int]$_.Value * 100.0 / $total), 2) } else { 0.0 }
      is_owner = ([string]$_.Key -eq $ownerPage)
    }
  } | Sort-Object -Property @{ Expression = { $_.impressions }; Descending = $true }, @{ Expression = { $_.page }; Descending = $false })
  $materialPages = @($pages | Where-Object { $_.share -ge 20 })
  $competingPages = @($pages | Where-Object { -not $_.is_owner } | Select-Object -First 3)
  $cannibalization = ($total -ge 50 -and $materialPages.Count -ge 2)
  $alignmentEligible = ($total -ge 50 -and $ownerShare -lt 80) -or $cannibalization
  $reason = if ($total -eq 0) {
    'owner terms have no Query × Page impressions.'
  } elseif ($cannibalization) {
    "cannibalization: $($materialPages.Count) pages each hold >=20% of $total impressions."
  } elseif ($ownerShare -lt 80) {
    "owner share below 80%: $ownerShare% of $total impressions."
  } else {
    "owner share $ownerShare% of $total impressions."
  }
  return [PSCustomObject]@{
    available = $true
    total_impressions = $total
    owner_impressions = $ownerImpressions
    owner_share = $ownerShare
    competing_pages = $competingPages
    cannibalization = $cannibalization
    alignment_eligible = $alignmentEligible
    reason = $reason
  }
}

function Get-PositionBand {
  param([double]$Position)
  if ($Position -gt 0 -and $Position -le 3) { return '1-3' }
  if ($Position -le 7) { return '4-7' }
  if ($Position -le 10) { return '8-10' }
  if ($Position -le 15) { return '11-15' }
  if ($Position -le 20) { return '16-20' }
  if ($Position -le 30) { return '21-30' }
  return '31+'
}

function New-CtrBands {
  param([object[]]$Rows, [int]$MinimumImpressions)
  $bands = @()
  foreach ($band in @('1-3','4-7','8-10','11-15','16-20','21-30','31+')) {
    $bandRows = @($Rows | Where-Object { (Get-PositionBand -Position ([double]$_.position)) -eq $band })
    $impressions = [double](($bandRows | Measure-Object -Property impressions -Sum).Sum)
    $clicks = [double](($bandRows | Measure-Object -Property clicks -Sum).Sum)
    $ctr = if ($impressions -gt 0) { 100.0 * $clicks / $impressions } else { 0.0 }
    # Conservative normal-approximation lower bound. It prevents a tiny or
    # volatile cohort from becoming an automatic snippet task.
    $p = $ctr / 100.0
    $lower = if ($impressions -ge $MinimumImpressions) { [Math]::Max(0.0, 100.0 * ($p - 1.96 * [Math]::Sqrt(($p * (1.0 - $p)) / $impressions))) } else { $null }
    $bands += [PSCustomObject]@{ position_band = $band; clicks = [int]$clicks; impressions = [int]$impressions; weighted_ctr = (Format-Ctr -Value $ctr); lower_bound_ctr = if ($null -ne $lower) { Format-Ctr -Value $lower } else { 'n/a' }; eligible = ($null -ne $lower); target_ctr = $lower }
  }
  return $bands
}

function New-CtrSegment {
  param([string]$Scope, [string]$Device, [string]$PageType, [string]$BrandScope, [object[]]$Rows, [int]$MinimumImpressions)
  return [PSCustomObject]@{ scope = $Scope; device = $Device; page_type = $PageType; brand_scope = $BrandScope; minimum_impressions = $MinimumImpressions; bands = @(New-CtrBands -Rows $Rows -MinimumImpressions $MinimumImpressions) }
}

function Get-PageTypeForBenchmark {
  param([string]$Page, [object[]]$Owners)
  $owner = @($Owners | Where-Object { [string]$_.ownerPage -eq $Page } | Select-Object -First 1)[0]
  if ($owner -and -not [string]::IsNullOrWhiteSpace([string]$owner.pageType)) { return [string]$owner.pageType }
  if ($Page -like '*/products/*') { return 'product' }
  if ($Page -like '*/location/*') { return 'geo' }
  if ($Page -like '*/blog/*') { return 'blog' }
  if ($Page -like '*/calculator/*') { return 'calculator' }
  if ($Page -eq 'https://online.hong-sen.com/') { return 'home' }
  return 'other'
}

function Test-BrandedQuery {
  param([string]$Query)
  return [regex]::IsMatch($Query, '宏森|hong\s*-?\s*sen', [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
}

function New-CtrBenchmark {
  param(
    [object[]]$Rows,
    [object[]]$QueryRows,
    [object[]]$DeviceQueryRows,
    [object[]]$Owners,
    [string]$WeeklyRoot,
    [string]$StartDate,
    [string]$EndDate,
    [object[]]$DateRows,
    [object]$Manifest,
    [string]$ManifestPath,
    [string]$ManifestSha256,
    [int]$MinimumImpressions = 100
  )
  $segments = @()
  $segments += New-CtrSegment -Scope 'page' -Device 'all' -PageType 'all' -BrandScope 'all' -Rows $Rows -MinimumImpressions $MinimumImpressions
  $typedRows = @($Rows | ForEach-Object { [PSCustomObject]@{ clicks=$_.clicks; impressions=$_.impressions; position=$_.position; page_type=(Get-PageTypeForBenchmark -Page ([string]$_.page) -Owners $Owners) } })
  foreach ($pageType in @($typedRows.page_type | Sort-Object -Unique)) {
    $segments += New-CtrSegment -Scope 'page' -Device 'all' -PageType $pageType -BrandScope 'all' -Rows @($typedRows | Where-Object { $_.page_type -eq $pageType }) -MinimumImpressions 60
  }
  foreach ($brandScope in @('branded','non_branded')) {
    $querySegmentRows = @($QueryRows | Where-Object { (Test-BrandedQuery -Query ([string]$_.query)) -eq ($brandScope -eq 'branded') })
    $segments += New-CtrSegment -Scope 'query' -Device 'all' -PageType 'all' -BrandScope $brandScope -Rows $querySegmentRows -MinimumImpressions 80
  }
  foreach ($device in @($DeviceQueryRows.device | Sort-Object -Unique)) {
    foreach ($brandScope in @('branded','non_branded')) {
      $deviceRows = @($DeviceQueryRows | Where-Object { $_.device -eq $device -and (Test-BrandedQuery -Query ([string]$_.query)) -eq ($brandScope -eq 'branded') })
      $segments += New-CtrSegment -Scope 'query' -Device ([string]$device) -PageType 'all' -BrandScope $brandScope -Rows $deviceRows -MinimumImpressions 60
    }
  }

  $historyPath = Join-Path $WeeklyRoot 'history\curtain-online\ctr-benchmark-history.json'
  $history = if (Test-Path -LiteralPath $historyPath -PathType Leaf) { Read-JsonIfExists -Path $historyPath } else { [PSCustomObject]@{ schema_version = 1; windows = @() } }
  if (-not $history) { $history = [PSCustomObject]@{ schema_version = 1; windows = @() } }
  foreach ($oldWindow in @($history.windows)) {
    if (-not ($oldWindow.PSObject.Properties.Name -contains 'valid')) {
      $reason = if ([string]$oldWindow.window_key -eq '2026-07-14~2026-08-10') { 'invalid Date coverage: 2026-08-10 was not present as API final data' } else { 'historical unbound window: manifest path/SHA, Date completeness, and decision_ready were not recorded' }
      $oldWindow | Add-Member -NotePropertyName valid -NotePropertyValue $false -Force
      $oldWindow | Add-Member -NotePropertyName invalid_reason -NotePropertyValue $reason -Force
    }
    if (-not [bool]$oldWindow.valid) {
      foreach ($field in @{
        decision_ready = $false
        date_range_complete = $false
        manifest_path = $null
        manifest_sha256 = $null
        date_path = $null
        date_sha256 = $null
        expected_date_count = 28
        actual_date_count = $null
        missing_dates = @()
        provenance_status = 'historical_unbound_evidence'
      }.GetEnumerator()) {
        if (-not ($oldWindow.PSObject.Properties.Name -contains $field.Key)) {
          $oldWindow | Add-Member -NotePropertyName $field.Key -NotePropertyValue $field.Value
        }
      }
      if ([string]$oldWindow.window_key -eq '2026-07-14~2026-08-10') {
        $oldWindow.missing_dates = @('2026-08-10')
      }
    }
  }
  $windowKey = "$StartDate~$EndDate"
  $expectedDates = @()
  $dateCursor = [datetime]::ParseExact($StartDate, 'yyyy-MM-dd', [Globalization.CultureInfo]::InvariantCulture)
  $dateEnd = [datetime]::ParseExact($EndDate, 'yyyy-MM-dd', [Globalization.CultureInfo]::InvariantCulture)
  while ($dateCursor -le $dateEnd) { $expectedDates += $dateCursor.ToString('yyyy-MM-dd'); $dateCursor = $dateCursor.AddDays(1) }
  $actualDates = @($DateRows | ForEach-Object { [string]$_.date } | Where-Object { $_ -match '^\d{4}-\d{2}-\d{2}$' } | Sort-Object -Unique)
  $missingDates = @($expectedDates | Where-Object { $_ -notin $actualDates })
  $is28Days = ($expectedDates.Count -eq 28)
  $manifestMatches = [bool]($Manifest -and [string]$Manifest.start_date -eq $StartDate -and [string]$Manifest.end_date -eq $EndDate)
  $decisionReady = [bool]($Manifest -and $Manifest.decision_ready -and [string]$Manifest.data_confidence -eq 'decision_ready')
  $currentValid = [bool]($is28Days -and $manifestMatches -and $decisionReady -and $missingDates.Count -eq 0 -and -not [string]::IsNullOrWhiteSpace($ManifestPath) -and $ManifestSha256 -match '^[0-9a-f]{64}$')
  $invalidReason = if ($currentValid) { $null } elseif (-not $is28Days) { 'window is not exactly 28 inclusive dates' } elseif (-not $manifestMatches) { 'manifest start/end do not match benchmark window' } elseif (-not $decisionReady) { 'manifest is not decision_ready' } elseif ($missingDates.Count -gt 0) { "Date coverage incomplete: missing $($missingDates -join ',')" } else { 'manifest path/SHA binding is incomplete' }
  $otherWindows = @($history.windows | Where-Object { [string]$_.window_key -ne $windowKey })
  $history.windows = @($otherWindows) + @([PSCustomObject]@{
    window_key=$windowKey; start_date=$StartDate; end_date=$EndDate; generated_at=(Get-Date).ToUniversalTime().ToString('o')
    manifest_path=$ManifestPath; manifest_sha256=$ManifestSha256
    date_path=if ($Manifest.diagnostic_dimensions.date) { [string]$Manifest.diagnostic_dimensions.date.path } else { $null }
    date_sha256=if ($Manifest.diagnostic_dimensions.date) { ([string]$Manifest.diagnostic_dimensions.date.sha256).ToLowerInvariant() } else { $null }
    expected_date_count=$expectedDates.Count; actual_date_count=$actualDates.Count; missing_dates=$missingDates
    date_range_complete=($missingDates.Count -eq 0 -and $is28Days); decision_ready=$decisionReady
    valid=$currentValid; invalid_reason=$invalidReason; provenance_status=if($currentValid){'manifest_date_bound'}else{'invalid'}; segments=$segments
  })
  $history | Add-Member -NotePropertyName updated_at -NotePropertyValue ((Get-Date).ToUniversalTime().ToString('o')) -Force
  Write-Utf8NoBom -Path $historyPath -Text ($history | ConvertTo-Json -Depth 20)

  $selected = @()
  $boundary = [datetime]::MaxValue
  foreach ($window in @($history.windows | Where-Object { [bool]$_.valid } | Sort-Object { [datetime]$_.end_date } -Descending)) {
    $start = [datetime]$window.start_date; $end = [datetime]$window.end_date
    if ($end -lt $boundary) { $selected += $window; $boundary = $start }
  }
  $mergedSegments = @()
  $segmentKeys = @($selected.segments | ForEach-Object { "$($_.scope)|$($_.device)|$($_.page_type)|$($_.brand_scope)" } | Sort-Object -Unique)
  foreach ($segmentKey in $segmentKeys) {
    $parts = $segmentKey.Split('|')
    $sourceSegments = @($selected.segments | Where-Object { "$($_.scope)|$($_.device)|$($_.page_type)|$($_.brand_scope)" -eq $segmentKey })
    $minimum = [int](($sourceSegments | Select-Object -First 1).minimum_impressions)
    $aggregateRows = @()
    foreach ($band in @('1-3','4-7','8-10','11-15','16-20','21-30','31+')) {
      $bandRows = @($sourceSegments.bands | Where-Object { $_.position_band -eq $band })
      $representativePosition = switch ($band) { '1-3' { 2 } '4-7' { 5 } '8-10' { 9 } '11-15' { 13 } '16-20' { 18 } '21-30' { 25 } default { 31 } }
      $aggregateRows += [PSCustomObject]@{ clicks=[int](($bandRows|Measure-Object clicks -Sum).Sum); impressions=[int](($bandRows|Measure-Object impressions -Sum).Sum); position=$representativePosition }
    }
    $mergedSegments += New-CtrSegment -Scope $parts[0] -Device $parts[1] -PageType $parts[2] -BrandScope $parts[3] -Rows $aggregateRows -MinimumImpressions $minimum
  }
  $fallback = @($mergedSegments | Where-Object { $_.scope -eq 'page' -and $_.device -eq 'all' -and $_.page_type -eq 'all' -and $_.brand_scope -eq 'all' } | Select-Object -First 1)[0]
  return [PSCustomObject]@{
    available = [bool]($selected.Count -gt 0 -and $fallback)
    method = 'non_overlapping_28d_segmented_ctr_lower_bound'
    device_scope = if (@($DeviceQueryRows).Count -gt 0) { 'segmented' } else { 'all_devices_fallback' }
    minimum_impressions = $MinimumImpressions
    history_window_count = $selected.Count
    history_windows = @($selected | ForEach-Object { $_.window_key })
    selected_window = if ($selected.Count -gt 0) { [string]$selected[0].window_key } else { $null }
    selected_manifest_path = if ($selected.Count -gt 0) { [string]$selected[0].manifest_path } else { $null }
    selected_manifest_sha256 = if ($selected.Count -gt 0) { [string]$selected[0].manifest_sha256 } else { $null }
    invalid_windows = @($history.windows | Where-Object { -not [bool]$_.valid } | ForEach-Object { [PSCustomObject]@{ window_key=[string]$_.window_key; reason=[string]$_.invalid_reason } })
    segments = $mergedSegments
    bands = if ($fallback) { $fallback.bands } else { @() }
  }
}

function Get-TargetCtr {
  param([double]$Position, [object]$Benchmark, [string]$PageType = 'all')
  $band = Get-PositionBand -Position $Position
  if (-not $Benchmark -or -not [bool]$Benchmark.available) { return [PSCustomObject]@{ available = $false; position_band = $band; target_ctr = $null; reason = 'no valid manifest/Date-bound CTR benchmark window' } }
  $segment = @($Benchmark.segments | Where-Object { $_.scope -eq 'page' -and $_.device -eq 'all' -and $_.page_type -eq $PageType -and $_.brand_scope -eq 'all' } | Select-Object -First 1)[0]
  if (-not $segment) { $segment = @($Benchmark.segments | Where-Object { $_.scope -eq 'page' -and $_.device -eq 'all' -and $_.page_type -eq 'all' -and $_.brand_scope -eq 'all' } | Select-Object -First 1)[0] }
  $row = @($segment.bands | Where-Object { $_.position_band -eq $band } | Select-Object -First 1)[0]
  if ($null -eq $row -or -not [bool]$row.eligible) { return [PSCustomObject]@{ available = $false; position_band = $band; target_ctr = $null; reason = "本站 $band 排名區間樣本不足" } }
  return [PSCustomObject]@{ available = $true; position_band = $band; target_ctr = [double]$row.target_ctr; reason = "本站 $($segment.page_type) / $band 非重疊 28d conservative CTR benchmark" }
}

function Get-ActionType {
  param(
    [double]$Position,
    [double]$Ctr,
    [double]$Impressions,
    [string]$Mode,
    [object]$Benchmark,
    [string]$PageType = 'all'
  )
  $targetCtr = Get-TargetCtr -Position $Position -Benchmark $Benchmark -PageType $PageType
  if ($targetCtr.available -and $Ctr -lt $targetCtr.target_ctr -and $Impressions -gt 0) { return 'CTR 修正 / snippet quick win' }
  if ($Position -ge 8 -and $Position -le 15) { return '排名 8-15 推前 10' }
  if ($Position -gt 15 -and $Impressions -gt 0) { return '內容 / FAQ / 內鏈補強' }
  if ($Mode -eq 'weekly') { return '7d watchlist 微調' }
  return '觀察'
}

function Get-PerformanceOpportunity {
  param(
    [object]$PageMetric28d,
    [object]$QueryMetric28d,
    [object]$Benchmark,
    [string]$PageType = 'all'
  )
  # Content compliance is a quality floor, not a reason to ignore proven
  # search-performance opportunities. Keep this gate deliberately strict so
  # a normal low-volume fluctuation does not create a source-change Round.
  $metric = if ($PageMetric28d) { $PageMetric28d } elseif ($QueryMetric28d) { $QueryMetric28d.row } else { $null }
  if (-not $metric) { return [PSCustomObject]@{ qualifies = $false; reason = '' } }
  $impressions = [double]$metric.impressions
  $position = [double]$metric.position
  $ctr = [double]$metric.ctr
  $targetCtr = Get-TargetCtr -Position $position -Benchmark $Benchmark -PageType $PageType
  if (-not $targetCtr.available) { return [PSCustomObject]@{ qualifies = $false; reason = "CTR benchmark unavailable: $($targetCtr.reason)" } }
  $ctrGap = $targetCtr.target_ctr - $ctr
  if ($impressions -lt 250 -or $position -lt 6 -or $position -gt 15 -or $ctrGap -lt 0.4) {
    return [PSCustomObject]@{ qualifies = $false; reason = '' }
  }
  $queryText = if ($QueryMetric28d) { "; owner query=$($QueryMetric28d.term), impr=$($QueryMetric28d.row.impressions), pos=$(Format-Decimal -Value ([double]$QueryMetric28d.row.position)), CTR=$(Format-Ctr -Value ([double]$QueryMetric28d.row.ctr))" } else { '' }
  return [PSCustomObject]@{
    qualifies = $true
    reason = "28d page impr=$impressions, pos=$(Format-Decimal -Value $position), CTR=$(Format-Ctr -Value $ctr)，低於 $($targetCtr.position_band) benchmark lower bound $(Format-Ctr -Value $targetCtr.target_ctr) $queryText"
  }
}

function Get-IntentType {
  param(
    [string]$Page,
    [string]$ActionType
  )
  if ($ActionType -like 'CTR*') { return '高曝光低 CTR' }
  if ($ActionType -like '排名*') { return '前 10 邊緣詞' }
  if ($Page -like '*/location/*') { return 'GEO 地區推進' }
  if ($Page -like '*/products/*') { return '產品交易意圖' }
  if ($Page -like '*/calculator/*') { return '估價交易意圖' }
  if ($Page -like '*/blog/*') { return '價格資訊意圖' }
  return '入口/品牌意圖'
}

function Get-PageTask {
  param(
    [string]$Page,
    [string[]]$Keywords
  )
  $keywordText = ($Keywords -join ' / ')
  $base = @(
    "title/meta description 放入：$keywordText",
    'H1 / 首屏短答案直接回答搜尋意圖',
    'FAQ 與 JSON-LD 同步，避免 schema 和可見內容不一致',
    '補 2-3 個內鏈錨文字，導到 owner page、價格指南、估價頁或 GEO 頁'
  )
  if ($Page -like '*/blog/*') {
    $base += '價格指南頁優先補「合理價格、安裝費、試算差異」摘要與 CTA。'
  } elseif ($Page -like '*/calculator/*') {
    $base += '估價頁優先補「1 分鐘試算、基本安裝費、同尺寸比較」首屏與 FAQ。'
  } elseif ($Page -like '*/products/' -or $Page -like '*/products') {
    $base += '產品總覽頁聚焦品類比較與估價分流，不取代單一產品 owner page。'
  } elseif ($Page -like '*/products/*') {
    $base += '產品頁聚焦材質/價格/適用情境，不寫成重複 GEO 頁。'
  } elseif ($Page -like '*/location/*') {
    $base += 'GEO 頁需在 title、H1、FAQ、內鏈都看得到地區詞。'
  } elseif ($Page -like '*/about/*' -or $Page -like '*/about') {
    $base += '品牌頁只補工廠、服務流程與信任證據，不定位成首頁或產品交易入口。'
  } elseif ($Page -like '*/cases/*' -or $Page -like '*/cases') {
    $base += '案例頁聚焦完工情境、材質與服務證據，不定位成首頁或搶產品 owner 詞。'
  } else {
    $base += '首頁定位為品牌與估價入口，不與產品頁或 GEO 頁搶同一長尾詞。'
  }
  return ($base -join '；')
}

function New-ActionRow {
  param(
    [int]$Priority,
    [object]$Owner,
    [object]$PageMetric7d,
    [object]$PageMetric28d,
    [object]$QueryMetric7d,
    [object]$QueryMetric28d,
    [object]$Compliance,
    [object]$Benchmark,
    [ValidateSet('content_gap', 'performance', 'alignment')][string]$EligibilityKind = 'content_gap',
    [string]$EligibilityReason = ''
  )

  $page = [string]$Owner.ownerPage
  $metric = if ($PageMetric28d) { $PageMetric28d } elseif ($QueryMetric28d) { $QueryMetric28d.row } elseif ($PageMetric7d) { $PageMetric7d } elseif ($QueryMetric7d) { $QueryMetric7d.row } else { $null }

  $clicks7d = if ($PageMetric7d) { [int]$PageMetric7d.clicks } else { 0 }
  $impressions7d = if ($PageMetric7d) { [int]$PageMetric7d.impressions } else { 0 }
  $ctr7d = if ($PageMetric7d) { [double]$PageMetric7d.ctr } else { 0.0 }
  $position7d = if ($PageMetric7d) { [double]$PageMetric7d.position } else { 0.0 }
  $clicks28d = if ($PageMetric28d) { [int]$PageMetric28d.clicks } else { 0 }
  $impressions28d = if ($PageMetric28d) { [int]$PageMetric28d.impressions } else { 0 }
  $ctr28d = if ($PageMetric28d) { [double]$PageMetric28d.ctr } else { 0.0 }
  $position28d = if ($PageMetric28d) { [double]$PageMetric28d.position } else { 0.0 }
  $ctr = if ($metric) { [double]$metric.ctr } else { 0.0 }
  $position = if ($metric) { [double]$metric.position } else { 0.0 }
  $impressions = if ($metric) { [double]$metric.impressions } else { 0.0 }
  $targetCtr = Get-TargetCtr -Position $position -Benchmark $Benchmark -PageType ([string]$Owner.pageType)
  $ctrGap = if ($targetCtr.available) { [Math]::Max(0.0, $targetCtr.target_ctr - $ctr) } else { 0.0 }
  $edgeBonus = if ($position -ge 8 -and $position -le 15) { 45 } elseif ($position -gt 15 -and $position -le 25) { 25 } elseif ($position -gt 0 -and $position -le 10) { 35 } else { 0 }
  $priorityBonus = switch ([string]$Owner.priority) { 'P0' { 30 } 'P1' { 20 } default { 10 } }
  $businessBonus = switch ([string]$Owner.businessValue) { 'critical' { 25 } 'high' { 15 } 'medium' { 8 } default { 0 } }
  $sampleWeight = [Math]::Min(1.0, $impressions / 250.0)
  $dataScore = ($impressions * $ctrGap / 10.0 * $sampleWeight)
  $strategicPriority = $edgeBonus + $priorityBonus + $businessBonus + [Math]::Max(0, 20 - [int]$Owner.order)
  $score = $dataScore
  $keywords = @([string]$Owner.primaryKeyword) + @($Owner.variants)
  $queryEvidence = @()
  foreach ($queryMetric in @($QueryMetric7d, $QueryMetric28d)) {
    if ($queryMetric) {
      $queryEvidence += "$($queryMetric.window) query $($queryMetric.term) impr=$($queryMetric.row.impressions), pos=$(Format-Decimal -Value $queryMetric.row.position), CTR=$(Format-Ctr -Value $queryMetric.row.ctr)"
    }
  }
  if ($queryEvidence.Count -eq 0) { $queryEvidence += '無 exact owner query match' }
  $pageEvidence = "7d page clicks=$clicks7d, impr=$impressions7d, pos=$(Format-Decimal -Value $position7d), CTR=$(Format-Ctr -Value $ctr7d)；28d page clicks=$clicks28d, impr=$impressions28d, pos=$(Format-Decimal -Value $position28d), CTR=$(Format-Ctr -Value $ctr28d)"

  $actionType = Get-ActionType -Position $position -Ctr $ctr -Impressions $impressions -Mode 'monthly' -Benchmark $Benchmark -PageType ([string]$Owner.pageType)
  $fixedActions = if ($EligibilityKind -eq 'performance') {
    "以既有 owner keyword 為限，優先優化 title/meta description 的價格、材質與 CTA 表達；首屏短答案須直接對齊搜尋意圖；檢查 2-3 個內鏈錨文字是否將泛用詞導回正確 owner；不要為了補字數重做已合規的 FAQ/Schema，也不要搶其他 owner 詞。"
  } elseif ($EligibilityKind -eq 'alignment') {
    "先審核 Query × Page 競爭頁與搜尋意圖，只在核准後調整內鏈錨文字、canonical intent 或 owner 頁首屏；不得新增 owner、改綁主攻詞或讓競爭頁搶同一 exact cluster。"
  } else {
    Get-PageTask -Page $page -Keywords $keywords
  }
  $gapText = (@($Compliance.missing) | Sort-Object) -join ','
  $keywordFingerprintText = (@($keywords | ForEach-Object { ([string]$_).Trim() } | Where-Object { $_ } | Sort-Object -Unique)) -join '|'
  $fingerprint = Get-Sha256Text -Text (@(
    'seo-geo-action-v3',
    [string]$Owner.clusterId,
    $page,
    $keywordFingerprintText,
    $gapText,
    $fixedActions,
    "${EligibilityKind}_opportunity"
  ) -join "`n")
  $safeCluster = ([string]$Owner.clusterId) -replace '[^A-Za-z0-9_-]', '-'
  $requiredValidations = @(
    'node .agents/skills/curtain-online-seo-geo/scripts/keyword-owner-check.mjs',
    'npm.cmd run build',
    'npm.cmd run seo:check',
    'npm.cmd run seo:preflight'
  )
  return [PSCustomObject]@{
    action_id          = "seo-$safeCluster-$($fingerprint.Substring(0, 12))"
    fingerprint        = $fingerprint
    priority           = $Priority
    clusterId          = [string]$Owner.clusterId
    page               = $page
    ownerKeywords      = ($keywords -join ' / ')
    intentType         = (Get-IntentType -Page $page -ActionType $actionType)
    '7d clicks'        = $clicks7d
    '7d impressions'   = $impressions7d
    '7d CTR'           = (Format-Ctr -Value $ctr7d)
    '7d position'      = (Format-Decimal -Value $position7d)
    '28d clicks'       = $clicks28d
    '28d impressions'  = $impressions28d
    '28d CTR'          = (Format-Ctr -Value $ctr28d)
    '28d position'     = (Format-Decimal -Value $position28d)
    actionType         = $actionType
    eligibility_kind   = $EligibilityKind
    score              = (Format-Decimal -Value $score)
    data_score         = (Format-Decimal -Value $dataScore)
    strategic_priority = (Format-Decimal -Value $strategicPriority)
    reason             = "$pageEvidence；$($queryEvidence -join '；')；benchmark=$(if ($targetCtr.available) { "$($targetCtr.position_band)/$(Format-Ctr -Value $targetCtr.target_ctr)" } else { $targetCtr.reason })；eligibility=$EligibilityKind；$EligibilityReason；source gaps=$gapText"
    fixedActions       = $fixedActions
    required_validations = $requiredValidations
    validationCommands = ($requiredValidations -join "`n")
  }
}

function Convert-ActionsToMarkdownTable {
  param([object[]]$Rows)
  $headers = @('priority', 'action_id', 'page', 'ownerKeywords', 'intentType', '7d impressions', '7d CTR', '7d position', '28d impressions', '28d CTR', '28d position', 'actionType', 'data_score', 'strategic_priority', 'reason', 'fixedActions', 'validationCommands')
  $lines = @()
  $lines += '| ' + (($headers | ForEach-Object { Escape-MdCell -Value $_ }) -join ' | ') + ' |'
  $lines += '| ---: | --- | --- | --- | ---: | ---: | ---: | ---: | --- | --- | --- | --- |'
  foreach ($row in $Rows) {
    $cells = foreach ($h in $headers) { Escape-MdCell -Value $row.$h }
    $lines += '| ' + ($cells -join ' | ') + ' |'
  }
  return ($lines -join "`n")
}

function Convert-ActionsToHtmlTable {
  param([object[]]$Rows)
  $headers = @('priority', 'action_id', 'page', 'ownerKeywords', 'intentType', '7d impressions', '7d CTR', '7d position', '28d impressions', '28d CTR', '28d position', 'actionType', 'data_score', 'strategic_priority', 'reason', 'fixedActions', 'validationCommands')
  $html = @('<table><thead><tr>')
  foreach ($h in $headers) { $html += '<th>' + (Escape-Html -Value $h) + '</th>' }
  $html += '</tr></thead><tbody>'
  foreach ($row in $Rows) {
    $html += '<tr>'
    foreach ($h in $headers) {
      $html += '<td>' + (Escape-Html -Value ([string]$row.$h)) + '</td>'
    }
    $html += '</tr>'
  }
  $html += '</tbody></table>'
  return ($html -join '')
}

function Convert-ListToHtml {
  param([string[]]$Items)
  return '<ul>' + (($Items | ForEach-Object { '<li>' + (Escape-Html -Value $_) + '</li>' }) -join '') + '</ul>'
}

function Get-RequiredSourceForPage {
  param([string]$Page)

  $sources = @()
  if ($Page -eq 'https://online.hong-sen.com/' -or $Page -eq 'https://online.hong-sen.com') {
    $sources += 'src/app/page.tsx'
    $sources += 'src/lib/seo.ts'
  } elseif ($Page -like '*/calculator/*') {
    $sources += 'src/app/calculator/page.tsx'
    $sources += 'src/app/calculator/CalculatorClient.tsx'
    $sources += 'src/lib/seo.ts'
  } elseif ($Page -like '*/products/' -or $Page -like '*/products') {
    $sources += 'src/app/products/page.tsx'
    $sources += 'src/data/products.ts'
    $sources += 'src/lib/seo.ts'
  } elseif ($Page -like '*/products/*') {
    $sources += 'src/data/products.ts'
    $sources += 'src/app/products/[slug]/page.tsx'
    $sources += 'src/lib/seo.ts'
  } elseif ($Page -like '*/location/*') {
    $sources += 'src/data/locationPages.ts'
    $sources += 'src/app/location/[area]/page.tsx'
    $sources += 'src/lib/seo.ts'
  } elseif ($Page -like '*/blog/*') {
    $sources += 'src/data/knowledgePosts.ts'
    $sources += 'src/app/blog/[id]/page.tsx'
    $sources += 'src/lib/seo.ts'
  } elseif ($Page -like '*/about/*' -or $Page -like '*/about') {
    $sources += 'src/app/about/page.tsx'
    $sources += 'src/lib/seo.ts'
  } elseif ($Page -like '*/cases/*' -or $Page -like '*/cases') {
    $sources += 'src/app/cases/layout.tsx'
    $sources += 'src/app/cases/page.tsx'
    $sources += 'src/lib/seo.ts'
  } else {
    $sources += 'src/app'
    $sources += 'src/lib/seo.ts'
  }

  return @($sources | Select-Object -Unique)
}

function Test-TextContains {
  param([string]$Text, [string]$Value)
  if ([string]::IsNullOrWhiteSpace($Text) -or [string]::IsNullOrWhiteSpace($Value)) { return $false }
  return $Text.IndexOf($Value, [System.StringComparison]::OrdinalIgnoreCase) -ge 0
}

function Get-OutputHtmlIndex {
  param([string]$RepoRoot)
  $outRoot = Join-Path $RepoRoot 'out'
  $documents = @()
  if (Test-Path -LiteralPath $outRoot -PathType Container) {
    foreach ($file in @(Get-ChildItem -LiteralPath $outRoot -Recurse -Filter 'index.html' -File)) {
      $documents += [PSCustomObject]@{
        path = $file.FullName
        relative_path = Get-RelativePortablePath -BasePath $RepoRoot -Path $file.FullName
        last_write_utc = $file.LastWriteTimeUtc
        html = Read-Utf8Text -Path $file.FullName
      }
    }
  }
  return [PSCustomObject]@{ out_root = $outRoot; documents = $documents }
}

function Get-HtmlTagAttribute {
  param([string]$Tag, [string]$Name)
  $match = [regex]::Match($Tag, ('\b' + [regex]::Escape($Name) + '\s*=\s*["'']([^"'']*)["'']'), [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
  $value = if ($match.Success) { [System.Net.WebUtility]::HtmlDecode($match.Groups[1].Value) } else { '' }
  return $value
}

function Convert-HtmlToVisibleText {
  param([string]$Html)
  $value = [regex]::Replace($Html, '<script\b[^>]*>[\s\S]*?</script>', ' ', [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
  $value = [regex]::Replace($value, '<style\b[^>]*>[\s\S]*?</style>', ' ', [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
  $value = [regex]::Replace($value, '<[^>]+>', ' ')
  $value = [System.Net.WebUtility]::HtmlDecode($value)
  return [regex]::Replace($value, '\s+', ' ').Trim()
}

function Get-OwnerOutputCompliance {
  param(
    [object]$Owner,
    [string]$RepoRoot,
    [object]$OutputIndex
  )
  $relativePaths = @(Get-RequiredSourceForPage -Page $Owner.ownerPage)
  $missingFiles = @()
  $latestSourceWrite = [datetime]::MinValue
  foreach ($relativePath in $relativePaths) {
    $fullPath = Join-Path $RepoRoot ($relativePath.Replace('/', '\'))
    if (Test-Path -LiteralPath $fullPath -PathType Leaf) {
      $write = (Get-Item -LiteralPath $fullPath).LastWriteTimeUtc
      if ($write -gt $latestSourceWrite) { $latestSourceWrite = $write }
    } else {
      $missingFiles += $relativePath
    }
  }

  $ownerUri = [System.Uri]$Owner.ownerPage
  $route = $ownerUri.AbsolutePath
  $relativeOutput = if ($route -eq '/') { 'out/index.html' } else { 'out/' + $route.Trim('/').Replace('\', '/').Replace('/', '/') + '/index.html' }
  $outputPath = Join-Path $RepoRoot ($relativeOutput.Replace('/', '\'))
  $document = @($OutputIndex.documents | Where-Object { $_.path -eq $outputPath } | Select-Object -First 1)[0]
  $html = if ($document) { [string]$document.html } else { '' }
  $visibleText = if ($html) { Convert-HtmlToVisibleText -Html $html } else { '' }

  $titleMatch = [regex]::Match($html, '<title\b[^>]*>([\s\S]*?)</title>', [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
  $title = if ($titleMatch.Success) { [System.Net.WebUtility]::HtmlDecode($titleMatch.Groups[1].Value).Trim() } else { '' }
  $description = ''
  foreach ($tagMatch in [regex]::Matches($html, '<meta\b[^>]*>', [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)) {
    if ((Get-HtmlTagAttribute -Tag $tagMatch.Value -Name 'name') -eq 'description') { $description = Get-HtmlTagAttribute -Tag $tagMatch.Value -Name 'content'; break }
  }
  $canonical = ''
  foreach ($tagMatch in [regex]::Matches($html, '<link\b[^>]*>', [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)) {
    if ((Get-HtmlTagAttribute -Tag $tagMatch.Value -Name 'rel') -eq 'canonical') { $canonical = Get-HtmlTagAttribute -Tag $tagMatch.Value -Name 'href'; break }
  }
  $h1Matches = [regex]::Matches($html, '<h1\b[^>]*>([\s\S]*?)</h1>', [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
  $h1Text = if ($h1Matches.Count -eq 1) { Convert-HtmlToVisibleText -Html $h1Matches[0].Groups[1].Value } else { '' }

  $jsonLdParseable = $true
  $schemaOwnerBound = $false
  $faqQuestions = @()
  $faqAnswers = @()
  $jsonLdCount = 0
  foreach ($script in [regex]::Matches($html, '<script\b[^>]*type=["'']application/ld\+json["''][^>]*>([\s\S]*?)</script>', [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)) {
    $jsonLdCount++
    try {
      $json = [System.Net.WebUtility]::HtmlDecode($script.Groups[1].Value) | ConvertFrom-Json
      $serialized = $json | ConvertTo-Json -Depth 100 -Compress
      if (Test-TextContains -Text $serialized -Value ([string]$Owner.ownerPage)) { $schemaOwnerBound = $true }
      $nodes = @($json)
      if ($json.PSObject.Properties.Name -contains '@graph') { $nodes += @($json.'@graph') }
      foreach ($node in $nodes) {
        if ([string]$node.'@type' -eq 'FAQPage') {
          foreach ($entity in @($node.mainEntity)) {
            if ($entity.name) { $faqQuestions += [string]$entity.name }
            if ($entity.acceptedAnswer -and $entity.acceptedAnswer.text) { $faqAnswers += [string]$entity.acceptedAnswer.text }
          }
        }
      }
    } catch {
      $jsonLdParseable = $false
    }
  }
  $faqParity = ($faqQuestions.Count -ge 3 -and $faqQuestions.Count -le 5 -and $faqQuestions.Count -eq $faqAnswers.Count)
  if ($faqParity) {
    foreach ($text in @($faqQuestions + $faqAnswers)) {
      if (-not (Test-TextContains -Text $visibleText -Value $text)) { $faqParity = $false; break }
    }
  }

  $calculatorCta = [regex]::IsMatch($html, 'href\s*=\s*["''](?:https://online\.hong-sen\.com)?/calculator(?:/|\?|["''])', [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
  $aiAnswerMatch = [regex]::Match($html, '<[^>]+data-ai-answer=["'']true["''][^>]*>([\s\S]*?)</[^>]+>', [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
  $aiAnswer = $aiAnswerMatch.Success -and -not [string]::IsNullOrWhiteSpace((Convert-HtmlToVisibleText -Html $aiAnswerMatch.Groups[1].Value))
  $routePattern = 'href\s*=\s*["''](?:https://online\.hong-sen\.com)?' + [regex]::Escape($route) + '(?:[?#][^"'']*)?["'']'
  $incoming = @($OutputIndex.documents | Where-Object { $_.path -ne $outputPath -and [regex]::IsMatch([string]$_.html, $routePattern, [System.Text.RegularExpressions.RegexOptions]::IgnoreCase) } | Select-Object -ExpandProperty relative_path)
  $outputFresh = ($document -and $missingFiles.Count -eq 0 -and $document.last_write_utc -ge $latestSourceWrite)

  $checks = [ordered]@{
    output_file = [bool]$document
    output_fresh = [bool]$outputFresh
    title = ((Test-TextContains -Text $title -Value ([string]$Owner.primaryKeyword)))
    meta_description = (-not [string]::IsNullOrWhiteSpace($description))
    h1 = ($h1Matches.Count -eq 1 -and (Test-TextContains -Text $h1Text -Value ([string]$Owner.primaryKeyword)))
    canonical = ($canonical -eq [string]$Owner.ownerPage)
    json_ld = ($jsonLdCount -gt 0 -and $jsonLdParseable -and $schemaOwnerBound)
    faq_parity = $faqParity
    calculator_cta = $calculatorCta
    ai_answer = $aiAnswer
    inbound_links = ($incoming.Count -gt 0)
  }
  $missing = @($checks.Keys | Where-Object { -not [bool]($checks[$_]) })
  $evidence = [ordered]@{
    output_file = @($relativeOutput)
    output_fresh = @("output=$($document.last_write_utc); latest_source=$latestSourceWrite")
    title = @($title)
    meta_description = @($description)
    h1 = @($h1Text)
    canonical = @($canonical)
    json_ld = @("scripts=$jsonLdCount; parseable=$jsonLdParseable; owner_bound=$schemaOwnerBound")
    faq_parity = @("questions=$($faqQuestions.Count); answers=$($faqAnswers.Count)")
    calculator_cta = @($relativeOutput)
    ai_answer = @($relativeOutput)
    inbound_links = @($incoming | Select-Object -First 20)
  }
  return [PSCustomObject]@{
    compliant = ($missing.Count -eq 0)
    checks = [PSCustomObject]$checks
    missing = $missing
    requiredSource = $relativePaths
    missingSource = $missingFiles
    outputPath = $relativeOutput
    evidence = [PSCustomObject]$evidence
  }
}

function New-ComplianceReportRow {
  param([object]$Owner, [object]$Compliance)
  $checkNames = @($Compliance.checks.PSObject.Properties.Name)
  $passed = @($checkNames | Where-Object { [bool]$Compliance.checks.$_ })
  return [PSCustomObject]@{
    cluster_id = [string]$Owner.clusterId
    page = [string]$Owner.ownerPage
    output_path = [string]$Compliance.outputPath
    compliant = [bool]$Compliance.compliant
    passed_checks = "$($passed.Count)/$($checkNames.Count)"
    missing_checks = (@($Compliance.missing) -join ', ')
    missing_source_files = (@($Compliance.missingSource) -join ', ')
    required_source = (@($Compliance.requiredSource) -join ', ')
    check_details = (($checkNames | ForEach-Object {
      $evidence = @($Compliance.evidence.$_)
      "$_=" + $(if ($Compliance.checks.$_) { 'pass' } else { 'fail' }) + $(if ($evidence.Count) { " [$($evidence -join '; ')]" } else { '' })
    }) -join ' | ')
  }
}

function Get-CooldownStatus {
  param(
    [string]$LastChangedAt,
    [datetime]$Now = (Get-Date),
    [int]$Days = 28
  )
  if ([string]::IsNullOrWhiteSpace($LastChangedAt)) {
    return [PSCustomObject]@{ active = $false; last_changed_at = $null; cooldown_until = $null; days_remaining = 0 }
  }
  $changed = [datetime]::MinValue
  if (-not [datetime]::TryParse($LastChangedAt, [ref]$changed)) {
    return [PSCustomObject]@{ active = $true; last_changed_at = $LastChangedAt; cooldown_until = $null; days_remaining = $Days; invalid = $true }
  }
  $until = $changed.Date.AddDays($Days)
  $active = $Now.Date -lt $until
  $remaining = if ($active) { [Math]::Max(1, [int][Math]::Ceiling(($until - $Now.Date).TotalDays)) } else { 0 }
  return [PSCustomObject]@{
    active = $active
    last_changed_at = $changed.ToString('yyyy-MM-dd')
    cooldown_until = $until.ToString('yyyy-MM-dd')
    days_remaining = $remaining
  }
}

function Get-ActionHistoryEntries {
  param([string]$Path)
  if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { return @() }
  $document = Read-JsonIfExists -Path $Path
  if ($null -eq $document) { return @() }
  if ($document -is [System.Array]) { return @($document) }
  foreach ($propertyName in @('entries', 'actions', 'history')) {
    if ($document.PSObject.Properties.Name -contains $propertyName) {
      return @($document.$propertyName)
    }
  }
  if ($document.PSObject.Properties.Name -contains 'fingerprint' -or
      $document.PSObject.Properties.Name -contains 'action_fingerprint' -or
      $document.PSObject.Properties.Name -contains 'action_fingerprints') {
    return @($document)
  }
  return @()
}

function Get-ActionHistoryCooldown {
  param(
    [object[]]$Entries,
    [string]$Fingerprint,
    [datetime]$Now = (Get-Date),
    [int]$Days = 28
  )
  $matches = @()
  foreach ($entry in @($Entries)) {
    if (-not $entry) { continue }
    $fingerprints = @()
    foreach ($propertyName in @('fingerprint', 'action_fingerprint', 'action_fingerprints')) {
      if ($entry.PSObject.Properties.Name -contains $propertyName) {
        $fingerprints += @($entry.$propertyName)
      }
    }
    $fingerprints = @($fingerprints | ForEach-Object { ([string]$_).Trim().ToLowerInvariant() } | Where-Object { $_ } | Select-Object -Unique)
    if ($fingerprints -notcontains $Fingerprint.ToLowerInvariant()) { continue }

    $status = if ($entry.PSObject.Properties.Name -contains 'status') { ([string]$entry.status).Trim().ToLowerInvariant() } else { '' }
    if ($status -in @('failed', 'cancelled', 'canceled', 'rejected')) { continue }

    $timestampText = ''
    foreach ($propertyName in @('completed_at', 'validated_at', 'deployed_at', 'changed_at', 'created_at', 'generated_at', 'timestamp')) {
      if ($entry.PSObject.Properties.Name -contains $propertyName -and -not [string]::IsNullOrWhiteSpace([string]$entry.$propertyName)) {
        $timestampText = [string]$entry.$propertyName
        break
      }
    }
    if ([string]::IsNullOrWhiteSpace($timestampText)) { continue }
    $timestamp = [datetime]::MinValue
    if (-not [datetime]::TryParse($timestampText, [ref]$timestamp)) { continue }
    $until = $timestamp.Date.AddDays($Days)
    if ($Now.Date -lt $until) {
      $matches += [PSCustomObject]@{
        timestamp = $timestamp
        completed_at = $timestamp.ToString('yyyy-MM-dd')
        cooldown_until = $until.ToString('yyyy-MM-dd')
        days_remaining = [Math]::Max(1, [int][Math]::Ceiling(($until - $Now.Date).TotalDays))
        queue_id = if ($entry.PSObject.Properties.Name -contains 'queue_id') { [string]$entry.queue_id } else { $null }
        action_id = if ($entry.PSObject.Properties.Name -contains 'action_id') { [string]$entry.action_id } else { $null }
      }
    }
  }
  if ($matches.Count -eq 0) {
    return [PSCustomObject]@{ active = $false; completed_at = $null; cooldown_until = $null; days_remaining = 0; queue_id = $null; action_id = $null }
  }
  $latest = @($matches | Sort-Object timestamp -Descending | Select-Object -First 1)[0]
  return [PSCustomObject]@{
    active = $true
    completed_at = $latest.completed_at
    cooldown_until = $latest.cooldown_until
    days_remaining = $latest.days_remaining
    queue_id = $latest.queue_id
    action_id = $latest.action_id
  }
}

function Get-LifecycleReviewDates {
  param([string]$WeeklyRoot)
  $map = @{}
  $path = Join-Path $WeeklyRoot 'latest\seo-geo-lifecycle-receipt.json'
  if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { return $map }
  try { $receipt = Read-JsonIfExists -Path $path } catch { return $map }
  if (-not $receipt) { return $map }
  $deployed = @($receipt.stages | Where-Object { $_.stage -eq 'deployed' } | Select-Object -Last 1)[0]
  $live = @($receipt.stages | Where-Object { $_.stage -eq 'live_verified' } | Select-Object -Last 1)[0]
  foreach ($page in @($receipt.target_pages)) {
    $map[[string]$page] = [PSCustomObject]@{
      deployed_at = if ($deployed) { [string]$deployed.recorded_at } else { $null }
      live_verified_at = if ($live) { [string]$live.recorded_at } else { $null }
      queue_id = [string]$receipt.queue_id
    }
  }
  return $map
}

function Get-NonOverlappingReviewWindows {
  param(
    [object[]]$Owners,
    [string]$LatestFinalizedDate,
    [hashtable]$LifecycleDates = @{},
    [object[]]$DateRows = @(),
    [object[]]$DatePageRows = @()
  )

  $latest = [datetime]::MinValue
  [void][datetime]::TryParseExact($LatestFinalizedDate, 'yyyy-MM-dd', [Globalization.CultureInfo]::InvariantCulture, [Globalization.DateTimeStyles]::None, [ref]$latest)
  $availableDates = @($DateRows | ForEach-Object { [string]$_.date } | Where-Object { $_ -match '^\d{4}-\d{2}-\d{2}$' } | Sort-Object -Unique)
  $windows = @()
  foreach ($owner in @($Owners)) {
    $changed = [datetime]::MinValue
    $dateSource = 'registry.lastChangedAt (source change date; not a deployment timestamp)'
    $lifecycle = if ($LifecycleDates.ContainsKey([string]$owner.ownerPage)) { $LifecycleDates[[string]$owner.ownerPage] } else { $null }
    if ($lifecycle -and -not [string]::IsNullOrWhiteSpace([string]$lifecycle.live_verified_at) -and [datetime]::TryParse([string]$lifecycle.live_verified_at, [ref]$changed)) {
      $dateSource = "lifecycle.live_verified_at ($($lifecycle.queue_id))"
    } elseif ($lifecycle -and -not [string]::IsNullOrWhiteSpace([string]$lifecycle.deployed_at) -and [datetime]::TryParse([string]$lifecycle.deployed_at, [ref]$changed)) {
      $dateSource = "lifecycle.deployed_at ($($lifecycle.queue_id))"
    } elseif (-not [datetime]::TryParseExact([string]$owner.lastChangedAt, 'yyyy-MM-dd', [Globalization.CultureInfo]::InvariantCulture, [Globalization.DateTimeStyles]::None, [ref]$changed)) { continue }
    $changed = $changed.Date
    $post7End = $changed.AddDays(7)
    $post28End = $changed.AddDays(28)
    $pre28Start=$changed.AddDays(-28).ToString('yyyy-MM-dd');$pre28End=$changed.AddDays(-1).ToString('yyyy-MM-dd')
    $pre7Start=$changed.AddDays(-7).ToString('yyyy-MM-dd');$pre7End=$changed.AddDays(-1).ToString('yyyy-MM-dd')
    $post7Start=$changed.AddDays(1).ToString('yyyy-MM-dd');$post7EndText=$post7End.ToString('yyyy-MM-dd')
    $post28Start=$changed.AddDays(1).ToString('yyyy-MM-dd');$post28EndText=$post28End.ToString('yyyy-MM-dd')
    $pre28Result=Get-PeriodDiagnosticResult -Rows $DatePageRows -AvailableDates $availableDates -StartDate $pre28Start -EndDate $pre28End -Page ([string]$owner.ownerPage)
    $pre7Result=Get-PeriodDiagnosticResult -Rows $DatePageRows -AvailableDates $availableDates -StartDate $pre7Start -EndDate $pre7End -Page ([string]$owner.ownerPage)
    $post7Result=Get-PeriodDiagnosticResult -Rows $DatePageRows -AvailableDates $availableDates -StartDate $post7Start -EndDate $post7EndText -Page ([string]$owner.ownerPage)
    $post28Result=Get-PeriodDiagnosticResult -Rows $DatePageRows -AvailableDates $availableDates -StartDate $post28Start -EndDate $post28EndText -Page ([string]$owner.ownerPage)
    $windows += [PSCustomObject]@{
      cluster_id = [string]$owner.clusterId
      page = [string]$owner.ownerPage
      change_date = $changed.ToString('yyyy-MM-dd')
      date_source = $dateSource
      pre_change_28d = "$pre28Start~$pre28End"
      pre_change_28d_result = $pre28Result
      pre_change_28d_metrics = Format-DiagnosticResult -Result $pre28Result
      pre_7d = "$pre7Start~$pre7End"
      pre_7d_result = $pre7Result
      pre_7d_metrics = Format-DiagnosticResult -Result $pre7Result
      post_7d = "$post7Start~$post7EndText"
      post_7d_result = $post7Result
      post_7d_metrics = Format-DiagnosticResult -Result $post7Result
      post_28d = "$post28Start~$post28EndText"
      post_28d_result = $post28Result
      post_28d_metrics = Format-DiagnosticResult -Result $post28Result
      review_7d_status = if ($latest -lt $post7End) { 'awaiting_complete_post_window' } elseif (-not $post7Result.available -or -not $pre7Result.available) { 'data_unavailable' } else { 'eligible' }
      review_28d_status = if ($latest -lt $post28End) { 'awaiting_complete_post_window' } elseif (-not $post28Result.available -or -not $pre28Result.available) { 'data_unavailable' } else { 'eligible' }
      latest_finalized_date = if ($latest -eq [datetime]::MinValue) { $null } else { $latest.ToString('yyyy-MM-dd') }
    }
  }
  return @($windows | Sort-Object change_date, cluster_id)
}

function Get-SourceProvenance {
  param(
    [object[]]$Owners,
    [string]$RepoRoot
  )
  $paths = @()
  $ownerBindings = @()
  foreach ($owner in $Owners) {
    $ownerPaths = @(Get-RequiredSourceForPage -Page $owner.ownerPage)
    $paths += $ownerPaths
    $ownerBindings += [PSCustomObject]@{
      cluster_id = [string]$owner.clusterId
      owner_url = [string]$owner.ownerPage
      source_files = @($ownerPaths | Sort-Object -Unique)
    }
  }
  $parts = @()
  $files = @()
  foreach ($relativePath in @($paths | Select-Object -Unique | Sort-Object)) {
    $fullPath = Join-Path $RepoRoot ($relativePath.Replace('/', '\'))
    $hash = Get-Sha256File -Path $fullPath
    $hashMaterial = if ([string]::IsNullOrWhiteSpace($hash)) { 'missing' } else { $hash }
    $files += [PSCustomObject]@{ path = $relativePath.Replace('\', '/'); sha256 = $hash }
    $parts += "$relativePath=$hashMaterial"
  }
  return [PSCustomObject]@{
    source_files = $files
    owners = $ownerBindings
    source_fingerprint = Get-Sha256Text -Text ($parts -join "`n")
  }
}

function New-ObservationRow {
  param(
    [object]$Owner,
    [object]$PageMetric7d,
    [object]$PageMetric28d,
    [object]$QueryMetric7d,
    [object]$QueryMetric28d,
    [object]$Compliance,
    [object]$RegistryCooldown,
    [object]$ActionHistoryCooldown,
    [object]$QueryPageAnalysis7d,
    [object]$QueryPageAnalysis28d,
    [string]$ActionFingerprint,
    [string]$Disposition,
    [string]$Reason
  )
  $p7 = if ($PageMetric7d) { $PageMetric7d } else { [PSCustomObject]@{ clicks = 0; impressions = 0; ctr = 0.0; position = 0.0 } }
  $p28 = if ($PageMetric28d) { $PageMetric28d } else { [PSCustomObject]@{ clicks = 0; impressions = 0; ctr = 0.0; position = 0.0 } }
  $q7 = if ($QueryMetric7d) { $QueryMetric7d.row } else { [PSCustomObject]@{ clicks = 0; impressions = 0; ctr = 0.0; position = 0.0 } }
  $q28 = if ($QueryMetric28d) { $QueryMetric28d.row } else { [PSCustomObject]@{ clicks = 0; impressions = 0; ctr = 0.0; position = 0.0 } }
  return [PSCustomObject]@{
    order = [int]$Owner.order
    cluster_id = [string]$Owner.clusterId
    page = [string]$Owner.ownerPage
    primary_keyword = [string]$Owner.primaryKeyword
    variants = (@($Owner.variants) -join ' / ')
    '7d clicks' = [int]$p7.clicks
    '7d impressions' = [int]$p7.impressions
    '7d CTR' = (Format-Ctr -Value ([double]$p7.ctr))
    '7d position' = (Format-Decimal -Value ([double]$p7.position))
    '7d query' = if ($QueryMetric7d) { [string]$QueryMetric7d.term } else { '' }
    '7d query clicks' = [int]$q7.clicks
    '7d query impressions' = [int]$q7.impressions
    '7d query CTR' = (Format-Ctr -Value ([double]$q7.ctr))
    '7d query position' = (Format-Decimal -Value ([double]$q7.position))
    '28d clicks' = [int]$p28.clicks
    '28d impressions' = [int]$p28.impressions
    '28d CTR' = (Format-Ctr -Value ([double]$p28.ctr))
    '28d position' = (Format-Decimal -Value ([double]$p28.position))
    '28d query' = if ($QueryMetric28d) { [string]$QueryMetric28d.term } else { '' }
    '28d query clicks' = [int]$q28.clicks
    '28d query impressions' = [int]$q28.impressions
    '28d query CTR' = (Format-Ctr -Value ([double]$q28.ctr))
    '28d query position' = (Format-Decimal -Value ([double]$q28.position))
    '7d owner share' = if ($QueryPageAnalysis7d.available) { ((Format-Decimal -Value ([double]$QueryPageAnalysis7d.owner_share)) + '%') } else { 'n/a' }
    '28d owner share' = if ($QueryPageAnalysis28d.available) { ((Format-Decimal -Value ([double]$QueryPageAnalysis28d.owner_share)) + '%') } else { 'n/a' }
    '28d owner impressions' = [int]$QueryPageAnalysis28d.owner_impressions
    '28d cluster impressions' = [int]$QueryPageAnalysis28d.total_impressions
    '28d competing pages' = (@($QueryPageAnalysis28d.competing_pages | ForEach-Object { "$($_.page) ($($_.share)%)" }) -join ' / ')
    cannibalization = [bool]$QueryPageAnalysis28d.cannibalization
    output_compliant = [bool]$Compliance.compliant
    compliance_missing = (@($Compliance.missing) -join ', ')
    action_fingerprint = $ActionFingerprint
    registry_last_changed_at = $RegistryCooldown.last_changed_at
    registry_cooldown_until = $RegistryCooldown.cooldown_until
    action_history_completed_at = $ActionHistoryCooldown.completed_at
    action_history_cooldown_until = $ActionHistoryCooldown.cooldown_until
    cooldown_source = if ($RegistryCooldown.active) { 'registry_lastChangedAt' } elseif ($ActionHistoryCooldown.active) { 'action_history' } else { '' }
    cooldown_until = if ($RegistryCooldown.active) { $RegistryCooldown.cooldown_until } elseif ($ActionHistoryCooldown.active) { $ActionHistoryCooldown.cooldown_until } else { $null }
    disposition = $Disposition
    reason = $Reason
  }
}

function New-MonitoringAssetRow {
  param(
    [object]$Asset,
    [object]$PageMetric7d,
    [object]$PageMetric28d
  )
  $p7 = if ($PageMetric7d) { $PageMetric7d } else { [PSCustomObject]@{ clicks = 0; impressions = 0; ctr = 0.0; position = 0.0 } }
  $p28 = if ($PageMetric28d) { $PageMetric28d } else { [PSCustomObject]@{ clicks = 0; impressions = 0; ctr = 0.0; position = 0.0 } }
  return [PSCustomObject]@{
    order = [int]$Asset.order
    asset_id = [string]$Asset.id
    type = [string]$Asset.type
    page = [string]$Asset.page
    label = [string]$Asset.label
    monitoring_terms = (@($Asset.monitoringTerms) -join ' / ')
    '7d clicks' = [int]$p7.clicks
    '7d impressions' = [int]$p7.impressions
    '7d CTR' = (Format-Ctr -Value ([double]$p7.ctr))
    '7d position' = (Format-Decimal -Value ([double]$p7.position))
    '28d clicks' = [int]$p28.clicks
    '28d impressions' = [int]$p28.impressions
    '28d CTR' = (Format-Ctr -Value ([double]$p28.ctr))
    '28d position' = (Format-Decimal -Value ([double]$p28.position))
    disposition = 'monitor_only_asset'
    reason = '監控資產；不屬於 keyword owner，不建立自動優化 Round。'
  }
}

function Convert-MonitoringAssetsToMarkdownTable {
  param([object[]]$Rows)
  $headers = @('order', 'asset_id', 'type', 'page', 'label', 'monitoring_terms', '7d clicks', '7d impressions', '7d CTR', '7d position', '28d clicks', '28d impressions', '28d CTR', '28d position', 'disposition', 'reason')
  $lines = @('| ' + ($headers -join ' | ') + ' |', '| ---: | --- | --- | --- | --- | --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | --- | --- |')
  foreach ($row in $Rows) {
    $lines += '| ' + (($headers | ForEach-Object { Escape-MdCell -Value ([string]$row.$_) }) -join ' | ') + ' |'
  }
  return ($lines -join "`n")
}

function Convert-MonitoringAssetsToHtmlTable {
  param([object[]]$Rows)
  $headers = @('order', 'asset_id', 'type', 'page', 'label', 'monitoring_terms', '7d clicks', '7d impressions', '7d CTR', '7d position', '28d clicks', '28d impressions', '28d CTR', '28d position', 'disposition', 'reason')
  $html = @('<table><thead><tr>')
  foreach ($header in $headers) { $html += '<th>' + (Escape-Html -Value $header) + '</th>' }
  $html += '</tr></thead><tbody>'
  foreach ($row in $Rows) {
    $html += '<tr>'
    foreach ($header in $headers) { $html += '<td>' + (Escape-Html -Value ([string]$row.$header)) + '</td>' }
    $html += '</tr>'
  }
  $html += '</tbody></table>'
  return ($html -join '')
}

function Convert-ObjectRowsToMarkdownTable {
  param([object[]]$Rows, [string[]]$Headers)
  if (@($Rows).Count -eq 0) { return '- data unavailable / no matching anomalies。' }
  $lines=@('| '+($Headers -join ' | ')+' |','| '+(($Headers|ForEach-Object{'---'}) -join ' | ')+' |')
  foreach($row in $Rows){$lines += '| '+(($Headers|ForEach-Object{Escape-MdCell -Value ([string]$row.$_)}) -join ' | ')+' |'}
  return ($lines -join "`n")
}

function Convert-ObjectRowsToHtmlTable {
  param([object[]]$Rows, [string[]]$Headers)
  if (@($Rows).Count -eq 0) { return '<div class="note">data unavailable / no matching anomalies。</div>' }
  $html=@('<table><thead><tr>');foreach($header in $Headers){$html += '<th>'+(Escape-Html -Value $header)+'</th>'};$html += '</tr></thead><tbody>'
  foreach($row in $Rows){$html += '<tr>';foreach($header in $Headers){$html += '<td>'+(Escape-Html -Value ([string]$row.$header))+'</td>'};$html += '</tr>'};$html += '</tbody></table>';return ($html -join '')
}

function Get-DeviceDifferenceReportRows {
  param([object[]]$Rows)
  return @($Rows|ForEach-Object{[PSCustomObject]@{page=$_.page;total_impressions=$_.total_impressions;dominant_device=$_.dominant_device;position_gap=$_.position_gap;ctr_gap_pp=$_.ctr_gap_pp;anomaly=$_.anomaly;devices=(@($_.devices|ForEach-Object{"$($_.device): impr=$($_.impressions), share=$($_.share)%, CTR=$($_.ctr)%, pos=$($_.position)"}) -join ' / ')}})
}

function Get-CountryAnomalyReportRows {
  param([object[]]$Rows)
  return @($Rows|ForEach-Object{[PSCustomObject]@{page=$_.page;total_impressions=$_.total_impressions;reason=$_.reason;countries=(@($_.countries|ForEach-Object{"$($_.country): impr=$($_.impressions), share=$($_.share)%, CTR=$($_.ctr)%, pos=$($_.position)"}) -join ' / ')}})
}

function Get-AlignmentReportRows {
  param([object[]]$Rows)
  return @($Rows|ForEach-Object{[PSCustomObject]@{cluster_id=$_.cluster_id;page=$_.page;primary_keyword=$_.primary_keyword;owner_share=("$($_.owner_share)%");cluster_impressions=$_.cluster_impressions;cannibalization=$_.cannibalization;disposition=$_.disposition;cooldown_until=$_.cooldown_until;reason=$_.reason}})
}

function Convert-ReviewWindowsToMarkdownTable {
  param([object[]]$Rows)
  $headers = @('cluster_id', 'page', 'change_date', 'date_source', 'pre_change_28d', 'pre_change_28d_metrics', 'pre_7d', 'pre_7d_metrics', 'post_7d', 'post_7d_metrics', 'review_7d_status', 'post_28d', 'post_28d_metrics', 'review_28d_status', 'latest_finalized_date')
  $lines = @('| ' + ($headers -join ' | ') + ' |', '| ' + (($headers | ForEach-Object { '---' }) -join ' | ') + ' |')
  foreach ($row in $Rows) { $lines += '| ' + (($headers | ForEach-Object { Escape-MdCell -Value ([string]$row.$_) }) -join ' | ') + ' |' }
  return ($lines -join "`n")
}

function Convert-ReviewWindowsToHtmlTable {
  param([object[]]$Rows)
  $headers = @('cluster_id', 'page', 'change_date', 'date_source', 'pre_change_28d', 'pre_change_28d_metrics', 'pre_7d', 'pre_7d_metrics', 'post_7d', 'post_7d_metrics', 'review_7d_status', 'post_28d', 'post_28d_metrics', 'review_28d_status', 'latest_finalized_date')
  $html = @('<table><thead><tr>')
  foreach ($header in $headers) { $html += '<th>' + (Escape-Html -Value $header) + '</th>' }
  $html += '</tr></thead><tbody>'
  foreach ($row in $Rows) {
    $html += '<tr>'
    foreach ($header in $headers) { $html += '<td>' + (Escape-Html -Value ([string]$row.$header)) + '</td>' }
    $html += '</tr>'
  }
  $html += '</tbody></table>'
  return ($html -join '')
}

function Convert-ComplianceToMarkdownTable {
  param([object[]]$Rows)
  $headers = @('cluster_id', 'page', 'output_path', 'compliant', 'passed_checks', 'missing_checks', 'missing_source_files', 'required_source', 'check_details')
  $lines = @('| ' + ($headers -join ' | ') + ' |', '| --- | --- | --- | --- | --- | --- | --- | --- | --- |')
  foreach ($row in $Rows) { $lines += '| ' + (($headers | ForEach-Object { Escape-MdCell -Value ([string]$row.$_) }) -join ' | ') + ' |' }
  return ($lines -join "`n")
}

function Get-QueryDeltaRows {
  param([object]$Delta)
  $rows = @()
  foreach ($row in @($Delta.new_queries)) { $rows += [PSCustomObject]@{ change = 'new'; signal_class = 'confirmed_signal'; query = [string]$row.query; clicks = [int]$row.clicks; impressions = [int]$row.impressions; ctr = (Format-Ctr -Value ([double]$row.ctr)); position = (Format-Decimal -Value ([double]$row.position)) } }
  foreach ($row in @($Delta.lost_queries)) { $rows += [PSCustomObject]@{ change = 'lost'; signal_class = 'confirmed_signal'; query = [string]$row.query; clicks = [int]$row.clicks; impressions = [int]$row.impressions; ctr = (Format-Ctr -Value ([double]$row.ctr)); position = (Format-Decimal -Value ([double]$row.position)) } }
  foreach ($row in @($Delta.pending_queries)) { $rows += [PSCustomObject]@{ change = [string]$row.change; signal_class = [string]$row.signal_class; query = [string]$row.query; clicks = [int]$row.clicks; impressions = [int]$row.impressions; ctr = (Format-Ctr -Value ([double]$row.ctr)); position = (Format-Decimal -Value ([double]$row.position)) } }
  foreach ($row in @($Delta.noise_queries)) { $rows += [PSCustomObject]@{ change = [string]$row.change; signal_class = [string]$row.signal_class; query = [string]$row.query; clicks = [int]$row.clicks; impressions = [int]$row.impressions; ctr = (Format-Ctr -Value ([double]$row.ctr)); position = (Format-Decimal -Value ([double]$row.position)) } }
  return $rows
}

function Convert-QueryDeltaToMarkdownTable {
  param([object]$Delta)
  if (-not $Delta.available) { return '- comparison query baseline unavailable。' }
  $headers = @('change', 'signal_class', 'query', 'clicks', 'impressions', 'ctr', 'position')
  $lines = @('| ' + ($headers -join ' | ') + ' |', '| --- | --- | --- | ---: | ---: | ---: | ---: |')
  foreach ($row in @(Get-QueryDeltaRows -Delta $Delta)) { $lines += '| ' + (($headers | ForEach-Object { Escape-MdCell -Value ([string]$row.$_) }) -join ' | ') + ' |' }
  return ($lines -join "`n")
}

function Convert-QueryDeltaToHtmlTable {
  param([object]$Delta)
  if (-not $Delta.available) { return '<div class="note">comparison query baseline unavailable。</div>' }
  $headers = @('change', 'signal_class', 'query', 'clicks', 'impressions', 'ctr', 'position')
  $html = @('<table><thead><tr>')
  foreach ($header in $headers) { $html += '<th>' + (Escape-Html -Value $header) + '</th>' }
  $html += '</tr></thead><tbody>'
  foreach ($row in @(Get-QueryDeltaRows -Delta $Delta)) { $html += '<tr>'; foreach ($header in $headers) { $html += '<td>' + (Escape-Html -Value ([string]$row.$header)) + '</td>' }; $html += '</tr>' }
  $html += '</tbody></table>'
  return ($html -join '')
}

function Convert-ComplianceToHtmlTable {
  param([object[]]$Rows)
  $headers = @('cluster_id', 'page', 'output_path', 'compliant', 'passed_checks', 'missing_checks', 'missing_source_files', 'required_source', 'check_details')
  $html = @('<table><thead><tr>')
  foreach ($header in $headers) { $html += '<th>' + (Escape-Html -Value $header) + '</th>' }
  $html += '</tr></thead><tbody>'
  foreach ($row in $Rows) { $html += '<tr>'; foreach ($header in $headers) { $html += '<td>' + (Escape-Html -Value ([string]$row.$header)) + '</td>' }; $html += '</tr>' }
  $html += '</tbody></table>'
  return ($html -join '')
}

function Convert-ObservationsToMarkdownTable {
  param([object[]]$Rows)
  $headers = @('order', 'page', 'primary_keyword', '7d clicks', '7d impressions', '7d CTR', '7d position', '7d owner share', '28d clicks', '28d impressions', '28d CTR', '28d position', '28d owner share', '28d owner impressions', '28d cluster impressions', '28d competing pages', 'cannibalization', 'output_compliant', 'cooldown_source', 'cooldown_until', 'disposition', 'reason')
  $lines = @()
  $lines += '| ' + ($headers -join ' | ') + ' |'
  $lines += '| ---: | --- | --- | ---: | ---: | ---: | ---: | --- | ---: | ---: | ---: | ---: | ---: | --- | ---: | --- | --- | --- | --- | --- |'
  foreach ($row in $Rows) {
    $cells = foreach ($header in $headers) { Escape-MdCell -Value ([string]$row.$header) }
    $lines += '| ' + ($cells -join ' | ') + ' |'
  }
  return ($lines -join "`n")
}

function Convert-ObservationsToHtmlTable {
  param([object[]]$Rows)
  $headers = @('order', 'page', 'primary_keyword', '7d clicks', '7d impressions', '7d CTR', '7d position', '7d owner share', '28d clicks', '28d impressions', '28d CTR', '28d position', '28d owner share', '28d owner impressions', '28d cluster impressions', '28d competing pages', 'cannibalization', 'output_compliant', 'cooldown_source', 'cooldown_until', 'disposition', 'reason')
  $html = @('<table><thead><tr>')
  foreach ($header in $headers) { $html += '<th>' + (Escape-Html -Value $header) + '</th>' }
  $html += '</tr></thead><tbody>'
  foreach ($row in $Rows) {
    $html += '<tr>'
    foreach ($header in $headers) { $html += '<td>' + (Escape-Html -Value ([string]$row.$header)) + '</td>' }
    $html += '</tr>'
  }
  $html += '</tbody></table>'
  return ($html -join '')
}

function Copy-ActionRowForQueue {
  param(
    [object]$Row,
    [int]$Priority
  )

  return [PSCustomObject]@{
    action_id          = $Row.action_id
    fingerprint        = $Row.fingerprint
    priority           = $Priority
    clusterId          = $Row.clusterId
    page               = $Row.page
    ownerKeywords      = $Row.ownerKeywords
    intentType         = $Row.intentType
    '7d clicks'        = $Row.'7d clicks'
    '7d impressions'   = $Row.'7d impressions'
    '7d CTR'           = $Row.'7d CTR'
    '7d position'      = $Row.'7d position'
    '28d clicks'       = $Row.'28d clicks'
    '28d impressions'  = $Row.'28d impressions'
    '28d CTR'          = $Row.'28d CTR'
    '28d position'     = $Row.'28d position'
    actionType         = $Row.actionType
    eligibility_kind   = $Row.eligibility_kind
    score              = $Row.score
    data_score         = $Row.data_score
    strategic_priority = $Row.strategic_priority
    reason             = $Row.reason
    fixedActions       = $Row.fixedActions
    required_validations = @($Row.required_validations)
    validationCommands = $Row.validationCommands
  }
}

function New-QueueRound {
  param(
    [int]$Round,
    [object[]]$Items
  )

  $rows = @()
  $priority = 1
  foreach ($item in $Items) {
    $rows += (Copy-ActionRowForQueue -Row $item.row -Priority $priority)
    $priority++
  }

  $requiredSource = @()
  foreach ($row in $rows) {
    $requiredSource += @(Get-RequiredSourceForPage -Page $row.page)
  }
  $requiredValidations = @(
    'node .agents/skills/curtain-online-seo-geo/scripts/keyword-owner-check.mjs',
    'npm.cmd run build',
    'npm.cmd run seo:check',
    'npm.cmd run seo:preflight'
  )

  return [PSCustomObject]@{
    round              = $Round
    type               = 'page-batch'
    priority           = $Round
    title              = "Round $Round page-batch"
    targetCount        = $rows.Count
    targets            = @($rows | ForEach-Object { $_.page })
    ownerKeywords      = @($rows | ForEach-Object { $_.ownerKeywords })
    action_ids         = @($rows | ForEach-Object { $_.action_id })
    action_fingerprints = @($rows | ForEach-Object { $_.fingerprint })
    requiredSource     = @($requiredSource | Select-Object -Unique)
    required_validations = $requiredValidations
    validationCommands = $requiredValidations
    actions            = $rows
  }
}

function New-ActionQueue {
  param(
    [object[]]$CandidateItems,
    [int]$BatchSize = 5,
    [int]$MaximumBatchSize = 6,
    [int]$MaxRounds = 3
  )

  $orderedItems = @($CandidateItems |
    Sort-Object -Property @{ Expression = { [double]$_.row.data_score }; Descending = $true }, @{ Expression = { [double]$_.row.strategic_priority }; Descending = $true }, strategicOrder)

  $deduped = @()
  $seen = @{}
  foreach ($item in $orderedItems) {
    if (-not $seen.ContainsKey($item.page)) {
      $seen[$item.page] = $true
      $deduped += $item
    }
  }

  $rounds = @()
  if ($deduped.Count -lt 2) { return $rounds }
  $index = 0
  $round = 1
  while ($index -lt $deduped.Count -and $round -le $MaxRounds) {
    $remaining = $deduped.Count - $index
    $take = if ($remaining -le $MaximumBatchSize) { $remaining } else { [Math]::Min($BatchSize, $remaining) }
    if ($take -lt 2) { break }
    $items = @($deduped | Select-Object -Skip $index -First $take)
    if ($items.Count -gt 0) {
      $rounds += (New-QueueRound -Round $round -Items $items)
    }
    $index += $take
    $round++
  }

  return $rounds
}

function New-SinglePageReviewOpportunity {
  param([object]$CandidateItem, [string]$ReviewType = 'single_page_p0_review', [string]$TitlePrefix = '單頁 P0 review')

  # A single high-value owner must never be converted into an executable
  # Round merely to satisfy the normal 2-page batch rule. Keep the same
  # evidence/action contract, but make the approval boundary explicit.
  $review = Copy-ActionRowForQueue -Row $CandidateItem.row -Priority 1
  $review | Add-Member -NotePropertyName type -NotePropertyValue 'single_page_review'
  $review | Add-Member -NotePropertyName review_type -NotePropertyValue $ReviewType
  $review | Add-Member -NotePropertyName title -NotePropertyValue ("${TitlePrefix}：{0}" -f $review.page)
  $review | Add-Member -NotePropertyName requires_user_approval -NotePropertyValue $true
  $review | Add-Member -NotePropertyName approval_instruction -NotePropertyValue '需要使用者明確批准後，才可另開單頁實作 Round；不得直接修改 source、建立 validation receipt 或部署。'
  $review | Add-Member -NotePropertyName owner_priority -NotePropertyValue $CandidateItem.ownerPriority
  $review | Add-Member -NotePropertyName business_value -NotePropertyValue $CandidateItem.businessValue
  $review | Add-Member -NotePropertyName requiredSource -NotePropertyValue @(Get-RequiredSourceForPage -Page $review.page)
  return $review
}

function New-RoundSlimPrompt {
  param(
    [object]$Round,
    [string]$RequestedMode,
    [string]$EffectiveMode,
    [string]$ModeLabel,
    [string]$QueueId,
    [string]$CycleKey,
    [string]$ReceiptPath
  )

  $lines = @()
  $lines += 'PLEASE IMPLEMENT THIS PLAN:'
  $lines += ''
  $lines += ('# Curtain Online SEO/GEO Round {0} Slim 指令' -f $Round.round)
  $lines += ''
  $lines += '請依這份 AI 執行指令實作，不要重新選詞/選頁。'
  $lines += ''
  $lines += '## Slim Rules'
  $lines += ''
  $lines += ('- 只實作 Round {0}，不要自行加入其他 Round 或 Watchlist。' -f $Round.round)
  $lines += '- 不要重新選頁、重新選詞或重新做策略分析。'
  $lines += '- 不要讀 raw 7d/28d CSV、`Weekly SOP/reports/`、`Weekly SOP/history/`、`All_plan/` 或 Phase 歷史。'
  $lines += '- 只讀本指令、`plan.md`、Required Source 內列出的檔案，以及目標頁必要 source truth。'
  $lines += '- 不直接修改 `out/`，不改公開 API、型別、後台邏輯或計價邏輯。'
  $lines += ''
  $lines += ('Mode: {0} -> {1}（{2}）' -f $RequestedMode, $EffectiveMode, $ModeLabel)
  $lines += ''
  $lines += ('## Round {0}' -f $Round.round)
  $lines += ''
  $lines += (Convert-ActionsToMarkdownTable -Rows $Round.actions)
  $lines += ''
  $lines += '## Required Source'
  $lines += ''
  foreach ($item in @($Round.requiredSource)) { $lines += ('- `{0}`' -f $item) }
  $lines += ''
  $lines += '## Validation'
  $lines += ''
  foreach ($command in @($Round.required_validations)) { $lines += ('- `{0}`' -f $command) }
  $lines += ''
  $lines += '## Validation Receipt Writer'
  $lines += ''
  $lines += '- 只有上述所有命令 exit code 皆為 0，才可呼叫 receipt writer；不要手寫或直接覆蓋 receipt JSON。'
  $lines += ('- 固定使用 `scripts/write-seo-geo-validation-receipt.ps1`，它會核對 queue/cycle/round/action_ids/action_fingerprints 並寫入 `{0}`。' -f $ReceiptPath)
  $lines += ('- 固定參數：`-RuntimeRoot . -QueueId ''{0}'' -CycleKey ''{1}'' -Round {2}`。' -f $QueueId, $CycleKey, [int]$Round.round)
  $lines += '- 有修改 source 時使用 `-Result implemented -ChangedFiles <實際修改檔案>`；確認無需修改時使用 `-Result no_change_verified` 且不要傳 ChangedFiles。'
  $lines += '- `-ValidationResultsJson` 必須是 JSON array，逐項包含與 Validation 完全相同的 `command`、`status: passed`、`exit_code: 0`。'
  $lines += '- 任一驗證失敗時不要呼叫 receipt writer；回報失敗命令與最後錯誤。'
  $lines += '- HTA 將本輪前進為 `local_validated` 後，部署、live、7d、28d 必須依序呼叫 `scripts/write-seo-geo-lifecycle-receipt.ps1` 寫入 `deployed → live_verified → observing_7d → reviewed_28d → completed` receipt；不可跳關或手寫 state。'
  $lines += ''
  $lines += '## Report Back'
  $lines += ''
  $lines += ('- 回報已修改的 source files、Round {0} 頁面、驗證 pass/fail。' -f $Round.round)
  $lines += '- build/deploy/FTP log 只回報摘要與最後錯誤，不貼逐檔清單。'

  return $lines
}

function New-MonitoringPrompt {
  param(
    [object[]]$Rows,
    [string]$RequestedMode,
    [string]$EffectiveMode,
    [string]$Reason
  )
  $lines = @()
  $lines += 'PLEASE REVIEW THIS MONITORING LIST:'
  $lines += ''
  $lines += '# Curtain Online SEO/GEO Observation Only'
  $lines += ''
  $lines += '本週資料只供監控；沒有可執行 Round，也不授權修改 source。'
  $lines += ''
  $lines += '## Slim Rules'
  $lines += ''
  $lines += '- 不要重新選頁、選詞或重做策略。'
  $lines += '- 不要讀 raw CSV、reports/history、All_plan 或 Phase 歷史。'
  $lines += '- 不要修改 source、不要跑 build、不要部署、不要建立 validation receipt。'
  $lines += ('- 只根據 {0} 個 active owner 的 7d/28d 完整 baseline metrics 回報異常或下一次應觀察項目。' -f @($Rows).Count)
  $lines += ''
  $lines += "Mode: $RequestedMode -> $EffectiveMode"
  $lines += "Reason: $Reason"
  $lines += ''
  $lines += '## Monitoring List'
  $lines += ''
  $lines += (Convert-ObservationsToMarkdownTable -Rows $Rows)
  $lines += ''
  $lines += '## Report Back'
  $lines += ''
  $lines += '- 短摘要回報：是否繼續觀察、最多 1-3 個異常 owner、原因。'
  $lines += '- 不提出 source 實作步驟；等待新的 decision-ready 28d cycle。'
  return $lines
}

function New-OptionalOpportunitiesPrompt {
  param(
    [object[]]$Rows,
    [string]$RequestedMode,
    [string]$EffectiveMode,
    [string]$ModeLabel
  )

  $sources = @()
  foreach ($row in @($Rows)) {
    $sources += @(Get-RequiredSourceForPage -Page $row.page)
  }

  $lines = @()
  $lines += 'PLEASE REVIEW THIS OPTIONAL SEO/GEO LIST:'
  $lines += ''
  $lines += '# Curtain Online SEO/GEO 小幅可優化參考清單'
  $lines += ''
  $lines += '這份清單只用來判斷是否值得另開一輪小幅優化；不要直接修改 source，除非使用者明確要求實作。'
  $lines += ''
  $lines += '## Slim Rules'
  $lines += ''
  $lines += '- 不要重新選頁、重新選詞或重新做策略分析。'
  $lines += '- 不要讀 raw 7d/28d CSV、`Weekly SOP/reports/`、`Weekly SOP/history/`、`All_plan/` 或 Phase 歷史。'
  $lines += '- 只根據本清單判斷：值得做 / 先觀察 / 不建議做。'
  $lines += '- 若建議加做，最多挑 1-3 頁，並說明原因；不要自行擴大成新的完整 ranking cycle。'
  $lines += '- 省 token 回覆：不要重述整份表格；只列建議頁面、原因、建議修改類型。'
  $lines += '- 如果使用者決定要做，等待使用者另外下短指令，例如：`請依剛剛建議，實作 A 頁和 B 頁的小幅 SEO/GEO 優化。`'
  if (@($Rows | Where-Object { $_.review_type -in @('single_page_p0_review','single_page_alignment_review') }).Count -gt 0) {
    $lines += '- `single_page_*_review` 是核准前審查：先請使用者明確批准指定頁面；批准前不得修改 source、跑 build、部署或建立 validation receipt。'
  }
  $lines += ''
  $lines += ('Mode: {0} -> {1}（{2}）' -f $RequestedMode, $EffectiveMode, $ModeLabel)
  $lines += ''
  $lines += '## Optional Opportunities'
  $lines += ''
  if (@($Rows).Count -gt 0) {
    foreach ($review in @($Rows | Where-Object { $_.review_type -in @('single_page_p0_review','single_page_alignment_review') })) {
      $lines += ('- 單頁 review（{0}）：`{1}`；{2}' -f $review.review_type, $review.page, $review.approval_instruction)
    }
    if (@($Rows | Where-Object { $_.review_type -in @('single_page_p0_review','single_page_alignment_review') }).Count -gt 0) { $lines += '' }
    $lines += (Convert-ActionsToMarkdownTable -Rows $Rows)
  } else {
    $lines += '- 目前沒有額外小幅可優化參考頁。'
  }
  $lines += ''
  $lines += '## Required Source If User Later Asks To Implement'
  $lines += ''
  foreach ($item in @($sources | Select-Object -Unique)) { $lines += ('- `{0}`' -f $item) }
  $lines += ''
  $lines += '## Report Back'
  $lines += ''
  $lines += '- 只回報是否建議加做、建議頁面、原因、預估修改類型。'
  $lines += '- 回覆請控制在短摘要，不要貼回完整 Optional Opportunities 表格。'
  $lines += '- 不要跑 build，不要部署，不要修改 source，除非使用者另外明確要求。'

  return $lines
}

$weeklyRoot = if ([string]::IsNullOrWhiteSpace($RuntimeRoot)) {
  [System.IO.Path]::GetFullPath($PSScriptRoot)
} else {
  [System.IO.Path]::GetFullPath($RuntimeRoot)
}
$repoRoot = Split-Path -Parent $PSScriptRoot
Ensure-Dir -Path $weeklyRoot

$registryFullPath = if ([string]::IsNullOrWhiteSpace($RegistryPath)) {
  Join-Path $weeklyRoot 'config\target-registry.json'
} else {
  Resolve-RuntimePath -WeeklyRoot $weeklyRoot -Value $RegistryPath
}
$siteConfigPath = Join-Path $weeklyRoot 'config\site-config.json'
$siteConfig = Read-JsonIfExists -Path $siteConfigPath
if (-not $siteConfig -or [string]::IsNullOrWhiteSpace([string]$siteConfig.expectedHost)) {
  throw "Missing or invalid site config expectedHost: $siteConfigPath"
}
$expectedHost = ([string]$siteConfig.expectedHost).Trim().TrimEnd('.').ToLowerInvariant()

$latestRoot = Join-Path $weeklyRoot 'latest'
$latest7d = Join-Path $latestRoot '7d'
$latest28d = Join-Path $latestRoot '28d'
Ensure-Dir -Path $latestRoot
$fresh7d = Get-WindowFreshness -WeeklyRoot $weeklyRoot -LatestDir $latest7d -Window '7d' -MaxAgeDays 10 -ExpectedHost $expectedHost
$fresh28d = Get-WindowFreshness -WeeklyRoot $weeklyRoot -LatestDir $latest28d -Window '28d' -MaxAgeDays 35 -ExpectedHost $expectedHost
if (-not $fresh7d.fresh) {
  throw "Cannot generate SEO/GEO action plan: latest 7d snapshot is not fresh. $($fresh7d.text)"
}

$requestedMode = $Mode
$sameSnapshotFamily = ($fresh7d.snapshot_family_id -and $fresh7d.snapshot_family_id -eq $fresh28d.snapshot_family_id -and $fresh7d.end_date -eq $fresh28d.end_date)
$snapshotDecisionReady = [bool]($fresh7d.fresh -and $fresh28d.fresh -and $fresh7d.decision_ready -and $fresh28d.decision_ready -and $sameSnapshotFamily)
if ($Mode -eq 'monthly' -and -not $snapshotDecisionReady) {
  throw "Cannot generate monthly SEO/GEO action plan: 7d/28d snapshots are not decision-ready (7d=$($fresh7d.data_confidence), 28d=$($fresh28d.data_confidence))."
}
$cycleDecisionReady = [bool](($Mode -eq 'monthly' -or $Mode -eq 'auto') -and $snapshotDecisionReady)
$effectiveMode = if ($cycleDecisionReady) { 'monthly' } else { 'weekly' }

$registryResult = Get-RegistryOwners -Path $registryFullPath -ExpectedHost $expectedHost
$registry = $registryResult.registry
$owners = @($registryResult.owners)
$ownerUrlMap = @{}
foreach ($owner in $owners) { $ownerUrlMap[[string]$owner.ownerPage] = $true }
$canonicalAliasMap = Get-CanonicalAliasMap -Owners $owners -ExpectedHost $expectedHost
$monitorOnlyAssets = @(Get-MonitorOnlyAssets -Registry $registry -ExpectedHost $expectedHost -OwnerUrls $ownerUrlMap)
$registryRelativePath = Get-RelativePortablePath -BasePath $weeklyRoot -Path $registryFullPath
$registrySha = Get-Sha256File -Path $registryFullPath
$registryVersion = if ($null -ne $registry.schemaVersion) { [int]$registry.schemaVersion } else { 1 }
$lifecycleReviewDates = Get-LifecycleReviewDates -WeeklyRoot $weeklyRoot
$outputHtmlIndex = Get-OutputHtmlIndex -RepoRoot $repoRoot

$query7dPath = Get-BaselinePathFromManifest -WeeklyRoot $weeklyRoot -Manifest $fresh7d.manifest -Kind query -Required $true
$page7dPath = Get-BaselinePathFromManifest -WeeklyRoot $weeklyRoot -Manifest $fresh7d.manifest -Kind page -Required $true
$query28dPath = Get-BaselinePathFromManifest -WeeklyRoot $weeklyRoot -Manifest $fresh28d.manifest -Kind query -Required $false
$page28dPath = Get-BaselinePathFromManifest -WeeklyRoot $weeklyRoot -Manifest $fresh28d.manifest -Kind page -Required $false
$queryPage7dPath = Get-BaselinePathFromManifest -WeeklyRoot $weeklyRoot -Manifest $fresh7d.manifest -Kind query_page -Required $true
$queryPage28dPath = Get-BaselinePathFromManifest -WeeklyRoot $weeklyRoot -Manifest $fresh28d.manifest -Kind query_page -Required $cycleDecisionReady

$comparisonQuery28dPath = if ($fresh28d.manifest.comparison_sources) { Resolve-ManifestPath -WeeklyRoot $weeklyRoot -Value ([string]$fresh28d.manifest.comparison_sources.query_before) } else { $null }
$queryRows7d = @(Get-NormalizedBaselineRows -Path $query7dPath -CanonicalAliasMap $canonicalAliasMap)
$pageRows7d = @(Get-NormalizedBaselineRows -Path $page7dPath -CanonicalAliasMap $canonicalAliasMap)
$queryRows28d = @(Get-NormalizedBaselineRows -Path $query28dPath -CanonicalAliasMap $canonicalAliasMap)
$pageRows28d = @(Get-NormalizedBaselineRows -Path $page28dPath -CanonicalAliasMap $canonicalAliasMap)
$queryPageRows7d = @(Get-NormalizedBaselineRows -Path $queryPage7dPath -CanonicalAliasMap $canonicalAliasMap)
$queryPageRows28d = @(Get-NormalizedBaselineRows -Path $queryPage28dPath -CanonicalAliasMap $canonicalAliasMap)
$comparisonQueryRows28d = @(Get-NormalizedBaselineRows -Path $comparisonQuery28dPath -CanonicalAliasMap $canonicalAliasMap)
$diagnosticHistory7d = Update-DiagnosticHistoryFromManifest -WeeklyRoot $weeklyRoot -Freshness $fresh7d
$diagnosticHistory28d = Update-DiagnosticHistoryFromManifest -WeeklyRoot $weeklyRoot -Freshness $fresh28d
$dateRows28d = @(Get-DiagnosticDailyRows -WeeklyRoot $weeklyRoot -HistoryBinding $diagnosticHistory28d -Kind 'date')
$datePageRows28d = @(Get-DiagnosticDailyRows -WeeklyRoot $weeklyRoot -HistoryBinding $diagnosticHistory28d -Kind 'date_page')
$devicePageRows28d = @(Get-DiagnosticRowsFromManifest -WeeklyRoot $weeklyRoot -Manifest $fresh28d.manifest -Kind 'device_page')
$countryPageRows28d = @(Get-DiagnosticRowsFromManifest -WeeklyRoot $weeklyRoot -Manifest $fresh28d.manifest -Kind 'country_page')
$deviceQueryRows28d = @(Get-DiagnosticRowsFromManifest -WeeklyRoot $weeklyRoot -Manifest $fresh28d.manifest -Kind 'device_query')
$comparisonPeriod = $fresh28d.manifest.comparison_period
$queryDelta = Get-QueryDelta -CurrentRows $queryRows28d -PreviousRows $comparisonQueryRows28d -CurrentStartDate ([string]$fresh28d.start_date) -CurrentEndDate ([string]$fresh28d.end_date) -ComparisonStartDate ([string]$comparisonPeriod.start_date) -ComparisonEndDate ([string]$comparisonPeriod.end_date) -ComparisonType ([string]$comparisonPeriod.comparison_type) -WeeklyRoot $weeklyRoot -MinimumImpressions 5
$ctrBenchmark = New-CtrBenchmark -Rows $pageRows28d -QueryRows $queryRows28d -DeviceQueryRows $deviceQueryRows28d -Owners $owners -WeeklyRoot $weeklyRoot -StartDate ([string]$fresh28d.manifest.start_date) -EndDate ([string]$fresh28d.manifest.end_date) -DateRows $dateRows28d -Manifest $fresh28d.manifest -ManifestPath (Get-RelativePortablePath -BasePath $weeklyRoot -Path $fresh28d.manifest_path) -ManifestSha256 ([string]$fresh28d.manifest_sha256) -MinimumImpressions 100
$sitewideDaily = New-SitewideDailyAnalysis -Rows $dateRows28d
$devicePageDifferences = @(Get-DevicePageDifferences -Rows $devicePageRows28d)
$countryPageAnomalies = @(Get-CountryPageAnomalies -Rows $countryPageRows28d)
$reviewWindows = @(Get-NonOverlappingReviewWindows -Owners $owners -LatestFinalizedDate $fresh28d.end_date -LifecycleDates $lifecycleReviewDates -DateRows $dateRows28d -DatePageRows $datePageRows28d)
$diagnostics = [ordered]@{
  status = if ($fresh28d.diagnostics_complete) { 'complete' } else { 'incomplete' }
  required_dimensions = @('date','date_page','device_page','country_page','device_query')
  history = [ordered]@{ '7d' = $diagnosticHistory7d; '28d' = $diagnosticHistory28d }
  sitewide_daily = $sitewideDaily
  page_review_windows = $reviewWindows
  device_page_differences = $devicePageDifferences
  country_page_anomalies = $countryPageAnomalies
}
$queryMap7d = Index-RowsByQuery -Rows $queryRows7d
$queryMap28d = Index-RowsByQuery -Rows $queryRows28d
$pageMap7d = Index-RowsByPage -Rows $pageRows7d
$pageMap28d = Index-RowsByPage -Rows $pageRows28d
$monitorOnlyAssets = @($monitorOnlyAssets) + @(Get-DynamicMonitorOnlyAssets -StaticAssets $monitorOnlyAssets -PageRows $pageRows28d -OwnerUrls $ownerUrlMap -ExpectedHost $expectedHost -MaximumDynamic 5)
$monitoringAssets = @()
foreach ($asset in $monitorOnlyAssets) {
  $pageMetric7d = if ($pageMap7d.ContainsKey([string]$asset.page)) { $pageMap7d[[string]$asset.page] } else { $null }
  $pageMetric28d = if ($pageMap28d.ContainsKey([string]$asset.page)) { $pageMap28d[[string]$asset.page] } else { $null }
  $monitoringAssets += New-MonitoringAssetRow -Asset $asset -PageMetric7d $pageMetric7d -PageMetric28d $pageMetric28d
}

$sourceProvenance = Get-SourceProvenance -Owners $owners -RepoRoot $repoRoot
$sourceFiles = @($sourceProvenance.source_files)
$sourceOwnerBindings = @($sourceProvenance.owners)
$sourceFingerprint = [string]$sourceProvenance.source_fingerprint
$actionHistoryPath = Join-Path $weeklyRoot 'history\curtain-online\seo-geo-action-history.json'
if (-not (Test-Path -LiteralPath $actionHistoryPath -PathType Leaf)) {
  Ensure-Dir -Path (Split-Path -Parent $actionHistoryPath)
  Write-Utf8NoBom -Path $actionHistoryPath -Text (([ordered]@{ schema_version = 1; entries = @() } | ConvertTo-Json -Depth 4) + [Environment]::NewLine)
}
$actionHistoryRelativePath = Get-RelativePortablePath -BasePath $weeklyRoot -Path $actionHistoryPath
$actionHistorySha = Get-Sha256File -Path $actionHistoryPath
$actionHistoryEntries = @(Get-ActionHistoryEntries -Path $actionHistoryPath)
$actionHistoryBinding = [ordered]@{
  path = $actionHistoryRelativePath
  sha256 = $actionHistorySha
  entry_count = $actionHistoryEntries.Count
}
$candidateItems = @()
$alignmentCandidateItems = @()
$alignmentSignals = @()
$observations = @()
$ownerAnalyses = @()
foreach ($owner in $owners) {
  $page = [string]$owner.ownerPage
  $terms = @(Get-QueryTerms -Owner $owner)
  $queryMetric7d = Get-BestQueryMetric -Terms $terms -Map7d $queryMap7d -Map28d @{} -Mode 'weekly'
  $queryMetric28d = Get-BestQueryMetric -Terms $terms -Map7d @{} -Map28d $queryMap28d -Mode 'monthly'
  $pageMetric7d = if ($pageMap7d.ContainsKey($page)) { $pageMap7d[$page] } else { $null }
  $pageMetric28d = if ($pageMap28d.ContainsKey($page)) { $pageMap28d[$page] } else { $null }
  $queryPageAnalysis7d = Get-OwnerQueryPageAnalysis -Owner $owner -Rows $queryPageRows7d
  $queryPageAnalysis28d = Get-OwnerQueryPageAnalysis -Owner $owner -Rows $queryPageRows28d
  $compliance = Get-OwnerOutputCompliance -Owner $owner -RepoRoot $repoRoot -OutputIndex $outputHtmlIndex
  $registryCooldown = Get-CooldownStatus -LastChangedAt ([string]$owner.lastChangedAt)
  $row = New-ActionRow -Priority 0 -Owner $owner -PageMetric7d $pageMetric7d -PageMetric28d $pageMetric28d -QueryMetric7d $queryMetric7d -QueryMetric28d $queryMetric28d -Compliance $compliance -Benchmark $ctrBenchmark
  $actionHistoryCooldown = Get-ActionHistoryCooldown -Entries $actionHistoryEntries -Fingerprint ([string]$row.fingerprint)
  $performanceOpportunity = Get-PerformanceOpportunity -PageMetric28d $pageMetric28d -QueryMetric28d $queryMetric28d -Benchmark $ctrBenchmark -PageType ([string]$owner.pageType)
  if ($queryPageAnalysis28d.alignment_eligible) {
    $alignmentReason = "Query × Page alignment: owner share=$($queryPageAnalysis28d.owner_share)%, cluster impressions=$($queryPageAnalysis28d.total_impressions), cannibalization=$([bool]$queryPageAnalysis28d.cannibalization)."
    $alignmentRow = New-ActionRow -Priority 0 -Owner $owner -PageMetric7d $pageMetric7d -PageMetric28d $pageMetric28d -QueryMetric7d $queryMetric7d -QueryMetric28d $queryMetric28d -Compliance $compliance -Benchmark $ctrBenchmark -EligibilityKind alignment -EligibilityReason $alignmentReason
    $alignmentRow.actionType = 'Query × Page alignment review'
    $alignmentHistoryCooldown = Get-ActionHistoryCooldown -Entries $actionHistoryEntries -Fingerprint ([string]$alignmentRow.fingerprint)
    $pageHistoryCooldown = if ($actionHistoryCooldown.active) { $actionHistoryCooldown } else { $alignmentHistoryCooldown }
    $alignmentDisposition = if (-not $cycleDecisionReady) { 'monitor_only' } elseif ($registryCooldown.active) { 'registry_cooldown' } elseif ($pageHistoryCooldown.active) { 'action_history_cooldown' } else { 'alignment_review' }
    $alignmentSignals += [PSCustomObject]@{
      cluster_id=[string]$owner.clusterId; page=$page; primary_keyword=[string]$owner.primaryKeyword
      owner_share=[double]$queryPageAnalysis28d.owner_share; cluster_impressions=[int]$queryPageAnalysis28d.total_impressions
      cannibalization=[bool]$queryPageAnalysis28d.cannibalization; competing_pages=@($queryPageAnalysis28d.competing_pages)
      action_fingerprint=[string]$alignmentRow.fingerprint; disposition=$alignmentDisposition
      cooldown_source=if($registryCooldown.active){'registry_lastChangedAt'}elseif($pageHistoryCooldown.active){'action_history'}else{''}
      cooldown_until=if($registryCooldown.active){$registryCooldown.cooldown_until}elseif($pageHistoryCooldown.active){$pageHistoryCooldown.cooldown_until}else{$null}
      reason=$alignmentReason
    }
    if ($alignmentDisposition -eq 'alignment_review') {
      $alignmentCandidateItems += [PSCustomObject]@{ page=$page; strategicOrder=[int]$owner.order; ownerPriority=[string]$owner.priority; businessValue=[string]$owner.businessValue; row=$alignmentRow }
    }
  }

  $disposition = 'actionable'
  $reason = 'decision-ready，source 尚有缺口，且不在 registry/action-history 28d cooldown。'
  if (-not $cycleDecisionReady) {
    $disposition = 'monitor_only'
    $reason = 'snapshot 尚未 decision-ready，只記錄完整 metrics。'
  } elseif ($registryCooldown.active) {
    $disposition = 'registry_cooldown'
    $reason = "registry lastChangedAt=$($registryCooldown.last_changed_at)，28d cooldown 至 $($registryCooldown.cooldown_until)。"
  } elseif ($actionHistoryCooldown.active) {
    $disposition = 'action_history_cooldown'
    $reason = "相同 action fingerprint 已於 $($actionHistoryCooldown.completed_at) 完成，action-history 28d cooldown 至 $($actionHistoryCooldown.cooldown_until)。"
  } elseif ($compliance.compliant -and $performanceOpportunity.qualifies) {
    $disposition = 'performance_actionable'
    $reason = "實際輸出 HTML 已合規，但符合成效優化門檻：$($performanceOpportunity.reason)"
    $row = New-ActionRow -Priority 0 -Owner $owner -PageMetric7d $pageMetric7d -PageMetric28d $pageMetric28d -QueryMetric7d $queryMetric7d -QueryMetric28d $queryMetric28d -Compliance $compliance -Benchmark $ctrBenchmark -EligibilityKind performance -EligibilityReason $performanceOpportunity.reason
    $actionHistoryCooldown = Get-ActionHistoryCooldown -Entries $actionHistoryEntries -Fingerprint ([string]$row.fingerprint)
    if ($actionHistoryCooldown.active) {
      $disposition = 'action_history_cooldown'
      $reason = "相同性能優化 action fingerprint 已於 $($actionHistoryCooldown.completed_at) 完成，action-history 28d cooldown 至 $($actionHistoryCooldown.cooldown_until)。"
    }
  } elseif ($compliance.compliant) {
    $disposition = 'output_compliant'
    $reason = '實際輸出 HTML 的 title、description、H1、canonical、JSON-LD、FAQ parity、calculator CTA、AI answer 與 inbound links 已符合，且未達成效優化門檻。'
  }

  if ($queryPageAnalysis28d.cannibalization) {
    $reason += " Query × Page 互搶警示：$($queryPageAnalysis28d.reason)"
  } elseif ($queryPageAnalysis28d.available -and $queryPageAnalysis28d.owner_share -lt 80 -and $queryPageAnalysis28d.total_impressions -gt 0) {
    $reason += " Query × Page owner share：$($queryPageAnalysis28d.reason)"
  }
  $observation = New-ObservationRow -Owner $owner -PageMetric7d $pageMetric7d -PageMetric28d $pageMetric28d -QueryMetric7d $queryMetric7d -QueryMetric28d $queryMetric28d -Compliance $compliance -RegistryCooldown $registryCooldown -ActionHistoryCooldown $actionHistoryCooldown -QueryPageAnalysis7d $queryPageAnalysis7d -QueryPageAnalysis28d $queryPageAnalysis28d -ActionFingerprint ([string]$row.fingerprint) -Disposition $disposition -Reason $reason
  $observations += $observation
  $analysis = [PSCustomObject]@{
    owner = $owner
    pageMetric7d = $pageMetric7d
    pageMetric28d = $pageMetric28d
    queryMetric7d = $queryMetric7d
    queryMetric28d = $queryMetric28d
    compliance = $compliance
    registryCooldown = $registryCooldown
    actionHistoryCooldown = $actionHistoryCooldown
    queryPageAnalysis7d = $queryPageAnalysis7d
    queryPageAnalysis28d = $queryPageAnalysis28d
    observation = $observation
  }
  $ownerAnalyses += $analysis
  if ($cycleDecisionReady -and ($disposition -eq 'actionable' -or $disposition -eq 'performance_actionable') -and -not $registryCooldown.active -and -not $actionHistoryCooldown.active) {
    $candidateItems += [PSCustomObject]@{
      page = $page
      strategicOrder = [int]$owner.order
      ownerPriority = [string]$owner.priority
      businessValue = [string]$owner.businessValue
      row = $row
    }
  }
}

$actionQueue = @(
  if ($cycleDecisionReady) {
    New-ActionQueue -CandidateItems $candidateItems -BatchSize 5 -MaximumBatchSize 6 -MaxRounds 3
  }
)
$complianceReport = @($ownerAnalyses | ForEach-Object { New-ComplianceReportRow -Owner $_.owner -Compliance $_.compliance })
$minorOpportunities = @()
if ($cycleDecisionReady -and $candidateItems.Count -eq 1) {
  $singleCandidate = $candidateItems[0]
  if ($singleCandidate.ownerPriority -eq 'P0' -or $singleCandidate.businessValue -eq 'critical') {
    $minorOpportunities = @(New-SinglePageReviewOpportunity -CandidateItem $singleCandidate)
  }
}
if ($cycleDecisionReady -and $alignmentCandidateItems.Count -gt 0) {
  foreach ($alignmentCandidate in $alignmentCandidateItems) {
    if (@($minorOpportunities | Where-Object { $_.page -eq $alignmentCandidate.page }).Count -eq 0) {
      $minorOpportunities += New-SinglePageReviewOpportunity -CandidateItem $alignmentCandidate -ReviewType 'single_page_alignment_review' -TitlePrefix 'Query × Page alignment review'
    }
  }
}
$queuedPages = @($actionQueue | ForEach-Object { $_.targets } | Select-Object -Unique)
foreach ($observation in $observations) {
  if ($queuedPages -contains $observation.page) {
    $observation.disposition = 'queued'
    $observation.reason = 'decision-ready 且通過 action eligibility；已排入動態 Round。'
  } elseif ($observation.disposition -in @('actionable', 'performance_actionable') -and @($minorOpportunities | Where-Object { $_.page -eq $observation.page }).Count -gt 0) {
    $observation.disposition = 'single_page_review'
    $observation.reason = '僅 1 個 P0/critical 可行 owner；列入 Optional Opportunities，需使用者明確批准後才可另開單頁實作 Round。'
  } elseif ($observation.disposition -in @('actionable', 'performance_actionable')) {
    $observation.disposition = 'observation'
    $observation.reason = if ($candidateItems.Count -lt 2) { '可行 owner 少於 2 頁，不建立單頁 Round。' } else { '超出本 cycle 最多 3 個 Round，保留觀察。' }
  } elseif (@($minorOpportunities | Where-Object { $_.page -eq $observation.page -and $_.review_type -in @('single_page_alignment_review','alignment_review') }).Count -gt 0) {
    $observation.disposition = 'single_page_review'
    $observation.reason = 'Query × Page alignment eligibility 成立；需使用者明確批准後才可建立單頁 executable Round。'
  }
}

# The queue is the single source of truth for execution state. Deriving this
# from its concrete rounds avoids a stale boolean producing an observation
# summary after a valid Round has already been created.
$isObservationOnly = (@($actionQueue).Count -eq 0)
$currentRound = if ($actionQueue.Count -gt 0) { $actionQueue[0] } else { $null }
$actions = @(if ($currentRound) { $currentRound.actions })
$round1Source = @(if ($currentRound) { $currentRound.requiredSource })
$pageBatchSize = if ($currentRound) { [int]$currentRound.targetCount } else { 0 }
$watchlist = $observations

$monitorReasons = @()
if ($requestedMode -eq 'weekly') { $monitorReasons += 'weekly mode 固定只產生 observation' }
if (-not $fresh28d.fresh) { $monitorReasons += "28d=$($fresh28d.status)" }
if (-not $fresh7d.decision_ready) { $monitorReasons += "7d confidence=$($fresh7d.data_confidence)" }
if (-not $fresh28d.decision_ready) { $monitorReasons += "28d confidence=$($fresh28d.data_confidence)" }
if ($fresh7d.bootstrapped -or $fresh28d.bootstrapped) { $monitorReasons += 'bootstrap baseline 尚無前期比較' }
if (-not $sameSnapshotFamily) { $monitorReasons += '7d/28d snapshot family 或資料截止日不一致' }
if ($minorOpportunities.Count -gt 0) { $monitorReasons += "$($minorOpportunities.Count) 個內容／成效／alignment 候選已列入 review，等待使用者明確批准" }
elseif ($cycleDecisionReady -and $actionQueue.Count -eq 0) { $monitorReasons += '所有 owner 皆無內容缺口／成效優化機會、正在 cooldown，或可行頁少於 2' }
$monitorReason = if ($monitorReasons.Count -gt 0) { $monitorReasons -join '；' } else { 'decision-ready' }
$baselineLabel = if ($isObservationOnly) {
  if ($fresh7d.bootstrapped -or $fresh28d.bootstrapped) { 'bootstrap_monitor_only' } else { 'observation_only' }
} else {
  'decision_ready'
}
$modeLabel = if ($isObservationOnly) { '7d/28d observation only' } else { '28d 正式決策 + 7d 異常觀察' }
$generatedAt = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'

function New-SnapshotBinding {
  param(
    [object]$Freshness,
    [string]$QueryPath,
    [string]$PagePath,
    [string]$QueryPagePath,
    [string]$ComparisonQueryPath,
    [object]$DiagnosticHistory,
    [string]$WeeklyRoot
  )
  if (-not $Freshness -or -not $Freshness.manifest) { return $null }
  $binding = [ordered]@{
    run_id = [string]$Freshness.run_id
    sha256 = [string]$Freshness.input_sha256
    manifest_path = Get-RelativePortablePath -BasePath $WeeklyRoot -Path $Freshness.manifest_path
    manifest_sha256 = [string]$Freshness.manifest_sha256
    query_baseline = [ordered]@{
      path = Get-RelativePortablePath -BasePath $WeeklyRoot -Path $QueryPath
      sha256 = Get-Sha256File -Path $QueryPath
    }
    page_baseline = [ordered]@{
      path = Get-RelativePortablePath -BasePath $WeeklyRoot -Path $PagePath
      sha256 = Get-Sha256File -Path $PagePath
    }
    query_page_baseline = [ordered]@{
      path = Get-RelativePortablePath -BasePath $WeeklyRoot -Path $QueryPagePath
      sha256 = Get-Sha256File -Path $QueryPagePath
    }
    data_confidence = [string]$Freshness.data_confidence
    decision_ready = [bool]$Freshness.decision_ready
    bootstrapped = [bool]$Freshness.bootstrapped
    diagnostics_complete = [bool]$Freshness.diagnostics_complete
    diagnostic_history = $DiagnosticHistory
  }
  if ($ComparisonQueryPath -and (Test-Path -LiteralPath $ComparisonQueryPath -PathType Leaf)) {
    $binding.comparison_query_baseline = [ordered]@{
      path = Get-RelativePortablePath -BasePath $WeeklyRoot -Path $ComparisonQueryPath
      sha256 = Get-Sha256File -Path $ComparisonQueryPath
    }
  }
  return $binding
}

$snapshot = [ordered]@{
  '7d' = New-SnapshotBinding -Freshness $fresh7d -QueryPath $query7dPath -PagePath $page7dPath -QueryPagePath $queryPage7dPath -DiagnosticHistory $diagnosticHistory7d -WeeklyRoot $weeklyRoot
  '28d' = New-SnapshotBinding -Freshness $fresh28d -QueryPath $query28dPath -PagePath $page28dPath -QueryPagePath $queryPage28dPath -ComparisonQueryPath $comparisonQuery28dPath -DiagnosticHistory $diagnosticHistory28d -WeeklyRoot $weeklyRoot
}
$registryBinding = [ordered]@{
  path = $registryRelativePath
  sha256 = $registrySha
  version = $registryVersion
  owners = $sourceOwnerBindings
}
$provenance = [ordered]@{
  snapshot = $snapshot
  registry = $registryBinding
  action_history = $actionHistoryBinding
  source_files = $sourceFiles
  source_fingerprint = $sourceFingerprint
}
$cycleMaterial = [ordered]@{
  schema_version = 2
  provenance = $provenance
}
$cycleHash = Get-Sha256Text -Text ($cycleMaterial | ConvertTo-Json -Depth 8 -Compress)
$cycleKey = "seo-geo-v2-$($cycleHash.Substring(0, 24))"
$queueId = "seo-geo-$($cycleHash.Substring(0, 16))"
$receiptRelativePath = 'latest/seo-geo-validation-receipt.json'

$outputMd = Join-Path $latestRoot 'seo-geo-action-plan.md'
$outputHtml = Join-Path $latestRoot 'seo-geo-action-plan.html'
$outputAi = Join-Path $latestRoot 'seo-geo-action-plan.ai.md'
$outputSlimAi = Join-Path $latestRoot 'seo-geo-action-plan.slim.ai.md'
$outputOptionalAi = Join-Path $latestRoot 'seo-geo-action-plan.optional.slim.ai.md'
$outputJson = Join-Path $latestRoot 'seo-geo-action-plan.json'
$outputQueueMd = Join-Path $latestRoot 'seo-geo-action-queue.md'
$outputQueueJson = Join-Path $latestRoot 'seo-geo-action-queue.json'
$outputQueueStateJson = Join-Path $latestRoot 'seo-geo-action-queue-state.json'
$previousExecutionQueue = Read-JsonIfExists -Path $outputQueueJson
$previousExecutionState = Read-JsonIfExists -Path $outputQueueStateJson
$previousExecutionPages = @()
$previousLifecycleStatus = if ($previousExecutionState) { [string]$previousExecutionState.status } else { '' }
if ($previousLifecycleStatus -in @('awaiting_implemented_receipt', 'implemented', 'local_validated', 'deployed', 'live_verified', 'observing_7d', 'reviewed_28d')) {
  $previousExecutionPages = @($previousExecutionQueue.rounds | ForEach-Object { @($_.targets) } | Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_) } | Select-Object -Unique)
}
$lineFeed = [string][char]10

$validation = @(
  'node .agents/skills/curtain-online-seo-geo/scripts/keyword-owner-check.mjs',
  'npm.cmd run build',
  'npm.cmd run seo:check',
  'npm.cmd run seo:preflight'
)
$technicalTasks = @(
  [PSCustomObject]@{
    priority = 1
    type = 'validation'
    title = 'Build / SEO check / preflight 本機驗收'
    scope = '只有 decision-ready Round 需要執行；observation_only 不執行。'
    requiredSource = @('scripts/seo-check.mjs', 'scripts/seo-preflight.mjs')
    validationCommands = $validation
    aiTokenRule = '只回報 passed/failed 與最後錯誤。'
  }
)

# Round prompt files are generated artifacts for the current queue only. Remove
# stale numbered prompts first so an observation-only cycle cannot leave an old
# executable instruction behind in latest/.
Get-ChildItem -LiteralPath $latestRoot -Filter 'seo-geo-action-plan.round-*.slim.ai.md' -File -ErrorAction SilentlyContinue |
  Remove-Item -Force -ErrorAction Stop

$roundPromptFiles = @()
if ($isObservationOnly) {
  $monitorPrompt = New-MonitoringPrompt -Rows $observations -RequestedMode $requestedMode -EffectiveMode $effectiveMode -Reason $monitorReason
  Write-Utf8NoBom -Path $outputSlimAi -Text ($monitorPrompt -join $lineFeed)
  Write-Utf8NoBom -Path $outputAi -Text ($monitorPrompt -join $lineFeed)
} else {
  foreach ($round in $actionQueue) {
    $roundPromptPath = Join-Path $latestRoot ('seo-geo-action-plan.round-{0}.slim.ai.md' -f $round.round)
    $roundPrompt = New-RoundSlimPrompt -Round $round -RequestedMode $requestedMode -EffectiveMode $effectiveMode -ModeLabel $modeLabel -QueueId $queueId -CycleKey $cycleKey -ReceiptPath $receiptRelativePath
    Write-Utf8NoBom -Path $roundPromptPath -Text ($roundPrompt -join $lineFeed)
    $roundPromptFiles += [PSCustomObject]@{
      round = [int]$round.round
      path = Get-RelativePortablePath -BasePath $weeklyRoot -Path $roundPromptPath
      targetCount = [int]$round.targetCount
      targets = @($round.targets)
      action_ids = @($round.action_ids)
      action_fingerprints = @($round.action_fingerprints)
      required_validations = @($round.required_validations)
    }
    if ($round.round -eq 1) {
      Write-Utf8NoBom -Path $outputSlimAi -Text ($roundPrompt -join $lineFeed)
      Write-Utf8NoBom -Path $outputAi -Text ($roundPrompt -join $lineFeed)
    }
  }
}

$optionalPrompt = New-OptionalOpportunitiesPrompt -Rows $minorOpportunities -RequestedMode $requestedMode -EffectiveMode $effectiveMode -ModeLabel $modeLabel
Write-Utf8NoBom -Path $outputOptionalAi -Text ($optionalPrompt -join $lineFeed)

$queueMd = @()
$queueMd += '# Curtain Online SEO/GEO Action Queue'
$queueMd += ''
$queueMd += "- 產生時間：$generatedAt"
$queueMd += "- 狀態：$(if ($isObservationOnly) { 'observation_only' } else { 'active' })"
$queueMd += "- Cycle key：$cycleKey"
$queueMd += "- Registry：$registryRelativePath (v$registryVersion)"
$queueMd += ''
if ($isObservationOnly) {
  $queueMd += '## Observation Only'
  $queueMd += ''
  $queueMd += "- $monitorReason"
  $queueMd += '- 本 cycle 有 0 個 Round，不執行 source 修改或 validation receipt。'
  $queueMd += ''
  $queueMd += (Convert-ObservationsToMarkdownTable -Rows $observations)
} else {
  foreach ($round in $actionQueue) {
    $queueMd += "## Round $($round.round)"
    $queueMd += ''
    $queueMd += "- 目標數：$($round.targetCount)"
    $queueMd += "- action_ids：$($round.action_ids -join '；')"
    $queueMd += "- Required Source：$($round.requiredSource -join '；')"
    $queueMd += ''
    $queueMd += (Convert-ActionsToMarkdownTable -Rows $round.actions)
    $queueMd += ''
  }
  $queueMd += '## Observation / Excluded Owners'
  $queueMd += ''
  $queueMd += (Convert-ObservationsToMarkdownTable -Rows @($observations | Where-Object { $_.disposition -ne 'queued' }))
}
$queueMd += ''
$queueMd += '## Optional Opportunities'
$queueMd += ''
if ($minorOpportunities.Count -gt 0) {
  $queueMd += '- `single_page_review` 不建立 Round；必須先取得使用者明確批准。'
  $queueMd += ''
  $queueMd += (Convert-ActionsToMarkdownTable -Rows $minorOpportunities)
} else {
  $queueMd += '- 目前沒有 Optional Opportunities。'
}
$queueMd += ''
$queueMd += '## Monitor-only Assets'
$queueMd += ''
$queueMd += '- 下列資產只記錄 GSC page metrics，不納入 keyword owner、cooldown 或自動優化 Round。'
$queueMd += ''
$queueMd += (Convert-MonitoringAssetsToMarkdownTable -Rows $monitoringAssets)
$queueMd += ''
$queueMd += '## Query Delta / Canonical Aggregation'
$queueMd += ''
$queryDeltaComparisonPeriod = if ($queryDelta.comparison_start_date -and $queryDelta.comparison_end_date) { "$($queryDelta.comparison_start_date)~$($queryDelta.comparison_end_date)" } else { 'data unavailable（legacy manifest 未保存 comparison dates）' }
$queueMd += "- canonical aliases：$($canonicalAliasMap.Count)；comparison=$($queryDelta.comparison_type)；period=$queryDeltaComparisonPeriod → $($queryDelta.current_start_date)~$($queryDelta.current_end_date)；signals=$($queryDelta.signal_count)；noise=$($queryDelta.noise_count)；pending=$($queryDelta.pending_confirmation_count)。"
$queueMd += ''
$queueMd += (Convert-QueryDeltaToMarkdownTable -Delta $queryDelta)
$queueMd += ''
$queueMd += '## Query × Page Alignment Review'
$queueMd += ''
$queueMd += (Convert-ObjectRowsToMarkdownTable -Rows (Get-AlignmentReportRows -Rows $alignmentSignals) -Headers @('cluster_id','page','primary_keyword','owner_share','cluster_impressions','cannibalization','disposition','cooldown_until','reason'))
Write-Utf8NoBom -Path $outputQueueMd -Text ($queueMd -join $lineFeed)

$queuePayload = [ordered]@{
  schema_version = 2
  status = if ($isObservationOnly) { 'observation_only' } else { 'active' }
  generated_at = $generatedAt
  queue_id = $queueId
  cycle_key = $cycleKey
  requested_mode = $requestedMode
  mode = $effectiveMode
  provenance = $provenance
  snapshot = $snapshot
  registry = $registryBinding
  action_history = $actionHistoryBinding
  source_files = $sourceFiles
  source_fingerprint = $sourceFingerprint
  page_batch_size = $pageBatchSize
  rounds = $actionQueue
  observations = $observations
  compliance = $complianceReport
  monitoring_assets = $monitoringAssets
  canonical_aliases = $canonicalAliasMap
  query_delta = $queryDelta
  diagnostics = $diagnostics
  alignment_candidates = $alignmentSignals
  ctr_benchmark = $ctrBenchmark
  review_windows = $reviewWindows
  technical_tasks = $technicalTasks
  optional_opportunities = $minorOpportunities
}
Write-Utf8NoBom -Path $outputQueueJson -Text ($queuePayload | ConvertTo-Json -Depth 12)

$stateRounds = @($actionQueue | ForEach-Object {
  [PSCustomObject]@{
    round = [int]$_.round
    action_ids = @($_.action_ids)
    action_fingerprints = @($_.action_fingerprints)
    required_validations = @($_.required_validations)
  }
})
$queueState = [ordered]@{
  schema_version = 2
  status = if ($isObservationOnly) { 'observation_only' } else { 'active' }
  queue_id = $queueId
  cycle_key = $cycleKey
  generated_at = $generatedAt
  provenance = $provenance
  snapshot = $snapshot
  registry = $registryBinding
  action_history = $actionHistoryBinding
  source_files = $sourceFiles
  source_fingerprint = $sourceFingerprint
  review_windows = $reviewWindows
  active_round = if ($actionQueue.Count -gt 0) { 1 } else { 0 }
  next_round = if ($actionQueue.Count -gt 0) { 1 } else { 0 }
  completed_rounds = @()
  copied_rounds = @()
  total_rounds = $actionQueue.Count
  rounds = $stateRounds
  prompt_files = $roundPromptFiles
  receipt_path = $receiptRelativePath
  precondition_gates = [ordered]@{
    data_validated = [ordered]@{
      status = if ($cycleDecisionReady) { 'passed' } else { 'blocked' }
      source = 'decision_ready_snapshot'
      assessed_at = $generatedAt
      reason = if ($cycleDecisionReady) { '7d/28d decision-ready snapshots are bound to this queue.' } else { 'A non-decision-ready snapshot cannot create an executable Round.' }
    }
    strategy_approved = [ordered]@{
      status = if ($isObservationOnly) { 'not_required' } else { 'passed' }
      source = if ($isObservationOnly) { 'no_executable_round' } else { 'strategy_selector' }
      assessed_at = $generatedAt
      reason = if ($isObservationOnly) { 'Observation-only queue has no executable Round.' } else { 'Executable queue was produced from a decision-ready strategy selection.' }
    }
  }
  note = if ($isObservationOnly) { 'Observation only; no executable Round.' } else { 'Advance requires a matching passed validation receipt.' }
}
$existingState = Read-JsonIfExists -Path $outputQueueStateJson
# Preserve execution progress only when the regenerated queue contains the
# exact same actions. A selector change can keep the same provenance cycle key
# while adding/removing actions; carrying an old observation state into that
# new queue would incorrectly disable its Round.
$existingActionIds = @()
$existingFingerprints = @()
if ($existingState -and $existingState.PSObject.Properties.Name -contains 'rounds') {
  $existingActionIds = @($existingState.rounds | ForEach-Object { @($_.action_ids) } | Sort-Object -Unique)
  $existingFingerprints = @($existingState.rounds | ForEach-Object { @($_.action_fingerprints) } | Sort-Object -Unique)
}
$newActionIds = @($stateRounds | ForEach-Object { @($_.action_ids) } | Sort-Object -Unique)
$newFingerprints = @($stateRounds | ForEach-Object { @($_.action_fingerprints) } | Sort-Object -Unique)
$sameActionBinding = (($existingActionIds -join '|') -ceq ($newActionIds -join '|')) -and (($existingFingerprints -join '|') -ceq ($newFingerprints -join '|'))
if ($existingState -and [string]$existingState.cycle_key -eq $cycleKey -and $sameActionBinding -and
    ($isObservationOnly -or [string]$existingState.status -ne 'observation_only')) {
  foreach ($name in @('queue_id', 'generated_at', 'status', 'active_round', 'next_round', 'completed_rounds', 'copied_rounds', 'last_copied_round', 'last_copied_at', 'last_validated_round', 'last_validation_receipt', 'last_validated_at', 'precondition_gates', 'local_validated_at', 'lifecycle_receipt_path', 'deployed_at', 'live_verified_at', 'observing_7d_at', 'reviewed_28d_at', 'completed_at')) {
    if ($existingState.PSObject.Properties.Name -contains $name) { $queueState[$name] = $existingState.$name }
  }
  if ($isObservationOnly) {
    $queueState.status = 'observation_only'
    $queueState.active_round = 0
    $queueState.next_round = 0
    $queueState.completed_rounds = @()
    $queueState.copied_rounds = @()
  }
}
Write-Utf8NoBom -Path $outputQueueStateJson -Text ($queueState | ConvertTo-Json -Depth 12)

$md = @()
$md += '# Curtain Online SEO/GEO Action Plan'
$md += ''
$md += "- 產生時間：$generatedAt"
$md += "- 狀態：$baselineLabel"
$md += "- 模式：$requestedMode -> $effectiveMode（$modeLabel）"
$md += "- Registry：$registryRelativePath (v$registryVersion)"
$md += "- 7d manifest：$($snapshot['7d'].manifest_path)"
if ($snapshot['28d']) { $md += "- 28d manifest：$($snapshot['28d'].manifest_path)" }
$md += ''
if ($isObservationOnly) {
  $md += '## Observation Only / 0 Rounds'
  $md += ''
  $md += "- $monitorReason"
  $md += ''
  $md += (Convert-ObservationsToMarkdownTable -Rows $observations)
} else {
  foreach ($round in $actionQueue) {
    $md += "## Round $($round.round)"
    $md += ''
    $md += (Convert-ActionsToMarkdownTable -Rows $round.actions)
    $md += ''
  }
  $md += '## Compliant / Cooldown Observations'
  $md += ''
  $md += (Convert-ObservationsToMarkdownTable -Rows @($observations | Where-Object { $_.disposition -ne 'queued' }))
}
$md += ''
$md += '## Optional Opportunities'
$md += ''
if ($minorOpportunities.Count -gt 0) {
  $md += '- `single_page_review` 不建立 Round；必須先取得使用者明確批准。'
  $md += ''
  $md += (Convert-ActionsToMarkdownTable -Rows $minorOpportunities)
} else {
  $md += '- 目前沒有 Optional Opportunities。'
}
$md += ''
$md += '## Monitor-only Assets'
$md += ''
$md += '- 只做 GSC page metrics 監控；不屬於 keyword owner，不產生自動優化 Round。'
$md += ''
$md += (Convert-MonitoringAssetsToMarkdownTable -Rows $monitoringAssets)
$md += ''
$md += '## Query Delta / Canonical Aggregation'
$md += ''
$md += "- 先套用 $($canonicalAliasMap.Count) 個 legacy→canonical alias 再聚合；comparison=$($queryDelta.comparison_type)，current=$($queryDelta.current_start_date)~$($queryDelta.current_end_date)，comparison period=$queryDeltaComparisonPeriod，minimum impressions=$($queryDelta.minimum_impressions)，confirmed signals=$($queryDelta.signal_count)，noise=$($queryDelta.noise_count)，pending second period=$($queryDelta.pending_confirmation_count)。"
$md += ''
$md += (Convert-QueryDeltaToMarkdownTable -Delta $queryDelta)
$md += ''
$md += '## Query × Page Alignment Review'
$md += ''
$md += '- owner share <80% 且 cluster impressions ≥50，或 cannibalization 成立時才產生；registry/action-history cooldown 仍優先。單一候選須經 single_page_review 明確核准。'
$md += ''
$md += (Convert-ObjectRowsToMarkdownTable -Rows (Get-AlignmentReportRows -Rows $alignmentSignals) -Headers @('cluster_id','page','primary_keyword','owner_share','cluster_impressions','cannibalization','disposition','cooldown_until','reason'))
$md += ''
$md += '## Per-page Compliance'
$md += ''
$md += '- 直接解析每個 owner 的 `out/<route>/index.html`；輸出缺失、晚於 source、canonical/schema URL 不符、FAQ 不一致或 CTA／AI answer／inbound links 缺失都會失敗。'
$md += ''
$md += (Convert-ComplianceToMarkdownTable -Rows $complianceReport)
$md += ''
$md += '## CTR Benchmark'
$md += ''
$md += "- method：$($ctrBenchmark.method)；available=$($ctrBenchmark.available)；selected window=$($ctrBenchmark.selected_window)；manifest=$($ctrBenchmark.selected_manifest_path) / $($ctrBenchmark.selected_manifest_sha256)；device scope：$($ctrBenchmark.device_scope)；minimum impressions：$($ctrBenchmark.minimum_impressions)。無有效窗口或樣本不足時禁止 performance_actionable。"
$md += ''
$md += (Convert-MonitoringAssetsToMarkdownTable -Rows @($ctrBenchmark.bands | ForEach-Object { [PSCustomObject]@{ order=''; asset_id=$_.position_band; type='ctr_benchmark'; page=''; label=''; monitoring_terms=''; '7d clicks'=''; '7d impressions'=''; '7d CTR'=''; '7d position'=''; '28d clicks'=$_.clicks; '28d impressions'=$_.impressions; '28d CTR'=$_.weighted_ctr; '28d position'=$_.lower_bound_ctr; disposition=$_.eligible; reason='sitewide 28d' } }))
$md += ''
$md += '## Non-overlapping Review Windows'
$md += ''
$md += '- 變更日不納入前／後比較；優先使用 lifecycle `live_verified_at`／`deployed_at`，沒有 receipt 才 fallback 到 registry source 變更日。包含 `pre_change_28d`、post 7d 與 post 28d。'
$md += ''
if ($reviewWindows.Count -gt 0) { $md += (Convert-ReviewWindowsToMarkdownTable -Rows $reviewWindows) } else { $md += '- 尚無需要 review 的 source 變更日期。' }
$md += ''
$md += '## Diagnostic Analysis'
$md += ''
$md += "- history：$($sitewideDaily.start_date)~$($sitewideDaily.end_date)，days=$($sitewideDaily.day_count)；五維 status=$($diagnostics.status)。"
$md += ''
$md += '### 全站每日趨勢'
$md += ''
$md += (Convert-ObjectRowsToMarkdownTable -Rows $sitewideDaily.days -Headers @('date','clicks','impressions','ctr','position','clicks_delta','impressions_delta','ctr_delta_pp','position_delta'))
$md += ''
$md += '### Device × Page 差異'
$md += ''
$md += (Convert-ObjectRowsToMarkdownTable -Rows (Get-DeviceDifferenceReportRows -Rows $devicePageDifferences) -Headers @('page','total_impressions','dominant_device','position_gap','ctr_gap_pp','anomaly','devices'))
$md += ''
$md += '### Country × Page 異常'
$md += ''
$md += (Convert-ObjectRowsToMarkdownTable -Rows (Get-CountryAnomalyReportRows -Rows $countryPageAnomalies) -Headers @('page','total_impressions','reason','countries'))
Write-Utf8NoBom -Path $outputMd -Text ($md -join $lineFeed)

$dashboardKeywordRows = @()
$dashboardAttentionRows = @()
$decisionReadyLabel = if ($snapshotDecisionReady) { '是（資料完整，可作正式判斷）' } else { '否（資料尚不足，只能觀察）' }
$strategyLabel = switch ([string]$baselineLabel) {
  'observation_only' { '僅觀察（本輪不修改網站）' }
  'bootstrap_monitor_only' { '初始觀察（資料尚在累積，本輪不修改網站）' }
  'decision_ready' { '可正式判斷（可建立優化工作）' }
  default { [string]$baselineLabel }
}
$diagnosticLabel = if ([string]$diagnostics.status -eq 'complete') { '完整（必要資料皆已取得）' } else { ([string]$diagnostics.status + '（必要資料尚未完整）') }
foreach ($analysis in @($ownerAnalyses | Where-Object {
  $_.owner.priority -eq 'P0' -or $_.observation.disposition -in @('queued', 'single_page_review') -or $_.owner.ownerPage -in $previousExecutionPages
} | Sort-Object { $_.owner.order })) {
  $observation = $analysis.observation
  $statusLabel = switch ([string]$observation.disposition) {
    'queued' { '本輪執行' }
    'single_page_review' { '待人工決定' }
    'registry_cooldown' { '冷卻觀察' }
    'action_history_cooldown' { '冷卻觀察' }
    'output_compliant' { '正常觀察' }
    default { [string]$observation.disposition }
  }
  if ($analysis.owner.ownerPage -in $previousExecutionPages -and $previousLifecycleStatus -eq 'live_verified') { $statusLabel = '已上線觀察' }
  elseif ($analysis.owner.ownerPage -in $previousExecutionPages -and $previousLifecycleStatus) { $statusLabel = $previousLifecycleStatus }
  $dashboardKeywordRows += [PSCustomObject]@{
    '優先級（P0 最高）' = [string]$analysis.owner.priority
    '關鍵字' = [string]$analysis.owner.primaryKeyword
    '對應主頁' = [string]$analysis.owner.ownerPath
    '7d 曝光' = [string]$observation.'7d impressions'
    '7d CTR' = [string]$observation.'7d CTR'
    '7d 排名' = [string]$observation.'7d position'
    '28d 曝光' = [string]$observation.'28d impressions'
    '28d CTR' = [string]$observation.'28d CTR'
    '28d 排名' = [string]$observation.'28d position'
    '主頁流量占比（Owner share）' = [string]$observation.'28d owner share'
    '目前狀態' = $statusLabel
  }
  if ($observation.disposition -in @('queued', 'single_page_review') -or [bool]$observation.cannibalization -or $analysis.owner.ownerPage -in $previousExecutionPages) {
    $signal = if ($observation.disposition -eq 'single_page_review') {
      '需要人工核准後才能建立執行 Round'
    } elseif ($analysis.owner.ownerPage -in $previousExecutionPages -and $previousLifecycleStatus -eq 'live_verified') {
      '已完成上線驗證，等待成效觀察資料'
    } elseif ($observation.disposition -eq 'queued') {
      '已排入本輪執行'
    } else {
      '查詢與對應主頁（Query × Page）互搶，需要持續觀察'
    }
    $nextStep = if ($analysis.owner.ownerPage -in $previousExecutionPages -and $previousLifecycleStatus -eq 'live_verified') {
      '等待部署後完整近 7 天／28 天（7d／28d）GSC 資料'
    } elseif ($observation.cooldown_until) {
      "等待冷卻期（cooldown）至 $($observation.cooldown_until)"
    } elseif ($observation.disposition -eq 'single_page_review') {
      '確認是否核准單頁調整'
    } else {
      '依本輪 Round 執行或等待下次 7d／28d 資料'
    }
    $dashboardAttentionRows += [PSCustomObject]@{
      '關鍵字' = [string]$analysis.owner.primaryKeyword
      '目前情況' = $signal
      '下一步' = $nextStep
    }
  }
}

$html = @()
$html += '<!doctype html><html lang="zh-Hant"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1">'
$html += '<title>Curtain Online SEO/GEO 重點報告</title>'
$html += '<style>body{font-family:"Microsoft JhengHei",Arial,sans-serif;margin:0;background:#f6f8fb;color:#18324a}main{max-width:1120px;margin:0 auto;padding:28px}h1{margin:0;color:#0b2f4a}h2{margin:28px 0 12px;font-size:20px}.sub{color:#607487;margin:8px 0 22px}.grid{display:grid;grid-template-columns:repeat(auto-fit,minmax(210px,1fr));gap:12px}.card,.note{background:#fff;border:1px solid #d9e3ec;border-radius:10px;padding:16px;line-height:1.65}.card strong{display:block;color:#607487;font-size:13px;margin-bottom:4px}.ok{border-left:5px solid #2f7d68}.warn{border-left:5px solid #bd7d18}.action{border-left:5px solid #2d6a9f}.small{color:#607487;font-size:13px}ul{margin:8px 0;padding-left:22px}code{background:#edf2f7;padding:2px 5px;border-radius:4px}.table-wrap{overflow:auto;border:1px solid #d9e3ec;border-radius:10px;background:#fff}table{width:100%;border-collapse:collapse;font-size:13px}th,td{padding:9px;border-bottom:1px solid #e3e9ef;text-align:left;white-space:nowrap}th{background:#edf4f8;color:#355166}tr:last-child td{border-bottom:0}</style>'
$html += '</head><body><main><h1>SEO/GEO 重點報告</h1>'
$html += '<p class="sub">給網站管理者閱讀的精簡版。完整明細保留於 JSON（系統資料檔）；請 AI 執行時使用 <code>*.ai.md</code>（AI 工作指令檔）。</p>'
$html += '<div class="grid">'
$html += '<div class="card ok"><strong>資料狀態</strong>近 7 天（7d）：' + (Escape-Html -Value ([string]$fresh7d.start_date)) + '~' + (Escape-Html -Value ([string]$fresh7d.end_date)) + '<br>近 28 天（28d）：' + (Escape-Html -Value ([string]$fresh28d.start_date)) + '~' + (Escape-Html -Value ([string]$fresh28d.end_date)) + '<br>可正式判斷（decision-ready）：' + (Escape-Html -Value $decisionReadyLabel) + '</div>'
$html += '<div class="card action"><strong>本輪策略</strong>' + (Escape-Html -Value $strategyLabel) + '<br>自動執行工作批次（Round）：' + (Escape-Html -Value ([string]$actionQueue.Count)) + '</div>'
$html += '<div class="card"><strong>技術驗收</strong>關鍵字對應主頁（Owner）通過：' + (Escape-Html -Value ([string](@($complianceReport | Where-Object { $_.compliant }).Count))) + '/' + (Escape-Html -Value ([string]$complianceReport.Count)) + '<br>資料診斷：' + (Escape-Html -Value $diagnosticLabel) + '</div>'
$html += '<div class="card"><strong>查詢變化</strong>已確認變化（signal）：' + (Escape-Html -Value ([string]$queryDelta.signal_count)) + '<br>待確認／雜訊：' + (Escape-Html -Value ([string]$queryDelta.pending_confirmation_count)) + '／' + (Escape-Html -Value ([string]$queryDelta.noise_count)) + '（雜訊為資料量過少，暫不採取動作）</div>'
$html += '</div>'
$html += '<h2>核心關鍵字表現</h2><p class="small">固定顯示 P0 主攻詞，並自動加入本輪需決策的關鍵字。數字為關鍵字對應主頁（Owner）的 GSC 指標；主頁流量占比（Owner share）用來檢查主攻詞流量是否集中在正確頁面。</p>'
$html += '<div class="table-wrap">' + (Convert-ObjectRowsToHtmlTable -Rows $dashboardKeywordRows -Headers @('優先級（P0 最高）','關鍵字','對應主頁','7d 曝光','7d CTR','7d 排名','28d 曝光','28d CTR','28d 排名','主頁流量占比（Owner share）','目前狀態')) + '</div>'
$html += '<h2>現在要做什麼</h2>'
if ($isObservationOnly) {
  $html += '<div class="note warn"><strong>目前不需修改網站。</strong><br>' + (Escape-Html -Value $monitorReason) + '</div>'
} else {
  $html += '<div class="note action"><strong>依序處理以下已建立的 Round：</strong><ul>'
  foreach ($round in $actionQueue) {
    $html += '<li>Round ' + (Escape-Html -Value ([string]$round.round)) + '：' + (Escape-Html -Value ([string]$round.targetCount)) + ' 頁，主題：' + (Escape-Html -Value ((@($round.targets) -join '、'))) + '</li>'
  }
  $html += '</ul></div>'
}
$html += '<h2>重要提醒</h2>'
if ($dashboardAttentionRows.Count -gt 0) {
  $html += '<div class="table-wrap">' + (Convert-ObjectRowsToHtmlTable -Rows @($dashboardAttentionRows | Select-Object -First 5) -Headers @('關鍵字','目前情況','下一步')) + '</div>'
} else {
  $html += '<div class="note ok">核心關鍵字目前沒有需要立即處理的互搶或執行項目。</div>'
}
$html += '<h2>候選優化</h2>'
if ($minorOpportunities.Count -gt 0) {
  $html += '<div class="note"><strong>' + (Escape-Html -Value ([string]$minorOpportunities.Count)) + ' 項候選待人工確認</strong><ul>'
  foreach ($item in @($minorOpportunities | Select-Object -First 3)) {
    $html += '<li>' + (Escape-Html -Value ([string]$item.ownerKeywords)) + '：' + (Escape-Html -Value ([string]$item.actionType)) + '；需明確核准後才可建立執行 Round。</li>'
  }
  $html += '</ul></div>'
} else {
  $html += '<div class="note ok">目前沒有需要人工核准的候選項目。</div>'
}
$html += '<p class="small">此報告是不可變的策略快照；已核准、已部署或已上線的實際進度，請以 Weekly SOP UI 的實際流程狀態（effective workflow）為準。Cycle（本次流程編號）：' + (Escape-Html -Value $cycleKey) + '</p>'
$html += '</main></body></html>'
Write-Utf8NoBom -Path $outputHtml -Text ($html -join $lineFeed)

$freshnessPublic = [ordered]@{
  '7d' = [ordered]@{ status = $fresh7d.status; text = $fresh7d.text; data_confidence = $fresh7d.data_confidence; decision_ready = $fresh7d.decision_ready; bootstrapped = $fresh7d.bootstrapped; run_time = $fresh7d.run_time }
  '28d' = [ordered]@{ status = $fresh28d.status; text = $fresh28d.text; data_confidence = $fresh28d.data_confidence; decision_ready = $fresh28d.decision_ready; bootstrapped = $fresh28d.bootstrapped; run_time = $fresh28d.run_time }
}
$json = [ordered]@{
  schema_version = 2
  status = 'success'
  workflow_status = if ($isObservationOnly) { 'observation_only' } else { [string]$queueState.status }
  generated_at = $generatedAt
  queue_id = $queueId
  cycle_key = $cycleKey
  requested_mode = $requestedMode
  mode = $effectiveMode
  mode_label = $modeLabel
  baseline_status = $baselineLabel
  freshness = $freshnessPublic
  provenance = $provenance
  snapshot = $snapshot
  registry = $registryBinding
  action_history = $actionHistoryBinding
  source_files = $sourceFiles
  source_fingerprint = $sourceFingerprint
  active_owner_count = $owners.Count
  monitor_only_asset_count = $monitoringAssets.Count
  page_batch_size = $pageBatchSize
  outputs = [ordered]@{
    markdown = Get-RelativePortablePath -BasePath $weeklyRoot -Path $outputMd
    html = Get-RelativePortablePath -BasePath $weeklyRoot -Path $outputHtml
    ai_prompt = Get-RelativePortablePath -BasePath $weeklyRoot -Path $outputAi
    slim_ai_prompt = Get-RelativePortablePath -BasePath $weeklyRoot -Path $outputSlimAi
    optional_ai_prompt = Get-RelativePortablePath -BasePath $weeklyRoot -Path $outputOptionalAi
    queue_markdown = Get-RelativePortablePath -BasePath $weeklyRoot -Path $outputQueueMd
    queue_json = Get-RelativePortablePath -BasePath $weeklyRoot -Path $outputQueueJson
    queue_state_json = Get-RelativePortablePath -BasePath $weeklyRoot -Path $outputQueueStateJson
    round_prompts = $roundPromptFiles
  }
  action_count = $actions.Count
  queue_round_count = $actionQueue.Count
  current_round = $currentRound
  queue = $actionQueue
  observations = $observations
  compliance = $complianceReport
  monitoring_assets = $monitoringAssets
  canonical_aliases = $canonicalAliasMap
  query_delta = $queryDelta
  diagnostics = $diagnostics
  alignment_candidates = $alignmentSignals
  ctr_benchmark = $ctrBenchmark
  review_windows = $reviewWindows
  technical_tasks = $technicalTasks
  optional_opportunities = $minorOpportunities
  actions = $actions
  watchlist = $watchlist
}
Write-Utf8NoBom -Path $outputJson -Text ($json | ConvertTo-Json -Depth 12)

Write-Host 'SEO/GEO action plan completed.'
Write-Host "Workflow status: $(if ($isObservationOnly) { 'observation_only' } else { $queueState.status })"
Write-Host "Cycle key: $cycleKey"
Write-Host "Active owners: $($owners.Count)"
Write-Host "Queue rounds: $($actionQueue.Count)"
Write-Host "Slim AI prompt: $(Get-RelativePortablePath -BasePath $weeklyRoot -Path $outputSlimAi)"
Write-Host "Registry: $registryRelativePath"
Write-Host "Markdown: $(Get-RelativePortablePath -BasePath $weeklyRoot -Path $outputMd)"
Write-Host "HTML: $(Get-RelativePortablePath -BasePath $weeklyRoot -Path $outputHtml)"
return
