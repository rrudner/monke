#!/usr/bin/env bash
set -euo pipefail

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
package_dir=$(cd -- "$script_dir/.." && pwd)
repo_dir=$(cd -- "$package_dir/.." && pwd)
config_dir=${XDG_CONFIG_HOME:-"$HOME/.config"}/scriptorium
fragment=$config_dir/tmux.conf
target=${TMUX_CONFIG:-"$HOME/.tmux.conf"}
backup_stamp=$(date -u +%Y%m%dT%H%M%SZ)

source "$repo_dir/scripts/managed-block.sh"

if [[ ${1:-} == --disable ]]; then
    remove_managed_block "$target" '# >>> scriptorium >>>' '# <<< scriptorium <<<'
    printf 'Tmux integration disabled; tmux and user settings were not removed.\n'
    exit 0
fi

if ! command -v tmux >/dev/null 2>&1; then
    printf 'Tmux integration is unavailable because tmux is not installed.\n' >&2
    exit 3
fi

mkdir -p -- "$config_dir"
if [[ ! -f $fragment ]] || ! cmp -s -- "$package_dir/tmux.conf" "$fragment"; then
    if [[ -e $fragment ]]; then
        cp -a -- "$fragment" "$fragment.backup-$backup_stamp"
        printf 'Backup: %s\n' "$fragment.backup-$backup_stamp"
    fi
    fragment_candidate=$(mktemp "$config_dir/.tmux-fragment.XXXXXX")
    cp -- "$package_dir/tmux.conf" "$fragment_candidate"
    mv -- "$fragment_candidate" "$fragment"
    chmod 600 -- "$fragment"
    printf 'Installed Scriptorium tmux fragment: %s\n' "$fragment"
else
    printf 'Unchanged: %s\n' "$fragment"
fi

block=$(mktemp "$config_dir/.tmux-source.XXXXXX")
trap 'rm -f -- "$block"' EXIT
printf 'source-file "%s"\n' "$fragment" >"$block"
update_managed_block "$target" "$block" '# >>> scriptorium >>>' \
    '# <<< scriptorium <<<' prepend "$package_dir/tmux.conf"

if tmux list-sessions >/dev/null 2>&1; then
    tmux source-file "$target"
fi
printf 'Tmux integration configured.\n'
