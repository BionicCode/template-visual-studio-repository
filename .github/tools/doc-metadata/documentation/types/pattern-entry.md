---
doc_version: 1
created: 2026-05-26T01:40:38+02:00
updated: 2026-05-26T01:40:38+02:00
---
# PatternEntry

A repository-root-relative glob string or future-compatible object entry.

## Shapes

```json
"docs/**/*.md"
```

```json
{
  "pattern": "docs/**/*.md"
}
```

## Glob Rules

Patterns are normalized to repository-relative paths with `/` separators.

`*` matches within one path segment only. It does not cross `/`.

`**/` matches zero or more path segments. Use `**/*AGENT*.md` to match both root-level and nested `AGENT` files.

Matching is case-sensitive.

## Examples

| Pattern | Matches | Does not match |
|---|---|---|
| `*AGENT*.md` | `AGENTS.md`, `AGENT_GUARDRAILS.md`, `NET_AGENTS.md` | `docs/AGENTS.md`, `agents.md` |
| `**/*AGENT*.md` | `AGENTS.md`, `docs/AGENTS.md` | `agents.md` |
| `docs/**/*.md` | `docs/readme.md`, `docs/reference/type.md` | `README.md` |
