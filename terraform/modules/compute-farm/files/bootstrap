#!/usr/bin/env bash

# EBS scratch space configuration
device=/dev/xvdf
if [[ -e /dev/nvme0n1 ]]; then
    # Nitro instance: https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/nvme-ebs-volumes.html
    device=/dev/nvme0n1
fi
mkfs -t ext4 "$${device}"
mkdir -p /scratch
mount "$${device}" /scratch
chown ubuntu /scratch

# S3 remote mount
mkdir -p /data-s3
chown ubuntu /data-s3
su ubuntu -c "yas3fs s3://${data_s3_bucket}/ /data-s3 --region ${region} --topic ${data_sns_topic_arn} --new-queue"
