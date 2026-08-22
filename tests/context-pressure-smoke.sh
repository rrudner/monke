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

printf 'Context pressure smoke tests passed.\n'
