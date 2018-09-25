#!/usr/bin/env bash

set -Eeo pipefail

readlinkf() { perl -MCwd -e 'print Cwd::abs_path glob shift' "$1"; }
basedir=$(dirname "$(readlinkf $0)")
script=$(basename "${BASH_SOURCE[${#BASH_SOURCE[@]}-1]}")


. "${basedir}/common.sh"


### configuration
path_reference_human_genome=/precisely/data/human_g1k_v37.fasta.bgz
path_sample_test_run=/precisely/data/samples/2018-08-16-imputation-run-abeeler-miniaturized/abeeler1/23andme/a5cef5de111d61d4e8f57f0ab6166a1d8279cdc419f414383d8505efe74704f0


### parameters
if [[ "$#" -eq 0 ]]; then
    echo "usage: convert-23andme-to-vcf.sh <input-23andme-file-path> <output-vcf-path> <test-mock-vcf> <output-conversion-results-path>" >&2
    exit 1
fi

input_23andme_file_path="$1"
output_vcf_path="$2"
test_mock_vcf="$3"
output_conversion_results_path="$4"

if [[ -z "${input_23andme_file_path}" ]]; then
    echo "input 23andMe genome file path required" >&2
    exit 1
fi

if [[ -z "${output_vcf_path}" ]]; then
    echo "output VCF file path required" >&2
    exit 1
fi

if [[ -z "${test_mock_vcf}" ]]; then
    echo "test-mock-vcf flag required" >&2
    exit 1
fi

if [[ -z "${output_conversion_results_path}" ]]; then
    echo "output conversion results file required" >&2
    exit 1
fi


### run
info $(json_pairs input_23andme_file_path "${input_23andme_file_path}" output_vcf_path "${output_vcf_path}")

# check for genome version 37, others seem to fail (?); this information is
# stored in a comment
if [[ $(grep '.*#' "${input_23andme_file_path}" |
            grep 'We are using reference human assembly build' |
            sed 's/.*build \([[:digit:]]\+\).*/\1/') -ne 37 ]]; then
    info "unsupported genome version"
    exit 11
fi

sample_id=$(sha256sum "${input_23andme_file_path}" | awk '{print $1}')

# convert 23andMe file to VCF
if [[ -e "${output_vcf_path}" ]]; then
    warn "${output_vcf_path} already exists, no conversion attempted"
else
    if [[ "${test_mock_vcf}" == "true" ]]; then
        cp "${path_sample_test_run}/raw.vcf.gz" "${output_vcf_path}"
        cp "${path_sample_test_run}/raw.vcf.gz-run-output" "${output_conversion_results_path}"
    else
        bcftools convert \
                 --tsv2vcf "${input_23andme_file_path}" \
                 -f "${path_reference_human_genome}" \
                 -s "${sample_id}" \
                 -Oz -o "${output_vcf_path}" 1>&2 2>"${output_conversion_results_path}"
    fi
fi
