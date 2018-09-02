#!/usr/bin/env bash

set -e
set -o pipefail

readlinkf() { perl -MCwd -e 'print Cwd::abs_path glob shift' "$1"; }
basedir=$(dirname "$(readlinkf $0)")
script=$(basename "${BASH_SOURCE[${#BASH_SOURCE[@]}-1]}")


# This script takes an imputed dataset and miniaturizes it by throwing away most
# of the data. It's useful for making a test-size dataset to work with.


### parameters
if [[ "$#" -eq 0 ]]; then
    echo "usage: miniaturize-imputation-dataset.sh <imputed-vcf-path> <output-vcf-path>" 1>&2
    exit 1
fi

imputed_vcf_path="$1"
output_vcf_path="$2"

if [[ -z "${imputed_vcf_path}" ]]; then
    echo "imputed VCF directory path required" 1>&2
    exit 1
fi

if [[ ! -d "${imputed_vcf_path}" ]]; then
    echo "imputed VCF directory path does not exit" 1>&2
    exit 1
fi

if [[ -z "${output_vcf_path}" ]]; then
    echo "output VCF directory path required" 1>&2
    exit 1
fi

if [[ -e "${output_vcf_path}" ]]; then
    echo "output VCF directory already exists" 1>&2
    exit 1
fi


### run
echo "copying '${imputed_vcf_path}' to '${output_vcf_path}'..."
cp -R "${imputed_vcf_path}" "${output_vcf_path}"
pushd "${output_vcf_path}"
echo "removing existing Tabix index files..."
rm -f *.tbi
for f in *.bgz; do
    [ -e "${f}" ] || continue
    base=$(basename "${f}" .bgz)
    echo "processing ${base}..."
    set +e
    zcat "${f}" | head -500 | bgzip > "${base}-tmp.bgz"
    set -e
    rm -f "${base}.bgz"
    mv "${base}-tmp.bgz" "${base}.bgz"
    echo "creating new Tabix index..."
    tabix -p vcf "${base}.bgz"
done
echo "done"
