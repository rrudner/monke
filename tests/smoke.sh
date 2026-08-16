#!/usr/bin/env bash
set -euo pipefail

repo_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
test_root=$(mktemp -d /tmp/scriptorium-smoke.XXXXXX)
trap 'rm -rf -- "$test_root"' EXIT
mkdir -p -- "$test_root/bin" "$test_root/home/.codex"
ln -s /bin/true "$test_root/bin/tmux"

bash -n "$repo_dir/install.sh" "$repo_dir/uninstall.sh" "$repo_dir/update.sh" "$repo_dir/bin/scodex" \
    "$repo_dir"/scripts/*.sh "$repo_dir"/codex/scripts/*.sh \
    "$repo_dir"/tmux/scripts/*.sh "$repo_dir"/tests/*.sh

cat >"$test_root/home/.codex/config.toml" <<'EOF'
model = "user-model"

[projects."/srv/user-project"]
trust_level = "trusted"
EOF
cp -- "$test_root/home/.codex/config.toml" "$test_root/original-config.toml"
printf '# User instructions\n\nKeep this content.\n' >"$test_root/home/.codex/AGENTS.md"
printf 'set -g status off\n' >"$test_root/home/.tmux.conf"
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
grep -q '^<!-- >>> scriptorium >>> -->$' "$test_root/home/.codex/AGENTS.md"
grep -q '^Keep this content\.$' "$test_root/home/.codex/AGENTS.md"
grep -q '^# >>> scriptorium >>>$' "$test_root/home/.tmux.conf"
grep -q '^set -g status off$' "$test_root/home/.tmux.conf"
grep -q '^alias user_command=true$' "$test_root/home/.bashrc"
grep -q 'tmux new-session -A -s main' "$test_root/home/.bashrc"
grep -qx 'tmux=1' "$test_root/home/.config/scriptorium/preferences"
grep -qx 'update_check=1' "$test_root/home/.config/scriptorium/preferences"
grep -qx 'tools=0' "$test_root/home/.config/scriptorium/preferences"
[[ -f "$test_root/home/.config/scriptorium/tools.catalog-reviewed" ]]

backup_count=$(find "$test_root/home" -name '*.backup-*' | wc -l)
PATH="$test_root/bin:$PATH" SHELL=/bin/bash HOME="$test_root/home" \
CODEX_HOME="$test_root/home/.codex" \
    "$repo_dir/install.sh" --apply-saved >"$test_root/reapply.log"
[[ $(find "$test_root/home" -name '*.backup-*' | wc -l) -eq $backup_count ]]

PATH="$test_root/bin:$PATH" SHELL=/bin/bash HOME="$test_root/home" \
CODEX_HOME="$test_root/home/.codex" \
    "$repo_dir/install.sh" --without-tmux --without-update-check --without-tools \
    >"$test_root/disable.log"
! grep -q '^source-file .*scriptorium' "$test_root/home/.tmux.conf"
grep -q '^set -g status off$' "$test_root/home/.tmux.conf"
! grep -q 'tmux new-session -A -s main' "$test_root/home/.bashrc"
grep -q '.local/bin' "$test_root/home/.bashrc"

legacy_home=$test_root/legacy-home
mkdir -p -- "$legacy_home/.codex"
cp -- "$repo_dir/codex/config.toml" "$legacy_home/.codex/config.toml"
printf '\n[projects."/srv/legacy"]\ntrust_level = "trusted"\n' \
    >>"$legacy_home/.codex/config.toml"
cp -- "$repo_dir/codex/AGENTS.md" "$legacy_home/.codex/AGENTS.md"
cp -- "$repo_dir/tmux/tmux.conf" "$legacy_home/.tmux.conf"
PATH="$test_root/bin:$PATH" SHELL=/bin/zsh HOME="$legacy_home" \
CODEX_HOME="$legacy_home/.codex" \
    "$repo_dir/install.sh" --without-tools --shell zsh >"$test_root/legacy.log"
! grep -q '^model = ' "$legacy_home/.codex/config.toml"
grep -q '^\[projects."/srv/legacy"\]$' "$legacy_home/.codex/config.toml"
grep -q '^<!-- >>> scriptorium >>> -->$' "$legacy_home/.codex/AGENTS.md"
grep -q '^source-file .*scriptorium' "$legacy_home/.tmux.conf"
grep -q 'tmux new-session -A -s main' "$legacy_home/.zshrc"

fish_home=$test_root/fish-home
PATH="$test_root/bin:$PATH" SHELL=/usr/bin/fish HOME="$fish_home" \
CODEX_HOME="$fish_home/.codex" \
    "$repo_dir/install.sh" --without-tools --shell fish >"$test_root/fish.log"
grep -q '^fish_add_path ' "$fish_home/.config/fish/conf.d/scriptorium.fish"
grep -q 'tmux new-session -A -s main' "$fish_home/.config/fish/conf.d/scriptorium.fish"
[[ ! -e $fish_home/.codex/config.toml ]]

rollback_home=$test_root/rollback-home
mkdir -p -- "$rollback_home/.codex" "$rollback_home/.config/scriptorium"
cat >"$rollback_home/.config/scriptorium/preferences" <<'EOF'
repo_dir=/previous/repository
tmux=0
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
    "$repo_dir/install.sh" --without-tmux --with-update-check --without-tools \
    >"$test_root/rollback.log" 2>&1; then
    printf 'Expected malformed managed markers to stop installation.\n' >&2
    exit 1
fi
cmp -s "$test_root/original-preferences" \
    "$rollback_home/.config/scriptorium/preferences"
cmp -s "$test_root/original-agents" "$rollback_home/.codex/AGENTS.md"

shell_rollback_home=$test_root/shell-rollback-home
mkdir -p -- "$shell_rollback_home"
cat >"$shell_rollback_home/.bashrc" <<'EOF'
# >>> tmux-init auto-tmux >>>
legacy command
# <<< tmux-init auto-tmux <<<
# <<< scriptorium <<<
User shell content.
# >>> scriptorium >>>
EOF
cp -- "$shell_rollback_home/.bashrc" "$test_root/original-shell-rollback"
if HOME="$shell_rollback_home" SCRIPTORIUM_SHELL=bash \
    "$repo_dir/scripts/install-shell-hook.sh" >"$test_root/shell-rollback.log" 2>&1; then
    printf 'Expected malformed shell markers to stop migration.\n' >&2
    exit 1
fi
cmp -s "$test_root/original-shell-rollback" "$shell_rollback_home/.bashrc"

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
PATH="$test_root/bin:$PATH" HOME="$uninstall_home" SCRIPTORIUM_SHELL=zsh SCRIPTORIUM_TMUX=1 \
    "$repo_dir/scripts/install-shell-hook.sh" >"$test_root/uninstall-zsh-hook.log"
PATH="$test_root/bin:$PATH" HOME="$uninstall_home" SCRIPTORIUM_SHELL=bash SCRIPTORIUM_TMUX=0 \
    "$repo_dir/scripts/install-shell-hook.sh" "$uninstall_home/.customrc" \
    >"$test_root/uninstall-custom-hook.log"
PATH="$test_root/bin:$PATH" HOME="$uninstall_home" SCRIPTORIUM_SHELL=fish SCRIPTORIUM_TMUX=1 \
    "$repo_dir/scripts/install-shell-hook.sh" >"$test_root/uninstall-fish-hook.log"
printf '# >>> tmux-init auto-tmux >>>\nlegacy command\n# <<< tmux-init auto-tmux <<<\n' \
    >>"$uninstall_home/.bashrc"
sed -i "s|^shell_rc=.*|shell_rc=$uninstall_home/.customrc|" \
    "$uninstall_home/.config/scriptorium/preferences"
PATH="$test_root/bin:$PATH" SHELL=/bin/bash HOME="$uninstall_home" \
CODEX_HOME="$uninstall_home/.codex" \
    "$uninstall_home/.local/bin/scodex" uninstall --yes --keep-repo >"$test_root/uninstall.log"
! grep -q '^<!-- >>> scriptorium >>> -->$' "$uninstall_home/.codex/AGENTS.md"
! grep -q '^# >>> scriptorium >>>$' "$uninstall_home/.bashrc"
! grep -q '^# >>> tmux-init auto-tmux >>>$' "$uninstall_home/.bashrc"
! grep -q '^# >>> scriptorium >>>$' "$uninstall_home/.zshrc"
! grep -q '^# >>> scriptorium >>>$' "$uninstall_home/.customrc"
! grep -q '^# >>> scriptorium >>>$' "$uninstall_home/.tmux.conf"
[[ ! -e $uninstall_home/.codex/scriptorium-hard.config.toml ]]
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
PATH="$test_root/bin:$PATH" SHELL=/bin/bash HOME="$modified_home" \
CODEX_HOME="$modified_home/.codex" \
    "$repo_dir/uninstall.sh" --yes --keep-repo >"$test_root/modified-uninstall.log"
grep -q '^# user modification$' "$modified_home/.codex/scriptorium-hard.config.toml"

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
    commit -qm 'Add uninstall fixture'
PATH="$test_root/bin:$PATH" SHELL=/bin/bash HOME="$repo_remove_home" \
CODEX_HOME="$repo_remove_home/.codex" \
    "$repo_remove_dir/install.sh" --without-tools --shell bash >"$test_root/repo-remove-install.log"
PATH="$test_root/bin:$PATH" SHELL=/bin/bash HOME="$repo_remove_home" \
CODEX_HOME="$repo_remove_home/.codex" \
    "$repo_remove_dir/uninstall.sh" --yes >"$test_root/repo-remove.log"
[[ ! -e $repo_remove_dir ]]

printf 'Smoke tests passed.\n'
