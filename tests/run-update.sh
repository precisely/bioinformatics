#!/usr/bin/env bash

set -Eeo pipefail

readlinkf() { perl -MCwd -e 'print Cwd::abs_path glob shift' "$1"; }
basedir=$(dirname "$(readlinkf $0)")
script=$(basename "${BASH_SOURCE[${#BASH_SOURCE[@]}-1]}")


. "${basedir}/common-tests.sh"


### configuration
export S3_BUCKET_BIOINFORMATICS_UPLOAD=test-precisely-bioinformatics-upload
export S3_BUCKET_BIOINFORMATICS_VCF=test-precisely-bioinformatics-vcf
export AWS_REGION=us-east-1
export AWS_S3_ENDPOINT_URL=http://localhost:9000
export AWS_ACCESS_KEY_ID=access-key
export AWS_SECRET_ACCESS_KEY=secret-key


### helpers
function before {
    minio_start
    awss3 mb s3://${S3_BUCKET_BIOINFORMATICS_UPLOAD}
    awss3 mb s3://${S3_BUCKET_BIOINFORMATICS_VCF}
    cp -R /precisely/data/samples/2018-08-16-imputation-run-abeeler-miniaturized/* "${minio_workdir}/${S3_BUCKET_BIOINFORMATICS_VCF}/"
}

function after {
    minio_stop
}


### run
function test_overall_functionality {
    say_test_name
    before
    script_workdir=$(
        eval \
            "${basedir}/../run-update.sh" --data-source=23andme --stage=test --test-mock-lambda=true --cleanup-after=false 2>&1 9>&1 1>/dev/null)
    abeeler1=${script_workdir}/abeeler1/a5cef5de111d61d4e8f57f0ab6166a1d8279cdc419f414383d8505efe74704f0
    [[ -f "${abeeler1}/chr1.vcf.bgz" &&
           -f "${abeeler1}/chr1.vcf.bgz.tbi" &&
           -f "${abeeler1}/chr2.vcf.bgz" &&
           -f "${abeeler1}/chr2.vcf.bgz.tbi" &&
           -f "${abeeler1}/chr4.vcf.bgz" &&
           -f "${abeeler1}/chr4.vcf.bgz.tbi" ]] || add_error "abeeler1 has missing files"
    abeeler2=${script_workdir}/abeeler2/cafe1234
    [[ -f "${abeeler2}/chr1.vcf.bgz" &&
           -f "${abeeler2}/chr1.vcf.bgz.tbi" &&
           -f "${abeeler2}/chr2.vcf.bgz" &&
           -f "${abeeler2}/chr2.vcf.bgz.tbi" &&
           -f "${abeeler2}/chr4.vcf.bgz" &&
           -f "${abeeler2}/chr4.vcf.bgz.tbi" ]] || add_error "abeeler2 has missing files"
    [[ -f "${script_workdir}/aws-invoke-SysGetVariantRequirements.json" &&
           -f "${script_workdir}/aws-invoke-SysUpdateVariantRequirementStatuses.json" &&
           -f "${script_workdir}/aws-invoke-VariantCallBatchCreate.json" &&
           -f "${script_workdir}/new-batch.json" &&
           -f "${script_workdir}/new-call-variants-abeeler1.json" &&
           -f "${script_workdir}/new-call-variants-abeeler2.json" &&
           -f "${script_workdir}/variant-batch-results.json" &&
           -f "${script_workdir}/variant-reqs-new.json" &&
           -f "${script_workdir}/variant-reqs-update-results.json" &&
           -f "${script_workdir}/variant-reqs-update.json" ]] || add_error "intermediate JSON files missing"
    rm -rf "${script_workdir}"
    after
}

test_overall_functionality

report
