#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Prep-XboxRecovery: prepares a USB drive for Xbox's official Offline
    System Update (OSU1) repair process.

.DESCRIPTION
    This automates the fiddly, easy-to-get-wrong parts of Xbox's official
    offline recovery process (formatting, exact folder placement), while
    leaving the actual download to you via the official Microsoft page —
    that page doesn't have a stable direct-download URL, so hardcoding one
    here would just break the first time Microsoft updates it.

    This is Microsoft's own official repair mechanism, used for console
    black-screen/boot-loop/corrupted-update scenarios. It does not erase
    games or saves (a full factory reset is a separate, unrelated option on
    the console itself).

.NOTES
    Run as Administrator. Requires a USB drive with at least 8GB free —
    it WILL be reformatted, erasing everything currently on it.
#>

[CmdletBinding()]
param([switch]$Help)

$ErrorActionPreference = 'Stop'

function Write-Section($text) { Write-Host "`n==== $text ====" -ForegroundColor Cyan }
function Confirm-OrAbort($message) {
    $response = Read-Host "$message (type YES to continue)"
    if ($response -ne 'YES') { Write-Host "Aborted." -ForegroundColor Yellow; exit 1 }
}

function Show-Instructions {
@"

===============================================================
  Prep-XboxRecovery.ps1 -- Instructions
===============================================================

WHAT THIS DOES
  Prepares a USB drive for Xbox's OFFICIAL Offline System Update (OSU1)
  repair process -- Microsoft's own recovery mechanism for consoles
  stuck on a black screen, boot loop, or corrupted update. This does
  NOT erase games or saves (that's a separate, unrelated factory
  reset option on the console itself).

  This script does not push an OS onto the target drive the way the
  Windows/macOS tools do -- the console's internal storage already has
  its own OS. Instead, it preps a USB installer, and the CONSOLE ITSELF
  reads that USB and repairs its own system software.

BEFORE YOU RUN THIS
  - Run PowerShell AS ADMINISTRATOR.
  - Have a USB drive with at least 8GB free -- it WILL be reformatted,
    erasing anything currently on it.
  - You'll need to manually download the OSU1.zip file yourself from
    the official Microsoft page the script opens for you -- Microsoft
    doesn't publish a stable direct-download link, so this step can't
    be automated without risking a broken URL later.

TYPICAL USE
  1. .\Prep-XboxRecovery.ps1
  2. Download OSU1.zip from the page that opens, matching your console
     family (Xbox One vs Series X|S).
  3. Point the script at the downloaded file.
  4. Pick and confirm the USB drive letter -- it gets reformatted.
  5. The script places the files correctly and prints the exact
     button-combo steps to run on the console itself.

===============================================================
"@ | Write-Host
}

if ($Help) { Show-Instructions; exit 0 }

Write-Section "Step 1: Get the official OSU1 file from Microsoft"
Write-Host "Opening the official Xbox Offline System Update page in your browser."
Write-Host "Download the OSU1.zip file that matches your console (Xbox One family or Xbox Series X|S)."
Start-Process "https://support.xbox.com/help/hardware-network/console/offline-system-update"
Read-Host "`nPress Enter once you've downloaded OSU1.zip somewhere on this PC"

$osuZipPath = Read-Host "Enter the full path to the downloaded OSU1.zip file"
if (-not (Test-Path $osuZipPath)) {
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
Confirm-OrAbort "Format ${driveLetter}: as NTFS"

Format-Volume -DriveLetter $driveLetter -FileSystem NTFS -NewFileSystemLabel "XBOXOSU" -Confirm:$false | Out-Null
Write-Host "Formatted ${driveLetter}: as NTFS." -ForegroundColor Green

Write-Section "Step 3: Extract and place the update files"
$extractPath = Join-Path $env:TEMP "osu1_extract"
if (Test-Path $extractPath) { Remove-Item $extractPath -Recurse -Force }
Expand-Archive -Path $osuZipPath -DestinationPath $extractPath -Force

$systemUpdateFolder = Get-ChildItem -Path $extractPath -Filter '$SystemUpdate' -Directory -Recurse | Select-Object -First 1
if (-not $systemUpdateFolder) {
    Write-Host "Could not find a `$SystemUpdate folder inside the extracted OSU1.zip — is this the correct official file?" -ForegroundColor Red
    exit 1
}

$destination = "${driveLetter}:\`$SystemUpdate"
Copy-Item -Path $systemUpdateFolder.FullName -Destination $destination -Recurse -Force
Write-Host "Copied `$SystemUpdate to the root of ${driveLetter}: — ready to use." -ForegroundColor Green

Write-Section "Step 4: Apply it on the console"
Write-Host @"
On the Xbox itself:
  1. Turn the console fully off, then unplug it for 30 seconds.
  2. Plug the USB stick into the console.
  3. Press and HOLD the Pair button and Eject button together, then press
     the Xbox button (on models without an Eject button — e.g. Series S —
     hold just the Pair button, then press the Xbox button).
  4. Keep holding until you hear two power-up tones (about 10-15 seconds),
     then release. This boots into the Xbox Startup Troubleshooter.
  5. Choose the offline system update option and follow the on-screen steps.

This does not erase your games or saves — it's a system-software repair,
not a factory reset.
"@ -ForegroundColor White
