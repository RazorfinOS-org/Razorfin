# Razorfin

[![build](https://github.com/RazorfinOS-org/Razorfin/actions/workflows/build.yml/badge.svg)](https://github.com/RazorfinOS-org/Razorfin/actions/workflows/build.yml)

Razorfin is a custom [Universal Blue](https://universal-blue.org/) image based on [Bazzite](https://bazzite.gg/) that replaces KDE Plasma with the [COSMIC](https://system76.com/cosmic) desktop environment. It combines Bazzite's gaming optimizations and hardware support with System76's next-generation Rust-based desktop.

## Variants

| Variant | Base Image | Description |
|---------|------------|-------------|
| `razorfin` | `bazzite` | COSMIC desktop (AMD/Intel) |
| `razorfin-dx` | `bazzite-dx` | COSMIC desktop + developer tools |
| `razorfin-nvidia-open` | `bazzite-nvidia-open` | COSMIC desktop + NVIDIA open drivers |
| `razorfin-dx-nvidia-open` | `bazzite-dx-nvidia` | COSMIC desktop + developer tools + NVIDIA open drivers |

## Release Channels

Images are built once and promoted between channels by re-tagging, so each channel ships the exact same image digest that was validated in the tier below it.

| Channel | Cadence | Description |
|---------|---------|-------------|
| `testing` | Every push to `main` | Bleeding edge — latest changes, may have rough edges |
| `latest` | Daily | Previous day's `testing` build, suitable for general use |
| `stable` | Weekly (Tuesdays) | Previous week's `latest`, recommended for most users |

Each promotion also creates a date-stamped tag (e.g., `stable.20260208`) that can be used for pinning or rollback.

## Installation

### Switch from an existing Fedora Atomic / Universal Blue system

```bash
# Base variant (AMD/Intel) — stable channel (recommended)
sudo bootc switch --enforce-container-sigpolicy ghcr.io/razorfinos-org/razorfin:stable

# DX variant
sudo bootc switch --enforce-container-sigpolicy ghcr.io/razorfinos-org/razorfin-dx:stable

# NVIDIA Open variant
sudo bootc switch --enforce-container-sigpolicy ghcr.io/razorfinos-org/razorfin-nvidia-open:stable

# DX + NVIDIA Open variant
sudo bootc switch --enforce-container-sigpolicy ghcr.io/razorfinos-org/razorfin-dx-nvidia-open:stable
```

To track a different channel, replace `:stable` with `:latest` or `:testing`.

### Fresh Install via ISO

Download the ISO for your hardware from the [Releases](https://github.com/razorfinos-org/Razorfin/releases) page and boot from it. ISOs are built monthly from the `stable` channel.

## Image Verification

All images are signed with [Cosign](https://docs.sigstore.dev/cosign/overview/). The public key is included in this repository as [`cosign.pub`](cosign.pub).

```bash
cosign verify --key cosign.pub ghcr.io/razorfinos-org/razorfin:stable
```

## Changing Channels

Switch your system to a different release channel at any time:

```bash
# Move to the stable channel
sudo bootc switch --enforce-container-sigpolicy ghcr.io/razorfinos-org/razorfin:stable

# Or pin to a specific date-stamped image
sudo bootc switch --enforce-container-sigpolicy ghcr.io/razorfinos-org/razorfin:stable.20260208

systemctl reboot
```

## Rollback

If an update causes issues, you can roll back to the previous deployment without re-downloading anything:

```bash
sudo bootc rollback
systemctl reboot
```

Or switch to a known-good date-stamped image:

```bash
sudo bootc switch --enforce-container-sigpolicy ghcr.io/razorfinos-org/razorfin:stable.20260201
systemctl reboot
```

## Building Locally

Razorfin uses [Just](https://just.systems/) for build automation (available by default on all Universal Blue images).

### Container Images

```bash
just build                  # Base variant
just build-dx               # DX variant
just build-nvidia-open      # NVIDIA Open variant
just build-dx-nvidia-open   # DX + NVIDIA Open variant
```

### ISOs

```bash
just build-iso              # Base variant
just build-iso-nvidia-open  # NVIDIA Open variant
```

### QCOW2 VM Images

```bash
just build-qcow2            # Build base QCOW2
just run-vm-qcow2           # Build and run in a VM
```

Run `just` with no arguments to see all available recipes.

## Contributing

See the [release runbook](docs/release-runbook.md) for details on the CI/CD pipeline, emergency hotfix procedures, and rollback operations.

## Community

- [Universal Blue Forums](https://universal-blue.discourse.group/)
- [Universal Blue Discord](https://discord.gg/WEu6BdFEtp)
- [COSMIC Desktop](https://system76.com/cosmic)
- [Bazzite](https://bazzite.gg/)

## License

Apache-2.0
