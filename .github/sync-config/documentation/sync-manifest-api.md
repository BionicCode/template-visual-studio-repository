# Sync Manifest API Reference

This reference documents the JSON API consumed by the `sync-files-from-manifest` reusable workflow.

The caller-owned manifest lives at:

```text
.github/sync-config/sync-manifest.json
```

The authoritative schema and runtime rules are bundled with the reusable workflow version being executed. The schema copied into a caller repository is for editor tooling and human guidance.

## Types

| Type | Description |
|---|---|
| [`ManifestDocument`](types/manifest-document.md) | Top-level JSON object that identifies the schema version and contains manifest entries. |
| [`ManifestEntry`](types/manifest-entry.md) | One strict source-to-target managed-file mapping plus its policy values. |
| [`Markers`](types/markers.md) | Marker delimiters used by future marker-aware managed scopes. |
| [`RepoRelativeFilePath`](types/repo-relative-file-path.md) | Repository-relative file path string used for source and target paths. |
| [`Direction`](types/direction.md) | Declares the synchronization direction for an entry. |
| [`LifecyclePolicy`](types/lifecycle-policy.md) | Declares whether an entry is enforced, seeded once, or disabled. |
| [`UniquenessPolicy`](types/uniqueness-policy.md) | Declares repository-wide basename uniqueness behavior. |
| [`ManagedScope`](types/managed-scope.md) | Declares whether the workflow manages the whole file or a marker-scoped section. |

## Guides

| Document | Description |
|---|---|
| [`sync-manifest.md`](sync-manifest.md) | Purpose, usage, supported Stage 1 behavior, non-goals, and field-by-field manifest documentation. |
