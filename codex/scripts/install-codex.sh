#!/usr/bin/env bash
set -euo pipefail

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
package_dir=$(cd -- "$script_dir/.." && pwd)
repo_dir=$(cd -- "$package_dir/.." && pwd)
codex_home=${CODEX_HOME:-"$HOME/.codex"}
config_dir=${XDG_CONFIG_HOME:-"$HOME/.config"}/monke
source "$repo_dir/scripts/backup.sh"

install_owned() {
    local source=$1 target=$2 candidate root_real parent_real
    mkdir -p -- "$(dirname -- "$target")"
    root_real=$(cd -- "$codex_home" && pwd -P)
    parent_real=$(cd -- "$(dirname -- "$target")" && pwd -P)
    if [[ $parent_real != "$root_real" && $parent_real != "$root_real"/* ]]; then
        printf 'Refusing to install outside the physical Codex directory: %s\n' "$target" >&2
        return 1
    fi
    if [[ -f $target ]] && cmp -s -- "$source" "$target"; then
        prepare_backup_target "$target"
        printf 'Unchanged: %s\n' "$target"
        return
    fi
    prepare_backup_target "$target"
    if [[ -e $target ]]; then
        backup_target "$target"
    fi
    candidate=$(mktemp "$(dirname -- "$target")/.monke-owned.XXXXXX")
    cp -- "$source" "$candidate"
    mv -- "$candidate" "$target"
    chmod 600 -- "$target"
    printf 'Installed Monke asset: %s\n' "$target"
}

retire_if_identical() {
    local target=$1 expected=$2
    [[ -e $target ]] || return 0
    prepare_backup_target "$target"
    if cmp -s -- "$target" "$expected"; then
        backup_target "$target"
        rm -rf -- "$target"
        printf 'Retired legacy asset: %s\n' "$target"
    else
        printf 'Preserved modified legacy asset: %s\n' "$target" >&2
    fi
}

migrate_legacy_config() {
    local target=$codex_home/config.toml projects expected candidate
    if [[ -L $target ]]; then
        printf 'Preserved symbolic-link Codex config: %s\n' "$target" >&2
        return 0
    fi
    [[ -f $target ]] || return 0
    prepare_backup_target "$target"
    projects=$(mktemp "$codex_home/.legacy-projects.XXXXXX")
    expected=$(mktemp "$codex_home/.legacy-expected.XXXXXX")
    candidate=$(mktemp "$codex_home/.legacy-config.XXXXXX")
    trap 'rm -f -- "$projects" "$expected" "$candidate"' RETURN

    awk '
        /^\[projects\./ { keep = 1 }
        keep && /^\[/ && $0 !~ /^\[projects\./ { keep = 0 }
        keep { print }
    ' "$target" >"$projects"
    cp -- "$package_dir/config.toml" "$expected"
    if [[ -s $projects ]]; then
        printf '\n' >>"$expected"
        cat -- "$projects" >>"$expected"
    fi

    if cmp -s -- "$target" "$package_dir/config.toml" || cmp -s -- "$target" "$expected"; then
        backup_target "$target"
        cp -- "$projects" "$candidate"
        mv -- "$candidate" "$target"
        chmod 600 -- "$target"
        printf 'Migrated legacy Codex config; user project entries were preserved.\n'
    fi
    rm -f -- "$projects" "$expected" "$candidate"
    trap - RETURN
}

mkdir -p -- "$codex_home" "$config_dir"
migrate_legacy_config

install_owned "$package_dir/profiles/monke.config.toml" \
    "$codex_home/monke.config.toml"
install_owned "$package_dir/agents/monke-worker.toml" \
    "$codex_home/agents/monke-worker.toml"
install_owned "$package_dir/skills/monke-delegate/SKILL.md" \
    "$codex_home/skills/monke-delegate/SKILL.md"
install_owned "$package_dir/skills/monke-delegate/agents/openai.yaml" \
    "$codex_home/skills/monke-delegate/agents/openai.yaml"
install_owned "$package_dir/skills/compact-markdown/SKILL.md" \
    "$codex_home/skills/compact-markdown/SKILL.md"
install_owned "$package_dir/skills/compact-markdown/agents/openai.yaml" \
    "$codex_home/skills/compact-markdown/agents/openai.yaml"
install_owned "$package_dir/skills/reuse-first/SKILL.md" \
    "$codex_home/skills/reuse-first/SKILL.md"
install_owned "$package_dir/skills/reuse-first/agents/openai.yaml" \
    "$codex_home/skills/reuse-first/agents/openai.yaml"
install_owned "$package_dir/skills/reuse-first/references/tooling.md" \
    "$codex_home/skills/reuse-first/references/tooling.md"

legacy_profile=$(mktemp "$codex_home/.legacy-profile.XXXXXX")
legacy_profile_model=$(mktemp "$codex_home/.legacy-profile-model.XXXXXX")
for profile in cheap normal hard; do
    case $profile in
        cheap) profile_model='gpt-5.6-luna' ;;
        normal) profile_model='gpt-5.6-terra' ;;
        hard) profile_model='gpt-5.6-sol' ;;
    esac
    sed "s/^model = \".*\"/model = \"$profile_model\"/" \
        "$package_dir/profiles/monke.config.toml" >"$legacy_profile"
    retire_if_identical "$codex_home/monke-$profile.config.toml" "$legacy_profile"
    awk '/^model =/{emit=1} emit && NF==0{exit} emit{print}' \
        "$legacy_profile" >"$legacy_profile_model"
    retire_if_identical "$codex_home/$profile.config.toml" "$legacy_profile_model"
done
rm -f -- "$legacy_profile" "$legacy_profile_model"

legacy_agent=$(mktemp "$codex_home/.legacy-agent.XXXXXX")
sed 's/^name = "monke_worker"/name = "token_worker"/' \
    "$package_dir/agents/monke-worker.toml" >"$legacy_agent"
retire_if_identical "$codex_home/agents/token-worker.toml" "$legacy_agent"
rm -f -- "$legacy_agent"

legacy_skill=$(mktemp "$codex_home/.legacy-skill.XXXXXX")
legacy_skill_yaml=$(mktemp "$codex_home/.legacy-skill-yaml.XXXXXX")
legacy_skill_v1=0
[[ ! -e $codex_home/skills/delegate ]] || prepare_backup_target "$codex_home/skills/delegate"
sed -e 's/^name: monke-delegate$/name: delegate/' \
    -e 's/`monke_worker`/`token_worker`/' \
    "$package_dir/skills/monke-delegate/SKILL.md" >"$legacy_skill"
sed 's/\$monke-delegate/\$delegate/' \
    "$package_dir/skills/monke-delegate/agents/openai.yaml" >"$legacy_skill_yaml"
if [[ -f $codex_home/skills/delegate/SKILL.md ]] \
    && [[ -f $codex_home/skills/delegate/agents/openai.yaml ]] \
    && [[ $(find "$codex_home/skills/delegate" -type f | wc -l) -eq 2 ]] \
    && [[ $(sha256sum "$codex_home/skills/delegate/SKILL.md" | awk '{ print $1 }') \
        == 133767280a94d6f61c3977f0f4d371b15266666667a43118895239390ab4c597 ]] \
    && [[ $(sha256sum "$codex_home/skills/delegate/agents/openai.yaml" | awk '{ print $1 }') \
        == 6a3b29ff21c4fbe4d47fc271124dd5bb984e35efaf552f804b0f1466d4776edf ]]; then
    legacy_skill_v1=1
fi
if [[ -f $codex_home/skills/delegate/SKILL.md ]] \
    && [[ -f $codex_home/skills/delegate/agents/openai.yaml ]] \
    && [[ $(find "$codex_home/skills/delegate" -type f | wc -l) -eq 2 ]] \
    && { [[ $legacy_skill_v1 == 1 ]] \
        || { cmp -s -- "$codex_home/skills/delegate/SKILL.md" "$legacy_skill" \
            && cmp -s -- "$codex_home/skills/delegate/agents/openai.yaml" "$legacy_skill_yaml"; }; }; then
    backup_target "$codex_home/skills/delegate"
    rm -rf -- "$codex_home/skills/delegate"
    printf 'Retired legacy skill: %s\n' "$codex_home/skills/delegate"
elif [[ -e $codex_home/skills/delegate ]]; then
    printf 'Preserved modified legacy skill: %s\n' "$codex_home/skills/delegate" >&2
fi
rm -f -- "$legacy_skill" "$legacy_skill_yaml"

printf '\nCodex profiles configured without replacing the user base config.\n'
