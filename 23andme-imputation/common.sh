### output helpers
if [[ $(command -v gdate) ]]; then
    datecmd=gdate
else
    if [[ $(uname -s) == "Darwin" ]]; then
        echo "GNU Date required on macOS; install coreutils" >&2
        exit 1
    fi
    datecmd=date
fi

timestamp() {
    local d=$("${datecmd}" -u --rfc-3339=ns)
    echo ${d/ /T}
}

make_message() {
    local text=$*
    # parse the input as JSON, if it parses, great: use the result, in compact
    # form
    local transformed # must assign separately to preserve $? value
    transformed=$(jq -ca '.' <<< "${text}" 2>/dev/null)
    if [[ $? != 0 ]]; then
        # force escapes
        transformed=$(jq -caR '.' <<< "${text}" 2>/dev/null)
    fi
    echo "${transformed}"
}

log() {
    local message=$(make_message $*)
    local output="{\"timestamp\":\"$(timestamp)\",\"script\":\"${script}\",\"message\":${message}}"
    echo "${output}" >&1
}

error() {
    local message=$(make_message $*)
    local output="{\"timestamp\":\"$(timestamp)\",\"script\":\"${script}\",\"level\":\"error\",\"message\":${message}}"
    echo "${output}" >&2
}

warn() {
    local message=$(make_message $*)
    local output="{\"timestamp\":\"$(timestamp)\",\"script\":\"${script}\",\"level\":\"warn\",\"message\":${message}}"
    echo "${output}" >&3
}

info() {
    local message=$(make_message $*)
    local output="{\"timestamp\":\"$(timestamp)\",\"script\":\"${script}\",\"level\":\"info\",\"message\":${message}}"
    echo "${output}" >&4
}

debug() {
    local message=$(make_message $*)
    local output="{\"timestamp\":\"$(timestamp)\",\"script\":\"${script}\",\"level\":\"debug\",\"message\":${message}}"
    echo "${output}" >&5
}

for fd in 3 4 5; do
    eval "exec ${fd}>&1"
done

transform_as_needed() {
    local level=$1
    local cmd=$2
    local input
    local output
    local timestamp=$(timestamp)
    while read -r input; do
        if [[ $(jq 'has("message")' <<< "${input}" 2>/dev/null) == "true" ]]; then
            # input parses as JSON and has message field, so inject:
            # - script info if needed
            # - level if needed
            # - timestamp if needed
            output=$(jq -c --arg cmd "${cmd}" --arg level "${level}" --arg timestamp "${timestamp}" '. | if (.script) then . else . + {script: $cmd} end | if (.level) then . else . + {level: $level} end | if (.timestamp) then . else . + {timestamp: $timestamp} end' <<< "${input}" 2>/dev/null)
        else
            # input does not parse as JSON or does not contain a message field:
            # turn it into valid JSON and proceed
            local transformed=$(jq -caR '.' <<< "${input}" 2>/dev/null)
            output="{\"timestamp\":\"${timestamp}\",\"level\":\"${level}\",\"script\":\"${cmd}\",\"message\":${transformed}}"
        fi
        echo "${output}"
    done
}

with_output_to_log() {
    # XXX: This preserves the streams, i.e., stderr remains stderr and stdout
    # remains stdout. The pattern is: open an extra stream (8, because 9 is
    # already used elsewhere in the code, and 3-5 are taken by logging),
    # redirect stderr to 1 and 1 to 8, pipe to stderr command, redirect 8 back
    # to 1, pipe to stdout command.
    local cmd=$(basename $1)
    exec 8>&1
    ( $* 2>&1 1>&8 8>&- | transform_as_needed error "${cmd}" ) 8>&1 1>&2 |
        transform_as_needed info "${cmd}"
    return ${PIPESTATUS[0]}
}

with_stderr_to_log() {
    # XXX: This preserves the streams, like with_output_to_log, but only
    # transforms stderr. stdout is left alone. This is helpful for commands
    # whose output is important, but may need to write status messages to
    # stderr. They should explicitly use JSON log format output to do this.
    local cmd=$(basename $1)
    exec 8>&1
    ( $* 2>&1 1>&8 8>&- | transform_as_needed error "${cmd}" ) 8>&1 1>&2
    return ${PIPESTATUS[0]}
}


### JSON converter for pairs: turn input like "one two three four" into the
### following JSON object: {"one": "two", "three": "four"}. Only works when jq
### is available.
json_pairs() {
    if [[ $(command -v jq) ]]; then
        echo $* | jq -c '. | split(" ") | [recurse(.[2:];length>1)[0:2]] | map({ (.[0]): .[1] }) | add ' -R
    else
        echo $*
    fi
}
