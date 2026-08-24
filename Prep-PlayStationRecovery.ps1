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
    [ValidateSet('PS3','PS4','PS5')]
    [Parameter(Mandatory=$true)]
    [string]$Console
)

$ErrorActionPreference = 'Stop'

function Write-Section($text) { Write-Host "`n==== $text ====" -ForegroundColor Cyan }
function Confirm-OrAbort($message) {
    $response = Read-Host "$message (type YES to continue)"
    if ($response -ne 'YES') { Write-Host "Aborted." -ForegroundColor Yellow; exit 1 }
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
