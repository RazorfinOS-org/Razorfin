#!/usr/bin/env bash

set -xeuo pipefail

dnf5 install -y @cosmic-desktop-environment

# Create system users (cosmic-greeter, etc.) - doesn't run automatically in container builds
systemd-sysusers

systemctl enable cosmic-greeter.service

systemctl set-default graphical.target
