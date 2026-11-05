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

echo "Built RPM artifacts:"
ls -lh "${OUT_DIR}"/*.rpm
