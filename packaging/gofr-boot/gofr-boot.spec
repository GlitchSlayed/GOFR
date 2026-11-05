Name:           gofr-boot
Version:        0.1.0
Release:        1%{?dist}
Summary:        Bootloader and UKI layout configuration for GOFR
License:        MIT
URL:            https://github.com/GlitchSlayed/GOFR
BuildArch:      noarch

Requires:       systemd-boot
Requires:       systemd-ukify
Requires:       dracut

%description
Provides systemd-boot configuration, UKI layout specifications, and default
loader configuration files for GOFR.

%prep
# No prep required

%build
# No build required

%install
mkdir -p %{buildroot}%{_prefix}/lib/gofr/boot
mkdir -p %{buildroot}%{_sysconfdir}/kernel

# Default loader.conf template
cat << 'EOF' > %{buildroot}%{_prefix}/lib/gofr/boot/loader.conf
default gofr*
timeout 3
console-mode max
auto-entries 1
auto-firmware 1
reboot-for-bitlocker 0
EOF

# Default kernel commandline template
cat << 'EOF' > %{buildroot}%{_prefix}/lib/gofr/boot/cmdline
rootflags=subvol=@ ro quiet rhgb splash
EOF

%files
%{_prefix}/lib/gofr/boot/loader.conf
%{_prefix}/lib/gofr/boot/cmdline

%changelog
* Wed Nov 05 2026 GlitchSlayed <glitchy@example.com> - 0.1.0-1
- Initial GOFR boot package definition
