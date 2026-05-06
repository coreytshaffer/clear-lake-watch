param(
  [string]$OutputPath = "data/private/field-microscopy-intake.local.json"
)

$ErrorActionPreference = "Stop"

$projectRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot ".."))
$templatePath = Join-Path $projectRoot "data/field-microscopy-intake.example.json"
$resolvedOutputPath = Join-Path $projectRoot $OutputPath
$outputDirectory = Split-Path -Parent $resolvedOutputPath

if (-not (Test-Path $templatePath)) {
  throw "Missing intake example template: data/field-microscopy-intake.example.json"
}

if (-not (Test-Path $outputDirectory)) {
  New-Item -ItemType Directory -Path $outputDirectory | Out-Null
}

if (Test-Path $resolvedOutputPath) {
  Write-Output "Private field/microscopy intake file already exists: $OutputPath"
  Write-Output "No files were modified."
  exit 0
}

$template = Get-Content $templatePath -Raw | ConvertFrom-Json
$template.status = "private-local"

foreach ($record in @($template.records)) {
  $record.recordId = "field-micro-draft-001"
  $record.qaStatus = "draft"
  $record.permissionToPublish = $false
  $record.publicSummary = ""
}

$template |
  ConvertTo-Json -Depth 20 |
  Set-Content -Path $resolvedOutputPath -Encoding UTF8

Write-Output "Created private field/microscopy intake file: $OutputPath"
Write-Output "This file is ignored by Git and should stay out of the public static mirror."
