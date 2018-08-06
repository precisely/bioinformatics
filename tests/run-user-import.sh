#!/usr/bin/env bash

set -e
set -o pipefail

readlinkf() { perl -MCwd -e 'print Cwd::abs_path glob shift' "$1"; }
basedir=$(dirname "$(readlinkf $0)")


### configuration
export S3_BUCKET_USER_UPLOAD=cv-precisely-user-upload
export S3_BUCKET_GENETICS_VCF=cv-precisely-genetics-vcf
export AWS_S3_ENDPOINT_URL=http://localhost:9000
export AWS_ACCESS_KEY_ID=access-key
export AWS_SECRET_ACCESS_KEY=secret-key


### helper
function awss3 {
    aws s3 --endpoint-url=${AWS_S3_ENDPOINT_URL} $*
}


### local AWS environment handling
minio_pid=
minio_workdir=

function minio_start {
    minio_workdir=$(date +"%Y-%m-%d.%H-%M-%S.%N")
    export MINIO_ACCESS_KEY=access-key
    export MINIO_SECRET_KEY=secret-key
    export MINIO_BROWSER=off
    /precisely/aws-local/minio server --config-dir /precisely/aws-local/conf/minio "${basedir}/${minio_workdir}" > /dev/null &
    minio_pid=$!
    sleep 1
    awss3 cp mb s3://${S3_BUCKET_USER_UPLOAD}
    awss3 mb s3://${S3_BUCKET_GENETICS_VCF}
}

function minio_stop {
    [[ ! -z ${minio_pid} ]] && kill ${minio_pid}
    [[ ! -z "${minio_workdir}" ]] && rm -rf "${minio_workdir}"
}

# guarantee cleanup (except kill -9, of course)
trap minio_stop EXIT


### test setup
#awss3 mb s3://test-precisely-user-upload
# ...


### run

# FIXME: Write tests for individual scripts.
# Don't forget to test for v36 genome failures.

#minio_start
eval \
    PARAM_USER_DATA_SOURCE=23andme \
    PARAM_USER_GENOME_UPLOAD_PATH=genome_Andrew_Beeler_Full_20160320135452.txt \
    PARAM_USER_ID=t3 \
    "${basedir}/../run-user-import.sh" true
#minio_stop

# assert some things...

# Try rerunning and make sure it does not upload again.
