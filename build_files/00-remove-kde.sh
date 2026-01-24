#!/usr/bin/env bash
set -xeuo pipefail

# Remove KDE Plasma desktop environment
dnf5 remove -y \
    plasma-desktop \
    plasma-workspace \
    kwin \
    sddm \
    kde-settings \
    || true

# Remove KDE applications (optional, keeps base utilities)
dnf5 remove -y \
    konsole \
    dolphin \
    kate \
    || true

# Skip autoremove - it may remove dependencies needed by COSMIC
# dnf5 autoremove -y || true
