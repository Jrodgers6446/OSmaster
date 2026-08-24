#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Prep-PlayStationRecovery: prepares a USB drive for Sony's official
    PlayStation system software reinstall/recovery process (PS3, PS4, PS5).

.DESCRIPTION
    Automates the exact folder structure and file-naming Sony's Safe Mode
    recovery requires — this is the single most common way people get this
    wrong by hand (wrong case, extra file extension, file in the wrong
    folder depth). As with the Xbox script, the actual download comes from
    you via the official PlayStation page, since Sony doesn't publish a
    stable direct-download URL either.

.NOTES
    Run as Administrator. Requires a USB drive, formatted FAT32 or exFAT
    per Sony's own requirement — this script formats as exFAT (works for
    all three consoles and isn't limited by FAT32's 4GB single-file cap,
    which matters since some PUP files exceed 4GB).

    IMPORTANT — this reinstalls SYSTEM SOFTWARE only. If your console's
    problem is a hardware failure (e.g. PS3 YLOD from cracked GPU/CPU
    solder joints, a dead PSU, etc.), a software reinstall will not fix it
    — this tool only addresses corrupted/stuck system software, not
    physical hardware faults.
#>

[CmdletBinding()]
param(
    [switch]$Help,

    [ValidateSet('PS3','PS4','PS5')]
    [string]$Console
)

$ErrorActionPreference = 'Stop'

function Write-Section($text) { Write-Host "`n==== $text ====" -ForegroundColor Cyan }
function Confirm-OrAbort($message) {
    $response = Read-Host "$message (type YES to continue)"
    if ($response -ne 'YES') { Write-Host "Aborted." -ForegroundColor Yellow; exit 1 }
}

