$ErrorActionPreference = 'Stop'
$helperPath = Join-Path $PSScriptRoot '../scripts/refresh-live-data.usgs.ps1'
if (-not (Test-Path $helperPath -PathType Leaf)) {
  throw 'Expected the v1 USGS provider helper, but it does not exist yet.'
}
. $helperPath

function New-ColeFeature {
  param([string]$Date, $Value)
  [pscustomobject]@{
    type = 'Feature'
    properties = [pscustomobject]@{
      monitoring_location_id = 'USGS-11449820'
      parameter_code = '00060'
      statistic_id = '00003'
      time_series_id = '2e676501fea94713a03e6dea33a58f07'
      unit_of_measure = 'ft^3/s'
      time = $Date
      value = $Value
      approval_status = 'Provisional'
      qualifier = $null
    }
  }
}

function New-Page {
  [pscustomobject]@{
    type = 'FeatureCollection'
    features = @((New-ColeFeature '2026-11-14' '0.00'), (New-ColeFeature '2026-11-11' '0.00'))
    numberReturned = 2
    links = @([pscustomobject]@{ rel = 'self'; href = 'https://api.waterdata.usgs.gov/ogcapi/v1/collections/daily/items' })
  }
}
function Invoke-RestMethod {
  param($Uri, $Headers, $TimeoutSec, $MaximumRedirection, $ErrorAction)
  $script:request = $Uri
  if ($script:networkFailure) { throw 'HTTP 503 fixture' }
  $script:fixture
}
function Assert-Equal {
  param($Actual, $Expected, [string]$Label)
  if ($Actual -cne $Expected) { throw "${Label}: expected '$Expected', got '$Actual'" }
}
function Get-FixtureSeries {
  Get-UsgsSeries -Site '11449820' -StartDate ([datetime]'2026-11-11') -EndDate ([datetime]'2026-11-14') -Headers @{}
}
function Assert-Rejected {
  param([scriptblock]$Mutate, [string]$Expected)
  $script:fixture = New-Page
  & $Mutate
  try { $null = Get-FixtureSeries }
  catch {
    if ($_.Exception.Message -notmatch $Expected) { throw }
    return
  }
  throw "Expected rejection matching '$Expected'."
}

$networkFailure = $false
$fixture = New-Page
$fixture | Add-Member -NotePropertyName numberMatched -NotePropertyValue 2
$fixture.features[0].properties.approval_status = 'Approved'
$fixture.features[0].properties.qualifier = 'e'
$series = Get-FixtureSeries
Assert-Equal $series.siteCode '11449820' 'Cole site code'
Assert-Equal $series.siteName 'COLE C A KELSEYVILLE CA' 'Cole display name'
Assert-Equal $series.unitCode 'ft3/s' 'Cole public unit'
Assert-Equal (($series.values | ForEach-Object { $_.dateTime.ToString('yyyy-MM-dd') }) -join ',') '2026-11-11,2026-11-14' 'Sorted date-only gaps'
Assert-Equal $series.values[0].value 0 'Observed zero'
Assert-Equal $series.values[1].approvalStatus 'Approved' 'Upstream approval metadata'
Assert-Equal $series.values[1].qualifier 'e' 'Upstream qualifier metadata'
Assert-Equal $request 'https://api.waterdata.usgs.gov/ogcapi/v1/collections/daily/items?f=json&limit=100&monitoring_location_id=USGS-11449820&parameter_code=00060&statistic_id=00003&time_series_id=2e676501fea94713a03e6dea33a58f07&datetime=2026-11-11%2F2026-11-14' 'Pinned request'
$fixture = New-Page
foreach ($f in $fixture.features) {
  $f.properties.monitoring_location_id = 'USGS-11450000'
  $f.properties.parameter_code = '00065'
  $f.properties.time_series_id = 'faffcc2acf7c47b295a49d7e295a8a34'
  $f.properties.unit_of_measure = 'ft'
  $f.properties.value = '7.50'
}
$series = Get-UsgsSeries -Site '11450000' -StartDate ([datetime]'2026-11-11') -EndDate ([datetime]'2026-11-14') -Headers @{}
Assert-Equal $series.unitCode 'ft' 'Lakeport public unit'
Assert-Equal $series.values[0].value 7.5 'Lakeport decimal'
Assert-Equal $request 'https://api.waterdata.usgs.gov/ogcapi/v1/collections/daily/items?f=json&limit=100&monitoring_location_id=USGS-11450000&parameter_code=00065&statistic_id=00003&time_series_id=faffcc2acf7c47b295a49d7e295a8a34&datetime=2026-11-11%2F2026-11-14' 'Lakeport pinned request'

