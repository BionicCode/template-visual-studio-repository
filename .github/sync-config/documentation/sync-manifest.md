# Sync Manifest

`sync-manifest.json` describes the files that the reusable workflow manages in a caller repository.

The file is caller-owned and lives at:

```text
.github/sync-config/sync-manifest.json
```

The reusable workflow reads the manifest, validates it against the schema bundled with the workflow version being executed, then runs semantic validation before any source fetch or file write.

## What The Manifest Does

- Declares strict one-to-one mappings from source files to target files.
- Supports source files from multiple repositories in one workflow run.
- Supports nested repository-relative target paths.
- Defines lifecycle, uniqueness, and managed-scope policy for each mapping.
- Lets pull request runs verify that managed targets are present and in sync.
- Lets default-branch maintenance runs create or update one aggregated sync PR.

## What The Manifest Does Not Do In Stage 1

- It does not support target-to-source writes.
- It does not support two-way synchronization.
- It does not support rename aliases where source and target basenames differ.
- It does not delete extra tracked files.
- It does not preserve marker-scoped sections yet.
- It does not use timestamps or newer-wins conflict resolution.
- It is not intended for large binary assets.

## Top-Level Shape

The manifest is a JSON object:

```json
{
  "$schema": "./sync-manifest.schema.json",
  "schema_version": 1,
  "entries": []
}
```

| Field | Required | Type | Description |
|---|---:|---|---|
| `$schema` | No | string | Relative schema reference for editor tooling. Authoritative validation uses the schema bundled with the reusable workflow. |
| `schema_version` | Yes | number | Manifest schema version. Stage 1 supports `1`. |
| `entries` | Yes | [`ManifestEntry[]`](types/manifest-entry.md) | Non-empty list of managed-file mappings. |

Old top-level array manifests are rejected. Wrap the array under `entries` and add `schema_version`.

## Entry Fields

Each entry is a strict one-to-one mapping:

```json
{
  "source_repo": "BionicCode/template-visual-studio-repository",
  "source_ref": "main",
  "source_path": "README.md",
  "target_path": "README.md",
  "direction": "source_to_target",
  "lifecycle_policy": "seed_once",
  "uniqueness_policy": "none",
  "managed_scope": "whole_file"
}
```

| Field | Required | Type | Description |
|---|---:|---|---|
| `source_repo` | Yes | string | Source repository in `owner/repository` form. |
| `source_ref` | Yes | string | Source branch, tag, or commit SHA. |
| `source_path` | Yes | [`RepoRelativeFilePath`](types/repo-relative-file-path.md) | Source file path inside `source_repo`. |
| `target_path` | Yes | [`RepoRelativeFilePath`](types/repo-relative-file-path.md) | Target file path inside the caller repository. Parent directories are created as needed. |
| `direction` | Yes | [`Direction`](types/direction.md) | Synchronization direction. Stage 1 executes only `source_to_target`. |
| `lifecycle_policy` | Yes | [`LifecyclePolicy`](types/lifecycle-policy.md) | Runtime behavior for missing, existing, and changed targets. |
| `uniqueness_policy` | Yes | [`UniquenessPolicy`](types/uniqueness-policy.md) | Optional repository-wide basename uniqueness enforcement. |
| `managed_scope` | Yes | [`ManagedScope`](types/managed-scope.md) | Portion of the target file managed by the workflow. Stage 1 executes only `whole_file`. |
| `markers` | Conditional | [`Markers`](types/markers.md) | Required for marker-scoped entries and forbidden for `whole_file`. Marker scopes are schema-recognized but Stage 1 runtime-deferred. |

## Mapping Rules

- Each normalized source identity may appear once.
- Each normalized target path may appear once.
- `basename(source_path)` must equal `basename(target_path)`.
- Source and target paths must be repository-relative file paths.
- `target_path` must not be under `_sync-files-from-manifest-workflow/`.

## Authentication

Public source repositories can be read without an extra secret. Private source repositories require the caller workflow to pass the optional `source_token` secret explicitly.
