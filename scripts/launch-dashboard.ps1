$ErrorActionPreference = "Stop"

$projectRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot ".."))
$port = 4173
$url = "http://127.0.0.1:$port/"
$runtimeBase = if ($env:LOCALAPPDATA) {
  Join-Path $env:LOCALAPPDATA "ClearLakeWatch"
} else {
  Join-Path ([System.IO.Path]::GetTempPath()) "ClearLakeWatch"
}
$runtimeDir = Join-Path $runtimeBase "runtime"
$pidFile = Join-Path $runtimeDir "server.pid"
$outLog = Join-Path $runtimeDir "server.out.log"
$errLog = Join-Path $runtimeDir "server.err.log"

New-Item -ItemType Directory -Path $runtimeDir -Force | Out-Null

function Show-LaunchError {
  param(
    [string]$Message
  )

  try {
    $shell = New-Object -ComObject WScript.Shell
    $shell.Popup($Message, 12, "Clear Lake Watch", 16) | Out-Null
  } catch {
    Write-Error $Message
  }
}

function Get-ListeningProcessId {
  param(
    [int]$LocalPort
  )

  $connection = Get-NetTCPConnection -LocalPort $LocalPort -State Listen -ErrorAction SilentlyContinue |
    Select-Object -First 1

  if ($connection) {
    return [int]$connection.OwningProcess
  }

  return $null
}

function Get-PythonLaunch {
  $bundledPython = Join-Path $env:USERPROFILE ".cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe"

  if ($env:CLEAR_LAKE_PYTHON -and (Test-Path $env:CLEAR_LAKE_PYTHON)) {
    return @{
      FilePath = $env:CLEAR_LAKE_PYTHON
      Arguments = @("-m", "http.server", "$port", "--bind", "127.0.0.1")
    }
  }

  if (Test-Path $bundledPython) {
    return @{
      FilePath = $bundledPython
      Arguments = @("-m", "http.server", "$port", "--bind", "127.0.0.1")
    }
  }

  $pythonCommand = Get-Command python -ErrorAction SilentlyContinue
  if ($pythonCommand) {
    return @{
      FilePath = $pythonCommand.Source
      Arguments = @("-m", "http.server", "$port", "--bind", "127.0.0.1")
    }
  }

  $pyCommand = Get-Command py -ErrorAction SilentlyContinue
  if ($pyCommand) {
    return @{
      FilePath = $pyCommand.Source
      Arguments = @("-3", "-m", "http.server", "$port", "--bind", "127.0.0.1")
    }
  }

  throw "Python was not found. Set CLEAR_LAKE_PYTHON to a Python executable or install Python 3 locally."
}

try {
  $listenerPid = Get-ListeningProcessId -LocalPort $port

  if (-not $listenerPid) {
    $pythonLaunch = Get-PythonLaunch
    $server = Start-Process `
      -FilePath $pythonLaunch.FilePath `
      -ArgumentList $pythonLaunch.Arguments `
      -WorkingDirectory $projectRoot `
      -RedirectStandardOutput $outLog `
      -RedirectStandardError $errLog `
      -PassThru `
      -WindowStyle Hidden

    Set-Content -Path $pidFile -Value $server.Id

    $deadline = (Get-Date).AddSeconds(8)
    do {
      Start-Sleep -Milliseconds 250
      $listenerPid = Get-ListeningProcessId -LocalPort $port
    } while (-not $listenerPid -and (Get-Date) -lt $deadline)

    if (-not $listenerPid) {
      throw "The dashboard server did not start on port $port. Check $errLog."
    }
  }

  Start-Process $url
} catch {
  Show-LaunchError -Message $_.Exception.Message
  throw
}
