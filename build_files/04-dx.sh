#!/usr/bin/env bash
set -xeuo pipefail

# =============================================================================
# DX LAYER — runs only when INSTALL_DX=1
# =============================================================================
# Adds libvirt/QEMU, Docker CE, dev essentials, observability, AI/remoting,
# and Sunshine streaming on top of the chosen base. Gated so non-dx variants
# share the same Containerfile but skip this step entirely.
#
# Background: upstream bazzite-dx/bazzite-dx-nvidia derive from the
# bazzite-deck / bazzite-deck-nvidia handheld images (commit 1685003c), not
# the desktop images. That once left them frozen on F43
# (https://github.com/ublue-os/bazzite-dx/issues/170, closed 2026-06-05, and
# they are back on F44), but the deck base is still wrong for a desktop
# image. We keep layering the dx packages on top of the desktop F44
# bazzite / bazzite-nvidia-open bases.

if [[ "${INSTALL_DX:-0}" != "1" ]]; then
    echo "INSTALL_DX != 1 — skipping dx layer"
    exit 0
fi

# shellcheck source=build_files/shared/copr-helpers.sh
source /ctx/build/shared/copr-helpers.sh

echo "Installing dx layer..."

# -----------------------------------------------------------------------------
# Fedora packages — one bulk transaction (single solve, single download pass).
# Grouped by purpose for readability; concatenated into one array.
# gamescope is NOT here: bazzite F44 ships terra-gamescope (a fork that
# Provides gamescope), and the Fedora gamescope package conflicts with it.
# -----------------------------------------------------------------------------
FEDORA_PACKAGES=(
    # Virtualization
    libvirt
    libvirt-client
    libvirt-daemon
    libvirt-daemon-driver-qemu
    libvirt-daemon-driver-network
    libvirt-daemon-driver-storage-core
    libvirt-daemon-driver-storage-disk
    libvirt-daemon-driver-nodedev
    libvirt-daemon-driver-nwfilter
    libvirt-daemon-driver-interface
    libvirt-daemon-driver-secret
    libvirt-daemon-config-network
    libvirt-daemon-config-nwfilter
    qemu-kvm
    qemu-kvm-core
    qemu-system-x86
    qemu-system-x86-core
    qemu-user
    qemu-img
    qemu-tools
    qemu-audio-pipewire
    qemu-audio-pa
    qemu-device-display-virtio-gpu
    qemu-device-display-virtio-gpu-gl
    qemu-device-display-virtio-vga
    qemu-device-display-virtio-vga-gl
    qemu-device-usb-host
    qemu-device-usb-redirect
    qemu-ui-gtk
    qemu-ui-spice-app
    qemu-ui-spice-core
    qemu-char-spice
    qemu-block-curl
    virt-manager
    virt-install
    virt-viewer
    swtpm
    swtpm-tools
    # edk2-ovmf is pinned separately below
    libguestfs
    guestfs-tools
    osinfo-db
    osinfo-db-tools

    # Container extras (podman comes from the base)
    podman-machine
    podman-tui

    # Dev essentials
    git
    git-subtree
    ccache
    flatpak-builder
    hexedit
    gdisk
    android-tools
    clevis
    clevis-luks
    clevis-pin-tpm2

    # eBPF observability
    bcc
    bpftrace
    bpftop

    # AI / remoting
    ramalama
    waypipe
)

echo "Installing ${#FEDORA_PACKAGES[@]} dx packages from Fedora repos..."
dnf5 install -y "${FEDORA_PACKAGES[@]}"

# -----------------------------------------------------------------------------
# edk2-ovmf pin — 20260812-8 (the Bazzite base's version since 44.20260914)
# hangs Windows 11 Secure Boot guests before the TianoCore splash.
#   https://github.com/ublue-os/bazzite/issues/5857
#   https://bugzilla.redhat.com/show_bug.cgi?id=2537116
# Same pin as upstream bazzite-dx (bb84187). Remove once Fedora ships a
# fixed build; the warning below flags when the base moves past the bad one.
# -----------------------------------------------------------------------------
EDK2_BAD="20260812-8.fc44"
EDK2_PIN="20260508-8.fc44"
EDK2_BASE="$(rpm -q --queryformat '%{version}-%{release}' edk2-ovmf 2>/dev/null || true)"
if [[ -n "${EDK2_BASE}" && "${EDK2_BASE}" != "${EDK2_BAD}" ]]; then
    echo "::warning::edk2-ovmf in base is ${EDK2_BASE}, not ${EDK2_BAD}; re-check whether the ${EDK2_PIN} pin is still needed"
fi
dnf5 install -y \
    "https://kojipkgs.fedoraproject.org/packages/edk2/${EDK2_PIN%-*}/${EDK2_PIN#*-}/noarch/edk2-ovmf-${EDK2_PIN}.noarch.rpm"

# -----------------------------------------------------------------------------
# Docker CE — third-party repo, enabled only for this transaction.
# Same isolation pattern as copr_install_isolated but for a regular repo.
# -----------------------------------------------------------------------------
dnf5 config-manager addrepo --from-repofile=https://download.docker.com/linux/fedora/docker-ce.repo
dnf5 config-manager setopt docker-ce-stable.enabled=0
dnf5 -y install --enablerepo=docker-ce-stable \
    docker-ce \
    docker-ce-cli \
    containerd.io \
    docker-buildx-plugin \
    docker-compose-plugin

