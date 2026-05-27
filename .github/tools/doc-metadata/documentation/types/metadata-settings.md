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

# Metadata Settings

`metadata` settings define the managed header contract for a governed file.

| Property | Type | Description |
| --- | --- | --- |
| `format` | string | `yaml-front-matter` or `comment-block`. |
| `placement` | string | `top` or `bottom`; YAML front matter supports `top` only. |
| `versionField` | string | Defaults to `Version`. |
| `createdField` | string | Defaults to `Created`. |
| `updatedField` | string | Defaults to `Updated`. |
| `authorField` | string | Defaults to `Author`. |
| `versioningMode` | string | Only `body-content-change` is supported. |
| `timestampFormat` | string | `rfc3339-utc`; generated values use `+00:00`. |
| `commentStart` | string | Required for effective `comment-block`. |
| `commentLinePrefix` | string | Optional metadata-line prefix for comment blocks. |
| `commentEnd` | string | Required for effective `comment-block`. |

`Version` accepts positive integer and numeric dotted values such as `2.1.2`. Automatic increments update the first component only.

Custom front matter fields are preserved and ignored by metadata automation.
