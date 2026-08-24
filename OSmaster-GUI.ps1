#Requires -RunAsAdministrator
<#
.SYNOPSIS
    OSmaster GUI -- native Windows app wrapping the whole OSmaster toolkit.

.DESCRIPTION
    A tabbed WPF window: an Instructions tab explaining every tool, and one
    Run tab per tool (Windows deploy, Xbox recovery, PlayStation recovery).
    All destructive actions require selecting a target from a live list
    AND typing a confirmation value before the action button enables.

    This is a single self-contained script -- no Node/npm/Electron install
    required, just PowerShell (built into Windows) run as Administrator.
#>

Add-Type -AssemblyName PresentationFramework, System.Windows.Forms, WindowsBase

# ---------------------------------------------------------------------
# Shared state for background tasks + logging
# ---------------------------------------------------------------------
$sync = [hashtable]::Synchronized(@{
    Log     = New-Object System.Collections.Generic.List[string]
    Running = $false
})
$logCursor = 0

function Start-BackgroundTask {
    param([scriptblock]$ScriptBlock, [hashtable]$Params = @{})
    if ($sync.Running) { return $null }
    $sync.Running = $true
    $ps = [PowerShell]::Create()
    $ps.Runspace = [runspacefactory]::CreateRunspace()
    $ps.Runspace.Open()
    $ps.Runspace.SessionStateProxy.SetVariable('sync', $sync)
    foreach ($k in $Params.Keys) { $ps.Runspace.SessionStateProxy.SetVariable($k, $Params[$k]) }
    [void]$ps.AddScript($ScriptBlock)
    $handle = $ps.BeginInvoke()
    return [pscustomobject]@{ PS = $ps; Handle = $handle }
}

