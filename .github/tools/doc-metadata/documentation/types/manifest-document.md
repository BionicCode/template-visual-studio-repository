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

# Manifest Document

The manifest document is `.github/tools/doc-metadata/doc-metadata-manifest.json`.

```json
{
  "$schema": "./doc-metadata-manifest.schema.json",
  "version": 1,
  "defaults": {
    "metadata": {
      "format": "yaml-front-matter",
      "placement": "top",
      "versionField": "Version",
      "createdField": "Created",
      "updatedField": "Updated",
      "authorField": "Author"
    },
    "presentation": {
      "enabled": true,
      "historyLimit": 20,
      "includeSeparator": true,
      "spacingBreaks": 2
    }
  },
  "include": ["README.md"],
  "exclude": []
}
```

Unknown top-level properties fail validation.
