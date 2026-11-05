# RustyUKI Integration & Technical Audit

This document details the architectural audit of **RustyUKI** (developed by GlitchSlayed at [https://github.com/GlitchSlayed/RustyUKI](https://github.com/GlitchSlayed/RustyUKI)), its integration into GOFR, and the technical specification for the upcoming RustyUKI rework project.

---

## 1. Project Overview & Audit

- **Repository:** `https://github.com/GlitchSlayed/RustyUKI`
- **Current Version:** `0.2.0` (commit `1d037d0`)
- **Language:** Rust (edition 2021)
- **License:** MIT
- **Primary Purpose:** CLI utility to assemble and manage Unified Kernel Images (UKIs) on Fedora-based distributions utilizing `dracut` for initramfs creation and `ukify` for PE binary assembly.

### Architecture Analysis

```
RustyUKI Source Structure:
├── src/main.rs        # CLI entry point, logging, command routing, root validation
├── src/cli.rs         # Clap command parser (generate, install, reconcile, install-hook, status, confirm)
├── src/cmd.rs         # Command execution abstraction (dry-run vs real execution)
├── src/config.rs      # AppConfig / TOML parser (/etc/uki/uki.conf)
├── src/dracut.rs      # dracut invocation (dracut -f <initrd> <kver>)
├── src/ukify.rs       # ukify invocation (ukify build --linux --initrd --cmdline --output)
├── src/efi.rs         # ESP checks, findmnt, statvfs, efibootmgr boot entry management
├── src/hook.rs        # kernel-install hook generator (90-rustyuki.install) & boot confirm service
├── src/kernel.rs      # Kernel package querying and cmdline discovery/sanitization
├── src/privilege.rs   # UID 0 / root privilege check
└── tests/             # CLI & unit tests
```

---

## 2. Capabilities & Strengths

1. **Two-Stage Assembly Pipeline:**
   - Clearly separates stage 1 (`dracut` creating a temporary initramfs) from stage 2 (`ukify build` combining stub + vmlinuz + initramfs + cmdline + os-release).
   - Atomic rename pattern in `ukify.rs`: writes to `.{output}.tmp` and renames to prevent half-written artifacts.

2. **Command-Line Auto-Detection:**
   - Multi-tier detection in `kernel.rs`: inspects `/proc/cmdline`, `/etc/kernel/cmdline`, and fallback GRUB configurations, sanitizing out transient parameters (`BOOT_IMAGE=`, `initrd=`).

3. **Trial Boot Safety ("BootNext"):**
   - Implements an optional `--boot-once` trial workflow using `efibootmgr -n <entry>` and a companion systemd boot confirmation service (`Commands::Confirm`) to avoid bricking boot configurations.

4. **Disk Safety Pre-flight Checks:**
   - Verifies ESP mount state, read-write status, and checks free disk space (`statvfs`) before attempting generation (requires $\ge 50$ MiB free).

---

## 3. Findings & Required Improvements for RustyUKI Rework

During the audit, several architectural mismatches with modern `systemd-boot` and `kernel-cachyos` were identified. These should be addressed in the separate project to redo and improve RustyUKI:

### A. Kernel Package Querying (`src/kernel.rs`)
- **Current Behavior:**
  ```rust
  let output = runner.run("rpm", &["-q", "kernel"])?;
  let mut kernels = output
      .stdout
      .lines()
      .filter_map(|line| line.strip_prefix("kernel-"))
  ```
- **Issue:** GOFR uses `kernel-cachyos` (and `kernel-cachyos-core`). Running `rpm -q kernel` returns failure or misses CachyOS kernels entirely. Furthermore, stripping `kernel-` from `kernel-cachyos-7.3.1...` yields `cachyos-7.3.1...` which fails the `/lib/modules/<version>/vmlinuz` check.
- **Rework Solution:**
  1. Inspect installed kernel directories directly under `/usr/lib/modules/*/vmlinuz` or `/lib/modules/*/vmlinuz`.
  2. Or generalize the RPM query: `rpm -qa "kernel*" "kernel-cachyos*"` and extract versions using RPM query format: `--queryformat "%{VERSION}-%{RELEASE}.%{ARCH}\n"`.

### B. Bootloader Target: `systemd-boot` BLS Type #2 vs `efibootmgr` NVRAM
- **Current Behavior:**
  RustyUKI's `install` command calls `efibootmgr -c` to create a dedicated UEFI NVRAM boot entry for each generated UKI.
- **Issue:** Modern distributions pairing `systemd-boot` with UKIs rely on **Boot Loader Specification Type #2**. In BLS Type #2:
  - `systemd-boot` scans `$ESP/EFI/Linux/*.efi`.
  - Any valid PE binary in `EFI/Linux/` is automatically discovered and presented in the boot menu.
  - Generating redundant NVRAM boot entries per kernel version can clutter motherboard NVRAM, risk NVRAM overflow, or bypass `systemd-boot`'s menu.
- **Rework Solution:**
  - Add native support for `systemd-boot` mode where placing the signed UKI in `$ESP/EFI/Linux/<entry-name>.efi` is the primary installation action.
  - Make `efibootmgr` direct NVRAM entry creation an optional mode (`--bootloader=systemd-boot` vs `--bootloader=direct-efi`).

### C. ESP Path Standardization
- **Current Behavior:**
  Defaults to `/boot/efi` with output at `/boot/efi/EFI/Linux`.
- **Issue:** GOFR adopts the modern partition layout where the 4 GiB ESP is mounted at `/efi` (or alternatively `/boot`).
- **Rework Solution:**
  - Support automatic detection of `$ESP` following the systemd Extended Boot Loader / ESP specification (checks `/efi`, `/boot`, and `/boot/efi`).

### D. Secure Boot Signing
- **Current Behavior:**
  Passes generic extra args to `ukify`.
- **Rework Solution:**
  - Add first-class signing arguments or configuration fields (`--sign-key`, `--sign-cert`, or `--signtool=sbsign/pesign`).

### E. Microcode Integration
- **Current Behavior:**
  Relies on `dracut` hostonly bundling.
- **Rework Solution:**
  - Ensure CPU microcode (Intel/AMD) is systematically incorporated, either via dracut early microcode or ukify `--uname` / `--microcode` parameters.

---

## 4. GOFR Integration Boundary

While RustyUKI is being improved upstream:

1. **`gofr-rustyuki-integration` RPM:**
   - Ships configuration `/etc/uki/uki.conf` pre-set with:
     ```toml
     [uki]
     esp_path = "/efi"
     output_dir = "/efi/EFI/Linux"
     cmdline_file = "/etc/kernel/cmdline"
     auto_detect_cmdline = true
     ```
   - Ships kernel-install hook at `/usr/lib/kernel/install.d/90-rustyuki.install`.
   - Ships systemd service `rustyuki-boot-confirm.service`.

2. **Fallback & Parallel Mechanism:**
   - GOFR provides `gofr-boot` which also configures standard `kernel-install` plugins so that the system remains bootable even if RustyUKI is undergoing an active local rebuild.
