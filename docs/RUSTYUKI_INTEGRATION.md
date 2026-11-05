# RustyUKI Integration & Upstream Alignment

This document details the architecture, boundaries, and runtime integration between **GOFR** and [RustyUKI](https://github.com/GlitchSlayed/RustyUKI).

---

## 1. Upstream Alignment & Packaging

RustyUKI is maintained independently at `https://github.com/GlitchSlayed/RustyUKI`.

- **Release Consumed:** `0.2.0` (commit `47f556b`, tag `rpm-nightly-20261105-47f556bc`)
- **Upstream Package:** `rustyuki-0.2.0-1.fc45.x86_64.rpm`
- **Ownership Division:**
  - Upstream `rustyuki` owns:
    - Executable: `/usr/bin/rustyuki`
    - Base configuration: `/etc/rustyuki/config.toml`
    - Kernel update hook: `/usr/lib/kernel/install.d/90-rustyuki.install`
    - Boot confirmation service: `/usr/lib/systemd/system/rustyuki-boot-confirm.service`
    - State directory: `/var/lib/uki-build`
  - `gofr-rustyuki-integration` owns:
    - Dependency on `rustyuki >= 0.2.0`
    - Default kernel cmdline template with Btrfs subvolume flags: `/etc/kernel/cmdline.gofr-template`
    - Administrative helper: `/usr/sbin/gofr-uki-reconcile` (supports `--sysroot` for offline builds)

---

## 2. Verified Capabilities & Boot Flow

1. **BLS Type #2 Discovery:**
   - UKIs are generated as PE32+ executables and placed under `/efi/EFI/Linux/<name>.efi`.
   - `systemd-boot` natively discovers all valid UKIs in `/EFI/Linux/` without requiring NVRAM entry manipulation.

2. **Fallback Retention:**
   - Upstream RustyUKI automatically preserves the previous working UKI as `.prev.efi`.
   - When a new kernel is provisioned, `gofr-cachyos.efi` is updated and `gofr-cachyos.prev.efi` remains bootable in the `systemd-boot` menu.

3. **Trial Boot Safety:**
   - Supports one-shot trial booting (`systemd-boot-set-oneshot` / `efibootmgr -n`) with companion `rustyuki-boot-confirm.service` to prevent unbootable updates.

4. **Offline Sysroot Support:**
   - Both `rustyuki` and `systemd-ukify` support offline image generation via `--sysroot`, allowing GOFR disk images and ISOs to be composed cleanly without host modification.
