#!/usr/bin/env bash
set -xeuo pipefail

# =============================================================================
# KDE FRAMEWORK CLEANUP — runs AFTER COSMIC install (02-cosmic.sh)
# =============================================================================
# At this point, COSMIC's @cosmic-desktop-environment group marks its deps as
# explicitly installed, so autoremove won't touch them.

# Remove all KDE Framework 5 libraries (COSMIC has no kf5 deps)
dnf5 remove -y kf5-* || true

# NOTE: kf6-* glob is NOT safe — COSMIC packages depend on some kf6 libraries,
# so removing all kf6-* cascades into removing the entire COSMIC desktop.
# Orphaned kf6 packages are handled by autoremove below.

# Remove Breeze icon/cursor/GTK themes
dnf5 remove -y breeze-icon-theme breeze-cursor-theme breeze-gtk-* || true

# Remove orphaned Qt and other packages no longer required
dnf5 autoremove -y || true

# Audit: log remaining KDE/Qt packages for CI visibility
echo "=== Remaining KDE packages ==="
rpm -qa | grep -iE '^kde|^kf5-|^kf6-|^plasma' || echo "(none)"
echo "=== Remaining Qt packages ==="
rpm -qa | grep -iE '^qt5-|^qt6-' || echo "(none)"
echo "=== Remaining Breeze packages ==="
rpm -qa | grep -i breeze || echo "(none)"

# Safety net: fail the build if any dependency breakage is detected
dnf5 check
