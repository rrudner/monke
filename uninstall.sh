#!/usr/bin/env bash
set -euo pipefail

repo_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
config_dir=${XDG_CONFIG_HOME:-"$HOME/.config"}/scriptorium
data_dir=${XDG_DATA_HOME:-"$HOME/.local/share"}/scriptorium
cache_dir=${XDG_CACHE_HOME:-"$HOME/.cache"}/scriptorium
state_dir=${XDG_STATE_HOME:-"$HOME/.local/state"}/scriptorium
bin_dir=${XDG_BIN_HOME:-"$HOME/.local/bin"}
codex_home=${CODEX_HOME:-"$HOME/.codex"}
preferences_file=$config_dir/preferences
assume_yes=0
keep_repo=0
shell_rc=
fish_target=${XDG_CONFIG_HOME:-"$HOME/.config"}/fish/conf.d/scriptorium.fish
fish_expected_plain=
shell_targets=()

usage() {
    cat <<'EOF'
Usage: ./uninstall.sh [options]

Remove Scriptorium-managed integration and assets without replacing user configuration.

  --yes        Do not ask for confirmation
  --keep-repo  Keep the repository even when it is the clean default data-directory clone
  -h, --help   Show this help
EOF
}

while (($#)); do
    case $1 in
        --yes) assume_yes=1 ;;
        --keep-repo) keep_repo=1 ;;
        -h|--help) usage; exit 0 ;;
        *) printf 'Unknown option: %s\n' "$1" >&2; usage >&2; exit 2 ;;
    esac
    shift
done

source "$repo_dir/scripts/managed-block.sh"

read_pref() {
    local key=$1 default=$2 value
    value=$(sed -n "s/^${key}=//p" "$preferences_file" 2>/dev/null | tail -n 1)
    printf '%s\n' "${value:-$default}"
}

fail_preflight() {
    printf 'Refusing to uninstall: %s\n' "$1" >&2
    exit 1
}

assert_safe_path() {
    local target=$1 current=$1 leaf=1
    while [[ $current != / && $current != . ]]; do
        [[ -L $current ]] && fail_preflight "symbolic-link path: $target"
        if [[ $leaf == 0 && -e $current && ! -d $current ]]; then
            fail_preflight "non-directory parent: $current"
        fi
        leaf=0
        current=$(dirname -- "$current")
    done
}

preflight_block() {
    local target=$1 start=$2 end=$3
    assert_safe_path "$target"
    [[ -e $target ]] || return 0
    [[ -f $target ]] || fail_preflight "managed file is not regular: $target"
    validate_managed_markers "$target" "$start" "$end" \
        || fail_preflight "invalid managed markers: $target"
}

same_directory() {
    local left=$1 right=$2
    [[ -d $left && -d $right ]] || return 1
    [[ $(cd -- "$left" && pwd -P) == $(cd -- "$right" && pwd -P) ]]
}

remove_if_identical() {
    local target=$1 expected=$2 label=$3
    [[ -e $target ]] || return 0
    if cmp -s -- "$target" "$expected"; then
        rm -f -- "$target"
        printf 'Removed %s: %s\n' "$label" "$target"
    else
        printf 'Preserved modified %s: %s\n' "$label" "$target" >&2
    fi
}

remove_owned_file() {
    local target=$1 label=$2
    [[ -e $target ]] || return 0
    rm -f -- "$target"
    printf 'Removed %s: %s\n' "$label" "$target"
}

remove_empty_dir() {
    local target=$1
    [[ -d $target && ! -L $target ]] && rmdir -- "$target" 2>/dev/null || true
}

shell_rc=$(read_pref shell_rc '')
add_shell_target() {
    local candidate=$1 existing
    [[ -n $candidate ]] || return 0
    for existing in "${shell_targets[@]}"; do
        [[ $existing == "$candidate" ]] && return 0
    done
    shell_targets+=("$candidate")
}

write_fish_expected() {
    printf 'fish_add_path -g %s\n' "$bin_dir" >"$1"
}

