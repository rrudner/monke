# Scriptorium contributor instructions

## Scope

- Maintain a portable Linux Codex CLI setup with optional tools and tmux integration.
- Keep Codex as the required core component; tmux and automatic updates remain independently
  configurable through `install.sh`.
- Treat `codex/AGENTS.md` as an installed payload for end users, not as contributor instructions
  for this repository.

## Implementation rules

- Invoke `$reuse-first` before implementation or refactoring that could overlap existing behavior,
  ownership, helpers, services, or error handling. If overlap exists, select one reuse/extend/new
  path and propose consolidation or a scoped migration follow-up.
- Use portable Bash and keep external dependencies limited to commands documented in `README.md`.
- Keep all user-facing script output, prompts, comments, and documentation in English.
- Avoid generic AI-sounding prose in documentation. Do not use em or en dashes; use plain
  punctuation such as commas, semicolons, or parentheses.
- Preserve existing installer flags and saved preference keys unless a migration is included.
- Updates run only from `scodex`, remain fast-forward-only, and must never prevent Codex from
  starting.
- Never expand the set of replaced user files silently. Document whether each managed file is
  replaced, merged, or edited through a marker-delimited block.
- Never replace the user base Codex config. Modify user-owned AGENTS, tmux, Bash, and Zsh files
  only inside Scriptorium marker blocks; use a namespaced Fish file.

## Verification

- Run `bash -n install.sh update.sh bin/scodex scripts/*.sh codex/scripts/*.sh
  tmux/scripts/*.sh tests/*.sh` after shell changes.
  after shell changes.
- Run `./tests/smoke.sh` after any installer, updater, preference, Codex merge, or tmux behavior
  change.
- Review changed files for accidental home-directory data, credentials, generated archives, and
  unrelated edits before finishing.

## Git authorization

- A user request to commit and push explicitly authorizes committing the requested changes and
  pushing them to the current branch's configured upstream. Do not ask for separate confirmation.
