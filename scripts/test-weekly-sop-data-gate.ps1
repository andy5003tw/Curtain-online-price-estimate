param()

$ErrorActionPreference = 'Stop'
$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
$repoRoot = Split-Path -Parent $PSScriptRoot
$runner = Join-Path $repoRoot 'Weekly SOP\run-weekly-window.ps1'
$testRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("curtain-weekly-sop-gate-{0}" -f ([guid]::NewGuid().ToString('N')))
$runtimeRoot = Join-Path $testRoot 'runtime'

function Ensure-Dir {
  param([string]$Path)
  if (-not (Test-Path -LiteralPath $Path)) {
    New-Item -ItemType Directory -Path $Path | Out-Null
  }
}

function Write-Utf8NoBom {
  param(
    [string]$Path,
    [string]$Text
  )
  Ensure-Dir -Path (Split-Path -Parent $Path)
  [System.IO.File]::WriteAllText($Path, $Text, $utf8NoBom)
}

function New-GscZip {
  param(
    [string]$Path,
    [string]$DomainHost,
    [string[]]$Dates = @(),
    [switch]$IncludeDiagnostics
  )

  $sourceDir = Join-Path $testRoot ([System.IO.Path]::GetFileNameWithoutExtension($Path))
  Ensure-Dir -Path $sourceDir
  Write-Utf8NoBom -Path (Join-Path $sourceDir 'query.csv') -Text (@(
    'Query,Clicks,Impressions,CTR,Position'
    '窗簾,3,100,3%,9.5'
    '調光簾,1,25,4%,12.0'
  ) -join "`r`n")
  Write-Utf8NoBom -Path (Join-Path $sourceDir 'page.csv') -Text (@(
    'Page,Clicks,Impressions,CTR,Position'
    "https://$DomainHost/,3,100,3%,9.5"
    "https://$DomainHost/products/zebra-blinds/,1,25,4%,12.0"
  ) -join "`r`n")
  Write-Utf8NoBom -Path (Join-Path $sourceDir 'filters.csv') -Text (@(
    'Filter,Value'
    'Date,Last 7 days'
  ) -join "`r`n")
  if ($IncludeDiagnostics) {
    Write-Utf8NoBom -Path (Join-Path $sourceDir 'query-page.csv') -Text (@(
      'Query,Page,Clicks,Impressions,CTR,Position'
      "窗簾,https://$DomainHost/,3,100,3%,9.5"
      "調光簾,https://$DomainHost/products/zebra-blinds/,1,25,4%,12.0"
    ) -join "`r`n")
    Write-Utf8NoBom -Path (Join-Path $sourceDir 'date-page.csv') -Text ((@('Date,Page,Clicks,Impressions,CTR,Position') + @($Dates | ForEach-Object { "$_,https://$DomainHost/,1,10,10%,9" })) -join "`r`n")
    Write-Utf8NoBom -Path (Join-Path $sourceDir 'device-page.csv') -Text ((@('Date,Device,Page,Clicks,Impressions,CTR,Position') + @($Dates | ForEach-Object { "$_,MOBILE,https://$DomainHost/,1,10,10%,9" })) -join "`r`n")
    Write-Utf8NoBom -Path (Join-Path $sourceDir 'country-page.csv') -Text ((@('Date,Country,Page,Clicks,Impressions,CTR,Position') + @($Dates | ForEach-Object { "$_,twn,https://$DomainHost/,1,10,10%,9" })) -join "`r`n")
    Write-Utf8NoBom -Path (Join-Path $sourceDir 'device-query.csv') -Text ((@('Date,Device,Query,Clicks,Impressions,CTR,Position') + @($Dates | ForEach-Object { "$_,MOBILE,窗簾,1,10,10%,9" })) -join "`r`n")
  }
  if ($Dates.Count -gt 0) {
    Write-Utf8NoBom -Path (Join-Path $sourceDir 'date.csv') -Text ((@('Date,Clicks,Impressions,CTR,Position') + @($Dates | ForEach-Object { "$_,1,10,10%,9" })) -join "`r`n")
  }
  Compress-Archive -Path (Join-Path $sourceDir '*') -DestinationPath $Path -Force
}

function Invoke-Import {
  param([string]$ZipPath)
  $output = @(& pwsh -NoLogo -NoProfile -File $runner -Window auto -InputFile $ZipPath -RuntimeRoot $runtimeRoot 2>&1)
  $exitCode = [int]$LASTEXITCODE
  Write-Utf8NoBom -Path (Join-Path $runtimeRoot 'latest\weekly-sop-last-run.log') -Text ((@($output | ForEach-Object { [string]$_ }) -join [Environment]::NewLine) + [Environment]::NewLine)
  if ($exitCode -ne 0) {
    $output | ForEach-Object { Write-Host $_ }
  }
  return $exitCode
}

