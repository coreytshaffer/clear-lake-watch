param(
  [switch]$Quiet
)

$ErrorActionPreference = "Stop"

function Find-GitExecutable {
  $pathGit = Get-Command git -ErrorAction SilentlyContinue

  if ($pathGit) {
    return [PSCustomObject]@{
      Source = "PATH"
      Path = $pathGit.Source
    }
  }

  $candidatePaths = @(
    "C:\Program Files\Git\cmd\git.exe",
    "C:\Program Files\Git\bin\git.exe",
    "$env:LOCALAPPDATA\GitHubDesktop\app-*\resources\app\git\cmd\git.exe",
    "$env:LOCALAPPDATA\GitHubDesktop\app-*\resources\app\git\mingw64\bin\git.exe",
    "C:\Program Files\GitHub Desktop\resources\app\git\cmd\git.exe"
  )

  foreach ($candidate in $candidatePaths) {
    $matches = @(Get-ChildItem -Path $candidate -ErrorAction SilentlyContinue | Sort-Object FullName -Descending)

    if ($matches.Count -gt 0) {
      return [PSCustomObject]@{
        Source = "fallback"
        Path = $matches[0].FullName
      }
    }
  }

  return $null
}

function Test-GitRepository {
  param([string]$GitPath)

  $previousErrorActionPreference = $ErrorActionPreference
  $ErrorActionPreference = "Continue"

  try {
    & $GitPath rev-parse --is-inside-work-tree 1> $null 2> $null
    $exitCode = $LASTEXITCODE
  } finally {
    $ErrorActionPreference = $previousErrorActionPreference
  }

  return $exitCode -eq 0
}

$git = Find-GitExecutable

if (-not $git) {
  throw "Could not find git.exe on PATH, in Program Files Git, or in GitHub Desktop's bundled Git."
}

$version = (& $git.Path --version)
$isRepository = Test-GitRepository -GitPath $git.Path

if ($Quiet) {
  Write-Output $git.Path
  exit 0
}

Write-Output "Git found."
Write-Output "  Source: $($git.Source)"
Write-Output "  Path: $($git.Path)"
Write-Output "  Version: $version"
Write-Output "  Current folder is Git repository: $isRepository"
Write-Output ""
Write-Output "Use this command for explicit local diffs:"
Write-Output "  & '$($git.Path)' --no-pager diff"

if (-not $isRepository) {
  Write-Output ""
  Write-Output "Note: Git is available, but this project folder is not currently a Git repository."
  Write-Output "Do not run git init automatically unless you intentionally want this folder to become the repository root."
}
