param(
  [int]$Port = 4173,
  [switch]$SkipHttp
)

$ErrorActionPreference = "Stop"

$projectRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot ".."))
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
    "README.md",
    "assets\clear-lake-watch.ico",
    "data\sources.json",
    "data\sites.json",
    "data\live.json",
    "data\reports.json",
    "data\observations.json",
    "data\sites-normalized.json",
    "data\site-review.json",
    "data\site-review-decisions.example.json",
    "data\analytics.json",
    "data\manifest.json",
    "data\lake-shoreline.json",
    "data\forecast-output.example.json",
    "data\weather-context.json",
    "data\weather-context.example.json",
    "docs\backlog.md",
    "docs\forecast-boundary.md",
    "docs\local-git-workflow.md",
    "docs\site-registry-decision-workflow.md",
    "docs\site-registry-review.md",
    "docs\site-registry-high-priority.md",
    "docs\source-audit.md",
    "docs\conversation-log.md",
    "docs\weather-context-contract.md",
    "scripts\refresh-live-data.ps1",
    "scripts\refresh-osm-shoreline.ps1",
    "scripts\build-site-review-report.ps1",
    "scripts\new-site-review-decisions.ps1",
    "scripts\preview-site-review-decisions.ps1",
    "scripts\launch-dashboard.ps1",
    "scripts\create-windows-shortcut.ps1",
    "scripts\find-local-git.ps1"
  )

  foreach ($file in $requiredFiles) {
    Assert-FileExists $file
  }

  @(
    "server.pid",
    "server.out.log",
    "server.err.log"
  ) | ForEach-Object {
    Assert-FileAbsent $_ "Runtime file should not be in the static web root: $_"
  }

  $sources = Read-JsonFile "data\sources.json"
  $sites = Read-JsonFile "data\sites.json"
  $live = Read-JsonFile "data\live.json"
  $reports = Read-JsonFile "data\reports.json"
  $observations = Read-JsonFile "data\observations.json"
  $sitesNormalized = Read-JsonFile "data\sites-normalized.json"
  $siteReview = Read-JsonFile "data\site-review.json"
  $siteReviewDecisionsExample = Read-JsonFile "data\site-review-decisions.example.json"
  $analytics = Read-JsonFile "data\analytics.json"
  $manifest = Read-JsonFile "data\manifest.json"
  $shoreline = Read-JsonFile "data\lake-shoreline.json"
  $forecastOutputExample = Read-JsonFile "data\forecast-output.example.json"
  $weatherContext = Read-JsonFile "data\weather-context.json"
  $weatherContextExample = Read-JsonFile "data\weather-context.example.json"

  if ($sources) {
    Assert-NonEmptyCollection $sources.sources "sources.json must include at least one source."
    Assert-NonEmptyCollection $sources.arms "sources.json must include lake arms."
    Assert-NonEmptyCollection $sources.modules "sources.json must include dashboard modules."
    Assert-NonEmptyCollection $sources.guardrails "sources.json must include guardrails."
  }

  if ($sites) {
    Assert-NonEmptyCollection $sites.sites "sites.json must include at least one site."
    $hendersonPointSite = @($sites.sites | Where-Object { $_.siteId -eq "fhabs-henderson-point" }) | Select-Object -First 1
    Assert-True -Condition ($null -ne $hendersonPointSite) -Message "sites.json must include the unresolved Henderson Point / Riviera Point candidate site."
    if ($hendersonPointSite) {
      Assert-True -Condition ($hendersonPointSite.assignmentStatus -eq "needs-local-review") -Message "Henderson Point / Riviera Point must remain needs-local-review until locally certified."
      Assert-True -Condition (@($hendersonPointSite.aliases) -contains "Riveria Point Launch at Henderson Point in Soda Bay") -Message "Henderson Point / Riviera Point must preserve the FHABS source spelling as an alias."
      Assert-True -Condition (@($hendersonPointSite.aliases) -contains "Riviera Point Launch at Henderson Point in Soda Bay") -Message "Henderson Point / Riviera Point must include the likely corrected Riviera spelling as an alias."
    }
  }

  if ($live) {
    Assert-True -Condition (-not [string]::IsNullOrWhiteSpace($live.generatedAt)) -Message "live.json must include generatedAt."
    Assert-NonEmptyCollection $live.liveCards "live.json must include liveCards."
    Assert-NonEmptyCollection $live.hydrologySeries "live.json must include hydrologySeries."
    Assert-NonEmptyCollection $live.mapMarkers "live.json must include mapMarkers."
    Assert-True -Condition ($null -ne $live.analytics) -Message "live.json must include embedded analytics."
    $lakeLevelCard = @($live.liveCards | Where-Object { $_.label -eq "Lake level at Lakeport" }) | Select-Object -First 1
    Assert-True -Condition ($null -ne $lakeLevelCard) -Message "live.json must include the Lakeport lake-level card."
    if ($lakeLevelCard) {
      Assert-True -Condition ($lakeLevelCard.value -match "ft Rumsey") -Message "Lakeport lake-level card must label the value as feet Rumsey."
      Assert-True -Condition ($lakeLevelCard.note -match "Zero Rumsey = 1318\.256 ft") -Message "Lakeport lake-level card must include the Zero Rumsey elevation context."
      Assert-True -Condition ($lakeLevelCard.note -match "water-surface elevation") -Message "Lakeport lake-level card must include the approximate water-surface elevation."
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
  $sourceAudit = Get-Content (Resolve-ProjectPath "docs\source-audit.md") -Raw
  $forecastBoundaryDoc = Get-Content (Resolve-ProjectPath "docs\forecast-boundary.md") -Raw
  $siteReviewDecisionWorkflowDoc = Get-Content (Resolve-ProjectPath "docs\site-registry-decision-workflow.md") -Raw
  $siteReviewDoc = Get-Content (Resolve-ProjectPath "docs\site-registry-review.md") -Raw
  $highPrioritySiteReviewDoc = Get-Content (Resolve-ProjectPath "docs\site-registry-high-priority.md") -Raw
  $refreshScript = Get-Content (Resolve-ProjectPath "scripts\refresh-live-data.ps1") -Raw
  $decisionPreviewScript = Get-Content (Resolve-ProjectPath "scripts\preview-site-review-decisions.ps1") -Raw
  $gitDiscoveryScript = Get-Content (Resolve-ProjectPath "scripts\find-local-git.ps1") -Raw
  $launchScript = Get-Content (Resolve-ProjectPath "scripts\launch-dashboard.ps1") -Raw
  $gitignore = Get-Content (Resolve-ProjectPath ".gitignore") -Raw
  Assert-True -Condition ($index.Contains('rel="icon"')) -Message "index.html must include the favicon link."
  Assert-True -Condition ($project.Contains('rel="icon"')) -Message "project.html must include the favicon link."
  Assert-True -Condition ($methodology.Contains('rel="icon"')) -Message "methodology.html must include the favicon link."
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
  Assert-True -Condition ($app.Contains("High-priority checks")) -Message "app.js must surface high-priority site-review checks."
  Assert-True -Condition ($app.Contains("filterMapMarkers")) -Message "app.js must include confidence-aware map filtering."
  Assert-True -Condition ($app.Contains("setupMapReviewFilter")) -Message "app.js must wire the map trust filter."
  Assert-True -Condition ($app.Contains("sourceOutputGridElement")) -Message "app.js must render generated output manifest data."
  Assert-True -Condition ($app.Contains("manifestNotesElement")) -Message "app.js must render manifest notes."
  Assert-True -Condition ($app.Contains("renderWeatherContext")) -Message "app.js must render optional weather-context data."
  Assert-True -Condition ($app.Contains("weather-context.json")) -Message "app.js must attempt to load the optional weather-context export."
  Assert-True -Condition ($refreshScript.Contains("Get-FhabsPackage")) -Message "refresh-live-data.ps1 must resolve FHABS package metadata dynamically."
  Assert-True -Condition ($refreshScript.Contains("manifestOutputPath")) -Message "refresh-live-data.ps1 must write a source manifest."
  Assert-True -Condition ($refreshScript.Contains("Assert-FhabsResourceFreshness")) -Message "refresh-live-data.ps1 must freshness-check FHABS resource filenames."
  Assert-True -Condition (-not ($refreshScript -match 'download/(?:bloom-report|hab-results)_\d{4}-\d{2}-\d{2}\.csv')) -Message "refresh-live-data.ps1 must not pin FHABS downloads to dated CSV URLs."
  Assert-True -Condition ($launchScript.Contains("LOCALAPPDATA") -and $launchScript.Contains("runtime")) -Message "launch-dashboard.ps1 must keep runtime files outside the static web root."
  Assert-True -Condition (-not ($launchScript -match 'Join-Path\s+\$projectRoot\s+"server\.(?:pid|out\.log|err\.log)"')) -Message "launch-dashboard.ps1 must not write server runtime files into the project root."
  Assert-TextContains -Text $backlog -Needle "P0-04 Split Public Dashboard From Project Roadmap Content" -Message "docs/backlog.md must track the dashboard/project split."
  Assert-TextContains -Text $backlog -Needle "Status: Done" -Message "docs/backlog.md must mark completed trust-hardening items as done."
  Assert-TextContains -Text $backlog -Needle "live export pending" -Message "docs/backlog.md must keep the live weather-context export boundary visible."
  Assert-TextContains -Text $conversationLog -Needle "April 22, 2026 Trust-Hardening Update" -Message "docs/conversation-log.md must include the latest trust-hardening update."
  Assert-TextContains -Text $conversationLog -Needle "Git was not available" -Message "docs/conversation-log.md must preserve the local Git availability caveat."
  Assert-TextContains -Text $conversationLog -Needle "Local Git Availability Check" -Message "docs/conversation-log.md must preserve the local Git availability check."
  Assert-TextContains -Text $conversationLog -Needle "Forecast Boundary Contract" -Message "docs/conversation-log.md must preserve the forecast boundary update."
  Assert-TextContains -Text $sourceAudit -Needle "Shared Backbone Weather Context Export" -Message "docs/source-audit.md must document the weather context export as a context source."
  Assert-TextContains -Text $sourceAudit -Needle "resolves FHABS resources dynamically" -Message "docs/source-audit.md must document dynamic FHABS resource resolution."
  Assert-TextContains -Text $forecastBoundaryDoc -Needle "Experimental forecast only. Not official public-health guidance." -Message "docs/forecast-boundary.md must include the required forecast disclaimer."
  Assert-TextContains -Text $forecastBoundaryDoc -Needle "trainingWindow" -Message "docs/forecast-boundary.md must require a training window."
  Assert-TextContains -Text $forecastBoundaryDoc -Needle "uncertainty" -Message "docs/forecast-boundary.md must require uncertainty language."
  Assert-TextContains -Text $siteReviewDecisionWorkflowDoc -Needle "Review decisions should be recorded before registry edits are made." -Message "docs/site-registry-decision-workflow.md must preserve review-before-write guidance."
  Assert-TextContains -Text $siteReviewDecisionWorkflowDoc -Needle "preview-site-review-decisions.ps1" -Message "docs/site-registry-decision-workflow.md must document the preview command."
  Assert-TextContains -Text $siteReviewDecisionWorkflowDoc -Needle "promote-reviewed-local" -Message "docs/site-registry-decision-workflow.md must document reviewed-local promotion rules."
  Assert-TextContains -Text $siteReviewDoc -Needle "Evidence note" -Message "docs/site-registry-review.md must include evidence notes."
  Assert-TextContains -Text $highPrioritySiteReviewDoc -Needle "High-Priority Site Registry Review" -Message "docs/site-registry-high-priority.md must include the high-priority review packet."
  Assert-TextContains -Text $highPrioritySiteReviewDoc -Needle "Review Decision Rules" -Message "docs/site-registry-high-priority.md must include review decision rules."
  Assert-TextContains -Text $highPrioritySiteReviewDoc -Needle "Decision:" -Message "docs/site-registry-high-priority.md must include a decision checklist."
  Assert-TextContains -Text $highPrioritySiteReviewDoc -Needle "Jones bay" -Message "docs/site-registry-high-priority.md must include the current Jones bay review item."
  Assert-TextContains -Text $highPrioritySiteReviewDoc -Needle "openstreetmap.org" -Message "docs/site-registry-high-priority.md must include map links for review."
  Assert-TextContains -Text $decisionPreviewScript -Needle "No files were modified" -Message "preview-site-review-decisions.ps1 must make its dry-run behavior explicit."
  Assert-TextContains -Text $decisionPreviewScript -Needle "permissionToPublish" -Message "preview-site-review-decisions.ps1 must validate publication permission boundaries."
  Assert-TextContains -Text $gitDiscoveryScript -Needle "GitHubDesktop" -Message "find-local-git.ps1 must check GitHub Desktop's bundled Git."
  Assert-TextContains -Text $gitDiscoveryScript -Needle "Do not run git init automatically" -Message "find-local-git.ps1 must keep repository initialization as an explicit decision."
  Assert-TextContains -Text $gitignore -Needle "data/site-review-decisions*.json" -Message ".gitignore must ignore private site-review decision files."
  Assert-TextContains -Text $gitignore -Needle "!data/site-review-decisions.example.json" -Message ".gitignore must preserve the public site-review decision example."
  Assert-TextContains -Text $styles -Needle "map-filter-panel" -Message "styles.css must style the map trust filter."

  $nodeExecutable = Get-NodeExecutable
  if ($nodeExecutable) {
    & $nodeExecutable --check (Resolve-ProjectPath "app.js") | Out-Null
    if ($LASTEXITCODE -ne 0) {
      Add-Failure "app.js failed JavaScript syntax validation."
    }
  } else {
    Add-Warning "Node.js was not found; skipped app.js syntax validation."
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
