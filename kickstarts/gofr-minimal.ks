# GOFR Minimal Developer Kickstart Definition
# Glitchy's Opinionated Fedora Remix (GOFR 45)
# Profile: Minimal Developer

version=F45
lang en_US.UTF-8
keyboard us
timezone UTC --utc

# Storage & Partitioning: 4 GiB ESP at /efi, Btrfs root
%include configs/partitioning/btrfs-4gb-esp.ks

# Network & Authentication
network --bootproto=dhcp --device=link --activate
firewall --enabled --service=ssh
selinux --enforcing

# Repositories
repo --name=fedora --mirrorlist=https://mirrors.fedoraproject.org/mirrorlist?repo=fedora-45&arch=x86_64
repo --name=updates --mirrorlist=https://mirrors.fedoraproject.org/mirrorlist?repo=updates-released-f45&arch=x86_64
repo --name=cachyos --baseurl=https://download.copr.fedorainfracloud.org/results/bieszczaders/kernel-cachyos/fedora-45-x86_64/
repo --name=starship --baseurl=https://download.copr.fedorainfracloud.org/results/atim/starship/fedora-45-x86_64/
repo --name=rpmfusion-free --metalink=https://mirrors.rpmfusion.org/metalink?repo=free-fedora-45&arch=x86_64
repo --name=rpmfusion-nonfree --metalink=https://mirrors.rpmfusion.org/metalink?repo=nonfree-fedora-45&arch=x86_64

# Bootloader: Defer legacy GRUB MBR installation; systemd-boot configured in %post
bootloader --location=none

# Package Manifest
%packages
@core
git
tmux
neovim
curl
wget
htop
openssh-server

# CachyOS Performance Kernel
kernel-cachyos
kernel-cachyos-devel

# Bootloader & UKI Subsystem
systemd-boot
systemd-ukify
dracut
rustyuki

# Modern CLI Stack
starship
zoxide
uutils-coreutils
ripgrep
fd-find
bat
eza
btop

# Repositories & Upstream Integrations
rpmfusion-free-release
rpmfusion-nonfree-release

# GOFR Custom RPM Suite
gofr-release
gofr-defaults
gofr-boot
gofr-rustyuki-integration
gofr-welcome

-grub2-common
-grub2-efi-x64
-grubby
%end

# Copy user's graphical UKI boot selection from live environment into target chroot
%post --nochroot --log=/mnt/sysimage/root/gofr-post-nochroot.log
if [ -f /tmp/gofr-boot-backend ]; then
    mkdir -p /mnt/sysimage/etc/rustyuki
    cp -v /tmp/gofr-boot-backend /mnt/sysimage/etc/rustyuki/boot-backend.selected 2>/dev/null || true
elif [ -f /run/gofr-boot-backend ]; then
    mkdir -p /mnt/sysimage/etc/rustyuki
    cp -v /run/gofr-boot-backend /mnt/sysimage/etc/rustyuki/boot-backend.selected 2>/dev/null || true
fi
%end

# Post-Installation Bootloader and Environment Setup
%post --erroronfail --log=/root/gofr-post-install.log
echo "=== Beginning GOFR Post-Installation Configuration (Minimal) ==="

# 0. Apply user's UKI bootloader selection from gofr-welcome if provided
if [ -f /etc/rustyuki/boot-backend.selected ]; then
    SELECTED_BACKEND=$(cat /etc/rustyuki/boot-backend.selected | tr -d '[:space:]')
    rm -f /etc/rustyuki/boot-backend.selected
    if [ -f /etc/rustyuki/config.toml ]; then
        if [ "${SELECTED_BACKEND}" = "direct" ]; then
            echo "Applying user selection: configuring backend = \"direct\" in /etc/rustyuki/config.toml..."
            sed -i 's/backend = "systemd-boot"/backend = "direct"/' /etc/rustyuki/config.toml
        elif [ "${SELECTED_BACKEND}" = "systemd-boot" ]; then
            echo "Applying user selection: configuring backend = \"systemd-boot\" in /etc/rustyuki/config.toml..."
            sed -i 's/backend = "direct"/backend = "systemd-boot"/' /etc/rustyuki/config.toml
        fi
    fi
fi

# 1. Install and configure systemd-boot on the 4 GiB ESP at /efi
echo "Setting up systemd-boot on /efi..."
/usr/sbin/gofr-boot-setup /efi

# 2. Register Brush in /etc/shells if installed
if [ -x /usr/bin/brush ]; then
    echo "Registering /usr/bin/brush in /etc/shells..."
    if ! grep -q "^/usr/bin/brush$" /etc/shells; then
        echo "/usr/bin/brush" >> /etc/shells
    fi
    useradd -D -s /usr/bin/brush || true
fi

# 3. Assemble initial UKI via RustyUKI
echo "Generating initial UKI via RustyUKI..."
/usr/sbin/gofr-uki-reconcile

# 4. Enable SSH server
systemctl enable sshd.service || true

echo "=== GOFR Post-Installation Completed Successfully ==="
%end
