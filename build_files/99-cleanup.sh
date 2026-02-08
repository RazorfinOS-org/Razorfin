#!/usr/bin/env bash
set -xeuo pipefail

# =============================================================================
# FINAL CLEANUP — runs AFTER KDE Frameworks cleanup (03-cleanup-kde-frameworks.sh)
# =============================================================================
# This is the last step in the build process, so it's safe to clean up any
# remaining build artifacts, regenerate initramfs, and verify the final image.


KERNEL_VERSION="$(rpm -q --queryformat='%{VERSION}-%{RELEASE}.%{ARCH}' kernel-core)"
if [[ -n "${KERNEL_VERSION}" ]]; then
    echo "Regenerating initramfs for kernel ${KERNEL_VERSION}..."

    # Run depmod to generate modules.dep (skipped when using tsflags=noscripts)
    /usr/sbin/depmod -a "${KERNEL_VERSION}"

    export DRACUT_NO_XATTR=1
    /usr/bin/dracut --no-hostonly --kver "${KERNEL_VERSION}" --reproducible --add ostree -f "/lib/modules/${KERNEL_VERSION}/initramfs.img"
    chmod 0600 "/lib/modules/${KERNEL_VERSION}/initramfs.img"
fi

# Remove sb-key-notify autostart — the binary is installed without +x by ublue-setup-services,
# and the profile.d script causes "permission denied" errors on the greeter console
rm -f /etc/profile.d/sbkey-notify-autostart.sh
rm -f /etc/skel/.config/autostart/sb-key-notify.desktop

dnf5 clean all

rm -rf /tmp/* /var/tmp/* || true

rm -rf /var/cache/dnf/* || true
