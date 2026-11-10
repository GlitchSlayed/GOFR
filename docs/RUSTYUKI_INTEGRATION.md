# RustyUKI Integration & Upstream Alignment

This document details the architecture, boundaries, runtime integration, and verification between **GOFR** and [RustyUKI](https://github.com/GlitchSlayed/RustyUKI).

---

## 1. Upstream Alignment & Packaging

RustyUKI is maintained independently at `https://github.com/GlitchSlayed/RustyUKI`.

- **Release Consumed:** `0.2.0` (commit `f63f10f`, tag `rpm-nightly-20261110-f63f10fc`)
- **Upstream Package:** `rustyuki-0.2.0-1.fc45.x86_64.rpm` / `rustyuki-0.2.0-1.fc44.x86_64.rpm`
- **Ownership Division:**
  - Upstream `rustyuki` owns:
    - Executable: `/usr/bin/rustyuki`
    - Base configuration: `/etc/rustyuki/config.toml` (with fallback to `/etc/uki/uki.conf`)
    - Kernel update hook: `/usr/lib/kernel/install.d/90-rustyuki.install`
    - Boot confirmation service: `/usr/lib/systemd/system/rustyuki-boot-confirm.service`
    - State directory: `/var/lib/uki-build`
  - `gofr-rustyuki-integration` owns:
    - Dependency on `rustyuki >= 0.2.0`
    - Default kernel cmdline template with Btrfs subvolume flags: `/etc/kernel/cmdline.gofr-template`
    - Administrative helper: `/usr/sbin/gofr-uki-reconcile` (supports `--sysroot` for offline builds)

---

## 2. Bootloader Backends: Architecture & Tradeoffs

GOFR and RustyUKI support two primary boot backends configured via `/etc/rustyuki/config.toml`:

### 2.1 Direct UKI (`backend = "direct"`)

In Direct UKI mode, UEFI firmware executes the Unified Kernel Image directly from the EFI System Partition (ESP) without any intermediate bootloader (such as GRUB or systemd-boot).

- **Mechanics:**
  - RustyUKI registers UEFI boot entries via `efibootmgr` pointing directly to `\EFI\Linux\<uki>.efi`.
  - When a new kernel is installed, RustyUKI creates a new boot entry and schedules it for one-shot trial execution using UEFI `BootNext`.
  - Upon successful userspace startup, `rustyuki confirm` (or `rustyuki-boot-confirm.service`) promotes the newly booted entry (`BootCurrent`) to the front of `BootOrder`.
- **Tradeoffs & Advantages:**
  - *Fastest Boot Path:* Zero bootloader overhead; immediate transition from UEFI firmware to the kernel stub.
  - *Firmware Dependency:* Requires reliable UEFI NVRAM implementation with functioning `BootNext` and `BootOrder` variable retention.
  - *Interactive Menu Limitation:* Lacks an interactive graphical boot menu unless invoked through firmware boot select keys (F11/F12).

### 2.2 systemd-boot (`backend = "systemd-boot"`) [GOFR Default]

In `systemd-boot` mode, systemd's lightweight UEFI boot manager provides entry selection and Boot Loader Specification (BLS) Type #2 discovery.

- **Mechanics:**
  - UKIs placed in `$ESP/EFI/Linux/` are automatically discovered and enumerated at boot time.
  - RustyUKI configures the default entry in `loader.conf` or manages slot state.
  - Fallback retention automatically preserves the prior working kernel as `.prev.efi`.
- **Tradeoffs & Advantages:**
  - *Instant Normal Boot & Safe Recovery:* Boots instantly (`timeout 0`) on healthy boots, automatically arming a 3-second one-shot timeout menu if a trial boot or boot failure occurs.
  - *Broad Firmware Resilience:* Decouples boot success from quirks in buggy UEFI NVRAM implementations.

---

## 3. Upstream Fixes & Stability Enhancements in RustyUKI 0.2.0

During full-installer and VM lifecycle validation across both `direct` and `systemd-boot` backends, the following upstream defects were resolved in RustyUKI:

1. **`util-linux` 2.40+ Partition Column Resolution (`src/backend/direct.rs`):**
   - *Issue:* Modern `lsblk` uses `PARTN` instead of `PARTNUM`. Querying `PARTNUM` failed with exit code 1 (`lsblk: unknown column: PARTNUM`), causing direct UKI generation to abort.
   - *Resolution:* Implemented a multi-tier resolution strategy querying `PARTN`, falling back to `PARTNUM`, and extracting trailing device node digits via regular expressions if needed. Whole-disk parent resolution is also handled cleanly.

2. **`ukify` OS-Release Syntax Alignment (`src/build/ukify.rs`):**
   - *Issue:* `ukify` requires the `--os-release` parameter to be prefixed with `@` (`@/usr/lib/os-release`) when reading from a file. Omitting `@` embeds the file path as literal string text into the `.osrel` PE section, corrupting `bootctl` parsing with `Bad message`.
   - *Resolution:* RustyUKI now automatically prepends `@` to the `os_release` path when assembling the `ukify` command line.

3. **CLI Argument Aliasing & Hook Synchronization (`src/cli.rs` & `90-rustyuki.install`):**
   - *Issue:* `90-rustyuki.install` invoked `rustyuki generate --kernel <ver>`, but `cli.rs` only defined `--kernel-version` without an alias, causing `unexpected argument '--kernel' found`.
   - *Resolution:* Added `#[arg(long, short = 'k', alias = "kernel")]` to `cli.rs` and aligned `90-rustyuki.install` to use `--kernel-version`.

4. **Default Configuration Fallback (`src/config.rs`):**
   - *Issue:* Running `rustyuki` without explicit `--config` failed if `/etc/uki/uki.conf` was absent, even when `/etc/rustyuki/config.toml` existed.
   - *Resolution:* Updated config loader to check `/etc/rustyuki/config.toml` first, falling back to `/etc/uki/uki.conf`.

5. **Safe Sysroot Normalization (`src/config.rs`):**
   - *Issue:* An empty configuration entry `sysroot = ""` was treated as an offline target directory instead of live root mode.
   - *Resolution:* Empty strings or `"/"` in `sysroot` are now normalized to `None`.

6. **Direct Utility Detection (`src/backend/direct.rs`):**
   - *Issue:* Direct UKI relied on `/usr/bin/which` to detect `efibootmgr`, which is not installed in minimal or containerized rootfs environments.
   - *Resolution:* Directly tests `efibootmgr --version` and inspects `/usr/bin/efibootmgr` and `/usr/sbin/efibootmgr`.

---

## 4. Verified Kernel Lifecycle Flow

Both backends have been verified under live QEMU/KVM virtual machine execution:

```
[DNF5 Kernel Upgrade]
       │
       ▼
[/usr/bin/kernel-install add <kver> ... vmlinuz]
       │
       ▼
[/usr/lib/kernel/install.d/90-rustyuki.install]
       │
       ▼
[rustyuki generate --kernel-version <kver>]
       │
       ├─► Stage 1: Dracut generates initramfs
       ├─► Stage 2: ukify assembles PE32+ UKI with stub + kernel + initramfs + @os-release + cmdline
       │
       ▼
[Backend Specific Registration]
       │
       ├─► Direct UKI: efibootmgr creates Boot000X, sets BootNext, preserves fallback slot
       └─► systemd-boot: Places in /efi/EFI/Linux/, rotates .prev.efi, verified by bootctl
       │
       ▼
[Reboot & Health Assessment]
       │
       ▼
[rustyuki confirm --force / rustyuki-boot-confirm.service]
       │
       ├─► Direct UKI: BootCurrent promoted to permanent BootOrder
       └─► systemd-boot: Entry marked permanently active / blessed
```
