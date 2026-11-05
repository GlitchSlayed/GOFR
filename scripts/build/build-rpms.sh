#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/../.." && pwd)"
OUT_DIR="${ROOT_DIR}/out/rpms"

mkdir -p "${OUT_DIR}"

echo "=== Building GOFR RPM Packages via Containerized rpmbuild ==="

# Execute containerized build to guarantee clean buildroot
podman run --rm \
    -v "${ROOT_DIR}:/workspace:z" \
    -w /workspace \
    docker.io/library/fedora:45 \
    bash -c '
        set -euo pipefail
        echo "Installing rpm-build tools inside builder container..."
        dnf5 install -y rpm-build >/dev/null 2>&1

        mkdir -p /root/rpmbuild/{BUILD,RPMS,SOURCES,SPECS,SRPMS}

        PACKAGES=(gofr-release gofr-defaults gofr-boot gofr-rustyuki-integration)

        for PKG in "${PACKAGES[@]}"; do
            echo "Building RPM for ${PKG}..."
            rpmbuild -ba "packaging/${PKG}/${PKG}.spec" --define "_topdir /root/rpmbuild"
        done

        echo "Copying built RPMs to output directory..."
        cp -v /root/rpmbuild/RPMS/*/*.rpm /workspace/out/rpms/
        cp -v /root/rpmbuild/SRPMS/*.src.rpm /workspace/out/rpms/
        echo "RPM build completed successfully."
    '

# Also include pre-built sibling packages (rustyuki and brush-shell) if present
if [ -f "/tmp/rustyuki-0.2.0-1.fc45.x86_64.rpm" ]; then
    cp -v "/tmp/rustyuki-0.2.0-1.fc45.x86_64.rpm" "${OUT_DIR}/"
fi
if [ -f "/tmp/brush-shell-0.4.0-1.fc45.x86_64.rpm" ]; then
    cp -v "/tmp/brush-shell-0.4.0-1.fc45.x86_64.rpm" "${OUT_DIR}/"
fi

echo "All package artifacts in ${OUT_DIR}:"
ls -lh "${OUT_DIR}"/*.rpm
