#!/usr/bin/env bash

set -xeuo pipefail

# =============================================================================
# OS-RELEASE BRANDING
# =============================================================================
# Customize os-release for Razorfin branding (shown in GRUB via PRETTY_NAME)

OSTREE_VERSION=$(grep "^OSTREE_VERSION=" /usr/lib/os-release | cut -d"'" -f2)
VERSION_ID=$(grep "^VERSION_ID=" /usr/lib/os-release | cut -d'=' -f2)

sed -i 's/^NAME=.*/NAME="Razorfin"/' /usr/lib/os-release
sed -i "s/^PRETTY_NAME=.*/PRETTY_NAME=\"Razorfin (Version: ${OSTREE_VERSION})\"/" /usr/lib/os-release
sed -i "s/^BOOTLOADER_NAME=.*/BOOTLOADER_NAME=\"Razorfin (${OSTREE_VERSION})\"/" /usr/lib/os-release
sed -i 's/^DEFAULT_HOSTNAME=.*/DEFAULT_HOSTNAME="razorfin"/' /usr/lib/os-release
sed -i 's|^HOME_URL=.*|HOME_URL="https://github.com/RazorfinOS-org/Razorfin"|' /usr/lib/os-release
sed -i 's|^DOCUMENTATION_URL=.*|DOCUMENTATION_URL="https://github.com/RazorfinOS-org/Razorfin"|' /usr/lib/os-release
sed -i 's|^SUPPORT_URL=.*|SUPPORT_URL="https://github.com/RazorfinOS-org/Razorfin/issues"|' /usr/lib/os-release
sed -i 's|^BUG_REPORT_URL=.*|BUG_REPORT_URL="https://github.com/RazorfinOS-org/Razorfin/issues"|' /usr/lib/os-release

# Additional branding fixes for distro command output
sed -i 's/^ID=.*/ID=razorfin/' /usr/lib/os-release
sed -i "s/^VERSION=.*/VERSION=\"${VERSION_ID} (Cosmonaut)\"/" /usr/lib/os-release
sed -i 's/^VERSION_CODENAME=.*/VERSION_CODENAME="Cosmonaut"/' /usr/lib/os-release
sed -i 's/^LOGO=.*/LOGO=razorfin/' /usr/lib/os-release
sed -i 's/^VARIANT=.*/VARIANT="COSMIC"/' /usr/lib/os-release
sed -i 's/^VARIANT_ID=bazzite/VARIANT_ID=razorfin/' /usr/lib/os-release

# =============================================================================
# PACKAGES
# =============================================================================

dnf5 install -y \
    zsh \
    tmux \
    htop \
    git \
    curl \
    wget

# =============================================================================
# PLYMOUTH BOOT SPLASH BRANDING
# =============================================================================
# Install Razorfin Plymouth theme (uses two-step module with spinner animation)
# The theme reuses spinner's animation files but with custom watermark and colors

# Copy theme config to Plymouth themes directory
cp -r /ctx/build/plymouth/razorfin /usr/share/plymouth/themes/

# Replace spinner's watermark with Razorfin logo (theme references spinner's ImageDir)
cp /ctx/build/plymouth/razorfin/watermark.png /usr/share/plymouth/themes/spinner/watermark.png

# Set Razorfin as the default Plymouth theme
plymouth-set-default-theme razorfin

systemctl enable podman.socket

# =============================================================================
# RAZORFIN BRANDING (MOTD & FASTFETCH)
# =============================================================================
# Override Bazzite's MOTD and fastfetch with Razorfin branding

# Install Razorfin branding files for fastfetch
mkdir -p /usr/share/ublue-os/razorfin
cp /ctx/build/razorfin/logo.txt /usr/share/ublue-os/razorfin/
cp /ctx/build/razorfin/fastfetch.jsonc /usr/share/ublue-os/razorfin/

# Install razorfin-fetch-image helper script
cp /ctx/build/razorfin/razorfin-fetch-image /usr/libexec/
chmod +x /usr/libexec/razorfin-fetch-image

# Override Bazzite's fastfetch aliases with Razorfin config
# Using 'zzz-' prefix ensures this runs after bazzite-neofetch.sh
cp /ctx/build/razorfin/razorfin-neofetch.sh /etc/profile.d/zzz-razorfin-neofetch.sh

# Replace Bazzite MOTD with Razorfin MOTD
cp /ctx/build/razorfin/motd.md /usr/share/ublue-os/motd/razorfin.md
# Remove Bazzite-specific MOTD if it exists
rm -f /usr/share/ublue-os/motd/bazzite.md

# Fix ublue-motd script to use razorfin.md instead of bazzite.md
sed -i 's|/usr/share/ublue-os/motd/bazzite.md|/usr/share/ublue-os/motd/razorfin.md|g' /usr/libexec/ublue-motd

# Update image-info.json with Razorfin branding
if [[ -f /usr/share/ublue-os/image-info.json ]]; then
    # Update image name while preserving other fields
    jq '.["image-name"] = "Razorfin" | .["image-vendor"] = "RazorfinOS"' \
        /usr/share/ublue-os/image-info.json > /tmp/image-info.json
    mv /tmp/image-info.json /usr/share/ublue-os/image-info.json
fi

# Remove Bazzite-specific MOTD tips
rm -f /usr/share/ublue-os/motd/tips/20-bazzite.md
