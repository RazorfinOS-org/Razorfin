#!/usr/bin/env bash

set -xeuo pipefail

# Disable any existing display managers
systemctl disable sddm.service || true
systemctl disable gdm.service || true

dnf5 install -y --allowerasing --skip-broken @cosmic-desktop-environment

# Create system users (cosmic-greeter, etc.) - doesn't run automatically in container builds
systemd-sysusers

# Enable greetd (the display manager that runs cosmic-greeter)
systemctl enable greetd.service

systemctl set-default graphical.target
