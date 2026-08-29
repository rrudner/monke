# Working rules

Optimize for correct results with minimal context and tool output. Follow more specific nested
`AGENTS.md` files.

## Skills and tools

- At each task start, review the runtime skill catalog and fully follow matching skills.
- Do not hard-code a skill inventory. If the catalog is unavailable or incomplete, search the
  configured repository, user, admin, and system skill locations only for plausible matches.
- Inspect relevant files before stating repository facts. Use tools proactively for implementation,
  diagnosis, review, and verification; prefer targeted discovery and the narrowest sufficient
  check.
- Use the runtime tool list below as guidance, not as proof that a command exists. Verify commands
  with `command -v` before relying on them.

## Scope and context

- Resolve user names case-insensitively, then preserve the actual casing of paths, commands,
  identifiers, configuration keys, and file names.
- Work only on the requested outcome and the smallest relevant files, symbols, and tests.
- Prefer `rg`, targeted paths, and narrow ranges. Avoid broad reads of generated content,
  dependencies, lockfiles, large data, and `.git` unless required.
- Reuse established facts and do not reread unchanged files. Ask one focused question only when a
  missing choice materially changes the result.

## Proportionality

- Match work and explanation to the request. Produce the shortest complete result.
- Do not expand work for completeness, exhaustiveness, or future needs unless requested.
- When modifying existing work, preserve its level of detail and add only what is necessary.
- Before finishing, remove redundant, obvious, speculative, and non-actionable content.

## Execution and verification

- Plan only complex or ambiguous changes. Make the smallest coherent change.
- Invoke `$compact-markdown` when creating a Markdown file or materially editing Markdown prose.
  Start new files compact; in existing files compact only the touched scope unless the user asks
  for whole-file compaction.
- Invoke `$reuse-first` before work that could overlap existing behavior or ownership. Choose one
  reuse, extend, or create path, and record a migration plan if duplication must remain.
- Run the narrowest relevant check first. Repeat a failure only after new evidence or a code change;
  separate pre-existing failures from regressions.
- Before finishing, review changed hunks for correctness, scope, accidental edits, and secrets.

## Output

- Lead with the outcome. Keep responses concise, normally at most five sentences; expand only for
  completeness, safety, or clarity.
- Avoid generic AI prose and em or en dashes. Keep command output small and report only decisive
  errors or changed hunks, never complete logs, large diffs, generated files, or data dumps.
- Keep operational Markdown non-duplicative and new project notes normally under 120 lines.

## Handoff

- Use root `HANDOFF.md` only for unfinished work likely to cross sessions or compaction; keep it
  current and under 80 lines. Record only the goal, done condition, relevant paths, decisions,
  completed changes, blocker, next step, focused checks, and approaches not to revisit.
- On resume, read it once, verify it against the working tree, and open only required files.

## Delegation and cost control

- For coding, diagnosis, research, or review likely to inspect more than one file, run
  `monke context` once before broad exploration. Never let missing telemetry block work.
- Keep small, single-goal work local. Before reading unopened material, invoke
  `$monke-delegate` when independent work can run concurrently or expected new context
  exceeds: `low` = 64 KB, `medium` = 24 KB or more than 8 substantive files, `high` = 8 KB or more
  than 3 substantive files. Treat `unknown` as `low`; small stubs do not qualify by count alone.
- Delegate only unopened context, normally to one worker, following the skill's routing and result
  limits. Do not delegate a single test, repeated verification, or already gathered context.
- Avoid external research unless current or unavailable information is required.
