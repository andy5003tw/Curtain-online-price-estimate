[CmdletBinding()]
param(
  [Parameter(Mandatory = $true)][string]$RuntimeRoot,
  [ValidateSet('Inspect', 'Write')][string]$Mode = 'Inspect',
  [string]$OutputPath = ''
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Read-Json([string]$Path) {
  if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { return $null }
  Get-Content -LiteralPath $Path -Raw -Encoding UTF8 | ConvertFrom-Json
}

function Get-Sha256([string]$Path) { (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant() }
function Get-StringSet([object[]]$Values) { @($Values | ForEach-Object { ([string]$_).Trim() } | Where-Object { $_ } | Sort-Object -Unique) }
function Test-SameSet([object[]]$Left, [object[]]$Right) {
  $a = @(Get-StringSet $Left); $b = @(Get-StringSet $Right)
  $a.Count -eq $b.Count -and @($a | Where-Object { $_ -notin $b }).Count -eq 0
}
function Write-JsonAtomic([string]$Path, [object]$Value) {
  $folder = Split-Path -Parent $Path
  if (-not (Test-Path -LiteralPath $folder)) { New-Item -ItemType Directory -Path $folder -Force | Out-Null }
  $temp = "$Path.tmp.$([guid]::NewGuid().ToString('N'))"
  try {
    [System.IO.File]::WriteAllText($temp, ($Value | ConvertTo-Json -Depth 20) + [Environment]::NewLine, [System.Text.UTF8Encoding]::new($false))
    [System.IO.File]::Move($temp, $Path, $true)
  } finally { if (Test-Path -LiteralPath $temp) { Remove-Item -LiteralPath $temp -Force -ErrorAction SilentlyContinue } }
}

$root = (Resolve-Path -LiteralPath $RuntimeRoot).Path
$weeklyRoot = if (Test-Path -LiteralPath (Join-Path $root 'latest\seo-geo-action-queue-state.json')) { $root } elseif (Test-Path -LiteralPath (Join-Path $root 'Weekly SOP\latest\seo-geo-action-queue-state.json')) { Join-Path $root 'Weekly SOP' } else { throw "Queue state not found under RuntimeRoot: $root" }
$repoRoot = Split-Path -Parent $weeklyRoot
$latestRoot = Join-Path $weeklyRoot 'latest'
$queue = Read-Json (Join-Path $latestRoot 'seo-geo-action-queue.json')
$state = Read-Json (Join-Path $latestRoot 'seo-geo-action-queue-state.json')
$receiptPath = Join-Path $latestRoot 'seo-geo-validation-receipt.json'
$receipt = Read-Json $receiptPath
if (-not $queue -or -not $state -or -not $receipt) { throw 'Queue、state 或 validation receipt 缺失。' }
if ([string]$state.status -ne 'local_validated') { throw "Deploy plan only permits local_validated; current=$($state.status)" }
if ([string]$queue.queue_id -ne [string]$state.queue_id -or [string]$queue.cycle_key -ne [string]$state.cycle_key) { throw 'Queue/state identity mismatch.' }
if ([string]$receipt.status -ne 'passed' -or [string]$receipt.queue_id -ne [string]$state.queue_id -or [string]$receipt.cycle_key -ne [string]$state.cycle_key) { throw 'Validation receipt is not a passed receipt for the current queue.' }
$queueActionIds = @(Get-StringSet @($queue.rounds | ForEach-Object { @($_.action_ids) }))
$receiptActionIds = @(Get-StringSet @($receipt.action_ids))
if ($queueActionIds.Count -eq 0 -or $receiptActionIds.Count -eq 0 -or @($receiptActionIds | Where-Object { $_ -notin $queueActionIds }).Count) { throw 'Validation receipt action IDs are not bound to the approved queue.' }

$outRoot = Join-Path $repoRoot 'out'
if (-not (Test-Path -LiteralPath $outRoot -PathType Container)) { throw "Static output folder not found: $outRoot. Run the validated build before deployment." }
$allowedFtpHosts = @('ftp.hong-sen.com')
$allowedRemoteRoots = @('online.hong-sen.com')
$ftpHost = [string]$env:FTP_HOST
$remoteRoot = ([string]$env:FTP_REMOTE_DIR).Trim('/')
$preflightReasons = @()
if ($ftpHost -notin $allowedFtpHosts) { $preflightReasons += 'FTP_HOST is missing or not on the production whitelist.' }
if ($remoteRoot -notin $allowedRemoteRoots) { $preflightReasons += 'FTP_REMOTE_DIR is missing or not on the production whitelist.' }

$relativePaths = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
foreach ($target in @($queue.rounds | ForEach-Object { @($_.targets) })) {
  try {
    $uri = [uri][string]$target
    if ($uri.Host.ToLowerInvariant() -ne 'online.hong-sen.com') { throw 'target host is not production' }
    $route = $uri.AbsolutePath.Trim('/')
    $relative = if ($route) { "$route/index.html" } else { 'index.html' }
    [void]$relativePaths.Add($relative)
  } catch { throw "Queue target is not an approved production URL: $target" }
}
foreach ($file in @(Get-ChildItem -LiteralPath (Join-Path $outRoot '_next\static') -Recurse -File -ErrorAction SilentlyContinue)) {
  [void]$relativePaths.Add(([IO.Path]::GetRelativePath($outRoot, $file.FullName) -replace '\\','/'))
}
foreach ($relative in @('robots.txt','sitemap.xml','.htaccess')) {
  if (Test-Path -LiteralPath (Join-Path $outRoot $relative) -PathType Leaf) { [void]$relativePaths.Add($relative) }
}
if ($relativePaths.Count -eq 0) { throw 'Deploy plan did not resolve any approved output files.' }

$files = @()
foreach ($relative in @($relativePaths | Sort-Object)) {
  $safeRelative = $relative.Replace('/',[IO.Path]::DirectorySeparatorChar)
  $fullPath = Join-Path $outRoot $safeRelative
  if (-not (Test-Path -LiteralPath $fullPath -PathType Leaf)) { throw "Approved route output is missing: $relative" }
  if ($relative -match '(^|/)(Weekly SOP|scripts|config|latest|inbox|logs?)(/|$)' -or $relative -match '\.(ps1|cmd|hta|json)$') { throw "Sensitive or non-output path rejected: $relative" }
  $file = Get-Item -LiteralPath $fullPath
  $files += [ordered]@{ relative_path = $relative; sha256 = Get-Sha256 $fullPath; size_bytes = [int64]$file.Length; action_ids = $receiptActionIds }
}

$plan = [ordered]@{
  schema_version = 1
  generated_at = (Get-Date).ToUniversalTime().ToString('o')
  status = if ($preflightReasons.Count) { 'blocked' } else { 'ready' }
  preflight = [ordered]@{ passed = ($preflightReasons.Count -eq 0); reasons = $preflightReasons; allowed_ftp_hosts = $allowedFtpHosts; allowed_remote_roots = $allowedRemoteRoots }
  target_host = 'online.hong-sen.com'
  ftp_host = $ftpHost
  remote_root = $remoteRoot
  output_root = $outRoot
  queue_id = [string]$state.queue_id
  cycle_key = [string]$state.cycle_key
  action_ids = $queueActionIds
  validation_action_ids = $receiptActionIds
  validation_receipt = [ordered]@{ path = 'latest/seo-geo-validation-receipt.json'; sha256 = Get-Sha256 $receiptPath }
  files = $files
}
if ($Mode -eq 'Write') {
  if (-not $OutputPath) { $OutputPath = Join-Path $latestRoot 'seo-geo-deploy-plan.json' }
  if (-not [IO.Path]::IsPathRooted($OutputPath)) { $OutputPath = Join-Path $weeklyRoot $OutputPath }
  Write-JsonAtomic $OutputPath $plan
  $plan['path'] = $OutputPath
}
$plan | ConvertTo-Json -Depth 20 -Compress -EscapeHandling EscapeNonAscii
