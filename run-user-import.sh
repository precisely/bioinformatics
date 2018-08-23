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
! getopt --test > /dev/null
if [[ ${PIPESTATUS[0]} -ne 4 ]]; then
    echo "enhanced getopt not available" 1>&2
    exit 1
fi
! PARSED=$(getopt --options="h" --longoptions="data-source:,upload-path:,user-id:,stage:,test-mock-vcf:,test-mock-lambda:,cleanup-after:,help" --name "$0" -- "$@")
if [[ ${PIPESTATUS[0]} -ne 0 ]]; then
    exit 1
fi
eval set -- "$PARSED"
while true; do
    case "$1" in
        --data-source)
            param_data_source="$2"
            shift 2
            ;;
        --upload-path)
            param_upload_path="$2"
            shift 2
            ;;
        --user-id)
            param_user_id="$2"
            shift 2
            ;;
        --stage)
            param_stage="$2"
            shift 2
            ;;
        --test-mock-vcf)
            param_test_mock_vcf="$2"
            shift 2
            ;;
        --test-mock-lambda)
            param_test_mock_lambda="$2"
            shift 2
            ;;
        --cleanup-after)
            param_cleanup_after="$2"
            shift 2
            ;;
        -h|--help)
            echo "usage: run-user-import.sh --data-source=... --upload-path=... --user-id=... --stage=... --test-mock-vcf=... --test-mock-lambda=... --cleanup-after=..."
            exit 0
            ;;
        --)
            shift
            break
            ;;
        *)
            echo "something's wrong" 1>&2
            exit 1
            ;;
    esac
done

[[ -z "${param_data_source}" ]] && param_data_source="${PARAM_DATA_SOURCE}"
[[ -z "${param_upload_path}" ]] && param_upload_path="${PARAM_UPLOAD_PATH}"
[[ -z "${param_user_id}" ]] && param_user_id="${PARAM_USER_ID}"
[[ -z "${param_stage}" ]] && param_stage="${PARAM_STAGE}"

if [[ -z "${param_data_source}" ]]; then
    echo "data source must be set with PARAM_DATA_SOURCE or --data-source" 1>&2
    exit 1
fi

if [[ "${param_data_source}" != "23andme" ]]; then
    echo "only 23andme supported at the moment" 1>&2
    exit 1
fi

if [[ -z "${param_upload_path}" ]]; then
    echo "upload path must be set with PARAM_UPLOAD_PATH or --upload-path" 1>&2
    exit 1
fi

if [[ -z "${param_user_id}" ]]; then
    echo "user ID must be set with PARAM_USER_ID environment variable or --user-id" 1>&2
    exit 1
fi

if [[ -z "${param_stage}" ]]; then
    echo "stage must be set with PARAM_STAGE environment variable or --stage" 1>&2
    exit 1
fi

if [[ -z "${param_test_mock_vcf}" || ("${param_test_mock_vcf}" != "true" && "${param_test_mock_vcf}" != "false") ]]; then
    echo "test mode for mock VCF use must be set with --test-mock-vcf and must be 'true' or 'false'" 1>&2
    exit 1
fi

if [[ -z "${param_test_mock_lambda}" || ("${param_test_mock_lambda}" != "true" && "${param_test_mock_lambda}" != "false") ]]; then
    echo "test mode for mock AWS Lambda use must be set with --test-mock-lambda and must be 'true' or 'false'" 1>&2
    exit 1
fi

if [[ -z "${param_cleanup_after}" || ("${param_cleanup_after}" != "true" && "${param_cleanup_after}" != "false") ]]; then
    echo "cleanup must be set with --cleanup-after and must be true or false" 1>&2
    exit 1
fi

data_source="${param_data_source}"
upload_path="${param_upload_path}"
user_id="${param_user_id}"
stage="${param_stage}"
test_mock_vcf="${param_test_mock_vcf}"
test_mock_lambda="${param_test_mock_lambda}"
cleanup_after="${param_cleanup_after}"


### cleanup
function cleanup {
    if [[ "${cleanup_after}" == "true" ]]; then
        [[ ! -z "${workdir}" ]] && rm -rf "${workdir}"
    fi
}

trap cleanup EXIT


### run
function avoid_dest_overwrite {
    local phase=$1
    if [[ ! -z $(aws s3 --endpoint-url "${AWS_S3_ENDPOINT_URL}" ls "s3://${S3_BUCKET_BIOINFORMATICS_VCF}/${user_id}") ]]; then
        echo "${user_id} already exists in S3 (${phase})" 1>&2
        exit 1
    fi
}

# Do not do any expensive work if the destination path exists in S3.
avoid_dest_overwrite "check before conversion and imputation"

workdir="${basedir}/$(date +"%Y-%m-%d.%H-%M-%S.%N")"
mkdir "${workdir}"
pushd "${workdir}" > /dev/null

mkdir "${user_id}"
pushd "${user_id}" > /dev/null

mkdir "${data_source}"
pushd "${data_source}" > /dev/null

input_file=${data_source}-raw.txt

aws s3 --endpoint-url "${AWS_S3_ENDPOINT_URL}" \
    cp "s3://${S3_BUCKET_BIOINFORMATICS_UPLOAD}/${upload_path}" "${input_file}" > /dev/null

sha256sum=$(sha256sum "${input_file}" | awk '{print $1}')
mkdir "${sha256sum}"
pushd "${sha256sum}" > /dev/null
mv "../${input_file}" .

mkdir headers
mkdir imputed

"${basedir}/convert-${data_source}-to-vcf.sh" "${input_file}" raw.vcf.gz ${test_mock_vcf}

"${basedir}/extract-vcf-headers.sh" raw.vcf.gz > "headers/${data_source}.txt"

# TODO: How many cores for imputation?
num_cores=3
for chr in {1..22} X Y MT; do
    imputed_filename="imputed/chr${chr}.vcf"
    "${basedir}/impute-genotype.sh" raw.vcf.gz "${imputed_filename}" ${chr} ${num_cores} ${test_mock_vcf}
    "${basedir}/extract-vcf-headers.sh" "${imputed_filename}.bgz" > "headers/imputed-chr${chr}.txt"
done

popd > /dev/null
popd > /dev/null
popd > /dev/null

# Once again, check that the destination does not exist in case another process raced this one.
avoid_dest_overwrite "check after imputation and before final copy into S3"

src_dir=$(readlinkf "${user_id}")
aws s3 --endpoint-url "${AWS_S3_ENDPOINT_URL}" cp --recursive "${src_dir}" "s3://${S3_BUCKET_BIOINFORMATICS_VCF}/${user_id}" --exclude "**/${input_file}" > /dev/null

popd > /dev/null

"${basedir}/run-initial-call-variants-import.sh" \
    --user-id="${user_id}" \
    --workdir="${workdir}" \
    --data-source="${data_source}" \
    --stage="${stage}" \
    --test-mock-lambda="${test_mock_lambda}" \
    --cleanup-after="${cleanup_after}"

# if we are not cleaning up afterwards, print the path to the working directory:
# it may come in handy
if [[ "${cleanup_after}" == "false" ]]; then
    echo "${workdir}"
fi
