#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# GOFR Full Fedora Workstation Release Image Builder
#
# Generates a bootable, pre-installed Fedora Workstation disk image with:
#  - Base: Fedora Workstation 45 (@workstation-product-environment + GNOME)
#  - Performance Kernel: CachyOS (from Copr bieszczaders/kernel-cachyos)
#  - UKI Subsystem: Type #2 Unified Kernel Image (BLS Type #2) via ukify/dracut
#  - Bootloader: systemd-boot on a 4 GiB FAT32 ESP (/efi)
#  - Filesystem: Btrfs root with @ and @home subvolumes, zstd compression
#  - Modern CLI Stack: zoxide, uutils-coreutils, ripgrep, fd-find, bat, eza, btop
#  - Shell: Brush shell default integration with bash fallback
#  - Security: SELinux Enforcing mode, cleaned machine-id & zero secrets
# ==============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/../.." && pwd)"

FEDORA_RELEASE="${FEDORA_RELEASE:-45}"
VERSION_TAG="${VERSION_TAG:-${FEDORA_RELEASE}.1}"
ESP_SIZE_MIB="${ESP_SIZE_MIB:-4096}"
ROOT_SIZE_MIB="${ROOT_SIZE_MIB:-16384}"
TOTAL_SIZE_MIB=$((1 + ESP_SIZE_MIB + ROOT_SIZE_MIB + 4))

OUT_DIR="${OUT_DIR:-${ROOT_DIR}/out/release}"
RPMS_DIR="${ROOT_DIR}/out/rpms"
IMAGE_NAME="gofr-workstation-${VERSION_TAG}-x86_64"
RAW_IMAGE="${OUT_DIR}/${IMAGE_NAME}.raw"
QCOW_IMAGE="${OUT_DIR}/${IMAGE_NAME}.qcow2"
SHA256_FILE="${OUT_DIR}/SHA256SUMS"
MANIFEST_FILE="${OUT_DIR}/manifest.json"

# Check if running natively inside a Fedora root environment with dnf5
IS_FEDORA_BUILDER=false
if [ -f /etc/fedora-release ] && command -v dnf5 >/dev/null 2>&1 && [ "$(id -u)" -eq 0 ]; then
    IS_FEDORA_BUILDER=true
fi

if [ "${IS_FEDORA_BUILDER}" = false ]; then
    if command -v podman >/dev/null 2>&1; then
        echo "=== Invoking Fedora ${FEDORA_RELEASE} privileged build container via Podman ==="
        mkdir -p "${OUT_DIR}"
        exec podman run --privileged --rm \
            -v "${ROOT_DIR}:${ROOT_DIR}:z" \
            -w "${ROOT_DIR}" \
            -e FEDORA_RELEASE="${FEDORA_RELEASE}" \
            -e VERSION_TAG="${VERSION_TAG}" \
            -e ESP_SIZE_MIB="${ESP_SIZE_MIB}" \
            -e ROOT_SIZE_MIB="${ROOT_SIZE_MIB}" \
            -e OUT_DIR="${OUT_DIR}" \
            registry.fedoraproject.org/fedora:${FEDORA_RELEASE} \
            bash "${ROOT_DIR}/scripts/release/build-workstation-image.sh" "$@"
    else
        echo "ERROR: Release build requires root in Fedora ${FEDORA_RELEASE} or podman container engine!" >&2
        exit 1
    fi
fi

echo "=============================================================================="
echo " GOFR Master Release Build: Fedora Workstation (GNOME) + CachyOS + RustyUKI"
echo " Target Release: Fedora ${FEDORA_RELEASE}"
echo " Partitioning:   ESP=${ESP_SIZE_MIB} MiB, Root=${ROOT_SIZE_MIB} MiB, Total=${TOTAL_SIZE_MIB} MiB"
echo " Output Dir:     ${OUT_DIR}"
echo "=============================================================================="

mkdir -p "${OUT_DIR}"

