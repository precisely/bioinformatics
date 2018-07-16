#!/usr/bin/env bash

# this script should fail on any invocation error
set -e
set -o pipefail

# configuration
export BEAGLE_REFDB_PATH=/precisely/data/beagle-refdb
beagle_leash=/precisely/beagle-leash/inst/beagle-leash/bin/beagle-leash
beagle_num_cores=2
path_reference_human_genome=/precisely/data/human_g1k_v37.fasta.bgz

# parameter handling
if [ "$#" -eq 0 ]; then
    echo "usage: run.sh <input-23andme-genome-file> <sample-id>" 1>&2
    exit 1
fi

input_23andme_genome_file="$1"
sample_id="$2"

if [[ -z "${input_23andme_genome_file}" ]]; then
    echo "input 23andMe genome file required"
    exit 1
fi

if [[ -z "${sample_id}" ]]; then
    echo "sample ID required"
    exit 1
fi

# step 0: check for genome version 37, others seem to fail (?); this information
# is stored in a comment
if [[ $(grep '.*#' "${input_23andme_genome_file}" |
            grep 'We are using reference human assembly build' |
            sed 's/.*build \([[:digit:]]\+\).*/\1/') -ne 37 ]]; then
    echo "unsupported genome version"
    exit 1
fi

vcf_file_converted=/precisely/app/vcf-step-1-converted-${sample_id}.vcf.gz
vcf_file_imputed=/precisely/app/vcf-step-2-imputed-${sample_id}.vcf.gz
vcf_file_compressed=/precisely/app/vcf-step-3-imputed-${sample_id}.vcf.bgz

# step 1: convert 23andMe file to VCF
if [[ ! -f "${vcf_file_converted}" ]]; then
    bcftools convert \
             --tsv2vcf "${input_23andme_genome_file}" \
             -f "${path_reference_human_genome}" \
             -s "${sample_id}" \
             -Oz -o "${vcf_file_converted}"
fi

# step 2: use Beagle to impute from the input VCF to a fuller VCF
if [[ ! -f "${vcf_file_imputed}" ]]; then
    BEAGLE_LEASH_CHROMS="21" ${beagle_leash} "${vcf_file_converted}" "${vcf_file_imputed}" ${beagle_num_cores}
fi

# step 3: use bgzip to compress the imputed output
if [[ ! -f "${vcf_file_compressed}" ]]; then
    zcat "${vcf_file_imputed}" | bgzip > "${vcf_file_compressed}"
fi

# step 4: use tabix (not sure if needed?)
if [[ ! -f "${vcf_file_compressed}.tbi" ]]; then
    tabix -p vcf "${vcf_file_compressed}"
fi
