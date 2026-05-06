param(
  [string]$WorkingInputPath = "data/private/field-microscopy-review-cycle.local.json",
  [string]$WorkingOutputPath = "data/private/reviewed-field-observations-cycle.local.json"
)

$ErrorActionPreference = "Stop"

$projectRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot ".."))
$examplePath = Join-Path $projectRoot "data/field-microscopy-intake.example.json"
$resolvedInputPath = Join-Path $projectRoot $WorkingInputPath
$resolvedOutputPath = Join-Path $projectRoot $WorkingOutputPath
$inputDirectory = Split-Path -Parent $resolvedInputPath
$outputDirectory = Split-Path -Parent $resolvedOutputPath

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

if (-not (Test-Path $examplePath)) {
  throw "Missing intake example: data/field-microscopy-intake.example.json"
}

if (-not (Test-Path $inputDirectory)) {
  New-Item -ItemType Directory -Path $inputDirectory | Out-Null
}

if (-not (Test-Path $outputDirectory)) {
  New-Item -ItemType Directory -Path $outputDirectory | Out-Null
}

try {
  $sample = Get-Content $examplePath -Raw | ConvertFrom-Json
  $sample.status = "private-local"

  $record = @($sample.records)[0]
  $record.recordId = "field-micro-cycle-approved-001"
  $record.sampleDateTime = "2026-05-05T09:00:00-07:00"
  $record.siteId = "example-public-site"
  $record.siteName = "Example public-safe site"
  $record.lakeArm = "Lower Arm"
  $record.qaStatus = "approved-public"
  $record.qaReviewedAt = "2026-05-05T10:00:00-07:00"
  $record.permissionToPublish = $true
  $record.publicLocationPrecision = "site generalized"
  $record.publicSummary = "Synthetic review-cycle record for exporter smoke testing."

  $sample |
    ConvertTo-Json -Depth 20 |
    Set-Content -Path $resolvedInputPath -Encoding UTF8

  & (Join-Path $PSScriptRoot "validate-field-microscopy-intake.ps1") -InputPath $WorkingInputPath | Out-Null
  & (Join-Path $PSScriptRoot "export-reviewed-field-observations.ps1") -InputPath $WorkingInputPath -OutputPath $WorkingOutputPath | Out-Null

  $export = Get-Content $resolvedOutputPath -Raw | ConvertFrom-Json
  $records = @($export.records)

  if ($records.Count -ne 1) {
    throw "Expected one reviewed public record, found $($records.Count)."
  }

  foreach ($field in $forbiddenPublicFields) {
    if ($records[0].PSObject.Properties.Name -contains $field) {
      throw "Public export leaked private field '$field'."
    }
  }

  if ($records[0].sourceFamily -ne "field-microscopy") {
    throw "Public export did not preserve sourceFamily field-microscopy."
  }

  if ($records[0].publicQaStatus -ne "approved-public") {
    throw "Public export did not preserve approved-public QA status."
  }

  Write-Output "Field/microscopy review-cycle check passed."
  Write-Output "Synthetic approved records exported: $($records.Count)"
  Write-Output "Private fields checked for exclusion: $($forbiddenPublicFields.Count)"
} finally {
  if (Test-Path $resolvedInputPath) {
    Remove-Item -LiteralPath $resolvedInputPath -Force
  }

  if (Test-Path $resolvedOutputPath) {
    Remove-Item -LiteralPath $resolvedOutputPath -Force
  }
}
