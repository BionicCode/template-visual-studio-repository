---
doc_version: 1
created: 2026-05-26T01:40:38+02:00
updated: 2026-05-26T01:40:38+02:00
---
# DocumentEligibility

Eligibility filters manifest matches to document-like text files before Analyze, Bootstrap, Update, or Repair can mutate anything.

## Fields

| Field | Required | Type | Default | Description |
|---|---:|---|---|---|
| `allowedExtensions` | No | string[] | `.md`, `.markdown`, `.txt` | Base allowed extensions. If present, replaces the default base list. |
| `additionalAllowedExtensions` | No | string[] | `[]` | Extensions appended to the base allowed list. |
| `deniedExtensions` | No | string[] | `[]` | Extensions that are never eligible. Denied wins over allowed. |
| `deniedPaths` | No | string[] | `[]` | Repository-relative forward-slash path or glob patterns that are never eligible. |
| `allowExtensionless` | No | boolean | `false` | Allows files without an extension. |
| `failOnIneligibleMatches` | No | boolean | `false` | Fails when manifest patterns match ineligible files. |

## Extension Semantics

Extensions are normalized by script code to leading-dot lowercase values. Values without a leading dot are accepted and normalized. Empty values, dot-only values, wildcards, and path separators are invalid.

File extension comparison is case-insensitive after normalization.

## Path Semantics

`deniedPaths` are evaluated against normalized repository-relative paths using `/` separators. Absolute paths, drive-qualified paths, backslashes, and traversal with `..` are invalid.

## Text Safety

The supported document text encoding is strict UTF-8 with optional BOM preservation. Invalid UTF-8 or NUL bytes are classified as `ignoredBinaryOrNonText` and are never mutated.
