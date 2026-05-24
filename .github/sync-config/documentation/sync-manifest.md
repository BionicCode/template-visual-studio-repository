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

## Current Version Boundaries

- Target-to-source writes are accepted by the manifest schema but rejected by current execution rules before source fetch or write.
- Two-way synchronization is accepted by the manifest schema but rejected by current execution rules before source fetch or write.
- Rename aliases where source and target basenames differ are rejected.
- Extra tracked files are not deleted.
- Timestamp or newer-wins conflict resolution is not part of the current workflow behavior.
- Large binary assets are outside the intended use case.

## Feature Support Matrix

| Feature | Schema-valid | Runtime-supported | Notes |
|---|---:|---:|---|
| `source_to_target` + `whole_file` | Yes | Yes | Byte-for-byte source-to-target sync. |
| `source_to_target` + `outside_markers` | Yes | Yes | Source owns outside content; target inner content is preserved or fully omitted by projection. |
| `source_to_target` + `inside_markers` | Yes | Yes | Source inner content is enforced by occurrence order. |
| `target_to_source` | Yes | No | Rejected by current execution rules. |
| `two_way` | Yes | No | Rejected by current execution rules. |
| Directory or glob sync | No | No | Use explicit one-to-one entries. |
| Delete unmatched targets | No | No | Extra files are not deleted automatically. |

## Complete Shape

This example shows the complete manifest structure, including the conditional `markers` child object. A real entry uses either `managed_scope: "whole_file"` without `markers`, or a marker-scoped value with `markers`.

```json
{
  "$schema": "./sync-manifest.schema.json",
  "schema_version": 1,
  "entries": [
    {
      "source_repo": "BionicCode/template-visual-studio-repository",
      "source_ref": "main",
      "source_path": "AGENTS.md",
      "target_path": "AGENTS.md",
      "direction": "source_to_target",
      "lifecycle_policy": "enforce",
      "uniqueness_policy": "none",
      "managed_scope": "outside_markers",
      "markers": {
        "start": "<!-- BEGIN REPOSITORY SPECIFICS -->",
        "end": "<!-- END REPOSITORY SPECIFICS -->"
      }
    }
  ]
}
```

## Type Placement

| Type | Placement | Valid Parent | Parent Property | Description |
|---|---|---|---|---|
| [`ManifestDocument`](types/manifest-document.md) | Top-level object | None | None | Root JSON object for `sync-manifest.json`. |
| [`ManifestEntry`](types/manifest-entry.md) | Array item object | `ManifestDocument` | `entries[]` | One strict managed-file mapping. |
| [`Markers`](types/markers.md) | Nested object | `ManifestEntry` | `markers` | Marker delimiter object for marker-scoped entries. |
| [`RepoRelativeFilePath`](types/repo-relative-file-path.md) | Scalar string | `ManifestEntry` | `source_path`, `target_path` | Repository-relative file path. |
| [`Direction`](types/direction.md) | Enum string | `ManifestEntry` | `direction` | Synchronization direction. |
| [`LifecyclePolicy`](types/lifecycle-policy.md) | Enum string | `ManifestEntry` | `lifecycle_policy` | Missing, changed, and existing target behavior. |
| [`UniquenessPolicy`](types/uniqueness-policy.md) | Enum string | `ManifestEntry` | `uniqueness_policy` | Basename uniqueness policy. |
| [`ManagedScope`](types/managed-scope.md) | Enum string | `ManifestEntry` | `managed_scope` | Portion of the target file managed by the workflow. |

## ManifestDocument Fields

| Field | Required | Type | Child Level | Description |
|---|---:|---|---|---|
| `$schema` | No | string | Top-level scalar | Relative schema reference for editor tooling. Authoritative validation uses the schema bundled with the reusable workflow. |
| `schema_version` | Yes | number | Top-level scalar | Manifest schema version. The current version supports `1`. |
| `entries` | Yes | [`ManifestEntry[]`](types/manifest-entry.md) | Child array | Non-empty list of managed-file mappings. |

