# Working rules

Optimize for correct results with minimal context and tool output. Follow more specific
`AGENTS.md` files in subdirectories when present.

## Skills and tools

- Review the runtime skill catalog at the start of each task. Use a skill when its description
  clearly matches the request, and follow its complete instructions.
- Do not hard-code a skill inventory. If the catalog is unavailable or incomplete, search the
  configured repository, user, admin, and system skill locations only for plausible matches.
- For repository facts, inspect the relevant files before answering. For implementation,
  diagnosis, review, and verification, use available tools proactively.
- Prefer targeted discovery and the narrowest sufficient validation. Answer without tools only
  when the request is conversational or the supplied context is already sufficient.
- Use the runtime tool list below as guidance, not as proof that a command exists. Verify commands
  with `command -v` before relying on them.

## Scope and context

- Resolve user-entered names case-insensitively, then preserve the actual casing of paths,
  commands, identifiers, configuration keys, and file names.
- Work only on the requested outcome. Identify the smallest relevant files, symbols, and tests.
- Prefer `rg`, targeted paths, and narrow ranges. Avoid broad reads of generated content,
  dependencies, lockfiles, large data, and `.git` unless required.
- Reuse established facts and do not reread unchanged files. Ask one focused question only when a
  missing choice materially changes the result.

## Execution and verification

- Use a short plan only for complex or ambiguous changes. Make the smallest coherent change.
- Invoke `$reuse-first` before work that could overlap existing behavior or ownership. Choose one
  reuse, extend, or create path, and record a migration plan if duplication must remain.
- Run the narrowest relevant check first. Do not repeat an unchanged failure without new evidence
  or a code change; distinguish pre-existing failures from regressions.
- Before finishing, review changed hunks for correctness, scope, accidental edits, and secrets.

## Output

- Lead with the outcome and keep responses concise, normally at most five sentences. Expand only
  when brevity would be incomplete, unsafe, or ambiguous.
- Avoid generic AI prose and em or en dashes. Keep command output small and report only decisive
  errors or changed hunks, never complete logs, large diffs, generated files, or data dumps.
- Keep operational Markdown non-duplicative and new project notes normally under 120 lines.

## Handoff

- Use root-level `HANDOFF.md` only for unfinished work likely to cross sessions or compaction.
  Keep it current and under 80 lines; do not create it for a small completed task.
- Record only the goal, done condition, relevant paths, decisions, completed changes, blocker,
  next step, focused verification commands, and approaches not to revisit.
- On resume, read it once, verify it against the working tree, and open only required files.

## Delegation and cost control

- For coding, diagnosis, research, or review likely to inspect more than one file, run
  `scodex context` once before broad exploration. Never let missing telemetry block work.
- Keep small, single-goal work local. Before reading unopened material, invoke
  `$scriptorium-delegate` when independent work can run concurrently or expected new context
  exceeds: `low` = 64 KB, `medium` = 24 KB or more than 8 substantive files, `high` = 8 KB or more
  than 3 substantive files. Treat `unknown` as `low`; small stubs do not qualify by count alone.
- Delegate only unopened context, normally to one worker, following the skill's routing and result
  limits. Do not delegate a single test, repeated verification, or already gathered context.
- Avoid external research unless current or unavailable information is required.
