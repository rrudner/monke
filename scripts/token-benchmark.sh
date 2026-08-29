#!/usr/bin/env bash
set -euo pipefail

repo_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
fixture_dir=$repo_dir/tests/fixtures/token-benchmark

usage() {
    cat <<'EOF'
Usage: scripts/token-benchmark.sh COMMAND [OUTPUT_DIR]

Commands:
  prepare              Validate the fixture and print the five prompts (offline)
  run [OUTPUT_DIR]     Run the 5-task baseline/Scriptorium pilot (uses Codex tokens)
  run-one TASK VARIANT OUTPUT_DIR
                       Run one task with baseline or scriptorium (uses Codex tokens)
  report OUTPUT_DIR    Rebuild the Markdown report from collected results
EOF
}

require_command() {
    command -v "$1" >/dev/null 2>&1 || {
        printf 'token-benchmark: required command is unavailable: %s\n' "$1" >&2
        exit 127
    }
}

task_check() {
    case $1 in
        01-analysis) printf '%s' analysis ;;
        02-config-path) printf '%s' config-precedence ;;
        03-repeated-tags) printf '%s' repeated-tags ;;
        04-safe-unpack) printf '%s' safe-unpack ;;
        05-json-report) printf '%s' json-report ;;
        06-broad-trace) printf '%s' analysis-broad ;;
        *) return 1 ;;
    esac
}

show_prompts() {
    local prompt task
    for prompt in "$fixture_dir"/tasks/*.txt; do
        task=${prompt##*/}
        printf '\n[%s]\n' "${task%.txt}"
        sed -n '1,20p' "$prompt"
    done
}

validate_fixture() (
    local work task check expected_failure=0
    work=$(mktemp -d /tmp/scriptorium-token-fixture.XXXXXX)
    trap 'rm -rf -- "$work"' EXIT
    cp -a -- "$fixture_dir/." "$work/"
    chmod +x "$work/bin/tasker" "$work/tests/check.sh"
    git -C "$work" init -q
    git -C "$work" config user.email benchmark@example.invalid
    git -C "$work" config user.name Benchmark
    git -C "$work" add -A
    git -C "$work" commit -qm fixture

    # Task 01 has a known answer; the four implementation checks must initially fail.
    # The disposable fixture path is created above.
    # shellcheck disable=SC1091
    source "$work/lib/tasker.sh"
    unset TASKER_COLOR COLOR
    load_settings "" ""
    [[ $TASKER_EFFECTIVE_COLOR == auto ]]
    for task in 02-config-path 03-repeated-tags 04-safe-unpack 05-json-report; do
        check=$(task_check "$task")
        if "$work/tests/check.sh" "$check" >/dev/null 2>&1; then
            printf 'token-benchmark: fixture check unexpectedly passes: %s\n' "$check" >&2
            expected_failure=1
        fi
    done
    (( expected_failure == 0 ))
    printf 'Offline fixture validation passed. Four seeded checks fail as expected.\n'
)

link_auth() {
    local target_home=$1 source_home=${CODEX_HOME:-"$HOME/.codex"}
    if [[ ! -f $source_home/auth.json ]]; then
        printf 'token-benchmark: Codex authentication not found at %s/auth.json\n' "$source_home" >&2
        exit 1
    fi
    ln -s -- "$source_home/auth.json" "$target_home/auth.json"
}

cleanup_auth_links() {
    local run_dir=$1 auth_link
    while IFS= read -r auth_link; do
        unlink -- "$auth_link"
    done < <(find "$run_dir/homes" "$run_dir/run-homes" -type l -name auth.json 2>/dev/null)
}

write_results_header() {
    printf 'task\tvariant\texit\tquality\tseconds\tdiff_lines\tmain_input\tmain_cached\tmain_output\tmain_reasoning\tmain_total\tall_input\tall_cached\tall_output\tall_reasoning\tall_total\tmain_peak_input\tmain_final_input\tcontext_window\tmain_peak_percent\tchild_sessions\tchild_total\n' \
        >"$1"
}

