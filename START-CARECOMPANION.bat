@echo off
rem Double-click to start the CareCompanion demo (backend, web portal, Android emulator + apps).
rem Installs CareCompanion, CareCompanion Pro, CareCompanion Doctor and, if its APK was built
rem (scripts\build-android-release.ps1 -Apps all_in_one), the CareCompanion All-in-One demo app.
rem Add /reseed to reset the demo data:  START-CARECOMPANION.bat /reseed
set ARGS=
if /I "%1"=="/reseed" set ARGS=-Reseed
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\start-local.ps1" %ARGS%
pause
