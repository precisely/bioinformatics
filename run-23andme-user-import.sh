#!/usr/bin/env bash

set -e
set -o pipefail

readlinkf() { perl -MCwd -e 'print Cwd::abs_path glob shift' "$1"; }
basedir=$(dirname "$(readlinkf $0)")


### configuration
if [[ -z "${S3_BUCKET_USER_UPLOAD}" ]]; then
    echo "S3_BUCKET_USER_UPLOAD environment variable required" 1>&2
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
function avoid_dest_overwrite {
    local phase=$1
    if [[ ! -z $(aws s3 --endpoint-url "${AWS_S3_ENDPOINT_URL}" ls "s3://${S3_BUCKET_GENETICS_VCF}/${PARAM_SAMPLE_ID}") ]]; then
        echo "${PARAM_SAMPLE_ID} already exists in S3 (${phase})" 1>&2
        exit 1
    fi
}

# Do not do any expensive work if the destination path exists in S3.
avoid_dest_overwrite "check before conversion and imputation"

workdir="./$(date +"%Y-%m-%d.%H-%M-%S.%N")"
mkdir "${workdir}"
pushd "${workdir}" > /dev/null

mkdir "${PARAM_SAMPLE_ID}"
pushd "${PARAM_SAMPLE_ID}" > /dev/null

mkdir headers
mkdir imputed

aws s3 --endpoint-url "${AWS_S3_ENDPOINT_URL}" \
    cp "s3://${S3_BUCKET_USER_UPLOAD}/${PARAM_USER_23ANDME_GENOME_UPLOAD_PATH}" 23andme-raw.txt > /dev/null

"${basedir}/convert-23andme-to-vcf.sh" 23andme-raw.txt 23andme.vcf.gz ${PARAM_SAMPLE_ID} ${test_mode}
"${basedir}/extract-vcf-headers.sh" 23andme.vcf.gz > headers/23andme.txt

for chr in {1..23}; do
    imputed_filename="imputed/chr-${chr}.vcf.gz"
    "${basedir}/impute-genotype.sh" 23andme.vcf.gz "${imputed_filename}" ${chr} 3 ${test_mode}
    "${basedir}/extract-vcf-headers.sh" "${imputed_filename}" > "headers/imputed-${chr}.txt"
done

popd > /dev/null

# Once again, check that the destination does not exist in case another process raced this one.
avoid_dest_overwrite "check after imputation and before final copy into S3"

src_dir=$(readlinkf "${PARAM_SAMPLE_ID}")
aws s3 --endpoint-url "${AWS_S3_ENDPOINT_URL}" cp --recursive "${src_dir}" "s3://${S3_BUCKET_GENETICS_VCF}/${PARAM_SAMPLE_ID}" --exclude "23andme-raw.txt" > /dev/null

popd > /dev/null
