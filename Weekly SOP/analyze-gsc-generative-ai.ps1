[CmdletBinding()]
param(
  [Parameter(Mandatory = $true)][string]$InputPath,
  [string]$RuntimeRoot = (Split-Path -Parent $PSCommandPath)
)

$ErrorActionPreference = 'Stop'

function Get-Sha256([string]$Path) {
  return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()
}

function Get-WorkbookXml([System.IO.Compression.ZipArchive]$Archive, [string]$EntryPath) {
  $entry = $Archive.GetEntry($EntryPath)
  if (-not $entry) { throw "XLSX 缺少必要內容：$EntryPath" }
  $reader = [System.IO.StreamReader]::new($entry.Open())
  try {
    $xml = [System.Xml.XmlDocument]::new()
    $xml.LoadXml($reader.ReadToEnd())
    return $xml
  } finally {
    $reader.Dispose()
  }
}

function New-NamespaceManager([System.Xml.XmlDocument]$Xml) {
  $manager = [System.Xml.XmlNamespaceManager]::new($Xml.NameTable)
  $manager.AddNamespace('x', 'http://schemas.openxmlformats.org/spreadsheetml/2006/main') | Out-Null
  $manager.AddNamespace('r', 'http://schemas.openxmlformats.org/officeDocument/2006/relationships') | Out-Null
  $manager.AddNamespace('p', 'http://schemas.openxmlformats.org/package/2006/relationships') | Out-Null
  return ,$manager
}

function Get-CellValue([System.Xml.XmlNode]$Cell, [string[]]$SharedStrings, [System.Xml.XmlNamespaceManager]$Manager) {
  $type = [string]$Cell.Attributes['t'].Value
  if ($type -eq 's') {
    $index = [int]($Cell.SelectSingleNode('x:v', $Manager).InnerText)
    return $SharedStrings[$index]
  }
  if ($type -eq 'inlineStr') { return [string]$Cell.SelectSingleNode('x:is', $Manager).InnerText }
  $value = $Cell.SelectSingleNode('x:v', $Manager)
  if ($value) { return [string]$value.InnerText }
  return ''
}

function Get-SheetRows([System.IO.Compression.ZipArchive]$Archive, [string]$EntryPath, [string[]]$SharedStrings) {
  $xml = Get-WorkbookXml $Archive $EntryPath
  $ns = New-NamespaceManager $xml
  $rows = @()
  foreach ($row in $xml.SelectNodes('/x:worksheet/x:sheetData/x:row', $ns)) {
    $values = @{}
    foreach ($cell in $row.SelectNodes('x:c', $ns)) {
      $reference = [string]$cell.Attributes['r'].Value
      $column = ([regex]::Match($reference, '^[A-Z]+')).Value
      $values[$column] = Get-CellValue $cell $SharedStrings $ns
    }
    $rows += [pscustomobject]@{ row = [int]$row.Attributes['r'].Value; values = $values }
  }
  return $rows
}

function ConvertTo-Number([string]$Value) {
  $number = 0.0
  if (-not [double]::TryParse($Value, [Globalization.NumberStyles]::Float, [Globalization.CultureInfo]::InvariantCulture, [ref]$number)) {
    throw "無法解析數值：$Value"
  }
  return $number
}

function Get-DataPairs($Rows) {
  $result = @()
  foreach ($row in ($Rows | Where-Object { $_.row -gt 1 })) {
    $label = [string]$row.values['A']
    $value = [string]$row.values['B']
    if ($label -and $value) {
      $result += [pscustomobject]@{ label = $label; impressions = [int](ConvertTo-Number $value) }
    }
  }
  return $result
}

Add-Type -AssemblyName System.IO.Compression.FileSystem
$input = Get-Item -LiteralPath $InputPath -ErrorAction Stop
if ($input.Extension -ne '.xlsx') { throw '請選擇 GSC「生成式 AI 功能」匯出的 .xlsx 檔案。' }
if (-not (Test-Path -LiteralPath $RuntimeRoot -PathType Container)) { throw "找不到 RuntimeRoot：$RuntimeRoot" }

