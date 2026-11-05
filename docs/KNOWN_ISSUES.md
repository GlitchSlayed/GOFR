# Known Limitations & Project Tracking

This document records validated milestones, hardware prerequisites, and open tracking items for GOFR.

---

## 1. Validated Implementation Milestones

- [x] **GOFR RPM Package Suite:** `gofr-release`, `gofr-defaults`, `gofr-boot`, and `gofr-rustyuki-integration` build cleanly in containerized Fedora 45 cleanroom.
- [x] **Upstream RustyUKI Packaging:** Integrated verified `rustyuki-0.2.0-1.fc45.x86_64.rpm`.
- [x] **Bootable UEFI Disk Image:** `out/gofr-disk.raw` (6.1 GiB with 4 GiB ESP + Btrfs root) and `out/gofr-disk.qcow2` built without host root privileges.
- [x] **Real QEMU UEFI Boot:** Verified boot sequence in QEMU/OVMF: UEFI firmware loads `systemd-boot`, loads Type #2 UKI, boots CachyOS kernel, mounts root, and reaches userspace init.
- [x] **Installable Hybrid UEFI ISO:** `out/gofr-45.0.0-x86_64.iso` built and verified booting directly from CD-ROM via `systemd-boot` in QEMU.
- [x] **Kernel Lifecycle & Rollback:** Automated test `tests/integration/test_kernel_lifecycle.sh` verifies multi-generation UKI rotation and fallback retention (`.prev.efi`).
- [x] **Two-Tier CI:** Configured GitHub Actions workflow covering linting, RPM packaging, and boot validation.

---

## 2. Hardware & Architecture Prerequisites

1. **x86-64-v3 CPU Instruction Support:**
   - CachyOS kernel packages are compiled with x86-64-v3 optimization flags (AVX, AVX2, BMI1/2).
   - In virtual machine testing, `-cpu host` or `-cpu max` with KVM acceleration is required.
   - Older pre-Haswell CPUs require fallback to generic Fedora kernel builds.

2. **UEFI Firmware Required:**
   - GOFR uses Unified Kernel Images and `systemd-boot`. Legacy BIOS / MBR booting is not supported.

3. **Secure Boot Key Enrollment:**
   - Development images are built with unsigned artifacts (or self-signed). Booting with Secure Boot active requires enrolling the custom signing key into UEFI firmware `db` or `MOK`.
