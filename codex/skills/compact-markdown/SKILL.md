---
name: compact-markdown
description: Create or edit Markdown with high information density while preserving meaning, structure, exact literals, and project conventions. Use for new Markdown files and material prose edits; compact an entire existing file only when requested.
---

# Compact Markdown

Write the smallest Markdown that preserves the user's intent and every required semantic unit.
Optimize for information density, not a word count or compression ratio.

## Scope

- For a new file, identify its purpose, audience, and required decisions, then draft it compactly
  from the start.
- For an existing file, compact only the requested or edited scope. Include adjacent text only
  when needed to remove duplication or keep the result coherent.
- Compact the whole file only when the user asks. Preserve untouched sections byte-for-byte when
  practical.
- Follow more specific repository and document rules. Preserve the document's language, tone,
  terminology, and useful level of detail.

## Method

1. Inventory the scope's purpose, facts, decisions, instructions, constraints, exceptions,
   evidence, and navigation.
2. Remove repetition, meta-prose, obvious introductions, filler transitions, unsupported
   speculation, and non-actionable text.
3. Merge statements with the same scope. Prefer one rule, decision criterion, or invariant over
   repeated cases.
4. Replace examples with general logic only when that logic covers every relevant case. Keep an
   example when it defines syntax, expected input or output, a contract, a boundary, or a necessary
   counterexample.
5. Shorten sentences and structure while keeping conditions, negation, causality, ownership, and
   exceptions explicit.
6. Keep the result easy to scan. Use headings, lists, and tables only when they improve retrieval
   or encode real structure.

## Protected content

Do not alter or infer away exact content unless the request requires it:

- frontmatter, directives, managed markers, and control comments;
- code fences, inline code, commands, paths, identifiers, configuration keys, and literal values;
- APIs, schemas, tables that encode mappings, test fixtures, and normative examples;
- links, citations, attribution, warnings, permissions, dates, quantities, and compatibility notes.

Preserve Markdown nesting and references. Do not trade valid structure for fewer lines.

## Verification

- Compare the result with the semantic inventory. Every retained claim must be supported by the
  source, and every required unit must remain.
- Review the diff for changed meaning, broadened scope, broken Markdown, lost links, and accidental
  edits outside the selected scope.
- Stop when every remaining part changes action, interpretation, verification, or navigation.
  Further compression must not force the reader to guess.