# Load iptable_nat for docker-in-docker (devcontainers), as bazzite-dx does.
#   https://github.com/ublue-os/bluefin/issues/2365
#   https://github.com/devcontainers/features/issues/1235
mkdir -p /usr/lib/modules-load.d
echo "iptable_nat" > /usr/lib/modules-load.d/razorfin-docker.conf

# -----------------------------------------------------------------------------
# docker group — add wheel users so docker works without sudo.
# The docker group only exists in /usr/lib/group (nss-altfiles), which
# usermod can't modify, so copy it into /etc/group first. Same approach as
# bazzite-dx's dx-usergroups hook (which needs ublue-setup-services; we don't
# ship that). Runs after rechunker-group-fix so /etc/gshadow gets rebuilt
# with the docker entry on every boot. The done-marker is only written once
# a wheel user exists: on fresh installs the first user may be created by
# cosmic-initial-setup after this runs at first boot, so it retries next boot.
# -----------------------------------------------------------------------------
cat > /usr/libexec/razorfin-dx-groups <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

if ! grep -q '^docker:' /etc/group; then
    grep '^docker:' /usr/lib/group >> /etc/group
fi

mapfile -t wheel_users < <(getent group wheel | cut -d: -f4 | tr ',' '\n' | sed '/^$/d')
if [[ ${#wheel_users[@]} -eq 0 ]]; then
    echo "No wheel users yet; will retry next boot"
    exit 0
fi

for user in "${wheel_users[@]}"; do
    usermod -aG docker "${user}"
done

install -d /var/lib/razorfin
touch /var/lib/razorfin/dx-groups.done
EOF
chmod 0755 /usr/libexec/razorfin-dx-groups

cat > /usr/lib/systemd/system/razorfin-dx-groups.service <<'EOF'
[Unit]
Description=Razorfin: add wheel users to the docker group (one-shot)
After=local-fs.target rechunker-group-fix.service
Before=systemd-user-sessions.service
ConditionPathExists=!/var/lib/razorfin/dx-groups.done

[Service]
Type=oneshot
ExecStart=/usr/libexec/razorfin-dx-groups

[Install]
WantedBy=multi-user.target
EOF
systemctl enable razorfin-dx-groups.service

# -----------------------------------------------------------------------------
# Sunshine — lizardbyte/beta COPR (lizardbyte/stable has no F44 build yet).
# -----------------------------------------------------------------------------
copr_install_isolated "lizardbyte/beta" "Sunshine"

# -----------------------------------------------------------------------------
# Sunshine firewalld service + first-boot oneshot.
# firewalld isn't running during the container build, so we can't
# `firewall-cmd` here — drop the service definition and let a oneshot
# register it with the default zone at first boot.
# -----------------------------------------------------------------------------
mkdir -p /etc/firewalld/services
cat > /etc/firewalld/services/sunshine.xml <<'EOF'
<?xml version="1.0" encoding="utf-8"?>
<service>
  <short>Sunshine</short>
  <description>Sunshine game stream host (Moonlight-compatible)</description>
  <port protocol="tcp" port="47984"/>
  <port protocol="tcp" port="47989"/>
  <port protocol="tcp" port="47990"/>
  <port protocol="tcp" port="48010"/>
  <port protocol="udp" port="47998"/>
  <port protocol="udp" port="47999"/>
  <port protocol="udp" port="48000"/>
  <port protocol="udp" port="48002"/>
  <port protocol="udp" port="48010"/>
</service>
EOF
chmod 0644 /etc/firewalld/services/sunshine.xml

cat > /usr/lib/systemd/system/razorfin-firewall-sunshine.service <<'EOF'
[Unit]
Description=Razorfin: add Sunshine to firewalld default zone (one-shot)
After=firewalld.service
Requires=firewalld.service
ConditionPathExists=!/var/lib/razorfin/firewall-sunshine.done

[Service]
Type=oneshot
ExecStart=/usr/bin/firewall-cmd --permanent --add-service=sunshine
ExecStart=/usr/bin/firewall-cmd --reload
ExecStart=/usr/bin/install -d /var/lib/razorfin
ExecStart=/usr/bin/touch /var/lib/razorfin/firewall-sunshine.done
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF
systemctl enable razorfin-firewall-sunshine.service

# -----------------------------------------------------------------------------
# Enable dx services.
# Sunshine is user-mode (needs the user session for video capture) — ship a
# user-preset so it gets enabled for every user automatically.
# -----------------------------------------------------------------------------
systemctl enable libvirtd.service
systemctl enable docker.service

mkdir -p /usr/lib/systemd/user-preset
cat > /usr/lib/systemd/user-preset/50-razorfin-sunshine.preset <<'EOF'
enable app-dev.lizardbyte.app.Sunshine.service
EOF

# -----------------------------------------------------------------------------
# Trim caches (99-cleanup.sh does the final pass too)
# -----------------------------------------------------------------------------
dnf5 clean all
rm -rf /var/cache/dnf/* || true
