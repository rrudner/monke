# Scriptorium

**A portable, updateable Codex CLI workspace for Linux.**

Scriptorium gives you the same Codex profiles, instructions, terminal integration, and optional
developer tools on every machine—without taking ownership of your existing configuration.
Everything starts through one command: `scodex`.

## Why Scriptorium?

- Keep one setup in Git and deploy it consistently across machines.
- Check for repository updates when `scodex` starts, never during shell login.
- Choose between cheap, normal, and hard Codex profiles.
- Reuse installed tools or keep missing ones isolated from the system.
- Preserve personal Codex, shell, and tmux settings.

## Quick start

Codex, Git, Bash, standard GNU utilities, and util-linux (`flock`) must already be available.

```bash
git clone https://github.com/rrudner/scriptorium.git ~/.local/share/scriptorium/repo
~/.local/share/scriptorium/repo/install.sh
```

The installer supports Bash, Zsh, and Fish. It lets you choose:

- tmux integration—enabled by default when tmux is already installed;
- update checks on `scodex` startup—enabled by default;
- isolated optional tools—disabled by default.

Change these choices at any time with:

```bash
scodex configure
```

For unattended installation and all available flags, run `./install.sh --help`.

## Uninstall

Run `scodex uninstall` and confirm the prompt, or use `scodex uninstall --yes` for automation.
It removes only matching Scriptorium assets and marker-managed integration, retaining user files,
timestamped backups, and modified assets. A clean repository in the default data location is
removed last; pass `--keep-repo` to retain it. Invalid markers or symbolic-link paths stop before
any file is changed.

## Everyday commands

```bash
scodex                         # Start with the default Sol profile
scodex --cheap                 # Luna profile
scodex --normal                # Terra profile
scodex --hard                  # Sol profile
scodex --no-update             # Skip one repository update check

scodex update                  # Install the available repository update
scodex configure               # Change saved integration choices
scodex uninstall --keep-repo   # Remove integration and keep this repository
scodex tools configure         # Select optional tools in a terminal UI
scodex tools status            # Show active tools and their providers
scodex tools update            # Update locally managed tools
scodex tools remove NAME       # Remove a tool from the selection
```

## How it works

| Component | Location | Ownership |
|---|---|---|
| Repository | `~/.local/share/scriptorium/repo` | Git-managed |
| Preferences | `~/.config/scriptorium/preferences` | Scriptorium-managed |
| Launcher helper | `~/.local/bin/scriptorium-preferences.sh` | Scriptorium-managed |
| Codex profiles | `~/.codex/scriptorium-*.config.toml` | Scriptorium-managed |
| Codex instructions | `~/.codex/AGENTS.md` | Marker-managed block |
| Tmux settings | `~/.config/scriptorium/tmux.conf` | Scriptorium-managed |
| Shell and tmux hooks | User configuration files | Marker-managed blocks |
| Optional tool data | Matching XDG data/cache/state directories | Isolated |

`scodex` loads a namespaced Codex profile, exposes only the selected tool environment, checks for
updates when enabled, and then starts Codex. Your regular shell remains unchanged apart from the
small launcher and optional tmux blocks selected during installation.

## Safe by design

- `~/.codex/config.toml` is never replaced.
- User-owned files are edited only between explicit Scriptorium markers.
- Every changed user file receives a timestamped backup.
- Invalid, duplicated, or out-of-order markers stop the edit instead of guessing.
- Symlinked managed files and escaping parent symlinks are rejected.
- Failed installation restores the previous saved preferences.
- Modified legacy assets are preserved and reported.

Tmux settings are sourced at the beginning of `~/.tmux.conf`, so your later settings take
precedence. Scriptorium never installs or removes tmux itself.

## Repository updates

When enabled, startup performs a Git fetch with a 10-second limit. If a new commit exists, choose
`Install`, `Later`, or `View`. No response within 10 seconds selects `Later`; the same commit is
snoozed for 24 hours, while a newer commit is shown immediately.

Updates are fast-forward-only and skipped when the working tree is dirty or divergent. Network,
Git, or installation failures never prevent Codex from starting.

When an update adds optional tools, Scriptorium reports their names. If optional tools are
enabled, the next interactive `scodex` launch reopens the complete selector with existing choices
preselected. New entries are labeled `(new)` and remain unchecked until selected explicitly;
non-interactive launches keep the selection pending and show the command to run.

## Optional tools

<!-- BEGIN GENERATED OPTIONAL TOOLS -->
| Tool | Purpose | Selected by default |
|---|---|:---:|
| ripgrep (`rg`) | Fast recursive text search | Yes |
| fd | Fast and convenient file search | Yes |
| jq | Query and transform JSON | Yes |
| yq | Query and transform YAML | Yes |
| ShellCheck | Find problems in shell scripts | Yes |
| ast-grep | Search and rewrite code with syntax-aware patterns | Yes |
| GitHub CLI | Work with GitHub repositories and pull requests | No |
| SOPS | Encrypt configuration files and secrets | No |
| hyperfine | Benchmark commands | No |
| just | Run project commands defined in a `justfile` | No |
<!-- END GENERATED OPTIONAL TOOLS -->

The optional-tools module itself is disabled by default. Once enabled, existing system commands
win. Missing tools are installed without administrator access through a pinned,
checksum-verified, isolated mise runtime and are available only inside `scodex`.

Installing missing tools requires `curl` or `wget` and `sha256sum`. Repository updates never
upgrade tools; `scodex` checks for local tool updates at most weekly and only displays a notice.

## Verification

```bash
./tests/smoke.sh
./tests/tools-smoke.sh
./tests/update-smoke.sh
```

These suites cover safe installation and migration, tool isolation, update behavior, and failure
rollback without modifying the real home directory.

## Overlap policy

Scriptorium installs the `reuse-first` skill and an AGENTS rule that makes Codex invoke it
automatically before work that may duplicate existing behavior, ownership, helpers, services, or
error handling. Codex then:

- searches for semantic analogs,
- selects and reports one decision: `Reuse`, `Extend`, or `Create new`,
- proposes consolidation when overlap exists and performs it when it is within the requested scope,
- blocks a parallel implementation and proposes a migration follow-up when consolidation is out of
  scope.

Invoke it explicitly with `$reuse-first` when you want an audit or want to force this check before
a task. Re-run `./install.sh --apply-saved` after updating Scriptorium to deploy the latest skill
and AGENTS block.
