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

## Everyday commands

```bash
scodex                         # Start with the default Sol profile
scodex --cheap                 # Luna profile
scodex --normal                # Terra profile
scodex --hard                  # Sol profile
scodex --no-update             # Skip one repository update check

scodex update                  # Install the available repository update
scodex configure               # Change saved integration choices
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

## Optional tools

| Default on | Default off |
|---|---|
| ripgrep (`rg`) | GitHub CLI (`gh`) |
| fd | SOPS |
| jq | hyperfine |
| yq | just |
| ShellCheck | |

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
