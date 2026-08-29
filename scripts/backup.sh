#!/usr/bin/env bash

monke_backup_root() {
    printf '%s/monke/backups\n' "${XDG_STATE_HOME:-$HOME/.local/state}"
}

backup_target_dir() {
    local target=$1 root hash
    root=$(monke_backup_root)
    hash=$(printf '%s' "$target" | sha256sum | awk '{ print $1 }')
    printf '%s/%s\n' "$root" "$hash"
}

unique_backup_path() {
    local target_dir=$1 prefix=$2 candidate
    while :; do
        candidate=$target_dir/$prefix-${BASHPID:-$$}-$RANDOM
        [[ -e $candidate || -L $candidate ]] || { printf '%s\n' "$candidate"; return; }
    done
}

prune_target_backups() {
    local target_dir=$1 backups=() remove_count index
    shopt -s nullglob
    backups=("$target_dir"/backup-*)
    shopt -u nullglob
    ((${#backups[@]} <= 3)) && return 0
    mapfile -t backups < <(printf '%s\n' "${backups[@]}" | LC_ALL=C sort)
    remove_count=$((${#backups[@]} - 3))
    for ((index = 0; index < remove_count; index++)); do
        rm -rf -- "${backups[index]}"
    done
}

prepare_backup_target() {
    local target=$1 target_dir root legacy name stamp destination
    root=$(monke_backup_root)
    target_dir=$(backup_target_dir "$target")
    mkdir -p -- "$root" "$target_dir"
    chmod 700 -- "$root" "$target_dir"
    printf '%s\n' "$target" >"$target_dir/original-path"
    chmod 600 -- "$target_dir/original-path"

    shopt -s nullglob
    for legacy in "$target".backup-*; do
        name=${legacy##*/}
        stamp=${name##*.backup-}
        [[ $stamp =~ ^[0-9]{8}T[0-9]{6}Z$ ]] || continue
        destination=$(unique_backup_path "$target_dir" "backup-$stamp-$(date -u +%s%N)-migrated")
        mv -- "$legacy" "$destination"
    done
    shopt -u nullglob
    prune_target_backups "$target_dir"
}

backup_target() {
    local target=$1 output=${2-} target_dir stamp generated_path
    prepare_backup_target "$target" || return 1
    target_dir=$(backup_target_dir "$target")
    stamp=$(date -u +%Y%m%dT%H%M%SZ)
    generated_path=$(unique_backup_path "$target_dir" "backup-$stamp-$(date -u +%s%N)-current")
    cp -a -- "$target" "$generated_path" || return 1
    prune_target_backups "$target_dir" || return 1
    [[ -z $output ]] || printf -v "$output" '%s' "$generated_path"
    printf 'Backup: %s\n' "$generated_path"
}