Old top-level array manifests are rejected. Wrap the array under `entries` and add `schema_version`.

## ManifestEntry Fields

Each entry is a strict one-to-one mapping and is valid only as an item of `ManifestDocument.entries`.

| Field | Required | Type | Child Level | Description |
|---|---:|---|---|---|
| `source_repo` | Yes | string | Entry scalar | Source repository in `owner/repository` form. |
| `source_ref` | Yes | string | Entry scalar | Source branch, tag, or commit SHA. |
| `source_path` | Yes | [`RepoRelativeFilePath`](types/repo-relative-file-path.md) | Entry scalar | Source file path inside `source_repo`. |
| `target_path` | Yes | [`RepoRelativeFilePath`](types/repo-relative-file-path.md) | Entry scalar | Target file path inside the caller repository. Parent directories are created as needed. |
| `direction` | Yes | [`Direction`](types/direction.md) | Entry scalar | Synchronization direction. The current version executes only `source_to_target`. |
| `lifecycle_policy` | Yes | [`LifecyclePolicy`](types/lifecycle-policy.md) | Entry scalar | Runtime behavior for missing, existing, and changed targets. |
| `uniqueness_policy` | Yes | [`UniquenessPolicy`](types/uniqueness-policy.md) | Entry scalar | Optional repository-wide basename uniqueness enforcement. |
| `managed_scope` | Yes | [`ManagedScope`](types/managed-scope.md) | Entry scalar | Portion of the target file managed by the workflow. |
| `markers` | Conditional | [`Markers`](types/markers.md) | Nested child object | Required for marker-scoped entries and forbidden for `whole_file`. |

## Examples

`whole_file` lets the source own the entire target file. It is byte-for-byte behavior and can be used for text or binary files that can be fetched through the GitHub source API:

```json
{
  "source_repo": "BionicCode/bioniccode-code-style",
  "source_ref": "main",
  "source_path": ".editorconfig",
  "target_path": ".editorconfig",
  "direction": "source_to_target",
  "lifecycle_policy": "enforce",
  "uniqueness_policy": "basename_unique",
  "managed_scope": "whole_file"
}
```

`inside_markers` lets the source own content inside each marker block while the target owns all outside content. Existing targets must keep the same number of exact marker blocks as the source, matched by occurrence order:

```json
{
  "source_repo": "BionicCode/template-visual-studio-repository",
  "source_ref": "main",
  "source_path": "AGENTS.md",
  "target_path": "AGENTS.md",
  "direction": "source_to_target",
  "lifecycle_policy": "enforce",
  "uniqueness_policy": "none",
  "managed_scope": "inside_markers",
  "markers": {
    "start": "<!-- BEGIN MANAGED SECTION -->",
    "end": "<!-- END MANAGED SECTION -->"
  }
}
```

`outside_markers` lets the source own content outside each marker block while the target owns the inside content. Existing targets may keep all marker blocks, or omit all marker blocks and match the source outside projection:

```json
{
  "source_repo": "BionicCode/template-visual-studio-repository",
  "source_ref": "main",
  "source_path": "AGENTS.md",
  "target_path": "AGENTS.md",
  "direction": "source_to_target",
  "lifecycle_policy": "enforce",
  "uniqueness_policy": "none",
  "managed_scope": "outside_markers",
  "markers": {
    "start": "<!-- BEGIN REPOSITORY SPECIFICS -->",
    "end": "<!-- END REPOSITORY SPECIFICS -->"
  }
}
```

Source files can use a repository-specific placeholder like this:

```markdown
<!-- BEGIN REPOSITORY SPECIFICS -->
<!-- Repository owners may edit only this section. -->
<!-- END REPOSITORY SPECIFICS -->
```

The manifest marker strings in this example are exactly `<!-- BEGIN REPOSITORY SPECIFICS -->` and `<!-- END REPOSITORY SPECIFICS -->`. Do not append annotations inside a marker delimiter unless the manifest marker string also includes that annotation exactly.

If no target-owned section is desired, use `managed_scope: "whole_file"` instead of a marker-scoped value.

