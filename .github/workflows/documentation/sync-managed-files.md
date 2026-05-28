# Sync managed files

> [!NOTE]
> See [tool documentation](../../tools/sync-config/documentation/sync-manifest.md) for detailed information about configuration using the manifest.

## Purpose

[sync-managed-files.yml](../sync-managed-files.yml) inspects the local sync manifest and delegates managed-file initialization or synchronization to the shared reusable workflow in `BionicCode/workflows`.

## When it runs

| Trigger | Active or passive | Notes |
| --- | --- | --- |
| `workflow_call` | Passive/reusable | Normal repository maintenance routing calls this workflow through the orchestrator. |
| `workflow_dispatch` | Passive/reusable with direct manual entry | Available for targeted manual execution when maintainers intentionally want to run the wrapper directly. |

> [!NOTE]
> Normal schedule, push, pull-request, and manual orchestration is owned by [Repository maintenance](repository-maintenance.md).

## Workflow role

This workflow is a passive reusable child workflow and a local wrapper around the shared workflow at `BionicCode/workflows/.github/workflows/sync-files-from-manifest.yml@main`.

It does not inline the shared sync engine. Instead, it preserves local manifest inspection, missing-manifest handling, and delegation to the shared workflow.

## Execution flow

1. `reject-non-default-manual-run` rejects direct manual runs from non-default branches.
2. `inspect-manifest` checks whether `.github/tools/sync-config/sync-manifest.json` exists and publishes its JSON content when present.
3. `fail-missing-manifest-on-pr` fails PR validation when the manifest is missing.
4. `init-managed-file-sync` delegates manifest initialization to the shared workflow when initialization is needed.
5. `sync-managed-files` delegates synchronization to the shared workflow when the manifest exists.

## Inputs

### `workflow_call` inputs

| Input | Purpose |
| --- | --- |
| `effective_event_name` | Effective event type used for wrapper routing decisions. |
| `default_branch` | Effective default branch for branch-context checks. |
| `ref_name` | Effective ref name used by manual and push/default-branch checks. |
| `base_ref` | Effective pull request base branch used by PR scope checks. |
| `pull_request_number` | Effective PR number used for concurrency scoping. |

### `workflow_dispatch`

This workflow currently defines no custom manual-dispatch inputs.

## Permissions and secrets

| Job | Permissions | Secrets |
| --- | --- | --- |
| `reject-non-default-manual-run` | none | none |
| `inspect-manifest` | `contents: read` | none |
| `fail-missing-manifest-on-pr` | none | none |
| `init-managed-file-sync` | `contents: write`, `pull-requests: write` | no local secret forwarding is currently defined for init |
| `sync-managed-files` | `contents: write`, `pull-requests: write` | forwards `SOURCE_REPO_READ_TOKEN` to the shared workflow as `source_token` |

## Important behavior notes

- This workflow remains a local wrapper around the shared workflow in `BionicCode/workflows`.
- The wrapper preserves inspect/init/sync behavior visible from this repository.
- PR validation still fails when the manifest is missing.
- Sync still forwards the required secret to the shared workflow where the local wrapper currently uses it.

> [!IMPORTANT]
> Keep the local wrapper role intact. Do not inline the shared workflow logic here unless that architecture is intentionally being changed.

> [!WARNING]
> Do not restore schedule or direct PR/push trigger ownership in this file unless the orchestrator contract is intentionally being changed.

## Related workflows

- [Repository maintenance](repository-maintenance.md)
- [Document metadata](doc-metadata.md)
- [sync-managed-files.yml](../sync-managed-files.yml)

## Maintenance notes

- Safe edits here include wrapper-routing documentation, manifest-inspection notes, and the boundary between local wrapper logic and shared workflow logic.
- Do not document internal implementation details of the shared workflow beyond what is visible from this local wrapper.
- If the wrapper starts forwarding additional inputs or secrets in the future, update this file so it stays aligned with the local YAML.