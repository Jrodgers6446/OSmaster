@echo off
REM Runs Setup.ps1 with script execution allowed for just this one run.
REM This does NOT elevate and does NOT hide any window -- it's the same
REM plain, visible pattern countless internal tools use to work around
REM Windows' default "no unsigned scripts" policy, which otherwise
REM blocks Setup.ps1 from running at all (a separate thing from admin
REM rights -- this is PowerShell's own script-signing policy).
powershell.exe -ExecutionPolicy Bypass -File "%~dp0Setup.ps1"
