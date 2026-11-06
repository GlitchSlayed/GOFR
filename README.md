# GOFR — Glitchy's Opinionated Fedora Remix

**GOFR** (pronounced *"Gopher"*) is a modern, lightly opinionated Fedora Remix designed around **Unified Kernel Image (UKI)** booting via `systemd-boot`, the **CachyOS performance Linux kernel**, **RustyUKI** lifecycle management, and a **Netinstall-first delivery architecture**—all while preserving the rock-solid stability and compatibility of the Fedora Workstation ecosystem.

---

## The Netinstall Advantage

GOFR embraces a **Netinstall-first architecture** designed for speed, flexibility, and rolling package freshness:

- **Ultra-Compact & Fast Downloads:** A lightweight boot ISO (< 1 GiB) that downloads in seconds and fits directly on official GitHub Releases with incremental versioning (`45.1`, `45.2`, etc.).
- **Always Up-to-Date:** At installation time, packages are resolved and streamed directly from upstream mirrors. You immediately get the freshest CachyOS kernel, upstream Fedora packages, and GOFR updates—completely eliminating the need for a massive multi-gigabyte `dnf upgrade` immediately after installation.
- **Maximum Customizability:** Because packages are deployed dynamically via Kickstart or Anaconda, you have total control over your system profile:
  - **Fedora Workstation GNOME (Default):** Full modern Wayland desktop with PipeWire, WirePlumber, and GDM.
  - **Minimal / Window Managers:** Deploy Sway, COSMIC, or custom window managers without bloat.
  - **Developer Workstations:** Install specialized toolchains and SDKs during initial deployment.
- **Pure UKI & systemd-boot Partitioning:** The installer automatically configures a dedicated **4 GiB FAT32 ESP at `/efi`** and a **Btrfs root filesystem with `@` and `@home` subvolumes**, orchestrating initial UKI generation via RustyUKI.

---

## Key Highlights

