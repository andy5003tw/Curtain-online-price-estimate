param(
  [ValidateSet('both', '7d', '28d')]
  [string]$Window = 'both',
  [switch]$PlanOnly,
  [string]$ClientSecretPath = (Join-Path $PSScriptRoot 'credentials\gsc-oauth-client.json'),
  [string]$TokenPath = (Join-Path $PSScriptRoot 'credentials\gsc-oauth-token.json')
)

$ErrorActionPreference = 'Stop'
$scope = 'https://www.googleapis.com/auth/webmasters.readonly'
$siteConfig = Get-Content -LiteralPath (Join-Path $PSScriptRoot 'config\site-config.json') -Raw -Encoding UTF8 | ConvertFrom-Json
$property = [string]$siteConfig.gscProperty
$dataLagDays = [int]$siteConfig.dataLagDays
$inboxDir = Join-Path $PSScriptRoot 'inbox'
$latestDir = Join-Path $PSScriptRoot 'latest'

function Get-TaipeiToday {
  $timeZone = $null
  foreach ($id in @('Taipei Standard Time', 'Asia/Taipei')) {
    try { $timeZone = [TimeZoneInfo]::FindSystemTimeZoneById($id); break } catch { }
  }
  if (-not $timeZone) { throw 'Unable to resolve the Taipei time zone.' }
  return [TimeZoneInfo]::ConvertTimeFromUtc((Get-Date).ToUniversalTime(), $timeZone).Date
}

function Get-WindowRange {
  param([ValidateSet('7d', '28d')][string]$Name, [datetime]$EndDate)
  $days = if ($Name -eq '7d') { 7 } else { 28 }
  $startDate = $EndDate.AddDays(-($days - 1))
  return [PSCustomObject]@{
    window = $Name
    start_date = $startDate.ToString('yyyy-MM-dd')
    end_date = $EndDate.ToString('yyyy-MM-dd')
    days = $days
  }
}

function Get-CurrentEndDate {
  param([string]$Name)
  $manifestPath = Join-Path $latestDir "$Name\weekly-sop-last-run.json"
  if (-not (Test-Path -LiteralPath $manifestPath -PathType Leaf)) { return $null }
  try {
    $manifest = Get-Content -LiteralPath $manifestPath -Raw -Encoding UTF8 | ConvertFrom-Json
    if ($manifest.end_date) { return [string]$manifest.end_date }
  } catch { Write-Warning "Ignoring unreadable current $Name manifest while checking for new GSC data." }
  return $null
}

function Get-CurrentDiagnosticEndDate {
  param([string]$Name)
  $manifestPath = Join-Path $latestDir "$Name\weekly-sop-last-run.json"
  if (-not (Test-Path -LiteralPath $manifestPath -PathType Leaf)) { return $null }
  try {
    $manifest = Get-Content -LiteralPath $manifestPath -Raw -Encoding UTF8 | ConvertFrom-Json
    $binding = $manifest.diagnostic_dimensions.date
    if (-not $binding -or -not $binding.available -or [string]::IsNullOrWhiteSpace([string]$binding.path)) { return $null }
    $relative = ([string]$binding.path).Replace('/', '\')
    if ([IO.Path]::IsPathRooted($relative)) { return $null }
    $path = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot $relative))
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { return $null }
    $dates = @(Import-Csv -LiteralPath $path -Encoding UTF8 | ForEach-Object { [string]$_.date } | Where-Object { $_ -match '^\d{4}-\d{2}-\d{2}$' } | Sort-Object -Unique)
    if ($dates.Count -eq 0) { return $null }
    return [string]$dates[-1]
  } catch { return $null }
}

function Convert-ToBase64Url {
  param([byte[]]$Bytes)
  return [Convert]::ToBase64String($Bytes).TrimEnd('=').Replace('+', '-').Replace('/', '_')
}

