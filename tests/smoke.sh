#!/usr/bin/env bash
set -euo pipefail

repo_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
test_root=$(mktemp -d /tmp/scriptorium-smoke.XXXXXX)
trap 'rm -rf -- "$test_root"' EXIT
mkdir -p -- "$test_root/bin" "$test_root/home/.codex"
export XDG_STATE_HOME="$test_root/home/.local/state"

bash -n "$repo_dir/install.sh" "$repo_dir/uninstall.sh" "$repo_dir/update.sh" "$repo_dir/bin/scodex" \
    "$repo_dir"/scripts/*.sh "$repo_dir"/codex/scripts/*.sh "$repo_dir"/tests/*.sh

bash "$repo_dir/tests/managed-block-smoke.sh"
bash "$repo_dir/tests/developer-instructions-smoke.sh"

cat >"$test_root/home/.codex/config.toml" <<'EOF'
model = "user-model"

[projects."/srv/user-project"]
trust_level = "trusted"
EOF
cp -- "$test_root/home/.codex/config.toml" "$test_root/original-config.toml"
printf '# User instructions\n\nKeep this content.\n' >"$test_root/home/.codex/AGENTS.md"
printf 'alias user_command=true\n' >"$test_root/home/.bashrc"

PATH="$test_root/bin:$PATH" SHELL=/bin/bash HOME="$test_root/home" \
CODEX_HOME="$test_root/home/.codex" \
    "$repo_dir/install.sh" --without-tools --shell bash >"$test_root/install.log"

cmp -s "$test_root/original-config.toml" "$test_root/home/.codex/config.toml"
grep -q '^model = "gpt-5.6-sol"$' \
    "$test_root/home/.codex/scriptorium-hard.config.toml"
grep -q '^default_subagent_model = "gpt-5.3-codex-spark"$' \
    "$test_root/home/.codex/scriptorium-hard.config.toml"
[[ -f "$test_root/home/.codex/skills/reuse-first/SKILL.md" ]]
[[ -f "$test_root/home/.codex/skills/reuse-first/agents/openai.yaml" ]]
[[ -f "$test_root/home/.codex/skills/reuse-first/references/tooling.md" ]]
[[ -f "$test_root/home/.codex/skills/compact-markdown/SKILL.md" ]]
[[ -f "$test_root/home/.codex/skills/compact-markdown/agents/openai.yaml" ]]
grep -q 'compact only the requested or edited scope' \
    "$test_root/home/.codex/skills/compact-markdown/SKILL.md"
grep -q 'allow_implicit_invocation: true' \
    "$test_root/home/.codex/skills/compact-markdown/agents/openai.yaml"
grep -q '^name: reuse-first$' "$test_root/home/.codex/skills/reuse-first/SKILL.md"
grep -q 'default_prompt' "$test_root/home/.codex/skills/reuse-first/agents/openai.yaml"
grep -q 'overlap exists' "$test_root/home/.codex/skills/reuse-first/SKILL.md"
grep -q '^<!-- >>> scriptorium >>> -->$' "$test_root/home/.codex/AGENTS.md"
grep -q '^Keep this content\.$' "$test_root/home/.codex/AGENTS.md"
grep -q '^## Proportionality$' "$test_root/home/.codex/AGENTS.md"
grep -q 'Produce the shortest complete result.' \
    "$test_root/home/.codex/AGENTS.md"
grep -q 'Invoke `$compact-markdown`' "$test_root/home/.codex/AGENTS.md"
grep -q 'Keep small, single-goal work local' "$test_root/home/.codex/AGENTS.md"
if grep -q 'including small searches' "$test_root/home/.codex/AGENTS.md"; then
    printf 'Installed Scriptorium block retained aggressive delegation instructions.\n' >&2
    exit 1
fi
grep -q 'Default to local work.' \
    "$test_root/home/.codex/skills/scriptorium-delegate/SKILL.md"
grep -q '^alias user_command=true$' "$test_root/home/.bashrc"
repo_pref_test=$test_root/home/.config/scriptorium/preferences-preferences-reader
cat >"$repo_pref_test" <<'EOF'
tools=0
tools=1
EOF
source "$repo_dir/scripts/preferences.sh"
reader_value=$(read_pref "$repo_pref_test" tools 0)
if [[ $reader_value != 1 ]]; then
    printf 'Expected last preference value to win\n' >&2
    exit 1
fi
reader_default=$(read_pref "$repo_pref_test" absent default)
if [[ $reader_default != default ]]; then
    printf 'Expected default preference value when missing\n' >&2
    exit 1
fi
grep -qx 'update_check=1' "$test_root/home/.config/scriptorium/preferences"
grep -qx 'tools=0' "$test_root/home/.config/scriptorium/preferences"
grep -qx 'developer_instructions=1' "$test_root/home/.config/scriptorium/preferences"
grep -Fxq "developer_instructions_file=$repo_dir/.agents/skills/monke-language/SKILL.md" \
    "$test_root/home/.config/scriptorium/preferences"
[[ -f "$test_root/home/.config/scriptorium/tools.catalog-reviewed" ]]

printf '\n# Force wrapper replacement.\n' >>"$test_root/home/.local/bin/scodex"
legacy_wrapper_backup=$test_root/home/.local/bin/scodex.backup-20240101T000000Z
printf 'legacy wrapper backup\n' >"$legacy_wrapper_backup"
PATH="$test_root/bin:$PATH" SHELL=/bin/bash HOME="$test_root/home" \
CODEX_HOME="$test_root/home/.codex" \
    "$repo_dir/install.sh" --apply-saved >"$test_root/wrapper-backup.log"
wrapper_backup=$(find "$test_root/home/.local/bin" -maxdepth 1 -type f \
    -name 'scodex.backup-*' -print -quit)
[[ -z $wrapper_backup ]]
[[ ! -e $legacy_wrapper_backup ]]
backup_root=$test_root/home/.local/state/scriptorium/backups
[[ -d $backup_root ]]
wrapper_hash=$(printf '%s' "$test_root/home/.local/bin/scodex" | sha256sum | awk '{print $1}')
[[ -d "$backup_root/$wrapper_hash" ]]
backup_dir_count=$(find "$backup_root" -mindepth 1 -maxdepth 1 -type d | wc -l)
[[ $backup_dir_count -gt 0 ]]
while IFS= read -r backup_dir; do
    backup_name=${backup_dir##*/}
    [[ $backup_name =~ ^[[:xdigit:]]{64}$ ]]
    [[ $(find "$backup_dir" -maxdepth 1 -type f -name 'backup-*' | wc -l) -le 3 ]]
