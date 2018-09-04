#!/usr/bin/env bash

set -Euo pipefail

readlinkf() { perl -MCwd -e 'print Cwd::abs_path glob shift' "$1"; }
basedir=$(dirname "$(readlinkf $0)")
script=$(basename "${BASH_SOURCE[${#BASH_SOURCE[@]}-1]}")


. "${basedir}/common-tests.sh"


### configuration
export S3_BUCKET_BIOINFORMATICS_UPLOAD=test-precisely-bioinformatics-upload
export S3_BUCKET_BIOINFORMATICS_VCF=test-precisely-bioinformatics-vcf
export AWS_REGION=us-east-1
export AWS_S3_ENDPOINT_URL=http://localhost:9000
export AWS_ACCESS_KEY_ID=access-key
export AWS_SECRET_ACCESS_KEY=secret-key


### helpers
function before {
    minio_start
    awss3 mb s3://${S3_BUCKET_BIOINFORMATICS_UPLOAD}
    awss3 mb s3://${S3_BUCKET_BIOINFORMATICS_VCF}
    # v36 genotype
    cp /precisely/data/samples/23andme/genome_v36_Joseph_Bedell_Full_20110113135135.txt "${minio_workdir}/${S3_BUCKET_BIOINFORMATICS_UPLOAD}/b76a6dae4094f31a59cee93a2a3aacf3d56bb32d0dcb4fa8bd9e24e4308b2348"
    # normal v37 genotype
    cp /precisely/data/samples/23andme/genome_v37_Andrew_Beeler_Full_20160320135452.txt "${minio_workdir}/${S3_BUCKET_BIOINFORMATICS_UPLOAD}/a5cef5de111d61d4e8f57f0ab6166a1d8279cdc419f414383d8505efe74704f0"
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
        "${basedir}/../run-user-import.sh" --stage=test --test-mock-vcf=true --test-mock-lambda=true --cleanup-after=true 2>&1 >/dev/null
    [[ $? == 0 ]] || add_error "initial run failed"
    awss3 ls s3://${S3_BUCKET_BIOINFORMATICS_VCF}/test-user-1/23andme/${hash} || \
        add_error "did not create user directory at destination"
    awss3 ls s3://${S3_BUCKET_BIOINFORMATICS_VCF}/test-user-1/23andme/${hash}/raw.vcf.gz || \
        add_error "did not copy in raw converted VCF file"
    awss3 ls s3://${S3_BUCKET_BIOINFORMATICS_VCF}/test-user-1/23andme/${hash}/imputed/chr1.vcf.bgz || \
        add_error "did not copy in chromosome files"
    awss3 ls s3://${S3_BUCKET_BIOINFORMATICS_VCF}/test-user-1/23andme/${hash}/imputed/chr1.vcf.bgz.tbi || \
        add_error "did not copy in tabix index files"
    # Try rerunning and make sure it does not upload again.
    local err # must assign separately to preserve $? value
    err=$(
        eval \
            PARAM_DATA_SOURCE=23andme \
            PARAM_UPLOAD_PATH=a5cef5de111d61d4e8f57f0ab6166a1d8279cdc419f414383d8505efe74704f0 \
            PARAM_USER_ID=test-user-1 \
            "${basedir}/../run-user-import.sh" --stage=test --test-mock-vcf=true --test-mock-lambda=true --cleanup-after=true 2>&1 >/dev/null)
    [[ $? != 0 ]] || add_error "second upload on same user ID succeeded"
    [[ "${err}" =~ "test-user-1 already exists in S3 (check before conversion and imputation)" ]] || add_error "error message on duplicate upload in run-user-import.sh not expected"
    after
}

function test_v36_rejection {
    say_test_name
    before
    local hash=b76a6dae4094f31a59cee93a2a3aacf3d56bb32d0dcb4fa8bd9e24e4308b2348
    local err # must assign separately to preserve $? value
    err=$(
        eval \
            PARAM_DATA_SOURCE=23andme \
            PARAM_UPLOAD_PATH=${hash} \
            PARAM_USER_ID=test-user-1 \
            "${basedir}/../run-user-import.sh" --stage=test --test-mock-vcf=true --test-mock-lambda=true --cleanup-after=true 2>&1 >/dev/null)
    [[ $? != 0 ]] || add_error "accepted v36 genotype instead of rejecting"
    [[ "${err}" =~ "unsupported genome version" ]] || add_error "error message on genome version in run-user-import.sh not expected"
    after
}

test_overall_functionality
test_v36_rejection

report
