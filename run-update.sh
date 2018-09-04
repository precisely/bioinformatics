#!/usr/bin/env bash

set -Eeo pipefail

readlinkf() { perl -MCwd -e 'print Cwd::abs_path glob shift' "$1"; }
basedir=$(dirname "$(readlinkf $0)")
script=$(basename "${BASH_SOURCE[${#BASH_SOURCE[@]}-1]}")


. "${basedir}/common.sh"


### configuration
if [[ -z "${AWS_S3_ENDPOINT_URL}" ]]; then
    echo "AWS_S3_ENDPOINT_URL environment variable required" >&2
    exit 1
fi

if [[ -z "${AWS_REGION}" ]]; then
    echo "AWS_REGION environment variable required" >&2
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


### parameters
! getopt --test > /dev/null
if [[ ${PIPESTATUS[0]} -ne 4 ]]; then
    echo "enhanced getopt not available" >&2
    exit 1
fi
! PARSED=$(getopt --options="h" --longoptions="data-source:,stage:,test-mock-lambda:,cleanup-after:,help" --name "$0" -- "$@")
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
        --stage)
            param_stage="$2"
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
            echo "usage: run-update.sh --data-source=... --stage=... --test-mock-lambda=... --cleanup-after=..."
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
[[ -z "${param_stage}" ]] && param_stage="${PARAM_STAGE}"

if [[ -z "${param_data_source}" ]]; then
    echo "data source must be set with PARAM_DATA_SOURCE or --data-source" >&2
    exit 1
fi

if [[ "${param_data_source}" != "23andme" ]]; then
    echo "only 23andme supported at the moment" >&2
    exit 1
fi

if [[ -z "${param_stage}" ]]; then
    echo "stage must be set with PARAM_STAGE environment variable or --stage" >&2
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
stage="${param_stage}"
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
info $(json_pairs data_source "${data_source}")

workdir="${basedir}/$(timestamp)"
mkdir "${workdir}"
pushd "${workdir}" > /dev/null

if [[ "${test_mock_lambda}" == "true" ]]; then
    cp "${basedir}/tests/mocks/variant-reqs-new.json" .
    cp "${basedir}/tests/mocks/aws-invoke-SysGetVariantRequirements.json" .
else
    aws lambda invoke --invocation-type RequestResponse --function-name "precisely-backend-${stage}-SysGetVariantRequirements" --payload '"new"' --region "${AWS_REGION}" variant-reqs-new.json > aws-invoke-SysGetVariantRequirements.json
fi

if [[ $(jq '.StatusCode' aws-invoke-SysGetVariantRequirements.json) != "200" ]]; then
    error "SysGetVariantRequirements invocation failed"
    exit 1
fi

required_refs=($(jq -r '[.[] | .refName] | unique | .[]' variant-reqs-new.json))

# TODO: Does this need to avoid pagination?
user_ids=($(aws s3api --endpoint-url="${AWS_S3_ENDPOINT_URL}" list-objects --bucket="${S3_BUCKET_BIOINFORMATICS_VCF}" --delimiter=/ --no-paginate | \
                jq -r '.CommonPrefixes | .[] | .Prefix | split("/")[0]'))

for user_id in "${user_ids[@]}"; do
    mkdir "${user_id}"
    pushd "${user_id}" > /dev/null
    sample_ids=($(aws s3api --endpoint-url="${AWS_S3_ENDPOINT_URL}" list-objects --bucket="${S3_BUCKET_BIOINFORMATICS_VCF}" --delimiter=/ --prefix="${user_id}/${data_source}/" --no-paginate | \
                      jq -r '.CommonPrefixes | .[]? | .Prefix | split("/")[2]'))
    for sample_id in "${sample_ids[@]}"; do
        mkdir -p "${sample_id}"
        pushd "${sample_id}" > /dev/null
        # copy in the chromosome files containing the new variants to import
        for ref in "${required_refs[@]}"; do
            aws s3 --endpoint-url="${AWS_S3_ENDPOINT_URL}" cp --recursive --exclude="*" --include="${ref}.vcf.bgz*" "s3://${S3_BUCKET_BIOINFORMATICS_VCF}/${user_id}/${data_source}/${sample_id}/imputed" . > /dev/null
        done
        "${basedir}/python/extract-variant.py" "${workdir}/variant-reqs-new.json" . | \
            jq --arg data_source ${data_source} \
               --arg user_id ${user_id} \
               --arg sample_id ${sample_id} \
               '[.[] | . + {sampleType: $data_source, userId: $user_id, sampleId: $sample_id}]' > "${workdir}/new-call-variants-${user_id}.json"
        popd > /dev/null
    done
    popd > /dev/null
done

# concatenate the resulting per-user files together
jq -s add new-call-variants-*.json > new-batch.json

# call the right Lambda to create call variant entries for the given users
if [[ "${test_mock_lambda}" == "true" ]]; then
    cp "${basedir}/tests/mocks/variant-batch-results-2.json" ./variant-batch-results.json
    cp "${basedir}/tests/mocks/aws-invoke-VariantCallBatchCreate.json" .
else
    aws lambda invoke --invocation-type RequestResponse --function-name "precisely-backend-${stage}-VariantCallBatchCreate" --payload file://new-batch.json --region "${AWS_REGION}" variant-batch-results.json > aws-invoke-VariantCallBatchCreate.json
fi

if [[ $(jq '.StatusCode' aws-invoke-VariantCallBatchCreate.json) != "200" ]]; then
    error "VariantCallBatchCreate invocation failed"
    exit 1
fi

variant_call_batch_create_errors=$(jq -r '.[] | .error | select(. != null)' variant-batch-results.json)
if [[ ! -z "${variant_call_batch_create_errors}" ]]; then
    error "errors from call to VariantCallBatchCreate: ${variant_call_batch_create_errors}"
    exit 1
fi

# update the list of "new" call variants to "ready"
jq '[.[] | {status: "ready", refVersion: .refVersion, start: .start, refName: .refName}]' variant-reqs-new.json > variant-reqs-update.json

if [[ "${test_mock_lambda}" == "true" ]]; then
    cp "${basedir}/tests/mocks/variant-reqs-update-results.json" .
    cp "${basedir}/tests/mocks/aws-invoke-SysUpdateVariantRequirementStatuses.json" .
else
    aws lambda invoke --invocation-type RequestResponse --function-name "precisely-backend-${stage}-SysUpdateVariantRequirementStatuses" --payload file://variant-reqs-update.json --region "${AWS_REGION}" variant-reqs-update-results.json > aws-invoke-SysUpdateVariantRequirementStatuses.json
fi

if [[ $(jq '.StatusCode' aws-invoke-SysUpdateVariantRequirementStatuses.json) != "200" ]]; then
    error "SysUpdateVariantRequirementStatuses invocation failed"
    exit 1
fi

# if we are not cleaning up afterwards, print the path to the working directory:
# it may come in handy
# NB: Only do this if file descriptor 9 is available, e.g., with 9>&1 on the
# invoking command line.
if command >&9 && [[ "${cleanup_after}" == "false" ]]; then
    echo "${workdir}" >&9
fi 2>/dev/null
