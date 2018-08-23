### local AWS environment handling
minio_pid=
minio_workdir=

function minio_start {
    minio_workdir=${basedir}/$(date +"%Y-%m-%d.%H-%M-%S.%N")
    export MINIO_ACCESS_KEY=access-key
    export MINIO_SECRET_KEY=secret-key
    export MINIO_BROWSER=off
    /precisely/aws-local/minio server --config-dir /precisely/aws-local/conf/minio "${minio_workdir}" > /dev/null &
    minio_pid=$!
}

function minio_stop {
    [[ ! -z ${minio_pid} ]] && kill ${minio_pid}
    [[ ! -z "${minio_workdir}" ]] && rm -rf "${minio_workdir}"
}


### cleanup
trap minio_stop EXIT


### output helpers
function say {
    printf " ---> $1\n" 1>&2
}

function say_test_name {
    say "running test: ${FUNCNAME[1]}"
}


### AWS helper
function awss3 {
    aws s3 --endpoint-url="${AWS_S3_ENDPOINT_URL}" $* > /dev/null
}


### test helpers
errors=0
function add_error {
    local err=$1
    if [[ -z "${err}" ]]; then
        err=${FUNCNAME[1]}
    else
        err="${FUNCNAME[1]}: ${err}"
    fi
    say "error: ${err}"
    ((errors++))
}

function report {
    if [[ ${errors} == 0 ]]; then
        say "success"
        exit 0
    else
        say "failures: ${errors}"
        exit 1
    fi
}
