#!/usr/bin/env bash

mkfs -t ext4 /dev/xvdf
mkdir -p /scratch
mount /dev/xvdf /scratch
chown ubuntu /scratch