write_baseline_profile() {
    local target=$1
    cat >"$target/baseline.config.toml" <<'EOF'
approval_policy = "on-request"
approvals_reviewer = "auto_review"
sandbox_mode = "workspace-write"
model = "gpt-5.6-terra"
model_reasoning_effort = "low"
model_reasoning_summary = "none"
model_verbosity = "low"

[agents]
enabled = false
EOF
}

write_scriptorium_benchmark_profile() {
    local target=$1
    cat >"$target" <<'EOF'
approval_policy = "on-request"
approvals_reviewer = "auto_review"
sandbox_mode = "workspace-write"
model = "gpt-5.6-terra"
model_reasoning_effort = "low"
model_reasoning_summary = "none"
model_verbosity = "low"
EOF
}

write_benchmark_preferences() {
    local run_dir=$1
    mkdir -p -- "$run_dir/xdg-config/scriptorium"
    printf 'update_check=0\n' >"$run_dir/xdg-config/scriptorium/preferences"
}

prepare_codex_homes() {
    local run_dir=$1
    local baseline_home=$run_dir/homes/baseline scriptorium_home=$run_dir/homes/scriptorium
    mkdir -p -- "$baseline_home" "$scriptorium_home/agents" \
        "$scriptorium_home/skills/scriptorium-delegate"
    write_benchmark_preferences "$run_dir"
    link_auth "$baseline_home"
    link_auth "$scriptorium_home"
    write_baseline_profile "$baseline_home"
    cp -- "$repo_dir/codex/AGENTS.md" "$scriptorium_home/AGENTS.md"
    write_scriptorium_benchmark_profile "$scriptorium_home/scriptorium.config.toml"
    cp -- "$repo_dir/codex/agents/scriptorium-worker.toml" \
        "$scriptorium_home/agents/scriptorium-worker.toml"
    cp -- "$repo_dir/codex/skills/scriptorium-delegate/SKILL.md" \
        "$scriptorium_home/skills/scriptorium-delegate/SKILL.md"
}

make_worktree() {
    local destination=$1
    mkdir -p -- "$destination"
    cp -a -- "$fixture_dir/." "$destination/"
    chmod +x "$destination/bin/tasker" "$destination/tests/check.sh"
    git -C "$destination" init -q
    git -C "$destination" config user.email benchmark@example.invalid
    git -C "$destination" config user.name Benchmark
    git -C "$destination" add -A
    git -C "$destination" commit -qm fixture
}

score_run() {
    local task=$1 work=$2 last_message=$3 check
    if [[ $task == 01-analysis ]]; then
        if tr '\n' ' ' <"$last_message" | grep -Eiq \
            'default.*(config|file).*(TASKER_COLOR|environment).*(--color|CLI)'; then
            printf '%s' pass
        else
            printf '%s' fail
        fi
        return
    fi
    if [[ $task == 06-broad-trace ]]; then
        if tr '\n' ' ' <"$last_message" | grep -Eiq \
            'intake.*sanitize.*normalize.*enrich.*persist.*notify.*complete'; then
            printf '%s' pass
        else
            printf '%s' fail
        fi
        return
    fi
    check=$(task_check "$task")
    if "$work/tests/check.sh" "$check" >/dev/null 2>&1; then
        printf '%s' pass
    else
        printf '%s' fail
    fi
}

