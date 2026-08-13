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
$testRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("curtain-seo-geo-cycle-{0}" -f ([guid]::NewGuid().ToString('N')))
$runtimeRoot = Join-Path $testRoot 'runtime'

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
    "測試產品總覽主詞,(all pages),2,$(22 * $multiplier),2.27,11.4"
    "本期新增查詢,(all pages),1,$(9 * $multiplier),2.78,13.2"
    "一次曝光雜訊,(all pages),0,1,0,8"
    "蛇形窗簾,(all pages),0,$([int](165 / $multiplier)),0,12"
  ) -join "`r`n")

  Write-Utf8NoBom -Path $comparisonQueryPath -Text (@(
    'query,page,clicks,impressions,ctr,position'
    "測試案例主詞,(all pages),0,$([Math]::Max(1, [int]($CasesImpressions / 2))),0,$CasesPosition"
    "測試品牌主詞,(all pages),1,$(17 * $multiplier),1.47,7.2"
    "測試產品總覽主詞,(all pages),2,$(22 * $multiplier),2.27,11.4"
    "本期消失查詢,(all pages),1,$(8 * $multiplier),3.12,14.1"
    "蛇形窗簾,(all pages),0,$([int](165 / $multiplier)),0,12"
  ) -join "`r`n")

  Write-Utf8NoBom -Path $pagePath -Text (@(
    'query,page,clicks,impressions,ctr,position'
    ",https://online.hong-sen.com/cases/,0,$CasesImpressions,$CasesCtr,$CasesPosition"
    ",https://online.hong-sen.com/about/,1,$(18 * $multiplier),1.39,6.8"
    ",https://online.hong-sen.com/products/,2,$(23 * $multiplier),2.17,12.1"
    ",https://online.hong-sen.com/products/s-fold-curtains/,0,$([int](165 / $multiplier)),0,12"
  ) -join "`r`n")

  Write-Utf8NoBom -Path $queryPagePath -Text (@(
    'query,page,clicks,impressions,ctr,position'
    "測試案例主詞,https://online.hong-sen.com/cases/,0,$(60 * $multiplier),0,9"
    "測試案例主詞,https://online.hong-sen.com/products/,0,$(40 * $multiplier),0,10"
    "測試品牌主詞,https://online.hong-sen.com/about/,1,$(17 * $multiplier),1.47,7.2"
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
  $startDate = if ($Window -eq '7d') { '2026-08-03' } else { '2026-07-13' }
  $endDate = '2026-08-09'
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
    snapshot_family_id = 'fixture|https://online.hong-sen.com/|2026-08-09|Asia/Taipei'
    baseline = [ordered]@{
      query = "$historyRelative/current_query_baseline.normalized.csv"
      page = "$historyRelative/current_page_baseline.normalized.csv"
      query_page = "$historyRelative/current_query_page_baseline.normalized.csv"
      bootstrapped = $Bootstrapped
    }
    comparison_sources = [ordered]@{ query_before = "$historyRelative/previous_query_baseline.normalized.csv" }
    comparison_period = if($Window -eq '28d'){[ordered]@{start_date='2026-06-15';end_date='2026-07-12';comparison_type='non_overlapping';overlap_days=0}}else{$null}
  }
  Write-Json -Path $manifestPath -Value $manifest
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
  $queue = Read-Json -Path $queuePath
  $state = Read-Json -Path $statePath
  $slim = Get-Content -LiteralPath $slimPath -Raw -Encoding UTF8
  $html = Get-Content -LiteralPath $htmlPath -Raw -Encoding UTF8
  $casesObservation = @($queue.observations | Where-Object { $_.page -eq 'https://online.hong-sen.com/cases/' })[0]

  Assert-True ($queue.status -eq 'observation_only') 'monitor_only generated an executable queue.'
  Assert-True ($html -match '<h1>SEO/GEO 重點報告</h1>' -and $html -match '核心關鍵字表現' -and $html -match '現在要做什麼' -and $html -match '重要提醒') 'Human HTML report is missing its concise decision and keyword summary.'
  Assert-True ($html -match '7d 曝光' -and $html -match '28d 排名' -and $html -match 'Owner share') 'Human HTML report is missing core keyword KPI columns.'
  Assert-True ($html -match '可正式判斷（decision-ready）' -and $html -match '本輪不修改網站' -and $html -match '主頁流量占比（Owner share）') 'Human HTML report is missing Chinese annotations for report status terms.'
  Assert-True ($html -notmatch 'Diagnostic Analysis' -and $html -notmatch 'Per-page Compliance') 'Human HTML report must not render full diagnostic or per-page detail tables by default.'
  Assert-True ($html -match '完整明細保留於 JSON' -and $html -match '\*\.ai\.md') 'Human HTML report must direct detailed review and AI execution to the correct artifacts.'
  Assert-True ([int]$state.total_rounds -eq 0) 'monitor_only state total_rounds is not 0.'
  Assert-True (@($state.prompt_files).Count -eq 0) 'monitor_only state contains prompt files.'
  Assert-True (@($queue.observations).Count -eq 4) 'monitor_only did not include every registry owner.'
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
  $approvedProjection = ($approvedProjectionResult.Output -join "`n") | ConvertFrom-Json
  Assert-True ([bool]$approvedProjection.consistency.valid -and [string]$approvedProjection.strategy_snapshot.status -eq 'observation_only' -and [bool]$approvedProjection.approved_queue.approved_override -and [string]$approvedProjection.effective.status -eq 'active' -and [string]$approvedProjection.effective.source -eq 'approved_queue') 'effective workflow projection did not distinguish immutable observation snapshot from approved active Round.'

  $planSnapshotPath = Join-Path $runtimeRoot 'latest\seo-geo-action-plan.json'
  $planSnapshotBeforeMismatch = Get-Content -LiteralPath $planSnapshotPath -Raw -Encoding UTF8
  $badPlanSnapshot = $planSnapshotBeforeMismatch | ConvertFrom-Json
  $badPlanSnapshot.queue_id = 'different-queue'
  Write-Json -Path $planSnapshotPath -Value $badPlanSnapshot
  $mismatchProjectionResult = Invoke-PwshFile -File $projectionWriter -ScriptArgs @('-RuntimeRoot', $runtimeRoot)
  Assert-True ($mismatchProjectionResult.ExitCode -eq 0) 'effective workflow projection did not return a safe result for plan/queue mismatch.'
  $mismatchProjection = ($mismatchProjectionResult.Output -join "`n") | ConvertFrom-Json
  Assert-True (-not [bool]$mismatchProjection.consistency.valid -and @($mismatchProjection.consistency.reasons) -contains 'plan_queue_identity_mismatch' -and [string]$mismatchProjection.effective.status -eq 'inconsistent') 'effective workflow projection did not block plan/queue identity mismatch.'
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
  $deploymentManifestPath = Join-Path $runtimeRoot 'latest\seo-geo-deployment-manifest.json'
  Write-Json -Path $deploymentManifestPath -Value ([ordered]@{
    schema_version = 1; status = 'success'; dry_run = $false; target_host = 'online.hong-sen.com'; deploy_mode = 'quick'
    generated_at = (Get-Date).AddMinutes(-1).ToUniversalTime().ToString('o'); completed_at = (Get-Date).ToUniversalTime().ToString('o')
    deployment_context = [ordered]@{ queue_id = $queueBinding.queue_id; cycle_key = $queueBinding.cycle_key; action_ids = $queueBinding.action_ids }
    summary = [ordered]@{ selected = 3; uploaded = 2; skipped = 1; failed = 0 }
    files = @(
      [ordered]@{ relative_path = 'products/cases/index.html'; size_bytes = 100; sha256 = ('a' * 64); result = 'uploaded' },
      [ordered]@{ relative_path = 'sitemap.xml'; size_bytes = 100; sha256 = ('b' * 64); result = 'uploaded' },
      [ordered]@{ relative_path = 'robots.txt'; size_bytes = 100; sha256 = ('c' * 64); result = 'skipped_same_size' }
    )
  })
  $badDeployEvidence = [ordered]@{ queue_id = $queueBinding.queue_id; cycle_key = $queueBinding.cycle_key; queue_sha256 = $queueBinding.queue_sha256; action_ids = $queueBinding.action_ids; validation_receipt_sha256 = (Get-FileHash -LiteralPath $receiptPath -Algorithm SHA256).Hash.ToLowerInvariant(); uploaded = 2; skipped = 1; failed = 0; command = 'deploy fixture'; completed_at = (Get-Date).ToString('o'); target_host = 'online.hong-sen.com' } | ConvertTo-Json -Depth 5 -Compress
  $badDeployReceipt = Invoke-PwshFile -File $lifecycleWriter -ScriptArgs @('-RuntimeRoot', $runtimeRoot, '-Stage', 'deployed', '-EvidenceJson', $badDeployEvidence)
  Assert-True ($badDeployReceipt.ExitCode -ne 0) 'deployed lifecycle receipt accepted evidence without a complete deployment manifest.'
  $badDeployShaEvidence = [ordered]@{ queue_id = $queueBinding.queue_id; cycle_key = $queueBinding.cycle_key; queue_sha256 = $queueBinding.queue_sha256; action_ids = $queueBinding.action_ids; validation_receipt_sha256 = (Get-FileHash -LiteralPath $receiptPath -Algorithm SHA256).Hash.ToLowerInvariant(); uploaded = 2; skipped = 1; failed = 0; command = 'deploy fixture'; completed_at = (Get-Date).ToString('o'); target_host = 'online.hong-sen.com'; deployment_manifest = [ordered]@{ path = 'latest/seo-geo-deployment-manifest.json'; sha256 = ('0' * 64) } } | ConvertTo-Json -Depth 8 -Compress
  $badDeployShaReceipt = Invoke-PwshFile -File $lifecycleWriter -ScriptArgs @('-RuntimeRoot', $runtimeRoot, '-Stage', 'deployed', '-EvidenceJson', $badDeployShaEvidence)
  Assert-True ($badDeployShaReceipt.ExitCode -ne 0) 'deployed lifecycle receipt accepted a deployment manifest SHA mismatch.'
  Assert-True ((Read-Json -Path $statePath).status -eq 'local_validated') 'deployment manifest SHA mismatch advanced lifecycle state.'
  $deployReceipt = Invoke-PwshFile -File $lifecycleNext -ScriptArgs @('-RuntimeRoot', $runtimeRoot, '-Mode', 'Advance')
  if ($deployReceipt.ExitCode -ne 0) { $deployReceipt.Output | ForEach-Object { Write-Host $_ } }
  Assert-True ($deployReceipt.ExitCode -eq 0) 'deployed lifecycle receipt was rejected after local validation.'
  $state = Read-Json -Path $statePath
  Assert-True ($state.status -eq 'deployed' -and -not [string]::IsNullOrWhiteSpace([string]$state.deployed_at)) 'deployed lifecycle stage was not persisted.'
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
  $provenanceCurrentJson = ($provenanceCurrent.Output -join "`n") | ConvertFrom-Json
  Assert-True (-not [bool]$provenanceCurrentJson.stale) ('freshly generated queue was incorrectly marked stale: ' + (@($provenanceCurrentJson.reasons) -join ', '))

  $registryFixturePath = Join-Path $runtimeRoot 'config\target-registry.json'
  $registryFixtureText = Get-Content -LiteralPath $registryFixturePath -Raw -Encoding UTF8
  Write-Utf8NoBom -Path $registryFixturePath -Text ($registryFixtureText + "`n")
  $registryDrift = Invoke-PwshFile -File $provenanceChecker -ScriptArgs $provenanceArgs
  $registryDriftJson = ($registryDrift.Output -join "`n") | ConvertFrom-Json
  Assert-True ([bool]$registryDriftJson.stale -and @($registryDriftJson.reasons) -contains 'registry_sha_mismatch') 'registry SHA drift was not detected.'
  Write-Utf8NoBom -Path $registryFixturePath -Text $registryFixtureText

  $manifestFixturePath = Join-Path $runtimeRoot 'latest\7d\weekly-sop-last-run.json'
  $manifestFixtureText = Get-Content -LiteralPath $manifestFixturePath -Raw -Encoding UTF8
  Write-Utf8NoBom -Path $manifestFixturePath -Text ($manifestFixtureText + "`n")
  $manifestDrift = Invoke-PwshFile -File $provenanceChecker -ScriptArgs $provenanceArgs
  $manifestDriftJson = ($manifestDrift.Output -join "`n") | ConvertFrom-Json
  Assert-True ([bool]$manifestDriftJson.stale -and @($manifestDriftJson.reasons) -contains 'snapshot_7d_manifest_sha_mismatch') '7d manifest SHA drift was not detected.'
  Write-Utf8NoBom -Path $manifestFixturePath -Text $manifestFixtureText

  $baselineFixturePath = Join-Path $runtimeRoot 'history\curtain-online\28d\current_query_page_baseline.normalized.csv'
  $baselineFixtureText = Get-Content -LiteralPath $baselineFixturePath -Raw -Encoding UTF8
  Write-Utf8NoBom -Path $baselineFixturePath -Text ($baselineFixtureText + "`n")
  $baselineDrift = Invoke-PwshFile -File $provenanceChecker -ScriptArgs $provenanceArgs
  $baselineDriftJson = ($baselineDrift.Output -join "`n") | ConvertFrom-Json
  Assert-True ([bool]$baselineDriftJson.stale -and @($baselineDriftJson.reasons) -contains 'snapshot_28d_query_page_sha_mismatch') '28d query-page baseline SHA drift was not detected.'
  Write-Utf8NoBom -Path $baselineFixturePath -Text $baselineFixtureText

  $historyFixturePath = Join-Path $runtimeRoot 'history\curtain-online\seo-geo-action-history.json'
  $historyFixtureText = Get-Content -LiteralPath $historyFixturePath -Raw -Encoding UTF8
  Write-Utf8NoBom -Path $historyFixturePath -Text ($historyFixtureText + "`n")
  $historyDrift = Invoke-PwshFile -File $provenanceChecker -ScriptArgs $provenanceArgs
  $historyDriftJson = ($historyDrift.Output -join "`n") | ConvertFrom-Json
  Assert-True ([bool]$historyDriftJson.stale -and @($historyDriftJson.reasons) -contains 'action_history_sha_mismatch') 'action-history SHA drift was not detected.'
  Write-Utf8NoBom -Path $historyFixturePath -Text $historyFixtureText

  $sourceFixturePath = Join-Path $runtimeRoot 'src\app\cases\page.tsx'
  [System.IO.File]::AppendAllText($sourceFixturePath, "`n// provenance drift fixture`n", $utf8NoBom)
  $sourceDrift = Invoke-PwshFile -File $provenanceChecker -ScriptArgs $provenanceArgs
  $sourceDriftJson = ($sourceDrift.Output -join "`n") | ConvertFrom-Json
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
