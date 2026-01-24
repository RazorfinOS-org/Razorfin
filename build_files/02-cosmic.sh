#!/usr/bin/env bash

set -xeuo pipefail

# Disable any existing display managers
systemctl disable sddm.service || true
systemctl disable gdm.service || true

dnf5 install -y --allowerasing --skip-broken \
    @cosmic-desktop-environment \
    gnome-keyring-pam \
    xdg-user-dirs

# Create system users (cosmic-greeter, etc.) - doesn't run automatically in container builds
systemd-sysusers

systemctl set-default graphical.target

# cosmic-greeter.service is auto-enabled by the package - no manual enable needed
