param(
  [string]$InputPath = "data/private/field-microscopy-intake.local.json"
)

$ErrorActionPreference = "Stop"

$projectRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot ".."))
$resolvedInputPath = Join-Path $projectRoot $InputPath
$failures = [System.Collections.Generic.List[string]]::new()
$warnings = [System.Collections.Generic.List[string]]::new()

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
  "createdAt",
  "updatedAt",
  "createdBy",
  "sampleDateTime",
  "collectorName",
  "collectorOrganization",
  "collectionProgram",
  "custodyId",
  "custodyNotes",
  "siteId",
  "siteName",
  "latitude",
  "longitude",
  "gpsPrecisionMeters",
  "coordinateSource",
  "lakeArm",
  "locationPrivacyClass",
  "sampleType",
  "collectionMethod",
  "preservationMethod",
  "fieldNotes",
  "microscopeMethod",
  "magnification",
  "preparationMethod",
  "taxonName",
  "taxonRank",
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

function Add-Failure {
  param([string]$Message)
  $failures.Add($Message)
}

function Add-Warning {
  param([string]$Message)
  $warnings.Add($Message)
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

function Test-DateLikeValue {
  param([object]$Value)

  if ($null -eq $Value) {
    return $true
  }

  $text = [string]$Value
  if ([string]::IsNullOrWhiteSpace($text)) {
    return $true
  }

  if ($text.Contains("YYYY-MM-DD")) {
    return $true
  }

  try {
    [datetimeoffset]::Parse(
      $text,
      [System.Globalization.CultureInfo]::InvariantCulture
    ) | Out-Null
    return $true
  } catch {
    return $false
  }
}

if (-not (Test-Path $resolvedInputPath)) {
  throw "Missing private intake file: $InputPath. Run scripts/new-field-microscopy-intake.ps1 first."
}

try {
  $data = Get-Content $resolvedInputPath -Raw | ConvertFrom-Json
} catch {
  throw "Invalid JSON in $InputPath`: $($_.Exception.Message)"
}

Assert-True -Condition ($data.schemaVersion -eq "field-microscopy-intake-v0") -Message "Private intake must use schemaVersion field-microscopy-intake-v0."
Assert-True -Condition ($data.status -eq "private-local") -Message "Private intake status should be private-local."
Assert-True -Condition (@($data.records).Count -gt 0) -Message "Private intake must include at least one record."

foreach ($status in $allowedReviewStatuses) {
  Assert-True -Condition (@($data.allowedReviewStatuses) -contains $status) -Message "Private intake must include allowed status '$status'."
}

$approvedPublicCount = 0
$publishableCount = 0

foreach ($record in @($data.records)) {
  foreach ($field in $requiredRecordFields) {
    Assert-True -Condition ($record.PSObject.Properties.Name -contains $field) -Message "Record '$($record.recordId)' is missing required field '$field'."
  }

  Assert-True -Condition ($record.recordType -eq "field-microscopy") -Message "Record '$($record.recordId)' must use recordType field-microscopy."
  Assert-True -Condition ($allowedReviewStatuses -contains $record.qaStatus) -Message "Record '$($record.recordId)' has unsupported qaStatus '$($record.qaStatus)'."
  Assert-True -Condition (($record.permissionToPublish -eq $true) -or ($record.permissionToPublish -eq $false)) -Message "Record '$($record.recordId)' must set permissionToPublish to true or false."
  Assert-True -Condition (Test-DateLikeValue $record.createdAt) -Message "Record '$($record.recordId)' createdAt must be a date-like value."
  Assert-True -Condition (Test-DateLikeValue $record.updatedAt) -Message "Record '$($record.recordId)' updatedAt must be a date-like value."
  Assert-True -Condition (Test-DateLikeValue $record.sampleDateTime) -Message "Record '$($record.recordId)' sampleDateTime must be a date-like value."
  Assert-True -Condition ($record.gpsPrecisionMeters -ge 0) -Message "Record '$($record.recordId)' gpsPrecisionMeters must be zero or greater."

  if ($record.qaStatus -eq "approved-public") {
    $approvedPublicCount += 1
    Assert-True -Condition ($record.permissionToPublish -eq $true) -Message "Record '$($record.recordId)' is approved-public but permissionToPublish is not true."
    Assert-True -Condition (-not [string]::IsNullOrWhiteSpace($record.publicSummary)) -Message "Record '$($record.recordId)' is approved-public but publicSummary is blank."
    Assert-True -Condition ($record.publicLocationPrecision -ne "not approved") -Message "Record '$($record.recordId)' is approved-public but publicLocationPrecision is still not approved."
  }

  if ($record.permissionToPublish -eq $true) {
    $publishableCount += 1
    Assert-True -Condition ($record.qaStatus -eq "approved-public") -Message "Record '$($record.recordId)' has permissionToPublish true but qaStatus is not approved-public."
  }
}

if ($approvedPublicCount -eq 0) {
  Add-Warning "No approved-public records are ready for public export."
}

if ($publishableCount -eq 0) {
  Add-Warning "No records currently have permissionToPublish true."
}

if ($warnings.Count -gt 0) {
  Write-Output "Warnings:"
  foreach ($warning in $warnings) {
    Write-Output "  - $warning"
  }
}

if ($failures.Count -gt 0) {
  Write-Output "Validation failed for private field/microscopy intake:"
  foreach ($failure in $failures) {
    Write-Output "  - $failure"
  }
  exit 1
}

Write-Output "Private field/microscopy intake validation passed."
Write-Output "Records checked: $(@($data.records).Count)"
Write-Output "Approved-public records: $approvedPublicCount"
Write-Output "Publishable records: $publishableCount"
