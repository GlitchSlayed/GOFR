# GOFR — Glitchy's Opinionated Fedora Remix

**GOFR** (pronounced *"Gopher"*) is a modern, minimally invasive, performance-oriented Fedora Remix designed around Unified Kernel Image (UKI) booting, `systemd-boot`, the CachyOS optimized Linux kernel, and modern interactive CLI tooling—all while preserving the rock-solid Fedora Workstation desktop experience.

---

## Key Highlights

- **Foundation:** Fedora Workstation (Fedora 45 x86_64 base) with upstream DNF5, GNOME on Wayland, PipeWire, WirePlumber, and enforcing SELinux.
- **Kernel:** High-performance [CachyOS Kernel](https://github.com/CachyOS/linux-cachyos) via maintained Fedora COPR (`bieszczaders/kernel-cachyos`).
- **Boot Subsystem:** UEFI → `systemd-boot` → Type #2 Unified Kernel Image (UKI) assembled via [RustyUKI](https://github.com/GlitchSlayed/RustyUKI) and `systemd-ukify`.
- **Partition Layout:** 4 GiB FAT32 ESP mounted at `/efi`, Btrfs root filesystem with standard Fedora subvolume conventions (`@` and `@home`), Swap-on-zram.
- **Repositories:** Fedora Base, Updates, RPM Fusion Free & Nonfree, and CachyOS COPR enabled out of the box with full GPG signature checking.
- **Default Shell:** [Brush](https://github.com/reubeno/brush) as the default interactive login shell for new users, retaining full POSIX/Bash compatibility for system scripts.
- **Modern CLI:** [zoxide](https://github.com/ajeetdsouza/zoxide) smart cd, [uutils-coreutils](https://github.com/uutils/coreutils) interactive user space integration, and optional [Starship](https://starship.rs) prompt.

---

## Repository Layout

```
GOFR/
├── README.md               # Project overview and status
├── LICENSE                 # MIT License
├── Makefile                # Build and orchestration targets
├── configs/                # Distribution configuration files
│   ├── boot/               # systemd-boot and UKI configuration
│   ├── packages/           # Package manifests and selection lists
│   ├── partitioning/       # Storage and partition templates
│   ├── repos/              # Repository definitions (RPM Fusion, CachyOS)
│   ├── shell/              # Shell startup and integration (Brush, zoxide, uutils)
│   └── systemd/            # Systemd units, presets, and overrides
├── docs/                   # Engineering documentation
│   ├── ARCHITECTURE.md     # System architecture and design decisions
│   ├── BOOT.md             # Boot architecture & UKI specification
│   ├── BUILDING.md         # Image and package build procedures
│   ├── KNOWN_ISSUES.md     # Current blockers and tracked work
│   ├── RELEASE.md          # Release criteria and checklist
│   ├── RUSTYUKI_INTEGRATION.md # RustyUKI audit, contract, and rework roadmap
│   ├── SECURE_BOOT.md      # Secure Boot signing and trust enrollment
│   └── UPSTREAM.md         # Verified upstream repositories and dependencies
├── kickstarts/             # Anaconda and image build kickstarts
├── packaging/              # GOFR-specific RPM package definitions
│   ├── gofr-boot/          # Bootloader, ESP, and kernel-install integration
│   ├── gofr-defaults/      # Shell, CLI defaults, and user profile configuration
│   ├── gofr-release/       # Release branding, os-release, and repo files
│   └── gofr-rustyuki-integration/ # RustyUKI hook and configuration bindings
├── scripts/                # Build and verification scripts
│   ├── build/              # RPM and image build helpers
│   ├── release/            # Checksum and manifest generation
│   └── test/               # Validation and smoke test scripts
└── tests/                  # Test suites
    ├── integration/        # Configuration and package integration tests
    ├── unit/               # Local validation unit tests
    └── vm/                 # Automated QEMU/OVMF VM test harness
```

---

## Status & Roadmap

- [x] Upstream dependency verification & research (`docs/UPSTREAM.md`)
- [x] Architectural design & component definition (`docs/ARCHITECTURE.md`)
- [x] RustyUKI comprehensive technical audit (`docs/RUSTYUKI_INTEGRATION.md`)
- [x] RPM packaging definitions (`gofr-release`, `gofr-defaults`, `gofr-boot`, `gofr-rustyuki-integration`)
- [x] Default configuration blueprints (boot, repos, shells, partition templates)
- [ ] RustyUKI upstream modernization and CachyOS/systemd-boot alignment
- [ ] Automated disk image prototype build via containerized tooling
- [ ] Installable Live / Netinstall ISO generation
- [ ] QEMU/OVMF automated validation suite
