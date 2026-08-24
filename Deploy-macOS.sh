#!/bin/zsh
#
# Deploy-macOS.sh
#
# The macOS counterpart to Deploy-Windows.ps1 — but it works fundamentally
# differently, because Apple's distribution model is different from
# Microsoft's. Read the "How this differs from the Windows script" section
# in README.md before using this.
#
# WHAT THIS DOES:
#   1. Fetches a full macOS installer directly from Apple, using Apple's own
#      `softwareupdate` command (the same mechanism macOS itself uses).
#   2. Either:
#        (a) builds a bootable USB installer using Apple's own
#            `createinstallmedia`, or
#        (b) deploys headlessly to an internal/target volume using the
#            installer's own `startosinstall` assistant.
#
# REQUIREMENTS:
#   - Must be run ON a Mac, running macOS. Apple's installer-fetching and
#     media-creation tools do not exist on any other platform — there is no
#     way to fetch or build macOS install media from Windows or Linux, full
#     stop. This is an Apple platform restriction, not a limitation of this
#     script.
#   - Administrator (sudo) privileges.
#   - These tools are intended for deployment onto genuine Apple hardware.
#
set -euo pipefail

show_instructions() {
cat << 'EOF'

===============================================================
  Deploy-macOS.sh -- Instructions
===============================================================

WHAT THIS DOES
  Fetches an official macOS installer directly from Apple (via the
  built-in `softwareupdate` command), then either builds a bootable
  USB installer or deploys headlessly straight to a target volume --
  both using Apple's own tools (createinstallmedia / startosinstall).

MUST RUN ON AN ACTUAL MAC
  Apple's fetching and media-creation tools only exist on macOS. This
  cannot be run from Windows or Linux -- that's an Apple platform
  restriction, not a limitation of this script. If you're reading
  this from a non-Mac machine, this script isn't the tool for that
  job; there is no cross-platform equivalent.

BEFORE YOU RUN THIS
  - Run on the target Mac itself, with sudo access.
  - Decide up front: bootable USB (to install elsewhere / keep as
    reusable media) or headless direct-deploy (wipes a volume on THIS
    machine and installs straight to it, no separate boot media).
  - Direct-deploy mode reboots the machine automatically partway
    through -- don't run it if you need to babysit other work on the
    same machine during that window.

TYPICAL USE
  1. chmod +x Deploy-macOS.sh && ./Deploy-macOS.sh
  2. Pick a macOS version from the list Apple currently serves.
  3. Choose bootable-USB or direct-deploy.
  4. Confirm the target volume by name -- it gets erased.
  5. Let it run; direct-deploy will reboot on its own to finish.

===============================================================
EOF
}

if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
    show_instructions
    exit 0
fi

say() { print -P "%F{cyan}==== $1 ====%f"; }
warn() { print -P "%F{yellow}$1%f"; }
err() { print -P "%F{red}$1%f"; }

confirm_or_abort() {
    local msg="$1"
    read "response?$msg (type YES to continue): "
    if [[ "$response" != "YES" ]]; then
        warn "Aborted by user."
        exit 1
    fi
}

if [[ "$(uname)" != "Darwin" ]]; then
    err "This script must be run on macOS. Apple's installer tools (softwareupdate, createinstallmedia) don't exist on any other platform."
    exit 1
fi

# ----------------------------------------------------------------------
# STEP 1 — List and fetch the full macOS installer via Apple's own tool
# ----------------------------------------------------------------------
say "Step 1: Available macOS installers"

echo "Querying Apple's software catalog (this can take a moment)..."
softwareupdate --list-full-installers

echo
read "targetVersion?Enter the exact macOS VERSION to fetch (as shown above, e.g. 15.1): "

say "Fetching macOS $targetVersion"
echo "This downloads the full installer app into /Applications — it's several GB, so this will take a while."
sudo softwareupdate --fetch-full-installer --full-installer-version "$targetVersion"

# Find the installer app that was just downloaded
installerApp=$(find /Applications -maxdepth 1 -iname "Install macOS*.app" -newer /tmp 2>/dev/null | head -n 1)
if [[ -z "$installerApp" ]]; then
    installerApp=$(find /Applications -maxdepth 1 -iname "Install macOS*.app" | sort | tail -n 1)
fi
if [[ -z "$installerApp" ]]; then
    err "Could not locate the downloaded installer app in /Applications."
    exit 1
fi
echo "Using installer: $installerApp"

# ----------------------------------------------------------------------
# STEP 2 — Choose deployment mode
# ----------------------------------------------------------------------
say "Step 2: Choose what to do with it"
echo "  1) Build a bootable USB installer (createinstallmedia)"
echo "  2) Deploy headlessly to an internal/target volume (startosinstall)"
read "mode?Choose 1 or 2: "

if [[ "$mode" == "1" ]]; then
    # -------------------- Bootable USB path --------------------
    say "Bootable USB installer"
    echo "Attached volumes:"
    diskutil list

    read "volName?Enter the volume NAME to erase and turn into the installer (e.g. MyUSB): "
    warn "THIS WILL ERASE EVERYTHING ON THAT VOLUME."
    confirm_or_abort "Erase and use volume '$volName' as the installer target"

    sudo "$installerApp/Contents/Resources/createinstallmedia" --volume "/Volumes/$volName"
    say "Done"
    echo "Bootable installer created on '$volName'. Hold Option at startup on an Apple Silicon or Intel Mac to boot from it."

elif [[ "$mode" == "2" ]]; then
    # -------------------- Headless direct-deploy path --------------------
    say "Headless deployment to a target volume"
    echo "Attached volumes:"
    diskutil list

    read "targetVol?Enter the target VOLUME NAME to install onto (must already exist — this does not partition disks for you): "
    warn "This will erase the target volume and install macOS onto it. Any existing data on '$targetVol' will be lost."
    confirm_or_abort "Install macOS $targetVersion onto volume '$targetVol'"

    echo "Running startosinstall — this will reboot the machine automatically partway through."
    sudo "$installerApp/Contents/Resources/startosinstall" \
        --volume "/Volumes/$targetVol" \
        --agreetolicense \
        --nointeraction

else
    err "Invalid choice."
    exit 1
fi
