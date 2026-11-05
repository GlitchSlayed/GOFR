Name:           gofr-defaults
Version:        45.0.0
Release:        1%{?dist}
Summary:        Default shell, CLI, and user profile configuration for GOFR
License:        MIT
URL:            https://github.com/GlitchSlayed/GOFR
BuildArch:      noarch

Requires:       zoxide
Requires:       uutils-coreutils
Requires:       bash
Recommends:     brush-shell

%description
Provides GOFR interactive shell profiles, registering Brush as an acceptable
login shell for new users, configuring zoxide initialization for interactive
sessions, and providing safe user-space aliases for uutils coreutils while
preserving standard GNU coreutils for system scripts and transactions.

%prep
# No prep required

%build
# No build required

%install
mkdir -p %{buildroot}%{_sysconfdir}/profile.d

# Interactive profile integration
cat << 'EOF' > %{buildroot}%{_sysconfdir}/profile.d/gofr-defaults.sh
# GOFR Interactive Environment Setup
# Only execute for interactive shells
if [ -n "${PS1:-}" ] || [ -n "${BRUSH_VERSION:-}" ]; then
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

%post
# Register brush shell in /etc/shells if present
if [ -x %{_bindir}/brush ]; then
    if ! grep -q "^%{_bindir}/brush$" %{_sysconfdir}/shells 2>/dev/null; then
        echo "%{_bindir}/brush" >> %{_sysconfdir}/shells
    fi
    # Safely set default shell for newly created users without clobbering /etc/default/useradd
    useradd -D -s %{_bindir}/brush 2>/dev/null || true
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

%changelog
* Thu Nov 05 2026 GlitchSlayed <60859364+GlitchSlayed@users.noreply.github.com> - 45.0.0-1
- Align with Fedora 45 versioning
- Safely manage default login shell via useradd -D rather than clobbering useradd config
- Remove unsubstantiated global sysctl overrides
- Maintain zoxide and safe interactive uutils integration
