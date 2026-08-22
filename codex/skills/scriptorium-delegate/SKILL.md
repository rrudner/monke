---
name: scriptorium-delegate
description: Delegate substantial independent coding, exploration, research, review, log analysis, testing, or implementation when a concise leaf agent is likely to reduce main-thread context or useful work can run concurrently. Keep small single-goal work local. Choose the cheapest model likely to succeed and do not ask permission for qualifying delegation.
---

# Delegate

Use native subagents or configured custom agents. Do not launch a nested CLI process when native
delegation is available.

Treat this skill and any matching `AGENTS.md` rule as standing user authorization to spawn a
subagent and select its model. Do not ask for confirmation before delegation. This does not
authorize broader scope, destructive actions, permission escalation, or bypassing approvals
required by the delegated action itself.

## Decide

Default to local execution. When `SCRIPTORIUM_ACTIVE=1` and a repository task is likely to inspect
more than one file, use the single `scodex context` result requested by the installed instructions.
Apply its unopened-context budget: `low` = 64 KB, `medium` = 24 KB or more than 8 substantive files,
`high` = 8 KB or more than 3 substantive files, and `unknown` = the `low` budget. File count alone
does not qualify small stubs that targeted tools can summarize cheaply. Do not measure again in the
same turn. Small searches, focused fixes, and single test runs remain local while inside the budget.
A separate model usage limit does not imply lower total token use.

Delegate automatically only when at least one condition is satisfied:

- At least two independent workstreams can run concurrently while the parent performs useful work.
- Unopened exploration exceeds the context-pressure budget, and a worker can replace that material
  with the result limit defined below.
- The user explicitly requests delegation or parallel agent work.

Before spawning, compare the delegation packet plus expected result with the unopened context it
replaces. Keep the work local when the saving is doubtful. Never delegate material already read by
the parent. Do not delegate merely to run a single test, repeat a completed check, or obtain a
second opinion.

Use one agent by default. Use parallel agents only for genuinely independent work when latency or
coverage justifies the extra tokens. Never delegate when acting as a leaf worker.

## Route

Honor an explicit model choice. Otherwise choose the first model likely to finish correctly:

- `gpt-5.3-codex-spark`: prefer for narrow coding, targeted exploration, focused fixes, and test
  triage. Do not inspect or infer the user's subscription plan, account tier, startup state, or
  cached account metadata, tool metadata, or suggested model list to decide availability. Do not
  report Spark as unavailable before a direct spawn fails. On the first suitable delegation in a
  session, request Spark directly. A successful spawn proves availability for that session. Only an
  explicit permanent authorization, unsupported-model, or account-access error marks Spark
  unavailable for the rest of that session. Treat timeouts, overload, rate limits, and temporary
  availability failures as transient: use Luna for the current task, record the service-provided
  retry delay when present, and retry Spark on the first suitable delegation after that delay.
  When no delay is provided, retry after 10 minutes. A successful retry clears the transient
  failure state. Do not retry before the cooldown, and do not classify unrelated tool, sandbox,
  filesystem, network, or task errors as model unavailability.
- `gpt-5.6-luna`: use for targeted search, extraction, classification, transformation, simple
  checks, and summaries. This is the lightweight fallback.
- `gpt-5.6-terra`: use for everyday debugging, review, and scoped implementation needing normal
  reasoning or tool use.
- `gpt-5.6-sol`: reserve for ambiguous architecture, security-sensitive analysis, difficult
  multi-step reasoning, or one escalation after a smaller model lacks confidence.

Use low reasoning for clear work and medium for normal coding. Increase it only when needed.

## Delegate

Spawn the `scriptorium_worker` custom agent when present and pass the selected model and effort
explicitly. Otherwise use a native leaf agent with those settings. Fork no conversation history,
or the smallest supported slice. Send only:

```text
You are a leaf worker in a wider project. Do not delegate.
Goal: <one verifiable outcome>
Scope: <at most five paths, symbols, commands, or sources>
Constraints: <only task-specific constraints>
Done when: <observable completion condition>
Return: <=120 words or 6 bullets: outcome, decisive evidence with paths, verification, and risk.
No narration or raw logs. If blocked, return ESCALATE: <reason>.
```

Do not paste chat history, whole files, or full logs when the worker can read them. Give exact
paths and symbols instead.

## Collect

Wait for the selected worker. Reuse it for one focused follow-up instead of spawning another.
Forward only concise findings; verify material claims or edits at the narrowest relevant boundary.

Within one task, escalate at most once: Spark to Luna for availability, Luna to Terra for
reasoning, or Terra to Sol for ambiguity. A later Spark retry after its cooldown starts a new
availability attempt and is not an escalation of the earlier task. Do not escalate merely for
different wording. For writes, assign one writer at a time and do not edit the same files
concurrently in the parent.
