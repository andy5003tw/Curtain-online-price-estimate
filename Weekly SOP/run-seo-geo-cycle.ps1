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
  $decisionReady = ($dataConfidence -eq 'decision_ready' -and -not $bootstrapped -and $hasCompleteRange -and $queryPageAvailable)
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
  param([string]$Path)
  if ([string]::IsNullOrWhiteSpace($Path) -or -not (Test-Path -LiteralPath $Path -PathType Leaf)) { return @() }
  $rows = @()
  foreach ($row in @(Import-Csv -LiteralPath $Path -Encoding utf8)) {
    $page = [string]$row.page
    if ($page -and $page -ne '(all pages)') { $page = Normalize-PageUrl -Page $page }
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
    [ValidateSet('query', 'page')]
    [string]$Kind,
    [bool]$Required = $false
  )
  $value = $null
  if ($Manifest -and $Manifest.baseline) {
    $value = if ($Kind -eq 'query') { [string]$Manifest.baseline.query } else { [string]$Manifest.baseline.page }
  }
  $path = Resolve-ManifestPath -WeeklyRoot $WeeklyRoot -Value $value
  if ($Required -and ([string]::IsNullOrWhiteSpace($path) -or -not (Test-Path -LiteralPath $path -PathType Leaf))) {
    throw "Missing normalized current $Kind baseline referenced by manifest: $value"
  }
  return $path
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

