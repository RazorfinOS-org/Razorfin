#!/usr/bin/env bash

set -xeuo pipefail

# Disable any existing display managers
systemctl disable sddm.service || true
systemctl disable gdm.service || true

dnf5 install -y --allowerasing --skip-broken \
    @cosmic-desktop-environment \
    gnome-keyring-pam \
    xdg-user-dirs

# Create cosmic-greeter user in /usr/lib/passwd (ostree requires users here, not /etc/passwd)
# useradd writes to /etc/passwd which doesn't persist in ostree images
if ! grep -q "^cosmic-greeter:" /usr/lib/passwd; then
    echo "cosmic-greeter:x:969:969:COSMIC Greeter:/var/lib/cosmic-greeter:/sbin/nologin" >> /usr/lib/passwd
fi
if ! grep -q "^cosmic-greeter:" /usr/lib/group; then
    echo "cosmic-greeter:x:969:" >> /usr/lib/group
fi

# Add cosmic-greeter to video and render groups for display/DRM access
for group in video render; do
    if grep -q "^${group}:" /usr/lib/group; then
        sed -i "s/^\(${group}:.*\)$/\1,cosmic-greeter/" /usr/lib/group
    fi
done
# Clean up double commas or trailing commas
sed -i 's/:,/:/g; s/,,/,/g' /usr/lib/group

# Create cosmic-greeter home directory with proper ownership
mkdir -p /var/lib/cosmic-greeter/.local/state/cosmic-comp
chown -R 969:969 /var/lib/cosmic-greeter

systemctl set-default graphical.target

# cosmic-greeter.service is auto-enabled by the package - no manual enable needed
