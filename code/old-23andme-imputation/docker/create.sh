#!/usr/bin/env bash

set -Eeo pipefail

readlinkf() { perl -MCwd -MFile::Glob -l -e 'print Cwd::abs_path File::Glob::bsd_glob shift' "$1"; }
basedir=$(dirname "$(readlinkf "$0")")
script=$(basename "${BASH_SOURCE[${#BASH_SOURCE[@]}-1]}")


### parameters
if [[ "$#" -eq 0 ]]; then
    echo "usage: docker-create.sh <mode> <image-tag> <container-name> <app-source-path>" >&2
    exit 1
fi

mode="$1"
image_tag="$2"
container_name="$3"
app_source_path="$4"

if [[ "${mode}" != "link" && "${mode}" != "build" ]]; then
    echo "only 'link' and 'build' modes supported" >&2
    exit 1
fi

if [[ -z "${image_tag}" ]]; then
    echo "image tag required" >&2
    exit 1
fi

if [[ -z "${container_name}" ]]; then
    echo "container name required" >&2
    exit 1
fi

if [[ "${mode}" == "link" ]]; then
    if [[ -z "${app_source_path}" ]]; then
        echo "app source path required in link mode" >&2
        exit 1
    else
        app_source_path=$(readlinkf "${app_source_path}")
    fi
fi


### run
if [[ "${mode}" == "link" ]]; then
    docker create -i -t --name "${container_name}" \
           --net=host \
           --hostname "${container_name}" \
           --add-host "${container_name}:127.0.0.1" \
           --volume "${app_source_path}":/precisely/app \
           "${image_tag}"
else
    docker create -i -t --name "${container_name}" \
           --net=host \
           --hostname "${container_name}" \
           --add-host "${container_name}:127.0.0.1" \
           "${image_tag}"
fi
