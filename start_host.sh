#!/bin/bash

source gbash.sh || exit

DEFINE_dir --required name '' 'Host directory.'
DEFINE_bool debug false 'Attach to the kernel with GDB.'

gbash::init_google "$@"

# TODO: Set tmux window name

root_image="$FLAGS_name/root.img"

opts=(
  -drive file="$root_image",index=0,format=raw
  -nic user
  -nic socket,mcast=230.0.0.1:1234
  -serial mon:stdio
  -display none
  -m 4G
  --enable-kvm
  -cpu host
)

if (( FLAGS_debug )); then
  opts+=(-s)
fi

# Make sure we are able to start qemu with sudo, before starting gdb.
sudo true

tmux new-window -a -d -n "gdb $FLAGS_name" gdb "$PWD/$FLAGS_name/pkg-debug-kernel/vmlinux" -ex "dir $PWD/$FLAGS_name/pkg-debug-kernel/linux-src/" -ex 'target remote localhost:1234' -ex continue

sudo qemu-system-x86_64 "${opts[@]}"

# TODO: Allow adding/overriding the options.
# TODO: Option to start with debug kernel.
