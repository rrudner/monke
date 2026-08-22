#!/usr/bin/env bash
set -euo pipefail

repo_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
test_root=$(mktemp -d /tmp/scriptorium-tools.XXXXXX)
trap 'rm -rf -- "$test_root"' EXIT
mkdir -p -- "$test_root/bin"

for command_name in rg fd jq yq shellcheck shfmt ast-grep gh; do
    cat >"$test_root/bin/$command_name" <<EOF
#!/usr/bin/env bash
printf '%s test-version\n' '$command_name'
EOF
    chmod +x "$test_root/bin/$command_name"
done

PATH="$test_root/bin:$PATH" HOME="$test_root/home" \
    "$repo_dir/scripts/tools-manager.sh" configure \
    --select ripgrep,fd,jq,yq,shellcheck,shfmt,ast-grep,gh >"$test_root/configure.log"

state=$test_root/home/.config/scriptorium/tools.state
[[ $(wc -l <"$state") -eq 8 ]]
awk -F '\t' '$2 != "system" {exit 1}' "$state"
grep -q '`ripgrep` (`rg`): system' \
    "$test_root/home/.config/scriptorium/capabilities.md"
grep -q 'Fast recursive text search' "$test_root/home/.config/scriptorium/capabilities.md"
grep -q 'Use first for targeted text, symbol, and file-content discovery.' \
    "$test_root/home/.config/scriptorium/capabilities.md"
grep -q '`ast-grep` (`ast-grep`): system' \
    "$test_root/home/.config/scriptorium/capabilities.md"
grep -q '`shfmt` (`shfmt`): system' \
    "$test_root/home/.config/scriptorium/capabilities.md"
grep -qx ast-grep "$test_root/home/.config/scriptorium/tools.catalog-reviewed"
[[ ! -e $test_root/home/.local/state/scriptorium/tools-reconfigure-required ]]
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
shim_dir=$local_home/.local/share/scriptorium/mise/shims
mkdir -p -- "$shim_dir"
cat >"$shim_dir/just" <<'EOF'
#!/usr/bin/env bash
printf 'mise shim\n'
EOF
chmod +x "$shim_dir/just"
cat >"$shim_dir/playwright-cli" <<'EOF'
#!/usr/bin/env bash
if [[ ${1:-} == install-browser ]]; then
    browser_dir=$PLAYWRIGHT_BROWSERS_PATH/chromium-123/chrome-linux64
    mkdir -p -- "$browser_dir"
    printf '#!/usr/bin/env bash\n' >"$browser_dir/chrome"
    chmod +x "$browser_dir/chrome"
fi
printf 'playwright shim\n'
EOF
chmod +x "$shim_dir/playwright-cli"
cat >"$test_root/bin/node" <<'EOF'
#!/usr/bin/env bash
printf 'v22.19.0\n'
EOF
chmod +x "$test_root/bin/node"
PATH="$shim_dir:$test_root/bin:/usr/bin:/bin" HOME="$local_home" "$repo_dir/scripts/tools-manager.sh" configure --select just \
    >"$test_root/local-configure.log"
grep -q $'^just\tlocal\t1.2.3\tjust$' \
    "$local_home/.config/scriptorium/tools.state"
grep -q 'export PATH=.*mise/shims' "$local_home/.config/scriptorium/tools-env.sh"
grep -q '^install just@1.2.3$' "$MISE_TEST_LOG"
PATH="$test_root/bin:/usr/bin:/bin" HOME="$local_home" "$repo_dir/scripts/tools-manager.sh" remove just \
    >"$test_root/local-remove.log"
grep -q '^uninstall just@1.2.3$' "$MISE_TEST_LOG"

PATH="$shim_dir:$test_root/bin:/usr/bin:/bin" HOME="$local_home" \
    "$repo_dir/scripts/tools-manager.sh" configure --select playwright-cli \
    >"$test_root/playwright-configure.log"
grep -q $'^playwright-cli\tlocal\t1.2.3\tplaywright-cli$' \
    "$local_home/.config/scriptorium/tools.state"
grep -q '^install npm:@playwright/cli@1.2.3$' "$MISE_TEST_LOG"
grep -q '^"npm:@playwright/cli" = "1.2.3"$' \
    "$local_home/.config/scriptorium/mise.toml"
grep -q '^export PLAYWRIGHT_BROWSERS_PATH=.*scriptorium/playwright' \
    "$local_home/.config/scriptorium/tools-env.sh"
grep -q '^export CHROME_PATH=.*chromium-123/chrome-linux64/chrome' \
    "$local_home/.config/scriptorium/tools-env.sh"
grep -q '^export PLAYWRIGHT_MCP_EXECUTABLE_PATH=.*chromium-123/chrome-linux64/chrome' \
    "$local_home/.config/scriptorium/tools-env.sh"

cat >"$shim_dir/lighthouse" <<'EOF'
#!/usr/bin/env bash
printf 'lighthouse shim\n'
EOF
chmod +x "$shim_dir/lighthouse"
PATH="$shim_dir:$test_root/bin:/usr/bin:/bin" HOME="$local_home" \
    "$repo_dir/scripts/tools-manager.sh" configure --select lighthouse \
    >"$test_root/lighthouse-configure.log"
grep -q $'^lighthouse\tlocal\t1.2.3\tlighthouse$' \
    "$local_home/.config/scriptorium/tools.state"
grep -q '^install npm:lighthouse@1.2.3$' "$MISE_TEST_LOG"
grep -q '^"npm:lighthouse" = "1.2.3"$' \
    "$local_home/.config/scriptorium/mise.toml"