$archive = [System.IO.Compression.ZipFile]::OpenRead($input.FullName)
try {
  $workbook = Get-WorkbookXml $archive 'xl/workbook.xml'
  $workbookNs = New-NamespaceManager $workbook
  $relationships = Get-WorkbookXml $archive 'xl/_rels/workbook.xml.rels'
  $relationshipsNs = New-NamespaceManager $relationships
  $relationshipTargets = @{}
  foreach ($relationship in $relationships.SelectNodes('/p:Relationships/p:Relationship', $relationshipsNs)) {
    $relationshipTargets[[string]$relationship.Attributes['Id'].Value] = [string]$relationship.Attributes['Target'].Value
  }
  $sharedStrings = @()
  if ($archive.GetEntry('xl/sharedStrings.xml')) {
    $shared = Get-WorkbookXml $archive 'xl/sharedStrings.xml'
    $sharedNs = New-NamespaceManager $shared
    foreach ($item in $shared.SelectNodes('/x:sst/x:si', $sharedNs)) { $sharedStrings += [string]$item.InnerText }
  }
  $sheetPaths = @{}
  foreach ($sheet in $workbook.SelectNodes('/x:workbook/x:sheets/x:sheet', $workbookNs)) {
    $relationshipId = [string]$sheet.Attributes.GetNamedItem('r:id').Value
    $target = $relationshipTargets[$relationshipId]
    if (-not $target) { throw "找不到工作表關聯：$relationshipId" }
    $sheetPaths[[string]$sheet.Attributes['name'].Value] = 'xl/' + $target.TrimStart('/')
  }
  foreach ($required in @('圖表', '網頁', '國家_地區', '裝置', '篩選器')) {
    if (-not $sheetPaths.ContainsKey($required)) { throw "這不是預期的 GSC 生成式 AI 匯出檔，缺少工作表：$required" }
  }

  $chart = Get-DataPairs (Get-SheetRows $archive $sheetPaths['圖表'] $sharedStrings)
  $pages = Get-DataPairs (Get-SheetRows $archive $sheetPaths['網頁'] $sharedStrings)
  $countries = Get-DataPairs (Get-SheetRows $archive $sheetPaths['國家_地區'] $sharedStrings)
  $devices = Get-DataPairs (Get-SheetRows $archive $sheetPaths['裝置'] $sharedStrings)
  $filters = Get-SheetRows $archive $sheetPaths['篩選器'] $sharedStrings | ForEach-Object {
    [pscustomobject]@{ label = [string]$_.values['A']; value = [string]$_.values['B'] }
  }

  if ($chart.Count -eq 0) { throw '圖表工作表沒有可分析的日期／曝光資料。' }
  $totalImpressions = [int](($chart | Measure-Object -Property impressions -Sum).Sum)
  $firstDate = ($chart | Select-Object -First 1).label
  $lastDate = ($chart | Select-Object -Last 1).label
  $topPages = @($pages | Sort-Object impressions -Descending | Select-Object -First 10)
  $topCountries = @($countries | Sort-Object impressions -Descending | Select-Object -First 10)
  $deviceBreakdown = @($devices | Sort-Object impressions -Descending)
  $taiwan = $countries | Where-Object { $_.label -in @('Taiwan', '台灣') } | Select-Object -First 1
  $pageGroups = @(
    [pscustomobject]@{ hostname = 'online.hong-sen.com'; impressions = [int](($pages | Where-Object { $_.label -like 'https://online.hong-sen.com/*' } | Measure-Object impressions -Sum).Sum) },
    [pscustomobject]@{ hostname = 'www.hong-sen.com'; impressions = [int](($pages | Where-Object { $_.label -like 'https://www.hong-sen.com/*' } | Measure-Object impressions -Sum).Sum) }
  )
  foreach ($group in $pageGroups) { $group | Add-Member -NotePropertyName share_of_page_rows -NotePropertyValue $(if ($pages.Count -gt 0) { [math]::Round(($group.impressions / [math]::Max(1, (($pages | Measure-Object impressions -Sum).Sum))) * 100, 2) } else { 0 }) }

  $analysis = [ordered]@{
    schema_version = 1
    status = 'complete'
    analyzed_at = (Get-Date).ToUniversalTime().ToString('o')
    measurement_source = 'gsc_search_console_search_generative_ai_features_export'
    gsc_inference_prohibited = $true
    source = [ordered]@{ path = $input.FullName; sha256 = Get-Sha256 $input.FullName; file_name = $input.Name }
    filters = @($filters)
    period = [ordered]@{ start_date = $firstDate; end_date = $lastDate; days = $chart.Count }
    impressions = [ordered]@{ total = $totalImpressions; daily = @($chart); average_per_day = [math]::Round($totalImpressions / $chart.Count, 2) }
    pages = [ordered]@{ row_total = [int](($pages | Measure-Object impressions -Sum).Sum); top_10 = $topPages; hostnames = $pageGroups }
    countries = [ordered]@{ top_10 = $topCountries; taiwan_impressions = if ($taiwan) { $taiwan.impressions } else { 0 }; taiwan_share = if ($taiwan) { [math]::Round(($taiwan.impressions / [math]::Max(1, $totalImpressions)) * 100, 2) } else { 0 } }
    devices = $deviceBreakdown
    interpretation = [ordered]@{
      allowed = '此資料只描述 GSC Search Generative AI 功能的曝光分布。'
      prohibited = '不可據此推論 AI engine 的品牌提及率、引用率或回答正確性；該等指標只採 direct AI engine observation。'
      deployment_note = '請以報表結束日與實際部署時間比對；結束日前的曝光不可用於評估其後的部署。'
    }
  }
} finally {
  $archive.Dispose()
}

$latest = Join-Path $RuntimeRoot 'latest'
New-Item -ItemType Directory -Path $latest -Force | Out-Null
$jsonPath = Join-Path $latest 'gsc-generative-ai-analysis.json'
$markdownPath = Join-Path $latest 'gsc-generative-ai-analysis.md'
$analysis | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $jsonPath -Encoding utf8
$topPageText = @($analysis.pages.top_10 | ForEach-Object { '- ' + $_.label + ': ' + $_.impressions }) -join [Environment]::NewLine
$deviceText = @($analysis.devices | ForEach-Object { '- ' + $_.label + ': ' + $_.impressions }) -join [Environment]::NewLine
@(
  '# GSC 生成式 AI 功能分析'
  ''
  "- 分析時間：$($analysis.analyzed_at)"
  "- 來源：$($analysis.source.path)"
  "- 資料期間：$($analysis.period.start_date) ～ $($analysis.period.end_date)（$($analysis.period.days) 天）"
  "- 曝光：$($analysis.impressions.total)，日均 $($analysis.impressions.average_per_day)"
  "- 台灣：$($analysis.countries.taiwan_impressions)（$($analysis.countries.taiwan_share)%）"
  ''
  '## 前 10 個網頁'
  $topPageText
  ''
  '## 裝置'
  $deviceText
  ''
  '## 口徑'
  '- 此報表只描述 GSC Search Generative AI 功能的曝光分布。'
  '- 不可據此推論 AI engine 的品牌提及率、引用率或回答正確性；該等指標只採 direct AI engine observation。'
) | Set-Content -LiteralPath $markdownPath -Encoding utf8

Write-Output "GSC 生成式 AI 分析完成。JSON：$jsonPath"
Write-Output "摘要：$markdownPath"
