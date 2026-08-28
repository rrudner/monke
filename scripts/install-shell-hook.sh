#!/usr/bin/env bash
set -euo pipefail

repo_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
login_shell=${SHELL:-bash}
shell_name=${SCRIPTORIUM_SHELL:-${login_shell##*/}}
override_rc=${1:-}
local_bin=${XDG_BIN_HOME:-"$HOME/.local/bin"}

source "$repo_dir/scripts/managed-block.sh"

install_posix_style() {
    local target=$1 block
    mkdir -p -- "$(dirname -- "$target")"
    block=$(mktemp "$(dirname -- "$target")/.scriptorium-shell-block.XXXXXX")
    {
        printf 'case ":$PATH:" in\n'
        printf '    *":%s:"*) ;;\n' "$local_bin"
        printf '    *) export PATH="%s:$PATH" ;;\n' "$local_bin"
        printf 'esac\n'
    } >"$block"
    if ! update_managed_block "$target" "$block" '# >>> scriptorium >>>' \
        '# <<< scriptorium <<<' append; then
        rm -f -- "$block"
        return 1
    fi
    rm -f -- "$block"
}

install_fish() {
    local target fish_dir candidate
    fish_dir=${XDG_CONFIG_HOME:-"$HOME/.config"}/fish/conf.d
    target=$fish_dir/scriptorium.fish
    mkdir -p -- "$fish_dir"
    candidate=$(mktemp "$fish_dir/.scriptorium-fish.XXXXXX")
    printf 'fish_add_path -g %s\n' "$local_bin" >"$candidate"
    if [[ -f $target ]] && cmp -s -- "$candidate" "$target"; then
        prepare_backup_target "$target"
        rm -f -- "$candidate"
        printf 'Unchanged: %s\n' "$target"
        return
    fi
    prepare_backup_target "$target"
    if [[ -e $target ]]; then
        backup_target "$target"
    fi
    mv -- "$candidate" "$target"
    chmod 600 -- "$target"
    printf 'Updated Fish integration: %s\n' "$target"
}

case $shell_name in
    bash) install_posix_style "${override_rc:-$HOME/.bashrc}" ;;
    zsh) install_posix_style "${override_rc:-$HOME/.zshrc}" ;;
    fish) install_fish ;;
    *)
        printf 'Shell %s is not managed. Add %s to PATH manually.\n' "$shell_name" "$local_bin" >&2
        ;;
esac