function Get-AccessToken {
  if (-not (Test-Path -LiteralPath $ClientSecretPath -PathType Leaf)) {
    throw "OAuth client JSON not found: $ClientSecretPath"
  }
  $clientRoot = Get-Content -LiteralPath $ClientSecretPath -Raw -Encoding UTF8 | ConvertFrom-Json
  $client = if ($clientRoot.installed) { $clientRoot.installed } elseif ($clientRoot.web) { $clientRoot.web } else { throw 'OAuth client JSON must contain installed or web credentials.' }
  if ([string]::IsNullOrWhiteSpace([string]$client.client_id)) { throw 'OAuth client JSON has no client_id.' }

  $token = if (Test-Path -LiteralPath $TokenPath -PathType Leaf) { Get-Content -LiteralPath $TokenPath -Raw -Encoding UTF8 | ConvertFrom-Json } else { $null }
  if ($token -and $token.refresh_token) {
    try {
      $refreshBody = @{ client_id = $client.client_id; grant_type = 'refresh_token'; refresh_token = $token.refresh_token }
      if ($client.client_secret) { $refreshBody.client_secret = $client.client_secret }
      $refreshed = Invoke-RestMethod -Method Post -Uri 'https://oauth2.googleapis.com/token' -ContentType 'application/x-www-form-urlencoded' -Body $refreshBody
      $token.access_token = $refreshed.access_token
      $token.expires_at = (Get-Date).AddSeconds([int]$refreshed.expires_in - 60).ToUniversalTime().ToString('o')
      [IO.Directory]::CreateDirectory((Split-Path -Parent $TokenPath)) | Out-Null
      $token | ConvertTo-Json | Set-Content -LiteralPath $TokenPath -Encoding UTF8
      return [string]$token.access_token
    } catch { Write-Warning 'Saved OAuth token could not be refreshed; starting a new browser authorization.' }
  }

  $listener = [Net.Sockets.TcpListener]::new([Net.IPAddress]::Loopback, 0)
  $listener.Start()
  try {
    $port = ([Net.IPEndPoint]$listener.LocalEndpoint).Port
    $redirectUri = "http://127.0.0.1:$port/"
    $random = [byte[]]::new(48)
    [Security.Cryptography.RandomNumberGenerator]::Fill($random)
    $verifier = Convert-ToBase64Url -Bytes $random
    $sha = [Security.Cryptography.SHA256]::Create()
    $challenge = Convert-ToBase64Url -Bytes ($sha.ComputeHash([Text.Encoding]::ASCII.GetBytes($verifier)))
    $query = @{
      client_id = $client.client_id; redirect_uri = $redirectUri; response_type = 'code'; scope = $scope
      access_type = 'offline'; prompt = 'consent'; code_challenge = $challenge; code_challenge_method = 'S256'
    }.GetEnumerator() | ForEach-Object { "$([uri]::EscapeDataString($_.Key))=$([uri]::EscapeDataString([string]$_.Value))" }
    $authorizeUri = 'https://accounts.google.com/o/oauth2/v2/auth?' + ($query -join '&')
    Write-Host 'Opening Google sign-in. Use the account that has access to this Search Console property.'
    Start-Process $authorizeUri
    $code = ''
    while (-not $code) {
      $context = $listener.AcceptTcpClient()
      $stream = $context.GetStream()
      $reader = [IO.StreamReader]::new($stream)
      $requestLine = $reader.ReadLine()
      $candidate = ([regex]::Match($requestLine, '[?&]code=([^& ]+)')).Groups[1].Value
      $error = ([regex]::Match($requestLine, '[?&]error=([^& ]+)')).Groups[1].Value
      $response = if ($candidate) { '<html><body><h2>Search Console authorization complete. You can close this tab.</h2></body></html>' } else { '<html><body><h2>Waiting for Google authorization. You can return to the Google sign-in tab.</h2></body></html>' }
      $responseBytes = [Text.Encoding]::UTF8.GetBytes($response)
      $writer = [IO.StreamWriter]::new($stream)
      $writer.Write("HTTP/1.1 200 OK`r`nContent-Type: text/html; charset=utf-8`r`nContent-Length: $($responseBytes.Length)`r`nConnection: close`r`n`r`n$response")
      $writer.Flush(); $writer.Dispose(); $reader.Dispose(); $stream.Dispose(); $context.Dispose()
      if ($error) { throw "Google authorization failed: $([uri]::UnescapeDataString($error))" }
      if ($candidate) { $code = [uri]::UnescapeDataString($candidate) }
    }
    $exchangeBody = @{ client_id = $client.client_id; code = $code; code_verifier = $verifier; grant_type = 'authorization_code'; redirect_uri = $redirectUri }
    if ($client.client_secret) { $exchangeBody.client_secret = $client.client_secret }
    $created = Invoke-RestMethod -Method Post -Uri 'https://oauth2.googleapis.com/token' -ContentType 'application/x-www-form-urlencoded' -Body $exchangeBody
    $saved = [ordered]@{ refresh_token = $created.refresh_token; access_token = $created.access_token; expires_at = (Get-Date).AddSeconds([int]$created.expires_in - 60).ToUniversalTime().ToString('o') }
    [IO.Directory]::CreateDirectory((Split-Path -Parent $TokenPath)) | Out-Null
    $saved | ConvertTo-Json | Set-Content -LiteralPath $TokenPath -Encoding UTF8
    return [string]$created.access_token
  } finally { $listener.Stop() }
}

