# USGS Water Data OGC API v1: daily mean, one pinned primary series per station.
# Keep this mapping explicit; never select another series just because it has rows.
function Get-UsgsSeries {
  param(
    [Parameter(Mandatory)] [ValidateSet('11450000', '11449820')] [string]$Site,
    [Parameter(Mandatory)] [datetime]$StartDate,
    [Parameter(Mandatory)] [datetime]$EndDate,
    [Parameter(Mandatory)] [hashtable]$Headers
  )

  $station = switch ($Site) {
    '11450000' {
      @{
        ParameterCode = '00065'
        SeriesId = 'faffcc2acf7c47b295a49d7e295a8a34'
        ApiUnit = 'ft'
        UnitCode = 'ft'
        SiteName = 'CLEAR LK A LAKEPORT CA'
        VariableName = 'Gage height, feet'
      }
    }
    '11449820' {
      @{
        ParameterCode = '00060'
        SeriesId = '2e676501fea94713a03e6dea33a58f07'
        ApiUnit = 'ft^3/s'
        UnitCode = 'ft3/s'
        SiteName = 'COLE C A KELSEYVILLE CA'
        VariableName = 'Discharge, cubic feet per second'
      }
    }
  }
  $culture = [Globalization.CultureInfo]::InvariantCulture
  $start = $StartDate.Date
  $end = $EndDate.Date
  if ($end -lt $start -or ($end - $start).Days -ge 30) {
    throw 'USGS daily request requires at most 30 inclusive calendar dates.'
  }
  $location = "USGS-$Site"
  $range = '{0}%2F{1}' -f $start.ToString('yyyy-MM-dd', $culture), $end.ToString('yyyy-MM-dd', $culture)
  $url = 'https://api.waterdata.usgs.gov/ogcapi/v1/collections/daily/items?f=json&limit=100&monitoring_location_id={0}&parameter_code={1}&statistic_id=00003&time_series_id={2}&datetime={3}' -f $location, $station.ParameterCode, $station.SeriesId, $range
  $response = Invoke-RestMethod -Uri $url -Headers $Headers -TimeoutSec 30 -MaximumRedirection 0 -ErrorAction Stop

  if ($response.type -isnot [string] -or $response.type -cne 'FeatureCollection' -or $response.features -isnot [array] -or $response.features.Count -eq 0) {
    throw "USGS daily response for $Site must be a nonempty FeatureCollection."
  }
  if ($response.links -isnot [array] -or $response.links.Count -eq 0) {
    throw "USGS daily response for $Site has missing links."
  }
  $hasSelfLink = $false
  foreach ($link in $response.links) {
    if ($link.rel -isnot [string] -or [string]::IsNullOrWhiteSpace($link.rel) -or $link.rel -match '\s' -or
        $link.href -isnot [string] -or [string]::IsNullOrWhiteSpace($link.href)) {
      throw "USGS daily response for $Site has a malformed link."
    }
    if ($link.rel -in @('next', 'prev')) {
      throw "USGS daily response for $Site has unexpected pagination."
    }
    if ($link.rel -eq 'self') {
      $hasSelfLink = $true
    }
  }
  if (-not $hasSelfLink) {
    throw "USGS daily response for $Site has no self link."
  }
  if (($response.numberReturned -isnot [int] -and $response.numberReturned -isnot [long]) -or
      $response.numberReturned -ne $response.features.Count) {
    throw "USGS daily response for $Site has mismatched numberReturned."
  }
  $numberMatched = $response.PSObject.Properties['numberMatched']
  if ($null -ne $numberMatched) {
    $matched = $numberMatched.Value
    if (($matched -isnot [int] -and $matched -isnot [long]) -or $matched -ne $response.numberReturned) {
      throw "USGS daily response for $Site has invalid or mismatched numberMatched."
    }
  }

  $seen = @{}
  $values = foreach ($feature in $response.features) {
    $p = $feature.properties
    if ($feature.type -isnot [string] -or $feature.type -cne 'Feature' -or $null -eq $p) {
      throw "USGS daily response for $Site has invalid feature properties."
    }
    if ($p.monitoring_location_id -isnot [string] -or $p.monitoring_location_id -cne $location -or
        $p.parameter_code -isnot [string] -or $p.parameter_code -cne $station.ParameterCode -or
        $p.statistic_id -isnot [string] -or $p.statistic_id -cne '00003' -or
        $p.time_series_id -isnot [string] -or $p.time_series_id -cne $station.SeriesId) {
      throw "USGS daily response for $Site has unexpected series identity."
    }
    if ($p.unit_of_measure -isnot [string] -or $p.unit_of_measure -cne $station.ApiUnit) {
      throw "USGS daily response for $Site has an unexpected unit."
    }

    $date = [datetime]::MinValue
    if ($p.time -isnot [string] -or $p.time -cnotmatch '^[0-9]{4}-[0-9]{2}-[0-9]{2}$' -or
        -not [datetime]::TryParseExact($p.time, 'yyyy-MM-dd', $culture, [Globalization.DateTimeStyles]::None, [ref]$date) -or
        $date -lt $start -or $date -gt $end) {
      throw "USGS daily response for $Site has an invalid or out-of-window observation date."
    }
    if ($seen.ContainsKey($p.time)) {
      throw "USGS daily response for $Site has a duplicate observation date ($($p.time))."
    }
    $seen[$p.time] = $true

    $valueProperty = $p.PSObject.Properties['value']
    if ($null -eq $valueProperty) {
      throw "USGS daily response for $Site has a missing value field on $($p.time)."
    }
    # USGS uses JSON null for a missing reading. Leave that date out of the series.
    $rawValue = $valueProperty.Value
    if ($null -eq $rawValue) {
      continue
    }

    $value = [double]0
    if ($rawValue -isnot [string] -or $rawValue -cnotmatch '^[+-]?(?:[0-9]+(?:\.[0-9]*)?|\.[0-9]+)(?:[eE][+-]?[0-9]+)?$' -or
        -not [double]::TryParse($rawValue, [Globalization.NumberStyles]::Float, $culture, [ref]$value) -or
        [double]::IsNaN($value) -or [double]::IsInfinity($value)) {
      throw "USGS daily response for $Site has a non-numeric value on $($p.time)."
    }
    [pscustomobject]@{
      value = $value
      dateTime = $date
      approvalStatus = $p.approval_status
      qualifier = $p.qualifier
    }
  }
  if ($null -eq $values) {
    throw "USGS daily response for $Site has no usable observations."
  }

  [pscustomobject]@{
    siteName = $station.SiteName
    siteCode = $Site
    variableName = $station.VariableName
    unitCode = $station.UnitCode
    values = @($values | Sort-Object -Property dateTime)
  }
}
