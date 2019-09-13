#!/usr/bin/env bash

# EBS scratch space configuration
mkfs -t ext4 /dev/xvdf
mkdir -p /scratch
mount /dev/xvdf /scratch
chown ubuntu /scratch

# S3 remote mount
mkdir -p /data-s3
chown ubuntu /data-s3
su ubuntu -c "yas3fs s3://${data_s3_bucket}/ /data-s3 --region ${region} --topic ${data_sns_topic_arn} --new-queue"
