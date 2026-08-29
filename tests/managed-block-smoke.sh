#!/usr/bin/env bash
set -euo pipefail

repo_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
test_root=$(mktemp -d /tmp/monke-managed-block.XXXXXX)
trap 'rm -rf -- "$test_root"' EXIT
export XDG_STATE_HOME=$test_root/state

source "$repo_dir/scripts/managed-block.sh"

backup_root=${XDG_STATE_HOME:-"$HOME/.local/state"}/monke/backups

managed_file=$test_root/managed.sh
cat >"$managed_file" <<'EOF'
export EXAMPLE=1
# >>> monke managed >>>
export BLOCK=1
# <<< monke managed <<<
export DONE=1
EOF

if ! validate_managed_markers "$managed_file" '# >>> monke managed >>>' '# <<< monke managed <<<'; then
    printf 'Expected valid managed markers to validate.\n' >&2
    exit 1
fi

cat >"$managed_file" <<'EOF'
export EXAMPLE=1
# >>> monke managed >>>
export BLOCK=1
EOF
if validate_managed_markers "$managed_file" '# >>> monke managed >>>' '# <<< monke managed <<<'; then
    printf 'Expected unterminated marker block to fail.\n' >&2
    exit 1
fi

cat >"$managed_file" <<'EOF'
export EXAMPLE=1
# >>> monke managed >>>
export BLOCK=1
# <<< monke managed <<<
# <<< monke managed <<<
EOF
if validate_managed_markers "$managed_file" '# >>> monke managed >>>' '# <<< monke managed <<<'; then
    printf 'Expected mismatched closing marker count to fail.\n' >&2
    exit 1
fi

cat >"$managed_file" <<'EOF'
export EXAMPLE=1
# >>> monke managed >>>
export BLOCK=1
# <<< monke managed <<<
export DONE=1
EOF
cp -- "$managed_file" "$test_root/original-managed.sh"
legacy_backup=
if ! remove_managed_block "$managed_file" '# >>> monke managed >>>' \
    '# <<< monke managed <<<' legacy_backup; then
    printf 'Expected valid managed markers to be removed.\n' >&2
    exit 1
fi
if grep -Fqx '# >>> monke managed >>>' "$managed_file" \
    || grep -Fqx '# <<< monke managed <<<' "$managed_file"; then
    printf 'Expected managed block content to be removed.\n' >&2
    exit 1
fi
[[ -f "$legacy_backup" ]]
if ! cmp -s "$test_root/original-managed.sh" "$legacy_backup"; then
    printf 'Expected backup file to preserve removed content.\n' >&2
    exit 1
fi

# Reapplying identical bytes must not create another backup.
cat >"$managed_file" <<'EOF'
export EXAMPLE=1
# >>> monke managed >>>
export BLOCK=1
# <<< monke managed <<<
export DONE=1
EOF
block_content=$(mktemp "$test_root/content.XXXXXX")
printf 'export BLOCK=1\n' >"$block_content"
update_managed_block "$managed_file" "$block_content" \
    '# >>> monke managed >>>' '# <<< monke managed <<<' append >/dev/null
backup_before=$(find "$backup_root" -type f -name 'backup-*' 2>/dev/null | wc -l)
before_bytes=$(mktemp "$test_root/before.XXXXXX")
cp -- "$managed_file" "$before_bytes"
update_managed_block "$managed_file" "$block_content" \
    '# >>> monke managed >>>' '# <<< monke managed <<<' append >/dev/null
cmp -s "$before_bytes" "$managed_file"
[[ $(find "$backup_root" -type f -name 'backup-*' 2>/dev/null | wc -l) -eq $backup_before ]]
rm -f -- "$block_content" "$before_bytes"

# Replacing a block must preserve every user byte around it.
printf 'user-prefix\n\n# >>> monke managed >>>\nold\n# <<< monke managed <<<\nuser-suffix' \
    >"$managed_file"
block_content=$(mktemp "$test_root/content.XXXXXX")
printf 'new\n' >"$block_content"
update_managed_block "$managed_file" "$block_content" \
    '# >>> monke managed >>>' '# <<< monke managed <<<' append >/dev/null
expected_file=$test_root/expected-managed.sh
printf 'user-prefix\n\n# >>> monke managed >>>\nnew\n# <<< monke managed <<<\nuser-suffix' \
    >"$expected_file"
cmp -s "$expected_file" "$managed_file"
rm -f -- "$block_content"

# Five snapshots of one target retain only the newest three.
retention_target=$test_root/retention.txt
for version in 1 2 3 4 5; do
    printf '%s\n' "$version" >"$retention_target"
    backup_target "$retention_target" >/dev/null
done
retention_dir=$(backup_target_dir "$retention_target")
[[ $(find "$retention_dir" -maxdepth 1 -name 'backup-*' | wc -l) -eq 3 ]]
[[ $(stat -c '%a' "$backup_root") == 700 ]]

# Migrate only exact legacy names; leave user lookalikes alone.
migration_target=$test_root/migration.txt
printf 'old\n' >"$migration_target.backup-20240101T000000Z"
printf 'mine\n' >"$migration_target.backup-user"
prepare_backup_target "$migration_target"
[[ ! -e $migration_target.backup-20240101T000000Z ]]
[[ -f $migration_target.backup-user ]]
migration_dir=$(backup_target_dir "$migration_target")
[[ $(find "$migration_dir" -maxdepth 1 -name 'backup-20240101T000000Z-*' | wc -l) -eq 1 ]]

cat >"$managed_file" <<'EOF'
export EXAMPLE=1
# >>> monke managed >>>
export BLOCK=1
EOF
if remove_managed_block "$managed_file" '# >>> monke managed >>>' \
    '# <<< monke managed <<<' > /dev/null; then
    printf 'Expected malformed removal to fail.\n' >&2
    exit 1
fi

printf 'Managed block smoke tests passed.\n'
