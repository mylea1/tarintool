$ErrorActionPreference = 'Stop'

$mobileRoot = Split-Path -Parent $PSScriptRoot
$repoRoot = Split-Path -Parent $mobileRoot
$branch = (git -C $repoRoot branch --show-current).Trim()

if ($branch -ne 'master') {
  throw "Refusing to build: expected branch 'master', current branch is '$branch'."
}

$socialEntryPoints = git -C $repoRoot grep -n -E 'PageId\.world|WorldPage\(' -- mobile/lib 2>$null
if ($LASTEXITCODE -eq 0 -and $socialEntryPoints) {
  throw "Refusing to build: social/world navigation entry points exist on master.`n$socialEntryPoints"
}

$commit = (git -C $repoRoot rev-parse --short HEAD).Trim()
$artifactName = "xingyu-master-$commit-debug.apk"
$artifactDirectory = Join-Path $mobileRoot 'build\app\outputs\flutter-apk'
$namedArtifact = Join-Path $artifactDirectory $artifactName
$checksumPath = "$namedArtifact.sha256"
$snapshotBase = Join-Path (Split-Path -Parent $repoRoot) '.codex-build-snapshots'
$snapshotRoot = Join-Path $snapshotBase ("xingyu-master-build-" + [guid]::NewGuid().ToString('N'))
$snapshotZip = Join-Path $snapshotRoot 'source.zip'
$snapshotSource = Join-Path $snapshotRoot 'source'
$snapshotMobile = Join-Path $snapshotSource 'mobile'
$snapshotArtifact = Join-Path $snapshotMobile 'build\app\outputs\flutter-apk\app-debug.apk'

try {
  New-Item -ItemType Directory -Path $snapshotBase -Force | Out-Null
  New-Item -ItemType Directory -Path $snapshotRoot | Out-Null
  New-Item -ItemType Directory -Path $snapshotSource | Out-Null
  git -C $repoRoot archive --format=zip --output=$snapshotZip $commit
  if ($LASTEXITCODE -ne 0) {
    throw "Unable to create an isolated source archive for commit $commit."
  }
  Expand-Archive -LiteralPath $snapshotZip -DestinationPath $snapshotSource

  Push-Location $snapshotMobile
  try {
    flutter pub get
    flutter build apk --debug
  } finally {
    Pop-Location
  }

  if (-not (Test-Path -LiteralPath $snapshotArtifact)) {
    throw "Flutter completed without producing $snapshotArtifact"
  }

  New-Item -ItemType Directory -Path $artifactDirectory -Force | Out-Null
  Copy-Item -LiteralPath $snapshotArtifact -Destination $namedArtifact -Force
} finally {
  $resolvedSnapshot = [System.IO.Path]::GetFullPath($snapshotRoot)
  $resolvedBase = [System.IO.Path]::GetFullPath($snapshotBase)
  if ($resolvedSnapshot.StartsWith($resolvedBase, [System.StringComparison]::OrdinalIgnoreCase) -and
      (Test-Path -LiteralPath $resolvedSnapshot)) {
    # Gradle may still release deeply nested Windows paths while cleanup is
    # running. A cleanup miss must never turn a successfully built APK into a
    # failed build result; stale snapshots remain confined to the verified
    # task-specific base directory and can be removed on the next run.
    Remove-Item -LiteralPath $resolvedSnapshot -Recurse -Force -ErrorAction SilentlyContinue
  }
}

$checksum = (Get-FileHash -LiteralPath $namedArtifact -Algorithm SHA256).Hash.ToLowerInvariant()
Set-Content -LiteralPath $checksumPath -Value "$checksum  $artifactName" -Encoding ascii

Write-Host "MASTER APK: $namedArtifact"
Write-Host "COMMIT:     $commit"
Write-Host "SHA256:     $checksum"
