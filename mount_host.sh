#!/bin/bash

source gbash.sh || exit

DEFINE_dir --required name '' 'Host directory.'

gbash::init_google "$@"

# TODO: Move to common.sh
sector_size=512
partition_start_sectors=2048
partition_start_bytes="$(( $sector_size * $partition_start_sectors ))"
root_image="$FLAGS_name/root.img"
mount_dir="$FLAGS_name/mnt"

sudo mount "$root_image" "$mount_dir" -o offset="$partition_start_bytes"