# ---------------------------------------------------------------------
# XAML — window layout
# ---------------------------------------------------------------------
[xml]$xaml = @'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="OSmaster" Height="720" Width="980" WindowStartupLocation="CenterScreen">
  <Grid Margin="10">
    <Grid.RowDefinitions>
      <RowDefinition Height="*"/>
      <RowDefinition Height="180"/>
    </Grid.RowDefinitions>

    <TabControl Grid.Row="0" Name="MainTabs">

      <TabItem Header="Instructions">
        <Grid Margin="10">
          <Grid.RowDefinitions>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="*"/>
          </Grid.RowDefinitions>
          <StackPanel Orientation="Horizontal" Grid.Row="0" Margin="0,0,0,10">
            <TextBlock Text="Tool:" VerticalAlignment="Center" Margin="0,0,8,0" FontWeight="Bold"/>
            <ComboBox Name="InstructionsPicker" Width="320"/>
          </StackPanel>
          <TextBox Name="InstructionsText" Grid.Row="1" IsReadOnly="True" TextWrapping="Wrap"
                    VerticalScrollBarVisibility="Auto" FontFamily="Consolas" FontSize="13"
                    Background="#F6F6F6" Padding="10"/>
        </Grid>
      </TabItem>

      <TabItem Header="Deploy Windows">
        <Grid Margin="10">
          <Grid.RowDefinitions>
            <RowDefinition Height="Auto"/><RowDefinition Height="Auto"/><RowDefinition Height="Auto"/>
            <RowDefinition Height="Auto"/><RowDefinition Height="Auto"/><RowDefinition Height="Auto"/>
            <RowDefinition Height="Auto"/><RowDefinition Height="Auto"/><RowDefinition Height="*"/>
          </Grid.RowDefinitions>

          <StackPanel Orientation="Horizontal" Grid.Row="0" Margin="0,4">
            <TextBlock Text="Windows version:" Width="150" VerticalAlignment="Center"/>
            <ComboBox Name="WinVersion" Width="150">
              <ComboBoxItem Content="11" IsSelected="True"/>
              <ComboBoxItem Content="10"/>
              <ComboBoxItem Content="8.1"/>
            </ComboBox>
          </StackPanel>

          <StackPanel Orientation="Horizontal" Grid.Row="1" Margin="0,4">
            <TextBlock Text="Edition:" Width="150" VerticalAlignment="Center"/>
            <ComboBox Name="WinEdition" Width="200">
              <ComboBoxItem Content="Pro" IsSelected="True"/>
              <ComboBoxItem Content="Home"/>
              <ComboBoxItem Content="Education"/>
              <ComboBoxItem Content="Enterprise"/>
              <ComboBoxItem Content="Pro Education"/>
              <ComboBoxItem Content="Pro for Workstations"/>
              <ComboBoxItem Content="(let Fido prompt)"/>
            </ComboBox>
            <TextBlock Text="  not every edition exists for every version -- Fido will tell you if it doesn't" Foreground="Gray" VerticalAlignment="Center"/>
          </StackPanel>

          <StackPanel Orientation="Horizontal" Grid.Row="2" Margin="0,4">
            <TextBlock Text="Architecture:" Width="150" VerticalAlignment="Center"/>
            <ComboBox Name="WinArch" Width="120">
              <ComboBoxItem Content="x64" IsSelected="True"/>
              <ComboBoxItem Content="x86"/>
              <ComboBoxItem Content="arm64"/>
            </ComboBox>
            <TextBlock Text="   Specific build (optional):" VerticalAlignment="Center" Margin="20,0,8,0"/>
            <TextBox Name="WinRelease" Width="120"/>
            <TextBlock Text="  e.g. 21H1, 1607 -- blank = latest" Foreground="Gray" VerticalAlignment="Center"/>
          </StackPanel>

          <StackPanel Orientation="Horizontal" Grid.Row="3" Margin="0,4">
            <TextBlock Text="Or use existing ISO:" Width="150" VerticalAlignment="Center"/>
            <TextBox Name="IsoPathBox" Width="420" IsReadOnly="True"/>
            <Button Name="BrowseIsoBtn" Content="Browse..." Width="90" Margin="8,0,0,0"/>
          </StackPanel>

          <StackPanel Orientation="Horizontal" Grid.Row="4" Margin="0,10,0,4">
            <TextBlock Text="Target disk:" Width="150" VerticalAlignment="Center"/>
            <ComboBox Name="DiskPicker" Width="500"/>
            <Button Name="RefreshDisksBtn" Content="Refresh" Width="90" Margin="8,0,0,0"/>
          </StackPanel>

          <TextBlock Grid.Row="5" Text="EVERYTHING ON THE SELECTED DISK WILL BE PERMANENTLY ERASED."
                     Foreground="Red" FontWeight="Bold" Margin="0,4"/>

          <StackPanel Orientation="Horizontal" Grid.Row="6" Margin="0,4">
            <TextBlock Text="Type disk number to confirm:" Width="220" VerticalAlignment="Center"/>
            <TextBox Name="WinConfirmBox" Width="80"/>
          </StackPanel>

          <StackPanel Orientation="Horizontal" Grid.Row="7" Margin="0,10">
            <Button Name="DeployWinBtn" Content="Wipe &amp; Deploy Windows" Width="220" Height="34"
                    Background="#B5482F" Foreground="White" FontWeight="Bold" IsEnabled="False"/>
          </StackPanel>
        </Grid>
      </TabItem>

      <TabItem Header="Xbox Recovery">
        <Grid Margin="10">
          <Grid.RowDefinitions>
            <RowDefinition Height="Auto"/><RowDefinition Height="Auto"/><RowDefinition Height="Auto"/>
            <RowDefinition Height="Auto"/><RowDefinition Height="Auto"/><RowDefinition Height="*"/>
          </Grid.RowDefinitions>

          <Button Name="OpenXboxPageBtn" Grid.Row="0" Content="Open official Microsoft OSU1 download page"
                  Width="340" HorizontalAlignment="Left" Margin="0,4"/>

          <StackPanel Orientation="Horizontal" Grid.Row="1" Margin="0,10,0,4">
            <TextBlock Text="Downloaded OSU1.zip:" Width="170" VerticalAlignment="Center"/>
            <TextBox Name="OsuZipBox" Width="420" IsReadOnly="True"/>
            <Button Name="BrowseOsuBtn" Content="Browse..." Width="90" Margin="8,0,0,0"/>
          </StackPanel>

          <StackPanel Orientation="Horizontal" Grid.Row="2" Margin="0,4">
            <TextBlock Text="Target USB drive:" Width="170" VerticalAlignment="Center"/>
            <ComboBox Name="XboxUsbPicker" Width="200"/>
            <Button Name="RefreshXboxUsbBtn" Content="Refresh" Width="90" Margin="8,0,0,0"/>
          </StackPanel>

          <TextBlock Grid.Row="3" Text="THE SELECTED USB DRIVE WILL BE ERASED AND FORMATTED AS NTFS."
                     Foreground="Red" FontWeight="Bold" Margin="0,8,0,4"/>

          <StackPanel Orientation="Horizontal" Grid.Row="4" Margin="0,4">
            <TextBlock Text="Type drive letter to confirm:" Width="220" VerticalAlignment="Center"/>
            <TextBox Name="XboxConfirmBox" Width="60"/>
            <Button Name="PrepXboxBtn" Content="Prepare Recovery USB" Width="200" Height="34" Margin="20,0,0,0"
                    Background="#2F6B5E" Foreground="White" FontWeight="Bold" IsEnabled="False"/>
          </StackPanel>
        </Grid>
      </TabItem>

      <TabItem Header="PlayStation Recovery">
        <Grid Margin="10">
          <Grid.RowDefinitions>
            <RowDefinition Height="Auto"/><RowDefinition Height="Auto"/><RowDefinition Height="Auto"/>
            <RowDefinition Height="Auto"/><RowDefinition Height="Auto"/><RowDefinition Height="Auto"/>
            <RowDefinition Height="*"/>
          </Grid.RowDefinitions>

          <StackPanel Orientation="Horizontal" Grid.Row="0" Margin="0,4">
            <TextBlock Text="Console:" Width="150" VerticalAlignment="Center"/>
            <ComboBox Name="PsConsolePicker" Width="120">
              <ComboBoxItem Content="PS5" IsSelected="True"/>
              <ComboBoxItem Content="PS4"/>
              <ComboBoxItem Content="PS3"/>
            </ComboBox>
            <Button Name="OpenPsPageBtn" Content="Open official Sony download page" Width="260" Margin="20,0,0,0"/>
          </StackPanel>

          <TextBlock Grid.Row="1" Margin="0,8,0,4" Foreground="DarkOrange" TextWrapping="Wrap"
                     Text="Software repair only. This will NOT fix hardware faults (dead PSU, PS3 YLOD cracked solder joints, etc.)."/>

          <StackPanel Orientation="Horizontal" Grid.Row="2" Margin="0,10,0,4">
            <TextBlock Text="Downloaded update file:" Width="170" VerticalAlignment="Center"/>
            <TextBox Name="PupPathBox" Width="420" IsReadOnly="True"/>
            <Button Name="BrowsePupBtn" Content="Browse..." Width="90" Margin="8,0,0,0"/>
          </StackPanel>

          <StackPanel Orientation="Horizontal" Grid.Row="3" Margin="0,4">
            <TextBlock Text="Target USB drive:" Width="170" VerticalAlignment="Center"/>
            <ComboBox Name="PsUsbPicker" Width="200"/>
            <Button Name="RefreshPsUsbBtn" Content="Refresh" Width="90" Margin="8,0,0,0"/>
          </StackPanel>

          <TextBlock Grid.Row="4" Text="THE SELECTED USB DRIVE WILL BE ERASED AND FORMATTED AS exFAT."
                     Foreground="Red" FontWeight="Bold" Margin="0,8,0,4"/>

          <StackPanel Orientation="Horizontal" Grid.Row="5" Margin="0,4">
            <TextBlock Text="Type drive letter to confirm:" Width="220" VerticalAlignment="Center"/>
            <TextBox Name="PsConfirmBox" Width="60"/>
            <Button Name="PrepPsBtn" Content="Prepare Recovery USB" Width="200" Height="34" Margin="20,0,0,0"
                    Background="#2F6B5E" Foreground="White" FontWeight="Bold" IsEnabled="False"/>
          </StackPanel>
        </Grid>
      </TabItem>

      <TabItem Header="macOS (info)">
        <TextBox IsReadOnly="True" TextWrapping="Wrap" Margin="10" FontFamily="Consolas" FontSize="13"
                  Text="macOS deployment cannot run from this Windows app -- Apple's installer tools (softwareupdate, createinstallmedia, startosinstall) only exist on macOS itself. Copy Deploy-macOS.sh to the target Mac and run it there:&#10;&#10;  chmod +x Deploy-macOS.sh&#10;  ./Deploy-macOS.sh --help&#10;&#10;See README.md in the repo for full details."/>
      </TabItem>

    </TabControl>

    <GroupBox Header="Log" Grid.Row="1" Margin="0,10,0,0">
      <TextBox Name="LogBox" IsReadOnly="True" TextWrapping="Wrap" VerticalScrollBarVisibility="Auto"
                FontFamily="Consolas" FontSize="12" Background="#111318" Foreground="#D7DCE0"/>
    </GroupBox>
  </Grid>
