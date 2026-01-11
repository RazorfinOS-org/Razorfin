#!/usr/bin/env bash

if [[ ! "${BUILD_FLAVOR:-}" =~ "nvidia" ]]; then
    exit 0
fi

set -xeuo pipefail

AKMODS_PATH="/usr/share/akmods"

# Install pre-built nvidia-open drivers from ublue-os akmods
# These RPMs are copied from ghcr.io/ublue-os/akmods-nvidia-open in the Containerfile

source "${AKMODS_PATH}/rpms/kmods/nvidia-vars"

CURRENT_KERNEL="$(rpm -q --queryformat '%{VERSION}-%{RELEASE}.%{ARCH}' kernel-core)"

echo "Current kernel: ${CURRENT_KERNEL}"
echo "NVIDIA kmod built for kernel: ${KERNEL_VERSION}"

if [[ "${CURRENT_KERNEL}" != "${KERNEL_VERSION}" ]]; then
    echo "Kernel version mismatch detected, installing matching kernel..."

    dnf5 install -y --setopt=tsflags=noscripts \
        "${AKMODS_PATH}/kernel-rpms/kernel-"*.rpm \
        "${AKMODS_PATH}/kernel-rpms/kernel-core-"*.rpm \
        "${AKMODS_PATH}/kernel-rpms/kernel-modules-"*.rpm
fi

dnf5 install -y "${AKMODS_PATH}/rpms/ublue-os/ublue-os-nvidia-addons-"*.rpm

dnf5 install -y --setopt=tsflags=noscripts \
    "${AKMODS_PATH}/rpms/kmods/kmod-nvidia-${KERNEL_VERSION}-${NVIDIA_AKMOD_VERSION}.${DIST_ARCH}.rpm"

dnf5 install -y \
    nvidia-gpu-firmware \
    libva-nvidia-driver

dnf5 install -y nvidia-container-toolkit

curl --retry 3 -L https://raw.githubusercontent.com/NVIDIA/dgx-selinux/master/bin/RHEL9/nvidia-container.pp -o nvidia-container.pp
semodule -i nvidia-container.pp
rm -f nvidia-container.pp

# Blacklist nouveau driver
tee /usr/lib/modprobe.d/00-nouveau-blacklist.conf <<'EOF'
blacklist nouveau
options nouveau modeset=0
EOF

# Configure kernel boot arguments for NVIDIA
tee /usr/lib/bootc/kargs.d/00-nvidia.toml <<'EOF'
kargs = ["rd.driver.blacklist=nouveau", "modprobe.blacklist=nouveau", "nvidia-drm.modeset=1"]
EOF

# Configure dracut for NVIDIA driver loading
# Force-load NVIDIA drivers and pre-load iGPU drivers for hardware acceleration
if [[ -f /usr/lib/dracut/dracut.conf.d/99-nvidia.conf ]]; then
    sed -i 's/omit_drivers/force_drivers/g' /usr/lib/dracut/dracut.conf.d/99-nvidia.conf
    sed -i 's/ nvidia / i915 amdgpu nvidia /g' /usr/lib/dracut/dracut.conf.d/99-nvidia.conf
fi

# Move modprobe config to system location if it exists
if [[ -f /etc/modprobe.d/nvidia-modeset.conf ]]; then
    mv /etc/modprobe.d/nvidia-modeset.conf /usr/lib/modprobe.d/nvidia-modeset.conf
fi

# Create systemd service for NVIDIA Container Toolkit CDI generation
tee /usr/lib/systemd/system/nvctk-cdi.service <<'EOF'
[Unit]
Description=NVIDIA Container Toolkit CDI auto-generation
ConditionFileIsExecutable=/usr/bin/nvidia-ctk
After=local-fs.target

[Service]
Type=oneshot
ExecStart=/usr/bin/nvidia-ctk cdi generate --output=/etc/cdi/nvidia.yaml

[Install]
WantedBy=multi-user.target
EOF

systemctl enable nvctk-cdi.service

# Clean up copied akmods RPMs
rm -rf /usr/share/akmods
