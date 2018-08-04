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


### start local AWS environment
# ...


# aws s3 --endpoint-url ${AWS_S3_ENDPOINT_URL} mb s3://test-precisely-user-upload


### run
eval \
    PARAM_USER_23ANDME_GENOME_UPLOAD_PATH=genome_Andrew_Beeler_Full_20160320135452.txt \
    PARAM_SAMPLE_ID=abeeler \
    "${basedir}/../run-23andme-user-import.sh" true
