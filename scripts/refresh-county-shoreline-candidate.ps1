param(
  [string]$SourcePath = "",
  [string]$OutputPath = "",
  [string]$Ogr2OgrPath = "",
  [double]$SimplifyToleranceFeet = 0,
  [switch]$Promote
)

$ErrorActionPreference = "Stop"

$projectRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot ".."))

if ([string]::IsNullOrWhiteSpace($SourcePath)) {
  $SourcePath = if ($env:CLEAR_LAKE_COUNTY_LAKES_PATH) {
    $env:CLEAR_LAKE_COUNTY_LAKES_PATH
  } else {
    "C:\Users\corey\Documents\Codex\North Shore Risk Analysis Document\02_data_raw\lake_county_public_gis_2026_04_21\extracted\waterfeatures\lakes.shp"
  }
}

if ([string]::IsNullOrWhiteSpace($OutputPath)) {
  $targetFileName = if ($Promote) {
    "lake-shoreline.json"
  } else {
    "lake-shoreline-county-candidate.json"
  }
  $OutputPath = Join-Path $projectRoot "data\$targetFileName"
}

function Resolve-Ogr2OgrPath {
  param(
    [string]$RequestedPath
  )

  if (-not [string]::IsNullOrWhiteSpace($RequestedPath)) {
    if (Test-Path $RequestedPath) {
      return [System.IO.Path]::GetFullPath($RequestedPath)
    }

    throw "OGR2OGR was not found at '$RequestedPath'. Set CLEAR_LAKE_OGR2OGR or pass -Ogr2OgrPath."
  }

  if ($env:CLEAR_LAKE_OGR2OGR -and (Test-Path $env:CLEAR_LAKE_OGR2OGR)) {
    return [System.IO.Path]::GetFullPath($env:CLEAR_LAKE_OGR2OGR)
  }

  $qgisOgr2Ogr = "C:\Program Files\QGIS 3.44.6\bin\ogr2ogr.exe"
  if (Test-Path $qgisOgr2Ogr) {
    return $qgisOgr2Ogr
  }

  $pathCommand = Get-Command ogr2ogr -ErrorAction SilentlyContinue
  if ($pathCommand) {
    return $pathCommand.Source
  }

  throw "OGR2OGR was not found. Install/use QGIS, set CLEAR_LAKE_OGR2OGR, or pass -Ogr2OgrPath."
}

function Write-JsonFile {
  param(
    [string]$Path,
    [object]$Data
  )

  $json = $Data | ConvertTo-Json -Depth 20
  $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
  $fullPath = [System.IO.Path]::GetFullPath($Path)
  [System.IO.Directory]::CreateDirectory([System.IO.Path]::GetDirectoryName($fullPath)) | Out-Null
  [System.IO.File]::WriteAllText($fullPath, $json, $utf8NoBom)
}

function New-Point {
  param(
    [object[]]$Coordinate
  )

  return [PSCustomObject]@{
    latitude = [math]::Round([double]$Coordinate[1], 7)
    longitude = [math]::Round([double]$Coordinate[0], 7)
  }
}

function New-Ring {
  param(
    [object[]]$Coordinates,
    [string]$Role,
    [string]$SourceFeatureId
  )

  $points = @($Coordinates | ForEach-Object { New-Point $_ })
  $closed = $false
  if ($points.Count -gt 1) {
    $first = $points[0]
    $last = $points[$points.Count - 1]
    $closed = $first.latitude -eq $last.latitude -and $first.longitude -eq $last.longitude
  }

  return [PSCustomObject]@{
    role = $Role
    pointCount = $points.Count
    closed = $closed
    sourceFeatureIds = @($SourceFeatureId)
    points = @($points)
  }
}

function Add-PolygonRings {
  param(
    [System.Collections.Generic.List[object]]$Rings,
    [object[]]$PolygonCoordinates,
    [string]$SourceFeatureId
  )

  for ($ringIndex = 0; $ringIndex -lt $PolygonCoordinates.Count; $ringIndex++) {
    $role = if ($ringIndex -eq 0) { "outer" } else { "inner" }
    $Rings.Add((New-Ring -Coordinates @($PolygonCoordinates[$ringIndex]) -Role $role -SourceFeatureId $SourceFeatureId))
  }
}

$sourceFullPath = [System.IO.Path]::GetFullPath($SourcePath)
if (-not (Test-Path $sourceFullPath)) {
  throw "County lakes source was not found at '$sourceFullPath'. Set CLEAR_LAKE_COUNTY_LAKES_PATH or pass -SourcePath."
}

