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

# Document Eligibility

`documentEligibility` filters manifest matches before analysis or mutation.

| Property | Default | Description |
| --- | --- | --- |
| `allowedExtensions` | `.md`, `.markdown`, `.txt` | Base allowed extensions. If present, replaces the default list. |
| `additionalAllowedExtensions` | `[]` | Appends extra document-like extensions. |
| `deniedExtensions` | `[]` | Always wins over allowed extensions. |
| `deniedPaths` | `[]` | Repository-relative denied path or glob patterns. |
| `allowExtensionless` | `false` | Allows files without extensions. |
| `failOnIneligibleMatches` | `false` | Fails when broad globs match ineligible files. |

Extensions normalize to leading-dot lowercase values. Wildcards and path separators are invalid in extension lists.

Files must decode as strict UTF-8 and must not contain NUL bytes. Invalid UTF-8 is reported as `ignoredBinaryOrNonText` with the remediation: convert the document to UTF-8 if it should be managed.

Example:

```json
{
  "include": ["AGENTS.*"],
  "documentEligibility": {
    "allowedExtensions": [".md", ".markdown", ".txt"]
  }
}
```

`AGENTS.md` is eligible. `AGENTS.cs` is reported but not modified.
