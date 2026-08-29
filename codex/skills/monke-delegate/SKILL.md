---
name: monke-delegate
description: Delegate substantial independent coding, exploration, research, review, log analysis, testing, or implementation when a concise leaf agent is likely to reduce main-thread context or useful work can run concurrently. Keep small single-goal work local. Choose the cheapest model likely to succeed and do not ask permission for qualifying delegation.
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

- `gpt-5.3-codex-spark`: prefer for narrow coding, targeted exploration, focused fixes, and test
  triage. Test availability by direct spawn, never subscription, account, startup, cache, tool
  metadata, or suggested-model inspection. Request Spark on the session's first suitable
  delegation; success proves session availability. Only an explicit permanent authorization,
  unsupported-model, or account-access error disables it for that session. For timeouts, overload,
  rate limits, or temporary failures, use Luna for the task and retry Spark on the first suitable
  delegation after the supplied delay, or after 10 minutes when absent. Success clears the failure.
  Do not retry before cooldown or treat unrelated tool, sandbox, filesystem, network, or task errors
  as model unavailability.
- `gpt-5.6-luna`: use for targeted search, extraction, classification, transformation, simple
  checks, and summaries. This is the lightweight fallback.
- `gpt-5.6-terra`: use for everyday debugging, review, and scoped implementation needing normal
  reasoning or tool use.
- `gpt-5.6-sol`: reserve for ambiguous architecture, security-sensitive analysis, difficult
  multi-step reasoning, or one escalation after a smaller model lacks confidence.

Use low reasoning for clear work, medium for normal coding, and more only when needed.

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

Within one task, escalate at most once: Spark to Luna for availability, Luna to Terra for
reasoning, or Terra to Sol for ambiguity. A later Spark retry after its cooldown starts a new
availability attempt and is not an escalation of the earlier task. Do not escalate merely for
different wording. For writes, assign one writer at a time and do not edit the same files
concurrently in the parent.
