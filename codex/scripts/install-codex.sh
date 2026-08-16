#!/usr/bin/env bash
set -euo pipefail

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
package_dir=$(cd -- "$script_dir/.." && pwd)
repo_dir=$(cd -- "$package_dir/.." && pwd)
codex_home=${CODEX_HOME:-"$HOME/.codex"}
config_dir=${XDG_CONFIG_HOME:-"$HOME/.config"}/scriptorium
backup_stamp=$(date -u +%Y%m%dT%H%M%SZ)

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
        printf 'Unchanged: %s\n' "$target"
        return
    fi
    if [[ -e $target ]]; then
        cp -a -- "$target" "$target.backup-$backup_stamp"
        printf 'Backup: %s\n' "$target.backup-$backup_stamp"
    fi
    candidate=$(mktemp "$(dirname -- "$target")/.scriptorium-owned.XXXXXX")
    cp -- "$source" "$candidate"
    mv -- "$candidate" "$target"
    chmod 600 -- "$target"
    printf 'Installed Scriptorium asset: %s\n' "$target"
}

retire_if_identical() {
    local target=$1 expected=$2
    [[ -e $target ]] || return 0
    if cmp -s -- "$target" "$expected"; then
        mv -- "$target" "$target.backup-$backup_stamp"
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
        cp -a -- "$target" "$target.backup-$backup_stamp"
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

install_owned "$package_dir/profiles/scriptorium-cheap.config.toml" \
    "$codex_home/scriptorium-cheap.config.toml"
install_owned "$package_dir/profiles/scriptorium-normal.config.toml" \
    "$codex_home/scriptorium-normal.config.toml"
install_owned "$package_dir/profiles/scriptorium-hard.config.toml" \
    "$codex_home/scriptorium-hard.config.toml"
install_owned "$package_dir/agents/scriptorium-worker.toml" \
    "$codex_home/agents/scriptorium-worker.toml"
install_owned "$package_dir/skills/scriptorium-delegate/SKILL.md" \
    "$codex_home/skills/scriptorium-delegate/SKILL.md"
install_owned "$package_dir/skills/scriptorium-delegate/agents/openai.yaml" \
    "$codex_home/skills/scriptorium-delegate/agents/openai.yaml"
install_owned "$package_dir/skills/reuse-first/SKILL.md" \
    "$codex_home/skills/reuse-first/SKILL.md"
install_owned "$package_dir/skills/reuse-first/agents/openai.yaml" \
    "$codex_home/skills/reuse-first/agents/openai.yaml"
install_owned "$package_dir/skills/reuse-first/references/tooling.md" \
    "$codex_home/skills/reuse-first/references/tooling.md"

legacy_profile=$(mktemp "$codex_home/.legacy-profile.XXXXXX")
for profile in cheap normal hard; do
    awk '/^model =/{emit=1} emit && NF==0{exit} emit{print}' \
        "$package_dir/profiles/scriptorium-$profile.config.toml" >"$legacy_profile"
    retire_if_identical "$codex_home/$profile.config.toml" "$legacy_profile"
done
rm -f -- "$legacy_profile"

legacy_agent=$(mktemp "$codex_home/.legacy-agent.XXXXXX")
sed 's/^name = "scriptorium_worker"/name = "token_worker"/' \
    "$package_dir/agents/scriptorium-worker.toml" >"$legacy_agent"
retire_if_identical "$codex_home/agents/token-worker.toml" "$legacy_agent"
rm -f -- "$legacy_agent"

legacy_skill=$(mktemp "$codex_home/.legacy-skill.XXXXXX")
legacy_skill_yaml=$(mktemp "$codex_home/.legacy-skill-yaml.XXXXXX")
sed -e 's/^name: scriptorium-delegate$/name: delegate/' \
    -e 's/`scriptorium_worker`/`token_worker`/' \
    "$package_dir/skills/scriptorium-delegate/SKILL.md" >"$legacy_skill"
sed 's/\$scriptorium-delegate/\$delegate/' \
    "$package_dir/skills/scriptorium-delegate/agents/openai.yaml" >"$legacy_skill_yaml"
if [[ -f $codex_home/skills/delegate/SKILL.md ]] \
    && [[ -f $codex_home/skills/delegate/agents/openai.yaml ]] \
    && [[ $(find "$codex_home/skills/delegate" -type f | wc -l) -eq 2 ]] \
    && cmp -s -- "$codex_home/skills/delegate/SKILL.md" "$legacy_skill" \
    && cmp -s -- "$codex_home/skills/delegate/agents/openai.yaml" "$legacy_skill_yaml"; then
    mv -- "$codex_home/skills/delegate" "$codex_home/skills/delegate.backup-$backup_stamp"
    printf 'Retired legacy skill: %s\n' "$codex_home/skills/delegate"
elif [[ -e $codex_home/skills/delegate ]]; then
    printf 'Preserved modified legacy skill: %s\n' "$codex_home/skills/delegate" >&2
fi
rm -f -- "$legacy_skill" "$legacy_skill_yaml"

printf '\nCodex profiles configured without replacing the user base config.\n'
