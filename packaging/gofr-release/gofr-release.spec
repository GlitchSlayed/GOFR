Name:           gofr-release
Version:        45.0.0
Release:        1%{?dist}
Summary:        GOFR (Glitchy's Opinionated Fedora Remix) Release Files and Repositories
License:        MIT
URL:            https://github.com/GlitchSlayed/GOFR
BuildArch:      noarch

Provides:       system-release(45)
Requires:       fedora-release

%description
GOFR release metadata, distribution identification, and default repository
configurations for CachyOS COPR and official RPM Fusion Free & Nonfree.

%prep
# No prep required

%build
# No build required

%install
mkdir -p %{buildroot}%{_prefix}/lib
mkdir -p %{buildroot}%{_sysconfdir}/yum.repos.d
mkdir -p %{buildroot}%{_sysconfdir}/pki/rpm-gpg

# Install os-release supplement / identity
cat << 'EOF' > %{buildroot}%{_prefix}/lib/gofr-release
NAME="GOFR"
VERSION="45 (Workstation Remix)"
ID=gofr
ID_LIKE="fedora"
VERSION_ID=45
PRETTY_NAME="GOFR 45 (Fedora Workstation Remix)"
ANSI_COLOR="0;38;2;45;156;219"
HOME_URL="https://github.com/GlitchSlayed/GOFR"
DOCUMENTATION_URL="https://github.com/GlitchSlayed/GOFR/tree/main/docs"
SUPPORT_URL="https://github.com/GlitchSlayed/GOFR/issues"
BUG_REPORT_URL="https://github.com/GlitchSlayed/GOFR/issues"
REDHAT_BUGZILLA_PRODUCT="Fedora"
REDHAT_BUGZILLA_PRODUCT_VERSION=45
REDHAT_SUPPORT_PRODUCT="Fedora"
REDHAT_SUPPORT_PRODUCT_VERSION=45
VARIANT="Workstation Remix"
VARIANT_ID=gofr-workstation
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

# Install Starship Copr repository
cat << 'EOF' > %{buildroot}%{_sysconfdir}/yum.repos.d/atim-starship.repo
[copr:copr.fedorainfracloud.org:atim:starship]
name=Copr repo for starship owned by atim
baseurl=https://download.copr.fedorainfracloud.org/results/atim/starship/fedora-$releasever-$basearch/
type=rpm-md
skip_if_unavailable=True
gpgcheck=1
gpgkey=https://download.copr.fedorainfracloud.org/results/atim/starship/pubkey.gpg
repo_gpgcheck=0
enabled=1
enabled_metadata=1
priority=95
EOF

# Install RPM Fusion Free repository
cat << 'EOF' > %{buildroot}%{_sysconfdir}/yum.repos.d/rpmfusion-free.repo
[rpmfusion-free]
name=RPM Fusion for Fedora $releasever - Free
metalink=https://mirrors.rpmfusion.org/metalink?repo=free-fedora-$releasever&arch=$basearch
enabled=1
type=rpm-md
gpgcheck=1
repo_gpgcheck=0
gpgkey=https://rpmfusion.org/keys?action=AttachFile&do=get&target=RPM-GPG-KEY-rpmfusion-free-fedora-$releasever
EOF

# Install RPM Fusion Free Updates repository
cat << 'EOF' > %{buildroot}%{_sysconfdir}/yum.repos.d/rpmfusion-free-updates.repo
[rpmfusion-free-updates]
name=RPM Fusion for Fedora $releasever - Free - Updates
metalink=https://mirrors.rpmfusion.org/metalink?repo=free-fedora-updates-released-$releasever&arch=$basearch
enabled=1
type=rpm-md
gpgcheck=1
repo_gpgcheck=0
gpgkey=https://rpmfusion.org/keys?action=AttachFile&do=get&target=RPM-GPG-KEY-rpmfusion-free-fedora-$releasever
EOF

# Install RPM Fusion Nonfree repository
cat << 'EOF' > %{buildroot}%{_sysconfdir}/yum.repos.d/rpmfusion-nonfree.repo
[rpmfusion-nonfree]
name=RPM Fusion for Fedora $releasever - Nonfree
metalink=https://mirrors.rpmfusion.org/metalink?repo=nonfree-fedora-$releasever&arch=$basearch
enabled=1
type=rpm-md
gpgcheck=1
repo_gpgcheck=0
gpgkey=https://rpmfusion.org/keys?action=AttachFile&do=get&target=RPM-GPG-KEY-rpmfusion-nonfree-fedora-$releasever
EOF

# Install RPM Fusion Nonfree Updates repository
cat << 'EOF' > %{buildroot}%{_sysconfdir}/yum.repos.d/rpmfusion-nonfree-updates.repo
[rpmfusion-nonfree-updates]
name=RPM Fusion for Fedora $releasever - Nonfree - Updates
metalink=https://mirrors.rpmfusion.org/metalink?repo=nonfree-fedora-updates-released-$releasever&arch=$basearch
enabled=1
type=rpm-md
gpgcheck=1
repo_gpgcheck=0
gpgkey=https://rpmfusion.org/keys?action=AttachFile&do=get&target=RPM-GPG-KEY-rpmfusion-nonfree-fedora-$releasever
EOF

%files
%{_prefix}/lib/gofr-release
%config(noreplace) %{_sysconfdir}/yum.repos.d/bieszczaders-kernel-cachyos.repo
%config(noreplace) %{_sysconfdir}/yum.repos.d/atim-starship.repo
%config(noreplace) %{_sysconfdir}/yum.repos.d/rpmfusion-free.repo
%config(noreplace) %{_sysconfdir}/yum.repos.d/rpmfusion-free-updates.repo
%config(noreplace) %{_sysconfdir}/yum.repos.d/rpmfusion-nonfree.repo
%config(noreplace) %{_sysconfdir}/yum.repos.d/rpmfusion-nonfree-updates.repo

%changelog
* Sun Nov 08 2026 GlitchSlayed <60859364+GlitchSlayed@users.noreply.github.com> - 45.0.0-2
- Add Starship Copr repository configuration
* Thu Nov 05 2026 GlitchSlayed <60859364+GlitchSlayed@users.noreply.github.com> - 45.0.0-1
- Align with Fedora 45 release versioning
- Add official RPM Fusion Free and Nonfree repositories
- Remove Terra repository dependency
- Include CachyOS Copr repository
