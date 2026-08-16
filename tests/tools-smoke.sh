#!/usr/bin/env bash
set -euo pipefail

repo_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
test_root=$(mktemp -d /tmp/scriptorium-tools.XXXXXX)
trap 'rm -rf -- "$test_root"' EXIT
mkdir -p -- "$test_root/bin"

for command_name in rg fd jq yq shellcheck gh; do
    cat >"$test_root/bin/$command_name" <<EOF
#!/usr/bin/env bash
printf '%s test-version\n' '$command_name'
EOF
    chmod +x "$test_root/bin/$command_name"
done

PATH="$test_root/bin:$PATH" HOME="$test_root/home" \
    "$repo_dir/scripts/tools-manager.sh" configure \
    --select ripgrep,fd,jq,yq,shellcheck,gh >"$test_root/configure.log"

state=$test_root/home/.config/scriptorium/tools.state
[[ $(wc -l <"$state") -eq 6 ]]
awk -F '\t' '$2 != "system" {exit 1}' "$state"
grep -q '`ripgrep` (`rg`): system' \
    "$test_root/home/.config/scriptorium/capabilities.md"
[[ ! -e $test_root/home/.local/share/scriptorium/runtime/mise ]]

PATH="$test_root/bin:$PATH" HOME="$test_root/home" \
    "$repo_dir/scripts/tools-manager.sh" status >"$test_root/status.log"
grep -q '^ripgrep ' "$test_root/status.log"

PATH="$test_root/bin:$PATH" HOME="$test_root/home" \
    "$repo_dir/scripts/tools-manager.sh" remove gh >"$test_root/remove.log"
! grep -qx gh "$test_root/home/.config/scriptorium/tools.selected"
[[ -x $test_root/bin/gh ]]

HOME="$test_root/home" "$repo_dir/scripts/tools-manager.sh" clear
[[ ! -s $test_root/home/.config/scriptorium/tools.selected ]]

local_home=$test_root/local-home
runtime_dir=$local_home/.local/share/scriptorium/runtime
mkdir -p -- "$runtime_dir"
cat >"$runtime_dir/mise" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" >>"$MISE_TEST_LOG"
case ${1:-} in
    latest) printf '1.2.3\n' ;;
    outdated) printf 'just 1.2.3 1.2.4\n' ;;
esac
EOF
chmod +x "$runtime_dir/mise"
export MISE_TEST_LOG=$test_root/mise.log
HOME="$local_home" "$repo_dir/scripts/tools-manager.sh" configure --select just \
    >"$test_root/local-configure.log"
grep -q $'^just\tlocal\t1.2.3\tjust$' \
    "$local_home/.config/scriptorium/tools.state"
grep -q 'mise/shims' "$local_home/.config/scriptorium/tools-env.sh"
grep -q '^install just@1.2.3$' "$MISE_TEST_LOG"
HOME="$local_home" "$repo_dir/scripts/tools-manager.sh" remove just \
    >"$test_root/local-remove.log"
grep -q '^uninstall just@1.2.3$' "$MISE_TEST_LOG"

printf 'Tool smoke tests passed.\n'
