#!/usr/bin/env bash
set -euo pipefail

repo_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
test_root=$(mktemp -d /tmp/scriptorium-managed-block.XXXXXX)
trap 'rm -rf -- "$test_root"' EXIT

source "$repo_dir/scripts/managed-block.sh"

managed_file=$test_root/managed.sh
cat >"$managed_file" <<'EOF'
export EXAMPLE=1
# >>> scriptorium managed >>>
export BLOCK=1
# <<< scriptorium managed <<<
export DONE=1
EOF

if ! validate_managed_markers "$managed_file" '# >>> scriptorium managed >>>' '# <<< scriptorium managed <<<'; then
    printf 'Expected valid managed markers to validate.\n' >&2
    exit 1
fi

cat >"$managed_file" <<'EOF'
export EXAMPLE=1
# >>> scriptorium managed >>>
export BLOCK=1
EOF
if validate_managed_markers "$managed_file" '# >>> scriptorium managed >>>' '# <<< scriptorium managed <<<'; then
    printf 'Expected unterminated marker block to fail.\n' >&2
    exit 1
fi

cat >"$managed_file" <<'EOF'
export EXAMPLE=1
# >>> scriptorium managed >>>
export BLOCK=1
# <<< scriptorium managed <<<
# <<< scriptorium managed <<<
EOF
if validate_managed_markers "$managed_file" '# >>> scriptorium managed >>>' '# <<< scriptorium managed <<<'; then
    printf 'Expected mismatched closing marker count to fail.\n' >&2
    exit 1
fi

cat >"$managed_file" <<'EOF'
export EXAMPLE=1
# >>> scriptorium managed >>>
export BLOCK=1
# <<< scriptorium managed <<<
export DONE=1
EOF
cp -- "$managed_file" "$test_root/original-managed.sh"
legacy_backup=
if ! remove_managed_block "$managed_file" '# >>> scriptorium managed >>>' \
    '# <<< scriptorium managed <<<' legacy_backup; then
    printf 'Expected valid managed markers to be removed.\n' >&2
    exit 1
fi
if grep -Fqx '# >>> scriptorium managed >>>' "$managed_file" \
    || grep -Fqx '# <<< scriptorium managed <<<' "$managed_file"; then
    printf 'Expected managed block content to be removed.\n' >&2
    exit 1
fi
[[ -f "$legacy_backup" ]]
if ! cmp -s "$test_root/original-managed.sh" "$legacy_backup"; then
    printf 'Expected backup file to preserve removed content.\n' >&2
    exit 1
fi

cat >"$managed_file" <<'EOF'
export EXAMPLE=1
# >>> scriptorium managed >>>
export BLOCK=1
EOF
if remove_managed_block "$managed_file" '# >>> scriptorium managed >>>' \
    '# <<< scriptorium managed <<<' > /dev/null; then
    printf 'Expected malformed removal to fail.\n' >&2
    exit 1
fi

printf 'Managed block smoke tests passed.\n'
