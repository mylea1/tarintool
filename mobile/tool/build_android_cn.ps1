$ErrorActionPreference = 'Stop'
& (Join-Path $PSScriptRoot 'build_android_release.ps1') -Flavor cn
