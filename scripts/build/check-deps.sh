#!/usr/bin/env bash
set -euo pipefail

echo "=== GOFR Dependency and Environment Check ==="

check_cmd() {
    local cmd="$1"
    local required="$2"
    if command -v "$cmd" >/dev/null 2>&1; then
        echo "  [OK] $cmd: $(command -v "$cmd")"
    else
        if [ "$required" = "true" ]; then
            echo "  [FAIL] $cmd (REQUIRED but not found)"
            return 1
        else
            echo "  [WARN] $cmd (optional)"
        fi
    fi
    return 0
}

MISSING=0

echo "Checking host build utilities..."
check_cmd make true || MISSING=$((MISSING + 1))
check_cmd git true || MISSING=$((MISSING + 1))
check_cmd podman false || true

echo "Checking virtualization tools..."
check_cmd qemu-system-x86_64 false || true

if [ -w /dev/kvm ]; then
    echo "  [OK] /dev/kvm is accessible (hardware acceleration enabled)"
else
    echo "  [WARN] /dev/kvm is not writable (software emulation will be used)"
fi

echo "Checking sibling repositories..."
if [ -d "../RustyUKI" ]; then
    echo "  [OK] RustyUKI source directory present at ../RustyUKI"
else
    echo "  [WARN] RustyUKI source not found at ../RustyUKI"
fi

if [ -d "../brush" ]; then
    echo "  [OK] brush source directory present at ../brush"
fi

if [ -d "../fedora-kickstarts" ]; then
    echo "  [OK] fedora-kickstarts present at ../fedora-kickstarts"
fi

if [ "$MISSING" -gt 0 ]; then
    echo "ERROR: Missing $MISSING required host dependencies."
    exit 1
fi

echo "=== Environment check completed successfully ==="
