#!/usr/bin/env bash
set -euo pipefail

repo_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
test_root=$(mktemp -d /tmp/scriptorium-token-benchmark-smoke.XXXXXX)
trap 'rm -rf -- "$test_root"' EXIT

bash -n "$repo_dir/scripts/token-benchmark.sh" \
    "$repo_dir/tests/fixtures/token-benchmark/bin/tasker" \
    "$repo_dir/tests/fixtures/token-benchmark/lib/tasker.sh" \
    "$repo_dir/tests/fixtures/token-benchmark/tests/check.sh"

"$repo_dir/scripts/token-benchmark.sh" prepare >"$test_root/prepare.log"
grep -q '^Offline fixture validation passed\.' "$test_root/prepare.log"
[[ $(grep -c '^\[0[1-6]-' "$test_root/prepare.log") -eq 6 ]]
grep -q 'Repeated --tag options' "$test_root/prepare.log"

# Exercise the complete runner with a fake Codex so isolation and reporting remain offline.
mkdir -p -- "$test_root/bin" "$test_root/source-codex-home"
printf '{}\n' >"$test_root/source-codex-home/auth.json"
cat >"$test_root/bin/codex" <<'EOF'
#!/usr/bin/env bash
output_message=
while (( $# )); do
    case $1 in
        --output-last-message) output_message=$2; shift 2 ;;
        *) shift ;;
    esac
done
printf '%s\n' "$CODEX_HOME" >>"$BENCHMARK_CODEX_LOG"
[[ -z $output_message ]] || printf 'default config TASKER_COLOR --color load_settings\n' >"$output_message"
mkdir -p -- "$CODEX_HOME/sessions"
cat >"$CODEX_HOME/sessions/fake.jsonl" <<'JSON'
{"payload":{"id":"fake","type":"session_meta"}}
{"payload":{"type":"token_count","info":{"total_token_usage":{"input_tokens":10,"cached_input_tokens":2,"output_tokens":3,"reasoning_output_tokens":1,"total_tokens":13},"last_token_usage":{"input_tokens":8},"model_context_window":100}}}
JSON
printf '{"type":"thread.started","thread_id":"fake"}\n'
EOF
chmod +x "$test_root/bin/codex"

PATH=$test_root/bin:$PATH CODEX_HOME=$test_root/source-codex-home \
    BENCHMARK_CODEX_LOG=$test_root/codex-homes.log \
    "$repo_dir/scripts/token-benchmark.sh" run "$test_root/run" >/dev/null
[[ $(wc -l <"$test_root/codex-homes.log") -eq 12 ]]
[[ $(sort -u "$test_root/codex-homes.log" | wc -l) -eq 12 ]]
[[ ! -e $test_root/run/homes/baseline/AGENTS.md ]]
[[ -f $test_root/run/homes/scriptorium/AGENTS.md ]]
[[ ! -e $test_root/run/homes/baseline/auth.json ]]
[[ ! -e $test_root/run/homes/scriptorium/auth.json ]]
[[ $(tail -n +2 "$test_root/run/results.tsv" | wc -l) -eq 12 ]]
grep -q '^# Codex token benchmark$' "$test_root/run/report.md"
grep -q '| baseline | 1/6 |' "$test_root/run/report.md"
grep -q '| 8% | 0 | 0 |' "$test_root/run/report.md"

PATH=$test_root/bin:$PATH CODEX_HOME=$test_root/source-codex-home \
    BENCHMARK_CODEX_LOG=$test_root/single-codex-home.log \
    "$repo_dir/scripts/token-benchmark.sh" run-one 02-config-path scriptorium \
    "$test_root/single" >/dev/null
[[ $(wc -l <"$test_root/single-codex-home.log") -eq 1 ]]
grep -q '| scriptorium | 0/1 |' "$test_root/single/report.md"

printf 'Token benchmark smoke tests passed.\n'
