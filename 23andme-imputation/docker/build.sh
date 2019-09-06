#!/usr/bin/env bash

set -Eeo pipefail

readlinkf() { perl -MCwd -MFile::Glob -l -e 'print Cwd::abs_path File::Glob::bsd_glob shift' "$1"; }
basedir=$(dirname "$(readlinkf "$0")")
script=$(basename "${BASH_SOURCE[${#BASH_SOURCE[@]}-1]}")


### parameter handling
if [[ "$#" -eq 0 ]]; then
    echo "usage: docker-build.sh <mode> <image-tag> <aws-profile>" >&2
    exit 1
fi

mode="$1"
image_tag="$2"
aws_profile="$3"

if [[ "${mode}" != "link" && "${mode}" != "build" ]]; then
    echo "only 'link' and 'build' modes supported" >&2
    exit 1
fi

if [[ -z "${image_tag}" ]]; then
    echo "image tag required" >&2
    exit 1
fi

if [[ -z "${aws_profile}" ]]; then
    echo "AWS profile required (see ~/.aws/credentials)" >&2
    exit 1
fi

aws_access_key_id=$(aws --profile=${aws_profile} configure get aws_access_key_id)
aws_secret_access_key=$(aws --profile=${aws_profile} configure get aws_secret_access_key)

if [[ -z "${aws_access_key_id}" || -z "${aws_secret_access_key}" ]]; then
    echo "AWS profile not set up correctly" >&2
    exit 1
fi


### run
if [[ -z `docker images -q "${image_tag}"` ]]; then
    m4 -P -Dmode=${mode} "${basedir}/Dockerfile.m4" | \
        docker build "${basedir}/.." \
               --tag "${image_tag}" \
               --build-arg AWS_ACCESS_KEY_ID=${aws_access_key_id} \
               --build-arg AWS_SECRET_ACCESS_KEY=${aws_secret_access_key} \
               --file -
else
    echo "image ${image_tag} already exists, not building" >&2
fi
