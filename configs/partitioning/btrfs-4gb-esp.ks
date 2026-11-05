# GOFR Partitioning Blueprint: 4 GiB FAT32 ESP + Btrfs Root
# Clears partitions on target disk and initializes GPT layout
clearpart --all --initlabel

# EFI System Partition: 4096 MiB (4 GiB), FAT32 mounted at /efi
part /efi --fstype="vfat" --size=4096 --label=EFI --fsoptions="umask=0077,shortname=winnt"

# Btrfs Root Volume
part btrfs.gofr --fstype="btrfs" --size=10240 --grow --label=gofr-system

# Btrfs Subvolumes
btrfs none --label=gofr-system btrfs.gofr
btrfs / --subvol --name=@ btrfs.gofr
btrfs /home --subvol --name=@home btrfs.gofr
