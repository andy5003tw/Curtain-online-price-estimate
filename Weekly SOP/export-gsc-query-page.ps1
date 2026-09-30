param(
  [Parameter(Mandatory = $true)][string]$InputZip,
  [string]$StartDate,
  [string]$EndDate,
  [string]$OutputZip,
  [string]$ClientSecretPath = (Join-Path $PSScriptRoot 'credentials\gsc-oauth-client.json'),
  [string]$TokenPath = (Join-Path $PSScriptRoot 'credentials\gsc-oauth-token.json')
)

$ErrorActionPreference = 'Stop'
$scope = 'https://www.googleapis.com/auth/webmasters.readonly'
$siteConfig = Get-Content -LiteralPath (Join-Path $PSScriptRoot 'config\site-config.json') -Raw -Encoding UTF8 | ConvertFrom-Json
$property = [string]$siteConfig.gscProperty

function Get-DateRangeFromName {
  param([string]$Name)
  $match = [regex]::Match($Name, '(?<start>20\d{2}[-_/]\d{1,2}[-_/]\d{1,2})\s*(?:~|～|至|to)\s*(?<end>20\d{2}[-_/]\d{1,2}[-_/]\d{1,2})', [Text.RegularExpressions.RegexOptions]::IgnoreCase)
  if (-not $match.Success) { return $null }
  $start = [datetime]::ParseExact(($match.Groups['start'].Value -replace '[_/]', '-'), 'yyyy-M-d', [Globalization.CultureInfo]::InvariantCulture)
  $end = [datetime]::ParseExact(($match.Groups['end'].Value -replace '[_/]', '-'), 'yyyy-M-d', [Globalization.CultureInfo]::InvariantCulture)
  return [PSCustomObject]@{ start = $start.ToString('yyyy-MM-dd'); end = $end.ToString('yyyy-MM-dd') }
}

function Convert-ToBase64Url {
  param([byte[]]$Bytes)
  return [Convert]::ToBase64String($Bytes).TrimEnd('=').Replace('+', '-').Replace('/', '_')
}

function Get-AccessToken {
  if (-not (Test-Path -LiteralPath $ClientSecretPath -PathType Leaf)) {
    throw "OAuth client JSON not found: $ClientSecretPath. Create a Google Cloud Desktop OAuth client, enable Search Console API, then save its downloaded JSON at this path."
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

$input = Get-Item -LiteralPath $InputZip -ErrorAction Stop
if ($input.Extension -ne '.zip') { throw 'InputZip must be a GSC Performance ZIP.' }
if ([string]::IsNullOrWhiteSpace($StartDate) -or [string]::IsNullOrWhiteSpace($EndDate)) {
  $range = Get-DateRangeFromName -Name $input.Name
  if (-not $range) { throw 'StartDate/EndDate are required when the ZIP filename has no YYYY-MM-DD~YYYY-MM-DD range.' }
  $StartDate = $range.start; $EndDate = $range.end
}
[datetime]::ParseExact($StartDate, 'yyyy-MM-dd', [Globalization.CultureInfo]::InvariantCulture) | Out-Null
[datetime]::ParseExact($EndDate, 'yyyy-MM-dd', [Globalization.CultureInfo]::InvariantCulture) | Out-Null
if ([string]::IsNullOrWhiteSpace($OutputZip)) {
  $inboxDir = Join-Path $PSScriptRoot 'inbox'
  [IO.Directory]::CreateDirectory($inboxDir) | Out-Null
  $OutputZip = Join-Path $inboxDir ($input.BaseName + '-with-query-page.zip')
}
if (Test-Path -LiteralPath $OutputZip) { throw "Output ZIP already exists: $OutputZip" }

$accessToken = Get-AccessToken
$rows = @()
for ($startRow = 0; ; $startRow += 25000) {
  $body = @{ startDate = $StartDate; endDate = $EndDate; dimensions = @('query', 'page'); type = 'web'; rowLimit = 25000; startRow = $startRow; dataState = 'final' } | ConvertTo-Json -Depth 4
  $uri = 'https://www.googleapis.com/webmasters/v3/sites/' + [uri]::EscapeDataString($property) + '/searchAnalytics/query'
  $result = Invoke-RestMethod -Method Post -Uri $uri -Headers @{ Authorization = "Bearer $accessToken" } -ContentType 'application/json' -Body $body
  $batch = @($result.rows)
  foreach ($row in $batch) {
    $rows += [PSCustomObject]@{ query = [string]$row.keys[0]; page = [string]$row.keys[1]; clicks = $row.clicks; impressions = $row.impressions; ctr = ('{0:0.########}% ' -f ([double]$row.ctr * 100)).Trim(); position = $row.position }
  }
  if ($batch.Count -lt 25000) { break }
}
if ($rows.Count -eq 0) { throw "Search Console API returned no Query × Page rows for $StartDate to $EndDate." }

$tempDir = Join-Path ([IO.Path]::GetTempPath()) ('gsc-query-page-' + [guid]::NewGuid().ToString('N'))
try {
  Expand-Archive -LiteralPath $input.FullName -DestinationPath $tempDir -Force
  $rows | Export-Csv -LiteralPath (Join-Path $tempDir 'query-page.csv') -NoTypeInformation -Encoding UTF8
  Compress-Archive -Path (Join-Path $tempDir '*') -DestinationPath $OutputZip -CompressionLevel Optimal
} finally {
  if (Test-Path -LiteralPath $tempDir) { Remove-Item -LiteralPath $tempDir -Recurse -Force }
}
Write-Host "Created Query × Page ZIP: $OutputZip"
Write-Host "Rows: $($rows.Count) / property: $property / date range: $StartDate to $EndDate"
