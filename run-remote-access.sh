#!/usr/bin/env bash

set -Eeo pipefail

readlinkf() { perl -MCwd -e 'print Cwd::abs_path glob shift' "$1"; }
basedir=$(dirname "$(readlinkf $0)")
script=$(basename "${BASH_SOURCE[${#BASH_SOURCE[@]}-1]}")


. "${basedir}/common.sh"


### configuration
sleep_interval_sec=600
keep_running_file=${basedir}/KEEP-RUNNING


### run
info "starting ssh"
with_output_to_log sudo /etc/init.d/ssh start

info "initial sleep interval: ${sleep_interval_sec}sec"
info "create (touch) ${keep_running_file} to keep this script running (and its container alive)"
sleep ${sleep_interval_sec}

while [[ -f "${keep_running_file}" ]]; do
    info "${keep_running_file} found, sleeping for another ${sleep_interval_sec}sec"
    sleep ${sleep_interval_sec}
done
