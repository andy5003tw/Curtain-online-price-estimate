param()

$ErrorActionPreference = 'Stop'
$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$temporaryRoot = [IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd([IO.Path]::DirectorySeparatorChar) + [IO.Path]::DirectorySeparatorChar
$testRoot = Join-Path $temporaryRoot ('hs-pricing-test-' + [guid]::NewGuid().ToString('N'))
$resolvedTestRoot = [IO.Path]::GetFullPath($testRoot)
if (-not $resolvedTestRoot.StartsWith($temporaryRoot, [StringComparison]::OrdinalIgnoreCase)) {
  throw 'Test directory is outside the temporary directory.'
}

function Get-Csrf([string]$html) {
  $match = [regex]::Match($html, 'name="csrf_token" value="([a-f0-9]+)"')
  if (-not $match.Success) { throw 'CSRF token not found.' }
  return $match.Groups[1].Value
}

function Assert-True([bool]$condition, [string]$message) {
  if (-not $condition) { throw $message }
}

$server = $null
try {
  foreach ($directory in @('admin/pricing', 'api', 'private/lib', 'private/runtime', 'private/backups', 'private/logs')) {
    New-Item -ItemType Directory -Path (Join-Path $testRoot $directory) -Force | Out-Null
  }
  Copy-Item -Path (Join-Path $repoRoot 'admin/pricing/*.php') -Destination (Join-Path $testRoot 'admin/pricing')
  Copy-Item -Path (Join-Path $repoRoot 'api/*.php') -Destination (Join-Path $testRoot 'api')
  Copy-Item -Path (Join-Path $repoRoot 'private/lib/*.php') -Destination (Join-Path $testRoot 'private/lib')
  Copy-Item -LiteralPath (Join-Path $repoRoot 'private/pricing-rules.php') -Destination (Join-Path $testRoot 'private/pricing-rules.php')

  $port = Get-Random -Minimum 20000 -Maximum 40000
  $baseUrl = "http://127.0.0.1:$port"
  $server = Start-Process -FilePath 'php' -ArgumentList @('-S', "127.0.0.1:$port", '-t', '.') -WorkingDirectory $testRoot -WindowStyle Hidden -PassThru
  $ready = $false
  for ($attempt = 0; $attempt -lt 30; $attempt++) {
    try {
      Invoke-WebRequest -Uri "$baseUrl/admin/pricing/login.php" -UseBasicParsing | Out-Null
      $ready = $true
      break
    } catch {
      Start-Sleep -Milliseconds 200
    }
  }
  Assert-True $ready 'PHP test server did not start.'

  $webSession = [Microsoft.PowerShell.Commands.WebRequestSession]::new()
  $login = Invoke-WebRequest -Uri "$baseUrl/admin/pricing/login.php" -WebSession $webSession -UseBasicParsing
  $csrf = Get-Csrf $login.Content
  $password = 'Test-' + [guid]::NewGuid().ToString('N')
  Invoke-WebRequest -Uri "$baseUrl/admin/pricing/login.php" -Method Post -WebSession $webSession -Body @{ csrf_token=$csrf; action='bootstrap'; username='test_owner'; password=$password; confirm_password=$password } -UseBasicParsing | Out-Null
  $login = Invoke-WebRequest -Uri "$baseUrl/admin/pricing/login.php" -WebSession $webSession -UseBasicParsing
  $csrf = Get-Csrf $login.Content
  $dashboard = Invoke-WebRequest -Uri "$baseUrl/admin/pricing/login.php" -Method Post -WebSession $webSession -Body @{ csrf_token=$csrf; action='login'; username='test_owner'; password=$password } -UseBasicParsing
  Assert-True ($dashboard.Content -match '新增試算產品') 'Owner dashboard did not load.'

  $newPage = Invoke-WebRequest -Uri "$baseUrl/admin/pricing/new.php?formula_type=area_based" -WebSession $webSession -UseBasicParsing
  $csrf = Get-Csrf $newPage.Content
  $previewBody = @{
    csrf_token=$csrf; action='preview'; formula_type='area_based'; display_name='測試新產品';
    price_unit_price='100'; price_labor_per_tai='13'; param_min_per_tai='12'; param_min_install_tai='20';
    param_round_tai='ceil'; param_round_material='nearest'; param_round_install='nearest';
    width_cm='150'; height_cm='150'
  }
  $preview = Invoke-WebRequest -Uri "$baseUrl/admin/pricing/new.php" -Method Post -WebSession $webSession -Body $previewBody -UseBasicParsing
  Assert-True ($preview.Content -match '建立產品草稿') 'New product preview failed.'
  $created = Invoke-WebRequest -Uri "$baseUrl/admin/pricing/new.php" -Method Post -WebSession $webSession -Body @{ csrf_token=$csrf; action='create' } -UseBasicParsing
  Assert-True ($created.Content -match 'P014') 'Draft product was not created.'

  $catalog = (Invoke-RestMethod -Uri "$baseUrl/api/products.php" -Method Get)
  Assert-True (-not @($catalog.data.id).Contains('P014')) 'Draft product appeared in public catalog.'

  $formulaPage = Invoke-WebRequest -Uri "$baseUrl/admin/pricing/formula.php?product_id=P014" -WebSession $webSession -UseBasicParsing
  $csrf = Get-Csrf $formulaPage.Content
  $formulaPreview = Invoke-WebRequest -Uri "$baseUrl/admin/pricing/formula.php" -Method Post -WebSession $webSession -Body @{
    csrf_token=$csrf; product_id='P014'; action='preview'; width_cm='150'; height_cm='150';
    param_min_per_tai='12'; param_min_install_tai='20'; param_round_tai='ceil';
    param_round_material='nearest'; param_round_install='nearest'
  } -UseBasicParsing
  Assert-True ($formulaPreview.Content -match '上架產品') 'Draft formula preview did not enable publishing.'
  Invoke-WebRequest -Uri "$baseUrl/admin/pricing/formula.php" -Method Post -WebSession $webSession -Body @{ csrf_token=$csrf; product_id='P014'; action='publish' } -UseBasicParsing | Out-Null
  $catalog = (Invoke-RestMethod -Uri "$baseUrl/api/products.php" -Method Get)
  Assert-True (@($catalog.data.id).Contains('P014')) 'Published product missing from public catalog.'
  $quote = Invoke-RestMethod -Uri "$baseUrl/api/calc.php" -Method Post -ContentType 'application/json' -Body '{"product_id":"P014","width_cm":150,"height_cm":150}'
  Assert-True ($quote.ok -and $quote.data.total_price -eq 2825) 'Published product quote is incorrect.'

  $formulaPage = Invoke-WebRequest -Uri "$baseUrl/admin/pricing/formula.php?product_id=P014" -WebSession $webSession -UseBasicParsing
  $csrf = Get-Csrf $formulaPage.Content
  $changedPreview = Invoke-WebRequest -Uri "$baseUrl/admin/pricing/formula.php" -Method Post -WebSession $webSession -Body @{
    csrf_token=$csrf; product_id='P014'; action='preview'; width_cm='150'; height_cm='150';
    param_min_per_tai='40'; param_min_install_tai='20'; param_round_tai='ceil';
    param_round_material='nearest'; param_round_install='nearest'
  } -UseBasicParsing
  Assert-True ($changedPreview.Content -match '4,325') 'Formula preview did not show the new total.'
  Invoke-WebRequest -Uri "$baseUrl/admin/pricing/formula.php" -Method Post -WebSession $webSession -Body @{ csrf_token=$csrf; product_id='P014'; action='save' } -UseBasicParsing | Out-Null
  $quote = Invoke-RestMethod -Uri "$baseUrl/api/calc.php" -Method Post -ContentType 'application/json' -Body '{"product_id":"P014","width_cm":150,"height_cm":150}'
  Assert-True ($quote.data.total_price -eq 4325) 'Saved formula did not affect the public quote.'

  Invoke-WebRequest -Uri "$baseUrl/admin/pricing/formula.php" -Method Post -WebSession $webSession -Body @{ csrf_token=$csrf; product_id='P014'; action='unpublish' } -UseBasicParsing | Out-Null
  $catalog = (Invoke-RestMethod -Uri "$baseUrl/api/products.php" -Method Get)
  Assert-True (-not @($catalog.data.id).Contains('P014')) 'Unpublished product remained in public catalog.'
  $notFound = $false
  try {
    Invoke-WebRequest -Uri "$baseUrl/api/calc.php" -Method Post -ContentType 'application/json' -Body '{"product_id":"P014","width_cm":150,"height_cm":150}' -UseBasicParsing | Out-Null
  } catch {
    $notFound = $_.Exception.Response.StatusCode -eq 404
  }
  Assert-True $notFound 'Unpublished product still received a quote.'

  $formulaPage = Invoke-WebRequest -Uri "$baseUrl/admin/pricing/formula.php?product_id=P014" -WebSession $webSession -UseBasicParsing
  $csrf = Get-Csrf $formulaPage.Content
  $invalidCsrf = Invoke-WebRequest -Uri "$baseUrl/admin/pricing/formula.php" -Method Post -WebSession $webSession -Body @{ csrf_token='invalid'; product_id='P014'; action='unpublish' } -UseBasicParsing
  Assert-True ($invalidCsrf.Content -match '表單驗證失敗') 'Invalid CSRF token was accepted.'
  $formulaPreview = Invoke-WebRequest -Uri "$baseUrl/admin/pricing/formula.php" -Method Post -WebSession $webSession -Body @{
    csrf_token=$csrf; product_id='P014'; action='preview'; width_cm='200'; height_cm='240';
    param_min_per_tai='40'; param_min_install_tai='20'; param_round_tai='ceil';
    param_round_material='nearest'; param_round_install='nearest'
  } -UseBasicParsing
  Assert-True ($formulaPreview.Content -match '上架產品') 'Re-publish preview failed.'
  Invoke-WebRequest -Uri "$baseUrl/admin/pricing/formula.php" -Method Post -WebSession $webSession -Body @{ csrf_token=$csrf; product_id='P014'; action='publish' } -UseBasicParsing | Out-Null
  $catalog = (Invoke-RestMethod -Uri "$baseUrl/api/products.php" -Method Get)
  Assert-True (@($catalog.data.id).Contains('P014')) 'Re-published product missing from public catalog.'

  $usersPage = Invoke-WebRequest -Uri "$baseUrl/admin/pricing/users.php" -WebSession $webSession -UseBasicParsing
  $csrf = Get-Csrf $usersPage.Content
  $editorPassword = 'Test-' + [guid]::NewGuid().ToString('N')
  Invoke-WebRequest -Uri "$baseUrl/admin/pricing/users.php" -Method Post -WebSession $webSession -Body @{ csrf_token=$csrf; action='add_user'; username='test_editor'; password=$editorPassword; role='editor' } -UseBasicParsing | Out-Null
  $editorSession = [Microsoft.PowerShell.Commands.WebRequestSession]::new()
  $editorLogin = Invoke-WebRequest -Uri "$baseUrl/admin/pricing/login.php" -WebSession $editorSession -UseBasicParsing
  $editorCsrf = Get-Csrf $editorLogin.Content
  Invoke-WebRequest -Uri "$baseUrl/admin/pricing/login.php" -Method Post -WebSession $editorSession -Body @{ csrf_token=$editorCsrf; action='login'; username='test_editor'; password=$editorPassword } -UseBasicParsing | Out-Null
  $editorDenied = $false
  try {
    Invoke-WebRequest -Uri "$baseUrl/admin/pricing/new.php" -WebSession $editorSession -UseBasicParsing | Out-Null
  } catch {
    $editorDenied = $_.Exception.Response.StatusCode -eq 403
  }
  Assert-True $editorDenied 'Editor could open new-product management.'
  $editorFormula = Invoke-WebRequest -Uri "$baseUrl/admin/pricing/formula.php?product_id=P014" -WebSession $editorSession -UseBasicParsing
  Assert-True ($editorFormula.Content -match '公式設定') 'Editor cannot view formula.'
  $editorCsrf = Get-Csrf $editorFormula.Content
  $editorSave = Invoke-WebRequest -Uri "$baseUrl/admin/pricing/formula.php" -Method Post -WebSession $editorSession -SkipHttpErrorCheck -Body @{ csrf_token=$editorCsrf; product_id='P014'; action='unpublish' } -UseBasicParsing
  Assert-True ($editorSave.StatusCode -eq 403) 'Editor could change formula or product status.'

  $editorDashboard = Invoke-WebRequest -Uri "$baseUrl/admin/pricing/" -WebSession $editorSession -UseBasicParsing
  foreach ($field in @('price_min_track_ft', 'price_min_per_tai', 'price_base_installation_per_tai')) {
    Assert-True ($editorDashboard.Content.Contains("name=`"$field`"")) "Legacy pricing field $field is missing."
  }
  foreach ($change in @(
    @{ Product='P001'; Field='min_track_ft'; Value='10'; FormulaField='min_track_ft' },
    @{ Product='P002'; Field='min_track_ft'; Value='10'; FormulaField='min_track_ft' },
    @{ Product='P005'; Field='min_per_tai'; Value='25'; FormulaField='min_per_tai' },
    @{ Product='P005'; Field='base_installation_per_tai'; Value='30'; FormulaField='min_install_tai' }
  )) {
    $requestJson = @{ product_id=$change.Product; width_cm=30; height_cm=30 } | ConvertTo-Json -Compress
    $before = Invoke-RestMethod -Uri "$baseUrl/api/calc.php" -Method Post -ContentType 'application/json' -Body $requestJson
    $editorDashboard = Invoke-WebRequest -Uri "$baseUrl/admin/pricing/" -WebSession $editorSession -UseBasicParsing
    $editorCsrf = Get-Csrf $editorDashboard.Content
    $revisionMatch = [regex]::Match($editorDashboard.Content, 'name="rules_revision" value="([a-f0-9]+)"')
    Assert-True $revisionMatch.Success 'Editor price form revision not found.'
    $priceBody = @{ csrf_token=$editorCsrf; rules_revision=$revisionMatch.Groups[1].Value; action='save_product'; product_id=$change.Product }
    $priceBody['price_' + $change.Field] = $change.Value
    $saved = Invoke-WebRequest -Uri "$baseUrl/admin/pricing/" -Method Post -WebSession $editorSession -Body $priceBody -UseBasicParsing
    Assert-True ($saved.Content -match '價格更新成功') "Editor could not save $($change.Field)."
    $after = Invoke-RestMethod -Uri "$baseUrl/api/calc.php" -Method Post -ContentType 'application/json' -Body $requestJson
    Assert-True ($after.data.total_price -gt $before.data.total_price) "Editor change to $($change.Field) did not affect the quote."
    $ownerFormula = Invoke-WebRequest -Uri "$baseUrl/admin/pricing/formula.php?product_id=$($change.Product)" -WebSession $webSession -UseBasicParsing
    Assert-True ($ownerFormula.Content.Contains("name=`"param_$($change.FormulaField)`" type=`"number`" min=`"0`" step=`"1`" required value=`"$($change.Value)`"")) "Formula page did not show the saved $($change.Field)."
  }

  $formulaPage = Invoke-WebRequest -Uri "$baseUrl/admin/pricing/formula.php?product_id=P014" -WebSession $webSession -UseBasicParsing
  $csrf = Get-Csrf $formulaPage.Content
  Invoke-WebRequest -Uri "$baseUrl/admin/pricing/formula.php" -Method Post -WebSession $webSession -Body @{
    csrf_token=$csrf; product_id='P014'; action='preview'; width_cm='150'; height_cm='150';
    param_min_per_tai='41'; param_min_install_tai='20'; param_round_tai='ceil';
    param_round_material='nearest'; param_round_install='nearest'
  } -UseBasicParsing | Out-Null
  $dashboard = Invoke-WebRequest -Uri "$baseUrl/admin/pricing/" -WebSession $webSession -UseBasicParsing
  $revisionMatch = [regex]::Match($dashboard.Content, 'name="rules_revision" value="([a-f0-9]+)"')
  Assert-True $revisionMatch.Success 'Price form revision not found.'
  Invoke-WebRequest -Uri "$baseUrl/admin/pricing/" -Method Post -WebSession $webSession -Body @{
    csrf_token=$csrf; rules_revision=$revisionMatch.Groups[1].Value; action='save_product'; product_id='P014';
    price_unit_price='101'; price_labor_per_tai='13'
  } -UseBasicParsing | Out-Null
  $staleSave = Invoke-WebRequest -Uri "$baseUrl/admin/pricing/formula.php" -Method Post -WebSession $webSession -Body @{ csrf_token=$csrf; product_id='P014'; action='save' } -UseBasicParsing
  Assert-True ($staleSave.Content -match '重新試算') 'Stale formula preview was accepted.'
  $quote = Invoke-RestMethod -Uri "$baseUrl/api/calc.php" -Method Post -ContentType 'application/json' -Body '{"product_id":"P014","width_cm":150,"height_cm":150}'
  Assert-True ($quote.data.total_price -eq 4365) 'Stale save changed the published formula.'
  Write-Host 'Pricing workflow smoke test passed.'
} finally {
  if ($server -and -not $server.HasExited) { Stop-Process -Id $server.Id -Force }
  if (Test-Path -LiteralPath $testRoot) {
    $resolvedCleanup = [IO.Path]::GetFullPath($testRoot)
    if (-not $resolvedCleanup.StartsWith($temporaryRoot, [StringComparison]::OrdinalIgnoreCase)) { throw 'Unsafe test cleanup path.' }
    Remove-Item -LiteralPath $resolvedCleanup -Recurse -Force
  }
}
