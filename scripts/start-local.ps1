<#
.SYNOPSIS
  Starts the whole CareCompanion demo on this PC: backend API, staff web portal,
  and the Android emulator with both apps installed.

.DESCRIPTION
  Each server opens in its own window. Close a window to stop that server.
  Everything keeps running independently of any terminal or editor session.

  - Backend API       http://localhost:4000/api/v1
  - Staff web portal  http://localhost:3100/login
  - Android emulator  CareCompanion (patient) + CareCompanion Pro (provider)

.PARAMETER Reseed
  Reset the demo database to fresh sample data before starting.
.PARAMETER NoEmulator
  Start only the backend and the web portal.
.PARAMETER Avd
  Android Virtual Device to use (default: the first one found).
#>
param([switch]$Reseed, [switch]$NoEmulator, [string]$Avd = '')
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$api = Join-Path $root 'services\api'
$web = Join-Path $root 'apps\web'
$sdk = if ($env:ANDROID_HOME) { $env:ANDROID_HOME } else { Join-Path $env:LOCALAPPDATA 'Android\Sdk' }
$adb = Join-Path $sdk 'platform-tools\adb.exe'
$emulator = Join-Path $sdk 'emulator\emulator.exe'

function Test-Url($url) { try { (Invoke-WebRequest -UseBasicParsing -TimeoutSec 3 $url).StatusCode -eq 200 } catch { $false } }
function Wait-Until($what, $seconds, [scriptblock]$check) {
  Write-Host "Waiting for $what..." -NoNewline
  $end = (Get-Date).AddSeconds($seconds)
  while ((Get-Date) -lt $end) { if (& $check) { Write-Host ' ready' -ForegroundColor Green; return $true }; Start-Sleep 3; Write-Host '.' -NoNewline }
  Write-Host ' timed out' -ForegroundColor Yellow; return $false
}

# ---------------------------------------------------------------- dependencies
foreach ($dir in @($api, $web)) {
  if (-not (Test-Path (Join-Path $dir 'node_modules'))) { Write-Host "Installing packages in $dir"; Push-Location $dir; npm install; Pop-Location }
}
if ($Reseed -or -not (Test-Path (Join-Path $api '.data\pglite'))) {
  Write-Host 'Loading demo data...'; Push-Location $api; npm run seed -- --reset; Pop-Location
}
if (-not (Test-Path (Join-Path $web '.next\standalone\server.js'))) {
  Write-Host 'Building the web portal (first run only)...'; Push-Location $web; npm run build; Pop-Location
}

# ---------------------------------------------------------------- backend + portal
if (Test-Url 'http://localhost:4000/api/v1/health') { Write-Host 'Backend already running.' }
else { Start-Process powershell -WorkingDirectory $api -ArgumentList '-NoExit', '-Command', "`$host.UI.RawUI.WindowTitle='CareCompanion API (port 4000)'; npx tsx --env-file-if-exists=.env src/server.ts" }

if (Test-Url 'http://localhost:3100/login') { Write-Host 'Web portal already running.' }
else { Start-Process powershell -WorkingDirectory $web -ArgumentList '-NoExit', '-Command', "`$host.UI.RawUI.WindowTitle='CareCompanion web portal (port 3100)'; `$env:PORT='3100'; npm run start:standalone" }

Wait-Until 'backend' 120 { Test-Url 'http://localhost:4000/api/v1/health' } | Out-Null
Wait-Until 'web portal' 90 { Test-Url 'http://localhost:3100/login' } | Out-Null

# ---------------------------------------------------------------- emulator + apps
if (-not $NoEmulator) {
  if (-not (Test-Path $emulator)) { Write-Warning "Android emulator not found under $sdk; skipping." }
  else {
    if (-not $Avd) { $Avd = (& $emulator -list-avds | Where-Object { $_ -and $_ -notmatch '^INFO' } | Select-Object -First 1) }
    $running = (& $adb devices) -match 'emulator-\d+\s+device'
    if (-not $running) {
      $free = [math]::Round((Get-CimInstance Win32_OperatingSystem).FreePhysicalMemory / 1MB, 1)
      if ($free -lt 2.5) { Write-Warning "Only $free GB of memory is free. Close some programs (browser tabs, editors) if the emulator is slow or closes." }
      Write-Host "Starting emulator $Avd"
      Start-Process $emulator -ArgumentList '-avd', $Avd, '-memory', '2048', '-no-snapshot', '-gpu', 'auto'
    }
    $booted = Wait-Until 'Android emulator' 300 { ((& $adb shell getprop sys.boot_completed 2>$null) -join '').Trim() -eq '1' }
    if ($booted) {
      $packages = (& $adb shell pm list packages) -join "`n"
      $apkDir = Get-ChildItem (Join-Path $root 'dist\android') -Directory -ErrorAction SilentlyContinue | Sort-Object Name -Descending | Select-Object -First 1
      foreach ($app in @(@{ id = 'com.carecompanion.patient'; name = 'patient_app' }, @{ id = 'com.carecompanion.provider'; name = 'provider_app' })) {
        if ($packages -notmatch [regex]::Escape($app.id)) {
          $apk = if ($apkDir) { Get-ChildItem $apkDir.FullName -Filter "$($app.name)-*.apk" | Select-Object -First 1 }
          if (-not $apk) { $apk = Get-Item (Join-Path $root "apps\$($app.name)\build\app\outputs\flutter-apk\app-debug.apk") -ErrorAction SilentlyContinue }
          if ($apk) { Write-Host "Installing $($app.name)"; & $adb install $apk.FullName | Out-Null }
          else { Write-Warning "No APK for $($app.name). Build one with: ./scripts/build-android-release.ps1 -ApiUrl http://10.0.2.2:4000/api/v1" }
        }
      }
      & $adb shell monkey -p com.carecompanion.patient -c android.intent.category.LAUNCHER 1 2>$null | Out-Null
    }
  }
}

Write-Host @"

CareCompanion is running.  Close the API / portal windows (or the emulator) to stop them.

  Staff web portal   http://localhost:3100/login
  Emulator apps      CareCompanion (patient)  |  CareCompanion Pro (provider)

  Logins (type the 10-digit number, OTP 123456):
    Patient  9800000001 Vaibhav (switch to father Ramesh via the avatar)   9800000002 Lakshmi (family)
    Doctor   9800000101   Coordinator 9800000301   Ops admin 9800000401   Super admin 9800000501
    Nurse    9800000201   Applicant 9800000601     Expired credential 9800000203
"@ -ForegroundColor Cyan
