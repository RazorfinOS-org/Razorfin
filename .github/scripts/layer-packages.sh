#!/usr/bin/env bash
set -euo pipefail

# Print the current repo versions of the packages Razorfin layers on top of
# Bazzite, one name-evr per line. build.yml hashes this output into the
# org.razorfin.layer-packages label and rebuilds when it changes, so COSMIC
# and Docker updates don't wait for Bazzite to publish a new base.
#
# Runs inside a plain fedora:<release> container. Keep the package set in
# sync with 02-cosmic.sh and 04-dx.sh when adding layered packages that
# Bazzite doesn't already ship. Deliberately excluded:
#   - Sunshine (lizardbyte/beta COPR): date-based versions change daily.
#   - Fedora dx packages (libvirt/QEMU etc.) and 01-base.sh tools: would
#     rebuild on most Fedora update pushes for little benefit.

dnf5 -q config-manager addrepo --from-repofile=https://download.docker.com/linux/fedora/docker-ce.repo

{
    # COSMIC is pulled in via @cosmic-desktop-environment; its components
    # (cosmic-comp, cosmic-panel, ...) are dependencies rather than group
    # members, so match the whole cosmic-* namespace.
    dnf5 -q repoquery --latest-limit=1 --arch=x86_64,noarch --queryformat '%{name}-%{evr}\n' \
        'cosmic-*' \
        xdg-desktop-portal-cosmic \
        pop-launcher \
        gnome-keyring-pam \
        xdg-user-dirs |
        grep -vE -- '-(devel|debuginfo|debugsource)-'

    dnf5 -q repoquery --latest-limit=1 --repo=docker-ce-stable --arch=x86_64,noarch --queryformat '%{name}-%{evr}\n' \
        docker-ce \
        docker-ce-cli \
        containerd.io \
        docker-buildx-plugin \
        docker-compose-plugin
} | sort -u
