[CmdletBinding()]
param(
  [ValidateSet('cn', 'global')]
  [string]$Flavor = 'cn',
  [string]$Commit = 'HEAD',
  [string]$ApiBaseUrl = 'https://api.kilostrength.cn',
  [switch]$SkipQualityChecks
)

$ErrorActionPreference = 'Stop'
$mobileRoot = Split-Path -Parent $PSScriptRoot
$repoRoot = Split-Path -Parent $mobileRoot
$artifactDirectory = Join-Path $repoRoot 'artifacts'
$lockPath = Join-Path $artifactDirectory '.android-debug-build.lock'
$snapshotId = [guid]::NewGuid().ToString('N')
$linuxSnapshotRoot = "/tmp/kilo-android-build-$snapshotId"
$archivePath = Join-Path ([IO.Path]::GetTempPath()) "kilo-android-source-$snapshotId.tar.gz"
$linuxScriptWindowsPath = Join-Path ([IO.Path]::GetTempPath()) "kilo-android-build-$snapshotId.sh"
$lockStream = $null

function Invoke-CheckedCommand {
  param(
    [Parameter(Mandatory = $true)] [scriptblock]$Command,
    [Parameter(Mandatory = $true)] [string]$FailureMessage
  )
  & $Command
  if ($LASTEXITCODE -ne 0) {
    throw "$FailureMessage (exit code $LASTEXITCODE)."
  }
}

try {
  New-Item -ItemType Directory -Path $artifactDirectory -Force | Out-Null
  try {
    $lockStream = [IO.File]::Open(
      $lockPath,
      [IO.FileMode]::OpenOrCreate,
      [IO.FileAccess]::ReadWrite,
      [IO.FileShare]::None
    )
  } catch [IO.IOException] {
    throw 'Another isolated Android build is already running. Wait for it to finish instead of starting a second Gradle build.'
  }

  $resolvedCommit = (git -C $repoRoot rev-parse --verify "$Commit^{commit}").Trim()
  if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($resolvedCommit)) {
    throw "Unable to resolve Git commit '$Commit'."
  }
  $shortCommit = (git -C $repoRoot rev-parse --short $resolvedCommit).Trim()
  $branch = (git -C $repoRoot branch --show-current).Trim()
  if ([string]::IsNullOrWhiteSpace($branch)) { $branch = 'detached' }
  $safeBranch = $branch -replace '[^A-Za-z0-9._-]+', '-'

  $versionLine = git -C $repoRoot show "${resolvedCommit}:mobile/pubspec.yaml" |
    Select-String -Pattern '^version:\s*([^+\s]+)\+(\d+)\s*$' |
    Select-Object -First 1
  if ($null -eq $versionLine) {
    throw "Unable to read the mobile version from commit $shortCommit."
  }
  $versionName = $versionLine.Matches[0].Groups[1].Value
  $buildNumber = $versionLine.Matches[0].Groups[2].Value
  $artifactName = "xingyu-$versionName-build$buildNumber-$safeBranch-$shortCommit-$Flavor-debug.apk"
  $artifactPath = Join-Path $artifactDirectory $artifactName
  $checksumPath = "$artifactPath.sha256"

  $dirty = git -C $repoRoot status --porcelain
  if ($dirty) {
    Write-Warning "The working tree has uncommitted changes. This build intentionally uses commit $shortCommit only."
  }

  Invoke-CheckedCommand {
    git -C $repoRoot archive --format=tar.gz --output=$archivePath $resolvedCommit
  } "Unable to create an isolated archive for commit $shortCommit"

  $linuxHome = (wsl.exe bash -lc 'printf %s "$HOME"').Trim()
  $linuxArchivePath = (wsl.exe wslpath -a ($archivePath -replace '\\', '/')).Trim()
  $linuxArtifactDestination = (wsl.exe wslpath -a ($artifactPath -replace '\\', '/')).Trim()
  $linuxScriptPath = (wsl.exe wslpath -a ($linuxScriptWindowsPath -replace '\\', '/')).Trim()
  if ([string]::IsNullOrWhiteSpace($linuxHome) -or
      [string]::IsNullOrWhiteSpace($linuxArchivePath) -or
      [string]::IsNullOrWhiteSpace($linuxArtifactDestination) -or
      [string]::IsNullOrWhiteSpace($linuxScriptPath)) {
    throw 'WSL could not resolve its home directory or translate a build path.'
  }

  $qualityCommands = if ($SkipQualityChecks) { '' } else {
    'flutter analyze && flutter test --no-pub && '
  }
  $linuxScript = @"
