# Building GOFR

This document provides complete instructions for compiling GOFR RPM packages, building the Netinstall hybrid UEFI ISO, creating pre-installed virtual machine disk images, and testing deliverables.

---

## 1. Prerequisites and Build Environment

GOFR builds and tests are designed to run cleanly using **Fedora 45** tooling. All pipelines run in official Fedora 45 OCI containers (`registry.fedoraproject.org/fedora:45`) to guarantee reproducibility across development machines and CI runners.

### Required Host Packages
If building or testing on a Fedora host:

```bash
sudo dnf install -y \
    podman \
    make \
    git \
    qemu-system-x86-core \
    edk2-ovmf \
    util-linux \
    dosfstools \
    btrfs-progs \
    xorriso \
    genisoimage \
    qemu-img
```

Ensure your user is a member of the `kvm` group for hardware acceleration:
```bash
sudo usermod -aG kvm $USER
```

---

## 2. Fast Build Reference

The top-level [`Makefile`](../Makefile) provides standardized shortcuts:

```bash
# Check dependencies and system capabilities
make deps

# Build all custom GOFR RPM packages in clean container
make rpms

# Build bootable hybrid UEFI Netinstall ISO (< 1 GiB)
make iso
# or: make netinstall

# Build pre-installed GPT disk image (4 GiB ESP + Btrfs root)
make disk-image

# Run local QEMU/OVMF UEFI ISO boot smoke test
make test-iso

# Run local QEMU/OVMF UEFI disk image boot smoke test
make test-vm

# Run kernel update lifecycle and UKI fallback test
make test-lifecycle

# Run complete test suite
make test

# Clean build artifacts
make clean
```

---

## 3. Package Build Pipeline (`make rpms`)

The package build script [`scripts/build/build-rpms.sh`](../scripts/build/build-rpms.sh) builds all custom GOFR packages:

- `packaging/gofr-release/`: Distribution identity (`/etc/os-release`), DNF repository configurations (Fedora Base, Updates, RPM Fusion Free & Nonfree, CachyOS COPR), and RPM GPG keys.
- `packaging/gofr-defaults/`: Profile configurations (`/etc/profile.d/gofr-defaults.sh`), Brush shell default configuration, zoxide initialization, and safe uutils-coreutils wrappers.
- `packaging/gofr-boot/`: `systemd-boot` configuration (`loader.conf`), UKI cmdline template (`/etc/kernel/cmdline.gofr-template`), and ESP directory structures.
- `packaging/gofr-rustyuki-integration/`: Integration configuration for RustyUKI (`/etc/rustyuki/config.toml`), targeting BLS Type #2 systemd-boot backend with `/efi` ESP path.

