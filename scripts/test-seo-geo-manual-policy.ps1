$ErrorActionPreference = 'Stop'
$runner = Join-Path $PSScriptRoot '../Weekly SOP/run-seo-geo-cycle.ps1'
$tokens = $null; $errors = $null
$ast = [Management.Automation.Language.Parser]::ParseFile($runner, [ref]$tokens, [ref]$errors)
if ($errors.Count) { throw 'Unable to parse cycle runner.' }
$fn = $ast.Find({ param($node) $node -is [Management.Automation.Language.FunctionDefinitionAst] -and $node.Name -eq 'ConvertTo-DeploymentDateTimeOffset' }, $true)
if (-not $fn) { throw 'Missing timestamp parser.' }
Invoke-Expression $fn.Extent.Text
. (Join-Path $PSScriptRoot 'seo-geo-manual-policy.ps1')
function Event([string]$page, [string]$at, [string]$decision) {
  [PSCustomObject]@{ page_url = $page; candidate_at = $at; cooldown_decision = $decision }
}
function Assert($value, [string]$message) { if (-not $value) { throw $message } }
$events = @(
  (Event 'a' '2026-11-04T23:30:00Z' 'eligible'),
  (Event 'b' '2026-11-04T04:00:00Z' 'blocked_unknown'),
  (Event 'b' '2026-11-05T04:00:00Z' 'not_eligible'),
  (Event 'c' '2026-11-04T04:00:00Z' 'blocked_unknown'),
  (Event 'c' '2026-11-05T04:00:00Z' 'eligible'),
  (Event 'd' '2026-11-05T04:00:00Z' 'eligible'),
  (Event 'd' '2026-11-06T04:00:00Z' 'blocked_unknown'),
  (Event 'e' '2026-11-05T04:00:00Z' 'not_eligible')
)
$dates = @((1..28) | ForEach-Object { ([datetime]'2026-11-05').AddDays($_).ToString('yyyy-MM-dd') })
$p = Get-ManualDeploymentPolicyByPage -Candidates $events -Now ([datetime]'2026-12-03') -LatestFinalizedDate '2026-12-03' -FinalizedDates $dates
Assert ($p.a.post_28d_end -eq '2026-12-03' -and $p.a.cooldown_until -eq '2026-12-04' -and $p.a.cooldown_active) 'Taipei day boundary or 28-day window is incorrect.'
Assert ($p.b.classification_blocked -and $p.b.blocks_action) 'An unchanged event must not resolve an earlier unknown.'
Assert (-not $p.c.classification_blocked -and $p.c.cooldown_active) 'A later confirmed change must establish a new baseline.'
Assert ($p.d.classification_blocked) 'A later unknown must block.'
Assert (-not $p.e.blocks_action) 'A footer-only event must not create a cooldown.'
$p = Get-ManualDeploymentPolicyByPage -Candidates @($events[0]) -Now ([datetime]'2026-12-04') -LatestFinalizedDate '2026-12-02' -FinalizedDates $dates
Assert (-not $p.a.cooldown_active -and $p.a.awaiting_final_data -and $p.a.blocks_action) 'Incomplete final data must continue to block.'
$p = Get-ManualDeploymentPolicyByPage -Candidates @($events[0]) -Now ([datetime]'2026-12-04') -LatestFinalizedDate '2026-12-03' -FinalizedDates $dates
Assert (-not $p.a.blocks_action) 'Completed observation should no longer block.'
$p = Get-ManualDeploymentPolicyByPage -Candidates @($events[0]) -Now ([datetime]'2026-12-04') -LatestFinalizedDate '2026-12-03' -FinalizedDates @($dates | Where-Object { $_ -ne '2026-11-20' })
Assert ($p.a.awaiting_final_data -and $p.a.blocks_action) 'A missing daily final date must keep the page blocked.'
$failed = $false
try { $null = Get-ManualDeploymentPolicyByPage -Candidates @((Event 'a' '2026-11-05T04:00:00Z' 'invalid')) } catch { $failed = $true }
Assert $failed 'Invalid classification must fail closed.'
Write-Host 'Manual deployment policy tests passed.'
