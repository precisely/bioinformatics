#!/usr/bin/env bash


set -Eeuo pipefail

readlinkf() { perl -MCwd -MFile::Glob -l -e 'print Cwd::abs_path File::Glob::bsd_glob shift' "$1"; }
basedir=$(dirname "$(readlinkf "$0")")
script=$(basename "${BASH_SOURCE[${#BASH_SOURCE[@]}-1]}")


### parameter handling
if [[ "$#" -eq 0 ]]; then
    echo "usage: copy-ami.sh <source-region> <source-ami>" 1>&2
    exit 1
fi

source_region="$1"
source_ami="$2"

if [[ -z "${source_region}" ]]; then
    echo "source region required" 1>&2
    exit 1
fi

if [[ -z "${source_ami}" ]]; then
    echo "source ami required" 1>&2
    exit 1
fi


### run
# FIXME:
# - determine the exact AMI name (not ID) in the source region
#aws ec2 copy-image --source-region ${source_region} --source-image-id ${source_ami} --region ap-northeast-1 --name "precisely-cf-FIXME"
