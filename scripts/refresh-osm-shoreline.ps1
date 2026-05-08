$ErrorActionPreference = "Stop"

$headers = @{
  "User-Agent" = "ClearLakeWatchPrototype/0.1 (local development)"
}

$outputPath = Join-Path $PSScriptRoot "..\data\lake-shoreline.json"
$overpassUrl = "https://overpass-api.de/api/interpreter"
$relationId = 4046481
$query = @"
[out:json][timeout:25];
relation($relationId);
out body;
>;
out geom;
"@

function Write-JsonFile {
  param(
    [string]$Path,
    [object]$Data
  )

  $json = $Data | ConvertTo-Json -Depth 12
  $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
  $fullPath = [System.IO.Path]::GetFullPath($Path)
  [System.IO.File]::WriteAllText($fullPath, $json, $utf8NoBom)
}

function New-Point {
  param(
    [object]$Coordinate
  )

  return [PSCustomObject]@{
    latitude = [math]::Round([double]$Coordinate.lat, 7)
    longitude = [math]::Round([double]$Coordinate.lon, 7)
  }
}

function New-WaySegment {
  param(
    [object]$Way
  )

  $points = @($Way.geometry | ForEach-Object { New-Point $_ })
  $nodes = @($Way.nodes)

  if ($points.Count -eq 0 -or $nodes.Count -eq 0) {
    throw "OSM way $($Way.id) did not include geometry and node coordinates."
  }

  return [PSCustomObject]@{
    wayId = $Way.id
    nodes = $nodes
    points = $points
  }
}

function Reverse-Segment {
  param(
    [object]$Segment
  )

  $nodes = @($Segment.nodes)
  [array]::Reverse($nodes)

  $points = @($Segment.points)
  [array]::Reverse($points)

  return [PSCustomObject]@{
    wayId = $Segment.wayId
    nodes = $nodes
    points = $points
  }
}

function Join-WaySegments {
  param(
    [object[]]$Segments,
    [string]$Role
  )

  $remaining = [System.Collections.Generic.List[object]]::new()
  foreach ($segment in $Segments) {
    $remaining.Add($segment)
  }

  $rings = [System.Collections.Generic.List[object]]::new()

  while ($remaining.Count -gt 0) {
    $current = $remaining[0]
    $remaining.RemoveAt(0)

    $ringNodes = [System.Collections.Generic.List[object]]::new()
    $ringPoints = [System.Collections.Generic.List[object]]::new()
    $ringWayIds = [System.Collections.Generic.List[object]]::new()
    $ringWayIds.Add($current.wayId)
    foreach ($node in $current.nodes) { $ringNodes.Add($node) }
    foreach ($point in $current.points) { $ringPoints.Add($point) }

    $madeProgress = $true
    while ($madeProgress -and $remaining.Count -gt 0) {
      $madeProgress = $false
      $lastNode = $ringNodes[$ringNodes.Count - 1]

      for ($index = 0; $index -lt $remaining.Count; $index++) {
        $candidate = $remaining[$index]
        $candidateNodes = @($candidate.nodes)
        $firstCandidateNode = $candidateNodes[0]
        $lastCandidateNode = $candidateNodes[$candidateNodes.Count - 1]

        if ($firstCandidateNode -eq $lastNode -or $lastCandidateNode -eq $lastNode) {
          if ($lastCandidateNode -eq $lastNode) {
            $candidate = Reverse-Segment $candidate
            $candidateNodes = @($candidate.nodes)
          }

          $candidatePoints = @($candidate.points)
          for ($candidateIndex = 1; $candidateIndex -lt $candidateNodes.Count; $candidateIndex++) {
            $ringNodes.Add($candidateNodes[$candidateIndex])
            $ringPoints.Add($candidatePoints[$candidateIndex])
          }
          $ringWayIds.Add($candidate.wayId)

          $remaining.RemoveAt($index)
          $madeProgress = $true
          break
        }
      }
    }

    $isClosed = $ringNodes[0] -eq $ringNodes[$ringNodes.Count - 1]
    $rings.Add([PSCustomObject]@{
      role = $Role
      pointCount = $ringPoints.Count
      closed = $isClosed
      sourceWayIds = @($ringWayIds)
      points = @($ringPoints)
    })
  }

  return @($rings)
}

$response = Invoke-RestMethod -Method Post -Uri $overpassUrl -Body @{ data = $query } -Headers $headers
$relation = $response.elements | Where-Object { $_.type -eq "relation" -and $_.id -eq $relationId } | Select-Object -First 1

if (-not $relation) {
  throw "OpenStreetMap relation $relationId was not returned by Overpass."
}

$waysById = @{}
foreach ($way in $response.elements | Where-Object { $_.type -eq "way" }) {
  $waysById["$($way.id)"] = $way
}

$rings = [System.Collections.Generic.List[object]]::new()
foreach ($role in @("outer", "inner")) {
  $segments = @(
    $relation.members |
      Where-Object { $_.type -eq "way" -and $_.role -eq $role } |
      ForEach-Object {
        if (-not $waysById.ContainsKey("$($_.ref)")) {
          throw "OpenStreetMap relation $relationId references missing way $($_.ref)."
        }

        New-WaySegment $waysById["$($_.ref)"]
      }
  )

  foreach ($ring in Join-WaySegments -Segments $segments -Role $role) {
    $rings.Add($ring)
  }
}

$allPoints = @($rings | ForEach-Object { $_.points } | ForEach-Object { $_ })
if ($allPoints.Count -eq 0) {
  throw "No shoreline coordinates were generated from OpenStreetMap relation $relationId."
}

$bounds = [PSCustomObject]@{
  latitudeMin = [math]::Round([double](($allPoints | Measure-Object latitude -Minimum).Minimum), 7)
  latitudeMax = [math]::Round([double](($allPoints | Measure-Object latitude -Maximum).Maximum), 7)
  longitudeMin = [math]::Round([double](($allPoints | Measure-Object longitude -Minimum).Minimum), 7)
  longitudeMax = [math]::Round([double](($allPoints | Measure-Object longitude -Maximum).Maximum), 7)
}

$data = [ordered]@{
  generatedAt = (Get-Date).ToString("o")
  source = "OpenStreetMap"
  sourceUrl = "https://www.openstreetmap.org/relation/$relationId"
  attribution = "Map data from OpenStreetMap contributors"
  license = "Open Database License (ODbL)"
  licenseUrl = "https://www.openstreetmap.org/copyright"
  relationId = $relationId
  relationName = $relation.tags.name
  geometryType = "MultiPolygon"
  bounds = $bounds
  rings = @($rings)
}

Write-JsonFile -Path $outputPath -Data $data
Write-Output "Wrote $outputPath"
