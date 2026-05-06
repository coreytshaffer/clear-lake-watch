param(
  [string]$InputPath = "data/private/field-microscopy-intake.local.json",
  [string]$OutputPath = "data/reviewed-field-observations.json"
)

$ErrorActionPreference = "Stop"

$projectRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot ".."))
$resolvedInputPath = Join-Path $projectRoot $InputPath
$resolvedOutputPath = Join-Path $projectRoot $OutputPath

function Convert-ToPublicRecord {
  param([object]$Record)

  [ordered]@{
    recordId = $Record.recordId
    sourceFamily = "field-microscopy"
    publicSiteId = $Record.siteId
    publicSiteName = $Record.siteName
    publicLakeArm = $Record.lakeArm
    sampleDateTime = $Record.sampleDateTime
    observationType = $Record.sampleType
    taxonName = $Record.taxonName
    identificationConfidence = $Record.identificationConfidence
    abundanceEstimate = $Record.abundanceEstimate
    publicQaStatus = $Record.qaStatus
    publicLocationPrecision = $Record.publicLocationPrecision
    publicSummary = $Record.publicSummary
  }
}

if (-not (Test-Path $resolvedInputPath)) {
  throw "Missing private intake file: $InputPath. Run scripts/new-field-microscopy-intake.ps1 first."
}

$inputData = Get-Content $resolvedInputPath -Raw | ConvertFrom-Json
$approvedRecords = @(
  $inputData.records |
    Where-Object {
      $_.qaStatus -eq "approved-public" -and $_.permissionToPublish -eq $true
    } |
    ForEach-Object { Convert-ToPublicRecord -Record $_ }
)

$status = "not-connected"
if ($approvedRecords.Count -gt 0) {
  $status = "reviewed-export"
}

$export = [ordered]@{
  schemaVersion = "reviewed-field-observations-v0"
  generatedAt = ([datetimeoffset]::Now.ToString("o"))
  sourceFamily = "field-microscopy"
  status = $status
  records = $approvedRecords
  qualityNotes = @(
    "This export includes only records with qaStatus approved-public and permissionToPublish true.",
    "Private collector identity details, custody notes, QA notes, raw photo paths, and unpublished exact coordinates are excluded.",
    "Field and microscopy records remain a separate source family from FHABS, USGS, CLAMP/CEDEN, Tribal monitoring, and forecast labels."
  )
}

$export |
  ConvertTo-Json -Depth 20 |
  Set-Content -Path $resolvedOutputPath -Encoding UTF8

Write-Output "Wrote reviewed field/microscopy public export: $OutputPath"
Write-Output "Exported records: $($approvedRecords.Count)"