done < <(find "$backup_root" -mindepth 1 -maxdepth 1 -type d -print)

backup_count=$(find "$backup_root" -type f -name 'backup-*' | wc -l)
PATH="$test_root/bin:$PATH" SHELL=/bin/bash HOME="$test_root/home" \
CODEX_HOME="$test_root/home/.codex" \
    "$repo_dir/install.sh" --apply-saved >"$test_root/reapply.log"
[[ $(find "$backup_root" -type f -name 'backup-*' | wc -l) -eq $backup_count ]]

custom_instructions=$test_root/home/custom-SKILL.md
printf '%s\n' 'Custom instructions.' >"$custom_instructions"
PATH="$test_root/bin:$PATH" SHELL=/bin/bash HOME="$test_root/home" \
CODEX_HOME="$test_root/home/.codex" \
    "$repo_dir/install.sh" --developer-instructions-file "$custom_instructions" \
    >"$test_root/developer-override.log"
PATH="$test_root/bin:$PATH" SHELL=/bin/bash HOME="$test_root/home" \
CODEX_HOME="$test_root/home/.codex" \
    "$repo_dir/install.sh" --apply-saved >"$test_root/developer-override-reapply.log"
grep -Fxq "developer_instructions_file=$custom_instructions" \
    "$test_root/home/.config/scriptorium/preferences"

PATH="$test_root/bin:$PATH" SHELL=/bin/bash HOME="$test_root/home" \
CODEX_HOME="$test_root/home/.codex" \
    "$repo_dir/install.sh" --without-update-check --without-tools \
    --without-developer-instructions \
    >"$test_root/disable.log"
grep -qx 'developer_instructions=0' "$test_root/home/.config/scriptorium/preferences"
grep -q '.local/bin' "$test_root/home/.bashrc"

legacy_home=$test_root/legacy-home
mkdir -p -- "$legacy_home/.codex"
cp -- "$repo_dir/codex/config.toml" "$legacy_home/.codex/config.toml"
printf '\n[projects."/srv/legacy"]\ntrust_level = "trusted"\n' \
    >>"$legacy_home/.codex/config.toml"
