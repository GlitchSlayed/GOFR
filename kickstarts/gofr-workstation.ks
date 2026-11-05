# GOFR Workstation Kickstart Definition
# Glitchy's Opinionated Fedora Remix
# Base: Fedora 45 x86_64

# Version & Localization
version=F45
lang en_US.UTF-8
keyboard us
timezone UTC --utc

# Storage & Partitioning
%include configs/partitioning/btrfs-4gb-esp.ks

# Network & Authentication
network --bootproto=dhcp --device=link --activate
firewall --enabled --service=mdns
selinux --enforcing

# Repositories
repo --name=fedora --mirrorlist=https://mirrors.fedoraproject.org/mirrorlist?repo=fedora-45&arch=x86_64
repo --name=updates --mirrorlist=https://mirrors.fedoraproject.org/mirrorlist?repo=updates-released-f45&arch=x86_64
repo --name=cachyos --baseurl=https://download.copr.fedorainfracloud.org/results/bieszczaders/kernel-cachyos/fedora-45-x86_64/
repo --name=terra --baseurl=https://repos.fyralabs.com/terra45/

# Bootloader: systemd-boot
bootloader --location=mbr --boot-drive=default

# Packages
%packages
%include configs/packages/gofr-packages.txt
-grub2-common
-grub2-efi-x64
-grubby
%end

# Post Installation Scripts
%post --erroronfail
# Ensure systemd-boot is installed
bootctl install --esp-path=/efi || true

# Register Brush in /etc/shells
if ! grep -q "^/usr/bin/brush$" /etc/shells; then
    echo "/usr/bin/brush" >> /etc/shells
fi

# Enable systemd-boot EFI target
systemctl enable systemd-boot-update.service || true
%end
