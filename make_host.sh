#!/bin/bash

source gbash.sh || exit

DEFINE_string linux_distribution 'sid' 'Debian/Ubuntu version to install with debootstrap.'
DEFINE_string --required name '' 'Name of the host.'
DEFINE_string root_password 'root' 'Root password to set.'

gbash::init_google "$@"

set -o errexit
set -o nounset

root_image="$FLAGS_name.img"
mnt_dir="${FLAGS_name}_mnt"

## Prepare partitions on the image.
# TODO: Use qemu-image?
fallocate -l10G "$root_image"
sector_size=512
partition_start_sectors=2048
partition_start_bytes="$(( $sector_size * $partition_start_sectors ))"
echo "start=        $partition_start_sectors, size=    20969472, type=83" | sfdisk "$root_image"
disk_loop="$(sudo losetup --show -f "$root_image")"
partition_loop="$(sudo losetup --show -f "$root_image" -o "$partition_start_bytes")"
sudo mkfs -t ext4 "$partition_loop"
mkdir -p "$mnt_dir"
sudo mount "$partition_loop" "$mnt_dir"

## Install and configure the Linux distribution.
cache_dir="$HOME/.debootstrap-cache"
mkdir -p "$cache_dir"
sudo debootstrap --cache-dir="$cache_dir" --include=linux-image-amd64,grub-pc "$FLAGS_linux_distribution" "$mnt_dir"
yes "$FLAGS_root_password" | sudo chroot "$mnt_dir" passwd

sudo grub-install --modules part_msdos --directory "$mnt_dir/usr/lib/grub/i386-pc" --boot-directory "$mnt_dir/boot" "$disk_loop"
vmlinuz="$(ls "$mnt_dir"/boot/vmlinuz*)"
vmlinuz="${vmlinuz#*/}"
initrd="$(ls "$mnt_dir"/boot/initrd*)"
initrd="${initrd#*/}"
grub_cfg=$(cat <<END
linux (hd0,msdos1)/$vmlinuz root=/dev/sda1 console=ttyS0 nokaslr
initrd (hd0,msdos1)/$initrd
boot
END
)
echo "$grub_cfg" | sudo sh -c "cat > $mnt_dir/boot/grub/grub.cfg"

sudo sh -c "echo $FLAGS_name >| $mnt_dir/etc/hostname"

## Cleanup
sudo umount "$mnt_dir"
losetup -j "$root_image" -l --raw -n -O name | xargs sudo losetup -d

# TODO: Mount / rw
# TODO: Internet
# TODO: Local ethernet
# TODO: Connecting with gdb to the kernel
# TODO: ctrl+a doesn't work in the shell
# TODO: terminal size is small
