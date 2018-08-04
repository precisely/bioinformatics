#!/usr/bin/env bash

set -e
set -o pipefail


### parameters
if [ "$#" -eq 0 ]; then
    echo "usage: docker-start.sh <container-name>" 1>&2
    exit 1
fi

container_name="$1"

if [[ -z "${container_name}" ]]; then
    echo "container name required" 1>&2
    exit 1
fi


### run
docker start "${container_name}"
