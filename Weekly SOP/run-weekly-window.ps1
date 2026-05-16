param(
  [ValidateSet('7d', '28d')]
  [string]$Window = '7d',
  [string]$InputFile
)

$ErrorActionPreference = 'Stop'

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

function Test-SameFileContent {
  param(
    [string]$Left,
    [string]$Right
  )
  if (-not (Test-Path -LiteralPath $Left -PathType Leaf)) { return $false }
  if (-not (Test-Path -LiteralPath $Right -PathType Leaf)) { return $false }
  $leftHash = (Get-FileHash -LiteralPath $Left -Algorithm SHA256).Hash
  $rightHash = (Get-FileHash -LiteralPath $Right -Algorithm SHA256).Hash
  return ($leftHash -eq $rightHash)
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
    [ValidateSet('query', 'page')]
    [string]$Kind
  )

  $out = @()
  $validMetricRows = 0
  foreach ($row in $Rows) {
    $propNames = @($row.PSObject.Properties.Name)

    if ($Kind -eq 'query') {
      $query = Get-FirstPropValue -Row $row -Names @('query', 'Query', '熱門查詢項目', '查詢')
      if ([string]::IsNullOrWhiteSpace($query)) { $query = Get-PropByIndex -Row $row -Index 0 }
      if ([string]::IsNullOrWhiteSpace($query)) { continue }
      $page = '(all pages)'
    } else {
      $hasPageHeader = ($propNames | Where-Object { $_ -in @('page', 'Page', 'url', 'URL', '熱門網頁', '網頁', '頁面') }).Count -gt 0
      $page = Get-FirstPropValue -Row $row -Names @('page', 'Page', 'url', 'URL', '熱門網頁', '網頁', '頁面')
      if ([string]::IsNullOrWhiteSpace($page)) { $page = Get-PropByIndex -Row $row -Index 0 }
      if ([string]::IsNullOrWhiteSpace($page)) { continue }
      $query = '(all queries)'
    }

    $clicks = Get-FirstPropValue -Row $row -Names @('clicks', 'Clicks', '點擊')
    if ([string]::IsNullOrWhiteSpace($clicks)) { $clicks = Get-PropByIndex -Row $row -Index 1 }

    $impr = Get-FirstPropValue -Row $row -Names @('impressions', 'Impressions', '曝光')
    if ([string]::IsNullOrWhiteSpace($impr)) { $impr = Get-PropByIndex -Row $row -Index 2 }

    $ctr = Get-FirstPropValue -Row $row -Names @('ctr', 'CTR', '點閱率')
    if ([string]::IsNullOrWhiteSpace($ctr)) { $ctr = Get-PropByIndex -Row $row -Index 3 }

    $pos = Get-FirstPropValue -Row $row -Names @('position', 'Position', '排名')
    if ([string]::IsNullOrWhiteSpace($pos)) { $pos = Get-PropByIndex -Row $row -Index 4 }

    if ((Test-NumericMetric -Value $impr) -and (Test-NumericMetric -Value $pos)) {
      if ($Kind -eq 'query' -and $query -notmatch '^https?://') { $validMetricRows++ }
      if ($Kind -eq 'page' -and ($hasPageHeader -or $page -match '^https?://')) { $validMetricRows++ }
    }

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
    [ValidateSet('query', 'page')]
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
      if ($m.Success) {
        $days = [int]$m.Groups[1].Value
        if ($days -eq 7) { return @{ Slug = '7d'; Label = '前 7 天'; Days = 7; Title = '7天'; VerdictMode = 'observation' } }
        if ($days -eq 28) { return @{ Slug = '28d'; Label = '前 28 天'; Days = 28; Title = '28天'; VerdictMode = 'decision' } }
      }
      return @{ Slug = 'unknown'; Label = $value; Days = 0; Title = '未知區間'; VerdictMode = 'decision' }
    }
  }
  return @{ Slug = 'unknown'; Label = 'unknown'; Days = 0; Title = '未知區間'; VerdictMode = 'decision' }
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

$weeklyRoot = Join-Path $PSScriptRoot '.'
$repoRoot = Split-Path -Parent $PSScriptRoot
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

