# Upstream Research and Dependency Audit

This document records the upstream sources, repository locations, package availability in Fedora, licensing, integration methods, and architectural compatibility evaluations for all core components of GOFR.

---

## 1. Operating System Foundation

### Fedora Workstation Base
- **Upstream Project:** [Fedora Project](https://fedoraproject.org/)
- **Documentation:** [Fedora Docs](https://docs.fedoraproject.org/)
- **Target Release:** Fedora 45 (current stable)
- **Base Architecture:** `x86_64` UEFI
- **Desktop Environment:** GNOME (Wayland)
- **Audio & Media:** PipeWire & WirePlumber
- **Security:** SELinux in Enforcing mode
- **Package Management:** RPM + DNF5
- **License:** Various open source licenses (Fedora Project licensing guidelines)
- **Status in GOFR:** Core foundation. Preserves standard desktop experience, release cadence, and official Fedora updates.

### Fedora Kickstarts
- **Upstream Repository:** [https://pagure.io/fedora-kickstarts](https://pagure.io/fedora-kickstarts)
- **Cloned Reference:** Cloned locally at `../fedora-kickstarts`
- **Role:** Canonical definitions for Fedora Workstation, Live Desktop, and image composition.
- **License:** MIT / GPLv2+
- **Integration:** Used as the template baseline for GOFR kickstarts in `kickstarts/`.

---

## 2. Boot & Unified Kernel Image (UKI) Infrastructure

### systemd & systemd-boot
- **Upstream Repository:** [https://github.com/systemd/systemd](https://github.com/systemd/systemd)
- **Manuals:** [freedesktop.org/software/systemd/man/latest/](https://www.freedesktop.org/software/systemd/man/latest/)
- **Fedora Package:** `systemd-boot`, `systemd-udev`
- **License:** LGPL-2.1-or-later
- **Role:** Installed system bootloader (replaces GRUB2). Discovers Boot Loader Specification (BLS) Type #2 UKIs located at `$ESP/EFI/Linux/*.efi`.
- **Status in GOFR:** Mandatory bootloader. Installed on ESP at `/efi`.

### systemd-ukify
- **Upstream Repository:** Component of systemd ([systemd/src/ukify](https://github.com/systemd/systemd/tree/main/src/ukify))
- **Fedora Package:** `systemd-ukify` (Verified available in Fedora 45: `systemd-ukify-262.1-1.fc45.noarch`)
- **License:** LGPL-2.1-or-later
- **Role:** Assembles PE binaries containing systemd-stub, kernel, initramfs, cmdline, OS release, and optional splash/signatures.
- **Status in GOFR:** Required build dependency used directly or orchestrated via RustyUKI.

### dracut / dracut-ng
- **Upstream Repository:** [https://github.com/dracut-ng/dracut-ng](https://github.com/dracut-ng/dracut-ng)
- **Fedora Package:** `dracut`
- **License:** GPL-2.0-or-later
- **Role:** Generates initramfs images containing root discovery, Btrfs tools, systemd initrd, and storage modules.
- **Status in GOFR:** Required dependency for initramfs generation.

### systemd-stub
- **Fedora Package:** Provided by `systemd-boot` / `systemd-udev` (`/usr/lib/systemd/boot/efi/linuxx64.efi.stub`)
- **Role:** UEFI PE stub that executes early firmware handoff and loads embedded kernel/initrd.

---

## 3. Kernel Subsystem

### CachyOS Linux Kernel
- **Upstream Repository:** [https://github.com/CachyOS/linux-cachyos](https://github.com/CachyOS/linux-cachyos)
- **Packaging Repository:** [https://github.com/CachyOS/copr-linux-cachyos](https://github.com/CachyOS/copr-linux-cachyos)
- **Fedora COPR:** [bieszczaders/kernel-cachyos](https://copr.fedorainfracloud.org/coprs/bieszczaders/kernel-cachyos/)
- **Packages Verified:**
  - `kernel-cachyos` (current: `7.3.1-1.cachyos1.fc45.x86_64`)
  - `kernel-cachyos-devel`
  - `kernel-cachyos-core`
- **License:** GPL-2.0-only
- **Features:** BORE scheduler, upstream performance patches, tuned compiler flags (GCC x86-64-v3/v4 optimization options).
- **Status in GOFR:** Default running kernel. Enabled via official Copr repository configuration.

---

## 4. Primary UKI Management Solution: RustyUKI

- **Upstream Repository:** [https://github.com/GlitchSlayed/RustyUKI](https://github.com/GlitchSlayed/RustyUKI)
- **Cloned Reference:** Cloned locally at `../RustyUKI`
- **Version:** `0.2.0` (active pre-release)
- **License:** MIT
- **Language:** Rust (2021 edition)
- **Dependencies:** `clap`, `anyhow`, `thiserror`, `serde`, `toml`, `log`, `env_logger`, `nix`
- **Role in GOFR:** Primary UKI builder, ESP artifact orchestrator, and kernel-install lifecycle manager.
- **Audit Summary:** Comprehensive technical audit detailed in `docs/RUSTYUKI_INTEGRATION.md`. The author is setting up a separate project to redo and improve RustyUKI for cleaner BLS Type #2 systemd-boot support, generalized kernel package naming (`kernel-cachyos`), and `/efi` path conventions.

---

## 5. Third-Party Repositories

### RPM Fusion (Free & Nonfree)
- **Configuration Guide:** [https://rpmfusion.org/Configuration](https://rpmfusion.org/Configuration)
- **Packages:**
  - `rpmfusion-free-release`
  - `rpmfusion-nonfree-release`
- **GPG Keys:** Fedora official RPM Fusion distribution keys
- **Role:** Provides hardware codecs, drivers (NVIDIA), multimedia support.
- **Status in GOFR:** Enabled out of the box with signature checking enforced.

### Terra Repository
- **Upstream:** [Terra Project](https://terra.fyralabs.com/)
- **Packages Provided:** `brush-shell` (`brush-shell-0.4.0-1.fc45.x86_64`)
- **Status in GOFR:** Used for pre-built brush-shell RPM delivery.

---

## 6. Modern Interactive CLI Utilities

### Brush Shell
- **Upstream Repository:** [https://github.com/reubeno/brush](https://github.com/reubeno/brush)
- **Website:** [https://brush.sh/](https://brush.sh/)
- **Fedora Availability:** Available via Terra repository as `brush-shell` (`0.4.0-1.fc45`).
- **License:** MIT / Apache-2.0
- **Role:** Default interactive and login shell for newly created user accounts.
- **System Compatibility:** Preserves `/bin/bash` and `/bin/sh` intact for system services, scripts, and DNF transaction scriptlets. Registered in `/etc/shells`.

### zoxide
- **Upstream Repository:** [https://github.com/ajeetdsouza/zoxide](https://github.com/ajeetdsouza/zoxide)
- **Fedora Package:** `zoxide` (Verified in Fedora 45: `0.9.8-3.fc45.x86_64`)
- **License:** MIT
- **Role:** Smarter `cd` command for interactive shells. Initialized in user profile for Brush and Bash.

### uutils coreutils
- **Upstream Repository:** [https://github.com/uutils/coreutils](https://github.com/uutils/coreutils)
- **Fedora Package:** `uutils-coreutils` (Verified in Fedora 45: `0.7.0-14.fc45.x86_64`)
- **License:** MIT
- **Integration Strategy:** Installed as a non-conflicting package. Commands placed in `/usr/lib/cargo/bin` or wrapped via safe user-level shell aliases/functions. GNU coreutils remains the authoritative system provider in `/usr/bin` to guarantee script and SELinux compatibility.

### Starship Prompt
- **Upstream Repository:** [https://github.com/starship/starship](https://github.com/starship/starship)
- **Fedora Package:** `starship` (Verified in Fedora 45: `1.27.0-1.fc45.x86_64`)
- **License:** ISC
- **Role:** Optional modern cross-shell prompt, pre-packaged and configurable.

---

## 7. Build and Packaging Utilities

- **rpm-build / rpmbuild:** Used to package `gofr-release`, `gofr-defaults`, `gofr-boot`, and `gofr-rustyuki-integration`.
- **Podman:** Used to provide rootless containerized builds of RPM packages, kernel integrations, and disk images.
- **QEMU & OVMF:** Used for local UEFI VM boot testing and kernel lifecycle validation.
