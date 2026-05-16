param(
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
    return ($b1 -eq 0x50 -and $b2 -eq 0x4B) # PK
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

function Test-ArchiveContainsCsvName {
  param(
    [string]$Path,
    [string[]]$ExpectedNames
  )
  try {
    foreach ($name in (Get-ZipEntryNames -Path $Path)) {
      if (Test-InputNameMatches -Name $name -ExpectedNames $ExpectedNames) { return $true }
    }
  } catch {
    return $false
  }
  return $false
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

function Find-LatestInput {
  param(
    [string]$InputDir,
    [string[]]$ExpectedEntries,
    [string]$ModeLabel
  )
  $files = Get-ChildItem -LiteralPath $InputDir -File |
    Where-Object { $_.Extension -in @('.csv', '.zip') } |
    Sort-Object LastWriteTime -Descending

  foreach ($file in $files) {
    $isZip = Test-IsZipFile -Path $file.FullName
    if ($isZip -and (Test-ArchiveContainsCsvName -Path $file.FullName -ExpectedNames $ExpectedEntries)) {
      return $file
    }
    if (-not $isZip -and (Test-InputNameMatches -Name $file.Name -ExpectedNames $ExpectedEntries)) {
      return $file
    }
  }

  throw "No Search Performance $ModeLabel input found in $InputDir. Use the GSC Performance ZIP that contains 查詢.csv, or put 查詢.csv directly in inbox. Coverage ZIP exports are not supported by this KPI diff."
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
  param([object[]]$Rows)

  $out = @()
  $validMetricRows = 0
  foreach ($row in $Rows) {
    $query = Get-FirstPropValue -Row $row -Names @('query', 'Query', '熱門查詢項目', '查詢')
    if ([string]::IsNullOrWhiteSpace($query)) { $query = Get-PropByIndex -Row $row -Index 0 }
    if ([string]::IsNullOrWhiteSpace($query)) { continue }

    $clicks = Get-FirstPropValue -Row $row -Names @('clicks', 'Clicks', '點擊')
    if ([string]::IsNullOrWhiteSpace($clicks)) { $clicks = Get-PropByIndex -Row $row -Index 1 }

    $impr = Get-FirstPropValue -Row $row -Names @('impressions', 'Impressions', '曝光')
    if ([string]::IsNullOrWhiteSpace($impr)) { $impr = Get-PropByIndex -Row $row -Index 2 }

    $ctr = Get-FirstPropValue -Row $row -Names @('ctr', 'CTR', '點閱率')
    if ([string]::IsNullOrWhiteSpace($ctr)) { $ctr = Get-PropByIndex -Row $row -Index 3 }

    $pos = Get-FirstPropValue -Row $row -Names @('position', 'Position', '排名')
    if ([string]::IsNullOrWhiteSpace($pos)) { $pos = Get-PropByIndex -Row $row -Index 4 }

    if ($query -notmatch '^https?://' -and
      (Test-NumericMetric -Value $impr) -and
      (Test-NumericMetric -Value $pos)) {
      $validMetricRows++
    }

    $out += [PSCustomObject]@{
      query       = $query
      page        = '(all pages)'
      clicks      = $clicks
      impressions = $impr
      ctr         = $ctr
      position    = $pos
    }
  }
  if ($validMetricRows -eq 0) {
    throw "Input does not look like a GSC Search Performance query export. Use the Performance-on-Search ZIP that contains 查詢.csv, or upload 查詢.csv directly. Coverage ZIP exports are not supported by this KPI diff."
  }
  return $out
}

function Get-FirstDataFirstCell {
  param([string]$CsvPath)
  try {
    $lines = Get-Content -LiteralPath $CsvPath -TotalCount 2 -Encoding UTF8
  } catch {
    $lines = Get-Content -LiteralPath $CsvPath -TotalCount 2
  }
  if ($lines.Count -lt 2) { return '' }
  $line = [string]$lines[1]
  if ($line.StartsWith('"')) {
    $idx = $line.IndexOf('",')
    if ($idx -gt 0) { return $line.Substring(1, $idx - 1) }
  }
  return ($line.Split(',')[0]).Trim('"')
}

function Pick-QueryCsvFromExtracted {
  param([string]$ExtractDir)
  $csvFiles = Get-ChildItem -LiteralPath $ExtractDir -Recurse -File -Filter '*.csv'
  if (-not $csvFiles) { return $null }

  $named = $csvFiles | Where-Object {
    Test-InputNameMatches -Name $_.Name -ExpectedNames @('查詢.csv', 'query.csv', 'queries.csv')
  } | Select-Object -First 1
  if ($named) { return $named.FullName }

  $named = $csvFiles | Where-Object { $_.Name -match '查詢|query' } | Select-Object -First 1
  if ($named) { return $named.FullName }

  foreach ($f in $csvFiles) {
    $cell = Get-FirstDataFirstCell -CsvPath $f.FullName
    if ($cell -and $cell -notmatch '^https?://') { return $f.FullName }
  }

  return $csvFiles[0].FullName
}

function Normalize-Input {
  param(
    [string]$InputPath,
    [string]$OutputPath,
    [string]$TempDir
  )
  Ensure-Dir -Path (Split-Path -Parent $OutputPath)
  Ensure-Dir -Path $TempDir

  $csvPath = $InputPath
  if (Test-IsZipFile -Path $InputPath) {
    $zipPath = $InputPath
    if ([System.IO.Path]::GetExtension($InputPath).ToLowerInvariant() -ne '.zip') {
      $zipPath = Join-Path $TempDir 'input.zip'
      Copy-Item -LiteralPath $InputPath -Destination $zipPath -Force
    }
    Expand-Archive -LiteralPath $zipPath -DestinationPath $TempDir -Force
    $picked = Pick-QueryCsvFromExtracted -ExtractDir $TempDir
    if (-not $picked) { throw "No CSV found in archive: $InputPath" }
    $csvPath = $picked
  }

  $rows = Read-CsvUtf8OrDefault -Path $csvPath
  $norm = Normalize-Rows -Rows $rows
  if (-not $norm -or $norm.Count -eq 0) {
    throw "Could not normalize rows from input: $InputPath"
  }
  $norm | Export-Csv -LiteralPath $OutputPath -NoTypeInformation -Encoding UTF8
}

$weeklyRoot = Join-Path $PSScriptRoot '.'
$repoRoot = Split-Path -Parent $PSScriptRoot
$inboxDir = Join-Path $weeklyRoot 'inbox'
$archiveDir = Join-Path $weeklyRoot 'archive'
$historyDir = Join-Path $weeklyRoot 'history'
$reportsDir = Join-Path $weeklyRoot 'reports'
$latestDir = Join-Path $weeklyRoot 'latest'

Ensure-Dir -Path $inboxDir
Ensure-Dir -Path $archiveDir
Ensure-Dir -Path $historyDir
Ensure-Dir -Path $reportsDir
Ensure-Dir -Path $latestDir

$inputMode = 'inbox'
$incoming = $null

if (-not [string]::IsNullOrWhiteSpace($InputFile)) {
  $resolved = (Resolve-Path -LiteralPath $InputFile -ErrorAction Stop).Path
  if (-not (Test-Path -LiteralPath $resolved -PathType Leaf)) {
    throw "Input file not found: $InputFile"
  }
  $ext = [System.IO.Path]::GetExtension($resolved).ToLowerInvariant()
  if ($ext -notin @('.csv', '.zip')) {
    throw "Unsupported input extension: $ext. Use .csv or .zip"
  }
  $incoming = Get-Item -LiteralPath $resolved
  $inputMode = 'direct'
} else {
  $incoming = Find-LatestInput -InputDir $inboxDir -ExpectedEntries @('查詢.csv', 'query.csv', 'queries.csv') -ModeLabel 'query'
}

if (-not $incoming) {
  throw "No input file. Put a GSC export (.csv/.zip) into: $inboxDir or pass -InputFile."
}

$stamp = Get-Date -Format 'yyyy-MM-dd_HHmmss'
$runDir = Join-Path $reportsDir $stamp
$tmpDir = Join-Path $weeklyRoot "_tmp_$stamp"

$afterNorm = Join-Path $historyDir "after_$stamp.normalized.csv"
Normalize-Input -InputPath $incoming.FullName -OutputPath $afterNorm -TempDir $tmpDir

$baseline = Join-Path $historyDir 'current_query_baseline.normalized.csv'
if (-not (Test-Path -LiteralPath $baseline)) {
  $fallback = Join-Path $repoRoot 'scripts\gsc-data\after_28d_extracted\查詢.csv'
  if (Test-Path -LiteralPath $fallback) {
    $tmpFallbackDir = Join-Path $weeklyRoot '_tmp_baseline_query'
    Normalize-Input -InputPath $fallback -OutputPath $baseline -TempDir $tmpFallbackDir
    if (Test-Path -LiteralPath $tmpFallbackDir) {
      Remove-Item -LiteralPath $tmpFallbackDir -Recurse -Force
    }
  } else {
    # First-run bootstrap: seed baseline from current normalized input
    Copy-Item -LiteralPath $afterNorm -Destination $baseline -Force
  }
}

if (Test-SameFileContent -Left $baseline -Right $afterNorm) {
  if (Test-Path -LiteralPath $tmpDir) {
    Remove-Item -LiteralPath $tmpDir -Recurse -Force
  }
  throw "This query input is identical to the current baseline. It was probably already run, so latest report was not overwritten. Use a newer Search Performance export, or restore an older baseline before comparing again."
}

Ensure-Dir -Path $runDir

$baselineSnapshot = Join-Path $runDir 'before_query_baseline.normalized.csv'
Copy-Item -LiteralPath $baseline -Destination $baselineSnapshot -Force

$mdReport = Join-Path $runDir 'gsc-query-kpi-diff-report.md'
$htmlReport = Join-Path $runDir 'gsc-query-kpi-diff-report.html'

Push-Location $repoRoot
try {
  & node scripts/gsc-kpi-diff-from-csv.mjs --before $baselineSnapshot --after $afterNorm --output $mdReport --title-suffix " (查詢)"
  if ($LASTEXITCODE -ne 0) {
    throw "Node command failed with exit code $LASTEXITCODE"
  }
} finally {
  Pop-Location
}

if (-not (Test-Path -LiteralPath $mdReport)) { throw "Missing report: $mdReport" }
if (-not (Test-Path -LiteralPath $htmlReport)) { throw "Missing report: $htmlReport" }

# Update next-week baseline
Copy-Item -LiteralPath $afterNorm -Destination $baseline -Force

# Archive input
$archiveDay = Join-Path $archiveDir (Get-Date -Format 'yyyy-MM-dd')
Ensure-Dir -Path $archiveDay
$archivedPath = Join-Path $archiveDay $incoming.Name
if ($inputMode -eq 'direct') {
  Copy-Item -LiteralPath $incoming.FullName -Destination $archivedPath -Force
} else {
  Move-Item -LiteralPath $incoming.FullName -Destination $archivedPath -Force
}

# Latest shortcuts
Copy-Item -LiteralPath $mdReport -Destination (Join-Path $latestDir 'gsc-query-kpi-diff-report.md') -Force
Copy-Item -LiteralPath $htmlReport -Destination (Join-Path $latestDir 'gsc-query-kpi-diff-report.html') -Force

# Run summary
$summaryPath = Join-Path $runDir 'run-summary.md'
@(
  '# Weekly SOP Query Run Summary'
  ''
  "- Run time: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
  "- Input mode: $inputMode"
  "- Input file: $($incoming.Name)"
  "- Baseline snapshot used: $baselineSnapshot"
  "- Current baseline updated: $baseline"
  "- After normalized: $afterNorm"
  "- Markdown report: $mdReport"
  "- HTML report: $htmlReport"
  "- Latest markdown: $(Join-Path $latestDir 'gsc-query-kpi-diff-report.md')"
  "- Latest html: $(Join-Path $latestDir 'gsc-query-kpi-diff-report.html')"
) | Set-Content -LiteralPath $summaryPath -Encoding UTF8

if (Test-Path -LiteralPath $tmpDir) {
  Remove-Item -LiteralPath $tmpDir -Recurse -Force
}

Write-Host 'Weekly SOP query workflow completed.'
Write-Host "Report folder: $runDir"
Write-Host "Latest HTML: $(Join-Path $latestDir 'gsc-query-kpi-diff-report.html')"