add_shell_target "$HOME/.bashrc"
add_shell_target "$HOME/.zshrc"
add_shell_target "$shell_rc"
fish_expected_plain=$(mktemp "${TMPDIR:-/tmp}/scriptorium-fish.XXXXXX")
trap 'rm -f -- "$fish_expected_plain"' EXIT
write_fish_expected "$fish_expected_plain"

# Validate every target before changing any user file. Backups are deliberately not targets.
for target in \
    "$preferences_file" "$config_dir/tools.selected" \
    "$config_dir/tools.state" "$config_dir/mise.toml" "$config_dir/tools-env.sh" \
    "$config_dir/capabilities.md" "$config_dir/tools.catalog-reviewed" \
    "$state_dir/deployed-commit" "$state_dir/update.state" \
    "$state_dir/last-update.log" "$state_dir/update.lock" "$state_dir/tools-update-check" \
    "$state_dir/tools-reconfigure-required" \
    "$data_dir/repo" "$data_dir/runtime" "$data_dir/mise" "$cache_dir/mise" "$state_dir/mise" \
    "$bin_dir/scodex" "$bin_dir/scriptorium-preferences.sh" "$codex_home/scriptorium-cheap.config.toml" \
    "$codex_home/scriptorium-normal.config.toml" "$codex_home/scriptorium-hard.config.toml" \
    "$codex_home/agents/scriptorium-worker.toml" \
    "$codex_home/skills/scriptorium-delegate/SKILL.md" \
    "$codex_home/skills/scriptorium-delegate/agents/openai.yaml" \
    "$codex_home/skills/compact-markdown/SKILL.md" \
    "$codex_home/skills/compact-markdown/agents/openai.yaml" \
    "$codex_home/skills/reuse-first/SKILL.md" \
    "$codex_home/skills/reuse-first/agents/openai.yaml" \
    "$codex_home/skills/reuse-first/references/tooling.md"; do
    assert_safe_path "$target"
done
preflight_block "$codex_home/AGENTS.md" '<!-- >>> scriptorium >>> -->' '<!-- <<< scriptorium <<< -->'
for target in "${shell_targets[@]}"; do
    preflight_block "$target" '# >>> scriptorium >>>' '# <<< scriptorium <<<'
done
assert_safe_path "$fish_target"

repo_candidate=$data_dir/repo
repo_can_remove=0
if [[ $keep_repo == 0 ]] && same_directory "$repo_dir" "$repo_candidate" \
    && same_directory "$(read_pref repo_dir '')" "$repo_candidate" \
    && git -C "$repo_candidate" rev-parse --is-inside-work-tree >/dev/null 2>&1 \
    && [[ -z $(git -C "$repo_candidate" status --porcelain) ]]; then
    repo_can_remove=1
fi

if [[ $assume_yes == 0 ]]; then
    if ! read -r -p 'Remove Scriptorium-managed files? [y/N] ' answer; then
        printf 'Uninstall cancelled.\n'
        exit 0
    fi
    case ${answer,,} in y|yes) ;; *) printf 'Uninstall cancelled.\n'; exit 0 ;; esac
fi

remove_managed_block "$codex_home/AGENTS.md" '<!-- >>> scriptorium >>> -->' '<!-- <<< scriptorium <<< -->'
for target in "${shell_targets[@]}"; do
    remove_managed_block "$target" '# >>> scriptorium >>>' '# <<< scriptorium <<<'
done

remove_if_identical "$codex_home/scriptorium-cheap.config.toml" \
    "$repo_dir/codex/profiles/scriptorium-cheap.config.toml" 'Codex profile'
remove_if_identical "$codex_home/scriptorium-normal.config.toml" \
    "$repo_dir/codex/profiles/scriptorium-normal.config.toml" 'Codex profile'
remove_if_identical "$codex_home/scriptorium-hard.config.toml" \
    "$repo_dir/codex/profiles/scriptorium-hard.config.toml" 'Codex profile'
remove_if_identical "$codex_home/agents/scriptorium-worker.toml" \
    "$repo_dir/codex/agents/scriptorium-worker.toml" 'Codex agent'
remove_if_identical "$codex_home/skills/scriptorium-delegate/SKILL.md" \
    "$repo_dir/codex/skills/scriptorium-delegate/SKILL.md" 'Codex skill'
