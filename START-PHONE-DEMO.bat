@echo off
rem Start CareCompanion for testing on a REAL PHONE from any network (Wi-Fi or mobile data).
rem Starts the backend + web portal and a temporary public https link (Cloudflare quick tunnel).
rem Install the demo APK on the phone, then on the login screen tap "Server" and paste the link
rem shown below (also saved in PHONE-SERVER-URL.txt). Close the windows to stop.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\start-local.ps1" -NoEmulator -Tunnel %*
pause
