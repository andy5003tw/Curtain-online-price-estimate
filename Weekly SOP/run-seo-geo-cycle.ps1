param(
  [ValidateSet('auto', 'weekly', 'monthly')]
  [string]$Mode = 'auto'
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

function Get-WindowFreshness {
  param(
    [string]$LatestDir,
    [string]$Window,
    [int]$MaxAgeDays
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
      report_folder = $manifest.report_folder
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
      report_folder = $manifest.report_folder
      missing_reports = @()
    }
  }

  $missingReports = @()
  if ($manifest.latest_reports) {
    foreach ($prop in $manifest.latest_reports.PSObject.Properties) {
      if (-not (Test-Path -LiteralPath ([string]$prop.Value) -PathType Leaf)) {
        $missingReports += [string]$prop.Value
      }
    }
  }

  $ageDays = [int][Math]::Floor(((Get-Date) - $runTime).TotalDays)
  $isFresh = ($ageDays -le $MaxAgeDays -and $missingReports.Count -eq 0)
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
    manifest_path = $manifestPath
    report_folder = $manifest.report_folder
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

function Get-ReportRows {
  param([string]$Path)
  if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { return @() }
  $text = Read-Utf8Text -Path $Path
  $rawRows = Get-MarkdownTable -Text $text -HeadingPrefix '## 決策明細'
  if ($rawRows.Count -eq 0) {
    $rawRows = Get-FirstMarkdownTable -Text $text
  }
  $rows = @()
  foreach ($row in $rawRows) {
    $page = Normalize-PageUrl -Page ([string]$row.'頁面')
    if ([string]::IsNullOrWhiteSpace($page)) { $page = [string]$row.'頁面' }
    $rows += [PSCustomObject]@{
      title               = [string]$row.'網頁中文抬頭'
      page                = $page
      query               = [string]$row.'查詢'
      beforeImpressions   = [int](Parse-Number -Value $row.'改版前曝光')
      impressions         = [int](Parse-Number -Value $row.'改版後曝光')
      growth              = (Parse-Number -Value $row.'曝光成長率')
      beforePosition      = (Parse-Number -Value $row.'改版前排名')
      position            = (Parse-Number -Value $row.'改版後排名')
      positionImprovement = (Parse-Number -Value $row.'排名改善')
      beforeCtr           = (Parse-Number -Value $row.'改版前CTR')
      ctr                 = (Parse-Number -Value $row.'改版後CTR')
      ctrDiff             = (Parse-Number -Value $row.'CTR差異(百分點)')
    }
  }
  return $rows
}

function Get-KpiDiffs {
  param([string]$Path)
  if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { return @() }
  $text = Read-Utf8Text -Path $Path
  $rows = Get-MarkdownTable -Text $text -HeadingPrefix '## KPI 摘要'
  return @($rows | ForEach-Object { Parse-Number -Value $_.'差異' })
}

function Test-BaselineRefresh {
  param([string[]]$Paths)
  $diffs = @()
  foreach ($path in $Paths) {
    $diffs += Get-KpiDiffs -Path $path
  }
  if ($diffs.Count -eq 0) { return $false }
  foreach ($diff in $diffs) {
    if ([Math]::Abs([double]$diff) -gt 0.0001) { return $false }
  }
  return $true
}

function Resolve-ReportPath {
  param(
    [string]$Dir,
    [string]$BaseName
  )
  $full = Join-Path $Dir "$BaseName-full.md"
  if (Test-Path -LiteralPath $full -PathType Leaf) { return $full }
  return (Join-Path $Dir "$BaseName.md")
}

function Get-LatestKeywordPoolPath {
  param([string]$WeeklyRoot)
  $pool = Get-ChildItem -LiteralPath $WeeklyRoot -File -Filter '12-keyword-pool-v*.md' |
    Sort-Object LastWriteTime -Descending |
    Select-Object -First 1
  if (-not $pool) {
    throw "Missing keyword pool: $WeeklyRoot\12-keyword-pool-v*.md"
  }
  return $pool.FullName
}

function Get-KeywordPoolRows {
  param([string]$Path)
  $text = Read-Utf8Text -Path $Path
  $rawRows = @()
  foreach ($prefix in @('## 3)', '## 2)')) {
    $rawRows = @(Get-MarkdownTable -Text $text -HeadingPrefix $prefix)
    if ($rawRows.Count -gt 0) { break }
  }
  $rows = @()
  foreach ($row in $rawRows) {
    $keyword = Remove-MdCode -Value $row.'主攻詞（產品/交易/GEO 意圖）'
    $owner = Normalize-PageUrl -Page $row.'綁定主頁'
    $rootQuery = Remove-MdCode -Value $row.'依據根詞（GSC）'
    $signal = Remove-MdCode -Value $row.'7d / 28d 訊號'
    if ([string]::IsNullOrWhiteSpace($keyword)) {
      $keyword = Remove-MdCode -Value $row.keyword
    }
    if ([string]::IsNullOrWhiteSpace($owner)) {
      $owner = Normalize-PageUrl -Page $row.'owner page'
    }
    if ([string]::IsNullOrWhiteSpace($signal)) {
      $evidence = Remove-MdCode -Value $row.'28d / 7d evidence'
      $actionType = Remove-MdCode -Value $row.'action type'
      $signal = (@($evidence, $actionType) | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }) -join '；'
    }
    if ([string]::IsNullOrWhiteSpace($keyword) -or [string]::IsNullOrWhiteSpace($owner)) { continue }
    $rows += [PSCustomObject]@{
      order        = [int](Parse-Number -Value $row.'#')
      keyword      = $keyword
      rootQuery    = $rootQuery
      signal       = $signal
      ownerPage    = $owner
    }
  }
  if ($rows.Count -eq 0) {
    throw "Could not parse keyword-owner rows from $Path"
  }
  return $rows
}

