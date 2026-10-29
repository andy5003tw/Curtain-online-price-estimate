param()

$ErrorActionPreference = 'Stop'
$utf8NoBom = [System.Text.UTF8Encoding]::new($false)
$repoRoot = Split-Path -Parent $PSScriptRoot
$generator = Join-Path $repoRoot 'Weekly SOP\run-seo-geo-cycle.ps1'
$receiptWriter = Join-Path $repoRoot 'scripts\write-seo-geo-validation-receipt.ps1'
$lifecycleWriter = Join-Path $repoRoot 'scripts\write-seo-geo-lifecycle-receipt.ps1'
$workflowWriter = Join-Path $repoRoot 'scripts\write-seo-geo-workflow-transition.ps1'
$lifecycleNext = Join-Path $repoRoot 'scripts\invoke-seo-geo-lifecycle-next.ps1'
$singlePageApprovalWriter = Join-Path $repoRoot 'scripts\approve-seo-geo-single-page-review.ps1'
$provenanceChecker = Join-Path $repoRoot 'scripts\check-seo-geo-queue-provenance.ps1'
$projectionWriter = Join-Path $repoRoot 'scripts\get-seo-geo-effective-workflow.ps1'
$uiProjectionWriter = Join-Path $repoRoot 'scripts\get-seo-geo-ui-projection.ps1'
$deployPlanWriter = Join-Path $repoRoot 'scripts\new-seo-geo-deploy-plan.ps1'
$autoDeployWriter = Join-Path $repoRoot 'scripts\invoke-seo-geo-autodeploy.ps1'
$testRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("curtain-seo-geo-cycle-{0}" -f ([guid]::NewGuid().ToString('N')))
$runtimeRoot = Join-Path $testRoot 'runtime'
# Keep fixture data fresh while preserving the two-day GSC final-data lag used
# by the runtime configuration.  The fixture must exercise the freshness gate,
# not become stale merely because calendar time has advanced.
$fixtureFinalDate = (Get-Date).Date.AddDays(-2)

function Ensure-Dir {
  param([Parameter(Mandatory = $true)][string]$Path)
  if (-not (Test-Path -LiteralPath $Path -PathType Container)) {
    [void](New-Item -ItemType Directory -Path $Path -Force)
  }
}

function Write-Utf8NoBom {
  param(
    [Parameter(Mandatory = $true)][string]$Path,
    [Parameter(Mandatory = $true)][string]$Text
  )
  Ensure-Dir -Path (Split-Path -Parent $Path)
  [System.IO.File]::WriteAllText($Path, $Text, $utf8NoBom)
}

function Write-Json {
  param(
    [Parameter(Mandatory = $true)][string]$Path,
    [Parameter(Mandatory = $true)][object]$Value
  )
  Write-Utf8NoBom -Path $Path -Text (($Value | ConvertTo-Json -Depth 20) + [Environment]::NewLine)
}

function Read-Json {
  param([Parameter(Mandatory = $true)][string]$Path)
  return Get-Content -LiteralPath $Path -Raw -Encoding UTF8 | ConvertFrom-Json
}

function Assert-True {
  param(
    [bool]$Condition,
    [Parameter(Mandatory = $true)][string]$Message
  )
  if (-not $Condition) { throw $Message }
}

function Assert-MarkdownSectionTableFormat {
  param(
    [Parameter(Mandatory = $true)][string]$Markdown,
    [Parameter(Mandatory = $true)][string]$Heading
  )

  $lines = @($Markdown -split '\r?\n')
  $start = -1
  for ($index = 0; $index -lt $lines.Count; $index++) {
    if ([string]$lines[$index] -ceq $Heading) { $start = $index; break }
  }
  if ($start -lt 0) { throw "Markdown table section is missing heading: $Heading" }

  $headingLevel = ([regex]::Match($Heading, '^#+')).Length
  $end = $lines.Count
  for ($index = $start + 1; $index -lt $lines.Count; $index++) {
    $nextHeading = [regex]::Match([string]$lines[$index], '^\s*(#{1,6})\s+')
    if ($nextHeading.Success -and $nextHeading.Groups[1].Value.Length -le $headingLevel) { $end = $index; break }
  }

  $tableHeader = -1
  for ($index = $start + 1; $index -lt $end; $index++) {
    if (([string]$lines[$index]).TrimStart().StartsWith('|', [StringComparison]::Ordinal)) { $tableHeader = $index; break }
  }
  $delimiterPattern = '^\|\s*:?-{3,}:?\s*(?:\|\s*:?-{3,}:?\s*)+\|$'
  $hasSeparateDelimiter = $tableHeader -ge 0 -and ($tableHeader + 1) -lt $end -and ([string]$lines[$tableHeader + 1]).Trim() -match $delimiterPattern
  Assert-True $hasSeparateDelimiter "Markdown table under '$Heading' must put its delimiter row on the line immediately after the header."
}

function Invoke-PwshFile {
  param(
    [Parameter(Mandatory = $true)][string]$File,
    [string[]]$ScriptArgs = @()
  )
  $output = @(& pwsh -NoLogo -NoProfile -File $File @ScriptArgs 2>&1)
  return [PSCustomObject]@{
    ExitCode = [int]$LASTEXITCODE
    Output = @($output | ForEach-Object { [string]$_ })
  }
}

function Convert-CommandJson {
  param(
    [Parameter(Mandatory = $true)][string[]]$Output,
    [Parameter(Mandatory = $true)][string]$Label
  )
  $json = [string]::Join([Environment]::NewLine, $Output).Trim()
  try {
    return ConvertFrom-Json -InputObject $json -ErrorAction Stop
  } catch {
    throw "$Label did not emit valid JSON: $($_.Exception.Message)`nRaw output: $json"
  }
}

function Get-UiProjectionFixture {
  $result = Invoke-PwshFile -File $uiProjectionWriter -ScriptArgs @('-RuntimeRoot', $runtimeRoot, '-RepoRoot', $runtimeRoot)
  Assert-True ($result.ExitCode -eq 0) ('UI projection fixture failed: ' + ($result.Output -join ' '))
  return Convert-CommandJson -Output $result.Output -Label 'UI projection fixture'
}

function Invoke-Generator {
  $result = Invoke-PwshFile -File $generator -ScriptArgs @(
    '-Mode', 'auto',
    '-RuntimeRoot', $runtimeRoot
  )
  if ($result.ExitCode -ne 0) {
    $result.Output | ForEach-Object { Write-Host $_ }
    throw "SEO/GEO generator failed with exit code $($result.ExitCode)."
  }
  return $result
}

function Write-Baselines {
  param(
    [ValidateSet('7d', '28d')][string]$Window,
    [int]$CasesImpressions,
    [double]$CasesCtr,
    [double]$CasesPosition
  )
  $historyRoot = Join-Path $runtimeRoot "history\curtain-online\$Window"
  $queryPath = Join-Path $historyRoot 'current_query_baseline.normalized.csv'
  $pagePath = Join-Path $historyRoot 'current_page_baseline.normalized.csv'
  $queryPagePath = Join-Path $historyRoot 'current_query_page_baseline.normalized.csv'
  $comparisonQueryPath = Join-Path $historyRoot 'previous_query_baseline.normalized.csv'
  $multiplier = if ($Window -eq '28d') { 4 } else { 1 }

  Write-Utf8NoBom -Path $queryPath -Text (@(
    'query,page,clicks,impressions,ctr,position'
    "測試案例主詞,(all pages),0,$([Math]::Max(1, [int]($CasesImpressions / 2))),0,$CasesPosition"
    "測試品牌主詞,(all pages),1,$(17 * $multiplier),1.47,7.2"
    "測試品牌次詞,(all pages),0,$(80 * $multiplier),0,9.1"
    "測試產品比較詞,(all pages),2,$(22 * $multiplier),2.27,11.4"
    "本期新增查詢,(all pages),1,$(9 * $multiplier),2.78,13.2"
    "一次曝光雜訊,(all pages),0,1,0,8"
    "蛇形窗簾,(all pages),0,$([int](165 / $multiplier)),0,12"
  ) -join "`r`n")

  Write-Utf8NoBom -Path $comparisonQueryPath -Text (@(
    'query,page,clicks,impressions,ctr,position'
    "測試案例主詞,(all pages),0,$([Math]::Max(1, [int]($CasesImpressions / 2))),0,$CasesPosition"
    "測試品牌主詞,(all pages),1,$(17 * $multiplier),1.47,7.2"
    "測試品牌次詞,(all pages),0,$(80 * $multiplier),0,9.1"
    "測試產品比較詞,(all pages),2,$(22 * $multiplier),2.27,11.4"
    "本期消失查詢,(all pages),1,$(8 * $multiplier),3.12,14.1"
    "蛇形窗簾,(all pages),0,$([int](165 / $multiplier)),0,12"
  ) -join "`r`n")

  Write-Utf8NoBom -Path $pagePath -Text (@(
    'query,page,clicks,impressions,ctr,position'
    ",https://online.hong-sen.com/cases/,0,$CasesImpressions,$CasesCtr,$CasesPosition"
    ",https://online.hong-sen.com/about/,1,$(120 * $multiplier),0.21,6.8"
    ",https://online.hong-sen.com/products/,2,$(23 * $multiplier),2.17,12.1"
    ",https://online.hong-sen.com/products/s-fold-curtains/,0,$([int](165 / $multiplier)),0,12"
  ) -join "`r`n")

  Write-Utf8NoBom -Path $queryPagePath -Text (@(
    'query,page,clicks,impressions,ctr,position'
    "測試案例主詞,https://online.hong-sen.com/cases/,0,$(60 * $multiplier),0,9"
    "測試案例主詞,https://online.hong-sen.com/products/,0,$(40 * $multiplier),0,10"
    "測試品牌主詞,https://online.hong-sen.com/about/,1,$(17 * $multiplier),1.47,7.2"
    "測試品牌次詞,https://online.hong-sen.com/about/,0,$(40 * $multiplier),0,9.1"
    "測試產品總覽主詞,https://online.hong-sen.com/products/,2,$(22 * $multiplier),2.27,11.4"
    "測試產品總覽主詞,https://online.hong-sen.com/products/P006/,1,$(5 * $multiplier),1.00,12.4"
    "蛇形窗簾,https://online.hong-sen.com/products/s-fold-curtains/,0,9,0,12"
    "蛇形窗簾,https://online.hong-sen.com/products/,0,156,0,13"
  ) -join "`r`n")
}

