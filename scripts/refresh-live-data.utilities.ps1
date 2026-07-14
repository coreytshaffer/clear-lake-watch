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
