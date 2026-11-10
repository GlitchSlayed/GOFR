# Changelog

All notable changes to the GOFR (Glitchy's Opinionated Fedora Remix) project are documented in this file.
The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/), and releases adhere to Fedora major version alignment with incremental build releases (`<FEDORA_MAJOR>.<INCREMENT>`).

---

## [45.3] - 2026-11-10

### Fixed & Upstream Alignments
- **Direct UKI Partition Discovery (`util-linux` 2.40+ compatibility):**
  - Resolved `lsblk: unknown column: PARTNUM` failure on modern Fedora systems by querying `PARTN`, falling back to `PARTNUM`, and extracting trailing partition digits via regex in `RustyUKI/src/backend/direct.rs`.
  - Added whole-disk parent device node resolution when inspecting unpartitioned or raw loop devices.
- **`ukify` OS-Release Formatting (`.osrel` PE section integrity):**
  - Resolved `systemd-boot` / `bootctl status` `Bad message` parsing errors by automatically prefixing the `--os-release` file path with `@` (`@{os_release}`) during UKI PE assembly in `RustyUKI/src/build/ukify.rs`.
- **Kernel Install Hook Compatibility:**
  - Added `--kernel` as a first-class alias for `--kernel-version` (`-k`) in the `rustyuki` CLI argument parser.
  - Aligned `/usr/lib/kernel/install.d/90-rustyuki.install` to use canonical `--kernel-version`.
- **Configuration Resolution & Offline Sysroot Safety:**
  - Added fallback search path order (`/etc/rustyuki/config.toml` before `/etc/uki/uki.conf`) in `AppConfig::load()`.
  - Normalized empty `sysroot = ""` configuration values to `None`, preventing accidental invocation of offline sysroot staging modes during live runtime.
  - Removed host dependency on `/usr/bin/which` in `RustyUKI/src/backend/direct.rs` by directly querying `efibootmgr --version` and well-known executable paths.
- **First-Boot SELinux Initialization:**
  - Configured staged raw disk images with `SELINUX=permissive` and `touch /.autorelabel` to ensure unhindered systemd PID 1 startup and clean filesystem relabeling on initial boot before enforcement.

### Added
- **Dual Console Kernel Output:**
  - Included `console=tty0 console=ttyS0` in the default workstation kernel commandline template to ensure full visibility during both headless virtual machine debugging and physical display usage.
- **Bootloader Backend Documentation:**
  - Comprehensive documentation in `docs/RUSTYUKI_INTEGRATION.md` and `docs/BOOT.md` detailing architecture, tradeoffs, NVRAM entry lifecycles, and rollback behavior for both Direct UKI (`backend = "direct"`) and `systemd-boot` (`backend = "systemd-boot"`).
- **Automated Changelog Integration:**
  - Release pipeline automatically incorporates version-specific changelog notes and verification checksums into GitHub Releases.

### Verified
- **Live QEMU/KVM Virtual Machine Lifecycle:**
  - Verified full boot sequence under UEFI OVMF firmware.
  - Verified Direct UKI (`backend = "direct"`): initial UKI generation, NVRAM `Boot000X` creation, trial boot via `BootNext`, kernel update simulation (7.3.3 -> 7.3.4), `.prev.efi` fallback retention, and `rustyuki confirm` promotion.
  - Verified `systemd-boot` (`backend = "systemd-boot"`): BLS Type #2 auto-discovery, clean `bootctl status` without error, kernel update simulation (7.3.4 -> 7.3.5), and rollback slot restoration.

---

## [45.2] - 2026-11-09

### Added
- **Automated Workstation Image Release Pipeline:**
  - Added GitHub Actions workflow (`release.yml`) for automated builds of full Fedora Workstation images (GNOME + CachyOS kernel).
  - Multipart chunking (`.part00`, `.part01`) of QCOW2 images to respect GitHub Releases 2.0 GiB file upload ceiling.
- **Netinstall Hybrid UEFI ISO:**
  - Lightweight (< 1 GiB) bootable ISO streaming packages live from upstream mirrors with custom preset selections.

---

## [45.1] - 2026-11-05

### Added
- **Initial Baseline Release:**
  - Core GOFR RPM packaging suite (`gofr-release`, `gofr-defaults`, `gofr-boot`, `gofr-rustyuki-integration`).
  - Integration with RustyUKI v0.2.0 for BLS Type #2 UKI management.
  - CachyOS kernel with x86-64-v3 optimizations and Btrfs subvolume layout (`@` and `@home`).