function Get-BatchPagesFromPool {
  param([string]$Path)
  $lines = @((Read-Utf8Text -Path $Path) -split "`r?`n")
  $inside = $false
  $pages = @()
  foreach ($line in $lines) {
    if ($line -match '^##\s+\d+\).*(執行順序|優化順序)') {
      $inside = $true
      continue
    }
    if (-not $inside -and $line -match '^##\s+4\)') {
      $inside = $true
      continue
    }
    if ($inside -and $line -like '## *') { break }
    if ($inside -and $line -match '^\s*\d+\.\s+`([^`]+)`') {
      $pages += (Normalize-PageUrl -Page $Matches[1])
    }
  }
  return @($pages | Where-Object { $_ } | Select-Object -Unique)
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
  param([object[]]$Rows)
  $terms = @()
  foreach ($row in $Rows) {
    $terms += [string]$row.keyword
    $terms += @(([string]$row.rootQuery) -split '\s*/\s*')
  }
  return @($terms | ForEach-Object { $_.Trim() } | Where-Object { $_ -and $_ -ne '服務交易意圖擴寫' -and $_ -ne '產品交易意圖擴寫' } | Select-Object -Unique)
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
  } elseif ($Page -like '*/products/*') {
    $base += '產品頁聚焦材質/價格/適用情境，不寫成重複 GEO 頁。'
  } elseif ($Page -like '*/location/*') {
    $base += 'GEO 頁需在 title、H1、FAQ、內鏈都看得到地區詞。'
  } else {
    $base += '首頁定位為品牌與估價入口，不與產品頁或 GEO 頁搶同一長尾詞。'
  }
  return ($base -join '；')
}

function New-ActionRow {
  param(
    [int]$Priority,
    [string]$Page,
    [object[]]$OwnerRows,
    [object]$PageMetric7d,
    [object]$PageMetric28d,
    [object]$QueryMetric,
    [string]$Mode,
    [int]$StrategicOrder,
    [bool]$BaselineRefresh
  )

  $metric = if ($Mode -eq 'monthly' -and $PageMetric28d) { $PageMetric28d } else { $PageMetric7d }
  if (-not $metric -and $QueryMetric) { $metric = $QueryMetric.row }

  $impressions7d = if ($PageMetric7d) { [int]$PageMetric7d.impressions } else { 0 }
  $impressions28d = if ($PageMetric28d) { [int]$PageMetric28d.impressions } else { 0 }
  $ctr = if ($metric) { [double]$metric.ctr } else { 0.0 }
  $position = if ($metric) { [double]$metric.position } else { 0.0 }
  $impressions = if ($metric) { [double]$metric.impressions } else { 0.0 }
  $targetCtr = Get-TargetCtr -Position $position
  $ctrGap = [Math]::Max(0.0, $targetCtr - $ctr)
  $edgeBonus = if ($position -ge 8 -and $position -le 15) { 45 } elseif ($position -gt 15 -and $position -le 25) { 25 } elseif ($position -gt 0 -and $position -le 10) { 35 } else { 0 }
  $score = ($impressions * $ctrGap / 10.0) + $edgeBonus + [Math]::Max(0, 30 - ($StrategicOrder * 3))
  $keywords = @($OwnerRows | Sort-Object order | ForEach-Object { $_.keyword })
  $queryEvidence = if ($QueryMetric) {
    $queryTerm = [string]$QueryMetric.term
    $queryWindow = [string]$QueryMetric.window
    $queryRow = $QueryMetric.row
    "$queryWindow query $queryTerm impr=$($queryRow.impressions), pos=$(Format-Decimal -Value $queryRow.position), CTR=$(Format-Ctr -Value $queryRow.ctr)"
  } else {
    '無 exact query match，依 owner pool 與 page metric 判讀'
  }
  $pageEvidence = if ($metric) {
    "page impr=$($metric.impressions), pos=$(Format-Decimal -Value $metric.position), CTR=$(Format-Ctr -Value $metric.ctr)"
  } else {
    'page metric n/a'
  }
  if ($BaselineRefresh) {
    $pageEvidence += '；same-baseline，僅作現況機會判讀'
  }

  $actionType = Get-ActionType -Position $position -Ctr $ctr -Impressions $impressions -Mode $Mode
  return [PSCustomObject]@{
    priority           = $Priority
    page               = $Page
    ownerKeywords      = ($keywords -join ' / ')
    intentType         = (Get-IntentType -Page $Page -ActionType $actionType)
    '7d impressions'   = $impressions7d
    '28d impressions'  = $impressions28d
    CTR                = (Format-Ctr -Value $ctr)
    position           = (Format-Decimal -Value $position)
    actionType         = $actionType
    score              = (Format-Decimal -Value $score)
    reason             = "$pageEvidence；$queryEvidence"
    fixedActions       = (Get-PageTask -Page $Page -Keywords $keywords)
    validationCommands = 'node .agents/skills/curtain-online-seo-geo/scripts/keyword-owner-check.mjs; npm.cmd run build; npm.cmd run seo:check; npm.cmd run seo:preflight'
  }
}