$ogr2ogr = Resolve-Ogr2OgrPath -RequestedPath $Ogr2OgrPath
$tempGeoJson = Join-Path ([System.IO.Path]::GetTempPath()) "clear-lake-county-shoreline-$([Guid]::NewGuid()).geojson"

try {
  $ogrArgs = @(
    "-f",
    "GeoJSON",
    "-t_srs",
    "EPSG:4326",
    "-where",
    "Name = 'Clear Lake'"
  )

  if ($SimplifyToleranceFeet -gt 0) {
    $ogrArgs += @("-simplify", "$SimplifyToleranceFeet")
  }

  $ogrArgs += @($tempGeoJson, $sourceFullPath)

  & $ogr2ogr @ogrArgs | Out-Null

  if ($LASTEXITCODE -ne 0) {
    throw "OGR2OGR failed while exporting the Clear Lake polygon from '$sourceFullPath'."
  }

  $geoJson = Get-Content $tempGeoJson -Raw | ConvertFrom-Json
  $features = @($geoJson.features)
  if ($features.Count -ne 1) {
    throw "Expected exactly one county GIS feature named 'Clear Lake', found $($features.Count)."
  }

  $feature = $features[0]
  $featureId = if ($feature.id) { "$($feature.id)" } else { "county-lakes-clear-lake" }
  $rings = [System.Collections.Generic.List[object]]::new()

  if ($feature.geometry.type -eq "Polygon") {
    Add-PolygonRings -Rings $rings -PolygonCoordinates @($feature.geometry.coordinates) -SourceFeatureId $featureId
  } elseif ($feature.geometry.type -eq "MultiPolygon") {
    foreach ($polygon in @($feature.geometry.coordinates)) {
      Add-PolygonRings -Rings $rings -PolygonCoordinates @($polygon) -SourceFeatureId $featureId
    }
  } else {
    throw "Unsupported county shoreline geometry type '$($feature.geometry.type)'. Expected Polygon or MultiPolygon."
  }

  $allPoints = @($rings | ForEach-Object { $_.points } | ForEach-Object { $_ })
  if ($allPoints.Count -eq 0) {
    throw "No county shoreline points were generated from '$sourceFullPath'."
  }

  $bounds = [PSCustomObject]@{
    latitudeMin = [math]::Round([double](($allPoints | Measure-Object latitude -Minimum).Minimum), 7)
    latitudeMax = [math]::Round([double](($allPoints | Measure-Object latitude -Maximum).Maximum), 7)
    longitudeMin = [math]::Round([double](($allPoints | Measure-Object longitude -Minimum).Minimum), 7)
    longitudeMax = [math]::Round([double](($allPoints | Measure-Object longitude -Maximum).Maximum), 7)
  }

  $data = [ordered]@{
    generatedAt = (Get-Date).ToString("o")
    source = "Lake County public GIS"
    sourceDataset = "waterfeatures/lakes"
    sourceFeatureName = $feature.properties.Name
    sourceFeatureType = $feature.properties.Type
    sourceFeatureAcres = [math]::Round([double]$feature.properties.Acres, 4)
    sourcePath = "lake_county_public_gis_2026_04_21/extracted/waterfeatures/lakes.shp"
    simplifyToleranceFeet = if ($SimplifyToleranceFeet -gt 0) { $SimplifyToleranceFeet } else { $null }
    attribution = "Candidate geometry from Lake County public GIS waterfeatures lakes layer"
    license = "Source terms not yet verified for public publication"
    licenseUrl = "https://www.lakecountyca.gov/"
    geometryType = "MultiPolygon"
    candidate = -not $Promote
    publicationStatus = if ($Promote) { "active" } else { "candidate-review" }
    reviewNote = "Generated from local county GIS for visual/source review. Do not treat as the public map geometry until attribution and publication terms are confirmed."
    bounds = $bounds
    rings = @($rings)
  }

  Write-JsonFile -Path $OutputPath -Data $data
  Write-Output "Wrote $OutputPath"
  Write-Output "Rings: $($rings.Count)"
  Write-Output "Points: $($allPoints.Count)"
  Write-Output "Bounds: lat $($bounds.latitudeMin) to $($bounds.latitudeMax), lon $($bounds.longitudeMin) to $($bounds.longitudeMax)"
} finally {
  if (Test-Path $tempGeoJson) {
    Remove-Item $tempGeoJson -Force
  }
}
