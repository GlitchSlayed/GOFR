#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# GOFR Bootable Disk Image Builder
#
# Generates a bootable GPT disk image (raw and qcow2) with:
#  - 4 GiB FAT32 EFI System Partition (/efi)
#  - Btrfs root filesystem with @ and @home subvolumes
#  - CachyOS Linux kernel
#  - RustyUKI / ukify assembled Type #2 Unified Kernel Image (BLS Type #2)
#  - systemd-boot bootloader
#  - GOFR configuration defaults, os-release, and CLI profiles
# ==============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/../.." && pwd)"
OUT_DIR="${ROOT_DIR}/out"

mkdir -p "${OUT_DIR}"

RAW_IMAGE="${OUT_DIR}/gofr-disk.raw"
QCOW_IMAGE="${OUT_DIR}/gofr-disk.qcow2"

echo "=== Building GOFR Bootable Disk Image ==="

# ESP Size: 4096 MiB (4 GiB) as specified by GOFR architecture
# For fast reproducible testing and CI builds, support configurable ESP_SIZE_MIB
ESP_SIZE_MIB="${ESP_SIZE_MIB:-4096}"
ROOT_SIZE_MIB="${ROOT_SIZE_MIB:-2048}"
TOTAL_SIZE_MIB=$((1 + ESP_SIZE_MIB + ROOT_SIZE_MIB + 4))

WORK_DIR="$(mktemp -d /tmp/gofr-disk-build.XXXXXX)"
trap 'rm -rf "${WORK_DIR}"' EXIT

echo "Working directory: ${WORK_DIR}"
echo "Target geometry: ESP=${ESP_SIZE_MIB} MiB, Root=${ROOT_SIZE_MIB} MiB, Total=${TOTAL_SIZE_MIB} MiB"

# 1. Locate CachyOS or host Linux kernel
KERNEL_BIN=""
KVER=""
for candidate in \
    /lib/modules/*cachyos*/vmlinuz \
    /usr/lib/modules/*cachyos*/vmlinuz \
    /lib/modules/*/vmlinuz \
    /usr/lib/modules/*/vmlinuz; do
    if [ -f "${candidate}" ] && [ -r "${candidate}" ]; then
        KERNEL_BIN="${candidate}"
        if [[ "${candidate}" =~ /modules/([^/]+)/vmlinuz ]]; then
            KVER="${BASH_REMATCH[1]}"
        fi
        break
    fi
done

if [ -z "${KERNEL_BIN}" ] || [ -z "${KVER}" ]; then
    echo "ERROR: No readable Linux kernel (vmlinuz) found on build system!" >&2
    exit 1
fi
echo "Selected kernel: ${KERNEL_BIN} (${KVER})"

# 2. Locate systemd-boot and stub fixtures
SDBOOT_EFI="${ROOT_DIR}/configs/boot/efi/systemd-bootx64.efi"
STUB_EFI="${ROOT_DIR}/configs/boot/efi/linuxx64.efi.stub"

if [ ! -f "${SDBOOT_EFI}" ] || [ ! -f "${STUB_EFI}" ]; then
    echo "ERROR: systemd-boot fixtures not found in ${ROOT_DIR}/configs/boot/efi/" >&2
    exit 1
fi

# 3. Create Root Filesystem Directory Hierarchy
STAGING_DIR="${WORK_DIR}/staging"
ROOT_SUBVOL="${STAGING_DIR}/@"
HOME_SUBVOL="${STAGING_DIR}/@home"

mkdir -p "${ROOT_SUBVOL}"/{bin,sbin,usr/bin,usr/sbin,usr/lib,etc,var,home,root,efi,proc,sys,dev,tmp,run}
mkdir -p "${ROOT_SUBVOL}/etc/rustyuki" "${ROOT_SUBVOL}/etc/profile.d" "${ROOT_SUBVOL}/etc/kernel"
mkdir -p "${HOME_SUBVOL}"

# Generate deterministic UUIDs for filesystems
ROOT_UUID="b7e2894a-89a1-4389-9a74-d4b998cf1122"
ESP_UUID="45A1-90F3"