function Assert-True {
  param(
    [bool]$Condition,
    [string]$Message
  )
  if (-not $Condition) { throw $Message }
}

Ensure-Dir -Path $testRoot
try {
  $validZip = Join-Path $testRoot 'online-hong-sen_(2026-07-20~2026-07-26)_7d.zip'
  $foreignZip = Join-Path $testRoot 'foreign-host-7d.zip'
  $nextZip = Join-Path $testRoot 'online-hong-sen_(2026-07-21~2026-07-27)_7d.zip'
  $manualFallbackZip = Join-Path $testRoot 'online-hong-sen_(2026-07-22~2026-07-28)_manual_7d.zip'
  $incompleteDateZip = Join-Path $testRoot 'online-hong-sen_(2026-07-23~2026-07-29)_incomplete-date_7d.zip'
  $dates1 = @('2026-07-20','2026-07-21','2026-07-22','2026-07-23','2026-07-24','2026-07-25','2026-07-26')
  $dates2 = @('2026-07-21','2026-07-22','2026-07-23','2026-07-24','2026-07-25','2026-07-26','2026-07-27')
  New-GscZip -Path $validZip -DomainHost 'online.hong-sen.com' -Dates $dates1 -IncludeDiagnostics
  New-GscZip -Path $nextZip -DomainHost 'online.hong-sen.com' -Dates $dates2 -IncludeDiagnostics
  New-GscZip -Path $manualFallbackZip -DomainHost 'online.hong-sen.com'
  New-GscZip -Path $foreignZip -DomainHost 'twyesn.com'
  New-GscZip -Path $incompleteDateZip -DomainHost 'online.hong-sen.com' -Dates @('2026-07-23','2026-07-24','2026-07-25','2026-07-26','2026-07-27','2026-07-28') -IncludeDiagnostics

  $validExit = Invoke-Import -ZipPath $validZip
  Assert-True -Condition ($validExit -eq 0) -Message "Valid host import failed with exit code $validExit"

  $historyRoot = Join-Path $runtimeRoot 'history\curtain-online\7d'
  $queryBaseline = Join-Path $historyRoot 'current_query_baseline.normalized.csv'
  $pageBaseline = Join-Path $historyRoot 'current_page_baseline.normalized.csv'
  Assert-True -Condition (Test-Path -LiteralPath $queryBaseline -PathType Leaf) -Message 'Valid import did not create query baseline.'
  Assert-True -Condition (Test-Path -LiteralPath $pageBaseline -PathType Leaf) -Message 'Valid import did not create page baseline.'

  $queryHashBefore = (Get-FileHash -LiteralPath $queryBaseline -Algorithm SHA256).Hash
  $pageHashBefore = (Get-FileHash -LiteralPath $pageBaseline -Algorithm SHA256).Hash

  $windowManifestPath = Join-Path $runtimeRoot 'latest\7d\weekly-sop-last-run.json'
  $successManifest = Get-Content -Raw -Encoding UTF8 $windowManifestPath | ConvertFrom-Json
  Assert-True -Condition ($successManifest.status -eq 'success') -Message 'Success manifest status is not success.'
  Assert-True -Condition ($successManifest.expected_host -eq 'online.hong-sen.com') -Message 'Success manifest expected_host is incorrect.'
  Assert-True -Condition ([int]$successManifest.host_counts.foreign -eq 0) -Message 'Success manifest contains foreign hosts.'
  Assert-True -Condition ($successManifest.start_date -eq '2026-07-20' -and $successManifest.end_date -eq '2026-07-26') -Message 'ZIP filename date range was not recorded in the manifest.'
  Assert-True -Condition ($successManifest.date_source -eq 'zip_filename') -Message 'ZIP filename date source was not recorded.'
  foreach ($property in $successManifest.latest_reports.PSObject.Properties) {
    Assert-True -Condition (-not [System.IO.Path]::IsPathRooted([string]$property.Value)) -Message "Manifest report path is absolute: $($property.Value)"
    $resolved = Join-Path $runtimeRoot (([string]$property.Value).Replace('/', '\'))
    Assert-True -Condition (Test-Path -LiteralPath $resolved -PathType Leaf) -Message "Relative manifest report path does not resolve: $($property.Value)"
    $reportText = Get-Content -Raw -Encoding UTF8 $resolved
    Assert-True -Condition ($reportText -notmatch '_tmp_window_') -Message "Report leaks a temporary source path: $($property.Value)"
  }
  foreach ($property in $successManifest.comparison_sources.PSObject.Properties) {
    Assert-True -Condition (-not [System.IO.Path]::IsPathRooted([string]$property.Value)) -Message "Comparison source path is absolute: $($property.Value)"
    $resolved = Join-Path $runtimeRoot (([string]$property.Value).Replace('/', '\'))
    Assert-True -Condition (Test-Path -LiteralPath $resolved -PathType Leaf) -Message "Comparison source path does not resolve: $($property.Value)"
  }

  $successRunId = [string]$successManifest.run_id
  $successManifestHash = (Get-FileHash -LiteralPath $windowManifestPath -Algorithm SHA256).Hash
  $duplicateExit = Invoke-Import -ZipPath $validZip
  Assert-True -Condition ($duplicateExit -ne 0) -Message 'Duplicate ZIP unexpectedly updated the baseline.'

  $queryHashAfterDuplicate = (Get-FileHash -LiteralPath $queryBaseline -Algorithm SHA256).Hash
  $pageHashAfterDuplicate = (Get-FileHash -LiteralPath $pageBaseline -Algorithm SHA256).Hash
  $successManifestHashAfterDuplicate = (Get-FileHash -LiteralPath $windowManifestPath -Algorithm SHA256).Hash
  Assert-True -Condition ($queryHashBefore -eq $queryHashAfterDuplicate) -Message 'Duplicate ZIP changed query baseline.'
  Assert-True -Condition ($pageHashBefore -eq $pageHashAfterDuplicate) -Message 'Duplicate ZIP changed page baseline.'
  Assert-True -Condition ($successManifestHash -eq $successManifestHashAfterDuplicate) -Message 'Duplicate ZIP changed the per-window success manifest.'

  $duplicateManifestPath = Join-Path $runtimeRoot 'latest\weekly-sop-last-run.json'
  $duplicateManifest = Get-Content -Raw -Encoding UTF8 $duplicateManifestPath | ConvertFrom-Json
  Assert-True -Condition ($duplicateManifest.status -eq 'duplicate_input') -Message 'Duplicate ZIP status is not duplicate_input.'
  Assert-True -Condition ([string]$duplicateManifest.input_sha256 -eq ([string]$successManifest.input_sha256)) -Message 'Duplicate ZIP SHA does not match the successful input.'
  Assert-True -Condition (-not [System.IO.Path]::IsPathRooted([string]$duplicateManifest.duplicate_of)) -Message 'Duplicate archive path is absolute.'
  $duplicateArchivePath = Join-Path $runtimeRoot (([string]$duplicateManifest.duplicate_of).Replace('/', '\'))
  Assert-True -Condition (Test-Path -LiteralPath $duplicateArchivePath -PathType Leaf) -Message 'Duplicate archive relative path does not resolve.'
  $duplicateLog = Get-Content -LiteralPath (Join-Path $runtimeRoot 'latest\weekly-sop-last-run.log') -Raw -Encoding UTF8
  Assert-True -Condition ($duplicateLog -match 'Duplicate GSC ZIP detected') -Message 'Duplicate log does not identify the duplicate input.'
  Assert-True -Condition ($duplicateLog -notmatch '(?i)\b[A-Z]:\\') -Message 'Duplicate log leaks an absolute Windows path.'
  $successManifestAfterDuplicate = Get-Content -Raw -Encoding UTF8 $windowManifestPath | ConvertFrom-Json
  Assert-True -Condition ([string]$successManifestAfterDuplicate.run_id -eq $successRunId) -Message 'Duplicate ZIP replaced the successful per-window run_id.'

  $nextExit = Invoke-Import -ZipPath $nextZip
  Assert-True -Condition ($nextExit -eq 0) -Message 'Second complete diagnostic import failed.'
  $dailyDatePath = Join-Path $historyRoot 'diagnostics\daily\date.csv'
  $dailyDevicePagePath = Join-Path $historyRoot 'diagnostics\daily\device_page.csv'
  $dailyDates = @(Import-Csv -LiteralPath $dailyDatePath -Encoding UTF8 | ForEach-Object { [string]$_.Date } | Sort-Object -Unique)
  Assert-True -Condition ($dailyDates -contains '2026-07-20' -and $dailyDates -contains '2026-07-27' -and $dailyDates.Count -eq 8) -Message 'Next diagnostic import did not preserve and deduplicate the older daily Date history.'
  Assert-True -Condition (@(Import-Csv -LiteralPath $dailyDevicePagePath -Encoding UTF8).Count -eq 8) -Message 'Device×Page daily accumulated history was not deduplicated by date/device/page.'
  Assert-True -Condition (Test-Path -LiteralPath (Join-Path $historyRoot 'diagnostics\snapshots\2026-07-20_2026-07-26\date.csv')) -Message 'First dated diagnostic snapshot was not preserved.'
  Assert-True -Condition (Test-Path -LiteralPath (Join-Path $historyRoot 'diagnostics\snapshots\2026-07-21_2026-07-27\date.csv')) -Message 'Second dated diagnostic snapshot was not preserved.'

  $manualExit = Invoke-Import -ZipPath $manualFallbackZip
  Assert-True -Condition ($manualExit -eq 0) -Message 'Manual fallback ZIP should import in monitor-only mode.'
  $manualManifest = Get-Content -Raw -Encoding UTF8 $windowManifestPath | ConvertFrom-Json
  Assert-True -Condition (-not [bool]$manualManifest.decision_ready -and [string]$manualManifest.data_confidence -eq 'monitor_only' -and @($manualManifest.missing_diagnostic_dimensions).Count -eq 5) -Message 'Manual fallback without diagnostics was not downgraded to monitor_only.'

  $queryHashBefore = (Get-FileHash -LiteralPath $queryBaseline -Algorithm SHA256).Hash
  $pageHashBefore = (Get-FileHash -LiteralPath $pageBaseline -Algorithm SHA256).Hash

  $incompleteDateExit = Invoke-Import -ZipPath $incompleteDateZip
  Assert-True -Condition ($incompleteDateExit -ne 0) -Message 'Incomplete Date diagnostic unexpectedly updated the baseline.'
  $incompleteDateFailure = Get-Content -Raw -Encoding UTF8 (Join-Path $runtimeRoot 'latest\weekly-sop-last-run.json') | ConvertFrom-Json
  Assert-True -Condition ([string]$incompleteDateFailure.message -match 'Date diagnostic is incomplete' -and -not [bool]$incompleteDateFailure.baseline_updated) -Message 'Incomplete Date diagnostic did not fail with the expected no-update contract.'
  Assert-True -Condition ($queryHashBefore -eq (Get-FileHash -LiteralPath $queryBaseline -Algorithm SHA256).Hash -and $pageHashBefore -eq (Get-FileHash -LiteralPath $pageBaseline -Algorithm SHA256).Hash) -Message 'Incomplete Date diagnostic changed a current baseline.'

  $foreignExit = Invoke-Import -ZipPath $foreignZip
  Assert-True -Condition ($foreignExit -ne 0) -Message 'Foreign host import unexpectedly succeeded.'

  $queryHashAfter = (Get-FileHash -LiteralPath $queryBaseline -Algorithm SHA256).Hash
  $pageHashAfter = (Get-FileHash -LiteralPath $pageBaseline -Algorithm SHA256).Hash
  Assert-True -Condition ($queryHashBefore -eq $queryHashAfter) -Message 'Foreign host import changed query baseline.'
  Assert-True -Condition ($pageHashBefore -eq $pageHashAfter) -Message 'Foreign host import changed page baseline.'

  $failureManifestPath = Join-Path $runtimeRoot 'latest\weekly-sop-last-run.json'
  $failureManifest = Get-Content -Raw -Encoding UTF8 $failureManifestPath | ConvertFrom-Json
  Assert-True -Condition ($failureManifest.status -eq 'failed_validation') -Message 'Foreign host failure manifest status is incorrect.'
  Assert-True -Condition (-not [bool]$failureManifest.baseline_updated) -Message 'Foreign host failure incorrectly reports a baseline update.'
  Assert-True -Condition ([string]$failureManifest.message -match 'GSC host validation failed') -Message 'Foreign host failure manifest is missing the host validation reason.'

  $foreignArchives = @(Get-ChildItem -LiteralPath (Join-Path $runtimeRoot 'archive') -Recurse -File -ErrorAction SilentlyContinue | Where-Object { $_.Name -like '*foreign-host*' })
  Assert-True -Condition ($foreignArchives.Count -eq 0) -Message 'Foreign host ZIP was archived even though validation failed.'

  Write-Host 'Weekly SOP data gate tests passed.'
  Write-Host 'Valid host: accepted'
  Write-Host 'Duplicate ZIP: rejected; baseline and per-window manifest unchanged'
  Write-Host 'Foreign host: rejected'
  Write-Host 'Incomplete Date diagnostic: rejected; baseline unchanged'
  Write-Host 'Diagnostic history: dated snapshots retained; overlapping daily rows deduplicated'
  Write-Host 'Manual fallback without diagnostics: monitor_only / no decision-ready strategy'
  Write-Host 'Baseline hashes: unchanged after rejection'
  Write-Host 'Manifest paths: relative and resolvable'
} finally {
  $tempRoot = [System.IO.Path]::GetFullPath([System.IO.Path]::GetTempPath()).TrimEnd('\')
  $resolvedTestRoot = [System.IO.Path]::GetFullPath($testRoot).TrimEnd('\')
  if ($resolvedTestRoot.StartsWith($tempRoot + '\', [System.StringComparison]::OrdinalIgnoreCase) -and (Test-Path -LiteralPath $resolvedTestRoot)) {
    Remove-Item -LiteralPath $resolvedTestRoot -Recurse -Force
  }
}