$fixture = New-Page
$fixture.features += (New-ColeFeature '2026-11-13' $null)
$fixture.numberReturned = 3
$fixture | Add-Member -NotePropertyName numberMatched -NotePropertyValue 3
$series = Get-FixtureSeries
Assert-Equal (($series.values | ForEach-Object { $_.dateTime.ToString('yyyy-MM-dd') }) -join ',') '2026-11-11,2026-11-14' 'Null observation leaves a date gap'
Assert-Equal $series.values[0].value 0 'Observed zero remains in a page with a gap'

Assert-Rejected { $script:fixture.features = @(); $script:fixture.numberReturned = 0 } 'nonempty'
Assert-Rejected { $script:fixture.links += [pscustomobject]@{ rel = 'next'; href = '?offset=2' } } 'pagination'
Assert-Rejected { $script:fixture.links += [pscustomobject]@{ rel = 'prev'; href = '?offset=0' } } 'pagination'
Assert-Rejected { $script:fixture.numberReturned = 3 } 'numberReturned'
Assert-Rejected { $script:fixture | Add-Member -NotePropertyName numberMatched -NotePropertyValue 3 } 'numberMatched'
Assert-Rejected { $script:fixture | Add-Member -NotePropertyName numberMatched -NotePropertyValue 1 } 'numberMatched'
Assert-Rejected { $script:fixture | Add-Member -NotePropertyName numberMatched -NotePropertyValue '2' } 'numberMatched'
Assert-Rejected { $script:fixture | Add-Member -NotePropertyName numberMatched -NotePropertyValue $null } 'numberMatched'
Assert-Rejected { $script:fixture.links = @() } 'links'
Assert-Rejected { $script:fixture.links += [pscustomobject]@{ href = '?offset=2' } } 'link'
Assert-Rejected { $script:fixture.links[0].href = $null } 'link'
Assert-Rejected { $script:fixture.links[0].rel = 'collection' } 'self'
Assert-Rejected { $script:fixture.features[0] = $null } 'properties'
Assert-Rejected { $script:fixture.features[0].properties.monitoring_location_id = 'USGS-99999999' } 'identity'
Assert-Rejected { $script:fixture.features[0].properties.monitoring_location_id = @('USGS-11449820') } 'identity'
Assert-Rejected { $script:fixture.features[0].properties.parameter_code = 60 } 'identity'
Assert-Rejected { $script:fixture.features[0].properties.parameter_code = '00065' } 'identity'
Assert-Rejected { $script:fixture.features[0].properties.statistic_id = '00001' } 'identity'
Assert-Rejected { $script:fixture.features[0].properties.time_series_id = 'alternate' } 'identity'
Assert-Rejected { $script:fixture.features[0].properties.unit_of_measure = 'm^3/s' } 'unit'
Assert-Rejected { $script:fixture.features[0].properties.time = '2026-11-10' } 'date'
Assert-Rejected { $script:fixture.features[0].properties.time = '2026-11-31' } 'date'
Assert-Rejected { $script:fixture.features[0].properties.time = '2026-11-14T00:00:00Z' } 'date'
Assert-Rejected { $script:fixture.features[0].properties.time = '2026-11-11' } 'duplicate'
Assert-Rejected {
  $script:fixture.features[0].properties.time = '2026-11-11'
  $script:fixture.features[1].properties.value = $null
} 'duplicate'
Assert-Rejected {
  foreach ($feature in $script:fixture.features) {
    $feature.properties.value = $null
  }
} 'no usable observations'
Assert-Rejected { $script:fixture.features[0].properties.PSObject.Properties.Remove('value') } 'missing value'
Assert-Rejected { $script:fixture.features[0].properties.value = 'NaN' } 'non-numeric'
Assert-Rejected { $script:fixture.features[0].properties.value = '1e999' } 'non-numeric'
Assert-Rejected { $script:fixture.features[0].properties.value = '1,23' } 'non-numeric'
Assert-Rejected { $script:networkFailure = $true } 'HTTP 503'
Write-Output 'USGS daily v1 offline fixtures passed.'
