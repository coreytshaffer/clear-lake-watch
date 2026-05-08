param(
  [string]$OutputPath = ".\data\weather-context.json"
)

$ErrorActionPreference = "Stop"

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

$payload = [ordered]@{
  schemaVersion = "weather-context-v1"
  generatedAt = (Get-Date).ToString("o")
  sourceName = "Environmental Monitoring Backbone"
  machineReadableStatus = "unavailable"
  staleAfterHours = 6
  stations = @()
  summaryCards = @(
    [ordered]@{
      label = "Weather context"
      value = "Not connected"
      note = "No reviewed public weather export has been generated from live telemetry yet."
      status = "unavailable"
    }
  )
  contextWindows = @()
  qualityNotes = @(
    "Weather context is currently unavailable.",
    "The Clear Lake Watch dashboard is using public lake-source snapshots only.",
    "Weather context must remain separate from lake-health interpretation and public-health guidance.",
    "This file is a public-safe unavailable placeholder, not a live telemetry export."
  )
}

Write-JsonFile -Path $OutputPath -Data $payload
Write-Output "Wrote $OutputPath"