Marker-scoped synchronization is intended for text files. Marker-scoped source and target files are decoded and encoded as strict UTF-8.

## Markers Fields

`Markers` is valid only as the `ManifestEntry.markers` child object.

| Field | Required | Type | Child Level | Description |
|---|---:|---|---|---|
| `start` | Yes | string | Markers scalar | Non-empty marker start delimiter. |
| `end` | Yes | string | Markers scalar | Non-empty marker end delimiter. |

Current marker validation criteria:

- `markers` is required for `managed_scope: "outside_markers"` and `managed_scope: "inside_markers"`.
- `markers` is forbidden for `managed_scope: "whole_file"`.
- `markers.start` and `markers.end` are required non-empty strings.
- `markers.start` and `markers.end` must not be identical.
- Marker matching is exact substring matching.
- Marker matching does not trim, case-fold, regex-match, or normalize whitespace.
- Multiple marker blocks and adjacent marker blocks are allowed.
- Nested marker blocks are rejected.
- Source marker blocks define the authoritative sync regions where deterministically enforceable.
- Source and target marker blocks are matched by occurrence order.
- `inside_markers` requires matching exact marker block count and occurrence order.
- `inside_markers` does not prove same source-context position because outside content is target-owned; stronger moved-block enforcement requires future marker IDs, named anchors, or source-owned outside context anchors.
- `outside_markers` allows complete omission of all source-defined target-owned blocks when the target equals the source outside projection.
- `outside_markers` rejects partial marker block omission and extra target fences until marker IDs or named blocks exist.

## Common Recipes

- Sync `.editorconfig`: use `managed_scope: "whole_file"`, `lifecycle_policy: "enforce"`, and `uniqueness_policy: "basename_unique"`.
- Sync `Directory.Build.props`: use `managed_scope: "whole_file"` and `lifecycle_policy: "enforce"`.
- Sync `AGENTS.md` with repository-specific customization: use `managed_scope: "outside_markers"` with exact repository-specific markers.
- Sync Copilot instruction files with repository-specific customization: use `managed_scope: "outside_markers"` with exact markers.
- Seed a starter file once: use `lifecycle_policy: "seed_once"` and `managed_scope: "whole_file"`.

## Failure Mode Examples

- Old top-level array manifest: wrap the array under `entries` and add `schema_version`.
- Duplicate target path: each normalized `target_path` may appear once.
- Basename mismatch: `basename(source_path)` must equal `basename(target_path)`.
- Private source without `source_token`: pass an explicit read-only source token secret.
- Marker exact-match failure: source or target delimiter text does not match the manifest exactly.
- `outside_markers` partial marker mismatch: target has some but not all source-defined marker blocks, or adds extra exact marker blocks.
- Marker-scoped binary or invalid UTF-8 content: marker-scoped entries require strict UTF-8 text.

## Security And Limits

- Caller `GITHUB_TOKEN` writes only to the caller repository.
- `source_token` is optional, should be read-only, and is needed only for private source repositories.
- Avoid implicit secret inheritance; pass only the named `source_token` secret when needed.
- Pin reusable workflow versions for production, preferably to a full commit SHA.
- Marker scopes are for UTF-8 text files.
- `whole_file` remains byte-for-byte behavior and can handle binary files when GitHub source-fetch behavior supports them.
- Large files are constrained by GitHub repository contents/raw API behavior.

## Roadmap

- Current: `source_to_target`, `whole_file`, `outside_markers`, and `inside_markers`.
- Planned: directory or glob sync.
- Possible later: delete policy, marker IDs, named anchors, or source-owned outside context anchors.
- Deferred: `target_to_source` and `two_way`.

## Mapping Rules

- Each normalized source identity may appear once.
- Each normalized target path may appear once.
- `basename(source_path)` must equal `basename(target_path)`.
- Source and target paths must be repository-relative file paths.
- `target_path` must not be under `_sync-files-from-manifest-workflow/`.

## Authentication

Public source repositories can be read without an extra secret. Private source repositories require the caller workflow to pass the optional `source_token` secret explicitly.
