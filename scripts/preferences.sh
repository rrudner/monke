#!/usr/bin/env bash

read_pref() {
    local file=$1 key=$2 default=$3 value
    value=$(sed -n "s/^${key}=//p" "$file" 2>/dev/null | tail -n 1)
    printf '%s\n' "${value:-$default}"
}
