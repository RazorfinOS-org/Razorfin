#!/usr/bin/env bash

set -xeuo pipefail

# Disable any existing display managers
systemctl disable sddm.service || true
systemctl disable gdm.service || true

dnf5 install -y --allowerasing --skip-broken \
    @cosmic-desktop-environment \
    gnome-keyring-pam \
    xdg-user-dirs

# Create system users - systemd-sysusers doesn't reliably work in container builds
systemd-sysusers || true

# Explicitly create cosmic-greeter user if it doesn't exist (needed for greetd)
if ! id -u cosmic-greeter &>/dev/null; then
    useradd -r -M -d /var/empty -s /sbin/nologin -c "COSMIC Greeter" cosmic-greeter
fi

systemctl set-default graphical.target

# cosmic-greeter.service is auto-enabled by the package - no manual enable needed
