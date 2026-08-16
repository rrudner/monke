#!/usr/bin/env bash
set -euo pipefail

repo_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
test_root=$(mktemp -d /tmp/scriptorium-smoke.XXXXXX)
trap 'rm -rf -- "$test_root"' EXIT
mkdir -p -- "$test_root/bin" "$test_root/home/.codex"
ln -s /bin/true "$test_root/bin/tmux"

bash -n "$repo_dir/install.sh" "$repo_dir/update.sh" "$repo_dir/bin/scodex" \
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
grep -q '^<!-- >>> scriptorium >>> -->$' "$test_root/home/.codex/AGENTS.md"
grep -q '^Keep this content\.$' "$test_root/home/.codex/AGENTS.md"
grep -q '^# >>> scriptorium >>>$' "$test_root/home/.tmux.conf"
grep -q '^set -g status off$' "$test_root/home/.tmux.conf"
grep -q '^alias user_command=true$' "$test_root/home/.bashrc"
grep -q 'tmux new-session -A -s main' "$test_root/home/.bashrc"
grep -qx 'tmux=1' "$test_root/home/.config/scriptorium/preferences"
grep -qx 'update_check=1' "$test_root/home/.config/scriptorium/preferences"
grep -qx 'tools=0' "$test_root/home/.config/scriptorium/preferences"

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

printf 'Smoke tests passed.\n'
