param(
  [int]$Port = 4173,
  [switch]$SkipHttp,
  [int]$MaxSnapshotAgeDays = 7,
  [switch]$AllowStaleSnapshot
)

$ErrorActionPreference = "Stop"

$projectRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot ".."))
$schemaPackageRoot = [System.IO.Path]::GetFullPath((Join-Path $projectRoot "..\environmental-monitoring-schemas"))
$failures = [System.Collections.Generic.List[string]]::new()
$warnings = [System.Collections.Generic.List[string]]::new()

function Add-Failure {
  param([string]$Message)
  $failures.Add($Message)
}

function Add-Warning {
  param([string]$Message)
  $warnings.Add($Message)
}

function Resolve-ProjectPath {
  param([string]$RelativePath)
  return Join-Path $projectRoot $RelativePath
}

function Assert-FileExists {
  param([string]$RelativePath)

  if (-not (Test-Path (Resolve-ProjectPath $RelativePath))) {
    Add-Failure "Missing required file: $RelativePath"
  }
}

function Resolve-SchemaPackagePath {
  param([string]$RelativePath)
  return Join-Path $schemaPackageRoot $RelativePath
}

function Assert-SchemaPackageFileExists {
  param([string]$RelativePath)

  if (-not (Test-Path (Resolve-SchemaPackagePath $RelativePath))) {
    Add-Failure "Missing required schema package file: environmental-monitoring-schemas/$RelativePath"
  }
}

function Assert-FileAbsent {
  param(
    [string]$RelativePath,
    [string]$Message
  )

  if (Test-Path (Resolve-ProjectPath $RelativePath)) {
    Add-Failure $Message
  }
}

function Read-JsonFile {
  param([string]$RelativePath)

  $path = Resolve-ProjectPath $RelativePath
  if (-not (Test-Path $path)) {
    Add-Failure "Missing JSON file: $RelativePath"
    return $null
  }

  try {
    return Get-Content $path -Raw | ConvertFrom-Json
  } catch {
    Add-Failure "Invalid JSON in $RelativePath`: $($_.Exception.Message)"
    return $null
  }
}

function Assert-True {
  param(
    [bool]$Condition,
    [string]$Message
  )

  if (-not $Condition) {
    Add-Failure $Message
  }
}

function Assert-NonEmptyCollection {
  param(
    [object]$Collection,
    [string]$Message
  )

  Assert-True -Condition (@($Collection).Count -gt 0) -Message $Message
}

function Assert-AllowedValue {
  param(
    [string]$Value,
    [string[]]$AllowedValues,
    [string]$Message
  )

  Assert-True -Condition ($AllowedValues -contains $Value) -Message $Message
}

function Get-AgeDays {
  param([string]$Value)

  if ([string]::IsNullOrWhiteSpace($Value)) {
    return $null
  }

  try {
    $timestamp = [datetimeoffset]::Parse(
      $Value,
      [System.Globalization.CultureInfo]::InvariantCulture
    )
    return [math]::Floor(([datetimeoffset]::Now - $timestamp).TotalDays)
  } catch {
    return $null
  }
}

function Assert-TextContains {
  param(
    [string]$Text,
    [string]$Needle,
    [string]$Message
  )

  Assert-True -Condition ($Text.Contains($Needle)) -Message $Message
}

function Assert-WeatherContext {
  param(
    [object]$Data,
    [string]$Name
  )

  $allowedWeatherStatuses = @(
    "live",
    "stale",
    "partial",
    "unavailable"
  )
  $qualityNotes = @($Data.qualityNotes)
  $qualityNoteText = ($qualityNotes -join " ").ToLowerInvariant()

  Assert-True -Condition ($Data.schemaVersion -eq "weather-context-v1") -Message "$Name must use schema weather-context-v1."
  Assert-True -Condition (-not [string]::IsNullOrWhiteSpace($Data.generatedAt)) -Message "$Name must include generatedAt."
  Assert-True -Condition (-not [string]::IsNullOrWhiteSpace($Data.sourceName)) -Message "$Name must include sourceName."
  Assert-AllowedValue -Value $Data.machineReadableStatus -AllowedValues $allowedWeatherStatuses -Message "$Name must use an allowed weather status."
  Assert-True -Condition ($Data.staleAfterHours -gt 0) -Message "$Name must include a positive staleAfterHours value."
  Assert-True -Condition ($null -ne $Data.stations) -Message "$Name must include stations."
  Assert-True -Condition ($null -ne $Data.summaryCards) -Message "$Name must include summaryCards."
  Assert-True -Condition ($null -ne $Data.contextWindows) -Message "$Name must include contextWindows."
  Assert-NonEmptyCollection $qualityNotes "$Name must include at least one quality note."
  Assert-True -Condition ($qualityNoteText.Contains("separate")) -Message "$Name quality notes must state that weather context is separate from lake-health interpretation."
  Assert-True -Condition ($qualityNoteText.Contains("public-health") -or $qualityNoteText.Contains("public health")) -Message "$Name quality notes must mention public-health guidance boundaries."
}

function Assert-ForecastOutputExample {
  param(
    [object]$Data,
    [string]$Name
  )

  Assert-True -Condition ($Data.schemaVersion -eq "forecast-output-v0") -Message "$Name must use schema forecast-output-v0."
  Assert-True -Condition ($Data.status -eq "example-only") -Message "$Name must be clearly marked example-only."
  Assert-True -Condition (-not [string]::IsNullOrWhiteSpace($Data.generatedAt)) -Message "$Name must include generatedAt."
  Assert-True -Condition (-not [string]::IsNullOrWhiteSpace($Data.modelName)) -Message "$Name must include modelName."
  Assert-True -Condition (-not [string]::IsNullOrWhiteSpace($Data.modelVersion)) -Message "$Name must include modelVersion."
  Assert-True -Condition (-not [string]::IsNullOrWhiteSpace($Data.modelRunDate)) -Message "$Name must include modelRunDate."
  Assert-True -Condition ($null -ne $Data.trainingWindow) -Message "$Name must include trainingWindow."
  Assert-True -Condition ($null -ne $Data.forecastWindow) -Message "$Name must include forecastWindow."
  Assert-NonEmptyCollection $Data.inputSummary "$Name must include inputSummary."
  Assert-NonEmptyCollection $Data.excludedInputs "$Name must include excludedInputs."
  Assert-True -Condition (-not [string]::IsNullOrWhiteSpace($Data.uncertaintySummary)) -Message "$Name must include uncertaintySummary."
  Assert-True -Condition ($Data.publicHealthDisclaimer -match "Not official public-health guidance") -Message "$Name must include a public-health disclaimer."
  Assert-NonEmptyCollection $Data.outputs "$Name must include forecast output examples."

  foreach ($output in @($Data.outputs)) {
    Assert-True -Condition (-not [string]::IsNullOrWhiteSpace($output.arm)) -Message "$Name outputs must include arm."
    Assert-True -Condition (-not [string]::IsNullOrWhiteSpace($output.forecastDate)) -Message "$Name outputs must include forecastDate."
    Assert-True -Condition (-not [string]::IsNullOrWhiteSpace($output.severityClass)) -Message "$Name outputs must include severityClass."
    Assert-True -Condition (-not [string]::IsNullOrWhiteSpace($output.confidence)) -Message "$Name outputs must include confidence."
    Assert-True -Condition (-not [string]::IsNullOrWhiteSpace($output.uncertainty)) -Message "$Name outputs must include uncertainty."
    Assert-True -Condition (-not [string]::IsNullOrWhiteSpace($output.explanation)) -Message "$Name outputs must include explanation."
    Assert-True -Condition ($output.experimental -eq $true) -Message "$Name outputs must remain experimental."
  }
}

function Assert-FieldMicroscopyIntakeExample {
  param(
    [object]$Data,
    [string]$Name
  )

  $allowedReviewStatuses = @(
    "draft",
    "submitted",
    "needs-correction",
    "approved-private",
    "approved-public",
    "rejected"
  )
  $requiredRecordFields = @(
    "recordId",
    "recordType",
    "sampleDateTime",
    "collectorName",
    "collectorOrganization",
    "custodyId",
    "siteId",
    "siteName",
    "latitude",
    "longitude",
    "gpsPrecisionMeters",
    "lakeArm",
    "sampleType",
    "microscopeMethod",
    "magnification",
    "taxonName",
    "identificationConfidence",
    "abundanceEstimate",
    "photoOrVoucherReference",
    "qaStatus",
    "qaReviewer",
    "qaReviewedAt",
    "qaNotes",
    "permissionToPublish",
    "publicLocationPrecision",
    "publicSummary"
  )
  $rulesText = (@($Data.publicExportRules) -join " ").ToLowerInvariant()

  Assert-True -Condition ($Data.schemaVersion -eq "field-microscopy-intake-v0") -Message "$Name must use schema field-microscopy-intake-v0."
  Assert-True -Condition ($Data.status -eq "example-only") -Message "$Name must be marked example-only."
  Assert-NonEmptyCollection $Data.records "$Name must include example records."
  Assert-NonEmptyCollection $Data.allowedReviewStatuses "$Name must include allowed review statuses."
  Assert-NonEmptyCollection $Data.publicExportRules "$Name must include public export rules."

  foreach ($status in $allowedReviewStatuses) {
    Assert-True -Condition (@($Data.allowedReviewStatuses) -contains $status) -Message "$Name must include allowed review status '$status'."
  }

  foreach ($record in @($Data.records)) {
    foreach ($field in $requiredRecordFields) {
      Assert-True -Condition ($record.PSObject.Properties.Name -contains $field) -Message "$Name example records must include field '$field'."
    }

    Assert-True -Condition ($record.recordType -eq "field-microscopy") -Message "$Name records must use recordType field-microscopy."
    Assert-AllowedValue -Value $record.qaStatus -AllowedValues $allowedReviewStatuses -Message "$Name records must use an allowed QA status."
    Assert-True -Condition ($record.permissionToPublish -eq $false) -Message "$Name example records must not be publishable by default."
  }

  Assert-True -Condition ($rulesText.Contains("approved-public")) -Message "$Name rules must require approved-public status before export."
  Assert-True -Condition ($rulesText.Contains("permissiontopublish true")) -Message "$Name rules must require permissionToPublish true before export."
  Assert-True -Condition ($rulesText.Contains("separate source family")) -Message "$Name rules must preserve field/microscopy as a separate source family."
}

function Assert-ReviewedFieldObservations {
  param(
    [object]$Data,
    [string]$Name
  )

  $allowedStatuses = @(
    "not-connected",
    "reviewed-export"
  )
  $forbiddenPublicFields = @(
    "collectorName",
    "collectorOrganization",
    "custodyId",
    "custodyNotes",
    "fieldNotes",
    "qaReviewer",
    "qaReviewedAt",
    "qaNotes",
    "photoOrVoucherReference",
    "latitude",
    "longitude"
  )
  $qualityNoteText = (@($Data.qualityNotes) -join " ").ToLowerInvariant()

  Assert-True -Condition ($Data.schemaVersion -eq "reviewed-field-observations-v0") -Message "$Name must use schema reviewed-field-observations-v0."
  Assert-True -Condition ($Data.sourceFamily -eq "field-microscopy") -Message "$Name must preserve field-microscopy as the source family."
  Assert-AllowedValue -Value $Data.status -AllowedValues $allowedStatuses -Message "$Name must use an allowed public export status."
  Assert-True -Condition ($null -ne $Data.records) -Message "$Name must include records, even when empty."
  Assert-NonEmptyCollection $Data.qualityNotes "$Name must include quality notes."
  Assert-True -Condition ($qualityNoteText.Contains("approved-public")) -Message "$Name quality notes must require approved-public records."
  Assert-True -Condition ($qualityNoteText.Contains("permissiontopublish")) -Message "$Name quality notes must require permissionToPublish."
  Assert-True -Condition ($qualityNoteText.Contains("private")) -Message "$Name quality notes must explain private-field exclusion."

  foreach ($record in @($Data.records)) {
    foreach ($field in $forbiddenPublicFields) {
      Assert-True -Condition (-not ($record.PSObject.Properties.Name -contains $field)) -Message "$Name public records must not include private field '$field'."
    }

    Assert-True -Condition ($record.sourceFamily -eq "field-microscopy") -Message "$Name public records must keep sourceFamily field-microscopy."
    Assert-True -Condition ($record.publicQaStatus -eq "approved-public") -Message "$Name public records must have publicQaStatus approved-public."
  }
}