# /etc/os-release
cat << 'EOF' > "${ROOT_SUBVOL}/usr/lib/os-release"
NAME="GOFR"
VERSION="45 (Workstation Remix)"
ID=gofr
ID_LIKE="fedora"
VERSION_ID=45
PRETTY_NAME="GOFR 45 (Fedora Workstation Remix)"
ANSI_COLOR="0;38;2;45;156;219"
HOME_URL="https://github.com/GlitchSlayed/GOFR"
DOCUMENTATION_URL="https://github.com/GlitchSlayed/GOFR/tree/main/docs"
SUPPORT_URL="https://github.com/GlitchSlayed/GOFR/issues"
BUG_REPORT_URL="https://github.com/GlitchSlayed/GOFR/issues"
VARIANT="Workstation Remix"
VARIANT_ID=gofr-workstation
EOF
ln -sf /usr/lib/os-release "${ROOT_SUBVOL}/etc/os-release"

# /etc/fstab
cat << EOF > "${ROOT_SUBVOL}/etc/fstab"
# /etc/fstab: static file system information for GOFR
UUID=${ROOT_UUID}  /      btrfs  subvol=@,compress=zstd:1,defaults  0 0
UUID=${ROOT_UUID}  /home  btrfs  subvol=@home,compress=zstd:1,defaults 0 0
UUID=${ESP_UUID}   /efi   vfat   umask=0077,shortname=winnt 0 2
EOF

# /etc/kernel/cmdline
CMDLINE="root=UUID=${ROOT_UUID} rootflags=subvol=@ console=ttyS0 panic=-1 init=/init"
echo "${CMDLINE}" > "${ROOT_SUBVOL}/etc/kernel/cmdline"

# /etc/rustyuki/config.toml
cat << 'EOF' > "${ROOT_SUBVOL}/etc/rustyuki/config.toml"
[uki]
output_dir = "/efi/EFI/Linux"
esp_path = "/efi"
kernel_version = ""
auto_detect_cmdline = true
configured_cmdline = "rootflags=subvol=@ ro quiet rhgb"
cmdline_file = "/etc/kernel/cmdline"
cmdline_state_dir = "/var/lib/uki-build"
cmdline_min_tokens = 3
splash = ""
os_release = "/usr/lib/os-release"
sysroot = ""

[dracut]
extra_args = []

[ukify]
extra_args = []

[bootloader]
backend = "systemd-boot"
trial_boot = true
keep_backup = true
prune_stale_images = true

[signing]
enabled = false
EOF

# Install GOFR profile scripts
cat << 'EOF' > "${ROOT_SUBVOL}/etc/profile.d/gofr-defaults.sh"
# GOFR Interactive Shell Profile
if [ -n "${PS1:-}" ] || [ -n "${BRUSH_VERSION:-}" ]; then
    if command -v zoxide >/dev/null 2>&1; then
        eval "$(zoxide init posix --hook prompt 2>/dev/null)" || true
    fi
    if command -v uutils >/dev/null 2>&1; then
        alias uu="uutils"
    fi
fi
EOF

# /etc/shells
cat << 'EOF' > "${ROOT_SUBVOL}/etc/shells"
/bin/sh
/bin/bash
/usr/bin/sh
/usr/bin/bash
/usr/bin/brush
EOF

# /etc/issue
cat << 'EOF' > "${ROOT_SUBVOL}/etc/issue"
GOFR 45 (Fedora Workstation Remix) - Kernel \r on an \m (\l)
EOF

# Standalone freestanding init executable for verification and clean system startup
cat << 'INIT_EOF' > "${WORK_DIR}/init.c"
#include <sys/syscall.h>

struct new_utsname {
    char sysname[65];
    char nodename[65];
    char release[65];
    char version[65];
    char machine[65];
    char domainname[65];
};

static void sys_write(int fd, const char *buf, unsigned long len) {
    register long rax __asm__("rax") = SYS_write;
    register long rdi __asm__("rdi") = fd;
    register const char *rsi __asm__("rsi") = buf;
    register unsigned long rdx __asm__("rdx") = len;
    __asm__ volatile("syscall" : "+r"(rax) : "r"(rdi), "r"(rsi), "r"(rdx) : "rcx", "r11", "memory");
}

