@echo off
setlocal
cd /d "%~dp0"
if exist "build\windows\OfficeMischief.exe" (
    start "" "build\windows\OfficeMischief.exe"
    exit /b 0
)
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0tools\launch.ps1"
if errorlevel 1 (
    echo.
    echo Launch failed. See the message above.
    pause
)
