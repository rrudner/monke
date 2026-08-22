# Scriptorium

**A portable, updateable Codex CLI workspace for Linux.**

Scriptorium gives you the same Codex profiles, instructions, terminal integration, and optional
developer tools on every machine, without taking ownership of your existing configuration.
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

- tmux integration, enabled by default when tmux is already installed;
- update checks on `scodex` startup, enabled by default;
- isolated optional tools, disabled by default.

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
scodex context                 # Show current main-context pressure for diagnostics
scodex stats                   # Show readable token usage for the current project
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
| Project token statistics | `.scriptorium/stats` in a launched project | Replaced after each completed `scodex` run |

`scodex` loads a namespaced Codex profile, exposes only the selected tool environment, checks for
updates when enabled, and then starts Codex. Your regular shell remains unchanged apart from the
small launcher and optional tmux blocks selected during installation.

Scriptorium keeps small, single-goal work local. Before broad exploration it reads only the current
thread's token counters through `scodex context`, then lowers the delegation threshold as the main
context fills. It delegates only unopened file or log context that a concise worker result can
replace; having a separate Spark usage limit alone is not treated as a token saving. Missing or
incompatible telemetry falls back to the conservative low-pressure threshold.

`scodex stats` sums token telemetry for the current project thread, including delegate sessions.
It reports the complete thread, the last completed launcher run (including `resume`), and the last
main-agent turn. The project marker contains only the thread ID and run start time.

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
| Tool | Purpose | When to use | Selected by default |
|---|---|---|:---:|
| ripgrep (`rg`) | Fast recursive text search | Use first for targeted text, symbol, and file-content discovery. | Yes |
| fd | Fast and convenient file search | Use to locate files by name, extension, type, or directory. | Yes |
| jq | Query and transform JSON | Use for precise JSON inspection, filtering, validation, and transformation. | Yes |
| yq | Query and transform YAML | Use for precise YAML inspection, filtering, validation, and transformation. | Yes |
| ShellCheck | Find problems in shell scripts | Use after shell changes to detect correctness and portability issues. | Yes |
| shfmt | Format shell scripts consistently with syntax-aware formatting | Use to check or apply consistent shell formatting after edits. | Yes |
| ast-grep | Search and rewrite code with syntax-aware patterns | Use when syntax-aware matching or a safe structural rewrite is better than text search. | Yes |
| GitHub CLI | Work with GitHub repositories and pull requests | Use for GitHub issues, pull requests, checks, releases, and repository metadata. | No |
| SOPS | Encrypt configuration files and secrets | Use for encrypted configuration and secret files without exposing plaintext. | No |
| hyperfine | Benchmark commands | Use to compare command performance with repeatable measurements. | No |
| just | Run project commands defined in a `justfile` | Use existing project recipes instead of reconstructing their commands manually. | No |
| Playwright CLI | Capture pages and automate browser workflows (requires Node.js 20+) | Use for browser interaction, UI flows, screenshots, and rendered-page checks. | No |
| Lighthouse | Audit web performance, accessibility, SEO, and best practices (requires Node.js 22+) | Use for evidence-based audits of a rendered web page. | No |
<!-- END GENERATED OPTIONAL TOOLS -->

The optional-tools module itself is disabled by default. Once enabled, existing system commands
win. Missing tools are installed without administrator access through a pinned,
checksum-verified, isolated mise runtime and are available only inside `scodex`.

Installing missing tools requires `curl` or `wget` and `sha256sum`. Repository updates never
upgrade tools; `scodex` checks for local tool updates at most weekly and only displays a notice.
Playwright CLI requires Node.js 20 or newer, while Lighthouse requires Node.js 22 or newer. If a
compatible system Node.js is unavailable, Scriptorium keeps the selection but skips installation
and leaves the affected tool out of the active environment. Selecting either browser tool also
downloads Chromium without administrator access into Scriptorium's isolated cache. Both tools
reuse that browser. Scriptorium sets `CHROME_PATH` for Lighthouse and
`PLAYWRIGHT_MCP_EXECUTABLE_PATH` for Playwright CLI automatically. Lighthouse can audit pages behind
HTTP Basic Auth through an `Authorization` header passed with
`--extra-headers`; keep files containing credentials outside the repository.

## Verification

```bash
./tests/smoke.sh
./tests/tools-smoke.sh
./tests/update-smoke.sh
./tests/context-pressure-smoke.sh
```

These suites cover safe installation and migration, tool isolation, update behavior, and failure
rollback without modifying the real home directory.

## Token benchmark

Prepare and inspect the six-task Codex versus Scriptorium pilot without using model tokens:

```bash
./scripts/token-benchmark.sh prepare
```

The paid run is deliberately separate: `./scripts/token-benchmark.sh run [OUTPUT_DIR]`. It uses
isolated `CODEX_HOME` directories, the same Terra model settings for both variants, and writes a
per-task quality and token report. The baseline has no Scriptorium instructions or agents; the
Scriptorium variant uses the installed normal profile and delegation setup. One run per task is
directional evidence only, not a statistically significant result.

Use `./scripts/token-benchmark.sh run-one TASK VARIANT OUTPUT_DIR` for a single inexpensive
regression check, for example with `02-config-path scriptorium`.

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
