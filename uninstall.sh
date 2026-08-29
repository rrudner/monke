#!/usr/bin/env bash
set -euo pipefail

repo_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
config_dir=${XDG_CONFIG_HOME:-"$HOME/.config"}/monke
data_dir=${XDG_DATA_HOME:-"$HOME/.local/share"}/monke
cache_dir=${XDG_CACHE_HOME:-"$HOME/.cache"}/monke
state_dir=${XDG_STATE_HOME:-"$HOME/.local/state"}/monke
bin_dir=${XDG_BIN_HOME:-"$HOME/.local/bin"}
codex_home=${CODEX_HOME:-"$HOME/.codex"}
preferences_file=$config_dir/preferences
assume_yes=0
keep_repo=0
shell_rc=
fish_target=${XDG_CONFIG_HOME:-"$HOME/.config"}/fish/conf.d/monke.fish
fish_expected_plain=
shell_targets=()

usage() {
    cat <<'EOF'
Usage: ./uninstall.sh [options]

Remove Monke-managed integration and assets without replacing user configuration.

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
fish_expected_plain=$(mktemp "${TMPDIR:-/tmp}/monke-fish.XXXXXX")
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
    "$bin_dir/monke" "$bin_dir/monke-preferences.sh" "$codex_home/monke.config.toml" \
    "$codex_home/monke-cheap.config.toml" "$codex_home/monke-normal.config.toml" \
    "$codex_home/monke-hard.config.toml" "$codex_home/cheap.config.toml" "$codex_home/normal.config.toml" \
    "$codex_home/hard.config.toml" \
    "$codex_home/agents/monke-worker.toml" \
    "$codex_home/skills/btw/SKILL.md" \
    "$codex_home/skills/btw/agents/openai.yaml" \
    "$codex_home/skills/monke-delegate/SKILL.md" \
    "$codex_home/skills/monke-delegate/agents/openai.yaml" \
    "$codex_home/skills/compact-markdown/SKILL.md" \
    "$codex_home/skills/compact-markdown/agents/openai.yaml" \
    "$codex_home/skills/reuse-first/SKILL.md" \
    "$codex_home/skills/reuse-first/agents/openai.yaml" \
    "$codex_home/skills/reuse-first/references/tooling.md"; do
    assert_safe_path "$target"
done
preflight_block "$codex_home/AGENTS.md" '<!-- >>> monke >>> -->' '<!-- <<< monke <<< -->'
for target in "${shell_targets[@]}"; do
    preflight_block "$target" '# >>> monke >>>' '# <<< monke <<<'
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
    if ! read -r -p 'Remove Monke-managed files? [y/N] ' answer; then
        printf 'Uninstall cancelled.\n'
        exit 0
    fi
    case ${answer,,} in y|yes) ;; *) printf 'Uninstall cancelled.\n'; exit 0 ;; esac
fi

remove_managed_block "$codex_home/AGENTS.md" '<!-- >>> monke >>> -->' '<!-- <<< monke <<< -->'
for target in "${shell_targets[@]}"; do
    remove_managed_block "$target" '# >>> monke >>>' '# <<< monke <<<'
done

remove_if_identical "$codex_home/monke.config.toml" \
    "$repo_dir/codex/profiles/monke.config.toml" 'Codex profile'
legacy_profile=$(mktemp "$codex_home/.legacy-profile.XXXXXX")
legacy_profile_model=$(mktemp "$codex_home/.legacy-profile-model.XXXXXX")
for profile in cheap normal hard; do
    case $profile in
        cheap) profile_model='gpt-5.6-luna' ;;
        normal) profile_model='gpt-5.6-terra' ;;
        hard) profile_model='gpt-5.6-sol' ;;
    esac
    sed "s/^model = \".*\"/model = \"$profile_model\"/" \
        "$repo_dir/codex/profiles/monke.config.toml" \
        >"$legacy_profile"
    remove_if_identical "$codex_home/monke-$profile.config.toml" "$legacy_profile" 'Codex legacy profile'
    awk '/^model =/{emit=1} emit && NF==0{exit} emit{print}' \
        "$legacy_profile" >"$legacy_profile_model"
    remove_if_identical "$codex_home/$profile.config.toml" "$legacy_profile_model" 'Codex legacy profile'
done
rm -f -- "$legacy_profile" "$legacy_profile_model"
remove_if_identical "$codex_home/agents/monke-worker.toml" \
    "$repo_dir/codex/agents/monke-worker.toml" 'Codex agent'
remove_if_identical "$codex_home/skills/btw/SKILL.md" \
    "$repo_dir/codex/skills/btw/SKILL.md" 'Codex skill'
remove_if_identical "$codex_home/skills/btw/agents/openai.yaml" \
    "$repo_dir/codex/skills/btw/agents/openai.yaml" 'Codex skill metadata'
remove_if_identical "$codex_home/skills/monke-delegate/SKILL.md" \
    "$repo_dir/codex/skills/monke-delegate/SKILL.md" 'Codex skill'
remove_if_identical "$codex_home/skills/monke-delegate/agents/openai.yaml" \
    "$repo_dir/codex/skills/monke-delegate/agents/openai.yaml" 'Codex skill metadata'
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
remove_if_identical "$bin_dir/monke" "$repo_dir/bin/monke" 'launcher'
remove_if_identical "$bin_dir/monke-preferences.sh" "$repo_dir/scripts/preferences.sh" 'launcher helper'

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
    remove_owned_file "$target" 'Monke state'
done

# These paths are populated only by the optional-tools runtime. Other XDG content, including
# timestamped backups, remains untouched.
for target in "$data_dir/runtime" "$data_dir/mise" "$cache_dir/mise" "$state_dir/mise"; do
    [[ -e $target ]] || continue
    rm -rf -- "$target"
    printf 'Removed optional-tools data: %s\n' "$target"
done

remove_empty_dir "$codex_home/skills/monke-delegate/agents"
remove_empty_dir "$codex_home/skills/monke-delegate"
remove_empty_dir "$codex_home/skills/btw/agents"
remove_empty_dir "$codex_home/skills/btw"
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

printf 'Monke uninstall complete. Backups remain in %s; user configuration and modified assets were preserved.\n' \
    "$state_dir/backups"
