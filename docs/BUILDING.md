# Building GOFR

This guide outlines how to build GOFR RPM packages, configure build environments, and build distribution images.

---

## 1. Prerequisites

GOFR relies on containerized tooling via **Podman** to build packages and images cleanly without requiring root privileges or polluting the developer's workstation host.

Required host tools:
- `podman` (tested with Podman 5.x / 6.x)
- `make`
- `qemu-system-x86_64` (for VM testing)
- `git`

---

## 2. Common Build Commands

The top-level `Makefile` exposes standard targets:

```bash
# Check dependencies and system capabilities
make deps

# Build GOFR RPM packages (gofr-release, gofr-defaults, gofr-boot, gofr-rustyuki-integration)
make rpms

# Build bootable raw / qcow2 disk image
make disk-image

# Build installable hybrid UEFI Netinstall ISO (< 1 GiB)
make iso
# or: make netinstall

# Run VM smoke tests under QEMU with UEFI (OVMF)
make test-vm

# Clean build artifacts
make clean
```

---

## 3. Containerized RPM Build Pipeline

To build the RPM packages reproducibly:
```bash
make rpms
```
This mounts `packaging/` into a Fedora container and executes `rpmbuild -ba` for each package spec file, depositing output packages into `out/rpms/`.