cp -- "$repo_dir/codex/AGENTS.md" "$legacy_home/.codex/AGENTS.md"
PATH="$test_root/bin:$PATH" SHELL=/bin/zsh HOME="$legacy_home" \
CODEX_HOME="$legacy_home/.codex" \
    "$repo_dir/install.sh" --without-tools --shell zsh >"$test_root/legacy.log"
! grep -q '^model = ' "$legacy_home/.codex/config.toml"
grep -q '^\[projects."/srv/legacy"\]$' "$legacy_home/.codex/config.toml"
grep -q '^<!-- >>> scriptorium >>> -->$' "$legacy_home/.codex/AGENTS.md"

fish_home=$test_root/fish-home
PATH="$test_root/bin:$PATH" SHELL=/usr/bin/fish HOME="$fish_home" \
CODEX_HOME="$fish_home/.codex" \
    "$repo_dir/install.sh" --without-tools --shell fish >"$test_root/fish.log"
grep -q '^fish_add_path ' "$fish_home/.config/fish/conf.d/scriptorium.fish"
[[ ! -e $fish_home/.codex/config.toml ]]

path_hook_home=$test_root/path-hook-home
mkdir -p -- "$path_hook_home/.local/bin"
PATH="$test_root/bin:$PATH" SHELL=/bin/bash HOME="$path_hook_home" \
    "$repo_dir/scripts/install-shell-hook.sh" >"$test_root/path-hook-bash-install.log"
[[ ! -L $path_hook_home/.bashrc ]]
! grep -q '\\$PATH' "$path_hook_home/.bashrc"
bash_path=$(PATH="runtime-base-path:/usr/bin:/bin" SHELL=/bin/bash HOME="$path_hook_home" \
    bash -c 'source "$HOME/.bashrc"; printf "%s" "$PATH"')
[[ $bash_path == "$path_hook_home/.local/bin:runtime-base-path:/usr/bin:/bin" ]]
PATH="$test_root/bin:$PATH" SHELL=/bin/zsh HOME="$path_hook_home" SCRIPTORIUM_SHELL=zsh \
    "$repo_dir/scripts/install-shell-hook.sh" >"$test_root/path-hook-zsh-install.log"
[[ ! -L $path_hook_home/.zshrc ]]
! grep -q '\\$PATH' "$path_hook_home/.zshrc"
if command -v zsh >/dev/null 2>&1; then
    zsh_path=$(PATH="runtime-zsh-path:/usr/bin:/bin" SHELL=/bin/zsh HOME="$path_hook_home" \
        zsh -fc 'source "$HOME/.zshrc"; print -r -- "$PATH"')
    [[ $zsh_path == "$path_hook_home/.local/bin:runtime-zsh-path:/usr/bin:/bin" ]]
fi

rollback_home=$test_root/rollback-home
mkdir -p -- "$rollback_home/.codex" "$rollback_home/.config/scriptorium"
cat >"$rollback_home/.config/scriptorium/preferences" <<'EOF'
repo_dir=/previous/repository
update_check=0
tools=0
shell=bash
shell_rc=
EOF
cp -- "$rollback_home/.config/scriptorium/preferences" "$test_root/original-preferences"
cat >"$rollback_home/.codex/AGENTS.md" <<'EOF'
<!-- <<< scriptorium <<< -->
User content must remain unchanged.
<!-- >>> scriptorium >>> -->
EOF
cp -- "$rollback_home/.codex/AGENTS.md" "$test_root/original-agents"
if PATH="$test_root/bin:$PATH" SHELL=/bin/bash HOME="$rollback_home" \
CODEX_HOME="$rollback_home/.codex" \
    "$repo_dir/install.sh" --with-update-check --without-tools \
    >"$test_root/rollback.log" 2>&1; then
    printf 'Expected malformed managed markers to stop installation.\n' >&2
    exit 1
fi
cmp -s "$test_root/original-preferences" \
    "$rollback_home/.config/scriptorium/preferences"
cmp -s "$test_root/original-agents" "$rollback_home/.codex/AGENTS.md"

symlink_home=$test_root/symlink-home
symlink_outside=$test_root/symlink-outside
mkdir -p -- "$symlink_home/.codex" "$symlink_outside"
ln -s -- "$symlink_outside" "$symlink_home/.codex/agents"
if HOME="$symlink_home" CODEX_HOME="$symlink_home/.codex" \
    "$repo_dir/codex/scripts/install-codex.sh" >"$test_root/symlink.log" 2>&1; then
    printf 'Expected an escaping parent symlink to stop installation.\n' >&2
    exit 1
