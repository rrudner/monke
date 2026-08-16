# Reuse-First Tooling

## Discovery checklist
- `rg` for candidate symbols and related docs (tight scopes only)
- `ast-grep` for syntax-aware searches and controlled rewrites when available
- Compare APIs/contracts before writing new abstractions
- Confirm ownership and call boundaries before duplication
- Treat copied code or repeated structure as duplication, not reuse
- Treat a new local helper with an existing responsibility as a parallel implementation

## Guardrails
- Do not run parallel implementations while existing behavior is equivalent.
- Keep the workflow domain- and framework-neutral.
- Keep decisions explicit: reuse, extend, or create new.
- Use project-native architecture checks where present; for example Semgrep, custom linter rules,
  or dependency-boundary tests.

## Validation
- Verify one authoritative module per responsibility.
- Record a migration note when duplication is intentionally retained temporarily.
