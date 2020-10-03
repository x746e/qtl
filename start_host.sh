#!/bin/bash

source gbash.sh || exit

DEFINE_dir --required name '' 'Host directory.'

gbash::init_google "$@"

# TODO: Set tmux window name

root_image="$FLAGS_name/root.img"

sudo qemu-system-x86_64 \
  -drive file="$root_image",index=0,format=raw \
  -nic user \
  -nic socket,mcast=230.0.0.1:1234 \
  -serial mon:stdio \
  -display none \
  -m 4G \
  --enable-kvm \
  -cpu host

# TODO: Allow adding/overriding the options.
# TODO: Option to start with debug kernel.
