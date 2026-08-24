# OSmaster

A single PowerShell script that chains together the full Windows deployment pipeline, end to end:

1. **Fetch** — downloads an official Windows 10/11 ISO directly from Microsoft's servers using [Fido](https://github.com/pbatard/Fido) (no browser click-through, no third-party mirrors).
2. **Prepare** — partitions and formats a target disk with a standard UEFI/GPT layout (EFI system partition + Windows partition).
3. **Deploy** — applies the Windows image directly with DISM and makes it bootable with `bcdboot`, skipping the interactive Setup GUI entirely. On first boot, the target disk goes straight into Windows OOBE (the out-of-box setup screens).

## ⚠️ Before you run this

**Step 2 wipes the target disk completely and irreversibly.** The script will:
- List every attached disk with its size and model
- Require you to type the disk number twice as confirmation
- Require a final `YES` confirmation before touching anything

Even so — **triple-check the disk number and size before confirming.** There is no undo for `clean`. Never run this against a system you haven't personally verified, and never automate away the confirmation prompts unless you have independently verified the target disk through some other means first.

## Requirements

- Windows, PowerShell 5.1+
- Run as Administrator
- Internet access (to fetch the ISO and Fido itself, if not already present)

## Usage

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
