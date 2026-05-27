---
Version: 1
Created: 2026-05-26T19:08:33+00:00
Updated: 2026-05-26T19:08:33+00:00
Author: BionicCode
---
<!-- doc-metadata-presentation:start -->
<details>
<summary>Change History</summary>


</details>

---

<br>
<br>
<!-- doc-metadata-presentation:end -->

# Include Entry

`include` entries define candidate files.

String entries use defaults:

```json
"README.md"
```

Object entries use `pattern` plus scoped settings:

```json
{
  "pattern": "src/*AGENT*.md",
  "presentation": {
    "historyLimit": 30,
    "spacingBreaks": 1
  }
}
```

`*` does not cross `/`. `*AGENT*.md` matches `AGENTS.md`, `AGENT_GUARDRAILS.md`, and `NET_AGENTS.md` at the repository root, but not `docs/AGENTS.md`.

Use `**/*AGENT*.md` for root and nested matches. Glob matching is case-sensitive; add explicit variants when needed.

If multiple include entries match a file, their effective settings must be identical or validation fails.
