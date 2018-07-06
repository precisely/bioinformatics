#!/usr/bin/env bash

if [ "$#" -eq 0 ]; then
    echo "usage: docker-build.sh <mode> <image-tag> <aws-profile>" 1>&2
    exit 1
fi

mode="$1"
image_tag="$2"
aws_profile="$3"

if [[ "${mode}" != "link" && "${mode}" != "build" ]]; then
    echo "only 'link' and 'build' modes supported" 1>&2
    exit 1
fi

if [[ -z "${image_tag}" ]]; then
    echo "image tag required" 1>&2
    exit 1
fi

if [[ -z "${aws_profile}" ]]; then
    echo "AWS profile required (see ~/.aws/credentials)" 1>&2
    exit 1
fi

aws_access_key_id=$(aws --profile=${aws_profile} configure get aws_access_key_id)
aws_secret_access_key=$(aws --profile=${aws_profile} configure get aws_secret_access_key)

if [[ -z "${aws_access_key_id}" || -z "${aws_secret_access_key}" ]]; then
    echo "AWS profile not set up correctly" 1>&2
    exit 1
fi

basedir=$(dirname $(greadlink -f $0))
pushd $basedir > /dev/null

if [[ -z `docker images -q "${image_tag}"` ]]; then
    m4 -P -Dmode=${mode} Dockerfile.m4 | \
        docker build . \
               --tag "${image_tag}" \
               --build-arg aws_access_key_id=${aws_access_key_id} \
               --build-arg aws_secret_access_key=${aws_secret_access_key} \
               --file -
fi

popd > /dev/null
