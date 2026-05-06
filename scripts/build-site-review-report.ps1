param(
  [string]$SitesPath = ".\data\sites.json",
  [string]$LivePath = ".\data\live.json",
  [string]$ReviewJsonPath = ".\data\site-review.json",
  [string]$PublicSummaryJsonPath = ".\data\site-review-summary.json",
  [string]$ReviewMarkdownPath = ".\docs\site-registry-review.md",
  [string]$HighPriorityMarkdownPath = ".\docs\site-registry-high-priority.md"
)

$ErrorActionPreference = "Stop"

function Read-JsonFile {
  param([string]$Path)

  if (-not (Test-Path $Path)) {
    throw "Missing required JSON file: $Path"
  }

  return Get-Content $Path -Raw | ConvertFrom-Json
}

function Write-JsonFile {
  param(
    [string]$Path,
    [object]$Data
  )

  $json = $Data | ConvertTo-Json -Depth 8
  $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
  $fullPath = [System.IO.Path]::GetFullPath($Path)
  [System.IO.File]::WriteAllText($fullPath, $json, $utf8NoBom)
}

function Format-NullableDistance {
  param([object]$Value)

  if ($null -eq $Value) {
    return ""
  }

  return "$Value km"
}

function Format-NullableCoordinate {
  param([object]$Value)

  if ($null -eq $Value) {
    return ""
  }

  return ([double]$Value).ToString("0.######", [System.Globalization.CultureInfo]::InvariantCulture)
}

function Get-MapUrl {
  param(
    [object]$Latitude,
    [object]$Longitude
  )

  if ($null -eq $Latitude -or $null -eq $Longitude) {
    return ""
  }

  $lat = Format-NullableCoordinate $Latitude
  $lon = Format-NullableCoordinate $Longitude

  return "https://www.openstreetmap.org/?mlat=$lat&mlon=$lon#map=15/$lat/$lon"
}

function Find-RegistrySite {
  param(
    [array]$Sites,
    [string]$SiteId
  )

  if ([string]::IsNullOrWhiteSpace($SiteId)) {
    return $null
  }

  return $Sites | Where-Object { $_.siteId -eq $SiteId } | Select-Object -First 1
}

function Get-ReviewPriorityRank {
  param([string]$Priority)

  switch ($Priority) {
    "high" { return 3 }
    "medium" { return 2 }
    "low" { return 1 }
    default { return 0 }
  }
}

function Get-SiteReviewPriority {
  param([object]$Marker)

  if (-not $Marker.siteId -or $Marker.assignmentStatus -like "*unmatched*") {
    return "high"
  }

  if ($Marker.assignmentStatus -like "*reviewed*") {
    return "none"
  }

  if ($Marker.matchMethod -in @("proximity", "heuristic")) {
    return "high"
  }

  if ($null -ne $Marker.matchDistanceKm -and $Marker.matchDistanceKm -ge 1.5) {
    return "high"
  }

  if ($null -ne $Marker.matchDistanceKm -and $Marker.matchDistanceKm -gt 0.25) {
    return "medium"
  }

  return "low"
}

function Get-SiteReviewReason {
  param([object]$Marker)

  if (-not $Marker.siteId -or $Marker.assignmentStatus -like "*unmatched*") {
    return "No stable registry site is assigned to this marker."
  }

  if ($Marker.assignmentStatus -like "*reviewed*") {
    return "Current marker is already tied to a reviewed registry assignment."
  }

  if ($Marker.matchMethod -eq "proximity") {
    return "Marker matched by coordinate proximity rather than a reviewed alias."
  }

  if ($Marker.matchMethod -eq "heuristic") {
    return "Marker used heuristic arm assignment rather than a registry match."
  }

  if ($null -ne $Marker.matchDistanceKm -and $Marker.matchDistanceKm -ge 1.5) {
    return "Alias matched, but the source coordinate is more than 1.5 km from the registry point."
  }

  if ($null -ne $Marker.matchDistanceKm -and $Marker.matchDistanceKm -gt 0.25) {
    return "Alias matched, but the source coordinate is offset from the registry point."
  }

  return "Alias and coordinates are close, but local review has not certified the assignment."
}

