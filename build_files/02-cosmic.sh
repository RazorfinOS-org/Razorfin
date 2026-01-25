#!/usr/bin/env bash

set -xeuo pipefail

# Disable any existing display managers
systemctl disable sddm.service || true
systemctl disable gdm.service || true

dnf5 install -y --allowerasing --skip-broken \
    @cosmic-desktop-environment \
    gnome-keyring-pam \
    xdg-user-dirs

# =============================================================================
# SYSUSERS WORKAROUND FOR CONTAINER BUILDS
# =============================================================================
# In Fedora 42+, rpm-ostree container builds don't process sysusers.d files.
# We must manually create users/groups in /usr/lib/passwd and /usr/lib/group
# (not /etc/passwd which doesn't persist in ostree images).
#
# IMPORTANT: Check for UID/GID conflicts before choosing IDs!
# Run: awk -F: '$3 >= 900 && $3 < 1000 {print $3, $1}' /usr/lib/group | sort -n
# =============================================================================

# --- cosmic-greeter user (UID/GID 950) ---
# Required for COSMIC greeter to run. Must be in video and render groups.
# Using 950 to avoid conflict with qat (961) from qatlib package in Bazzite.
COSMIC_GREETER_UID=950
COSMIC_GREETER_GID=950

if ! grep -q "^cosmic-greeter:" /usr/lib/passwd; then
    echo "cosmic-greeter:x:${COSMIC_GREETER_UID}:${COSMIC_GREETER_GID}:COSMIC Greeter:/var/lib/cosmic-greeter:/sbin/nologin" >> /usr/lib/passwd
fi
if ! grep -q "^cosmic-greeter:" /usr/lib/group; then
    echo "cosmic-greeter:x:${COSMIC_GREETER_GID}:" >> /usr/lib/group
fi

# --- greetd user (UID/GID 951) ---
# Required by /usr/lib/tmpfiles.d/greetd.conf (from greetd package).
# cosmic-greeter.service uses cosmic-greeter user, but greetd tmpfiles expects greetd.
GREETD_UID=951
GREETD_GID=951

if ! grep -q "^greetd:" /usr/lib/passwd; then
    echo "greetd:x:${GREETD_UID}:${GREETD_GID}:greetd daemon:/var/lib/greetd:/sbin/nologin" >> /usr/lib/passwd
fi
if ! grep -q "^greetd:" /usr/lib/group; then
    echo "greetd:x:${GREETD_GID}:" >> /usr/lib/group
fi

# --- abrt user (UID 173) ---
# Required by abrtd.service. Using upstream Fedora UID 173.
# If you don't need ABRT, you can disable it instead: systemctl disable abrtd.service
ABRT_UID=173
ABRT_GID=173

if ! grep -q "^abrt:" /usr/lib/passwd; then
    echo "abrt:x:${ABRT_UID}:${ABRT_GID}::/etc/abrt:/sbin/nologin" >> /usr/lib/passwd
fi
if ! grep -q "^abrt:" /usr/lib/group; then
    echo "abrt:x:${ABRT_GID}:" >> /usr/lib/group
fi

# =============================================================================
# GROUP MEMBERSHIPS
# =============================================================================
# Add cosmic-greeter to video and render groups for display/DRM access.
# This is required for the greeter to access GPU devices.

for group in video render; do
    if grep -q "^${group}:" /usr/lib/group; then
        # Only add if not already a member
        if ! grep -q "^${group}:.*cosmic-greeter" /usr/lib/group; then
            sed -i "s/^\(${group}:.*\)$/\1,cosmic-greeter/" /usr/lib/group
        fi
    fi
done

# Clean up any malformed group entries (double commas, trailing commas after colon)
sed -i 's/:,/:/g; s/,,/,/g' /usr/lib/group

# =============================================================================
# HOME DIRECTORIES
# =============================================================================
# Create home directories with proper ownership and permissions.

# cosmic-greeter home (needs .config/cosmic for settings persistence)
mkdir -p /var/lib/cosmic-greeter/.config/cosmic
mkdir -p /var/lib/cosmic-greeter/.local/state/cosmic-comp
chown -R ${COSMIC_GREETER_UID}:${COSMIC_GREETER_GID} /var/lib/cosmic-greeter
chmod 750 /var/lib/cosmic-greeter

# greetd home
mkdir -p /var/lib/greetd
chown -R ${GREETD_UID}:${GREETD_GID} /var/lib/greetd
chmod 750 /var/lib/greetd

# =============================================================================
# SYSTEMD CONFIGURATION
# =============================================================================

systemctl set-default graphical.target

# cosmic-greeter.service is auto-enabled by the package - no manual enable needed
