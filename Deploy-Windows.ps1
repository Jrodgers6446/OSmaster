#Requires -RunAsAdministrator
<#
.SYNOPSIS
    OSmaster: Windows ISO acquisition + headless deployment, chained into one script.

.DESCRIPTION
    This script does three things, in order:
      1. Fetches an official Windows ISO directly from Microsoft using Fido
         (github.com/pbatard/Fido) — no browser click-through required.
      2. Partitions and formats a TARGET DISK you choose (UEFI/GPT layout:
         EFI system partition + Windows partition).
      3. Applies the Windows image to that disk with DISM and makes it
         bootable with bcdboot — no interactive Setup GUI involved.

    This is the "headless" deployment path: after this script finishes and
    you boot from the target disk, Windows goes straight to OOBE (the
    out-of-box first-run screens), skipping the file-copy/install phase
    entirely, since the files are already applied to disk.

.WARNING
    Step 2 of this script runs `clean` on the disk you select, which
    PERMANENTLY ERASES EVERYTHING ON IT. There is no undo. The script will
    show you the exact disk (number, size, model) and require you to type
    the disk number again as an explicit confirmation before it touches
    anything. Read that confirmation prompt carefully every single time —
    do not run this unattended against a disk you have not personally
    verified.

.NOTES
    Requires: Windows, PowerShell 5.1+, run as Administrator.
    Fido.ps1 must be present in the same folder as this script, or this
    script will download it automatically from the official GitHub repo.
#>

[CmdletBinding()]
param(
    # Optional: path to an already-downloaded Windows ISO. If omitted, the
    # script runs Fido interactively to fetch one.
    [string]$IsoPath,

    # Optional: skip Fido's interactive menu by pre-specifying these.
    # Leave blank to be prompted interactively instead.
    [ValidateSet('10','11')]
    [string]$WindowsVersion,
    [string]$Edition,
    [string]$Language = 'English',
    [ValidateSet('x64','x86','arm64')]
    [string]$Arch = 'x64'
)

$ErrorActionPreference = 'Stop'
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

function Write-Section($text) {
    Write-Host ""
    Write-Host "==== $text ====" -ForegroundColor Cyan
}

function Confirm-OrAbort($message) {
    $response = Read-Host "$message (type YES to continue)"
    if ($response -ne 'YES') {
        Write-Host "Aborted by user." -ForegroundColor Yellow
        exit 1
    }
}

# ----------------------------------------------------------------------
# STEP 1 — Acquire the ISO via Fido, unless one was already supplied
# ----------------------------------------------------------------------
if (-not $IsoPath) {
    Write-Section "Step 1: Fetching Windows ISO via Fido"

    $fidoPath = Join-Path $scriptDir 'Fido.ps1'
    if (-not (Test-Path $fidoPath)) {
        Write-Host "Fido.ps1 not found locally — downloading the official script from pbatard/Fido..."
        $fidoUrl = 'https://raw.githubusercontent.com/pbatard/Fido/master/Fido.ps1'
        Invoke-WebRequest -Uri $fidoUrl -OutFile $fidoPath -UseBasicParsing
    }

    $downloadDir = Join-Path $scriptDir 'iso'
    New-Item -ItemType Directory -Force -Path $downloadDir | Out-Null

    # Build Fido arguments. If version/edition weren't passed on the command
    # line, Fido will prompt interactively for whatever's missing — that's
    # expected and fine, just follow its on-screen menu.
    $fidoArgs = @('-ExecutionPolicy', 'Bypass', '-File', $fidoPath, '-Arch', $Arch)
    if ($WindowsVersion) { $fidoArgs += @('-Win', $WindowsVersion) }
    if ($Edition)        { $fidoArgs += @('-Ed', $Edition) }
    if ($Language)       { $fidoArgs += @('-Lang', $Language) }

    Write-Host "Launching Fido — follow any on-screen prompts for version/edition if not pre-specified..."
    & powershell.exe @fidoArgs

    # Fido saves the ISO into its own working directory by default; find the
    # newest .iso file it produced.
    $iso = Get-ChildItem -Path $scriptDir -Filter '*.iso' -Recurse |
        Sort-Object LastWriteTime -Descending | Select-Object -First 1

    if (-not $iso) {
        Write-Host "Could not locate a downloaded ISO. Check Fido's output above for errors." -ForegroundColor Red
        exit 1
    }
    $IsoPath = $iso.FullName
    Write-Host "Using ISO: $IsoPath" -ForegroundColor Green
} else {
    Write-Section "Step 1: Using supplied ISO"
    Write-Host "ISO: $IsoPath"
}

