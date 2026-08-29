#!/usr/bin/env bash
set -euo pipefail

repo_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
test_root=$(mktemp -d /tmp/monke-developer-instructions.XXXXXX)
trap 'rm -rf -- "$test_root"' EXIT
mkdir -p -- "$test_root/bin" "$test_root/home/.config/monke"

cat >"$test_root/bin/codex" <<'EOF'
#!/usr/bin/env bash
for arg in "$@"; do
    printf '%s\0' "$arg" >>"$CODEX_ARGS_LOG"
    if [[ -n ${CODEX_TURNS_LOG:-} && $arg == developer_instructions=* ]]; then
        printf 'turn-1:%s\nturn-2:%s\n' "$arg" "$arg" >"$CODEX_TURNS_LOG"
    fi
done
EOF
chmod +x "$test_root/bin/codex"

write_preferences() {
    local path=$1 enabled=${2:-1}
    cat >"$test_root/home/.config/monke/preferences" <<EOF
repo_dir=$repo_dir
update_check=0
tools=0
developer_instructions=$enabled
developer_instructions_file=$path
EOF
}

launch() {
    : >"$test_root/args.log"
    PATH="$test_root/bin:$PATH" HOME="$test_root/home" \
        CODEX_ARGS_LOG="$test_root/args.log" "$repo_dir/bin/monke" \
        >"$test_root/stdout.log" 2>"$test_root/stderr.log"
}

assert_single_value() {
    local expected=$1 arg count=0 value=
    while IFS= read -r -d '' arg; do
        if [[ $arg == developer_instructions=* ]]; then
            count=$((count + 1))
            value=$arg
        fi
    done <"$test_root/args.log"
    [[ $count -eq 1 && $value == "$expected" ]]
}

assert_skipped_with_warning() {
    local arg
    while IFS= read -r -d '' arg; do
        [[ $arg != developer_instructions=* ]]
    done <"$test_root/args.log"
    [[ $(grep -c '^monke: developer instructions unavailable; continuing without them\.$' \
        "$test_root/stderr.log") -eq 1 ]]
}

plain_file=$test_root/plain.txt
printf 'Line 1\n"quote" \\ slash $() `tick`\ttab\rCR\n\n' >"$plain_file"
write_preferences "$plain_file"
launch
expected='developer_instructions="You are Monke, not Codex.\n\nLine 1\n\"quote\" \\ slash $() `tick`\ttab\rCR\n\n"'
assert_single_value "$expected"

mkdir -p "$test_root/home/instructions"
skill_file=$test_root/home/instructions/SKILL.md
printf '%s\n' '---' 'name: test' 'description: test skill' '---' \
    'Body line 1' 'Body $HOME `literal` \ path' >"$skill_file"
# shellcheck disable=SC2088
tilde_skill='~/instructions/SKILL.md'
write_preferences "$tilde_skill"
launch
assert_single_value 'developer_instructions="You are Monke, not Codex.\n\nBody line 1\nBody $HOME `literal` \\ path\n"'

write_preferences "$test_root/missing.txt"
launch
assert_skipped_with_warning

: >"$test_root/empty.txt"
write_preferences "$test_root/empty.txt"
launch
assert_skipped_with_warning

mkdir -p "$test_root/bad"
printf '%s\n' 'not-frontmatter' 'Body' >"$test_root/bad/SKILL.md"
write_preferences "$test_root/bad/SKILL.md"
launch
assert_skipped_with_warning

mkdir -p "$test_root/malformed"
printf '%s\n' '---' 'name: incomplete' 'Body' >"$test_root/malformed/SKILL.md"
write_preferences "$test_root/malformed/SKILL.md"
launch
assert_skipped_with_warning

mkdir -p "$test_root/empty-body"
printf '%s\n' '---' 'name: empty' '---' >"$test_root/empty-body/SKILL.md"
write_preferences "$test_root/empty-body/SKILL.md"
launch
assert_skipped_with_warning

printf 'blocked\n' >"$test_root/unreadable.txt"
chmod 000 "$test_root/unreadable.txt"
write_preferences "$test_root/unreadable.txt"
launch
if [[ -r $test_root/unreadable.txt ]]; then
    write_preferences "$test_root"
    launch
fi
assert_skipped_with_warning
chmod 600 "$test_root/unreadable.txt"

write_preferences "$plain_file" 0
launch
while IFS= read -r -d '' arg; do
    [[ $arg != developer_instructions=* ]]
done <"$test_root/args.log"
[[ ! -s $test_root/stderr.log ]]

fifo=$test_root/instructions.fifo
mkfifo "$fifo"
write_preferences "$fifo"
: >"$test_root/read-count"
(
    printf 'one session value\n' >"$fifo"
    printf 'read\n' >>"$test_root/read-count"
) &
producer_pid=$!
: >"$test_root/args.log"
PATH="$test_root/bin:$PATH" HOME="$test_root/home" \
    CODEX_ARGS_LOG="$test_root/args.log" CODEX_TURNS_LOG="$test_root/turns.log" \
    "$repo_dir/bin/monke" >"$test_root/stdout.log" 2>"$test_root/stderr.log"
wait "$producer_pid"
[[ $(wc -l <"$test_root/read-count") -eq 1 ]]
turn_value='developer_instructions="You are Monke, not Codex.\n\none session value\n"'
mapfile -t turns <"$test_root/turns.log"
[[ ${#turns[@]} -eq 2 ]]
[[ ${turns[0]} == "turn-1:$turn_value" ]]
[[ ${turns[1]} == "turn-2:$turn_value" ]]

printf 'developer instructions smoke tests passed.\n'