function Index-RowsByPage {
  param([object[]]$Rows)
  $map = @{}
  foreach ($row in $Rows) {
    if ($row.page -and -not $map.ContainsKey($row.page)) {
      $map[$row.page] = $row
    }
  }
  return $map
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

function Get-TargetCtr {
  param([double]$Position)
  if ($Position -gt 0 -and $Position -le 10) { return 2.5 }
  if ($Position -gt 10 -and $Position -le 15) { return 1.5 }
  return 1.0
}

function Get-ActionType {
  param(
    [double]$Position,
    [double]$Ctr,
    [double]$Impressions,
    [string]$Mode
  )
  $targetCtr = Get-TargetCtr -Position $Position
  if ($Ctr -lt $targetCtr -and $Impressions -gt 0) { return 'CTR 修正 / snippet quick win' }
  if ($Position -ge 8 -and $Position -le 15) { return '排名 8-15 推前 10' }
  if ($Position -gt 15 -and $Impressions -gt 0) { return '內容 / FAQ / 內鏈補強' }
  if ($Mode -eq 'weekly') { return '7d watchlist 微調' }
  return '觀察'
}

function Get-PerformanceOpportunity {
  param(
    [object]$PageMetric28d,
    [object]$QueryMetric28d
  )
  # Content compliance is a quality floor, not a reason to ignore proven
  # search-performance opportunities. Keep this gate deliberately strict so
  # a normal low-volume fluctuation does not create a source-change Round.
  $metric = if ($PageMetric28d) { $PageMetric28d } elseif ($QueryMetric28d) { $QueryMetric28d.row } else { $null }
  if (-not $metric) { return [PSCustomObject]@{ qualifies = $false; reason = '' } }
  $impressions = [double]$metric.impressions
  $position = [double]$metric.position
  $ctr = [double]$metric.ctr
  $targetCtr = Get-TargetCtr -Position $position
  $ctrGap = $targetCtr - $ctr
  if ($impressions -lt 250 -or $position -lt 6 -or $position -gt 15 -or $ctrGap -lt 0.4) {
    return [PSCustomObject]@{ qualifies = $false; reason = '' }
  }
  $queryText = if ($QueryMetric28d) { "; owner query=$($QueryMetric28d.term), impr=$($QueryMetric28d.row.impressions), pos=$(Format-Decimal -Value ([double]$QueryMetric28d.row.position)), CTR=$(Format-Ctr -Value ([double]$QueryMetric28d.row.ctr))" } else { '' }
  return [PSCustomObject]@{
    qualifies = $true
    reason = "28d page impr=$impressions, pos=$(Format-Decimal -Value $position), CTR=$(Format-Ctr -Value $ctr)，低於該排名目標 CTR $(Format-Ctr -Value $targetCtr) $queryText"
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
    [ValidateSet('content_gap', 'performance')][string]$EligibilityKind = 'content_gap',
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
  $targetCtr = Get-TargetCtr -Position $position
  $ctrGap = [Math]::Max(0.0, $targetCtr - $ctr)
  $edgeBonus = if ($position -ge 8 -and $position -le 15) { 45 } elseif ($position -gt 15 -and $position -le 25) { 25 } elseif ($position -gt 0 -and $position -le 10) { 35 } else { 0 }
  $priorityBonus = switch ([string]$Owner.priority) { 'P0' { 30 } 'P1' { 20 } default { 10 } }
  $businessBonus = switch ([string]$Owner.businessValue) { 'critical' { 25 } 'high' { 15 } 'medium' { 8 } default { 0 } }
  $score = ($impressions * $ctrGap / 10.0) + $edgeBonus + $priorityBonus + $businessBonus + [Math]::Max(0, 20 - [int]$Owner.order)
  $keywords = @([string]$Owner.primaryKeyword) + @($Owner.variants)
  $queryEvidence = @()
  foreach ($queryMetric in @($QueryMetric7d, $QueryMetric28d)) {
    if ($queryMetric) {
      $queryEvidence += "$($queryMetric.window) query $($queryMetric.term) impr=$($queryMetric.row.impressions), pos=$(Format-Decimal -Value $queryMetric.row.position), CTR=$(Format-Ctr -Value $queryMetric.row.ctr)"
    }
  }
  if ($queryEvidence.Count -eq 0) { $queryEvidence += '無 exact owner query match' }
  $pageEvidence = "7d page clicks=$clicks7d, impr=$impressions7d, pos=$(Format-Decimal -Value $position7d), CTR=$(Format-Ctr -Value $ctr7d)；28d page clicks=$clicks28d, impr=$impressions28d, pos=$(Format-Decimal -Value $position28d), CTR=$(Format-Ctr -Value $ctr28d)"

  $actionType = Get-ActionType -Position $position -Ctr $ctr -Impressions $impressions -Mode 'monthly'
  $fixedActions = if ($EligibilityKind -eq 'performance') {
    "以既有 owner keyword 為限，優先優化 title/meta description 的價格、材質與 CTA 表達；首屏短答案須直接對齊搜尋意圖；檢查 2-3 個內鏈錨文字是否將泛用詞導回正確 owner；不要為了補字數重做已合規的 FAQ/Schema，也不要搶其他 owner 詞。"
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
    $(if ($EligibilityKind -eq 'performance') { 'performance_opportunity' } else { '' })
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
    reason             = "$pageEvidence；$($queryEvidence -join '；')；eligibility=$EligibilityKind；$EligibilityReason；source gaps=$gapText"
    fixedActions       = $fixedActions
    required_validations = $requiredValidations
    validationCommands = ($requiredValidations -join "`n")
  }
}

function Convert-ActionsToMarkdownTable {
  param([object[]]$Rows)
  $headers = @('priority', 'action_id', 'page', 'ownerKeywords', 'intentType', '7d impressions', '7d CTR', '7d position', '28d impressions', '28d CTR', '28d position', 'actionType', 'reason', 'fixedActions', 'validationCommands')
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
  $headers = @('priority', 'action_id', 'page', 'ownerKeywords', 'intentType', '7d impressions', '7d CTR', '7d position', '28d impressions', '28d CTR', '28d position', 'actionType', 'reason', 'fixedActions', 'validationCommands')
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
  param(
    [string]$Text,
    [string]$Value
  )
  if ([string]::IsNullOrWhiteSpace($Text) -or [string]::IsNullOrWhiteSpace($Value)) { return $false }
  return $Text.IndexOf($Value, [System.StringComparison]::OrdinalIgnoreCase) -ge 0
}

function Get-OwnerSourceCompliance {
  param(
    [object]$Owner,
    [string]$RepoRoot
  )
  $relativePaths = @(Get-RequiredSourceForPage -Page $Owner.ownerPage)
  $sourceTexts = @()
  $missingFiles = @()
  foreach ($relativePath in $relativePaths) {
    $fullPath = Join-Path $RepoRoot ($relativePath.Replace('/', '\'))
    if (Test-Path -LiteralPath $fullPath -PathType Leaf) {
      $sourceTexts += Read-Utf8Text -Path $fullPath
    } else {
      $missingFiles += $relativePath
    }
  }
  $text = $sourceTexts -join "`n"
  $keyword = Test-TextContains -Text $text -Value ([string]$Owner.primaryKeyword)
  $metadata = ((Test-TextContains -Text $text -Value 'meta_title') -and (Test-TextContains -Text $text -Value 'meta_description')) -or
    ((Test-TextContains -Text $text -Value 'metadata') -and (Test-TextContains -Text $text -Value 'title') -and (Test-TextContains -Text $text -Value 'description'))
  $h1 = Test-TextContains -Text $text -Value '<h1'
  $faq = (Test-TextContains -Text $text -Value 'FAQPage') -or (Test-TextContains -Text $text -Value 'faqs') -or (Test-TextContains -Text $text -Value 'faqSchema')
  $jsonLd = (Test-TextContains -Text $text -Value 'application/ld+json') -or (Test-TextContains -Text $text -Value 'JSON.stringify')
  $internalLink = (Test-TextContains -Text $text -Value '<Link') -or (Test-TextContains -Text $text -Value 'internalLinks') -or (Test-TextContains -Text $text -Value 'href=')
  $checks = [ordered]@{
    keyword = $keyword
    metadata = $metadata
    h1 = $h1
    faq = $faq
    json_ld = $jsonLd
    internal_link = $internalLink
    source_files = ($missingFiles.Count -eq 0)
  }
  $missing = @($checks.Keys | Where-Object { -not [bool]($checks[$_]) })
  return [PSCustomObject]@{
    compliant = ($missing.Count -eq 0)
    checks = [PSCustomObject]$checks
    missing = $missing
    requiredSource = $relativePaths
    missingSource = $missingFiles
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
    source_compliant = [bool]$Compliance.compliant
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

function Convert-ObservationsToMarkdownTable {
  param([object[]]$Rows)
  $headers = @('order', 'page', 'primary_keyword', '7d clicks', '7d impressions', '7d CTR', '7d position', '7d query', '7d query impressions', '28d clicks', '28d impressions', '28d CTR', '28d position', '28d query', '28d query impressions', 'source_compliant', 'cooldown_source', 'cooldown_until', 'disposition', 'reason')
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
  $headers = @('order', 'page', 'primary_keyword', '7d clicks', '7d impressions', '7d CTR', '7d position', '28d clicks', '28d impressions', '28d CTR', '28d position', 'source_compliant', 'cooldown_source', 'cooldown_until', 'disposition', 'reason')
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
    Sort-Object -Property @{ Expression = { [double]$_.row.score }; Descending = $true }, strategicOrder)

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
  $lines += ''
  $lines += ('Mode: {0} -> {1}（{2}）' -f $RequestedMode, $EffectiveMode, $ModeLabel)
  $lines += ''
  $lines += '## Optional Opportunities'
  $lines += ''
  if (@($Rows).Count -gt 0) {
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
$registryRelativePath = Get-RelativePortablePath -BasePath $weeklyRoot -Path $registryFullPath
$registrySha = Get-Sha256File -Path $registryFullPath
$registryVersion = if ($null -ne $registry.schemaVersion) { [int]$registry.schemaVersion } else { 1 }

$query7dPath = Get-BaselinePathFromManifest -WeeklyRoot $weeklyRoot -Manifest $fresh7d.manifest -Kind query -Required $true
$page7dPath = Get-BaselinePathFromManifest -WeeklyRoot $weeklyRoot -Manifest $fresh7d.manifest -Kind page -Required $true
$query28dPath = Get-BaselinePathFromManifest -WeeklyRoot $weeklyRoot -Manifest $fresh28d.manifest -Kind query -Required $false
$page28dPath = Get-BaselinePathFromManifest -WeeklyRoot $weeklyRoot -Manifest $fresh28d.manifest -Kind page -Required $false

$queryRows7d = @(Get-NormalizedBaselineRows -Path $query7dPath)
$pageRows7d = @(Get-NormalizedBaselineRows -Path $page7dPath)
$queryRows28d = @(Get-NormalizedBaselineRows -Path $query28dPath)
$pageRows28d = @(Get-NormalizedBaselineRows -Path $page28dPath)
$queryMap7d = Index-RowsByQuery -Rows $queryRows7d
$queryMap28d = Index-RowsByQuery -Rows $queryRows28d
$pageMap7d = Index-RowsByPage -Rows $pageRows7d
$pageMap28d = Index-RowsByPage -Rows $pageRows28d

$sourceProvenance = Get-SourceProvenance -Owners $owners -RepoRoot $repoRoot
$sourceFiles = @($sourceProvenance.source_files)
$sourceOwnerBindings = @($sourceProvenance.owners)
$sourceFingerprint = [string]$sourceProvenance.source_fingerprint
$actionHistoryPath = Join-Path $weeklyRoot 'history\curtain-online\seo-geo-action-history.json'
$actionHistoryRelativePath = Get-RelativePortablePath -BasePath $weeklyRoot -Path $actionHistoryPath
$actionHistorySha = Get-Sha256File -Path $actionHistoryPath
$actionHistoryEntries = @(Get-ActionHistoryEntries -Path $actionHistoryPath)
$actionHistoryBinding = [ordered]@{
  path = $actionHistoryRelativePath
  sha256 = $actionHistorySha
  entry_count = $actionHistoryEntries.Count
}
$candidateItems = @()
$observations = @()
$ownerAnalyses = @()
foreach ($owner in $owners) {
  $page = [string]$owner.ownerPage
  $terms = @(Get-QueryTerms -Owner $owner)
  $queryMetric7d = Get-BestQueryMetric -Terms $terms -Map7d $queryMap7d -Map28d @{} -Mode 'weekly'
  $queryMetric28d = Get-BestQueryMetric -Terms $terms -Map7d @{} -Map28d $queryMap28d -Mode 'monthly'
  $pageMetric7d = if ($pageMap7d.ContainsKey($page)) { $pageMap7d[$page] } else { $null }
  $pageMetric28d = if ($pageMap28d.ContainsKey($page)) { $pageMap28d[$page] } else { $null }
  $compliance = Get-OwnerSourceCompliance -Owner $owner -RepoRoot $repoRoot
  $registryCooldown = Get-CooldownStatus -LastChangedAt ([string]$owner.lastChangedAt)
  $row = New-ActionRow -Priority 0 -Owner $owner -PageMetric7d $pageMetric7d -PageMetric28d $pageMetric28d -QueryMetric7d $queryMetric7d -QueryMetric28d $queryMetric28d -Compliance $compliance
  $actionHistoryCooldown = Get-ActionHistoryCooldown -Entries $actionHistoryEntries -Fingerprint ([string]$row.fingerprint)
  $performanceOpportunity = Get-PerformanceOpportunity -PageMetric28d $pageMetric28d -QueryMetric28d $queryMetric28d

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
    $reason = "source 已合規，但符合成效優化門檻：$($performanceOpportunity.reason)"
    $row = New-ActionRow -Priority 0 -Owner $owner -PageMetric7d $pageMetric7d -PageMetric28d $pageMetric28d -QueryMetric7d $queryMetric7d -QueryMetric28d $queryMetric28d -Compliance $compliance -EligibilityKind performance -EligibilityReason $performanceOpportunity.reason
    $actionHistoryCooldown = Get-ActionHistoryCooldown -Entries $actionHistoryEntries -Fingerprint ([string]$row.fingerprint)
    if ($actionHistoryCooldown.active) {
      $disposition = 'action_history_cooldown'
      $reason = "相同性能優化 action fingerprint 已於 $($actionHistoryCooldown.completed_at) 完成，action-history 28d cooldown 至 $($actionHistoryCooldown.cooldown_until)。"
    }
  } elseif ($compliance.compliant) {
    $disposition = 'source_compliant'
    $reason = 'keyword、metadata、H1、FAQ、JSON-LD、internal link 已符合，且未達成效優化門檻。'
  }

  $observation = New-ObservationRow -Owner $owner -PageMetric7d $pageMetric7d -PageMetric28d $pageMetric28d -QueryMetric7d $queryMetric7d -QueryMetric28d $queryMetric28d -Compliance $compliance -RegistryCooldown $registryCooldown -ActionHistoryCooldown $actionHistoryCooldown -ActionFingerprint ([string]$row.fingerprint) -Disposition $disposition -Reason $reason
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
    observation = $observation
  }
  $ownerAnalyses += $analysis
  if ($cycleDecisionReady -and ($disposition -eq 'actionable' -or $disposition -eq 'performance_actionable') -and -not $registryCooldown.active -and -not $actionHistoryCooldown.active) {
    $candidateItems += [PSCustomObject]@{ page = $page; strategicOrder = [int]$owner.order; row = $row }
  }
}

$actionQueue = @(
  if ($cycleDecisionReady) {
    New-ActionQueue -CandidateItems $candidateItems -BatchSize 5 -MaximumBatchSize 6 -MaxRounds 3
  }
)
$queuedPages = @($actionQueue | ForEach-Object { $_.targets } | Select-Object -Unique)
foreach ($observation in $observations) {
  if ($queuedPages -contains $observation.page) {
    $observation.disposition = 'queued'
    $observation.reason = 'decision-ready 且通過 action eligibility；已排入動態 Round。'
  } elseif ($observation.disposition -eq 'actionable') {
    $observation.disposition = 'observation'
    $observation.reason = if ($candidateItems.Count -lt 2) { '可行 owner 少於 2 頁，不建立單頁 Round。' } else { '超出本 cycle 最多 3 個 Round，保留觀察。' }
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
$minorOpportunities = @()
$watchlist = $observations

$monitorReasons = @()
if ($requestedMode -eq 'weekly') { $monitorReasons += 'weekly mode 固定只產生 observation' }
if (-not $fresh28d.fresh) { $monitorReasons += "28d=$($fresh28d.status)" }
if (-not $fresh7d.decision_ready) { $monitorReasons += "7d confidence=$($fresh7d.data_confidence)" }
if (-not $fresh28d.decision_ready) { $monitorReasons += "28d confidence=$($fresh28d.data_confidence)" }
if ($fresh7d.bootstrapped -or $fresh28d.bootstrapped) { $monitorReasons += 'bootstrap baseline 尚無前期比較' }
if (-not $sameSnapshotFamily) { $monitorReasons += '7d/28d snapshot family 或資料截止日不一致' }
if ($cycleDecisionReady -and $actionQueue.Count -eq 0) { $monitorReasons += '所有 owner 皆無內容缺口／成效優化機會、正在 cooldown，或可行頁少於 2' }
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
    [string]$WeeklyRoot
  )
  if (-not $Freshness -or -not $Freshness.manifest) { return $null }
  return [ordered]@{
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
    data_confidence = [string]$Freshness.data_confidence
    decision_ready = [bool]$Freshness.decision_ready
    bootstrapped = [bool]$Freshness.bootstrapped
  }
}

$snapshot = [ordered]@{
  '7d' = New-SnapshotBinding -Freshness $fresh7d -QueryPath $query7dPath -PagePath $page7dPath -WeeklyRoot $weeklyRoot
  '28d' = New-SnapshotBinding -Freshness $fresh28d -QueryPath $query28dPath -PagePath $page28dPath -WeeklyRoot $weeklyRoot
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

$optionalPrompt = New-OptionalOpportunitiesPrompt -Rows @() -RequestedMode $requestedMode -EffectiveMode $effectiveMode -ModeLabel $modeLabel
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
  technical_tasks = $technicalTasks
  optional_opportunities = @()
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
  active_round = if ($actionQueue.Count -gt 0) { 1 } else { 0 }
  next_round = if ($actionQueue.Count -gt 0) { 1 } else { 0 }
  completed_rounds = @()
  copied_rounds = @()
  total_rounds = $actionQueue.Count
  rounds = $stateRounds
  prompt_files = $roundPromptFiles
  receipt_path = $receiptRelativePath
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
  foreach ($name in @('queue_id', 'generated_at', 'status', 'active_round', 'next_round', 'completed_rounds', 'copied_rounds', 'last_copied_round', 'last_copied_at', 'last_validated_round', 'last_validation_receipt', 'last_validated_at', 'local_validated_at')) {
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
Write-Utf8NoBom -Path $outputMd -Text ($md -join $lineFeed)

$html = @()
$html += '<!doctype html><html lang="zh-Hant"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1">'
$html += '<title>Curtain Online SEO/GEO Action Plan</title>'
$html += '<style>body{font-family:"Microsoft JhengHei",Arial,sans-serif;margin:0;background:#f6f8fb;color:#18324a}main{max-width:1280px;margin:0 auto;padding:28px}h1{color:#0b2f4a}h2{margin-top:28px;border-left:5px solid #2f7d68;padding-left:10px}.meta,.note{background:#fff;border:1px solid #d9e3ec;border-radius:8px;padding:14px 16px;margin:14px 0;line-height:1.7;overflow:auto}table{width:100%;border-collapse:collapse;background:#fff;font-size:12px}th,td{border:1px solid #d9e3ec;padding:7px;vertical-align:top}th{background:#eaf2f8;text-align:left}</style>'
$html += '</head><body><main><h1>Curtain Online SEO/GEO Action Plan</h1>'
$html += '<div class="meta">狀態：' + (Escape-Html -Value $baselineLabel) + '<br>Cycle：' + (Escape-Html -Value $cycleKey) + '<br>Registry：' + (Escape-Html -Value $registryRelativePath) + '</div>'
if ($isObservationOnly) {
  $html += '<h2>Observation Only / 0 Rounds</h2><div class="note">' + (Escape-Html -Value $monitorReason) + '</div>'
  $html += Convert-ObservationsToHtmlTable -Rows $observations
} else {
  foreach ($round in $actionQueue) {
    $html += '<h2>Round ' + (Escape-Html -Value ([string]$round.round)) + '</h2>'
    $html += Convert-ActionsToHtmlTable -Rows $round.actions
  }
  $html += '<h2>Compliant / Cooldown Observations</h2>'
  $html += Convert-ObservationsToHtmlTable -Rows @($observations | Where-Object { $_.disposition -ne 'queued' })
}
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
  technical_tasks = $technicalTasks
  optional_opportunities = @()
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
