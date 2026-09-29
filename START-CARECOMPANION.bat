@echo off
rem Double-click to start the CareCompanion demo (backend, web portal, Android emulator + apps).
rem Add /reseed to reset the demo data:  START-CARECOMPANION.bat /reseed
set ARGS=
if /I "%1"=="/reseed" set ARGS=-Reseed
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\start-local.ps1" %ARGS%
pause
