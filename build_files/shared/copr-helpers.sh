#!/usr/bin/env bash
set -euo pipefail

# Adapted from https://github.com/ublue-os/bluefin/blob/main/build_files/shared/copr-helpers.sh
#
# Install packages from a COPR without leaving the repo permanently enabled.
# The enable/disable dance writes the proper .repo file (with GPG key) via
# dnf's copr plugin, then --enablerepo flips it on just for this transaction.
# Avoids the "malicious COPR shadows a Fedora package" risk and keeps the
# image's enabled repo set minimal.
copr_install_isolated() {
    local copr_name="$1"
    shift
    local packages=("$@")

    if [[ ${#packages[@]} -eq 0 ]]; then
        echo "ERROR: No packages specified for copr_install_isolated"
        return 1
    fi

    local repo_id="copr:copr.fedorainfracloud.org:${copr_name//\//:}"

    echo "Installing ${packages[*]} from COPR $copr_name (isolated)"

    dnf5 -y copr enable "$copr_name"
    dnf5 -y copr disable "$copr_name"
    dnf5 -y install --enablerepo="$repo_id" "${packages[@]}"
}