function Write-WindowManifest {
  param(
    [ValidateSet('7d', '28d')][string]$Window,
    [ValidateSet('monitor_only', 'decision_ready')][string]$Confidence,
    [bool]$Bootstrapped,
    [char]$ShaCharacter
  )
  $manifestPath = Join-Path $runtimeRoot "latest\$Window\weekly-sop-last-run.json"
  $historyRelative = "history/curtain-online/$Window"
  $historyFull = Join-Path $runtimeRoot ($historyRelative.Replace('/', '\'))
  $windowDays = if ($Window -eq '7d') { 7 } else { 28 }
  $startDate = $fixtureFinalDate.AddDays(1 - $windowDays).ToString('yyyy-MM-dd')
  $endDate = $fixtureFinalDate.ToString('yyyy-MM-dd')
  $comparisonPeriod = $null
  if ($Window -eq '28d') {
    $comparisonPeriod = [ordered]@{
      start_date = $fixtureFinalDate.AddDays(-55).ToString('yyyy-MM-dd')
      end_date = $fixtureFinalDate.AddDays(-28).ToString('yyyy-MM-dd')
      comparison_type = 'non_overlapping'
      overlap_days = 0
    }
  }
  $dates=@();$cursor=[datetime]::ParseExact($startDate,'yyyy-MM-dd',[Globalization.CultureInfo]::InvariantCulture);$end=[datetime]::ParseExact($endDate,'yyyy-MM-dd',[Globalization.CultureInfo]::InvariantCulture);while($cursor -le $end){$dates += $cursor.ToString('yyyy-MM-dd');$cursor=$cursor.AddDays(1)}
  $diagnosticDefinitions=[ordered]@{
    date=[PSCustomObject]@{slug='date';header='Date,Clicks,Impressions,CTR,Position';rows=@($dates|ForEach-Object{"$_,1,20,5%,9"})}
    date_page=[PSCustomObject]@{slug='date_page';header='Date,Page,Clicks,Impressions,CTR,Position';rows=@($dates|ForEach-Object{"$_,https://online.hong-sen.com/cases/,1,20,5%,9"})}
    device_page=[PSCustomObject]@{slug='device_page';header='Date,Device,Page,Clicks,Impressions,CTR,Position';rows=@($dates|ForEach-Object{"$_,MOBILE,https://online.hong-sen.com/cases/,1,20,5%,9"})}
    country_page=[PSCustomObject]@{slug='country_page';header='Date,Country,Page,Clicks,Impressions,CTR,Position';rows=@($dates|ForEach-Object{"$_,twn,https://online.hong-sen.com/cases/,1,20,5%,9"})}
    device_query=[PSCustomObject]@{slug='device_query';header='Date,Device,Query,Clicks,Impressions,CTR,Position';rows=@($dates|ForEach-Object{"$_,MOBILE,測試案例主詞,1,20,5%,9"})}
  }
  $diagnosticBindings=[ordered]@{}
  foreach($kind in $diagnosticDefinitions.Keys){$definition=$diagnosticDefinitions[$kind];$path=Join-Path $historyFull ("current_$($definition.slug)_diagnostic.csv");Write-Utf8NoBom -Path $path -Text ((@($definition.header)+@($definition.rows)) -join "`r`n");$diagnosticBindings[$kind]=[ordered]@{available=$true;row_count=$dates.Count;path="$historyRelative/current_$($definition.slug)_diagnostic.csv";sha256=(Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash.ToLowerInvariant()}}
  $manifest = [ordered]@{
    schema_version = 2
    status = 'success'
    site_id = 'curtain-online'
    property = 'https://online.hong-sen.com/'
    expected_host = 'online.hong-sen.com'
    window = $Window
    run_id = "fixture-$Window-$Confidence"
    run_time = (Get-Date).ToString('o')
    input_sha256 = ([string]$ShaCharacter) * 64
    host_counts = [ordered]@{ target = 3; foreign = 0; invalid = 0 }
    report_folder = $historyRelative
    latest_reports = [ordered]@{}
    data_confidence = $Confidence
    decision_ready = ($Confidence -eq 'decision_ready' -and -not $Bootstrapped)
    start_date = $startDate
    end_date = $endDate
    date_range_complete = $true
    query_page_available = $true
    diagnostics_complete = $true
    diagnostic_dimensions = $diagnosticBindings
    snapshot_family_id = "fixture|https://online.hong-sen.com/|$endDate|Asia/Taipei"
    baseline = [ordered]@{
      query = "$historyRelative/current_query_baseline.normalized.csv"
      page = "$historyRelative/current_page_baseline.normalized.csv"
      query_page = "$historyRelative/current_query_page_baseline.normalized.csv"
      bootstrapped = $Bootstrapped
    }
    comparison_sources = [ordered]@{ query_before = "$historyRelative/previous_query_baseline.normalized.csv" }
    comparison_period = $comparisonPeriod
  }
  Write-Json -Path $manifestPath -Value $manifest
}

function Test-ReviewWindowBoundaries {
  $tokens = $null
  $parseErrors = $null
  $generatorAst = [System.Management.Automation.Language.Parser]::ParseFile($generator, [ref]$tokens, [ref]$parseErrors)
  if ($parseErrors.Count -gt 0) { throw "Could not parse generator review-window helpers: $($parseErrors[0].Message)" }
  $requiredFunctions = @('Get-ReturnedMetrics', 'Get-ExactPrimaryKeywordMetrics', 'Measure-DiagnosticMetrics', 'Get-PeriodDiagnosticResult', 'Format-DiagnosticResult', 'Get-NonOverlappingReviewWindows')
  $functionAsts = @($generatorAst.FindAll({
    param($node)
    $node -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $requiredFunctions -contains $node.Name
  }, $true))
  $functionSource = @()
  foreach ($name in $requiredFunctions) {
    $definition = @($functionAsts | Where-Object { $_.Name -eq $name } | Select-Object -First 1)[0]
    if (-not $definition) { throw "Generator is missing review-window helper function $name." }
    $functionSource += $definition.Extent.Text
  }
  $extractedSource = $functionSource -join [Environment]::NewLine
  . ([scriptblock]::Create($extractedSource))

  $unavailableOwner = [PSCustomObject]@{ primaryKeyword = 'fixture unavailable primary'; ownerPage = 'https://online.hong-sen.com/fixture-unavailable/'; variants = @() }
  $unavailableMetrics = Get-ExactPrimaryKeywordMetrics -Owner $unavailableOwner -QueryMap @{} -QueryPageRows @() -QueryAvailable $false -QueryPageAvailable $false
  Assert-True ([string]$unavailableMetrics.site.status -eq 'unavailable' -and [string]$unavailableMetrics.owner.status -eq 'unavailable' -and -not [bool]$unavailableMetrics.site.row_found -and $null -eq $unavailableMetrics.site.impressions) 'An unavailable baseline was mislabeled as a query that GSC did not return.'
  $zeroImpressionRow = Get-ReturnedMetrics -Rows @([PSCustomObject]@{ clicks = 0; impressions = 0; ctr = 0; position = 0 }) -Scope 'fixture_zero_impressions' -Available $true
  Assert-True ([string]$zeroImpressionRow.status -eq 'available' -and [bool]$zeroImpressionRow.row_found -and [int]$zeroImpressionRow.clicks -eq 0 -and [int]$zeroImpressionRow.impressions -eq 0 -and $null -eq $zeroImpressionRow.ctr -and $null -eq $zeroImpressionRow.position) 'A returned zero-impression row did not retain null CTR and position.'

  $changeDate = (Get-Date).Date.AddDays(-28)
  $post28End = $changeDate.AddDays(28)
  $rangeStart = $changeDate.AddDays(-28)
  $ownerPage = 'https://online.hong-sen.com/'
  $owner = [PSCustomObject]@{
    clusterId = 'fixture-home-review'
    ownerPage = $ownerPage
    lastChangedAt = $changeDate.ToString('yyyy-MM-dd')
  }

  $makeRows = {
    param([datetime]$ThroughDate, [string]$OmitDate = '')
    $dateRows = [System.Collections.Generic.List[object]]::new()
    $datePageRows = [System.Collections.Generic.List[object]]::new()
    $cursor = $rangeStart
    while ($cursor -le $ThroughDate) {
      $date = $cursor.ToString('yyyy-MM-dd')
      if ($date -ne $OmitDate) {
        $dateRows.Add([PSCustomObject]@{ date = $date; clicks = 2; impressions = 4; ctr = 50.0; position = 5.0 })
        $datePageRows.Add([PSCustomObject]@{ date = $date; page = $ownerPage; clicks = 1; impressions = 2; ctr = 50.0; position = 5.0 })
      }
      $cursor = $cursor.AddDays(1)
    }
    return [PSCustomObject]@{ date_rows = @($dateRows.ToArray()); date_page_rows = @($datePageRows.ToArray()) }
  }

  $beforeLatest = $post28End.AddDays(-1)
  $beforeRows = & $makeRows -ThroughDate $beforeLatest
  $beforeWindow = @(Get-NonOverlappingReviewWindows -Owners @($owner) -LatestFinalizedDate $beforeLatest.ToString('yyyy-MM-dd') -DateRows $beforeRows.date_rows -DatePageRows $beforeRows.date_page_rows)[0]
  Assert-True ($beforeWindow.post_28d -eq "$($changeDate.AddDays(1).ToString('yyyy-MM-dd'))~$($post28End.ToString('yyyy-MM-dd'))") 'Post-28d window did not exclude the change date or include the 28th day.'
  Assert-True ($beforeWindow.review_28d_status -eq 'awaiting_complete_post_window') 'Post-28d review became eligible before its final day was finalized.'

  $completeRows = & $makeRows -ThroughDate $post28End
  $completeWindow = @(Get-NonOverlappingReviewWindows -Owners @($owner) -LatestFinalizedDate $post28End.ToString('yyyy-MM-dd') -DateRows $completeRows.date_rows -DatePageRows $completeRows.date_page_rows)[0]
  Assert-True ($completeWindow.review_28d_status -eq 'eligible' -and [bool]$completeWindow.post_28d_result.available) 'A fully covered post-28d window was not marked eligible at its final day.'
  Assert-True ([int]$completeWindow.post_28d_result.impressions -eq 56) 'Post-28d metrics did not cover all 28 days after the change date.'

  $missingDate = $post28End.ToString('yyyy-MM-dd')
  $missingRows = & $makeRows -ThroughDate $post28End -OmitDate $missingDate
  $missingWindow = @(Get-NonOverlappingReviewWindows -Owners @($owner) -LatestFinalizedDate $post28End.ToString('yyyy-MM-dd') -DateRows $missingRows.date_rows -DatePageRows $missingRows.date_page_rows)[0]
  Assert-True ($missingWindow.review_28d_status -eq 'data_unavailable' -and -not [bool]$missingWindow.post_28d_result.available) 'Post-28d review passed despite a missing finalized Date row.'
  Assert-True ([string]$missingWindow.post_28d_result.reason -match [regex]::Escape($missingDate)) 'Post-28d missing-date reason did not identify the uncovered final day.'
}

function Test-ObservationBackfillIsolation {
  param(
    [Parameter(Mandatory = $true)][string]$SourceRuntimeRoot,
    [Parameter(Mandatory = $true)][datetime]$LatestFinalDate,
    [switch]$FinalWindowComplete
  )

  $isolatedRuntimeRoot = Join-Path $testRoot $(if ($FinalWindowComplete) { 'observation-backfill-final-runtime' } else { 'observation-backfill-runtime' })
  Ensure-Dir -Path $isolatedRuntimeRoot
  foreach ($item in @(Get-ChildItem -LiteralPath $SourceRuntimeRoot -Force)) {
    Copy-Item -LiteralPath $item.FullName -Destination $isolatedRuntimeRoot -Recurse -Force
  }

  $periodEnd = if ($FinalWindowComplete) { $LatestFinalDate.Date } else { $LatestFinalDate.Date.AddDays(1) }
  $periodStart = $periodEnd.AddDays(-27)
  $changeDate = $periodStart.AddDays(-1)
  $finalDayCount = if ($FinalWindowComplete) { 28 } else { 27 }
  $homePage = 'https://online.hong-sen.com/'
  $homeClusterId = 'fixture-home-backfill'

  $registryPath = Join-Path $isolatedRuntimeRoot 'config\target-registry.json'
  $registry = Read-Json -Path $registryPath
  $registry.targets = @($registry.targets) + @([ordered]@{
    clusterId = $homeClusterId; layer = 'brand'; primaryKeyword = '測試首頁主詞'; variants = @()
    intent = 'homepage'; ownerUrl = '/'; pageType = 'home'; priority = 'P0'; schemaProfile = 'website'
    businessValue = 'critical'; lastChangedAt = $changeDate.ToString('yyyy-MM-dd'); status = 'active'
  })
  Write-Json -Path $registryPath -Value $registry

  $periodDates = @(0..27 | ForEach-Object { $periodStart.AddDays($_).ToString('yyyy-MM-dd') })
  $finalPageRows = @($periodDates | Select-Object -First $finalDayCount | ForEach-Object {
    [PSCustomObject]@{ date = $_; page = $homePage; clicks = 1; impressions = 20; ctr = 5; position = 9 }
  })
  $previewPageRows = @($periodDates | ForEach-Object {
    [PSCustomObject]@{ date = $_; page = $homePage; clicks = 1; impressions = 20; ctr = 5; position = 9 }
  })
  $pendingDate = [string]$periodDates[-1]
  $pendingPageRows = @($previewPageRows | Where-Object { -not $FinalWindowComplete -and $_.date -eq $pendingDate })
  $finalClicks = [int](($finalPageRows | Measure-Object -Property clicks -Sum).Sum)
  $finalImpressions = [int](($finalPageRows | Measure-Object -Property impressions -Sum).Sum)
  $finalPosition = [double](($finalPageRows | ForEach-Object { [double]$_.position * [int]$_.impressions } | Measure-Object -Sum).Sum / $finalImpressions)
  $previewClicks = [int](($previewPageRows | Measure-Object -Property clicks -Sum).Sum)
  $previewImpressions = [int](($previewPageRows | Measure-Object -Property impressions -Sum).Sum)
  $previewPosition = [double](($previewPageRows | ForEach-Object { [double]$_.position * [int]$_.impressions } | Measure-Object -Sum).Sum / $previewImpressions)
  $audit = [ordered]@{
    schema_version = 1
    generated_at = (Get-Date).ToUniversalTime().ToString('o')
    property = 'https://online.hong-sen.com/'
    cluster_id = $homeClusterId
    page = $homePage
    change_date = $changeDate.ToString('yyyy-MM-dd')
    date_source = 'registry.lastChangedAt (source change date; not a deployment timestamp)'
    period = [ordered]@{ start_date = $periodStart.ToString('yyyy-MM-dd'); end_date = $periodEnd.ToString('yyyy-MM-dd'); days = 28 }
    latest_api_final_date = $LatestFinalDate.Date.ToString('yyyy-MM-dd')
    status = if ($FinalWindowComplete) { 'complete' } else { 'awaiting_final_data' }
    final_window_complete = [bool]$FinalWindowComplete
    finalized_day_count = $finalDayCount
    missing_final_dates = @($periodDates | Select-Object -Skip $finalDayCount)
    first_incomplete_date = if ($FinalWindowComplete) { $null } else { $pendingDate }
    finalized_page_totals = [ordered]@{ returned_row_count = $finalPageRows.Count; clicks = $finalClicks; impressions = $finalImpressions; ctr = ($finalClicks * 100.0 / $finalImpressions); position = $finalPosition }
    preview_page_totals = [ordered]@{ returned_row_count = $previewPageRows.Count; clicks = $previewClicks; impressions = $previewImpressions; ctr = ($previewClicks * 100.0 / $previewImpressions); position = $previewPosition }
    preview_site_day_rows = @($pendingPageRows | ForEach-Object { [PSCustomObject]@{ date = $_.date; clicks = 1; impressions = 20; ctr = '5%'; position = 9 } })
    preview_page_day_rows = $pendingPageRows
    preliminary_promoted_to_baseline = $false
    metric_scopes = [ordered]@{
      finalized_page_totals = 'dataState=final rows for this page across the requested 28-day period.'
      preview_page_totals = 'dataState=all rows for this page across the full 28-day period; may include finalized and preliminary dates.'
    preview_page_day_rows = 'dataState=all page rows restricted to dates missing final data.'
    }
    interpretation = 'Preview includes preliminary data and must not affect final eligibility or baseline metrics.'
  }
  Write-Json -Path (Join-Path $isolatedRuntimeRoot 'latest\gsc-observation-backfill.json') -Value $audit

  $result = Invoke-PwshFile -File $generator -ScriptArgs @('-Mode', 'auto', '-RuntimeRoot', $isolatedRuntimeRoot)
  if ($result.ExitCode -ne 0) {
    $result.Output | ForEach-Object { Write-Host $_ }
    throw "SEO/GEO backfill fixture failed with exit code $($result.ExitCode)."
  }

  $queue = Read-Json -Path (Join-Path $isolatedRuntimeRoot 'latest\seo-geo-action-queue.json')
  $plan = Read-Json -Path (Join-Path $isolatedRuntimeRoot 'latest\seo-geo-action-plan.json')
  $html = Get-Content -LiteralPath (Join-Path $isolatedRuntimeRoot 'latest\seo-geo-action-plan.html') -Raw -Encoding UTF8
  $md = Get-Content -LiteralPath (Join-Path $isolatedRuntimeRoot 'latest\seo-geo-action-plan.md') -Raw -Encoding UTF8
  $queueAudit = $queue.observation_backfill
  $planAudit = $plan.observation_backfill
  $homeReview = @($queue.review_windows | Where-Object { $_.page -eq $homePage })[0]
  $scopeJson = ConvertTo-Json -InputObject $queueAudit.metric_scopes -Depth 8 -Compress

  Assert-True ($null -ne $queueAudit -and [string]$queueAudit.cluster_id -eq $homeClusterId -and [int]$queueAudit.preview_page_totals.returned_row_count -eq 28 -and [int]$queueAudit.preview_page_totals.impressions -eq 560) 'The matching observation audit did not remain a separate full-window preliminary preview in queue JSON.'
  Assert-True ($null -ne $planAudit -and [string]$planAudit.page -eq $homePage -and [bool]$planAudit.preliminary_promoted_to_baseline -eq $false) 'The matching observation audit was not carried into plan JSON as non-baseline evidence.'
  Assert-True (($scopeJson -match 'preview_page_totals') -and ($scopeJson -match '(?i)(full|whole|entire|完整|全).{0,24}(28|二十八).{0,16}(day|日)') -and ($scopeJson -match 'preview_page_day_rows') -and ($scopeJson -match '(?i)(pending|missing.{0,12}final|待補|缺正式)')) 'Observation metric_scopes does not distinguish full-window totals from pending-day preview rows.'
  $fixedPeriod = @($queue.report_periods | Where-Object { $_.id -eq 'homepage_fixed_post_28d' })[0]
  Assert-True ($null -ne $fixedPeriod -and [string]$fixedPeriod.start_date -eq $periodStart.ToString('yyyy-MM-dd') -and [string]$fixedPeriod.end_date -eq $periodEnd.ToString('yyyy-MM-dd') -and [int]$fixedPeriod.finalized_day_count -eq $finalDayCount -and [bool]$fixedPeriod.final_window_complete -eq [bool]$FinalWindowComplete) 'Report period metadata lost the fixed-window dates or final completeness.'
  if (-not $FinalWindowComplete) {
    Assert-True ($null -ne $homeReview -and [string]$homeReview.post_28d -eq "$($periodStart.ToString('yyyy-MM-dd'))~$($periodEnd.ToString('yyyy-MM-dd'))" -and [string]$homeReview.review_28d_status -eq 'awaiting_complete_post_window') 'A 28-day all-state preview incorrectly made the homepage review eligible before the final date.'
    Assert-True ([int]@($queueAudit.preview_page_day_rows).Count -eq 1 -and [string]$queueAudit.preview_page_day_rows[0].date -eq $pendingDate) 'Pending-day preview rows did not remain limited to the one date missing from final data.'
  }
  Assert-MarkdownSectionTableFormat -Markdown $md -Heading '## 首頁上一輪 28 天觀察'

  $htmlSectionStart = $html.IndexOf('<h2>首頁上一輪 28 天觀察</h2>', [StringComparison]::Ordinal)
  $mdSectionStart = $md.IndexOf('## 首頁上一輪 28 天觀察', [StringComparison]::Ordinal)
  Assert-True ($htmlSectionStart -ge 0 -and $mdSectionStart -ge 0) 'HTML/Markdown did not render the homepage backfill observation section.'
  $htmlSectionEnd = $html.IndexOf('<h2>', $htmlSectionStart + '<h2>首頁上一輪 28 天觀察</h2>'.Length, [StringComparison]::Ordinal)
  if ($htmlSectionEnd -lt 0) { $htmlSectionEnd = $html.Length }
  $htmlSection = $html.Substring($htmlSectionStart, $htmlSectionEnd - $htmlSectionStart)
  $mdSectionEnd = $md.IndexOf("`n## ", $mdSectionStart + '## 首頁上一輪 28 天觀察'.Length, [StringComparison]::Ordinal)
  if ($mdSectionEnd -lt 0) { $mdSectionEnd = $md.Length }
  $mdSection = $md.Substring($mdSectionStart, $mdSectionEnd - $mdSectionStart)
  $periodLabel = "$($periodStart.ToString('yyyy-MM-dd'))~$($periodEnd.ToString('yyyy-MM-dd'))"
  if ($FinalWindowComplete) {
    foreach ($section in @($htmlSection, $mdSection)) {
      Assert-True (($section -match '28/28') -and ($section -match '固定觀察期已完整') -and ($section -match 'dataState=final') -and ($section -match '560') -and ($section -notmatch '包含初步資料，僅預覽|待正式資料的首頁單日初步值|仍在處理')) 'A complete final homepage window was still rendered as a pending preview.'
    }
    $scope = [string]$queue.metric_scopes.homepage_fixed_window
    Assert-True (($scope -match 'finalized_page_totals.{0,40}dataState=final') -and ($scope -match 'preview_page_totals.{0,60}dataState=all')) 'Queue metadata conflated finalized fixed-window totals with all-state preview totals.'
  } else {
    Assert-True (($htmlSection -match '包含初步資料，僅預覽') -and ($htmlSection -match [regex]::Escape($periodLabel)) -and ($htmlSection -match '560')) 'HTML homepage preview did not label the full 28-day all-state totals and date range as preliminary.'
    Assert-True (($mdSection -match '包含初步資料，僅預覽') -and ($mdSection -match [regex]::Escape($periodLabel)) -and ($mdSection -match '560')) 'Markdown homepage preview did not label the full 28-day all-state totals and date range as preliminary.'
  }
  foreach ($name in @('seo-geo-action-plan.md', 'seo-geo-action-plan.html', 'seo-geo-action-plan.ai.md', 'seo-geo-action-plan.slim.ai.md', 'seo-geo-action-plan.optional.slim.ai.md')) {
    $document = Get-Content -LiteralPath (Join-Path $isolatedRuntimeRoot "latest\$name") -Raw -Encoding UTF8
    Assert-True (($document -match [regex]::Escape($periodLabel)) -and ($document -match "$finalDayCount/28") -and ($document -match '重複附件與重疊視窗不加總')) "Generated $name lost the fixed-window dates, final day count, or no-double-counting rule."
  }
}

function Copy-SourceFixture {
  param([Parameter(Mandatory = $true)][string]$RelativePath)
  $sourcePath = Join-Path $repoRoot ($RelativePath.Replace('/', '\'))
  $targetPath = Join-Path $runtimeRoot ($RelativePath.Replace('/', '\'))
  Ensure-Dir -Path (Split-Path -Parent $targetPath)
  Copy-Item -LiteralPath $sourcePath -Destination $targetPath -Force
}

Ensure-Dir -Path $runtimeRoot
try {
  Write-Json -Path (Join-Path $runtimeRoot 'config\site-config.json') -Value ([ordered]@{
    schemaVersion = 1
    siteId = 'curtain-online'
    siteUrl = 'https://online.hong-sen.com/'
    expectedHost = 'online.hong-sen.com'
    gscProperty = 'https://online.hong-sen.com/'
    timezone = 'Asia/Taipei'
    dataLagDays = 2
    allowedHosts = @('online.hong-sen.com')
  })

  Test-ReviewWindowBoundaries

  $today = Get-Date -Format 'yyyy-MM-dd'
  Write-Json -Path (Join-Path $runtimeRoot 'config\target-registry.json') -Value ([ordered]@{
    schemaVersion = 9
    siteId = 'curtain-online-fixture'
    updatedAt = $today
    targets = @(
      [ordered]@{
        clusterId = 'fixture-cases'; layer = 'support'; primaryKeyword = '測試案例主詞'; variants = @('測試案例次詞')
        intent = 'support'; ownerUrl = '/cases/'; pageType = 'cases'; priority = 'P0'; schemaProfile = 'article'
        businessValue = 'critical'; lastChangedAt = $null; status = 'active'
      },
      [ordered]@{
        clusterId = 'fixture-about'; layer = 'brand'; primaryKeyword = '測試品牌主詞'; variants = @('測試品牌次詞')
        intent = 'brand'; ownerUrl = '/about/'; pageType = 'about'; priority = 'P1'; schemaProfile = 'organization'
        businessValue = 'high'; lastChangedAt = $null; status = 'active'
      },
      [ordered]@{
        clusterId = 'product-P006'; layer = 'hub'; primaryKeyword = '測試產品總覽主詞'; variants = @('測試產品比較詞')
        intent = 'hub'; ownerUrl = '/products/'; pageType = 'hub'; priority = 'P1'; schemaProfile = 'collection'
        businessValue = 'high'; lastChangedAt = $today; status = 'active'
      },
      [ordered]@{
        clusterId = 'product-P003'; layer = 'product'; primaryKeyword = '蛇形窗簾'; variants = @('蛇形簾')
        intent = 'product-transactional'; ownerUrl = '/products/s-fold-curtains/'; pageType = 'product'; priority = 'P1'; schemaProfile = 'product'
        businessValue = 'high'; lastChangedAt = $null; status = 'active'
      }
    )
    monitorOnlyAssets = @(
      [ordered]@{ id = 'fixture-calculator'; label = '測試估價工具'; type = 'calculator'; url = '/calculator/'; monitoringTerms = @('測試估價') },
      [ordered]@{ id = 'fixture-price-guide'; label = '測試價格指南'; type = 'price_guide'; url = '/blog/fixture-price-guide/'; monitoringTerms = @('測試價格') }
    )
  })

  foreach ($relativePath in @(
    'src/app/cases/layout.tsx',
    'src/app/cases/page.tsx',
    'src/app/about/page.tsx',
    'src/app/products/page.tsx',
    'src/app/products/[slug]/page.tsx',
    'src/data/products.ts',
    'src/lib/seo.ts'
  )) {
    Copy-SourceFixture -RelativePath $relativePath
  }

  Write-Baselines -Window '7d' -CasesImpressions 11 -CasesCtr 0 -CasesPosition 9
  Write-Baselines -Window '28d' -CasesImpressions 51 -CasesCtr 0 -CasesPosition 9
  Write-WindowManifest -Window '7d' -Confidence monitor_only -Bootstrapped $true -ShaCharacter '7'
  Write-WindowManifest -Window '28d' -Confidence monitor_only -Bootstrapped $true -ShaCharacter '2'
  Write-Json -Path (Join-Path $runtimeRoot 'history\curtain-online\ctr-benchmark-history.json') -Value ([ordered]@{
    schema_version = 1
    windows = @([ordered]@{ window_key='2026-07-14~2026-08-10'; start_date='2026-07-14'; end_date='2026-08-10'; generated_at='2026-08-12T00:00:00Z'; segments=@() })
  })

  [void](Invoke-Generator)
  $queuePath = Join-Path $runtimeRoot 'latest\seo-geo-action-queue.json'
  $statePath = Join-Path $runtimeRoot 'latest\seo-geo-action-queue-state.json'
  $slimPath = Join-Path $runtimeRoot 'latest\seo-geo-action-plan.slim.ai.md'
  $htmlPath = Join-Path $runtimeRoot 'latest\seo-geo-action-plan.html'
  $mdPath = Join-Path $runtimeRoot 'latest\seo-geo-action-plan.md'
  $aiPath = Join-Path $runtimeRoot 'latest\seo-geo-action-plan.ai.md'
  $queue = Read-Json -Path $queuePath
  $state = Read-Json -Path $statePath
  $slim = Get-Content -LiteralPath $slimPath -Raw -Encoding UTF8
  $html = Get-Content -LiteralPath $htmlPath -Raw -Encoding UTF8
  $md = Get-Content -LiteralPath $mdPath -Raw -Encoding UTF8
  $ai = Get-Content -LiteralPath $aiPath -Raw -Encoding UTF8
  $optionalAi = Get-Content -LiteralPath (Join-Path $runtimeRoot 'latest\seo-geo-action-plan.optional.slim.ai.md') -Raw -Encoding UTF8
  $casesObservation = @($queue.observations | Where-Object { $_.page -eq 'https://online.hong-sen.com/cases/' })[0]
  $brandObservation = @($queue.observations | Where-Object { $_.cluster_id -eq 'fixture-about' })[0]
  $productsObservation = @($queue.observations | Where-Object { $_.cluster_id -eq 'product-P006' })[0]

  Assert-True ($queue.status -eq 'observation_only') 'monitor_only generated an executable queue.'
  Assert-True ($html -match '<h1>SEO/GEO 重點報告</h1>' -and $html -match '核心關鍵字表現' -and $html -match '現在要做什麼' -and $html -match '重要提醒') 'Human HTML report is missing its concise decision and keyword summary.'
  Assert-True ($html -match '7d 曝光' -and $html -match '7d 平均排名' -and $html -match '28d 平均排名' -and $html -match '詞群 Owner share') 'Human HTML report is missing the scoped page-average ranking or cluster-share labels.'
  Assert-True ($html -match '可正式判斷（decision-ready）' -and $html -match '本輪不修改網站') 'Human HTML report is missing Chinese annotations for report status terms.'
  Assert-True ($html -notmatch 'Diagnostic Analysis' -and $html -notmatch 'Per-page Compliance') 'Human HTML report must not render full diagnostic or per-page detail tables by default.'
  Assert-True ($html -match '完整明細保留於 JSON' -and $html -match '\*\.ai\.md') 'Human HTML report must direct detailed review and AI execution to the correct artifacts.'
  Assert-True (($html -match '整頁指標') -and ($html -match '精確主攻詞') -and ($html -match '詞群 Owner share') -and ($html -match '首頁上一輪 28 天觀察')) 'Human HTML report is missing the separated page, exact-keyword, cluster-share, or homepage-review sections.'
  Assert-True (($md -match '整頁指標') -and ($md -match '精確主攻詞') -and ($md -match '詞群 Owner share') -and ($md -match '首頁上一輪 28 天觀察')) 'Human Markdown report is missing the separated page, exact-keyword, cluster-share, or homepage-review sections.'
  foreach ($markdownTableSection in @('### 整頁指標', '### 精確主攻詞', '### 詞群 Owner share')) {
    Assert-MarkdownSectionTableFormat -Markdown $md -Heading $markdownTableSection
  }
  $clusterHeadingStart = $html.IndexOf('<h2>詞群 Owner share</h2>', [StringComparison]::Ordinal)
  $clusterHeadingEnd = if ($clusterHeadingStart -ge 0) { $html.IndexOf('<h2>', $clusterHeadingStart + '<h2>詞群 Owner share</h2>'.Length, [StringComparison]::Ordinal) } else { -1 }
  $clusterHtmlSection = if ($clusterHeadingStart -ge 0 -and $clusterHeadingEnd -gt $clusterHeadingStart) { $html.Substring($clusterHeadingStart, $clusterHeadingEnd - $clusterHeadingStart) } else { '' }
  $multipleUrlsAreNotSearchCounts = $clusterHtmlSection -match '(合計.{0,12}不能.{0,12}當成獨立搜尋次數|不是獨立搜尋次數)'
  $lowShareIsNotProofOfCollision = $clusterHtmlSection -match '低占比.{0,12}(不等同|不代表|不必然|不一定).{0,12}已確認同詞互搶'
  Assert-True (($clusterHtmlSection -match 'Query × Page') -and ($clusterHtmlSection -match '多個 URL 可同時曝光') -and $multipleUrlsAreNotSearchCounts -and $lowShareIsNotProofOfCollision) 'Human HTML cluster-share section does not explain its Query × Page distribution scope and non-cannibalization caveat.'
  $metricScopesJson = ConvertTo-Json -InputObject $queue.metric_scopes -Depth 12 -Compress
  Assert-True (($metricScopesJson -match 'page_all_queries') -and ($metricScopesJson -match 'query.best|query-best|曝光最高|最高曝光') -and ($metricScopesJson -match 'cluster|詞群|Query × Page')) 'Queue metric_scopes does not explain legacy page metrics, query-best selection, and cluster URL distribution.'
  $missingIsNotZero = ($ai -match 'GSC 未列出') -and ($ai -match '≠\s*0|不等於\s*0|不代表\s*0')
  $pageAndVariantAreNotPrimary = ($ai -match '整頁|page_all_queries') -and ($ai -match '變體|variant') -and ($ai -match '代替|取代') -and ($ai -match '主詞|primary')
  $lowShareIsNotProofOfCollision = $ai -match '(?s)(低.{0,12}(share|占比|曝光).{0,30}(≠|不等於|不代表|不必然|不一定).{0,30}(互搶|cannibalization))|(互搶|cannibalization).{0,30}(不等於|不代表|不必然|不一定|不能只靠).{0,30}(share|占比|曝光)'
  Assert-True ($missingIsNotZero -and $pageAndVariantAreNotPrimary -and $lowShareIsNotProofOfCollision) 'AI instructions do not distinguish missing rows, exact primary metrics, and cluster-share warnings.'
  foreach ($window in @('7d','28d')) {
    $manifest = Read-Json -Path (Join-Path $runtimeRoot "latest\$window\weekly-sop-last-run.json")
    $period = @($queue.report_periods | Where-Object { $_.id -eq "rolling_$window" })[0]
    Assert-True ($null -ne $period -and [string]$period.start_date -eq [string]$manifest.start_date -and [string]$period.end_date -eq [string]$manifest.end_date -and [bool]$period.decision_ready -eq [bool]$manifest.decision_ready) 'Rolling period metadata does not match its source manifest.'
    $range = "$($manifest.start_date)~$($manifest.end_date)"
    foreach ($document in @($html, $md, $ai, $slim, $optionalAi)) {
      Assert-True (($document -match [regex]::Escape($range)) -and ($document -match '資料期間與合併規則') -and ($document -match '重複附件與重疊視窗不加總') -and ($document -notmatch 'INTEGRATED-REPORT-REVIEW')) 'A generated report depends on manual supplements for rolling dates or no-double-counting rules.'
    }
  }
  Assert-MarkdownSectionTableFormat -Markdown $md -Heading '## 資料期間與合併規則'
  Assert-True ([int]$state.total_rounds -eq 0) 'monitor_only state total_rounds is not 0.'
  Assert-True (@($state.prompt_files).Count -eq 0) 'monitor_only state contains prompt files.'
  Assert-True (@($queue.observations).Count -eq 4) 'monitor_only did not include every registry owner.'
  Assert-True ($null -ne $brandObservation -and $null -ne $productsObservation) 'Exact-keyword regression observations are missing from the fixture queue.'
  Assert-True ([string]$brandObservation.'28d query' -eq '測試品牌次詞' -and [int]$brandObservation.'28d query impressions' -eq 320) 'Compatibility query-best field did not continue selecting the highest-impression owner term.'
  $brandPage28d = $brandObservation.page_metrics.'28d'
  $brandPrimary28d = $brandObservation.primary_keyword_metrics.'28d'
  Assert-True ([string]$brandObservation.primary_keyword_metrics.query -eq '測試品牌主詞') 'Primary-keyword metrics are not bound to the registry primary keyword.'
  Assert-True ([string]$brandPage28d.status -eq 'available' -and [bool]$brandPage28d.row_found -and [int]$brandPage28d.impressions -eq 480 -and [string]$brandPage28d.scope -eq 'page_all_queries') 'All-query page metrics lost their explicit scope or fixture values.'
  Assert-True ([string]$brandPrimary28d.site.status -eq 'available' -and [bool]$brandPrimary28d.site.row_found -and [int]$brandPrimary28d.site.impressions -eq 68 -and [double]$brandPrimary28d.site.position -eq 7.2) 'Exact primary all-site metrics were replaced by a higher-impression variant.'
  Assert-True ([string]$brandPrimary28d.owner.status -eq 'available' -and [bool]$brandPrimary28d.owner.row_found -and [int]$brandPrimary28d.owner.impressions -eq 68) 'Exact primary owner-page metrics were not read from query × page rows.'
  $missingProductsPrimary28d = $productsObservation.primary_keyword_metrics.'28d'
  Assert-True ([int]$productsObservation.'28d impressions' -eq 92) 'Fixture did not retain all-query page metrics for the owner with a missing exact query row.'
  Assert-True ([string]$missingProductsPrimary28d.site.status -eq 'not_returned' -and -not [bool]$missingProductsPrimary28d.site.row_found -and $null -eq $missingProductsPrimary28d.site.impressions -and $null -eq $missingProductsPrimary28d.site.position) 'Missing exact primary query was converted to zero or filled with page-level metrics.'
  Assert-True ([string]$missingProductsPrimary28d.owner.status -eq 'available' -and [bool]$missingProductsPrimary28d.owner.row_found -and [int]$missingProductsPrimary28d.owner.impressions -eq 108 -and [int]$missingProductsPrimary28d.owner.clicks -eq 3) 'Exact primary owner-page rows, including a canonicalized legacy route, were not aggregated.'
  Assert-True ([Math]::Abs([double]$missingProductsPrimary28d.owner.ctr - (100.0 * 3 / 108)) -lt 0.01 -and [Math]::Abs([double]$missingProductsPrimary28d.owner.position - 11.59) -lt 0.01) 'Exact primary owner-page CTR or impression-weighted position was not recalculated from rows.'
  Assert-True (@($queue.monitoring_assets).Count -eq 2) 'monitor-only assets were not included in the queue output.'
  Assert-True ($queue.ctr_benchmark.method -eq 'non_overlapping_28d_segmented_ctr_lower_bound' -and -not [bool]$queue.ctr_benchmark.available -and @($queue.observations | Where-Object { $_.disposition -eq 'performance_actionable' }).Count -eq 0) 'No-valid-benchmark monitor cycle allowed performance_actionable.'
  $casesCompliance = @($queue.compliance | Where-Object { $_.cluster_id -eq 'fixture-cases' })[0]
  Assert-True ($null -ne $casesCompliance -and $casesCompliance.passed_checks -match '^\d+/11$' -and [string]$casesCompliance.output_path -eq 'out/cases/index.html' -and -not [string]::IsNullOrWhiteSpace([string]$casesCompliance.check_details)) 'per-page output HTML compliance is missing its output path, check counts, or evidence.'
  $reviewWindow = @($queue.review_windows | Where-Object { $_.cluster_id -eq 'product-P006' })[0]
  Assert-True ($null -ne $reviewWindow -and $reviewWindow.date_source -match 'source change date') 'review window is missing or does not disclose its source date.'
  Assert-True ($reviewWindow.pre_7d -notmatch [regex]::Escape([string]$reviewWindow.change_date) -and $reviewWindow.post_7d -notmatch [regex]::Escape([string]$reviewWindow.change_date)) 'review windows include the source change date and are not non-overlapping.'
  Assert-True (-not [string]::IsNullOrWhiteSpace([string]$reviewWindow.pre_change_28d)) 'review window is missing pre_change_28d.'
  Assert-True (-not [string]::IsNullOrWhiteSpace([string]$reviewWindow.pre_7d_metrics) -and -not [string]::IsNullOrWhiteSpace([string]$reviewWindow.post_7d_metrics)) 'review window does not expose metrics or a concrete data-unavailable reason.'
  Assert-True ([bool]$queue.diagnostics.sitewide_daily.available -and [int]$queue.diagnostics.sitewide_daily.day_count -eq 28) 'Sitewide daily diagnostic trend was not calculated from dated history.'
  Assert-True ([string]$queue.snapshot.'28d'.diagnostic_history.date.daily_history.start_date -eq [string]$queue.snapshot.'28d'.diagnostic_history.date.snapshot.start_date) 'Diagnostic daily history does not retain its dated range provenance.'
  Assert-True ([int]$casesObservation.'28d impressions' -eq 51) '/cases/ did not read 28d metrics from the full normalized baseline.'
  Assert-True ($casesObservation.cannibalization -eq $true -and [string]$casesObservation.'28d owner share' -eq '60.00%') 'Query × Page owner share/cannibalization was not calculated.'
  $productsObservation = @($queue.observations | Where-Object { $_.page -eq 'https://online.hong-sen.com/products/' })[0]
  Assert-True ([string]$productsObservation.'28d owner share' -eq '100.00%' -and [string]$productsObservation.'28d competing pages' -notmatch '/products/P006/') 'legacy P006 URL was not merged into the semantic canonical owner before aggregation.'
  Assert-True ([bool]$queue.query_delta.available -and [int]$queue.query_delta.raw_new_count -eq 2 -and [int]$queue.query_delta.raw_lost_count -eq 1 -and [int]$queue.query_delta.signal_count -eq 0 -and [int]$queue.query_delta.noise_count -eq 1) 'Query delta did not separate raw changes, confirmation-pending signals, and one-impression noise.'
  Assert-True (@($queue.query_delta.noise_queries | Where-Object { $_.query -eq '一次曝光雜訊' -and $_.signal_class -eq 'emerging_noise' }).Count -eq 1) 'One-impression query became a formal new-query signal.'
  Assert-True ($slim -notmatch 'PLEASE IMPLEMENT') 'monitor_only prompt contains PLEASE IMPLEMENT.'
  Assert-True ($slim -match 'PLEASE REVIEW THIS MONITORING LIST') 'monitor_only prompt is not an observation prompt.'
  Assert-True (@(Get-ChildItem -LiteralPath (Join-Path $runtimeRoot 'latest') -Filter 'seo-geo-action-plan.round-*.slim.ai.md' -File).Count -eq 0) 'monitor_only left a stale executable Round prompt.'

  Test-ObservationBackfillIsolation -SourceRuntimeRoot $runtimeRoot -LatestFinalDate $fixtureFinalDate
  Test-ObservationBackfillIsolation -SourceRuntimeRoot $runtimeRoot -LatestFinalDate $fixtureFinalDate -FinalWindowComplete

  Write-WindowManifest -Window '7d' -Confidence decision_ready -Bootstrapped $false -ShaCharacter '8'
  Write-WindowManifest -Window '28d' -Confidence decision_ready -Bootstrapped $false -ShaCharacter '3'

  # A sole P0/critical candidate stays outside the executable queue. It is
  # surfaced as an approval-only Optional Opportunity instead of silently
  # disappearing because the normal batch minimum is two pages.
  $singleReviewRegistryPath = Join-Path $runtimeRoot 'config\target-registry.json'
  $singleReviewRegistry = Read-Json -Path $singleReviewRegistryPath
  (@($singleReviewRegistry.targets | Where-Object { $_.clusterId -eq 'fixture-about' })[0]).lastChangedAt = $today
  Write-Json -Path $singleReviewRegistryPath -Value $singleReviewRegistry
  [void](Invoke-Generator)
  $singleReviewQueue = Read-Json -Path $queuePath
  $singleReviewState = Read-Json -Path $statePath
  $singleReviewCases = @($singleReviewQueue.observations | Where-Object { $_.page -eq 'https://online.hong-sen.com/cases/' })[0]
  $singleReviewOpportunity = @($singleReviewQueue.optional_opportunities | Where-Object { $_.page -eq 'https://online.hong-sen.com/cases/' -and $_.review_type -eq 'single_page_p0_review' })[0]
  $snakeAlignment = @($singleReviewQueue.alignment_candidates | Where-Object { $_.cluster_id -eq 'product-P003' })[0]
  $snakeAlignmentReview = @($singleReviewQueue.optional_opportunities | Where-Object { $_.page -eq 'https://online.hong-sen.com/products/s-fold-curtains/' -and $_.review_type -eq 'single_page_alignment_review' })[0]
  $singleReviewPrompt = Get-Content -LiteralPath (Join-Path $runtimeRoot 'latest\seo-geo-action-plan.optional.slim.ai.md') -Raw -Encoding UTF8
  Assert-True ([bool]$singleReviewQueue.ctr_benchmark.available -and @($singleReviewQueue.ctr_benchmark.bands).Count -eq 7 -and @($singleReviewQueue.ctr_benchmark.segments).Count -gt 1) 'Decision-ready CTR benchmark is missing valid segmented bands.'
  $expectedCtrWindow = "$($singleReviewQueue.snapshot.'28d'.diagnostic_history.date.snapshot.start_date)~$($singleReviewQueue.snapshot.'28d'.diagnostic_history.date.snapshot.end_date)"
  $invalidCtrCount = @($singleReviewQueue.ctr_benchmark.invalid_windows | Where-Object { $_.window_key -eq '2026-07-14~2026-08-10' }).Count
  Assert-True ([string]$singleReviewQueue.ctr_benchmark.selected_window -eq $expectedCtrWindow -and $invalidCtrCount -eq 1) "Invalid CTR selection/history contract failed: selected=$($singleReviewQueue.ctr_benchmark.selected_window), expected=$expectedCtrWindow, invalid_count=$invalidCtrCount."
  Assert-True ($singleReviewQueue.status -eq 'observation_only' -and [int]$singleReviewState.total_rounds -eq 0) 'single P0 review unexpectedly created an executable Round.'
  $uiObservation = Get-UiProjectionFixture
  Assert-True ([bool]$uiObservation.consistent -and [string]$uiObservation.state -eq 'observation_only' -and [string]$uiObservation.primary_action.id -eq 'GENERATE_PLAN' -and [bool]$uiObservation.primary_action.enabled) 'Observation-only UI projection changed the primary action.'
  Assert-True (-not [bool]$uiObservation.actions.AUTO_DEPLOY.enabled -and -not [bool]$uiObservation.actions.ADVANCE_ROUND.enabled) 'Observation-only UI projection enabled deployment or Round advancement.'
  Assert-True ($null -ne $singleReviewOpportunity -and [bool]$singleReviewOpportunity.requires_user_approval) 'single P0 review was not retained with its explicit approval guard.'
  Assert-True ($null -ne $snakeAlignment -and [double]$snakeAlignment.owner_share -eq 5.45 -and [int]$snakeAlignment.cluster_impressions -eq 165 -and [string]$snakeAlignment.disposition -eq 'alignment_review') 'Snake-curtain owner-share alignment fixture did not become an eligible review signal.'
  Assert-True ($null -ne $snakeAlignmentReview -and [bool]$snakeAlignmentReview.requires_user_approval) 'Single owner-share alignment candidate did not use the single_page_review approval flow.'
  Assert-True ($singleReviewCases.disposition -eq 'single_page_review') 'single P0 candidate observation did not report single_page_review.'
  Assert-True ($singleReviewPrompt -match 'single_page_p0_review' -and $singleReviewPrompt -match '不得修改 source') 'single P0 Optional prompt does not enforce the approval boundary.'

  $approvalResult = Invoke-PwshFile -File $singlePageApprovalWriter -ScriptArgs @(
    '-RuntimeRoot', $runtimeRoot,
    '-RepoRoot', $runtimeRoot,
    '-Page', 'https://online.hong-sen.com/cases/',
    '-ApprovedBy', 'SEO/GEO fixture approver',
    '-Reason', 'Explicit fixture approval for the sole P0 owner.'
  )
  Assert-True ($approvalResult.ExitCode -eq 0) ('single-page approval writer failed: ' + ($approvalResult.Output -join ' '))
  $approvedQueue = Read-Json -Path $queuePath
  $approvedState = Read-Json -Path $statePath
  $approvalReceipt = Read-Json -Path (Join-Path $runtimeRoot 'latest\seo-geo-single-page-approval.json')
  $approvedPrompt = Get-Content -LiteralPath (Join-Path $runtimeRoot 'latest\seo-geo-action-plan.round-1.slim.ai.md') -Raw -Encoding UTF8
  Assert-True ($approvedQueue.status -eq 'active' -and @($approvedQueue.rounds).Count -eq 1 -and [int]$approvedQueue.rounds[0].targetCount -eq 1) 'explicit single-page approval did not create exactly one executable Round.'
  Assert-True ($approvedState.status -eq 'active' -and [int]$approvedState.active_round -eq 1 -and [int]$approvedState.total_rounds -eq 1) 'single-page approval did not activate queue state.'
  Assert-True ([string]$approvalReceipt.status -eq 'approved' -and [string]$approvalReceipt.page -eq 'https://online.hong-sen.com/cases/' -and -not [string]::IsNullOrWhiteSpace([string]$approvalReceipt.action_fingerprint)) 'single-page approval receipt is missing its page/action binding.'
  Assert-True ($approvedPrompt -match 'PLEASE IMPLEMENT THIS PLAN' -and $approvedPrompt -match [regex]::Escape([string]$approvedQueue.queue_id)) 'single-page approval did not create a queue-bound executable prompt.'

  $approvedProjectionResult = Invoke-PwshFile -File $projectionWriter -ScriptArgs @('-RuntimeRoot', $runtimeRoot)
  Assert-True ($approvedProjectionResult.ExitCode -eq 0) ('effective workflow projection failed after single-page approval: ' + ($approvedProjectionResult.Output -join ' '))
  $approvedProjection = Convert-CommandJson -Output $approvedProjectionResult.Output -Label 'effective workflow projection after single-page approval'
  Assert-True ([bool]$approvedProjection.consistency.valid -and [string]$approvedProjection.strategy_snapshot.status -eq 'observation_only' -and [bool]$approvedProjection.approved_queue.approved_override -and [string]$approvedProjection.effective.status -eq 'active' -and [string]$approvedProjection.effective.source -eq 'approved_queue') 'effective workflow projection did not distinguish immutable observation snapshot from approved active Round.'
  $uiActive = Get-UiProjectionFixture
  Assert-True ([bool]$uiActive.consistent -and [string]$uiActive.primary_action.id -eq 'COPY_ROUND_PROMPT' -and [bool]$uiActive.primary_action.enabled -and -not [bool]$uiActive.actions.ADVANCE_ROUND.enabled) 'Active UI projection did not require a validation receipt before advancing.'
  $missingGateScripts = Join-Path $testRoot 'missing-round-gate-scripts'
  Ensure-Dir -Path $missingGateScripts
  foreach ($scriptName in @('get-seo-geo-ui-projection.ps1', 'get-seo-geo-effective-workflow.ps1', 'check-seo-geo-queue-provenance.ps1')) {
    Copy-Item -LiteralPath (Join-Path $PSScriptRoot $scriptName) -Destination (Join-Path $missingGateScripts $scriptName)
  }
  $missingGateResult = Invoke-PwshFile -File (Join-Path $missingGateScripts 'get-seo-geo-ui-projection.ps1') -ScriptArgs @('-RuntimeRoot', $runtimeRoot, '-RepoRoot', $runtimeRoot)
  $uiMissingGate = Convert-CommandJson -Output $missingGateResult.Output -Label 'UI projection without Round gate'
  Assert-True ($missingGateResult.ExitCode -eq 0 -and -not [bool]$uiMissingGate.consistent -and [string]$uiMissingGate.primary_action.id -eq 'NONE' -and -not [bool]$uiMissingGate.panels.queue.receipt_gate.passed -and (@($uiMissingGate.panels.data_trust.reasons) -join ' ') -match 'round_gate_failed') 'Missing Round gate did not fail closed.'

  $planSnapshotPath = Join-Path $runtimeRoot 'latest\seo-geo-action-plan.json'
  $planSnapshotBeforeMismatch = Get-Content -LiteralPath $planSnapshotPath -Raw -Encoding UTF8
  $badPlanSnapshot = $planSnapshotBeforeMismatch | ConvertFrom-Json
  $badPlanSnapshot.queue_id = 'different-queue'
  Write-Json -Path $planSnapshotPath -Value $badPlanSnapshot
  $mismatchProjectionResult = Invoke-PwshFile -File $projectionWriter -ScriptArgs @('-RuntimeRoot', $runtimeRoot)
  Assert-True ($mismatchProjectionResult.ExitCode -eq 0) 'effective workflow projection did not return a safe result for plan/queue mismatch.'
  $mismatchProjection = Convert-CommandJson -Output $mismatchProjectionResult.Output -Label 'effective workflow projection after identity mismatch'
  Assert-True (-not [bool]$mismatchProjection.consistency.valid -and @($mismatchProjection.consistency.reasons) -contains 'plan_queue_identity_mismatch' -and [string]$mismatchProjection.effective.status -eq 'inconsistent') 'effective workflow projection did not block plan/queue identity mismatch.'
  $uiMismatch = Get-UiProjectionFixture
  Assert-True (-not [bool]$uiMismatch.consistent -and [string]$uiMismatch.primary_action.id -eq 'NONE' -and -not [bool]$uiMismatch.primary_action.enabled -and -not [bool]$uiMismatch.actions.AUTO_DEPLOY.enabled) 'Inconsistent UI projection did not block the primary action and auto-deploy.'
  [System.IO.File]::WriteAllText($planSnapshotPath, $planSnapshotBeforeMismatch, $utf8NoBom)

  (@($singleReviewRegistry.targets | Where-Object { $_.clusterId -eq 'fixture-about' })[0]).lastChangedAt = $null
  Write-Json -Path $singleReviewRegistryPath -Value $singleReviewRegistry
  [void](Invoke-Generator)
  $queue = Read-Json -Path $queuePath
  $state = Read-Json -Path $statePath
  $firstFingerprints = @($queue.rounds[0].actions | Sort-Object action_id | ForEach-Object { $_.fingerprint })
  $productsObservation = @($queue.observations | Where-Object { $_.page -eq 'https://online.hong-sen.com/products/' })[0]

  Assert-True ($queue.status -eq 'active') 'decision-ready fixture did not generate an active queue.'
  Assert-True (@($queue.rounds).Count -eq 1) 'decision-ready fixture should generate exactly one dynamic Round.'
  Assert-True ([int]$queue.rounds[0].targetCount -eq 2) 'dynamic Round did not contain the two eligible owners.'
  Assert-True ($productsObservation.disposition -eq 'registry_cooldown') 'registry lastChangedAt did not enforce the 28d cooldown.'
  Assert-True ([int]$queue.schema_version -eq 2 -and [int]$state.schema_version -eq 2) 'queue/state schema_version is not 2.'
  Assert-True ([string]$queue.snapshot.'7d'.sha256 -eq ('8' * 64)) 'queue is not bound to the 7d input SHA.'
  Assert-True ([string]$queue.snapshot.'28d'.sha256 -eq ('3' * 64)) 'queue is not bound to the 28d input SHA.'
  Assert-True (-not [string]::IsNullOrWhiteSpace([string]$queue.snapshot.'28d'.query_page_baseline.sha256)) 'queue is not bound to the 28d Query × Page SHA.'
  Assert-True ([int]$queue.registry.version -eq 9 -and -not [string]::IsNullOrWhiteSpace([string]$queue.registry.sha256)) 'queue is not bound to registry version/SHA.'
  Assert-True (-not [string]::IsNullOrWhiteSpace([string]$queue.source_fingerprint)) 'queue source fingerprint is missing.'
  Assert-True (@($queue.source_files).Count -gt 0) 'queue source_files binding is missing.'
  Assert-True ([string]$queue.action_history.path -eq 'history/curtain-online/seo-geo-action-history.json') 'action history path is not stable and relative.'

  Write-Baselines -Window '28d' -CasesImpressions 88 -CasesCtr 5 -CasesPosition 2
  Write-WindowManifest -Window '28d' -Confidence decision_ready -Bootstrapped $false -ShaCharacter '4'
  [void](Invoke-Generator)
  $queue = Read-Json -Path $queuePath
  $state = Read-Json -Path $statePath
  $secondFingerprints = @($queue.rounds[0].actions | Sort-Object action_id | ForEach-Object { $_.fingerprint })
  $casesObservation = @($queue.observations | Where-Object { $_.page -eq 'https://online.hong-sen.com/cases/' })[0]
  Assert-True ([int]$casesObservation.'28d impressions' -eq 88) 'updated /cases/ full-baseline metric was not consumed.'
  Assert-True (($firstFingerprints -join '|') -ceq ($secondFingerprints -join '|')) 'action fingerprints changed only because metrics/actionType changed.'

  $cycleKeyBefore = [string]$queue.cycle_key
  $queueIdBefore = [string]$queue.queue_id
  $actionIdsBefore = @($queue.rounds[0].action_ids)
  [void](Invoke-Generator)
  $queueRepeat = Read-Json -Path $queuePath
  Assert-True ([string]$queueRepeat.cycle_key -ceq $cycleKeyBefore) 'identical provenance produced a different cycle_key.'
  Assert-True ([string]$queueRepeat.queue_id -ceq $queueIdBefore) 'identical provenance produced a different queue_id.'
  Assert-True ((@($queueRepeat.rounds[0].action_ids) -join '|') -ceq ($actionIdsBefore -join '|')) 'identical provenance produced different action_ids.'

  $validationResults = @($state.rounds[0].required_validations | ForEach-Object {
    [ordered]@{ command = [string]$_; status = 'passed'; exit_code = 0 }
  }) | ConvertTo-Json -Depth 5 -Compress
  $receiptResult = Invoke-PwshFile -File $receiptWriter -ScriptArgs @(
    '-RuntimeRoot', $runtimeRoot,
    '-QueueId', $queueIdBefore,
    '-CycleKey', $cycleKeyBefore,
    '-Round', '1',
    '-Result', 'no_change_verified',
    '-ValidationResultsJson', $validationResults
  )
  if ($receiptResult.ExitCode -ne 0) {
    $receiptResult.Output | ForEach-Object { Write-Host $_ }
  }
  Assert-True ($receiptResult.ExitCode -eq 0) 'matching receipt was rejected.'
  $uiValidatedRound = Get-UiProjectionFixture
  Assert-True ([bool]$uiValidatedRound.consistent -and [string]$uiValidatedRound.primary_action.id -eq 'ADVANCE_ROUND' -and [bool]$uiValidatedRound.primary_action.enabled) 'Validated active Round UI projection did not select advancement.'
  Assert-True ([bool]$uiValidatedRound.panels.queue.receipt_gate.passed) 'Validated active Round queue panel did not expose the passing receipt gate.'
  $fixtureReceiptPath = Join-Path $runtimeRoot 'latest\seo-geo-validation-receipt.json'
  $fixtureReceiptOriginal = Get-Content -LiteralPath $fixtureReceiptPath -Raw -Encoding UTF8
  try {
    foreach ($defect in @('round', 'action_ids', 'fingerprint', 'source_before', 'source_after', 'registry', 'snapshot', 'validation')) {
      $badReceipt = $fixtureReceiptOriginal | ConvertFrom-Json
      switch ($defect) {
        'round' { $badReceipt.round = 99 }
        'action_ids' { $badReceipt.action_ids = @('wrong-action') }
        'fingerprint' { $badReceipt.action_fingerprints[0].fingerprint = ('f' * 64) }
        'source_before' { $badReceipt.source_fingerprint_before = ('f' * 64) }
        'source_after' { $badReceipt.source_fingerprint_after = ('f' * 64) }
        'registry' { $badReceipt.registry.sha256 = ('f' * 64) }
        'snapshot' { $badReceipt.snapshot.'7d'.sha256 = ('f' * 64) }
        'validation' { $badReceipt.validation_results[0].status = 'failed' }
      }
      Write-Json -Path $fixtureReceiptPath -Value $badReceipt
      $uiBadReceipt = Get-UiProjectionFixture
      Assert-True (-not [bool]$uiBadReceipt.panels.queue.receipt_gate.passed -and [string]$uiBadReceipt.primary_action.id -ne 'ADVANCE_ROUND') "Invalid $defect receipt enabled Round advancement."
    }
  } finally {
    Write-Utf8NoBom -Path $fixtureReceiptPath -Text $fixtureReceiptOriginal
  }

  $receiptPath = Join-Path $runtimeRoot 'latest\seo-geo-validation-receipt.json'
  $receipt = Read-Json -Path $receiptPath
  Assert-True (@($receipt.action_fingerprints).Count -eq $actionIdsBefore.Count) 'receipt action_fingerprints do not cover the Round.'
  Assert-True ([string]$receipt.source_fingerprint_before -ceq [string]$receipt.source_fingerprint_after) 'no_change_verified receipt changed the source fingerprint.'
  Assert-True ([string]$receipt.registry.sha256 -ceq [string]$queue.registry.sha256) 'receipt registry binding does not match the queue.'
  Assert-True ([string]$receipt.snapshot.'28d'.sha256 -ceq [string]$queue.snapshot.'28d'.sha256) 'receipt 28d snapshot binding does not match the queue.'

  $receiptHashBefore = (Get-FileHash -LiteralPath $receiptPath -Algorithm SHA256).Hash
  $badReceiptResult = Invoke-PwshFile -File $receiptWriter -ScriptArgs @(
    '-RuntimeRoot', $runtimeRoot,
    '-QueueId', $queueIdBefore,
    '-CycleKey', 'seo-geo-v2-intentional-mismatch',
    '-Round', '1',
    '-Result', 'no_change_verified',
    '-ValidationResultsJson', $validationResults
  )
  Assert-True ($badReceiptResult.ExitCode -ne 0) 'mismatched receipt unexpectedly succeeded.'
  $receiptHashAfter = (Get-FileHash -LiteralPath $receiptPath -Algorithm SHA256).Hash
  Assert-True ($receiptHashBefore -ceq $receiptHashAfter) 'mismatched receipt overwrote the valid receipt.'

  Assert-True (Test-Path -LiteralPath $workflowWriter -PathType Leaf) 'unified workflow transition writer is missing.'
  Assert-True ([string]$state.precondition_gates.data_validated.status -eq 'passed') 'decision-ready queue did not persist data_validated precondition gate.'
  Assert-True ([string]$state.precondition_gates.strategy_approved.status -eq 'passed') 'executable queue did not persist strategy_approved precondition gate.'
  $stateHashBeforeWorkflowRollback = (Get-FileHash -LiteralPath $statePath -Algorithm SHA256).Hash
  $historyPath = Join-Path $runtimeRoot 'history\curtain-online\seo-geo-action-history.json'
  $registryPath = Join-Path $runtimeRoot 'config\target-registry.json'
  $historyHashBeforeWorkflowRollback = (Get-FileHash -LiteralPath $historyPath -Algorithm SHA256).Hash
  $rollbackResult = Invoke-PwshFile -File $workflowWriter -ScriptArgs @('-RuntimeRoot', $runtimeRoot, '-Transition', 'round_validated', '-OperationId', 'fixture-round-rollback', '-TestFailAfterExecutor')
  Assert-True ($rollbackResult.ExitCode -ne 0) 'workflow writer test-failure injection unexpectedly committed.'
  Assert-True ((Get-FileHash -LiteralPath $statePath -Algorithm SHA256).Hash -ceq $stateHashBeforeWorkflowRollback) 'workflow rollback did not restore queue state.'
  Assert-True ((Get-FileHash -LiteralPath $historyPath -Algorithm SHA256).Hash -ceq $historyHashBeforeWorkflowRollback) 'workflow rollback did not restore action history.'
  $journal = Read-Json -Path (Join-Path $runtimeRoot 'latest\seo-geo-workflow-recovery-journal.json')
  Assert-True ([string]$journal.status -eq 'recovered') 'workflow rollback did not leave a recovered journal.'
  $workflowResult = Invoke-PwshFile -File $workflowWriter -ScriptArgs @('-RuntimeRoot', $runtimeRoot, '-Transition', 'round_validated', '-OperationId', 'fixture-round-commit')
  if ($workflowResult.ExitCode -ne 0) { $workflowResult.Output | ForEach-Object { Write-Host $_ } }
  Assert-True ($workflowResult.ExitCode -eq 0) 'unified workflow writer rejected a valid Round transition.'
  $state = Read-Json -Path $statePath
  Assert-True ([string]$state.status -eq 'awaiting_implemented_receipt') 'unified workflow writer did not advance the final Round to awaiting_implemented_receipt.'
  # The transaction's durable after-state must remain receipt-bound: source and
  # registry fingerprints come from the receipt, while action history records each
  # completed action before the lifecycle state is advanced.
  $historyAfterRound = Read-Json -Path $historyPath
  Assert-True (@($historyAfterRound.actions | Where-Object { $_.queue_id -eq $queueIdBefore -and $_.cycle_key -eq $cycleKeyBefore -and $_.round -eq 1 }).Count -eq $actionIdsBefore.Count) 'Round transaction did not persist one queue-bound history row per action.'
  Assert-True (@($historyAfterRound.actions | Where-Object { $_.queue_id -eq $queueIdBefore -and $_.result -eq 'no_change_verified' -and $_.fingerprint -in @($receipt.action_fingerprints | ForEach-Object { $_.fingerprint }) }).Count -eq $actionIdsBefore.Count) 'Round history after-state is not bound to the validated receipt fingerprints.'
  Assert-True ((Get-FileHash -LiteralPath $registryPath -Algorithm SHA256).Hash.ToLowerInvariant() -ceq [string]$receipt.registry.sha256) 'Round transaction changed registry despite a no_change_verified receipt.'
  Assert-True ([string]$receipt.source_fingerprint_after -ceq [string]$queue.source_fingerprint) 'Round after-state source fingerprint no longer matches the queue-bound source.'
  $stateHashAfterWorkflowCommit = (Get-FileHash -LiteralPath $statePath -Algorithm SHA256).Hash
  $workflowRetry = Invoke-PwshFile -File $workflowWriter -ScriptArgs @('-RuntimeRoot', $runtimeRoot, '-Transition', 'round_validated', '-OperationId', 'fixture-round-commit')
  Assert-True ($workflowRetry.ExitCode -eq 0 -and (($workflowRetry.Output -join "`n") -match '"idempotent":true')) 'workflow writer did not return idempotent success for a repeated operation.'
  Assert-True ((Get-FileHash -LiteralPath $statePath -Algorithm SHA256).Hash -ceq $stateHashAfterWorkflowCommit) 'idempotent workflow retry changed queue state.'

  $queueSha = (Get-FileHash -LiteralPath $queuePath -Algorithm SHA256).Hash.ToLowerInvariant()
  $queueBinding = [ordered]@{ queue_id = $queueIdBefore; cycle_key = $cycleKeyBefore; queue_sha256 = $queueSha; action_ids = $actionIdsBefore }
  $badImplementedReceipt = Invoke-PwshFile -File $lifecycleWriter -ScriptArgs @('-RuntimeRoot', $runtimeRoot, '-Stage', 'implemented', '-EvidenceJson', '{"implemented_at":"2026-08-12T00:00:00Z"}')
  Assert-True ($badImplementedReceipt.ExitCode -ne 0) 'implemented lifecycle receipt accepted unbound evidence.'
  $implementedReceipt = Invoke-PwshFile -File $lifecycleNext -ScriptArgs @('-RuntimeRoot', $runtimeRoot, '-Mode', 'Advance')
  if ($implementedReceipt.ExitCode -ne 0) { $implementedReceipt.Output | ForEach-Object { Write-Host $_ } }
  Assert-True ($implementedReceipt.ExitCode -eq 0) 'smart lifecycle controller rejected implemented after queue-bound validation.'
  $state = Read-Json -Path $statePath
  Assert-True ($state.status -eq 'implemented' -and -not [string]::IsNullOrWhiteSpace([string]$state.implemented_at)) 'implemented lifecycle stage was not persisted.'
  $localLifecycleReceipt = Invoke-PwshFile -File $lifecycleNext -ScriptArgs @('-RuntimeRoot', $runtimeRoot, '-Mode', 'Advance')
  Assert-True ($localLifecycleReceipt.ExitCode -eq 0) 'smart lifecycle controller rejected local_validated after implemented.'
  $state = Read-Json -Path $statePath
  Assert-True ($state.status -eq 'local_validated' -and -not [string]::IsNullOrWhiteSpace([string]$state.local_validated_at)) 'local_validated lifecycle stage was not persisted.'
  $uiLocalValidated = Get-UiProjectionFixture
  Assert-True ([bool]$uiLocalValidated.consistent -and [string]$uiLocalValidated.primary_action.id -eq 'AUTO_DEPLOY' -and -not [bool]$uiLocalValidated.primary_action.enabled) 'Local-validated fixture must block auto-deploy without a ready deploy plan.'
  # Build a self-contained deploy candidate under the temporary fixture only.
  # Inspect commands must not connect to FTP or write a deployment journal.
  Copy-Item -LiteralPath (Join-Path $runtimeRoot 'src') -Destination (Join-Path $testRoot 'src') -Recurse
  foreach ($target in @($queue.rounds | ForEach-Object { @($_.targets) })) {
    $route = ([uri][string]$target).AbsolutePath.Trim('/')
    $relativeOutput = if ($route) { "$route/index.html" } else { 'index.html' }
    Write-Utf8NoBom -Path (Join-Path (Join-Path $testRoot 'out') $relativeOutput.Replace('/', '\')) -Text 'isolated deploy fixture'
  }
  $ftpEnvironment = @{}
  foreach ($name in @('FTP_HOST', 'FTP_REMOTE_DIR', 'FTP_USER', 'FTP_PASS', 'FTP_PASSWORD')) {
    $ftpEnvironment[$name] = [Environment]::GetEnvironmentVariable($name, 'Process')
  }
  $fixtureManifestPath = Join-Path $runtimeRoot 'latest\7d\weekly-sop-last-run.json'
  $fixtureManifestOriginal = Get-Content -LiteralPath $fixtureManifestPath -Raw -Encoding UTF8
  try {
    [Environment]::SetEnvironmentVariable('FTP_HOST', 'ftp.hong-sen.com', 'Process')
    [Environment]::SetEnvironmentVariable('FTP_REMOTE_DIR', 'online.hong-sen.com', 'Process')
    [Environment]::SetEnvironmentVariable('FTP_USER', 'fixture-user', 'Process')
    [Environment]::SetEnvironmentVariable('FTP_PASS', 'fixture-pass', 'Process')
    [Environment]::SetEnvironmentVariable('FTP_PASSWORD', $null, 'Process')
    $freshProvenance = Invoke-PwshFile -File $provenanceChecker -ScriptArgs @('-RuntimeRoot', $runtimeRoot)
    Assert-True ($freshProvenance.ExitCode -eq 0 -and -not [bool](Convert-CommandJson -Output $freshProvenance.Output -Label 'fresh deploy provenance').stale) 'Fresh isolated deploy fixture has stale provenance.'
    $freshPlanResult = Invoke-PwshFile -File $deployPlanWriter -ScriptArgs @('-RuntimeRoot', $runtimeRoot, '-Mode', 'Inspect')
    Assert-True ($freshPlanResult.ExitCode -eq 0 -and [string](Convert-CommandJson -Output $freshPlanResult.Output -Label 'fresh deploy plan').status -eq 'ready') 'Fresh isolated deploy plan did not pass preflight.'
    $freshDeployUi = Get-UiProjectionFixture
    Assert-True ([bool]$freshDeployUi.actions.AUTO_DEPLOY.enabled) 'Fresh isolated deploy projection was not enabled.'

    Write-Utf8NoBom -Path $fixtureManifestPath -Text ($fixtureManifestOriginal + "`n")
    $staleProvenance = Invoke-PwshFile -File $provenanceChecker -ScriptArgs @('-RuntimeRoot', $runtimeRoot)
    Assert-True ($staleProvenance.ExitCode -eq 0 -and [bool](Convert-CommandJson -Output $staleProvenance.Output -Label 'stale deploy provenance').stale) 'Modified snapshot fixture was not stale.'
    $stalePlanResult = Invoke-PwshFile -File $deployPlanWriter -ScriptArgs @('-RuntimeRoot', $runtimeRoot, '-Mode', 'Inspect')
    $stalePlan = Convert-CommandJson -Output $stalePlanResult.Output -Label 'stale deploy plan'
    Assert-True ($stalePlanResult.ExitCode -eq 0 -and [string]$stalePlan.status -eq 'blocked' -and -not [bool]$stalePlan.preflight.passed -and (@($stalePlan.preflight.reasons) -join ' ') -match 'snapshot_7d_manifest_sha_mismatch') 'Deploy plan did not block stale queue provenance.'
    $staleDeployUi = Get-UiProjectionFixture
    Assert-True (-not [bool]$staleDeployUi.consistent -and -not [bool]$staleDeployUi.actions.AUTO_DEPLOY.enabled) 'Stale queue provenance did not disable the UI auto-deploy action.'
    $staleAutoResult = Invoke-PwshFile -File $autoDeployWriter -ScriptArgs @('-RuntimeRoot', $runtimeRoot, '-Mode', 'Inspect')
    if ($staleAutoResult.ExitCode -eq 0) {
      Assert-True (-not [bool](Convert-CommandJson -Output $staleAutoResult.Output -Label 'stale auto-deploy inspection').ready) 'Auto-deploy inspection accepted stale queue provenance.'
    } else {
      Assert-True (($staleAutoResult.Output -join ' ') -match 'workflow consistency is not valid') 'Auto-deploy inspection failed for an unexpected reason.'
    }
    Assert-True (-not (Test-Path -LiteralPath (Join-Path $runtimeRoot 'latest\seo-geo-autodeploy-journal.json'))) 'Inspect must not start auto-deployment.'
  } finally {
    Write-Utf8NoBom -Path $fixtureManifestPath -Text $fixtureManifestOriginal
    foreach ($name in $ftpEnvironment.Keys) { [Environment]::SetEnvironmentVariable($name, $ftpEnvironment[$name], 'Process') }
  }
  $deploymentManifestPath = Join-Path $runtimeRoot 'latest\seo-geo-deployment-manifest.json'
  $deploymentManifest = [ordered]@{
    schema_version = 1; status = 'success'; dry_run = $false; target_host = 'online.hong-sen.com'; deploy_mode = 'quick'
    generated_at = (Get-Date).AddMinutes(-1).ToUniversalTime().ToString('o'); completed_at = (Get-Date).ToUniversalTime().ToString('o')
    deployment_context = [ordered]@{ queue_id = $queueBinding.queue_id; cycle_key = $queueBinding.cycle_key; action_ids = $queueBinding.action_ids }
    deploy_plan = $null
    summary = [ordered]@{ selected = 3; uploaded = 2; skipped = 1; failed = 0 }
    files = @(
      [ordered]@{ relative_path = 'products/cases/index.html'; size_bytes = 100; sha256 = ('a' * 64); result = 'uploaded' },
      [ordered]@{ relative_path = 'sitemap.xml'; size_bytes = 100; sha256 = ('b' * 64); result = 'uploaded' },
      [ordered]@{ relative_path = 'robots.txt'; size_bytes = 100; sha256 = ('c' * 64); result = 'skipped_same_hash'; remote_sha256_before = ('c' * 64) }
    )
  }
  Write-Json -Path $deploymentManifestPath -Value $deploymentManifest
  $badDeployEvidence = [ordered]@{ queue_id = $queueBinding.queue_id; cycle_key = $queueBinding.cycle_key; queue_sha256 = $queueBinding.queue_sha256; action_ids = $queueBinding.action_ids; validation_receipt_sha256 = (Get-FileHash -LiteralPath $receiptPath -Algorithm SHA256).Hash.ToLowerInvariant(); uploaded = 2; skipped = 1; failed = 0; command = 'deploy fixture'; completed_at = (Get-Date).ToString('o'); target_host = 'online.hong-sen.com' } | ConvertTo-Json -Depth 5 -Compress
  $badDeployReceipt = Invoke-PwshFile -File $lifecycleWriter -ScriptArgs @('-RuntimeRoot', $runtimeRoot, '-Stage', 'deployed', '-EvidenceJson', $badDeployEvidence)
  Assert-True ($badDeployReceipt.ExitCode -ne 0) 'deployed lifecycle receipt accepted evidence without a complete deployment manifest.'
  $badDeployShaEvidence = [ordered]@{ queue_id = $queueBinding.queue_id; cycle_key = $queueBinding.cycle_key; queue_sha256 = $queueBinding.queue_sha256; action_ids = $queueBinding.action_ids; validation_receipt_sha256 = (Get-FileHash -LiteralPath $receiptPath -Algorithm SHA256).Hash.ToLowerInvariant(); uploaded = 2; skipped = 1; failed = 0; command = 'deploy fixture'; completed_at = (Get-Date).ToString('o'); target_host = 'online.hong-sen.com'; deployment_manifest = [ordered]@{ path = 'latest/seo-geo-deployment-manifest.json'; sha256 = ('0' * 64) } } | ConvertTo-Json -Depth 8 -Compress
  $badDeployShaReceipt = Invoke-PwshFile -File $lifecycleWriter -ScriptArgs @('-RuntimeRoot', $runtimeRoot, '-Stage', 'deployed', '-EvidenceJson', $badDeployShaEvidence)
  Assert-True ($badDeployShaReceipt.ExitCode -ne 0) 'deployed lifecycle receipt accepted a deployment manifest SHA mismatch.'
  Assert-True ((Read-Json -Path $statePath).status -eq 'local_validated') 'deployment manifest SHA mismatch advanced lifecycle state.'
  foreach ($unsafeSkip in @('skipped_same_size', 'skipped_same_hash')) {
    $deploymentManifest.files[2].result = $unsafeSkip
    $deploymentManifest.files[2].remote_sha256_before = ('d' * 64)
    Write-Json -Path $deploymentManifestPath -Value $deploymentManifest
    $unsafeDeployEvidence = [ordered]@{ queue_id = $queueBinding.queue_id; cycle_key = $queueBinding.cycle_key; queue_sha256 = $queueBinding.queue_sha256; action_ids = $queueBinding.action_ids; validation_receipt_sha256 = (Get-FileHash -LiteralPath $receiptPath -Algorithm SHA256).Hash.ToLowerInvariant(); uploaded = 2; skipped = 1; failed = 0; command = 'deploy fixture'; completed_at = (Get-Date).ToString('o'); target_host = 'online.hong-sen.com'; deployment_manifest = [ordered]@{ path = 'latest/seo-geo-deployment-manifest.json'; sha256 = (Get-FileHash -LiteralPath $deploymentManifestPath -Algorithm SHA256).Hash.ToLowerInvariant() } } | ConvertTo-Json -Depth 8 -Compress
    $unsafeDeployReceipt = Invoke-PwshFile -File $lifecycleWriter -ScriptArgs @('-RuntimeRoot', $runtimeRoot, '-Stage', 'deployed', '-EvidenceJson', $unsafeDeployEvidence)
    Assert-True ($unsafeDeployReceipt.ExitCode -ne 0) "deployed lifecycle receipt accepted unsafe skip: $unsafeSkip"
    Assert-True ((Read-Json -Path $statePath).status -eq 'local_validated') 'unsafe skip advanced lifecycle state.'
    $unsafeInspection = Invoke-PwshFile -File $lifecycleNext -ScriptArgs @('-RuntimeRoot', $runtimeRoot, '-Mode', 'Inspect')
    Assert-True ($unsafeInspection.ExitCode -eq 0 -and -not [bool](Convert-CommandJson -Output $unsafeInspection.Output -Label 'Unsafe deployment inspection').ready) 'lifecycle inspection marked an unsafe skip ready.'
  }
  $deploymentManifest.files[2].result = 'skipped_same_hash'
  $deploymentManifest.files[2].remote_sha256_before = ('c' * 64)
  Write-Json -Path $deploymentManifestPath -Value $deploymentManifest
  $deployReceipt = Invoke-PwshFile -File $lifecycleNext -ScriptArgs @('-RuntimeRoot', $runtimeRoot, '-Mode', 'Advance')
  if ($deployReceipt.ExitCode -ne 0) { $deployReceipt.Output | ForEach-Object { Write-Host $_ } }
  Assert-True ($deployReceipt.ExitCode -eq 0) 'deployed lifecycle receipt was rejected after local validation.'
  $state = Read-Json -Path $statePath
  Assert-True ($state.status -eq 'deployed' -and -not [string]::IsNullOrWhiteSpace([string]$state.deployed_at)) 'deployed lifecycle stage was not persisted.'
  $uiDeployed = Get-UiProjectionFixture
  Assert-True ([bool]$uiDeployed.consistent -and [string]$uiDeployed.primary_action.id -eq 'LIVE_VERIFY' -and [bool]$uiDeployed.primary_action.enabled -and -not [bool]$uiDeployed.actions.AUTO_DEPLOY.enabled) 'Deployed UI projection did not select live verification.'
  $liveManifestPath = Join-Path $runtimeRoot 'latest\seo-geo-live-verification.json'
  $pageChecks = @('http','title','meta_description','h1','canonical','faq_parity','json_ld','internal_links','cta','robots','sitemap') | ForEach-Object { [ordered]@{ name = $_; passed = $true; evidence = "fixture $_ passed" } }
  Write-Json -Path $liveManifestPath -Value ([ordered]@{
    schema_version = 1; status = 'passed'; scope = 'queue_targets'; host = 'online.hong-sen.com'; queue_id = $queueBinding.queue_id; cycle_key = $queueBinding.cycle_key; action_ids = $queueBinding.action_ids
    verified_at = (Get-Date).ToUniversalTime().ToString('o')
    pages = @([ordered]@{ url = 'https://online.hong-sen.com/cases/'; checks = $pageChecks })
  })
  $badLiveEvidence = [ordered]@{ queue_id = $queueBinding.queue_id; cycle_key = $queueBinding.cycle_key; queue_sha256 = $queueBinding.queue_sha256; action_ids = $queueBinding.action_ids; host = 'online.hong-sen.com'; verified_at = (Get-Date).ToString('o'); checks = @('http', 'canonical', 'json_ld', 'sitemap', 'redirects') | ForEach-Object { [ordered]@{ name = $_; status = 'passed'; evidence = "fixture $_ passed" } } } | ConvertTo-Json -Depth 5 -Compress
  $badLiveReceipt = Invoke-PwshFile -File $lifecycleWriter -ScriptArgs @('-RuntimeRoot', $runtimeRoot, '-Stage', 'live_verified', '-EvidenceJson', $badLiveEvidence)
  Assert-True ($badLiveReceipt.ExitCode -ne 0) 'live_verified lifecycle receipt accepted evidence without a formal live verification manifest.'
  $partialChecks = @('http','title','meta_description','h1','canonical','faq_parity','json_ld','internal_links','cta','robots','sitemap') | ForEach-Object { [ordered]@{ name = $_; passed = ($_ -ne 'faq_parity'); evidence = if ($_ -eq 'faq_parity') { 'fixture FAQ parity failed' } else { "fixture $_ passed" } } }
  Write-Json -Path $liveManifestPath -Value ([ordered]@{
    schema_version = 1; status = 'failed'; scope = 'queue_targets'; host = 'online.hong-sen.com'; queue_id = $queueBinding.queue_id; cycle_key = $queueBinding.cycle_key; action_ids = $queueBinding.action_ids
    pages = @([ordered]@{ url = 'https://online.hong-sen.com/cases/'; checks = $partialChecks })
  })
  $partialLiveEvidence = [ordered]@{
    queue_id = $queueBinding.queue_id; cycle_key = $queueBinding.cycle_key; queue_sha256 = $queueBinding.queue_sha256; action_ids = $queueBinding.action_ids
    host = 'online.hong-sen.com'; verified_at = (Get-Date).ToString('o')
    live_verification_manifest = [ordered]@{ path = 'latest/seo-geo-live-verification.json'; sha256 = (Get-FileHash -LiteralPath $liveManifestPath -Algorithm SHA256).Hash.ToLowerInvariant() }
  } | ConvertTo-Json -Depth 5 -Compress
  $partialLiveReceipt = Invoke-PwshFile -File $lifecycleWriter -ScriptArgs @('-RuntimeRoot', $runtimeRoot, '-Stage', 'live_verified', '-EvidenceJson', $partialLiveEvidence)
  Assert-True ($partialLiveReceipt.ExitCode -ne 0) 'live_verified lifecycle receipt accepted a partial/failed live contract.'
  Assert-True ((Read-Json -Path $statePath).status -eq 'deployed') 'partial live verification advanced lifecycle state.'
  Write-Json -Path $liveManifestPath -Value ([ordered]@{
    schema_version = 1; status = 'passed'; scope = 'queue_targets'; host = 'online.hong-sen.com'; queue_id = $queueBinding.queue_id; cycle_key = $queueBinding.cycle_key; action_ids = $queueBinding.action_ids
    verified_at = (Get-Date).ToUniversalTime().ToString('o')
    pages = @([ordered]@{ url = 'https://online.hong-sen.com/cases/'; checks = $pageChecks })
  })
  $liveReceipt = Invoke-PwshFile -File $lifecycleNext -ScriptArgs @('-RuntimeRoot', $runtimeRoot, '-Mode', 'Advance')
  if ($liveReceipt.ExitCode -ne 0) { $liveReceipt.Output | ForEach-Object { Write-Host $_ } }
  Assert-True ($liveReceipt.ExitCode -eq 0) 'live_verified lifecycle receipt was rejected after deployed.'
  $state = Read-Json -Path $statePath
  Assert-True ($state.status -eq 'live_verified') 'live_verified lifecycle stage was not persisted.'
  $uiLiveVerified = Get-UiProjectionFixture
  Assert-True ([bool]$uiLiveVerified.consistent -and [string]$uiLiveVerified.primary_action.id -eq 'ADVANCE_LIFECYCLE') 'Live-verified UI projection did not select lifecycle inspection.'
  $outOfOrderReceipt = Invoke-PwshFile -File $lifecycleWriter -ScriptArgs @('-RuntimeRoot', $runtimeRoot, '-Stage', 'completed', '-EvidenceJson', '{}')
  Assert-True ($outOfOrderReceipt.ExitCode -ne 0) 'lifecycle receipt allowed completed before 7d/28d review.'

  $state = Read-Json -Path $statePath
  $state.deployed_at = (Get-Date).AddDays(-35).ToUniversalTime().ToString('o')
  Write-Json -Path $statePath -Value $state
  $sevenManifestPath = Join-Path $runtimeRoot 'latest\7d\weekly-sop-last-run.json'
  $sevenManifest = Read-Json -Path $sevenManifestPath
  $observingReceipt = Invoke-PwshFile -File $lifecycleNext -ScriptArgs @('-RuntimeRoot', $runtimeRoot, '-Mode', 'Advance')
  Assert-True ($observingReceipt.ExitCode -eq 0) 'observing_7d rejected a bound decision-ready 7d manifest.'

  $twentyEightManifestPath = Join-Path $runtimeRoot 'latest\28d\weekly-sop-last-run.json'
  $twentyEightManifest = Read-Json -Path $twentyEightManifestPath
  $reviewReceipt = Invoke-PwshFile -File $lifecycleNext -ScriptArgs @('-RuntimeRoot', $runtimeRoot, '-Mode', 'Advance', '-Decision', 'keep', '-Summary', 'fixture review completed')
  Assert-True ($reviewReceipt.ExitCode -eq 0) 'reviewed_28d rejected a bound decision-ready 28d manifest and decision.'
  $completedReceipt = Invoke-PwshFile -File $lifecycleNext -ScriptArgs @('-RuntimeRoot', $runtimeRoot, '-Mode', 'Advance')
  Assert-True ($completedReceipt.ExitCode -eq 0) 'completed rejected a formal 28d decision summary.'

  $historyActions = @($queue.rounds[0].actions | ForEach-Object {
    [ordered]@{
      action_id = [string]$_.action_id
      fingerprint = [string]$_.fingerprint
      cluster_id = [string]$_.clusterId
      page = [string]$_.page
      result = 'no_change_verified'
      validated_at = (Get-Date).ToUniversalTime().ToString('o')
      queue_id = $queueIdBefore
      cycle_key = $cycleKeyBefore
      round = 1
    }
  })
  Write-Json -Path (Join-Path $runtimeRoot 'history\curtain-online\seo-geo-action-history.json') -Value ([ordered]@{
    schema_version = 1
    updated_at = (Get-Date).ToUniversalTime().ToString('o')
    actions = $historyActions
  })
  [void](Invoke-Generator)
  $cooldownQueue = Read-Json -Path $queuePath
  $cooldownSlim = Get-Content -LiteralPath $slimPath -Raw -Encoding UTF8
  $historyCooldownRows = @($cooldownQueue.observations | Where-Object { $_.page -in @('https://online.hong-sen.com/cases/', 'https://online.hong-sen.com/about/') })
  Assert-True ($cooldownQueue.status -eq 'observation_only') 'recent action fingerprints did not suppress the duplicate queue.'
  Assert-True (@($historyCooldownRows | Where-Object { $_.disposition -eq 'action_history_cooldown' }).Count -eq 2) 'action-history cooldown was not reported for both prior actions.'
  Assert-True ($cooldownSlim -notmatch 'PLEASE IMPLEMENT') 'history cooldown left an executable prompt.'
  Assert-True (@(Get-ChildItem -LiteralPath (Join-Path $runtimeRoot 'latest') -Filter 'seo-geo-action-plan.round-*.slim.ai.md' -File).Count -eq 0) 'history cooldown left stale numbered Round prompts.'

  $provenanceArgs = @('-RuntimeRoot', $runtimeRoot, '-RepoRoot', $runtimeRoot)
  $provenanceCurrent = Invoke-PwshFile -File $provenanceChecker -ScriptArgs $provenanceArgs
  Assert-True ($provenanceCurrent.ExitCode -eq 0) 'queue provenance checker failed on a current queue.'
  $provenanceCurrentJson = Convert-CommandJson -Output $provenanceCurrent.Output -Label 'current queue provenance'
  Assert-True (-not [bool]$provenanceCurrentJson.stale) ('freshly generated queue was incorrectly marked stale: ' + (@($provenanceCurrentJson.reasons) -join ', '))

  $registryFixturePath = Join-Path $runtimeRoot 'config\target-registry.json'
  $registryFixtureText = Get-Content -LiteralPath $registryFixturePath -Raw -Encoding UTF8
  Write-Utf8NoBom -Path $registryFixturePath -Text ($registryFixtureText + "`n")
  $registryDrift = Invoke-PwshFile -File $provenanceChecker -ScriptArgs $provenanceArgs
  $registryDriftJson = Convert-CommandJson -Output $registryDrift.Output -Label 'registry-drift provenance'
  Assert-True ([bool]$registryDriftJson.stale -and @($registryDriftJson.reasons) -contains 'registry_sha_mismatch') 'registry SHA drift was not detected.'
  Write-Utf8NoBom -Path $registryFixturePath -Text $registryFixtureText

  $manifestFixturePath = Join-Path $runtimeRoot 'latest\7d\weekly-sop-last-run.json'
  $manifestFixtureText = Get-Content -LiteralPath $manifestFixturePath -Raw -Encoding UTF8
  Write-Utf8NoBom -Path $manifestFixturePath -Text ($manifestFixtureText + "`n")
  $manifestDrift = Invoke-PwshFile -File $provenanceChecker -ScriptArgs $provenanceArgs
  $manifestDriftJson = Convert-CommandJson -Output $manifestDrift.Output -Label 'manifest-drift provenance'
  Assert-True ([bool]$manifestDriftJson.stale -and @($manifestDriftJson.reasons) -contains 'snapshot_7d_manifest_sha_mismatch') '7d manifest SHA drift was not detected.'
  Write-Utf8NoBom -Path $manifestFixturePath -Text $manifestFixtureText

  $baselineFixturePath = Join-Path $runtimeRoot 'history\curtain-online\28d\current_query_page_baseline.normalized.csv'
  $baselineFixtureText = Get-Content -LiteralPath $baselineFixturePath -Raw -Encoding UTF8
  Write-Utf8NoBom -Path $baselineFixturePath -Text ($baselineFixtureText + "`n")
  $baselineDrift = Invoke-PwshFile -File $provenanceChecker -ScriptArgs $provenanceArgs
  $baselineDriftJson = Convert-CommandJson -Output $baselineDrift.Output -Label 'baseline-drift provenance'
  Assert-True ([bool]$baselineDriftJson.stale -and @($baselineDriftJson.reasons) -contains 'snapshot_28d_query_page_sha_mismatch') '28d query-page baseline SHA drift was not detected.'
  Write-Utf8NoBom -Path $baselineFixturePath -Text $baselineFixtureText

  $historyFixturePath = Join-Path $runtimeRoot 'history\curtain-online\seo-geo-action-history.json'
  $historyFixtureText = Get-Content -LiteralPath $historyFixturePath -Raw -Encoding UTF8
  Write-Utf8NoBom -Path $historyFixturePath -Text ($historyFixtureText + "`n")
  $historyDrift = Invoke-PwshFile -File $provenanceChecker -ScriptArgs $provenanceArgs
  $historyDriftJson = Convert-CommandJson -Output $historyDrift.Output -Label 'history-drift provenance'
  Assert-True ([bool]$historyDriftJson.stale -and @($historyDriftJson.reasons) -contains 'action_history_sha_mismatch') 'action-history SHA drift was not detected.'
  Write-Utf8NoBom -Path $historyFixturePath -Text $historyFixtureText

  $sourceFixturePath = Join-Path $runtimeRoot 'src\app\cases\page.tsx'
  [System.IO.File]::AppendAllText($sourceFixturePath, "`n// provenance drift fixture`n", $utf8NoBom)
  $sourceDrift = Invoke-PwshFile -File $provenanceChecker -ScriptArgs $provenanceArgs
  $sourceDriftJson = Convert-CommandJson -Output $sourceDrift.Output -Label 'source-drift provenance'
  Assert-True ([bool]$sourceDriftJson.stale -and @($sourceDriftJson.reasons) -contains 'source_fingerprint_mismatch') 'source SHA drift was not detected.'

  foreach ($jsonPath in @(
    (Join-Path $runtimeRoot 'latest\seo-geo-action-queue.json'),
    (Join-Path $runtimeRoot 'latest\seo-geo-action-queue-state.json'),
    (Join-Path $runtimeRoot 'latest\seo-geo-action-plan.json')
  )) {
    $jsonText = Get-Content -LiteralPath $jsonPath -Raw -Encoding UTF8
    Assert-True ($jsonText -notmatch '(?i)\b[A-Z]:[\\/]') "Runtime JSON contains an absolute Windows path: $jsonPath"
  }

  Write-Host 'SEO/GEO cycle tests passed.'
  Write-Host 'monitor_only: observation only / 0 Rounds'
  Write-Host 'normalized baseline: /cases/ 28d metrics preserved'
  Write-Host 'queue provenance: snapshot, registry, source, history bound'
  Write-Host 'stale-plan guard: manifest/baseline/history/registry/source SHA drift detected'
  Write-Host 'receipt: matching accepted, mismatch rejected without overwrite'
  Write-Host 'dedupe: stable fingerprint + 28d history cooldown'
} finally {
  $tempRoot = [System.IO.Path]::GetFullPath([System.IO.Path]::GetTempPath()).TrimEnd('\')
  $resolvedTestRoot = [System.IO.Path]::GetFullPath($testRoot).TrimEnd('\')
  if ($resolvedTestRoot.StartsWith($tempRoot + '\', [System.StringComparison]::OrdinalIgnoreCase) -and
      (Test-Path -LiteralPath $resolvedTestRoot)) {
    Remove-Item -LiteralPath $resolvedTestRoot -Recurse -Force
  }
}
