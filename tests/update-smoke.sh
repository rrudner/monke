#!/usr/bin/env bash
set -euo pipefail

repo_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
test_root=$(mktemp -d /tmp/scriptorium-smoke-update.XXXXXX)
trap 'rm -rf -- "$test_root"' EXIT

work_base=$test_root/work
mkdir -p -- "$work_base"
mkdir -p -- "$work_base/bin"
PATH=$work_base/bin:$PATH

cat >"$work_base/bin/codex" <<'EOF'
#!/usr/bin/env bash
{
    printf 'args:%s\n' "$*"
    printf 'profile:%s\n' "${CODEX_PROFILE-}"
} >>"$CODEX_TEST_LOG"
exit 0
EOF
chmod +x "$work_base/bin/codex"

export PATH

bash -n "$repo_dir/install.sh" "$repo_dir/update.sh" "$repo_dir"/scripts/*.sh \
    "$repo_dir"/codex/scripts/*.sh "$repo_dir"/tmux/scripts/*.sh "$repo_dir"/tests/update-smoke.sh

git_work=$work_base/source
mkdir -p -- "$git_work"
cp -a -- "$repo_dir/install.sh" "$repo_dir/update.sh" "$repo_dir/AGENTS.md" "$repo_dir/README.md" \
    "$repo_dir/bin" "$repo_dir/codex" "$repo_dir/scripts" "$repo_dir/tmux" \
    "$repo_dir/tools" "$repo_dir/tests" "$git_work"/
git -C "$git_work" init -q -b main
git -C "$git_work" config user.email test@example.invalid
git -C "$git_work" config user.name Test
git -C "$git_work" add -A
git -C "$git_work" commit -qm "seed local test repo"
git clone --bare "$git_work" "$work_base/origin.git" > /dev/null
git clone "$work_base/origin.git" "$work_base/local" > /dev/null
git clone "$work_base/origin.git" "$work_base/upstream" > /dev/null

git -C "$work_base/upstream" config user.email test@example.invalid
git -C "$work_base/upstream" config user.name Test
printf 'future\n' >>"$work_base/upstream/file.txt"
printf 'future-tool\tfuture-tool\t-\t0\tadvanced\tFuture tool\tUpdate migration test\n' \
    >>"$work_base/upstream/tools/catalog.tsv"
git -C "$work_base/upstream" add file.txt
git -C "$work_base/upstream" add tools/catalog.tsv
git -C "$work_base/upstream" commit -qm future
git -C "$work_base/upstream" push > /dev/null

codex_log=$test_root/codex.log
HOME=$test_root/home
mkdir -p -- "$HOME/.config/scriptorium"
cat >"$HOME/.config/scriptorium/preferences" <<EOF
repo_dir=$work_base/local
tmux=0
update_check=1
tools=1
shell=bash
shell_rc=
EOF
printf '%s\n' ripgrep fd jq yq shellcheck >"$HOME/.config/scriptorium/tools.selected"

export CODEX_TEST_LOG=$codex_log

# scodex should continue even when update check is unavailable without SCRIPTORIUM_MANUAL_UPDATE
"$repo_dir/scripts/update-repository.sh" >"$test_root/login-update.log"
[[ ! -s "$test_root/login-update.log" ]]

# launch path should invoke codex even when updates are available
before=$(git -C "$work_base/local" rev-parse HEAD)
"$repo_dir/bin/scodex" normal >/dev/null
[[ -s "$codex_log" ]]
grep -q '^args:--profile scriptorium-normal -c shell_environment_policy.inherit=all -c shell_environment_policy.set.PATH="' \
    "$codex_log"

# explicit update should apply remote changes and continue to updated state
CODEX_TEST_LOG=$test_root/update-call.log "$repo_dir/bin/scodex" update \
    >"$test_root/update-output.log"
after=$(git -C "$work_base/local" rev-parse HEAD)
if [[ "$before" == "$after" ]]; then
    printf 'update did not apply\n' >&2
    exit 1
fi
if ! grep -q 'new optional tools are available: future-tool' "$test_root/update-output.log"; then
    printf 'update did not report the new tool:\n' >&2
    head -20 "$test_root/update-output.log" >&2
    exit 1
fi
grep -q '^scodex: downloading repository update$' "$test_root/update-output.log"
grep -q '^scodex: applying the updated configuration$' "$test_root/update-output.log"
grep -q '^scodex: finalizing update$' "$test_root/update-output.log"
grep -qx 'future-tool' \
    "$HOME/.local/state/scriptorium/tools-reconfigure-required"
grep -qx 'ast-grep' \
    "$HOME/.local/state/scriptorium/tools-reconfigure-required"

# Non-interactive launches report the exact additions without clearing the pending review.
CODEX_TEST_LOG=$test_root/pending-launch.log "$repo_dir/bin/scodex" normal \
    >"$test_root/pending-output.log"
grep -q 'new optional tools require your selection: ast-grep,future-tool' \
    "$test_root/pending-output.log"
grep -qx 'future-tool' \
    "$HOME/.local/state/scriptorium/tools-reconfigure-required"

# an explicit selection clears the pending catalog migration
CODEX_TEST_LOG=$test_root/reselect.log "$repo_dir/bin/scodex" tools configure \
    --select ripgrep >/dev/null
[[ ! -e $HOME/.local/state/scriptorium/tools-reconfigure-required ]]

# tools delegation when tools manager is present
cat > "$work_base/local/scripts/tools-manager.sh" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" >>"$CODEX_TEST_LOG"
EOF
chmod +x "$work_base/local/scripts/tools-manager.sh"
CODEX_TEST_LOG=$test_root/tools.log "$repo_dir/bin/scodex" tools inspect >/dev/null
grep -q 'inspect' "$test_root/tools.log"

printf 'smoke tests passed.\n'
