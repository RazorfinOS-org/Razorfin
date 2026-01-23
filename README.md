# Razorfin

[![build](https://github.com/RazorfinOS-org/Razorfin/actions/workflows/build.yml/badge.svg)](https://github.com/RazorfinOS-org/Razorfin/actions/workflows/build.yml)

A custom Universal Blue image featuring the [COSMIC](https://system76.com/cosmic/) desktop environment.

## Variants

| Variant | Base Image | Description |
|---------|------------|-------------|
| `razorfin` | `ghcr.io/ublue-os/base-main:latest` | Base image with COSMIC desktop |
| `razorfin-nvidia` | `ghcr.io/ublue-os/base-main:latest` | COSMIC desktop with NVIDIA proprietary drivers |

## Features

- **COSMIC Desktop** - System76's modern, Rust-based desktop environment
- **Homebrew** - Linux package manager integrated with automatic updates
- **Podman** - Container runtime with socket activation
- **Developer Tools** - zsh, tmux, htop, git, curl, wget pre-installed

### NVIDIA Variant

The `-nvidia` variant includes:
- Full NVIDIA proprietary driver stack
- NVIDIA Container Toolkit for GPU containers
- CUDA support
- Nouveau blacklisted for compatibility

## Installation

### Switching from an Existing Atomic System

If you're already running a Fedora Atomic system (Silverblue, Kinoite, Bazzite, etc.):

```bash
# Base variant
sudo bootc switch ghcr.io/razorfinos-org/razorfin:latest

# NVIDIA variant
sudo bootc switch ghcr.io/razorfinos-org/razorfin-nvidia:latest
```

Reboot when the switch completes.

### Fresh Installation

ISO images are available from the [GitHub Actions artifacts](https://github.com/RazorfinOS-org/Razorfin/actions/workflows/build-disk.yml) or can be built locally:

```bash
just build-iso
```

### Verifying Images

Images are signed with cosign. To verify:

```bash
cosign verify --key cosign.pub ghcr.io/razorfinos-org/razorfin:latest
```

## Building Locally

Requires [just](https://just.systems/) and [podman](https://podman.io/).

```bash
# Build base image
just build

# Build NVIDIA variant
just build-nvidia

# Build a bootable QCOW2 VM image
just build-qcow2

# Run the VM
just run-vm-qcow2
```

See `just --list` for all available commands.

## Acknowledgments

Built using the [Universal Blue image-template](https://github.com/ublue-os/image-template).
