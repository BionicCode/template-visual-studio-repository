# Sync Manifest API Reference

This reference documents the JSON API consumed by the `sync-files-from-manifest` reusable workflow.

The caller-owned manifest lives at:

```text
.github/sync-config/sync-manifest.json
```

The authoritative schema and runtime rules are bundled with the reusable workflow version being executed. The schema copied into a caller repository is for editor tooling and human guidance.

Marker-scoped synchronization is supported for strict UTF-8 text files. Source marker blocks define authoritative sync regions where deterministically enforceable, marker delimiters are matched exactly, marker blocks are matched by occurrence order, and existing target delimiter text is preserved.

## Runtime Support

| Feature | Schema-valid | Runtime-supported | Notes |
|---|---:|---:|---|
| `source_to_target` + `whole_file` | Yes | Yes | Byte-for-byte source-to-target sync. |
| `source_to_target` + `outside_markers` | Yes | Yes | Source owns outside content; target-owned blocks may be preserved or fully omitted by projection. |
| `source_to_target` + `inside_markers` | Yes | Yes | Source inner content is enforced by occurrence order. |
| `target_to_source` | Yes | No | Rejected by current execution rules. |
| `two_way` | Yes | No | Rejected by current execution rules. |
| Directory or glob sync | No | No | Not part of the current manifest API. |
| Delete unmatched targets | No | No | Extra files are not deleted automatically. |

## Marker-Scoped Runtime Errors

- Missing source markers for a marker-scoped entry.
- Malformed, unmatched, or nested source or target markers.
- `inside_markers` target missing, fewer, or extra exact marker blocks.
- `outside_markers` target containing a partial set of marker blocks or extra exact marker blocks.
- UTF-8 decode failure for marker-scoped source or target content.

## Types

| Type | Placement | Description |
|---|---|---|
| [`ManifestDocument`](types/manifest-document.md) | Top-level object | Root JSON object that identifies the schema version and contains manifest entries. |
| [`ManifestEntry`](types/manifest-entry.md) | Array item object | One strict source-to-target managed-file mapping plus its policy values. |
| [`Markers`](types/markers.md) | Nested object | Marker delimiters stored under `ManifestEntry.markers`. |
| [`RepoRelativeFilePath`](types/repo-relative-file-path.md) | Scalar string | Repository-relative file path string used by `source_path` and `target_path`. |
| [`Direction`](types/direction.md) | Enum string | Synchronization direction value used by `ManifestEntry.direction`. |
| [`LifecyclePolicy`](types/lifecycle-policy.md) | Enum string | Lifecycle value used by `ManifestEntry.lifecycle_policy`. |
| [`UniquenessPolicy`](types/uniqueness-policy.md) | Enum string | Uniqueness value used by `ManifestEntry.uniqueness_policy`. |
| [`ManagedScope`](types/managed-scope.md) | Enum string | Managed-scope value used by `ManifestEntry.managed_scope`. |

## Guides

| Document | Description |
|---|---|
| [`sync-manifest.md`](sync-manifest.md) | Purpose, usage, current version boundaries, type placement, and field-by-field manifest documentation. |
