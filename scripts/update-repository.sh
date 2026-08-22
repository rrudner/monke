#!/usr/bin/env bash
set -euo pipefail

config_dir=${XDG_CONFIG_HOME:-"$HOME/.config"}/scriptorium
state_dir=${XDG_STATE_HOME:-"$HOME/.local/state"}/scriptorium
preferences_file=$config_dir/preferences
state_file=$state_dir/update.state
log_file=$state_dir/last-update.log
deployed_file=$state_dir/deployed-commit
mode=${1:-check}
repo_dir_script=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
tools_manager=$repo_dir_script/tools-manager.sh
source "$repo_dir_script/preferences.sh"

if [[ ${SCRIPTORIUM_MANUAL_UPDATE:-0} != 1 ]]; then
    # keep login hook from checking updates; updates are now handled through scodex launch
    exit 0
fi

read_state() {
    local key=$1
    sed -n "s/^${key}=//p" "$state_file" 2>/dev/null | tail -n 1
}

set_state() {
    local key=$1 value=$2 tmp_file
    tmp_file=$(mktemp "$state_file.XXXXXX")
    if [[ -f $state_file ]]; then
        grep -v "^${key}=" "$state_file" >"$tmp_file" || true
    else
        : >"$tmp_file"
    fi
    printf '%s=%s\n' "$key" "$value" >>"$tmp_file"
    mv -- "$tmp_file" "$state_file"
}

log() {
    printf '%s\n' "$1" >>"$log_file"
}

run_logged_with_heartbeat() {
    local activity=$1 pid heartbeat_pid status
    shift
    printf 'scodex: %s\n' "$activity"
    "$@" >>"$log_file" 2>&1 &
    pid=$!
    (
        while sleep 10; do
            kill -0 "$pid" 2>/dev/null || exit 0
            printf 'scodex: still working, %s (details: %s)\n' "$activity" "$log_file"
        done
    ) &
    heartbeat_pid=$!
    if wait "$pid"; then status=0; else status=$?; fi
    kill "$heartbeat_pid" 2>/dev/null || true
    wait "$heartbeat_pid" 2>/dev/null || true
    return "$status"
}

mkdir -p -- "$state_dir"
: >"$log_file"

repo_dir=$(read_pref "$preferences_file" repo_dir "")
if [[ -z $repo_dir || ! -d $repo_dir/.git ]]; then
    log "missing repository path"
    exit 0
fi

exec 9>"$state_dir/update.lock"
if ! flock -n 9; then
    log "another update is already running"
    exit 0
fi

if ! timeout 10s git -C "$repo_dir" fetch origin --quiet --prune >>"$log_file" 2>&1; then
    log "fetch failed"
    exit 0
fi

current_commit=$(git -C "$repo_dir" rev-parse HEAD 2>>"$log_file")
if [[ -z $current_commit ]]; then
    log "missing current commit"
    exit 0
fi
upstream_ref=$(git -C "$repo_dir" rev-parse --abbrev-ref --symbolic-full-name @{upstream} 2>/dev/null || true)
branch=$(git -C "$repo_dir" rev-parse --abbrev-ref HEAD 2>/dev/null || true)
if [[ -z $upstream_ref ]]; then
    if [[ -n $branch && $branch != HEAD ]]; then
        upstream_ref="origin/$branch"
    else
        upstream_ref="origin/HEAD"
    fi
fi
remote_commit=$(git -C "$repo_dir" rev-parse "$upstream_ref" 2>/dev/null || true)
if [[ -z $remote_commit ]]; then
    remote_commit=$(git -C "$repo_dir" rev-parse origin/HEAD 2>/dev/null || true)
    if [[ -z $remote_commit ]]; then
        log "no upstream commit"
        exit 0
    fi
fi

if [[ $current_commit == "$remote_commit" ]]; then
    log "already up to date"
    printf '%s\n' "$current_commit" >"$deployed_file"
    printf 'scodex: already up to date\n'
    exit 0
fi

if [[ $mode == check && ${SCRIPTORIUM_SKIP_SNOOZE_CHECK:-0} != 1 ]]; then
    now=$(date +%s)
    snooze_until=$(read_state update_snooze_until || true)
    snoozed_commit=$(read_state update_snoozed_commit || true)
    if [[ $snoozed_commit == "$remote_commit" && -n $snooze_until && $now -lt $snooze_until ]]; then
        exit 0
    fi
fi

if ! git -C "$repo_dir" merge-base --is-ancestor "$current_commit" "$remote_commit"; then
    log "local branch diverged"
    exit 0
fi

install_update() {
    local catalog_before new_tools merge_pending=0
    if [[ -n $(git -C "$repo_dir" status --porcelain 2>>"$log_file") ]]; then
        log "working tree has local changes"
        printf 'scodex: repository has local changes; update skipped\n'
        return 0
    fi
    catalog_before=$(mktemp "$state_dir/.tools-catalog-before.XXXXXX")
    cp -- "$repo_dir/tools/catalog.tsv" "$catalog_before"
    printf 'scodex: downloading repository update\n'
    if ! timeout 10s git -C "$repo_dir" pull --ff-only --quiet >>"$log_file" 2>&1; then
        rm -f -- "$catalog_before"
        log "pull failed"
        printf 'scodex: update failed, continuing codex\n'
        return 0
    fi
    if [[ $(read_pref "$preferences_file" tools 0) == 1 ]]; then
        merge_pending=1
    fi
    new_tools=$("$tools_manager" catalog-diff "$catalog_before" "$repo_dir/tools/catalog.tsv" "$merge_pending")
    rm -f -- "$catalog_before"
    if ! run_logged_with_heartbeat 'applying the updated configuration' \
        "$repo_dir/install.sh" --apply-saved --no-package-install; then
        log "install failed"
        printf 'scodex: install failed, continuing codex\n'
        return 0
    fi
    printf 'scodex: finalizing update\n'
    current_commit=$(git -C "$repo_dir" rev-parse HEAD 2>>"$log_file")
    printf '%s\n' "$current_commit" >"$deployed_file"
    printf 'scodex: update installed %s\n' "${current_commit:0:8}"
    if [[ -n $new_tools ]]; then
        printf 'scodex: new optional tools are available: %s\n' \
            "$(printf '%s\n' "$new_tools" | paste -sd, -)"
        if (( merge_pending == 1 )); then
            printf 'scodex: review your tool selection before continuing\n'
        else
            printf 'scodex: optional tools are disabled; run `scodex tools configure` to enable them\n'
        fi
    fi
    return 0
}

set_snooze() {
    set_state update_snooze_until "$(( $(date +%s) + 86400 ))"
    set_state update_snoozed_commit "$remote_commit"
    printf 'scodex: update postponed for 24h\n'
}

show_view() {
    printf 'scodex: update summary:\n'
    git -C "$repo_dir" --no-pager log --oneline --decorate -n 10 \
        "$current_commit".."$remote_commit" || true
}

if [[ $mode == apply ]]; then
    install_update
    exit 0
fi

if [[ -t 0 ]]; then
    while true; do
        printf 'A Scriptorium update is available.\n'
        printf 'Install (1), Later (default, 2), View (3): '
        if ! IFS= read -r -t 10 choice; then
            choice=2
        fi
        case ${choice:-2} in
            1)
                install_update
                exit 0
                ;;
            2|'')
                set_snooze
                exit 0
                ;;
            3)
                show_view
                ;;
            *)
                ;;
        esac
    done
fi

printf 'scodex: update available, run `scodex update` to install\n'
exit 0
