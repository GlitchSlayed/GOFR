Name:           gofr-defaults
Version:        0.1.0
Release:        1%{?dist}
Summary:        Default shell, CLI, and system configuration for GOFR
License:        MIT
URL:            https://github.com/GlitchSlayed/GOFR
BuildArch:      noarch

Requires:       brush-shell
Requires:       zoxide
Requires:       uutils-coreutils
Requires:       bash

%description
Provides GOFR interactive shell profiles, registering Brush as an acceptable
login shell, configuring zoxide initialization, and providing user-space
access to uutils coreutils while preserving system-wide GNU coreutils.

%prep
# No prep required

%build
# No build required

%install
mkdir -p %{buildroot}%{_sysconfdir}/profile.d
mkdir -p %{buildroot}%{_sysconfdir}/sysctl.d
mkdir -p %{buildroot}%{_sysconfdir}/default

# User creation default shell
cat << 'EOF' > %{buildroot}%{_sysconfdir}/default/useradd
# GOFR useradd defaults
GROUP=100
HOME=/home
INACTIVE=-1
EXPIRE=
SHELL=/usr/bin/brush
SKEL=/etc/skel
CREATE_MAIL_SPOOL=no
EOF

# Interactive profile integration
cat << 'EOF' > %{buildroot}%{_sysconfdir}/profile.d/gofr-defaults.sh
# GOFR Interactive Environment Setup
# Only execute for interactive sessions
if [ -n "$PS1" ] || [ -n "$BRUSH_VERSION" ]; then
    # Initialize zoxide if installed
    if command -v zoxide >/dev/null 2>&1; then
        eval "$(zoxide init posix --hook prompt 2>/dev/null)" || true
    fi

    # Safe alias integration for uutils coreutils without breaking scripts
    if [ -d "/usr/lib/cargo/bin" ] && [ -x "/usr/lib/cargo/bin/coreutils" ]; then
        # Expose modern rust utilities safely in interactive mode
        alias uu="/usr/lib/cargo/bin/coreutils"
    fi
fi
EOF

# Performance sysctl tuning
cat << 'EOF' > %{buildroot}%{_sysconfdir}/sysctl.d/99-gofr-performance.conf
# GOFR Performance tuning
vm.swappiness = 133
vm.vfs_cache_pressure = 50
vm.dirty_bytes = 268435456
vm.dirty_background_bytes = 134217728
EOF

%post
# Register brush shell in /etc/shells if not already present
if ! grep -q "^/usr/bin/brush$" %{_sysconfdir}/shells 2>/dev/null; then
    echo "/usr/bin/brush" >> %{_sysconfdir}/shells
fi

%postun
# Clean up if package removed
if [ "$1" -eq 0 ]; then
    sed -i '\|^/usr/bin/brush$|d' %{_sysconfdir}/shells 2>/dev/null || true
fi

%files
%config(noreplace) %{_sysconfdir}/default/useradd
%{_sysconfdir}/profile.d/gofr-defaults.sh
%{_sysconfdir}/sysctl.d/99-gofr-performance.conf

%changelog
* Wed Nov 05 2026 GlitchSlayed <glitchy@example.com> - 0.1.0-1
- Initial GOFR defaults package definition
