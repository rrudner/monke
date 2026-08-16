#!/usr/bin/env bash

validate_managed_markers() {
    local target=$1 start_marker=$2 end_marker=$3
    awk -v start="$start_marker" -v end="$end_marker" '
        $0 == start { if (inside || seen) exit 1; inside = 1; seen = 1; next }
        $0 == end { if (!inside) exit 1; inside = 0; next }
        END { if (inside) exit 1 }
    ' "$target"
}

update_managed_block() {
    local target=$1 content=$2 start_marker=$3 end_marker=$4 position=$5
    local legacy_source=${6:-} target_dir cleaned candidate mode backup_stamp

    if [[ -L $target ]]; then
        printf 'Refusing to edit %s: managed files cannot be symbolic links.\n' "$target" >&2
        return 1
    fi
    target_dir=$(dirname -- "$target")
    mkdir -p -- "$target_dir"
    cleaned=$(mktemp "$target_dir/.scriptorium-clean.XXXXXX")
    candidate=$(mktemp "$target_dir/.scriptorium-candidate.XXXXXX")

    if [[ -f $target ]] \
        && { [[ -z $legacy_source ]] || ! cmp -s -- "$target" "$legacy_source"; }; then
        if ! validate_managed_markers "$target" "$start_marker" "$end_marker"; then
            printf 'Refusing to edit %s: unmatched Scriptorium markers.\n' "$target" >&2
            rm -f -- "$cleaned" "$candidate"
            return 1
        fi
        awk -v start="$start_marker" -v end="$end_marker" '
            $0 == start { skip = 1; next }
            $0 == end { skip = 0; next }
            !skip { print }
        ' "$target" >"$cleaned"
    else
        : >"$cleaned"
    fi

    if [[ $position == prepend ]]; then
        printf '%s\n' "$start_marker" >"$candidate"
        cat -- "$content" >>"$candidate"
        [[ ! -s $content || $(tail -c 1 "$content" | wc -l) -eq 1 ]] || printf '\n' >>"$candidate"
        printf '%s\n' "$end_marker" >>"$candidate"
        [[ ! -s $cleaned ]] || { printf '\n' >>"$candidate"; cat -- "$cleaned" >>"$candidate"; }
    else
        cat -- "$cleaned" >"$candidate"
        [[ ! -s $cleaned ]] || printf '\n' >>"$candidate"
        printf '%s\n' "$start_marker" >>"$candidate"
        cat -- "$content" >>"$candidate"
        [[ ! -s $content || $(tail -c 1 "$content" | wc -l) -eq 1 ]] || printf '\n' >>"$candidate"
        printf '%s\n' "$end_marker" >>"$candidate"
    fi

    if [[ -f $target ]] && cmp -s -- "$candidate" "$target"; then
        rm -f -- "$cleaned" "$candidate"
        printf 'Unchanged: %s\n' "$target"
        return
    fi

    if [[ -e $target ]]; then
        backup_stamp=$(date -u +%Y%m%dT%H%M%SZ)
        cp -a -- "$target" "$target.backup-$backup_stamp"
        mode=$(stat -c '%a' "$target" 2>/dev/null || printf '600')
        printf 'Backup: %s\n' "$target.backup-$backup_stamp"
    else
        mode=600
    fi
    mv -- "$candidate" "$target"
    chmod "$mode" -- "$target"
    rm -f -- "$cleaned"
    printf 'Updated managed block: %s\n' "$target"
}

remove_managed_block() {
    local target=$1 start_marker=$2 end_marker=$3 cleaned backup_stamp
    [[ -L $target ]] && {
        printf 'Refusing to edit %s: managed files cannot be symbolic links.\n' "$target" >&2
        return 1
    }
    [[ -f $target ]] || return 0
    grep -Fqx -- "$start_marker" "$target" || return 0
    if ! validate_managed_markers "$target" "$start_marker" "$end_marker"; then
        printf 'Refusing to edit %s: unmatched Scriptorium markers.\n' "$target" >&2
        return 1
    fi
    cleaned=$(mktemp "$(dirname -- "$target")/.scriptorium-remove.XXXXXX")
    awk -v start="$start_marker" -v end="$end_marker" '
        $0 == start { skip = 1; next }
        $0 == end { skip = 0; next }
        !skip { print }
    ' "$target" >"$cleaned"
    backup_stamp=$(date -u +%Y%m%dT%H%M%SZ)
    cp -a -- "$target" "$target.backup-$backup_stamp"
    mv -- "$cleaned" "$target"
    printf 'Removed managed block: %s\n' "$target"
}
