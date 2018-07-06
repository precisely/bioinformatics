#!/usr/bin/env bash

if [ "$#" -eq 0 ]; then
    echo "usage: docker-create.sh <mode> <image-tag> <container-name> <app-source-path>" 1>&2
    exit 1
fi

mode="$1"
image_tag="$2"
container_name="$3"
app_source_path="$4"

if [[ "${mode}" != "link" && "${mode}" != "build" ]]; then
    echo "only 'link' and 'build' modes supported" 1>&2
    exit 1
fi

if [[ -z "${image_tag}" ]]; then
    echo "image tag required" 1>&2
    exit 1
fi

if [[ -z "${container_name}" ]]; then
    echo "container name required" 1>&2
    exit 1
fi

if [[ "${mode}" == "link" && -z "${app_source_path}" ]]; then
    echo "app source path required in link mode" 1>&2
    exit 1
fi
app_source_path=$(realpath "${app_source_path}")

if [[ "${mode}" == "link" ]]; then
    docker create -i -t --name "${container_name}" \
           --net=host \
           --volume "${app_source_path}":/precisely/app \
           "${image_tag}"
else
    docker create -i -t --name "${container_name}" \
           --net=host \
           "${image_tag}"
fi
