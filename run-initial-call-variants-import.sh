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
            echo "usage: run-initial-call-variants-import.sh FIXME"
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
# check if the workdir exists
if [[ -z "${workdir}" || ! -d "${workdir}" ]]; then
    echo "FIXME: Implement this code path" 1>&2
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

#aws lambda invoke --invocation-type RequestResponse --function-name "precisely-backend-${stage}-SysGetVariantRequirements" --payload '"ready"' --region "${AWS_REGION}" variant-reqs.json

# FIXME: Check for errors in variant-reqs.json.

# It makes more sense to just invoke the Python variant extractor here.
# FIXME: Undo this.
#REQS_FILE=variant-reqs.json
REQS_FILE=/precisely/app/tests/sample-variant-reqs-2.json
"${basedir}/python/extract-variant.py" "${REQS_FILE}" ./imputed | \
    jq --arg data_source ${data_source} \
       --arg user_id ${user_id} \
       --arg sample_id ${sample_id} \
       '[.[] | . + {sampleType: $data_source, userId: $user_id, sampleId: $sample_id}]' # > base-batch.json

aws lambda invoke --invocation-type RequestResponse --function-name "precisely-backend-${stage}-VariantCallBatchCreate" --payload file://base-batch.json --region "${AWS_REGION}" variant-batch-results.json

# FIXME: Check for errors in variant-reqs.json

#rm -f variant-reqs.json
#rm -f variant-batch-results.json
