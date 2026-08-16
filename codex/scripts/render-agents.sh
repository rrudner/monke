#!/usr/bin/env bash
set -euo pipefail

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
package_dir=$(cd -- "$script_dir/.." && pwd)
repo_dir=$(cd -- "$package_dir/.." && pwd)
codex_home=${CODEX_HOME:-"$HOME/.codex"}
config_dir=${XDG_CONFIG_HOME:-"$HOME/.config"}/scriptorium
capabilities_file=$config_dir/capabilities.md
target=$codex_home/AGENTS.md
start_marker='<!-- >>> scriptorium >>> -->'
end_marker='<!-- <<< scriptorium <<< -->'

source "$repo_dir/scripts/managed-block.sh"
mkdir -p -- "$codex_home"
content=$(mktemp "$codex_home/.scriptorium-agents.XXXXXX")
trap 'rm -f -- "$content"' EXIT
cat -- "$package_dir/AGENTS.md" >"$content"
cat >>"$content" <<'EOF'

## Scriptorium runtime

- Apply Scriptorium-specific delegation and tool instructions only when
  `SCRIPTORIUM_ACTIVE=1` is present in the environment.
- Verify a command with `command -v` before relying on it.
EOF
if [[ -s $capabilities_file ]]; then
    printf '\n' >>"$content"
    cat -- "$capabilities_file" >>"$content"
else
    printf '%s\n' '- No optional Scriptorium tools are currently available.' >>"$content"
fi
if grep -qx 'tmux=1' "$config_dir/preferences" 2>/dev/null && command -v tmux >/dev/null 2>&1; then
    printf '%s\n' '- `tmux`: system, available for persistent terminal sessions.' >>"$content"
fi

update_managed_block "$target" "$content" "$start_marker" "$end_marker" append \
    "$package_dir/AGENTS.md"
