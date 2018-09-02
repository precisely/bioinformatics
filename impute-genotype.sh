#!/usr/bin/env bash

set -Eeuo pipefail


### configuration
path_sample_test_run=/precisely/data/samples/2018-08-16-imputation-run-abeeler-miniaturized/abeeler1/23andme/a5cef5de111d61d4e8f57f0ab6166a1d8279cdc419f414383d8505efe74704f0


### parameters
if [[ "$#" -eq 0 ]]; then
    echo "usage: impute-genotype.sh <input-vcf-path> <output-imputed-vcf-path> <num-chromosome> <num-cores>? <test-mock-vcf>?" 1>&2
    exit 1
fi

input_vcf_path="$1"
output_imputed_vcf_path="$2"
num_chromosome="$3"
num_cores="$4"
test_mock_vcf="$5"

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

if [[ -z "${test_mock_vcf}" ]]; then
    test_mock_vcf=false
fi


### configuration
export BEAGLE_REFDB_PATH=/precisely/data/beagle-refdb
beagle_leash=/precisely/beagle-leash/inst/beagle-leash/bin/beagle-leash


### run
if [[ -e "${output_imputed_vcf_path}*" ]]; then
    echo "${output_imputed_vcf_path} already exists, no imputation attempted"
else
    if [[ "${test_mock_vcf}" == "true" ]]; then
        cp "${path_sample_test_run}/imputed/chr${num_chromosome}.vcf.bgz" "${output_imputed_vcf_path}.bgz"
        cp "${path_sample_test_run}/imputed/chr${num_chromosome}.vcf.bgz.tbi" "${output_imputed_vcf_path}.bgz.tbi"
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
