---
name: reuse-first
description: Prevent duplicate or parallel implementations by discovering semantic analogs and choosing reuse, extension, or justified creation before editing. Use proactively for implementation, refactoring, architecture changes, new components, shared behavior, helpers, services, error handling, cleanup of duplication, or whenever requested work may overlap existing responsibility.
---

# Reuse First

Use this skill when work may overlap existing behavior or ownership. Default to reuse or extend;
proceed only after choosing one path.

## Workflow

### Discover

1. Search the smallest relevant repository scope for functionally similar code and docs, preferring
   `rg` or equivalent.
2. List each candidate's location, purpose, and behavioral or ownership overlap. Ignore cosmetic
   similarity.
3. If uncertain, inspect only enough extra context to confirm contracts and ownership.

### Decide

Before editing, list any new owning symbols or modules and reject any that repeat responsibility.
Shared formats, interfaces, names, or algorithms alone are not reuse. Choose exactly one mode:

- **Reuse:** call, import, source, or compose the existing owner when behavior matches. Copying its
  code or structure is duplication. Name affected adapters and contracts.
- **Extend:** change the authoritative primitive when it is close but incomplete. If it cannot be
  shared, extract one owner and migrate both consumers in this change; do not add a peer helper or
  service with the same responsibility.
- **Create new:** only for a distinct responsibility and ownership boundary. If overlap remains,
  give the migration rationale and deprecation plan.

Report the mode, why it is safe, the authoritative owner after the change, and one rejected fallback.
When overlap exists, consolidate now if in scope; otherwise block the duplicate and document a
follow-up with owner, priority, migration target, and measurable acceptance criteria.

### Audit

- Verify one implementation owns each responsibility and stack boundaries remain intact.
- If duplication remains, reference the shared interface, mark the duplicate for deprecation, and
  provide scoped migration steps instead of a broad rewrite.

## References

Use `references/tooling.md` for implementation helpers, search patterns, and validation rules.
