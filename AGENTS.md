# Monke contributor instructions

## Scope

- Maintain a portable Linux Codex CLI setup. Codex is required; optional tools and automatic
  updates remain independently configurable through `install.sh`.
- `codex/AGENTS.md` is an installed end-user payload, not a contributor instruction file.

## Implementation rules

- Before work that may overlap existing behavior or ownership, invoke `$reuse-first`, choose one
  reuse/extend/new path, and propose consolidation or a scoped migration follow-up.
- Use portable Bash and keep external dependencies limited to commands documented in `README.md`.
- Keep all user-facing script output, prompts, comments, and documentation in English.
- Avoid generic AI prose and em or en dashes in documentation; use plain punctuation.
- Preserve existing installer flags and saved preference keys unless a migration is included.
- Updates run only from `monke`, stay fast-forward-only, and never block Codex startup.
- Document every new managed user file as replaced, merged, or marker-edited. Never replace the
  base Codex config. Change user-owned AGENTS, Bash, and Zsh files only inside Monke markers;
  use a namespaced Fish file.

## Verification

- Run `bash -n install.sh bin/monke scripts/*.sh codex/scripts/*.sh tests/*.sh` after
  shell changes.
- Run `./tests/smoke.sh` after installer, updater, preference, or Codex merge changes.
- Before finishing, check changed files for home data, credentials, generated archives, and
  unrelated edits.

## Git authorization

- A request to commit and push authorizes both actions for the requested changes on the current
  branch and configured upstream. Do not reconfirm.
