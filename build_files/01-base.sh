#!/usr/bin/env bash

set -xeuo pipefail

# Customize os-release for Razorfin branding
# Extract version from existing os-release
VERSION=$(grep "^VERSION=" /usr/lib/os-release | cut -d'"' -f2 | cut -d' ' -f1)
OSTREE_VERSION=$(grep "^OSTREE_VERSION=" /usr/lib/os-release | cut -d"'" -f2)

sed -i 's/^NAME=.*/NAME="Razorfin"/' /usr/lib/os-release
sed -i "s/^PRETTY_NAME=.*/PRETTY_NAME=\"Razorfin (${OSTREE_VERSION})\"/" /usr/lib/os-release
sed -i "s/^BOOTLOADER_NAME=.*/BOOTLOADER_NAME=\"Razorfin (${OSTREE_VERSION})\"/" /usr/lib/os-release
sed -i 's/^DEFAULT_HOSTNAME=.*/DEFAULT_HOSTNAME="razorfin"/' /usr/lib/os-release
sed -i 's|^HOME_URL=.*|HOME_URL="https://github.com/RazorfinOS-org/Razorfin"|' /usr/lib/os-release
sed -i 's|^DOCUMENTATION_URL=.*|DOCUMENTATION_URL="https://github.com/RazorfinOS-org/Razorfin"|' /usr/lib/os-release
sed -i 's|^SUPPORT_URL=.*|SUPPORT_URL="https://github.com/RazorfinOS-org/Razorfin/issues"|' /usr/lib/os-release
sed -i 's|^BUG_REPORT_URL=.*|BUG_REPORT_URL="https://github.com/RazorfinOS-org/Razorfin/issues"|' /usr/lib/os-release

dnf5 install -y \
    zsh \
    tmux \
    htop \
    git \
    curl \
    wget

systemctl enable podman.socket

# Create ublue-motd files (referenced by shared scripts but not included)
mkdir -p /usr/share/ublue-os/motd
tee /usr/share/ublue-os/motd/env.sh <<'EOF'
#!/usr/bin/env sh
export IMAGE_NAME="${IMAGE_NAME:-Razorfin}"
export IMAGE_TAG="${IMAGE_TAG:-latest}"
EOF

tee /usr/share/ublue-os/motd/template.md <<'EOF'
# Welcome to ${IMAGE_NAME}

A custom Universal Blue image with COSMIC desktop.
EOF
