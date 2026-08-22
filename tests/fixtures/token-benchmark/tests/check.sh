#!/usr/bin/env bash
set -euo pipefail

fixture_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
tasker=$fixture_dir/bin/tasker
case ${1:-all} in
    config-precedence)
        settings_dir=$(mktemp -d /tmp/tasker-settings.XXXXXX)
        trap 'rm -rf -- "$settings_dir"' EXIT
        printf 'COLOR=file\n' >"$settings_dir/settings file"
        [[ $($tasker --config "$settings_dir/settings file" report | head -1) == color=file ]]
        [[ $(TASKER_COLOR=environment $tasker --config "$settings_dir/settings file" report | head -1) == color=environment ]]
        [[ $(TASKER_COLOR=environment $tasker --config "$settings_dir/settings file" --color cli report | head -1) == color=cli ]]
        ;;
    repeated-tags)
        [[ $($tasker report | tail -1) == tags= ]]
        [[ $($tasker --tag one report | tail -1) == tags=one ]]
        [[ $($tasker --tag one --tag 'two words' --tag three report | tail -1) == 'tags=one two words three' ]]
        ;;
    safe-unpack)
        command -v tar >/dev/null
        test_dir=$(mktemp -d /tmp/tasker-archive.XXXXXX)
        trap 'rm -rf -- "$test_dir"' EXIT
        mkdir -p -- "$test_dir/source" "$test_dir/output"
        printf 'ok\n' >"$test_dir/source/good.txt"
        tar -C "$test_dir/source" -cf "$test_dir/good.tar" good.txt
        $tasker unpack "$test_dir/good.tar" "$test_dir/output"
        [[ -f $test_dir/output/good.txt ]]
        printf '../escape.txt\n' >"$test_dir/list"
        tar -C "$test_dir/source" -cf "$test_dir/bad.tar" --transform='s|good.txt|../escape.txt|' good.txt
        if $tasker unpack "$test_dir/bad.tar" "$test_dir/rejected" >/dev/null 2>&1; then
            printf 'Unsafe archive was accepted.\n' >&2
            exit 1
        fi
        [[ ! -e $test_dir/rejected && ! -e $test_dir/escape.txt ]]
        tar -C "$test_dir/source" -cf "$test_dir/absolute.tar" \
            --transform='s|good.txt|/tmp/tasker-absolute-escape.txt|' good.txt
        if $tasker unpack "$test_dir/absolute.tar" "$test_dir/absolute-rejected" >/dev/null 2>&1; then
            printf 'Archive with an absolute member was accepted.\n' >&2
            exit 1
        fi
        [[ ! -e $test_dir/absolute-rejected && ! -e /tmp/tasker-absolute-escape.txt ]]
        ;;
    json-report)
        output=$($tasker --color 'blue"shade' --tag 'one two' report --json)
        command -v jq >/dev/null
        jq -e '.color == "blue\"shade" and .tags == ["one two"] and .status == "ok"' \
            <<<"$output" >/dev/null
        [[ $(grep -c '^json_escape()' "$fixture_dir/lib/tasker.sh") -eq 1 ]]
        ;;
    all)
        "$0" config-precedence
        "$0" repeated-tags
        "$0" safe-unpack
        "$0" json-report
        ;;
    *) printf 'Unknown check: %s\n' "$1" >&2; exit 2 ;;
esac
