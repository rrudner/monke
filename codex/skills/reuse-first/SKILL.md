---
name: reuse-first
description: Prevent duplicate or parallel implementations by discovering semantic analogs and choosing reuse, extension, or justified creation before editing. Use for implementation, refactoring, architecture changes, shared behavior, components, services, helpers, error handling, and cleanup of existing duplication.
---

# Reuse First

Use this skill whenever requested work could overlap existing behavior or ownership. Avoid parallel implementations and make reuse or extension the default before writing new code.

## Workflow

### 1) Discover semantic analogs

1. Search for functionally similar code and documentation first in the repository.
   - Read only the smallest relevant files/symbols.
   - Prefer `rg` (or equivalent) over broad scans.
2. Build a concise candidate list with: location, purpose, and why it is semantically close.
3. Ignore cosmetic similarity; prioritize behavior overlap and ownership.
4. If analogs are uncertain, open only one additional file to confirm signatures/contracts.

### 2) Decide strategy

Choose exactly one mode before editing. Do not combine mode labels in one decision.

Apply this hard gate first:

- List the new owning symbols or modules the change would introduce.
- Reject the decision if any would repeat an existing responsibility.
- Reusing only a file format, interface shape, naming convention, or algorithm is not code reuse.
- When equivalent implementations already exist, consolidate them or make the overlap an explicit
  blocked dependency; do not add another copy.

1. Reuse
   - Call, import, source, or compose the existing implementation when behavior matches.
   - Copying an implementation or repeating its structure is not reuse.
   - Cite minimal adapter points and tests/contracts affected.
2. Extend
   - Modify the authoritative primitive when reuse is close but incomplete.
   - If the primitive is not shareable, extract one shared implementation and migrate both the
     existing and new consumers to it in the same change.
   - Do not add a local peer helper, parser, component, service, or state owner with overlapping
     responsibility.
3. Create new
   - Use only when no safe reuse path exists.
   - Require a distinct responsibility and ownership boundary, not merely a different location.
   - Add explicit migration rationale and deprecation plan for overlapping pieces.

Decision must include one selected mode, why it is safe, the authoritative implementation after
the change, and one fallback option rejected.

### 3) Post-change audit

After changes, perform a short local audit:

1. Verify no two implementations solve the same responsibility.
2. Flag duplicates and map a migration target for future cleanup.
3. Add staged remediation plan with priority and owner if not immediate.
4. Keep stack-specific guardrails in place (`language/framework` boundaries, shared error model, dependency policy).

### 4) Remediation staging

- Stage 1: lock in the chosen reuse/extend/new decision and document it in the same change.
- Stage 2: add or update references to existing shared interfaces.
- Stage 3: deprecate duplicate paths and provide migration steps, not broad rewrites.
- Stage 4: if duplication remains, propose follow-up task with measurable acceptance criteria.

## References

Use `references/tooling.md` for implementation helpers, search patterns, and validation rules.
