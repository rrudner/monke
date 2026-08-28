# Reuse-First Tooling

## Discovery checklist

- Use `rg` for tightly scoped candidate symbols and docs; use `ast-grep` for syntax-aware searches
  or controlled rewrites when available.
- Compare contracts, ownership, and call boundaries before adding abstractions.
- Treat copied code, repeated structure, or a local helper with existing responsibility as a
  parallel implementation, not reuse.

## Guardrails
- Do not run parallel implementations while existing behavior is equivalent.
- Keep the workflow domain- and framework-neutral.
- Keep decisions explicit: reuse, extend, or create new.
- Use available project-native architecture checks, such as Semgrep, custom linters, or dependency
  boundary tests.

## Validation
- Verify one authoritative module per responsibility.
- Record a migration note when duplication is intentionally retained temporarily.
