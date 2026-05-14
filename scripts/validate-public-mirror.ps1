param(
  [switch]$CheckHttp
)

$ErrorActionPreference = "Stop"

$projectRoot = Split-Path -Parent $PSScriptRoot
$failures = New-Object System.Collections.Generic.List[string]
$warnings = New-Object System.Collections.Generic.List[string]

function Add-Failure {
  param([string]$Message)
  $script:failures.Add($Message)
}

function Add-Warning {
  param([string]$Message)
  $script:warnings.Add($Message)
}

function Resolve-ProjectPath {
  param([string]$RelativePath)
  return Join-Path $projectRoot $RelativePath
}

function Assert-FileExists {
  param([string]$RelativePath)
  if (-not (Test-Path -LiteralPath (Resolve-ProjectPath $RelativePath) -PathType Leaf)) {
    Add-Failure "Missing required file: $RelativePath"
  }
}

function Get-TrackedFiles {
  try {
    return @(git ls-files)
  } catch {
    Add-Failure "Unable to inspect tracked files with git ls-files: $($_.Exception.Message)"
    return @()
  }
}

function Assert-PathNotTracked {
  param(
    [string[]]$TrackedFiles,
    [string]$RelativePath,
    [string]$Reason
  )

  $normalized = $RelativePath -replace '\\', '/'
  $matches = @(
    $TrackedFiles |
      Where-Object { $_ -eq $normalized -or $_.StartsWith("$normalized/") }
  )

  if ($matches.Count -gt 0) {
    Add-Failure "$Reason`: $RelativePath"
  }
}

function Assert-TextContains {
  param(
    [string]$Text,
    [string]$Needle,
    [string]$Message
  )
  if (-not $Text.Contains($Needle)) {
    Add-Failure $Message
  }
}

function Read-JsonFile {
  param([string]$RelativePath)

  try {
    return Get-Content -LiteralPath (Resolve-ProjectPath $RelativePath) -Raw | ConvertFrom-Json
  } catch {
    Add-Failure "Invalid JSON in $RelativePath`: $($_.Exception.Message)"
    return $null
  }
}

function Test-HttpEndpoint {
  param([string]$Uri)

  try {
    $response = Invoke-WebRequest -UseBasicParsing -Uri $Uri -TimeoutSec 10
    if ($response.StatusCode -lt 200 -or $response.StatusCode -ge 300) {
      Add-Failure "HTTP check failed for $Uri with status $($response.StatusCode)."
    }
  } catch {
    Add-Failure "HTTP check failed for $Uri`: $($_.Exception.Message)"
  }
}

function ConvertTo-DateTimeOffsetOrNull {
  param(
    [object]$Value,
    [string]$Label
  )

  if ($null -eq $Value -or [string]::IsNullOrWhiteSpace([string]$Value)) {
    Add-Failure "$Label is missing or blank."
    return $null
  }

  try {
    return [datetimeoffset]::Parse([string]$Value, [Globalization.CultureInfo]::InvariantCulture)
  } catch {
    Add-Failure "$Label is not a parseable date/time: $Value"
    return $null
  }
}

function Get-ArrayCount {
  param([object]$Value)
  if ($null -eq $Value) {
    return 0
  }
  return @($Value).Count
}

function Assert-PositiveNumber {
  param(
    [object]$Value,
    [string]$Message
  )

  if ($null -eq $Value) {
    Add-Failure $Message
    return
  }

  try {
    if ([double]$Value -le 0) {
      Add-Failure $Message
    }
  } catch {
    Add-Failure $Message
  }
}

function Assert-GapWithinMinutes {
  param(
    [datetimeoffset]$Left,
    [datetimeoffset]$Right,
    [int]$MaxMinutes,
    [string]$Message
  )

  $gapMinutes = [math]::Abs(($Left - $Right).TotalMinutes)
  if ($gapMinutes -gt $MaxMinutes) {
    Add-Failure "$Message Gap: $([math]::Round($gapMinutes, 2)) minutes."
  }
}

function Get-OutputRecordCount {
  param(
    [string]$File,
    [object]$Data
  )

  switch ($File) {
    "data/live.json" {
      return (Get-ArrayCount $Data.liveCards) + (Get-ArrayCount $Data.mapMarkers)
    }
    "data/reports.json" {
      return Get-ArrayCount $Data.records
    }
    "data/observations.json" {
      return Get-ArrayCount $Data.records
    }
    "data/sites-normalized.json" {
      return Get-ArrayCount $Data.sites
    }
    "data/analytics.json" {
      return (Get-ArrayCount $Data.reportTrendByYear) + (Get-ArrayCount $Data.advisoryDistributionByArm) + (Get-ArrayCount $Data.observationCoverage)
    }
    default {
      return $null
    }
  }
}

