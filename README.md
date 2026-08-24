# OSmaster

## Download

|  | |
|---|---|
| 🪟 **Windows** | **[⬇ Download OSmaster for Windows](https://raw.githubusercontent.com/Jrodgers6446/OSmaster/main/dist/OSmaster-Windows.zip)** |
| 🍎 **macOS** | **[⬇ Download OSmaster for macOS](https://raw.githubusercontent.com/Jrodgers6446/OSmaster/main/dist/OSmaster-macOS.zip)** |

**Windows:** unzip anywhere, right-click `Setup.ps1` → "Run with PowerShell" once — creates a proper shortcut (optionally on your Desktop too). Double-click that shortcut going forward: approve the one Windows UAC prompt (required by Windows itself for admin rights, not something any app can skip), and the native tabbed app window opens — no console.

**macOS:** unzip, drag `OSmaster.app` to Applications or your Desktop, double-click. First launch needs a right-click → Open to get past Gatekeeper's unsigned-app warning (one-time only after that). Opens Terminal to do its work rather than a native window — see the macOS section further down for why that's a real platform constraint, not a shortcut taken.

These are plain zip files hosted directly in this repo (`/dist`), not GitHub Releases assets — same one-click download experience, just via a direct link.

## The scripts themselves (if you'd rather not use the packaged downloads)

A native tabbed GUI (`OSmaster-GUI.ps1`) plus the underlying scripts it wraps — one for Windows deployment, one for macOS, and two official-recovery tools for Xbox and PlayStation consoles.

## Start here: `OSmaster-GUI.ps1`

```powershell
.\OSmaster-GUI.ps1
```
or, for a proper double-click desktop app experience (no visible console):
```
OSmaster.vbs
```

A single window opens with an **Instructions** tab (pick a tool from the dropdown to read what it does, what it requires, what it erases) and one tab per tool with live controls — dropdowns populated from your actual attached disks/drives, file pickers instead of typed paths, and a shared log pane at the bottom showing progress in real time.

**Safety model:** every destructive action button (Deploy, Prepare Recovery USB) stays disabled until you both select a target from a live list *and* type that exact target's letter/number into a confirm box next to it. There's no way to click a destructive button by accident — it's physically disabled until the confirmation matches.

This is a single self-contained PowerShell script — no Node.js, no npm install, no build/packaging step. Just PowerShell (already built into Windows), run as Administrator.

> Note: this was built and reviewed carefully, but hasn't been run on real hardware yet — if you hit any errors on first run, let me know what PowerShell prints and I'll fix it.

If you'd rather not use the GUI, every underlying script also works standalone from the command line (see below), and `OSmaster.ps1` offers the same tool selection as a simple text menu instead of a window.

## Deploy-Windows.ps1

1. **Fetch** — downloads an official Windows ISO directly from Microsoft's servers using [Fido](https://github.com/pbatard/Fido) (no browser click-through, no third-party mirrors). Supports **Windows 8.1, 10, and 11**, across whichever editions Microsoft still distributes retail ISOs for (Home/Pro/Education/Enterprise — varies by version).
2. **Prepare** — partitions and formats a target disk with a standard UEFI/GPT layout (EFI system partition + Windows partition).
3. **Deploy** — applies the Windows image directly with DISM and makes it bootable with `bcdboot`, skipping the interactive Setup GUI entirely. On first boot, the target disk goes straight into Windows OOBE (the out-of-box setup screens).

Run on: Windows, PowerShell 5.1+, as Administrator.

> Note: plain Windows 8 (pre-8.1) retail ISOs are no longer distributed by Microsoft at all — 8.1 is the oldest version Fido (and this script) can fetch.

> ⚠️ **Known Fido issue:** Microsoft runs an anti-automation system ("Sentinel") on its download servers that can block Fido's requests outright — you'll see `Sentinel marked this request as rejected` if this happens. This is a real, currently-active issue affecting Fido and Rufus broadly (server-side IP flagging on Microsoft's end), not a bug here, and there's no code fix for it. A VPN generally doesn't help. If it happens: in the GUI, use the **"Get ISO from Microsoft"** button next to the ISO field to open the real download page and grab the ISO by hand instead; from the CLI, download manually from [microsoft.com/software-download/windows11](https://www.microsoft.com/software-download/windows11) (or `windows10ISO` for Windows 10) and pass it via `-IsoPath`.

## Deploy-macOS.sh

### How this differs from the Windows script

Windows and macOS have genuinely different distribution models, so this isn't just a language port of the same idea:

- **Apple's installer-fetching tools only run on macOS itself.** There's no equivalent of "run Fido from any OS to get a Windows-style ISO" for macOS — `softwareupdate` (Apple's own fetch command) and `createinstallmedia` (Apple's own media-creation tool) are macOS-only binaries. This script has to be run **on an actual Mac**, not from Windows or Linux. That's an Apple platform restriction, not a limitation of this script.
- **There's no single portable "ISO" file for macOS** the way Windows has — `softwareupdate --fetch-full-installer` downloads a full installer *application* (several GB) into `/Applications`, and that app itself contains the tools used in the next step.
- **Two different deployment modes**, matching what Apple's own tools support:
  1. **Bootable USB installer** (`createinstallmedia`) — same idea as making Windows install media.
  2. **Headless direct deployment** (`startosinstall`) — installs straight onto a target volume without manually booting from external media, similar in spirit to the Windows script's DISM/bcdboot approach, though the underlying mechanism is Apple's own installer assistant rather than an image-apply step.

### Usage

**Packaged app (recommended):** see the Download section above — `OSmaster.app` wraps this same script with a real icon and double-click launch via Terminal.

**Running the script directly:**
```zsh
chmod +x Deploy-macOS.sh
./Deploy-macOS.sh
```

It'll walk you through: listing available macOS versions Apple currently serves → fetching the one you choose → picking bootable-USB vs. direct-deploy → confirming the target volume (with an explicit `YES` confirmation, same safety pattern as the Windows script) → running the actual installer step.

Run on: an actual Mac, macOS, with `sudo` access.

### A note on hardware

Apple's installer tools are built for, and intended for, genuine Apple hardware. This script doesn't do anything to work around that — it's a straightforward wrapper around Apple's own `softwareupdate`/`createinstallmedia`/`startosinstall` commands, used the way Apple documents them.

## Prep-XboxRecovery.ps1 and Prep-PlayStationRecovery.ps1

These are a different category from the OS-install scripts above — they're **repair tools**, using each manufacturer's own official offline/Safe-Mode system software reinstall mechanism. Not jailbreaking, not homebrew, not firmware downgrades — the same official recovery path Microsoft and Sony document and support directly.

Both scripts follow the same pattern:
1. Open the correct official support page in your browser (Microsoft/Sony don't publish stable direct-download links for these files, so this step stays manual rather than relying on a URL that'll eventually break)
2. You download the official update/recovery file
3. The script formats a USB drive and places the file in the **exact** folder structure and filename the console requires — this is the part people most often get wrong by hand (case sensitivity, extra file extensions, wrong folder depth)
4. The script prints the exact button-combo/Safe-Mode steps for applying it on the console itself

### Xbox
```powershell
.\Prep-XboxRecovery.ps1
```
Supports Xbox One family and Xbox Series X|S, via Microsoft's official Offline System Update (OSU1) process. Formats the USB as NTFS, places the `$SystemUpdate` folder at the drive root. Does not erase games or saves.

### PlayStation
```powershell
.\Prep-PlayStationRecovery.ps1 -Console PS5
.\Prep-PlayStationRecovery.ps1 -Console PS4
.\Prep-PlayStationRecovery.ps1 -Console PS3
```
Formats the USB as exFAT, creates the `\<Console>\UPDATE\` folder structure, and places the file under its console-specific required name — note PS3 uses `PS3UPDAT.PUP` (no "E"), while PS4/PS5 use `PS4UPDATE.PUP`/`PS5UPDATE.PUP` — a well-known gotcha this script handles for you.

**Important:** this reinstalls *system software* only. If a console's problem is a hardware fault — a dead PSU, or the classic PS3 YLOD from cracked GPU/CPU solder joints — a software reinstall will not fix it. This tool is for corrupted/stuck system software, boot loops caused by bad updates, and similar software-level issues, not physical hardware repair.

## ⚠️ Before you run this

**Step 2 wipes the target disk completely and irreversibly.** The script will:
- List every attached disk with its size and model
- Require you to type the disk number twice as confirmation
- Require a final `YES` confirmation before touching anything

Even so — **triple-check the disk number and size before confirming.** There is no undo for `clean`. Never run this against a system you haven't personally verified, and never automate away the confirmation prompts unless you have independently verified the target disk through some other means first.

## Requirements (Deploy-Windows.ps1)

- Windows, PowerShell 5.1+
- Run as Administrator
- Internet access (to fetch the ISO and Fido itself, if not already present)

## Usage (Deploy-Windows.ps1)

### Fully interactive (recommended for first use)
```powershell
.\Deploy-Windows.ps1
```
Fido will prompt you through Windows version, edition, language, and architecture. The script then walks you through disk selection and image index selection interactively.

### Pre-specifying the OS to skip some prompts
```powershell
.\Deploy-Windows.ps1 -WindowsVersion 11 -Edition Pro -Language English -Arch x64
```

### Using an ISO you've already downloaded
```powershell
.\Deploy-Windows.ps1 -IsoPath "C:\path\to\Win11.iso"
```
This skips the Fido step entirely and goes straight to disk selection.

## What this does *not* do

- It does not download or manage product keys — you'll still activate Windows normally after first boot.
- It does not create removable bootable media (USB/DVD) — this deploys directly to a fixed target disk. If you want a bootable USB installer instead, use [Rufus](https://rufus.ie) with the ISO this script downloads.
- It is not a silent/unattended install past the partitioning and file-deployment stage — you'll still go through Windows's normal first-run OOBE screens on first boot (region, account setup, etc.).

## Credits

- [Fido](https://github.com/pbatard/Fido) by pbatard (also the author of Rufus) — used here for official, direct-from-Microsoft ISO retrieval.