function Get-SearchAnalyticsRows {
  param([string]$AccessToken, [PSCustomObject]$Range, [string[]]$Dimensions)
  $uri = 'https://www.googleapis.com/webmasters/v3/sites/' + [uri]::EscapeDataString($property) + '/searchAnalytics/query'
  $rows = @()
  for ($startRow = 0; ; $startRow += 25000) {
    $body = @{ startDate = $Range.start_date; endDate = $Range.end_date; dimensions = $Dimensions; type = 'web'; rowLimit = 25000; startRow = $startRow; dataState = 'final' } | ConvertTo-Json -Depth 4
    $result = Invoke-RestMethod -Method Post -Uri $uri -Headers @{ Authorization = "Bearer $AccessToken" } -ContentType 'application/json' -Body $body
    $batch = @($result.rows)
    $rows += $batch
    if ($batch.Count -lt 25000) { break }
  }
  return $rows
}

function Convert-Row {
  param($Row, [string]$FirstKey, [string]$SecondKey = '', [string]$ThirdKey = '')
  $record = [ordered]@{}
  $record[$FirstKey] = [string]$Row.keys[0]
  if ($SecondKey) { $record[$SecondKey] = [string]$Row.keys[1] }
  if ($ThirdKey) { $record[$ThirdKey] = [string]$Row.keys[2] }
  $record.clicks = $Row.clicks
  $record.impressions = $Row.impressions
  $record.ctr = ('{0:0.########}%' -f ([double]$Row.ctr * 100))
  $record.position = $Row.position
  return [PSCustomObject]$record
}

