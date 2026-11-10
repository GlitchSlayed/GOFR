# Boot Architecture & UKI Specification

GOFR boots exclusively via UEFI using Unified Kernel Images (UKIs) assembled according to the Boot Loader Specification (BLS). This document specifies the boot chain, supported backends (`systemd-boot` and `direct`), runtime lifecycle hooks, and dual-target boot environments (Netinstall ISO vs. Installed System).

---

## 1. Boot Loader Backends

GOFR supports two UEFI boot mechanisms managed by [RustyUKI](https://github.com/GlitchSlayed/RustyUKI):

| Backend | Primary Use Case | Entry Discovery | Fallback Mechanism |
| :--- | :--- | :--- | :--- |
| **`systemd-boot` (Default)** | General Workstation & ISO install | BLS Type #2 (`$ESP/EFI/Linux/`) | Interactive menu & `.prev.efi` slots |
| **`direct` (Direct UKI)** | Minimal / Ultra-fast boot | UEFI NVRAM (`efibootmgr`) | One-shot `BootNext` + promotion |

### 1.1 systemd-boot (BLS Type #2)
- UKIs are standalone UEFI PE binaries located at:
  ```
  $ESP/EFI/Linux/<ENTRY_TOKEN>-<KERNEL_VERSION>.efi
  ```
- Example:
  ```
  /efi/EFI/Linux/gofr-7.3.3-1.cachyos1.fc45.x86_64.efi
  /efi/EFI/Linux/gofr-7.3.3-1.cachyos1.fc45.x86_64.prev.efi
  ```
- `systemd-boot` automatically discovers all `.efi` binaries in `$ESP/EFI/Linux/` and presents them in the boot menu without requiring NVRAM entry manipulation.

### 1.2 Direct UKI (UEFI NVRAM Direct Boot)
- UEFI firmware loads the UKI binary directly from `$ESP/EFI/Linux/<name>.efi`.
- `efibootmgr` manages entries in UEFI NVRAM:
  - New kernels are registered as trial boot candidates using `BootNext`.
  - Once userland reaches `rustyuki-boot-confirm.service`, `rustyuki confirm` permanently shifts `BootCurrent` to the top of `BootOrder`.
  - If a newly installed kernel faults, a reboot without intervention causes firmware to revert to the previous `BootOrder` entry.

### 1.3 Graphical Backend Selection (`gofr-welcome`)
- In live installer environments, GOFR provides `gofr-welcome`, a dedicated Libadwaita onboarding application.
- It displays a welcome summary of the system architecture and features an interactive UKI boot backend selection page.
- The selected backend is recorded to `/tmp/gofr-boot-backend`, transferred by Kickstart (`%post --nochroot`), and applied automatically to `/etc/rustyuki/config.toml` before initial UKI reconciliation.

---

## 2. Loader Configuration (`loader.conf`)

When using the `systemd-boot` backend, configuration is located at `$ESP/loader/loader.conf`:

```ini
default gofr*
timeout 0
console-mode max
auto-entries 1
auto-firmware 1
reboot-for-bitlocker 0
```

- `default gofr*`: Boots the newest matching entry by default.
- `timeout 0`: Boots instantly without delay on healthy boots (menu can be shown by holding Space or Esc). During trial boots or after a boot failure, a 3-second one-shot timeout is armed (`set-timeout-oneshot 3`).
- `auto-entries 1`: Automatically detects EFI/Linux Type #2 images and Windows Boot Manager if dual-booting.

---

## 3. UKI Anatomy

Each generated UKI binary contains the following PE sections assembled via `systemd-ukify`:

| Section Name | Content | Description |
| :--- | :--- | :--- |
| `.text` / `.data` | `systemd-stub` | UEFI stub loader executable |
| `.linux` | `vmlinuz` | CachyOS kernel binary |
| `.initrd` | `initramfs.img` | Dracut generated initramfs + CPU microcode |
| `.cmdline` | Kernel parameters | `root=UUID=<UUID> rootflags=subvol=@ ro quiet rhgb console=tty0 console=ttyS0` |
| `.osrel` | `/usr/lib/os-release` | OS metadata identifying GOFR (passed via `@/usr/lib/os-release`) |
| `.splash` | Optional bitmap | Boot splash graphic |

---

## 4. Boot Environments

### 4.1 Installed System Boot Sequence
```mermaid
sequenceDiagram
    participant Firmware as UEFI Firmware
    participant Bootloader as systemd-boot (/efi/EFI/BOOT/BOOTX64.EFI)
    participant UKI as Type #2 UKI (/efi/EFI/Linux/gofr-cachyos.efi)
    participant Stub as systemd-stub
    participant Kernel as CachyOS Kernel
    participant Initrd as Dracut Initramfs
    participant Systemd as Root Systemd Init

    Firmware->>Bootloader: Hands off execution
    Bootloader->>Bootloader: Reads loader.conf, scans /EFI/Linux/
    Bootloader->>UKI: Launches default/selected UKI PE binary
    UKI->>Stub: Stub initializes UEFI handover
    Stub->>Kernel: Unpacks and jumps to kernel entry point
    Kernel->>Initrd: Mounts initramfs & runs Dracut hooks
    Initrd->>Initrd: Locates Btrfs UUID & mounts subvolume @
    Initrd->>Systemd: Switches root to /sysroot and executes /usr/lib/systemd/systemd
```

### 4.2 Netinstall Hybrid ISO Boot Sequence
The Netinstall ISO (`gofr-netinstall-*.iso`) provides an El Torito hybrid UEFI boot structure:
- UEFI firmware boots `EFI/BOOT/BOOTX64.EFI` from the embedded EFI system partition.
- `systemd-boot` presents the installation options:
  - **GOFR 45 Netinstall (GNOME Workstation) [Default]**
  - **GOFR 45 Netinstall (Sway Wayland Desktop)**
  - **GOFR 45 Netinstall (Minimal Developer)**
  - **GOFR 45 Netinstall (Interactive Anaconda)**
  - **Reboot into Firmware Interface**
- The installer kernel loads an initramfs with network provisioning and loads package groups directly from upstream mirrors into target disks.

---

## 5. Kernel Lifecycle Flow & Fallback Retention

When a kernel package is installed or updated via DNF5:

1. `dnf5 upgrade kernel-cachyos` downloads and unpacks RPM files into `/usr/lib/modules/<version>/`.
2. DNF5 triggers `/usr/bin/kernel-install add <version> /usr/lib/modules/<version>/vmlinuz`.
3. `kernel-install` invokes plugin `/usr/lib/kernel/install.d/90-rustyuki.install`.
4. RustyUKI reads `/etc/rustyuki/config.toml`, invokes `dracut` to generate the initrd, and `ukify build` to output the new `.efi` directly into `/efi/EFI/Linux/`.
5. The prior working UKI is automatically retained as `.prev.efi`. If the newly installed kernel encounters a fault:
   - Under `systemd-boot`: The system boots with a 3-second one-shot recovery window; if unconfirmed or failing, Automatic Boot Assessment and `.prev.efi` take over.
   - Under `direct`: The system automatically falls back on reboot because `BootNext` expired and the previous entry remains top of `BootOrder`.

---

## 6. Multi-Tiered Fallback Architecture & Recovery Cascade

### 6.1 Direct UKI Fallback Cascade
When booting via `backend = "direct"`, the recovery chain operates directly at the UEFI firmware NVRAM level:
1. **Tier 1 (Latest UKI):** Targeted on trial boot via one-shot UEFI `BootNext`. If successful, `rustyuki confirm` permanently shifts it to `BootOrder[0]`.
2. **Tier 2 (Previous Working UKI):** If the new UKI fails, crashes, or hangs, the reboot drops `BootNext`. Firmware executes `BootOrder[0]`, which points to the previously confirmed operational UKI.
3. **Tier 3 (systemd-boot Emergency Menu):** If direct NVRAM entries are unbootable or corrupted, firmware advances to `Linux Boot Manager` (`systemd-boot`) in `BootOrder`. `systemd-boot` scans the ESP `/EFI/Linux/` directory and presents an interactive rescue menu to boot any discovered UKI or edit parameters.
4. **Tier 4 (UEFI Fallback / GRUB):** If ESP bootloader entries fail, firmware loads the standard fallback executable `\EFI\BOOT\BOOTX64.EFI` or legacy GRUB.

### 6.2 systemd-boot Fallback Cascade
When booting via `backend = "systemd-boot"`, recovery operates through systemd's Boot Loader Interface specification:
1. **Tier 1 (Instant Default Boot):** In normal operation, `timeout 0` boots the default UKI immediately without delay.
2. **Tier 2 (Trial Boot 3-Second Window):** During kernel updates with `trial_boot = true`, RustyUKI configures `set-oneshot <entry>` and arms `set-timeout-oneshot 3`. If the updated kernel fails, the system reboots with a 3-second recovery menu visible.
3. **Tier 3 (Automatic Rollback Slot):** If boot assessment fails or an entry is marked bad, `systemd-boot` automatically bypasses the failing entry and boots the preserved fallback slot (`.prev.efi`).
4. **Tier 4 (Manual Interactive Menu):** Holding <kbd>Space</kbd> or <kbd>Esc</kbd> at boot forces the full boot menu to display, listing all local UKIs and firmware setup.
5. **Tier 5 (Firmware Fallback Bootloader):** If `systemd-bootx64.efi` is missing or damaged, firmware boots `systemd-boot-fallbackx64.efi` or `BOOTX64.EFI`.
