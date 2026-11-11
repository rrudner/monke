---
name: monke-delegate
description: Delegate substantial independent coding, exploration, research, review, log analysis, testing, or implementation when a concise leaf agent is likely to reduce main-thread context or useful work can run concurrently. Keep small single-goal work local. Route work across Luna, Terra, Sol, and Astra without asking permission for qualifying delegation.
---

# Delegate

Use native or configured custom subagents, never a nested CLI when native delegation is available.

This skill and matching `AGENTS.md` rules authorize spawning and model selection without
confirmation, but not broader scope, destructive actions, escalation, or bypassed approvals.

## Decide

Default to local work. With `MONKE_ACTIVE=1`, before a repository task likely to inspect
multiple files, use the one required `monke context` result. Apply its unopened-context budget:
`low` = 64 KB, `medium` = 24 KB or over 8 substantive files, `high` = 8 KB or over 3 substantive
files, and `unknown` = `low`. Cheaply summarized stubs do not qualify by count. Measure once per
turn. Keep small searches, focused fixes, and single tests local while within budget. A separate
model limit does not imply fewer total tokens.

Delegate automatically only when at least one condition is satisfied:

- At least two independent workstreams can run concurrently while the parent performs useful work.
- Unopened exploration exceeds the context-pressure budget, and a worker can replace that material
  with the result limit defined below.
- The user explicitly requests delegation or parallel agent work.

Spawn only when the packet and expected result are smaller than the unopened context replaced.
Never delegate material already read, a single test, a repeated check, or a second opinion.

Default to one agent. Parallelize only independent work when latency or coverage justifies the
tokens. Leaf workers never delegate.

## Route

Honor an explicit model choice. Otherwise choose the first model likely to finish correctly:

- `gpt-6-luna`: default for targeted search, extraction, classification, transformation,
  summaries, narrow coding, focused fixes, and test triage.
- `gpt-6.1-terra`: use for visual reasoning, computer use, concise writing, and scoped code
  fixes with clear inputs and checks.
- `gpt-6.1-sol`: use for complex coding, debugging, review, architecture, security-sensitive
  analysis, or one escalation after Terra lacks confidence.
- `gpt-6-astra`: reserve for the most demanding, cross-cutting, or exceptionally ambiguous work,
  or one escalation after Sol lacks confidence.

Use low reasoning for clear work, medium for normal coding, and more only when needed.

Use models exposed by the current runtime. If a selected model is unavailable, choose an
available model suited to the same task or keep the work local. Do not probe retired models or
infer access from a subscription. Do not treat tool, sandbox, filesystem, or network errors as
model unavailability.

## Delegate

Use `monke_worker` when present, otherwise a native leaf agent. Pass model and effort
explicitly, fork no history or the smallest supported slice, and send only:

```text
You are a leaf worker in a wider project. Do not delegate.
Goal: <one verifiable outcome>
Scope: <at most five paths, symbols, commands, or sources>
Constraints: <only task-specific constraints>
Done when: <observable completion condition>
Return: <=120 words or 6 bullets: outcome, decisive evidence with paths, verification, and risk.
No narration or raw logs. If blocked, return ESCALATE: <reason>.
```

Give exact paths and symbols; do not paste readable chat history, files, or logs.

## Collect

Wait for the worker and reuse it for one focused follow-up. Forward only concise findings and
verify material claims or edits at the narrowest boundary.

Within one task, escalate at most once to the next suitable model: Terra for scoped visual work,
Sol for complex coding or ambiguity, or Astra for exceptional complexity. Do not escalate merely
for different wording. For writes, assign one writer at a time and do not edit the same files
concurrently in the parent.
