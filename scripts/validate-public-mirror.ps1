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
    "docs\clear_lake_watch_portfolio_case_study.md",
    "docs\deployment.md",
    "docs\field-microscopy-intake-contract.md",
    "docs\flagship-maturity-plan.md",
    "docs\forecast-boundary.md",
    "docs\local-first-operating-model.md",
    "docs\public-mirror-boundary.md",
    "docs\publication-review-checklist.md",
    "docs\published-commentary.md",
    "docs\research-readiness-brief.md",
    "docs\resume-linkedin-snippets.md",
    "docs\source-audit.md",
    "docs\weather-context-contract.md",
    "scripts\refresh-live-data.ps1",
    "scripts\refresh-osm-shoreline.ps1",
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
  Assert-TextContains -Text $readme -Needle "not part of this public mirror branch" -Message "README must explain that private review materials are excluded."
  Assert-TextContains -Text $methodology -Needle "not official public-health direction" -Message "Methodology page must preserve public-health boundary."
  Assert-TextContains -Text $index -Needle "not background emergency alerts or official public-health notifications" -Message "Dashboard must preserve alert boundary."
  Assert-TextContains -Text $project -Needle "docs/forecast-boundary.md" -Message "Project page must link forecast boundary."
  Assert-TextContains -Text $app -Needle "site-review-summary.json" -Message "App must consume public site-review summary."

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