- **Foundation:** Fedora Workstation 45 (`x86_64`) with upstream DNF5, GNOME on Wayland, PipeWire, WirePlumber, and enforcing SELinux.
- **Performance Kernel:** High-performance [CachyOS Kernel](https://github.com/CachyOS/linux-cachyos) via maintained Fedora COPR (`bieszczaders/kernel-cachyos`).
- **Boot Subsystem:** UEFI firmware → `systemd-boot` → Type #2 Unified Kernel Image (BLS Type #2) assembled via [RustyUKI](https://github.com/GlitchSlayed/RustyUKI) and `systemd-ukify`. Direct UKI is supported as an optional experimental backend.
- **Partition Layout:** 4 GiB FAT32 ESP mounted at `/efi`, Btrfs root filesystem with standard Fedora subvolume conventions (`@` and `@home`), and swap-on-zram.
- **Repositories:** Fedora Base, Updates, official RPM Fusion Free & Nonfree, and CachyOS COPR enabled with full OpenPGP signature verification.
- **Default Shell:** [Brush](https://github.com/reubeno/brush) configured as the default interactive login shell for new users via `useradd -D -s /usr/bin/brush`, retaining full POSIX/Bash compatibility for system scripts.
- **Modern CLI Stack:** [zoxide](https://github.com/ajeetdsouza/zoxide) smart cd, [uutils-coreutils](https://github.com/uutils/coreutils) interactive user space integration, [ripgrep](https://github.com/BurntSushi/ripgrep), [fd-find](https://github.com/sharkdp/fd), [bat](https://github.com/sharkdp/bat), [eza](https://github.com/eza-community/eza), and [btop](https://github.com/aristocratos/btop).

---

## Quick Start & Installation

### 1. Download Release
Download the latest verified Netinstall ISO or pre-installed virtual machine image from the [GitHub Releases](https://github.com/GlitchSlayed/GOFR/releases) page:

- `gofr-netinstall-45.x-x86_64.iso` — Bootable hybrid UEFI Netinstall media (< 1 GiB)
- `SHA256SUMS` — Cryptographic verification checksums

Verify your download:
```bash
sha256sum -c SHA256SUMS --ignore-missing
```

### 2. Write to USB Installation Media
```bash
sudo dd if=gofr-netinstall-45.1-x86_64.iso of=/dev/sdX bs=4M status=progress conv=fsync
```
*(Replace `/dev/sdX` with your target USB drive block device).*

### 3. Test in QEMU / KVM
You can test the Netinstall ISO in a virtual machine using UEFI (OVMF) firmware:
```bash
qemu-system-x86_64 \
    -enable-kvm \
    -m 4G \
    -smp 4 \
    -bios /usr/share/edk2/ovmf/OVMF_CODE.fd \
    -cdrom out/gofr-netinstall-45.1-x86_64.iso \
    -boot d
```

---

## Storage & Partition Architecture

GOFR replaces legacy GRUB configurations with a clean, UKI-first layout:

```
[ UEFI Firmware ]
       │
       ▼
[ /efi (4 GiB FAT32 ESP) ]
       ├── EFI/BOOT/BOOTX64.EFI          (systemd-boot boot manager)
       ├── loader/loader.conf            (timeout, default entries)
       └── EFI/Linux/                    (Type #2 Unified Kernel Images)
             ├── gofr-cachyos.efi        (Active CachyOS UKI)
             └── gofr-cachyos.prev.efi   (Fallback slot)
       │
       ▼
[ /dev/disk/by-uuid/... (Btrfs Root) ]
       ├── Subvolume @                   (Mounted at /)
       └── Subvolume @home               (Mounted at /home)
```

The 4 GiB ESP provides ample room for multiple concurrent rolling UKIs, fallback slots, recovery images, and UEFI firmware capsules without running out of disk space.

---

## Repository Layout

```
GOFR/
├── README.md               # Project overview and validated milestones
├── LICENSE                 # MIT License
├── Makefile                # Build and orchestration targets
├── configs/                # Distribution configuration files
│   ├── boot/               # systemd-boot, loader.conf, and UKI configuration
│   ├── packages/           # Package manifests and selection lists
│   ├── partitioning/       # Storage blueprints (4 GiB ESP + Btrfs subvolumes)
│   ├── repos/              # Repository definitions (RPM Fusion, CachyOS)
│   └── shell/              # Shell startup and profiles (Brush, zoxide, uutils)
├── docs/                   # Engineering documentation
│   ├── ARCHITECTURE.md     # System architecture and design decisions
│   ├── BOOT.md             # Boot architecture & UKI specification
│   ├── BUILDING.md         # Image and package build procedures
│   ├── KNOWN_ISSUES.md     # Hardware requirements & known notes
│   ├── REBUILD.md          # Repository audit classification & decisions
│   ├── RELEASE.md          # Release criteria and checklist
│   ├── RUSTYUKI_INTEGRATION.md # RustyUKI integration boundaries
│   ├── SECURE_BOOT.md      # Secure Boot signing and trust enrollment
│   └── UPSTREAM.md         # Verified upstream repositories and dependencies
├── kickstarts/             # Anaconda and image build kickstarts
│   └── gofr-workstation.ks # Default Fedora Workstation 45 kickstart
├── packaging/              # GOFR custom RPM package definitions
│   ├── gofr-boot/          # Bootloader, ESP, and kernel-install integration
│   ├── gofr-defaults/      # Shell, CLI defaults, and user profile configuration
│   ├── gofr-release/       # Release branding, os-release, and repo files
│   └── gofr-rustyuki-integration/ # RustyUKI hook and configuration bindings
├── scripts/                # Build and verification scripts
│   ├── build/              # RPM, disk image, and ISO build helpers
│   ├── release/            # Checksum, manifest, and release automation
│   └── test/               # Automated QEMU/OVMF boot test suites
└── tests/                  # Test suites
    ├── integration/        # Kernel lifecycle & UKI rollback tests
    └── vm/                 # Automated VM test scripts
```

---

## Local Build & Test Workflow

All build targets run natively on Fedora or inside clean Fedora 45 containers:

```bash
# Verify host build tools and dependencies
make deps

# Build GOFR RPM packages in clean container
make rpms

# Build bootable Netinstall hybrid UEFI ISO (< 1 GiB)
make iso
# or: make netinstall

# Build bootable QEMU/OVMF GPT disk image (4 GiB ESP + Btrfs root)
make disk-image

# Run automated QEMU/OVMF UEFI ISO boot verification
make test-iso

# Run automated QEMU/OVMF UEFI disk image boot verification
make test-vm

# Run kernel update lifecycle and rollback test
make test-lifecycle

# Run all test suites
make test
```

---

## Release Pipeline

GOFR releases are built and published using GitHub Actions (`.github/workflows/release.yml`):
- **Incremental Versioning:** Generates sequential build numbers keyed to the major Fedora version (e.g. `45.1`, `45.2`, `45.3`).
- **Containerized Environment:** Builds inside official `registry.fedoraproject.org/fedora:45` containers with native DNF5 and RPM packaging.
- **Published Artifacts:** Every release publishes the bootable **Netinstall ISO**, pre-installed virtual disk images, cryptographic checksums (`SHA256SUMS`), and `manifest.json`.

---

## Validation Status

- [x] **GOFR RPM Package Suite:** `gofr-release`, `gofr-defaults`, `gofr-boot`, `gofr-rustyuki-integration`, and `rustyuki`.
- [x] **Real QEMU/OVMF Disk Boot:** Verified UEFI firmware → `systemd-boot` → Type #2 UKI → CachyOS kernel → userspace init.
- [x] **Real QEMU/OVMF ISO Boot:** Verified hybrid UEFI ISO booting from CD/DVD via `systemd-boot`.
- [x] **Kernel Lifecycle:** Verified multi-version rotation and fallback slot retention (`.prev.efi`).
- [x] **Two-Tier CI Pipeline:** Fully verified on pure Fedora 45 runners via GitHub Actions.
