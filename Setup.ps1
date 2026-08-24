<#
.SYNOPSIS
    OSmaster one-time setup. Run this once (right-click this file ->
    "Run with PowerShell") to create a proper launch shortcut.

.DESCRIPTION
    This creates a standard Windows shortcut (.lnk) with the native
    "Run as administrator" flag set -- the exact same flag Windows sets
    when you right-click any shortcut, open Properties > Advanced, and
    tick that checkbox by hand. Double-clicking the resulting shortcut
    triggers a normal UAC prompt through Windows' own shortcut handling.

    This script itself does NOT elevate, does NOT hide any window, and
    does NOT download or run anything from the internet -- it only
    creates a shortcut file, using the standard WScript.Shell COM object
    that ships with every Windows install. That transparency matters:
    the previous VBScript-based launcher used a scripted silent-elevation
    pattern (ShellExecute with the "runas" verb + a hidden window), which
    is a common antivirus heuristic trigger even though nothing malicious
    was actually happening. This approach avoids that pattern entirely.
#>

$scriptDir = $PSScriptRoot
$targetScript = Join-Path $scriptDir 'OSmaster-GUI.ps1'
$iconPath = Join-Path $scriptDir 'icon.ico'

if (-not (Test-Path $targetScript)) {
    Write-Host "ERROR: OSmaster-GUI.ps1 not found in this folder. Keep this setup script alongside it." -ForegroundColor Red
    Read-Host "Press Enter to close"
    exit 1
}

function Set-ShortcutRunAsAdmin([string]$LinkPath) {
    $bytes = [System.IO.File]::ReadAllBytes($LinkPath)
    # Byte 21 of the .lnk header holds link flags; bit 0x20 is the
    # documented "Run as administrator" bit -- same one the Properties
    # dialog's checkbox sets.
    $bytes[21] = $bytes[21] -bor 0x20
    [System.IO.File]::WriteAllBytes($LinkPath, $bytes)
}

function New-OSmasterShortcut([string]$ShortcutPath) {
    $wsh = New-Object -ComObject WScript.Shell
    $link = $wsh.CreateShortcut($ShortcutPath)
    $link.TargetPath = 'powershell.exe'
    $link.Arguments = "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$targetScript`""
    $link.WorkingDirectory = $scriptDir
    if (Test-Path $iconPath) { $link.IconLocation = $iconPath }
    $link.Description = 'OSmaster - OS deployment and console recovery toolkit'
    $link.Save()
    Set-ShortcutRunAsAdmin -LinkPath $ShortcutPath
}

Write-Host "Creating shortcuts..." -ForegroundColor Cyan

# Shortcut right next to the app itself
$localShortcut = Join-Path $scriptDir 'OSmaster.lnk'
New-OSmasterShortcut -ShortcutPath $localShortcut
Write-Host "Created: $localShortcut" -ForegroundColor Green

# Ask before touching the Desktop
$answer = Read-Host "Also create a shortcut on your Desktop? (Y/N)"
if ($answer -match '^[Yy]') {
    $desktop = [Environment]::GetFolderPath('Desktop')
    $desktopShortcut = Join-Path $desktop 'OSmaster.lnk'
    New-OSmasterShortcut -ShortcutPath $desktopShortcut
    Write-Host "Created: $desktopShortcut" -ForegroundColor Green
}

Write-Host "`nDone. Double-click the shortcut to open OSmaster -- it'll show a normal Windows admin prompt, then open the app with no console window." -ForegroundColor Cyan
Read-Host "Press Enter to close"