function New-GscWindowZip {
  param([string]$AccessToken, [PSCustomObject]$Range)
  $queryRows = @(Get-SearchAnalyticsRows -AccessToken $AccessToken -Range $Range -Dimensions @('query'))
  $pageRows = @(Get-SearchAnalyticsRows -AccessToken $AccessToken -Range $Range -Dimensions @('page'))
  $queryPageRows = @(Get-SearchAnalyticsRows -AccessToken $AccessToken -Range $Range -Dimensions @('query', 'page'))
  # These diagnostic cuts are intentionally separate from the owner baseline:
  # they explain movement by day/device without changing 1 keyword = 1 owner.
  $datePageRows = @(Get-SearchAnalyticsRows -AccessToken $AccessToken -Range $Range -Dimensions @('date', 'page'))
  $devicePageRows = @(Get-SearchAnalyticsRows -AccessToken $AccessToken -Range $Range -Dimensions @('date', 'device', 'page'))
  $dateRows = @(Get-SearchAnalyticsRows -AccessToken $AccessToken -Range $Range -Dimensions @('date'))
  $countryPageRows = @(Get-SearchAnalyticsRows -AccessToken $AccessToken -Range $Range -Dimensions @('date', 'country', 'page'))
  $deviceQueryRows = @(Get-SearchAnalyticsRows -AccessToken $AccessToken -Range $Range -Dimensions @('date', 'device', 'query'))
  if ($queryRows.Count -eq 0 -or $pageRows.Count -eq 0 -or $queryPageRows.Count -eq 0) {
    throw "Search Console API returned incomplete data for $($Range.window) $($Range.start_date) to $($Range.end_date)."
  }
  $expectedDates = @()
  $cursor = [datetime]::ParseExact($Range.start_date, 'yyyy-MM-dd', [Globalization.CultureInfo]::InvariantCulture)
  $end = [datetime]::ParseExact($Range.end_date, 'yyyy-MM-dd', [Globalization.CultureInfo]::InvariantCulture)
  while ($cursor -le $end) { $expectedDates += $cursor.ToString('yyyy-MM-dd'); $cursor = $cursor.AddDays(1) }
  $actualDates = @($dateRows | ForEach-Object { [string]$_.keys[0] } | Sort-Object -Unique)
  $missingDates = @($expectedDates | Where-Object { $_ -notin $actualDates })
  if ($missingDates.Count -gt 0) {
    throw "Search Console final Date dimension is incomplete for $($Range.window): missing $($missingDates -join ', '). Baseline was not updated."
  }
  [IO.Directory]::CreateDirectory($inboxDir) | Out-Null
  $baseName = "gsc-api_$($Range.start_date)~$($Range.end_date)_$($Range.window)"
  $outputZip = Join-Path $inboxDir "$baseName.zip"
  if (Test-Path -LiteralPath $outputZip) { throw "Generated ZIP already exists: $outputZip. The date window has already been fetched." }
  $tempDir = Join-Path ([IO.Path]::GetTempPath()) ('gsc-api-' + [guid]::NewGuid().ToString('N'))
  try {
    [IO.Directory]::CreateDirectory($tempDir) | Out-Null
    $queryRows | ForEach-Object { Convert-Row -Row $_ -FirstKey 'query' } | Export-Csv -LiteralPath (Join-Path $tempDir 'query.csv') -NoTypeInformation -Encoding UTF8
    $pageRows | ForEach-Object { Convert-Row -Row $_ -FirstKey 'page' } | Export-Csv -LiteralPath (Join-Path $tempDir 'page.csv') -NoTypeInformation -Encoding UTF8
    $queryPageRows | ForEach-Object { Convert-Row -Row $_ -FirstKey 'query' -SecondKey 'page' } | Export-Csv -LiteralPath (Join-Path $tempDir 'query-page.csv') -NoTypeInformation -Encoding UTF8
    $datePageRows | ForEach-Object { Convert-Row -Row $_ -FirstKey 'date' -SecondKey 'page' } | Export-Csv -LiteralPath (Join-Path $tempDir 'date-page.csv') -NoTypeInformation -Encoding UTF8
    $devicePageRows | ForEach-Object { Convert-Row -Row $_ -FirstKey 'date' -SecondKey 'device' -ThirdKey 'page' } | Export-Csv -LiteralPath (Join-Path $tempDir 'device-page.csv') -NoTypeInformation -Encoding UTF8
    $dateRows | ForEach-Object { Convert-Row -Row $_ -FirstKey 'date' } | Export-Csv -LiteralPath (Join-Path $tempDir 'date.csv') -NoTypeInformation -Encoding UTF8
    $countryPageRows | ForEach-Object { Convert-Row -Row $_ -FirstKey 'date' -SecondKey 'country' -ThirdKey 'page' } | Export-Csv -LiteralPath (Join-Path $tempDir 'country-page.csv') -NoTypeInformation -Encoding UTF8
    $deviceQueryRows | ForEach-Object { Convert-Row -Row $_ -FirstKey 'date' -SecondKey 'device' -ThirdKey 'query' } | Export-Csv -LiteralPath (Join-Path $tempDir 'device-query.csv') -NoTypeInformation -Encoding UTF8
    @([PSCustomObject]@{ Filter = 'Date'; Value = "$($Range.start_date)~$($Range.end_date)" }) | Export-Csv -LiteralPath (Join-Path $tempDir 'filters.csv') -NoTypeInformation -Encoding UTF8
    Compress-Archive -Path (Join-Path $tempDir '*') -DestinationPath $outputZip -CompressionLevel Optimal
  } finally {
    if (Test-Path -LiteralPath $tempDir) { Remove-Item -LiteralPath $tempDir -Recurse -Force }
  }
  return [PSCustomObject]@{ path = $outputZip; query_rows = $queryRows.Count; page_rows = $pageRows.Count; query_page_rows = $queryPageRows.Count; date_rows = $dateRows.Count; date_page_rows = $datePageRows.Count; device_page_rows = $devicePageRows.Count; country_page_rows = $countryPageRows.Count; device_query_rows = $deviceQueryRows.Count }
}

