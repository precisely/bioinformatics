#!/usr/bin/env bash

set -e
set -o pipefail

readlinkf() { perl -MCwd -e 'print Cwd::abs_path glob shift' "$1"; }
basedir=$(dirname "$(readlinkf $0)")


### configuration
if [[ -z "${S3_BUCKET_USER_UPLOAD}" ]]; then
    echo "" 1>&2
    exit 1
fi

if [[ -z "${S3_BUCKET_GENETICS_VCF}" ]]; then
    echo "S3_BUCKET_GENETICS_VCF environment variable required" 1>&2
    exit 1
fi

# TODO: Figure out what to do with this.
# if [[ -z "${S3_BUCKET_INGESTION_ERROR}" ]]; then
#     echo "S3_BUCKET_INGESTION_ERROR environment variable required" 1>&2
#     exit 1
# fi

if [[ -z "${AWS_S3_ENDPOINT_URL}" ]]; then
    echo "AWS_S3_ENDPOINT_URL environment variable required" 1>&2
    exit 1
fi


### parameters
test_mode="$1"

if [[ -z "${test_mode}" ]]; then
    test_mode=false
fi

if [[ -z "${PARAM_USER_23ANDME_GENOME_UPLOAD_PATH}" ]]; then
    echo "PARAM_USER_23ANDME_GENOME_UPLOAD_PATH environment variable required" 1>&2
    exit 1
fi

if [[ -z "${PARAM_SAMPLE_ID}" ]]; then
    echo "SAMPLE_ID environment variable required" 1>&2
    exit 1
fi


### run
workdir="./$(date +"%Y-%m-%d.%H-%M-%S.%N")"
mkdir "${workdir}"
pushd "${workdir}" > /dev/null

mkdir headers
mkdir imputed
aws s3 --endpoint-url "${AWS_S3_ENDPOINT_URL}" \
    cp "s3://${S3_BUCKET_USER_UPLOAD}/${PARAM_USER_23ANDME_GENOME_UPLOAD_PATH}" 23andme-raw.txt
"${basedir}/convert-23andme-to-vcf.sh" 23andme-raw.txt 23andme.vcf.gz ${PARAM_SAMPLE_ID} ${test_mode}
"${basedir}/extract-vcf-headers.sh" 23andme.vcf.gz > headers/23andme.txt
for chr in {1..23}; do
    local imputed_filename="imputed/chr-${chr}.vcf.gz"
    "${basedir}/impute-genotype.sh" 23andme.vcf.gz "${imputed_filename}" ${chr} 3 ${test_mode}
    "${basedir}/extract-vcf-headers.sh" "${imputed_filename}" > "headers/imputed-${chr}.txt"
done
aws s3 --endpoint-url "${AWS_S3_ENDPOINT_URL}" sync . "${S3_BUCKET_GENETICS_VCF}/${PARAM_SAMPLE_ID}"

popd > /dev/null
