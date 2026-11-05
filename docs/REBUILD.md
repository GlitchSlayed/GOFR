# GOFR Repository Audit & Rebuild Decisions

This document evaluates the existing components of the GOFR repository against the master engineering directive and classifies each component as **Retain**, **Repair**, **Replace**, or **Remove**.

---

## 1. Classification Matrix

| Component | Path / Scope | Status | Rationale & Remediation |
| :--- | :--- | :--- | :--- |
| **Documentation Baseline** | `docs/UPSTREAM.md`, `docs/ARCHITECTURE.md`, `docs/BOOT.md` | **Repair** | Update to reflect current RustyUKI v0.2.0 interfaces (`/etc/rustyuki/config.toml`, BLS Type #2 `systemd-boot` primary backend, Direct UKI experimental backend), remove obsolete `/etc/uki/uki.conf` assumptions. |
| **RustyUKI Integration Doc** | `docs/RUSTYUKI_INTEGRATION.md` | **Repair** | Update audit to reflect upstream's recent completion of systemd-boot support, sysroot targeting, and atomic durability. Specify GOFR integration contract. |
| **RustyUKI Hook Script** | `packaging/gofr-rustyuki-integration/90-rustyuki.install` | **Remove** | Upstream RustyUKI RPM package already installs and owns `/usr/lib/kernel/install.d/90-rustyuki.install`. Shipping it in GOFR creates duplicate ownership. |
| **RustyUKI Package Spec** | `packaging/rustyuki/` | **Replace / Add** | Package RustyUKI using its official RPM spec from upstream repository (`.github/rpm/rustyuki.spec`). |
| **GOFR Release Spec** | `packaging/gofr-release/gofr-release.spec` | **Repair** | Remove unnecessary Terra repository bootstrapping. Ensure official RPM Fusion Free/Nonfree and CachyOS COPR repository configurations are correctly packaged. |
| **GOFR Defaults Spec** | `packaging/gofr-defaults/gofr-defaults.spec` | **Repair** | Stop blindly overwriting `/etc/default/useradd` with hardcoded shell; use profile and user-creation integration. Remove unsubstantiated global sysctl overrides. Retain safe interactive zoxide and uutils wrappers. |
| **GOFR Boot Spec** | `packaging/gofr-boot/gofr-boot.spec` | **Repair** | Ensure systemd-boot loader configuration (`loader.conf`) and kernel cmdline templates are applied directly to the image and ESP rather than remaining disconnected templates. |
| **GOFR RustyUKI Config** | `packaging/gofr-rustyuki-integration/` | **Repair** | Target `/etc/rustyuki/config.toml`, configure `backend = "systemd-boot"` as primary and expose Direct UKI as alternative; set `esp_path = "/efi"`. |
| **Kickstart Definition** | `kickstarts/gofr-workstation.ks` | **Replace** | Remove contradictory legacy `bootloader --location=mbr` and suppressed `bootctl install || true`. Align with Anaconda UEFI guidelines and 4 GiB ESP at `/efi`. |
| **Disk Image Builder** | `scripts/build/build-disk-image.sh` | **Replace / Add** | Implement a fully automated, containerized disk image build producing a bootable GPT image with 4 GiB FAT32 ESP, Btrfs root, CachyOS kernel, and RustyUKI UKI. |
| **Installer ISO Builder** | `scripts/build/build-iso.sh` | **Replace / Add** | Implement automated ISO composition pipeline targeting UEFI x86_64. |
| **CI / CD Pipeline** | `.github/workflows/ci.yml` | **Replace** | Implement two-tier CI: Tier 1 (fast checks, RPM builds, spec lint) and Tier 2 (QEMU/OVMF boot verification). |
| **Makefile** | `Makefile` | **Repair** | Add functional targets for `make disk-image`, `make iso`, `make test-vm`, and containerized cleanrooms. |
