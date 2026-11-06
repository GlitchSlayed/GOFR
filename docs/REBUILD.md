# GOFR Repository Audit & Rebuild Decisions

This document evaluates the components of the GOFR repository against the master engineering directive and records their status, resolution, and current implementation.

---

## 1. Classification & Status Matrix

| Component | Path / Scope | Status | Resolution & Implementation |
| :--- | :--- | :--- | :--- |
| **Documentation Baseline** | `docs/UPSTREAM.md`, `docs/ARCHITECTURE.md`, `docs/BOOT.md` | **Completed** | Updated to reflect RustyUKI v0.2.0 interfaces (`/etc/rustyuki/config.toml`), BLS Type #2 `systemd-boot` primary backend, and Netinstall-first delivery architecture. |
| **RustyUKI Integration Doc** | `docs/RUSTYUKI_INTEGRATION.md` | **Completed** | Documents upstream packaging boundary (`rustyuki-0.2.0-1.fc45.x86_64.rpm`), offline `--sysroot` support, and fallback slot management. |
| **RustyUKI Hook Script** | `packaging/gofr-rustyuki-integration/90-rustyuki.install` | **Completed** | Removed redundant hook from GOFR package; uses upstream RustyUKI's canonical kernel-install hook. |
| **RustyUKI Package Spec** | `packaging/rustyuki/` | **Completed** | Automatically acquires and integrates the verified upstream binary RPM from GitHub Releases. |
| **GOFR Release Spec** | `packaging/gofr-release/gofr-release.spec` | **Completed** | Removed obsolete Terra repos. Configures official RPM Fusion Free/Nonfree and CachyOS COPR with OpenPGP keys. |
| **GOFR Defaults Spec** | `packaging/gofr-defaults/gofr-defaults.spec` | **Completed** | Implements Brush shell default login integration via `useradd -D -s /usr/bin/brush`, profile hooks for zoxide, and safe uutils-coreutils wrappers. |
| **GOFR Boot Spec** | `packaging/gofr-boot/gofr-boot.spec` | **Completed** | Applies systemd-boot loader configuration (`loader.conf`) and UKI cmdline templates to `/efi` and system trees. |
| **GOFR RustyUKI Config** | `packaging/gofr-rustyuki-integration/` | **Completed** | Targets `/etc/rustyuki/config.toml`, sets `backend = "systemd-boot"`, and targets `esp_path = "/efi"`. |
| **Kickstart Definition** | `kickstarts/gofr-workstation.ks` | **Completed** | Configured for pure UEFI with 4 GiB ESP at `/efi` and Btrfs subvolumes (`@` and `@home`). |
| **Disk Image Builder** | `scripts/release/build-workstation-image.sh` | **Completed** | Fully automated containerized build producing a bootable GPT image with 4 GiB FAT32 ESP, Btrfs root, CachyOS kernel, GNOME desktop, and automatic 1800MB multipart chunking. |
| **Installer ISO Builder** | `scripts/build/build-iso.sh` | **Completed** | Assembles hybrid UEFI Netinstall ISO (< 1 GiB) bootable via `systemd-boot`. |
| **CI / CD Pipeline** | `.github/workflows/release.yml`, `ci.yml` | **Completed** | Multi-tier CI & CD pipelines running in pure `fedora:45` containers with incremental release tag generation and automated publishing to GitHub Releases. |
| **Makefile** | `Makefile` | **Completed** | Standardized targets: `make rpms`, `make iso`, `make netinstall`, `make disk-image`, `make test-iso`, `make test-vm`, and `make test-lifecycle`. |
