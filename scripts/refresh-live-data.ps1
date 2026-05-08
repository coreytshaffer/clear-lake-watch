$ErrorActionPreference = "Stop"

$headers = @{
  "User-Agent" = "Mozilla/5.0 (Codex Clear Lake Watch Prototype)"
}

$outputPath = Join-Path $PSScriptRoot "..\data\live.json"
$reportsOutputPath = Join-Path $PSScriptRoot "..\data\reports.json"
$observationsOutputPath = Join-Path $PSScriptRoot "..\data\observations.json"
$normalizedSitesOutputPath = Join-Path $PSScriptRoot "..\data\sites-normalized.json"
$analyticsOutputPath = Join-Path $PSScriptRoot "..\data\analytics.json"
$manifestOutputPath = Join-Path $PSScriptRoot "..\data\manifest.json"
$siteRegistryPath = Join-Path $PSScriptRoot "..\data\sites.json"
$siteRegistry = Get-Content $siteRegistryPath -Raw | ConvertFrom-Json
$fhabsDatasetId = "ab672540-aecd-42f1-9b05-9aad326f97ec"
$fhabsBloomReportsResourceId = "c6a36b91-ad38-4611-8750-87ee99e497dd"
$fhabsResultsResourceId = "9d4e1df4-0cd6-4165-9e63-effcafd9dccc"
$fhabsMaxResourceAgeDays = 14
$rumseyZeroElevationFt = 1318.256

