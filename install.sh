#!/usr/bin/env bash
set -euo pipefail

repo_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
config_dir=${XDG_CONFIG_HOME:-"$HOME/.config"}/scriptorium
data_dir=${XDG_DATA_HOME:-"$HOME/.local/share"}/scriptorium
state_dir=${XDG_STATE_HOME:-"$HOME/.local/state"}/scriptorium
bin_dir=${XDG_BIN_HOME:-"$HOME/.local/bin"}
preferences_file=$config_dir/preferences
mode=interactive
tmux_choice=
update_choice=
tools_choice=
tools_selection=
shell_choice=
shell_rc=

usage() {
    cat <<'EOF'
Usage: ./install.sh [options]

  --with-tmux | --without-tmux
  --with-update-check | --without-update-check
  --with-auto-update | --without-auto-update   Legacy aliases
  --with-tools | --without-tools
  --tools NAME[,NAME...]                       Non-interactive tool selection
  --shell bash|zsh|fish
  --shell-rc PATH                              Override Bash/Zsh rc path
  --apply-saved                                Reapply saved choices
  --no-package-install                         Accepted legacy no-op
  -h, --help
EOF
}

read_pref() {
    local key=$1 default=$2 value
    value=$(sed -n "s/^${key}=//p" "$preferences_file" 2>/dev/null | tail -n 1)
    printf '%s\n' "${value:-$default}"
}

prompt_boolean() {
    local prompt=$1 current=$2 answer suffix
    [[ $current == 1 ]] && suffix='[Y/n]' || suffix='[y/N]'
    while true; do
        read -r -p "$prompt $suffix " answer
        case ${answer,,} in
            '') printf '%s\n' "$current"; return ;;
            y|yes) printf '1\n'; return ;;
            n|no) printf '0\n'; return ;;
            *) printf 'Please answer yes or no.\n' >&2 ;;
        esac
    done
}

while (($#)); do
    case $1 in
        --with-tmux) tmux_choice=1; mode=flags ;;
        --without-tmux) tmux_choice=0; mode=flags ;;
        --with-update-check|--with-auto-update) update_choice=1; mode=flags ;;
        --without-update-check|--without-auto-update) update_choice=0; mode=flags ;;
        --with-tools) tools_choice=1; mode=flags ;;
        --without-tools) tools_choice=0; mode=flags ;;
        --tools)
            shift; [[ $# -gt 0 ]] || { printf 'Missing list after --tools.\n' >&2; exit 2; }
            tools_choice=1; tools_selection=$1; mode=flags
            ;;
        --shell)
            shift; [[ $# -gt 0 ]] || { printf 'Missing shell name.\n' >&2; exit 2; }
            shell_choice=$1
            ;;
        --shell-rc)
            shift; [[ $# -gt 0 ]] || { printf 'Missing shell rc path.\n' >&2; exit 2; }
            shell_rc=$1
            ;;
        --apply-saved) mode=saved ;;
        --no-package-install) : ;;
        -h|--help) usage; exit 0 ;;
        *) printf 'Unknown option: %s\n' "$1" >&2; usage >&2; exit 2 ;;
    esac
    shift
done

saved_tmux=$(read_pref tmux 1)
saved_update=$(read_pref update_check "$(read_pref auto_update 1)")
saved_tools=$(read_pref tools 0)
login_shell=${SHELL:-bash}
saved_shell=$(read_pref shell "${login_shell##*/}")
saved_rc=$(read_pref shell_rc '')
shell_choice=${shell_choice:-$saved_shell}
shell_rc=${shell_rc:-$saved_rc}

case $shell_choice in bash|zsh|fish) ;; *) shell_choice=bash ;; esac

if [[ $mode == interactive && -t 0 ]]; then
    if command -v tmux >/dev/null 2>&1; then
        tmux_choice=$(prompt_boolean 'Enable tmux integration?' "$saved_tmux")
    else
        tmux_choice=0
        printf 'Tmux integration is unavailable because tmux is not installed.\n'
    fi
    update_choice=$(prompt_boolean 'Check for Scriptorium updates when scodex starts?' "$saved_update")
    tools_choice=$(prompt_boolean 'Configure optional scodex tools?' "$saved_tools")
