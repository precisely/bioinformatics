#!/usr/bin/env bash

set -Eeo pipefail

readlinkf() { perl -MCwd -MFile::Glob -l -e 'print Cwd::abs_path File::Glob::bsd_glob shift' "$1"; }
basedir=$(dirname "$(readlinkf "$0")")
script=$(basename "${BASH_SOURCE[${#BASH_SOURCE[@]}-1]}")


. "${basedir}/common.sh"


### configuration
sleep_interval_sec=600
keep_running_file=${basedir}/KEEP-RUNNING


### parameters
! getopt --test > /dev/null
if [[ ${PIPESTATUS[0]} -ne 4 ]]; then
    echo "enhanced getopt not available" >&2
    exit 1
fi
! PARSED=$(getopt --options="h" --longoptions="keep-running:,help" --name "$0" -- "$@")
if [[ ${PIPESTATUS[0]} -ne 0 ]]; then
    exit 1
fi
eval set -- "$PARSED"
while true; do
    case "$1" in
        --keep-running)
            param_keep_running="$2"
            shift 2
            ;;
        -h|--help)
            echo "usage: run-remote-access.sh --keep-running=..."
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

if [[ -z "${param_keep_running}" ]]; then
    param_keep_running=false
fi

keep_running="${param_keep_running}"


### run
# XXX: Work around a sudo error which occurs when the hostname does not resolve
# to anything in /etc/hosts.
sudo bash -c 'echo $(hostname -I | cut -d\  -f1) $(hostname) >> /etc/hosts' 1>&2 2>/dev/null

info "saving credentials environment variable AWS_CONTAINER_CREDENTIALS_RELATIVE_URI"
echo "export AWS_CONTAINER_CREDENTIALS_RELATIVE_URI=$AWS_CONTAINER_CREDENTIALS_RELATIVE_URI" >> /home/docker/.bashrc

set +e
info "setting bash prompt to include IAM role"
iam_role=$(curl -s 169.254.170.2$AWS_CONTAINER_CREDENTIALS_RELATIVE_URI | jq -r '.RoleArn' | awk -F ":" '{print $6}')
echo "export PS1=\"\[\e[1;91m\]${iam_role}\[\e[0m\] \$PS1\"" >> /home/docker/.bashrc
set -e

info "starting ssh"
with_output_to_log sudo /etc/init.d/ssh start

info "copying in public keys"
with_output_to_log "${basedir}/ssh-copy-public-keys.sh" --bucket-keys=precisely-ssh-public-keys

if [[ "${keep_running}" == "true" ]]; then

    info "initial sleep interval: ${sleep_interval_sec}sec"
    info "create (touch) ${keep_running_file} to keep this script running (and its container alive)"
    sleep ${sleep_interval_sec}

    while [[ -f "${keep_running_file}" ]]; do
        info "${keep_running_file} found, sleeping for another ${sleep_interval_sec}sec"
        sleep ${sleep_interval_sec}
    done

    info "all sleep intervals concluded and ${keep_running_file} not found; terminating remote access script"

fi
