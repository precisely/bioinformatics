#!/usr/bin/env bash

set +e
set -o pipefail

readlinkf() { perl -MCwd -e 'print Cwd::abs_path glob shift' "$1"; }
basedir=$(dirname "$(readlinkf $0)")


### configuration
export S3_BUCKET_BIOINFORMATICS_UPLOAD=test-precisely-bioinformatics-upload
export S3_BUCKET_BIOINFORMATICS_VCF=test-precisely-bioinformatics-vcf
export AWS_REGION=us-east-1
export AWS_S3_ENDPOINT_URL=http://localhost:9000
export AWS_ACCESS_KEY_ID=access-key
export AWS_SECRET_ACCESS_KEY=secret-key
export STAGE=test


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
    awss3 mb s3://${S3_BUCKET_BIOINFORMATICS_UPLOAD}
    awss3 mb s3://${S3_BUCKET_BIOINFORMATICS_VCF}
    # v36 genotype
    cp /precisely/data/samples/genome_Joseph_Bedell_Full_20110113135135.txt "${minio_workdir}/${S3_BUCKET_BIOINFORMATICS_UPLOAD}/b76a6dae4094f31a59cee93a2a3aacf3d56bb32d0dcb4fa8bd9e24e4308b2348"
    # normal v37 genotype
    cp /precisely/data/samples/genome_Andrew_Beeler_Full_20160320135452.txt "${minio_workdir}/${S3_BUCKET_BIOINFORMATICS_UPLOAD}/a5cef5de111d61d4e8f57f0ab6166a1d8279cdc419f414383d8505efe74704f0"
}

function after {
    minio_stop
}


### run

function test_overall_functionality {
    say_test_name
    before
    local hash=a5cef5de111d61d4e8f57f0ab6166a1d8279cdc419f414383d8505efe74704f0
    eval \
        PARAM_DATA_SOURCE=23andme \
        PARAM_UPLOAD_PATH=${hash} \
        PARAM_USER_ID=test-user-1 \
        "${basedir}/../run-user-import.sh" --test-mock-vcf=true --test-mock-lambda=true --cleanup-after=true 1>&2
    [[ $? == 0 ]] || add_error "initial run failed"
    awss3 ls s3://${S3_BUCKET_BIOINFORMATICS_VCF}/test-user-1/23andme/${hash} || \
        add_error "did not create user directory at destination"
    awss3 ls s3://${S3_BUCKET_BIOINFORMATICS_VCF}/test-user-1/23andme/${hash}/raw.vcf.gz || \
        add_error "did not copy in raw converted VCF file"
    awss3 ls s3://${S3_BUCKET_BIOINFORMATICS_VCF}/test-user-1/23andme/${hash}/imputed/chr1.vcf.bgz || \
        add_error "did not copy in chromosome files"
    awss3 ls s3://${S3_BUCKET_BIOINFORMATICS_VCF}/test-user-1/23andme/${hash}/imputed/chr1.vcf.bgz.tbi || \
        add_error "did not copy in tabix index files"
    awss3 ls s3://${S3_BUCKET_BIOINFORMATICS_VCF}/test-user-1/23andme/${hash}/headers/23andme.txt || \
        add_error "did not copy in raw converted VCF file header"
    awss3 ls s3://${S3_BUCKET_BIOINFORMATICS_VCF}/test-user-1/23andme/${hash}/headers/imputed-chr1.txt || \
        add_error "did not copy in raw converted VCF file header"
    # Try rerunning and make sure it does not upload again.
    err=$(
        eval \
            PARAM_DATA_SOURCE=23andme \
            PARAM_UPLOAD_PATH=a5cef5de111d61d4e8f57f0ab6166a1d8279cdc419f414383d8505efe74704f0 \
            PARAM_USER_ID=test-user-1 \
            "${basedir}/../run-user-import.sh" --test-mock-vcf=true --test-mock-lambda=true --cleanup-after=true 2>&1)
    [[ $? != 0 ]] || add_error "second upload on same user ID succeeded"
    [[ "${err}" == "test-user-1 already exists in S3 (check before conversion and imputation)" ]] || add_error "error message on duplicate upload in run-user-import.sh not expected"
    after
}

function test_v36_rejection {
    say_test_name
    before
    local hash=b76a6dae4094f31a59cee93a2a3aacf3d56bb32d0dcb4fa8bd9e24e4308b2348
    err=$(
        eval \
            PARAM_DATA_SOURCE=23andme \
            PARAM_UPLOAD_PATH=${hash} \
            PARAM_USER_ID=test-user-1 \
            "${basedir}/../run-user-import.sh" --test-mock-vcf=true --test-mock-lambda=true --cleanup-after=true 2>&1)
    [[ $? != 0 ]] || add_error "accepted v36 genotype instead of rejecting"
    [[ "${err}" == "unsupported genome version" ]] || add_error "error message on genome version in run-user-import.sh not expected"
    after
}

test_overall_functionality
test_v36_rejection

report