$latestFinalizedDate = (Get-TaipeiToday).AddDays(-$dataLagDays)
$selectedWindows = if ($Window -eq 'both') { @('7d', '28d') } else { @($Window) }
$ranges = @($selectedWindows | ForEach-Object { Get-WindowRange -Name $_ -EndDate $latestFinalizedDate })
$status = @()
foreach ($range in $ranges) {
  $currentEnd = Get-CurrentEndDate -Name $range.window
  $isCandidateNew = -not $currentEnd -or $range.end_date -gt $currentEnd
  $status += [PSCustomObject]@{ window = $range.window; estimated_start_date = $range.start_date; estimated_end_date = $range.end_date; current_end_date = $currentEnd; estimated_new_data_candidate = $isCandidateNew; new_data_available = $null; availability_basis = 'configured_lag_estimate'; requires_api_final_probe = $true }
}
if ($PlanOnly) { $status | ConvertTo-Json -Depth 3; exit 0 }
$accessToken = Get-AccessToken
$probeRange = [PSCustomObject]@{
  window = 'probe'
  start_date = $latestFinalizedDate.AddDays(-10).ToString('yyyy-MM-dd')
  end_date = $latestFinalizedDate.ToString('yyyy-MM-dd')
}
$probeDates = @(Get-SearchAnalyticsRows -AccessToken $accessToken -Range $probeRange -Dimensions @('date') | ForEach-Object { [string]$_.keys[0] } | Where-Object { $_ -match '^\d{4}-\d{2}-\d{2}$' } | Sort-Object -Unique)
if ($probeDates.Count -eq 0) { throw 'Search Console API returned no final Date rows for the recent availability probe.' }
$apiFinalizedDate = [datetime]::ParseExact([string]$probeDates[-1], 'yyyy-MM-dd', [Globalization.CultureInfo]::InvariantCulture)
if ($apiFinalizedDate -lt $latestFinalizedDate) {
  Write-Warning "Configured dataLagDays=$dataLagDays suggested $($latestFinalizedDate.ToString('yyyy-MM-dd')), but the latest API final Date row is $($apiFinalizedDate.ToString('yyyy-MM-dd')). Using the API-confirmed date."
  $latestFinalizedDate = $apiFinalizedDate
  $ranges = @($selectedWindows | ForEach-Object { Get-WindowRange -Name $_ -EndDate $latestFinalizedDate })
}
$status = @()
foreach ($range in $ranges) {
  $currentEnd = Get-CurrentEndDate -Name $range.window
  $diagnosticEnd = Get-CurrentDiagnosticEndDate -Name $range.window
  $isNew = -not $currentEnd -or $range.end_date -gt $currentEnd
  $repairIncompleteEnd = [bool]($currentEnd -and $diagnosticEnd -and $currentEnd -gt $range.end_date -and $diagnosticEnd -eq $range.end_date)
  $status += [PSCustomObject]@{ window = $range.window; start_date = $range.start_date; end_date = $range.end_date; current_end_date = $currentEnd; current_diagnostic_end_date = $diagnosticEnd; new_data_available = $isNew; repair_incomplete_end_date = $repairIncompleteEnd }
}
if (@($status | Where-Object { -not $_.new_data_available -and -not $_.repair_incomplete_end_date }).Count -gt 0) {
  $status | ForEach-Object { Write-Host "$($_.window): API final $($_.end_date); current baseline $($_.current_end_date); diagnostic end $($_.current_diagnostic_end_date); new data $($_.new_data_available); repair $($_.repair_incomplete_end_date)" }
  Write-Host 'No new finalized GSC period is available for every requested window. Nothing was changed.'
  exit 0
}
$generated = @()
foreach ($range in $ranges) {
  $windowStatus = @($status | Where-Object { $_.window -eq $range.window })[0]
  $result = New-GscWindowZip -AccessToken $accessToken -Range $range
  $generated += [PSCustomObject]@{ window = $range.window; start_date = $range.start_date; end_date = $range.end_date; zip = $result.path; query_rows = $result.query_rows; page_rows = $result.page_rows; query_page_rows = $result.query_page_rows; date_rows = $result.date_rows; date_page_rows = $result.date_page_rows; device_page_rows = $result.device_page_rows; country_page_rows = $result.country_page_rows; device_query_rows = $result.device_query_rows }
  & (Join-Path $PSScriptRoot 'run-weekly-window.ps1') -Window $range.window -InputFile $result.path -ImportSource api -RepairIncompleteCurrentEndDate:([bool]$windowStatus.repair_incomplete_end_date)
  if ($LASTEXITCODE -ne 0) { throw "Weekly SOP import failed for $($range.window)." }
}
if ($Window -eq 'both') {
  & (Join-Path $PSScriptRoot 'run-seo-geo-cycle.ps1') -Mode auto
  if ($LASTEXITCODE -ne 0) { throw 'SEO/GEO action-plan generation failed.' }
}
$generated | ConvertTo-Json -Depth 3 | Set-Content -LiteralPath (Join-Path $latestDir 'gsc-latest-fetch.json') -Encoding UTF8
Write-Host 'GSC latest fetch completed. Current reports and SEO/GEO action plan are updated.'
$generated | ConvertTo-Json -Depth 3
