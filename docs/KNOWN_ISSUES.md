# Known Limitations, Upstream Alignments & Tracking

This document records validated milestones, hardware prerequisites, operational requirements, upstream alignments, and tracking notes for GOFR.

---

## 1. Validated Implementation Milestones

- [x] **GOFR RPM Package Suite:** `gofr-release`, `gofr-defaults`, `gofr-boot`, and `gofr-rustyuki-integration` compile cleanly in a pure Fedora 45 cleanroom container and native build environments.
- [x] **Upstream RustyUKI Packaging:** Integrated verified `rustyuki-0.2.0-1.fc45.x86_64.rpm` from `GlitchSlayed/RustyUKI` with upstream bugfixes.
- [x] **Dual Bootloader Verification:** Live QEMU/KVM verification of both `direct` (Direct UKI NVRAM boot) and `systemd-boot` (BLS Type #2) backends.
- [x] **Live Kernel Updates & Fallbacks:** Verified simulation of multi-generation kernel upgrades (7.3.3 -> 7.3.4 -> 7.3.5) with automatic initrd regeneration, PE32+ UKI assembly, fallback slot preservation (`.prev.efi`), and boot confirmation.
- [x] **Bootable UEFI Disk Image:** `scripts/release/build-workstation-image.sh` constructs complete Workstation images featuring GNOME, CachyOS kernel, 4 GiB ESP, and Btrfs subvolumes (`@` and `@home`).
- [x] **Real QEMU UEFI Boot:** Verified boot sequence in QEMU/OVMF: UEFI firmware loads `systemd-boot`, loads Type #2 UKI, boots CachyOS kernel, mounts root, and reaches userspace init.
- [x] **Netinstall Hybrid UEFI ISO:** Assembles `gofr-netinstall-45.x-x86_64.iso` (< 100 MiB) bootable via `systemd-boot` under UEFI.
- [x] **Automated Release Pipeline:** GitHub Actions workflow (`release.yml`) builds and publishes official releases with incremental versioning (e.g. `45.1`) in pure Fedora 45 containers.
- [x] **Multipart Image Slicing:** Multi-gigabyte QCOW2 images are automatically split into 1800MB chunks (`.part00`, `.part01`) to comply with GitHub's 2.0 GiB file limit.

---

## 2. Upstream Alignments & Bugfixes (RustyUKI 0.2.0)

During end-to-end VM lifecycle testing, several edge cases were uncovered and patched:

1. **`util-linux` Partition Column (`PARTN`):**
   - Modern `util-linux` (Fedora 42+) deprecates `PARTNUM` in favor of `PARTN`.
   - Running `lsblk -no PARTNUM` fails with code 1. Patched `RustyUKI` to query `PARTN` first with fallback to `PARTNUM` and regex trailing-digit parsing.

2. **`ukify` Argument Format (`--os-release @PATH`):**
   - `systemd-ukify` interprets `--os-release` without an `@` prefix as a literal string payload rather than a path to read. This causes `systemd-boot` to reject the generated UKI with `Bad message`.
   - Patched `RustyUKI` to automatically ensure the `@` prefix is applied.

3. **Kernel Install Hook Compatibility:**
   - `90-rustyuki.install` called `rustyuki generate --kernel <ver>`, while `cli.rs` previously expected `--kernel-version`.
   - Added `--kernel` as a first-class CLI alias and aligned the install script.

4. **Default Configuration Resolution:**
   - Fallback chain added to `AppConfig::load()` to search `/etc/rustyuki/config.toml` before `/etc/uki/uki.conf`.
   - Empty `sysroot` configuration values (`""` or `"/"`) are safely normalized to `None`.

---

## 3. Hardware & Architecture Prerequisites

1. **x86-64-v3 CPU Instruction Support:**
   - CachyOS kernel packages are compiled with x86-64-v3 optimization flags (AVX, AVX2, BMI1/2).
   - In virtual machine testing, `-cpu host` or `-cpu max` with KVM acceleration is required.
   - Older pre-Haswell CPUs require fallback to generic Fedora kernel builds.

2. **UEFI Firmware Required:**
   - GOFR uses Unified Kernel Images and `systemd-boot` / Direct UKI. Legacy BIOS / MBR booting is not supported.

3. **Secure Boot Key Enrollment:**
   - Development images are built with self-signed or unsigned UKI artifacts.
   - Booting with Secure Boot enabled requires enrolling the signing key into UEFI firmware `db` or `MOK` (see [`docs/SECURE_BOOT.md`](SECURE_BOOT.md)).

---

## 4. Operational and Build Notes

1. **SELinux Initialization on Staged Raw Images:**
   - When building offline disk images without a full SELinux policy loaded on the host, root filesystems are configured with `SELINUX=permissive` and `touch /.autorelabel` to prevent systemd PID 1 startup denial on initial boot. Once booted, the policy relabels the filesystem and enforcement can be re-enabled.

2. **Dual Serial & Graphic Console Output:**
   - Workstation images include `console=tty0 console=ttyS0` in the default kernel cmdline template. This ensures that boot diagnostic messages are accessible in headless VM testing via serial stdio and simultaneously displayed on physical monitors.

3. **GitHub Releases 2.0 GiB Limit:**
   - The GitHub Releases API rejects file uploads $\ge$ 2,147,483,648 bytes.
   - The Netinstall ISO (~84 MiB) is the recommended distribution deliverable.
   - Pre-installed QCOW2 images are distributed as multipart parts (`.part00`, `.part01`) and reassembled via `cat *.part* > image.qcow2`.