</Window>
'@

$reader = New-Object System.Xml.XmlNodeReader $xaml
$window = [Windows.Markup.XamlReader]::Load($reader)

# ---------------------------------------------------------------------
# First-run: offer to create a Desktop shortcut, regardless of whether
# the app was launched via OSmaster.vbs or directly via PowerShell.
# ---------------------------------------------------------------------
function Offer-DesktopShortcut {
    $desktop = [Environment]::GetFolderPath('Desktop')
    $shortcutPath = Join-Path $desktop 'OSmaster.lnk'
    if (Test-Path $shortcutPath) { return } # already created, don't ask again

    $result = [System.Windows.MessageBox]::Show(
        "Add an OSmaster shortcut to your Desktop?`n`nYou'll be able to launch the app from there next time instead of coming back to this folder.",
        "OSmaster",
        [System.Windows.MessageBoxButton]::YesNo,
        [System.Windows.MessageBoxImage]::Question
    )
    if ($result -ne [System.Windows.MessageBoxResult]::Yes) { return }

    $scriptDir = $PSScriptRoot
    $vbsPath = Join-Path $scriptDir 'OSmaster.vbs'
    $iconPath = Join-Path $scriptDir 'icon.ico'

    try {
        $wsh = New-Object -ComObject WScript.Shell
        $link = $wsh.CreateShortcut($shortcutPath)
        if (Test-Path $vbsPath) {
            # Prefer routing through OSmaster.vbs -- it launches silently
            # (no console) and elevates properly via UAC.
            $link.TargetPath = $vbsPath
        } else {
            # Fallback if the .vbs isn't present alongside this script for
            # some reason: launch PowerShell directly. Note this won't
            # auto-elevate on double-click the way the .vbs does -- it'll
            # rely on the #Requires -RunAsAdministrator check at the top
            # of this script, which will show its own elevation prompt.
            $link.TargetPath = 'powershell.exe'
            $link.Arguments = "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$PSCommandPath`""
        }
        $link.WorkingDirectory = $scriptDir
        if (Test-Path $iconPath) { $link.IconLocation = $iconPath }
        $link.Description = 'OSmaster - OS deployment and console recovery toolkit'
        $link.Save()
        [System.Windows.MessageBox]::Show("Desktop shortcut created.", "OSmaster", 'OK', 'Information') | Out-Null
    } catch {
        [System.Windows.MessageBox]::Show("Couldn't create the shortcut: $($_.Exception.Message)", "OSmaster", 'OK', 'Warning') | Out-Null
    }
}
Offer-DesktopShortcut