It also automatically acquires upstream `rustyuki-0.2.0-1.fc45.x86_64.rpm` from [GlitchSlayed/RustyUKI](https://github.com/GlitchSlayed/RustyUKI).

Output RPMs are placed in `out/rpms/`:
```
out/rpms/
├── noarch/
│   ├── gofr-boot-45.0.0-1.fc45.noarch.rpm
│   ├── gofr-defaults-45.0.0-1.fc45.noarch.rpm
│   ├── gofr-release-45.0.0-1.fc45.noarch.rpm
│   └── gofr-rustyuki-integration-45.0.0-1.fc45.noarch.rpm
└── x86_64/
    └── rustyuki-0.2.0-1.fc45.x86_64.rpm
```

---

## 4. Netinstall ISO Composition (`make iso` / `make netinstall`)

The Netinstall builder script [`scripts/build/build-iso.sh`](../scripts/build/build-iso.sh) produces `gofr-netinstall-<version>-x86_64.iso` (~196 MiB):

### How the Netinstall ISO is Assembled
1. **UEFI Boot Layout:** Creates an El Torito hybrid UEFI layout containing `systemd-boot` at `/EFI/BOOT/BOOTX64.EFI`.
2. **Multi-Choice Profile UKIs:** Builds independent BLS Type #2 UKIs for each supported installation profile:
   - `01-gofr-workstation.efi` (Fedora Workstation GNOME, default)
   - `02-gofr-sway.efi` (Sway Wayland desktop)
   - `03-gofr-minimal.efi` (Minimal developer environment)
   - `04-gofr-interactive.efi` (Interactive Anaconda installer)
3. **Kickstart Automation:** Embeds all profile kickstart files (`gofr-workstation.ks`, `gofr-sway.ks`, `gofr-minimal.ks`), pre-configured to:
   - Partition target disk with a 4 GiB FAT32 ESP at `/efi` and Btrfs subvolumes (`@` and `@home`).
   - Stream package groups over the network (`@workstation-product-environment` or `@sway-desktop` or minimal dev tools, `kernel-cachyos`, `starship`, `brush`, `rustyuki`).
4. **Hybrid ISO Generation:** Invokes `xorriso` / `mkisofs` to create an ISO image that is directly bootable from optical media or written byte-for-byte to a USB flash drive (`dd`).

---

## 5. Pre-Installed Workstation Image (`scripts/release/build-workstation-image.sh`)

To generate a full pre-installed GNOME desktop disk image:

```bash
# Run release workstation image builder (requires root/container with loop device access)
sudo ./scripts/release/build-workstation-image.sh 45.1
```

### Build Architecture:
1. **Sparse Disk Allocation:** Allocates a 24 GiB raw disk image (`out/gofr-workstation-<version>-x86_64.raw`).
2. **GPT Partitioning:**
   - Partition 1: 4096 MiB EFI System Partition (`/efi`, FAT32).
   - Partition 2: Btrfs root volume formatted with `@` (root) and `@home` (user home directories).
3. **Chroot Environment Preparation:**
   - Mounts the target subvolume to `/tmp/gofr-rootfs-...`.
   - Binds host `/proc`, `/sys`, and `/dev` into the target rootfs. This is critical for systemd utilities (`systemd-hwdb`, `systemd-sysusers`) to avoid `ENOSYS` failures during package installation.
   - Sets `layout=none` in `/etc/kernel/install.conf` and creates `/run/ostree-booted` flag to prevent kernel scriptlets from attempting offline UKI installs before userspace is initialized.
4. **Package Installation:**
   - Runs `dnf5 --installroot` installing `@workstation-product-environment`, `kernel-cachyos`, `kernel-cachyos-devel`, `systemd-boot`, `systemd-ukify`, `dracut`, and GOFR RPMs.
5. **Post-Processing & Compression:**
   - Configures `/etc/fstab` with proper filesystem UUIDs.
   - Installs `systemd-boot` to `/efi/EFI/BOOT/BOOTX64.EFI`.
   - Generates initial Type #2 UKI via `systemd-ukify`.
   - Converts raw disk to sparse QCOW2 image.
   - Slices into 1800MB chunks (`.part00`, `.part01`) if the file size exceeds GitHub's 2.0 GiB limit.

---

## 6. Verification and Smoke Testing

### ISO Boot Verification (`make test-iso`)
Spawns QEMU with UEFI (OVMF) firmware and the Netinstall ISO:
```bash
make test-iso
```
The test verifies that the hybrid ISO boots to `systemd-boot`, executes the kernel, and emits a serial console boot banner.

### VM Disk Boot Verification (`make test-vm`)
Tests the partitioned disk image:
```bash
make test-vm
```
Verifies that UEFI firmware boots `systemd-boot`, detects `/EFI/Linux/gofr-cachyos.efi`, mounts the Btrfs `@` subvolume, and reaches target init.

### Kernel Lifecycle Verification (`make test-lifecycle`)
Verifies update durability and rollback:
```bash
make test-lifecycle
```
Validates that when a new kernel version is installed, RustyUKI creates a new UKI entry while keeping the prior working kernel in the `.prev.efi` fallback slot.
