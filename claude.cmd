@echo off
where pwsh >nul 2>&1
if %errorlevel%==0 (
    pwsh -NoProfile -ExecutionPolicy Bypass -Command "& '%~dp0claude-safe.ps1' %*"
) else (
    powershell -NoProfile -ExecutionPolicy Bypass -Command "& '%~dp0claude-safe.ps1' %*"
)
exit /b %errorlevel%
