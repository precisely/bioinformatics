#!/usr/bin/env bash

set +e
set -o pipefail

readlinkf() { perl -MCwd -e 'print Cwd::abs_path glob shift' "$1"; }
basedir=$(dirname "$(readlinkf $0)")


### configuration
export S3_BUCKET_USER_UPLOAD=test-precisely-user-upload
export S3_BUCKET_GENETICS_VCF=test-precisely-genetics-vcf
export AWS_S3_ENDPOINT_URL=http://localhost:9000
export AWS_ACCESS_KEY_ID=access-key
export AWS_SECRET_ACCESS_KEY=secret-key


### helper
function awss3 {
    aws s3 --endpoint-url=${AWS_S3_ENDPOINT_URL} $* > /dev/null
}


### local AWS environment handling
minio_pid=
minio_workdir=

function minio_start {
    minio_workdir=${basedir}/$(date +"%Y-%m-%d.%H-%M-%S.%N")
    export MINIO_ACCESS_KEY=access-key
    export MINIO_SECRET_KEY=secret-key
    export MINIO_BROWSER=off
    /precisely/aws-local/minio server --config-dir /precisely/aws-local/conf/minio "${minio_workdir}" > /dev/null &
    minio_pid=$!
}

function minio_stop {
    [[ ! -z ${minio_pid} ]] && kill ${minio_pid}
    [[ ! -z "${minio_workdir}" ]] && rm -rf "${minio_workdir}"
}


### cleanup
trap minio_stop EXIT


### output helpers
function say {
    printf " ---> $1\n" 1>&2
}

function say_test_name {
    say "running test: ${FUNCNAME[1]}"
}


### test helpers
errors=0
function add_error {
    local err=$1
    if [[ -z "${err}" ]]; then
        err=${FUNCNAME[1]}
    else
        err="${FUNCNAME[1]}: ${err}"
    fi
    say "error: ${err}"
    ((errors++))
}

function report {
    if [[ ${errors} == 0 ]]; then
        say "success"
        exit 0
    else
        say "failures: ${errors}"
        exit 1
    fi
}

function before {
    minio_start
    awss3 mb s3://${S3_BUCKET_USER_UPLOAD}
    awss3 mb s3://${S3_BUCKET_GENETICS_VCF}
    # normal v37 genotype
    cp /precisely/data/samples/genome_Joseph_Bedell_Full_20110113135135.txt "${minio_workdir}/${S3_BUCKET_USER_UPLOAD}/b76a6dae4094f31a59cee93a2a3aacf3d56bb32d0dcb4fa8bd9e24e4308b2348"
    # v36 genotype
    cp /precisely/data/samples/genome_Andrew_Beeler_Full_20160320135452.txt "${minio_workdir}/${S3_BUCKET_USER_UPLOAD}/a5cef5de111d61d4e8f57f0ab6166a1d8279cdc419f414383d8505efe74704f0"
}

function after {
    minio_stop
}


### run

# FIXME: Write tests for individual scripts.

function test_overall_functionality {
    say_test_name
    before
    eval \
        PARAM_USER_DATA_SOURCE=23andme \
        PARAM_USER_GENOME_UPLOAD_PATH=a5cef5de111d61d4e8f57f0ab6166a1d8279cdc419f414383d8505efe74704f0 \
        PARAM_USER_ID=test-user-1 \
        "${basedir}/../run-user-import.sh" true true
    [[ $? == 0 ]] || add_error "initial run failed"
    # FIXME: assert some things...
    # Try rerunning and make sure it does not upload again.
    eval \
        PARAM_USER_DATA_SOURCE=23andme \
        PARAM_USER_GENOME_UPLOAD_PATH=a5cef5de111d61d4e8f57f0ab6166a1d8279cdc419f414383d8505efe74704f0 \
        PARAM_USER_ID=test-user-1 \
        "${basedir}/../run-user-import.sh" true true
    [[ $? != 0 ]] || add_error "second upload on same user ID succeeded"
    after
}

function test_v36_rejection {
    say_test_name
    before
    eval \
        PARAM_USER_DATA_SOURCE=23andme \
        PARAM_USER_GENOME_UPLOAD_PATH=b76a6dae4094f31a59cee93a2a3aacf3d56bb32d0dcb4fa8bd9e24e4308b2348 \
        PARAM_USER_ID=test-user-1 \
        "${basedir}/../run-user-import.sh" true true
    [[ $? != 0 ]] || add_error "accepted v36 genotype instead of rejecting"
    after
}

test_overall_functionality
test_v36_rejection

report
