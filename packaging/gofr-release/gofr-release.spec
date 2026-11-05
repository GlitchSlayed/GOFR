Name:           gofr-release
Version:        0.1.0
Release:        1%{?dist}
Summary:        GOFR (Glitchy's Opinionated Fedora Remix) Release Files and Repositories
License:        MIT
URL:            https://github.com/GlitchSlayed/GOFR
BuildArch:      noarch

Provides:       system-release(45)
Requires:       fedora-release

%description
GOFR release metadata, distribution identification, and default repository
configurations for CachyOS COPR, RPM Fusion Free & Nonfree, and Terra.

%prep
# No prep required

%build
# No build required

%install
mkdir -p %{buildroot}%{_prefix}/lib
mkdir -p %{buildroot}%{_sysconfdir}/yum.repos.d
mkdir -p %{buildroot}%{_sysconfdir}

# Install os-release supplement / identity
cat << 'EOF' > %{buildroot}%{_prefix}/lib/gofr-release
NAME="GOFR"
VERSION="0.1 (Fedora 45 Remix)"
ID=gofr
ID_LIKE="fedora"
VERSION_ID=0.1
PRETTY_NAME="GOFR 0.1 (Fedora 45 Remix)"
ANSI_COLOR="0;38;2;45;156;219"
HOME_URL="https://github.com/GlitchSlayed/GOFR"
DOCUMENTATION_URL="https://github.com/GlitchSlayed/GOFR/tree/main/docs"
SUPPORT_URL="https://github.com/GlitchSlayed/GOFR/issues"
BUG_REPORT_URL="https://github.com/GlitchSlayed/GOFR/issues"
REDHAT_BUGZILLA_PRODUCT="Fedora"
REDHAT_BUGZILLA_PRODUCT_VERSION=45
REDHAT_SUPPORT_PRODUCT="Fedora"
REDHAT_SUPPORT_PRODUCT_VERSION=45
VARIANT="Opinionated Remix"
VARIANT_ID=gofr
EOF

# Install CachyOS Copr repository
cat << 'EOF' > %{buildroot}%{_sysconfdir}/yum.repos.d/bieszczaders-kernel-cachyos.repo
[copr:copr.fedorainfracloud.org:bieszczaders:kernel-cachyos]
name=Copr repo for kernel-cachyos owned by bieszczaders
baseurl=https://download.copr.fedorainfracloud.org/results/bieszczaders/kernel-cachyos/fedora-$releasever-$basearch/
type=rpm-md
skip_if_unavailable=True
gpgcheck=1
gpgkey=https://download.copr.fedorainfracloud.org/results/bieszczaders/kernel-cachyos/pubkey.gpg
repo_gpgcheck=0
enabled=1
enabled_metadata=1
priority=90
EOF

# Install Terra repository for Brush shell
cat << 'EOF' > %{buildroot}%{_sysconfdir}/yum.repos.d/terra.repo
[terra]
name=Terra $releasever
baseurl=https://repos.fyralabs.com/terra$releasever/
enabled=1
gpgcheck=1
gpgkey=https://repos.fyralabs.com/terra$releasever/key.asc
priority=95
EOF

%files
%{_prefix}/lib/gofr-release
%config(noreplace) %{_sysconfdir}/yum.repos.d/bieszczaders-kernel-cachyos.repo
%config(noreplace) %{_sysconfdir}/yum.repos.d/terra.repo

%changelog
* Wed Nov 05 2026 GlitchSlayed <glitchy@example.com> - 0.1.0-1
- Initial GOFR release package definition