$tmpDir = $null
$incoming = $null
$inputMode = 'inbox'

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

  # Include milliseconds + PID to avoid same-second temp/report collisions.
  $stamp = "{0}_{1}" -f (Get-Date -Format 'yyyy-MM-dd_HHmmss_fff'), $PID
  $tmpDir = Join-Path $weeklyRoot "_tmp_window_$stamp"
  $runDir = Join-Path $reportsDir ("{0}_{1}" -f $stamp, $Window)
  $windowHistoryDir = Join-Path $historyDir $Window
  $latestDir = Join-Path $latestRoot $Window

  Ensure-Dir -Path $tmpDir

  Expand-Archive -LiteralPath $incoming.FullName -DestinationPath $tmpDir -Force

  $queryCsv = Find-CsvByName -ExtractDir $tmpDir -ExpectedNames @('查詢.csv', 'query.csv', 'queries.csv')
  $pageCsv = Find-CsvByName -ExtractDir $tmpDir -ExpectedNames @('網頁.csv', 'page.csv', 'pages.csv')
  $filterCsv = Find-CsvByName -ExtractDir $tmpDir -ExpectedNames @('篩選器.csv', 'filters.csv')

  if (-not $queryCsv) { throw "Missing 查詢.csv in ZIP: $($incoming.FullName)" }
  if (-not $pageCsv) { throw "Missing 網頁.csv in ZIP: $($incoming.FullName)" }
  if (-not $filterCsv) { throw "Missing 篩選器.csv in ZIP: $($incoming.FullName)" }

  $actualWindow = Read-WindowFromFilter -FilterCsv $filterCsv.FullName
  if ($actualWindow.Slug -ne $Window) {
    throw "日期區間不符：目前檔案是 $($actualWindow.Label)，但你執行的是 $Window 模式。請到 GSC 匯出正確區間的 Search Performance ZIP。"
  }

  $windowTitle = [string]$actualWindow.Title
  $periodLabel = [string]$actualWindow.Label
  $verdictMode = [string]$actualWindow.VerdictMode
  $trackingStartDate = Get-Date -Format 'yyyy-MM-dd'
  $detailMinImpr = if ($Window -eq '7d') { 1 } else { 20 }
  $detailLimit = if ($Window -eq '7d') { 30 } else { 50 }
  $fullDetailMinImpr = 1
  $mainQueryLimit = $detailLimit
  $mainPageLimit = $detailLimit

  $queryAfter = Join-Path $windowHistoryDir ("after_query_{0}_{1}.normalized.csv" -f $Window, $stamp)
  $pageAfter = Join-Path $windowHistoryDir ("after_page_{0}_{1}.normalized.csv" -f $Window, $stamp)
  Normalize-Csv -CsvPath $queryCsv.FullName -OutputPath $queryAfter -Kind 'query'
  Normalize-Csv -CsvPath $pageCsv.FullName -OutputPath $pageAfter -Kind 'page'
  $seoGeoQueryCount = @((Import-Csv -LiteralPath $queryAfter -Encoding UTF8)).Count
  $seoGeoPageCount = @((Import-Csv -LiteralPath $pageAfter -Encoding UTF8)).Count
  $seoGeoTotal = $seoGeoQueryCount + $seoGeoPageCount

  $queryBaseline = Join-Path $windowHistoryDir 'current_query_baseline.normalized.csv'
  $pageBaseline = Join-Path $windowHistoryDir 'current_page_baseline.normalized.csv'
  Initialize-Baseline -BaselinePath $queryBaseline -Kind 'query' -Window $Window -WeeklyRoot $weeklyRoot -RepoRoot $repoRoot -SeedNormalizedPath $queryAfter
  Initialize-Baseline -BaselinePath $pageBaseline -Kind 'page' -Window $Window -WeeklyRoot $weeklyRoot -RepoRoot $repoRoot -SeedNormalizedPath $pageAfter

  $querySameAsBaseline = Test-SameFileContent -Left $queryBaseline -Right $queryAfter
  $pageSameAsBaseline = Test-SameFileContent -Left $pageBaseline -Right $pageAfter

  Ensure-Dir -Path $runDir

  $queryBaselineSnapshot = Join-Path $runDir ("before_query_baseline_{0}.normalized.csv" -f $Window)
  $pageBaselineSnapshot = Join-Path $runDir ("before_page_baseline_{0}.normalized.csv" -f $Window)
  Copy-Item -LiteralPath $queryBaseline -Destination $queryBaselineSnapshot -Force
  Copy-Item -LiteralPath $pageBaseline -Destination $pageBaselineSnapshot -Force

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

  Invoke-KpiReport -RepoRoot $repoRoot -Before $queryBaselineSnapshot -After $queryAfter -Output $queryMd -FullOutput $queryFullMd -TitleSuffix " (查詢-$windowTitle)" -PeriodLabel $periodLabel -TrackingStartDate $trackingStartDate -VerdictMode $verdictMode -MinImpr $detailMinImpr -Limit $detailLimit -FullMinImpr $fullDetailMinImpr -MainQueryLimit $mainQueryLimit -MainPageLimit $mainPageLimit -SeoGeoTotal $seoGeoTotal -SeoGeoQueryCount $seoGeoQueryCount -SeoGeoPageCount $seoGeoPageCount
  Invoke-KpiReport -RepoRoot $repoRoot -Before $pageBaselineSnapshot -After $pageAfter -Output $pageMd -FullOutput $pageFullMd -TitleSuffix " (網頁-$windowTitle)" -PeriodLabel $periodLabel -TrackingStartDate $trackingStartDate -VerdictMode $verdictMode -MinImpr $detailMinImpr -Limit $detailLimit -FullMinImpr $fullDetailMinImpr -MainQueryLimit $mainQueryLimit -MainPageLimit $mainPageLimit -SeoGeoTotal $seoGeoTotal -SeoGeoQueryCount $seoGeoQueryCount -SeoGeoPageCount $seoGeoPageCount

  if (-not (Test-Path -LiteralPath $queryMd)) { throw "Missing report: $queryMd" }
  if (-not (Test-Path -LiteralPath $queryHtml)) { throw "Missing report: $queryHtml" }
  if (-not (Test-Path -LiteralPath $queryFullMd)) { throw "Missing report: $queryFullMd" }
  if (-not (Test-Path -LiteralPath $queryFullHtml)) { throw "Missing report: $queryFullHtml" }
  if (-not (Test-Path -LiteralPath $pageMd)) { throw "Missing report: $pageMd" }
  if (-not (Test-Path -LiteralPath $pageHtml)) { throw "Missing report: $pageHtml" }
  if (-not (Test-Path -LiteralPath $pageFullMd)) { throw "Missing report: $pageFullMd" }
  if (-not (Test-Path -LiteralPath $pageFullHtml)) { throw "Missing report: $pageFullHtml" }

  Copy-Item -LiteralPath $queryAfter -Destination $queryBaseline -Force
  Copy-Item -LiteralPath $pageAfter -Destination $pageBaseline -Force

  Ensure-Dir -Path $latestDir
  Copy-Item -LiteralPath $queryMd -Destination (Join-Path $latestDir "$queryBaseName.md") -Force
  Copy-Item -LiteralPath $queryHtml -Destination (Join-Path $latestDir "$queryBaseName.html") -Force
  Copy-Item -LiteralPath $queryFullMd -Destination (Join-Path $latestDir "$queryBaseName-full.md") -Force
  Copy-Item -LiteralPath $queryFullHtml -Destination (Join-Path $latestDir "$queryBaseName-full.html") -Force
  Copy-Item -LiteralPath $pageMd -Destination (Join-Path $latestDir "$pageBaseName.md") -Force
  Copy-Item -LiteralPath $pageHtml -Destination (Join-Path $latestDir "$pageBaseName.html") -Force
  Copy-Item -LiteralPath $pageFullMd -Destination (Join-Path $latestDir "$pageBaseName-full.md") -Force
  Copy-Item -LiteralPath $pageFullHtml -Destination (Join-Path $latestDir "$pageBaseName-full.html") -Force

  $archiveDay = Join-Path $archiveDir (Get-Date -Format 'yyyy-MM-dd')
  $archiveWindow = Join-Path $archiveDay $Window
  Ensure-Dir -Path $archiveWindow
  $archivedPath = Join-Path $archiveWindow ("{0}_{1}" -f $stamp, $incoming.Name)
  if ($inputMode -eq 'direct') {
    Copy-Item -LiteralPath $incoming.FullName -Destination $archivedPath -Force
  } else {
    Move-Item -LiteralPath $incoming.FullName -Destination $archivedPath -Force
  }

  $summaryPath = Join-Path $runDir 'run-summary.md'
  @(
    "# Weekly SOP $windowTitle Run Summary"
    ''
    "- Run time: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
    "- Window: $Window / $periodLabel"
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
    "- Input mode: $inputMode"
    "- Input file: $($incoming.Name)"
    "- Query CSV: $($queryCsv.FullName)"
    "- Page CSV: $($pageCsv.FullName)"
    "- Query baseline snapshot: $queryBaselineSnapshot"
    "- Page baseline snapshot: $pageBaselineSnapshot"
    "- Query baseline updated: $queryBaseline"
    "- Page baseline updated: $pageBaseline"
    "- Latest query HTML: $(Join-Path $latestDir "$queryBaseName.html")"
    "- Latest query full HTML: $(Join-Path $latestDir "$queryBaseName-full.html")"
    "- Latest page HTML: $(Join-Path $latestDir "$pageBaseName.html")"
    "- Latest page full HTML: $(Join-Path $latestDir "$pageBaseName-full.html")"
    "- Archived input: $archivedPath"
  ) | Set-Content -LiteralPath $summaryPath -Encoding UTF8

  Write-Host "Weekly SOP $windowTitle workflow completed."
  Write-Host "Report folder: $runDir"
  Write-Host "Latest query HTML: $(Join-Path $latestDir "$queryBaseName.html")"
  Write-Host "Latest query full HTML: $(Join-Path $latestDir "$queryBaseName-full.html")"
  Write-Host "Latest page HTML: $(Join-Path $latestDir "$pageBaseName.html")"
  Write-Host "Latest page full HTML: $(Join-Path $latestDir "$pageBaseName-full.html")"
  if ($querySameAsBaseline -or $pageSameAsBaseline) {
    Write-Host "Note: input matched the current $Window baseline, so this run created/updated latest reports as a baseline snapshot."
  }
} finally {
  if ($tmpDir -and (Test-Path -LiteralPath $tmpDir)) {
    Remove-Item -LiteralPath $tmpDir -Recurse -Force
  }
}

