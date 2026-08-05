param()

$ErrorActionPreference = 'Stop'
$utf8NoBom = [System.Text.UTF8Encoding]::new($false)
$repoRoot = Split-Path -Parent $PSScriptRoot
$generator = Join-Path $repoRoot 'Weekly SOP\run-seo-geo-cycle.ps1'
$receiptWriter = Join-Path $repoRoot 'scripts\write-seo-geo-validation-receipt.ps1'
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
  $multiplier = if ($Window -eq '28d') { 4 } else { 1 }

  Write-Utf8NoBom -Path $queryPath -Text (@(
    'query,page,clicks,impressions,ctr,position'
    "測試案例主詞,(all pages),0,$([Math]::Max(1, [int]($CasesImpressions / 2))),0,$CasesPosition"
    "測試品牌主詞,(all pages),1,$(17 * $multiplier),1.47,7.2"
    "測試產品總覽主詞,(all pages),2,$(22 * $multiplier),2.27,11.4"
  ) -join "`r`n")

  Write-Utf8NoBom -Path $pagePath -Text (@(
    'query,page,clicks,impressions,ctr,position'
    ",https://online.hong-sen.com/cases/,0,$CasesImpressions,$CasesCtr,$CasesPosition"
    ",https://online.hong-sen.com/about/,1,$(18 * $multiplier),1.39,6.8"
    ",https://online.hong-sen.com/products/,2,$(23 * $multiplier),2.17,12.1"
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
    start_date = if ($Window -eq '7d') { (Get-Date).AddDays(-8).ToString('yyyy-MM-dd') } else { (Get-Date).AddDays(-29).ToString('yyyy-MM-dd') }
    end_date = (Get-Date).AddDays(-2).ToString('yyyy-MM-dd')
    date_range_complete = $true
    query_page_available = $true
    snapshot_family_id = 'fixture|https://online.hong-sen.com/|' + (Get-Date).AddDays(-2).ToString('yyyy-MM-dd') + '|Asia/Taipei'
    baseline = [ordered]@{
      query = "$historyRelative/current_query_baseline.normalized.csv"
      page = "$historyRelative/current_page_baseline.normalized.csv"
      bootstrapped = $Bootstrapped
    }
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
        clusterId = 'fixture-products'; layer = 'hub'; primaryKeyword = '測試產品總覽主詞'; variants = @('測試產品比較詞')
        intent = 'hub'; ownerUrl = '/products/'; pageType = 'hub'; priority = 'P1'; schemaProfile = 'collection'
        businessValue = 'high'; lastChangedAt = $today; status = 'active'
      }
    )
  })

  foreach ($relativePath in @(
    'src/app/cases/layout.tsx',
    'src/app/cases/page.tsx',
    'src/app/about/page.tsx',
    'src/app/products/page.tsx',
    'src/data/products.ts',
    'src/lib/seo.ts'
  )) {
    Copy-SourceFixture -RelativePath $relativePath
  }

  Write-Baselines -Window '7d' -CasesImpressions 11 -CasesCtr 0 -CasesPosition 9
  Write-Baselines -Window '28d' -CasesImpressions 51 -CasesCtr 0 -CasesPosition 9
  Write-WindowManifest -Window '7d' -Confidence monitor_only -Bootstrapped $true -ShaCharacter '7'
  Write-WindowManifest -Window '28d' -Confidence monitor_only -Bootstrapped $true -ShaCharacter '2'

  [void](Invoke-Generator)
  $queuePath = Join-Path $runtimeRoot 'latest\seo-geo-action-queue.json'
  $statePath = Join-Path $runtimeRoot 'latest\seo-geo-action-queue-state.json'
  $slimPath = Join-Path $runtimeRoot 'latest\seo-geo-action-plan.slim.ai.md'
  $queue = Read-Json -Path $queuePath
  $state = Read-Json -Path $statePath
  $slim = Get-Content -LiteralPath $slimPath -Raw -Encoding UTF8
  $casesObservation = @($queue.observations | Where-Object { $_.page -eq 'https://online.hong-sen.com/cases/' })[0]

  Assert-True ($queue.status -eq 'observation_only') 'monitor_only generated an executable queue.'
  Assert-True ([int]$state.total_rounds -eq 0) 'monitor_only state total_rounds is not 0.'
  Assert-True (@($state.prompt_files).Count -eq 0) 'monitor_only state contains prompt files.'
  Assert-True (@($queue.observations).Count -eq 3) 'monitor_only did not include every registry owner.'
  Assert-True ([int]$casesObservation.'28d impressions' -eq 51) '/cases/ did not read 28d metrics from the full normalized baseline.'
  Assert-True ($slim -notmatch 'PLEASE IMPLEMENT') 'monitor_only prompt contains PLEASE IMPLEMENT.'
  Assert-True ($slim -match 'PLEASE REVIEW THIS MONITORING LIST') 'monitor_only prompt is not an observation prompt.'
  Assert-True (@(Get-ChildItem -LiteralPath (Join-Path $runtimeRoot 'latest') -Filter 'seo-geo-action-plan.round-*.slim.ai.md' -File).Count -eq 0) 'monitor_only left a stale executable Round prompt.'

  Write-WindowManifest -Window '7d' -Confidence decision_ready -Bootstrapped $false -ShaCharacter '8'
  Write-WindowManifest -Window '28d' -Confidence decision_ready -Bootstrapped $false -ShaCharacter '3'
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