function Get-SiteReviewAction {
  param([object]$Marker)

  if (-not $Marker.siteId -or $Marker.assignmentStatus -like "*unmatched*") {
    return "Create or match a stable site ID before using this marker as a trusted arm label."
  }

  if ($Marker.assignmentStatus -like "*reviewed*") {
    return "No immediate action."
  }

  if ($Marker.matchMethod -eq "proximity") {
    return "Confirm whether this landmark should be added as an alias for the matched site."
  }

  if ($Marker.matchMethod -eq "heuristic") {
    return "Confirm the landmark and arm, then add a registry site or alias."
  }

  if ($null -ne $Marker.matchDistanceKm -and $Marker.matchDistanceKm -ge 1.5) {
    return "Check whether the registry point is too generic or whether a separate landmark site is needed."
  }

  if ($null -ne $Marker.matchDistanceKm -and $Marker.matchDistanceKm -gt 0.25) {
    return "Confirm the source coordinate, landmark, arm assignment, and match radius."
  }

  return "Confirm local landmark and arm assignment, then promote only if locally reviewed."
}

$sites = Read-JsonFile $SitesPath
$live = Read-JsonFile $LivePath
$siteRows = @($sites.sites)
$markerRows = @($live.mapMarkers)

$reviewedSites = @($siteRows | Where-Object { $_.assignmentStatus -like "*reviewed*" })
$needsReviewSites = @($siteRows | Where-Object { $_.assignmentStatus -like "*needs*review*" })
$unresolvedMarkers = @($markerRows | Where-Object { $_.assignmentStatus -like "*needs*review*" -or $_.assignmentStatus -like "*unmatched*" })
$reviewedMarkers = @($markerRows | Where-Object { $_.assignmentStatus -like "*reviewed*" })

$markersBySite = @(
  $markerRows |
    Group-Object siteId |
    Sort-Object Count -Descending |
    ForEach-Object {
      $first = $_.Group | Select-Object -First 1
      [PSCustomObject]@{
        siteId = $_.Name
        siteName = $first.siteName
        arm = $first.arm
        assignmentStatus = $first.assignmentStatus
        reportCount = $_.Count
        latestReportDate = ($_.Group | Sort-Object isoDate -Descending | Select-Object -First 1).date
        matchMethods = @($_.Group | Group-Object matchMethod | Sort-Object Count -Descending | ForEach-Object { "$($_.Name): $($_.Count)" })
        landmarks = @($_.Group | Sort-Object isoDate -Descending | ForEach-Object { $_.landmark } | Select-Object -Unique)
      }
    }
)

$reviewQueue = @(
  $markerRows |
    Sort-Object @{ Expression = { -(Get-ReviewPriorityRank (Get-SiteReviewPriority $_)) } }, siteName, isoDate |
    ForEach-Object {
      $priority = Get-SiteReviewPriority $_
      $registrySite = Find-RegistrySite -Sites $siteRows -SiteId $_.siteId

      [PSCustomObject]@{
        siteId = $_.siteId
        siteName = $_.siteName
        landmark = $_.landmark
        arm = $_.arm
        assignmentStatus = $_.assignmentStatus
        reviewPriority = $priority
        reviewReason = Get-SiteReviewReason $_
        matchMethod = $_.matchMethod
        matchDistanceKm = $_.matchDistanceKm
        reportDate = $_.date
        latitude = $_.latitude
        longitude = $_.longitude
        sourceMapUrl = Get-MapUrl -Latitude $_.latitude -Longitude $_.longitude
        registryLatitude = if ($registrySite) { $registrySite.latitude } else { $null }
        registryLongitude = if ($registrySite) { $registrySite.longitude } else { $null }
        registryMapUrl = if ($registrySite) {
          Get-MapUrl -Latitude $registrySite.latitude -Longitude $registrySite.longitude
        } else {
          ""
        }
        recommendedReviewAction = Get-SiteReviewAction $_
      }
    }
)

$highPriorityReviewItems = @($reviewQueue | Where-Object { $_.reviewPriority -eq "high" })
$mediumPriorityReviewItems = @($reviewQueue | Where-Object { $_.reviewPriority -eq "medium" })
$lowPriorityReviewItems = @($reviewQueue | Where-Object { $_.reviewPriority -eq "low" })
$matchedButUnreviewedMarkers = @($markerRows | Where-Object {
    $_.siteId -and $_.assignmentStatus -like "*needs*review*"
  })

