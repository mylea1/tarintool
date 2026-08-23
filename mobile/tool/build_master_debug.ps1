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
$defaultArtifact = Join-Path $artifactDirectory 'app-debug.apk'
$namedArtifact = Join-Path $artifactDirectory $artifactName
$checksumPath = "$namedArtifact.sha256"

Push-Location $mobileRoot
try {
  flutter clean
  flutter pub get
  flutter build apk --debug
} finally {
  Pop-Location
}

if (-not (Test-Path -LiteralPath $defaultArtifact)) {
  throw "Flutter completed without producing $defaultArtifact"
}

Copy-Item -LiteralPath $defaultArtifact -Destination $namedArtifact -Force
$checksum = (Get-FileHash -LiteralPath $namedArtifact -Algorithm SHA256).Hash.ToLowerInvariant()
Set-Content -LiteralPath $checksumPath -Value "$checksum  $artifactName" -Encoding ascii

Write-Host "MASTER APK: $namedArtifact"
Write-Host "COMMIT:     $commit"
Write-Host "SHA256:     $checksum"
