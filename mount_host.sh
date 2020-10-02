#!/bin/bash

source gbash.sh || exit

DEFINE_file --required image '' 'Host image to start.'

gbash::init_google "$@"

# TODO: Move to common.sh
sector_size=512
partition_start_sectors=2048
partition_start_bytes="$(( $sector_size * $partition_start_sectors ))"
mount_dir="${FLAGS_image%.img}_mnt"

sudo mount "$FLAGS_image" "$mount_dir" -o offset="$partition_start_bytes"