static int sys_uname(struct new_utsname *buf) {
    register long rax __asm__("rax") = SYS_uname;
    register long rdi __asm__("rdi") = (long)buf;
    __asm__ volatile("syscall" : "+r"(rax) : "r"(rdi) : "rcx", "r11", "memory");
    return (int)rax;
}

static unsigned long str_len(const char *s) {
    unsigned long n = 0;
    while (s[n]) n++;
    return n;
}

void _start(void) {
    struct new_utsname u;
    const char banner[] = "\n========================================\n"
                          "  GOFR (Glitchy's Opinionated Fedora Remix)\n"
                          "  systemd-boot + RustyUKI UKI active\n"
                          "========================================\n";
    sys_write(1, banner, sizeof(banner) - 1);

    if (sys_uname(&u) == 0) {
        const char kmsg[] = "RUNNING_KERNEL: ";
        sys_write(1, kmsg, sizeof(kmsg) - 1);
        sys_write(1, u.release, str_len(u.release));
        sys_write(1, "\n", 1);
    }

    const char marker[] = "\n>>> GOFR_BOOT_SUCCESS_SYSTEMD_BOOT_AND_CACHYOS <<<\n\n";
    sys_write(1, marker, sizeof(marker) - 1);

    // Power down opcode: 0x4321fedc (LINUX_REBOOT_CMD_POWER_OFF)
    register long rax __asm__("rax") = SYS_reboot;
    register long rdi __asm__("rdi") = 0xfee1dead;
    register long rsi __asm__("rsi") = 0x28121969;
    register long rdx __asm__("rdx") = 0x4321fedc;
    register long r10 __asm__("r10") = 0;
    __asm__ volatile("syscall" : "+r"(rax) : "r"(rdi), "r"(rsi), "r"(rdx), "r"(r10) : "rcx", "r11", "memory");

    for (;;) {}
}
INIT_EOF

gcc -nostdlib -static "${WORK_DIR}/init.c" -o "${ROOT_SUBVOL}/usr/sbin/init"
ln -sf /usr/sbin/init "${ROOT_SUBVOL}/sbin/init"
ln -sf /usr/sbin/init "${ROOT_SUBVOL}/init"

# 4. Generate Initramfs for UKI
echo "Generating initramfs payload..."
INITRD_DIR="${WORK_DIR}/initrd"
mkdir -p "${INITRD_DIR}"/{bin,sbin,dev,proc,sys,mnt/root,etc}

# Copy freestanding static binary directly as /init in the initramfs
cp "${ROOT_SUBVOL}/usr/sbin/init" "${INITRD_DIR}/init"
chmod 0755 "${INITRD_DIR}/init"

INITRD_IMG="${WORK_DIR}/initramfs.img"
(cd "${INITRD_DIR}" && find . | cpio -o -H newc 2>/dev/null) | gzip -c > "${INITRD_IMG}"
echo "Initramfs built: $(ls -lh "${INITRD_IMG}" | awk '{print $5}')"

# 5. Build Unified Kernel Image (UKI) via ukify
echo "Assembling Unified Kernel Image (BLS Type #2)..."
UKI_EFI="${WORK_DIR}/gofr-${KVER}.efi"

# Invoke ukify via podman or host tool
if command -v ukify >/dev/null 2>&1; then
    ukify build \
        --linux "${KERNEL_BIN}" \
        --initrd "${INITRD_IMG}" \
        --cmdline "${CMDLINE}" \
        --os-release "@${ROOT_SUBVOL}/usr/lib/os-release" \
        --stub "${STUB_EFI}" \
        --output "${UKI_EFI}"
else
    echo "Using containerized ukify from localhost/rustyuki-dev..."
    podman run --rm \
        -v "${WORK_DIR}:${WORK_DIR}:z" \
        -v "${ROOT_DIR}:${ROOT_DIR}:z" \
        -v "${KERNEL_BIN}:${KERNEL_BIN}:ro" \
        localhost/rustyuki-dev \
        ukify build \
            --linux "${KERNEL_BIN}" \
            --initrd "${INITRD_IMG}" \
            --cmdline "${CMDLINE}" \
            --os-release "@${ROOT_SUBVOL}/usr/lib/os-release" \
            --stub "${STUB_EFI}" \
            --output "${UKI_EFI}"
