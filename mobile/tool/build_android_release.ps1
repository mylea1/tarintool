[CmdletBinding()]
param(
  [Parameter(Mandatory = $true)]
  [ValidateSet('cn', 'global')]
  [string]$Flavor
)

$ErrorActionPreference = 'Stop'

$mobileRoot = Split-Path -Parent $PSScriptRoot
$keystorePath = $env:KILO_ANDROID_KEYSTORE
$keystoreBase64 = $env:KILO_ANDROID_KEYSTORE_B64
$requiredVariables = @(
  'KILO_ANDROID_STORE_PASSWORD',
  'KILO_ANDROID_KEY_ALIAS',
  'KILO_ANDROID_KEY_PASSWORD'
)

foreach ($name in $requiredVariables) {
  $value = [Environment]::GetEnvironmentVariable($name)
  if ([string]::IsNullOrWhiteSpace($value)) {
    throw "Missing $name. Release builds never fall back to the debug signing key."
  }
}

if ([string]::IsNullOrWhiteSpace($keystorePath) -and [string]::IsNullOrWhiteSpace($keystoreBase64)) {
  throw 'Set KILO_ANDROID_KEYSTORE to a local .jks/.keystore path or set KILO_ANDROID_KEYSTORE_B64 in CI.'
}

if ([string]::IsNullOrWhiteSpace($keystorePath)) {
  $signingDirectory = Join-Path $mobileRoot 'build\kilo-signing'
  New-Item -ItemType Directory -Path $signingDirectory -Force | Out-Null
  $keystorePath = Join-Path $signingDirectory 'kilo-release.jks'
  try {
    [IO.File]::WriteAllBytes($keystorePath, [Convert]::FromBase64String($keystoreBase64))
  } catch [FormatException] {
    throw 'KILO_ANDROID_KEYSTORE_B64 is not valid Base64.'
  }
  $env:KILO_ANDROID_KEYSTORE = $keystorePath
}

$resolvedKeystorePath = [IO.Path]::GetFullPath($keystorePath)
if (-not (Test-Path -LiteralPath $resolvedKeystorePath -PathType Leaf)) {
  throw "Release signing keystore was not found at $resolvedKeystorePath."
}
$env:KILO_ANDROID_KEYSTORE = $resolvedKeystorePath

Push-Location $mobileRoot
try {
  flutter pub get
  flutter build apk --release --flavor $Flavor --dart-define=APP_MARKET=$Flavor
  flutter build appbundle --release --flavor $Flavor --dart-define=APP_MARKET=$Flavor
} finally {
  Pop-Location
}

$apkDirectory = Join-Path $mobileRoot 'build\app\outputs\flutter-apk'
$aabDirectory = Join-Path $mobileRoot "build\app\outputs\bundle\${Flavor}Release"
$apkPath = Get-ChildItem -LiteralPath $apkDirectory -Filter "app-$Flavor-release.apk" -File -ErrorAction SilentlyContinue | Select-Object -First 1
$aabPath = Get-ChildItem -LiteralPath $aabDirectory -Filter "app-$Flavor-release.aab" -File -ErrorAction SilentlyContinue | Select-Object -First 1

if ($null -eq $apkPath) {
  throw "Flutter completed without producing app-$Flavor-release.apk."
}
if ($null -eq $aabPath) {
  throw "Flutter completed without producing app-$Flavor-release.aab."
}

$apkHash = (Get-FileHash -LiteralPath $apkPath.FullName -Algorithm SHA256).Hash.ToLowerInvariant()
$aabHash = (Get-FileHash -LiteralPath $aabPath.FullName -Algorithm SHA256).Hash.ToLowerInvariant()
Write-Host "ANDROID FLAVOR: $Flavor"
Write-Host "APK:            $($apkPath.FullName)"
Write-Host "APK SHA256:     $apkHash"
Write-Host "AAB:            $($aabPath.FullName)"
Write-Host "AAB SHA256:     $aabHash"
