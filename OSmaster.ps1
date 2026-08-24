#Requires -RunAsAdministrator
<#
.SYNOPSIS
    OSmaster -- main menu. Start here.

.DESCRIPTION
    A menu launcher for the OSmaster toolkit. Run this first if you're not
    sure which script you need -- it explains each tool before you commit
    to running it, and launches whichever one you pick.

    Covers everything runnable from Windows: OS deployment (Deploy-Windows),
    and the console recovery tools (Prep-XboxRecovery, Prep-PlayStationRecovery).
    Deploy-macOS.sh is not listed here since it must be run on an actual Mac
    -- see README.md for that one.
#>

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

function Show-Banner {
    Clear-Host
    Write-Host @"
===============================================================
  OSmaster
  OS deployment and console recovery toolkit
===============================================================
"@ -ForegroundColor Cyan
}

function Show-Menu {
    Write-Host ""
    Write-Host "  [1] Deploy Windows (8.1 / 10 / 11) to a target disk"
    Write-Host "  [2] Prep Xbox official recovery USB (OSU1)"
    Write-Host "  [3] Prep PlayStation official recovery USB (PS3/PS4/PS5)"
    Write-Host "  [4] macOS deployment -- info only (must run on a Mac)"
    Write-Host "  [Q] Quit"
    Write-Host ""
}

function Pause-Return {
    Write-Host ""
    Read-Host "Press Enter to return to the menu"
}

Show-Banner
Write-Host "Every tool here explains itself and asks for explicit confirmation before" -ForegroundColor DarkGray
Write-Host "changing anything destructive. When in doubt, pick a tool and read its" -ForegroundColor DarkGray
Write-Host "instructions screen first -- nothing runs until you confirm." -ForegroundColor DarkGray

while ($true) {
    Show-Menu
    $choice = Read-Host "Choose an option"

    switch ($choice) {
        '1' {
            & (Join-Path $scriptDir 'Deploy-Windows.ps1') -Help
            $go = Read-Host "`nRun Deploy-Windows.ps1 now? (y/n)"
            if ($go -eq 'y') { & (Join-Path $scriptDir 'Deploy-Windows.ps1') }
            Pause-Return
        }
        '2' {
            & (Join-Path $scriptDir 'Prep-XboxRecovery.ps1') -Help
            $go = Read-Host "`nRun Prep-XboxRecovery.ps1 now? (y/n)"
            if ($go -eq 'y') { & (Join-Path $scriptDir 'Prep-XboxRecovery.ps1') }
            Pause-Return
        }
        '3' {
            & (Join-Path $scriptDir 'Prep-PlayStationRecovery.ps1') -Help
            $consoleChoice = Read-Host "`nWhich console? (PS3/PS4/PS5, or blank to cancel)"
            if ($consoleChoice -in @('PS3','PS4','PS5')) {
                & (Join-Path $scriptDir 'Prep-PlayStationRecovery.ps1') -Console $consoleChoice
            }
            Pause-Return
        }
        '4' {
            Write-Host @"

macOS deployment (Deploy-macOS.sh) cannot run from Windows -- Apple's
installer tools only exist on macOS itself. Copy Deploy-macOS.sh to the
target Mac and run it there:

  chmod +x Deploy-macOS.sh
  ./Deploy-macOS.sh --help

See README.md for full details.
"@ -ForegroundColor Yellow
            Pause-Return
        }
        { $_ -in @('q','Q') } { exit 0 }
        default { Write-Host "Not a valid option." -ForegroundColor Red }
    }
    Show-Banner
}
