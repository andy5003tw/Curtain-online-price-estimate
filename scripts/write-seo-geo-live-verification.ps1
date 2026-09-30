[CmdletBinding()]
param(
  [Parameter(Mandatory = $true)][string]$RuntimeRoot,
  [ValidateSet('queue_targets', 'foundation_sweep')][string]$Scope = 'queue_targets',
  [string]$SiteUrl = 'https://online.hong-sen.com',
  [string]$OutputPath = '',
  [int]$TimeoutSec = 30
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Write-JsonAtomic([string]$Path, [object]$Value) {
  $temp = "$Path.tmp.$([guid]::NewGuid().ToString('N'))"
  try {
    $json = $Value | ConvertTo-Json -Depth 30
    [System.IO.File]::WriteAllText($temp, $json + [Environment]::NewLine, [System.Text.UTF8Encoding]::new($false))
    [System.IO.File]::Move($temp, $Path, $true)
  } finally { if (Test-Path -LiteralPath $temp) { Remove-Item -LiteralPath $temp -Force -ErrorAction SilentlyContinue } }
}
function Get-Sha256([string]$Path) { (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant() }
function Normalize-Url([string]$Value) {
  $uri = [uri]$Value
  $path = $uri.AbsolutePath
  if (-not $path.EndsWith('/')) { $path += '/' }
  return ($uri.Scheme.ToLowerInvariant() + '://' + $uri.Host.ToLowerInvariant() + $path)
}
function Get-Text([string]$Html) { ([regex]::Replace([regex]::Replace($Html, '<script[\s\S]*?</script>|<style[\s\S]*?</style>', ''), '<[^>]+>', ' ') -replace '\s+', ' ').Trim() }
function Get-MatchValue([string]$Html, [string]$Pattern) { $m = [regex]::Match($Html, $Pattern, [Text.RegularExpressions.RegexOptions]::IgnoreCase); if ($m.Success) { return [System.Net.WebUtility]::HtmlDecode($m.Groups[1].Value).Trim() }; return '' }
function Get-Title([string]$Html) { Get-MatchValue $Html '<title[^>]*>([\s\S]*?)</title>' }
function Get-H1([string]$Html) { Get-MatchValue $Html '<h1[^>]*>([\s\S]*?)</h1>' }
function Get-MetaDescription([string]$Html) {
  $m = [regex]::Match($Html, '<meta\b(?=[^>]*\bname\s*=\s*["'']description["''])[^>]*\bcontent\s*=\s*["'']([^"'']+)["''][^>]*>', [Text.RegularExpressions.RegexOptions]::IgnoreCase)
  if (-not $m.Success) { $m = [regex]::Match($Html, '<meta\b(?=[^>]*\bcontent\s*=\s*["'']([^"'']+)["''])[^>]*\bname\s*=\s*["'']description["''][^>]*>', [Text.RegularExpressions.RegexOptions]::IgnoreCase) }
  if ($m.Success) { return [System.Net.WebUtility]::HtmlDecode($m.Groups[1].Value).Trim() }; return ''
}
function Get-Canonical([string]$Html) { Get-MatchValue $Html '<link\b(?=[^>]*\brel\s*=\s*["'']canonical["''])[^>]*\bhref\s*=\s*["'']([^"'']+)["''][^>]*>' }
function Get-Hrefs([string]$Html) { @([regex]::Matches($Html, '<a\b[^>]*\bhref\s*=\s*["'']([^"''#][^"'']*)["'']', [Text.RegularExpressions.RegexOptions]::IgnoreCase) | ForEach-Object { $_.Groups[1].Value }) }
function Get-JsonLd([string]$Html) {
  $values = @()
  foreach ($match in [regex]::Matches($Html, '<script\b[^>]*\btype\s*=\s*["'']application/ld\+json["''][^>]*>([\s\S]*?)</script>', [Text.RegularExpressions.RegexOptions]::IgnoreCase)) {
    try { $values += ($match.Groups[1].Value | ConvertFrom-Json) } catch { throw "JSON-LD parse failed: $($_.Exception.Message)" }
  }
  return $values
}
function Get-SchemaNodes([object]$Value) {
  $nodes = @()
  if ($null -eq $Value) { return $nodes }
  if ($Value -is [System.Collections.IEnumerable] -and -not ($Value -is [string])) { foreach ($item in $Value) { $nodes += Get-SchemaNodes $item }; return $nodes }
  if ($Value.PSObject.Properties.Name -contains '@graph') { $nodes += Get-SchemaNodes $Value.'@graph' }
  $nodes += $Value
  return $nodes
}
function Test-FAQParity([string]$Html) {
  try { $nodes = @(Get-JsonLd $Html | ForEach-Object { Get-SchemaNodes $_ }) } catch { return [ordered]@{ passed = $false; reason = $_.Exception.Message; count = 0 } }
  $faq = @($nodes | Where-Object { $_ -and $_.PSObject.Properties.Name -contains '@type' -and [string]$_.'@type' -eq 'FAQPage' })
  if ($faq.Count -ne 1) { return [ordered]@{ passed = $false; reason = 'FAQPage schema missing or duplicated'; count = 0 } }
  $entities = @($faq[0].mainEntity)
  if ($entities.Count -lt 3 -or $entities.Count -gt 5) { return [ordered]@{ passed = $false; reason = 'FAQ count must be 3-5'; count = $entities.Count } }
  $text = Get-Text $Html
  foreach ($entry in $entities) {
    $question = [string]$entry.name; $answer = [string]$entry.acceptedAnswer.text
    if ([string]::IsNullOrWhiteSpace($question) -or [string]::IsNullOrWhiteSpace($answer) -or -not $text.Contains($question) -or -not $text.Contains($answer)) { return [ordered]@{ passed = $false; reason = 'FAQ schema question/answer is not visible'; count = $entities.Count } }
  }
  return [ordered]@{ passed = $true; reason = $null; count = $entities.Count }
}
function Get-Response([string]$Uri, [switch]$NoRedirect) {
  $tempPath = Join-Path ([System.IO.Path]::GetTempPath()) ('seo-geo-live-' + [guid]::NewGuid().ToString('N') + '.tmp')
  try {
    if (-not (Get-Command curl.exe -ErrorAction SilentlyContinue)) { throw 'curl.exe is required for live verification transport.' }
    $maxRedirs = if ($NoRedirect) { '0' } else { '5' }
    $curlArgs = @('-sS', '--max-time', [string]$TimeoutSec, '--max-redirs', $maxRedirs, '-L', '-o', $tempPath, '-w', "`n%{http_code}`n%{url_effective}", $Uri)
    $output = @(& curl.exe @curlArgs 2>&1)
    if ($LASTEXITCODE -ne 0) { throw ($output -join ' ') }
    $lines = @($output | ForEach-Object { [string]$_ } | Where-Object { $_ -ne '' })
    $status = if ($lines.Count -ge 2) { [int]$lines[$lines.Count - 2] } else { 0 }
    $finalUrl = if ($lines.Count -ge 1) { $lines[$lines.Count - 1] } else { $Uri }
    $content = if (Test-Path -LiteralPath $tempPath) { Get-Content -LiteralPath $tempPath -Raw -Encoding UTF8 } else { '' }
    return [pscustomobject]@{ status = $status; content = $content; headers = @{}; final_url = $finalUrl; error = $null }
  } catch {
    return [pscustomobject]@{ status = 0; content = ''; headers = @{}; final_url = $Uri; error = $_.Exception.Message }
  } finally { if (Test-Path -LiteralPath $tempPath) { Remove-Item -LiteralPath $tempPath -Force -ErrorAction SilentlyContinue } }
}
function Test-RedirectContract([string]$LegacyUrl, [string]$TargetUrl, [string]$ProductId) {
  $bodyPath = Join-Path ([System.IO.Path]::GetTempPath()) ('seo-geo-redirect-body-' + [guid]::NewGuid().ToString('N') + '.tmp')
  $headerPath = Join-Path ([System.IO.Path]::GetTempPath()) ('seo-geo-redirect-header-' + [guid]::NewGuid().ToString('N') + '.tmp')
  try {
    if (-not (Get-Command curl.exe -ErrorAction SilentlyContinue)) { throw 'curl.exe is required for redirect verification.' }
    $output = @(& curl.exe '-sS' '--max-time' ([string]$TimeoutSec) '-o' $bodyPath '-D' $headerPath '-w' '%{http_code}' $LegacyUrl 2>&1)
    $status = if ($LASTEXITCODE -eq 0 -and $output.Count) { [int]($output[-1] -replace '[^0-9]', '') } else { 0 }
    $headers = if (Test-Path -LiteralPath $headerPath) { Get-Content -LiteralPath $headerPath -Raw -Encoding UTF8 } else { '' }
    $match = [regex]::Match($headers, '(?im)^Location:\s*([^\r\n]+)')
    $location = if ($match.Success) { $match.Groups[1].Value.Trim() } else { '' }
    $resolved = if ($location) { ([uri]::new([uri]$LegacyUrl, $location)).AbsoluteUri } else { '' }
    $passed = $status -in @(301, 308) -and $resolved -and (Normalize-Url $resolved) -eq (Normalize-Url $TargetUrl)
    return [ordered]@{
      product_id = $ProductId
      legacy_url = $LegacyUrl
      target_url = $TargetUrl
      status_code = $status
      location = $location
      passed = [bool]$passed
      evidence = "status=$status; location=$location"
    }
  } catch {
    return [ordered]@{ product_id = $ProductId; legacy_url = $LegacyUrl; target_url = $TargetUrl; status_code = 0; location = ''; passed = $false; evidence = $_.Exception.Message }
  } finally {
    foreach ($path in @($bodyPath, $headerPath)) { if (Test-Path -LiteralPath $path) { Remove-Item -LiteralPath $path -Force -ErrorAction SilentlyContinue } }
  }
}
function Test-PageContract([string]$Url, [string]$ExpectedLocalPath, [string[]]$SitemapUrls) {
  $response = Get-Response -Uri $Url
  $checks = @(); $html = [string]$response.content
  $checks += [ordered]@{ name = 'http'; passed = ($response.status -eq 200); evidence = "status=$($response.status)" }
  if ($response.status -eq 200) {
    $localHtml = if ($ExpectedLocalPath -and (Test-Path -LiteralPath $ExpectedLocalPath -PathType Leaf)) { Get-Content -LiteralPath $ExpectedLocalPath -Raw -Encoding UTF8 } else { '' }
    $title = Get-Title $html; $meta = Get-MetaDescription $html; $h1 = Get-H1 $html; $canonical = Get-Canonical $html
    $checks += [ordered]@{ name = 'title'; passed = (-not [string]::IsNullOrWhiteSpace($title) -and (-not $localHtml -or $title -eq (Get-Title $localHtml))); evidence = $title }
    $checks += [ordered]@{ name = 'meta_description'; passed = (-not [string]::IsNullOrWhiteSpace($meta) -and (-not $localHtml -or $meta -eq (Get-MetaDescription $localHtml))); evidence = $meta }
    $checks += [ordered]@{ name = 'h1'; passed = (-not [string]::IsNullOrWhiteSpace($h1) -and (-not $localHtml -or $h1 -eq (Get-H1 $localHtml))); evidence = $h1 }
    $checks += [ordered]@{ name = 'canonical'; passed = ((Normalize-Url $canonical) -eq (Normalize-Url $Url)); evidence = $canonical }
    $faq = Test-FAQParity $html; $checks += [ordered]@{ name = 'faq_parity'; passed = [bool]$faq.passed; evidence = "count=$($faq.count); $($faq.reason)" }
    try { $jsonLdCount = @(Get-JsonLd $html).Count; $checks += [ordered]@{ name = 'json_ld'; passed = ($jsonLdCount -gt 0); evidence = "scripts=$jsonLdCount" } } catch { $checks += [ordered]@{ name = 'json_ld'; passed = $false; evidence = $_.Exception.Message } }
    $hrefs = Get-Hrefs $html
    $internal = @($hrefs | Where-Object { $_ -match '^/' -or $_ -match '^https://online\.hong-sen\.com/' })
    $invalidInternal = @()
    foreach ($href in $internal) {
      try {
        $resolved = Normalize-Url ([uri]::new([uri]$Url, $href).AbsoluteUri)
        if ($resolved -notin $SitemapUrls) { $invalidInternal += $href }
      } catch { $invalidInternal += $href }
    }
    $checks += [ordered]@{ name = 'internal_links'; passed = ($internal.Count -gt 0 -and $invalidInternal.Count -eq 0); evidence = "count=$($internal.Count); unresolved=$($invalidInternal.Count)" }
    $checks += [ordered]@{ name = 'cta'; passed = (@($hrefs | Where-Object { $_ -match '^/calculator/|^https://online\.hong-sen\.com/calculator/' }).Count -gt 0); evidence = 'calculator link required' }
    $robotMeta = Get-MatchValue $html '<meta\b(?=[^>]*\bname\s*=\s*["'']robots["''])[^>]*\bcontent\s*=\s*["'']([^"'']+)["''][^>]*>'
    $checks += [ordered]@{ name = 'robots'; passed = ($robotMeta -notmatch '(?i)noindex'); evidence = if ($robotMeta) { $robotMeta } else { 'no restrictive meta robots' } }
    $checks += [ordered]@{ name = 'sitemap'; passed = ((Normalize-Url $Url) -in $SitemapUrls); evidence = 'semantic URL present in live sitemap' }
  }
  return [ordered]@{ url = $Url; status_code = $response.status; checks = $checks; passed = (@($checks | Where-Object { -not $_.passed }).Count -eq 0) }
}

$root = (Resolve-Path -LiteralPath $RuntimeRoot).Path
$weeklyRoot = if (Test-Path -LiteralPath (Join-Path $root 'latest\seo-geo-action-queue-state.json')) { $root } elseif (Test-Path -LiteralPath (Join-Path $root 'Weekly SOP\latest\seo-geo-action-queue-state.json')) { Join-Path $root 'Weekly SOP' } else { throw "Queue state not found under RuntimeRoot: $root" }
$repoRoot = Split-Path -Parent $PSScriptRoot
$latestRoot = Join-Path $weeklyRoot 'latest'
$queue = Get-Content -LiteralPath (Join-Path $latestRoot 'seo-geo-action-queue.json') -Raw -Encoding UTF8 | ConvertFrom-Json
$state = Get-Content -LiteralPath (Join-Path $latestRoot 'seo-geo-action-queue-state.json') -Raw -Encoding UTF8 | ConvertFrom-Json
$site = $SiteUrl.TrimEnd('/')
$robots = Get-Response -Uri "$site/robots.txt"
$sitemap = Get-Response -Uri "$site/sitemap.xml"
$sitemapUrls = @()
if ($sitemap.status -eq 200) { $sitemapUrls = @([regex]::Matches($sitemap.content, '<loc>\s*(.*?)\s*</loc>', [Text.RegularExpressions.RegexOptions]::IgnoreCase) | ForEach-Object { Normalize-Url $_.Groups[1].Value } | Sort-Object -Unique) }
$globalChecks = @(
  [ordered]@{ name = 'robots_txt'; passed = ($robots.status -eq 200 -and $robots.content -match '(?im)^Sitemap:\s*https://online\.hong-sen\.com/sitemap\.xml'); evidence = "status=$($robots.status)" },
  [ordered]@{ name = 'sitemap_xml'; passed = ($sitemap.status -eq 200 -and $sitemapUrls.Count -gt 0); evidence = "status=$($sitemap.status); urls=$($sitemapUrls.Count)" }
)

if ($Scope -eq 'queue_targets') {
  $targets = @($queue.rounds | ForEach-Object { @($_.targets) } | Sort-Object -Unique)
  if ($targets.Count -eq 0) { throw 'Queue live verification requires executable target pages.' }
  $pages = @()
  foreach ($target in $targets) {
    $route = ([uri]$target).AbsolutePath.Trim('/')
    $localPath = Join-Path $repoRoot ('out\' + ($route -replace '/', '\') + '\index.html')
    $pages += Test-PageContract -Url $target -ExpectedLocalPath $localPath -SitemapUrls $sitemapUrls
  }
  $redirectChecks = @()
  $owners = if ($queue.provenance -and $queue.provenance.registry) { @($queue.provenance.registry.owners) } else { @($queue.registry.owners) }
  foreach ($owner in $owners) {
    $match = [regex]::Match([string]$owner.cluster_id, '^product-(P\d+)$')
    if (-not $match.Success -or [string]$owner.owner_url -notin $targets) { continue }
    $productId = $match.Groups[1].Value
    $legacyUrl = "$site/products/$productId/"
    $redirectChecks += Test-RedirectContract -LegacyUrl $legacyUrl -TargetUrl ([string]$owner.owner_url) -ProductId $productId
  }
  $result = [ordered]@{
    schema_version = 1; status = if ((@($globalChecks | Where-Object { -not $_.passed }).Count -eq 0) -and (@($pages | Where-Object { -not $_.passed }).Count -eq 0) -and (@($redirectChecks | Where-Object { -not $_.passed }).Count -eq 0)) { 'passed' } else { 'failed' }
    scope = 'queue_targets'; verified_at = (Get-Date).ToUniversalTime().ToString('o'); host = 'online.hong-sen.com'
    queue_id = [string]$state.queue_id; cycle_key = [string]$state.cycle_key; action_ids = @($queue.rounds | ForEach-Object { @($_.action_ids) } | Sort-Object -Unique)
    global_checks = $globalChecks; pages = $pages; redirect_checks = $redirectChecks
  }
  if (-not $OutputPath) { $OutputPath = Join-Path $latestRoot 'seo-geo-live-verification.json' }
} else {
  $pages = @(); $allInternal = @()
  foreach ($url in $sitemapUrls) {
    $page = Test-PageContract -Url $url -ExpectedLocalPath '' -SitemapUrls $sitemapUrls
    $page.checks = @($page.checks | Where-Object { $_.name -notin @('faq_parity','cta') })
    $page.passed = (@($page.checks | Where-Object { -not $_.passed }).Count -eq 0)
    $pages += $page
  }
  $result = [ordered]@{
    schema_version = 1; status = if ((@($globalChecks | Where-Object { -not $_.passed }).Count -eq 0) -and (@($pages | Where-Object { -not $_.passed }).Count -eq 0)) { 'passed' } else { 'failed' }
    scope = 'foundation_sweep'; verified_at = (Get-Date).ToUniversalTime().ToString('o'); host = 'online.hong-sen.com'
    page_count = $pages.Count; global_checks = $globalChecks; pages = $pages
  }
  if (-not $OutputPath) { $OutputPath = Join-Path $latestRoot 'foundation-sweep-live-audit.json' }
}
Write-JsonAtomic -Path $OutputPath -Value $result
[pscustomobject]@{ status = $result.status; scope = $Scope; output_path = $OutputPath; sha256 = Get-Sha256 $OutputPath; pages = @($result.pages).Count } | ConvertTo-Json -Compress
if ($result.status -ne 'passed') { exit 1 }
