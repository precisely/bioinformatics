#!/usr/bin/env bash

set -Eeo pipefail

readlinkf() { perl -MCwd -e 'print Cwd::abs_path glob shift' "$1"; }
basedir=$(dirname "$(readlinkf $0)")
script=$(basename "${BASH_SOURCE[${#BASH_SOURCE[@]}-1]}")


. "${basedir}/common.sh"


### configuration
if [[ -z "${AWS_REGION}" ]]; then
    echo "AWS_REGION environment variable required" >&2
    exit 1
fi

if [[ -z "${AWS_S3_ENDPOINT_URL}" ]]; then
    echo "AWS_S3_ENDPOINT_URL environment variable required" >&2
    exit 1
fi


### parameters
! getopt --test > /dev/null
if [[ ${PIPESTATUS[0]} -ne 4 ]]; then
    echo "enhanced getopt not available" >&2
    exit 1
fi
! PARSED=$(getopt --options="h" --longoptions="bucket-keys:,cleanup-after:,help" --name "$0" -- "$@")
if [[ ${PIPESTATUS[0]} -ne 0 ]]; then
    exit 1
fi
eval set -- "$PARSED"
while true; do
    case "$1" in
        --bucket-keys)
            param_bucket_keys="$2"
            shift 2
            ;;
        --cleanup-after)
            param_cleanup_after="$2"
            shift 2
            ;;
        -h|--help)
            echo "usage: ssh-copy-public-keys.sh --bucket-keys=..."
            exit 0
            ;;
        --)
            shift
            break
            ;;
        *)
            echo "something's wrong" >&2
            exit 1
            ;;
    esac
done

[[ -z "${param_bucket_keys}" ]] && param_data_source="${S3_BUCKET_KEYS}"

if [[ -z "${param_bucket_keys}" ]]; then
    echo "S3 bucket containing public keys to copy in must be set with PARAM_BUCKET_KEYS or --bucket-keys" >&2
    exit 1
fi

if [[ -z "${param_cleanup_after}" || ("${param_cleanup_after}" != "true" && "${param_cleanup_after}" != "false") ]]; then
    param_cleanup_after=true
fi

bucket_keys="${param_bucket_keys}"
cleanup_after="${param_cleanup_after}"


### cleanup
function cleanup {
    if [[ "${cleanup_after}" == "true" && ! -z "${workdir}" ]]; then
        debug "clean up: removing '${workdir}'"
        [[ ! -z "${workdir}" ]] && rm -rf "${workdir}"
    fi
}

trap cleanup EXIT


### run
info $(json_pairs bucket_keys "${bucket_keys}")

workdir="${basedir}/$(timestamp)"
mkdir "${workdir}"

sshdir="${HOME}/.ssh"
if [[ ! -d "${sshdir}" ]]; then
    mkdir -p "${sshdir}"
    chmod 700 "${sshdir}"
fi

pushd "${workdir}" > /dev/null

aws s3 --endpoint-url="${AWS_S3_ENDPOINT_URL}" cp --recursive "s3://${bucket_keys}/${user_id}" . > /dev/null

for f in *; do
    (cat "${f}"; echo '') >> "${sshdir}/authorized_keys"
done