function Show-Instructions {
@"

===============================================================
  Prep-PlayStationRecovery.ps1 -- Instructions
===============================================================

WHAT THIS DOES
  Prepares a USB drive for Sony's OFFICIAL system software reinstall
  process, for PS3, PS4, or PS5 -- Safe Mode recovery, same as the
  Xbox script's equivalent. Handles the exact folder structure and
  filename Sony requires (this is the #1 thing people get wrong by
  hand -- especially PS3's oddball "PS3UPDAT.PUP", no E, versus
  PS4/PS5's "PS4UPDATE.PUP"/"PS5UPDATE.PUP").

  IMPORTANT: this fixes SOFTWARE problems only (corrupted system
  software, stuck updates, boot loops from a bad update). It does
  NOT fix hardware faults -- a dead PSU, or the classic PS3 YLOD from
  cracked GPU/CPU solder joints, will not be fixed by this. If the
  console shows the green-yellow-blinking-red light sequence, that's
  hardware, and this tool won't help.

BEFORE YOU RUN THIS
  - Run PowerShell AS ADMINISTRATOR.
  - Have a USB drive to spare -- it WILL be reformatted as exFAT,
    erasing anything currently on it.
  - You'll manually download the official update file from the Sony
    page the script opens -- same reasoning as the Xbox tool, Sony
    doesn't publish a stable direct link either.

TYPICAL USE
  1. .\Prep-PlayStationRecovery.ps1 -Console PS5     (or PS4 / PS3)
  2. Download the official update/reinstallation file from the page
     that opens.
  3. Point the script at the downloaded file.
  4. Pick and confirm the USB drive letter.
  5. The script places it with the exact required folder/filename and
     prints the exact Safe Mode steps for that console.

===============================================================
"@ | Write-Host
}

if ($Help) { Show-Instructions; exit 0 }

if (-not $Console) {
    Write-Host "You must specify -Console PS3, -Console PS4, or -Console PS5." -ForegroundColor Red
    Write-Host "Run with -Help for full instructions." -ForegroundColor Yellow
    exit 1
}

# PS3 uses a different filename than PS4/PS5 — a well-known gotcha.
# PS4/PS5 use "PS4UPDATE.PUP" / "PS5UPDATE.PUP" (with the E).
# PS3 uses "PS3UPDAT.PUP" (no E) — get this wrong and the console won't see it.
$updateFileName = switch ($Console) {
    'PS3' { 'PS3UPDAT.PUP' }
    'PS4' { 'PS4UPDATE.PUP' }
    'PS5' { 'PS5UPDATE.PUP' }
}

$officialUrl = switch ($Console) {
    'PS3' { 'https://www.playstation.com/en-us/support/hardware/ps3-system-software/' }
    'PS4' { 'https://www.playstation.com/en-us/support/hardware/ps4-system-software/' }
    'PS5' { 'https://www.playstation.com/en-us/support/hardware/ps5-system-software/' }
}

Write-Section "Step 1: Get the official update file from Sony"
Write-Host "Opening the official PlayStation system software support page for $Console."
Start-Process $officialUrl
Write-Host @"

On that page, look for a "Reinstallation File" or "Update system software"
download (not a disc-based or online-only update). Save it anywhere on
this PC — do not rename it yet, that happens automatically next.
"@
Read-Host "Press Enter once you've downloaded the update file"

$pupPath = Read-Host "Enter the full path to the downloaded update file"
if (-not (Test-Path $pupPath)) {
    Write-Host "File not found at that path." -ForegroundColor Red
    exit 1
}

Write-Section "Step 2: Select and format the USB drive"
Write-Host "Attached removable drives:`n"
Get-Volume | Where-Object { $_.DriveType -eq 'Removable' -or $_.DriveLetter } |
    Format-Table DriveLetter, FileSystemLabel, FileSystem, @{Name='SizeGB';Expression={[math]::Round($_.Size/1GB,1)}} -AutoSize

$driveLetter = Read-Host "`nEnter the DRIVE LETTER of the USB stick to use (e.g. E)"
$driveLetter = $driveLetter.TrimEnd(':')

Write-Host "`nTHIS WILL ERASE EVERYTHING ON ${driveLetter}:" -ForegroundColor Red
Confirm-OrAbort "Format ${driveLetter}: as exFAT"

Format-Volume -DriveLetter $driveLetter -FileSystem exFAT -NewFileSystemLabel "$Console`REC" -Confirm:$false | Out-Null
Write-Host "Formatted ${driveLetter}: as exFAT." -ForegroundColor Green

Write-Section "Step 3: Place the file in the exact required structure"
$destFolder = "${driveLetter}:\$Console\UPDATE"
New-Item -ItemType Directory -Force -Path $destFolder | Out-Null

$destFile = Join-Path $destFolder $updateFileName
Copy-Item -Path $pupPath -Destination $destFile -Force

Write-Host "Placed file at: $destFile" -ForegroundColor Green
Write-Host "(Console folder and filename are uppercase and exact — this matters, the console is picky about it.)"

Write-Section "Step 4: Apply it on the console"
switch ($Console) {
    'PS3' {
        Write-Host @"
On the PS3 itself:
  1. Turn the console fully off (not standby).
  2. Plug the USB stick into a PS3 USB port.
  3. Hold the power button until it beeps twice, powers off, then beeps
     again and turns on — this boots Recovery/Safe Mode.
  4. Choose "System Update" from the Recovery Menu and follow the prompts.
"@
    }
    default {
        Write-Host @"
On the $Console itself:
  1. Turn the console fully off.
  2. Plug the USB stick into a console USB port.
  3. Hold the power button until you hear a second beep (about 7 seconds
     after the first), then release — this boots Safe Mode.
  4. Connect a controller via USB cable and press the PS button to pair it.
  5. Choose "Update System Software" (for a normal repair-in-place update)
     or "Reinstall System Software" (a full wipe-and-reinstall, only if the
     update option fails) and follow the prompts.
"@
    }
}
Write-Host "`nThis is a software-level repair. It will not fix hardware faults (dead PSU, cracked solder joints, etc.)." -ForegroundColor Yellow
