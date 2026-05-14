param(
  [string]$OutputPath = ".\data\weather-context.json",
  [string]$StationId = "KELC1",
  [string]$StationName = "KONOCTI",
  [int]$StaleAfterHours = 6
)

$ErrorActionPreference = "Stop"

function Write-JsonFile {
  param(
    [string]$Path,
    [object]$Data
  )

  $json = $Data | ConvertTo-Json -Depth 10
  $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
  $fullPath = [System.IO.Path]::GetFullPath($Path)
  [System.IO.File]::WriteAllText($fullPath, $json, $utf8NoBom)
}

function Convert-CelsiusToDisplay {
  param([object]$Value)

  if ($null -eq $Value) {
    return "Unavailable"
  }
  return "$([math]::Round([double]$Value, 1)) C"
}

function Convert-PercentToDisplay {
  param([object]$Value)

  if ($null -eq $Value) {
    return "Unavailable"
  }
  return "$([math]::Round([double]$Value, 0))%"
}

function Convert-WindToDisplay {
  param([object]$Value)

  if ($null -eq $Value) {
    return "Unavailable"
  }
  return "$([math]::Round([double]$Value, 1)) m/s"
}

function Get-MetricRecord {
  param(
    [string]$Label,
    [object]$Value,
    [string]$Unit,
    [string]$Status = "reviewed-public-source"
  )

  return [ordered]@{
    label = $Label
    value = if ($null -eq $Value) { $null } else { [math]::Round([double]$Value, 3) }
    unit = $Unit
    status = if ($null -eq $Value) { "unavailable" } else { $Status }
  }
}

$headers = @{
  "User-Agent" = "ClearLakeWatchPrototype/0.1 (https://github.com/coreytshaffer/clear-lake-watch)"
}

$stationUrl = "https://api.weather.gov/stations/$StationId"
$latestUrl = "https://api.weather.gov/stations/$StationId/observations/latest"

try {
  $stationResponse = Invoke-RestMethod -Uri $stationUrl -Headers $headers -TimeoutSec 30
  $latestResponse = Invoke-RestMethod -Uri $latestUrl -Headers $headers -TimeoutSec 30
  $station = $stationResponse.properties
  $observation = $latestResponse.properties
  $observedAt = [datetimeoffset]$observation.timestamp
  $generatedAt = [datetimeoffset](Get-Date)
  $ageHours = ($generatedAt - $observedAt).TotalHours
  $status = if ($ageHours -gt $StaleAfterHours) { "stale" } else { "partial" }

  $temperatureC = $observation.temperature.value
  $relativeHumidityPct = $observation.relativeHumidity.value
  $windSpeedMps = $observation.windSpeed.value
  $windDirectionDeg = $observation.windDirection.value

  $payload = [ordered]@{
    schemaVersion = "weather-context-v1"
    generatedAt = $generatedAt.ToString("o")
    sourceName = "NOAA/National Weather Service API"
    sourceUrl = $latestUrl
    machineReadableStatus = $status
    staleAfterHours = $StaleAfterHours
    stations = @(
      [ordered]@{
        stationId = $StationId
        displayName = if ([string]::IsNullOrWhiteSpace($station.name)) { $StationName } else { $station.name }
        visibility = "public-source-generalized"
        latitude = $null
        longitude = $null
        observedAt = $observedAt.ToString("o")
        healthLabel = $status
        metrics = @(
          Get-MetricRecord -Label "Air temperature" -Value $temperatureC -Unit "C"
          Get-MetricRecord -Label "Relative humidity" -Value $relativeHumidityPct -Unit "%"
          Get-MetricRecord -Label "Wind speed" -Value $windSpeedMps -Unit "m/s"
          Get-MetricRecord -Label "Wind direction" -Value $windDirectionDeg -Unit "degrees"
        )
      }
    )
    summaryCards = @(
      [ordered]@{
        label = "Weather source"
        value = "$StationId / $StationName"
        note = "Reviewed public weather.gov station snapshot; generalized for public context."
        status = "context-only"
      },
      [ordered]@{
        label = "Air temperature"
        value = Convert-CelsiusToDisplay $temperatureC
        note = "Latest reviewed public-source station observation, not a lake-water measurement."
        status = $status
      },
      [ordered]@{
        label = "Relative humidity"
        value = Convert-PercentToDisplay $relativeHumidityPct
        note = "Weather-driver context only."
        status = $status
      },
      [ordered]@{
        label = "Wind speed"
        value = Convert-WindToDisplay $windSpeedMps
        note = "Wind context is not a bloom-severity estimate."
        status = $status
      }
    )
    contextWindows = @(
      [ordered]@{
        label = "Latest weather observation"
        windowHours = $StaleAfterHours
        summary = "Public weather.gov station observation reviewed as environmental-driver context only."
        status = "context-only"
      }
    )
    qualityNotes = @(
      "Weather context is generated from a reviewed public NOAA/National Weather Service API station observation.",
      "Station coordinates are not published in this public export; the station ID is included for source transparency.",
      "Weather context is separate from lake-health interpretation and public-health guidance.",
      "This is not MQTT, Grafana, InfluxDB, raw local telemetry, or a private gateway export.",
      "Weather context is not a bloom-severity estimate, cyanotoxin advisory, or recreation-safety recommendation."
    )
  }
} catch {
  $payload = [ordered]@{
    schemaVersion = "weather-context-v1"
    generatedAt = (Get-Date).ToString("o")
    sourceName = "NOAA/National Weather Service API"
    sourceUrl = $latestUrl
    machineReadableStatus = "unavailable"
    staleAfterHours = $StaleAfterHours
    stations = @()
    summaryCards = @(
      [ordered]@{
        label = "Weather context"
        value = "Unavailable"
        note = "The public weather source could not be fetched for this reviewed snapshot."
        status = "unavailable"
      }
    )
    contextWindows = @()
    qualityNotes = @(
      "Weather context fetch failed during reviewed public export generation.",
      "The dashboard remains a public lake-source snapshot, not live weather telemetry.",
      "Weather context is not public-health guidance or a bloom-severity estimate."
    )
  }
}

Write-JsonFile -Path $OutputPath -Data $payload
Write-Output "Wrote $OutputPath"