# ----------------------------------------------------------------------
# STEP 2 — Select and prepare the target disk
# ----------------------------------------------------------------------
Write-Section "Step 2: Select target disk"

Write-Host "Currently attached disks:`n"
Get-Disk | Format-Table Number, FriendlyName, @{Name='SizeGB'; Expression={[math]::Round($_.Size/1GB,1)}}, PartitionStyle, OperationalStatus -AutoSize

$diskNumber = Read-Host "`nEnter the disk NUMBER to install Windows onto"
$targetDisk = Get-Disk -Number $diskNumber -ErrorAction SilentlyContinue
if (-not $targetDisk) {
    Write-Host "No disk found with that number." -ForegroundColor Red
    exit 1
}

$sizeGB = [math]::Round($targetDisk.Size / 1GB, 1)
Write-Host "`nYou selected: Disk $diskNumber — $($targetDisk.FriendlyName) — ${sizeGB} GB" -ForegroundColor Yellow
Write-Host "EVERYTHING ON THIS DISK WILL BE PERMANENTLY ERASED." -ForegroundColor Red
$confirmNumber = Read-Host "Type the disk number again to confirm ($diskNumber)"
if ($confirmNumber -ne $diskNumber) {
    Write-Host "Confirmation did not match. Aborted for safety." -ForegroundColor Yellow
    exit 1
}
Confirm-OrAbort "Final confirmation: wipe and deploy Windows to Disk $diskNumber"

Write-Host "`nWiping and partitioning Disk $diskNumber (GPT/UEFI layout)..."

$diskpartScript = @"
select disk $diskNumber
clean
convert gpt
create partition efi size=100
format fs=fat32 quick label="System"
assign letter=S
create partition msr size=16
create partition primary
format fs=ntfs quick label="Windows"
assign letter=W
exit
"@

$diskpartScriptPath = Join-Path $env:TEMP 'osmaster-diskpart.txt'
$diskpartScript | Out-File -FilePath $diskpartScriptPath -Encoding ascii
diskpart /s $diskpartScriptPath

Write-Host "Partitioning complete: S: (EFI), W: (Windows)." -ForegroundColor Green

# ----------------------------------------------------------------------
# STEP 3 — Apply the Windows image and make it bootable
# ----------------------------------------------------------------------
Write-Section "Step 3: Deploying Windows image"

Write-Host "Mounting ISO..."
$mountResult = Mount-DiskImage -ImagePath $IsoPath -PassThru
$isoDriveLetter = ($mountResult | Get-Volume).DriveLetter
$isoRoot = "${isoDriveLetter}:"

$wimPath = Join-Path $isoRoot 'sources\install.wim'
if (-not (Test-Path $wimPath)) {
    # Some ISOs ship install.esd instead of install.wim
    $wimPath = Join-Path $isoRoot 'sources\install.esd'
}
if (-not (Test-Path $wimPath)) {
    Write-Host "Could not find install.wim or install.esd on the mounted ISO." -ForegroundColor Red
    Dismount-DiskImage -ImagePath $IsoPath
    exit 1
}

Write-Host "`nAvailable editions in this image:`n"
Get-WindowsImage -ImagePath $wimPath | Format-Table ImageIndex, ImageName -AutoSize

$imageIndex = Read-Host "`nEnter the image INDEX to deploy"

Write-Host "`nApplying image (this takes a while — grab a coffee)..."
Expand-WindowsImage -ImagePath $wimPath -Index $imageIndex -ApplyPath 'W:\'

Write-Host "Making the disk bootable..."
& bcdboot 'W:\Windows' /s S: /f UEFI

Write-Host "Unmounting ISO..."
Dismount-DiskImage -ImagePath $IsoPath

Write-Section "Done"
Write-Host "Windows has been deployed to Disk $diskNumber." -ForegroundColor Green
Write-Host "Reboot and select this disk in your boot menu to continue into Windows OOBE." -ForegroundColor Green
