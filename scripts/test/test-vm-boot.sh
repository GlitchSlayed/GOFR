#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# GOFR Automated QEMU/OVMF UEFI Boot Verification Test
#
# Validates that:
#  1. UEFI firmware loads systemd-boot from ESP (/efi)
#  2. systemd-boot discovers the Type #2 UKI (/EFI/Linux/gofr-cachyos.efi)
#  3. The CachyOS kernel boots successfully with embedded cmdline
#  4. The Btrfs root subvolume @ is mounted
#  5. GOFR userspace init activates and confirms boot
# ==============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/../.." && pwd)"
OUT_DIR="${ROOT_DIR}/out"

DISK_IMAGE="${OUT_DIR}/gofr-disk.qcow2"
DISK_FORMAT="qcow2"

if [ ! -f "${DISK_IMAGE}" ]; then
    if [ -f "${OUT_DIR}/gofr-disk.raw" ]; then
        DISK_IMAGE="${OUT_DIR}/gofr-disk.raw"
        DISK_FORMAT="raw"
    else
        echo "ERROR: Disk image not found in ${OUT_DIR}. Run 'make disk-image' first." >&2
        exit 1
    fi
fi

# Locate OVMF firmware images
OVMF_CODE=""
for candidate in \
    "/usr/share/edk2/ovmf/OVMF_CODE.fd" \
    "/usr/share/OVMF/OVMF_CODE_4M.fd" \
    "/usr/share/OVMF/OVMF_CODE.fd" \
    "/usr/share/edk2/OVMF_CODE.fd" \
    "/usr/share/ovmf/x64/OVMF_CODE.fd" \
    "/usr/share/qemu/OVMF_CODE.fd"; do
    if [ -f "${candidate}" ]; then
        OVMF_CODE="${candidate}"
        break
    fi
done

if [ -z "${OVMF_CODE}" ]; then
    for c in /usr/share/OVMF/*CODE*.fd /usr/share/edk2/*CODE*.fd /usr/share/edk2/ovmf/OVMF*.fd; do
        if [ -f "$c" ] && [[ ! "$c" =~ "VARS" ]]; then
            OVMF_CODE="$c"
            break
        fi
    done
fi

if [ -z "${OVMF_CODE}" ]; then
    echo "ERROR: OVMF UEFI firmware files not found on system!" >&2
    exit 1
fi

WORK_DIR="$(mktemp -d /tmp/gofr-vm-test.XXXXXX)"
trap 'rm -rf "${WORK_DIR}"' EXIT

SERIAL_LOG="${WORK_DIR}/serial.log"

echo "=== Launching GOFR UEFI VM in QEMU ==="
echo "OVMF CODE:  ${OVMF_CODE}"
echo "Disk Image: ${DISK_IMAGE} (${DISK_FORMAT})"
echo "Serial Log: ${SERIAL_LOG}"

KVM_ARG=()
CPU_ARG=("-cpu" "max")

if [ -w /dev/kvm ]; then
    KVM_ARG=("-enable-kvm")
    CPU_ARG=("-cpu" "host")
fi

# Run QEMU with timeout of 120 seconds
set +e
timeout 120s qemu-system-x86_64 \
    -nodefaults \
    -nographic \
    -machine q35 \
    "${KVM_ARG[@]}" \
    "${CPU_ARG[@]}" \
    -m 1024 \
    -drive if=pflash,format=raw,readonly=on,file="${OVMF_CODE}" \
    -drive file="${DISK_IMAGE}",format="${DISK_FORMAT}",snapshot=on \
    -serial file:"${SERIAL_LOG}" \
    -no-reboot < /dev/null > "${WORK_DIR}/qemu.stdout" 2>&1
QEMU_EXIT=$?
set -e

echo "QEMU execution finished with exit status: ${QEMU_EXIT}"

if [ -f "${WORK_DIR}/qemu.stdout" ] && [ -s "${WORK_DIR}/qemu.stdout" ]; then
    echo "=== QEMU stdout/stderr ==="
    cat "${WORK_DIR}/qemu.stdout"
    echo "=========================="
fi

if [ -f "${SERIAL_LOG}" ]; then
    echo "=== VM Guest Serial Console Output ==="
    cat "${SERIAL_LOG}"
    echo "======================================"
fi

# Validate expected success markers in serial log
if grep -q "GOFR_BOOT_SUCCESS_SYSTEMD_BOOT_AND_CACHYOS" "${SERIAL_LOG}"; then
    echo "SUCCESS: GOFR disk image booted successfully via UEFI -> systemd-boot -> CachyOS UKI!"
    if grep -q "cachyos" "${SERIAL_LOG}"; then
        echo "SUCCESS: Running kernel verified as CachyOS!"
    fi
    exit 0
else
    echo "ERROR: Expected boot success marker not found in guest serial log!" >&2
    exit 1
fi
