#!/usr/bin/env bash

set -Eeo pipefail

readlinkf() { perl -MCwd -e 'print Cwd::abs_path glob shift' "$1"; }
basedir=$(dirname "$(readlinkf $0)")
script=$(basename "${BASH_SOURCE[${#BASH_SOURCE[@]}-1]}")


. "${basedir}/common.sh"


### configuration
if [[ -z "${AWS_REGION}" ]]; then
    echo "AWS_REGION environment variable required" >&2
    exit 1
fi

if [[ -z "${AWS_S3_ENDPOINT_URL}" ]]; then
    echo "AWS_S3_ENDPOINT_URL environment variable required" >&2
    exit 1
fi

if [[ -z "${S3_BUCKET_BIOINFORMATICS_UPLOAD}" ]]; then
    echo "S3_BUCKET_BIOINFORMATICS_UPLOAD environment variable required" >&2
    exit 1
fi

if [[ -z "${S3_BUCKET_BIOINFORMATICS_VCF}" ]]; then
    echo "S3_BUCKET_BIOINFORMATICS_VCF environment variable required" >&2
    exit 1
fi

# TODO: Figure out what to do with this.
# if [[ -z "${S3_BUCKET_BIOINFORMATICS_ERROR}" ]]; then
#     echo "S3_BUCKET_BIOINFORMATICS_ERROR environment variable required" >&2
#     exit 1
# fi


### parameters
! getopt --test > /dev/null
if [[ ${PIPESTATUS[0]} -ne 4 ]]; then
    echo "enhanced getopt not available" >&2
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
            echo "something's wrong" >&2
            exit 1
            ;;
    esac
done

[[ -z "${param_data_source}" ]] && param_data_source="${PARAM_DATA_SOURCE}"
[[ -z "${param_upload_path}" ]] && param_upload_path="${PARAM_UPLOAD_PATH}"
[[ -z "${param_user_id}" ]] && param_user_id="${PARAM_USER_ID}"
[[ -z "${param_stage}" ]] && param_stage="${PARAM_STAGE}"

if [[ -z "${param_data_source}" ]]; then
    echo "data source must be set with PARAM_DATA_SOURCE or --data-source" >&2
    exit 1
fi

if [[ "${param_data_source}" != "23andme" ]]; then
    echo "only 23andme supported at the moment" >&2
    exit 1
fi

if [[ -z "${param_upload_path}" ]]; then
    echo "upload path must be set with PARAM_UPLOAD_PATH or --upload-path" >&2
    exit 1
fi

if [[ -z "${param_user_id}" ]]; then
    echo "user ID must be set with PARAM_USER_ID environment variable or --user-id" >&2
    exit 1
fi

if [[ -z "${param_stage}" ]]; then
    echo "stage must be set with PARAM_STAGE environment variable or --stage" >&2
    exit 1
fi

if [[ -z "${param_test_mock_vcf}" || ("${param_test_mock_vcf}" != "true" && "${param_test_mock_vcf}" != "false") ]]; then
    echo "test mode for mock VCF use must be set with --test-mock-vcf and must be 'true' or 'false'" >&2
    exit 1
fi

if [[ -z "${param_test_mock_lambda}" || ("${param_test_mock_lambda}" != "true" && "${param_test_mock_lambda}" != "false") ]]; then
    echo "test mode for mock AWS Lambda use must be set with --test-mock-lambda and must be 'true' or 'false'" >&2
    exit 1
fi

if [[ -z "${param_cleanup_after}" || ("${param_cleanup_after}" != "true" && "${param_cleanup_after}" != "false") ]]; then
    echo "cleanup must be set with --cleanup-after and must be true or false" >&2
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
    if [[ "${cleanup_after}" == "true" && ! -z "${workdir}" ]]; then
        debug "clean up: removing '${workdir}'"
        [[ ! -z "${workdir}" ]] && rm -rf "${workdir}"
    fi
}

trap cleanup EXIT


### run
info $(json_pairs user_id "${user_id}" data_source "${data_source}" upload_path "${upload_path}")

function avoid_dest_overwrite {
    local phase=$1
    if [[ ! -z $(aws s3 --endpoint-url "${AWS_S3_ENDPOINT_URL}" ls "s3://${S3_BUCKET_BIOINFORMATICS_VCF}/${user_id}") ]]; then
        error "${user_id} already exists in S3 (${phase})"
        exit 1
    fi
}

