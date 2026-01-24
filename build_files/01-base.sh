#!/usr/bin/env bash

set -xeuo pipefail

dnf5 install -y \
    zsh \
    tmux \
    htop \
    git \
    curl \
    wget

systemctl enable podman.socket

# Create ublue-motd files (referenced by shared scripts but not included)
mkdir -p /usr/share/ublue-os/motd
tee /usr/share/ublue-os/motd/env.sh <<'EOF'
#!/usr/bin/env sh
export IMAGE_NAME="${IMAGE_NAME:-Razorfin}"
export IMAGE_TAG="${IMAGE_TAG:-latest}"
EOF

tee /usr/share/ublue-os/motd/template.md <<'EOF'
# Welcome to ${IMAGE_NAME}

A custom Universal Blue image with COSMIC desktop.
EOF
