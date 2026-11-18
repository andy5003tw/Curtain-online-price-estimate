# Manual deployment decisions are separate from queue-bound lifecycle receipts.
# This helper consumes evidence-reader candidates only; it does not write state.
function Get-ManualDeploymentPolicyByPage {
  param(
    [object[]]$Candidates = @(),
    [datetime]$Now = (Get-Date),
    [string]$LatestFinalizedDate = '',
    [string[]]$FinalizedDates = @()
  )

  $latestFinal = [datetime]::MinValue
  $hasFinal = [datetime]::TryParseExact($LatestFinalizedDate, 'yyyy-MM-dd', [Globalization.CultureInfo]::InvariantCulture, [Globalization.DateTimeStyles]::None, [ref]$latestFinal)
  $grouped = @{}
  foreach ($candidate in @($Candidates)) {
    if (-not $candidate) { continue }
    $page = [string]$candidate.page_url
    $at = ConvertTo-DeploymentDateTimeOffset -Value ([string]$candidate.candidate_at)
    if ([string]::IsNullOrWhiteSpace($page) -or -not $at) { throw 'Manual deployment candidate has an invalid page or zoned timestamp.' }
    $decision = [string]$candidate.cooldown_decision
    if ($decision -notin @('eligible', 'not_eligible', 'blocked_unknown')) { throw 'Manual deployment candidate has an invalid classification decision.' }
    if (-not $grouped.ContainsKey($page)) { $grouped[$page] = @() }
    $grouped[$page] += [PSCustomObject]@{ event = $candidate; instant = $at }
  }

  $result = @{}
  foreach ($page in $grouped.Keys) {
    $latestChange = $null
    $latestUnknown = $null
    foreach ($item in @($grouped[$page] | Sort-Object { $_.instant.UtcDateTime.Ticks })) {
      switch ([string]$item.event.cooldown_decision) {
        'eligible' {
          $latestChange = $item
          # A later confirmed main-content change establishes a new baseline;
          # an earlier unknown cannot make that newer baseline any older.
          if ($latestUnknown -and $latestUnknown.instant.UtcDateTime.Ticks -lt $item.instant.UtcDateTime.Ticks) { $latestUnknown = $null }
        }
        'blocked_unknown' { $latestUnknown = $item }
        # A later footer-only event does not resolve an earlier unknown event.
        'not_eligible' { }
      }
    }
    $windowEnd = if ($latestChange) { $latestChange.instant.ToOffset([TimeSpan]::FromHours(8)).Date.AddDays(28) } else { $null }
    $cooldownUntil = if ($windowEnd) { $windowEnd.AddDays(1) } else { $null }
    $cooldownActive = [bool]($cooldownUntil -and $Now.Date -lt $cooldownUntil)
    $completeDates = $true
    if ($windowEnd) {
      for ($day = $windowEnd.AddDays(-27); $day -le $windowEnd; $day = $day.AddDays(1)) {
        if ($day.ToString('yyyy-MM-dd') -notin $FinalizedDates) { $completeDates = $false; break }
      }
    }
    $awaitingFinal = [bool]($windowEnd -and (-not $hasFinal -or $latestFinal.Date -lt $windowEnd -or -not $completeDates))
    $result[$page] = [PSCustomObject]@{
      page = $page
      latest_change = if ($latestChange) { $latestChange.event } else { $null }
      latest_unknown = if ($latestUnknown) { $latestUnknown.event } else { $null }
      classification_blocked = [bool]$latestUnknown
      cooldown_active = $cooldownActive
      cooldown_until = if ($cooldownUntil) { $cooldownUntil.ToString('yyyy-MM-dd') } else { $null }
      post_28d_end = if ($windowEnd) { $windowEnd.ToString('yyyy-MM-dd') } else { $null }
      awaiting_final_data = $awaitingFinal
      blocks_action = [bool]($latestUnknown -or $cooldownActive -or $awaitingFinal)
    }
  }
  return $result
}