# Grab named controls
$c = @{}
$xaml.SelectNodes("//*[@*[local-name()='Name']]") | ForEach-Object {
    $name = $_.Name
    $c[$name] = $window.FindName($name)
}

# ---------------------------------------------------------------------
# Instructions content
# ---------------------------------------------------------------------
$instructions = [ordered]@{
    'Overview' = @"
OSmaster -- OS deployment and console recovery toolkit.

Pick a tool from this dropdown to read what it does before running it.
Nothing destructive happens anywhere in this app until you've selected a
target AND typed its confirmation value -- the action buttons stay
disabled until then.

TOOLS IN THIS APP
  - Deploy Windows: fetches an official Windows 8.1/10/11 ISO (via Fido)
    and deploys it directly onto a target disk -- no Setup GUI involved.
  - Xbox Recovery: prepares a USB for Microsoft's official OSU1 offline
    system update / repair process.
  - PlayStation Recovery: prepares a USB for Sony's official PS3/PS4/PS5
    Safe Mode system software reinstall.
  - macOS: info-only tab -- that tool must run on an actual Mac, see the
    macOS tab for details.
"@
    'Deploy Windows' = @"
WHAT THIS DOES
  Downloads an official Windows ISO from Microsoft (via Fido), then
  partitions, formats, and deploys it directly onto a target disk -- no
  Windows Setup GUI involved. On first boot, the target disk goes
  straight into Windows OOBE (the first-run setup screens).

SUPPORTS: Windows 8.1, 10, and 11 (there is no Windows 9 -- Microsoft
skipped that number entirely, going straight from 8.1 to 10), in x64/
x86/arm64, and optionally a specific historical build (e.g. 21H1, 1607)
rather than just latest -- useful for matching older hardware/driver
compatibility. Edition is a dropdown of common options; not every
edition exists for every version, Fido will tell you if your pick isn't
available for the version selected. Windows 7 is not available through
this tool at all -- Microsoft no longer serves official retail ISO links
for it, so there's no legitimate source left to pull from. Windows
Server / LTSC / Insider builds use entirely different distribution
channels and aren't covered here.

BEFORE YOU RUN THIS
  - Know exactly which physical disk is your target -- identify it by
    SIZE in the dropdown, not just its disk number (numbers can shift
    between sessions).
  - The Deploy button stays disabled until you type the exact disk
    number into the confirm box. There is no undo once you click it.
  - If the only disk available is the one this PC is currently running
    from, stop -- this tool is for a blank/spare target disk.
"@
    'Xbox Recovery' = @"
WHAT THIS DOES
  Prepares a USB drive for Xbox's OFFICIAL Offline System Update (OSU1)
  repair process -- Microsoft's own recovery mechanism for consoles
  stuck on a black screen, boot loop, or corrupted update. Does not
  erase games or saves.

  This does not push an OS onto the USB the way the Deploy Windows tab
  does to a disk -- it preps an installer, and the CONSOLE ITSELF reads
  it and repairs its own system software.

BEFORE YOU RUN THIS
  - Click "Open official Microsoft OSU1 download page" and download the
    OSU1.zip matching your console family yourself -- Microsoft doesn't
    publish a stable direct link, so this step stays manual.
  - Pick the USB drive by letter; it WILL be reformatted as NTFS.
"@
    'PlayStation Recovery' = @"
WHAT THIS DOES
  Prepares a USB drive for Sony's OFFICIAL system software reinstall
  process (PS3, PS4, or PS5) -- Safe Mode recovery. Handles the exact
  required folder structure and filename automatically, including PS3's
  oddball "PS3UPDAT.PUP" (no E) vs PS4/PS5's "PS4UPDATE.PUP"/
  "PS5UPDATE.PUP".

IMPORTANT: this is a SOFTWARE repair only. It will not fix hardware
faults -- a dead PSU, or the classic PS3 YLOD from cracked GPU/CPU
solder joints, needs board-level repair, not a system software
reinstall.

BEFORE YOU RUN THIS
  - Pick the console first, then click "Open official Sony download
    page" and download the matching update/reinstallation file
    yourself.
  - Pick the USB drive by letter; it WILL be reformatted as exFAT.
"@
    'macOS' = @"
macOS deployment cannot run from this Windows app. Apple's installer
tools (softwareupdate, createinstallmedia, startosinstall) only exist on
macOS itself -- this is an Apple platform restriction, not a limitation
of this app.

Copy Deploy-macOS.sh to the target Mac and run it there:
  chmod +x Deploy-macOS.sh
  ./Deploy-macOS.sh --help
"@
}
foreach ($k in $instructions.Keys) { [void]$c['InstructionsPicker'].Items.Add($k) }
$c['InstructionsPicker'].SelectedIndex = 0
$c['InstructionsText'].Text = $instructions['Overview']
$c['InstructionsPicker'].Add_SelectionChanged({
    $c['InstructionsText'].Text = $instructions[$c['InstructionsPicker'].SelectedItem.ToString()]
})