function Convert-ActionsToMarkdownTable {
  param([object[]]$Rows)
  $headers = @('priority', 'page', 'ownerKeywords', 'intentType', '7d impressions', '28d impressions', 'CTR', 'position', 'actionType', 'reason', 'fixedActions', 'validationCommands')
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
  $headers = @('priority', 'page', 'ownerKeywords', 'intentType', '7d impressions', '28d impressions', 'CTR', 'position', 'actionType', 'reason', 'fixedActions', 'validationCommands')
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
  } elseif ($Page -like '*/products/*') {
    $sources += 'src/data/products.ts'
    $sources += 'src/app/products/[slug]/page.tsx'
    $sources += 'src/lib/seo.ts'
  } elseif ($Page -like '*/products/' -or $Page -like '*/products') {
    $sources += 'src/app/products/page.tsx'
    $sources += 'src/data/products.ts'
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
    $sources += 'src/app/cases/page.tsx'
    $sources += 'src/lib/seo.ts'
  } else {
    $sources += 'src/app'
    $sources += 'src/lib/seo.ts'
  }

  return @($sources | Select-Object -Unique)
}

function Copy-ActionRowForQueue {
  param(
    [object]$Row,
    [int]$Priority
  )

  return [PSCustomObject]@{
    priority           = $Priority
    page               = $Row.page
    ownerKeywords      = $Row.ownerKeywords
    intentType         = $Row.intentType
    '7d impressions'   = $Row.'7d impressions'
    '28d impressions'  = $Row.'28d impressions'
    CTR                = $Row.CTR
    position           = $Row.position
    actionType         = $Row.actionType
    score              = $Row.score
    reason             = $Row.reason
    fixedActions       = $Row.fixedActions
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

  return [PSCustomObject]@{
    round              = $Round
    type               = 'page-batch'
    priority           = $Round
    title              = "Round $Round page-batch"
    targetCount        = $rows.Count
    targets            = @($rows | ForEach-Object { $_.page })
    ownerKeywords      = @($rows | ForEach-Object { $_.ownerKeywords })
    requiredSource     = @($requiredSource | Select-Object -Unique)
    validationCommands = @(
      'node .agents/skills/curtain-online-seo-geo/scripts/keyword-owner-check.mjs',
      'npm.cmd run build',
      'npm.cmd run seo:check',
      'npm.cmd run seo:preflight'
    )
    actions            = $rows
  }
}

function New-ActionQueue {
  param(
    [object[]]$CandidateItems,
    [string[]]$BatchPages,
    [int]$BatchSize = 6,
    [int]$MaxRounds = 3
  )

  $orderedItems = @()
  if ($BatchPages.Count -gt 0) {
    foreach ($page in $BatchPages) {
      $item = @($CandidateItems | Where-Object { $_.page -eq $page } | Select-Object -First 1)
      if ($item) { $orderedItems += $item }
    }
    $orderedItems += @($CandidateItems |
      Where-Object { $BatchPages -notcontains $_.page } |
      Sort-Object -Property @{ Expression = { [double]$_.row.score }; Descending = $true }, strategicOrder)
  } else {
    $orderedItems = @($CandidateItems |
      Sort-Object -Property @{ Expression = { [double]$_.row.score }; Descending = $true }, strategicOrder)
  }

  $deduped = @()
  $seen = @{}
  foreach ($item in $orderedItems) {
    if (-not $seen.ContainsKey($item.page)) {
      $seen[$item.page] = $true
      $deduped += $item
    }
  }

  $rounds = @()
  $index = 0
  $round = 1
  while ($index -lt $deduped.Count -and $round -le $MaxRounds) {
    $take = [Math]::Min($BatchSize, $deduped.Count - $index)
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
    [string]$ModeLabel
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
  $lines += '- `node .agents/skills/curtain-online-seo-geo/scripts/keyword-owner-check.mjs`'
  $lines += '- `npm.cmd run build`'
  $lines += '- `npm.cmd run seo:check`'
  $lines += '- `npm.cmd run seo:preflight`'
  $lines += ''
  $lines += '## Report Back'
  $lines += ''
  $lines += ('- 回報已修改的 source files、Round {0} 頁面、驗證 pass/fail。' -f $Round.round)
  $lines += '- build/deploy/FTP log 只回報摘要與最後錯誤，不貼逐檔清單。'

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
  $lines += '- 若建議加做，最多挑 1-3 頁，並說明原因；不要自行擴大成新一輪完整 6 頁。'
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

$weeklyRoot = Join-Path $PSScriptRoot '.'
$repoRoot = Split-Path -Parent $PSScriptRoot
$latestRoot = Join-Path $weeklyRoot 'latest'
$latest7d = Join-Path $latestRoot '7d'
$latest28d = Join-Path $latestRoot '28d'
$fresh7d = Get-WindowFreshness -LatestDir $latest7d -Window '7d' -MaxAgeDays 10
$fresh28d = Get-WindowFreshness -LatestDir $latest28d -Window '28d' -MaxAgeDays 35

$requestedMode = $Mode
if ($Mode -eq 'auto') {
  if (-not $fresh7d.fresh) {
    throw "Cannot generate SEO/GEO action plan: latest 7d report is not fresh. $($fresh7d.text)"
  }
  $effectiveMode = if ($fresh28d.fresh) { 'monthly' } else { 'weekly' }
} else {
  $effectiveMode = $Mode
  if (-not $fresh7d.fresh) {
    throw "Cannot generate SEO/GEO action plan: latest 7d report is not fresh. $($fresh7d.text)"
  }
  if ($effectiveMode -eq 'monthly' -and -not $fresh28d.fresh) {
    throw "Cannot generate monthly SEO/GEO action plan: latest 28d report is not fresh. $($fresh28d.text)"
  }
}

$query7dPath = Resolve-ReportPath -Dir $latest7d -BaseName 'gsc-query-kpi-diff-report(查詢-7天)'
$page7dPath = Resolve-ReportPath -Dir $latest7d -BaseName 'gsc-page-kpi-diff-report(網頁-7天)'
$query28dPath = Resolve-ReportPath -Dir $latest28d -BaseName 'gsc-query-kpi-diff-report(查詢-28天)'
$page28dPath = Resolve-ReportPath -Dir $latest28d -BaseName 'gsc-page-kpi-diff-report(網頁-28天)'

if (-not (Test-Path -LiteralPath $query7dPath -PathType Leaf)) {
  throw "Missing latest 7d query report: $query7dPath. Please upload the 7-day GSC ZIP first."
}
if (-not (Test-Path -LiteralPath $page7dPath -PathType Leaf)) {
  throw "Missing latest 7d page report: $page7dPath. Please upload the 7-day GSC ZIP first."
}
if ($effectiveMode -eq 'monthly' -and -not (Test-Path -LiteralPath $query28dPath -PathType Leaf)) {
  throw "Missing latest 28d query report: $query28dPath. Use -Mode weekly or upload the 28-day GSC ZIP first."
}
if ($effectiveMode -eq 'monthly' -and -not (Test-Path -LiteralPath $page28dPath -PathType Leaf)) {
  throw "Missing latest 28d page report: $page28dPath. Use -Mode weekly or upload the 28-day GSC ZIP first."
}

Ensure-Dir -Path $latestRoot

$poolPath = Get-LatestKeywordPoolPath -WeeklyRoot $weeklyRoot
$poolRows = Get-KeywordPoolRows -Path $poolPath
$batchPages = @(Get-BatchPagesFromPool -Path $poolPath | Select-Object -First 6)

$queryRows7d = Get-ReportRows -Path $query7dPath
$pageRows7d = Get-ReportRows -Path $page7dPath
$queryRows28d = if (Test-Path -LiteralPath $query28dPath -PathType Leaf) { Get-ReportRows -Path $query28dPath } else { @() }
$pageRows28d = if (Test-Path -LiteralPath $page28dPath -PathType Leaf) { Get-ReportRows -Path $page28dPath } else { @() }

$queryMap7d = Index-RowsByQuery -Rows $queryRows7d
$queryMap28d = Index-RowsByQuery -Rows $queryRows28d
$pageMap7d = Index-RowsByPage -Rows $pageRows7d
$pageMap28d = Index-RowsByPage -Rows $pageRows28d

$baselinePaths = @($query7dPath, $page7dPath)
if (Test-Path -LiteralPath $query28dPath -PathType Leaf) { $baselinePaths += $query28dPath }
if (Test-Path -LiteralPath $page28dPath -PathType Leaf) { $baselinePaths += $page28dPath }
$baselineRefresh = Test-BaselineRefresh -Paths $baselinePaths

$grouped = $poolRows | Group-Object ownerPage
$candidateItems = @()
foreach ($group in $grouped) {
  $page = [string]$group.Name
  $ownerRows = @($group.Group)
  $terms = Get-QueryTerms -Rows $ownerRows
  $queryMetric = Get-BestQueryMetric -Terms $terms -Map7d $queryMap7d -Map28d $queryMap28d -Mode $effectiveMode
  $m7 = if ($pageMap7d.ContainsKey($page)) { $pageMap7d[$page] } else { $null }
  $m28 = if ($pageMap28d.ContainsKey($page)) { $pageMap28d[$page] } else { $null }
  $strategicOrder = 99
  $batchIndex = [Array]::IndexOf($batchPages, $page)
  if ($batchIndex -ge 0) {
    $strategicOrder = $batchIndex + 1
  } else {
    $strategicOrder = [int](@($ownerRows | Sort-Object order | Select-Object -First 1).order)
  }
  $row = New-ActionRow -Priority 0 -Page $page -OwnerRows $ownerRows -PageMetric7d $m7 -PageMetric28d $m28 -QueryMetric $queryMetric -Mode $effectiveMode -StrategicOrder $strategicOrder -BaselineRefresh $baselineRefresh
  $candidateItems += [PSCustomObject]@{
    page = $page
    strategicOrder = $strategicOrder
    row = $row
  }
}

$pageBatchSize = if ($batchPages.Count -gt 0 -and $batchPages.Count -lt 6) { $batchPages.Count } else { 6 }
$actionQueue = @(New-ActionQueue -CandidateItems $candidateItems -BatchPages $batchPages -BatchSize $pageBatchSize -MaxRounds 3)
if ($actionQueue.Count -eq 0) {
  throw 'No SEO/GEO action candidates could be generated from latest reports and keyword pool.'
}

$currentRound = $actionQueue[0]
$actions = @($currentRound.actions)
$round1Source = @($currentRound.requiredSource)
$queuedPages = @($actionQueue | ForEach-Object { $_.targets } | Select-Object -Unique)

$selectedPages = @($actions | ForEach-Object { $_.page })
$watchlist = @()
$watchPriority = 1
foreach ($item in @($candidateItems | Where-Object { $selectedPages -notcontains $_.page } | Sort-Object -Property @{ Expression = { [double]$_.row.score }; Descending = $true }, strategicOrder | Select-Object -First 8)) {
  $row = $item.row
  $row.priority = $watchPriority
  $watchlist += $row
  $watchPriority++
}

$minorOpportunities = @()
$minorPriority = 1
foreach ($item in @($candidateItems |
  Where-Object { $queuedPages -notcontains $_.page } |
  Sort-Object -Property @{ Expression = { [double]$_.row.score }; Descending = $true }, strategicOrder |
  Select-Object -First 12)) {
  $minorOpportunities += (Copy-ActionRowForQueue -Row $item.row -Priority $minorPriority)
  $minorPriority++
}

if ($actions.Count -eq 0) {
  throw 'No SEO/GEO action candidates could be generated from latest reports and keyword pool.'
}

$generatedAt = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
$modeLabel = if ($effectiveMode -eq 'monthly') { '28d 正式決策 + 7d 異常觀察' } else { '7d weekly watchlist' }
$baselineLabel = if ($baselineRefresh) { 'same-baseline / 現況機會判讀' } else { '前後期差異判讀' }
$outputMd = Join-Path $latestRoot 'seo-geo-action-plan.md'
$outputHtml = Join-Path $latestRoot 'seo-geo-action-plan.html'
$outputAi = Join-Path $latestRoot 'seo-geo-action-plan.ai.md'
$outputSlimAi = Join-Path $latestRoot 'seo-geo-action-plan.slim.ai.md'
$outputOptionalAi = Join-Path $latestRoot 'seo-geo-action-plan.optional.slim.ai.md'
$outputJson = Join-Path $latestRoot 'seo-geo-action-plan.json'
$outputQueueMd = Join-Path $latestRoot 'seo-geo-action-queue.md'
$outputQueueJson = Join-Path $latestRoot 'seo-geo-action-queue.json'
$outputQueueStateJson = Join-Path $latestRoot 'seo-geo-action-queue-state.json'

$fixedWorkflow = @(
  '每週先匯入 latest 7d 與 28d GSC Search Performance ZIP。',
  '7d 只看異常、曝光突增但低 CTR、排名急退與 watchlist 微調。',
  '28d 作正式決策：先救 CTR，再推排名 8-15 的前 10 邊緣詞。',
  '固定以 SEO/GEO 任務佇列執行；Round 1 是 AI 本輪要做的頁面批次，Round 2/3 只作後續預排。',
  '頁面批次維持最多 6 頁；維持 1 keyword = 1 owner page。',
  '每頁固定調整 title、meta description、H1/首屏、FAQ、內鏈錨文字、JSON-LD 對齊。',
  '技術型 SEO/GEO 任務放入 technical queue，由驗證命令與 schema/content source truth 控制，不消耗 AI 重新判讀 token。',
  '不新增頁面、不改公開 API/型別/後台邏輯/計價邏輯、不直接修改 out/。'
)

$validation = @(
  'node .agents/skills/curtain-online-seo-geo/scripts/keyword-owner-check.mjs',
  'npm.cmd run build',
  'npm.cmd run seo:check',
  'npm.cmd run seo:preflight',
  'npm.cmd run deploy:ftp:dry',
  'npm.cmd run deploy:ftp'
)

$lineFeed = [string][char]10

$technicalTasks = @(
  [PSCustomObject]@{
    priority           = 1
    type               = 'validation-deploy'
    title              = 'Build / SEO check / preflight 摘要驗收'
    scope              = '技術型 SEO/GEO 任務，預設只跑固定驗證並回報摘要；只有失敗時才讀 scripts 或完整 log。'
    requiredSource     = @('scripts/seo-check.mjs', 'scripts/seo-preflight.mjs')
    validationCommands = @('npm.cmd run build', 'npm.cmd run seo:check', 'npm.cmd run seo:preflight')
    aiTokenRule        = '不要貼逐檔 build/deploy log；回報 passed/failed 與最後錯誤即可。'
  }
)

$queueMd = @()
$queueMd += '# Curtain Online SEO/GEO Action Queue'
$queueMd += ''
$queueMd += "- 產生時間：$generatedAt"
$queueMd += "- 模式：$requestedMode -> $effectiveMode（$modeLabel）"
$queueMd += "- Queue 原則：AI 只實作 Round 1；Round 2/3 是後續排程參考，不要在同一輪一起修改。"
$queueMd += "- Token 原則：策略判讀已由本機 SOP 完成；不要重新讀 raw CSV、reports/history、All_plan 或 Phase 歷史。"
$queueMd += ''
foreach ($round in $actionQueue) {
  $queueMd += "## Round $($round.round) - $($round.type)"
  $queueMd += ''
  $queueMd += "- 目標數：$($round.targetCount)"
  $queueMd += "- AI 執行：$(if ($round.round -eq 1) { 'YES，本輪 Slim 指令只包含這一輪' } else { 'NO，保留給下一輪' })"
  $queueMd += "- 需要讀的 source：$((@($round.requiredSource) | Select-Object -Unique) -join '；')"
  $queueMd += ''
  $queueMd += (Convert-ActionsToMarkdownTable -Rows $round.actions)
  $queueMd += ''
}
$queueMd += '## Optional Opportunities / 小幅可優化參考清單'
$queueMd += ''
$queueMd += '- 這一區只供人工判斷，不會被「複製下一輪 Slim AI 指令」自動複製。'
$queueMd += '- 若 Round 1/2/3 都完成後仍想加做，請另開新一輪或明確指定頁面。'
$queueMd += ''
if ($minorOpportunities.Count -gt 0) {
  $queueMd += (Convert-ActionsToMarkdownTable -Rows $minorOpportunities)
} else {
  $queueMd += '- Round 1/2/3 已涵蓋目前 keyword-owner pool 內可排序的頁面，沒有額外小幅參考頁。'
}
$queueMd += ''
$queueMd += '## Technical Queue'
$queueMd += ''
foreach ($task in $technicalTasks) {
  $queueMd += "- P$($task.priority) / $($task.type)：$($task.title)"
  $queueMd += "  - Scope：$($task.scope)"
  $queueMd += "  - Required source when debugging：$($task.requiredSource -join '；')"
  $queueMd += "  - Validation：$($task.validationCommands -join '；')"
  $queueMd += "  - Token rule：$($task.aiTokenRule)"
}

Write-Utf8NoBom -Path $outputQueueMd -Text ($queueMd -join $lineFeed)
Write-Utf8NoBom -Path $outputQueueJson -Text ([ordered]@{
  status = 'success'
  generated_at = $generatedAt
  requested_mode = $requestedMode
  mode = $effectiveMode
  page_batch_size = $pageBatchSize
  queue_rule = 'AI only implements Round 1. Later rounds are queued for future cycles.'
  rounds = $actionQueue
  technical_tasks = $technicalTasks
  optional_opportunities = $minorOpportunities
} | ConvertTo-Json -Depth 10)

$md = @()
$md += '# Curtain Online SEO/GEO Action Plan'
$md += ''
$md += "- 產生時間：$generatedAt"
$md += "- 模式：$requestedMode -> $effectiveMode（$modeLabel）"
$md += "- 判讀狀態：$baselineLabel"
$md += "- 7d freshness：$($fresh7d.status) / $($fresh7d.text)"
$md += "- 28d freshness：$($fresh28d.status) / $($fresh28d.text)"
$md += "- keyword-owner 來源：$poolPath"
$md += "- 7d query 來源：$query7dPath"
$md += "- 7d page 來源：$page7dPath"
if (Test-Path -LiteralPath $query28dPath -PathType Leaf) { $md += "- 28d query 來源：$query28dPath" }
if (Test-Path -LiteralPath $page28dPath -PathType Leaf) { $md += "- 28d page 來源：$page28dPath" }
$md += ''
$md += '## 固定優化流程'
$md += ''
foreach ($item in $fixedWorkflow) { $md += "- $item" }
$md += ''
$md += '## Round 1 本輪行動批次'
$md += ''
$md += (Convert-ActionsToMarkdownTable -Rows $actions)
$md += ''
$md += '## Round 2/3 預排佇列'
$md += ''
if ($actionQueue.Count -gt 1) {
  foreach ($round in @($actionQueue | Select-Object -Skip 1)) {
    $md += "### Round $($round.round)"
    $md += ''
    $md += (Convert-ActionsToMarkdownTable -Rows $round.actions)
    $md += ''
  }
} else {
  $md += '- 目前 keyword-owner pool 已全部納入 Round 1。'
}
$md += ''
$md += '## Technical Queue'
$md += ''
foreach ($task in $technicalTasks) {
  $md += "- $($task.type)：$($task.title)；$($task.aiTokenRule)"
}
$md += ''
$md += '## Optional Opportunities / 小幅可優化參考清單'
$md += ''
$md += '- 這一區只供人工判斷，不會進入自動複製的 Round。'
$md += '- 若 Round 1/2/3 已完成，仍想補做其中頁面，請另開新一輪或明確指定頁面。'
$md += ''
if ($minorOpportunities.Count -gt 0) {
  $md += (Convert-ActionsToMarkdownTable -Rows $minorOpportunities)
} else {
  $md += '- 目前沒有額外小幅可優化參考頁。'
}
$md += ''
$md += '## AI 執行規則'
$md += ''
$md += '- AI 執行時請直接依照「Round 1 本輪行動批次」修改 source，不需要重新做選頁/選詞策略分析。'
$md += '- Round 2/3 只作後續排程參考，不要在同一輪一起修改，避免任務和 token 膨脹。'
$md += '- AI 執行時使用 Slim Mode：不要重新讀 raw 7d/28d CSV、不要掃 `Weekly SOP/reports/`、不要讀 `All_plan/` 或 Phase 歷史。'
$md += '- 只讀本報告、`plan.md`、目標頁相關 source 與必要 source truth；產品頁讀 `src/data/products.ts`，GEO 頁讀 `src/data/locationPages.ts`，Blog 頁讀 `src/data/knowledgePosts.ts`。'
$md += '- 若報告顯示 same-baseline，只把它視為現況機會判讀，不判定成 SEO/GEO 失敗。'
$md += '- 僅允許 SEO/GEO/schema/content/internal-link 相關 source 修改。'
$md += '- 不直接修改 `out/`，由 build 重新產生。'
$md += ''
$md += '## 固定驗證命令'
$md += ''
foreach ($item in $validation) { $md += ('- `{0}`' -f $item) }

Write-Utf8NoBom -Path $outputMd -Text ($md -join $lineFeed)

$ai = @()
$ai += 'PLEASE IMPLEMENT THIS PLAN:'
$ai += ''
$ai += '# Curtain Online SEO/GEO 固定優化行動報告'
$ai += ''
$ai += '請依這份 AI 執行指令實作，不要重新選詞/選頁。'
$ai += ''
$ai += "本報告已依 latest 7d / 28d GSC 報表與最新 keyword-owner pool 產生。SEO 判斷已由 Weekly SOP 腳本完成，AI 只負責照本指令精準修改 source。"
$ai += ''
$ai += '## Slim Mode Rules'
$ai += ''
$ai += '- 不要重新選頁、重新選詞或重新做策略分析，除非使用者明確要求。'
$ai += '- 不要讀 raw 7d/28d CSV、`Weekly SOP/reports/`、`Weekly SOP/history/`、`All_plan/` 或 Phase 歷史。'
$ai += '- 只讀本 AI 指令、`plan.md`、本輪 6 頁相關 source 與必要 source truth。'
$ai += '- 產品頁只在需要時讀 `src/data/products.ts` 與 `src/app/products/[slug]/page.tsx`。'
$ai += '- GEO 頁只在需要時讀 `src/data/locationPages.ts` 與 `src/app/location/[area]/page.tsx`。'
$ai += '- Blog 頁只在需要時讀 `src/data/knowledgePosts.ts` 與 `src/app/blog/[id]/page.tsx`。'
$ai += '- 首頁、估價頁或跨頁 SEO helper 只在需要時讀對應 page file 與 `src/lib/seo.ts`。'
$ai += '- 不直接修改 `out/`，所有網站內容修改都回到 source。'
$ai += ''
$ai += "- Requested mode: $requestedMode"
$ai += "- Effective mode: $effectiveMode（$modeLabel）"
$ai += "- 7d freshness: $($fresh7d.status) / $($fresh7d.text)"
$ai += "- 28d freshness: $($fresh28d.status) / $($fresh28d.text)"
$ai += ''
$ai += '## Scope'
$ai += ''
$ai += '- 僅修改 source 內 SEO/GEO/schema/content/internal-link 相關內容。'
$ai += '- 不新增頁面，不修改公開 API、型別、後台邏輯或計價邏輯。'
$ai += '- 不直接修改 `out/`。'
$ai += '- 只實作 Round 1；Round 2/3 是後續排程，不要在本輪一起修改。'
$ai += '- 頁面批次最多 6 頁，維持 `1 keyword = 1 owner page`。'
$ai += ''
$ai += '## Fixed Weekly SOP'
$ai += ''
foreach ($item in $fixedWorkflow) { $ai += "- $item" }
$ai += ''
$ai += '## Round 1 Task Queue To Implement'
$ai += ''
$ai += (Convert-ActionsToMarkdownTable -Rows $actions)
$ai += ''
$ai += '## Required Source For Round 1'
$ai += ''
foreach ($item in $round1Source) { $ai += ('- `{0}`' -f $item) }
$ai += ''
$ai += '## Technical Queue'
$ai += ''
$ai += '- 本輪只需跑固定驗證並摘要回報；只有 build/seo check/preflight 失敗時才讀 `scripts/seo-check.mjs` 或 `scripts/seo-preflight.mjs`。'
$ai += '- 不要貼完整 build/deploy/FTP 逐檔 log。'
$ai += ''
$ai += '## Validation'
$ai += ''
foreach ($item in $validation) { $ai += ('- `{0}`' -f $item) }
$ai += ''
$ai += '## Reporting'
$ai += ''
$ai += '- 回報修改頁面、資料來源、驗證結果、deploy dry-run 結果。'
$ai += '- 若缺 FTP 帳密，停止正式上傳並明確回報未 live 驗收。'

Write-Utf8NoBom -Path $outputAi -Text ($ai -join $lineFeed)

$roundPromptFiles = @()
foreach ($round in $actionQueue) {
  $roundPromptPath = Join-Path $latestRoot ('seo-geo-action-plan.round-{0}.slim.ai.md' -f $round.round)
  $roundPrompt = New-RoundSlimPrompt -Round $round -RequestedMode $requestedMode -EffectiveMode $effectiveMode -ModeLabel $modeLabel
  Write-Utf8NoBom -Path $roundPromptPath -Text ($roundPrompt -join $lineFeed)
  $roundPromptFiles += [PSCustomObject]@{
    round = $round.round
    path = $roundPromptPath
    targetCount = $round.targetCount
    targets = $round.targets
  }
  if ($round.round -eq 1) {
    Write-Utf8NoBom -Path $outputSlimAi -Text ($roundPrompt -join $lineFeed)
  }
}

$queueId = 'seo-geo-' + (Get-Date -Format 'yyyyMMdd-HHmmss')
$queueState = [ordered]@{
  status = 'active'
  queue_id = $queueId
  generated_at = $generatedAt
  active_round = 1
  next_round = 1
  completed_rounds = @()
  copied_rounds = @()
  total_rounds = $actionQueue.Count
  prompt_files = $roundPromptFiles
  note = 'Use the HTA copy button to copy the active round. Confirm completion to advance.'
}
Write-Utf8NoBom -Path $outputQueueStateJson -Text ($queueState | ConvertTo-Json -Depth 8)

$optionalPrompt = New-OptionalOpportunitiesPrompt -Rows $minorOpportunities -RequestedMode $requestedMode -EffectiveMode $effectiveMode -ModeLabel $modeLabel
Write-Utf8NoBom -Path $outputOptionalAi -Text ($optionalPrompt -join $lineFeed)

$json = [ordered]@{
  status = 'success'
  generated_at = $generatedAt
  requested_mode = $requestedMode
  mode = $effectiveMode
  mode_label = $modeLabel
  baseline_status = $baselineLabel
  freshness = [ordered]@{
    '7d' = $fresh7d
    '28d' = $fresh28d
  }
  keyword_pool = $poolPath
  batch_pages = $batchPages
  page_batch_size = $pageBatchSize
  outputs = @{
    markdown = $outputMd
    html = $outputHtml
    ai_prompt = $outputAi
    slim_ai_prompt = $outputSlimAi
    optional_ai_prompt = $outputOptionalAi
    queue_markdown = $outputQueueMd
    queue_json = $outputQueueJson
    queue_state_json = $outputQueueStateJson
    round_prompts = $roundPromptFiles
  }
  action_count = $actions.Count
  queue_round_count = $actionQueue.Count
  current_round = $currentRound
  queue = $actionQueue
  technical_tasks = $technicalTasks
  optional_opportunities = $minorOpportunities
  actions = $actions
  watchlist = $watchlist
}
Write-Utf8NoBom -Path $outputJson -Text ($json | ConvertTo-Json -Depth 8)

$html = @()
$html += '<!doctype html><html lang="zh-Hant"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1">'
$html += '<title>Curtain Online SEO/GEO Action Plan</title>'
$html += '<style>body{font-family:"Microsoft JhengHei",Arial,sans-serif;margin:0;background:#f6f8fb;color:#18324a}main{max-width:1240px;margin:0 auto;padding:28px}h1{font-size:28px;margin:0 0 14px;color:#0b2f4a}h2{font-size:20px;margin-top:28px;border-left:5px solid #2f7d68;padding-left:10px}.meta,.note{background:#fff;border:1px solid #d9e3ec;border-radius:8px;padding:14px 16px;margin:14px 0;line-height:1.7}table{width:100%;border-collapse:collapse;background:#fff;border:1px solid #d9e3ec;font-size:13px}th,td{border:1px solid #d9e3ec;padding:8px;vertical-align:top}th{background:#eaf2f8;text-align:left}tr:nth-child(even) td{background:#fbfdff}code{background:#eef4fa;padding:2px 5px;border-radius:4px}ul{background:#fff;border:1px solid #d9e3ec;border-radius:8px;padding:14px 28px;line-height:1.7}.status{display:inline-block;border-radius:999px;padding:4px 10px;background:#e9f7ef;color:#1b6846;font-weight:700}.warning{background:#fff8e6;border-color:#f0d58a}</style>'
$html += '</head><body><main>'
$html += '<h1>Curtain Online SEO/GEO Action Plan</h1>'
$html += '<div class="meta">'
$html += '<div>產生時間：' + (Escape-Html -Value $generatedAt) + '</div>'
$html += '<div>模式：' + (Escape-Html -Value "$requestedMode -> $effectiveMode（$modeLabel）") + '</div>'
$html += '<div>判讀狀態：<span class="status">' + (Escape-Html -Value $baselineLabel) + '</span></div>'
$html += '<div>7d freshness：' + (Escape-Html -Value "$($fresh7d.status) / $($fresh7d.text)") + '</div>'
$html += '<div>28d freshness：' + (Escape-Html -Value "$($fresh28d.status) / $($fresh28d.text)") + '</div>'
$html += '<div>keyword-owner 來源：' + (Escape-Html -Value $poolPath) + '</div>'
$html += '<div>7d query/page：' + (Escape-Html -Value "$query7dPath / $page7dPath") + '</div>'
if (Test-Path -LiteralPath $page28dPath -PathType Leaf) { $html += '<div>28d query/page：' + (Escape-Html -Value "$query28dPath / $page28dPath") + '</div>' }
$html += '</div>'
$html += '<h2>固定優化流程</h2>'
$html += Convert-ListToHtml -Items $fixedWorkflow
$html += '<h2>Round 1 本輪行動批次</h2>'
$html += Convert-ActionsToHtmlTable -Rows $actions
$html += '<h2>Round 2/3 預排佇列</h2>'
if ($actionQueue.Count -gt 1) {
  foreach ($round in @($actionQueue | Select-Object -Skip 1)) {
    $html += '<h3>Round ' + (Escape-Html -Value ([string]$round.round)) + '</h3>'
    $html += Convert-ActionsToHtmlTable -Rows $round.actions
  }
} else {
  $html += '<div class="note">目前 keyword-owner pool 已全部納入 Round 1。</div>'
}
$html += '<h2>Technical Queue</h2>'
$html += Convert-ListToHtml -Items @($technicalTasks | ForEach-Object { "$($_.type)：$($_.title)；$($_.aiTokenRule)" })
$html += '<h2>Optional Opportunities / 小幅可優化參考清單</h2>'
if ($minorOpportunities.Count -gt 0) {
  $html += '<div class="note">這一區只供人工判斷，不會被「複製下一輪 Slim AI 指令」自動複製。</div>'
  $html += Convert-ActionsToHtmlTable -Rows $minorOpportunities
} else {
  $html += '<div class="note">目前沒有額外小幅可優化參考頁。</div>'
}
$html += '<h2>AI 執行規則</h2>'
$html += Convert-ListToHtml -Items @(
  '直接依本報告的 Round 1 執行，不需要重新做選頁/選詞策略分析。',
  'Round 2/3 是後續排程，不要在同一輪一起修改。',
  '只修改 SEO/GEO/schema/content/internal-link 相關 source。',
  '不新增頁面、不改公開 API/型別/後台邏輯/計價邏輯、不直接修改 out/。',
  '完成後依固定驗證命令驗收。'
)
$html += '<h2>固定驗證命令</h2>'
$html += Convert-ListToHtml -Items $validation
$html += '<div class="note warning">AI 可直接使用的 Slim 版本已輸出：' + (Escape-Html -Value $outputSlimAi) + '<br>完整任務佇列已輸出：' + (Escape-Html -Value $outputQueueMd) + '</div>'
$html += '</main></body></html>'
Write-Utf8NoBom -Path $outputHtml -Text ($html -join $lineFeed)

Write-Host 'SEO/GEO action plan completed.'
Write-Host "Requested mode: $requestedMode"
Write-Host "Effective mode: $effectiveMode"
Write-Host "7d freshness: $($fresh7d.status) / $($fresh7d.text)"
Write-Host "28d freshness: $($fresh28d.status) / $($fresh28d.text)"
Write-Host "Status: $baselineLabel"
Write-Host "Queue rounds: $($actionQueue.Count)"
Write-Host "Slim AI prompt: $outputSlimAi"
Write-Host "Keyword pool: $poolPath"
Write-Host "Next batch: $((@($actions | ForEach-Object { $_.page }) -join ', '))"
Write-Host "Markdown: $outputMd"
Write-Host "HTML: $outputHtml"
Write-Host "AI prompt: $outputAi"
