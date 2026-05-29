function Test-InternalLinks {
  param([string[]]$RelativeFiles)

  $directorySeparator = [System.IO.Path]::DirectorySeparatorChar
  $directorySeparatorText = [string]$directorySeparator

  $linkPatterns = @(
    '(?:href|src)=["'']([^"'']+)["'']',
    '\[[^\]]+\]\(([^)\s]+)(?:\s+["''][^"'']+["''])?\)',
    '["'']((?:\.\.?/|[A-Za-z0-9_-]+/)[^"'']+\.(?:html|md|json|png|jpg|jpeg|webp|ico|css|js|webmanifest|pdf|ps1))["'']'
  )

  foreach ($relativeFile in $RelativeFiles) {
    $sourcePath = Resolve-ProjectPath ($relativeFile -replace '/', '\')
    if (-not (Test-Path -LiteralPath $sourcePath -PathType Leaf)) {
      continue
    }

    $text = Get-Content -LiteralPath $sourcePath -Raw
    $targets = New-Object System.Collections.Generic.List[string]

    foreach ($pattern in $linkPatterns) {
      foreach ($match in [regex]::Matches($text, $pattern)) {
        [void]$targets.Add($match.Groups[1].Value)
      }
    }

    foreach ($target in $targets) {
      $cleanTarget = ([string]$target).Trim()
      if (
        [string]::IsNullOrWhiteSpace($cleanTarget) -or
        $cleanTarget.StartsWith("#") -or
        $cleanTarget -match '^[a-zA-Z][a-zA-Z0-9+.-]*:'
      ) {
        continue
      }

      $targetPath = (($cleanTarget -split '#')[0] -split '\?')[0]
      if ([string]::IsNullOrWhiteSpace($targetPath)) {
        continue
      }

      try {
        $targetPath = [uri]::UnescapeDataString($targetPath)
      } catch {
        Add-Failure "Internal link in $relativeFile is not a valid URI path: $cleanTarget"
        continue
      }

      $normalizedTarget = $targetPath -replace '/', $directorySeparatorText
      if ($normalizedTarget.StartsWith($directorySeparatorText)) {
        $candidatePath = Resolve-ProjectPath $normalizedTarget.TrimStart($directorySeparator)
      } else {
        $basePath = Split-Path -Parent $relativeFile
        if ([string]::IsNullOrWhiteSpace($basePath)) {
          $basePath = "."
        }
        $candidatePath = Resolve-ProjectPath (Join-Path $basePath $normalizedTarget)
      }

      try {
        $fullCandidatePath = [System.IO.Path]::GetFullPath($candidatePath)
        $fullProjectRoot = [System.IO.Path]::GetFullPath($projectRoot).TrimEnd(
          [System.IO.Path]::DirectorySeparatorChar,
          [System.IO.Path]::AltDirectorySeparatorChar
        )
      } catch {
        Add-Failure "Internal link in $relativeFile could not be resolved: $cleanTarget"
        continue
      }

      $projectRootWithSeparator = "$fullProjectRoot$directorySeparatorText"
      if (
        -not $fullCandidatePath.Equals($fullProjectRoot, [System.StringComparison]::OrdinalIgnoreCase) -and
        -not $fullCandidatePath.StartsWith($projectRootWithSeparator, [System.StringComparison]::OrdinalIgnoreCase)
      ) {
        Add-Failure "Internal link in $relativeFile points outside the project: $cleanTarget"
        continue
      }

      if (-not (Test-Path -LiteralPath $fullCandidatePath -PathType Leaf)) {
        Add-Failure "Broken internal link in $relativeFile`: $cleanTarget"
      }
    }
  }
}