# ---------------------------------------------------------------------
# Logging helper (main thread)
# ---------------------------------------------------------------------
function Append-Log([string]$line) {
    $c['LogBox'].AppendText("$line`r`n")
    $c['LogBox'].ScrollToEnd()
}

# Poll timer: drains background-task log entries, re-enables UI when done
$timer = New-Object System.Windows.Threading.DispatcherTimer
$timer.Interval = [TimeSpan]::FromMilliseconds(300)
$timer.Add_Tick({
    while ($logCursor -lt $sync.Log.Count) {
        Append-Log $sync.Log[$logCursor]
        $logCursor++
    }
})
$timer.Start()

# ---------------------------------------------------------------------
# Deploy Windows tab logic
# ---------------------------------------------------------------------
function Refresh-Disks {
    $c['DiskPicker'].Items.Clear()
    Get-Disk | ForEach-Object {
        $sizeGB = [math]::Round($_.Size / 1GB, 1)
        [void]$c['DiskPicker'].Items.Add("Disk $($_.Number) - $($_.FriendlyName) - ${sizeGB}GB")
    }
}
$c['RefreshDisksBtn'].Add_Click({ Refresh-Disks })
Refresh-Disks

$c['BrowseIsoBtn'].Add_Click({
    $dlg = New-Object System.Windows.Forms.OpenFileDialog
    $dlg.Filter = "ISO files (*.iso)|*.iso"
    if ($dlg.ShowDialog() -eq 'OK') { $c['IsoPathBox'].Text = $dlg.FileName }
})

