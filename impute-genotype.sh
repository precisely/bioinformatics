#!/usr/bin/env bash

set -e
set -o pipefail


### parameters
if [[ "$#" -eq 0 ]]; then
    echo "usage: impute-genotype.sh <input-vcf-path> <output-imputed-vcf-path> <num-chromosome> <num-cores>? <test-mode>?" 1>&2
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
    echo "chromosome to impute is required (1..22, X, Y, MT)" 1>&2
    exit 1
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
if [[ -e "${output_imputed_vcf_path}*" ]]; then
    echo "${output_imputed_vcf_path} already exists, no imputation attempted"
else
    if [[ "${test_mode}" == "true" ]]; then
        printf "##input=${input_vcf_path}\n##chromosome=${num_chromosome}\ninput: ${input_vcf_path}\nchromosome: ${num_chromosome}\n" > "${output_imputed_vcf_path}.bgz"
        printf "sample tabix index\n" > "${output_imputed_vcf_path}.bgz.tbi"
    else
        if [[ "${num_chromosome}" == "Y" || "${num_chromosome}" == "MT" ]]; then
            # Imputation is not supported for Y and MT chromosomes; for these,
            # we just copy them from the input to the output file.
            zcat "${input_vcf_path}" | \
                awk -v chr="${num_chromosome}" '/^#/ || $1 == chr' | \
                gzip > "${output_imputed_vcf_path}.gz"
        else
            export BEAGLE_LEASH_CHROMS=${num_chromosome}
            "${beagle_leash}" "${input_vcf_path}" "${output_imputed_vcf_path}-tmp.gz" ${num_cores}
            # remove entries from the output file which do not match the required chromosome
            if [[ ! -f "${output_imputed_vcf_path}-tmp.gz" ]]; then
                echo "${output_imputed_vcf_path}-tmp.gz missing!" 1>&2
                exit 1
            fi
            zcat "${output_imputed_vcf_path}-tmp.gz" | \
                awk -v chr="${num_chromosome}" '/^#/ || $1 == chr' | \
                gzip > "${output_imputed_vcf_path}.gz"
            rm -f "${output_imputed_vcf_path}-tmp.gz"
        fi
        zcat "${output_imputed_vcf_path}.gz" | bgzip > "${output_imputed_vcf_path}.bgz"
        rm -f "${output_imputed_vcf_path}.gz"
        tabix -p vcf "${output_imputed_vcf_path}.bgz"
    fi
fi