function Test-ManifestFreshness {
  param(
    [object]$Manifest,
    [object]$LiveData
  )

  if ($null -eq $Manifest -or $null -eq $LiveData) {
    return
  }

  $manifestGeneratedAt = ConvertTo-DateTimeOffsetOrNull $Manifest.generatedAt "Manifest generatedAt"
  $liveGeneratedAt = ConvertTo-DateTimeOffsetOrNull $LiveData.generatedAt "Live snapshot generatedAt"

  if ($manifestGeneratedAt -and $liveGeneratedAt) {
    Assert-GapWithinMinutes -Left $manifestGeneratedAt -Right $liveGeneratedAt -MaxMinutes 5 -Message "Manifest and live snapshot appear to come from different refresh passes."
  }

  $expectedSourceIds = @(
    "usgs-lake-level",
    "usgs-cole-creek-discharge",
    "fhabs-bloom-reports",
    "fhabs-results"
  )
  $sourceIds = @($Manifest.sources | ForEach-Object { $_.id })

  foreach ($expectedSourceId in $expectedSourceIds) {
    if ($sourceIds -notcontains $expectedSourceId) {
      Add-Failure "Manifest is missing expected source: $expectedSourceId"
    }
  }

  if ($Manifest.status -eq "ok") {
    $nonOkSources = @($Manifest.sources | Where-Object { $_.status -ne "ok" })
    if ($nonOkSources.Count -gt 0) {
      Add-Failure "Manifest status is ok, but one or more sources are not ok."
    }
  }

  $maxSourceAgeDays = if ($Manifest.sourceFreshnessMaxAgeDays) { [int]$Manifest.sourceFreshnessMaxAgeDays } else { 14 }

  foreach ($source in @($Manifest.sources)) {
    if ([string]::IsNullOrWhiteSpace($source.id)) {
      Add-Failure "Manifest source is missing id."
      continue
    }

    if ([string]::IsNullOrWhiteSpace($source.status)) {
      Add-Failure "Manifest source $($source.id) is missing status."
    }

    Assert-PositiveNumber -Value $source.rowCount -Message "Manifest source $($source.id) must have a positive rowCount."

    $latestObservation = ConvertTo-DateTimeOffsetOrNull $source.latestObservationDate "Manifest source $($source.id) latestObservationDate"
    if ($manifestGeneratedAt -and $latestObservation) {
      $ageDays = ($manifestGeneratedAt.Date - $latestObservation.Date).TotalDays
      if ($ageDays -lt 0) {
        Add-Failure "Manifest source $($source.id) has a latestObservationDate after the manifest generatedAt."
      } elseif ($ageDays -gt $maxSourceAgeDays) {
        Add-Warning "Manifest source $($source.id) latest observation is $([int]$ageDays) days older than the dashboard snapshot; keep stale-source language visible."
      }
    }

    if ($source.id -like "fhabs-*") {
      Assert-PositiveNumber -Value $source.clearLakeRowCount -Message "Manifest source $($source.id) must have a positive clearLakeRowCount."
      if ($null -ne $source.resourceDate) {
        $resourceDate = ConvertTo-DateTimeOffsetOrNull $source.resourceDate "Manifest source $($source.id) resourceDate"
        if ($manifestGeneratedAt -and $resourceDate -and $resourceDate.Date -gt $manifestGeneratedAt.Date) {
          Add-Failure "Manifest source $($source.id) resourceDate is after manifest generatedAt."
        }
      }
      if ($null -ne $source.resourceAgeDays -and [int]$source.resourceAgeDays -lt 0) {
        Add-Failure "Manifest source $($source.id) resourceAgeDays cannot be negative."
      }
    }
  }

  $expectedOutputFiles = @(
    "data/live.json",
    "data/reports.json",
    "data/observations.json",
    "data/sites-normalized.json",
    "data/analytics.json"
  )
  $manifestOutputFiles = @($Manifest.outputs | ForEach-Object { $_.file })

  foreach ($expectedOutputFile in $expectedOutputFiles) {
    if ($manifestOutputFiles -notcontains $expectedOutputFile) {
      Add-Failure "Manifest is missing expected output entry: $expectedOutputFile"
    }
  }

  foreach ($output in @($Manifest.outputs)) {
    if ([string]::IsNullOrWhiteSpace($output.file)) {
      Add-Failure "Manifest output is missing file."
      continue
    }

    Assert-PositiveNumber -Value $output.recordCount -Message "Manifest output $($output.file) must have a positive recordCount."

    $outputData = Read-JsonFile ($output.file -replace '/', '\')
    if ($null -ne $outputData) {
      $outputGeneratedAt = ConvertTo-DateTimeOffsetOrNull $outputData.generatedAt "Manifest output $($output.file) generatedAt"
      if ($manifestGeneratedAt -and $outputGeneratedAt) {
        Assert-GapWithinMinutes -Left $manifestGeneratedAt -Right $outputGeneratedAt -MaxMinutes 5 -Message "Manifest output $($output.file) appears to come from a different refresh pass."
      }

      $computedCount = Get-OutputRecordCount -File $output.file -Data $outputData
      if ($null -ne $computedCount -and [int]$output.recordCount -ne [int]$computedCount) {
        Add-Failure "Manifest output $($output.file) recordCount $($output.recordCount) does not match computed count $computedCount."
      }
    }
  }

  $notesText = (@($Manifest.notes) -join " ")
  Assert-TextContains -Text $notesText -Needle "Observation dates may be older than the dashboard generation time" -Message "Manifest must preserve dashboard-refresh versus source-observation distinction."
}

function Test-WeatherContext {
  param([object]$WeatherContext)

  if ($null -eq $WeatherContext) {
    return
  }

  $allowedStatuses = @("live", "stale", "partial", "unavailable")
  if ($allowedStatuses -notcontains $WeatherContext.machineReadableStatus) {
    Add-Failure "Weather context has unexpected machineReadableStatus: $($WeatherContext.machineReadableStatus)"
  }

  [void](ConvertTo-DateTimeOffsetOrNull $WeatherContext.generatedAt "Weather context generatedAt")

  if ([string]::IsNullOrWhiteSpace($WeatherContext.sourceName)) {
    Add-Failure "Weather context must include sourceName."
  }

  Assert-PositiveNumber -Value $WeatherContext.staleAfterHours -Message "Weather context staleAfterHours must be positive."

  $qualityNotes = (@($WeatherContext.qualityNotes) -join " ")
  Assert-TextContains -Text $qualityNotes -Needle "separate from lake-health interpretation" -Message "Weather context must preserve lake-health separation."
  Assert-TextContains -Text $qualityNotes -Needle "not a bloom-severity estimate" -Message "Weather context must preserve bloom-severity boundary."
  Assert-TextContains -Text $qualityNotes -Needle "not MQTT, Grafana, InfluxDB, raw local telemetry, or a private gateway export" -Message "Weather context must keep private telemetry systems out of the public export."

  if ($WeatherContext.machineReadableStatus -ne "unavailable") {
    if (-not $WeatherContext.sourceName.Contains("NOAA") -and -not $WeatherContext.sourceName.Contains("National Weather Service")) {
      Add-Failure "Available weather context must use a reviewed public source name."
    }

    if ((Get-ArrayCount $WeatherContext.stations) -le 0) {
      Add-Failure "Available weather context must include at least one public-safe station record."
    }

    if ((Get-ArrayCount $WeatherContext.summaryCards) -le 0) {
      Add-Failure "Available weather context must include summary cards."
    }
  }

  foreach ($station in @($WeatherContext.stations)) {
    if ([string]::IsNullOrWhiteSpace($station.stationId)) {
      Add-Failure "Weather station record is missing stationId."
    }
    if ([string]::IsNullOrWhiteSpace($station.visibility)) {
      Add-Failure "Weather station $($station.stationId) is missing visibility."
    }
    [void](ConvertTo-DateTimeOffsetOrNull $station.observedAt "Weather station $($station.stationId) observedAt")

    foreach ($metric in @($station.metrics)) {
      if ([string]::IsNullOrWhiteSpace($metric.label) -or [string]::IsNullOrWhiteSpace($metric.unit)) {
        Add-Failure "Weather station $($station.stationId) has a metric without label or unit."
      }
    }
  }
}

function Test-ReviewedFieldObservations {
  param([object]$ReviewedFieldObservations)

  if ($null -eq $ReviewedFieldObservations) {
    return
  }

  if ($ReviewedFieldObservations.sourceFamily -ne "field-microscopy") {
    Add-Failure "Reviewed field observations must use sourceFamily field-microscopy."
  }

  $qualityNotes = (@($ReviewedFieldObservations.qualityNotes) -join " ")
  Assert-TextContains -Text $qualityNotes -Needle "approved-public and permissionToPublish true" -Message "Reviewed field observations must preserve approval and permission rule."
  Assert-TextContains -Text $qualityNotes -Needle "Private collector identity details" -Message "Reviewed field observations must preserve private collector exclusion."
  Assert-TextContains -Text $qualityNotes -Needle "separate source family" -Message "Reviewed field observations must remain separate from other source families."

  foreach ($record in @($ReviewedFieldObservations.records)) {
    if ($record.qaStatus -ne "approved-public") {
      Add-Failure "Reviewed public field observation $($record.recordId) is not approved-public."
    }
    if ($record.permissionToPublish -ne $true) {
      Add-Failure "Reviewed public field observation $($record.recordId) lacks permissionToPublish true."
    }

    $serialized = $record | ConvertTo-Json -Depth 12
    foreach ($privateNeedle in @("collectorName", "qaNotes", "custodyNotes", "photoOrVoucherReference", "latitude", "longitude")) {
      if ($serialized.Contains($privateNeedle)) {
        Add-Failure "Reviewed public field observation $($record.recordId) includes private or sensitive field: $privateNeedle"
      }
    }
  }
}

Push-Location $projectRoot
try {
  $requiredFiles = @(
    ".nojekyll",
    "index.html",
    "project.html",
    "methodology.html",
    "styles.css",
    "app.js",
    "manifest.webmanifest",
    "sw.js",
    "README.md",
    "assets\clear-lake-watch-preview.png",
    "assets\clear-lake-watch.ico",
    "assets\apple-touch-icon.png",
    "assets\clear-lake-watch-icon-192.png",
    "assets\clear-lake-watch-icon-512.png",
    "data\sources.json",
    "data\sites.json",
    "data\live.json",
    "data\reports.json",
    "data\observations.json",
    "data\sites-normalized.json",
    "data\site-review-summary.json",
    "data\analytics.json",
    "data\manifest.json",
    "data\lake-shoreline.json",
    "data\forecast-output.example.json",
    "data\field-microscopy-intake.example.json",
    "data\reviewed-field-observations.json",
    "data\weather-context.json",
    "data\weather-context.example.json",
    "docs\project-brief.md",
    "docs\Clear-Lake-Watch-Project-Brief.pdf",
    "docs\clear-lake-watch-v0.1-evidence-summary.md",
    "docs\clear_lake_watch_portfolio_case_study.md",
    "docs\dashboard-anatomy-review-guide.md",
    "docs\deployment.md",
    "docs\field-microscopy-intake-contract.md",
    "docs\field-microscopy-review-workflow.md",
    "docs\flagship-maturity-plan.md",
    "docs\forecast-boundary.md",
    "docs\local-first-operating-model.md",
    "docs\public-mirror-boundary.md",
    "docs\public-backlog.md",
    "docs\public-snapshot-release-note-2026-05-13.md",
    "docs\portfolio-evidence-index.md",
    "docs\public-screenshots\clear-lake-watch-homepage-desktop-2026-05-13.png",
    "docs\public-screenshots\clear-lake-watch-homepage-mobile-2026-05-13.png",
    "docs\public-screenshots\clear-lake-watch-dashboard-overview-2026-05-14.png",
    "docs\public-screenshots\clear-lake-watch-snapshot-status-2026-05-14.png",
    "docs\public-screenshots\clear-lake-watch-map-qa-2026-05-14.png",
    "docs\public-screenshots\clear-lake-watch-methodology-2026-05-14.png",
    "docs\public-screenshots\clear-lake-watch-project-page-2026-05-14.png",
    "docs\site-registry-decision-workflow.md",
    "docs\site-registry-trust-review-pass-001.md",
    "docs\publication-review-checklist.md",
    "docs\published-commentary.md",
    "docs\research-readiness-brief.md",
    "docs\reviewer-demo-notes.md",
    "docs\resume-linkedin-snippets.md",
    "docs\scheduled-public-refresh-design.md",
    "docs\source-audit.md",
    "docs\source-freshness-validation.md",
    "docs\weather-context-contract.md",
    "scripts\refresh-live-data.ps1",
    "scripts\refresh-osm-shoreline.ps1",
    "scripts\write-weather-context-public-source.ps1",
    "scripts\write-weather-context-unavailable.ps1"
  )

  foreach ($file in $requiredFiles) {
    Assert-FileExists $file
  }

  $trackedFiles = Get-TrackedFiles

  $excludedPaths = @(
    "portfolio-materials.html",
    "docs\trusted-review-request.md",
    "docs\trusted-review-feedback-log.md",
    "docs\conversation-log.md",
    "docs\review-screenshots",
    "docs\screenshot-only-portfolio-packet.md",
    "docs\public-mirror-review-2026-05-08.md",
    "docs\public-mirror-file-set-2026-05-08.md",
    "data\site-review.json",
    "data\private",
    "shortcuts",
    "server.pid",
    "server.out.log",
    "server.err.log"
  )

  foreach ($path in $excludedPaths) {
    Assert-PathNotTracked -TrackedFiles $trackedFiles -RelativePath $path -Reason "Public mirror must not track excluded review/private/local artifact"
  }

  $unexpectedLocalFiles = @(
    $trackedFiles |
      Where-Object {
        $_ -match '^data/.*\.local\.json$' -or
        $_ -match '\.local\.sqlite$'
      }
  )

  if ($unexpectedLocalFiles.Count -gt 0) {
    foreach ($file in $unexpectedLocalFiles) {
      Add-Failure "Public mirror must not track local/private file: $file"
    }
  }

  $readme = Get-Content -LiteralPath (Resolve-ProjectPath "README.md") -Raw
  $index = Get-Content -LiteralPath (Resolve-ProjectPath "index.html") -Raw
  $project = Get-Content -LiteralPath (Resolve-ProjectPath "project.html") -Raw
  $methodology = Get-Content -LiteralPath (Resolve-ProjectPath "methodology.html") -Raw
  $app = Get-Content -LiteralPath (Resolve-ProjectPath "app.js") -Raw

  Assert-TextContains -Text $readme -Needle "late-prototype / early-MVP" -Message "README must preserve maturity language."
  Assert-TextContains -Text $readme -Needle "not official public-health guidance" -Message "README must preserve public-health boundary."
  Assert-TextContains -Text $readme -Needle "Weather context is a reviewed public-source snapshot and remains separate from lake-health interpretation." -Message "README must describe weather context as reviewed public-source context."
  Assert-TextContains -Text $readme -Needle "not part of this public mirror branch" -Message "README must explain that private review materials are excluded."
  Assert-TextContains -Text $readme -Needle "docs/public-backlog.md" -Message "README must link the public backlog."
  Assert-TextContains -Text $readme -Needle "docs/public-snapshot-release-note-2026-05-13.md" -Message "README must link the public snapshot release note."
  Assert-TextContains -Text $readme -Needle "docs/reviewer-demo-notes.md" -Message "README must link the reviewer demo notes."
  Assert-TextContains -Text $readme -Needle "docs/site-registry-trust-review-pass-001.md" -Message "README must link the site-registry review pass."
  Assert-TextContains -Text $index -Needle "late prototype / early MVP" -Message "Homepage must preserve maturity language."
  Assert-TextContains -Text $index -Needle "Public Data Snapshot, Not Advisory Guidance" -Message "Homepage must include the public snapshot status strip."
  Assert-TextContains -Text $index -Needle "What The Public Snapshot Files Are Showing" -Message "Homepage must avoid overclaiming current-feed wording."
  Assert-TextContains -Text $index -Needle "Best First Reads" -Message "Homepage must include reviewer entry points."
  Assert-TextContains -Text $index -Needle "What This Project Demonstrates" -Message "Homepage must include a portfolio demonstration section."
  Assert-TextContains -Text $index -Needle "map-review-status" -Message "Homepage must include the map review status callout."
  Assert-TextContains -Text $methodology -Needle "not official public-health direction" -Message "Methodology page must preserve public-health boundary."
  Assert-TextContains -Text $project -Needle "not official public-health guidance" -Message "Project page must preserve public-health boundary."
  Assert-TextContains -Text $project -Needle "late prototype / early MVP" -Message "Project page must preserve maturity language."
  Assert-TextContains -Text $project -Needle "Unresolved markers remain in local review" -Message "Project page must preserve site-review caution language."
  Assert-TextContains -Text $index -Needle "local browser notices only, not background emergency or official public-health notifications" -Message "Dashboard must preserve data-QA notice boundary."
  Assert-TextContains -Text $project -Needle "docs/forecast-boundary.md" -Message "Project page must link forecast boundary."
  Assert-TextContains -Text $app -Needle "site-review-summary.json" -Message "App must consume public site-review summary."
  Assert-TextContains -Text $app -Needle "renderSnapshotStatusStrip" -Message "App must render the snapshot status strip."
  Assert-TextContains -Text $app -Needle "Latest Clear Lake FHABS report" -Message "App must expose FHABS report freshness in the status strip."
  Assert-TextContains -Text $app -Needle "Latest FHABS lab-linked sample" -Message "App must expose FHABS lab-result freshness in the status strip."
  Assert-TextContains -Text $app -Needle "before site or arm assignments should be treated as authoritative" -Message "App must preserve map-review caution language."

  $publicBacklog = Get-Content -LiteralPath (Resolve-ProjectPath "docs\public-backlog.md") -Raw
  Assert-TextContains -Text $publicBacklog -Needle "Public Backlog" -Message "Public backlog must define the roadmap index."
  Assert-TextContains -Text $publicBacklog -Needle "late prototype / early MVP" -Message "Public backlog must preserve maturity language."
  Assert-TextContains -Text $publicBacklog -Needle "not official public-health guidance" -Message "Public backlog must preserve public-health boundary."
  Assert-TextContains -Text $publicBacklog -Needle "Completed Public Trust-Hardening Issues" -Message "Public backlog must reflect completed trust-hardening pass."
  Assert-TextContains -Text $publicBacklog -Needle "issues/5" -Message "Public backlog must link the screenshot/release-note issue."
  Assert-TextContains -Text $publicBacklog -Needle "issues/11" -Message "Public backlog must link the reviewer screenshot issue."
  Assert-TextContains -Text $publicBacklog -Needle "Open Reviewer-Readiness Issues" -Message "Public backlog must define the current reviewer-readiness issue set."
  Assert-TextContains -Text $publicBacklog -Needle "issues/21" -Message "Public backlog must link the accessibility reviewer-readiness issue."
  Assert-TextContains -Text $publicBacklog -Needle "issues/24" -Message "Public backlog must link the Career Services handoff issue."
  Assert-TextContains -Text $publicBacklog -Needle "Next Optional Candidates" -Message "Public backlog must define next optional candidates."

  $releaseNote = Get-Content -LiteralPath (Resolve-ProjectPath "docs\public-snapshot-release-note-2026-05-13.md") -Raw
  Assert-TextContains -Text $releaseNote -Needle "Public Snapshot Release Note - 2026-05-13" -Message "Release note must include its title."
  Assert-TextContains -Text $releaseNote -Needle "late prototype / early MVP" -Message "Release note must preserve maturity language."
  Assert-TextContains -Text $releaseNote -Needle "not official public-health guidance" -Message "Release note must preserve public-health boundary."
  Assert-TextContains -Text $releaseNote -Needle "Snapshot generated: May 5, 2026" -Message "Release note must include snapshot generation date."
  Assert-TextContains -Text $releaseNote -Needle "USGS observations through: May 3, 2026" -Message "Release note must include USGS freshness date."
  Assert-TextContains -Text $releaseNote -Needle "September 7, 2025" -Message "Release note must include FHABS report freshness date."
  Assert-TextContains -Text $releaseNote -Needle "January 11, 2024" -Message "Release note must include FHABS lab-linked sample freshness date."
  Assert-TextContains -Text $releaseNote -Needle "clear-lake-watch-homepage-desktop-2026-05-13.png" -Message "Release note must link the desktop screenshot."
  Assert-TextContains -Text $releaseNote -Needle "clear-lake-watch-homepage-mobile-2026-05-13.png" -Message "Release note must link the mobile-width screenshot."
  Assert-TextContains -Text $releaseNote -Needle "before site or arm assignments should be treated as authoritative" -Message "Release note must preserve map-review caution language."

  $siteDecisionWorkflow = Get-Content -LiteralPath (Resolve-ProjectPath "docs\site-registry-decision-workflow.md") -Raw
  Assert-TextContains -Text $siteDecisionWorkflow -Needle "Site Registry Decision Workflow" -Message "Site decision workflow must include its title."
  Assert-TextContains -Text $siteDecisionWorkflow -Needle "not an official source of public-health" -Message "Site decision workflow must preserve public-health boundary."
  Assert-TextContains -Text $siteDecisionWorkflow -Needle "Keep private reviewer notes" -Message "Site decision workflow must preserve private-review boundary."
  Assert-TextContains -Text $siteDecisionWorkflow -Needle "site-registry-trust-review-pass-001.md" -Message "Site decision workflow must link the current review pass."

  $siteReviewPass = Get-Content -LiteralPath (Resolve-ProjectPath "docs\site-registry-trust-review-pass-001.md") -Raw
  Assert-TextContains -Text $siteReviewPass -Needle "Site Registry Trust Review Pass 001" -Message "Site review pass must include its title."
  Assert-TextContains -Text $siteReviewPass -Needle "no current FHABS marker is promoted" -Message "Site review pass must record the no-promotion decision."
  Assert-TextContains -Text $siteReviewPass -Needle "Clear Lake Keys near Ketch Court" -Message "Site review pass must identify the Clear Lake Keys medium-priority check."
  Assert-TextContains -Text $siteReviewPass -Needle "Jago Bay" -Message "Site review pass must identify the Jago Bay medium-priority check."
  Assert-TextContains -Text $siteReviewPass -Needle "Soda Bay" -Message "Site review pass must identify the Soda Bay medium-priority check."
  Assert-TextContains -Text $siteReviewPass -Needle 'Keep `needs-local-review`' -Message "Site review pass must preserve unresolved assignment status."
  Assert-TextContains -Text $siteReviewPass -Needle "not public-health, recreation, emergency, regulatory, or forecasting guidance" -Message "Site review pass must preserve guidance boundary."

  $sourceFreshnessValidation = Get-Content -LiteralPath (Resolve-ProjectPath "docs\source-freshness-validation.md") -Raw
  Assert-TextContains -Text $sourceFreshnessValidation -Needle "Source Freshness Validation" -Message "Source freshness validation doc must include its title."
  Assert-TextContains -Text $sourceFreshnessValidation -Needle "not live monitoring" -Message "Source freshness validation doc must preserve non-operational boundary."
  Assert-TextContains -Text $sourceFreshnessValidation -Needle "dashboard refresh time and source observation dates" -Message "Source freshness validation doc must preserve freshness distinction."
  Assert-TextContains -Text $sourceFreshnessValidation -Needle "Warning Versus Failure" -Message "Source freshness validation doc must explain warning versus failure behavior."

  $scheduledRefreshDesign = Get-Content -LiteralPath (Resolve-ProjectPath "docs\scheduled-public-refresh-design.md") -Raw
  Assert-TextContains -Text $scheduledRefreshDesign -Needle "Scheduled Public Refresh Design" -Message "Scheduled refresh design doc must include its title."
  Assert-TextContains -Text $scheduledRefreshDesign -Needle "No unattended publication workflow is enabled" -Message "Scheduled refresh design must preserve design-only status."
  Assert-TextContains -Text $scheduledRefreshDesign -Needle 'Do not let a scheduled run commit directly to `main`' -Message "Scheduled refresh design must require review before main updates."
  Assert-TextContains -Text $scheduledRefreshDesign -Needle "Fail closed if validation fails" -Message "Scheduled refresh design must define fail-closed behavior."
  Assert-TextContains -Text $scheduledRefreshDesign -Needle "The scheduled workflow must never publish" -Message "Scheduled refresh design must protect private/local files."
  Assert-TextContains -Text $scheduledRefreshDesign -Needle "not live monitoring" -Message "Scheduled refresh design must preserve non-operational boundary."
  Assert-TextContains -Text $scheduledRefreshDesign -Needle "write-weather-context-public-source.ps1" -Message "Scheduled refresh design must reference the reviewed public-source weather writer."

  $weatherContextContract = Get-Content -LiteralPath (Resolve-ProjectPath "docs\weather-context-contract.md") -Raw
  Assert-TextContains -Text $weatherContextContract -Needle "write-weather-context-public-source.ps1" -Message "Weather context contract must document the public-source writer."
  Assert-TextContains -Text $weatherContextContract -Needle "not live telemetry" -Message "Weather context contract must preserve non-live boundary."
  Assert-TextContains -Text $weatherContextContract -Needle 'Use `partial` for a reviewed public-source snapshot' -Message "Weather context contract must explain partial public-source status."

  $fieldMicroscopyContract = Get-Content -LiteralPath (Resolve-ProjectPath "docs\field-microscopy-intake-contract.md") -Raw
  Assert-TextContains -Text $fieldMicroscopyContract -Needle "field-microscopy-review-workflow.md" -Message "Field microscopy contract must link the review workflow."
  Assert-TextContains -Text $fieldMicroscopyContract -Needle 'Only `approved-public` records with `permissionToPublish: true`' -Message "Field microscopy contract must preserve public export permission rule."

  $fieldMicroscopyWorkflow = Get-Content -LiteralPath (Resolve-ProjectPath "docs\field-microscopy-review-workflow.md") -Raw
  Assert-TextContains -Text $fieldMicroscopyWorkflow -Needle "No public submission form is enabled" -Message "Field microscopy workflow must preserve no-public-form boundary."
  Assert-TextContains -Text $fieldMicroscopyWorkflow -Needle "collector name or contact details" -Message "Field microscopy workflow must identify private collector details."
  Assert-TextContains -Text $fieldMicroscopyWorkflow -Needle 'Only `approved-public` records with `permissionToPublish: true`' -Message "Field microscopy workflow must preserve approved-public export gate."
  Assert-TextContains -Text $fieldMicroscopyWorkflow -Needle "It must not include" -Message "Field microscopy workflow must define public export exclusions."
  Assert-TextContains -Text $fieldMicroscopyWorkflow -Needle 'The current public export is `not-connected`' -Message "Field microscopy workflow must preserve current public export state."
  Assert-TextContains -Text $fieldMicroscopyWorkflow -Needle "It is not public-health guidance" -Message "Field microscopy workflow must preserve public-health boundary."

  $reviewerDemoNotes = Get-Content -LiteralPath (Resolve-ProjectPath "docs\reviewer-demo-notes.md") -Raw
  Assert-TextContains -Text $reviewerDemoNotes -Needle "Reviewer Demo Notes" -Message "Reviewer demo notes must include their title."
  Assert-TextContains -Text $reviewerDemoNotes -Needle "Suggested Review Path" -Message "Reviewer demo notes must include a review path."
  Assert-TextContains -Text $reviewerDemoNotes -Needle "Dashboard overview" -Message "Reviewer demo notes must caption the dashboard screenshot."
  Assert-TextContains -Text $reviewerDemoNotes -Needle "Snapshot status strip" -Message "Reviewer demo notes must caption the snapshot-status screenshot."
  Assert-TextContains -Text $reviewerDemoNotes -Needle "Map QA" -Message "Reviewer demo notes must caption the map QA screenshot."
  Assert-TextContains -Text $reviewerDemoNotes -Needle "Methodology page" -Message "Reviewer demo notes must caption the methodology screenshot."
  Assert-TextContains -Text $reviewerDemoNotes -Needle "Project page" -Message "Reviewer demo notes must caption the project-page screenshot."
  Assert-TextContains -Text $reviewerDemoNotes -Needle "dashboard-anatomy-review-guide.md" -Message "Reviewer demo notes must link the dashboard anatomy guide."
  Assert-TextContains -Text $reviewerDemoNotes -Needle "not official public-health guidance" -Message "Reviewer demo notes must preserve public-health boundary."

  $portfolioEvidenceIndex = Get-Content -LiteralPath (Resolve-ProjectPath "docs\portfolio-evidence-index.md") -Raw
  Assert-TextContains -Text $portfolioEvidenceIndex -Needle "Dashboard anatomy review guide" -Message "Portfolio evidence index must link the dashboard anatomy guide."

  $dashboardAnatomyGuide = Get-Content -LiteralPath (Resolve-ProjectPath "docs\dashboard-anatomy-review-guide.md") -Raw
  Assert-TextContains -Text $dashboardAnatomyGuide -Needle "Dashboard Anatomy Review Guide" -Message "Dashboard anatomy guide must include its title."
  Assert-TextContains -Text $dashboardAnatomyGuide -Needle "What This Project Demonstrates" -Message "Dashboard anatomy guide must explain the portfolio demonstration section."
  Assert-TextContains -Text $dashboardAnatomyGuide -Needle "Open-App Data QA Notices" -Message "Dashboard anatomy guide must explain data QA notices."
  Assert-TextContains -Text $dashboardAnatomyGuide -Needle "not official public-health guidance" -Message "Dashboard anatomy guide must preserve public-health boundary."

  $jsonFiles = @(
    "data\sources.json",
    "data\sites.json",
    "data\live.json",
    "data\reports.json",
    "data\observations.json",
    "data\sites-normalized.json",
    "data\site-review-summary.json",
    "data\analytics.json",
    "data\manifest.json",
    "data\lake-shoreline.json",
    "data\forecast-output.example.json",
    "data\field-microscopy-intake.example.json",
    "data\reviewed-field-observations.json",
    "data\weather-context.json",
    "data\weather-context.example.json",
    "manifest.webmanifest"
  )

  foreach ($jsonFile in $jsonFiles) {
    [void](Read-JsonFile $jsonFile)
  }

  $manifest = Read-JsonFile "data\manifest.json"
  if ($manifest -and $manifest.interpretationNotes) {
    $joinedNotes = ($manifest.interpretationNotes -join " ")
    Assert-TextContains -Text $joinedNotes -Needle "not official public-health guidance" -Message "Manifest must preserve public-health boundary."
  }
  if ($manifest -and $manifest.notes) {
    $joinedNotes = ($manifest.notes -join " ")
    Assert-TextContains -Text $joinedNotes -Needle "not official public-health guidance" -Message "Manifest must preserve public-health boundary."
  }

  $liveData = Read-JsonFile "data\live.json"
  Test-ManifestFreshness -Manifest $manifest -LiveData $liveData

  $weatherContext = Read-JsonFile "data\weather-context.json"
  Test-WeatherContext -WeatherContext $weatherContext

  $reviewedFieldObservations = Read-JsonFile "data\reviewed-field-observations.json"
  Test-ReviewedFieldObservations -ReviewedFieldObservations $reviewedFieldObservations

  $siteReviewSummary = Read-JsonFile "data\site-review-summary.json"
  if ($siteReviewSummary -and $siteReviewSummary.summary) {
    if ($siteReviewSummary.summary.needsLocalReview -gt 0) {
      Add-Warning "Some map markers still need local review; public map trust cues should remain conservative."
    }
  }

  if ($CheckHttp) {
    Test-HttpEndpoint "http://127.0.0.1:4173/"
    Test-HttpEndpoint "http://127.0.0.1:4173/project.html"
    Test-HttpEndpoint "http://127.0.0.1:4173/methodology.html"
    Test-HttpEndpoint "http://127.0.0.1:4173/data/manifest.json"
  }

  if ($warnings.Count -gt 0) {
    Write-Host "Warnings:"
    foreach ($warning in $warnings) {
      Write-Host "  - $warning"
    }
  }

  if ($failures.Count -gt 0) {
    Write-Host "Validation failed:"
    foreach ($failure in $failures) {
      Write-Host "  - $failure"
    }
    exit 1
  }

  Write-Host "Validation passed for Clear Lake Watch public mirror."
} finally {
  Pop-Location
}