function Update-WinDeployButton {
    $picked = $c['DiskPicker'].SelectedItem
    if (-not $picked) { $c['DeployWinBtn'].IsEnabled = $false; return }
    $diskNum = ($picked -split ' ')[1]
    $c['DeployWinBtn'].IsEnabled = ($c['WinConfirmBox'].Text -eq $diskNum)
}
$c['DiskPicker'].Add_SelectionChanged({ Update-WinDeployButton })
$c['WinConfirmBox'].Add_TextChanged({ Update-WinDeployButton })

$c['DeployWinBtn'].Add_Click({
    $diskNum = ($c['DiskPicker'].SelectedItem -split ' ')[1]
    $isoPath = $c['IsoPathBox'].Text
    $winVer = $c['WinVersion'].Text
    $edition = $c['WinEdition'].Text
    if ($edition -eq '(let Fido prompt)') { $edition = '' }
    $arch = $c['WinArch'].Text
    $release = $c['WinRelease'].Text

    Append-Log "Starting Windows deployment to Disk $diskNum..."
    Start-BackgroundTask -Params @{ diskNum = $diskNum; isoPath = $isoPath; winVer = $winVer; edition = $edition; arch = $arch; release = $release; scriptRoot = $PSScriptRoot } -ScriptBlock {
        try {
            if (-not $isoPath) {
                $sync.Log.Add("No ISO supplied -- fetching via Fido for Windows $winVer $edition ($arch)" + $(if ($release) { ", build $release" } else { ", latest build" }) + " ...")
                $fidoPath = Join-Path $scriptRoot 'Fido.ps1'
                if (-not (Test-Path $fidoPath)) {
                    $sync.Log.Add("Downloading Fido.ps1 to: $fidoPath")
                    Invoke-WebRequest -Uri 'https://raw.githubusercontent.com/pbatard/Fido/master/Fido.ps1' -OutFile $fidoPath -UseBasicParsing
                }
                $fidoArgs = @('-ExecutionPolicy','Bypass','-File',$fidoPath,'-Win',$winVer,'-Arch',$arch)
                if ($edition) { $fidoArgs += @('-Ed', $edition) }
                if ($release) { $fidoArgs += @('-Rel', $release) }
                $sync.Log.Add("Running: powershell.exe $($fidoArgs -join ' ')")
                & powershell.exe @fidoArgs
                $iso = Get-ChildItem -Path $scriptRoot -Filter '*.iso' -Recurse | Sort-Object LastWriteTime -Descending | Select-Object -First 1
                if (-not $iso) { throw "Fido did not produce an ISO file. Check the log lines above for what Fido itself printed." }
                $isoPath = $iso.FullName
            }
            $sync.Log.Add("Using ISO: $isoPath")

            $sync.Log.Add("Partitioning Disk $diskNum ...")
            $dpScript = @"
select disk $diskNum
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
            $dpPath = Join-Path $env:TEMP 'osmaster-gui-diskpart.txt'
            $dpScript | Out-File -FilePath $dpPath -Encoding ascii
            diskpart /s $dpPath | Out-Null
            $sync.Log.Add("Partitioning complete.")

            $sync.Log.Add("Mounting ISO...")
            $mount = Mount-DiskImage -ImagePath $isoPath -PassThru
            $isoLetter = ($mount | Get-Volume).DriveLetter
            $wim = "${isoLetter}:\sources\install.wim"
            if (-not (Test-Path $wim)) { $wim = "${isoLetter}:\sources\install.esd" }

            $sync.Log.Add("Applying image (this takes a while)...")
            Expand-WindowsImage -ImagePath $wim -Index 1 -ApplyPath 'W:\' | Out-Null

            $sync.Log.Add("Making bootable...")
            & bcdboot 'W:\Windows' /s S: /f UEFI | Out-Null

            Dismount-DiskImage -ImagePath $isoPath | Out-Null
            $sync.Log.Add("DONE. Reboot and select Disk $diskNum to continue into Windows OOBE.")
        } catch {
            $sync.Log.Add("ERROR: $($_.Exception.Message)")
        } finally {
            $sync.Running = $false
        }
    }
})

