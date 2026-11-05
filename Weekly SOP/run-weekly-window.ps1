param(
  [ValidateSet('auto', '7d', '28d')]
  [string]$Window = 'auto',
  [string]$InputFile,
  [string]$RuntimeRoot,
  [ValidateSet('auto', 'api', 'manual_zip')]
  [string]$ImportSource = 'auto',
  [switch]$RepairIncompleteCurrentEndDate
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

function Test-IsZipFile {
  param([string]$Path)
  $fs = [System.IO.File]::OpenRead($Path)
  try {
    if ($fs.Length -lt 2) { return $false }
    $b1 = $fs.ReadByte()
    $b2 = $fs.ReadByte()
    return ($b1 -eq 0x50 -and $b2 -eq 0x4B)
  } finally {
    $fs.Dispose()
  }
}

function Test-NumericMetric {
  param([string]$Value)
  if ([string]::IsNullOrWhiteSpace($Value)) { return $false }
  $clean = $Value.Trim().TrimEnd('%') -replace ',', ''
  $parsed = 0.0
  return [double]::TryParse(
    $clean,
    [System.Globalization.NumberStyles]::Float,
    [System.Globalization.CultureInfo]::InvariantCulture,
    [ref]$parsed
  )
}

function Test-InputNameMatches {
  param(
    [string]$Name,
    [string[]]$ExpectedNames
  )
  foreach ($expected in $ExpectedNames) {
    if ($Name -ieq $expected) { return $true }
  }
  return $false
}

function Get-ZipEntryNames {
  param([string]$Path)
  Add-Type -AssemblyName System.IO.Compression.FileSystem -ErrorAction SilentlyContinue
  $zip = [System.IO.Compression.ZipFile]::OpenRead($Path)
  try {
    return @($zip.Entries | ForEach-Object { [System.IO.Path]::GetFileName($_.FullName) } | Where-Object { $_ })
  } finally {
    $zip.Dispose()
  }
}

function Test-ArchiveContainsPerformanceSet {
  param([string]$Path)
  try {
    $names = @(Get-ZipEntryNames -Path $Path)
    $hasQuery = ($names | Where-Object { Test-InputNameMatches -Name $_ -ExpectedNames @('查詢.csv', 'query.csv', 'queries.csv') }).Count -gt 0
    $hasPage = ($names | Where-Object { Test-InputNameMatches -Name $_ -ExpectedNames @('網頁.csv', 'page.csv', 'pages.csv') }).Count -gt 0
    $hasFilter = ($names | Where-Object { Test-InputNameMatches -Name $_ -ExpectedNames @('篩選器.csv', 'filters.csv') }).Count -gt 0
    return ($hasQuery -and $hasPage -and $hasFilter)
  } catch {
    return $false
  }
}

function Get-OptionalQueryPageCsv {
  param([string]$ExtractDir)
  return Find-CsvByName -ExtractDir $ExtractDir -ExpectedNames @(
    'query-page.csv', 'query_page.csv', 'query-pages.csv', 'queries-pages.csv',
    '查詢x網頁.csv', '查詢×網頁.csv', '查詢-網頁.csv'
  )
}

function Get-OptionalDiagnosticCsv {
  param([string]$ExtractDir, [ValidateSet('date', 'date_page', 'device_page', 'country_page', 'device_query')][string]$Kind)
  $names = switch ($Kind) {
    'date' { @('date.csv', '日期.csv') }
    'date_page' { @('date-page.csv', 'date_page.csv', '日期-網頁.csv', '日期×網頁.csv') }
    'device_page' { @('device-page.csv', 'device_page.csv', '裝置-網頁.csv', '裝置×網頁.csv') }
    'country_page' { @('country-page.csv', 'country_page.csv', '國家-網頁.csv', '國家×網頁.csv') }
    'device_query' { @('device-query.csv', 'device_query.csv', '裝置-查詢.csv', '裝置×查詢.csv') }
  }
  return Find-CsvByName -ExtractDir $ExtractDir -ExpectedNames $names
}

function Convert-GscMetric {
  param(
    [string]$Value,
    [string]$Name,
    [int]$RowNumber,
    [double]$Minimum = 0.0,
    [double]$Maximum = [double]::PositiveInfinity
  )
  if (-not (Test-NumericMetric -Value $Value)) {
    throw "Invalid ${Name} at CSV row ${RowNumber}: '$Value'"
  }
  $clean = $Value.Trim().TrimEnd('%') -replace ',', ''
  $parsed = 0.0
  $null = [double]::TryParse($clean, [System.Globalization.NumberStyles]::Float, [System.Globalization.CultureInfo]::InvariantCulture, [ref]$parsed)
  if ($parsed -lt $Minimum -or $parsed -gt $Maximum) {
    throw "Out-of-range ${Name} at CSV row ${RowNumber}: '$Value'"
  }
  return $parsed
}

function Get-FileSha256 {
  param([string]$Path)
  return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash
}

function Find-ArchivedZipByHash {
  param(
    [string]$ArchiveRoot,
    [string]$Hash
  )
  if ([string]::IsNullOrWhiteSpace($Hash)) { return '' }
  if (-not (Test-Path -LiteralPath $ArchiveRoot -PathType Container)) { return '' }

  foreach ($file in Get-ChildItem -LiteralPath $ArchiveRoot -Recurse -File -Filter '*.zip' -ErrorAction SilentlyContinue) {
    try {
      if ((Get-FileSha256 -Path $file.FullName) -eq $Hash) {
        return $file.FullName
      }
    } catch {
      # Ignore unreadable archives and continue checking the rest.
    }
  }
  return ''
}

function Find-LatestPerformanceZip {
  param([string]$InputDir)
  $files = Get-ChildItem -LiteralPath $InputDir -File -Filter '*.zip' |
    Sort-Object LastWriteTime -Descending

  foreach ($file in $files) {
    if ((Test-IsZipFile -Path $file.FullName) -and (Test-ArchiveContainsPerformanceSet -Path $file.FullName)) {
      return $file
    }
  }

  throw "No GSC Search Performance ZIP found in $InputDir. Need a ZIP containing 查詢.csv, 網頁.csv, and 篩選器.csv."
}

function Read-CsvUtf8OrDefault {
  param([string]$Path)
  try {
    return Import-Csv -LiteralPath $Path -Encoding UTF8
  } catch {
    return Import-Csv -LiteralPath $Path
  }
}

function Get-FirstPropValue {
  param(
    [object]$Row,
    [string[]]$Names
  )
  foreach ($n in $Names) {
    $p = $Row.PSObject.Properties[$n]
    if ($null -ne $p -and -not [string]::IsNullOrWhiteSpace([string]$p.Value)) {
      return [string]$p.Value
    }
  }
  return ''
}

function Get-PropByIndex {
  param(
    [object]$Row,
    [int]$Index
  )
  $names = @($Row.PSObject.Properties.Name)
  if ($Index -ge 0 -and $Index -lt $names.Count) {
    return [string]$Row.($names[$Index])
  }
  return ''
}

function Normalize-Rows {
  param(
    [object[]]$Rows,
    [ValidateSet('query', 'page', 'query_page')]
    [string]$Kind
  )

  $out = @()
  $validMetricRows = 0
  $rowNumber = 1
  foreach ($row in $Rows) {
    $rowNumber++
    $propNames = @($row.PSObject.Properties.Name)

    if ($Kind -eq 'query') {
      $query = Get-FirstPropValue -Row $row -Names @('query', 'Query', '熱門查詢項目', '查詢')
      if ([string]::IsNullOrWhiteSpace($query)) { $query = Get-PropByIndex -Row $row -Index 0 }
      if ([string]::IsNullOrWhiteSpace($query)) { continue }
      $page = '(all pages)'
    } elseif ($Kind -eq 'page') {
      $hasPageHeader = ($propNames | Where-Object { $_ -in @('page', 'Page', 'url', 'URL', '熱門網頁', '網頁', '頁面') }).Count -gt 0
      $page = Get-FirstPropValue -Row $row -Names @('page', 'Page', 'url', 'URL', '熱門網頁', '網頁', '頁面')
      if ([string]::IsNullOrWhiteSpace($page)) { $page = Get-PropByIndex -Row $row -Index 0 }
      if ([string]::IsNullOrWhiteSpace($page)) { continue }
      $query = '(all queries)'
    } else {
      $query = Get-FirstPropValue -Row $row -Names @('query', 'Query', '熱門查詢項目', '查詢')
      if ([string]::IsNullOrWhiteSpace($query)) { $query = Get-PropByIndex -Row $row -Index 0 }
      $page = Get-FirstPropValue -Row $row -Names @('page', 'Page', 'url', 'URL', '熱門網頁', '網頁', '頁面')
      if ([string]::IsNullOrWhiteSpace($page)) { $page = Get-PropByIndex -Row $row -Index 1 }
      if ([string]::IsNullOrWhiteSpace($query) -or [string]::IsNullOrWhiteSpace($page)) {
        throw "Query × Page export has an empty query or page at CSV row $rowNumber."
      }
    }

    $clicks = Get-FirstPropValue -Row $row -Names @('clicks', 'Clicks', '點擊')
    if ([string]::IsNullOrWhiteSpace($clicks)) { $clicks = Get-PropByIndex -Row $row -Index 1 }

    $impr = Get-FirstPropValue -Row $row -Names @('impressions', 'Impressions', '曝光')
    if ([string]::IsNullOrWhiteSpace($impr)) { $impr = Get-PropByIndex -Row $row -Index 2 }

    $ctr = Get-FirstPropValue -Row $row -Names @('ctr', 'CTR', '點閱率')
    if ([string]::IsNullOrWhiteSpace($ctr)) { $ctr = Get-PropByIndex -Row $row -Index 3 }

    $pos = Get-FirstPropValue -Row $row -Names @('position', 'Position', '排名')
    if ([string]::IsNullOrWhiteSpace($pos)) { $pos = Get-PropByIndex -Row $row -Index 4 }

    $clickValue = Convert-GscMetric -Value $clicks -Name 'clicks' -RowNumber $rowNumber
    $imprValue = Convert-GscMetric -Value $impr -Name 'impressions' -RowNumber $rowNumber
    $ctrValue = Convert-GscMetric -Value $ctr -Name 'CTR' -RowNumber $rowNumber -Maximum 100
    $positionValue = Convert-GscMetric -Value $pos -Name 'position' -RowNumber $rowNumber -Minimum 0.000001
    if ($clickValue -gt $imprValue) { throw "Clicks exceed impressions at CSV row $rowNumber." }
    $expectedCtr = if ($imprValue -gt 0) { ($clickValue / $imprValue) * 100.0 } else { 0.0 }
    if ([Math]::Abs($ctrValue - $expectedCtr) -gt 0.15) { throw "CTR is inconsistent with clicks/impressions at CSV row $rowNumber." }
    if ($Kind -eq 'query' -and $query -notmatch '^https?://') { $validMetricRows++ }
    if ($Kind -eq 'page' -and ($hasPageHeader -or $page -match '^https?://')) { $validMetricRows++ }
    if ($Kind -eq 'query_page' -and $query -notmatch '^https?://' -and $page -match '^https?://') { $validMetricRows++ }

    $out += [PSCustomObject]@{
      query       = $query
      page        = $page
      clicks      = $clicks
      impressions = $impr
      ctr         = $ctr
      position    = $pos
    }
  }

  if ($validMetricRows -eq 0) {
    throw "Input does not look like a GSC Search Performance $Kind export. Use the Performance ZIP that contains 查詢.csv and 網頁.csv."
  }

  return $out
}

function Normalize-Csv {
  param(
    [string]$CsvPath,
    [string]$OutputPath,
    [ValidateSet('query', 'page', 'query_page')]
    [string]$Kind
  )
  Ensure-Dir -Path (Split-Path -Parent $OutputPath)
  $rows = Read-CsvUtf8OrDefault -Path $CsvPath
  $norm = Normalize-Rows -Rows $rows -Kind $Kind
  if (-not $norm -or $norm.Count -eq 0) {
    throw "Could not normalize rows from input: $CsvPath"
  }
  $norm | Export-Csv -LiteralPath $OutputPath -NoTypeInformation -Encoding UTF8
}

function Find-CsvByName {
  param(
    [string]$ExtractDir,
    [string[]]$ExpectedNames
  )
  $csvFiles = Get-ChildItem -LiteralPath $ExtractDir -Recurse -File -Filter '*.csv'
  return ($csvFiles | Where-Object {
    Test-InputNameMatches -Name $_.Name -ExpectedNames $ExpectedNames
  } | Select-Object -First 1)
}

function Read-WindowFromFilter {
  param([string]$FilterCsv)
  $rows = Read-CsvUtf8OrDefault -Path $FilterCsv
  foreach ($row in $rows) {
    $key = Get-FirstPropValue -Row $row -Names @('篩選器', 'Filter')
    $value = Get-FirstPropValue -Row $row -Names @('值', 'Value')
    if ($key -match '日期|Date') {
      $m = [regex]::Match($value, '(\d+)')
      $dateMatches = [regex]::Matches($value, '(?<year>20\d{2})[\/-](?<month>\d{1,2})[\/-](?<day>\d{1,2})')
      $startDate = $null
      $endDate = $null
      if ($dateMatches.Count -ge 2) {
        try {
          $startDate = (Get-Date -Year $dateMatches[0].Groups['year'].Value -Month $dateMatches[0].Groups['month'].Value -Day $dateMatches[0].Groups['day'].Value).ToString('yyyy-MM-dd')
          $endDate = (Get-Date -Year $dateMatches[1].Groups['year'].Value -Month $dateMatches[1].Groups['month'].Value -Day $dateMatches[1].Groups['day'].Value).ToString('yyyy-MM-dd')
        } catch { throw "Invalid explicit date range in 篩選器.csv: $value" }
      }
      if ($m.Success -or ($startDate -and $endDate)) {
        $days = if ($startDate -and $endDate) {
          (([datetime]::ParseExact($endDate, 'yyyy-MM-dd', [Globalization.CultureInfo]::InvariantCulture) - [datetime]::ParseExact($startDate, 'yyyy-MM-dd', [Globalization.CultureInfo]::InvariantCulture)).Days + 1)
        } else { [int]$m.Groups[1].Value }
        if ($days -eq 7) { return @{ Slug = '7d'; Label = '前 7 天'; Days = 7; Title = '7天'; VerdictMode = 'observation'; FilterKey = $key; FilterValue = $value; StartDate = $startDate; EndDate = $endDate } }
        if ($days -eq 28) { return @{ Slug = '28d'; Label = '前 28 天'; Days = 28; Title = '28天'; VerdictMode = 'decision'; FilterKey = $key; FilterValue = $value; StartDate = $startDate; EndDate = $endDate } }
      }
      return @{ Slug = 'unknown'; Label = $value; Days = 0; Title = '未知區間'; VerdictMode = 'decision'; FilterKey = $key; FilterValue = $value }
    }
  }
  return @{ Slug = 'unknown'; Label = 'unknown'; Days = 0; Title = '未知區間'; VerdictMode = 'decision'; FilterKey = ''; FilterValue = '' }
}

function Read-DateRangeFromInputName {
  param([string]$Name)
  $match = [regex]::Match($Name, '(?<start>20\d{2}[-_/]\d{1,2}[-_/]\d{1,2})\s*(?:~|～|至|to)\s*(?<end>20\d{2}[-_/]\d{1,2}[-_/]\d{1,2})', [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
  if (-not $match.Success) { return $null }
  try {
    $start = [datetime]::ParseExact(($match.Groups['start'].Value -replace '[_/]', '-'), 'yyyy-M-d', [Globalization.CultureInfo]::InvariantCulture)
    $end = [datetime]::ParseExact(($match.Groups['end'].Value -replace '[_/]', '-'), 'yyyy-M-d', [Globalization.CultureInfo]::InvariantCulture)
    if ($end -lt $start) { throw 'end date precedes start date' }
    return [ordered]@{ StartDate = $start.ToString('yyyy-MM-dd'); EndDate = $end.ToString('yyyy-MM-dd'); Source = 'zip_filename' }
  } catch {
    throw "Invalid date range in ZIP filename '$Name': $($_.Exception.Message)"
  }
}

function Test-CompleteDateRange {
  param([string]$StartDate, [string]$EndDate, [int]$Days)
  if ([string]::IsNullOrWhiteSpace($StartDate) -or [string]::IsNullOrWhiteSpace($EndDate)) { return $false }
  try {
    $start = [datetime]::ParseExact($StartDate, 'yyyy-MM-dd', [Globalization.CultureInfo]::InvariantCulture)
    $end = [datetime]::ParseExact($EndDate, 'yyyy-MM-dd', [Globalization.CultureInfo]::InvariantCulture)
    return (($end - $start).Days + 1 -eq $Days)
  } catch { return $false }
}

function Initialize-Baseline {
  param(
    [string]$BaselinePath,
    [ValidateSet('query', 'page')]
    [string]$Kind,
    [string]$Window,
    [string]$WeeklyRoot,
    [string]$RepoRoot,
    [string]$SeedNormalizedPath
  )

  if (Test-Path -LiteralPath $BaselinePath -PathType Leaf) { return }
  Ensure-Dir -Path (Split-Path -Parent $BaselinePath)

  if ($Window -eq '7d') {
    $legacy = if ($Kind -eq 'query') {
      Join-Path $WeeklyRoot 'history\current_query_baseline.normalized.csv'
    } else {
      Join-Path $WeeklyRoot 'history\current_baseline.normalized.csv'
    }
    if (Test-Path -LiteralPath $legacy -PathType Leaf) {
      Copy-Item -LiteralPath $legacy -Destination $BaselinePath -Force
      return
    }
    throw "Missing 7d $Kind baseline. To avoid mixing 7d with 28d data, create the first 7d baseline from a previous 7-day Search Performance export."
  }

  # 28d fallback priority:
  # 1) Weekly SOP legacy baseline (same folder)
  # 2) repo historical gsc-data extracted csv
  # 3) seed with current normalized input (first run bootstrap)
  $legacyBaseline = if ($Kind -eq 'query') {
    Join-Path $WeeklyRoot 'history\current_query_baseline.normalized.csv'
  } else {
    Join-Path $WeeklyRoot 'history\current_baseline.normalized.csv'
  }
  if (Test-Path -LiteralPath $legacyBaseline -PathType Leaf) {
    Copy-Item -LiteralPath $legacyBaseline -Destination $BaselinePath -Force
    return
  }

  $fallbackCsv = if ($Kind -eq 'query') {
    Join-Path $RepoRoot 'scripts\gsc-data\after_28d_extracted\查詢.csv'
  } else {
    Join-Path $RepoRoot 'scripts\gsc-data\after_28d_extracted\網頁.csv'
  }

  if (Test-Path -LiteralPath $fallbackCsv -PathType Leaf) {
    Normalize-Csv -CsvPath $fallbackCsv -OutputPath $BaselinePath -Kind $Kind
    return
  }

  if ((-not [string]::IsNullOrWhiteSpace($SeedNormalizedPath)) -and (Test-Path -LiteralPath $SeedNormalizedPath -PathType Leaf)) {
    Copy-Item -LiteralPath $SeedNormalizedPath -Destination $BaselinePath -Force
    return
  }

  throw "Missing $Window $Kind baseline. Checked legacy baseline, repo fallback CSV, and seed normalized path."
}

function Invoke-KpiReport {
  param(
    [string]$RepoRoot,
    [string]$Before,
    [string]$After,
    [string]$Output,
    [string]$FullOutput,
    [string]$TitleSuffix,
    [string]$PeriodLabel,
    [string]$TrackingStartDate,
    [string]$VerdictMode,
    [int]$MinImpr,
    [int]$Limit,
    [int]$FullMinImpr,
    [int]$MainQueryLimit,
    [int]$MainPageLimit,
    [int]$SeoGeoTotal,
    [int]$SeoGeoQueryCount,
    [int]$SeoGeoPageCount
  )

  Push-Location $RepoRoot
  try {
    $nodeArgs = @(
      'scripts/gsc-kpi-diff-from-csv.mjs',
      '--before', $Before,
      '--after', $After,
      '--output', $Output,
      '--full-output', $FullOutput,
      '--full-min-impr', $FullMinImpr,
      '--title-suffix', $TitleSuffix,
      '--period-label', $PeriodLabel,
      '--tracking-start-date', $TrackingStartDate,
      '--verdict-mode', $VerdictMode,
      '--min-impr', $MinImpr,
      '--limit', $Limit,
      '--main-query-limit', $MainQueryLimit,
      '--main-page-limit', $MainPageLimit,
      '--seo-geo-total', $SeoGeoTotal,
      '--seo-geo-query-count', $SeoGeoQueryCount,
      '--seo-geo-page-count', $SeoGeoPageCount
    )
    & node @nodeArgs
    if ($LASTEXITCODE -ne 0) {
      throw "Node command failed with exit code $LASTEXITCODE"
    }
  } finally {
    Pop-Location
  }
}

function Set-KpiReportSourceLabels {
  param(
    [string[]]$ReportPaths,
    [string]$BeforePath,
    [string]$AfterPath,
    [string]$BeforeLabel,
    [string]$AfterLabel
  )

  $beforeFull = [System.IO.Path]::GetFullPath($BeforePath)
  $afterFull = [System.IO.Path]::GetFullPath($AfterPath)
  $utf8NoBom = New-Object System.Text.UTF8Encoding($false)

  foreach ($reportPath in $ReportPaths) {
    if (-not (Test-Path -LiteralPath $reportPath -PathType Leaf)) {
      throw "Missing report while normalizing source labels: $reportPath"
    }

    $content = [System.IO.File]::ReadAllText($reportPath, [System.Text.Encoding]::UTF8)
    foreach ($beforeVariant in @($beforeFull, $beforeFull.Replace('\', '/'))) {
      $content = $content.Replace($beforeVariant, $BeforeLabel)
    }
    foreach ($afterVariant in @($afterFull, $afterFull.Replace('\', '/'))) {
      $content = $content.Replace($afterVariant, $AfterLabel)
    }
    [System.IO.File]::WriteAllText($reportPath, $content, $utf8NoBom)
  }
}

function Write-RunManifest {
  param(
    [string]$Path,
    [hashtable]$Data
  )
  Ensure-Dir -Path (Split-Path -Parent $Path)
  $json = $Data | ConvertTo-Json -Depth 8
  try {
    $null = $json | ConvertFrom-Json -ErrorAction Stop
  } catch {
    throw "Refusing to write invalid manifest JSON: $($_.Exception.Message)"
  }
  $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
  $tempPath = "$Path.tmp.$PID"
  try {
    [System.IO.File]::WriteAllText($tempPath, $json, $utf8NoBom)
    $roundTrip = [System.IO.File]::ReadAllText($tempPath, [System.Text.Encoding]::UTF8)
    $null = $roundTrip | ConvertFrom-Json -ErrorAction Stop
    Move-Item -LiteralPath $tempPath -Destination $Path -Force
  } finally {
    if (Test-Path -LiteralPath $tempPath -PathType Leaf) {
      Remove-Item -LiteralPath $tempPath -Force
    }
  }
}

function Read-SiteConfig {
  param([string]$Path)

  if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
    throw "Missing site config: $Path"
  }

  try {
    $configText = [System.IO.File]::ReadAllText($Path, [System.Text.Encoding]::UTF8)
    $config = $configText | ConvertFrom-Json -ErrorAction Stop
  } catch {
    throw "Invalid site config JSON: $($_.Exception.Message)"
  }

  foreach ($field in @('siteId', 'siteUrl', 'expectedHost', 'gscProperty')) {
    if ([string]::IsNullOrWhiteSpace([string]$config.$field)) {
      throw "Site config is missing required field: $field"
    }
  }

  $expectedHost = ([string]$config.expectedHost).Trim().TrimEnd('.').ToLowerInvariant()
  $allowedHosts = @($config.allowedHosts | ForEach-Object { ([string]$_).Trim().TrimEnd('.').ToLowerInvariant() } | Where-Object { $_ })
  if ($allowedHosts.Count -eq 0) {
    $allowedHosts = @($expectedHost)
  }
  if ($allowedHosts -notcontains $expectedHost) {
    throw "Site config allowedHosts must include expectedHost: $expectedHost"
  }

  $config.expectedHost = $expectedHost
  $config.allowedHosts = $allowedHosts
  return $config
}

function Convert-ToRelativePath {
  param(
    [string]$Path,
    [string]$BaseRoot
  )

  if ([string]::IsNullOrWhiteSpace($Path)) { return $null }
  $root = [System.IO.Path]::GetFullPath($BaseRoot).TrimEnd('\', '/')
  $full = [System.IO.Path]::GetFullPath($Path)
  $prefix = $root + [System.IO.Path]::DirectorySeparatorChar
  if (-not $full.StartsWith($prefix, [System.StringComparison]::OrdinalIgnoreCase)) {
    throw "Path is outside the configured base and cannot be stored in manifest: $full"
  }
  return $full.Substring($prefix.Length).Replace('\', '/')
}

function Test-PageHosts {
  param(
    [string]$NormalizedPageCsv,
    [string]$ExpectedHost,
    [string[]]$AllowedHosts
  )

  $rows = @(Import-Csv -LiteralPath $NormalizedPageCsv -Encoding UTF8)
  $hostCounts = @{}
  $targetRows = 0
  $foreignRows = 0
  $invalidRows = 0

  foreach ($row in $rows) {
    $value = [string]$row.page
    $uri = $null
    if (-not [Uri]::TryCreate($value, [UriKind]::Absolute, [ref]$uri) -or $uri.Scheme -notin @('http', 'https')) {
      $invalidRows++
      continue
    }

    $rowHost = $uri.Host.Trim().TrimEnd('.').ToLowerInvariant()
    if (-not $hostCounts.ContainsKey($rowHost)) { $hostCounts[$rowHost] = 0 }
    $hostCounts[$rowHost] = [int]$hostCounts[$rowHost] + 1
    if ($rowHost -eq $ExpectedHost) { $targetRows++ }
    if ($AllowedHosts -notcontains $rowHost) { $foreignRows++ }
  }

  $hostSummary = (($hostCounts.GetEnumerator() | Sort-Object Name | ForEach-Object { "$($_.Name)=$($_.Value)" }) -join ', ')
  if ($targetRows -eq 0 -or $foreignRows -gt 0 -or $invalidRows -gt 0) {
    throw "GSC host validation failed. expected=$ExpectedHost target_rows=$targetRows foreign_rows=$foreignRows invalid_rows=$invalidRows hosts=[$hostSummary]"
  }

  return [ordered]@{
    total = $rows.Count
    target = $targetRows
    foreign = $foreignRows
    invalid = $invalidRows
    hosts = $hostCounts
  }
}

function Set-AtomicFileFromSource {
  param(
    [string]$Source,
    [string]$Destination
  )

  Ensure-Dir -Path (Split-Path -Parent $Destination)
  $tempPath = "$Destination.tmp.$PID"
  try {
    Copy-Item -LiteralPath $Source -Destination $tempPath -Force
    Move-Item -LiteralPath $tempPath -Destination $Destination -Force
  } finally {
    if (Test-Path -LiteralPath $tempPath -PathType Leaf) {
      Remove-Item -LiteralPath $tempPath -Force
    }
  }
}

function Save-DiagnosticHistory {
  param(
    [Parameter(Mandatory = $true)][string]$Source,
    [Parameter(Mandatory = $true)][ValidateSet('date', 'date_page', 'device_page', 'country_page', 'device_query')][string]$Kind,
    [Parameter(Mandatory = $true)][string]$WindowHistoryDir,
    [Parameter(Mandatory = $true)][string]$StartDate,
    [Parameter(Mandatory = $true)][string]$EndDate,
    [Parameter(Mandatory = $true)][string]$WeeklyRoot
  )

  $snapshotDir = Join-Path $WindowHistoryDir ("diagnostics\snapshots\{0}_{1}" -f $StartDate, $EndDate)
  $snapshotPath = Join-Path $snapshotDir "$Kind.csv"
  Set-AtomicFileFromSource -Source $Source -Destination $snapshotPath

  $sourceRows = @(Import-Csv -LiteralPath $Source -Encoding UTF8)
  $datedRows = @($sourceRows | Where-Object { [string]$_.date -match '^\d{4}-\d{2}-\d{2}$' })
  $dailyPath = Join-Path $WindowHistoryDir "diagnostics\daily\$Kind.csv"
  $accumulationStatus = 'available'
  $accumulationReason = $null

  if ($datedRows.Count -gt 0) {
    $keyColumns = switch ($Kind) {
      'date' { @('date') }
      'date_page' { @('date', 'page') }
      'device_page' { @('date', 'device', 'page') }
      'country_page' { @('date', 'country', 'page') }
      'device_query' { @('date', 'device', 'query') }
    }
    $merged = @{}
    if (Test-Path -LiteralPath $dailyPath -PathType Leaf) {
      foreach ($row in @(Import-Csv -LiteralPath $dailyPath -Encoding UTF8)) {
        $key = ($keyColumns | ForEach-Object { [string]$row.$_ }) -join "`u{001f}"
        if ($key) { $merged[$key] = $row }
      }
    }
    foreach ($row in $datedRows) {
      $key = ($keyColumns | ForEach-Object { [string]$row.$_ }) -join "`u{001f}"
      if ($key) { $merged[$key] = $row }
    }
    Ensure-Dir -Path (Split-Path -Parent $dailyPath)
    $dailyTemp = "$dailyPath.tmp.$PID.$([guid]::NewGuid().ToString('N'))"
    try {
      @($merged.Values | Sort-Object @($keyColumns | ForEach-Object { @{ Expression = [string]$_; Descending = $false } })) |
        Export-Csv -LiteralPath $dailyTemp -NoTypeInformation -Encoding UTF8
      Move-Item -LiteralPath $dailyTemp -Destination $dailyPath -Force
    } finally {
      if (Test-Path -LiteralPath $dailyTemp -PathType Leaf) { Remove-Item -LiteralPath $dailyTemp -Force }
    }
  } else {
    $accumulationStatus = 'unavailable'
    $accumulationReason = 'snapshot lacks a Date column; preserved as a dated window snapshot only'
  }

  $dailyRows = if (Test-Path -LiteralPath $dailyPath -PathType Leaf) { @(Import-Csv -LiteralPath $dailyPath -Encoding UTF8) } else { @() }
  $dailyDates = @($dailyRows | ForEach-Object { [string]$_.date } | Where-Object { $_ -match '^\d{4}-\d{2}-\d{2}$' } | Sort-Object -Unique)
  return [ordered]@{
    snapshot = [ordered]@{
      path = Convert-ToRelativePath -Path $snapshotPath -BaseRoot $WeeklyRoot
      row_count = $sourceRows.Count
      sha256 = Get-FileSha256 -Path $snapshotPath
      start_date = $StartDate
      end_date = $EndDate
    }
    daily_history = [ordered]@{
      status = $accumulationStatus
      reason = $accumulationReason
      path = if (Test-Path -LiteralPath $dailyPath -PathType Leaf) { Convert-ToRelativePath -Path $dailyPath -BaseRoot $WeeklyRoot } else { $null }
      row_count = $dailyRows.Count
      sha256 = if (Test-Path -LiteralPath $dailyPath -PathType Leaf) { Get-FileSha256 -Path $dailyPath } else { $null }
      start_date = if ($dailyDates.Count -gt 0) { $dailyDates[0] } else { $null }
      end_date = if ($dailyDates.Count -gt 0) { $dailyDates[-1] } else { $null }
      dedupe_key = switch ($Kind) {
        'date' { 'date' }
        'date_page' { 'date|page' }
        'device_page' { 'date|device|page' }
        'country_page' { 'date|country|page' }
        'device_query' { 'date|device|query' }
      }
    }
  }
}

function Set-AtomicBaselinePair {
  param(
    [string]$QuerySource, [string]$QueryDestination,
    [string]$PageSource, [string]$PageDestination,
    [string]$QueryPageSource, [string]$QueryPageDestination
  )
  $entries = @(
    [PSCustomObject]@{ source = $QuerySource; destination = $QueryDestination },
    [PSCustomObject]@{ source = $PageSource; destination = $PageDestination }
  )
  if ($QueryPageSource) { $entries += [PSCustomObject]@{ source = $QueryPageSource; destination = $QueryPageDestination } }
  $token = "$PID.$([guid]::NewGuid().ToString('N'))"
  $backups = @()
  try {
    foreach ($entry in $entries) {
      Ensure-Dir -Path (Split-Path -Parent $entry.destination)
      $stage = "$($entry.destination).stage.$token"
      Copy-Item -LiteralPath $entry.source -Destination $stage -Force
      $entry | Add-Member -NotePropertyName stage -NotePropertyValue $stage
      $backup = "$($entry.destination).backup.$token"
      if (Test-Path -LiteralPath $entry.destination) { Copy-Item -LiteralPath $entry.destination -Destination $backup -Force; $backups += $entry.destination }
      $entry | Add-Member -NotePropertyName backup -NotePropertyValue $backup
    }
    foreach ($entry in $entries) { Move-Item -LiteralPath $entry.stage -Destination $entry.destination -Force }
  } catch {
    foreach ($entry in $entries) {
      if (Test-Path -LiteralPath $entry.backup) { Move-Item -LiteralPath $entry.backup -Destination $entry.destination -Force }
      elseif (Test-Path -LiteralPath $entry.destination -and $backups -notcontains $entry.destination) { Remove-Item -LiteralPath $entry.destination -Force }
    }
    throw
  } finally {
    foreach ($entry in $entries) {
      if (Test-Path -LiteralPath $entry.stage) { Remove-Item -LiteralPath $entry.stage -Force }
      if (Test-Path -LiteralPath $entry.backup) { Remove-Item -LiteralPath $entry.backup -Force }
    }
  }
}

$weeklyRoot = if ([string]::IsNullOrWhiteSpace($RuntimeRoot)) {
  Join-Path $PSScriptRoot '.'
} else {
  [System.IO.Path]::GetFullPath($RuntimeRoot)
}
$repoRoot = Split-Path -Parent $PSScriptRoot
$siteConfigPath = Join-Path $PSScriptRoot 'config\site-config.json'
$siteConfig = Read-SiteConfig -Path $siteConfigPath
$siteId = [string]$siteConfig.siteId
$expectedHost = [string]$siteConfig.expectedHost
$allowedHosts = @($siteConfig.allowedHosts)
$timezoneId = [string]$siteConfig.timezone
$dataLagDays = [int]$siteConfig.dataLagDays
$inboxDir = Join-Path $weeklyRoot 'inbox'
$archiveDir = Join-Path $weeklyRoot 'archive'
$historyDir = Join-Path $weeklyRoot 'history'
$reportsDir = Join-Path $weeklyRoot 'reports'
$latestRoot = Join-Path $weeklyRoot 'latest'

Ensure-Dir -Path $inboxDir
Ensure-Dir -Path $archiveDir
Ensure-Dir -Path $historyDir
Ensure-Dir -Path $reportsDir
Ensure-Dir -Path $latestRoot

$siteArchiveDir = Join-Path $archiveDir $siteId
$siteHistoryDir = Join-Path $historyDir $siteId
$siteReportsDir = Join-Path $reportsDir $siteId
Ensure-Dir -Path $siteArchiveDir
Ensure-Dir -Path $siteHistoryDir
Ensure-Dir -Path $siteReportsDir

$tmpDir = $null
$incoming = $null
$inputMode = 'inbox'
$inputHash = ''
$effectiveWindow = $null
$runDir = $null
$baselineCommitted = $false

try {
  if (-not [string]::IsNullOrWhiteSpace($InputFile)) {
    $resolved = (Resolve-Path -LiteralPath $InputFile -ErrorAction Stop).Path
    if (-not (Test-Path -LiteralPath $resolved -PathType Leaf)) {
      throw "Input file not found: $InputFile"
    }
    $ext = [System.IO.Path]::GetExtension($resolved).ToLowerInvariant()
    if ($ext -ne '.zip') {
      throw "The 7d/28d workflow requires a GSC Search Performance ZIP because 篩選器.csv is needed to verify the date range."
    }
    if (-not (Test-IsZipFile -Path $resolved)) {
      throw "Input is not a valid ZIP file: $resolved"
    }
    $incoming = Get-Item -LiteralPath $resolved
    $inputMode = 'direct'
  } else {
    $incoming = Find-LatestPerformanceZip -InputDir $inboxDir
  }

  if (-not (Test-ArchiveContainsPerformanceSet -Path $incoming.FullName)) {
    throw "This is not a complete GSC Search Performance ZIP. Need 查詢.csv, 網頁.csv, and 篩選器.csv. Coverage/Indexing ZIP exports are not supported."
  }

  $inputHash = Get-FileSha256 -Path $incoming.FullName
  $duplicateArchive = Find-ArchivedZipByHash -ArchiveRoot $siteArchiveDir -Hash $inputHash
  if (-not [string]::IsNullOrWhiteSpace($duplicateArchive)) {
    $duplicateRelative = Convert-ToRelativePath -Path $duplicateArchive -BaseRoot $weeklyRoot
    $duplicateManifest = @{
      schema_version = 2
      status = 'duplicate_input'
      run_time = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
      requested_window = $Window
      site_id = $siteId
      property = [string]$siteConfig.gscProperty
      expected_host = $expectedHost
      input_mode = $inputMode
      input_file = $incoming.Name
      input_sha256 = $inputHash
      path_base = 'weekly_sop'
      duplicate_of = $duplicateRelative
      message = 'This GSC ZIP was already archived. Baseline was not updated.'
    }
    Write-RunManifest -Path (Join-Path $latestRoot 'weekly-sop-last-run.json') -Data $duplicateManifest
    Write-Host "Duplicate GSC ZIP detected. Baseline was not updated."
    Write-Host "Input SHA256: $inputHash"
    Write-Host "Duplicate of: $duplicateRelative"
    exit 2
  }

  # Include milliseconds + PID to avoid same-second temp/report collisions.
  $stamp = "{0}_{1}" -f (Get-Date -Format 'yyyy-MM-dd_HHmmss_fff'), $PID
  $tmpDir = Join-Path $weeklyRoot "_tmp_window_$stamp"
  Ensure-Dir -Path $tmpDir

  Expand-Archive -LiteralPath $incoming.FullName -DestinationPath $tmpDir -Force

  $queryCsv = Find-CsvByName -ExtractDir $tmpDir -ExpectedNames @('查詢.csv', 'query.csv', 'queries.csv')
  $pageCsv = Find-CsvByName -ExtractDir $tmpDir -ExpectedNames @('網頁.csv', 'page.csv', 'pages.csv')
  $filterCsv = Find-CsvByName -ExtractDir $tmpDir -ExpectedNames @('篩選器.csv', 'filters.csv')
  $queryPageCsv = Get-OptionalQueryPageCsv -ExtractDir $tmpDir
  $datePageCsv = Get-OptionalDiagnosticCsv -ExtractDir $tmpDir -Kind 'date_page'
  $devicePageCsv = Get-OptionalDiagnosticCsv -ExtractDir $tmpDir -Kind 'device_page'
  $dateCsv = Get-OptionalDiagnosticCsv -ExtractDir $tmpDir -Kind 'date'
  $countryPageCsv = Get-OptionalDiagnosticCsv -ExtractDir $tmpDir -Kind 'country_page'
  $deviceQueryCsv = Get-OptionalDiagnosticCsv -ExtractDir $tmpDir -Kind 'device_query'

  if (-not $queryCsv) { throw "Missing 查詢.csv in ZIP: $($incoming.FullName)" }
  if (-not $pageCsv) { throw "Missing 網頁.csv in ZIP: $($incoming.FullName)" }
  if (-not $filterCsv) { throw "Missing 篩選器.csv in ZIP: $($incoming.FullName)" }

  $actualWindow = Read-WindowFromFilter -FilterCsv $filterCsv.FullName
  if ($actualWindow.Slug -eq 'unknown') {
    throw "無法從篩選器判斷日期區間：$($actualWindow.Label)。目前只支援前 7 天與前 28 天。"
  }
  $actualWindow.DateSource = if ($actualWindow.StartDate -and $actualWindow.EndDate) { 'filter_csv' } else { 'missing' }
  if (-not $actualWindow.StartDate -or -not $actualWindow.EndDate) {
    $filenameRange = Read-DateRangeFromInputName -Name $incoming.Name
    if ($filenameRange) {
      $filenameDays = (([datetime]::ParseExact($filenameRange.EndDate, 'yyyy-MM-dd', [Globalization.CultureInfo]::InvariantCulture) - [datetime]::ParseExact($filenameRange.StartDate, 'yyyy-MM-dd', [Globalization.CultureInfo]::InvariantCulture)).Days + 1)
      if ($filenameDays -ne [int]$actualWindow.Days) {
        throw "ZIP filename date range is $filenameDays days, but 篩選器.csv is $($actualWindow.Days) days."
      }
      $actualWindow.StartDate = $filenameRange.StartDate
      $actualWindow.EndDate = $filenameRange.EndDate
      $actualWindow.DateSource = $filenameRange.Source
    }
  }

  $effectiveWindow = if ($Window -eq 'auto') { [string]$actualWindow.Slug } else { $Window }
  $resolvedImportSource = if ($ImportSource -ne 'auto') { $ImportSource } elseif ($incoming.Name -like 'gsc-api_*') { 'api' } else { 'manual_zip' }
  if ($Window -ne 'auto' -and $actualWindow.Slug -ne $Window) {
    throw "日期區間不符：目前檔案是 $($actualWindow.Label)，但你執行的是 $Window 模式。請到 GSC 匯出正確區間的 Search Performance ZIP。"
  }

  $windowTitle = [string]$actualWindow.Title
  $periodLabel = [string]$actualWindow.Label
  $verdictMode = [string]$actualWindow.VerdictMode
  $trackingStartDate = Get-Date -Format 'yyyy-MM-dd'
  $detailMinImpr = if ($effectiveWindow -eq '7d') { 1 } else { 20 }
  $detailLimit = if ($effectiveWindow -eq '7d') { 30 } else { 50 }
  $fullDetailMinImpr = 1
  $mainQueryLimit = $detailLimit
  $mainPageLimit = $detailLimit

  $runDir = Join-Path $siteReportsDir ("{0}_{1}" -f $stamp, $effectiveWindow)
  $windowHistoryDir = Join-Path $siteHistoryDir $effectiveWindow
  $latestDir = Join-Path $latestRoot $effectiveWindow

  $normalizedStageDir = Join-Path $tmpDir 'normalized'
  $queryAfter = Join-Path $normalizedStageDir 'query.normalized.csv'
  $pageAfter = Join-Path $normalizedStageDir 'page.normalized.csv'
  $queryPageAfter = if ($queryPageCsv) { Join-Path $normalizedStageDir 'query-page.normalized.csv' } else { $null }
  $datePageDiagnostic = if ($datePageCsv) { Join-Path $windowHistoryDir 'current_date_page_diagnostic.csv' } else { $null }
  $devicePageDiagnostic = if ($devicePageCsv) { Join-Path $windowHistoryDir 'current_device_page_diagnostic.csv' } else { $null }
  $dateDiagnostic = if ($dateCsv) { Join-Path $windowHistoryDir 'current_date_diagnostic.csv' } else { $null }
  $countryPageDiagnostic = if ($countryPageCsv) { Join-Path $windowHistoryDir 'current_country_page_diagnostic.csv' } else { $null }
  $deviceQueryDiagnostic = if ($deviceQueryCsv) { Join-Path $windowHistoryDir 'current_device_query_diagnostic.csv' } else { $null }
  $queryHistoryAfter = Join-Path $windowHistoryDir ("after_query_{0}_{1}.normalized.csv" -f $effectiveWindow, $stamp)
  $pageHistoryAfter = Join-Path $windowHistoryDir ("after_page_{0}_{1}.normalized.csv" -f $effectiveWindow, $stamp)
  Normalize-Csv -CsvPath $queryCsv.FullName -OutputPath $queryAfter -Kind 'query'
  Normalize-Csv -CsvPath $pageCsv.FullName -OutputPath $pageAfter -Kind 'page'
  if ($queryPageCsv) { Normalize-Csv -CsvPath $queryPageCsv.FullName -OutputPath $queryPageAfter -Kind 'query_page' }
  $hostValidation = Test-PageHosts -NormalizedPageCsv $pageAfter -ExpectedHost $expectedHost -AllowedHosts $allowedHosts
  $seoGeoQueryCount = @((Import-Csv -LiteralPath $queryAfter -Encoding UTF8)).Count
  $seoGeoPageCount = @((Import-Csv -LiteralPath $pageAfter -Encoding UTF8)).Count
  $seoGeoQueryPageCount = if ($queryPageAfter) { @((Import-Csv -LiteralPath $queryPageAfter -Encoding UTF8)).Count } else { 0 }
  $datePageDiagnosticCount = if ($datePageCsv) { @((Import-Csv -LiteralPath $datePageCsv.FullName -Encoding UTF8)).Count } else { 0 }
  $devicePageDiagnosticCount = if ($devicePageCsv) { @((Import-Csv -LiteralPath $devicePageCsv.FullName -Encoding UTF8)).Count } else { 0 }
  $dateDiagnosticCount = if ($dateCsv) { @((Import-Csv -LiteralPath $dateCsv.FullName -Encoding UTF8)).Count } else { 0 }
  $countryPageDiagnosticCount = if ($countryPageCsv) { @((Import-Csv -LiteralPath $countryPageCsv.FullName -Encoding UTF8)).Count } else { 0 }
  $deviceQueryDiagnosticCount = if ($deviceQueryCsv) { @((Import-Csv -LiteralPath $deviceQueryCsv.FullName -Encoding UTF8)).Count } else { 0 }
  $seoGeoTotal = $seoGeoQueryCount + $seoGeoPageCount + $seoGeoQueryPageCount

  if ($dateCsv -and $actualWindow.StartDate -and $actualWindow.EndDate) {
    $expectedDates = @()
    $dateCursor = [datetime]::ParseExact($actualWindow.StartDate, 'yyyy-MM-dd', [Globalization.CultureInfo]::InvariantCulture)
    $dateEnd = [datetime]::ParseExact($actualWindow.EndDate, 'yyyy-MM-dd', [Globalization.CultureInfo]::InvariantCulture)
    while ($dateCursor -le $dateEnd) { $expectedDates += $dateCursor.ToString('yyyy-MM-dd'); $dateCursor = $dateCursor.AddDays(1) }
    $actualDates = @(Import-Csv -LiteralPath $dateCsv.FullName -Encoding UTF8 | ForEach-Object { [string]$_.date } | Where-Object { $_ -match '^\d{4}-\d{2}-\d{2}$' } | Sort-Object -Unique)
    $missingDates = @($expectedDates | Where-Object { $_ -notin $actualDates })
    if ($missingDates.Count -gt 0) { throw "Date diagnostic is incomplete for the declared window: missing $($missingDates -join ', ')." }
  }
  $diagnosticFiles = [ordered]@{
    date = $dateCsv
    date_page = $datePageCsv
    device_page = $devicePageCsv
    country_page = $countryPageCsv
    device_query = $deviceQueryCsv
  }
  $missingDiagnosticKinds = @($diagnosticFiles.Keys | Where-Object { -not $diagnosticFiles[$_] })
  $diagnosticsComplete = ($missingDiagnosticKinds.Count -eq 0 -and $dateDiagnosticCount -eq [int]$actualWindow.Days)

  $queryBaseline = Join-Path $windowHistoryDir 'current_query_baseline.normalized.csv'
  $pageBaseline = Join-Path $windowHistoryDir 'current_page_baseline.normalized.csv'
  $queryPageBaseline = Join-Path $windowHistoryDir 'current_query_page_baseline.normalized.csv'
  $queryBaselineExists = Test-Path -LiteralPath $queryBaseline -PathType Leaf
  $pageBaselineExists = Test-Path -LiteralPath $pageBaseline -PathType Leaf
  if ($queryBaselineExists -ne $pageBaselineExists) {
    throw "Baseline state is inconsistent for $siteId/$effectiveWindow. Query and page baselines must both exist or both be absent."
  }
  $baselineExists = ($queryBaselineExists -and $pageBaselineExists)
  $queryPageBaselineExists = Test-Path -LiteralPath $queryPageBaseline -PathType Leaf
  $queryCompareBaseline = if ($baselineExists) { $queryBaseline } else { $queryAfter }
  $pageCompareBaseline = if ($baselineExists) { $pageBaseline } else { $pageAfter }
  $queryBaselineHashBefore = if ($baselineExists) { Get-FileSha256 -Path $queryBaseline } else { $null }
  $pageBaselineHashBefore = if ($baselineExists) { Get-FileSha256 -Path $pageBaseline } else { $null }
  $queryAfterHash = Get-FileSha256 -Path $queryAfter
  $pageAfterHash = Get-FileSha256 -Path $pageAfter
  $queryPageAfterHash = if ($queryPageAfter) { Get-FileSha256 -Path $queryPageAfter } else { $null }

  $rangeComplete = Test-CompleteDateRange -StartDate $actualWindow.StartDate -EndDate $actualWindow.EndDate -Days $actualWindow.Days
  $todayTaipei = [TimeZoneInfo]::ConvertTimeBySystemTimeZoneId((Get-Date), $timezoneId).Date
  $latestAllowedEnd = $todayTaipei.AddDays(-$dataLagDays)
  $rangeLagValid = $rangeComplete -and ([datetime]::ParseExact($actualWindow.EndDate, 'yyyy-MM-dd', [Globalization.CultureInfo]::InvariantCulture) -le $latestAllowedEnd)
  $previousManifestPath = Join-Path $latestDir 'weekly-sop-last-run.json'
  $previousManifest = if (Test-Path -LiteralPath $previousManifestPath -PathType Leaf) { Get-Content -LiteralPath $previousManifestPath -Raw -Encoding UTF8 | ConvertFrom-Json } else { $null }
  if ($rangeComplete -and $previousManifest) {
    if ($previousManifest.end_date -and ([string]$previousManifest.end_date -ge [string]$actualWindow.EndDate)) {
      $repairAllowed = $false
      if ($RepairIncompleteCurrentEndDate -and [string]$previousManifest.end_date -gt [string]$actualWindow.EndDate -and $previousManifest.diagnostic_dimensions.date.available) {
        $previousDateRelative = ([string]$previousManifest.diagnostic_dimensions.date.path).Replace('/', '\')
        if (-not [IO.Path]::IsPathRooted($previousDateRelative)) {
          $previousDatePath = [IO.Path]::GetFullPath((Join-Path $weeklyRoot $previousDateRelative))
          if (Test-Path -LiteralPath $previousDatePath -PathType Leaf) {
            $previousDates = @(Import-Csv -LiteralPath $previousDatePath -Encoding UTF8 | ForEach-Object { [string]$_.date } | Where-Object { $_ -match '^\d{4}-\d{2}-\d{2}$' } | Sort-Object -Unique)
            $previousDiagnosticEnd = if ($previousDates.Count -gt 0) { [string]$previousDates[-1] } else { $null }
            $repairAllowed = [bool]($previousDiagnosticEnd -eq [string]$actualWindow.EndDate -and $previousDiagnosticEnd -lt [string]$previousManifest.end_date)
          }
        }
      }
      if (-not $repairAllowed) { throw "Imported end_date $($actualWindow.EndDate) is not newer than the current $effectiveWindow baseline end_date $($previousManifest.end_date)." }
      Write-Warning "Repairing incomplete current $effectiveWindow end_date $($previousManifest.end_date) to API-confirmed $($actualWindow.EndDate)."
    }
  }
  $snapshotFamilyId = if ($rangeComplete) { "$siteId|$($siteConfig.gscProperty)|$($actualWindow.EndDate)|$timezoneId" } else { $null }
  $qualityWarnings = @()
  if ($previousManifest -and $previousManifest.row_counts) {
    foreach ($check in @(
      [PSCustomObject]@{ name = 'query'; current = $seoGeoQueryCount; previous = [int]$previousManifest.row_counts.normalized_query },
      [PSCustomObject]@{ name = 'page'; current = $seoGeoPageCount; previous = [int]$previousManifest.row_counts.normalized_page }
    )) {
      if ($check.previous -gt 0 -and $check.current -lt [Math]::Ceiling($check.previous * 0.5)) {
        $qualityWarnings += "$($check.name) row count dropped from $($check.previous) to $($check.current); possible truncated export."
      }
    }
  }
  $dataConfidence = if ($rangeLagValid -and $queryPageAfter -and $baselineExists -and $qualityWarnings.Count -eq 0 -and $diagnosticsComplete) { 'decision_ready' } else { 'monitor_only' }
  if (-not $diagnosticsComplete) {
    $qualityWarnings += "Five diagnostic dimensions are required for a formal strategy cycle; missing=$($missingDiagnosticKinds -join ',')."
  }

  $querySameAsBaseline = ($baselineExists -and $queryBaselineHashBefore -eq $queryAfterHash)
  $pageSameAsBaseline = ($baselineExists -and $pageBaselineHashBefore -eq $pageAfterHash)
  if ($querySameAsBaseline -xor $pageSameAsBaseline) {
    throw 'Only one of the Query/Page snapshots matches the current baseline. Refusing a partial or inconsistent update.'
  }

  Ensure-Dir -Path $runDir

  $queryBaselineSnapshot = Join-Path $runDir ("before_query_baseline_{0}.normalized.csv" -f $effectiveWindow)
  $pageBaselineSnapshot = Join-Path $runDir ("before_page_baseline_{0}.normalized.csv" -f $effectiveWindow)
  $queryCurrentSnapshot = Join-Path $runDir ("after_query_snapshot_{0}.normalized.csv" -f $effectiveWindow)
  $pageCurrentSnapshot = Join-Path $runDir ("after_page_snapshot_{0}.normalized.csv" -f $effectiveWindow)
  Copy-Item -LiteralPath $queryCompareBaseline -Destination $queryBaselineSnapshot -Force
  Copy-Item -LiteralPath $pageCompareBaseline -Destination $pageBaselineSnapshot -Force
  Copy-Item -LiteralPath $queryAfter -Destination $queryCurrentSnapshot -Force
  Copy-Item -LiteralPath $pageAfter -Destination $pageCurrentSnapshot -Force

  $relativeQueryBaselineSnapshot = Convert-ToRelativePath -Path $queryBaselineSnapshot -BaseRoot $weeklyRoot
  $relativePageBaselineSnapshot = Convert-ToRelativePath -Path $pageBaselineSnapshot -BaseRoot $weeklyRoot
  $relativeQueryCurrentSnapshot = Convert-ToRelativePath -Path $queryCurrentSnapshot -BaseRoot $weeklyRoot
  $relativePageCurrentSnapshot = Convert-ToRelativePath -Path $pageCurrentSnapshot -BaseRoot $weeklyRoot

  $queryBaseName = "gsc-query-kpi-diff-report(查詢-$windowTitle)"
  $pageBaseName = "gsc-page-kpi-diff-report(網頁-$windowTitle)"
  $queryMd = Join-Path $runDir "$queryBaseName.md"
  $pageMd = Join-Path $runDir "$pageBaseName.md"
  $queryHtml = Join-Path $runDir "$queryBaseName.html"
  $pageHtml = Join-Path $runDir "$pageBaseName.html"
  $queryFullMd = Join-Path $runDir "$queryBaseName-full.md"
  $pageFullMd = Join-Path $runDir "$pageBaseName-full.md"
  $queryFullHtml = Join-Path $runDir "$queryBaseName-full.html"
  $pageFullHtml = Join-Path $runDir "$pageBaseName-full.html"

  Invoke-KpiReport -RepoRoot $repoRoot -Before $queryBaselineSnapshot -After $queryCurrentSnapshot -Output $queryMd -FullOutput $queryFullMd -TitleSuffix " (查詢-$windowTitle)" -PeriodLabel $periodLabel -TrackingStartDate $trackingStartDate -VerdictMode $verdictMode -MinImpr $detailMinImpr -Limit $detailLimit -FullMinImpr $fullDetailMinImpr -MainQueryLimit $mainQueryLimit -MainPageLimit $mainPageLimit -SeoGeoTotal $seoGeoTotal -SeoGeoQueryCount $seoGeoQueryCount -SeoGeoPageCount $seoGeoPageCount
  Invoke-KpiReport -RepoRoot $repoRoot -Before $pageBaselineSnapshot -After $pageCurrentSnapshot -Output $pageMd -FullOutput $pageFullMd -TitleSuffix " (網頁-$windowTitle)" -PeriodLabel $periodLabel -TrackingStartDate $trackingStartDate -VerdictMode $verdictMode -MinImpr $detailMinImpr -Limit $detailLimit -FullMinImpr $fullDetailMinImpr -MainQueryLimit $mainQueryLimit -MainPageLimit $mainPageLimit -SeoGeoTotal $seoGeoTotal -SeoGeoQueryCount $seoGeoQueryCount -SeoGeoPageCount $seoGeoPageCount

  Set-KpiReportSourceLabels -ReportPaths @($queryMd, $queryHtml, $queryFullMd, $queryFullHtml) -BeforePath $queryBaselineSnapshot -AfterPath $queryCurrentSnapshot -BeforeLabel $relativeQueryBaselineSnapshot -AfterLabel $relativeQueryCurrentSnapshot
  Set-KpiReportSourceLabels -ReportPaths @($pageMd, $pageHtml, $pageFullMd, $pageFullHtml) -BeforePath $pageBaselineSnapshot -AfterPath $pageCurrentSnapshot -BeforeLabel $relativePageBaselineSnapshot -AfterLabel $relativePageCurrentSnapshot

  if (-not (Test-Path -LiteralPath $queryMd)) { throw "Missing report: $queryMd" }
  if (-not (Test-Path -LiteralPath $queryHtml)) { throw "Missing report: $queryHtml" }
  if (-not (Test-Path -LiteralPath $queryFullMd)) { throw "Missing report: $queryFullMd" }
  if (-not (Test-Path -LiteralPath $queryFullHtml)) { throw "Missing report: $queryFullHtml" }
  if (-not (Test-Path -LiteralPath $pageMd)) { throw "Missing report: $pageMd" }
  if (-not (Test-Path -LiteralPath $pageHtml)) { throw "Missing report: $pageHtml" }
  if (-not (Test-Path -LiteralPath $pageFullMd)) { throw "Missing report: $pageFullMd" }
  if (-not (Test-Path -LiteralPath $pageFullHtml)) { throw "Missing report: $pageFullHtml" }

  Ensure-Dir -Path $windowHistoryDir
  Copy-Item -LiteralPath $queryAfter -Destination $queryHistoryAfter -Force
  Copy-Item -LiteralPath $pageAfter -Destination $pageHistoryAfter -Force
  Set-AtomicBaselinePair -QuerySource $queryAfter -QueryDestination $queryBaseline -PageSource $pageAfter -PageDestination $pageBaseline -QueryPageSource $queryPageAfter -QueryPageDestination $queryPageBaseline
  if ($datePageCsv) { Set-AtomicFileFromSource -Source $datePageCsv.FullName -Destination $datePageDiagnostic }
  if ($devicePageCsv) { Set-AtomicFileFromSource -Source $devicePageCsv.FullName -Destination $devicePageDiagnostic }
  if ($dateCsv) { Set-AtomicFileFromSource -Source $dateCsv.FullName -Destination $dateDiagnostic }
  if ($countryPageCsv) { Set-AtomicFileFromSource -Source $countryPageCsv.FullName -Destination $countryPageDiagnostic }
  if ($deviceQueryCsv) { Set-AtomicFileFromSource -Source $deviceQueryCsv.FullName -Destination $deviceQueryDiagnostic }
  $diagnosticHistory = [ordered]@{}
  foreach ($kind in $diagnosticFiles.Keys) {
    $file = $diagnosticFiles[$kind]
    if ($file) {
      $diagnosticHistory[$kind] = Save-DiagnosticHistory -Source $file.FullName -Kind $kind -WindowHistoryDir $windowHistoryDir -StartDate ([string]$actualWindow.StartDate) -EndDate ([string]$actualWindow.EndDate) -WeeklyRoot $weeklyRoot
    }
  }
  $baselineCommitted = $true
  $queryBaselineHashAfter = Get-FileSha256 -Path $queryBaseline
  $pageBaselineHashAfter = Get-FileSha256 -Path $pageBaseline
  $queryPageBaselineHashAfter = if ($queryPageAfter) { Get-FileSha256 -Path $queryPageBaseline } else { $null }

  Ensure-Dir -Path $latestDir
  Copy-Item -LiteralPath $queryMd -Destination (Join-Path $latestDir "$queryBaseName.md") -Force
  Copy-Item -LiteralPath $queryHtml -Destination (Join-Path $latestDir "$queryBaseName.html") -Force
  Copy-Item -LiteralPath $queryFullMd -Destination (Join-Path $latestDir "$queryBaseName-full.md") -Force
  Copy-Item -LiteralPath $queryFullHtml -Destination (Join-Path $latestDir "$queryBaseName-full.html") -Force
  Copy-Item -LiteralPath $pageMd -Destination (Join-Path $latestDir "$pageBaseName.md") -Force
  Copy-Item -LiteralPath $pageHtml -Destination (Join-Path $latestDir "$pageBaseName.html") -Force
  Copy-Item -LiteralPath $pageFullMd -Destination (Join-Path $latestDir "$pageBaseName-full.md") -Force
  Copy-Item -LiteralPath $pageFullHtml -Destination (Join-Path $latestDir "$pageBaseName-full.html") -Force

  $runEndedAt = Get-Date
  $archiveDay = Join-Path $siteArchiveDir ($runEndedAt.ToString('yyyy-MM-dd'))
  $archiveWindow = Join-Path $archiveDay $effectiveWindow
  Ensure-Dir -Path $archiveWindow
  $archivedPath = Join-Path $archiveWindow ("{0}_{1}" -f $stamp, $incoming.Name)
  if ($inputMode -eq 'direct') {
    Copy-Item -LiteralPath $incoming.FullName -Destination $archivedPath -Force
  } else {
    Move-Item -LiteralPath $incoming.FullName -Destination $archivedPath -Force
  }

  $summaryPath = Join-Path $runDir 'run-summary.md'
  $relativeQueryBaseline = Convert-ToRelativePath -Path $queryBaseline -BaseRoot $weeklyRoot
  $relativePageBaseline = Convert-ToRelativePath -Path $pageBaseline -BaseRoot $weeklyRoot
  $relativeArchivedPath = Convert-ToRelativePath -Path $archivedPath -BaseRoot $weeklyRoot
  $relativeRunDir = Convert-ToRelativePath -Path $runDir -BaseRoot $weeklyRoot
  $relativeSummaryPath = Convert-ToRelativePath -Path $summaryPath -BaseRoot $weeklyRoot
  $relativeLatestQueryHtml = Convert-ToRelativePath -Path (Join-Path $latestDir "$queryBaseName.html") -BaseRoot $weeklyRoot
  $relativeLatestQueryFullHtml = Convert-ToRelativePath -Path (Join-Path $latestDir "$queryBaseName-full.html") -BaseRoot $weeklyRoot
  $relativeLatestPageHtml = Convert-ToRelativePath -Path (Join-Path $latestDir "$pageBaseName.html") -BaseRoot $weeklyRoot
  $relativeLatestPageFullHtml = Convert-ToRelativePath -Path (Join-Path $latestDir "$pageBaseName-full.html") -BaseRoot $weeklyRoot
  @(
    "# Weekly SOP $windowTitle Run Summary"
    ''
    "- Run time: $($runEndedAt.ToString('yyyy-MM-dd HH:mm:ss'))"
    "- Requested window: $Window"
    "- Resolved window: $effectiveWindow / $periodLabel"
    "- Tracking start date: $trackingStartDate"
    "- Verdict mode: $verdictMode"
    "- SEO/GEO total rows: $seoGeoTotal"
    "- SEO/GEO query rows: $seoGeoQueryCount"
    "- SEO/GEO page rows: $seoGeoPageCount"
    "- Main detail min-impr: $detailMinImpr"
    "- Main detail limit: $detailLimit"
    "- Full detail min-impr: $fullDetailMinImpr"
    "- Query same as current baseline: $querySameAsBaseline"
    "- Page same as current baseline: $pageSameAsBaseline"
    "- Input SHA256: $inputHash"
    "- Query baseline hash before: $queryBaselineHashBefore"
    "- Page baseline hash before: $pageBaselineHashBefore"
    "- Query after hash: $queryAfterHash"
    "- Page after hash: $pageAfterHash"
    "- Query baseline hash after: $queryBaselineHashAfter"
    "- Page baseline hash after: $pageBaselineHashAfter"
    "- Input mode: $inputMode"
    "- Import source: $resolvedImportSource"
    "- Input file: $($incoming.Name)"
    "- Site ID: $siteId"
    "- Property: $($siteConfig.gscProperty)"
    "- Expected host: $expectedHost"
    "- Host rows: target=$($hostValidation.target), foreign=$($hostValidation.foreign), invalid=$($hostValidation.invalid)"
    "- Data confidence: $dataConfidence"
    "- Date range: $($actualWindow.StartDate) to $($actualWindow.EndDate) / complete=$rangeComplete / lag_valid=$rangeLagValid"
    "- Date source: $($actualWindow.DateSource)"
    "- Query × Page CSV: $(if ($queryPageCsv) { $queryPageCsv.Name } else { 'missing' })"
    "- Date × Page diagnostic: $(if ($datePageCsv) { "$($datePageCsv.Name) / $datePageDiagnosticCount rows" } else { 'missing' })"
    "- Device × Page diagnostic: $(if ($devicePageCsv) { "$($devicePageCsv.Name) / $devicePageDiagnosticCount rows" } else { 'missing' })"
    "- Date diagnostic: $(if ($dateCsv) { "$($dateCsv.Name) / $dateDiagnosticCount rows" } else { 'missing' })"
    "- Country × Page diagnostic: $(if ($countryPageCsv) { "$($countryPageCsv.Name) / $countryPageDiagnosticCount rows" } else { 'missing' })"
    "- Device × Query diagnostic: $(if ($deviceQueryCsv) { "$($deviceQueryCsv.Name) / $deviceQueryDiagnosticCount rows" } else { 'missing' })"
    "- Diagnostics complete: $diagnosticsComplete"
    "- Quality warnings: $(if ($qualityWarnings.Count) { $qualityWarnings -join ' | ' } else { 'none' })"
    "- Query CSV: $($queryCsv.Name)"
    "- Page CSV: $($pageCsv.Name)"
    "- Query baseline snapshot: $relativeQueryBaselineSnapshot"
    "- Page baseline snapshot: $relativePageBaselineSnapshot"
    "- Query current snapshot: $relativeQueryCurrentSnapshot"
    "- Page current snapshot: $relativePageCurrentSnapshot"
    "- Query baseline updated: $relativeQueryBaseline"
    "- Page baseline updated: $relativePageBaseline"
    "- Latest query HTML: $relativeLatestQueryHtml"
    "- Latest query full HTML: $relativeLatestQueryFullHtml"
    "- Latest page HTML: $relativeLatestPageHtml"
    "- Latest page full HTML: $relativeLatestPageFullHtml"
    "- Archived input: $relativeArchivedPath"
  ) | Set-Content -LiteralPath $summaryPath -Encoding UTF8

  $runManifest = @{
    schema_version = 2
    status = 'success'
    path_base = 'weekly_sop'
    site_id = $siteId
    property = [string]$siteConfig.gscProperty
    expected_host = $expectedHost
    allowed_hosts = $allowedHosts
    run_id = $stamp
    run_time = $runEndedAt.ToString('yyyy-MM-dd HH:mm:ss')
    generated_at = $runEndedAt.ToUniversalTime().ToString('o')
    requested_window = $Window
    resolved_window = $effectiveWindow
    start_date = $actualWindow.StartDate
    end_date = $actualWindow.EndDate
    date_source = $actualWindow.DateSource
    period_label = $periodLabel
    verdict_mode = $verdictMode
    data_confidence = $dataConfidence
    decision_ready = ($dataConfidence -eq 'decision_ready')
    snapshot_family_id = $snapshotFamilyId
    timezone = $timezoneId
    data_lag_days = $dataLagDays
    date_range_complete = $rangeComplete
    data_lag_valid = $rangeLagValid
    quality_warnings = $qualityWarnings
    property_validation = 'page_host'
    query_page_available = [bool]$queryPageAfter
    input_mode = $inputMode
    import_source = $resolvedImportSource
    input_file = $incoming.Name
    input_sha256 = $inputHash
    filter = @{
      key = [string]$actualWindow.FilterKey
      value = [string]$actualWindow.FilterValue
      days = [int]$actualWindow.Days
    }
    seo_geo = @{
      total = $seoGeoTotal
      query = $seoGeoQueryCount
      page = $seoGeoPageCount
      query_page = $seoGeoQueryPageCount
    }
    diagnostic_dimensions = @{
      date_page = @{
        available = [bool]$datePageCsv
        row_count = $datePageDiagnosticCount
        path = if ($diagnosticHistory.date_page) { $diagnosticHistory.date_page.snapshot.path } else { $null }
        current_path = if ($datePageDiagnostic) { Convert-ToRelativePath -Path $datePageDiagnostic -BaseRoot $weeklyRoot } else { $null }
        sha256 = if ($diagnosticHistory.date_page) { $diagnosticHistory.date_page.snapshot.sha256 } else { $null }
      }
      device_page = @{
        available = [bool]$devicePageCsv
        row_count = $devicePageDiagnosticCount
        path = if ($diagnosticHistory.device_page) { $diagnosticHistory.device_page.snapshot.path } else { $null }
        current_path = if ($devicePageDiagnostic) { Convert-ToRelativePath -Path $devicePageDiagnostic -BaseRoot $weeklyRoot } else { $null }
        sha256 = if ($diagnosticHistory.device_page) { $diagnosticHistory.device_page.snapshot.sha256 } else { $null }
      }
      date = @{
        available = [bool]$dateCsv
        row_count = $dateDiagnosticCount
        path = if ($diagnosticHistory.date) { $diagnosticHistory.date.snapshot.path } else { $null }
        current_path = if ($dateDiagnostic) { Convert-ToRelativePath -Path $dateDiagnostic -BaseRoot $weeklyRoot } else { $null }
        sha256 = if ($diagnosticHistory.date) { $diagnosticHistory.date.snapshot.sha256 } else { $null }
      }
      country_page = @{
        available = [bool]$countryPageCsv
        row_count = $countryPageDiagnosticCount
        path = if ($diagnosticHistory.country_page) { $diagnosticHistory.country_page.snapshot.path } else { $null }
        current_path = if ($countryPageDiagnostic) { Convert-ToRelativePath -Path $countryPageDiagnostic -BaseRoot $weeklyRoot } else { $null }
        sha256 = if ($diagnosticHistory.country_page) { $diagnosticHistory.country_page.snapshot.sha256 } else { $null }
      }
      device_query = @{
        available = [bool]$deviceQueryCsv
        row_count = $deviceQueryDiagnosticCount
        path = if ($diagnosticHistory.device_query) { $diagnosticHistory.device_query.snapshot.path } else { $null }
        current_path = if ($deviceQueryDiagnostic) { Convert-ToRelativePath -Path $deviceQueryDiagnostic -BaseRoot $weeklyRoot } else { $null }
        sha256 = if ($diagnosticHistory.device_query) { $diagnosticHistory.device_query.snapshot.sha256 } else { $null }
      }
    }
    diagnostics_complete = $diagnosticsComplete
    missing_diagnostic_dimensions = $missingDiagnosticKinds
    diagnostic_history = $diagnosticHistory
    comparison_period = if ($previousManifest -and $previousManifest.start_date -and $previousManifest.end_date) {
      $previousStart = [datetime]::ParseExact([string]$previousManifest.start_date, 'yyyy-MM-dd', [Globalization.CultureInfo]::InvariantCulture)
      $previousEnd = [datetime]::ParseExact([string]$previousManifest.end_date, 'yyyy-MM-dd', [Globalization.CultureInfo]::InvariantCulture)
      $currentStart = [datetime]::ParseExact([string]$actualWindow.StartDate, 'yyyy-MM-dd', [Globalization.CultureInfo]::InvariantCulture)
      $currentEnd = [datetime]::ParseExact([string]$actualWindow.EndDate, 'yyyy-MM-dd', [Globalization.CultureInfo]::InvariantCulture)
      $overlapStart = if ($previousStart -gt $currentStart) { $previousStart } else { $currentStart }
      $overlapEnd = if ($previousEnd -lt $currentEnd) { $previousEnd } else { $currentEnd }
      $overlapDays = [Math]::Max(0, [int](($overlapEnd - $overlapStart).TotalDays + 1))
      [ordered]@{ start_date = [string]$previousManifest.start_date; end_date = [string]$previousManifest.end_date; comparison_type = if ($overlapDays -gt 0) { 'rolling_overlapping' } else { 'non_overlapping' }; overlap_days = $overlapDays }
    } else { $null }
    row_counts = @{
      normalized_query = $seoGeoQueryCount
      normalized_page = $seoGeoPageCount
      normalized_query_page = $seoGeoQueryPageCount
    }
    host_counts = $hostValidation
    baseline = @{
      existed_before = $baselineExists
      bootstrapped = (-not $baselineExists)
      query = $relativeQueryBaseline
      page = $relativePageBaseline
      query_page = if ($queryPageAfter) { Convert-ToRelativePath -Path $queryPageBaseline -BaseRoot $weeklyRoot } else { $null }
    }
    comparison_sources = @{
      query_before = $relativeQueryBaselineSnapshot
      query_after = $relativeQueryCurrentSnapshot
      page_before = $relativePageBaselineSnapshot
      page_after = $relativePageCurrentSnapshot
    }
    same_baseline = @{
      query = $querySameAsBaseline
      page = $pageSameAsBaseline
    }
    hashes = @{
      query_baseline_before = $queryBaselineHashBefore
      page_baseline_before = $pageBaselineHashBefore
      query_after = $queryAfterHash
      page_after = $pageAfterHash
      query_page_after = $queryPageAfterHash
      query_baseline_after = $queryBaselineHashAfter
      page_baseline_after = $pageBaselineHashAfter
      query_page_baseline_after = $queryPageBaselineHashAfter
    }
    latest_reports = @{
      query_html = $relativeLatestQueryHtml
      query_full_html = $relativeLatestQueryFullHtml
      page_html = $relativeLatestPageHtml
      page_full_html = $relativeLatestPageFullHtml
    }
    archived_input = $relativeArchivedPath
    report_folder = $relativeRunDir
    run_summary = $relativeSummaryPath
  }
  Write-RunManifest -Path (Join-Path $latestRoot 'weekly-sop-last-run.json') -Data $runManifest
  Write-RunManifest -Path (Join-Path $latestDir 'weekly-sop-last-run.json') -Data $runManifest

  Write-Host "Weekly SOP $windowTitle workflow completed."
  Write-Host "Report folder: $runDir"
  Write-Host "Latest query HTML: $(Join-Path $latestDir "$queryBaseName.html")"
  Write-Host "Latest query full HTML: $(Join-Path $latestDir "$queryBaseName-full.html")"
  Write-Host "Latest page HTML: $(Join-Path $latestDir "$pageBaseName.html")"
  Write-Host "Latest page full HTML: $(Join-Path $latestDir "$pageBaseName-full.html")"
  if ($querySameAsBaseline -or $pageSameAsBaseline) {
    Write-Host "Note: input matched the current $effectiveWindow baseline, so this run created/updated latest reports as a baseline snapshot."
  }
} catch {
  $failureManifest = @{
    schema_version = 2
    status = 'failed_validation'
    path_base = 'weekly_sop'
    site_id = $siteId
    property = [string]$siteConfig.gscProperty
    expected_host = $expectedHost
    run_time = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
    requested_window = $Window
    resolved_window = $effectiveWindow
    input_mode = $inputMode
    input_file = if ($incoming) { $incoming.Name } else { $null }
    input_sha256 = $inputHash
    baseline_updated = $baselineCommitted
    message = $_.Exception.Message
  }
  try {
    Write-RunManifest -Path (Join-Path $latestRoot 'weekly-sop-last-run.json') -Data $failureManifest
  } catch {
    Write-Warning "Could not write failure manifest: $($_.Exception.Message)"
  }
  throw
} finally {
  if ($tmpDir -and (Test-Path -LiteralPath $tmpDir)) {
    Remove-Item -LiteralPath $tmpDir -Recurse -Force
  }
}

