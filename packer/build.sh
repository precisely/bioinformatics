#!/usr/bin/env bash


set -Eeuo pipefail

readlinkf() { perl -MCwd -MFile::Glob -l -e 'print Cwd::abs_path File::Glob::bsd_glob shift' "$1"; }
basedir=$(dirname "$(readlinkf "$0")")
script=$(basename "${BASH_SOURCE[${#BASH_SOURCE[@]}-1]}")


### parameter handling
if [[ "$#" -eq 0 ]]; then
    echo "usage: build.sh <packer-file>" 1>&2
    exit 1
fi

packer_file="$1"

if [[ -z "${packer_file}" ]]; then
    echo "packer file required" 1>&2
    exit 1
fi


### run
packer build "${packer_file}"

# FIXME:
#aws ec2 copy-image --source-image-id ami-5731123e --source-region us-east-1 --region ap-northeast-1 --name "My server"