fi
[[ ! -e $symlink_outside/scriptorium-worker.toml ]]

uninstall_home=$test_root/uninstall-home
mkdir -p -- "$uninstall_home/.codex" "$uninstall_home/.config/scriptorium"
printf '# Personal Codex settings\n' >"$uninstall_home/.codex/config.toml"
printf 'keep this user file\n' >"$uninstall_home/.config/scriptorium/custom.txt"
printf 'preserve backup\n' >"$uninstall_home/.config/scriptorium/preferences.backup-user"
PATH="$test_root/bin:$PATH" SHELL=/bin/bash HOME="$uninstall_home" \
CODEX_HOME="$uninstall_home/.codex" \
    "$repo_dir/install.sh" --without-tools --shell bash >"$test_root/uninstall-install.log"
PATH="$test_root/bin:$PATH" HOME="$uninstall_home" SCRIPTORIUM_SHELL=zsh \
    "$repo_dir/scripts/install-shell-hook.sh" >"$test_root/uninstall-zsh-hook.log"
PATH="$test_root/bin:$PATH" HOME="$uninstall_home" SCRIPTORIUM_SHELL=bash \
    "$repo_dir/scripts/install-shell-hook.sh" "$uninstall_home/.customrc" \
    >"$test_root/uninstall-custom-hook.log"
PATH="$test_root/bin:$PATH" HOME="$uninstall_home" SCRIPTORIUM_SHELL=fish \
    "$repo_dir/scripts/install-shell-hook.sh" >"$test_root/uninstall-fish-hook.log"
sed -i "s|^shell_rc=.*|shell_rc=$uninstall_home/.customrc|" \
    "$uninstall_home/.config/scriptorium/preferences"
PATH="$test_root/bin:$PATH" SHELL=/bin/bash HOME="$uninstall_home" \
CODEX_HOME="$uninstall_home/.codex" \
    "$uninstall_home/.local/bin/scodex" uninstall --yes --keep-repo >"$test_root/uninstall.log"
! grep -q '^<!-- >>> scriptorium >>> -->$' "$uninstall_home/.codex/AGENTS.md"
! grep -q '^# >>> scriptorium >>>$' "$uninstall_home/.bashrc"
! grep -q '^# >>> scriptorium >>>$' "$uninstall_home/.zshrc"
! grep -q '^# >>> scriptorium >>>$' "$uninstall_home/.customrc"
[[ ! -e $uninstall_home/.codex/scriptorium-hard.config.toml ]]
[[ ! -e $uninstall_home/.codex/skills/compact-markdown ]]
[[ ! -e $uninstall_home/.codex/skills/reuse-first ]]
[[ ! -e $uninstall_home/.local/bin/scodex ]]
[[ ! -e $uninstall_home/.config/scriptorium/preferences ]]
[[ ! -e $uninstall_home/.config/scriptorium/tools.catalog-reviewed ]]
[[ ! -e $uninstall_home/.config/fish/conf.d/scriptorium.fish ]]
grep -qx '# Personal Codex settings' "$uninstall_home/.codex/config.toml"
grep -qx 'keep this user file' "$uninstall_home/.config/scriptorium/custom.txt"
grep -qx 'preserve backup' "$uninstall_home/.config/scriptorium/preferences.backup-user"

cancel_home=$test_root/cancel-home
PATH="$test_root/bin:$PATH" SHELL=/bin/bash HOME="$cancel_home" \
CODEX_HOME="$cancel_home/.codex" \
    "$repo_dir/install.sh" --without-tools --shell bash >"$test_root/cancel-install.log"
printf 'n\n' | PATH="$test_root/bin:$PATH" SHELL=/bin/bash HOME="$cancel_home" \
CODEX_HOME="$cancel_home/.codex" "$repo_dir/uninstall.sh" --keep-repo >"$test_root/cancel.log"
[[ -e $cancel_home/.codex/scriptorium-hard.config.toml ]]
grep -q '^<!-- >>> scriptorium >>> -->$' "$cancel_home/.codex/AGENTS.md"
if ! PATH="$test_root/bin:$PATH" SHELL=/bin/bash HOME="$cancel_home" \
CODEX_HOME="$cancel_home/.codex" "$repo_dir/uninstall.sh" --keep-repo \
    < /dev/null >"$test_root/cancel-eof.log"; then
    printf 'Expected EOF confirmation to cancel cleanly.\n' >&2
    exit 1
