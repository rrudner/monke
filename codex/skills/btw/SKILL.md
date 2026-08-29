---
name: btw
description: Run a short side task in an isolated agent without replacing active work when a user message starts with the standalone prefix "btw", case-insensitively. Defer work that conflicts with the active task or needs user input.
---

# BTW

Treat optional leading whitespace followed by standalone `btw` and optional punctuation as the
side-task prefix. Strip it and reject an empty request.

## Dispatch

1. Briefly acknowledge the side task in commentary.
2. If it is one bounded goal, needs no clarification or approval, and does not overlap files or
   state owned by active work, invoke `$monke-delegate` and spawn one leaf worker without waiting.
3. Continue the active task. Check the worker only at natural boundaries and report its result in
   commentary as soon as it finishes. Do not expose its transcript or repeat the result later.
4. Run at most one `btw` worker at a time. Keep additional requests in arrival order until its slot
   is free.
5. Defer conflicting work, work needing user input or approval, and work that is no longer short
   until the active task is complete. Say why without interrupting it for a decision.

Use the active task's workspace and permissions. Assign explicit ownership for edits and never let
the worker touch files or state concurrently owned by another agent. Before the active task's final
answer, collect started workers and report any deferred, failed, or blocked side tasks.

The queue is session-local. Do not create a queue file, durable state, a second Codex process, or a
custom launcher protocol.
