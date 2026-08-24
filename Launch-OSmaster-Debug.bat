@echo off
REM OSmaster DEBUG launcher -- shows the PowerShell console with full
REM output, including any error messages. Use OSmaster.vbs instead for
REM normal day-to-day use (silent, no console window) -- only use this
REM one if something's going wrong and you need to see what's printed.

net session >nul 2>&1
if %errorlevel% neq 0 (
    echo Requesting Administrator privileges...
    powershell -Command "Start-Process -FilePath '%~f0' -Verb RunAs"
    exit /b
)

cd /d "%~dp0"
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0OSmaster-GUI.ps1"
if %errorlevel% neq 0 (
    echo.
    echo Something went wrong -- see any messages above.
    pause
)
