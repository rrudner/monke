#!/usr/bin/env bash
set -euo pipefail

repo_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
enable_tmux=${SCRIPTORIUM_TMUX:-0}
login_shell=${SHELL:-bash}
shell_name=${SCRIPTORIUM_SHELL:-${login_shell##*/}}
override_rc=${1:-}
local_bin=${XDG_BIN_HOME:-"$HOME/.local/bin"}
legacy_backup=

source "$repo_dir/scripts/managed-block.sh"

remove_legacy_tmux_block() {
    local target=$1
    local tmux_start='# >>> tmux-init auto-tmux >>>'
    local tmux_end='# <<< tmux-init auto-tmux <<<'
    if [[ -L $target ]]; then
        printf 'Refusing to edit %s: managed files cannot be symbolic links.\n' "$target" >&2
        return 1
    fi
    [[ -f $target ]] || return 0
    grep -Fqx "$tmux_start" "$target" || return 0
    if ! remove_managed_block "$target" "$tmux_start" "$tmux_end" legacy_backup; then
        if grep -Fqx "$tmux_start" "$target"; then
            printf 'Refusing to migrate %s: invalid legacy markers.\n' "$target" >&2
        fi
        return 1
    fi
    printf 'Removed legacy tmux shell block: %s\n' "$target"
}

install_posix_style() {
    local target=$1 block restore
    mkdir -p -- "$(dirname -- "$target")"
    remove_legacy_tmux_block "$target"
    block=$(mktemp "$(dirname -- "$target")/.scriptorium-shell-block.XXXXXX")
    {
        printf 'case ":$PATH:" in\n'
        printf '    *":%s:"*) ;;\n' "$local_bin"
        printf '    *) export PATH="%s:$PATH" ;;\n' "$local_bin"
        printf 'esac\n'
        if [[ $enable_tmux == 1 ]]; then
            cat <<'EOF'
if [ -n "${SSH_CONNECTION:-}" ] \
    && [ -z "${TMUX:-}" ] \
    && [ -z "${NO_AUTO_TMUX:-}" ] \
    && [ -z "${SSH_ORIGINAL_COMMAND:-}" ] \
    && [ "${TERM:-}" != dumb ] \
    && command -v tmux >/dev/null 2>&1; then
    exec tmux new-session -A -s main
fi
EOF
        fi
    } >"$block"
    if ! update_managed_block "$target" "$block" '# >>> scriptorium >>>' \
        '# <<< scriptorium <<<' append; then
        if [[ -n $legacy_backup ]]; then
            restore=$(mktemp "$(dirname -- "$target")/.legacy-shell-restore.XXXXXX")
            rm -f -- "$restore"
            cp -a -- "$legacy_backup" "$restore"
            mv -- "$restore" "$target"
            printf 'Restored %s after failed migration.\n' "$target" >&2
        fi
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
    if [[ $enable_tmux == 1 ]]; then
        cat >>"$candidate" <<'EOF'
if status is-interactive; and test -n "$SSH_CONNECTION"; and test -z "$TMUX"; \
        and test -z "$NO_AUTO_TMUX"; and test -z "$SSH_ORIGINAL_COMMAND"; \
        and test "$TERM" != dumb; and command -q tmux
    exec tmux new-session -A -s main
end
EOF
    fi
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
