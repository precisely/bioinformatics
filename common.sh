### output helpers
timestamp() {
    date +"%Y-%m-%d %H:%M:%S.%N"
}

log() {
    echo $(timestamp) "[${script}]" $* >&1
}

error() {
    echo $(timestamp) "[${script}] [ERROR]" $* >&2
}

warn() {
    echo $(timestamp) "[${script}] [WARN]" $* >&3
}

info() {
    echo $(timestamp) "[${script}] [INFO]" $* >&4
}

debug() {
    echo $(timestamp) "[${script}] [DEBUG]" $* >&5
}

for fd in 3 4 5; do
    eval "exec ${fd}>&1"
done

with_log() {
    # XXX: The slightly off-putting regex in the awk expression here tries to
    # match the logging format. If the line to log already seems to contain a
    # timestamp and a source, then do not inject it a second time.
    # XXX: This preserves the streams, i.e., stderr remains stderr and stdout
    # remains stdout. The pattern is: open an extra stream (8, because 9 is
    # already used elsewhere in the code, and 3-5 are taken by logging),
    # redirect stderr to 1 and 1 to 8, pipe to stderr command, redirect 8 back
    # to 1, pipe to stdout command.
    local cmd=$(basename $1)
    local awkexp='{
      if ($0 ~ /[0-9]{4}-[0-9]{2}-[0-9]{2} [0-9:\.]{12,} \[.+\]/) { print $0 }
      else { printf "%s [%s] %s\n", timestamp, cmd, $0 }
    }'
    exec 8>&1
    ( $* 2>&1 1>&8 8>&- | awk -v cmd=${cmd} -v timestamp="$(timestamp)" "${awkexp}" ) 8>&1 1>&2 |
        awk -v cmd=${cmd} -v timestamp="$(timestamp)" "${awkexp}"
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