fi
[[ -e $cancel_home/.codex/scriptorium-hard.config.toml ]]

modified_home=$test_root/modified-home
PATH="$test_root/bin:$PATH" SHELL=/bin/bash HOME="$modified_home" \
CODEX_HOME="$modified_home/.codex" \
    "$repo_dir/install.sh" --without-tools --shell bash >"$test_root/modified-install.log"
printf '# user modification\n' >>"$modified_home/.codex/scriptorium-hard.config.toml"
printf '# user modification\n' >>"$modified_home/.codex/skills/compact-markdown/SKILL.md"
PATH="$test_root/bin:$PATH" SHELL=/bin/bash HOME="$modified_home" \
CODEX_HOME="$modified_home/.codex" \
    "$repo_dir/uninstall.sh" --yes --keep-repo >"$test_root/modified-uninstall.log"
grep -q '^# user modification$' "$modified_home/.codex/scriptorium-hard.config.toml"
grep -q '^# user modification$' \
    "$modified_home/.codex/skills/compact-markdown/SKILL.md"

marker_refusal_home=$test_root/marker-refusal-home
PATH="$test_root/bin:$PATH" SHELL=/bin/bash HOME="$marker_refusal_home" \
CODEX_HOME="$marker_refusal_home/.codex" \
    "$repo_dir/install.sh" --without-tools --shell bash >"$test_root/marker-refusal-install.log"
printf '<!-- <<< scriptorium <<< -->\n' >>"$marker_refusal_home/.codex/AGENTS.md"
if PATH="$test_root/bin:$PATH" SHELL=/bin/bash HOME="$marker_refusal_home" \
CODEX_HOME="$marker_refusal_home/.codex" \
    "$repo_dir/uninstall.sh" --yes --keep-repo >"$test_root/marker-refusal.log" 2>&1; then
    printf 'Expected invalid markers to stop uninstall.\n' >&2
    exit 1
fi
[[ -e $marker_refusal_home/.codex/scriptorium-hard.config.toml ]]

path_refusal_home=$test_root/path-refusal-home
PATH="$test_root/bin:$PATH" SHELL=/bin/bash HOME="$path_refusal_home" \
CODEX_HOME="$path_refusal_home/.codex" \
    "$repo_dir/install.sh" --without-tools --shell bash >"$test_root/path-refusal-install.log"
rm -- "$path_refusal_home/.codex/agents/scriptorium-worker.toml"
ln -s /dev/null "$path_refusal_home/.codex/agents/scriptorium-worker.toml"
if PATH="$test_root/bin:$PATH" SHELL=/bin/bash HOME="$path_refusal_home" \
CODEX_HOME="$path_refusal_home/.codex" \
    "$repo_dir/uninstall.sh" --yes --keep-repo >"$test_root/path-refusal.log" 2>&1; then
    printf 'Expected symbolic-link path to stop uninstall.\n' >&2
    exit 1
fi
[[ -e $path_refusal_home/.codex/scriptorium-hard.config.toml ]]

repo_remove_home=$test_root/repo-remove-home
repo_remove_dir=$repo_remove_home/.local/share/scriptorium/repo
mkdir -p -- "$(dirname -- "$repo_remove_dir")"
git clone -q -- "$repo_dir" "$repo_remove_dir"
cp -- "$repo_dir/uninstall.sh" "$repo_remove_dir/uninstall.sh"
chmod 700 -- "$repo_remove_dir/uninstall.sh"
git -C "$repo_remove_dir" add -- uninstall.sh
git -C "$repo_remove_dir" -c user.name=Smoke -c user.email=smoke@example.invalid \
    commit --allow-empty -qm 'Add uninstall fixture'
PATH="$test_root/bin:$PATH" SHELL=/bin/bash HOME="$repo_remove_home" \
CODEX_HOME="$repo_remove_home/.codex" \
    "$repo_remove_dir/install.sh" --without-tools --shell bash >"$test_root/repo-remove-install.log"
PATH="$test_root/bin:$PATH" SHELL=/bin/bash HOME="$repo_remove_home" \
CODEX_HOME="$repo_remove_home/.codex" \
    "$repo_remove_dir/uninstall.sh" --yes >"$test_root/repo-remove.log"
[[ ! -e $repo_remove_dir ]]

printf 'Smoke tests passed.\n'
