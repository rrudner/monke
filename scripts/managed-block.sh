#!/usr/bin/env bash

managed_block_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
source "$managed_block_dir/backup.sh"

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
    local legacy_source=${6:-} target_dir candidate mode start_line end_line

    if [[ -L $target ]]; then
        printf 'Refusing to edit %s: managed files cannot be symbolic links.\n' "$target" >&2
        return 1
    fi
    target_dir=$(dirname -- "$target")
    mkdir -p -- "$target_dir"
    candidate=$(mktemp "$target_dir/.scriptorium-candidate.XXXXXX")

    prepare_backup_target "$target" || { rm -f -- "$candidate"; return 1; }

    if [[ -f $target ]] \
        && { [[ -z $legacy_source ]] || ! cmp -s -- "$target" "$legacy_source"; }; then
        if ! validate_managed_markers "$target" "$start_marker" "$end_marker"; then
            printf 'Refusing to edit %s: unmatched Scriptorium markers.\n' "$target" >&2
            rm -f -- "$candidate"
            return 1
        fi
        read -r start_line end_line < <(awk -v start="$start_marker" -v end="$end_marker" '
            $0 == start { first = NR } $0 == end { last = NR }
            END { print first, last }
        ' "$target")
    else
        start_line=''
        end_line=''
    fi

    if [[ -n $start_line ]]; then
        head -n "$((start_line - 1))" -- "$target" >"$candidate"
        printf '%s\n' "$start_marker" >>"$candidate"
        cat -- "$content" >>"$candidate"
        [[ ! -s $content || $(tail -c 1 "$content" | wc -l) -eq 1 ]] || printf '\n' >>"$candidate"
        printf '%s\n' "$end_marker" >>"$candidate"
        tail -n "+$((end_line + 1))" -- "$target" >>"$candidate"
    elif [[ $position == prepend ]]; then
        printf '%s\n' "$start_marker" >"$candidate"
        cat -- "$content" >>"$candidate"
        [[ ! -s $content || $(tail -c 1 "$content" | wc -l) -eq 1 ]] || printf '\n' >>"$candidate"
        printf '%s\n' "$end_marker" >>"$candidate"
        [[ ! -s $target ]] || { printf '\n' >>"$candidate"; cat -- "$target" >>"$candidate"; }
    else
        [[ ! -f $target ]] || cat -- "$target" >"$candidate"
        [[ ! -s $target ]] || printf '\n' >>"$candidate"
        printf '%s\n' "$start_marker" >>"$candidate"
        cat -- "$content" >>"$candidate"
        [[ ! -s $content || $(tail -c 1 "$content" | wc -l) -eq 1 ]] || printf '\n' >>"$candidate"
        printf '%s\n' "$end_marker" >>"$candidate"
    fi

    if [[ -f $target ]] && cmp -s -- "$candidate" "$target"; then
        rm -f -- "$candidate"
        printf 'Unchanged: %s\n' "$target"
        return
    fi

    if [[ -e $target ]]; then
        backup_target "$target"
        mode=$(stat -c '%a' "$target" 2>/dev/null || printf '600')
    else
        mode=600
    fi
    mv -- "$candidate" "$target"
    chmod "$mode" -- "$target"
    printf 'Updated managed block: %s\n' "$target"
}

remove_managed_block() {
    local target=$1 start_marker=$2 end_marker=$3 cleaned backup_path mode backup_output=${4-}
    [[ -L $target ]] && {
        printf 'Refusing to edit %s: managed files cannot be symbolic links.\n' "$target" >&2
        return 1
    }
    [[ -f $target ]] || return 0
    prepare_backup_target "$target" || return 1
    grep -Fqx -- "$start_marker" "$target" || return 0
    if ! validate_managed_markers "$target" "$start_marker" "$end_marker"; then
        printf 'Refusing to edit %s: unmatched Scriptorium markers.\n' "$target" >&2
        return 1
    fi
    cleaned=$(mktemp "$(dirname -- "$target")/.scriptorium-remove.XXXXXX")
    local start_line end_line
    read -r start_line end_line < <(awk -v start="$start_marker" -v end="$end_marker" '
        $0 == start { first = NR } $0 == end { last = NR }
        END { print first, last }
    ' "$target")
    head -n "$((start_line - 1))" -- "$target" >"$cleaned"
    tail -n "+$((end_line + 1))" -- "$target" >>"$cleaned"
    mode=$(stat -c '%a' "$target" 2>/dev/null || printf '600')
    backup_target "$target" backup_path
    mv -- "$cleaned" "$target"
    chmod "$mode" -- "$target"
    if [[ -n $backup_output ]]; then
        printf -v "$backup_output" '%s' "$backup_path"
    fi
    printf 'Removed managed block: %s\n' "$target"
}
