# GOFR Release Engineering

This document details the release process, artifacts, checksums, and verification steps for GOFR milestones.

---

## 1. Release Deliverables

Every official GOFR release includes:
1. **Installable UEFI ISO Image:** `gofr-<version>-<arch>.iso`
2. **QEMU / Cloud Raw/QCOW2 Image:** `gofr-<version>-<arch>.qcow2`
3. **Sha256 Checksums:** `SHA256SUMS`
4. **GPG Signatures:** `SHA256SUMS.gpg`
5. **Software Bill of Materials (SBOM) & Package Manifest:** `manifest.json`

---

## 2. Release Checklist

- [ ] All GOFR RPMs build cleanly from source.
- [ ] ISO boots under OVMF UEFI.
- [ ] System installer configures 4 GiB ESP at `/efi` and Btrfs root.
- [ ] Target system boots into `systemd-boot` and loads Type #2 UKI.
- [ ] Running kernel is confirmed as `kernel-cachyos`.
- [ ] SELinux is in `Enforcing` mode.
- [ ] Default user shell is `brush` and registers in `/etc/shells`.
- [ ] `zoxide` and `uutils-coreutils` interactive defaults are present.
- [ ] A test kernel update generates a working UKI without dropping the fallback boot option.
- [ ] Image audit verifies zero secrets, zero private keys, and uninitialized machine-ids.
