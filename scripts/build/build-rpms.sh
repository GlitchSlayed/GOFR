#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/../.." && pwd)"
OUT_DIR="${ROOT_DIR}/out/rpms"

mkdir -p "${OUT_DIR}"

echo "=== Building GOFR RPM Packages ==="

if command -v rpmbuild >/dev/null 2>&1 && [ "${FORCE_CONTAINER:-0}" != "1" ]; then
    echo "Building natively using Fedora rpmbuild..."
    RPMBUILD_DIR="${HOME}/rpmbuild"
    mkdir -p "${RPMBUILD_DIR}"/{BUILD,RPMS,SOURCES,SPECS,SRPMS}

    PACKAGES=(gofr-release gofr-defaults gofr-boot gofr-rustyuki-integration)

    for PKG in "${PACKAGES[@]}"; do
        echo "Building RPM for ${PKG}..."
        rpmbuild -ba "packaging/${PKG}/${PKG}.spec" --define "_topdir ${RPMBUILD_DIR}"
    done

    echo "Copying built RPMs to output directory..."
    cp -v "${RPMBUILD_DIR}"/RPMS/*/*.rpm "${OUT_DIR}/" || true
    cp -v "${RPMBUILD_DIR}"/SRPMS/*.src.rpm "${OUT_DIR}/" || true
    echo "RPM build completed successfully."
else
    echo "Building in clean Fedora 45 container..."
    podman run --rm \
        -v "${ROOT_DIR}:/workspace:z" \
        -w /workspace \
        registry.fedoraproject.org/fedora:45 \
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
fi

# Also include pre-built sibling packages (rustyuki and brush-shell)
RUSTYUKI_RPM="${OUT_DIR}/rustyuki-0.2.0-1.fc45.x86_64.rpm"
if [ ! -f "${RUSTYUKI_RPM}" ]; then
    if [ -f "/tmp/rustyuki-0.2.0-1.fc45.x86_64.rpm" ]; then
        cp -v "/tmp/rustyuki-0.2.0-1.fc45.x86_64.rpm" "${OUT_DIR}/"
    else
        echo "Fetching RustyUKI upstream Fedora 45 RPM..."
        curl -sSL "https://github.com/GlitchSlayed/RustyUKI/releases/download/rpm-nightly-20261110-6320ec94/rustyuki-0.2.0-1.fc45.x86_64.rpm" -o "${RUSTYUKI_RPM}" || true
    fi
fi

if [ -f "/tmp/brush-shell-0.4.0-1.fc45.x86_64.rpm" ]; then
    cp -v "/tmp/brush-shell-0.4.0-1.fc45.x86_64.rpm" "${OUT_DIR}/"
fi

echo "All package artifacts in ${OUT_DIR}:"
ls -lh "${OUT_DIR}"/*.rpm
