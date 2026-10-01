<#
.SYNOPSIS
  Builds signed Android release files for the CareCompanion apps (patient, provider, doctor)
  and, on request, the All-in-One demo build.

.DESCRIPTION
  Produces, per app:
    - app-release.aab  : the Android App Bundle you upload to Google Play
    - app-release.apk  : a signed APK you can install directly on a phone/emulator
  and copies them to  dist/android/<version>/.

  With -Demo it builds DEMO APKs for testing on real phones instead (APK only, no AAB) into
  dist/demo/<version>/. Demo builds:
    - pass --dart-define=ALLOW_SERVER_OVERRIDE=true, so the login screen and Profile/More show
      the "Server address" setting (the tester can point the app at any backend at runtime);
    - set the Gradle property demoCleartext=true (ORG_GRADLE_PROJECT_demoCleartext), which
      selects network_security_config_demo.xml: plain HTTP is allowed to any host, so a PC on
      the LAN works. https tunnel links need no cleartext.
  Never upload demo builds to a store.

  Signing uses apps/<app>/android/key.properties (never committed). If that file is
  missing the build is stopped, because Gradle would otherwise fall back to the
  debug key, which Google Play rejects. Exception: all_in_one (demo build, APK only) may
  fall back to the debug key, with a warning.

.PARAMETER ApiUrl
  The backend the apps talk to by default. For the store this must be your production HTTPS
  URL, e.g. https://api.yourdomain.in/api/v1. For testing on the Android emulator
  against a backend running on this PC use http://10.0.2.2:4000/api/v1. A LAN address
  (http://192.168.x.x:4000/api/v1, http://10.x.x.x:4000/api/v1) implies -Demo.

.PARAMETER Apps
  all (default: the three store apps: patient, provider and doctor), everything (the three
  store apps + the all_in_one demo build), both (patient + provider), or one app name.
  all_in_one is a DEMO convenience build that bundles the three apps; the stores use the
  separate apps.

.PARAMETER Demo
  Build demo APKs for real phones (runtime "Server address" setting + cleartext HTTP to any
  host) into dist/demo/<version>/.

.PARAMETER DartDefines
  Extra --dart-define values, e.g. "FIREBASE_PROJECT_ID=my-proj","FIREBASE_APP_ID=1:2:android:3".

.EXAMPLE
  ./scripts/build-android-release.ps1 -ApiUrl https://api.yourdomain.in/api/v1
.EXAMPLE
  ./scripts/build-android-release.ps1 -ApiUrl http://10.0.2.2:4000/api/v1 -Apps patient_app
.EXAMPLE
  ./scripts/build-android-release.ps1 -ApiUrl http://10.0.2.2:4000/api/v1 -Apps all_in_one
.EXAMPLE
  ./scripts/build-android-release.ps1 -ApiUrl http://10.10.17.134:4000/api/v1 -Apps everything -Demo
#>
param(
  [Parameter(Mandatory = $true)][string]$ApiUrl,
  [ValidateSet('all', 'everything', 'both', 'patient_app', 'provider_app', 'doctor_app', 'all_in_one')][string]$Apps = 'all',
  [switch]$Demo,
  [string[]]$DartDefines = @()
)
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$targets = switch ($Apps) {
  'all' { @('patient_app', 'provider_app', 'doctor_app') }
  'everything' { @('patient_app', 'provider_app', 'doctor_app', 'all_in_one') }
  'both' { @('patient_app', 'provider_app') }
  default { @($Apps) }
}

$localHost = $null   # set for http:// test builds
if ($ApiUrl -notmatch '^https://') {
  if ($ApiUrl -notmatch '^http://(?<h>10\.0\.2\.2|localhost|127\.0\.0\.1|10\.\d+\.\d+\.\d+|192\.168\.\d+\.\d+|172\.(1[6-9]|2\d|3[01])\.\d+\.\d+)(:\d+)?/') {
    throw "ApiUrl must be https:// (production), the emulator address (http://10.0.2.2:4000/api/v1) or a PC on your local network (http://192.168.x.x:4000/api/v1)."
  }
  $localHost = $Matches['h']
  Write-Warning "Building against a LOCAL test backend ($ApiUrl). Do not upload these files to the store."
}
# A build for a real phone on the local network is a demo build: it needs cleartext HTTP to the
# PC's LAN address, and the tester may have to change the address when the PC changes networks.
$isLanPhone = $localHost -and $localHost -notin @('10.0.2.2', 'localhost', '127.0.0.1')
if ($isLanPhone -and -not $Demo) {
  Write-Host "LAN address ${localHost}: building DEMO APKs (same as -Demo)." -ForegroundColor Yellow
  $Demo = [switch]$true
}
if ($Demo) {
  Write-Warning "DEMO build: runtime server override and cleartext HTTP are enabled. Never upload these to a store."
}
$sdk = if ($env:ANDROID_HOME) { $env:ANDROID_HOME } else { Join-Path $env:LOCALAPPDATA 'Android\Sdk' }
$apksigner = $null
if (Test-Path (Join-Path $sdk 'build-tools')) {
  $apksigner = Get-ChildItem (Join-Path $sdk 'build-tools') -Directory | Sort-Object Name -Descending |
    ForEach-Object { Join-Path $_.FullName 'apksigner.bat' } | Where-Object { Test-Path $_ } | Select-Object -First 1
}
$distRoot = if ($Demo) { Join-Path $root 'dist/demo' } else { Join-Path $root 'dist/android' }

foreach ($app in $targets) {
  $dir = Join-Path $root "apps/$app"
  # The All-in-One build and -Demo builds are never uploaded to a store: APK only. all_in_one may
  # fall back to the debug key (with a warning) when it has no key.properties of its own.
  $apkOnly = $Demo -or $app -eq 'all_in_one'
  $hasKey = Test-Path (Join-Path $dir 'android/key.properties')
  if (-not $hasKey -and $app -ne 'all_in_one') {
    throw "$app/android/key.properties is missing, so the build would be debug-signed. See docs/STORE_SUBMISSION.md."
  }
  if (-not $hasKey) { Write-Warning "$app/android/key.properties is missing: the demo APK is signed with the DEBUG key." }
  $version = (Select-String -Path (Join-Path $dir 'pubspec.yaml') -Pattern '^version:\s*(.+)$').Matches[0].Groups[1].Value.Trim()
  $defines = @("--dart-define=API_BASE_URL=$ApiUrl")
  if ($Demo) { $defines += '--dart-define=ALLOW_SERVER_OVERRIDE=true' }
  $defines += ($DartDefines | ForEach-Object { "--dart-define=$_" })
  $symbols = Join-Path $dir 'build/symbols'
  $gradleArgs = @("--android-project-arg=demoCleartext=$(if ($Demo) { 'true' } else { 'false' })")

  Write-Host "`n=== $app $version$(if ($Demo) { ' (demo)' }) ===" -ForegroundColor Green
  # Demo builds select network_security_config_demo.xml through the Gradle property
  # demoCleartext (see android/app/build.gradle.kts); store builds keep the strict file. It is set
  # both as ORG_GRADLE_PROJECT_demoCleartext and as -P (flutter build does not always hand the
  # environment to Gradle), and the built APK's manifest is checked below.
  $previousCleartext = $env:ORG_GRADLE_PROJECT_demoCleartext
  $env:ORG_GRADLE_PROJECT_demoCleartext = if ($Demo) { 'true' } else { 'false' }
  Push-Location $dir
  try {
    # Native tools write warnings to stderr; with output redirected, Windows PowerShell 5.1 would turn
    # them into terminating errors under 'Stop'. Exit codes are checked explicitly instead.
    $ErrorActionPreference = 'Continue'
    flutter pub get | Out-Null
    if (-not $apkOnly) {
      flutter build appbundle --release --obfuscate --split-debug-info=$symbols @defines @gradleArgs
      if ($LASTEXITCODE -ne 0) { throw "AAB build failed for $app" }
    }
    flutter build apk --release --obfuscate --split-debug-info=$symbols @defines @gradleArgs
    if ($LASTEXITCODE -ne 0) { throw "APK build failed for $app" }
  } finally {
    $ErrorActionPreference = 'Stop'
    Pop-Location
    $env:ORG_GRADLE_PROJECT_demoCleartext = $previousCleartext
  }

  $out = Join-Path $distRoot $version
  New-Item -ItemType Directory -Force -Path $out | Out-Null
  $apk = Join-Path $out "$app-$version.apk"
  Copy-Item (Join-Path $dir 'build/app/outputs/flutter-apk/app-release.apk') $apk -Force
  $size = [math]::Round((Get-Item $apk).Length / 1MB, 1)

  # The network security config must match the build type: demo -> permissive file, store -> strict.
  $aapt2 = if (Test-Path (Join-Path $sdk 'build-tools')) {
    Get-ChildItem (Join-Path $sdk 'build-tools') -Directory | Sort-Object Name -Descending |
      ForEach-Object { Join-Path $_.FullName 'aapt2.exe' } | Where-Object { Test-Path $_ } | Select-Object -First 1
  }
  if ($aapt2) {
    $nscId = & { $ErrorActionPreference = 'Continue'; & $aapt2 dump xmltree --file AndroidManifest.xml $apk 2>&1 | Out-String } |
      Select-String -Pattern 'networkSecurityConfig\([^)]*\)=@(0x[0-9a-f]+)' | ForEach-Object { $_.Matches[0].Groups[1].Value }
    $resources = & { $ErrorActionPreference = 'Continue'; & $aapt2 dump resources $apk 2>&1 | Out-String }
    $nscName = if ($nscId -and $resources -match "resource $nscId (\S+)") { $Matches[1] } else { '?' }
    $expected = if ($Demo) { 'xml/network_security_config_demo' } else { 'xml/network_security_config' }
    if ($nscName -ne $expected) { throw "$app APK uses network security config '$nscName', expected '$expected'" }
    Write-Host "Network security config: $nscName"
  }

  # Refuse to hand over anything signed with the Android debug key (unless all_in_one has no key).
  # The APK uses APK Signature Scheme v2+ (apksigner); the AAB carries a JAR signature (keytool).
  $signer = $null
  if ($apksigner) {
    $apkCert = & { $ErrorActionPreference = 'Continue'; & $apksigner verify --print-certs $apk 2>&1 | Out-String }
    if ($LASTEXITCODE -ne 0) { throw "$app APK signature check failed" }
    if ($apkCert -match 'CN=Android Debug' -and $hasKey) { throw "$app APK is signed with the Android debug key" }
    $signer = ($apkCert -split "`n" | Where-Object { $_ -match 'certificate DN:' } | Select-Object -First 1)
  } else {
    Write-Warning "apksigner not found: APK signature not verified."
  }
  if ($apkOnly) {
    Write-Host "APK: $apk ($size MB)$(if (-not $hasKey) { ', DEBUG-signed' })"
    if ($signer) { Write-Host "Signed by: $("$signer".Trim())" }
    continue
  }
  Copy-Item (Join-Path $dir 'build/app/outputs/bundle/release/app-release.aab') (Join-Path $out "$app-$version.aab") -Force
  $aabCert = & { $ErrorActionPreference = 'Continue'; keytool -printcert -jarfile (Join-Path $out "$app-$version.aab") 2>&1 | Out-String }
  if ($aabCert -match 'CN=Android Debug' -or $aabCert -notmatch 'Owner:') { throw "$app AAB is not signed with the upload key" }
  $owner = ($aabCert -split "`n" | Where-Object { $_ -match 'Owner:' } | Select-Object -First 1)
  Write-Host "Signed by: $("$owner".Trim())"
}
Write-Host "`n$(if ($Demo) { 'Demo APKs' } else { 'Release files' }): $distRoot" -ForegroundColor Green