elif [[ $mode == saved ]]; then
    tmux_choice=$saved_tmux; update_choice=$saved_update; tools_choice=$saved_tools
else
    tmux_choice=${tmux_choice:-$saved_tmux}
    update_choice=${update_choice:-$saved_update}
    tools_choice=${tools_choice:-$saved_tools}
fi

if [[ $tmux_choice == 1 ]] && ! command -v tmux >/dev/null 2>&1; then
    printf 'Tmux selection disabled because tmux is not installed.\n' >&2
    tmux_choice=0
fi

mkdir -p -- "$config_dir" "$data_dir" "$state_dir" "$bin_dir"
preferences_previous=$(mktemp "$config_dir/.preferences-previous.XXXXXX")
rm -f -- "$preferences_previous"
preferences_had_previous=0
if [[ -e $preferences_file || -L $preferences_file ]]; then
    cp -a -- "$preferences_file" "$preferences_previous"
    preferences_had_previous=1
fi
preferences_tmp=$(mktemp "$config_dir/.preferences.XXXXXX")
preferences_committed=0
rollback_install() {
    local status=$?
    trap - EXIT
    rm -f -- "$preferences_tmp"
    if [[ $status -ne 0 && $preferences_committed == 1 ]]; then
        if [[ $preferences_had_previous == 1 ]]; then
            mv -- "$preferences_previous" "$preferences_file"
        else
            rm -f -- "$preferences_file"
        fi
        printf 'Installation failed; previous preferences were restored.\n' >&2
    fi
    rm -f -- "$preferences_previous"
    exit "$status"
}
trap rollback_install EXIT
{
    printf 'repo_dir=%s\n' "$repo_dir"
    printf 'tmux=%s\n' "$tmux_choice"
    printf 'update_check=%s\n' "$update_choice"
    printf 'tools=%s\n' "$tools_choice"
    printf 'shell=%s\n' "$shell_choice"
    printf 'shell_rc=%s\n' "$shell_rc"
} >"$preferences_tmp"
chmod 600 -- "$preferences_tmp"
mv -- "$preferences_tmp" "$preferences_file"
preferences_committed=1

"$repo_dir/codex/scripts/install-codex.sh"

if [[ $tools_choice == 1 ]]; then
    if [[ -n $tools_selection ]]; then
        "$repo_dir/scripts/tools-manager.sh" configure --select "$tools_selection"
    elif [[ $mode == interactive && -t 0 ]]; then
        "$repo_dir/scripts/tools-manager.sh" configure
    else
        "$repo_dir/scripts/tools-manager.sh" apply
    fi
else
    "$repo_dir/scripts/tools-manager.sh" clear
fi
"$repo_dir/codex/scripts/render-agents.sh"

if [[ $tmux_choice == 1 ]]; then
    "$repo_dir/tmux/scripts/install-tmux.sh"
else
    "$repo_dir/tmux/scripts/install-tmux.sh" --disable
fi

SCRIPTORIUM_TMUX=$tmux_choice SCRIPTORIUM_SHELL=$shell_choice \
    "$repo_dir/scripts/install-shell-hook.sh" "$shell_rc"

wrapper_target=$bin_dir/scodex
if [[ ! -f $wrapper_target ]] || ! cmp -s -- "$repo_dir/bin/scodex" "$wrapper_target"; then
    wrapper_candidate=$(mktemp "$bin_dir/.scodex.XXXXXX")
    [[ ! -e $wrapper_target ]] || cp -a -- "$wrapper_target" \
        "$wrapper_target.backup-$(date -u +%Y%m%dT%H%M%SZ)"
    cp -- "$repo_dir/bin/scodex" "$wrapper_candidate"
    chmod 700 -- "$wrapper_candidate"
    mv -- "$wrapper_candidate" "$wrapper_target"
    printf 'Installed command: %s\n' "$wrapper_target"
else
    printf 'Unchanged: %s\n' "$wrapper_target"
fi

if commit=$(git -C "$repo_dir" rev-parse HEAD 2>/dev/null); then
    printf '%s\n' "$commit" >"$state_dir/deployed-commit"
fi
preferences_committed=0
rm -f -- "$preferences_previous"
trap - EXIT
printf '\nScriptorium configured. Run scodex configure to change your choices.\n'