function Get-NodeExecutable {
  $bundledNode = Join-Path $env:USERPROFILE ".cache\codex-runtimes\codex-primary-runtime\dependencies\node\bin\node.exe"

  if (Test-Path $bundledNode) {
    return $bundledNode
  }

  $nodeCommand = Get-Command node -ErrorAction SilentlyContinue
  if ($nodeCommand) {
    return $nodeCommand.Source
  }

  return $null
}

function Assert-HttpOk {
  param([string]$Path)

  $uri = "http://127.0.0.1:$Port/$Path"
  try {
    $response = Invoke-WebRequest -Uri $uri -UseBasicParsing -TimeoutSec 5
    Assert-True -Condition ($response.StatusCode -eq 200) -Message "HTTP check failed for $uri with status $($response.StatusCode)"
  } catch {
    Add-Failure "HTTP check failed for $uri`: $($_.Exception.Message)"
  }
}

Push-Location $projectRoot
try {
  $requiredFiles = @(
    "index.html",
    "project.html",
    "methodology.html",
    "styles.css",
    "app.js",
    "manifest.webmanifest",
    "sw.js",
    "README.md",
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
    "data\site-review.json",
    "data\site-review-summary.json",
    "data\site-review-decisions.example.json",
    "data\analytics.json",
    "data\manifest.json",
    "data\lake-shoreline.json",
    "data\forecast-output.example.json",
    "data\field-microscopy-intake.example.json",
    "data\reviewed-field-observations.json",
    "data\weather-context.json",
    "data\weather-context.example.json",
    "docs\backlog.md",
    "docs\career-services-call-notes.md",
    "docs\career-services-day-of-checklist.md",
    "docs\career-services-follow-up-tracker.md",
    "docs\career-services-share-packet.md",
    "docs\cross-platform-typography-audit.md",
    "docs\field-microscopy-intake-contract.md",
    "docs\private-site-review-surface.md",
    "docs\private-surface.md",
    "docs\private-sqlite-surface.md",
    "docs\public-mirror-boundary.md",
    "docs\publication-review-checklist.md",
    "docs\reusable-schema-package.md",
    "docs\resume-linkedin-snippets.md",
    "docs\screenshot-review.md",
    "docs\review-screenshots\clear-lake-watch-mobile-width-2026-05-05.png",
    "docs\deployment.md",
    "docs\forecast-boundary.md",
    "docs\local-first-operating-model.md",
    "docs\local-git-workflow.md",
    "docs\portfolio-release-branch-handoff.md",
    "docs\portfolio-safe-release-scope.md",
    "docs\clear_lake_watch_portfolio_case_study.md",
    "docs\internship-share-brief.md",
    "docs\internship-role-fit-map.md",
    "docs\site-registry-decision-workflow.md",
    "docs\site-registry-review.md",
    "docs\site-registry-high-priority.md",
    "docs\source-audit.md",
    "docs\conversation-log.md",
    "docs\weather-context-contract.md",
    "scripts\refresh-live-data.ps1",
    "scripts\refresh-osm-shoreline.ps1",
    "scripts\write-weather-context-unavailable.ps1",
    "scripts\build-site-review-report.ps1",
    "scripts\new-site-review-decisions.ps1",
    "scripts\new-field-microscopy-intake.ps1",
    "scripts\validate-field-microscopy-intake.ps1",
    "scripts\export-reviewed-field-observations.ps1",
    "scripts\check-field-microscopy-review-cycle.ps1",
    "scripts\field_microscopy_db.py",
    "scripts\site_review_db.py",
    "scripts\preview-site-review-decisions.ps1",
    "scripts\launch-dashboard.ps1",
    "scripts\create-windows-shortcut.ps1",
    "scripts\find-local-git.ps1"
  )

  foreach ($file in $requiredFiles) {
    Assert-FileExists $file
  }

  foreach ($file in @(
      "README.md",
      "pyproject.toml",
      "src\environmental_monitoring_schemas\__init__.py",
      "src\environmental_monitoring_schemas\field_microscopy.py"
    )) {
    Assert-SchemaPackageFileExists $file
  }

  @(
    "server.pid",
    "server.out.log",
    "server.err.log"
  ) | ForEach-Object {
    Assert-FileAbsent $_ "Runtime file should not be in the static web root: $_"
  }

  $sources = Read-JsonFile "data\sources.json"
  $webManifest = Read-JsonFile "manifest.webmanifest"
  $sites = Read-JsonFile "data\sites.json"
  $live = Read-JsonFile "data\live.json"
  $reports = Read-JsonFile "data\reports.json"
  $observations = Read-JsonFile "data\observations.json"
  $sitesNormalized = Read-JsonFile "data\sites-normalized.json"
  $siteReview = Read-JsonFile "data\site-review.json"
  $siteReviewSummary = Read-JsonFile "data\site-review-summary.json"
  $siteReviewDecisionsExample = Read-JsonFile "data\site-review-decisions.example.json"
  $analytics = Read-JsonFile "data\analytics.json"
  $manifest = Read-JsonFile "data\manifest.json"
  $shoreline = Read-JsonFile "data\lake-shoreline.json"
  $forecastOutputExample = Read-JsonFile "data\forecast-output.example.json"
  $fieldMicroscopyIntakeExample = Read-JsonFile "data\field-microscopy-intake.example.json"
  $reviewedFieldObservations = Read-JsonFile "data\reviewed-field-observations.json"
  $weatherContext = Read-JsonFile "data\weather-context.json"
  $weatherContextExample = Read-JsonFile "data\weather-context.example.json"

  if ($sources) {
    Assert-NonEmptyCollection $sources.sources "sources.json must include at least one source."
    Assert-NonEmptyCollection $sources.arms "sources.json must include lake arms."
    Assert-NonEmptyCollection $sources.modules "sources.json must include dashboard modules."
    Assert-NonEmptyCollection $sources.guardrails "sources.json must include guardrails."
  }

  if ($webManifest) {
    Assert-True -Condition ($webManifest.name -eq "Clear Lake Watch") -Message "manifest.webmanifest must use the Clear Lake Watch app name."
    Assert-True -Condition (-not [string]::IsNullOrWhiteSpace($webManifest.short_name)) -Message "manifest.webmanifest must include short_name."
    Assert-True -Condition ($webManifest.display -eq "standalone") -Message "manifest.webmanifest must use standalone display."
    Assert-True -Condition (-not [string]::IsNullOrWhiteSpace($webManifest.start_url)) -Message "manifest.webmanifest must include start_url."
    Assert-NonEmptyCollection $webManifest.icons "manifest.webmanifest must include app icons."
  }

  if ($sites) {
    Assert-NonEmptyCollection $sites.sites "sites.json must include at least one site."
    $hendersonPointSite = @($sites.sites | Where-Object { $_.siteId -eq "fhabs-henderson-point" }) | Select-Object -First 1
    $jagoBaySite = @($sites.sites | Where-Object { $_.siteId -eq "fhabs-jago-bay" }) | Select-Object -First 1
    $jonesBaySite = @($sites.sites | Where-Object { $_.siteId -eq "fhabs-jones-bay" }) | Select-Object -First 1
    Assert-True -Condition ($null -ne $hendersonPointSite) -Message "sites.json must include the unresolved Henderson Point / Riviera Point candidate site."
    Assert-True -Condition ($null -ne $jagoBaySite) -Message "sites.json must include the Jago Bay registry site."
    Assert-True -Condition ($null -ne $jonesBaySite) -Message "sites.json must include the distinct Jones Bay starter registry site."
    if ($hendersonPointSite) {
      Assert-True -Condition ($hendersonPointSite.assignmentStatus -eq "needs-local-review") -Message "Henderson Point / Riviera Point must remain needs-local-review until locally certified."
      Assert-True -Condition (@($hendersonPointSite.aliases) -contains "Riveria Point Launch at Henderson Point in Soda Bay") -Message "Henderson Point / Riviera Point must preserve the FHABS source spelling as an alias."
      Assert-True -Condition (@($hendersonPointSite.aliases) -contains "Riviera Point Launch at Henderson Point in Soda Bay") -Message "Henderson Point / Riviera Point must include the likely corrected Riviera spelling as an alias."
    }
    if ($jagoBaySite) {
      Assert-True -Condition ($jagoBaySite.assignmentStatus -eq "needs-local-review") -Message "Jago Bay must remain needs-local-review until locally certified."
      Assert-True -Condition (-not (@($jagoBaySite.aliases) -contains "Jones bay")) -Message "Jago Bay aliases must not collapse Jones bay into Jago Bay without review evidence."
    }
    if ($jonesBaySite) {
      Assert-True -Condition ($jonesBaySite.name -eq "Jones Bay") -Message "Jones Bay starter site must preserve the distinct bay name."
      Assert-True -Condition ($jonesBaySite.arm -eq "Lower Arm") -Message "Jones Bay starter site must remain assigned to Lower Arm pending local review."
      Assert-True -Condition ($jonesBaySite.assignmentStatus -eq "needs-local-review") -Message "Jones Bay starter site must remain needs-local-review until locally certified."
    }
  }

  if ($live) {
    Assert-True -Condition (-not [string]::IsNullOrWhiteSpace($live.generatedAt)) -Message "live.json must include generatedAt."
    $snapshotAgeDays = Get-AgeDays $live.generatedAt
    Assert-True -Condition ($null -ne $snapshotAgeDays) -Message "live.json generatedAt must be parseable as a date/time."
    if ($null -ne $snapshotAgeDays -and $snapshotAgeDays -gt $MaxSnapshotAgeDays) {
      if ($AllowStaleSnapshot) {
        Add-Warning "live.json snapshot is $snapshotAgeDays days old; stale snapshot allowed by -AllowStaleSnapshot."
      } else {
        Add-Failure "live.json snapshot is $snapshotAgeDays days old, which exceeds MaxSnapshotAgeDays=$MaxSnapshotAgeDays. Refresh data before publishing or rerun with -AllowStaleSnapshot for an intentional archival/portfolio check."
      }
    }
    Assert-NonEmptyCollection $live.liveCards "live.json must include liveCards."
    Assert-NonEmptyCollection $live.hydrologySeries "live.json must include hydrologySeries."
    Assert-NonEmptyCollection $live.mapMarkers "live.json must include mapMarkers."
    Assert-True -Condition ($null -ne $live.analytics) -Message "live.json must include embedded analytics."
    $lakeLevelCard = @($live.liveCards | Where-Object { $_.label -eq "Lake level at Lakeport" }) | Select-Object -First 1
    Assert-True -Condition ($null -ne $lakeLevelCard) -Message "live.json must include the Lakeport lake-level card."
    if ($lakeLevelCard) {
      Assert-True -Condition ($lakeLevelCard.value -match "ft Rumsey") -Message "Lakeport lake-level card must label the value as feet Rumsey."
      Assert-True -Condition ($lakeLevelCard.value -match "above sea level") -Message "Lakeport lake-level card must also show the standard elevation in plain language."
      Assert-True -Condition ($lakeLevelCard.note -match "Zero Rumsey = 1318\.256 ft") -Message "Lakeport lake-level card must include the Zero Rumsey elevation context."
    }
    $jonesBayMarker = @($live.mapMarkers | Where-Object { $_.landmark -eq "Jones bay" }) | Select-Object -First 1
    Assert-True -Condition ($null -ne $jonesBayMarker) -Message "live.json must keep the Jones bay marker visible."
    if ($jonesBayMarker) {
      Assert-True -Condition ($jonesBayMarker.siteId -eq "fhabs-jones-bay") -Message "Jones bay must match the distinct Jones Bay starter site."
      Assert-True -Condition ($jonesBayMarker.matchMethod -eq "alias") -Message "Jones bay should no longer rely on proximity matching."
      Assert-True -Condition ($jonesBayMarker.assignmentStatus -eq "needs-local-review") -Message "Jones bay must remain needs-local-review until locally certified."
    }
    $hendersonPointMarker = @($live.mapMarkers | Where-Object { $_.landmark -eq "Riveria Point Launch at Henderson Point in Soda Bay" }) | Select-Object -First 1
    Assert-True -Condition ($null -ne $hendersonPointMarker) -Message "live.json must keep the Henderson Point / Riviera Point FHABS marker visible."
    if ($hendersonPointMarker) {
      Assert-True -Condition ($hendersonPointMarker.siteId -eq "fhabs-henderson-point") -Message "Henderson Point / Riviera Point marker must match the specific unresolved registry site."
      Assert-True -Condition ($hendersonPointMarker.assignmentStatus -eq "needs-local-review") -Message "Henderson Point / Riviera Point marker must remain needs-local-review."
    }
  }

  if ($reports) {
    Assert-NonEmptyCollection $reports "reports.json must include normalized FHABS reports."
  }

  if ($observations) {
    Assert-NonEmptyCollection $observations "observations.json must include normalized observations."
  }

  if ($sitesNormalized) {
    Assert-NonEmptyCollection $sitesNormalized "sites-normalized.json must include normalized sites."
  }

  if ($siteReview) {
    Assert-True -Condition ($siteReview.summary.registrySites -gt 0) -Message "site-review.json must include registry site counts."
    Assert-True -Condition ($siteReview.summary.currentMapMarkers -ge 0) -Message "site-review.json must include current map marker counts."
    Assert-True -Condition ($siteReview.summary.highPriorityReviewItems -ge 0) -Message "site-review.json must include high-priority review counts."
    Assert-NonEmptyCollection $siteReview.reviewQueue "site-review.json must include a review queue."
    Assert-True -Condition ($siteReview.reviewQueue[0].PSObject.Properties.Name -contains "reviewPriority") -Message "site-review.json review queue must include reviewPriority."
    Assert-True -Condition ($siteReview.reviewQueue[0].PSObject.Properties.Name -contains "reviewReason") -Message "site-review.json review queue must include reviewReason."
    Assert-True -Condition ($siteReview.reviewQueue[0].PSObject.Properties.Name -contains "sourceMapUrl") -Message "site-review.json review queue must include sourceMapUrl."
    Assert-True -Condition ($siteReview.reviewQueue[0].PSObject.Properties.Name -contains "registryMapUrl") -Message "site-review.json review queue must include registryMapUrl."
    Assert-True -Condition (@($siteReview.reviewQueue | Where-Object { $_.reviewPriority -eq "high" }).Count -eq $siteReview.summary.highPriorityReviewItems) -Message "site-review.json high-priority summary must match the review queue."

    if ($siteReview.summary.currentMapMarkers -gt 0 -and $siteReview.summary.reviewedCurrentMapMarkers -eq 0) {
      Add-Warning "All current map markers still need local review; public map trust cues should remain conservative."
    }

    if ($siteReview.summary.highPriorityReviewItems -gt 0) {
      Add-Warning "$($siteReview.summary.highPriorityReviewItems) high-priority site-registry review item(s) remain open."
    }
  }

  if ($siteReviewSummary) {
    $publicNoteText = (@($siteReviewSummary.publicNotes) -join " ").ToLowerInvariant()

    Assert-True -Condition ($siteReviewSummary.schemaVersion -eq "site-review-summary-v0") -Message "site-review-summary.json must use schema site-review-summary-v0."
    Assert-True -Condition (-not [string]::IsNullOrWhiteSpace($siteReviewSummary.generatedAt)) -Message "site-review-summary.json must include generatedAt."
    Assert-True -Condition ($siteReviewSummary.source -match "sanitized aggregate") -Message "site-review-summary.json must identify itself as a sanitized aggregate."
    Assert-True -Condition ($siteReviewSummary.source -match "SQLite") -Message "site-review-summary.json must identify SQLite as the local detailed-record source."
    Assert-True -Condition ($siteReviewSummary.summary.registrySites -gt 0) -Message "site-review-summary.json must include registry site counts."
    Assert-True -Condition ($siteReviewSummary.summary.currentMapMarkers -ge 0) -Message "site-review-summary.json must include current map marker counts."
    Assert-True -Condition ($siteReviewSummary.priorityCounts.high -eq $siteReviewSummary.summary.highPriorityReviewItems) -Message "site-review-summary.json high priority count must match summary."
    Assert-True -Condition ($siteReviewSummary.priorityCounts.medium -eq $siteReviewSummary.summary.mediumPriorityReviewItems) -Message "site-review-summary.json medium priority count must match summary."
    Assert-True -Condition ($siteReviewSummary.priorityCounts.low -eq $siteReviewSummary.summary.lowPriorityReviewItems) -Message "site-review-summary.json low priority count must match summary."
    Assert-NonEmptyCollection $siteReviewSummary.publicNotes "site-review-summary.json must include public boundary notes."
    Assert-True -Condition ($publicNoteText.Contains("aggregate")) -Message "site-review-summary.json public notes must describe aggregate-only status."
    Assert-True -Condition ($publicNoteText.Contains("detailed review queues")) -Message "site-review-summary.json public notes must point detailed queues away from public use."
    Assert-True -Condition ($publicNoteText.Contains("public-health") -or $publicNoteText.Contains("public health")) -Message "site-review-summary.json public notes must preserve public-health boundary."
    Assert-True -Condition (-not ($siteReviewSummary.PSObject.Properties.Name -contains "reviewQueue")) -Message "site-review-summary.json must not include detailed reviewQueue records."
    Assert-True -Condition (-not ($siteReviewSummary.PSObject.Properties.Name -contains "markersBySite")) -Message "site-review-summary.json must not include detailed markersBySite records."

    if ($siteReview) {
      Assert-True -Condition ($siteReviewSummary.summary.currentMapMarkers -eq $siteReview.summary.currentMapMarkers) -Message "site-review-summary.json current marker count must match detailed site-review.json."
      Assert-True -Condition ($siteReviewSummary.summary.needsReviewCurrentMapMarkers -eq $siteReview.summary.needsReviewCurrentMapMarkers) -Message "site-review-summary.json needs-review count must match detailed site-review.json."
    }
  }

  if ($siteReviewDecisionsExample) {
    $allowedReviewActions = @(
      "keep-needs-review",
      "add-alias",
      "create-site",
      "promote-reviewed-local"
    )
    $requiredDecisionFields = @(
      "decisionId",
      "siteId",
      "landmark",
      "action",
      "proposedAssignmentStatus",
      "reviewer",
      "reviewedAt",
      "evidenceNote",
      "publicNote",
      "permissionToPublish"
    )

    Assert-True -Condition ($siteReviewDecisionsExample.schemaVersion -eq 1) -Message "site-review-decisions.example.json must use schemaVersion 1."
    Assert-NonEmptyCollection $siteReviewDecisionsExample.decisions "site-review-decisions.example.json must include decisions."
    Assert-NonEmptyCollection $siteReviewDecisionsExample.allowedActions "site-review-decisions.example.json must include allowedActions."

    foreach ($action in $allowedReviewActions) {
      Assert-True -Condition (@($siteReviewDecisionsExample.allowedActions) -contains $action) -Message "site-review-decisions.example.json must allow action '$action'."
    }

    foreach ($decision in @($siteReviewDecisionsExample.decisions)) {
      foreach ($field in $requiredDecisionFields) {
        Assert-True -Condition ($decision.PSObject.Properties.Name -contains $field) -Message "site-review decision examples must include field '$field'."
      }

      Assert-AllowedValue -Value $decision.action -AllowedValues $allowedReviewActions -Message "site-review decision examples must use allowed actions."
      Assert-True -Condition (-not [string]::IsNullOrWhiteSpace($decision.evidenceNote)) -Message "site-review decision examples must include evidence notes."
    }
  }

  if ($analytics) {
    Assert-NonEmptyCollection $analytics.reportTrendByYear "analytics.json must include reportTrendByYear."
    Assert-NonEmptyCollection $analytics.advisoryDistributionByArm "analytics.json must include advisoryDistributionByArm."
    Assert-NonEmptyCollection $analytics.observationCoverage "analytics.json must include observationCoverage."
  }

  if ($manifest) {
    Assert-True -Condition (-not [string]::IsNullOrWhiteSpace($manifest.generatedAt)) -Message "manifest.json must include generatedAt."
    Assert-True -Condition ($manifest.schemaVersion -eq 1) -Message "manifest.json must use schemaVersion 1."
    Assert-NonEmptyCollection $manifest.sources "manifest.json must include source status records."
    Assert-NonEmptyCollection $manifest.outputs "manifest.json must include generated output records."
  }

  if ($shoreline) {
    $rings = @($shoreline.rings)
    $outerRings = @($rings | Where-Object { $_.role -eq "outer" })
    $innerRings = @($rings | Where-Object { $_.role -eq "inner" })
    $pointTotal = ($rings | Measure-Object pointCount -Sum).Sum

    Assert-True -Condition ($shoreline.source -eq "OpenStreetMap") -Message "lake-shoreline.json source should be OpenStreetMap."
    Assert-True -Condition ($shoreline.relationId -eq 4046481) -Message "lake-shoreline.json should use OSM relation 4046481."
    Assert-True -Condition ($outerRings.Count -ge 1) -Message "lake-shoreline.json must include at least one outer ring."
    Assert-True -Condition ($innerRings.Count -ge 1) -Message "lake-shoreline.json should include inner island rings."
    Assert-True -Condition ($pointTotal -gt 1000) -Message "lake-shoreline.json should include detailed shoreline coordinates."
    Assert-True -Condition (-not [string]::IsNullOrWhiteSpace($shoreline.licenseUrl)) -Message "lake-shoreline.json must include an OSM license URL."
  }

  if ($forecastOutputExample) {
    Assert-ForecastOutputExample -Data $forecastOutputExample -Name "forecast-output.example.json"
  }

  if ($fieldMicroscopyIntakeExample) {
    Assert-FieldMicroscopyIntakeExample -Data $fieldMicroscopyIntakeExample -Name "field-microscopy-intake.example.json"
  }

  if ($reviewedFieldObservations) {
    Assert-ReviewedFieldObservations -Data $reviewedFieldObservations -Name "reviewed-field-observations.json"
  }

  foreach ($weatherFile in @(
      @{ Name = "weather-context.json"; Data = $weatherContext },
      @{ Name = "weather-context.example.json"; Data = $weatherContextExample }
    )) {
    if ($weatherFile.Data) {
      Assert-WeatherContext -Data $weatherFile.Data -Name $weatherFile.Name
    }
  }

  $index = Get-Content (Resolve-ProjectPath "index.html") -Raw
  $project = Get-Content (Resolve-ProjectPath "project.html") -Raw
  $methodology = Get-Content (Resolve-ProjectPath "methodology.html") -Raw
  $app = Get-Content (Resolve-ProjectPath "app.js") -Raw
  $styles = Get-Content (Resolve-ProjectPath "styles.css") -Raw
  $backlog = Get-Content (Resolve-ProjectPath "docs\backlog.md") -Raw
  $conversationLog = Get-Content (Resolve-ProjectPath "docs\conversation-log.md") -Raw
  $careerServicesCallNotesDoc = Get-Content (Resolve-ProjectPath "docs\career-services-call-notes.md") -Raw
  $careerServicesDayOfChecklistDoc = Get-Content (Resolve-ProjectPath "docs\career-services-day-of-checklist.md") -Raw
  $careerServicesFollowUpTrackerDoc = Get-Content (Resolve-ProjectPath "docs\career-services-follow-up-tracker.md") -Raw
  $careerServicesSharePacketDoc = Get-Content (Resolve-ProjectPath "docs\career-services-share-packet.md") -Raw
  $crossPlatformTypographyAuditDoc = Get-Content (Resolve-ProjectPath "docs\cross-platform-typography-audit.md") -Raw
  $sourceAudit = Get-Content (Resolve-ProjectPath "docs\source-audit.md") -Raw
  $forecastBoundaryDoc = Get-Content (Resolve-ProjectPath "docs\forecast-boundary.md") -Raw
  $localFirstOperatingModelDoc = Get-Content (Resolve-ProjectPath "docs\local-first-operating-model.md") -Raw
  $localGitWorkflowDoc = Get-Content (Resolve-ProjectPath "docs\local-git-workflow.md") -Raw
  $portfolioReleaseBranchHandoffDoc = Get-Content (Resolve-ProjectPath "docs\portfolio-release-branch-handoff.md") -Raw
  $portfolioSafeReleaseScopeDoc = Get-Content (Resolve-ProjectPath "docs\portfolio-safe-release-scope.md") -Raw
  $caseStudyDoc = Get-Content (Resolve-ProjectPath "docs\clear_lake_watch_portfolio_case_study.md") -Raw
  $internshipShareBriefDoc = Get-Content (Resolve-ProjectPath "docs\internship-share-brief.md") -Raw
  $internshipRoleFitMapDoc = Get-Content (Resolve-ProjectPath "docs\internship-role-fit-map.md") -Raw
  $weatherContextContractDoc = Get-Content (Resolve-ProjectPath "docs\weather-context-contract.md") -Raw
  $fieldMicroscopyIntakeDoc = Get-Content (Resolve-ProjectPath "docs\field-microscopy-intake-contract.md") -Raw
  $privateSiteReviewSurfaceDoc = Get-Content (Resolve-ProjectPath "docs\private-site-review-surface.md") -Raw
  $privateSurfaceDoc = Get-Content (Resolve-ProjectPath "docs\private-surface.md") -Raw
  $privateSqliteSurfaceDoc = Get-Content (Resolve-ProjectPath "docs\private-sqlite-surface.md") -Raw
  $publicMirrorBoundaryDoc = Get-Content (Resolve-ProjectPath "docs\public-mirror-boundary.md") -Raw
  $publicationReviewChecklistDoc = Get-Content (Resolve-ProjectPath "docs\publication-review-checklist.md") -Raw
  $reusableSchemaPackageDoc = Get-Content (Resolve-ProjectPath "docs\reusable-schema-package.md") -Raw
  $resumeLinkedinSnippetsDoc = Get-Content (Resolve-ProjectPath "docs\resume-linkedin-snippets.md") -Raw
  $screenshotReviewDoc = Get-Content (Resolve-ProjectPath "docs\screenshot-review.md") -Raw
  $deploymentDoc = Get-Content (Resolve-ProjectPath "docs\deployment.md") -Raw
  $siteReviewDecisionWorkflowDoc = Get-Content (Resolve-ProjectPath "docs\site-registry-decision-workflow.md") -Raw
  $siteReviewDoc = Get-Content (Resolve-ProjectPath "docs\site-registry-review.md") -Raw
  $highPrioritySiteReviewDoc = Get-Content (Resolve-ProjectPath "docs\site-registry-high-priority.md") -Raw
  $refreshScript = Get-Content (Resolve-ProjectPath "scripts\refresh-live-data.ps1") -Raw
  $writeWeatherContextUnavailableScript = Get-Content (Resolve-ProjectPath "scripts\write-weather-context-unavailable.ps1") -Raw
  $decisionPreviewScript = Get-Content (Resolve-ProjectPath "scripts\preview-site-review-decisions.ps1") -Raw
  $newFieldMicroscopyIntakeScript = Get-Content (Resolve-ProjectPath "scripts\new-field-microscopy-intake.ps1") -Raw
  $validateFieldMicroscopyIntakeScript = Get-Content (Resolve-ProjectPath "scripts\validate-field-microscopy-intake.ps1") -Raw
  $exportReviewedFieldObservationsScript = Get-Content (Resolve-ProjectPath "scripts\export-reviewed-field-observations.ps1") -Raw
  $checkFieldMicroscopyReviewCycleScript = Get-Content (Resolve-ProjectPath "scripts\check-field-microscopy-review-cycle.ps1") -Raw
  $fieldMicroscopyDbScript = Get-Content (Resolve-ProjectPath "scripts\field_microscopy_db.py") -Raw
  $siteReviewDbScript = Get-Content (Resolve-ProjectPath "scripts\site_review_db.py") -Raw
  $gitDiscoveryScript = Get-Content (Resolve-ProjectPath "scripts\find-local-git.ps1") -Raw
  $launchScript = Get-Content (Resolve-ProjectPath "scripts\launch-dashboard.ps1") -Raw
  $gitignore = Get-Content (Resolve-ProjectPath ".gitignore") -Raw
  $schemaPackageReadme = Get-Content (Resolve-SchemaPackagePath "README.md") -Raw
  $schemaPackagePyproject = Get-Content (Resolve-SchemaPackagePath "pyproject.toml") -Raw
  $fieldMicroscopySchemaModule = Get-Content (Resolve-SchemaPackagePath "src\environmental_monitoring_schemas\field_microscopy.py") -Raw
  Assert-True -Condition ($index.Contains('rel="icon"')) -Message "index.html must include the favicon link."
  Assert-True -Condition ($project.Contains('rel="icon"')) -Message "project.html must include the favicon link."
  Assert-True -Condition ($methodology.Contains('rel="icon"')) -Message "methodology.html must include the favicon link."
  Assert-True -Condition ($index.Contains('rel="manifest"')) -Message "index.html must include the web app manifest link."
  Assert-True -Condition ($project.Contains('rel="manifest"')) -Message "project.html must include the web app manifest link."
  Assert-True -Condition ($methodology.Contains('rel="manifest"')) -Message "methodology.html must include the web app manifest link."
  Assert-True -Condition ($index.Contains('apple-touch-icon')) -Message "index.html must include the Apple touch icon."
  Assert-True -Condition ($project.Contains('apple-touch-icon')) -Message "project.html must include the Apple touch icon."
  Assert-True -Condition ($methodology.Contains('apple-touch-icon')) -Message "methodology.html must include the Apple touch icon."
  Assert-True -Condition ($index.Contains('name="theme-color"')) -Message "index.html must include a theme-color meta tag."
  Assert-True -Condition ($project.Contains('name="theme-color"')) -Message "project.html must include a theme-color meta tag."
  Assert-True -Condition ($methodology.Contains('name="theme-color"')) -Message "methodology.html must include a theme-color meta tag."
  Assert-True -Condition ($index.Contains("./project.html")) -Message "index.html must link to the project page."
  Assert-True -Condition ($methodology.Contains("./project.html")) -Message "methodology.html must link to the project page."
  Assert-True -Condition ($project.Contains('aria-current="page"')) -Message "project.html must mark its active navigation item."
  Assert-True -Condition ($project.Contains('id="summary"')) -Message "project.html must include the project summary section."
  Assert-True -Condition ($project.Contains('id="arms"')) -Message "project.html must include the monitoring strategy section."
  Assert-True -Condition ($project.Contains('id="sources"')) -Message "project.html must include the source inventory section."
  Assert-True -Condition ($project.Contains('id="pipeline"')) -Message "project.html must include the implementation pipeline section."
  Assert-True -Condition ($project.Contains("module-list")) -Message "project.html must include the MVP module list."
  Assert-True -Condition ($project.Contains("guardrail-list")) -Message "project.html must include the trust guardrail list."
  Assert-True -Condition ($project.Contains("ml-grid")) -Message "project.html must include the ML roadmap surface."
  Assert-True -Condition ($project.Contains("forecast-boundary.md")) -Message "project.html must link to the forecast boundary contract."
  Assert-True -Condition (-not $index.Contains('id="sources"')) -Message "index.html should keep source inventory on project.html."
  Assert-True -Condition (-not $index.Contains('id="pipeline"')) -Message "index.html should keep implementation roadmap on project.html."
  Assert-True -Condition (-not $index.Contains("ml-grid")) -Message "index.html must not render the ML roadmap in the current-conditions flow."
  Assert-True -Condition ($index.Contains("map-attribution")) -Message "index.html must include visible map attribution."
  Assert-True -Condition ($index.Contains("site-review-grid")) -Message "index.html must include visible site-registry QA status."
  Assert-True -Condition ($index.Contains("map-review-filter")) -Message "index.html must include the map trust filter."
  Assert-True -Condition ($index.Contains("freshness-row")) -Message "index.html must include the data freshness row."
  Assert-True -Condition ($index.Contains("source-status-grid")) -Message "index.html must include the source status manifest surface."
  Assert-True -Condition ($index.Contains("source-output-grid")) -Message "index.html must include the generated output manifest surface."
  Assert-True -Condition ($index.Contains("manifest-notes")) -Message "index.html must include manifest interpretation notes."
  Assert-True -Condition ($index.Contains("weather-context-grid")) -Message "index.html must include the optional weather-context panel."
  Assert-True -Condition ($index.Contains("generated-label")) -Message "index.html must include the generated-label status element."
  Assert-True -Condition ($index.Contains("Loading live snapshot")) -Message "index.html must avoid a hard-coded current fallback date in the header."
  Assert-True -Condition ($index.Contains("signal-badge")) -Message "index.html must include visible signal labels for static chart cards."
  Assert-True -Condition ($index.Contains("Monitoring And Reporting Patterns")) -Message "index.html must label analytics as monitoring/reporting patterns."
  Assert-True -Condition ($index.Contains("not direct bloom-severity estimates")) -Message "index.html must warn that analytics are not direct bloom-severity estimates."
  Assert-True -Condition ($index.Contains("chart-caveat")) -Message "index.html must include inline analytics caveats."
  Assert-True -Condition ($app.Contains("Live snapshot unavailable")) -Message "app.js must render an explicit unavailable snapshot state."
  Assert-True -Condition (-not $app.Contains("formatDate(new Date())")) -Message "app.js must not fall back to today's date for missing live data."
  Assert-True -Condition ($app.Contains("createSignalBadge")) -Message "app.js must include reusable signal badge rendering."
  Assert-True -Condition ($app.Contains("Observed")) -Message "app.js must label observed data signals."
  Assert-True -Condition ($app.Contains("Reported")) -Message "app.js must label reported data signals."
  Assert-True -Condition ($app.Contains("Derived")) -Message "app.js must label derived data signals."
  Assert-True -Condition ($app.Contains("Experimental")) -Message "app.js must label experimental data signals."
  Assert-True -Condition ($app.Contains("renderSourceStatus")) -Message "app.js must render source status manifest data."
  Assert-True -Condition ($app.Contains("renderSiteReviewSummary")) -Message "app.js must render site-review QA summary data."
  Assert-True -Condition ($app.Contains("site-review-summary.json")) -Message "app.js must consume the sanitized public site-review summary."
  Assert-True -Condition (-not $app.Contains('fetchJson("./data/site-review.json"')) -Message "app.js must not fetch detailed site-review queue data for the public dashboard."
  Assert-True -Condition (-not $app.Contains("data/private/")) -Message "app.js must not reference private local data paths."
  Assert-True -Condition (-not $app.Contains(".local.json")) -Message "app.js must not reference ignored local JSON files."
  Assert-True -Condition (-not $app.Contains(".local.sqlite")) -Message "app.js must not reference ignored local SQLite stores."
  Assert-True -Condition ($app.Contains("High-priority checks")) -Message "app.js must surface high-priority site-review checks."
  Assert-True -Condition ($app.Contains("filterMapMarkers")) -Message "app.js must include confidence-aware map filtering."
  Assert-True -Condition ($app.Contains("setupMapReviewFilter")) -Message "app.js must wire the map trust filter."
  Assert-True -Condition ($app.Contains("sourceOutputGridElement")) -Message "app.js must render generated output manifest data."
  Assert-True -Condition ($app.Contains("manifestNotesElement")) -Message "app.js must render manifest notes."
  Assert-True -Condition ($app.Contains("renderWeatherContext")) -Message "app.js must render optional weather-context data."
  Assert-True -Condition ($app.Contains("weather-context.json")) -Message "app.js must attempt to load the optional weather-context export."
  Assert-True -Condition ($app.Contains("serviceWorker")) -Message "app.js must register the service worker when supported."
  Assert-True -Condition ($app.Contains('meta[name="theme-color"]')) -Message "app.js must update theme-color metadata for mobile browser chrome."
  Assert-TextContains -Text $styles -Needle '-apple-system' -Message "styles.css must include Apple/system font fallbacks."
  Assert-TextContains -Text $styles -Needle '"Helvetica Neue"' -Message "styles.css must include common cross-platform sans-serif fallback fonts."
  Assert-TextContains -Text $styles -Needle '"Book Antiqua"' -Message "styles.css must include local serif fallback fonts."
  Assert-True -Condition (-not ($styles -match 'letter-spacing:\s*-[^;]+;')) -Message "styles.css must not use negative letter spacing."
  $nonZeroLetterSpacing = @(
    $styles -split "`r?`n" |
      Where-Object { $_ -match "letter-spacing:" -and $_ -notmatch "letter-spacing:\s*0\s*;" }
  )
  Assert-True -Condition ($nonZeroLetterSpacing.Count -eq 0) -Message "styles.css explicit letter-spacing values must remain 0."
  Assert-TextContains -Text $styles -Needle "white-space: pre-line" -Message "styles.css must preserve multi-line stat values for mobile readability."
  Assert-True -Condition ($refreshScript.Contains("Get-FhabsPackage")) -Message "refresh-live-data.ps1 must resolve FHABS package metadata dynamically."
  Assert-True -Condition ($refreshScript.Contains("manifestOutputPath")) -Message "refresh-live-data.ps1 must write a source manifest."
  Assert-True -Condition ($refreshScript.Contains("Assert-FhabsResourceFreshness")) -Message "refresh-live-data.ps1 must freshness-check FHABS resource filenames."
  Assert-True -Condition (-not ($refreshScript -match 'download/(?:bloom-report|hab-results)_\d{4}-\d{2}-\d{2}\.csv')) -Message "refresh-live-data.ps1 must not pin FHABS downloads to dated CSV URLs."
  Assert-TextContains -Text $writeWeatherContextUnavailableScript -Needle "machineReadableStatus = `"unavailable`"" -Message "write-weather-context-unavailable.ps1 must write an unavailable weather status."
  Assert-TextContains -Text $writeWeatherContextUnavailableScript -Needle "not a live telemetry export" -Message "write-weather-context-unavailable.ps1 must preserve the no-live-telemetry boundary."
  Assert-TextContains -Text $writeWeatherContextUnavailableScript -Needle "public-health guidance" -Message "write-weather-context-unavailable.ps1 must preserve the public-health boundary."
  Assert-True -Condition ($launchScript.Contains("LOCALAPPDATA") -and $launchScript.Contains("runtime")) -Message "launch-dashboard.ps1 must keep runtime files outside the static web root."
  Assert-True -Condition (-not ($launchScript -match 'Join-Path\s+\$projectRoot\s+"server\.(?:pid|out\.log|err\.log)"')) -Message "launch-dashboard.ps1 must not write server runtime files into the project root."
  Assert-TextContains -Text $backlog -Needle "P0-04 Split Public Dashboard From Project Roadmap Content" -Message "docs/backlog.md must track the dashboard/project split."
  Assert-TextContains -Text $backlog -Needle "Status: Done" -Message "docs/backlog.md must mark completed trust-hardening items as done."
  Assert-TextContains -Text $backlog -Needle "live export pending" -Message "docs/backlog.md must keep the live weather-context export boundary visible."
  Assert-TextContains -Text $conversationLog -Needle "April 22, 2026 Trust-Hardening Update" -Message "docs/conversation-log.md must include the latest trust-hardening update."
  Assert-TextContains -Text $conversationLog -Needle "Git was not available" -Message "docs/conversation-log.md must preserve the local Git availability caveat."
  Assert-TextContains -Text $conversationLog -Needle "Local Git Availability Check" -Message "docs/conversation-log.md must preserve the local Git availability check."
  Assert-TextContains -Text $conversationLog -Needle "Forecast Boundary Contract" -Message "docs/conversation-log.md must preserve the forecast boundary update."
  Assert-TextContains -Text $conversationLog -Needle "Jones Bay Registry Split" -Message "docs/conversation-log.md must preserve the Jones Bay registry split rationale."
  Assert-TextContains -Text $sourceAudit -Needle "Shared Backbone Weather Context Export" -Message "docs/source-audit.md must document the weather context export as a context source."
  Assert-TextContains -Text $sourceAudit -Needle "resolves FHABS resources dynamically" -Message "docs/source-audit.md must document dynamic FHABS resource resolution."
  Assert-TextContains -Text $sourceAudit -Needle "Jones Bay / Jago Bay split" -Message "docs/source-audit.md must document the Jones Bay / Jago Bay naming cross-check."
  Assert-TextContains -Text $forecastBoundaryDoc -Needle "Experimental forecast only. Not official public-health guidance." -Message "docs/forecast-boundary.md must include the required forecast disclaimer."
  Assert-TextContains -Text $forecastBoundaryDoc -Needle "trainingWindow" -Message "docs/forecast-boundary.md must require a training window."
  Assert-TextContains -Text $forecastBoundaryDoc -Needle "uncertainty" -Message "docs/forecast-boundary.md must require uncertainty language."
  Assert-TextContains -Text $localFirstOperatingModelDoc -Needle "edge collection -> local processing -> local storage -> reviewed public export -> static public mirror" -Message "docs/local-first-operating-model.md must define the local-first operating path."
  Assert-TextContains -Text $localFirstOperatingModelDoc -Needle "Core functions must work without an LLM" -Message "docs/local-first-operating-model.md must preserve the no-LLM core-function boundary."
  Assert-TextContains -Text $localFirstOperatingModelDoc -Needle "data/private/site-review.local.sqlite" -Message "docs/local-first-operating-model.md must document the site-review SQLite store."
  Assert-TextContains -Text $localFirstOperatingModelDoc -Needle "data/private/field-microscopy.local.sqlite" -Message "docs/local-first-operating-model.md must document the field/microscopy SQLite store."
  Assert-TextContains -Text $localFirstOperatingModelDoc -Needle "data/weather-context.json" -Message "docs/local-first-operating-model.md must document the weather-context export."
  Assert-TextContains -Text $localFirstOperatingModelDoc -Needle "Do not connect the public dashboard directly to MQTT" -Message "docs/local-first-operating-model.md must protect the public dashboard from direct live/private connections."
  Assert-TextContains -Text $localFirstOperatingModelDoc -Needle "Lake module" -Message "docs/local-first-operating-model.md must keep lake module boundaries visible."
  Assert-TextContains -Text $localFirstOperatingModelDoc -Needle "Weather and soil module" -Message "docs/local-first-operating-model.md must keep weather/soil module boundaries visible."
  Assert-TextContains -Text $localFirstOperatingModelDoc -Needle "Field/microscopy module" -Message "docs/local-first-operating-model.md must keep field/microscopy module boundaries visible."
  Assert-TextContains -Text $localFirstOperatingModelDoc -Needle "Review-decision module" -Message "docs/local-first-operating-model.md must keep reusable review-decision module boundaries visible."
  Assert-TextContains -Text $localGitWorkflowDoc -Needle "git version 2.54.0.windows.1" -Message "docs/local-git-workflow.md must document the verified local Git version."
  Assert-TextContains -Text $localGitWorkflowDoc -Needle "Git work tree" -Message "docs/local-git-workflow.md must document that the current folder is a Git work tree."
  Assert-TextContains -Text $localGitWorkflowDoc -Needle "git --no-pager diff" -Message "docs/local-git-workflow.md must document local diff review."
  Assert-TextContains -Text $localGitWorkflowDoc -Needle "Git availability is not a publication decision" -Message "docs/local-git-workflow.md must separate Git availability from publication."
  Assert-TextContains -Text $portfolioReleaseBranchHandoffDoc -Needle "Portfolio Release Branch Handoff" -Message "docs/portfolio-release-branch-handoff.md must define the branch handoff note."
  Assert-TextContains -Text $portfolioReleaseBranchHandoffDoc -Needle "codex/portfolio-safe-release-prep" -Message "docs/portfolio-release-branch-handoff.md must document the current branch."
  Assert-TextContains -Text $portfolioReleaseBranchHandoffDoc -Needle "9ff94e3 Add portfolio release branch handoff" -Message "docs/portfolio-release-branch-handoff.md must document the latest local commit."
  Assert-TextContains -Text $portfolioReleaseBranchHandoffDoc -Needle "has not been pushed" -Message "docs/portfolio-release-branch-handoff.md must document that the branch is local/unpushed."
  Assert-TextContains -Text $portfolioReleaseBranchHandoffDoc -Needle "Intentionally Uncommitted" -Message "docs/portfolio-release-branch-handoff.md must document intentionally uncommitted files."
  Assert-TextContains -Text $portfolioReleaseBranchHandoffDoc -Needle "docs/Project_Brief_DRAFT_1.docx" -Message "docs/portfolio-release-branch-handoff.md must document the uncommitted docx artifact."
  Assert-TextContains -Text $portfolioReleaseBranchHandoffDoc -Needle "docs/publication-review-checklist.md" -Message "docs/portfolio-release-branch-handoff.md must point to the publication checklist."
  Assert-TextContains -Text $portfolioSafeReleaseScopeDoc -Needle "Portfolio-Safe Release Scope" -Message "docs/portfolio-safe-release-scope.md must define the portfolio-safe release scope."
  Assert-TextContains -Text $portfolioSafeReleaseScopeDoc -Needle "late prototype / early MVP" -Message "docs/portfolio-safe-release-scope.md must preserve maturity status."
  Assert-TextContains -Text $portfolioSafeReleaseScopeDoc -Needle "official monitoring authority" -Message "docs/portfolio-safe-release-scope.md must avoid authority claims."
  Assert-TextContains -Text $portfolioSafeReleaseScopeDoc -Needle "live field submission workflow" -Message "docs/portfolio-safe-release-scope.md must avoid live field submission scope."
  Assert-TextContains -Text $portfolioSafeReleaseScopeDoc -Needle "internship share brief and career-services call notes" -Message "docs/portfolio-safe-release-scope.md must include internship share materials."
  Assert-TextContains -Text $portfolioSafeReleaseScopeDoc -Needle "site-registry trust hardening" -Message "docs/portfolio-safe-release-scope.md must recommend site review before weather expansion."
  Assert-TextContains -Text $portfolioSafeReleaseScopeDoc -Needle "reviewed weather telemetry integration" -Message "docs/portfolio-safe-release-scope.md must name weather telemetry as a later fork."
  Assert-TextContains -Text $internshipShareBriefDoc -Needle "Clear Lake Watch Internship Share Brief" -Message "docs/internship-share-brief.md must be the internship share brief."
  Assert-TextContains -Text $internshipShareBriefDoc -Needle "not official public-health guidance" -Message "docs/internship-share-brief.md must preserve the public-health boundary."
  Assert-TextContains -Text $internshipShareBriefDoc -Needle "Internship-Relevant Skill Signals" -Message "docs/internship-share-brief.md must include skill signals."
  Assert-TextContains -Text $internshipShareBriefDoc -Needle "Claims To Avoid" -Message "docs/internship-share-brief.md must include claims to avoid."
  Assert-TextContains -Text $internshipShareBriefDoc -Needle "Suggested Ask For Career Services" -Message "docs/internship-share-brief.md must include a career-services ask."
  Assert-TextContains -Text $internshipShareBriefDoc -Needle "docs/career-services-share-packet.md" -Message "docs/internship-share-brief.md must link to the career-services packet index."
  Assert-TextContains -Text $internshipShareBriefDoc -Needle "docs/internship-role-fit-map.md" -Message "docs/internship-share-brief.md must link to the internship role fit map."
  Assert-TextContains -Text $internshipShareBriefDoc -Needle "docs/resume-linkedin-snippets.md" -Message "docs/internship-share-brief.md must link to resume and LinkedIn snippets."
  Assert-TextContains -Text $internshipShareBriefDoc -Needle "run May 6, 2026" -Message "docs/internship-share-brief.md must include the latest validation date."
  Assert-TextContains -Text $internshipShareBriefDoc -Needle "8 detailed queue records" -Message "docs/internship-share-brief.md must include site-review validation detail."
  Assert-TextContains -Text $internshipRoleFitMapDoc -Needle "Internship Role Fit Map" -Message "docs/internship-role-fit-map.md must define the internship role fit map."
  Assert-TextContains -Text $internshipRoleFitMapDoc -Needle "Environmental Data / Monitoring Intern" -Message "docs/internship-role-fit-map.md must include environmental data roles."
  Assert-TextContains -Text $internshipRoleFitMapDoc -Needle "GIS / Spatial Analysis Intern" -Message "docs/internship-role-fit-map.md must include GIS roles."
  Assert-TextContains -Text $internshipRoleFitMapDoc -Needle "Water Resources / Watershed Intern" -Message "docs/internship-role-fit-map.md must include water resources roles."
  Assert-TextContains -Text $internshipRoleFitMapDoc -Needle "Resume Bullet Variants" -Message "docs/internship-role-fit-map.md must include resume bullet variants."
  Assert-TextContains -Text $internshipRoleFitMapDoc -Needle "docs/resume-linkedin-snippets.md" -Message "docs/internship-role-fit-map.md must link to resume and LinkedIn snippets."
  Assert-TextContains -Text $internshipRoleFitMapDoc -Needle "Do not frame Clear Lake Watch as a complete monitoring system" -Message "docs/internship-role-fit-map.md must preserve the boundary reminder."
  Assert-TextContains -Text $careerServicesCallNotesDoc -Needle "Thirty-Second Project Pitch" -Message "docs/career-services-call-notes.md must include a short project pitch."
  Assert-TextContains -Text $careerServicesCallNotesDoc -Needle "Questions To Ask" -Message "docs/career-services-call-notes.md must include questions for career services."
  Assert-TextContains -Text $careerServicesCallNotesDoc -Needle "Resume Bullet Draft" -Message "docs/career-services-call-notes.md must include a resume bullet draft."
  Assert-TextContains -Text $careerServicesCallNotesDoc -Needle "Follow-Up Message Template" -Message "docs/career-services-call-notes.md must include a follow-up template."
  Assert-TextContains -Text $careerServicesCallNotesDoc -Needle "docs/career-services-day-of-checklist.md" -Message "docs/career-services-call-notes.md must link to the day-of checklist."
  Assert-TextContains -Text $careerServicesCallNotesDoc -Needle "docs/career-services-share-packet.md" -Message "docs/career-services-call-notes.md must link to the packet index."
  Assert-TextContains -Text $careerServicesCallNotesDoc -Needle "docs/internship-role-fit-map.md" -Message "docs/career-services-call-notes.md must link to the internship role fit map."
  Assert-TextContains -Text $careerServicesCallNotesDoc -Needle "docs/resume-linkedin-snippets.md" -Message "docs/career-services-call-notes.md must link to resume and LinkedIn snippets."
  Assert-TextContains -Text $careerServicesCallNotesDoc -Needle "Call Boundary" -Message "docs/career-services-call-notes.md must include a conservative call boundary."
  Assert-TextContains -Text $careerServicesDayOfChecklistDoc -Needle "Career Services Day-Of Checklist" -Message "docs/career-services-day-of-checklist.md must define the call-day checklist."
  Assert-TextContains -Text $careerServicesDayOfChecklistDoc -Needle "Open Before The Call" -Message "docs/career-services-day-of-checklist.md must include pre-call open items."
  Assert-TextContains -Text $careerServicesDayOfChecklistDoc -Needle "Main Ask" -Message "docs/career-services-day-of-checklist.md must include the main ask."
  Assert-TextContains -Text $careerServicesDayOfChecklistDoc -Needle "Three Questions To Prioritize" -Message "docs/career-services-day-of-checklist.md must include prioritized questions."
  Assert-TextContains -Text $careerServicesDayOfChecklistDoc -Needle "Notes To Capture During The Call" -Message "docs/career-services-day-of-checklist.md must include call notes fields."
  Assert-TextContains -Text $careerServicesDayOfChecklistDoc -Needle "docs/career-services-follow-up-tracker.md" -Message "docs/career-services-day-of-checklist.md must link to the follow-up tracker."
  Assert-TextContains -Text $careerServicesDayOfChecklistDoc -Needle "Avoid:" -Message "docs/career-services-day-of-checklist.md must include avoid-language guidance."
  Assert-TextContains -Text $careerServicesFollowUpTrackerDoc -Needle "Career Services Follow-Up Tracker" -Message "docs/career-services-follow-up-tracker.md must define the follow-up tracker."
  Assert-TextContains -Text $careerServicesFollowUpTrackerDoc -Needle "Recommended Role Titles" -Message "docs/career-services-follow-up-tracker.md must track recommended role titles."
  Assert-TextContains -Text $careerServicesFollowUpTrackerDoc -Needle "Recommended Search Keywords" -Message "docs/career-services-follow-up-tracker.md must track recommended search keywords."
  Assert-TextContains -Text $careerServicesFollowUpTrackerDoc -Needle "Organizations Or Contacts" -Message "docs/career-services-follow-up-tracker.md must track organizations or contacts."
  Assert-TextContains -Text $careerServicesFollowUpTrackerDoc -Needle "Application Leads" -Message "docs/career-services-follow-up-tracker.md must track application leads."
  Assert-TextContains -Text $careerServicesFollowUpTrackerDoc -Needle "Boundary Check" -Message "docs/career-services-follow-up-tracker.md must include a boundary check."
  Assert-TextContains -Text $careerServicesSharePacketDoc -Needle "Career Services Share Packet" -Message "docs/career-services-share-packet.md must define the packet index."
  Assert-TextContains -Text $careerServicesSharePacketDoc -Needle "docs/career-services-day-of-checklist.md" -Message "docs/career-services-share-packet.md must link to the day-of checklist."
  Assert-TextContains -Text $careerServicesSharePacketDoc -Needle "docs/career-services-follow-up-tracker.md" -Message "docs/career-services-share-packet.md must link to the follow-up tracker."
  Assert-TextContains -Text $careerServicesSharePacketDoc -Needle "Five-Minute Review" -Message "docs/career-services-share-packet.md must include a short review path."
  Assert-TextContains -Text $careerServicesSharePacketDoc -Needle "docs/resume-linkedin-snippets.md" -Message "docs/career-services-share-packet.md must link to resume and LinkedIn snippets."
  Assert-TextContains -Text $careerServicesSharePacketDoc -Needle "Fifteen-Minute Review" -Message "docs/career-services-share-packet.md must include a medium review path."
  Assert-TextContains -Text $careerServicesSharePacketDoc -Needle "Feedback Requested" -Message "docs/career-services-share-packet.md must ask for feedback."
  Assert-TextContains -Text $careerServicesSharePacketDoc -Needle "not official public-health guidance" -Message "docs/career-services-share-packet.md must preserve public-health boundary language."
  Assert-TextContains -Text $careerServicesSharePacketDoc -Needle "Avoid:" -Message "docs/career-services-share-packet.md must include avoid-language guidance."
  Assert-TextContains -Text $resumeLinkedinSnippetsDoc -Needle "Resume And LinkedIn Snippets" -Message "docs/resume-linkedin-snippets.md must define application snippets."
  Assert-TextContains -Text $resumeLinkedinSnippetsDoc -Needle "One-Line Resume Entry" -Message "docs/resume-linkedin-snippets.md must include a one-line resume entry."
  Assert-TextContains -Text $resumeLinkedinSnippetsDoc -Needle "LinkedIn Project Description" -Message "docs/resume-linkedin-snippets.md must include a LinkedIn project description."
  Assert-TextContains -Text $resumeLinkedinSnippetsDoc -Needle "Handshake / Portfolio Summary" -Message "docs/resume-linkedin-snippets.md must include a Handshake or portfolio summary."
  Assert-TextContains -Text $resumeLinkedinSnippetsDoc -Needle "late prototype / early MVP" -Message "docs/resume-linkedin-snippets.md must preserve maturity language."
  Assert-TextContains -Text $resumeLinkedinSnippetsDoc -Needle "Avoid these terms" -Message "docs/resume-linkedin-snippets.md must include avoid-language guidance."
  Assert-TextContains -Text $caseStudyDoc -Needle "Publication Readiness and Validation" -Message "case study must include publication readiness and validation framing."
  Assert-TextContains -Text $caseStudyDoc -Needle "portfolio-safe release" -Message "case study must preserve portfolio-safe release framing."
  Assert-TextContains -Text $caseStudyDoc -Needle "https://coreytshaffer.github.io/clear-lake-watch/" -Message "case study must include the live dashboard URL."
  Assert-TextContains -Text $caseStudyDoc -Needle "https://github.com/coreytshaffer/clear-lake-watch" -Message "case study must include the repository URL."
  Assert-TextContains -Text $caseStudyDoc -Needle "Latest local validation status, checked May 6, 2026" -Message "case study must include latest validation status."
  Assert-TextContains -Text $caseStudyDoc -Needle "review-screenshots/clear-lake-watch-mobile-width-2026-05-05.png" -Message "case study must reference the local screenshot artifact."
  Assert-TextContains -Text $caseStudyDoc -Needle "Soft-share privately" -Message "case study next steps must include private soft-share feedback."
  Assert-TextContains -Text $caseStudyDoc -Needle "Complete real site-registry review" -Message "case study next steps must prioritize site-registry trust hardening."
  Assert-TextContains -Text $caseStudyDoc -Needle "Connect reviewed weather-context exports only after" -Message "case study next steps must keep weather telemetry after trust-hardening."
  Assert-TextContains -Text $backlog -Needle "docs/local-first-operating-model.md" -Message "docs/backlog.md must track the local-first operating model slice."
  Assert-TextContains -Text $backlog -Needle "portfolio-safe release pass" -Message "docs/backlog.md must track the portfolio-safe release decision."
  Assert-TextContains -Text $backlog -Needle "Done for local availability" -Message "docs/backlog.md must mark local Git availability as resolved."
  Assert-TextContains -Text $conversationLog -Needle "Local-First Operating Model" -Message "docs/conversation-log.md must record the local-first operating model update."
  Assert-TextContains -Text $conversationLog -Needle "Git Availability Refresh" -Message "docs/conversation-log.md must record the current Git availability refresh."
  Assert-TextContains -Text $conversationLog -Needle "Portfolio-Safe Release Scope" -Message "docs/conversation-log.md must record the portfolio-safe release scope."
  Assert-TextContains -Text $crossPlatformTypographyAuditDoc -Needle "no external web fonts" -Message "docs/cross-platform-typography-audit.md must document the no-web-font posture."
  Assert-TextContains -Text $crossPlatformTypographyAuditDoc -Needle "local mobile-width screenshot review complete" -Message "docs/cross-platform-typography-audit.md must document the local mobile-width screenshot review."
  Assert-TextContains -Text $crossPlatformTypographyAuditDoc -Needle "non-Windows or physical mobile browser" -Message "docs/cross-platform-typography-audit.md must preserve the remaining device/browser screenshot review."
  Assert-TextContains -Text $crossPlatformTypographyAuditDoc -Needle "letter-spacing" -Message "docs/cross-platform-typography-audit.md must document letter-spacing normalization."
  Assert-TextContains -Text $screenshotReviewDoc -Needle "local mobile-width visual review complete" -Message "docs/screenshot-review.md must record the local screenshot review status."
  Assert-TextContains -Text $screenshotReviewDoc -Needle "clear-lake-watch-mobile-width-2026-05-05.png" -Message "docs/screenshot-review.md must point to the captured screenshot."
  Assert-TextContains -Text $screenshotReviewDoc -Needle "486 x 719 px" -Message "docs/screenshot-review.md must record the captured viewport dimensions."
  Assert-TextContains -Text $screenshotReviewDoc -Needle "not a publication announcement" -Message "docs/screenshot-review.md must preserve the local-only review boundary."
  Assert-TextContains -Text $backlog -Needle "local mobile-width screenshot review complete" -Message "docs/backlog.md must track the local screenshot review."
  Assert-TextContains -Text $weatherContextContractDoc -Needle "write-weather-context-unavailable.ps1" -Message "docs/weather-context-contract.md must document the unavailable writer command."
  Assert-TextContains -Text $weatherContextContractDoc -Needle "not evidence of live telemetry" -Message "docs/weather-context-contract.md must preserve the unavailable-placeholder boundary."
  Assert-TextContains -Text $fieldMicroscopyIntakeDoc -Needle "private intake -> QA review -> publish decision -> sanitized public export -> static dashboard" -Message "docs/field-microscopy-intake-contract.md must preserve the review-first workflow."
  Assert-TextContains -Text $fieldMicroscopyIntakeDoc -Needle 'Only `approved-public` records with `permissionToPublish: true` may be included in a public export.' -Message "docs/field-microscopy-intake-contract.md must require reviewed publication permission."
  Assert-TextContains -Text $fieldMicroscopyIntakeDoc -Needle "Field and microscopy records are a separate source family." -Message "docs/field-microscopy-intake-contract.md must keep field/microscopy as a separate source family."
  Assert-TextContains -Text $privateSiteReviewSurfaceDoc -Needle "data/site-review-summary.json" -Message "docs/private-site-review-surface.md must document the public site-review summary."
  Assert-TextContains -Text $privateSiteReviewSurfaceDoc -Needle "data/private/site-review.local.sqlite" -Message "docs/private-site-review-surface.md must document the ignored local SQLite site-review store."
  Assert-TextContains -Text $privateSiteReviewSurfaceDoc -Needle "review_decisions" -Message "docs/private-site-review-surface.md must document the reusable review_decisions table."
  Assert-TextContains -Text $privateSiteReviewSurfaceDoc -Needle "subject_type = site-registry-review" -Message "docs/private-site-review-surface.md must document the first site-registry decision subject type."
  Assert-TextContains -Text $privateSiteReviewSurfaceDoc -Needle "import-decisions" -Message "docs/private-site-review-surface.md must document the decision JSON import command."
  Assert-TextContains -Text $privateSiteReviewSurfaceDoc -Needle "data/site-review.json" -Message "docs/private-site-review-surface.md must document the detailed local review artifact."
  Assert-TextContains -Text $privateSiteReviewSurfaceDoc -Needle "Detailed site-review records stay local-only prior to review" -Message "docs/private-site-review-surface.md must document the local-only prior-to-review decision."
  Assert-TextContains -Text $privateSiteReviewSurfaceDoc -Needle "site_review_db.py export-summary" -Message "docs/private-site-review-surface.md must document the SQLite public-summary export command."
  Assert-TextContains -Text $privateSiteReviewSurfaceDoc -Needle "Public pages should not show" -Message "docs/private-site-review-surface.md must document public exclusion rules."
  Assert-TextContains -Text $privateSurfaceDoc -Needle "Use local SQLite" -Message "docs/private-surface.md must document the selected SQLite private surface."
  Assert-TextContains -Text $privateSurfaceDoc -Needle "data/private/" -Message "docs/private-surface.md must document the ignored private workspace."
  Assert-TextContains -Text $privateSurfaceDoc -Needle "data/reviewed-field-observations.json" -Message "docs/private-surface.md must document the public-safe reviewed export."
  Assert-TextContains -Text $privateSurfaceDoc -Needle "check-field-microscopy-review-cycle.ps1" -Message "docs/private-surface.md must document the review-cycle smoke check."
  Assert-TextContains -Text $privateSqliteSurfaceDoc -Needle "data/private/field-microscopy.local.sqlite" -Message "docs/private-sqlite-surface.md must document the ignored SQLite database path."
  Assert-TextContains -Text $privateSqliteSurfaceDoc -Needle "field_microscopy_db.py smoke-cycle" -Message "docs/private-sqlite-surface.md must document the SQLite smoke-cycle command."
  Assert-TextContains -Text $privateSqliteSurfaceDoc -Needle "permission_to_publish" -Message "docs/private-sqlite-surface.md must document SQLite publication permission."
  Assert-TextContains -Text $publicMirrorBoundaryDoc -Needle "private local record -> review decision -> sanitized export -> static public mirror" -Message "docs/public-mirror-boundary.md must document the reviewed export path."
  Assert-TextContains -Text $publicMirrorBoundaryDoc -Needle "data/private/" -Message "docs/public-mirror-boundary.md must exclude private data paths from publishing."
  Assert-TextContains -Text $publicMirrorBoundaryDoc -Needle "*.local.sqlite" -Message "docs/public-mirror-boundary.md must exclude local SQLite stores from publishing."
  Assert-TextContains -Text $publicMirrorBoundaryDoc -Needle "data/site-review-summary.json" -Message "docs/public-mirror-boundary.md must document public aggregate site-review export."
  Assert-TextContains -Text $publicMirrorBoundaryDoc -Needle "data/reviewed-field-observations.json" -Message "docs/public-mirror-boundary.md must document public-safe reviewed field export."
  Assert-TextContains -Text $publicMirrorBoundaryDoc -Needle "docs/publication-review-checklist.md" -Message "docs/public-mirror-boundary.md must point to the publication review checklist."
  Assert-TextContains -Text $publicationReviewChecklistDoc -Needle "local review only" -Message "docs/publication-review-checklist.md must distinguish local review from publication."
  Assert-TextContains -Text $publicationReviewChecklistDoc -Needle 'Do not use `-AllowStaleSnapshot` for a fresh public publish.' -Message "docs/publication-review-checklist.md must preserve the fresh-publish freshness rule."
  Assert-TextContains -Text $publicationReviewChecklistDoc -Needle "data/private/" -Message "docs/publication-review-checklist.md must include the private-file gate."
  Assert-TextContains -Text $publicationReviewChecklistDoc -Needle "late prototype / early MVP" -Message "docs/publication-review-checklist.md must preserve maturity claim language."
  Assert-TextContains -Text $publicationReviewChecklistDoc -Needle "needs-local-review" -Message "docs/publication-review-checklist.md must preserve the site-registry review boundary."
  Assert-TextContains -Text $publicationReviewChecklistDoc -Needle "clear-lake-watch-mobile-width-2026-05-05.png" -Message "docs/publication-review-checklist.md must reference the local screenshot review artifact."
  Assert-TextContains -Text $publicationReviewChecklistDoc -Needle "git ls-files --others --exclude-standard" -Message "docs/publication-review-checklist.md must include untracked-file review before publication."
  Assert-TextContains -Text $publicationReviewChecklistDoc -Needle "Git availability is not a publication decision." -Message "docs/publication-review-checklist.md must separate Git availability from publication."
  Assert-TextContains -Text $publicationReviewChecklistDoc -Needle "docs/portfolio-safe-release-scope.md" -Message "docs/publication-review-checklist.md must point to the portfolio-safe release scope."
  Assert-TextContains -Text $publicationReviewChecklistDoc -Needle "docs/portfolio-release-branch-handoff.md" -Message "docs/publication-review-checklist.md must point to the branch handoff note."
  Assert-TextContains -Text $publicationReviewChecklistDoc -Needle "Soft-Share Gate" -Message "docs/publication-review-checklist.md must include a private soft-share gate."
  Assert-TextContains -Text $deploymentDoc -Needle "docs/public-mirror-boundary.md" -Message "docs/deployment.md must point to the public mirror boundary."
  Assert-TextContains -Text $deploymentDoc -Needle "docs/publication-review-checklist.md" -Message "docs/deployment.md must point to the publication review checklist."
  Assert-TextContains -Text $deploymentDoc -Needle "data/site-review-decisions.local.json" -Message "docs/deployment.md must exclude local site-review decisions from public deployment."
  Assert-TextContains -Text $deploymentDoc -Needle "*.local.sqlite" -Message "docs/deployment.md must exclude local SQLite stores from public deployment."
  Assert-TextContains -Text $reusableSchemaPackageDoc -Needle "../environmental-monitoring-schemas/" -Message "docs/reusable-schema-package.md must document the sibling package repository path."
  Assert-TextContains -Text $reusableSchemaPackageDoc -Needle "validate_record(record)" -Message "docs/reusable-schema-package.md must document the reusable validation API."
  Assert-TextContains -Text $reusableSchemaPackageDoc -Needle "assert_no_private_fields(payload)" -Message "docs/reusable-schema-package.md must document private-field exclusion checks."
  Assert-TextContains -Text $siteReviewDecisionWorkflowDoc -Needle "Review decisions should be recorded before registry edits are made." -Message "docs/site-registry-decision-workflow.md must preserve review-before-write guidance."
  Assert-TextContains -Text $siteReviewDecisionWorkflowDoc -Needle "preview-site-review-decisions.ps1" -Message "docs/site-registry-decision-workflow.md must document the preview command."
  Assert-TextContains -Text $siteReviewDecisionWorkflowDoc -Needle "data/private/site-review.local.sqlite" -Message "docs/site-registry-decision-workflow.md must document the local SQLite site-review store."
  Assert-TextContains -Text $siteReviewDecisionWorkflowDoc -Needle "subject_type" -Message "docs/site-registry-decision-workflow.md must document reusable decision subjects."
  Assert-TextContains -Text $siteReviewDecisionWorkflowDoc -Needle "siteId::landmark" -Message "docs/site-registry-decision-workflow.md must document the site-registry decision subject ID."
  Assert-TextContains -Text $siteReviewDecisionWorkflowDoc -Needle "import-decisions" -Message "docs/site-registry-decision-workflow.md must document importing decision JSON into SQLite."
  Assert-TextContains -Text $siteReviewDecisionWorkflowDoc -Needle "promote-reviewed-local" -Message "docs/site-registry-decision-workflow.md must document reviewed-local promotion rules."
  Assert-TextContains -Text $siteReviewDecisionWorkflowDoc -Needle "fhabs-jones-bay" -Message "docs/site-registry-decision-workflow.md must document the Jones Bay starter-site split."
  Assert-TextContains -Text $siteReviewDoc -Needle "Evidence note" -Message "docs/site-registry-review.md must include evidence notes."
  Assert-TextContains -Text $highPrioritySiteReviewDoc -Needle "High-Priority Site Registry Review" -Message "docs/site-registry-high-priority.md must include the high-priority review packet."
  Assert-TextContains -Text $highPrioritySiteReviewDoc -Needle "Review Decision Rules" -Message "docs/site-registry-high-priority.md must include review decision rules."
  if ($siteReview.summary.highPriorityReviewItems -gt 0) {
    Assert-TextContains -Text $highPrioritySiteReviewDoc -Needle "Decision:" -Message "docs/site-registry-high-priority.md must include a decision checklist when high-priority items exist."
    Assert-TextContains -Text $highPrioritySiteReviewDoc -Needle "openstreetmap.org" -Message "docs/site-registry-high-priority.md must include map links for review when high-priority items exist."
  } else {
    Assert-TextContains -Text $highPrioritySiteReviewDoc -Needle "No high-priority current marker checks were generated." -Message "docs/site-registry-high-priority.md must clearly state when no high-priority items remain."
  }
  Assert-TextContains -Text $decisionPreviewScript -Needle "No files were modified" -Message "preview-site-review-decisions.ps1 must make its dry-run behavior explicit."
  Assert-TextContains -Text $decisionPreviewScript -Needle "permissionToPublish" -Message "preview-site-review-decisions.ps1 must validate publication permission boundaries."
  Assert-TextContains -Text $newFieldMicroscopyIntakeScript -Needle "data/private/field-microscopy-intake.local.json" -Message "new-field-microscopy-intake.ps1 must create the ignored local intake file by default."
  Assert-TextContains -Text $validateFieldMicroscopyIntakeScript -Needle "approved-public" -Message "validate-field-microscopy-intake.ps1 must validate approved-public publication rules."
  Assert-TextContains -Text $validateFieldMicroscopyIntakeScript -Needle "permissionToPublish" -Message "validate-field-microscopy-intake.ps1 must validate permissionToPublish publication rules."
  Assert-TextContains -Text $exportReviewedFieldObservationsScript -Needle "approved-public" -Message "export-reviewed-field-observations.ps1 must require approved-public before export."
  Assert-TextContains -Text $exportReviewedFieldObservationsScript -Needle "permissionToPublish" -Message "export-reviewed-field-observations.ps1 must require permissionToPublish before export."
  Assert-TextContains -Text $exportReviewedFieldObservationsScript -Needle "collector identity" -Message "export-reviewed-field-observations.ps1 must document private field exclusion."
  Assert-TextContains -Text $checkFieldMicroscopyReviewCycleScript -Needle "forbiddenPublicFields" -Message "check-field-microscopy-review-cycle.ps1 must check forbidden private fields."
  Assert-TextContains -Text $checkFieldMicroscopyReviewCycleScript -Needle "Remove-Item" -Message "check-field-microscopy-review-cycle.ps1 must clean up temporary local files."
  Assert-TextContains -Text $fieldMicroscopyDbScript -Needle "sqlite3" -Message "field_microscopy_db.py must use SQLite through Python's sqlite3 module."
  Assert-TextContains -Text $fieldMicroscopyDbScript -Needle "permission_to_publish = 1" -Message "field_microscopy_db.py must filter exports by permission_to_publish."
  Assert-TextContains -Text $fieldMicroscopyDbScript -Needle "FORBIDDEN_PUBLIC_FIELDS" -Message "field_microscopy_db.py must define forbidden public fields."
  Assert-TextContains -Text $fieldMicroscopyDbScript -Needle "field-microscopy-sqlite-smoke.local.sqlite" -Message "field_microscopy_db.py smoke-cycle must use a temporary database by default."
  Assert-TextContains -Text $fieldMicroscopyDbScript -Needle "from environmental_monitoring_schemas.field_microscopy import" -Message "field_microscopy_db.py must import shared schema rules from the package."
  Assert-TextContains -Text $fieldMicroscopyDbScript -Needle "PROJECT_ROOT.parent" -Message "field_microscopy_db.py must resolve the sibling shared package path."
  Assert-TextContains -Text $siteReviewDbScript -Needle "sqlite3" -Message "site_review_db.py must use SQLite through Python's sqlite3 module."
  Assert-TextContains -Text $siteReviewDbScript -Needle "site-review.local.sqlite" -Message "site_review_db.py must default to the ignored local site-review database."
  Assert-TextContains -Text $siteReviewDbScript -Needle "site_review_runs" -Message "site_review_db.py must define site-review run storage."
  Assert-TextContains -Text $siteReviewDbScript -Needle "site_review_queue" -Message "site_review_db.py must define detailed review-queue storage."
  Assert-TextContains -Text $siteReviewDbScript -Needle "review_decisions" -Message "site_review_db.py must define reusable review-decision storage."
  Assert-TextContains -Text $siteReviewDbScript -Needle "subject_type" -Message "site_review_db.py must support reusable decision subject types."
  Assert-TextContains -Text $siteReviewDbScript -Needle "DEFAULT_DECISION_SUBJECT_TYPE" -Message "site_review_db.py must define the default site-registry decision subject type."
  Assert-TextContains -Text $siteReviewDbScript -Needle "siteId::landmark" -Message "site_review_db.py must document the first decision subject ID convention."
  Assert-TextContains -Text $siteReviewDbScript -Needle "import-decisions" -Message "site_review_db.py must expose an import-decisions command."
  Assert-TextContains -Text $siteReviewDbScript -Needle "DECISION_STATUS_BY_ACTION" -Message "site_review_db.py must map existing JSON actions to reusable decision statuses."
  Assert-TextContains -Text $siteReviewDbScript -Needle "permission_to_publish" -Message "site_review_db.py must store review publication permission separately from queue facts."
  Assert-TextContains -Text $siteReviewDbScript -Needle "export-summary" -Message "site_review_db.py must expose a public summary export command."
  Assert-TextContains -Text $siteReviewDbScript -Needle "sanitized aggregate from local SQLite site-review store" -Message "site_review_db.py must label exported summaries as SQLite-backed sanitized aggregates."
  Assert-TextContains -Text $fieldMicroscopySchemaModule -Needle "FIELD_MICROSCOPY_INTAKE_SCHEMA_VERSION" -Message "field_microscopy.py must define the intake schema version."
  Assert-TextContains -Text $fieldMicroscopySchemaModule -Needle "def validate_record" -Message "field_microscopy.py must expose record validation."
  Assert-TextContains -Text $fieldMicroscopySchemaModule -Needle "def build_public_export" -Message "field_microscopy.py must expose public export construction."
  Assert-TextContains -Text $fieldMicroscopySchemaModule -Needle "def validate_database_review_state" -Message "field_microscopy.py must expose database review-state validation."
  Assert-TextContains -Text $schemaPackagePyproject -Needle 'name = "environmental-monitoring-schemas"' -Message "shared package pyproject.toml must define the reusable schema package name."
  Assert-TextContains -Text $schemaPackageReadme -Needle "Reusable local schemas" -Message "shared package README must explain its reusable schema purpose."
  Assert-TextContains -Text $gitDiscoveryScript -Needle "GitHubDesktop" -Message "find-local-git.ps1 must check GitHub Desktop's bundled Git."
  Assert-TextContains -Text $gitDiscoveryScript -Needle "Do not run git init automatically" -Message "find-local-git.ps1 must keep repository initialization as an explicit decision."
  Assert-TextContains -Text $gitignore -Needle "data/site-review-decisions*.json" -Message ".gitignore must ignore private site-review decision files."
  Assert-TextContains -Text $gitignore -Needle "!data/site-review-decisions.example.json" -Message ".gitignore must preserve the public site-review decision example."
  Assert-TextContains -Text $gitignore -Needle "data/private/" -Message ".gitignore must ignore private field/microscopy workspace files."
  Assert-TextContains -Text $gitignore -Needle "*.local.sqlite" -Message ".gitignore must ignore local SQLite stores."
  Assert-TextContains -Text $styles -Needle "map-filter-panel" -Message "styles.css must style the map trust filter."

  $nodeExecutable = Get-NodeExecutable
  if ($nodeExecutable) {
    & $nodeExecutable --check (Resolve-ProjectPath "app.js") | Out-Null
    if ($LASTEXITCODE -ne 0) {
      Add-Failure "app.js failed JavaScript syntax validation."
    }

    & $nodeExecutable --check (Resolve-ProjectPath "sw.js") | Out-Null
    if ($LASTEXITCODE -ne 0) {
      Add-Failure "sw.js failed JavaScript syntax validation."
    }
  } else {
    Add-Warning "Node.js was not found; skipped app.js and sw.js syntax validation."
  }

  if (-not $SkipHttp) {
    $listener = Get-NetTCPConnection -LocalPort $Port -State Listen -ErrorAction SilentlyContinue |
      Select-Object -First 1

    if ($listener) {
      @(
        "",
        "project.html",
        "methodology.html",
        "styles.css",
        "app.js",
        "assets/clear-lake-watch.ico",
        "data/sources.json",
        "data/sites.json",
        "data/live.json",
        "data/analytics.json",
        "data/manifest.json",
        "data/forecast-output.example.json",
        "data/weather-context.json",
        "data/weather-context.example.json",
        "data/reports.json",
        "data/observations.json",
        "data/sites-normalized.json",
        "data/site-review.json",
        "data/lake-shoreline.json"
      ) | ForEach-Object { Assert-HttpOk $_ }
    } else {
      Add-Warning "No local server is listening on port $Port; skipped HTTP endpoint checks."
    }
  }
} finally {
  Pop-Location
}

if ($warnings.Count -gt 0) {
  Write-Output "Warnings:"
  foreach ($warning in $warnings) {
    Write-Output "  - $warning"
  }
}

if ($failures.Count -gt 0) {
  Write-Output "Validation failed:"
  foreach ($failure in $failures) {
    Write-Output "  - $failure"
  }
  exit 1
}

Write-Output "Validation passed for Clear Lake Watch."
