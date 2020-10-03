#!/bin/bash

source gbash.sh || exit

DEFINE_string linux_distribution 'sid' 'Debian/Ubuntu version to install with debootstrap.'
DEFINE_string --required name '' 'Name of the host. Should be of form `\w+\d+`. \d+ part used for MAC address generation.'
DEFINE_string root_password 'root' 'Root password to set.'

gbash::init_google "$@"

set -o errexit
set -o nounset

die() { echo "$*" 1>&2 ; exit 1; }

# Validate the name.
echo "$FLAGS_name" | grep -qE '^[a-z]+[0-9]+$' || die "'$FLAGS_name' doesn't match '\\w+\\d+"
machine_number="$(echo "$FLAGS_name" | sed -Ee 's/.*([0-9]+)/\1/')"

_generate_mac() {
  nic_number="$1"
  # TODO: Check what this default QEMU prefix means.
  echo "52:54:00:$(printf "%02d" "$machine_number"):00:$(printf "%02d" "$nic_number")"
}

root_image="$FLAGS_name.img"
mnt_dir="${FLAGS_name}_mnt"

# Creates, partitions, formats, and mounts the image
prepare_image() {
  # TODO: Use qemu-image?
  fallocate -l10G "$root_image"
  sector_size=512
  partition_start_sectors=2048
  partition_start_bytes="$(( $sector_size * $partition_start_sectors ))"
  # TODO: Calculate the image size.
  echo "start=        $partition_start_sectors, size=    20969472, type=83" | sfdisk "$root_image"
  disk_loop="$(sudo losetup --show -f "$root_image")"
  partition_loop="$(sudo losetup --show -f "$root_image" -o "$partition_start_bytes")"
  sudo mkfs -t ext4 "$partition_loop"
  mkdir -p "$mnt_dir"
  sudo mount "$partition_loop" "$mnt_dir"
}

extra_packages=(
  tcpdump
  python3-scapy
  net-tools
  man-db
)

# Install the Linux distribution, configure GRUB to boot it.
install() {
  cache_dir="$HOME/.debootstrap-cache"
  mkdir -p "$cache_dir"
  sudo debootstrap --cache-dir="$cache_dir" \
    --include=linux-image-amd64,grub-pc,"$(printf '%s,' "${extra_packages[@]}")" \
    "$FLAGS_linux_distribution" "$mnt_dir"

  sudo grub-install \
    --modules part_msdos \
    --directory "$mnt_dir/usr/lib/grub/i386-pc" \
    --boot-directory "$mnt_dir/boot" \
    "$disk_loop"
  vmlinuz="$(ls "$mnt_dir"/boot/vmlinuz*)"
  vmlinuz="${vmlinuz#*/}"
  initrd="$(ls "$mnt_dir"/boot/initrd*)"
  initrd="${initrd#*/}"
  sudo sh -c "cat > $mnt_dir/boot/grub/grub.cfg" <<END
linux (hd0,msdos1)/$vmlinuz root=/dev/sda1 console=ttyS0 nokaslr
initrd (hd0,msdos1)/$initrd
boot
END
}


configure() {
  yes "$FLAGS_root_password" | sudo chroot "$mnt_dir" passwd

  sudo sh -c "cat >| $mnt_dir/etc/fstab" <<'END'
# <file system>        <dir>         <type>    <options>             <dump> <pass>
/dev/sda1              /             ext4      defaults              1      1
END

  sudo sh -c "echo $FLAGS_name >| $mnt_dir/etc/hostname"
  sudo sh -c "cat >| $mnt_dir/etc/network/interfaces" <<END
source-directory /etc/network/interfaces.d

auto ens3
iface ens3 inet dhcp

auto ens4
iface ens4 inet static
  address 192.168.1.$machine_number
  netmask 255.255.255.0
  hwaddress ether $(_generate_mac 2)
END

  sudo sh -c "cat >| $mnt_dir/root/.bashrc" <<'END'
# https://unix.stackexchange.com/questions/16578/resizable-serial-console-window/283206#283206
res() {
  old=$(stty -g)
  stty raw -echo min 0 time 5
  printf '\0337\033[r\033[999;999H\033[6n\0338' > /dev/tty
  IFS='[;R' read -r _ rows cols _ < /dev/tty
  stty "$old"
  # echo "cols:$cols"
  # echo "rows:$rows"
  stty cols "$cols" rows "$rows"
}
[ $(tty) = /dev/ttyS0 ] && res

export EDITOR=vi
export TERM=screen-256color
export LS_OPTIONS='--color=auto -F'
eval "`dircolors`"
alias ls='ls $LS_OPTIONS'
alias ll='ls $LS_OPTIONS -l'
alias l='ls $LS_OPTIONS -lA'
alias ip='ip -c'
END
}


cleanup() {
  sudo umount "$mnt_dir"
  losetup -j "$root_image" -l --raw -n -O name | xargs sudo losetup -d
}


prepare_image
install
configure
cleanup


# TODO: Connecting with gdb to the kernel
# TODO: make grub use serial console
# TODO: install zsh and my dotfiles
