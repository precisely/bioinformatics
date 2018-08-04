#!/usr/bin/env bash

set -e
set -o pipefail


### parameters
if [ "$#" -eq 0 ]; then
    echo "usage: extract-vcf-headers.sh <input-vcf-path>" 1>&2
    exit 1
fi

input_vcf_path="$1"

if [[ -z "${input_vcf_path}" ]]; then
    echo "input VCF file path required" 1>&2
    exit 1
fi

if [[ ! -f "${input_vcf_path}" ]]; then
    echo "input VCF file path does not exist" 1>&2
    exit 1
fi


### run
cat_cmd=cat
if [[ $(file "${input_vcf_path}" | grep gzip) ]]; then
    cat_cmd=zcat
fi

${cat_cmd} "${input_vcf_path}" | grep '##'
