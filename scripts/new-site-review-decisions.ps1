param(
  [string]$ReviewPath = ".\data\site-review.json",
  [string]$OutputPath = ".\data\site-review-decisions.local.json",
  [string]$Priority = "high",
  [switch]$AllPriorities,
  [switch]$Overwrite
)

$ErrorActionPreference = "Stop"

function Read-JsonFile {
  param([string]$Path)

  if (-not (Test-Path $Path)) {
    throw "Missing required JSON file: $Path"
  }

  return Get-Content $Path -Raw | ConvertFrom-Json
}

function Write-JsonFile {
  param(
    [string]$Path,
    [object]$Data
  )

  $json = $Data | ConvertTo-Json -Depth 8
  $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
  $fullPath = [System.IO.Path]::GetFullPath($Path)
  [System.IO.File]::WriteAllText($fullPath, $json, $utf8NoBom)
}

function Get-SafeDecisionId {
  param(
    [string]$SiteId,
    [string]$Landmark,
    [string]$DateStamp
  )

  $slug = "$SiteId-$Landmark".ToLowerInvariant()
  $slug = [regex]::Replace($slug, "[^a-z0-9]+", "-").Trim("-")

  return "$slug-$DateStamp"
}

if ((Test-Path $OutputPath) -and -not $Overwrite) {
  throw "Refusing to overwrite existing decision file: $OutputPath. Re-run with -Overwrite if that is intentional."
}

$reviewData = Read-JsonFile $ReviewPath
$reviewQueue = @($reviewData.reviewQueue)

if (-not $AllPriorities) {
  $reviewQueue = @($reviewQueue | Where-Object { $_.reviewPriority -eq $Priority })
}

if ($reviewQueue.Count -eq 0) {
  throw "No review queue items matched priority '$Priority'."
}

$dateStamp = Get-Date -Format "yyyy-MM-dd"
$reviewedAt = Get-Date -Format "o"

$decisions = @(
  $reviewQueue | ForEach-Object {
    [ordered]@{
      decisionId = Get-SafeDecisionId -SiteId $_.siteId -Landmark $_.landmark -DateStamp $dateStamp
      siteId = $_.siteId
      landmark = $_.landmark
      action = "keep-needs-review"
      proposedAlias = $null
      proposedAssignmentStatus = "needs-local-review"
      reviewer = "Corey"
      reviewedAt = $reviewedAt
      evidenceNote = "TODO: Review source coordinate, registry coordinate, lake arm, and landmark evidence before changing this decision."
      publicNote = "Review pending; keep assignment conservative until local evidence is recorded."
      permissionToPublish = $false
    }
  }
)

$decisionData = [ordered]@{
  schemaVersion = 1
  purpose = "Private working decision file generated from the current FHABS site-registry review queue."
  generatedAt = $reviewedAt
  generatedFrom = $ReviewPath
  priorityFilter = if ($AllPriorities) { "all" } else { $Priority }
  decisions = $decisions
  allowedActions = @(
    "keep-needs-review",
    "add-alias",
    "create-site",
    "promote-reviewed-local"
  )
  guardrails = @(
    "Do not promote to reviewed-local without evidenceNote and reviewer.",
    "Do not publish private reviewer notes or sensitive field details.",
    "Do not use unresolved decisions as public-health guidance or model labels."
  )
}

Write-JsonFile -Path $OutputPath -Data $decisionData

Write-Output "Wrote $OutputPath"
Write-Output "Review items included: $($decisions.Count)"
Write-Output "Next step:"
Write-Output "  powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\preview-site-review-decisions.ps1 -DecisionPath $OutputPath"