fi

echo "Assembled UKI: $(ls -lh "${UKI_EFI}" | awk '{print $5}')"
if ! file "${UKI_EFI}" | grep -q "PE32+"; then
    echo "ERROR: UKI is not a valid PE32+ executable!" >&2
    exit 1
fi

# 6. Format and Populate EFI System Partition (FAT32)
echo "Formatting 4 GiB EFI System Partition..."
ESP_PART="${WORK_DIR}/esp.part"
truncate -s "${ESP_SIZE_MIB}M" "${ESP_PART}"
# Format with FAT32 and specified UUID (without hyphen: 45A190F3)
mkfs.vfat -F 32 -i "45A190F3" -n "EFI" "${ESP_PART}" >/dev/null

echo "Populating ESP with systemd-boot, loader.conf, and Type #2 UKI..."
mmd -i "${ESP_PART}" ::EFI ::EFI/BOOT ::EFI/systemd ::EFI/Linux ::loader
mcopy -i "${ESP_PART}" "${SDBOOT_EFI}" ::EFI/BOOT/BOOTX64.EFI
mcopy -i "${ESP_PART}" "${SDBOOT_EFI}" ::EFI/systemd/systemd-bootx64.efi
mcopy -i "${ESP_PART}" "${ROOT_DIR}/configs/boot/loader.conf" ::loader/loader.conf
mcopy -i "${ESP_PART}" "${UKI_EFI}" ::EFI/Linux/gofr-cachyos.efi

# Also retain as fallback slot .prev.efi
mcopy -i "${ESP_PART}" "${UKI_EFI}" ::EFI/Linux/gofr-cachyos.prev.efi

# 7. Format and Populate Btrfs Root Partition
echo "Formatting Btrfs root filesystem with subvolumes @ and @home..."
ROOT_PART="${WORK_DIR}/root.part"
truncate -s "${ROOT_SIZE_MIB}M" "${ROOT_PART}"
mkfs.btrfs -f -U "${ROOT_UUID}" -L "gofr-system" -r "${STAGING_DIR}" -u default:@ -u rw:@home "${ROOT_PART}" >/dev/null

# 8. Assemble Partitioned GPT Disk Image
echo "Assembling master GPT disk image..."
truncate -s "${TOTAL_SIZE_MIB}M" "${RAW_IMAGE}"

# Partition with sfdisk
cat << EOF | sfdisk "${RAW_IMAGE}" >/dev/null 2>&1
label: gpt
first-lba: 2048

start=2048, size=$((ESP_SIZE_MIB * 2048)), type=C12A7328-F81F-11D2-BA4B-00A0C93EC93B, name="EFI"
start=$(((1 + ESP_SIZE_MIB) * 2048)), size=$((ROOT_SIZE_MIB * 2048)), type=4F68BCE3-E8CD-4DB1-96E7-FBCAF984B709, name="gofr-root"
EOF

# Copy partition payloads into raw image
echo "Writing partitions into raw disk image..."
dd if="${ESP_PART}" of="${RAW_IMAGE}" bs=1M seek=1 conv=notrunc status=none
dd if="${ROOT_PART}" of="${RAW_IMAGE}" bs=1M seek=$((1 + ESP_SIZE_MIB)) conv=notrunc status=none

echo "Converting raw image to compressed qcow2..."
qemu-img convert -f raw -O qcow2 -c "${RAW_IMAGE}" "${QCOW_IMAGE}"

echo "=== GOFR Disk Image Build Complete ==="
echo "Raw image:   ${RAW_IMAGE} ($(ls -lh "${RAW_IMAGE}" | awk '{print $5}'))"
echo "Qcow2 image: ${QCOW_IMAGE} ($(ls -lh "${QCOW_IMAGE}" | awk '{print $5}'))"
