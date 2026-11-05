Name:           gofr-rustyuki-integration
Version:        0.1.0
Release:        1%{?dist}
Summary:        RustyUKI integration hooks and configuration for GOFR
License:        MIT
URL:            https://github.com/GlitchSlayed/GOFR
BuildArch:      noarch

Requires:       dracut
Requires:       systemd-ukify
Requires:       systemd-boot

%description
Configures RustyUKI for GOFR, setting the EFI System Partition to /efi,
configuring UKI output to /efi/EFI/Linux, and binding kernel installation events
to automated UKI building.

%prep
# No prep required

%build
# No build required

%install
mkdir -p %{buildroot}%{_sysconfdir}/uki
mkdir -p %{buildroot}%{_prefix}/lib/kernel/install.d
mkdir -p %{buildroot}%{_unitdir}

# RustyUKI configuration file tailored for GOFR
cat << 'EOF' > %{buildroot}%{_sysconfdir}/uki/uki.conf
[uki]
kernel_version = ""
esp_path = "/efi"
output_dir = "/efi/EFI/Linux"
cmdline_file = "/etc/kernel/cmdline"
configured_cmdline = "rootflags=subvol=@ ro quiet rhgb"
auto_detect_cmdline = true
cmdline_state_dir = "/var/lib/uki-build"
cmdline_min_tokens = 3
splash = ""
os_release = "/etc/os-release"

[dracut]
extra_args = ["--hostonly", "--no-hostonly-cmdline"]

[ukify]
extra_args = []
EOF

# kernel-install hook for RustyUKI
cat << 'EOF' > %{buildroot}%{_prefix}/lib/kernel/install.d/90-rustyuki.install
#!/usr/bin/env bash
set -uo pipefail

COMMAND="${1:-}"
KERNEL_VER="${2:-unknown}"
KERNEL_IMAGE="${3:-}"
RUSTYUKI_BIN="/usr/bin/rustyuki"
RUSTYUKI_CONFIG="/etc/uki/uki.conf"

log() {
    echo "[gofr-rustyuki-hook] $*" >&2
}

# If rustyuki binary is not yet installed, log and exit cleanly
if [[ ! -x "$RUSTYUKI_BIN" ]]; then
    log "RustyUKI binary not found at $RUSTYUKI_BIN (waiting for rustyuki package)"
    exit 0
fi

case "$COMMAND" in
    add)
        log "Kernel add event for $KERNEL_VER — building UKI"
        if ! "$RUSTYUKI_BIN" --config "$RUSTYUKI_CONFIG" generate --kernel-version "$KERNEL_VER"; then
            log "Warning: UKI generation failed for $KERNEL_VER"
        fi
        ;;
    remove)
        log "Kernel remove event for $KERNEL_VER — reconciling UKIs"
        if ! "$RUSTYUKI_BIN" --config "$RUSTYUKI_CONFIG" reconcile; then
            log "Warning: UKI reconciliation failed after removal of $KERNEL_VER"
        fi
        ;;
    *)
        ;;
esac

exit 0
EOF
chmod 0755 %{buildroot}%{_prefix}/lib/kernel/install.d/90-rustyuki.install

%files
%config(noreplace) %{_sysconfdir}/uki/uki.conf
%{_prefix}/lib/kernel/install.d/90-rustyuki.install

%changelog
* Wed Nov 05 2026 GlitchSlayed <glitchy@example.com> - 0.1.0-1
- Initial GOFR RustyUKI integration package
