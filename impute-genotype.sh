#!/usr/bin/env bash

set -e
set -o pipefail


### parameters
if [[ "$#" -eq 0 ]]; then
    echo "usage: impute-genotype.sh <input-vcf-path> <output-imputed-vcf-path> all|<num-chromosome>? <num-cores>? <test-mode>?" 1>&2
    exit 1
fi

input_vcf_path="$1"
output_imputed_vcf_path="$2"
num_chromosome="$3"
num_cores="$4"
test_mode="$5"

if [[ -z "${input_vcf_path}" ]]; then
    echo "input VCF file path required" 1>&2
    exit 1
fi

if [[ ! -f "${input_vcf_path}" ]]; then
    echo "input VCF file path does not exist" 1>&2
    exit 1
fi

if [[ -z "${output_imputed_vcf_path}" ]]; then
    echo "output imputed VCF file path required" 1>&2
    exit 1
fi

if [[ -z "${num_chromosome}" ]]; then
    num_chromosome=all
fi

if [[ -z "${num_cores}" ]]; then
    num_cores=2
fi

if [[ -z "${test_mode}" ]]; then
    test_mode=false
fi


### configuration
export BEAGLE_REFDB_PATH=/precisely/data/beagle-refdb
beagle_leash=/precisely/beagle-leash/inst/beagle-leash/bin/beagle-leash


### run
if [[ -e "${output_imputed_vcf_path}" ]]; then
    echo "${output_imputed_vcf_path} already exists, no imputation attempted"
else
    if [[ "${num_chromosome}" != "all" ]]; then
        export BEAGLE_LEASH_CHROMS=${num_chromosome}
    fi
    if [[ "${test_mode}" == "true" ]]; then
        printf "##input=${input_vcf_path}\n##chromosome=${num_chromosome}\ninput: ${input_vcf_path}\nchromosome: ${num_chromosome}\n" > "${output_imputed_vcf_path}"
    else
        "${beagle_leash}" "${input_vcf_path}" "${output_imputed_vcf_path}" ${num_cores}
    fi
fi