grep -q '^"npm:@playwright/cli" = "1.2.3"$' \
    "$local_home/.config/scriptorium/mise.toml"
grep -q '^export CHROME_PATH=.*chromium-123/chrome-linux64/chrome' \
    "$local_home/.config/scriptorium/tools-env.sh"
grep -q '^export PLAYWRIGHT_MCP_EXECUTABLE_PATH=.*chromium-123/chrome-linux64/chrome' \
    "$local_home/.config/scriptorium/tools-env.sh"

old_node_home=$test_root/old-node-home
old_node_bin=$test_root/old-node-bin
mkdir -p -- "$old_node_bin"
cat >"$old_node_bin/node" <<'EOF'
#!/usr/bin/env bash
printf 'v20.19.0\n'
EOF
chmod +x "$old_node_bin/node"
PATH="$old_node_bin:/usr/bin:/bin" HOME="$old_node_home" \
    "$repo_dir/scripts/tools-manager.sh" configure --select lighthouse \
    >"$test_root/old-node.log" 2>&1
grep -qx lighthouse "$old_node_home/.config/scriptorium/tools.selected"
[[ ! -s $old_node_home/.config/scriptorium/tools.state ]]
grep -q 'Skipping lighthouse: Node.js 22 or newer is required.' "$test_root/old-node.log"

# Users upgrading from a version without catalog-review state must be prompted for new defaults.
legacy_home=$test_root/legacy-home
mkdir -p -- "$legacy_home/.config/scriptorium"
printf '%s\n' ripgrep fd jq yq shellcheck >"$legacy_home/.config/scriptorium/tools.selected"
PATH="$test_root/bin:$PATH" HOME="$legacy_home" \
    "$repo_dir/scripts/tools-manager.sh" reconcile
[[ "$(cat "$legacy_home/.local/state/scriptorium/tools-reconfigure-required")" == \
    $'ast-grep\nshfmt' ]]
printf '\n' | PATH="$test_root/bin:$PATH" HOME="$legacy_home" \
    script -qec "'$repo_dir/scripts/tools-manager.sh' configure --review ast-grep,shfmt" /dev/null \
    >"$test_root/legacy-configure.log"
[[ ! -e $legacy_home/.local/state/scriptorium/tools-reconfigure-required ]]
grep -qx ast-grep "$legacy_home/.config/scriptorium/tools.catalog-reviewed"
grep -q 'New tools: ast-grep,shfmt' "$test_root/legacy-configure.log"
grep -q 'ast-grep (new)' "$test_root/legacy-configure.log"
grep -q 'shfmt (new)' "$test_root/legacy-configure.log"
grep -qx ripgrep "$legacy_home/.config/scriptorium/tools.selected"
! grep -qx ast-grep "$legacy_home/.config/scriptorium/tools.selected"
! grep -qx shfmt "$legacy_home/.config/scriptorium/tools.selected"

# Contract tests for `catalog-diff`.
catalog_before=$test_root/catalog-before.tsv
catalog_after=$test_root/catalog-after.tsv
cat >"$catalog_before" <<'EOF'
# name	command	mise-id	default	tier	label	description
zeta	zeta	-	0	advanced	Zeta tool	Zeta
alpha	alpha	-	0	advanced	Alpha tool	Alpha
EOF
cat >"$catalog_after" <<'EOF'
# name	command	mise-id	default	tier	label	description
alpha	alpha	-	0	advanced	Alpha tool	Alpha
zeta	zeta	-	0	advanced	Zeta tool	Zeta
beta	beta	-	0	advanced	Beta tool	Beta
gamma	gamma	-	0	advanced	Gamma tool	Gamma
EOF
PATH="$test_root/bin:$PATH" HOME="$test_root/home" \
    "$repo_dir/scripts/tools-manager.sh" catalog-diff "$catalog_before" "$catalog_after" 0 \
    | tee "$test_root/catalog-diff.log"
[[ "$(cat "$test_root/catalog-diff.log")" == $'beta\ngamma' ]]
grep -qx beta "$test_root/catalog-diff.log"
grep -qx gamma "$test_root/catalog-diff.log"

cat >"$test_root/home/.local/state/scriptorium/tools-reconfigure-required" <<'EOF'
ast-grep
EOF
PATH="$test_root/bin:$PATH" HOME="$test_root/home" \
    "$repo_dir/scripts/tools-manager.sh" catalog-diff "$catalog_before" "$catalog_after" 1 \
    >"$test_root/catalog-diff-merge.log"
grep -qx ast-grep "$test_root/home/.local/state/scriptorium/tools-reconfigure-required"
grep -qx beta "$test_root/home/.local/state/scriptorium/tools-reconfigure-required"
grep -qx gamma "$test_root/home/.local/state/scriptorium/tools-reconfigure-required"
[[ "$(cat "$test_root/home/.local/state/scriptorium/tools-reconfigure-required")" == $'ast-grep\nbeta\ngamma' ]]

cat >"$test_root/home/.local/state/scriptorium/tools-reconfigure-required" <<'EOF'
ast-grep
EOF
PATH="$test_root/bin:$PATH" HOME="$test_root/home" \
    "$repo_dir/scripts/tools-manager.sh" catalog-diff "$catalog_before" "$catalog_after" 0 \
    >"$test_root/catalog-diff-disabled.log"
[[ "$(cat "$test_root/home/.local/state/scriptorium/tools-reconfigure-required")" == $'ast-grep' ]]

"$repo_dir/scripts/generate-tools-readme.sh" --check

printf 'Tool smoke tests passed.\n'
