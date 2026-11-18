@echo off
cd /d "%~dp0"
net session >nul 2>&1
if %errorlevel%==0 (
    powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0setup-firewall.ps1"
) else (
    powershell -NoProfile -ExecutionPolicy Bypass -Command "Start-Process powershell -Wait -Verb RunAs -ArgumentList '-NoProfile','-ExecutionPolicy','Bypass','-File',([char]34 + '%~dp0setup-firewall.ps1' + [char]34)"
    if errorlevel 1 (
        echo.
        echo [ERROR] Failed to elevate. Please right-click and Run as Administrator.
        pause
    )
)
