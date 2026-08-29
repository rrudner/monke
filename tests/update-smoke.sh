#!/usr/bin/env bash
set -euo pipefail

repo_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
test_root=$(mktemp -d /tmp/monke-smoke-update.XXXXXX)
trap 'rm -rf -- "$test_root"' EXIT

work_base=$test_root/work
mkdir -p -- "$work_base"
mkdir -p -- "$work_base/bin"
PATH=$work_base/bin:/usr/bin:/bin

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

bash -n "$repo_dir/install.sh" "$repo_dir"/scripts/*.sh \
    "$repo_dir"/codex/scripts/*.sh "$repo_dir"/tests/update-smoke.sh

git_work=$work_base/source
mkdir -p -- "$git_work"
cp -a -- "$repo_dir/install.sh" "$repo_dir/AGENTS.md" "$repo_dir/README.md" \
    "$repo_dir/.agents" "$repo_dir/bin" "$repo_dir/codex" "$repo_dir/scripts" \
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
printf 'future-tool\tfuture-tool\t-\t0\tadvanced\tFuture tool\tUpdate migration test\tUse for update migration tests.\n' \
    >>"$work_base/upstream/tools/catalog.tsv"
git -C "$work_base/upstream" add file.txt
git -C "$work_base/upstream" add tools/catalog.tsv
git -C "$work_base/upstream" commit -qm future
git -C "$work_base/upstream" push > /dev/null

codex_log=$test_root/codex.log
HOME=$test_root/home
mkdir -p -- "$HOME/.config/monke"
cat >"$HOME/.config/monke/preferences" <<EOF
repo_dir=$work_base/local
tools=1
update_check=1
shell=bash
shell_rc=
developer_instructions_file=$work_base/local/.agents/skills/monke-language/SKILL.md
EOF
printf '%s\n' ripgrep fd jq yq shellcheck >"$HOME/.config/monke/tools.selected"

export CODEX_TEST_LOG=$codex_log

# The repository updater runs only through the launcher.
"$repo_dir/scripts/update-repository.sh" >"$test_root/login-update.log"
[[ ! -s "$test_root/login-update.log" ]]

# launch path should invoke codex even when updates are available
before=$(git -C "$work_base/local" rev-parse HEAD)
"$repo_dir/bin/monke" >/dev/null
[[ -s "$codex_log" ]]
grep -q '^args:--profile monke -c shell_environment_policy.inherit=all -c shell_environment_policy.set.PATH="' \
    "$codex_log"

# Interactive startup should apply an update, restart once, and continue to Codex.
printf '1\n\n' | CODEX_TEST_LOG=$test_root/update-call.log \
    script -qec "'$repo_dir/bin/monke'" /dev/null >"$test_root/update-output.log"
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
grep -q 'monke: downloading repository update' "$test_root/update-output.log"
grep -q 'monke: applying the updated configuration' "$test_root/update-output.log"
grep -q 'monke: finalizing update' "$test_root/update-output.log"
grep -qx 'tools=1' "$HOME/.config/monke/preferences"
grep -qx 'developer_instructions=1' "$HOME/.config/monke/preferences"
grep -Fxq "developer_instructions_file=$work_base/local/codex/developer-instructions.md" \
    "$HOME/.config/monke/preferences"
grep -q $'^ripgrep\tsystem\t' "$HOME/.config/monke/tools.state"
# Interactive restart reviews and clears the pending catalog migration.
[[ ! -e $HOME/.local/state/monke/tools-reconfigure-required ]]
! grep -qx future-tool "$HOME/.config/monke/tools.selected"

# The short tools command remains the public status view.
"$repo_dir/bin/monke" tools >"$test_root/tools-status.log"
grep -q '^ripgrep ' "$test_root/tools-status.log"

# tools delegation when tools manager is present
cat > "$work_base/local/scripts/tools-manager.sh" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" >>"$CODEX_TEST_LOG"
EOF
chmod +x "$work_base/local/scripts/tools-manager.sh"
CODEX_TEST_LOG=$test_root/tools.log "$repo_dir/bin/monke" tools inspect >/dev/null
grep -q 'inspect' "$test_root/tools.log"

# Interactive startup offers to replace managed tools when system copies appear.
cat >"$work_base/local/scripts/tools-manager.sh" <<'EOF'
#!/usr/bin/env bash
case ${1:-} in
    system-replacements) printf 'gh\n' ;;
    adopt-system) printf 'adopt-system\n' >>"$CODEX_TEST_LOG" ;;
    *) printf '%s\n' "$*" >>"$CODEX_TEST_LOG" ;;
esac
EOF
chmod +x "$work_base/local/scripts/tools-manager.sh"
printf '\n' | CODEX_TEST_LOG=$test_root/system-replacement.log \
    script -qec "'$repo_dir/bin/monke'" /dev/null \
    >"$test_root/system-replacement-output.log"
grep -q 'system copies now available for locally managed tools: gh' \
    "$test_root/system-replacement-output.log"
grep -qx adopt-system "$test_root/system-replacement.log"
grep -q 'monke: switched to the system versions' "$test_root/system-replacement-output.log"

# A successful launch-time update restarts through the current launcher before Codex starts.
cat >"$work_base/local/scripts/update-repository.sh" <<'EOF'
#!/usr/bin/env bash
printf 'update-check\n' >>"$CODEX_TEST_LOG"
exit 10
EOF
chmod +x "$work_base/local/scripts/update-repository.sh"
CODEX_TEST_LOG=$test_root/restart.log "$repo_dir/bin/monke" >/dev/null
grep -qx 'update-check' "$test_root/restart.log"
[[ $(grep -c '^args:' "$test_root/restart.log") -eq 1 ]]

# Removed public aliases fail before Codex starts.
for removed in --cheap cheap --normal normal --hard hard --no-update update; do
    set +e
    CODEX_TEST_LOG=$test_root/removed.log "$repo_dir/bin/monke" "$removed" \
        >"$test_root/removed-output.log" 2>&1
    removed_status=$?
    set -e
    [[ $removed_status -eq 2 ]]
done
set +e
CODEX_TEST_LOG=$test_root/removed.log "$repo_dir/bin/monke" tools status \
    >"$test_root/removed-output.log" 2>&1
removed_status=$?
set -e
[[ $removed_status -eq 2 ]]
for removed in --with-auto-update --without-auto-update --no-package-install; do
    set +e
    HOME=$test_root/removed-home "$repo_dir/install.sh" "$removed" \
        >"$test_root/removed-output.log" 2>&1
    removed_status=$?
    set -e
    [[ $removed_status -eq 2 ]]
done

printf 'smoke tests passed.\n'
