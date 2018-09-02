#!/usr/bin/env bash

set -Eeuo pipefail

readlinkf() { perl -MCwd -e 'print Cwd::abs_path glob shift' "$1"; }
basedir=$(dirname "$(readlinkf $0)")
script=$(basename "${BASH_SOURCE[${#BASH_SOURCE[@]}-1]}")


### parameters
if [[ "$#" -eq 0 ]]; then
    echo "usage: vcf-sqlite-load.sh <input-vcf-path> <output-sqlite-path>" 1>&2
    exit 1
fi

input_vcf_path="$1"
output_sqlite_path="$2"

if [[ -z "${input_vcf_path}" ]]; then
    echo "input VCF file path required" 1>&2
    exit 1
fi

if [[ ! -f "${input_vcf_path}" ]]; then
    echo "input VCF file does not exist" 1>&2
    exit 1
fi

if [[ -z "${output_sqlite_path}" ]]; then
    echo "output SQLite file path required" 1>&2
    exit 1
fi


### set up the SQLite database
if [[ ! -f "${output_sqlite_path}" ]]; then
    sqlite3 "${output_sqlite_path}" <<EOF
create table files (
  filename text,
  ref text,
  start integer,
  entry text
);
create index idx_files_filename on files (filename);
create index idx_files_ref on files (ref);
create index idx_files_start on files (start);
EOF
fi


### prepare the temporary file for SQLite load
tmpfile=$(mktemp ./tmpfile-XXX)


### cleanup
function cleanup {
    if [[ -f "${tmpfile}" ]]; then
        rm -f "${tmpfile}"
    fi
}

trap cleanup EXIT


### massage the input file
input_filename=$(readlinkf "${input_vcf_path}" | xargs basename)
zcat "${input_vcf_path}" | \
    grep -v '^#' | \
    awk -v filename="${input_filename}" '{ \
      printf filename "," $1 "," $2 ","; \
      $1 = ""; \
      $2 = ""; \
      gsub(/^[ ]+/, "", $0); \
      gsub(/,/, " ", $0); \
      print $0 \
    }' > "${tmpfile}"


### load it
sqlite3 "${output_sqlite_path}" <<EOF
.mode csv
.import ${tmpfile} files
EOF
