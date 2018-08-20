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

if [[ -z "${AWS_REGION}" ]]; then
    echo "AWS_REGION environment variable required" 1>&2
    exit 1
fi

if [[ -z "${S3_BUCKET_BIOINFORMATICS_VCF}" ]]; then
    echo "S3_BUCKET_BIOINFORMATICS_VCF environment variable required" 1>&2
    exit 1
fi


### parameters
! getopt --test > /dev/null
if [[ ${PIPESTATUS[0]} -ne 4 ]]; then
    echo "enhanced getopt not available" 1>&2
    exit 1
fi
! PARSED=$(getopt --options="h" --longoptions="data-source:,user-id:,workdir:,stage:,help" --name "$0" -- "$@")
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
        --user-id)
            param_user_id="$2"
            shift 2
            ;;
        --workdir)
            param_workdir="$2"
            shift 2
            ;;
        --stage)
            param_stage="$2"
            shift 2
            ;;
        -h|--help)
            echo "usage: run-initial-call-variants-import.sh --data-source=... --user-id=... --workdir=... --stage=..."
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
[[ -z "${param_user_id}" ]] && param_user_id="${PARAM_USER_ID}"
[[ -z "${param_workdir}" ]] && param_workdir="${PARAM_WORKDIR}"
[[ -z "${param_stage}" ]] && param_workdir="${PARAM_STAGE}"

if [[ -z "${param_data_source}" ]]; then
    echo "data source must be set with PARAM_DATA_SOURCE or --data-source" 1>&2
    exit 1
fi

if [[ "${param_data_source}" != "23andme" ]]; then
    echo "only 23andme supported at the moment" 1>&2
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

data_source="${param_data_source}"
user_id="${param_user_id}"
workdir="${param_workdir}"
stage="${param_stage}"


### run
# if the workdir already exists, use it; else download the user's data as needed
if [[ -z "${workdir}" || ! -d "${workdir}" ]]; then
    echo "working directory missing" 1>&2
    exit 1
fi

real_workdir="${workdir}/${user_id}/${data_source}"

if [[ ! -d "${real_workdir}" ]]; then
    echo "something's missing in path ${real_workdir}" 1>&2
    exit 1
fi

pushd "${real_workdir}" > /dev/null

# TODO: This probably needs to support multiple checksums (sample IDs). Making
# this work properly requires keeping track of which one we intend to use for
# imports.
hashes=(*)
if [[ ${#hashes[@]} -gt 1 ]]; then
    echo "multiple hashes of original uploads not supported" 1>&2
    exit 1
fi
sample_id=${hashes[0]}

pushd "${sample_id}" > /dev/null

if [[ -f variant-reqs.json ]]; then
    echo "variant-reqs.json file already exists" 1>&2
    exit 1
fi

if [[ -f variant-batch-results.json ]]; then
    echo "variant-batch-results.json file already exists" 1>&2
    exit 1
fi

aws lambda invoke --invocation-type RequestResponse --function-name "precisely-backend-${stage}-SysGetVariantRequirements" --payload '"ready"' --region "${AWS_REGION}" variant-reqs.json > aws-invoke-SysGetVariantRequirements.json

if [[ $(jq '.StatusCode' aws-invoke-SysGetVariantRequirements.json) != "200" ]]; then
    echo "SysGetVariantRequirements invocation failed" 1>&2
    exit 1
fi

if [[ -f base-batch.json ]]; then
    echo "base-batch.json file already exists" 1>&2
    exit 1
fi

"${basedir}/python/extract-variant.py" variant-reqs.json ./imputed | \
    jq --arg data_source ${data_source} \
       --arg user_id ${user_id} \
       --arg sample_id ${sample_id} \
       '[.[] | . + {sampleType: $data_source, userId: $user_id, sampleId: $sample_id}]' > base-batch.json

aws lambda invoke --invocation-type RequestResponse --function-name "precisely-backend-${stage}-VariantCallBatchCreate" --payload file://base-batch.json --region "${AWS_REGION}" variant-batch-results.json > aws-invoke-VariantCallBatchCreate.json

if [[ $(jq '.StatusCode' aws-invoke-VariantCallBatchCreate.json) != "200" ]]; then
    echo "VariantCallBatchCreate invocation failed" 1>&2
    exit 1
fi

variant_call_batch_create_errors=$(jq -r '.[] | .error | select(. != null)' variant-batch-results.json)
if [[ ! -z "${variant_call_batch_create_errors}" ]]; then
    echo "errors from call to VariantCallBatchCreate: ${variant_call_batch_create_errors}" 1>&2
    exit 1
fi

rm -f variant-reqs.json
rm -f aws-invoke-SysGetVariantRequirements.json
rm -f base-batch.json
rm -f variant-batch-results.json
rm -f aws-invoke-VariantCallBatchCreate.json