$reviewData = [ordered]@{
  generatedAt = (Get-Date).ToString("o")
  sourceFiles = [ordered]@{
    sites = $SitesPath
    live = $LivePath
  }
  summary = [ordered]@{
    registrySites = $siteRows.Count
    reviewedRegistrySites = $reviewedSites.Count
    needsReviewRegistrySites = $needsReviewSites.Count
    currentMapMarkers = $markerRows.Count
    reviewedCurrentMapMarkers = $reviewedMarkers.Count
    needsReviewCurrentMapMarkers = $unresolvedMarkers.Count
    matchedButUnreviewedCurrentMapMarkers = $matchedButUnreviewedMarkers.Count
    highPriorityReviewItems = $highPriorityReviewItems.Count
    mediumPriorityReviewItems = $mediumPriorityReviewItems.Count
    lowPriorityReviewItems = $lowPriorityReviewItems.Count
  }
  reviewQueue = @($reviewQueue)
  markersBySite = @($markersBySite)
}

$publicSummaryData = [ordered]@{
  schemaVersion = "site-review-summary-v0"
  generatedAt = $reviewData.generatedAt
  source = "sanitized aggregate from site-registry review workflow"
  summary = $reviewData.summary
  priorityCounts = [ordered]@{
    high = $highPriorityReviewItems.Count
    medium = $mediumPriorityReviewItems.Count
    low = $lowPriorityReviewItems.Count
  }
  publicNotes = @(
    "This public summary reports aggregate site-registry review status only.",
    "Detailed review queues, reviewer notes, draft corrections, and unpublished decisions belong in private review artifacts.",
    "Counts do not certify site locations, arm assignments, or public-health status."
  )
  links = [ordered]@{
    publicMethodology = ".\methodology.html"
    reviewWorkflow = ".\docs\site-registry-decision-workflow.md"
  }
}

Write-JsonFile -Path $ReviewJsonPath -Data $reviewData
Write-JsonFile -Path $PublicSummaryJsonPath -Data $publicSummaryData

$markdown = [System.Collections.Generic.List[string]]::new()
$markdown.Add("# Site Registry Review")
$markdown.Add("")
$markdown.Add("Generated: $($reviewData.generatedAt)")
$markdown.Add("")
$markdown.Add("This file is a review queue for stable site IDs and arm assignments. It does not certify locations as authoritative; it identifies what still needs local review.")
$markdown.Add("")
$markdown.Add("## Summary")
$markdown.Add("")
$markdown.Add("- Registry sites: $($reviewData.summary.registrySites)")
$markdown.Add("- Reviewed registry sites: $($reviewData.summary.reviewedRegistrySites)")
$markdown.Add("- Registry sites needing review: $($reviewData.summary.needsReviewRegistrySites)")
$markdown.Add("- Current mapped markers: $($reviewData.summary.currentMapMarkers)")
$markdown.Add("- Current mapped markers needing review: $($reviewData.summary.needsReviewCurrentMapMarkers)")
$markdown.Add("- High-priority review items: $($reviewData.summary.highPriorityReviewItems)")
$markdown.Add("- Medium-priority review items: $($reviewData.summary.mediumPriorityReviewItems)")
$markdown.Add("- Low-priority review items: $($reviewData.summary.lowPriorityReviewItems)")
$markdown.Add("")
$markdown.Add("## Current Marker Review Queue")
$markdown.Add("")
$markdown.Add("| Priority | Site | Landmark | Arm | Status | Match | Distance | Report date | Evidence note | Review action |")
$markdown.Add("| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |")
foreach ($item in $reviewQueue) {
  $distance = Format-NullableDistance $item.matchDistanceKm
  $markdown.Add("| $($item.reviewPriority) | $($item.siteName) | $($item.landmark) | $($item.arm) | $($item.assignmentStatus) | $($item.matchMethod) | $distance | $($item.reportDate) | $($item.reviewReason) | $($item.recommendedReviewAction) |")
}
$markdown.Add("")
$markdown.Add("## Review Notes")
$markdown.Add("")
$markdown.Add('- Keep stable `siteId` values once created.')
$markdown.Add('- Use `reviewed-local` only after local landmark and arm assignment review.')
$markdown.Add('- Preserve `needs-local-review` when the assignment is plausible but not verified.')
$markdown.Add('- Preserve `unmatched-review-needed` when no stable site can be selected.')
$markdown.Add('- Do not use unresolved sites as authoritative labels for public-health interpretation or model targets.')

$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
[System.IO.File]::WriteAllText([System.IO.Path]::GetFullPath($ReviewMarkdownPath), ($markdown -join [Environment]::NewLine), $utf8NoBom)

