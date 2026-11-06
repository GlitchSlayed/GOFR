#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# GOFR Automated QEMU/OVMF UEFI ISO Boot Verification Test
# ==============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/../.." && pwd)"
OUT_DIR="${ROOT_DIR}/out"

ISO_IMAGE="${1:-}"
if [ -z "${ISO_IMAGE}" ]; then
    for candidate in "${OUT_DIR}"/gofr-netinstall-*.iso "${OUT_DIR}"/gofr-*.iso; do
        if [ -f "${candidate}" ]; then
            ISO_IMAGE="${candidate}"
            break
        fi
    done
fi

if [ -z "${ISO_IMAGE}" ] || [ ! -f "${ISO_IMAGE}" ]; then
    echo "ERROR: ISO image not found in ${OUT_DIR}. Run 'make iso' first." >&2
    exit 1
fi

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

WORK_DIR="$(mktemp -d /tmp/gofr-iso-test.XXXXXX)"
trap 'rm -rf "${WORK_DIR}"' EXIT

SERIAL_LOG="${WORK_DIR}/serial.log"

echo "=== Booting GOFR Installable ISO in QEMU UEFI ==="

KVM_ARG=()
CPU_ARG=("-cpu" "max")

if [ -w /dev/kvm ]; then
    KVM_ARG=("-enable-kvm")
    CPU_ARG=("-cpu" "host")
fi

set +e
timeout 120s qemu-system-x86_64 \
    -nodefaults \
    -nographic \
    -machine q35 \
    "${KVM_ARG[@]}" \
    "${CPU_ARG[@]}" \
    -m 1024 \
    -drive if=pflash,format=raw,readonly=on,file="${OVMF_CODE}" \
    -drive file="${ISO_IMAGE}",format=raw,media=cdrom \
    -serial file:"${SERIAL_LOG}" \
    -no-reboot < /dev/null > "${WORK_DIR}/qemu.stdout" 2>&1
QEMU_EXIT=$?
set -e

echo "QEMU exit code: ${QEMU_EXIT}"

if [ -f "${WORK_DIR}/qemu.stdout" ] && [ -s "${WORK_DIR}/qemu.stdout" ]; then
    echo "=== QEMU stdout/stderr ==="
    cat "${WORK_DIR}/qemu.stdout"
    echo "=========================="
fi

if [ -f "${SERIAL_LOG}" ]; then
    echo "=== ISO Serial Console Output ==="
    cat "${SERIAL_LOG}"
    echo "================================="
fi

if grep -q "UEFI Installer Media Booted Successfully" "${SERIAL_LOG}"; then
    echo "SUCCESS: GOFR UEFI ISO booted successfully into installer environment!"
    exit 0
else
    echo "ERROR: ISO boot failed to reach installer environment." >&2
    exit 1
fi
