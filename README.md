# Monke 🐒

**A portable, updateable OpenAI Codex CLI workspace for Linux.** It deploys Codex profiles,
instructions, terminal integration, and optional developer tools consistently without owning your
existing configuration. Start everything with `monke`; update checks run there, never at shell
login. A competent monkey crew keeps the terminal tools sorted; you choose the job.

## Quick start 🍌

Requires OpenAI Codex CLI, Git, Bash, standard GNU utilities, and util-linux (`flock`). Monke is
an independent third-party project and is not affiliated with or endorsed by OpenAI.

```bash
git clone https://github.com/rrudner/monke.git ~/.local/share/monke/repo
~/.local/share/monke/repo/install.sh
```

The Bash, Zsh, and Fish installer lets you choose:

- update checks on `monke` startup, enabled by default;
- isolated optional tools, disabled by default.

Change these choices at any time with:

```bash
monke configure
```

For unattended installation and all available flags, run `./install.sh --help`.

This is a breaking rename from Scriptorium and `scodex`. Monke does not migrate or remove the old
installation, and installing both versions together is unsupported.

## Uninstall

Run `monke uninstall` and confirm, or use `monke uninstall --yes` for automation. It removes
only matching Monke assets and marker-managed integration, retaining user files, timestamped
backups, and modified assets. A clean repository in the default data location is removed last;
pass `--keep-repo` to retain it. Invalid markers or symbolic-link paths stop before any file is
changed.

## Everyday commands

```bash
monke                         # Start with the Sol profile
monke configure               # Change saved integration choices
monke uninstall --keep-repo   # Remove integration and keep this repository
monke tools configure         # Select optional tools in a terminal UI
monke tools update            # Update locally managed tools
monke tools remove NAME       # Remove a tool from the selection
monke stats                   # Show readable token usage for the current project
```

## How it works 🛠️

| Component | Location | Ownership |
|---|---|---|
| Repository | `~/.local/share/monke/repo` | Git-managed |
| Preferences | `~/.config/monke/preferences` | Monke-managed |
| Launcher helper | `~/.local/bin/monke-preferences.sh` | Monke-managed |
| Codex profile | `~/.codex/monke.config.toml` | Monke-managed |
| Codex instructions | `~/.codex/AGENTS.md` | Marker-managed block |
| Codex skills | `~/.codex/skills/{compact-markdown,reuse-first,monke-delegate}` | Unchanged or backed up, then replaced |
| Monke personality | `codex/monke-personality.md` | Git-managed |
| Shell hooks | User configuration files | Marker-managed blocks |
| Optional tool data | Matching XDG data/cache/state directories | Isolated |
| Project token statistics | `.monke/stats` in a launched project | Replaced after each completed `monke` run |

`monke` loads its namespaced Sol profile, exposes only the selected tool environment, optionally
checks for updates, then starts Codex. Your shell changes only through the selected small launcher.

Each `monke` session loads the repository's Monke instructions and passes them through Codex's
`developer_instructions` setting, identifies the
session as Monke, and reads it once. Use
`monke configure --developer-instructions-file /absolute/path/to/another/SKILL.md` to select any
other instruction file, or `monke configure --without-developer-instructions` to disable this
behavior. A missing or invalid file produces one warning and does not prevent Codex from starting.

Monke keeps small, single-goal work local. Before broad exploration it reads only current
thread token counters through `monke context`, lowering the delegation threshold as the main
context fills. It delegates only unopened file or log context replaceable by a concise result; a
separate Spark usage limit alone is not a token saving. Missing or incompatible telemetry uses the
conservative low-pressure threshold.

`monke stats` sums current-project-thread telemetry, including delegates, and reports the complete
thread, last completed launcher run (including `resume`), and last main-agent turn. Its project
marker contains only the thread ID and run start time.

## Safe by design

- `~/.codex/config.toml` is never replaced.
- User-owned files are edited only between explicit Monke markers.
- Changed files are backed up under `${XDG_STATE_HOME:-$HOME/.local/state}/monke/backups`,
  in a directory named by the target path's full SHA-256. Each target keeps at most three
  `backup-*` snapshots. Legacy backups are migrated only when they match the strict
  `target.backup-YYYYMMDDTHHMMSSZ` format; `backup-user` files remain untouched.
- Managed blocks are compared byte-for-byte before writing, so an unchanged block creates no
  backup.
- Invalid, duplicated, or out-of-order markers stop the edit instead of guessing.
- Symlinked managed files and escaping parent symlinks are rejected.
- Failed installation restores the previous saved preferences.
- Modified legacy assets are preserved and reported.

## Repository updates 🔧

When enabled, startup performs a 10-second Git fetch. For a new commit, choose `Install`, `Later`,
or `View`. No response within 10 seconds selects `Later`; that commit is snoozed for 24 hours, but
a newer commit is shown immediately.

Updates are fast-forward-only and skipped for a dirty or divergent working tree. Network, Git, or
installation failures never prevent Codex from starting.

When an update adds optional tools, Monke reports them. If enabled, the next interactive
`monke` reopens the complete selector with existing choices preselected. New `(new)` entries stay
unchecked until explicit selection; non-interactive launches leave selection pending and show the
command.

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

Optional tools are disabled by default. Once enabled, commands already available on the machine
are used at any version and omitted from the installer selection. Missing selected tools install
without administrator access through a pinned, checksum-verified, isolated mise runtime and run
only inside `monke`. When a system copy appears later, interactive `monke` startup offers to
remove the managed copy; `monke tools adopt-system` performs the same migration directly.

Installing missing tools requires `curl` or `wget` and `sha256sum`. Repository updates never
upgrade tools; `monke` checks for local tool updates at most weekly and only displays a notice.
Playwright CLI requires Node.js 20 or newer, while Lighthouse requires Node.js 22 or newer. If a
compatible system Node.js is unavailable, Monke keeps the selection but skips installation
and leaves the affected tool out of the active environment. Selecting either browser tool also
downloads Chromium without administrator access into Monke's isolated cache. Both tools
reuse that browser. Monke sets `CHROME_PATH` for Lighthouse and
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

These suites cover safe installation and migration, tool isolation, updates, and failure rollback
without modifying the real home directory.

## Overlap policy

Monke installs `reuse-first` and an AGENTS rule that invokes it before work that may duplicate
existing behavior, ownership, helpers, services, or error handling. Codex then:

- searches for semantic analogs,
- selects and reports one decision: `Reuse`, `Extend`, or `Create new`,
- proposes consolidation when overlap exists and performs it when it is within the requested scope,
- blocks a parallel implementation and proposes a migration follow-up when consolidation is out of
  scope.

Invoke it explicitly with `$reuse-first` when you want an audit or want to force this check before
a task. Re-run `./install.sh --apply-saved` after updating Monke to deploy the latest skill
and AGENTS block.

## Compact Markdown

Monke installs and uses `compact-markdown` by default for new Markdown and material prose
edits. New files start compact; existing files keep untouched sections unless whole-file compaction
is requested. It removes repetition and safely generalizes repeated examples while preserving
contracts, exact literals, links, warnings, and Markdown structure.
