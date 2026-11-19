param(
  [switch]$CheckHttp,
  [string]$AsOfUtc
)

$ErrorActionPreference = "Stop"

# An explicit -AsOfUtc (a UTC instant ending in Z or +00:00) freezes the
# evaluation clock; otherwise the shared evaluator samples the UTC clock once.
$hasAsOfUtc = $PSBoundParameters.ContainsKey("AsOfUtc")

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

function Resolve-NativeProjectPath {
  param([string]$Path)

  $separator = [System.IO.Path]::DirectorySeparatorChar
  $rootPath = [System.IO.Path]::GetFullPath($projectRoot).TrimEnd(
    $separator, [System.IO.Path]::AltDirectorySeparatorChar
  )
  $fullPath = [System.IO.Path]::GetFullPath($Path)
  $comparison = if ($separator -eq '\') {
    [System.StringComparison]::OrdinalIgnoreCase
  } else {
    [System.StringComparison]::Ordinal
  }
  $prefix = "$rootPath$separator"
  if ($fullPath.Equals($rootPath, $comparison)) {
    return $fullPath
  }
  if (-not $fullPath.StartsWith($prefix, $comparison)) {
    throw "Unsafe native path $Path resolves outside the checkout."
  }

  # Inspect each component before walking into it. In Windows PowerShell 5.1
  # GetFullPath normalizes the spelling but does not dereference junctions.
  $current = $prefix
  foreach ($part in ($fullPath.Substring($prefix.Length) -split '[\\/]+')) {
    $current = Join-Path $current $part
    try {
      $item = Get-Item -LiteralPath $current -Force -ErrorAction Stop
    } catch [System.Management.Automation.ItemNotFoundException] {
      break
    }
    if ($item.Attributes -band [System.IO.FileAttributes]::ReparsePoint) {
      throw "Unsafe native path $Path uses a link or reparse point inside the checkout."
    }
  }
  return $fullPath
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
    $path = Resolve-NativeProjectPath (Resolve-ProjectPath $RelativePath)
  } catch {
    Add-Failure ("Unable to resolve {0}: {1}" -f $RelativePath, $_.Exception.Message)
    return $null
  }
  try {
    $content = Get-Content -LiteralPath $path -Raw -Encoding UTF8
    # Windows PowerShell can unwrap an array when emitting its parsed value.
    # Check the top-level token before conversion so arrays fail even with one object.
    if ($content -notmatch '^\s*\{') {
      Add-Failure "$RelativePath must contain a JSON object."
      return $null
    }
    return ConvertFrom-Json -InputObject $content
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

function ConvertTo-ProcessArgument {
  param([string]$Value)

  if ($Value.Length -gt 0 -and $Value -notmatch '[\s"]') {
    return $Value
  }

  # Windows command-line quoting, which .NET also applies on other platforms.
  $quoted = $Value -replace '(\\*)"', '$1$1\"'
  $quoted = $quoted -replace '(\\+)$', '$1$1'
  return '"' + $quoted + '"'
}

function Get-SharedEvaluatorPython {
  foreach ($name in @("python", "python3")) {
    $command = @(Get-Command $name -CommandType Application -ErrorAction SilentlyContinue) | Select-Object -First 1
    if ($null -ne $command) {
      return $command.Path
    }
  }
  return $null
}

function Get-SharedReportProblem {
  param(
    [string]$Stdout,
    [object]$Report,
    [int]$ExitCode
  )

  if ([string]::IsNullOrWhiteSpace($Stdout) -or -not $Stdout.TrimStart().StartsWith("{")) {
    return "stdout is not one JSON object"
  }

  if ($null -eq $Report -or $Report -isnot [System.Management.Automation.PSCustomObject]) {
    return "stdout is not one JSON object"
  }

  $propertyNames = @($Report.PSObject.Properties | ForEach-Object { $_.Name })
  if ($propertyNames -cnotcontains "schema_version" -or $propertyNames -cnotcontains "findings") {
    return "schema_version and findings are required"
  }

  $schemaVersion = $Report.schema_version
  if (-not ($schemaVersion -is [int] -or $schemaVersion -is [long]) -or $schemaVersion -ne 1) {
    return "unsupported schema_version $schemaVersion"
  }

  $findings = $Report.findings
  if ($null -eq $findings -or $findings -isnot [System.Array]) {
    return "findings must be an array"
  }

  $failureCount = 0
  foreach ($finding in $findings) {
    if ($finding -isnot [System.Management.Automation.PSCustomObject]) {
      return "each finding must be an object"
    }

    foreach ($field in @("severity", "code", "subject", "message")) {
      $value = $finding.$field
      if ($value -isnot [string] -or [string]::IsNullOrWhiteSpace($value)) {
        return "finding field $field must be a non-empty string"
      }
    }

    if ($finding.severity -ceq "failure") {
      $failureCount++
    } elseif ($finding.severity -cne "warning") {
      return "unknown severity $($finding.severity)"
    }
  }

  if ($ExitCode -eq 0 -and $failureCount -gt 0) {
    return "exit code 0 with $failureCount failure finding(s)"
  }

  if ($ExitCode -eq 1 -and $failureCount -eq 0) {
    return "exit code 1 without a failure finding"
  }

  return $null
}

function Invoke-SharedSnapshotEvaluator {
  param(
    [bool]$HasAsOfUtc,
    [string]$AsOfUtc
  )

  # The shared evaluator also applies PowerShell's required-text rules.
  # Launch, protocol, and dependency failures fail this gate.
  $evaluatorPath = Join-Path $PSScriptRoot "public_mirror_common.py"
  if (-not (Test-Path -LiteralPath $evaluatorPath -PathType Leaf)) {
    Add-Failure "Shared snapshot evaluator is unavailable: scripts/public_mirror_common.py is missing."
    return
  }

  $python = Get-SharedEvaluatorPython
  if ($null -eq $python) {
    Add-Failure "Shared snapshot evaluator could not start: no python executable was found on PATH. Install Python 3.11 or newer, then run: python -m pip install -r requirements-public-mirror.txt"
    return
  }

  $arguments = @("-B", $evaluatorPath, "--powershell-text-guards")
  if ($HasAsOfUtc) {
    $arguments += @("--as-of", $AsOfUtc)
  }

  $startInfo = New-Object System.Diagnostics.ProcessStartInfo
  $startInfo.FileName = $python
  $startInfo.Arguments = (@($arguments | ForEach-Object { ConvertTo-ProcessArgument $_ }) -join " ")
  $startInfo.WorkingDirectory = $projectRoot
  $startInfo.UseShellExecute = $false
  $startInfo.CreateNoWindow = $true
  $startInfo.RedirectStandardOutput = $true
  $startInfo.RedirectStandardError = $true
  $utf8 = New-Object System.Text.UTF8Encoding $false
  $startInfo.StandardOutputEncoding = $utf8
  $startInfo.StandardErrorEncoding = $utf8
  $startInfo.EnvironmentVariables["PYTHONIOENCODING"] = "utf-8"

  $process = New-Object System.Diagnostics.Process
  $process.StartInfo = $startInfo
  try {
    [void]$process.Start()
  } catch {
    Add-Failure "Shared snapshot evaluator could not start with $($python): $($_.Exception.Message)"
    $process.Dispose()
    return
  }

  try {
    $stdoutTask = $process.StandardOutput.ReadToEndAsync()
    $stderrTask = $process.StandardError.ReadToEndAsync()
    if (-not $process.WaitForExit(120000)) {
      try { $process.Kill() } catch { }
      Add-Failure "Shared snapshot evaluator did not finish within 120 seconds."
      return
    }
    $process.WaitForExit()
    $stdout = $stdoutTask.Result
    $stderr = $stderrTask.Result
    $exitCode = $process.ExitCode
  } catch {
    Add-Failure "Shared snapshot evaluator output could not be read: $($_.Exception.Message)"
    return
  } finally {
    $process.Dispose()
  }

  $stderrText = ""
  if (-not [string]::IsNullOrWhiteSpace($stderr)) {
    $stderrText = $stderr.Trim() -replace '\s+', ' '
  }
  $diagnostics = "exit code $exitCode"
  if ($stderrText) {
    $diagnostics = "$diagnostics; stderr: $stderrText"
  }

  if ($exitCode -ne 0 -and $exitCode -ne 1) {
    Add-Failure "Shared snapshot evaluator failed ($diagnostics)."
    return
  }

  $report = $null
  try {
    if (-not [string]::IsNullOrWhiteSpace($stdout)) {
      $report = $stdout | ConvertFrom-Json
    }
  } catch {
    $report = $null
  }

  $problem = Get-SharedReportProblem -Stdout $stdout -Report $report -ExitCode $exitCode
  if ($problem) {
    Add-Failure "Shared snapshot evaluator returned an invalid report: $problem ($diagnostics)."
    return
  }

  if ($stderrText) {
    Add-Warning "Shared snapshot evaluator wrote to stderr: $stderrText"
  }

  foreach ($finding in @($report.findings)) {
    $line = if ($finding.code -ceq "required_text_missing") {
      $finding.message
    } else {
      "[$($finding.code)] $($finding.subject): $($finding.message)"
    }
    if ($finding.severity -ceq "failure") {
      Add-Failure $line
    } else {
      Add-Warning $line
    }
  }
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

  $records = $ReviewedFieldObservations.records
  if ($records -isnot [System.Array]) {
    Add-Failure "Reviewed field observations must expose a records list."
    return
  }

  for ($index = 0; $index -lt $records.Count; $index++) {
    $record = $records[$index]
    if ($record -isnot [pscustomobject]) {
      Add-Failure "Reviewed field observation records[$index] must be a JSON object."
      continue
    }
    if ($record.qaStatus -isnot [string] -or $record.qaStatus -cne "approved-public") {
      Add-Failure "Reviewed public field observation $($record.recordId) is not approved-public."
    }
    if ($record.permissionToPublish -isnot [bool] -or -not $record.permissionToPublish) {
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

  $nativeJson = @{}
  foreach ($jsonFile in $jsonFiles) {
    $nativeJson[$jsonFile] = Read-JsonFile $jsonFile
  }

  $manifest = $nativeJson["data\manifest.json"]
  if ($manifest -and $manifest.interpretationNotes) {
    $joinedNotes = ($manifest.interpretationNotes -join " ")
    Assert-TextContains -Text $joinedNotes -Needle "not official public-health guidance" -Message "Manifest must preserve public-health boundary."
  }
  if ($manifest -and $manifest.notes) {
    $joinedNotes = ($manifest.notes -join " ")
    Assert-TextContains -Text $joinedNotes -Needle "not official public-health guidance" -Message "Manifest must preserve public-health boundary."
  }

  Invoke-SharedSnapshotEvaluator -HasAsOfUtc $hasAsOfUtc -AsOfUtc $AsOfUtc

  if ($manifest) {
    $manifestNotesText = (@($manifest.notes) -join " ")
    Assert-TextContains -Text $manifestNotesText -Needle "Observation dates may be older than the dashboard generation time" -Message "Manifest must preserve dashboard-refresh versus source-observation distinction."
  }

  $weatherContext = $nativeJson["data\weather-context.json"]
  Test-WeatherContext -WeatherContext $weatherContext

  $reviewedFieldObservations = $nativeJson["data\reviewed-field-observations.json"]
  Test-ReviewedFieldObservations -ReviewedFieldObservations $reviewedFieldObservations

  $siteReviewSummary = $nativeJson["data\site-review-summary.json"]
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

  # Run a small dashboard-utils smoke test without relying on the Node test runner.
  Write-Host "Running dashboard utils smoke test..."
  try {
    $nodeTestResult = Start-Process node -ArgumentList (Resolve-ProjectPath "scripts\dashboard-utils.smoke.mjs") -Wait -NoNewWindow -PassThru
    if ($nodeTestResult.ExitCode -ne 0) {
      Add-Failure "Dashboard utils smoke test failed with exit code $($nodeTestResult.ExitCode)."
    }
  } catch {
    Add-Failure "Failed to run dashboard utils smoke test: $_"
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
