#!/usr/bin/env bash
set -euo pipefail

repo_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
config_dir=${XDG_CONFIG_HOME:-"$HOME/.config"}/scriptorium
data_dir=${XDG_DATA_HOME:-"$HOME/.local/share"}/scriptorium
state_dir=${XDG_STATE_HOME:-"$HOME/.local/state"}/scriptorium
bin_dir=${XDG_BIN_HOME:-"$HOME/.local/bin"}
preferences_file=$config_dir/preferences
source "$repo_dir/scripts/preferences.sh"
source "$repo_dir/scripts/backup.sh"
mode=interactive
tmux_choice=
update_choice=
tools_choice=
tools_selection=
shell_choice=
shell_rc=
developer_instructions_choice=
developer_instructions_file_choice=

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
  --developer-instructions-file PATH           Load session instructions from PATH
  --without-developer-instructions              Disable session instructions
  --apply-saved                                Reapply saved choices
  --no-package-install                         Accepted legacy no-op
  -h, --help
EOF
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
        --developer-instructions-file)
            shift; [[ $# -gt 0 ]] || { printf 'Missing path after --developer-instructions-file.\n' >&2; exit 2; }
            case $1 in
                /*|[~]/*) ;;
                *)
                    printf 'Developer instructions path must be absolute or start with ~/.\n' >&2
                    exit 2
                    ;;
            esac
            developer_instructions_choice=1
            developer_instructions_file_choice=$1
            mode=flags
            ;;
        --without-developer-instructions)
            developer_instructions_choice=0
            mode=flags
            ;;
        --apply-saved) mode=saved ;;
        --no-package-install) : ;;
        -h|--help) usage; exit 0 ;;
        *) printf 'Unknown option: %s\n' "$1" >&2; usage >&2; exit 2 ;;
    esac
    shift
done

saved_tmux=$(read_pref "$preferences_file" tmux 1)
saved_update=$(read_pref "$preferences_file" update_check "$(read_pref "$preferences_file" auto_update 1)")
saved_tools_default=0
[[ -s $config_dir/tools.selected ]] && saved_tools_default=1
saved_tools=$(read_pref "$preferences_file" tools "$saved_tools_default")
login_shell=${SHELL:-bash}
saved_shell=$(read_pref "$preferences_file" shell "${login_shell##*/}")
saved_rc=$(read_pref "$preferences_file" shell_rc '')
saved_developer_instructions=$(read_pref "$preferences_file" developer_instructions 1)
saved_developer_instructions_file=$(read_pref "$preferences_file" developer_instructions_file \
    "$repo_dir/.agents/skills/monke-language/SKILL.md")
shell_choice=${shell_choice:-$saved_shell}
shell_rc=${shell_rc:-$saved_rc}
developer_instructions_file_choice=${developer_instructions_file_choice:-$saved_developer_instructions_file}

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
    developer_instructions_choice=$saved_developer_instructions
elif [[ $mode == saved ]]; then
    tmux_choice=$saved_tmux; update_choice=$saved_update; tools_choice=$saved_tools
    developer_instructions_choice=$saved_developer_instructions
else
    tmux_choice=${tmux_choice:-$saved_tmux}
    update_choice=${update_choice:-$saved_update}
    tools_choice=${tools_choice:-$saved_tools}
    developer_instructions_choice=${developer_instructions_choice:-$saved_developer_instructions}
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
    printf 'developer_instructions=%s\n' "$developer_instructions_choice"
    printf 'developer_instructions_file=%s\n' "$developer_instructions_file_choice"
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
        if [[ $mode == saved ]]; then
            "$repo_dir/scripts/tools-manager.sh" reconcile
        fi
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
helper_source=$repo_dir/scripts/preferences.sh
helper_target=$bin_dir/scriptorium-preferences.sh
wrapper_backup=
helper_backup=
prepare_backup_target "$wrapper_target"
if [[ ! -f $wrapper_target ]] || ! cmp -s -- "$repo_dir/bin/scodex" "$wrapper_target"; then
    wrapper_candidate=$(mktemp "$bin_dir/.scodex.XXXXXX")
    if [[ -e $wrapper_target ]]; then
        backup_target "$wrapper_target" wrapper_backup
        chmod a-x -- "$wrapper_backup"
    fi
    cp -- "$repo_dir/bin/scodex" "$wrapper_candidate"
    chmod 700 -- "$wrapper_candidate"
    mv -- "$wrapper_candidate" "$wrapper_target"
    printf 'Installed command: %s\n' "$wrapper_target"
else
    printf 'Unchanged: %s\n' "$wrapper_target"
fi

prepare_backup_target "$helper_target"
if [[ ! -f $helper_target ]]; then
    cp -- "$helper_source" "$helper_target"
    chmod 600 -- "$helper_target"
    printf 'Installed command support helper: %s\n' "$helper_target"
elif cmp -s -- "$helper_source" "$helper_target"; then
    printf 'Unchanged helper: %s\n' "$helper_target"
else
    backup_target "$helper_target" helper_backup
    cp -- "$helper_source" "$helper_target"
    chmod 600 -- "$helper_target"
    printf 'Updated command support helper: %s (backed up %s)\n' "$helper_target" "$helper_backup"
fi

if commit=$(git -C "$repo_dir" rev-parse HEAD 2>/dev/null); then
    printf '%s\n' "$commit" >"$state_dir/deployed-commit"
fi
preferences_committed=0
rm -f -- "$preferences_previous"
trap - EXIT
printf '\nScriptorium configured. Run scodex configure to change your choices.\n'