# ---------------------------------------------------------------------
# Xbox Recovery tab logic
# ---------------------------------------------------------------------
$c['OpenXboxPageBtn'].Add_Click({ Start-Process "https://support.xbox.com/help/hardware-network/console/offline-system-update" })
$c['BrowseOsuBtn'].Add_Click({
    $dlg = New-Object System.Windows.Forms.OpenFileDialog
    $dlg.Filter = "OSU1 zip (*.zip)|*.zip"
    if ($dlg.ShowDialog() -eq 'OK') { $c['OsuZipBox'].Text = $dlg.FileName }
})
function Refresh-RemovableDrives($comboBox) {
    $comboBox.Items.Clear()
    Get-Volume | Where-Object { $_.DriveLetter -and $_.DriveType -eq 'Removable' } | ForEach-Object {
        [void]$comboBox.Items.Add("$($_.DriveLetter): ($([math]::Round($_.Size/1GB,1))GB)")
    }
}
$c['RefreshXboxUsbBtn'].Add_Click({ Refresh-RemovableDrives $c['XboxUsbPicker'] })
Refresh-RemovableDrives $c['XboxUsbPicker']

function Update-XboxButton {
    $picked = $c['XboxUsbPicker'].SelectedItem
    if (-not $picked) { $c['PrepXboxBtn'].IsEnabled = $false; return }
    $letter = ($picked -split ':')[0]
    $c['PrepXboxBtn'].IsEnabled = ($c['XboxConfirmBox'].Text.ToUpper() -eq $letter)
}
$c['XboxUsbPicker'].Add_SelectionChanged({ Update-XboxButton })
$c['XboxConfirmBox'].Add_TextChanged({ Update-XboxButton })

$c['PrepXboxBtn'].Add_Click({
    $letter = ($c['XboxUsbPicker'].SelectedItem -split ':')[0]
    $osuZip = $c['OsuZipBox'].Text
    if (-not $osuZip) { Append-Log "ERROR: select the downloaded OSU1.zip first."; return }

    Append-Log "Preparing Xbox recovery USB on ${letter}:..."
    Start-BackgroundTask -Params @{ letter = $letter; osuZip = $osuZip } -ScriptBlock {
        try {
            $sync.Log.Add("Formatting ${letter}: as NTFS...")
            Format-Volume -DriveLetter $letter -FileSystem NTFS -NewFileSystemLabel "XBOXOSU" -Confirm:$false | Out-Null

            $extract = Join-Path $env:TEMP "osu1_gui_extract"
            if (Test-Path $extract) { Remove-Item $extract -Recurse -Force }
            $sync.Log.Add("Extracting OSU1.zip...")
            Expand-Archive -Path $osuZip -DestinationPath $extract -Force

            $folder = Get-ChildItem -Path $extract -Filter '$SystemUpdate' -Directory -Recurse | Select-Object -First 1
            if (-not $folder) { throw "No `$SystemUpdate folder found inside that zip -- is it the official OSU1 file?" }

            Copy-Item -Path $folder.FullName -Destination "${letter}:\`$SystemUpdate" -Recurse -Force
            $sync.Log.Add("DONE. USB ready. On the console: power off, unplug 30s, plug in USB, hold Pair+Eject (or just Pair on Series S) then press Xbox button until 2 power tones, then choose offline update in Startup Troubleshooter.")
        } catch {
            $sync.Log.Add("ERROR: $($_.Exception.Message)")
        } finally {
            $sync.Running = $false
        }
    }
})

