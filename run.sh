#!/usr/bin/env bash

set -e
set -o pipefail

export BEAGLE_REFDB_PATH=/precisely/data/beagle-refdb

beagle_leash=/precisely/beagle-leash/inst/beagle-leash/bin/beagle-leash
path_reference_human_genome=/precisely/data/human_g1k_v37.fasta.bgz
sample_id=SAMPLEID
num_cores=2

input_23andme_genome_file=/precisely/data/samples/genome-Adam-Davidson-Full-20150524125003_cc8525e1045f9cfacd8e6dd012134e07.txt

# step 0: check for genome version 37, others seem to fail (?); this information
# is stored in a comment
if [[ $(grep '.*#' "${input_23andme_genome_file}" |
            grep 'We are using reference human assembly build' |
            sed 's/.*build \([[:digit:]]\+\).*/\1/') -ne 37 ]]; then
    echo "unsupported genome version"
    exit 1
fi

vcf_file_converted=/precisely/app/vcf-step-1-converted-SAMPLEID.vcf.gz
vcf_file_imputed=/precisely/app/vcf-step-2-imputed-SAMPLEID.vcf.gz
vcf_file_compressed=/precisely/app/vcf-step-3-imputed-SAMPLEID.vcf.bgz

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
    BEAGLE_LEASH_CHROMS="21" ${beagle_leash} "${vcf_file_converted}" "${vcf_file_imputed}" ${num_cores}
fi

# step 3: use bgzip to compress the imputed output
if [[ ! -f "${vcf_file_compressed}" ]]; then
    zcat "${vcf_file_imputed}" | bgzip > "${vcf_file_compressed}"
fi

# step 4: use tabix (not sure if needed?)
if [[ ! -f "${vcf_file_compressed}.tbi" ]]; then
    tabix -p vcf "${vcf_file_compressed}"
fi
