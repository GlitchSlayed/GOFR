Name:           gofr-defaults
Version:        45.0.0
Release:        2%{?dist}
Summary:        Default shell, CLI, and user profile configuration for GOFR
License:        MIT
URL:            https://github.com/GlitchSlayed/GOFR
BuildArch:      noarch

Requires:       zoxide
Requires:       uutils-coreutils
Requires:       bash
Recommends:     brush-shell
Recommends:     starship

%description
Provides GOFR interactive shell profiles, registering Brush as an acceptable
login shell for new users, configuring Starship prompt and zoxide initialization
for interactive sessions, providing safe user-space aliases for uutils
coreutils, and establishing default system service presets (disabling boot-blocking
NetworkManager-wait-online and unnecessary ModemManager by default).

%prep
# No prep required

%build
# No build required

%install
mkdir -p %{buildroot}%{_sysconfdir}/profile.d
mkdir -p %{buildroot}%{_sysconfdir}/skel/.config/brush
mkdir -p %{buildroot}%{_prefix}/lib/systemd/system-preset

# Interactive profile integration (applies to bash, brush, and POSIX shells)
cat << 'EOF' > %{buildroot}%{_sysconfdir}/profile.d/gofr-defaults.sh
# GOFR Interactive Environment Setup
# Only execute for interactive shells
if [ -n "${PS1:-}" ] || [ -n "${BRUSH_VERSION:-}" ]; then
    # Initialize starship prompt for interactive shell / brush
    if command -v starship >/dev/null 2>&1; then
        eval "$(starship init bash 2>/dev/null)" || true
    fi

    # Initialize zoxide if installed
    if command -v zoxide >/dev/null 2>&1; then
        eval "$(zoxide init posix --hook prompt 2>/dev/null)" || true
    fi

    # Expose modern uutils utilities safely in interactive mode
    if command -v uutils >/dev/null 2>&1; then
        alias uu="uutils"
    elif [ -x "/usr/lib/cargo/bin/coreutils" ]; then
        alias uu="/usr/lib/cargo/bin/coreutils"
    fi
fi
EOF

# Brush-specific skeleton startup configuration
cat << 'EOF' > %{buildroot}%{_sysconfdir}/skel/.config/brush/brushrc
# GOFR Brush Startup Configuration
if command -v starship >/dev/null 2>&1; then
    eval "$(starship init bash 2>/dev/null)" || true
fi
EOF

# GOFR systemd system preset: disable NetworkManager-wait-online and ModemManager by default
cat << 'EOF' > %{buildroot}%{_prefix}/lib/systemd/system-preset/50-gofr.preset
# GOFR Default System Presets
# Disable services that cause boot delays or unnecessary resource consumption on desktops/VMs
disable NetworkManager-wait-online.service
disable ModemManager.service
EOF

%post
# Register brush shell in /etc/shells if present
if [ -x %{_bindir}/brush ]; then
    if ! grep -q "^%{_bindir}/brush$" %{_sysconfdir}/shells 2>/dev/null; then
        echo "%{_bindir}/brush" >> %{_sysconfdir}/shells
    fi
    # Safely set default shell for newly created users without clobbering /etc/default/useradd
    useradd -D -s %{_bindir}/brush 2>/dev/null || true
fi

# Disable services that cause boot delays or unnecessary background resource consumption
if command -v systemctl >/dev/null 2>&1; then
    if [ -d /run/systemd/system ]; then
        systemctl disable NetworkManager-wait-online.service 2>/dev/null || true
        systemctl disable --now ModemManager.service 2>/dev/null || true
    else
        systemctl disable NetworkManager-wait-online.service 2>/dev/null || true
        systemctl disable ModemManager.service 2>/dev/null || true
    fi
fi

%postun
# Clean up if package removed
if [ "$1" -eq 0 ]; then
    sed -i '\|^%{_bindir}/brush$|d' %{_sysconfdir}/shells 2>/dev/null || true
    if [ "$(useradd -D 2>/dev/null | grep -E '^SHELL=' | cut -d= -f2)" = "%{_bindir}/brush" ]; then
        useradd -D -s /bin/bash 2>/dev/null || true
    fi
fi

%files
%{_sysconfdir}/profile.d/gofr-defaults.sh
%dir %{_sysconfdir}/skel/.config
%dir %{_sysconfdir}/skel/.config/brush
%config(noreplace) %{_sysconfdir}/skel/.config/brush/brushrc
%{_prefix}/lib/systemd/system-preset/50-gofr.preset

%changelog
* Tue Nov 10 2026 GlitchSlayed <60859364+GlitchSlayed@users.noreply.github.com> - 45.0.0-2
- Disable NetworkManager-wait-online.service and ModemManager.service by default via systemd preset and post-install
* Sun Nov 08 2026 GlitchSlayed <60859364+GlitchSlayed@users.noreply.github.com> - 45.0.0-1
- Configure Starship prompt initialization for Brush and interactive shells
* Thu Nov 05 2026 GlitchSlayed <60859364+GlitchSlayed@users.noreply.github.com> - 45.0.0-0
- Align with Fedora 45 versioning
- Safely manage default login shell via useradd -D rather than clobbering useradd config
- Remove unsubstantiated global sysctl overrides
- Maintain zoxide and safe interactive uutils integration
