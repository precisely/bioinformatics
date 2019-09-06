#!/usr/bin/env bash

set -Eeo pipefail

readlinkf() { perl -MCwd -MFile::Glob -l -e 'print Cwd::abs_path File::Glob::bsd_glob shift' "$1"; }
basedir=$(dirname "$(readlinkf "$0")")
script=$(basename "${BASH_SOURCE[${#BASH_SOURCE[@]}-1]}")


. "${basedir}/common.sh"


### configuration
path_sample_test_run=/precisely/data/samples/2018-08-16-imputation-run-abeeler-miniaturized/abeeler1/23andme/a5cef5de111d61d4e8f57f0ab6166a1d8279cdc419f414383d8505efe74704f0


### parameters
if [[ "$#" -eq 0 ]]; then
    echo "usage: impute-genotype.sh <input-vcf-path> <output-imputed-vcf-path> <chromosomes> <test-mock-vcf>?" >&2
    exit 1
fi

input_vcf_path="$1"
output_imputed_vcf_path="$2"
chromosomes="$3"
test_mock_vcf="$4"

if [[ -z "${input_vcf_path}" ]]; then
    echo "input VCF file path required" >&2
    exit 1
fi

if [[ ! -f "${input_vcf_path}" ]]; then
    echo "input VCF file path does not exist" >&2
    exit 1
fi

if [[ -z "${output_imputed_vcf_path}" ]]; then
    echo "output imputed VCF file path required" >&2
    exit 1
fi

if [[ -z "${chromosomes}" ]]; then
    echo "chromosomes to impute are required as comma-separated list (valid values: 1..22, X, Y, MT)" >&2
    exit 1
fi

if [[ -z "${test_mock_vcf}" ]]; then
    test_mock_vcf=false
fi


### configuration
export BEAGLE_REFDB_PATH=/precisely/data/beagle-refdb
beagle_leash=/precisely/beagle-leash/inst/beagle-leash/bin/beagle-leash


### run
info $(json_pairs input_vcf_path "${input_vcf_path}" output_imputed_vcf_path "${output_imputed_vcf_path}" chromosomes "${chromosomes}")

# replace commas in chromosome list with spaces so splitting works
chromosomes=${chromosomes//,/ }

if [[ -e "${output_imputed_vcf_path}*" ]]; then
    warn "${output_imputed_vcf_path} already exists, no imputation attempted"
else
    if [[ "${test_mock_vcf}" == "true" ]]; then
        test_first_chr=true
        for chromosome in ${chromosomes}; do # NB: intentional splitting by space!
            if [[ "${test_first_chr}" == "true" ]]; then
                zcat "${path_sample_test_run}/imputed/chr${chromosome}.vcf.bgz" >> \
                     "${output_imputed_vcf_path}"
                test_first_chr=false
            else
                # exclude headers because various tools get confused by headers data
                # in the middle of the file
                zcat "${path_sample_test_run}/imputed/chr${chromosome}.vcf.bgz" |
                    awk '$0 !~ /^#/' >> "${output_imputed_vcf_path}"
            fi
        done
    else
        # Imputation is not supported for Y and MT chromosomes; for these, we
        # just copy them from the input to the output file.
        for special_case in Y MT; do
            if [[ "${chromosomes}" =~ "${special_case}" ]]; then
                debug "special handling for chromosome ${special_case}: copying to temporary file"
                # remove the special case from the chromosomes list
                chromosomes=${chromosomes//${special_case}/ }
                # extract it from the input file and write to a temporary output
                # file for later recombination
                zcat "${input_vcf_path}" | \
                    awk -v chr="${special_case}" '$1 == chr' > "${output_imputed_vcf_path}-${special_case}"
            fi
        done

        # invoke beagle-leash
        num_processes=$(wc -w <<< "${chromosomes}")
        export BEAGLE_LEASH_CHROMS=${chromosomes}
        "${beagle_leash}" "${input_vcf_path}" "${output_imputed_vcf_path}-tmp.gz" ${num_processes}
        if [[ ! -f "${output_imputed_vcf_path}-tmp.gz" ]]; then
            error "${output_imputed_vcf_path}-tmp.gz missing!"
            exit 1
        fi

        # clean up after beagle-leash in /tmp, because it fills up the disk
        # which is bad on 10GB Fargate containers
        rm -rf /tmp/beagle-leash-*

        # remove entries from the output file which do not match the requested chromosomes
        zcat "${output_imputed_vcf_path}-tmp.gz" | \
            awk -v chr_raw="${chromosomes}" '
              BEGIN {
                 split(chr_raw, chr_values)
                 for (i in chr_values) chr_keys[chr_values[i]] = ""
              }
              /^#/ || $1 in chr_keys
              ' > "${output_imputed_vcf_path}"
        rm -f "${output_imputed_vcf_path}-tmp.gz"

        # put entries from special case files, if any exist, into the output
        for special_case_file in ./"${output_imputed_vcf_path}"-*; do
            if [[ -f "${special_case_file}" ]]; then
                cat "${special_case_file}" >> "${output_imputed_vcf_path}"
                rm -f "${special_case_file}"
            fi
        done
    fi
fi
