#!/usr/bin/env bash
# configure_iso.sh — Titanoboa post-rootfs hook for Razorfin ISOs
# Runs inside the rootfs chroot before it is squashed into squashfs.img.
# Adapted from Bazzite's titanoboa_hook_postrootfs.sh for COSMIC desktop.

set -exo pipefail

# shellcheck source=/dev/null
source /etc/os-release

###############################################################################
# Variables
###############################################################################
imageref="$(podman images --format '{{ index .Names 0 }}\n' 'razorfin*' | head -1)"
imageref="${imageref##*://}"
imageref="${imageref%%:*}"
imagetag="$(podman images --format '{{ .Tag }}\n' "${imageref}" | head -1)"

sbkey='https://github.com/ublue-os/akmods/raw/main/certs/public_key.der'
SECUREBOOT_KEY="/usr/share/ublue-os/sb_pubkey.der"

###############################################################################
# Install Anaconda and dependencies
###############################################################################
# Clear versionlocks inherited from the base image (Bazzite locks
# NetworkManager among others) to avoid dependency conflicts when
# pulling in anaconda-core -> NetworkManager-team -> NetworkManager.
dnf -qy versionlock clear 2>/dev/null || true

dnf install -qy --allowerasing \
    anaconda-live \
    libblockdev-btrfs \
    libblockdev-lvm \
    libblockdev-dm

mkdir -p /var/lib/rpm-state

###############################################################################
# Disable unnecessary services in the live environment
###############################################################################
services_to_disable=(
    rpm-ostree-countme.timer
    tailscaled.service
    bootloader-cleanup.service
    brew-setup.service
    brew-upgrade.timer
    brew-update.timer
)

for svc in "${services_to_disable[@]}"; do
    systemctl disable "${svc}" 2>/dev/null || true
done

###############################################################################
# Configure COSMIC greeter/session for the live environment
###############################################################################
# Disable automatic sleep/suspend in the live environment so the installer
# does not get interrupted.
mkdir -p /etc/cosmic/com.system76.CosmicSettings.Power/v1
cat > /etc/cosmic/com.system76.CosmicSettings.Power/v1/0000-live-iso.ron <<'COSMIC_EOF'
(
    suspend_on_ac_timeout: None,
    suspend_on_battery_timeout: None,
    screen_off_on_ac_timeout: None,
    screen_off_on_battery_timeout: None,
    dim_on_ac_timeout: None,
    dim_on_battery_timeout: None,
)
COSMIC_EOF

###############################################################################
# Razorfin Anaconda profile
###############################################################################
mkdir -p /etc/anaconda/profile.d
cat > /etc/anaconda/profile.d/razorfin.conf <<'PROFILE_EOF'
# Anaconda configuration file for Razorfin

[Profile]
profile_id = razorfin

[Profile Detection]
os_id = razorfin

[Network]
default_on_boot = FIRST_WIRED_WITH_LINK

[Bootloader]
efi_dir = fedora
menu_auto_hide = True

[Storage]
default_scheme = BTRFS
btrfs_compression = zstd:1
default_partitioning =
    /     (min 1 GiB, max 70 GiB)
    /home (min 500 MiB, free 50 GiB)
    /var  (btrfs)

[User Interface]
custom_stylesheet = /usr/share/anaconda/pixmaps/fedora.css
hidden_spokes =
    NetworkSpoke
    PasswordSpoke

hidden_webui_pages =
    root-password
    network

[Localization]
use_geolocation = False
PROFILE_EOF

###############################################################################
# Branding
###############################################################################
echo "Razorfin release ${VERSION_ID}" > /etc/system-release

# Replace Fedora references in Anaconda
if [[ -f /usr/share/anaconda/pixmaps/fedora.css ]]; then
    sed -i 's/Fedora/Razorfin/g' /usr/share/anaconda/pixmaps/fedora.css
fi

###############################################################################
# Secure Boot key
###############################################################################
mkdir -p /usr/share/ublue-os
curl -Lo "${SECUREBOOT_KEY}" "${sbkey}"

###############################################################################
# Kickstart — post-install scripts
###############################################################################
cat >> /usr/share/anaconda/interactive-defaults.ks <<KICKSTART_EOF

# Razorfin post-install: bootc switch to the signed container image
%post --erroronfail
set -euo pipefail

imageref="${imageref}"
imagetag="${imagetag}"

# Switch to the target container image with signature verification
bootc switch --mutate-in-place --transport registry "\${imageref}:\${imagetag}"
%end

# Razorfin post-install: Secure Boot key enrollment
%post --nochroot --log=/tmp/secureboot-enroll.log
set -euo pipefail

SECUREBOOT_KEY="/usr/share/ublue-os/sb_pubkey.der"

# Detect Steam Deck by DMI — skip MOK enrollment there
if grep -qi "Jupiter\|Galileo" /sys/class/dmi/id/product_name 2>/dev/null; then
    echo "Steam Deck detected, skipping Secure Boot key enrollment."
    exit 0
fi

# Enroll the key if mokutil is available
if command -v mokutil &>/dev/null && [[ -f "\${SECUREBOOT_KEY}" ]]; then
    mokutil --timeout -1
    mokutil --import "\${SECUREBOOT_KEY}" --hash-file /dev/null 2>/dev/null || true
fi
%end
KICKSTART_EOF
