#!/usr/bin/env bash
set -euo pipefail

repo_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
catalog=$repo_dir/tools/catalog.tsv
readme=$repo_dir/README.md
begin='<!-- BEGIN GENERATED OPTIONAL TOOLS -->'
end='<!-- END GENERATED OPTIONAL TOOLS -->'

table=$(awk -F '\t' '
    BEGIN { print "| Tool | Purpose | When to use | Selected by default |"; print "|---|---|---|:---:|" }
    !/^#/ && NF >= 8 {
        tool = ($1 == $2 ? $6 : $6 " (`" $2 "`)")
        printf "| %s | %s | %s | %s |\n", tool, $7, $8, ($4 == 1 ? "Yes" : "No")
    }
' "$catalog")

generated=$(mktemp "$repo_dir/.README.XXXXXX")
trap 'rm -f -- "$generated"' EXIT
awk -v begin="$begin" -v end="$end" -v table="$table" '
    $0 == begin { print; print table; inside=1; found_begin=1; next }
    $0 == end { inside=0; found_end=1; print; next }
    !inside { print }
    END { if (!found_begin || !found_end) exit 2 }
' "$readme" >"$generated"

if [[ ${1:-} == --check ]]; then
    cmp -s "$readme" "$generated"
elif [[ $# == 0 ]]; then
    mv -- "$generated" "$readme"
    trap - EXIT
else
    printf 'Usage: %s [--check]\n' "${0##*/}" >&2
    exit 2
fi
