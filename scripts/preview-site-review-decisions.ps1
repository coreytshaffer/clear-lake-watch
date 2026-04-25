param(
  [string]$DecisionPath = ".\data\site-review-decisions.example.json",
  [string]$SitesPath = ".\data\sites.json",
  [string]$ReviewPath = ".\data\site-review.json"
)

$ErrorActionPreference = "Stop"

$allowedActions = @(
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

function Read-JsonFile {
  param([string]$Path)

  if (-not (Test-Path $Path)) {
    throw "Missing required JSON file: $Path"
  }

  return Get-Content $Path -Raw | ConvertFrom-Json
}

function Assert-DecisionField {
  param(
    [object]$Decision,
    [string]$FieldName
  )

  if ($Decision.PSObject.Properties.Name -notcontains $FieldName) {
    throw "Decision '$($Decision.decisionId)' is missing required field '$FieldName'."
  }
}

function Assert-NonEmptyDecisionText {
  param(
    [object]$Decision,
    [string]$FieldName
  )

  $value = $Decision.$FieldName

  if ([string]::IsNullOrWhiteSpace($value)) {
    throw "Decision '$($Decision.decisionId)' must include a non-empty '$FieldName'."
  }
}

function Find-Site {
  param(
    [array]$Sites,
    [string]$SiteId
  )

  return $Sites | Where-Object { $_.siteId -eq $SiteId } | Select-Object -First 1
}

function Find-ReviewItem {
  param(
    [array]$ReviewQueue,
    [object]$Decision
  )

  return $ReviewQueue |
    Where-Object {
      $_.siteId -eq $Decision.siteId -and
      $_.landmark -eq $Decision.landmark
    } |
    Select-Object -First 1
}

function Get-PreviewNote {
  param(
    [object]$Decision,
    [object]$Site,
    [object]$ReviewItem
  )

  switch ($Decision.action) {
    "keep-needs-review" {
      return "Would preserve '$($Decision.siteId)' as needs-local-review for '$($Decision.landmark)'."
    }
    "add-alias" {
      return "Would add alias '$($Decision.proposedAlias)' to '$($Site.name)' and keep status '$($Decision.proposedAssignmentStatus)'."
    }
    "create-site" {
      return "Would require a new stable site record before this decision can be applied."
    }
    "promote-reviewed-local" {
      return "Would promote '$($Decision.siteId)' to reviewed-local if evidence and reviewer fields are complete."
    }
    default {
      return "No preview available."
    }
  }
}

$decisionData = Read-JsonFile $DecisionPath
$siteData = Read-JsonFile $SitesPath
$reviewData = Read-JsonFile $ReviewPath

if ($decisionData.schemaVersion -ne 1) {
  throw "Decision file must use schemaVersion 1."
}

$sites = @($siteData.sites)
$reviewQueue = @($reviewData.reviewQueue)
$previewRows = [System.Collections.Generic.List[object]]::new()

foreach ($decision in @($decisionData.decisions)) {
  foreach ($field in $requiredDecisionFields) {
    Assert-DecisionField -Decision $decision -FieldName $field
  }

  if ($allowedActions -notcontains $decision.action) {
    throw "Decision '$($decision.decisionId)' has unsupported action '$($decision.action)'."
  }

  Assert-NonEmptyDecisionText -Decision $decision -FieldName "decisionId"
  Assert-NonEmptyDecisionText -Decision $decision -FieldName "siteId"
  Assert-NonEmptyDecisionText -Decision $decision -FieldName "landmark"
  Assert-NonEmptyDecisionText -Decision $decision -FieldName "reviewer"
  Assert-NonEmptyDecisionText -Decision $decision -FieldName "reviewedAt"
  Assert-NonEmptyDecisionText -Decision $decision -FieldName "evidenceNote"

  $site = Find-Site -Sites $sites -SiteId $decision.siteId
  if (-not $site -and $decision.action -ne "create-site") {
    throw "Decision '$($decision.decisionId)' references unknown siteId '$($decision.siteId)'."
  }

  $reviewItem = Find-ReviewItem -ReviewQueue $reviewQueue -Decision $decision
  if (-not $reviewItem) {
    throw "Decision '$($decision.decisionId)' does not match an item in the current review queue."
  }

  if ($decision.action -eq "promote-reviewed-local" -and -not $decision.permissionToPublish) {
    throw "Decision '$($decision.decisionId)' cannot promote to reviewed-local unless permissionToPublish is true."
  }

  if ($decision.action -eq "add-alias" -and [string]::IsNullOrWhiteSpace($decision.proposedAlias)) {
    throw "Decision '$($decision.decisionId)' must include proposedAlias for add-alias."
  }

  $previewRows.Add([PSCustomObject]@{
      decisionId = $decision.decisionId
      action = $decision.action
      siteId = $decision.siteId
      siteName = if ($site) { $site.name } else { "new site required" }
      landmark = $decision.landmark
      currentStatus = $reviewItem.assignmentStatus
      proposedStatus = $decision.proposedAssignmentStatus
      reviewPriority = $reviewItem.reviewPriority
      preview = Get-PreviewNote -Decision $decision -Site $site -ReviewItem $reviewItem
    })
}

Write-Output "Site review decision preview only. No files were modified."
Write-Output ""

foreach ($row in $previewRows) {
  Write-Output "Decision: $($row.decisionId)"
  Write-Output "  Action: $($row.action)"
  Write-Output "  Site: $($row.siteName) ($($row.siteId))"
  Write-Output "  Landmark: $($row.landmark)"
  Write-Output "  Priority: $($row.reviewPriority)"
  Write-Output "  Status: $($row.currentStatus) -> $($row.proposedStatus)"
  Write-Output "  Preview: $($row.preview)"
  Write-Output ""
}
