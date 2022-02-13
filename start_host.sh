#!/bin/bash

source gbash.sh || exit

DEFINE_dir --required name '' 'Host directory.'
DEFINE_bool debug false 'Attach to the kernel with GDB.'
DEFINE_bool net_dump false 'Capture traffic on the NIC connecting the VMs.'

gbash::init_google "$@"

tmux rename-window $FLAGS_name

root_image="$FLAGS_name/root.img"

opts=(
  -drive file="$root_image",index=0,format=raw
  -nic user
  -netdev socket,id=eth1,mcast=230.0.0.1:1234
  -device e1000,netdev=eth1
  -serial mon:stdio
  -display none
  -m 4G
  --enable-kvm
  -cpu host
)

if (( FLAGS_debug )); then
  opts+=(-s)
  # Make sure we are able to start qemu with sudo, before starting gdb.
  sudo true
  gdb_dir="$HOME/src/binutils-gdb/build"
  gdb="$gdb_dir/gdb/gdb --data-directory=$gdb_dir/gdb/data-directory"
  tmux new-window -a -d -n "gdb $FLAGS_name" "cd kernels/linux; $gdb vmlinux -ex 'target remote localhost:1234' -ex continue"
fi

if (( FLAGS_net_dump )); then
  pcap_path="$FLAGS_name/net_dump.pcap"
  opts+=(
    -object filter-dump,id=net_dump_1,netdev=eth1,file="$pcap_path"
  )
  rm -f "$pcap_path"
  tmux new-window -a -d -n "net-dump $FLAGS_name" "tail -n 10000 -F $pcap_path | tshark -r- -n --color; sleep 3000"
fi

sudo qemu-system-x86_64 "${opts[@]}"

# TODO: Allow adding/overriding the options.
