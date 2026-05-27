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

# Report Analysis

Every mode prints a console report. When `GITHUB_STEP_SUMMARY` is available, the script also appends a Markdown summary.

The JSON report includes:

| Property | Description |
| --- | --- |
| `mode` | `Analyze`, `Bootstrap`, `Update`, or `Check`. |
| `comparison` | Selected comparison mode and base/head SHAs when available. |
| `updatedFiles` | Files rewritten by Bootstrap or Update. |
| `unchangedFiles` | Files considered but not changed. |
| `skippedFiles` | Files skipped with a reason. |
| `failedFiles` | Validation failures and remediation. |
| `ineligibleFiles` | Manifest matches filtered out by document eligibility. |
| `analysis` | Analyze mode classification and repair categories. |
| `summaryCounts` | Counts used by console and GitHub summaries. |

`ChangedFilesOutputPath` remains stable:

```json
{
  "changedFiles": ["README.md"]
}
```

Use this machine-readable file for hooks and workflow staging. Do not parse the human report.
