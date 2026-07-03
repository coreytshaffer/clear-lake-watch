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

function Assert-WorkingPathAbsent {
  param(
    [string]$RelativePath,
    [string]$Reason
  )

  if (Test-Path -LiteralPath (Resolve-ProjectPath $RelativePath)) {
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

. (Join-Path $PSScriptRoot "public-mirror-link-validation.ps1")

if (-not (Get-Command Test-InternalLinks -CommandType Function -ErrorAction SilentlyContinue)) {
  Add-Failure "Unable to load internal link validation helper."
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
  $fieldDefinitions = $Manifest.fieldDefinitions
  if ($null -eq $fieldDefinitions) {
    Add-Failure "Manifest must include fieldDefinitions for trust clarity."
  } else {
    foreach ($fieldName in @("generatedAt", "latestObservationDate", "resourceDate", "resourceAgeDays")) {
      if ([string]::IsNullOrWhiteSpace($fieldDefinitions.$fieldName)) {
        Add-Failure "Manifest fieldDefinitions is missing $fieldName."
      }
    }
  }

  $freshnessLegendText = (@($Manifest.freshnessLegend) | ForEach-Object { "$($_.term) $($_.definition)" }) -join " "
  foreach ($requiredPhrase in @("Dashboard snapshot freshness", "Observation freshness", "Resource freshness")) {
    Assert-TextContains -Text $freshnessLegendText -Needle $requiredPhrase -Message "Manifest freshnessLegend must include $requiredPhrase."
  }


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
      } else {
        Add-Failure "Manifest source $($source.id) must include resourceDate for FHABS freshness validation."
      }
      if ($null -eq $source.resourceAgeDays) {
        Add-Failure "Manifest source $($source.id) must include resourceAgeDays for FHABS freshness validation."
      } elseif ([int]$source.resourceAgeDays -lt 0) {
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
  Assert-TextContains -Text $notesText -Needle "Resource freshness and observation freshness are separate checks" -Message "Manifest must preserve resource-freshness versus observation-freshness distinction."
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
    "scripts\dashboard-utils.js",
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
    "docs\career-services-handoff-packet.md",
    "docs\accessibility-review.md",
    "docs\browser-accessibility-interaction-pass-2026-05-28.md",
    "docs\mobile-reviewer-path-review.md",
    "docs\internship-review-start-here.md",
    "docs\project-brief.md",
    "docs\Clear-Lake-Watch-Project-Brief.pdf",
    "docs\clear-lake-watch-v0.1-evidence-summary.md",
    "docs\clear_lake_watch_portfolio_case_study.md",
    "docs\county-gis-public-use-check.md",
    "docs\dashboard-anatomy-review-guide.md",
    "docs\deployment.md",
    "docs\field-microscopy-intake-contract.md",
    "docs\field-microscopy-review-workflow.md",
    "docs\variable-register.md",
    "docs\field-validation-plan.md",
    "docs\flagship-maturity-plan.md",
    "docs\forecast-boundary.md",
    "docs\local-first-operating-model.md",
    "docs\maintenance-file-split-2026-05-28.md",
    "docs\public-mirror-boundary.md",
    "docs\public-backlog.md",
    "docs\public-snapshot-release-note-2026-05-13.md",
    "docs\portfolio-evidence-index.md",
    "docs\portfolio-outreach-summary-2026-05-17.md",
    "docs\project-delivery-ehs.md",
    "docs\official-method-source-spine.md",
    "docs\secchi-depth-clarity-mentor-review-protocol.md",
    "docs\secchi-mentor-review-handoff.md",
    "docs\public-screenshots\clear-lake-watch-homepage-desktop-2026-05-13.png",
    "docs\public-screenshots\clear-lake-watch-homepage-mobile-2026-05-13.png",
    "docs\public-screenshots\clear-lake-watch-homepage-desktop-2026-05-14.png",
    "docs\public-screenshots\clear-lake-watch-homepage-mobile-2026-05-14.png",
    "docs\public-screenshots\clear-lake-watch-dashboard-overview-2026-05-14.png",
    "docs\public-screenshots\clear-lake-watch-snapshot-status-2026-05-14.png",
    "docs\public-screenshots\clear-lake-watch-portfolio-signal-2026-05-14.png",
    "docs\public-screenshots\clear-lake-watch-data-qa-notices-2026-05-14.png",
    "docs\public-screenshots\clear-lake-watch-map-qa-2026-05-14.png",
    "docs\public-screenshots\clear-lake-watch-methodology-2026-05-14.png",
    "docs\public-screenshots\clear-lake-watch-project-page-2026-05-14.png",
    "docs\site-registry-decision-workflow.md",
    "docs\site-registry-trust-review-pass-001.md",
    "docs\site-registry-unresolved-decision.md",
    "docs\publication-review-checklist.md",
    "docs\published-commentary.md",
    "docs\research-readiness-brief.md",
    "docs\reviewer-demo-notes.md",
    "docs\resume-linkedin-snippets.md",
    "docs\scheduled-public-refresh-design.md",
    "docs\manual-refresh-dry-run-2026-05-28.md",
    "docs\source-audit.md",
    "docs\source-freshness-validation.md",
    "docs\weather-context-contract.md",
    "scripts\refresh-live-data.ps1",
    "scripts\refresh-live-data.utilities.ps1",
    "scripts\public-mirror-link-validation.ps1",
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
    "docs\communications-log.md",
    "docs\conversation-log.md",
    "docs\private",
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

  $publicUnsafeWorkingPaths = @(
    "geometry-preview.html",
    "data\lake-shoreline-county-candidate.json",
    "data\lake-shoreline-county-simplified-25ft.json",
    "data\lake-shoreline-county-simplified-50ft.json"
  )

  foreach ($path in $publicUnsafeWorkingPaths) {
    Assert-WorkingPathAbsent -RelativePath $path -Reason "Public mirror must not expose unverified county GIS review artifact"
  }

  $linkCheckFiles = @(
    $trackedFiles |
      Where-Object {
        $_ -match '\.(md|html|js|webmanifest)$' -and
        $_ -notmatch '^docs/private/' -and
        $_ -notmatch '^data/private/'
      }
  )

  Test-InternalLinks -RelativeFiles $linkCheckFiles

  $readme = Get-Content -LiteralPath (Resolve-ProjectPath "README.md") -Raw
  $index = Get-Content -LiteralPath (Resolve-ProjectPath "index.html") -Raw
  $project = Get-Content -LiteralPath (Resolve-ProjectPath "project.html") -Raw
  $methodology = Get-Content -LiteralPath (Resolve-ProjectPath "methodology.html") -Raw
  $styles = Get-Content -LiteralPath (Resolve-ProjectPath "styles.css") -Raw
  $app = Get-Content -LiteralPath (Resolve-ProjectPath "app.js") -Raw
  $dashboardUtils = Get-Content -LiteralPath (Resolve-ProjectPath "scripts\dashboard-utils.js") -Raw
  $serviceWorker = Get-Content -LiteralPath (Resolve-ProjectPath "sw.js") -Raw

  Assert-TextContains -Text $readme -Needle "late-prototype / early-MVP" -Message "README must preserve maturity language."
  Assert-TextContains -Text $readme -Needle "not official public-health guidance" -Message "README must preserve public-health boundary."
  Assert-TextContains -Text $readme -Needle "Weather context is a reviewed public-source snapshot and remains separate from lake-health interpretation." -Message "README must describe weather context as reviewed public-source context."
  Assert-TextContains -Text $readme -Needle "not part of this public mirror branch" -Message "README must explain that private review materials are excluded."
  Assert-TextContains -Text $readme -Needle "docs/public-backlog.md" -Message "README must link the public backlog."
  Assert-TextContains -Text $readme -Needle "docs/public-snapshot-release-note-2026-05-13.md" -Message "README must link the public snapshot release note."
  Assert-TextContains -Text $readme -Needle "docs/reviewer-demo-notes.md" -Message "README must link the reviewer demo notes."
  Assert-TextContains -Text $readme -Needle "docs/site-registry-trust-review-pass-001.md" -Message "README must link the site-registry review pass."
  Assert-TextContains -Text $readme -Needle "docs/official-method-source-spine.md" -Message "README must link the official method source spine."
  Assert-TextContains -Text $readme -Needle "docs/secchi-depth-clarity-mentor-review-protocol.md" -Message "README must link the Secchi mentor-review protocol."
  Assert-TextContains -Text $readme -Needle "docs/secchi-mentor-review-handoff.md" -Message "README must link the Secchi mentor-review handoff."
  Assert-TextContains -Text $index -Needle "late prototype / early MVP" -Message "Homepage must preserve maturity language."
  Assert-TextContains -Text $index -Needle "Internship portfolio prototype showing Clear Lake environmental data integration, GIS/spatial QA, source-freshness validation, static deployment, and responsible public communication." -Message "Homepage meta description must describe the internship portfolio signal."
  Assert-TextContains -Text $index -Needle "source-resource dates" -Message "Homepage must distinguish source-resource dates from observation dates."
  Assert-TextContains -Text $index -Needle "source-freshness-legend" -Message "Homepage must expose the freshness legend container."
  Assert-TextContains -Text $index -Needle "Internship Reviewer Path" -Message "Homepage must include an above-the-fold reviewer path."
  Assert-TextContains -Text $index -Needle "Dashboard snapshot" -Message "Homepage reviewer path must start with the dashboard snapshot."
  Assert-TextContains -Text $index -Needle "github.com/coreytshaffer/clear-lake-watch/blob/main/docs/clear-lake-watch-v0.1-evidence-summary.md" -Message "Homepage reviewer path must link the GitHub evidence summary."
  Assert-TextContains -Text $index -Needle "github.com/coreytshaffer/clear-lake-watch/blob/main/docs/reviewer-demo-notes.md" -Message "Homepage reviewer path must link GitHub reviewer demo notes."
  Assert-TextContains -Text $index -Needle "Public Data Snapshot, Not Advisory Guidance" -Message "Homepage must include the public snapshot status strip."
  Assert-TextContains -Text $index -Needle "What The Public Snapshot Files Are Showing" -Message "Homepage must avoid overclaiming current-feed wording."
  Assert-TextContains -Text $index -Needle "Deeper Review Links" -Message "Homepage must include secondary reviewer entry points."
  Assert-TextContains -Text $index -Needle "What This Project Demonstrates" -Message "Homepage must include a portfolio demonstration section."
  Assert-TextContains -Text $index -Needle "map-review-status" -Message "Homepage must include the map review status callout."
  Assert-TextContains -Text $styles -Needle "@media print" -Message "Stylesheet must include print-friendly output rules."
  Assert-TextContains -Text $styles -Needle ".site-nav" -Message "Print stylesheet must account for navigation."
  Assert-TextContains -Text $styles -Needle "a[href]::after" -Message "Print stylesheet must expose link targets."
  Assert-TextContains -Text $methodology -Needle "not official public-health direction" -Message "Methodology page must preserve public-health boundary."
  Assert-TextContains -Text $project -Needle "not official public-health guidance" -Message "Project page must preserve public-health boundary."
  Assert-TextContains -Text $project -Needle "late prototype / early MVP" -Message "Project page must preserve maturity language."
  Assert-TextContains -Text $project -Needle "Unresolved markers remain in local review" -Message "Project page must preserve site-review caution language."
  Assert-TextContains -Text $index -Needle "local browser notices only, not background emergency or official public-health notifications" -Message "Dashboard must preserve data-QA notice boundary."
  Assert-TextContains -Text $project -Needle "docs/forecast-boundary.md" -Message "Project page must link forecast boundary."
  Assert-TextContains -Text $app -Needle "site-review-summary.json" -Message "App must consume public site-review summary."
  Assert-TextContains -Text $app -Needle './scripts/dashboard-utils.js' -Message "App must import shared dashboard utilities."
  Assert-TextContains -Text $dashboardUtils -Needle "export const formatDate" -Message "Dashboard utilities must export date formatting."
  Assert-TextContains -Text $dashboardUtils -Needle "export const getStoredJson" -Message "Dashboard utilities must export localStorage JSON helper."
  Assert-TextContains -Text $serviceWorker -Needle './scripts/dashboard-utils.js' -Message "Service worker must cache the shared dashboard utilities."
  Assert-TextContains -Text $app -Needle "renderSnapshotStatusStrip" -Message "App must render the snapshot status strip."
  Assert-TextContains -Text $app -Needle "Latest Clear Lake FHABS report" -Message "App must expose FHABS report freshness in the status strip."
  Assert-TextContains -Text $app -Needle "Latest FHABS lab-linked sample" -Message "App must expose FHABS lab-result freshness in the status strip."
  Assert-TextContains -Text $app -Needle "Observation freshness can be older than dashboard refresh time" -Message "App must distinguish dashboard refresh time from observation freshness."
  Assert-TextContains -Text $app -Needle "Resource freshness: source file was" -Message "App must label resource freshness separately from observation freshness."
  Assert-TextContains -Text $app -Needle "before site or arm assignments should be treated as authoritative" -Message "App must preserve map-review caution language."

  $publicBacklog = Get-Content -LiteralPath (Resolve-ProjectPath "docs\public-backlog.md") -Raw
  Assert-TextContains -Text $publicBacklog -Needle "Public Backlog" -Message "Public backlog must define the roadmap index."
  Assert-TextContains -Text $publicBacklog -Needle "late prototype / early MVP" -Message "Public backlog must preserve maturity language."
  Assert-TextContains -Text $publicBacklog -Needle "not official public-health guidance" -Message "Public backlog must preserve public-health boundary."
  Assert-TextContains -Text $publicBacklog -Needle "Completed Public Trust-Hardening Issues" -Message "Public backlog must reflect completed trust-hardening pass."
  Assert-TextContains -Text $publicBacklog -Needle "above-the-fold internship reviewer path" -Message "Public backlog must record the homepage reviewer-path stabilization."
  Assert-TextContains -Text $publicBacklog -Needle "print-friendly public review output" -Message "Public backlog must record the print-friendly reviewer output."
  Assert-TextContains -Text $publicBacklog -Needle "This is a review-path improvement only." -Message "Public backlog must keep reviewer-path stabilization boundary language."
  Assert-TextContains -Text $publicBacklog -Needle "official method source spine" -Message "Public backlog must record the official method source spine."
  Assert-TextContains -Text $publicBacklog -Needle "This is a source-selection improvement only." -Message "Public backlog must preserve source-spine boundary language."
  Assert-TextContains -Text $publicBacklog -Needle "Decision recorded: keep the Secchi protocol mentor-review-only for now." -Message "Public backlog must record the mentor-review-only Secchi decision."
  Assert-TextContains -Text $publicBacklog -Needle "Secchi mentor-review handoff packet" -Message "Public backlog must record the Secchi mentor-review handoff packet."
  Assert-TextContains -Text $publicBacklog -Needle "issues/5" -Message "Public backlog must link the screenshot/release-note issue."
  Assert-TextContains -Text $publicBacklog -Needle "issues/11" -Message "Public backlog must link the reviewer screenshot issue."
  Assert-TextContains -Text $publicBacklog -Needle "Open Reviewer-Readiness Issues" -Message "Public backlog must define the current reviewer-readiness issue set."
  Assert-TextContains -Text $publicBacklog -Needle "issues/21" -Message "Public backlog must link the accessibility reviewer-readiness issue."
  Assert-TextContains -Text $publicBacklog -Needle "issues/24" -Message "Public backlog must link the Career Services handoff issue."
  Assert-TextContains -Text $publicBacklog -Needle "Next Optional Candidates" -Message "Public backlog must define next optional candidates."
  Assert-TextContains -Text $publicBacklog -Needle "Completed Maintenance / Trust Issues" -Message "Public backlog must define completed maintenance/trust issues."
  Assert-TextContains -Text $publicBacklog -Needle "Open Maintenance / Trust Issues" -Message "Public backlog must define implementation-facing maintenance candidates."
  Assert-TextContains -Text $publicBacklog -Needle "Internal link validation" -Message "Public backlog must include internal link validation candidate."
  Assert-TextContains -Text $publicBacklog -Needle "Static snapshot age cue" -Message "Public backlog must include static snapshot age cue status."
  Assert-TextContains -Text $publicBacklog -Needle "Manual-only refresh dry-run support" -Message "Public backlog must include manual refresh dry-run support status."
  Assert-TextContains -Text $publicBacklog -Needle "Site-registry local review pass" -Message "Public backlog must include site-registry local review pass status."
  Assert-TextContains -Text $publicBacklog -Needle "County GIS geometry publication boundary" -Message "Public backlog must include county GIS publication-boundary candidate."
  Assert-TextContains -Text $publicBacklog -Needle "Browser accessibility interaction pass" -Message "Public backlog must include browser accessibility interaction-pass status."
  Assert-TextContains -Text $publicBacklog -Needle "Maintenance file split" -Message "Public backlog must include maintenance file split status."
  Assert-TextContains -Text $publicBacklog -Needle "Freshness and publication-safety alignment follow-ups" -Message "Public backlog must track the freshness and publication-safety alignment follow-ups."

  $releaseNote = Get-Content -LiteralPath (Resolve-ProjectPath "docs\public-snapshot-release-note-2026-05-13.md") -Raw
  Assert-TextContains -Text $releaseNote -Needle "Public Snapshot Release Note - 2026-05-13" -Message "Release note must include its title."
  Assert-TextContains -Text $releaseNote -Needle "late prototype / early MVP" -Message "Release note must preserve maturity language."
  Assert-TextContains -Text $releaseNote -Needle "not official public-health guidance" -Message "Release note must preserve public-health boundary."
  Assert-TextContains -Text $releaseNote -Needle "Snapshot generated: May 5, 2026" -Message "Release note must include snapshot generation date."
  Assert-TextContains -Text $releaseNote -Needle "USGS observations through: May 3, 2026" -Message "Release note must include USGS freshness date."
  Assert-TextContains -Text $releaseNote -Needle "September 7, 2025" -Message "Release note must include FHABS report freshness date."
  Assert-TextContains -Text $releaseNote -Needle "January 11, 2024" -Message "Release note must include FHABS lab-linked sample freshness date."
  Assert-TextContains -Text $releaseNote -Needle "Static Snapshot Age Cue" -Message "Release note must include a static snapshot age cue."
  Assert-TextContains -Text $releaseNote -Needle "snapshot-age badge" -Message "Release note must point to the dashboard's dynamic snapshot-age badge instead of a hardcoded day count."
  Assert-TextContains -Text $releaseNote -Needle "not current bloom observations" -Message "Release note must preserve stale FHABS warning framing."
  Assert-TextContains -Text $releaseNote -Needle "clear-lake-watch-homepage-desktop-2026-05-13.png" -Message "Release note must link the desktop screenshot."
  Assert-TextContains -Text $releaseNote -Needle "clear-lake-watch-homepage-mobile-2026-05-13.png" -Message "Release note must link the mobile-width screenshot."
  Assert-TextContains -Text $releaseNote -Needle "before site or arm assignments should be treated as authoritative" -Message "Release note must preserve map-review caution language."

  $countyGisPublicUseCheck = Get-Content -LiteralPath (Resolve-ProjectPath "docs\county-gis-public-use-check.md") -Raw
  Assert-TextContains -Text $countyGisPublicUseCheck -Needle "needs verification before public promotion" -Message "County GIS public-use check must block promotion until terms are verified."
  Assert-TextContains -Text $countyGisPublicUseCheck -Needle "OpenStreetMap-derived" -Message "County GIS public-use check must keep OSM as current public geometry."
  Assert-TextContains -Text $countyGisPublicUseCheck -Needle "data/private/county-gis/" -Message "County GIS public-use check must keep local review files outside the public mirror."
  Assert-TextContains -Text $countyGisPublicUseCheck -Needle "Terms allow redistribution of derived coordinate JSON" -Message "County GIS public-use check must require derived-JSON reuse verification."
  Assert-TextContains -Text $countyGisPublicUseCheck -Needle "keep county-derived candidate JSON out of the public mirror" -Message "County GIS public-use check must name the fallback if terms cannot be verified."

  $siteDecisionWorkflow = Get-Content -LiteralPath (Resolve-ProjectPath "docs\site-registry-decision-workflow.md") -Raw
  Assert-TextContains -Text $siteDecisionWorkflow -Needle "Site Registry Decision Workflow" -Message "Site decision workflow must include its title."
  Assert-TextContains -Text $siteDecisionWorkflow -Needle "not an official source of public-health" -Message "Site decision workflow must preserve public-health boundary."
  Assert-TextContains -Text $siteDecisionWorkflow -Needle "Keep private reviewer notes" -Message "Site decision workflow must preserve private-review boundary."
  Assert-TextContains -Text $siteDecisionWorkflow -Needle "site-registry-trust-review-pass-001.md" -Message "Site decision workflow must link the current review pass."
  Assert-TextContains -Text $siteDecisionWorkflow -Needle "site-registry-unresolved-decision.md" -Message "Site decision workflow must link the unresolved medium-priority decision note."

  $siteReviewPass = Get-Content -LiteralPath (Resolve-ProjectPath "docs\site-registry-trust-review-pass-001.md") -Raw
  Assert-TextContains -Text $siteReviewPass -Needle "Site Registry Trust Review Pass 001" -Message "Site review pass must include its title."
  Assert-TextContains -Text $siteReviewPass -Needle "no current FHABS marker is promoted" -Message "Site review pass must record the no-promotion decision."
  Assert-TextContains -Text $siteReviewPass -Needle "Clear Lake Keys near Ketch Court" -Message "Site review pass must identify the Clear Lake Keys medium-priority check."
  Assert-TextContains -Text $siteReviewPass -Needle "Jago Bay" -Message "Site review pass must identify the Jago Bay medium-priority check."
  Assert-TextContains -Text $siteReviewPass -Needle "Soda Bay" -Message "Site review pass must identify the Soda Bay medium-priority check."
  Assert-TextContains -Text $siteReviewPass -Needle 'Keep `needs-local-review`' -Message "Site review pass must preserve unresolved assignment status."
  Assert-TextContains -Text $siteReviewPass -Needle "not public-health, recreation, emergency, regulatory, or forecasting guidance" -Message "Site review pass must preserve guidance boundary."
  Assert-TextContains -Text $siteReviewPass -Needle "site-registry-unresolved-decision.md" -Message "Site review pass must link the unresolved medium-priority decision note."

  $siteUnresolvedDecision = Get-Content -LiteralPath (Resolve-ProjectPath "docs\site-registry-unresolved-decision.md") -Raw
  Assert-TextContains -Text $siteUnresolvedDecision -Needle "Site Registry Unresolved Decision" -Message "Site unresolved decision note must include its title."
  Assert-TextContains -Text $siteUnresolvedDecision -Needle "Clear Lake Keys near Ketch Court" -Message "Site unresolved decision note must include the Clear Lake Keys medium-priority case."
  Assert-TextContains -Text $siteUnresolvedDecision -Needle "Jago Bay" -Message "Site unresolved decision note must include the Jago Bay medium-priority case."
  Assert-TextContains -Text $siteUnresolvedDecision -Needle "Soda Bay" -Message "Site unresolved decision note must include the Soda Bay medium-priority case."
  Assert-TextContains -Text $siteUnresolvedDecision -Needle 'Keep `needs-local-review`' -Message "Site unresolved decision note must preserve unresolved assignment status."
  Assert-TextContains -Text $siteUnresolvedDecision -Needle "not public-health guidance" -Message "Site unresolved decision note must preserve public-health boundary."

  $sourceFreshnessValidation = Get-Content -LiteralPath (Resolve-ProjectPath "docs\source-freshness-validation.md") -Raw
  Assert-TextContains -Text $sourceFreshnessValidation -Needle "Source Freshness Validation" -Message "Source freshness validation doc must include its title."
  Assert-TextContains -Text $sourceFreshnessValidation -Needle "not live monitoring" -Message "Source freshness validation doc must preserve non-operational boundary."
  Assert-TextContains -Text $sourceFreshnessValidation -Needle "dashboard refresh time and source observation dates" -Message "Source freshness validation doc must preserve freshness distinction."
  Assert-TextContains -Text $sourceFreshnessValidation -Needle "Resource freshness and observation freshness are separate checks" -Message "Source freshness validation doc must preserve resource-versus-observation freshness distinction."
  Assert-TextContains -Text $sourceFreshnessValidation -Needle "Warning Versus Failure" -Message "Source freshness validation doc must explain warning versus failure behavior."

  $scheduledRefreshDesign = Get-Content -LiteralPath (Resolve-ProjectPath "docs\scheduled-public-refresh-design.md") -Raw
  Assert-TextContains -Text $scheduledRefreshDesign -Needle "Scheduled Public Refresh Design" -Message "Scheduled refresh design doc must include its title."
  Assert-TextContains -Text $scheduledRefreshDesign -Needle "No unattended publication workflow is enabled" -Message "Scheduled refresh design must preserve design-only status."
  Assert-TextContains -Text $scheduledRefreshDesign -Needle 'Do not let a scheduled run commit directly to `main`' -Message "Scheduled refresh design must require review before main updates."
  Assert-TextContains -Text $scheduledRefreshDesign -Needle "Fail closed if validation fails" -Message "Scheduled refresh design must define fail-closed behavior."
  Assert-TextContains -Text $scheduledRefreshDesign -Needle "The scheduled workflow must never publish" -Message "Scheduled refresh design must protect private/local files."
  Assert-TextContains -Text $scheduledRefreshDesign -Needle "not live monitoring" -Message "Scheduled refresh design must preserve non-operational boundary."
  Assert-TextContains -Text $scheduledRefreshDesign -Needle "write-weather-context-public-source.ps1" -Message "Scheduled refresh design must reference the reviewed public-source weather writer."
  Assert-TextContains -Text $scheduledRefreshDesign -Needle "refresh-live-data.ps1 -DryRun" -Message "Scheduled refresh design must document the manual dry-run command."
  Assert-TextContains -Text $scheduledRefreshDesign -Needle "skips all public JSON writes" -Message "Scheduled refresh design must explain that dry runs do not mutate public JSON."
  Assert-TextContains -Text $scheduledRefreshDesign -Needle "manual-refresh-dry-run-2026-05-28.md" -Message "Scheduled refresh design must link the latest manual dry-run proof note."

  $manualRefreshDryRun = Get-Content -LiteralPath (Resolve-ProjectPath "docs\manual-refresh-dry-run-2026-05-28.md") -Raw
  Assert-TextContains -Text $manualRefreshDryRun -Needle "Manual Refresh Dry Run - 2026-05-28" -Message "Manual refresh dry-run note must include its title."
  Assert-TextContains -Text $manualRefreshDryRun -Needle "completed local dry-run rehearsal" -Message "Manual refresh dry-run note must record completion status."
  Assert-TextContains -Text $manualRefreshDryRun -Needle "the files above were not written" -Message "Manual refresh dry-run note must state that public JSON files were not written."
  Assert-TextContains -Text $manualRefreshDryRun -Needle "not publish a new snapshot" -Message "Manual refresh dry-run note must preserve publication boundary."

  $maintenanceFileSplit = Get-Content -LiteralPath (Resolve-ProjectPath "docs\maintenance-file-split-2026-05-28.md") -Raw
  Assert-TextContains -Text $maintenanceFileSplit -Needle "Maintenance File Split - 2026-05-28" -Message "Maintenance split note must include its title."
  Assert-TextContains -Text $maintenanceFileSplit -Needle "scripts/dashboard-utils.js" -Message "Maintenance split note must record dashboard utility extraction."
  Assert-TextContains -Text $maintenanceFileSplit -Needle "scripts/public-mirror-link-validation.ps1" -Message "Maintenance split note must record validator helper extraction."
  Assert-TextContains -Text $maintenanceFileSplit -Needle "scripts/refresh-live-data.utilities.ps1" -Message "Maintenance split note must record refresh helper extraction."
  Assert-TextContains -Text $maintenanceFileSplit -Needle "refresh-live-data.ps1 -DryRun" -Message "Maintenance split note must record refresh dry-run verification."
  Assert-TextContains -Text $maintenanceFileSplit -Needle "not official public-health guidance" -Message "Maintenance split note must preserve public-health boundary."

  $refreshLiveData = Get-Content -LiteralPath (Resolve-ProjectPath "scripts\refresh-live-data.ps1") -Raw
  $refreshLiveDataUtilities = Get-Content -LiteralPath (Resolve-ProjectPath "scripts\refresh-live-data.utilities.ps1") -Raw
  Assert-TextContains -Text $refreshLiveData -Needle "[switch]`$DryRun" -Message "Refresh script must expose a DryRun switch."
  Assert-TextContains -Text $refreshLiveData -Needle "refresh-live-data.utilities.ps1" -Message "Refresh script must import shared refresh utilities."
  Assert-TextContains -Text $refreshLiveData -Needle "Dry run: would write" -Message "Refresh script must report skipped writes during dry runs."
  Assert-TextContains -Text $refreshLiveData -Needle "[System.IO.File]::WriteAllText" -Message "Refresh script must retain the real write path for intentional refreshes."
  Assert-TextContains -Text $refreshLiveDataUtilities -Needle "function Get-RecordField" -Message "Refresh utility helper must include field lookup."
  Assert-TextContains -Text $refreshLiveDataUtilities -Needle "function Parse-Number" -Message "Refresh utility helper must include number parsing."

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

  $variableRegister = Get-Content -LiteralPath (Resolve-ProjectPath "docs\variable-register.md") -Raw
  Assert-TextContains -Text $variableRegister -Needle "Variable Register" -Message "Variable register must include its title."
  Assert-TextContains -Text $variableRegister -Needle "future-field-validation" -Message "Variable register must distinguish future field-validation variables."
  Assert-TextContains -Text $variableRegister -Needle "future-lab-or-microscopy" -Message "Variable register must distinguish future lab or microscopy variables."
  Assert-TextContains -Text $variableRegister -Needle "future-sensor-or-backbone" -Message "Variable register must distinguish future sensor or backbone variables."
  Assert-TextContains -Text $variableRegister -Needle "do-not-use-as-label" -Message "Variable register must define variables that should not become public labels."
  Assert-TextContains -Text $variableRegister -Needle "official-method-source-spine.md" -Message "Variable register must link the official method source spine."
  Assert-TextContains -Text $variableRegister -Needle "not official public-health guidance" -Message "Variable register must preserve public-health boundary."

  $fieldValidationPlan = Get-Content -LiteralPath (Resolve-ProjectPath "docs\field-validation-plan.md") -Raw
  Assert-TextContains -Text $fieldValidationPlan -Needle "Field Validation Plan" -Message "Field validation plan must include its title."
  Assert-TextContains -Text $fieldValidationPlan -Needle "official-method-source-spine.md" -Message "Field validation plan must link the official method source spine."
  Assert-TextContains -Text $fieldValidationPlan -Needle "secchi-depth-clarity-mentor-review-protocol.md" -Message "Field validation plan must link the Secchi mentor-review protocol."
  Assert-TextContains -Text $fieldValidationPlan -Needle "Keep the Secchi depth / clarity protocol mentor-review-only for now." -Message "Field validation plan must preserve the mentor-review-only Secchi decision."
  Assert-TextContains -Text $fieldValidationPlan -Needle "Which Lake County QAPP, EPA, SWAMP/CEDEN, or lab method should govern the written protocol?" -Message "Field validation plan must ask source-anchor mentor review question."
  Assert-TextContains -Text $fieldValidationPlan -Needle "Calibration And QA/QC Questions" -Message "Field validation plan must document calibration and QA/QC questions."
  Assert-TextContains -Text $fieldValidationPlan -Needle "Public Export Gate" -Message "Field validation plan must define a public export gate."
  Assert-TextContains -Text $fieldValidationPlan -Needle "field-microscopy-review-workflow.md" -Message "Field validation plan must link the field/microscopy review workflow."
  Assert-TextContains -Text $fieldValidationPlan -Needle "weather-context-contract.md" -Message "Field validation plan must link the weather context contract."
  Assert-TextContains -Text $fieldValidationPlan -Needle "not official public-health guidance" -Message "Field validation plan must preserve public-health boundary."

  $reviewerDemoNotes = Get-Content -LiteralPath (Resolve-ProjectPath "docs\reviewer-demo-notes.md") -Raw
  Assert-TextContains -Text $reviewerDemoNotes -Needle "Reviewer Demo Notes" -Message "Reviewer demo notes must include their title."
  Assert-TextContains -Text $reviewerDemoNotes -Needle "Suggested Review Path" -Message "Reviewer demo notes must include a review path."
  Assert-TextContains -Text $reviewerDemoNotes -Needle "Homepage desktop" -Message "Reviewer demo notes must caption the refreshed desktop homepage screenshot."
  Assert-TextContains -Text $reviewerDemoNotes -Needle "Homepage mobile" -Message "Reviewer demo notes must caption the refreshed mobile homepage screenshot."
  Assert-TextContains -Text $reviewerDemoNotes -Needle "Dashboard overview" -Message "Reviewer demo notes must caption the dashboard screenshot."
  Assert-TextContains -Text $reviewerDemoNotes -Needle "Snapshot status strip" -Message "Reviewer demo notes must caption the snapshot-status screenshot."
  Assert-TextContains -Text $reviewerDemoNotes -Needle "Portfolio signal" -Message "Reviewer demo notes must caption the portfolio signal screenshot."
  Assert-TextContains -Text $reviewerDemoNotes -Needle "Open-App Data QA Notices" -Message "Reviewer demo notes must caption the data QA notices screenshot."
  Assert-TextContains -Text $reviewerDemoNotes -Needle "Map QA" -Message "Reviewer demo notes must caption the map QA screenshot."
  Assert-TextContains -Text $reviewerDemoNotes -Needle "Methodology page" -Message "Reviewer demo notes must caption the methodology screenshot."
  Assert-TextContains -Text $reviewerDemoNotes -Needle "Project page" -Message "Reviewer demo notes must caption the project-page screenshot."
  Assert-TextContains -Text $reviewerDemoNotes -Needle "dashboard-anatomy-review-guide.md" -Message "Reviewer demo notes must link the dashboard anatomy guide."
  Assert-TextContains -Text $reviewerDemoNotes -Needle "snapshot-age badge" -Message "Reviewer demo notes must point to the dashboard's dynamic snapshot-age badge instead of a hardcoded day count."
  Assert-TextContains -Text $reviewerDemoNotes -Needle "not official public-health guidance" -Message "Reviewer demo notes must preserve public-health boundary."

  $portfolioEvidenceIndex = Get-Content -LiteralPath (Resolve-ProjectPath "docs\portfolio-evidence-index.md") -Raw
  Assert-TextContains -Text $portfolioEvidenceIndex -Needle "Dashboard anatomy review guide" -Message "Portfolio evidence index must link the dashboard anatomy guide."
  Assert-TextContains -Text $portfolioEvidenceIndex -Needle "Career Services handoff packet" -Message "Portfolio evidence index must link the Career Services handoff packet."
  Assert-TextContains -Text $portfolioEvidenceIndex -Needle "Project Delivery, EHS, and Environmental Systems Governance" -Message "Portfolio evidence index must link the project delivery and EHS positioning aid."
  Assert-TextContains -Text $portfolioEvidenceIndex -Needle "Official method source spine" -Message "Portfolio evidence index must link the official method source spine."
  Assert-TextContains -Text $portfolioEvidenceIndex -Needle "Secchi depth / clarity mentor-review protocol" -Message "Portfolio evidence index must link the Secchi mentor-review protocol."
  Assert-TextContains -Text $portfolioEvidenceIndex -Needle "Secchi mentor-review handoff" -Message "Portfolio evidence index must link the Secchi mentor-review handoff."
  Assert-TextContains -Text $portfolioEvidenceIndex -Needle "Internship review start here" -Message "Portfolio evidence index must link the internship start-here path."

  $portfolioOutreachSummary = Get-Content -LiteralPath (Resolve-ProjectPath "docs\portfolio-outreach-summary-2026-05-17.md") -Raw
  Assert-TextContains -Text $portfolioOutreachSummary -Needle "Clear Lake Watch Portfolio Outreach Summary" -Message "Portfolio outreach summary must include its title."
  Assert-TextContains -Text $portfolioOutreachSummary -Needle "late-prototype / early-MVP" -Message "Portfolio outreach summary must preserve maturity language."
  Assert-TextContains -Text $portfolioOutreachSummary -Needle "not official public-health guidance" -Message "Portfolio outreach summary must preserve public-health boundary."
  Assert-TextContains -Text $portfolioOutreachSummary -Needle "Strongest Current Claim" -Message "Portfolio outreach summary must include the strongest current claim."
  Assert-TextContains -Text $portfolioOutreachSummary -Needle "Current Review Ask" -Message "Portfolio outreach summary must include the current review ask."
  Assert-TextContains -Text $portfolioOutreachSummary -Needle "official-method planning" -Message "Portfolio outreach summary must include official-method planning language."
  Assert-TextContains -Text $portfolioOutreachSummary -Needle "Avoid:" -Message "Portfolio outreach summary must include avoid-language boundaries."

  $officialMethodSourceSpine = Get-Content -LiteralPath (Resolve-ProjectPath "docs\official-method-source-spine.md") -Raw
  Assert-TextContains -Text $officialMethodSourceSpine -Needle "Official Method Source Spine" -Message "Official method source spine must include its title."
  Assert-TextContains -Text $officialMethodSourceSpine -Needle "Lake County Clear Lake QAPP" -Message "Official method source spine must include Lake County QAPP anchor."
  Assert-TextContains -Text $officialMethodSourceSpine -Needle "EPA quality assurance guidance" -Message "Official method source spine must include EPA QA anchor."
  Assert-TextContains -Text $officialMethodSourceSpine -Needle "EPA lake and volunteer monitoring methods" -Message "Official method source spine must include EPA lake/volunteer method anchor."
  Assert-TextContains -Text $officialMethodSourceSpine -Needle "Secchi depth / clarity" -Message "Official method source spine must identify the first Secchi protocol candidate."
  Assert-TextContains -Text $officialMethodSourceSpine -Needle "secchi-depth-clarity-mentor-review-protocol.md" -Message "Official method source spine must link the Secchi mentor-review protocol."
  Assert-TextContains -Text $officialMethodSourceSpine -Needle "keep the Secchi protocol mentor-review-only for now" -Message "Official method source spine must preserve the mentor-review-only Secchi decision."
  Assert-TextContains -Text $officialMethodSourceSpine -Needle "not official public-health guidance" -Message "Official method source spine must preserve public-health boundary."

  $secchiProtocol = Get-Content -LiteralPath (Resolve-ProjectPath "docs\secchi-depth-clarity-mentor-review-protocol.md") -Raw
  Assert-TextContains -Text $secchiProtocol -Needle "Secchi Depth / Clarity Mentor-Review Protocol" -Message "Secchi protocol must include its title."
  Assert-TextContains -Text $secchiProtocol -Needle "mentor-review-needed" -Message "Secchi protocol must preserve mentor-review-needed status."
  Assert-TextContains -Text $secchiProtocol -Needle "mentor-review-only for now" -Message "Secchi protocol must preserve the mentor-review-only decision."
  Assert-TextContains -Text $secchiProtocol -Needle "not an approved field protocol" -Message "Secchi protocol must preserve non-approved boundary."
  Assert-TextContains -Text $secchiProtocol -Needle "What Not To Infer" -Message "Secchi protocol must define interpretation limits."
  Assert-TextContains -Text $secchiProtocol -Needle "Private-To-Public Gate" -Message "Secchi protocol must define a private-to-public gate."
  Assert-TextContains -Text $secchiProtocol -Needle "Do not use a Secchi reading by itself" -Message "Secchi protocol must prevent overinterpretation."
  Assert-TextContains -Text $secchiProtocol -Needle "secchi-mentor-review-handoff.md" -Message "Secchi protocol must link the mentor-review handoff."
  Assert-TextContains -Text $secchiProtocol -Needle "not official public-health guidance" -Message "Secchi protocol must preserve public-health boundary."

  $secchiHandoff = Get-Content -LiteralPath (Resolve-ProjectPath "docs\secchi-mentor-review-handoff.md") -Raw
  Assert-TextContains -Text $secchiHandoff -Needle "Secchi Mentor-Review Handoff" -Message "Secchi mentor-review handoff must include its title."
  Assert-TextContains -Text $secchiHandoff -Needle "Keep the Secchi protocol mentor-review-only for now." -Message "Secchi mentor-review handoff must preserve the current decision."
  Assert-TextContains -Text $secchiHandoff -Needle "What Feedback Is Needed" -Message "Secchi mentor-review handoff must define needed feedback."
  Assert-TextContains -Text $secchiHandoff -Needle "Feedback Capture Template" -Message "Secchi mentor-review handoff must include a feedback capture template."
  Assert-TextContains -Text $secchiHandoff -Needle "Do not convert this handoff directly into a field protocol or public export." -Message "Secchi mentor-review handoff must preserve the no-direct-pilot gate."
  Assert-TextContains -Text $secchiHandoff -Needle "not official public-health guidance" -Message "Secchi mentor-review handoff must preserve public-health boundary."

  $internshipReviewStartHere = Get-Content -LiteralPath (Resolve-ProjectPath "docs\internship-review-start-here.md") -Raw
  Assert-TextContains -Text $internshipReviewStartHere -Needle "Internship Review Start Here" -Message "Internship review start-here doc must include its title."
  Assert-TextContains -Text $internshipReviewStartHere -Needle "Open These 3 Links First" -Message "Internship review start-here doc must include the three-link path."
  Assert-TextContains -Text $internshipReviewStartHere -Needle "Copy-Paste Internship Outreach Blurb" -Message "Internship review start-here doc must include outreach language."
  Assert-TextContains -Text $internshipReviewStartHere -Needle "not official public-health guidance" -Message "Internship review start-here doc must preserve public-health boundary."
  Assert-TextContains -Text $internshipReviewStartHere -Needle "water quality, GIS, watershed planning, environmental monitoring, climate resilience, or environmental data systems" -Message "Internship review start-here doc must state target internship areas."

  $dashboardAnatomyGuide = Get-Content -LiteralPath (Resolve-ProjectPath "docs\dashboard-anatomy-review-guide.md") -Raw
  Assert-TextContains -Text $dashboardAnatomyGuide -Needle "Dashboard Anatomy Review Guide" -Message "Dashboard anatomy guide must include its title."
  Assert-TextContains -Text $dashboardAnatomyGuide -Needle "What This Project Demonstrates" -Message "Dashboard anatomy guide must explain the portfolio demonstration section."
  Assert-TextContains -Text $dashboardAnatomyGuide -Needle "Open-App Data QA Notices" -Message "Dashboard anatomy guide must explain data QA notices."
  Assert-TextContains -Text $dashboardAnatomyGuide -Needle "not official public-health guidance" -Message "Dashboard anatomy guide must preserve public-health boundary."

  $accessibilityReview = Get-Content -LiteralPath (Resolve-ProjectPath "docs\accessibility-review.md") -Raw
  Assert-TextContains -Text $accessibilityReview -Needle "Accessibility Review" -Message "Accessibility review must include its title."
  Assert-TextContains -Text $accessibilityReview -Needle "reviewer-readiness pass" -Message "Accessibility review must preserve narrow pass status."
  Assert-TextContains -Text $accessibilityReview -Needle "browser-accessibility-interaction-pass-2026-05-28.md" -Message "Accessibility review must link the browser interaction pass."
  Assert-TextContains -Text $accessibilityReview -Needle "descriptive link text" -Message "Accessibility review must discuss descriptive link text."
  Assert-TextContains -Text $accessibilityReview -Needle "Screenshot descriptions" -Message "Accessibility review must discuss screenshot descriptions."
  Assert-TextContains -Text $accessibilityReview -Needle "data-table equivalents" -Message "Accessibility review must preserve chart and map nonvisual follow-up."
  Assert-TextContains -Text $accessibilityReview -Needle "not official public-health guidance" -Message "Accessibility review must preserve public-health boundary."

  $browserAccessibilityPass = Get-Content -LiteralPath (Resolve-ProjectPath "docs\browser-accessibility-interaction-pass-2026-05-28.md") -Raw
  Assert-TextContains -Text $browserAccessibilityPass -Needle "Browser Accessibility Interaction Pass - 2026-05-28" -Message "Browser accessibility pass must include its title."
  Assert-TextContains -Text $browserAccessibilityPass -Needle "reviewer-readiness browser interaction pass" -Message "Browser accessibility pass must preserve narrow pass status."
  Assert-TextContains -Text $browserAccessibilityPass -Needle "Skip to dashboard content" -Message "Browser accessibility pass must record skip-link coverage."
  Assert-TextContains -Text $browserAccessibilityPass -Needle "Data QA notices" -Message "Browser accessibility pass must record notification-control coverage."
  Assert-TextContains -Text $browserAccessibilityPass -Needle "map trust filter" -Message "Browser accessibility pass must record map interaction coverage."
  Assert-TextContains -Text $browserAccessibilityPass -Needle "data-table equivalents" -Message "Browser accessibility pass must preserve chart and map nonvisual follow-up."
  Assert-TextContains -Text $browserAccessibilityPass -Needle "not official public-health guidance" -Message "Browser accessibility pass must preserve public-health boundary."

  $mobileReviewerPathReview = Get-Content -LiteralPath (Resolve-ProjectPath "docs\mobile-reviewer-path-review.md") -Raw
  Assert-TextContains -Text $mobileReviewerPathReview -Needle "Mobile Reviewer Path Review" -Message "Mobile reviewer path review must include its title."
  Assert-TextContains -Text $mobileReviewerPathReview -Needle "sticky primary navigation" -Message "Mobile reviewer path review must discuss sticky navigation."
  Assert-TextContains -Text $mobileReviewerPathReview -Needle "390px, 360px, and 320px" -Message "Mobile reviewer path review must record checked viewport widths."
  Assert-TextContains -Text $mobileReviewerPathReview -Needle "No mobile navigation redesign is needed" -Message "Mobile reviewer path review must record the disclosure-menu decision."
  Assert-TextContains -Text $mobileReviewerPathReview -Needle "not official public-health guidance" -Message "Mobile reviewer path review must preserve public-health boundary."

  $careerServicesHandoff = Get-Content -LiteralPath (Resolve-ProjectPath "docs\career-services-handoff-packet.md") -Raw
  Assert-TextContains -Text $careerServicesHandoff -Needle "Career Services Handoff Packet" -Message "Career Services handoff packet must include its title."
  Assert-TextContains -Text $careerServicesHandoff -Needle "Short Email Before An Appointment" -Message "Career Services handoff packet must include pre-appointment email language."
  Assert-TextContains -Text $careerServicesHandoff -Needle "Dashboard anatomy review guide" -Message "Career Services handoff packet must point to the dashboard anatomy guide."
  Assert-TextContains -Text $careerServicesHandoff -Needle "project-delivery-ehs.md" -Message "Career Services handoff packet must point to the project delivery and EHS positioning aid."
  Assert-TextContains -Text $careerServicesHandoff -Needle "Resume Placement" -Message "Career Services handoff packet must include resume placement guidance."
  Assert-TextContains -Text $careerServicesHandoff -Needle "not official public-health guidance" -Message "Career Services handoff packet must preserve public-health boundary."

  $projectDeliveryEhs = Get-Content -LiteralPath (Resolve-ProjectPath "docs\project-delivery-ehs.md") -Raw
  Assert-TextContains -Text $projectDeliveryEhs -Needle "Project Delivery, EHS, And Environmental Systems Governance" -Message "Project delivery and EHS doc must include its title."
  Assert-TextContains -Text $projectDeliveryEhs -Needle "Environmental systems analysis + field data workflows + project delivery + safety/risk governance" -Message "Project delivery and EHS doc must include the core frame."
  Assert-TextContains -Text $projectDeliveryEhs -Needle "I am building applied competency" -Message "Project delivery and EHS doc must preserve early-career positioning."
  Assert-TextContains -Text $projectDeliveryEhs -Needle "Avoid:" -Message "Project delivery and EHS doc must include avoid-language boundaries."
  Assert-TextContains -Text $projectDeliveryEhs -Needle "not official public-health guidance" -Message "Project delivery and EHS doc must preserve public-health boundary."

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