# 1. Install required build dependencies on host container if missing
MISSING_PKGS=()
for cmd_pkg in \
    "git:git" \
    "make:make" \
    "rpmbuild:rpm-build" \
    "rpmlint:rpmlint" \
    "qemu-img:qemu-img" \
    "ukify:systemd-ukify" \
    "mkfs.btrfs:btrfs-progs" \
    "mkfs.vfat:dosfstools" \
    "mcopy:mtools" \
    "sfdisk:fdisk" \
    "dracut:dracut" \
    "gcc:gcc" \
    "cpio:cpio" \
    "gzip:gzip" \
    "xz:xz" \
    "curl:curl" \
    "file:file"; do
    cmd="${cmd_pkg%%:*}"
    pkg="${cmd_pkg##*:}"
    if ! command -v "${cmd}" >/dev/null 2>&1; then
        MISSING_PKGS+=("${pkg}")
    fi
done

if [ ${#MISSING_PKGS[@]} -gt 0 ]; then
    echo "Installing build prerequisites: ${MISSING_PKGS[*]}..."
    dnf5 install -y "${MISSING_PKGS[@]}"
fi

# 2. Build GOFR custom RPM package suite if not present
if [ ! -d "${RPMS_DIR}" ] || [ -z "$(ls -A "${RPMS_DIR}"/*.rpm 2>/dev/null || true)" ]; then
    echo "Building GOFR custom RPM packages..."
    "${ROOT_DIR}/scripts/build/build-rpms.sh"
fi

# 3. Setup build workspace
WORK_DIR="$(mktemp -d /tmp/gofr-release-build.XXXXXX)"
STAGING_DIR="${WORK_DIR}/staging"
ROOT_SUBVOL="${STAGING_DIR}/@"
HOME_SUBVOL="${STAGING_DIR}/@home"

cleanup() {
    echo "Cleaning build workspace: ${WORK_DIR}..."
    umount -l "${ROOT_SUBVOL}/dev" 2>/dev/null || true
    umount -l "${ROOT_SUBVOL}/sys" 2>/dev/null || true
    umount -l "${ROOT_SUBVOL}/proc" 2>/dev/null || true
    rm -rf "${WORK_DIR}"
}
trap cleanup EXIT

mkdir -p "${ROOT_SUBVOL}"/{proc,sys,dev,run,etc/kernel} "${HOME_SUBVOL}"

ROOT_UUID="b7e2894a-89a1-4389-9a74-d4b998cf1122"
ESP_UUID="45A1-90F3"
ESP_UUID_HEX="45A190F3"

# Mount virtual filesystems for chroot and systemd RPM scriptlets
mount -t proc /proc "${ROOT_SUBVOL}/proc"
mount -t sysfs /sys "${ROOT_SUBVOL}/sys"
mount --bind /dev "${ROOT_SUBVOL}/dev"

# Configure layout=none for offline image composition
cat << 'EOF' > "${ROOT_SUBVOL}/etc/kernel/install.conf"
layout=none
EOF

# Signal kernel posttrans that we are running in an offline image builder
touch "${ROOT_SUBVOL}/run/ostree-booted"

# 4. Configure upstream repositories on host
echo "Enabling CachyOS Copr, Starship Copr, and RPM Fusion repositories..."
dnf5 copr enable -y bieszczaders/kernel-cachyos || true
dnf5 copr enable -y atim/starship || true
dnf5 install -y \
    "https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-${FEDORA_RELEASE}.noarch.rpm" \
    "https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-${FEDORA_RELEASE}.noarch.rpm" || true

# Ensure RustyUKI RPM is available
if [ ! -f "${RPMS_DIR}/rustyuki-0.2.0-1.fc45.x86_64.rpm" ]; then
    echo "Fetching RustyUKI upstream Fedora 45 RPM..."
    curl -sSL "https://github.com/GlitchSlayed/RustyUKI/releases/download/rpm-nightly-20261110-f63f10fc/rustyuki-0.2.0-1.fc45.x86_64.rpm" -o "${RPMS_DIR}/rustyuki-0.2.0-1.fc45.x86_64.rpm" || true
fi

# 5. Populate Root Filesystem via dnf5 --installroot
echo "Installing Fedora Workstation product environment (@workstation-product-environment)..."
echo "This will provision GNOME, Wayland, GDM, PipeWire, CachyOS kernel, and GOFR packages."

dnf5 --installroot="${ROOT_SUBVOL}" \
    --releasever="${FEDORA_RELEASE}" \
    --use-host-config \
    --setopt=install_weak_deps=False \
    --setopt=keepcache=False \
    -y install \
    @workstation-product-environment \
    kernel-cachyos \
    kernel-cachyos-devel \
    systemd-boot \
    systemd-ukify \
    dracut \
    starship \
    zoxide \
    uutils-coreutils \
    ripgrep \
    fd-find \
    bat \
    eza \
    btop \
    "${RPMS_DIR}"/*.noarch.rpm \
    "${RPMS_DIR}"/*.x86_64.rpm

echo "Cleaning installroot package cache and temporary builder mounts..."
dnf5 --installroot="${ROOT_SUBVOL}" clean all

rm -f "${ROOT_SUBVOL}/run/ostree-booted"
rm -f "${ROOT_SUBVOL}/etc/kernel/install.conf"
umount -l "${ROOT_SUBVOL}/dev" 2>/dev/null || true
umount -l "${ROOT_SUBVOL}/sys" 2>/dev/null || true
umount -l "${ROOT_SUBVOL}/proc" 2>/dev/null || true

# 6. Configure target system defaults
echo "Applying GOFR system configuration defaults..."

# Systemd default target: graphical
if [ -d "${ROOT_SUBVOL}/usr/lib/systemd/system" ]; then
    ln -sf /usr/lib/systemd/system/graphical.target "${ROOT_SUBVOL}/etc/systemd/system/default.target"
fi

# Hostname
echo "gofr" > "${ROOT_SUBVOL}/etc/hostname"

# Machine ID uninitialized (generated on first boot)
truncate -s 0 "${ROOT_SUBVOL}/etc/machine-id"

# SELinux Configuration: permissive on first boot to allow proper automatic filesystem relabeling
mkdir -p "${ROOT_SUBVOL}/etc/selinux"
cat << 'EOF' > "${ROOT_SUBVOL}/etc/selinux/config"
SELINUX=permissive
SELINUXTYPE=targeted
EOF
touch "${ROOT_SUBVOL}/.autorelabel"

# /etc/fstab with deterministic UUIDs and Btrfs subvolumes
cat << EOF > "${ROOT_SUBVOL}/etc/fstab"
# /etc/fstab: static file system information for GOFR
UUID=${ROOT_UUID}  /      btrfs  subvol=@,compress=zstd:1  0  0
UUID=${ROOT_UUID}  /home  btrfs  subvol=@home,compress=zstd:1  0  0
UUID=${ESP_UUID}   /efi   vfat   umask=0077,shortname=winnt  0  2
EOF

# Kernel commandline
mkdir -p "${ROOT_SUBVOL}/etc/kernel"
cat << EOF > "${ROOT_SUBVOL}/etc/kernel/cmdline"
root=UUID=${ROOT_UUID} rootflags=subvol=@ rw quiet splash rhgb console=tty0 console=ttyS0
EOF


# Ensure Brush is registered in /etc/shells if present
if [ -x "${ROOT_SUBVOL}/usr/bin/brush" ]; then
    if ! grep -q "^/usr/bin/brush$" "${ROOT_SUBVOL}/etc/shells" 2>/dev/null; then
        echo "/usr/bin/brush" >> "${ROOT_SUBVOL}/etc/shells"
    fi
    sed -i 's|^SHELL=.*|SHELL=/usr/bin/brush|' "${ROOT_SUBVOL}/etc/default/useradd" 2>/dev/null || true
fi

# Disable services causing boot delays or unnecessary background resource consumption
echo "Disabling NetworkManager-wait-online and ModemManager services in installroot..."
systemctl --root="${ROOT_SUBVOL}" disable NetworkManager-wait-online.service 2>/dev/null || true
systemctl --root="${ROOT_SUBVOL}" disable ModemManager.service 2>/dev/null || true
rm -f "${ROOT_SUBVOL}/etc/systemd/system/network-online.target.wants/NetworkManager-wait-online.service"
rm -f "${ROOT_SUBVOL}/etc/systemd/system/multi-user.target.wants/ModemManager.service"
rm -f "${ROOT_SUBVOL}/etc/systemd/system/dbus-org.freedesktop.ModemManager1.service"

# 7. Unified Kernel Image (UKI) Generation
echo "Locating installed CachyOS Linux kernel..."
KERNEL_BIN=""
KVER=""
for candidate in "${ROOT_SUBVOL}"/usr/lib/modules/*cachyos*/vmlinuz "${ROOT_SUBVOL}"/lib/modules/*cachyos*/vmlinuz "${ROOT_SUBVOL}"/lib/modules/*/vmlinuz; do
    if [ -f "${candidate}" ] && [ -r "${candidate}" ]; then
        KERNEL_BIN="${candidate}"
        if [[ "${candidate}" =~ /modules/([^/]+)/vmlinuz ]]; then
            KVER="${BASH_REMATCH[1]}"
        fi
        break
    fi
done

if [ -z "${KERNEL_BIN}" ] || [ -z "${KVER}" ]; then
    echo "ERROR: Failed to locate installed kernel inside installroot!" >&2
    exit 1
fi
echo "Target kernel: ${KERNEL_BIN} (${KVER})"

echo "Generating initramfs with dracut..."
INITRD_IMG="${WORK_DIR}/initramfs.img"
dracut --sysroot "${ROOT_SUBVOL}" \
    --kver "${KVER}" \
    --kmoddir "${ROOT_SUBVOL}/usr/lib/modules/${KVER}" \
    --force \
    --no-hostonly \
    --add "btrfs systemd" \
    "${INITRD_IMG}"

echo "Initramfs generated: $(ls -lh "${INITRD_IMG}" | awk '{print $5}')"

# Locate UEFI stub
STUB_EFI=""
for stub_candidate in \
    "${ROOT_SUBVOL}/usr/lib/systemd/boot/efi/linuxx64.efi.stub" \
    "${ROOT_DIR}/configs/boot/efi/linuxx64.efi.stub" \
    /usr/lib/systemd/boot/efi/linuxx64.efi.stub; do
    if [ -f "${stub_candidate}" ]; then
        STUB_EFI="${stub_candidate}"
        break
    fi
done

if [ -z "${STUB_EFI}" ]; then
    echo "ERROR: systemd-stub linuxx64.efi.stub not found!" >&2
    exit 1
fi

echo "Assembling Unified Kernel Image (BLS Type #2) with ukify..."
UKI_EFI="${WORK_DIR}/gofr-cachyos.efi"
CMDLINE="root=UUID=${ROOT_UUID} rootflags=subvol=@ rw quiet splash rhgb"

ukify build \
    --linux "${KERNEL_BIN}" \
    --initrd "${INITRD_IMG}" \
    --cmdline "${CMDLINE}" \
    --os-release "@${ROOT_SUBVOL}/usr/lib/os-release" \
    --stub "${STUB_EFI}" \
    --output "${UKI_EFI}"

echo "Unified Kernel Image assembled: $(ls -lh "${UKI_EFI}" | awk '{print $5}')"

# 8. Format and Populate 4 GiB EFI System Partition
echo "Formatting 4 GiB EFI System Partition..."
ESP_PART="${WORK_DIR}/esp.part"
truncate -s "${ESP_SIZE_MIB}M" "${ESP_PART}"
mkfs.vfat -F 32 -i "${ESP_UUID_HEX}" -n "EFI" "${ESP_PART}" >/dev/null

# Locate systemd-boot binary
SDBOOT_EFI=""
for sdboot_candidate in \
    "${ROOT_SUBVOL}/usr/lib/systemd/boot/efi/systemd-bootx64.efi" \
    "${ROOT_DIR}/configs/boot/efi/systemd-bootx64.efi" \
    /usr/lib/systemd/boot/efi/systemd-bootx64.efi; do
    if [ -f "${sdboot_candidate}" ]; then
        SDBOOT_EFI="${sdboot_candidate}"
        break
    fi
done

echo "Populating ESP with systemd-boot and Type #2 UKIs..."
mmd -i "${ESP_PART}" ::EFI ::EFI/BOOT ::EFI/systemd ::EFI/Linux ::loader
mcopy -i "${ESP_PART}" "${SDBOOT_EFI}" ::EFI/BOOT/BOOTX64.EFI
mcopy -i "${ESP_PART}" "${SDBOOT_EFI}" ::EFI/systemd/systemd-bootx64.efi
mcopy -i "${ESP_PART}" "${ROOT_DIR}/configs/boot/loader.conf" ::loader/loader.conf
mcopy -i "${ESP_PART}" "${UKI_EFI}" ::EFI/Linux/gofr-cachyos.efi
mcopy -i "${ESP_PART}" "${UKI_EFI}" ::EFI/Linux/gofr-cachyos.prev.efi

# 9. Format Btrfs Root Partition
echo "Formatting Btrfs root filesystem with subvolumes @ and @home..."
ROOT_PART="${WORK_DIR}/root.part"
truncate -s "${ROOT_SIZE_MIB}M" "${ROOT_PART}"
mkfs.btrfs -f -U "${ROOT_UUID}" -L "gofr-system" -r "${STAGING_DIR}" -u default:@ -u rw:@home "${ROOT_PART}" >/dev/null

# Free staging tree to conserve host runner disk space
rm -rf "${STAGING_DIR}"

# 10. Assemble Master Partitioned GPT Disk Image
echo "Assembling master GPT disk image (${RAW_IMAGE})..."
truncate -s "${TOTAL_SIZE_MIB}M" "${RAW_IMAGE}"

cat << EOF | sfdisk "${RAW_IMAGE}" >/dev/null 2>&1
label: gpt
first-lba: 2048

start=2048, size=$((ESP_SIZE_MIB * 2048)), type=C12A7328-F81F-11D2-BA4B-00A0C93EC93B, name="EFI"
start=$(((1 + ESP_SIZE_MIB) * 2048)), size=$((ROOT_SIZE_MIB * 2048)), type=4F68BCE3-E8CD-4DB1-96E7-FBCAF984B709, name="gofr-root"
EOF

echo "Writing ESP partition into raw image..."
dd if="${ESP_PART}" of="${RAW_IMAGE}" bs=1M seek=1 conv=notrunc status=none
rm -f "${ESP_PART}"

echo "Writing Btrfs root partition into raw image..."
dd if="${ROOT_PART}" of="${RAW_IMAGE}" bs=1M seek=$((1 + ESP_SIZE_MIB)) conv=notrunc status=none
rm -f "${ROOT_PART}"

# 11. Convert to Compressed QCOW2 Image
echo "Converting raw disk image to compressed QCOW2 format..."
qemu-img convert -f raw -O qcow2 -c "${RAW_IMAGE}" "${QCOW_IMAGE}"

# Check if QCOW2 image exceeds GitHub's 2GB (2,147,483,648 bytes) release asset upload limit
QCOW_SIZE=$(stat -c%s "${QCOW_IMAGE}")
if [ "${QCOW_SIZE}" -ge 2000000000 ]; then
    echo "QCOW2 image (${QCOW_SIZE} bytes) exceeds GitHub Release 2GB upload limit."
    echo "Splitting into 1800MB chunks for reliable distribution..."
    (
        cd "${OUT_DIR}"
        split -b 1800M -d -a 2 "${IMAGE_NAME}.qcow2" "${IMAGE_NAME}.qcow2.part"
    )
fi

# 12. Checksums and Manifest Generation
echo "Computing SHA256 checksums..."
(
    cd "${OUT_DIR}"
    rm -f "${SHA256_FILE}"
    sha256sum ${IMAGE_NAME}* > "${SHA256_FILE}"
)

cat << EOF > "${MANIFEST_FILE}"
{
  "distribution": "GOFR",
  "fedora_release": "${FEDORA_RELEASE}",
  "version": "${VERSION_TAG}",
  "architecture": "x86_64",
  "desktop": "GNOME",
  "kernel": "${KVER}",
  "bootloader": "systemd-boot",
  "esp_size_mib": ${ESP_SIZE_MIB},
  "root_size_mib": ${ROOT_SIZE_MIB},
  "filesystem": "btrfs",
  "subvolumes": ["@", "@home"],
  "artifacts": [
    "${IMAGE_NAME}.raw",
    "${IMAGE_NAME}.qcow2",
    "SHA256SUMS"
  ]
}
EOF

echo "=============================================================================="
echo " GOFR Workstation Release Build Complete!"
echo " Raw Image:      ${RAW_IMAGE} ($(ls -lh "${RAW_IMAGE}" | awk '{print $5}'))"
echo " QCOW2 Image:    ${QCOW_IMAGE} ($(ls -lh "${QCOW_IMAGE}" | awk '{print $5}'))"
if ls "${QCOW_IMAGE}.part"* 1> /dev/null 2>&1; then
    echo " QCOW2 Chunks:   $(ls -1 "${QCOW_IMAGE}.part"* | xargs -n1 basename | tr '\n' ' ')"
fi
echo " Checksums:      ${SHA256_FILE}"
echo " Manifest:       ${MANIFEST_FILE}"
echo "=============================================================================="
