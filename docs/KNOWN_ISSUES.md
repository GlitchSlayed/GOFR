# Known Limitations & Project Tracking

This document records validated milestones, hardware prerequisites, operational requirements, and tracking notes for GOFR.

---

## 1. Validated Implementation Milestones

- [x] **GOFR RPM Package Suite:** `gofr-release`, `gofr-defaults`, `gofr-boot`, and `gofr-rustyuki-integration` compile cleanly in a pure Fedora 45 cleanroom container.
- [x] **Upstream RustyUKI Packaging:** Integrated verified `rustyuki-0.2.0-1.fc45.x86_64.rpm` from `GlitchSlayed/RustyUKI`.
- [x] **Bootable UEFI Disk Image:** `scripts/release/build-workstation-image.sh` constructs complete Workstation images featuring GNOME, CachyOS kernel, 4 GiB ESP, and Btrfs subvolumes (`@` and `@home`).
- [x] **Real QEMU UEFI Boot:** Verified boot sequence in QEMU/OVMF: UEFI firmware loads `systemd-boot`, loads Type #2 UKI, boots CachyOS kernel, mounts root, and reaches userspace init.
- [x] **Netinstall Hybrid UEFI ISO:** Assembles `gofr-netinstall-45.x-x86_64.iso` (< 100 MiB) bootable via `systemd-boot` under UEFI.
- [x] **Kernel Lifecycle & Rollback:** Automated integration test validates multi-generation UKI rotation and fallback retention (`.prev.efi`).
- [x] **Automated Release Pipeline:** GitHub Actions workflow (`release.yml`) builds and publishes official releases with incremental versioning (e.g. `45.1`) in pure Fedora 45 containers.
- [x] **Multipart Image Slicing:** Multi-gigabyte QCOW2 images are automatically split into 1800MB chunks (`.part00`, `.part01`) to comply with GitHub's 2.0 GiB file limit.

---

## 2. Hardware & Architecture Prerequisites

1. **x86-64-v3 CPU Instruction Support:**
   - CachyOS kernel packages are compiled with x86-64-v3 optimization flags (AVX, AVX2, BMI1/2).
   - In virtual machine testing, `-cpu host` or `-cpu max` with KVM acceleration is required.
   - Older pre-Haswell CPUs require fallback to generic Fedora kernel builds.

2. **UEFI Firmware Required:**
   - GOFR uses Unified Kernel Images and `systemd-boot`. Legacy BIOS / MBR booting is not supported.

3. **Secure Boot Key Enrollment:**
   - Development images are built with self-signed or unsigned UKI artifacts.
   - Booting with Secure Boot enabled requires enrolling the signing key into UEFI firmware `db` or `MOK` (see [`docs/SECURE_BOOT.md`](SECURE_BOOT.md)).

---

## 3. Operational and Build Notes

1. **GitHub Releases 2.0 GiB Limit:**
   - The GitHub Releases API rejects file uploads $\ge$ 2,147,483,648 bytes.
   - The Netinstall ISO (~84 MiB) is the recommended distribution deliverable.
   - Pre-installed QCOW2 images are distributed as multipart parts (`.part00`, `.part01`) and reassembled via `cat *.part* > image.qcow2`.

2. **Offline `dnf5 --installroot` Chroot Requirements:**
   - During offline rootfs installation, systemd utilities (`systemd-hwdb`, `systemd-sysusers`) require `/proc`, `/sys`, and `/dev` to be bind-mounted into the target rootfs. Without these mounts, systemd symlink chasing returns `Function not implemented` (ENOSYS).
   - Setting `layout=none` in `/etc/kernel/install.conf` and creating `/run/ostree-booted` cleanly suppresses early posttrans kernel-install executions during offline staging.
