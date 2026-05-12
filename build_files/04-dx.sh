#!/usr/bin/env bash
set -xeuo pipefail

# =============================================================================
# DX LAYER — runs only when INSTALL_DX=1
# =============================================================================
# Adds libvirt/QEMU, Docker CE, dev essentials, observability, AI/remoting,
# and Sunshine streaming on top of the chosen base. Gated so non-dx variants
# share the same Containerfile but skip this step entirely.
#
# Background: upstream bazzite-dx/bazzite-dx-nvidia is frozen on F43
# (https://github.com/ublue-os/bazzite-dx/issues/170 — commit 1685003c
# made dx derive from the slow-rolled deck images). We instead layer the
# dx packages on top of the actively-maintained F44 bazzite / bazzite-nvidia-open.

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
    edk2-ovmf
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
