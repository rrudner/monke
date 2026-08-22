#!/usr/bin/env bash
set -euo pipefail

repo_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
test_root=$(mktemp -d /tmp/scriptorium-context-pressure.XXXXXX)
trap 'rm -rf -- "$test_root"' EXIT
thread_id=01a028d2-097d-7151-a9d7-357424c6e8c1
session_dir=$test_root/codex/sessions/2026/08/22
session_file=$session_dir/rollout-test-$thread_id.jsonl
mkdir -p -- "$session_dir"

write_usage() {
    local input=$1 window=$2
    printf '%s\n' \
        '{"type":"event_msg","payload":{"type":"token_count","info":{"last_token_usage":{"input_tokens":100},"model_context_window":200000}}}' \
        "{\"type\":\"event_msg\",\"payload\":{\"type\":\"token_count\",\"info\":{\"last_token_usage\":{\"input_tokens\":$input},\"model_context_window\":$window}}}" \
        >"$session_file"
}

write_usage 50000 200000
output=$(CODEX_HOME=$test_root/codex CODEX_THREAD_ID=$thread_id \
    "$repo_dir/bin/scodex" context)
[[ $output == 'context_pressure=low input_tokens=50000 context_window=200000 percent=25' ]]

write_usage 120000 200000
output=$(CODEX_HOME=$test_root/codex CODEX_THREAD_ID=$thread_id \
    "$repo_dir/bin/scodex" context)
[[ $output == 'context_pressure=medium input_tokens=120000 context_window=200000 percent=60' ]]

write_usage 160000 200000
output=$(CODEX_HOME=$test_root/codex CODEX_THREAD_ID=$thread_id \
    "$repo_dir/bin/scodex" context)
[[ $output == 'context_pressure=high input_tokens=160000 context_window=200000 percent=80' ]]

printf '%s\n' '{"type":"token_count","malformed":true}' >"$session_file"
output=$(CODEX_HOME=$test_root/codex CODEX_THREAD_ID=$thread_id \
    "$repo_dir/bin/scodex" context)
[[ $output == context_pressure=unknown ]]

output=$(CODEX_HOME=$test_root/codex CODEX_THREAD_ID='../../invalid' \
    "$repo_dir/bin/scodex" context)
[[ $output == context_pressure=unknown ]]

output=$(CODEX_HOME=$test_root/missing CODEX_THREAD_ID=$thread_id \
    "$repo_dir/bin/scodex" context)
[[ $output == context_pressure=unknown ]]

mkdir -p "$test_root/project/.scriptorium"
cat >"$test_root/project/.scriptorium/stats" <<EOF
version=1
thread_id=$thread_id
run_started_at=200
EOF
cat >"$session_file" <<EOF
{"type":"session_meta","payload":{"id":"$thread_id","cwd":"$test_root/project","source":"cli"}}
{"type":"event_msg","payload":{"type":"task_started","started_at":100}}
{"type":"event_msg","payload":{"type":"token_count","info":{"total_token_usage":{"input_tokens":900,"cached_input_tokens":400,"output_tokens":100,"total_tokens":1000},"last_token_usage":{"input_tokens":500,"cached_input_tokens":300,"output_tokens":50,"total_tokens":550},"model_context_window":200000}}}
{"type":"event_msg","payload":{"type":"task_started","started_at":200}}
{"type":"event_msg","payload":{"type":"token_count","info":{"total_token_usage":{"input_tokens":450,"cached_input_tokens":200,"output_tokens":50,"total_tokens":500},"last_token_usage":{"input_tokens":450,"cached_input_tokens":200,"output_tokens":50,"total_tokens":500},"model_context_window":200000}}}
EOF
child_id=01a02923-c4e7-7e33-9954-efaf9b17497c
child_file=$session_dir/rollout-test-$child_id.jsonl
cat >"$child_file" <<EOF
{"type":"session_meta","payload":{"id":"$child_id","parent_thread_id":"$thread_id","source":{"subagent":{}}}}
{"type":"event_msg","payload":{"type":"task_started","started_at":210}}
{"type":"event_msg","payload":{"type":"token_count","info":{"total_token_usage":{"input_tokens":100,"cached_input_tokens":20,"output_tokens":10,"total_tokens":110},"last_token_usage":{"input_tokens":100,"cached_input_tokens":20,"output_tokens":10,"total_tokens":110},"model_context_window":200000}}}
{"type":"event_msg","payload":{"type":"token_count","info":{"total_token_usage":{"input_tokens":500,"cached_input_tokens":120,"output_tokens":60,"total_tokens":560},"last_token_usage":{"input_tokens":400,"cached_input_tokens":100,"output_tokens":50,"total_tokens":450},"model_context_window":200000}}}
EOF
output=$(cd "$test_root/project" && CODEX_HOME=$test_root/codex CODEX_THREAD_ID='' \
    "$repo_dir/bin/scodex" stats)
grep -qx '  Entire thread                    2 060             720' <<<"$output"
grep -qx '  Last scodex run                  1 060             320' <<<"$output"
grep -qx '  Delegates (1 sessions):             560 tokens' <<<"$output"
if (cd "$test_root/project" && CODEX_HOME=$test_root/codex CODEX_THREAD_ID='' \
    "$repo_dir/bin/scodex" stats --raw >/dev/null 2>&1); then
    printf 'stats unexpectedly accepted an argument\n' >&2
    exit 1
fi

printf 'Context pressure smoke tests passed.\n'
