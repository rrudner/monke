# Working rules

Optimize for correct results with minimal context and tool output. Follow more specific
`AGENTS.md` files in subdirectories when present.

## Skill discovery and use

- At the start of each task, review the skills catalog supplied by the Codex runtime before
  choosing tools or a workflow. Treat a clear match between the task and a skill description as
  a reason to use that skill, not merely as an optional suggestion.
- Never maintain a hard-coded inventory of skill names in this file. Use the current catalog so
  newly installed, removed, disabled, repository-scoped, plugin, admin, and system skills are
  reflected automatically.
- If the runtime catalog is unavailable or reports that entries were omitted, discover relevant
  `SKILL.md` files from Codex's current repository, user, admin, and system skill locations and
  from enabled `[[skills.config]]` paths in the active Codex configuration. Keep this search
  targeted and read only the full instructions for skills that plausibly match the task.
- Follow every selected skill's trigger and workflow instructions. Do not invoke unrelated skills
  just to demonstrate that they are installed.

## Scope and context

- Interpret user-entered names and terms case-insensitively when determining intent. Do not
  correct, challenge, or ask for clarification solely because the user's capitalization differs.
  Before acting, resolve and preserve the actual casing of case-sensitive paths, commands,
  identifiers, configuration keys, and file names required by the target system.
- Work only on the requested outcome. Do not perform unrelated refactors or cleanup.
- Identify the smallest relevant set of files, symbols, and tests before editing.
- Prefer `rg`, targeted paths, and narrow file ranges over broad scans.
- Do not recursively inspect `.git`, `node_modules`, `dist`, `build`, `coverage`, `.venv`,
  `vendor`, generated assets, lockfiles, minified files, or large data unless required.
- Do not reread unchanged files. Reuse facts already established in the session.
- Ask one focused question only when a missing choice materially changes the result.

## Output and Markdown

- Avoid generic AI-sounding prose. Do not use em or en dashes; use commas, semicolons, or
  parentheses.
- Keep user-facing responses concise. Default to at most five sentences unless the task requires
  more detail or the user explicitly asks for it.
- Lead with the outcome. Do not narrate routine steps, tool usage, or reasoning unless it helps
  the user make a decision or understand a blocker.
- Expand explanations only when requested or when brevity would make the answer incomplete,
  unsafe, or ambiguous.
- Keep command output small. Filter or redirect unknown output, then inspect matches, a short
  tail, or a byte-capped sample such as `head -c 8000`.
- Never print complete logs, large diffs, generated files, lockfiles, JSON dumps, databases, or
  minified assets. Report only decisive errors and relevant changed hunks.
- Keep operational Markdown concise and non-duplicative. Prefer updating an existing section.
- Keep new project notes normally under 120 lines. Do not mechanically shorten user-authored
  documentation or remove necessary meaning.

## Handoff

- Use root-level `HANDOFF.md` only for multi-step work likely to cross sessions, require
  compaction, or remain unfinished. Do not create it for small tasks completed in one session.
- Refresh it at milestones, before planned compaction, or before ending unfinished work, not
  after every action. Keep it at no more than 80 lines and replace stale facts.
- Record only: goal and done condition; relevant paths and symbols; constraints and decisions;
  completed changes; decisive blocker; next step; exact focused verification commands; and
  approaches not to revisit with a short reason.
- Never copy full logs, diffs, chat history, source code, or speculative analysis into it.
- On resume, read it once, verify it against the working tree, then open only required files.

## Execution and verification

- Use a short plan only for complex or ambiguous changes.
- Invoke `$reuse-first` before implementation or refactoring that could overlap existing behavior,
  ownership, components, helpers, services, or error handling. If overlap exists, require
  reuse/extend/new with one explicit decision and a migration or follow-up plan for any remaining
  duplication.
- Make the smallest coherent change and run the narrowest relevant test first.
- Do not rerun an unchanged failing command without new evidence or a code change.
- Separate pre-existing failures from failures caused by the work.
- Review changed hunks for correctness, scope, accidental edits, and secrets before finishing.

## Delegation and cost control

- For coding, diagnosis, research, or review likely to inspect more than one file, run
  `scodex context` once before broad exploration. Do not run it for conversational answers or one
  known file. Treat `context_pressure=unknown` conservatively; the command must never block work.
- Keep small, single-goal work local. Before reading unopened material, invoke
  `$scriptorium-delegate` when independent work can run concurrently or the expected new context
  exceeds the matching budget: `low` = 64 KB, `medium` = 24 KB or more than 8 substantive files,
  `high` = 8 KB or more than 3 substantive files. With `unknown`, use the `low` budget. File count
  alone never qualifies when the files are small stubs that targeted tools can summarize cheaply.
- Estimate size from metadata or targeted matches, not by first reading the material. Delegate only
  the unopened branch; never delegate context already gathered by the parent. A separate Spark
  usage limit is not evidence of token savings. Explicit user delegation bypasses these thresholds.
- Use one delegate by default and follow the skill's routing, packet, fallback, and result limits.
  Do not delegate merely to run a single test or re-check work already completed by the parent.
- Keep progress updates and final responses concise. Avoid external research unless current or
  unavailable information is required.
