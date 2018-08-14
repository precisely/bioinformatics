#!/usr/bin/env bash

set -e
set -o pipefail

readlinkf() { perl -MCwd -e 'print Cwd::abs_path glob shift' "$1"; }
basedir=$(dirname "$(readlinkf $0)")


### configuration
if [[ -z "${AWS_S3_ENDPOINT_URL}" ]]; then
    echo "AWS_S3_ENDPOINT_URL environment variable required" 1>&2
    exit 1
fi

if [[ -z "${S3_BUCKET_BIOINFORMATICS_UPLOAD}" ]]; then
    echo "S3_BUCKET_BIOINFORMATICS_UPLOAD environment variable required" 1>&2
    exit 1
fi

if [[ -z "${S3_BUCKET_BIOINFORMATICS_VCF}" ]]; then
    echo "S3_BUCKET_BIOINFORMATICS_VCF environment variable required" 1>&2
    exit 1
fi

# TODO: Figure out what to do with this.
# if [[ -z "${S3_BUCKET_BIOINFORMATICS_ERROR}" ]]; then
#     echo "S3_BUCKET_BIOINFORMATICS_ERROR environment variable required" 1>&2
#     exit 1
# fi


### parameters
if [[ "$#" -eq 0 ]]; then
    echo "usage: run-user-import.sh <test-mode> <cleanup-run>" 1>&2
    exit 1
fi

test_mode="$1"
cleanup_run="$2"

if [[ -z "${test_mode}" ]]; then
    echo "test-mode parameter required (true or false)" 1>&2
    exit 1
fi

if [[ -z "${cleanup_run}" ]]; then
    echo "cleanup-run parameter required (true or false)" 1>&2
    exit 1
fi

if [[ -z "${PARAM_USER_DATA_SOURCE}" ]]; then
    echo "PARAM_USER_DATA_SOURCE environment variable required" 1>&2
    exit 1
fi

if [[ "${PARAM_USER_DATA_SOURCE}" != "23andme" ]]; then
    echo "only 23andme supported at the moment" 1>&2
    exit 1
fi

if [[ -z "${PARAM_USER_GENOME_UPLOAD_PATH}" ]]; then
    echo "PARAM_USER_GENOME_UPLOAD_PATH environment variable required" 1>&2
    exit 1
fi

if [[ -z "${PARAM_USER_ID}" ]]; then
    echo "PARAM_USER_ID environment variable required" 1>&2
    exit 1
fi


### cleanup
function cleanup {
    if [[ "${cleanup_run}" == "true" ]]; then
        [[ ! -z "${workdir}" ]] && rm -rf "${workdir}"
    fi
}

trap cleanup EXIT


### run
function avoid_dest_overwrite {
    local phase=$1
    if [[ ! -z $(aws s3 --endpoint-url "${AWS_S3_ENDPOINT_URL}" ls "s3://${S3_BUCKET_BIOINFORMATICS_VCF}/${PARAM_USER_ID}") ]]; then
        echo "${PARAM_USER_ID} already exists in S3 (${phase})" 1>&2
        exit 1
    fi
}

# Do not do any expensive work if the destination path exists in S3.
avoid_dest_overwrite "check before conversion and imputation"

workdir="${basedir}/$(date +"%Y-%m-%d.%H-%M-%S.%N")"
mkdir "${workdir}"
pushd "${workdir}" > /dev/null

mkdir "${PARAM_USER_ID}"
pushd "${PARAM_USER_ID}" > /dev/null

mkdir "${PARAM_USER_DATA_SOURCE}"
pushd "${PARAM_USER_DATA_SOURCE}" > /dev/null

input_file=${PARAM_USER_DATA_SOURCE}-raw.txt

aws s3 --endpoint-url "${AWS_S3_ENDPOINT_URL}" \
    cp "s3://${S3_BUCKET_BIOINFORMATICS_UPLOAD}/${PARAM_USER_GENOME_UPLOAD_PATH}" "${input_file}" > /dev/null

sha256sum=$(sha256sum "${input_file}" | awk '{print $1}')
mkdir "${sha256sum}"
pushd "${sha256sum}" > /dev/null
mv "../${input_file}" .

mkdir headers
mkdir imputed

"${basedir}/convert-${PARAM_USER_DATA_SOURCE}-to-vcf.sh" "${input_file}" raw.vcf.gz ${test_mode}

"${basedir}/extract-vcf-headers.sh" raw.vcf.gz > "headers/${PARAM_USER_DATA_SOURCE}.txt"

# TODO: How many cores for imputation?
num_cores=3
for chr in {1..22} X Y MT; do
    imputed_filename="imputed/chr${chr}.vcf.gz"
    "${basedir}/impute-genotype.sh" raw.vcf.gz "${imputed_filename}" ${chr} ${num_cores} ${test_mode}
    "${basedir}/extract-vcf-headers.sh" "${imputed_filename}" > "headers/imputed-chr${chr}.txt"
done

popd > /dev/null
popd > /dev/null
popd > /dev/null

# Once again, check that the destination does not exist in case another process raced this one.
avoid_dest_overwrite "check after imputation and before final copy into S3"

src_dir=$(readlinkf "${PARAM_USER_ID}")
aws s3 --endpoint-url "${AWS_S3_ENDPOINT_URL}" cp --recursive "${src_dir}" "s3://${S3_BUCKET_BIOINFORMATICS_VCF}/${PARAM_USER_ID}" --exclude "**/${input_file}" > /dev/null

popd > /dev/null