session_usage_for_file() {
    jq -sr '[.[] | select(.payload.type? == "token_count"
            and .payload.info.total_token_usage? != null)] as $events
        | if ($events | length) == 0 then empty else
            ($events[-1].payload.info.total_token_usage) as $total
            | [$total.input_tokens, $total.cached_input_tokens, $total.output_tokens,
               $total.reasoning_output_tokens, $total.total_tokens,
               ([$events[].payload.info.last_token_usage.input_tokens? // 0] | max),
               ($events[-1].payload.info.last_token_usage.input_tokens? // 0),
               ($events[-1].payload.info.model_context_window? // 0)] | @tsv
          end' "$1"
}

collect_usage() {
    local codex_home=$1 event_log=$2 session_id file usage
    local main='0\t0\t0\t0\t0\t0\t0\t0' total_input=0 total_cached=0 total_output=0 total_reasoning=0 total=0
    local main_found=0 session_count=0 main_peak=0 main_final=0 main_window=0 main_percent=0
    session_id=$(jq -r 'select(.type? == "thread.started") | .thread_id // empty' "$event_log" | head -1)
    while IFS= read -r file; do
        usage=$(session_usage_for_file "$file")
        [[ -n $usage ]] || continue
        IFS=$'\t' read -r input cached output reasoning sum peak final window <<<"$usage"
        (( session_count += 1 ))
        (( total_input += input, total_cached += cached, total_output += output,
            total_reasoning += reasoning, total += sum ))
        if [[ -n $session_id ]] && grep -Fq -- "$session_id" "$file"; then
            main=$usage
            main_found=1
            main_peak=$peak
            main_final=$final
            main_window=$window
        fi
    done < <(find "$codex_home/sessions" -type f -name '*.jsonl' 2>/dev/null | sort)
    if (( total == 0 || main_found == 0 )); then
        printf 'token-benchmark: no token telemetry found in %s\n' "$codex_home" >&2
        return 1
    fi
    if (( main_window > 0 )); then
        main_percent=$(( main_peak * 100 / main_window ))
    fi
    IFS=$'\t' read -r main_input main_cached main_output main_reasoning main_total \
        _ _ _ <<<"$main"
    printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s' \
        "$main_input" "$main_cached" "$main_output" "$main_reasoning" "$main_total" \
        "$total_input" "$total_cached" "$total_output" "$total_reasoning" "$total" \
        "$main_peak" "$main_final" "$main_window" "$main_percent" \
        "$(( session_count - 1 ))" "$(( total - main_total ))"
}

run_one() {
    local run_dir=$1 variant=$2 task=$3
    local work=$run_dir/work/$task-$variant codex_home=$run_dir/run-homes/$task-$variant
    local prompt=$fixture_dir/tasks/$task.txt events=$run_dir/events/$task-$variant.jsonl
    local message=$run_dir/messages/$task-$variant.txt status=0 quality duration_start duration usage diff_lines
    local -a sandbox_args=()
    [[ $task != 01-analysis && $task != 06-broad-trace ]] || sandbox_args=(-s read-only)
    make_worktree "$work"
    mkdir -p -- "$codex_home"
    cp -a -- "$run_dir/homes/$variant/." "$codex_home/"
    duration_start=$(date +%s)
    if [[ $variant == baseline ]]; then
        CODEX_HOME=$codex_home XDG_CONFIG_HOME=$run_dir/xdg-config \
            codex --profile baseline exec -C "$work" "${sandbox_args[@]}" --json \
            --output-last-message "$message" - <"$prompt" >"$events" 2>"$events.stderr" || status=$?
    else
        CODEX_HOME=$codex_home XDG_CONFIG_HOME=$run_dir/xdg-config \
            "$repo_dir/bin/scodex" exec -C "$work" "${sandbox_args[@]}" --json \
            --output-last-message "$message" - <"$prompt" >"$events" 2>"$events.stderr" || status=$?
    fi
    duration=$(( $(date +%s) - duration_start ))
    [[ -f $message ]] || : >"$message"
    quality=$(score_run "$task" "$work" "$message")
    usage=$(collect_usage "$codex_home" "$events")
    diff_lines=$(git -C "$work" diff --numstat | awk '{ added += $1; removed += $2 } END { print added + removed + 0 }')
    printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\n' "$task" "$variant" "$status" "$quality" \
        "$duration" "$diff_lines" "$usage" >>"$run_dir/results.tsv"
}

write_report() {
    local run_dir=$1
    local results=$run_dir/results.tsv report=$run_dir/report.md has_extended
    [[ -f $results ]] || { printf 'token-benchmark: results not found: %s\n' "$results" >&2; exit 1; }
    has_extended=$(awk -F '\t' 'NR == 1 { print ($17 == "main_peak_input") }' "$results")
    {
        printf '# Codex token benchmark\n\n'
        printf '## Summary\n\n'
        printf '| Variant | Passed | Seconds | Main total | Main uncached input | Main median | Peak context | Child sessions | Child tokens | All total | All uncached input | All median |\n'
        printf '|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|\n'
        for variant in baseline scriptorium; do
            runs=$(awk -F '\t' -v variant="$variant" 'NR > 1 && $2 == variant { count++ } END { print count + 0 }' "$results")
            passed=$(awk -F '\t' -v variant="$variant" 'NR > 1 && $2 == variant && $4 == "pass" { count++ } END { print count + 0 }' "$results")
            seconds=$(awk -F '\t' -v variant="$variant" 'NR > 1 && $2 == variant { sum += $5 } END { print sum + 0 }' "$results")
            main_sum=$(awk -F '\t' -v variant="$variant" 'NR > 1 && $2 == variant { sum += $11 } END { print sum + 0 }' "$results")
            main_uncached=$(awk -F '\t' -v variant="$variant" 'NR > 1 && $2 == variant { sum += $7 - $8 } END { print sum + 0 }' "$results")
            all_sum=$(awk -F '\t' -v variant="$variant" 'NR > 1 && $2 == variant { sum += $16 } END { print sum + 0 }' "$results")
            all_uncached=$(awk -F '\t' -v variant="$variant" 'NR > 1 && $2 == variant { sum += $12 - $13 } END { print sum + 0 }' "$results")
            main_median=$(awk -F '\t' -v variant="$variant" 'NR > 1 && $2 == variant { print $11 }' "$results" \
                | sort -n | awk '{ value[NR]=$1 } END { if (NR) print value[int((NR + 1) / 2)]; else print 0 }')
            all_median=$(awk -F '\t' -v variant="$variant" 'NR > 1 && $2 == variant { print $16 }' "$results" \
                | sort -n | awk '{ value[NR]=$1 } END { if (NR) print value[int((NR + 1) / 2)]; else print 0 }')
            if [[ $has_extended == 1 ]]; then
                peak_context=$(awk -F '\t' -v variant="$variant" 'NR > 1 && $2 == variant && $20 > max { max=$20 } END { print max + 0 }' "$results")%
                child_sessions=$(awk -F '\t' -v variant="$variant" 'NR > 1 && $2 == variant { sum += $21 } END { print sum + 0 }' "$results")
                child_tokens=$(awk -F '\t' -v variant="$variant" 'NR > 1 && $2 == variant { sum += $22 } END { print sum + 0 }' "$results")
            else
                peak_context=n/a
                child_sessions=n/a
                child_tokens=$(awk -F '\t' -v variant="$variant" 'NR > 1 && $2 == variant { sum += $16 - $11 } END { print sum + 0 }' "$results")
            fi
            printf '| %s | %s/%s | %s | %s | %s | %s | %s | %s | %s | %s | %s | %s |\n' \
                "$variant" "$passed" "$runs" "$seconds" "$main_sum" "$main_uncached" \
                "$main_median" "$peak_context" "$child_sessions" "$child_tokens" "$all_sum" \
                "$all_uncached" "$all_median"
        done
        printf '\n## Runs\n\n'
        printf '| Task | Variant | Exit | Quality | Seconds | Diff | Main input | Main cached | Main output | Main reasoning | Main total | All input | All cached | All output | All reasoning | All total | Peak input | Final input | Window | Peak | Children | Child tokens |\n'
        printf '|---|---|---:|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|\n'
        tail -n +2 "$results" | while IFS=$'\t' read -r task variant status quality seconds diff \
            main_input main_cached main_output main_reasoning main_total all_input all_cached \
            all_output all_reasoning all_total main_peak main_final context_window peak_percent \
            child_sessions child_total; do
            if [[ $has_extended != 1 ]]; then
                main_peak=n/a; main_final=n/a; context_window=n/a; peak_percent=n/a
                child_sessions=n/a; child_total=$(( all_total - main_total ))
            else
                peak_percent=${peak_percent:-0}%
            fi
            printf '| %s | %s | %s | %s | %s | %s | %s | %s | %s | %s | %s | %s | %s | %s | %s | %s | %s | %s | %s | %s | %s | %s |\n' \
                "$task" "$variant" "$status" "$quality" "$seconds" "$diff" "$main_input" \
                "$main_cached" "$main_output" "$main_reasoning" "$main_total" "$all_input" \
                "$all_cached" "$all_output" "$all_reasoning" "$all_total" "${main_peak:-0}" \
                "${main_final:-0}" "${context_window:-0}" "${peak_percent:-0}" \
                "${child_sessions:-0}" "${child_total:-0}"
        done
        printf '\nPilot only: one run per task and variant; differences are directional, not statistically significant.\n'
    } >"$report"
    printf 'Report written to %s\n' "$report"
}

run_benchmark() (
    local run_dir=${1:-/tmp/scriptorium-token-benchmark-$(date +%Y%m%dT%H%M%S)}
    local prompt task first second
    require_command codex
    require_command jq
    require_command git
    if [[ -e $run_dir ]]; then
        printf 'token-benchmark: output path already exists: %s\n' "$run_dir" >&2
        exit 1
    fi
    mkdir -p -- "$run_dir/events" "$run_dir/messages" "$run_dir/work" "$run_dir/xdg-config"
    trap 'cleanup_auth_links "$run_dir"' EXIT
    prepare_codex_homes "$run_dir"
    write_results_header "$run_dir/results.tsv"
    for prompt in "$fixture_dir"/tasks/*.txt; do
        task=${prompt##*/}; task=${task%.txt}
        if (( 10#${task%%-*} % 2 )); then
            first=baseline; second=scriptorium
        else
            first=scriptorium; second=baseline
        fi
        run_one "$run_dir" "$first" "$task"
        run_one "$run_dir" "$second" "$task"
    done
    write_report "$run_dir"
)

run_single() (
    local task=$1 variant=$2 run_dir=$3
    require_command codex
    require_command jq
    require_command git
    [[ -f $fixture_dir/tasks/$task.txt ]] || {
        printf 'token-benchmark: unknown task: %s\n' "$task" >&2
        exit 2
    }
    [[ $variant == baseline || $variant == scriptorium ]] || {
        printf 'token-benchmark: variant must be baseline or scriptorium\n' >&2
        exit 2
    }
    [[ ! -e $run_dir ]] || {
        printf 'token-benchmark: output path already exists: %s\n' "$run_dir" >&2
        exit 1
    }
    mkdir -p -- "$run_dir/events" "$run_dir/messages" "$run_dir/work" "$run_dir/xdg-config"
    trap 'cleanup_auth_links "$run_dir"' EXIT
    prepare_codex_homes "$run_dir"
    write_results_header "$run_dir/results.tsv"
    run_one "$run_dir" "$variant" "$task"
    write_report "$run_dir"
)

case ${1:-} in
    prepare)
        require_command git
        validate_fixture
        show_prompts
        ;;
    run) run_benchmark "${2:-}" ;;
    run-one) [[ $# -eq 4 ]] || { usage >&2; exit 2; }; run_single "$2" "$3" "$4" ;;
    report) [[ $# -eq 2 ]] || { usage >&2; exit 2; }; write_report "$2" ;;
    -h|--help|help) usage ;;
    *) usage >&2; exit 2 ;;
esac
