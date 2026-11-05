# GOFR — Glitchy's Opinionated Fedora Remix

**GOFR** (pronounced *"Gopher"*) is a modern, lightly opinionated Fedora Remix designed around Unified Kernel Image (UKI) booting via `systemd-boot`, the CachyOS performance Linux kernel, RustyUKI lifecycle management, and modern interactive CLI tooling—all while preserving the rock-solid Fedora Workstation desktop experience.

---

## Key Highlights

- **Foundation:** Fedora Workstation 45 (`x86_64`) with upstream DNF5, GNOME on Wayland, PipeWire, WirePlumber, and enforcing SELinux.
- **Performance Kernel:** High-performance [CachyOS Kernel](https://github.com/CachyOS/linux-cachyos) via maintained Fedora COPR (`bieszczaders/kernel-cachyos`).
- **Boot Subsystem:** UEFI → `systemd-boot` → Type #2 Unified Kernel Image (UKI) assembled via [RustyUKI](https://github.com/GlitchSlayed/RustyUKI) and `systemd-ukify`. Direct UKI is supported as an optional experimental backend.
- **Partition Layout:** 4 GiB FAT32 ESP mounted at `/efi`, Btrfs root filesystem with standard Fedora subvolume conventions (`@` and `@home`), Swap-on-zram.
- **Repositories:** Fedora Base, Updates, official RPM Fusion Free & Nonfree, and CachyOS COPR enabled with full GPG signature checking.
- **Default Shell:** [Brush](https://github.com/reubeno/brush) configured as the default interactive login shell for new users via `useradd -D -s /usr/bin/brush`, retaining full POSIX/Bash compatibility for system scripts.
- **Modern CLI:** [zoxide](https://github.com/ajeetdsouza/zoxide) smart cd, [uutils-coreutils](https://github.com/uutils/coreutils) interactive user space integration, and optional [Starship](https://starship.rs) prompt.

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
│   ├── partitioning/       # Storage and partition blueprints (4 GiB ESP + Btrfs)
│   ├── repos/              # Repository definitions (RPM Fusion, CachyOS)
│   └── shell/              # Shell startup and integration (Brush, zoxide, uutils)
├── docs/                   # Engineering documentation
│   ├── ARCHITECTURE.md     # System architecture and design decisions
│   ├── BOOT.md             # Boot architecture & UKI specification
│   ├── BUILDING.md         # Image and package build procedures
│   ├── KNOWN_ISSUES.md     # Validated milestones and hardware requirements
│   ├── REBUILD.md          # Repository audit classification & decisions
│   ├── RELEASE.md          # Release criteria and checklist
│   ├── RUSTYUKI_INTEGRATION.md # RustyUKI integration boundaries & audit
│   ├── SECURE_BOOT.md      # Secure Boot signing and trust enrollment
│   └── UPSTREAM.md         # Verified upstream repositories and dependencies
├── kickstarts/             # Anaconda and image build kickstarts
├── packaging/              # GOFR-specific RPM package definitions
│   ├── gofr-boot/          # Bootloader, ESP, and kernel-install integration
│   ├── gofr-defaults/      # Shell, CLI defaults, and user profile configuration
│   ├── gofr-release/       # Release branding, os-release, and repo files
│   └── gofr-rustyuki-integration/ # RustyUKI hook and configuration bindings
├── scripts/                # Build and verification scripts
│   ├── build/              # RPM, disk image, and ISO build helpers
│   ├── release/            # Checksum and manifest generation
│   └── test/               # Automated QEMU/OVMF boot test suites
└── tests/                  # Test suites
    ├── integration/        # Kernel lifecycle & UKI rollback tests
    └── vm/                 # Automated VM test scripts
```

---

## Build & Test Workflow

```bash
# Verify host build tools and dependencies
make deps

# Build GOFR RPM packages in containerized cleanroom
make rpms

# Build bootable QEMU/OVMF GPT disk image (4 GiB ESP + Btrfs root)
make disk-image

# Run automated QEMU/OVMF UEFI boot verification
make test-vm

# Build installable hybrid UEFI ISO
make iso

# Run automated ISO boot verification in QEMU
make test-iso

# Run kernel update lifecycle and rollback test
make test-lifecycle

# Run all test suites
make test
```

---

## Validation Status

- [x] **GOFR RPM Package Suite:** `gofr-release`, `gofr-defaults`, `gofr-boot`, `gofr-rustyuki-integration`, and `rustyuki`.
- [x] **Real QEMU/OVMF Disk Boot:** Verified UEFI firmware → `systemd-boot` → Type #2 UKI → CachyOS kernel → userspace init.
- [x] **Real QEMU/OVMF ISO Boot:** Verified hybrid UEFI ISO booting from DVD-ROM via `systemd-boot`.
- [x] **Kernel Lifecycle:** Verified multi-version rotation and fallback slot retention (`.prev.efi`).
- [x] **Two-Tier CI Pipeline:** Configured in `.github/workflows/ci.yml`.
