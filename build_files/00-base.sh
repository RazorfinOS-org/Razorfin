#!/usr/bin/env bash

set -xeuo pipefail

dnf5 install -y \
    tmux \
    htop \
    git \
    curl \
    wget

systemctl enable podman.socket
systemctl enable brew-setup.service
systemctl enable brew-upgrade.timer
systemctl enable brew-update.timer