set -euo pipefail
export FLUTTER_ROOT='$linuxHome/.local/toolchains/flutter-3.44.2'
export JAVA_HOME='$linuxHome/.local/toolchains/jdk-17'
export ANDROID_HOME='$linuxHome/.local/toolchains/android-sdk'
export ANDROID_SDK_ROOT="`$ANDROID_HOME"
export PUB_CACHE='$linuxHome/.pub-cache'
export PATH="`$FLUTTER_ROOT/bin:`$JAVA_HOME/bin:`$ANDROID_HOME/platform-tools:`$ANDROID_HOME/cmdline-tools/latest/bin:/usr/bin:/bin"
test -x "`$FLUTTER_ROOT/bin/flutter"
test -x "`$JAVA_HOME/bin/java"
test -d "`$ANDROID_HOME"
mkdir -p '$linuxSnapshotRoot'
tar -xzf '$linuxArchivePath' -C '$linuxSnapshotRoot'
cd '$linuxSnapshotRoot/mobile'
rm -rf .dart_tool build android/.gradle
flutter pub get
${qualityCommands}flutter build apk --debug --flavor '$Flavor' --no-pub --dart-define=APP_MARKET='$Flavor' --dart-define=KILO_API_BASE_URL='$ApiBaseUrl' --dart-define=KILO_SOURCE_COMMIT='$shortCommit'
test -f 'build/app/outputs/flutter-apk/app-$Flavor-debug.apk'
cp 'build/app/outputs/flutter-apk/app-$Flavor-debug.apk' '$linuxArtifactDestination'
"@

  $utf8WithoutBom = [Text.UTF8Encoding]::new($false)
  [IO.File]::WriteAllText(
    $linuxScriptWindowsPath,
    ($linuxScript -replace "`r`n", "`n") + "`n",
    $utf8WithoutBom
  )

  Invoke-CheckedCommand {
    wsl.exe --exec bash $linuxScriptPath
  } 'The isolated WSL Android build failed'

  if (-not (Test-Path -LiteralPath $artifactPath -PathType Leaf)) {
    throw "Build completed without producing $artifactPath."
  }
  $artifactLength = (Get-Item -LiteralPath $artifactPath).Length
  if ($artifactLength -lt 1MB) {
    throw "The generated APK is unexpectedly small ($artifactLength bytes)."
  }
  $checksum = (Get-FileHash -LiteralPath $artifactPath -Algorithm SHA256).Hash.ToLowerInvariant()
  Set-Content -LiteralPath $checksumPath -Value "$checksum  $artifactName" -Encoding ascii

  Write-Host "ANDROID FLAVOR: $Flavor"
  Write-Host "SOURCE COMMIT:  $resolvedCommit"
  Write-Host "APK:            $artifactPath"
  Write-Host "SIZE:           $artifactLength bytes"
  Write-Host "SHA256:         $checksum"
} finally {
  if ($lockStream) { $lockStream.Dispose() }
  Remove-Item -LiteralPath $lockPath -Force -ErrorAction SilentlyContinue
  Remove-Item -LiteralPath $archivePath -Force -ErrorAction SilentlyContinue
  Remove-Item -LiteralPath $linuxScriptWindowsPath -Force -ErrorAction SilentlyContinue
  if ($linuxSnapshotRoot -match '^/tmp/kilo-android-build-[0-9a-f]{32}$') {
    wsl.exe bash -lc "rm -rf '$linuxSnapshotRoot'" 2>$null
  }
}
