#requires -Version 7.0
[CmdletBinding()]
param(
  [ValidateSet('quick', 'all', 'paths')]
  [string]$Mode = 'quick',

  [string]$LocalRoot = 'out',
  [string]$HostName = '',
  [string]$RemoteRoot = '',
  [string]$UserName = '',
  [string]$Password = '',

  [string[]]$Path = @(),
  [string]$PathFile = '',

  [switch]$DryRun,
  [switch]$Force,

  [int]$Retries = 2,
  [int]$TimeoutSec = 60
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if (-not $HostName) { $HostName = if ($env:FTP_HOST) { $env:FTP_HOST } else { 'ftp.hong-sen.com' } }
if (-not $RemoteRoot) { $RemoteRoot = if ($env:FTP_REMOTE_DIR) { $env:FTP_REMOTE_DIR } else { 'online.hong-sen.com' } }
if (-not $UserName) { $UserName = $env:FTP_USER }
if (-not $Password) {
  $Password = if ($env:FTP_PASS) { $env:FTP_PASS } else { $env:FTP_PASSWORD }
}

$resolvedRoot = Resolve-Path -LiteralPath $LocalRoot
$rootPath = $resolvedRoot.Path
$remoteRootTrimmed = ($RemoteRoot -replace '\\', '/').Trim('/')
$timeoutMs = [Math]::Max(5, $TimeoutSec) * 1000
$credential = $null

if (-not $DryRun) {
  if (-not $UserName -or -not $Password) {
    throw 'FTP_USER and FTP_PASS environment variables are required unless -DryRun is used.'
  }

  $credential = [System.Net.NetworkCredential]::new($UserName, $Password)
}

function ConvertTo-RelativePath {
  param([System.IO.FileInfo]$File)

  return ([System.IO.Path]::GetRelativePath($rootPath, $File.FullName) -replace '\\', '/')
}

function ConvertTo-FtpPath {
  param([string]$PathValue)

  return (($PathValue -replace '\\', '/') -split '/' |
    Where-Object { $_ -ne '' } |
    ForEach-Object { [Uri]::EscapeDataString($_) }) -join '/'
}

function New-FtpRequest {
  param(
    [string]$RelativePath,
    [string]$Method
  )

  $encodedPath = ConvertTo-FtpPath "$remoteRootTrimmed/$RelativePath"
  $request = [System.Net.FtpWebRequest]::Create("ftp://$HostName/$encodedPath")
  $request.Method = $Method
  $request.Credentials = $credential
  $request.UseBinary = $true
  $request.UsePassive = $true
  $request.KeepAlive = $false
  $request.Timeout = $timeoutMs
  $request.ReadWriteTimeout = $timeoutMs
  return $request
}

$script:createdDirs = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)

function New-RemoteDirectory {
  param([string]$RelativeDir)

  if ([string]::IsNullOrWhiteSpace($RelativeDir)) { return }

  $current = ''
  foreach ($part in (($RelativeDir -replace '\\', '/') -split '/')) {
    if ([string]::IsNullOrWhiteSpace($part)) { continue }

    $current = if ($current) { "$current/$part" } else { $part }
    if (-not $script:createdDirs.Add($current)) { continue }

    $request = New-FtpRequest -RelativePath $current -Method ([System.Net.WebRequestMethods+Ftp]::MakeDirectory)
    try {
      $response = $request.GetResponse()
      $response.Close()
    } catch [System.Net.WebException] {
      if ($_.Exception.Response) { $_.Exception.Response.Close() }
    }
  }
}

function Get-RemoteFileSize {
  param([string]$RelativePath)

  $request = New-FtpRequest -RelativePath $RelativePath -Method ([System.Net.WebRequestMethods+Ftp]::GetFileSize)
  try {
    $response = $request.GetResponse()
    $size = $response.ContentLength
    $response.Close()
    return $size
  } catch [System.Net.WebException] {
    if ($_.Exception.Response) { $_.Exception.Response.Close() }
    return $null
  }
}

function Send-FtpFile {
  param(
    [System.IO.FileInfo]$File,
    [string]$RelativePath
  )

  $dir = Split-Path -Path $RelativePath -Parent
  New-RemoteDirectory -RelativeDir ($dir -replace '\\', '/')

  $attempt = 0
  while ($true) {
    try {
      $request = New-FtpRequest -RelativePath $RelativePath -Method ([System.Net.WebRequestMethods+Ftp]::UploadFile)
      $request.ContentLength = $File.Length

      $inputStream = [System.IO.File]::OpenRead($File.FullName)
      try {
        $outputStream = $request.GetRequestStream()
        try {
          $buffer = New-Object byte[] 65536
          while (($read = $inputStream.Read($buffer, 0, $buffer.Length)) -gt 0) {
            $outputStream.Write($buffer, 0, $read)
          }
        } finally {
          $outputStream.Close()
        }
      } finally {
        $inputStream.Close()
      }

      $response = $request.GetResponse()
      $response.Close()
      return
    } catch {
      $attempt += 1
      if ($attempt -gt $Retries) { throw }
      Start-Sleep -Seconds ([Math]::Min(10, 2 * $attempt))
    }
  }
}

