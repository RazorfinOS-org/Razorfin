# Razorfin

[![build](https://github.com/RazorfinOS-org/Razorfin/actions/workflows/build.yml/badge.svg)](https://github.com/RazorfinOS-org/Razorfin/actions/workflows/build.yml)

Razorfin is a custom Universal Blue image based on [Bazzite](https://bazzite.gg/) that replaces KDE Plasma with the [COSMIC](https://system76.com/cosmic) desktop environment.

## Variants

Razorfin is available in four variants:

| Variant | Base Image | Description |
|---------|------------|-------------|
| `razorfin` | `bazzite:stable` | Bazzite + COSMIC desktop (AMD/Intel) |
| `razorfin-dx` | `bazzite-dx:stable` | Bazzite DX + COSMIC desktop (includes developer tools) |
| `razorfin-nvidia-open` | `bazzite-nvidia-open:stable` | Bazzite + COSMIC desktop + NVIDIA open drivers |
| `razorfin-dx-nvidia-open` | `bazzite-dx-nvidia:stable` | Bazzite DX + COSMIC desktop + NVIDIA open drivers |

## Installation

### Switch from an existing Fedora Atomic / Universal Blue system

```bash
# Base variant (AMD/Intel)
sudo bootc switch ghcr.io/razorfinos-org/razorfin:latest

# DX variant (with developer tools)
sudo bootc switch ghcr.io/razorfinos-org/razorfin-dx:latest

# NVIDIA Open variant
sudo bootc switch ghcr.io/razorfinos-org/razorfin-nvidia-open:latest

# DX + NVIDIA Open variant
sudo bootc switch ghcr.io/razorfinos-org/razorfin-dx-nvidia-open:latest
```

### Fresh Install via ISO

Download the appropriate ISO for your hardware from the [Releases](https://github.com/razorfinos-org/Razorfin/releases) page and boot from it.

## Features

- **COSMIC Desktop**: System76's next-generation Rust-based desktop environment
- **Bazzite Base**: All the gaming optimizations and hardware support from Bazzite
- **Multiple Variants**: Choose between standard and developer (DX) editions, with or without NVIDIA support

## Building Locally

Razorfin uses [Just](https://just.systems/) for build automation. Install it from your package manager or it's available by default on all Universal Blue images.

### Build Commands

```bash
# Build base variant
just build

# Build DX variant
just build-dx

# Build NVIDIA Open variant
just build-nvidia-open

# Build DX + NVIDIA Open variant
just build-dx-nvidia-open
```

### Build ISOs

```bash
# Build ISO for base variant
just build-iso

# Build ISO for DX variant
just build-iso-dx

# Build ISO for NVIDIA Open variant
just build-iso-nvidia-open

# Build ISO for DX + NVIDIA Open variant
just build-iso-dx-nvidia-open
```

### Build QCOW2 VM Images

```bash
# Build QCOW2 for base variant
just build-qcow2

# Build QCOW2 for other variants
just build-qcow2-dx
just build-qcow2-nvidia-open
just build-qcow2-dx-nvidia-open
```

### Run in a VM

```bash
# Run base variant in a VM
just run-vm-qcow2

# Run other variants
just run-vm-qcow2-dx
just run-vm-qcow2-nvidia-open
just run-vm-qcow2-dx-nvidia-open
```

## Verification

After building, verify the image:

```bash
# Verify KDE is removed
podman run --rm localhost/razorfin:latest rpm -qa | grep -i plasma
# Should return nothing

# Verify COSMIC is installed
podman run --rm localhost/razorfin:latest rpm -qa | grep -i cosmic
# Should show cosmic packages
```

## Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `IMAGE_NAME` | `razorfin` | Output image name |
| `DEFAULT_TAG` | `latest` | Default tag for the image |
| `BASE_IMAGE` | `ghcr.io/ublue-os/bazzite:stable` | Base image for builds |
| `BIB_IMAGE` | `quay.io/centos-bootc/bootc-image-builder:latest` | Bootc Image Builder image |

## Community

- [Universal Blue Forums](https://universal-blue.discourse.group/)
- [Universal Blue Discord](https://discord.gg/WEu6BdFEtp)
- [COSMIC Desktop](https://system76.com/cosmic)
- [Bazzite](https://bazzite.gg/)

## License

Apache-2.0