if ($env:CLEAR_LAKE_FHABS_MAX_RESOURCE_AGE_DAYS) {
  $parsedMaxAgeDays = 0
  if (-not [int]::TryParse($env:CLEAR_LAKE_FHABS_MAX_RESOURCE_AGE_DAYS, [ref]$parsedMaxAgeDays) -or $parsedMaxAgeDays -lt 1) {
    throw "CLEAR_LAKE_FHABS_MAX_RESOURCE_AGE_DAYS must be a positive integer."
  }

  $fhabsMaxResourceAgeDays = $parsedMaxAgeDays
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

function Parse-Date {
  param(
    [string]$Value
  )

  if ([string]::IsNullOrWhiteSpace($Value)) {
    return $null
  }

  return [datetime]::Parse($Value, [System.Globalization.CultureInfo]::InvariantCulture)
}

function Format-DateIso {
  param(
    [object]$Value
  )

  if (-not $Value) {
    return $null
  }

  return ([datetime]$Value).ToString("yyyy-MM-dd")
}

function Convert-RumseyToElevationFeet {
  param([double]$RumseyFeet)

  return [math]::Round(($RumseyFeet + $rumseyZeroElevationFt), 2)
}

function Get-FhabsPackage {
  param(
    [string]$DatasetId
  )

  $url = "https://data.ca.gov/api/3/action/package_show?id=$DatasetId"
  $response = Invoke-RestMethod -Uri $url -Headers $headers

  if (-not $response.success -or -not $response.result.resources) {
    throw "Could not resolve FHABS dataset metadata from $url."
  }

  return $response
}

function Resolve-FhabsResourceUrl {
  param(
    [object]$Package,
    [string]$ResourceId,
    [string]$NamePattern,
    [string]$OverrideUrl
  )

  if (-not [string]::IsNullOrWhiteSpace($OverrideUrl)) {
    return $OverrideUrl
  }

  if (-not $Package) {
    throw "FHABS package metadata is required unless an override URL is provided."
  }

  $resource = $Package.result.resources |
    Where-Object { $_.id -eq $ResourceId } |
    Select-Object -First 1

  if (-not $resource) {
    $resource = $Package.result.resources |
      Where-Object { $_.format -eq "CSV" -and $_.name -match $NamePattern } |
      Select-Object -First 1
  }

  if (-not $resource -or [string]::IsNullOrWhiteSpace($resource.url)) {
    throw "Could not resolve FHABS resource matching '$NamePattern'."
  }

  return $resource.url
}

function Get-FhabsResourceFreshness {
  param(
    [string]$Url
  )

  if ($Url -notmatch '_(\d{4}-\d{2}-\d{2})\.csv(?:\?|$)') {
    return [PSCustomObject]@{
      resourceDate = $null
      ageDays = $null
    }
  }

  $resourceDate = [datetime]::ParseExact(
    $matches[1],
    "yyyy-MM-dd",
    [System.Globalization.CultureInfo]::InvariantCulture
  )
  $ageDays = ((Get-Date).Date - $resourceDate.Date).Days

  return [PSCustomObject]@{
    resourceDate = $resourceDate
    ageDays = $ageDays
  }
}

function Assert-FhabsResourceFreshness {
  param(
    [string]$Label,
    [string]$Url,
    [int]$MaxAgeDays
  )

  $freshness = Get-FhabsResourceFreshness -Url $Url

  if ($null -eq $freshness.ageDays) {
    return
  }

  if ($freshness.ageDays -gt $MaxAgeDays) {
    throw "$Label FHABS resource appears stale ($($freshness.resourceDate.ToString('yyyy-MM-dd')), $($freshness.ageDays) days old): $Url. Set CLEAR_LAKE_FHABS_MAX_RESOURCE_AGE_DAYS to intentionally allow older resources, or override the URL with CLEAR_LAKE_FHABS_BLOOM_REPORTS_URL / CLEAR_LAKE_FHABS_RESULTS_URL."
  }
}

function Get-RecordField {
  param(
    [object]$Row,
    [string]$FieldName
  )

  $property = $Row.PSObject.Properties | Where-Object {
    $_.Name -eq $FieldName -or
    ($_.Name -replace '^[^\w]+', '') -eq $FieldName -or
    $_.Name -like "*$FieldName"
  } | Select-Object -First 1

  if ($property) {
    return $property.Value
  }

  return $null
}

function Normalize-Text {
  param(
    [string]$Value
  )

  if ([string]::IsNullOrWhiteSpace($Value)) {
    return ""
  }

  return ($Value.ToLowerInvariant() -replace '[^a-z0-9]+', ' ').Trim()
}

function Get-DistanceKm {
  param(
    [double]$Lat1,
    [double]$Lon1,
    [double]$Lat2,
    [double]$Lon2
  )

  $earthRadiusKm = 6371
  $dLat = ($Lat2 - $Lat1) * [Math]::PI / 180
  $dLon = ($Lon2 - $Lon1) * [Math]::PI / 180
  $rLat1 = $Lat1 * [Math]::PI / 180
  $rLat2 = $Lat2 * [Math]::PI / 180
  $a = [Math]::Sin($dLat / 2) * [Math]::Sin($dLat / 2) +
    [Math]::Cos($rLat1) * [Math]::Cos($rLat2) *
    [Math]::Sin($dLon / 2) * [Math]::Sin($dLon / 2)
  $c = 2 * [Math]::Atan2([Math]::Sqrt($a), [Math]::Sqrt(1 - $a))

  return $earthRadiusKm * $c
}

function Resolve-RegisteredSite {
  param(
    [object]$Row,
    [string]$Source = "FHABS"
  )

  $sourceId = Get-RecordField $Row "Bloom_Report_ID"
  $lat = Parse-Number (Get-RecordField $Row "Bloom_Latitude")
  $lon = Parse-Number (Get-RecordField $Row "Bloom_Longitude")
  $haystack = Normalize-Text (@(
    Get-RecordField $Row "Landmark"
    Get-RecordField $Row "Site"
    Get-RecordField $Row "Sample_Location"
    Get-RecordField $Row "Water_Body_Name"
    Get-RecordField $Row "Official_Water_Body_Name"
  ) -join " ")

  foreach ($site in $siteRegistry.sites | Where-Object { $_.source -eq $Source }) {
    if ($sourceId -and $site.sourceId -and $site.sourceId -eq $sourceId) {
      return [PSCustomObject]@{
        site = $site
        method = "source-id"
        distanceKm = 0
      }
    }

    foreach ($alias in @($site.aliases)) {
      $needle = Normalize-Text $alias

      if ($needle -and $haystack.Contains($needle)) {
        return [PSCustomObject]@{
          site = $site
          method = "alias"
          distanceKm = if ($null -ne $lat -and $null -ne $lon) {
            [math]::Round((Get-DistanceKm -Lat1 $lat -Lon1 $lon -Lat2 $site.latitude -Lon2 $site.longitude), 2)
          } else {
            $null
          }
        }
      }
    }
  }

  if ($null -eq $lat -or $null -eq $lon) {
    return $null
  }

  $nearest = $siteRegistry.sites |
    Where-Object { $_.source -eq $Source } |
    ForEach-Object {
      [PSCustomObject]@{
        site = $_
        distanceKm = Get-DistanceKm -Lat1 $lat -Lon1 $lon -Lat2 $_.latitude -Lon2 $_.longitude
      }
    } |
    Sort-Object distanceKm |
    Select-Object -First 1

  if ($nearest -and $nearest.distanceKm -le $nearest.site.matchRadiusKm) {
    return [PSCustomObject]@{
      site = $nearest.site
      method = "proximity"
      distanceKm = [math]::Round($nearest.distanceKm, 2)
    }
  }

  return $null
}

function Get-UsgsSeries {
  param(
    [string]$Site,
    [string]$ParameterCd,
    [string]$Period = "P30D"
  )

  $url = "https://waterservices.usgs.gov/nwis/dv/?format=json&sites=$Site&parameterCd=$ParameterCd&siteStatus=all&period=$Period"
  $response = Invoke-RestMethod -Uri $url -Headers $headers
  $series = $response.value.timeSeries | Where-Object {
    $_.variable.variableCode[0].value -eq $ParameterCd -and $_.values[0].value.Count -gt 0
  } | Select-Object -First 1

  if (-not $series) {
    throw "No USGS data returned for site $Site parameter $ParameterCd"
  }

  $values = $series.values[0].value | ForEach-Object {
    [PSCustomObject]@{
      value    = [double]$_.value
      dateTime = [datetime]$_.dateTime
    }
  }

  return [PSCustomObject]@{
    siteName     = $series.sourceInfo.siteName
    siteCode     = $series.sourceInfo.siteCode[0].value
    variableName = $series.variable.variableName
    unitCode     = $series.variable.unit.unitCode
    values       = $values
  }
}

function Get-ClearLakeRecords {
  param(
    [array]$Rows
  )

  return $Rows | Where-Object {
    (Get-RecordField $_ "Water_Body_Name") -match '^(?i)clear lake$' -or
    (Get-RecordField $_ "Official_Water_Body_Name") -match '^(?i)clear lake$' -or
    (Get-RecordField $_ "Case_Water_Body_Name") -match '^(?i)clear lake$'
  }
}

function Get-RecentUniqueLocations {
  param(
    [array]$Rows,
    [int]$Limit = 5
  )

  $seen = @{}
  $items = @()

  foreach ($row in $Rows) {
    $key = if ([string]::IsNullOrWhiteSpace($row.Landmark)) {
      "Unknown location"
    } else {
      $row.Landmark
    }

    if ($seen.ContainsKey($key)) {
      continue
    }

    $seen[$key] = $true
    $items += [ordered]@{
      landmark   = $key
      date       = $row.ObservationDate.ToString("MMMM d, yyyy")
      advisory   = if ([string]::IsNullOrWhiteSpace($row.Advisory_Recommended)) { "Unspecified" } else { $row.Advisory_Recommended }
      reportType = if ([string]::IsNullOrWhiteSpace($row.Report_Type)) { "Monitoring record" } else { $row.Report_Type }
    }

    if ($items.Count -ge $Limit) {
      break
    }
  }

  return $items
}

function Get-ArmName {
  param(
    [object]$Row
  )

  $match = Resolve-RegisteredSite -Row $Row

  if ($match) {
    return $match.site.arm
  }

  $text = @(
    $row.Landmark,
    $row.Water_Body_Name,
    $row.Official_Water_Body_Name,
    $row.Case_Water_Body_Name
  ) -join " "

  if ($text -match '(?i)oaks|clearlake oaks|clear lake keys|keys|elem|sulphur|blue heron|oa-|cache creek') {
    return "Oaks Arm"
  }

  if ($text -match '(?i)lower|jago|baylis|redbud|anderson marsh|lower lake|soda bay|wheeler point') {
    return "Lower Arm"
  }

  if ($text -match '(?i)upper|lakeport|nice|lucerne|rocky point|horseshoe|buckingham|kelseyville|cole creek') {
    return "Upper Arm"
  }

  $lat = Parse-Number (Get-RecordField $Row "Bloom_Latitude")
  $lon = Parse-Number (Get-RecordField $Row "Bloom_Longitude")

  if ($null -ne $lat -and $null -ne $lon) {
    return Get-ArmNameFromCoordinate -Latitude $lat -Longitude $lon
  }

  return "Needs Review"
}

function Parse-Number {
  param(
    [string]$Value
  )

  if ([string]::IsNullOrWhiteSpace($Value)) {
    return $null
  }

  $parsed = 0.0

  if ([double]::TryParse($Value, [System.Globalization.NumberStyles]::Float, [System.Globalization.CultureInfo]::InvariantCulture, [ref]$parsed)) {
    return $parsed
  }

  return $null
}

function Get-ArmNameFromCoordinate {
  param(
    [double]$Latitude,
    [double]$Longitude
  )

  if ($Latitude -lt 38.9 -or $Latitude -gt 39.14 -or $Longitude -lt -122.94 -or $Longitude -gt -122.59) {
    return "Needs Review"
  }

  if ($Longitude -gt -122.72 -and $Latitude -lt 39.05) {
    return "Oaks Arm"
  }

  if ($Latitude -lt 38.99 -or ($Longitude -gt -122.78 -and $Latitude -lt 39.02)) {
    return "Lower Arm"
  }

  return "Upper Arm"
}

function Convert-Series {
  param(
    [object]$Series,
    [string]$Label
  )

  return [ordered]@{
    label   = $Label
    station = "$($Series.siteName) / USGS $($Series.siteCode)"
    unit    = $Series.unitCode
    points  = @(
      $Series.values | ForEach-Object {
        [ordered]@{
          date  = $_.dateTime.ToString("yyyy-MM-dd")
          value = $_.value
        }
      }
    )
  }
}

function Convert-UsgsObservations {
  param(
    [object]$Series,
    [string]$ParameterId,
    [string]$ParameterName,
    [string]$SiteId
  )

  return @(
    $Series.values | ForEach-Object {
      [ordered]@{
        observationId = "usgs-$($Series.siteCode)-$ParameterId-$($_.dateTime.ToString('yyyyMMdd'))"
        source = "USGS"
        sourceRecordId = $Series.siteCode
        siteId = $SiteId
        siteName = $Series.siteName
        arm = ($siteRegistry.sites | Where-Object { $_.siteId -eq $SiteId } | Select-Object -First 1).arm
        observedDate = $_.dateTime.ToString("yyyy-MM-dd")
        parameterId = $ParameterId
        parameterName = $ParameterName
        value = $_.value
        unit = $Series.unitCode
        dataType = "daily-mean"
        qualityFlag = "provisional"
      }
    }
  )
}

function Convert-FhabsReport {
  param(
    [object]$Row
  )

  $lat = Parse-Number (Get-RecordField $Row "Bloom_Latitude")
  $lon = Parse-Number (Get-RecordField $Row "Bloom_Longitude")
  $siteMatch = Resolve-RegisteredSite -Row $Row
  $arm = if ($siteMatch) { $siteMatch.site.arm } else { Get-ArmName $Row }
  $reportId = Get-RecordField $Row "Bloom_Report_ID"

  return [ordered]@{
    reportId = $reportId
    source = "FHABS"
    sourceRecordId = $reportId
    siteId = if ($siteMatch) { $siteMatch.site.siteId } else { $null }
    siteName = if ($siteMatch) { $siteMatch.site.name } else { "Unmatched FHABS report" }
    matchMethod = if ($siteMatch) { $siteMatch.method } else { "heuristic" }
    assignmentStatus = if ($siteMatch) { $siteMatch.site.assignmentStatus } else { "unmatched-review-needed" }
    arm = $arm
    observationDate = Format-DateIso $Row.ObservationDate
    landmark = Get-RecordField $Row "Landmark"
    advisoryRecommended = Get-RecordField $Row "Advisory_Recommended"
    reportType = Get-RecordField $Row "Report_Type"
    caseId = Get-RecordField $Row "Case_ID"
    caseStatus = Get-RecordField $Row "Case_Status"
    latitude = $lat
    longitude = $lon
    hasPictures = Get-RecordField $Row "Has_Pictures"
    waterBodyType = Get-RecordField $Row "Water_Body_Type"
  }
}

function Convert-FhabsResultObservation {
  param(
    [object]$Row
  )

  $sampleDate = Parse-Date (Get-RecordField $Row "Sample_Date")
  $resultDate = Parse-Date (Get-RecordField $Row "Results_Date")
  $observedDate = if ($sampleDate) { $sampleDate } else { $resultDate }

  if (-not $observedDate) {
    return $null
  }

  $lat = Parse-Number (Get-RecordField $Row "Latitude")
  $lon = Parse-Number (Get-RecordField $Row "Longitude")

  if ($null -eq $lat -or $lat -eq 0) {
    $lat = Parse-Number (Get-RecordField $Row "Bloom_Latitude")
  }

  if ($null -eq $lon -or $lon -eq 0) {
    $lon = Parse-Number (Get-RecordField $Row "Bloom_Longitude")
  }

  $siteMatch = Resolve-RegisteredSite -Row $Row
  $arm = if ($siteMatch) { $siteMatch.site.arm } else { Get-ArmName $Row }
  $value = Parse-Number (Get-RecordField $Row "Measurement_Value")
  $analyte = Get-RecordField $Row "Analyte"
  $parameterName = if ([string]::IsNullOrWhiteSpace($analyte)) {
    Get-RecordField $Row "Analysis_Type"
  } else {
    $analyte
  }

  return [ordered]@{
    observationId = "fhabs-result-$(Get-RecordField $Row 'RESULT ID UNIQUE')"
    source = "FHABS"
    sourceRecordId = Get-RecordField $Row "Result_ID"
    reportId = Get-RecordField $Row "Bloom_Report_ID"
    siteId = if ($siteMatch) { $siteMatch.site.siteId } else { $null }
    siteName = if ($siteMatch) { $siteMatch.site.name } else { "Unmatched FHABS result" }
    matchMethod = if ($siteMatch) { $siteMatch.method } else { "heuristic" }
    assignmentStatus = if ($siteMatch) { $siteMatch.site.assignmentStatus } else { "unmatched-review-needed" }
    arm = $arm
    observedDate = $observedDate.ToString("yyyy-MM-dd")
    parameterId = Normalize-Text $parameterName
    parameterName = $parameterName
    value = $value
    unit = Get-RecordField $Row "Measurement_Unit"
    dataType = Get-RecordField $Row "Sample_Type"
    method = Get-RecordField $Row "Method"
    analyteClass = Get-RecordField $Row "Analyte_Class"
    latitude = $lat
    longitude = $lon
  }
}

$lakeLevel = Get-UsgsSeries -Site "11450000" -ParameterCd "00065"
$coleCreek = Get-UsgsSeries -Site "11449820" -ParameterCd "00060"

$fhabsPackage = $null
if (
  [string]::IsNullOrWhiteSpace($env:CLEAR_LAKE_FHABS_BLOOM_REPORTS_URL) -or
  [string]::IsNullOrWhiteSpace($env:CLEAR_LAKE_FHABS_RESULTS_URL)
) {
  $fhabsPackage = Get-FhabsPackage -DatasetId $fhabsDatasetId
}

$bloomReportsUrl = Resolve-FhabsResourceUrl `
  -Package $fhabsPackage `
  -ResourceId $fhabsBloomReportsResourceId `
  -NamePattern "BLOOM REPORTS" `
  -OverrideUrl $env:CLEAR_LAKE_FHABS_BLOOM_REPORTS_URL

$resultsUrl = Resolve-FhabsResourceUrl `
  -Package $fhabsPackage `
  -ResourceId $fhabsResultsResourceId `
  -NamePattern "RESULTS" `
  -OverrideUrl $env:CLEAR_LAKE_FHABS_RESULTS_URL

Assert-FhabsResourceFreshness `
  -Label "Bloom reports" `
  -Url $bloomReportsUrl `
  -MaxAgeDays $fhabsMaxResourceAgeDays

Assert-FhabsResourceFreshness `
  -Label "Results" `
  -Url $resultsUrl `
  -MaxAgeDays $fhabsMaxResourceAgeDays

$bloomReportsFreshness = Get-FhabsResourceFreshness -Url $bloomReportsUrl
$resultsFreshness = Get-FhabsResourceFreshness -Url $resultsUrl

$bloomReportsRaw = (Invoke-WebRequest `
  -Uri $bloomReportsUrl `
  -Headers $headers `
  -UseBasicParsing).Content

$resultsRaw = (Invoke-WebRequest `
  -Uri $resultsUrl `
  -Headers $headers `
  -UseBasicParsing).Content

$bloomReports = $bloomReportsRaw.TrimStart([char]0xFEFF) | ConvertFrom-Csv

$results = $resultsRaw.TrimStart([char]0xFEFF) | ConvertFrom-Csv

$clearReports = Get-ClearLakeRecords -Rows $bloomReports | ForEach-Object {
  $_ | Add-Member -NotePropertyName ObservationDate -NotePropertyValue (Parse-Date $_.Observation_Date) -PassThru
}

$clearReportsSorted = $clearReports | Where-Object { $_.ObservationDate } | Sort-Object ObservationDate -Descending
$latestReport = $clearReportsSorted | Select-Object -First 1
$oneYearWindow = $clearReportsSorted | Where-Object { $_.ObservationDate -ge (Get-Date).AddYears(-1) }
$armSummaries = @("Upper Arm", "Lower Arm", "Oaks Arm", "Needs Review") | ForEach-Object {
  $arm = $_
  $rows = @($oneYearWindow | Where-Object { (Get-ArmName $_) -eq $arm })
  $latest = $rows | Sort-Object ObservationDate -Descending | Select-Object -First 1

  [ordered]@{
    arm         = $arm
    reportCount = $rows.Count
    latest      = if ($latest) {
      [ordered]@{
        date     = $latest.ObservationDate.ToString("MMMM d, yyyy")
        landmark = if ([string]::IsNullOrWhiteSpace($latest.Landmark)) { "Unknown location" } else { $latest.Landmark }
        advisory = if ([string]::IsNullOrWhiteSpace($latest.Advisory_Recommended)) { "Unspecified" } else { $latest.Advisory_Recommended }
      }
    } else {
      $null
    }
  }
}

$advisoryMix = $oneYearWindow |
  Group-Object Advisory_Recommended |
  Sort-Object Count -Descending |
  Select-Object -First 4 |
  ForEach-Object {
    $label = if ([string]::IsNullOrWhiteSpace($_.Name)) { "Unspecified" } else { $_.Name }
    [ordered]@{
      label = $label
      count = $_.Count
      note  = "Reports in the last year of Clear Lake FHABS data carrying this recommendation."
    }
  }

$clearResults = Get-ClearLakeRecords -Rows $results | ForEach-Object {
  $sampleDate = Parse-Date $_.Sample_Date
  $resultDate = Parse-Date $_.Results_Date
  $sortDate = if ($sampleDate) { $sampleDate } else { $resultDate }
  $_ | Add-Member -NotePropertyName SortDate -NotePropertyValue $sortDate -PassThru
}

$latestResult = $clearResults |
  Where-Object { $_.SortDate } |
  Sort-Object SortDate -Descending |
  Select-Object -First 1

$lakeFirst = $lakeLevel.values | Select-Object -First 1
$lakeLast = $lakeLevel.values | Select-Object -Last 1
$lakeRumseyFeet = [math]::Round($lakeLast.value, 2)
$lakeElevationFeet = Convert-RumseyToElevationFeet -RumseyFeet $lakeRumseyFeet
$lakeDelta = [math]::Round(($lakeLast.value - $lakeFirst.value), 2)
$lakeTrend = if ($lakeDelta -gt 0.03) {
  "up"
} elseif ($lakeDelta -lt -0.03) {
  "down"
} else {
  "nearly flat"
}

$creekLast = $coleCreek.values | Select-Object -Last 1
$creekPeak = ($coleCreek.values | Measure-Object -Property value -Maximum).Maximum

$openCases = (
  $clearReports |
    Where-Object { $_.Case_Status -match '^(?i)(open|ongoing)$' } |
    ForEach-Object { Get-RecordField $_ "Bloom_Report_ID" } |
    Where-Object { $_ } |
    Select-Object -Unique
).Count
$recentLocations = Get-RecentUniqueLocations -Rows $clearReportsSorted
$mapMarkers = @(
  $oneYearWindow |
    ForEach-Object {
      $lat = Parse-Number (Get-RecordField $_ "Bloom_Latitude")
      $lon = Parse-Number (Get-RecordField $_ "Bloom_Longitude")
      $hasValidCoordinates = (
        $null -ne $lat -and
        $null -ne $lon -and
        $lat -ge 38.9 -and
        $lat -le 39.14 -and
        $lon -ge -122.94 -and
        $lon -le -122.59
      )

      if ($hasValidCoordinates) {
        $siteMatch = Resolve-RegisteredSite -Row $_
        $arm = if ($siteMatch) {
          $siteMatch.site.arm
        } else {
          Get-ArmName $_
        }

        [ordered]@{
          id         = Get-RecordField $_ "Bloom_Report_ID"
          siteId     = if ($siteMatch) { $siteMatch.site.siteId } else { $null }
          siteName   = if ($siteMatch) { $siteMatch.site.name } else { "Unmatched FHABS report" }
          matchMethod = if ($siteMatch) { $siteMatch.method } else { "heuristic" }
          assignmentStatus = if ($siteMatch) { $siteMatch.site.assignmentStatus } else { "unmatched-review-needed" }
          matchDistanceKm = if ($siteMatch) { $siteMatch.distanceKm } else { $null }
          landmark   = if ([string]::IsNullOrWhiteSpace($_.Landmark)) { "Unknown location" } else { $_.Landmark }
          date       = $_.ObservationDate.ToString("MMMM d, yyyy")
          isoDate    = $_.ObservationDate.ToString("yyyy-MM-dd")
          advisory   = if ([string]::IsNullOrWhiteSpace($_.Advisory_Recommended)) { "Unspecified" } else { $_.Advisory_Recommended }
          reportType = if ([string]::IsNullOrWhiteSpace($_.Report_Type)) { "Monitoring record" } else { $_.Report_Type }
          arm        = $arm
          latitude   = $lat
          longitude  = $lon
        }
      }
    } |
    Sort-Object isoDate -Descending |
    Select-Object -First 16
)
$matchedMarkerCount = @($mapMarkers | Where-Object { $_.siteId }).Count
$unmatchedMarkerCount = @($mapMarkers | Where-Object { -not $_.siteId }).Count
$matchMethodGroups = @(
  $mapMarkers |
    Group-Object -Property { $_.matchMethod } |
    Sort-Object Count -Descending
)
$matchMethods = if ($matchMethodGroups.Count -gt 0) {
  ($matchMethodGroups | ForEach-Object { "{0}: {1}" -f $_.Name, $_.Count }) -join "; "
} else {
  "none"
}

$normalizedSites = [ordered]@{
  generatedAt = (Get-Date).ToString("o")
  schemaVersion = 1
  recordCount = $siteRegistry.sites.Count
  sites = @(
    $siteRegistry.sites |
      Sort-Object siteId |
      ForEach-Object {
        [ordered]@{
          siteId = $_.siteId
          name = $_.name
          source = $_.source
          sourceId = $_.sourceId
          siteType = $_.siteType
          aliases = @($_.aliases)
          latitude = $_.latitude
          longitude = $_.longitude
          arm = $_.arm
          assignmentStatus = $_.assignmentStatus
          matchRadiusKm = $_.matchRadiusKm
        }
      }
  )
}

$normalizedReports = [ordered]@{
  generatedAt = (Get-Date).ToString("o")
  schemaVersion = 1
  source = "FHABS bloom reports"
  recordCount = $clearReportsSorted.Count
  records = @(
    $clearReportsSorted | ForEach-Object {
      Convert-FhabsReport -Row $_
    }
  )
}

$usgsObservations = @(
  Convert-UsgsObservations -Series $lakeLevel -ParameterId "00065" -ParameterName "Gage height" -SiteId "usgs-11450000"
  Convert-UsgsObservations -Series $coleCreek -ParameterId "00060" -ParameterName "Discharge" -SiteId "usgs-11449820"
)

$fhabsObservations = @(
  $clearResults |
    ForEach-Object {
      Convert-FhabsResultObservation -Row $_
    } |
    Where-Object { $_ }
)

$normalizedObservations = [ordered]@{
  generatedAt = (Get-Date).ToString("o")
  schemaVersion = 1
  sources = @("USGS daily values", "FHABS results")
  recordCount = $usgsObservations.Count + $fhabsObservations.Count
  records = @($usgsObservations + $fhabsObservations)
}

$arms = @("Upper Arm", "Lower Arm", "Oaks Arm", "Needs Review")
$yearlyReportTrend = @(
  $clearReportsSorted |
    Group-Object { $_.ObservationDate.Year } |
    Sort-Object Name |
    ForEach-Object {
      $yearRows = @($_.Group)
      $armCounts = [ordered]@{}

      foreach ($arm in $arms) {
        $armCounts[$arm] = @($yearRows | Where-Object { (Get-ArmName $_) -eq $arm }).Count
      }

      [ordered]@{
        year = [int]$_.Name
        total = $yearRows.Count
        arms = $armCounts
      }
    }
)

$advisoryDistribution = @(
  $arms | ForEach-Object {
    $arm = $_
    $armRows = @($clearReportsSorted | Where-Object { (Get-ArmName $_) -eq $arm })
    $categories = @(
      $armRows |
        Group-Object Advisory_Recommended |
        Sort-Object Count -Descending |
        Select-Object -First 6 |
        ForEach-Object {
          [ordered]@{
            label = if ([string]::IsNullOrWhiteSpace($_.Name)) { "Unspecified" } else { $_.Name }
            count = $_.Count
          }
        }
    )

    [ordered]@{
      arm = $arm
      total = $armRows.Count
      categories = $categories
    }
  }
)

$observationCoverage = @(
  $normalizedObservations.records |
    Group-Object { "$($_.source)|$($_.parameterName)|$($_.siteId)" } |
    Sort-Object Count -Descending |
    ForEach-Object {
      $rows = @($_.Group)
      $dates = @($rows | ForEach-Object { $_.observedDate } | Where-Object { $_ } | Sort-Object)
      $first = $rows | Select-Object -First 1

      [ordered]@{
        source = $first.source
        siteId = $first.siteId
        siteName = $first.siteName
        arm = $first.arm
        parameterName = $first.parameterName
        unit = $first.unit
        count = $rows.Count
        firstObservedDate = if ($dates.Count) { $dates[0] } else { $null }
        lastObservedDate = if ($dates.Count) { $dates[-1] } else { $null }
      }
    }
)

$analytics = [ordered]@{
  generatedAt = (Get-Date).ToString("o")
  schemaVersion = 1
  reportTrendByYear = $yearlyReportTrend
  advisoryDistributionByArm = $advisoryDistribution
  observationCoverage = $observationCoverage
}

Write-JsonFile -Path $reportsOutputPath -Data $normalizedReports
Write-JsonFile -Path $observationsOutputPath -Data $normalizedObservations
Write-JsonFile -Path $normalizedSitesOutputPath -Data $normalizedSites
Write-JsonFile -Path $analyticsOutputPath -Data $analytics

$dataProducts = @(
  [ordered]@{
    name = "Normalized reports"
    file = "data/reports.json"
    recordCount = $normalizedReports.recordCount
    description = "FHABS Clear Lake bloom reports with site registry matches, arm assignments, coordinates, advisories, and case metadata."
  },
  [ordered]@{
    name = "Normalized observations"
    file = "data/observations.json"
    recordCount = $normalizedObservations.recordCount
    description = "USGS daily hydrology observations plus FHABS result records normalized into one observation-shaped table."
  },
  [ordered]@{
    name = "Normalized sites"
    file = "data/sites-normalized.json"
    recordCount = $normalizedSites.recordCount
    description = "Reviewed starter site registry exported with stable IDs, aliases, coordinates, arms, and assignment status."
  },
  [ordered]@{
    name = "Historical analytics"
    file = "data/analytics.json"
    recordCount = $yearlyReportTrend.Count + $advisoryDistribution.Count + $observationCoverage.Count
    description = "Precomputed arm/year report trends, advisory distributions, and observation coverage summaries for dashboard charts."
  },
  [ordered]@{
    name = "Snapshot manifest"
    file = "data/manifest.json"
    recordCount = 4
    description = "Machine-readable refresh manifest with source health, source row counts, output row counts, and currentness metadata."
  }
)

$sourceStatuses = @(
  [ordered]@{
    id = "usgs-lake-level"
    label = "USGS Lakeport lake level"
    source = "USGS"
    status = if (@($lakeLevel.values).Count -gt 0) { "ok" } else { "unavailable" }
    rowCount = @($lakeLevel.values).Count
    latestObservationDate = Format-DateIso (($lakeLevel.values | Select-Object -Last 1).dateTime)
    station = "11450000"
    parameter = "00065"
    note = "USGS daily values used for the Lakeport lake-level card and hydrology series."
  },
  [ordered]@{
    id = "usgs-cole-creek-discharge"
    label = "USGS Cole Creek discharge"
    source = "USGS"
    status = if (@($coleCreek.values).Count -gt 0) { "ok" } else { "unavailable" }
    rowCount = @($coleCreek.values).Count
    latestObservationDate = Format-DateIso (($coleCreek.values | Select-Object -Last 1).dateTime)
    station = "11449820"
    parameter = "00060"
    note = "USGS daily values used for tributary-flow context and hydrology series."
  },
  [ordered]@{
    id = "fhabs-bloom-reports"
    label = "FHABS bloom reports"
    source = "California Water Boards FHABS"
    status = if ($latestReport) { "ok" } else { "unavailable" }
    rowCount = @($bloomReports).Count
    clearLakeRowCount = @($clearReports).Count
    latestObservationDate = if ($latestReport) { Format-DateIso $latestReport.ObservationDate } else { $null }
    resourceUrl = $bloomReportsUrl
    resourceDate = if ($bloomReportsFreshness.resourceDate) { $bloomReportsFreshness.resourceDate.ToString("yyyy-MM-dd") } else { $null }
    resourceAgeDays = $bloomReportsFreshness.ageDays
    note = "Public report records filtered to Clear Lake and normalized into reports, map markers, arm summaries, and report-pattern analytics."
  },
  [ordered]@{
    id = "fhabs-results"
    label = "FHABS lab results"
    source = "California Water Boards FHABS"
    status = if ($latestResult) { "ok" } else { "unavailable" }
    rowCount = @($results).Count
    clearLakeRowCount = @($clearResults).Count
    latestObservationDate = if ($latestResult) { Format-DateIso $latestResult.SortDate } else { $null }
    resourceUrl = $resultsUrl
    resourceDate = if ($resultsFreshness.resourceDate) { $resultsFreshness.resourceDate.ToString("yyyy-MM-dd") } else { $null }
    resourceAgeDays = $resultsFreshness.ageDays
    note = "Public lab-linked result records filtered to Clear Lake and normalized into observation-shaped records."
  }
)

$manifest = [ordered]@{
  generatedAt = (Get-Date).ToString("o")
  schemaVersion = 1
  dashboard = "Clear Lake Watch"
  status = if (@($sourceStatuses | Where-Object { $_.status -ne "ok" }).Count -gt 0) { "partial" } else { "ok" }
  sourceFreshnessMaxAgeDays = $fhabsMaxResourceAgeDays
  sources = $sourceStatuses
  outputs = @(
    [ordered]@{
      file = "data/live.json"
      recordCount = 5 + @($mapMarkers).Count
      description = "Dashboard live snapshot cards, map markers, analytics bundle, and data product index."
    },
    [ordered]@{
      file = "data/reports.json"
      recordCount = $normalizedReports.recordCount
      description = "Normalized FHABS Clear Lake report records."
    },
    [ordered]@{
      file = "data/observations.json"
      recordCount = $normalizedObservations.recordCount
      description = "Normalized USGS and FHABS observation records."
    },
    [ordered]@{
      file = "data/sites-normalized.json"
      recordCount = $normalizedSites.recordCount
      description = "Normalized stable site registry export."
    },
    [ordered]@{
      file = "data/analytics.json"
      recordCount = $yearlyReportTrend.Count + $advisoryDistribution.Count + $observationCoverage.Count
      description = "Precomputed reporting-pattern and observation-coverage analytics."
    }
  )
  notes = @(
    "Observation dates may be older than the dashboard generation time.",
    "Lakeport lake-level values are shown as feet Rumsey, with approximate elevation calculated using Zero Rumsey = 1318.256 ft above mean sea level.",
    "FHABS report counts represent reporting activity, not direct bloom intensity.",
    "This manifest describes the generated public-data snapshot and is not official public-health guidance."
  )
}

$latestReportCard = if ($latestReport) {
  $latestReportLandmark = Get-RecordField $latestReport "Landmark"
  $latestReportAdvisory = Get-RecordField $latestReport "Advisory_Recommended"

  [ordered]@{
    label = "Latest Clear Lake FHABS report"
    value = $latestReport.ObservationDate.ToString("MMMM d, yyyy")
    note  = "$(if ([string]::IsNullOrWhiteSpace($latestReportLandmark)) { 'Unknown location' } else { $latestReportLandmark }) was reported as '$(if ([string]::IsNullOrWhiteSpace($latestReportAdvisory)) { 'Unspecified' } else { $latestReportAdvisory })' in FHABS. Open or ongoing Clear Lake reports in the file: $openCases."
  }
} else {
  [ordered]@{
    label = "Latest Clear Lake FHABS report"
    value = "Unavailable"
    note  = "No dated Clear Lake FHABS report was found in the current bloom-report resource. Treat this feed as unavailable until the next successful source review."
  }
}

$latestResultCard = if ($latestResult) {
  $latestResultLandmark = Get-RecordField $latestResult "Landmark"
  $latestResultAnalyte = Get-RecordField $latestResult "Analyte"
  $latestResultMethod = Get-RecordField $latestResult "Method"

  [ordered]@{
    label = "Latest FHABS lab-linked sample"
    value = $latestResult.SortDate.ToString("MMMM d, yyyy")
    note  = "$(if ([string]::IsNullOrWhiteSpace($latestResultLandmark)) { 'Unknown location' } else { $latestResultLandmark }); analyte $(if ([string]::IsNullOrWhiteSpace($latestResultAnalyte)) { 'not specified' } else { $latestResultAnalyte }) via $(if ([string]::IsNullOrWhiteSpace($latestResultMethod)) { 'method not specified' } else { $latestResultMethod }). This dataset appears to lag the current report stream."
  }
} else {
  [ordered]@{
    label = "Latest FHABS lab-linked sample"
    value = "Unavailable"
    note  = "No dated Clear Lake FHABS result was found in the current lab-results resource. This may reflect source lag or a temporary empty feed."
  }
}

$payload = [ordered]@{
  generatedAt = (Get-Date).ToString("o")
  liveCards   = @(
    [ordered]@{
      label = "Lake level at Lakeport"
      value = ("{0:N2} ft Rumsey`n{1:N2} ft above sea level" -f $lakeRumseyFeet, $lakeElevationFeet)
      note  = "USGS station 11450000 on $($lakeLast.dateTime.ToString('MMMM d, yyyy')); elevation shown using Zero Rumsey = $rumseyZeroElevationFt ft. 30-day trend $lakeTrend ($lakeDelta ft)."
    },
    [ordered]@{
      label = "Cole Creek discharge"
      value = ("{0:N2} cfs" -f $creekLast.value)
      note  = "USGS station 11449820 on $($creekLast.dateTime.ToString('MMMM d, yyyy')); 30-day peak was $([math]::Round($creekPeak, 2)) cfs."
    },
    $latestReportCard,
    $latestResultCard,
    [ordered]@{
      label = "Registry coverage"
      value = "$matchedMarkerCount / $($mapMarkers.Count)"
      note  = "Recent coordinate markers matched to the site registry. Unmatched: $unmatchedMarkerCount. Methods: $matchMethods."
    }
  )
  hydrologySeries = @(
    Convert-Series -Series $lakeLevel -Label "Lake level"
    Convert-Series -Series $coleCreek -Label "Cole Creek discharge"
  )
  armSummaries = $armSummaries
  mapMarkers = $mapMarkers
  analytics = $analytics
  dataProducts = $dataProducts
  advisoryMix = $advisoryMix
  recentLocations = $recentLocations
}

Write-JsonFile -Path $manifestOutputPath -Data $manifest
Write-Output "Wrote $manifestOutputPath"
Write-JsonFile -Path $outputPath -Data $payload
Write-Output "Wrote $outputPath"
