---
doc_version: 1
created: 2026-05-26T01:40:38+02:00
updated: 2026-05-26T01:40:38+02:00
---
# ReportAnalysis

Analyze-mode classification output used by the GitHub workflow to decide whether repair is required and safe.

## Shape

```json
{
  "metadataValid": false,
  "repairRequired": true,
  "repairSafe": true,
  "unrecoverableFailure": false,
  "repairableFiles": [
    {
      "path": "README.md",
      "reason": "body changed",
      "categories": [ "incremented" ]
    }
  ],
  "unrecoverableFiles": [],
  "repairCategories": {
    "initialized": [],
    "incremented": [ "README.md" ],
    "restoredFromHistory": [],
    "repaired": [],
    "skippedManualEdit": [],
    "notSafelyRepairable": []
  }
}
```

## Fields

| Field | Type | Description |
|---|---|---|
| `metadataValid` | boolean | True when no repair is required and no unrecoverable failure exists. |
| `repairRequired` | boolean | True when at least one eligible governed file can be safely repaired. |
| `repairSafe` | boolean | False when unrecoverable failures exist. |
| `unrecoverableFailure` | boolean | True when metadata state needs human intervention. |
| `repairableFiles` | object[] | Files the workflow may pass to Update mode. |
| `unrecoverableFiles` | object[] | Files that must not be automatically repaired. |
| `repairCategories` | object | Grouped repairable and unrecoverable path lists for reporting. |

`ChangedFilesOutputPath` is not an Analyze output. It remains reserved for actual writes by Update or Bootstrap.
