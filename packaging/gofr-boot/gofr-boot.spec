Name:           gofr-boot
Version:        45.0.0
Release:        1%{?dist}
Summary:        Bootloader policy and systemd-boot configuration for GOFR
License:        MIT
URL:            https://github.com/GlitchSlayed/GOFR
BuildArch:      noarch

Requires:       systemd-boot
Requires:       systemd-ukify
Requires:       dracut

%description
Provides systemd-boot configuration, UKI layout specifications, and bootloader
setup tooling for GOFR.

%prep
# No prep required

%build
# No build required

%install
mkdir -p %{buildroot}%{_prefix}/lib/gofr/boot
mkdir -p %{buildroot}%{_sbindir}
mkdir -p %{buildroot}%{_prefix}/lib/systemd/system-preset

# Default loader.conf template
cat << 'EOF' > %{buildroot}%{_prefix}/lib/gofr/boot/loader.conf
default gofr*
timeout 0
console-mode max
auto-entries 1
auto-firmware 1
reboot-for-bitlocker 0
EOF

# Default kernel commandline template
cat << 'EOF' > %{buildroot}%{_prefix}/lib/gofr/boot/cmdline
rootflags=subvol=@ ro quiet rhgb splash
EOF

# Systemd bootloader setup helper script
cat << 'EOF' > %{buildroot}%{_sbindir}/gofr-boot-setup
#!/usr/bin/env bash
set -euo pipefail

ESP_PATH="${1:-/efi}"

if [ ! -d "${ESP_PATH}" ]; then
    echo "ERROR: ESP mount point ${ESP_PATH} does not exist." >&2
    exit 1
fi

echo "Installing systemd-boot to ${ESP_PATH}..."
bootctl install --esp-path="${ESP_PATH}"

mkdir -p "${ESP_PATH}/loader"
cp -v /usr/lib/gofr/boot/loader.conf "${ESP_PATH}/loader/loader.conf"

echo "systemd-boot installation and GOFR loader configuration completed successfully."
EOF
chmod 0755 %{buildroot}%{_sbindir}/gofr-boot-setup

# Systemd preset enabling systemd-boot-update.service
cat << 'EOF' > %{buildroot}%{_prefix}/lib/systemd/system-preset/50-gofr-boot.preset
enable systemd-boot-update.service
EOF

%files
%{_prefix}/lib/gofr/boot/loader.conf
%{_prefix}/lib/gofr/boot/cmdline
%{_sbindir}/gofr-boot-setup
%{_prefix}/lib/systemd/system-preset/50-gofr-boot.preset

%changelog
* Thu Nov 05 2026 GlitchSlayed <60859364+GlitchSlayed@users.noreply.github.com> - 45.0.0-1
- Align with Fedora 45 versioning
- Provide gofr-boot-setup helper script with proper error propagation
- Include systemd preset for systemd-boot-update
