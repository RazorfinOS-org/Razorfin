#!/usr/bin/env bash

set -xeuo pipefail

KERNEL_VERSION="$(rpm -q --queryformat='%{VERSION}-%{RELEASE}.%{ARCH}' kernel-core)"
if [[ -n "${KERNEL_VERSION}" ]]; then
    echo "Regenerating initramfs for kernel ${KERNEL_VERSION}..."

    # Run depmod to generate modules.dep (skipped when using tsflags=noscripts)
    /usr/sbin/depmod -a "${KERNEL_VERSION}"

    export DRACUT_NO_XATTR=1
    /usr/bin/dracut --no-hostonly --kver "${KERNEL_VERSION}" --reproducible --add ostree -f "/lib/modules/${KERNEL_VERSION}/initramfs.img"
    chmod 0600 "/lib/modules/${KERNEL_VERSION}/initramfs.img"
fi

dnf5 clean all

rm -rf /tmp/* /var/tmp/* || true

rm -rf /var/cache/dnf/* || true
