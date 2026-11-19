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
    try {
      $sourcePath = Resolve-NativeProjectPath (Resolve-ProjectPath $relativeFile)
      if (-not (Test-Path -LiteralPath $sourcePath -PathType Leaf)) {
        continue
      }
      $text = Get-Content -LiteralPath $sourcePath -Raw
    } catch {
      Add-Failure ("Unable to read internal link source {0}: {1}" -f $relativeFile, $_.Exception.Message)
      continue
    }
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
        $fullCandidatePath = Resolve-NativeProjectPath $candidatePath
      } catch {
        Add-Failure ("Internal link in {0} could not be resolved: {1} ({2})" -f
          $relativeFile, $cleanTarget, $_.Exception.Message)
        continue
      }

      if (-not (Test-Path -LiteralPath $fullCandidatePath -PathType Leaf)) {
        Add-Failure "Broken internal link in $relativeFile`: $cleanTarget"
      }
    }
  }
}
