<#
.SYNOPSIS
  Builds signed Android release files for both CareCompanion apps.

.DESCRIPTION
  Produces, per app:
    - app-release.aab  : the Android App Bundle you upload to Google Play
    - app-release.apk  : a signed APK you can install directly on a phone/emulator
  and copies them to  dist/android/<version>/.

  Signing uses apps/<app>/android/key.properties (never committed). If that file is
  missing the build is stopped, because Gradle would otherwise fall back to the
  debug key, which Google Play rejects.

.PARAMETER ApiUrl
  The backend the apps talk to. For the store this must be your production HTTPS
  URL, e.g. https://api.yourdomain.in/api/v1. For testing on the Android emulator
  against a backend running on this PC use http://10.0.2.2:4000/api/v1.

.PARAMETER Apps
  patient_app, provider_app or both (default).

.PARAMETER DartDefines
  Extra --dart-define values, e.g. "FIREBASE_PROJECT_ID=my-proj","FIREBASE_APP_ID=1:2:android:3".

.EXAMPLE
  ./scripts/build-android-release.ps1 -ApiUrl https://api.yourdomain.in/api/v1
.EXAMPLE
  ./scripts/build-android-release.ps1 -ApiUrl http://10.0.2.2:4000/api/v1 -Apps patient_app
#>
param(
  [Parameter(Mandatory = $true)][string]$ApiUrl,
  [ValidateSet('both', 'patient_app', 'provider_app')][string]$Apps = 'both',
  [string[]]$DartDefines = @()
)
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$targets = if ($Apps -eq 'both') { @('patient_app', 'provider_app') } else { @($Apps) }

if ($ApiUrl -notmatch '^https://' -and $ApiUrl -notmatch '^http://(10\.0\.2\.2|localhost|127\.0\.0\.1)(:\d+)?/') {
  throw "ApiUrl must be https:// (production) or a local test address (http://10.0.2.2:4000/api/v1)."
}
if ($ApiUrl -notmatch '^https://') {
  Write-Warning "Building against a LOCAL test backend ($ApiUrl). Do not upload these files to the store."
}

foreach ($app in $targets) {
  $dir = Join-Path $root "apps/$app"
  if (-not (Test-Path (Join-Path $dir 'android/key.properties'))) {
    throw "$app/android/key.properties is missing, so the build would be debug-signed. See docs/STORE_SUBMISSION.md."
  }
  $version = (Select-String -Path (Join-Path $dir 'pubspec.yaml') -Pattern '^version:\s*(.+)$').Matches[0].Groups[1].Value.Trim()
  $defines = @("--dart-define=API_BASE_URL=$ApiUrl") + ($DartDefines | ForEach-Object { "--dart-define=$_" })
  $symbols = Join-Path $dir 'build/symbols'

  Write-Host "`n=== $app $version ===" -ForegroundColor Green
  Push-Location $dir
  try {
    flutter pub get | Out-Null
    flutter build appbundle --release --obfuscate --split-debug-info=$symbols @defines
    if ($LASTEXITCODE -ne 0) { throw "AAB build failed for $app" }
    flutter build apk --release --obfuscate --split-debug-info=$symbols @defines
    if ($LASTEXITCODE -ne 0) { throw "APK build failed for $app" }
  } finally { Pop-Location }

  $out = Join-Path $root "dist/android/$version"
  New-Item -ItemType Directory -Force -Path $out | Out-Null
  Copy-Item (Join-Path $dir 'build/app/outputs/bundle/release/app-release.aab') (Join-Path $out "$app-$version.aab") -Force
  Copy-Item (Join-Path $dir 'build/app/outputs/flutter-apk/app-release.apk') (Join-Path $out "$app-$version.apk") -Force

  # Refuse to hand over anything signed with the Android debug key.
  # The AAB carries a JAR signature (keytool); the APK uses APK Signature Scheme v2+ (apksigner).
  $aabCert = keytool -printcert -jarfile (Join-Path $out "$app-$version.aab") 2>&1 | Out-String
  if ($aabCert -match 'CN=Android Debug' -or $aabCert -notmatch 'Owner:') { throw "$app AAB is not signed with the upload key" }
  $sdk = if ($env:ANDROID_HOME) { $env:ANDROID_HOME } else { Join-Path $env:LOCALAPPDATA 'Android\Sdk' }
  $apksigner = Get-ChildItem (Join-Path $sdk 'build-tools') -Directory | Sort-Object Name -Descending |
    ForEach-Object { Join-Path $_.FullName 'apksigner.bat' } | Where-Object { Test-Path $_ } | Select-Object -First 1
  if ($apksigner) {
    $apkCert = & $apksigner verify --print-certs (Join-Path $out "$app-$version.apk") 2>&1 | Out-String
    if ($LASTEXITCODE -ne 0 -or $apkCert -match 'CN=Android Debug') { throw "$app APK signature check failed" }
  }
  $owner = ($aabCert -split "`n" | Where-Object { $_ -match 'Owner:' } | Select-Object -First 1)
  Write-Host "Signed by: $("$owner".Trim())"
}
Write-Host "`nRelease files: $(Join-Path $root 'dist/android')" -ForegroundColor Green