# Do not do any expensive work if the destination path exists in S3.
avoid_dest_overwrite "check before conversion and imputation"

workdir="${basedir}/$(timestamp)"
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

mkdir imputed

# convert the raw user input format (23andMe and the like) to VCF
conversion_result_file=raw-conversion-results.txt
set +e
"${basedir}/convert-${data_source}-to-vcf.sh" "${input_file}" raw.vcf.gz ${test_mock_vcf} "${conversion_result_file}"
conversion_err=$?
if [[ "${conversion_err}" == 11 ]]; then
    info "input file is unsupported"
    # FIXME: update UserState to "error"
    exit 0
elif [[ "${conversion_err}" != 0 ]]; then
    error "conversion failed"
    exit 1
fi
set -e
# post-process and print VCF conversion result run
function print_vcf_conversion_results {
    awk -f "${basedir}/collapse-repeating-lines.awk" "${conversion_result_file}"
}
with_output_to_log print_vcf_conversion_results
# extract relevant result statistics.
conversion_result_num_rows_total=$(grep 'Rows total:' "${conversion_result_file}" | awk -F ":" '{ $1 = ""; gsub(/[[:space:]]/, "", $2); print; }')
conversion_result_num_rows_skipped=$(grep 'Rows skipped:' "${conversion_result_file}" | awk -F ":" '{ $1 = ""; gsub(/[[:space:]]/, "", $2); print; }')
conversion_result_num_output_lines=$(zgrep -v '^#' raw.vcf.gz | wc -l)
# if the VCF output has no non-comment output lines, this is bad input
if [[ ${conversion_result_num_output_lines} == 0 ]]; then
    info "output VCF file has no non-comment lines, the input was probably bad"
    # FIXME: update UserState to "error"
    exit 0
fi
# if the process skipped too many rows, also consider it bad input
if [[ $(( ${conversion_result_num_rows_skipped} / ${conversion_result_num_rows_total} )) > 0.20 ]]; then
    info "output VCF file has too many skipped lines, the input was probably bad"
    # FIXME: update UserState to "error"
    exit 0
fi

# FIXME: update UserState to "processing"

# let's run 1 batch of all
chr_groups=("1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,X,Y,MT")
for chrs in "${chr_groups[@]}"; do
    info "looking at chr_group '${chrs}'"
    imputed_filename="imputed/chr-tmp.vcf"
    with_output_to_log \
        "${basedir}/impute-genotype.sh" raw.vcf.gz "${imputed_filename}" "${chrs}" ${test_mock_vcf}
    for chr in ${chrs//,/ }; do # NB: intentional splitting by space!
        imputed_chr_filename="imputed/chr${chr}.vcf"
        awk -v chr="${chr}" '/^#/ || $1 == chr' "${imputed_filename}" | bgzip > "${imputed_chr_filename}.bgz"
        tabix -p vcf "${imputed_chr_filename}.bgz"
    done
    rm -f "${imputed_filename}"
done

popd > /dev/null
popd > /dev/null
popd > /dev/null

# Once again, check that the destination does not exist in case another process raced this one.
avoid_dest_overwrite "check after imputation and before final copy into S3"

src_dir=$(readlinkf "${user_id}")
aws s3 --endpoint-url "${AWS_S3_ENDPOINT_URL}" cp --recursive "${src_dir}" "s3://${S3_BUCKET_BIOINFORMATICS_VCF}/${user_id}" --exclude "**/${input_file}" > /dev/null

popd > /dev/null

with_output_to_log \
    "${basedir}/import-initial-call-variants.sh" \
    --user-id="${user_id}" \
    --workdir="${workdir}" \
    --data-source="${data_source}" \
    --stage="${stage}" \
    --test-mock-lambda="${test_mock_lambda}" \
    --cleanup-after="${cleanup_after}"

# FIXME: update UserState to "ready"

# if we are not cleaning up afterwards, print the path to the working directory:
# it may come in handy
# NB: Only do this if file descriptor 9 is available, e.g., with 9>&1 on the
# invoking command line.
if command >&9 && [[ "${cleanup_after}" == "false" ]]; then
    echo "${workdir}" >&9
fi 2>/dev/null