$highPriorityMarkdown = [System.Collections.Generic.List[string]]::new()
$highPriorityMarkdown.Add("# High-Priority Site Registry Review")
$highPriorityMarkdown.Add("")
$highPriorityMarkdown.Add("Generated: $($reviewData.generatedAt)")
$highPriorityMarkdown.Add("")
$highPriorityMarkdown.Add("This packet focuses only on high-priority current FHABS marker checks. It is designed for local review and should not be treated as certification by itself.")
$highPriorityMarkdown.Add("")
$highPriorityMarkdown.Add("## Review Decision Rules")
$highPriorityMarkdown.Add("")
$highPriorityMarkdown.Add('- Promote a site to `reviewed-local` only when the landmark, coordinates, lake arm, and match radius are locally reviewed.')
$highPriorityMarkdown.Add("- Add an alias only when the alternate landmark clearly refers to the same maintained site.")
$highPriorityMarkdown.Add("- Split a site when the source coordinate suggests a distinct landmark rather than a generic bay or community label.")
$highPriorityMarkdown.Add('- Preserve `needs-local-review` when the evidence is plausible but not locally certified.')
$highPriorityMarkdown.Add("- Do not use unresolved markers as public-health guidance or model training labels.")
$highPriorityMarkdown.Add("")
$highPriorityMarkdown.Add("## High-Priority Items")
$highPriorityMarkdown.Add("")

if ($highPriorityReviewItems.Count -eq 0) {
  $highPriorityMarkdown.Add("No high-priority current marker checks were generated.")
} else {
  foreach ($item in $highPriorityReviewItems) {
    $distance = Format-NullableDistance $item.matchDistanceKm
    $sourceLat = Format-NullableCoordinate $item.latitude
    $sourceLon = Format-NullableCoordinate $item.longitude
    $registryLat = Format-NullableCoordinate $item.registryLatitude
    $registryLon = Format-NullableCoordinate $item.registryLongitude

    $highPriorityMarkdown.Add("### $($item.landmark)")
    $highPriorityMarkdown.Add("")
    $highPriorityMarkdown.Add("- Current site ID: ``$($item.siteId)``")
    $highPriorityMarkdown.Add("- Matched site name: $($item.siteName)")
    $highPriorityMarkdown.Add("- Current arm: $($item.arm)")
    $highPriorityMarkdown.Add("- Assignment status: ``$($item.assignmentStatus)``")
    $highPriorityMarkdown.Add("- Match method: ``$($item.matchMethod)``")
    $highPriorityMarkdown.Add("- Match distance: $distance")
    $highPriorityMarkdown.Add("- Report date: $($item.reportDate)")
    $highPriorityMarkdown.Add("- Evidence note: $($item.reviewReason)")
    $highPriorityMarkdown.Add("- Recommended action: $($item.recommendedReviewAction)")
    $highPriorityMarkdown.Add("- Source coordinate: [$sourceLat, $sourceLon]($($item.sourceMapUrl))")

    if ($item.registryMapUrl) {
      $highPriorityMarkdown.Add("- Registry coordinate: [$registryLat, $registryLon]($($item.registryMapUrl))")
    } else {
      $highPriorityMarkdown.Add("- Registry coordinate: unavailable")
    }

    $highPriorityMarkdown.Add("")
    $highPriorityMarkdown.Add("Review checklist:")
    $highPriorityMarkdown.Add("")
    $highPriorityMarkdown.Add("- [ ] Confirm whether the FHABS landmark name is a known local landmark.")
    $highPriorityMarkdown.Add("- [ ] Confirm whether the source coordinate falls in the expected lake arm.")
    $highPriorityMarkdown.Add("- [ ] Decide whether to keep the existing site, add an alias, split into a new site, or leave unresolved.")
    $highPriorityMarkdown.Add('- [ ] Record the evidence source or local-review note before changing `assignmentStatus`.')
    $highPriorityMarkdown.Add("")
    $highPriorityMarkdown.Add("Decision:")
    $highPriorityMarkdown.Add("")
    $highPriorityMarkdown.Add('- [ ] Keep `needs-local-review`')
    $highPriorityMarkdown.Add("- [ ] Add alias to existing site")
    $highPriorityMarkdown.Add("- [ ] Create separate registry site")
    $highPriorityMarkdown.Add('- [ ] Promote to `reviewed-local` after evidence is recorded')
    $highPriorityMarkdown.Add("")
  }
}

[System.IO.File]::WriteAllText([System.IO.Path]::GetFullPath($HighPriorityMarkdownPath), ($highPriorityMarkdown -join [Environment]::NewLine), $utf8NoBom)

Write-Output "Wrote $ReviewJsonPath"
Write-Output "Wrote $PublicSummaryJsonPath"
Write-Output "Wrote $ReviewMarkdownPath"
Write-Output "Wrote $HighPriorityMarkdownPath"