function Get-QuickFiles {
  return Get-ChildItem -LiteralPath $rootPath -Recurse -File | Where-Object {
    $relative = ConvertTo-RelativePath $_
    $relative -like '_next/static/*' -or
      $relative -like '*.html' -or
      $relative -like '*.txt' -or
      $relative -like '*.xml' -or
      $relative -eq 'robots.txt' -or
      $relative -eq '.htaccess'
  }
}

function Resolve-DeployPath {
  param([string]$InputPath)

  $normalized = ($InputPath.Trim() -replace '\\', '/').TrimStart('/')
  if (-not $normalized) { return @() }

  $candidate = Join-Path $rootPath ($normalized -replace '/', [IO.Path]::DirectorySeparatorChar)
  if (Test-Path -LiteralPath $candidate -PathType Leaf) {
    return @(Get-Item -LiteralPath $candidate)
  }

  if (Test-Path -LiteralPath $candidate -PathType Container) {
    $indexFile = Join-Path $candidate 'index.html'
    if (Test-Path -LiteralPath $indexFile -PathType Leaf) {
      return @(Get-Item -LiteralPath $indexFile)
    }

    return @(Get-ChildItem -LiteralPath $candidate -Recurse -File)
  }

  $routeFile = Join-Path $rootPath (($normalized.TrimEnd('/') + '/index.html') -replace '/', [IO.Path]::DirectorySeparatorChar)
  if (Test-Path -LiteralPath $routeFile -PathType Leaf) {
    return @(Get-Item -LiteralPath $routeFile)
  }

  throw "Deploy path not found under ${LocalRoot}: $InputPath"
}

$selectedFiles = switch ($Mode) {
  'quick' { @(Get-QuickFiles) }
  'all' { @(Get-ChildItem -LiteralPath $rootPath -Recurse -File) }
  'paths' {
    $inputs = @()
    if ($PathFile) {
      if (-not (Test-Path -LiteralPath $PathFile -PathType Leaf)) {
        throw "Path file not found: $PathFile"
      }

      $inputs += Get-Content -LiteralPath $PathFile |
        ForEach-Object { $_.Trim() } |
        Where-Object { $_ -and -not $_.StartsWith('#') }
    }

    $inputs += $Path
    $inputs = @(
      foreach ($inputValue in $inputs) {
        ($inputValue -split ',') |
          ForEach-Object { $_.Trim() } |
          Where-Object { $_ }
      }
    )
    if (-not $inputs) {
      throw 'Mode paths requires -Path or -PathFile.'
    }

    @($inputs | ForEach-Object { Resolve-DeployPath $_ })
  }
}

$fileMap = [ordered]@{}
foreach ($file in $selectedFiles) {
  $relative = ConvertTo-RelativePath $file
  $fileMap[$relative] = $file
}

$items = @(
  foreach ($key in ($fileMap.Keys | Sort-Object)) {
    [pscustomobject]@{
      RelativePath = $key
      File = $fileMap[$key]
    }
  }
)

Write-Host "FTP deploy mode: $Mode"
Write-Host "Local root: $rootPath"
Write-Host "Remote root: ftp://$HostName/$remoteRootTrimmed"
Write-Host "Files selected: $($items.Count)"
Write-Host "Dry run: $($DryRun.IsPresent)"
Write-Host "Force upload: $($Force.IsPresent)"

$uploaded = 0
$skipped = 0
$failed = 0
$bytesUploaded = [int64]0
$total = $items.Count
$index = 0

foreach ($item in $items) {
  $index += 1
  $file = [System.IO.FileInfo]$item.File
  $relative = [string]$item.RelativePath
  $sizeKb = [Math]::Round($file.Length / 1KB, 1)
  $prefix = "[{0}/{1}]" -f $index, $total

  if ($DryRun) {
    Write-Host "$prefix would upload $relative ($sizeKb KB)"
    continue
  }

  if (-not $Force) {
    $remoteSize = Get-RemoteFileSize -RelativePath $relative
    if ($null -ne $remoteSize -and [int64]$remoteSize -eq [int64]$file.Length) {
      $skipped += 1
      Write-Host "$prefix skip $relative ($sizeKb KB, same remote size)"
      continue
    }
  }

  try {
    Send-FtpFile -File $file -RelativePath $relative
    $uploaded += 1
    $bytesUploaded += $file.Length
    Write-Host "$prefix uploaded $relative ($sizeKb KB)"
  } catch {
    $failed += 1
    Write-Warning "$prefix failed $relative - $($_.Exception.Message)"
  }
}

Write-Host ("Summary: uploaded={0}, skipped={1}, failed={2}, uploadedMB={3}" -f $uploaded, $skipped, $failed, [Math]::Round($bytesUploaded / 1MB, 2))

if ($failed -gt 0) {
  throw "$failed file(s) failed to upload."
}