remove_if_identical "$codex_home/skills/scriptorium-delegate/agents/openai.yaml" \
    "$repo_dir/codex/skills/scriptorium-delegate/agents/openai.yaml" 'Codex skill metadata'
remove_if_identical "$codex_home/skills/compact-markdown/SKILL.md" \
    "$repo_dir/codex/skills/compact-markdown/SKILL.md" 'Codex skill'
remove_if_identical "$codex_home/skills/compact-markdown/agents/openai.yaml" \
    "$repo_dir/codex/skills/compact-markdown/agents/openai.yaml" 'Codex skill metadata'
remove_if_identical "$codex_home/skills/reuse-first/SKILL.md" \
    "$repo_dir/codex/skills/reuse-first/SKILL.md" 'Codex skill'
remove_if_identical "$codex_home/skills/reuse-first/agents/openai.yaml" \
    "$repo_dir/codex/skills/reuse-first/agents/openai.yaml" 'Codex skill metadata'
remove_if_identical "$codex_home/skills/reuse-first/references/tooling.md" \
    "$repo_dir/codex/skills/reuse-first/references/tooling.md" 'Codex skill reference'
remove_if_identical "$bin_dir/scodex" "$repo_dir/bin/scodex" 'launcher'
remove_if_identical "$bin_dir/scriptorium-preferences.sh" "$repo_dir/scripts/preferences.sh" 'launcher helper'

if [[ -e $fish_target ]]; then
    if cmp -s -- "$fish_target" "$fish_expected_plain"; then
        rm -f -- "$fish_target"
        printf 'Removed Fish integration: %s\n' "$fish_target"
    else
        printf 'Preserved modified Fish integration: %s\n' "$fish_target" >&2
    fi
fi

for target in \
    "$preferences_file" "$config_dir/tools.selected" "$config_dir/tools.state" \
    "$config_dir/mise.toml" "$config_dir/tools-env.sh" "$config_dir/capabilities.md" \
    "$config_dir/tools.catalog-reviewed" \
    "$state_dir/deployed-commit" "$state_dir/update.state" "$state_dir/last-update.log" \
    "$state_dir/update.lock" "$state_dir/tools-update-check" \
    "$state_dir/tools-reconfigure-required"; do
    remove_owned_file "$target" 'Scriptorium state'
done

# These paths are populated only by the optional-tools runtime. Other XDG content, including
# timestamped backups, remains untouched.
for target in "$data_dir/runtime" "$data_dir/mise" "$cache_dir/mise" "$state_dir/mise"; do
    [[ -e $target ]] || continue
    rm -rf -- "$target"
    printf 'Removed optional-tools data: %s\n' "$target"
done

remove_empty_dir "$codex_home/skills/scriptorium-delegate/agents"
remove_empty_dir "$codex_home/skills/scriptorium-delegate"
remove_empty_dir "$codex_home/skills/compact-markdown/agents"
remove_empty_dir "$codex_home/skills/compact-markdown"
remove_empty_dir "$codex_home/skills/reuse-first/agents"
remove_empty_dir "$codex_home/skills/reuse-first/references"
remove_empty_dir "$codex_home/skills/reuse-first"
remove_empty_dir "$codex_home/skills"
remove_empty_dir "$codex_home/agents"
remove_empty_dir "$config_dir"
remove_empty_dir "$cache_dir"
remove_empty_dir "$state_dir"

# The repository is last: all cleanup above continues to work even when it is removed.
if [[ $repo_can_remove == 1 ]]; then
    rm -rf -- "$repo_candidate"
    printf 'Removed clean managed repository: %s\n' "$repo_candidate"
elif [[ $keep_repo == 1 ]]; then
    printf 'Kept repository by request: %s\n' "$repo_dir"
else
    printf 'Preserved repository (not the clean default managed clone): %s\n' "$repo_dir"
fi
remove_empty_dir "$data_dir"

printf 'Scriptorium uninstall complete. Backups remain in %s; user configuration and modified assets were preserved.\n' \
    "$state_dir/backups"
