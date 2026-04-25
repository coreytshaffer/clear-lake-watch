$ErrorActionPreference = "Stop"

$projectRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot ".."))
$shortcutDir = Join-Path $projectRoot "shortcuts"
$assetsDir = Join-Path $projectRoot "assets"
$launcherPath = Join-Path $projectRoot "scripts\launch-dashboard.ps1"
$iconPath = Join-Path $assetsDir "clear-lake-watch.ico"
$projectShortcutPath = Join-Path $shortcutDir "Clear Lake Watch.lnk"
$desktopShortcutPath = Join-Path ([Environment]::GetFolderPath("Desktop")) "Clear Lake Watch.lnk"
$powershellPath = Join-Path $env:WINDIR "System32\WindowsPowerShell\v1.0\powershell.exe"

if (-not (Test-Path $iconPath)) {
  throw "Missing icon at $iconPath. Generate assets\clear-lake-watch.ico before creating the shortcut."
}

if (-not (Test-Path $launcherPath)) {
  throw "Missing launcher at $launcherPath."
}

New-Item -ItemType Directory -Path $shortcutDir -Force | Out-Null

function New-DashboardShortcut {
  param(
    [string]$Path
  )

  $shell = New-Object -ComObject WScript.Shell
  $shortcut = $shell.CreateShortcut($Path)
  $shortcut.TargetPath = $powershellPath
  $shortcut.Arguments = "-NoProfile -ExecutionPolicy Bypass -File `"$launcherPath`""
  $shortcut.WorkingDirectory = $projectRoot
  $shortcut.IconLocation = "$iconPath,0"
  $shortcut.Description = "Open the Clear Lake Watch dashboard"
  $shortcut.WindowStyle = 7
  $shortcut.Save()
}

New-DashboardShortcut -Path $projectShortcutPath
New-DashboardShortcut -Path $desktopShortcutPath

Write-Output "Created $projectShortcutPath"
Write-Output "Created $desktopShortcutPath"