# ---------------------------------------------------------------------
# PlayStation Recovery tab logic
# ---------------------------------------------------------------------
$psUrls = @{
    'PS3' = 'https://www.playstation.com/en-us/support/hardware/ps3-system-software/'
    'PS4' = 'https://www.playstation.com/en-us/support/hardware/ps4-system-software/'
    'PS5' = 'https://www.playstation.com/en-us/support/hardware/ps5-system-software/'
}
$psFileNames = @{ 'PS3' = 'PS3UPDAT.PUP'; 'PS4' = 'PS4UPDATE.PUP'; 'PS5' = 'PS5UPDATE.PUP' }

$c['OpenPsPageBtn'].Add_Click({
    $console = $c['PsConsolePicker'].Text
    Start-Process $psUrls[$console]
})
$c['BrowsePupBtn'].Add_Click({
    $dlg = New-Object System.Windows.Forms.OpenFileDialog
    $dlg.Filter = "PlayStation update file (*.pup)|*.pup|All files|*.*"
    if ($dlg.ShowDialog() -eq 'OK') { $c['PupPathBox'].Text = $dlg.FileName }
})
$c['RefreshPsUsbBtn'].Add_Click({ Refresh-RemovableDrives $c['PsUsbPicker'] })
Refresh-RemovableDrives $c['PsUsbPicker']

function Update-PsButton {
    $picked = $c['PsUsbPicker'].SelectedItem
    if (-not $picked) { $c['PrepPsBtn'].IsEnabled = $false; return }
    $letter = ($picked -split ':')[0]
    $c['PrepPsBtn'].IsEnabled = ($c['PsConfirmBox'].Text.ToUpper() -eq $letter)
}
$c['PsUsbPicker'].Add_SelectionChanged({ Update-PsButton })
$c['PsConfirmBox'].Add_TextChanged({ Update-PsButton })

$c['PrepPsBtn'].Add_Click({
    $letter = ($c['PsUsbPicker'].SelectedItem -split ':')[0]
    $pupPath = $c['PupPathBox'].Text
    $console = $c['PsConsolePicker'].Text
    $fileName = $psFileNames[$console]
    if (-not $pupPath) { Append-Log "ERROR: select the downloaded update file first."; return }

    Append-Log "Preparing $console recovery USB on ${letter}:..."
    Start-BackgroundTask -Params @{ letter = $letter; pupPath = $pupPath; console = $console; fileName = $fileName } -ScriptBlock {
        try {
            $sync.Log.Add("Formatting ${letter}: as exFAT...")
            Format-Volume -DriveLetter $letter -FileSystem exFAT -NewFileSystemLabel "${console}REC" -Confirm:$false | Out-Null

            $destFolder = "${letter}:\$console\UPDATE"
            New-Item -ItemType Directory -Force -Path $destFolder | Out-Null
            Copy-Item -Path $pupPath -Destination (Join-Path $destFolder $fileName) -Force

            $sync.Log.Add("DONE. Placed as $destFolder\$fileName")
            if ($console -eq 'PS3') {
                $sync.Log.Add("On the PS3: power off fully, plug in USB, hold power until it beeps twice/powers off/beeps again -- boots Recovery Menu -- choose System Update.")
            } else {
                $sync.Log.Add("On the ${console}: power off, plug in USB, hold power until second beep (~7s) -- boots Safe Mode -- pair a controller via USB, choose Update or Reinstall System Software.")
            }
        } catch {
            $sync.Log.Add("ERROR: $($_.Exception.Message)")
        } finally {
            $sync.Running = $false
        }
    }
})

# ---------------------------------------------------------------------
$window.ShowDialog() | Out-Null
