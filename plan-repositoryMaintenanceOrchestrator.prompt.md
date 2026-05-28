## Plan: Repository Maintenance Orchestrator

Introduce a new top-level orchestrator workflow that owns repository event triggers and invokes the two existing child workflows in order: document metadata first, sync managed files last. Preserve current behavioral scope by moving trigger ownership and branch/schedule gating into the orchestrator or reusable-child entry conditions, while keeping PowerShell scripts, manifests, doc-metadata engine behavior, and sync engine behavior unchanged.

**Steps**
1. Phase 1 - Normalize the child workflows into passive reusable entry points.
2. Update `.github/workflows/doc-metadata.yml` so `on` contains only `workflow_call` and `workflow_dispatch`, while preserving the existing internal job graph (`analyze-document-metadata` -> `repair-document-metadata` -> `final-status-report`).
3. Add `workflow_call` inputs to `doc-metadata.yml` for every event-derived value the workflow currently reads from `github.*` and `github.event.*` and that will no longer be reliable once called as a reusable workflow. This includes the effective event name, ref data, pull request branch/SHA data, and any repair-branch guard inputs needed to preserve current skip logic. Keep `workflow_dispatch` available for direct/manual maintenance runs.
4. Replace direct child-trigger assumptions inside `doc-metadata.yml` with inputs or normalized expressions, but do not change script arguments, repair rules, branch naming, summary generation, or final status semantics.
5. Update `.github/workflows/sync-managed-files.yml` so `on` contains only `workflow_call` and `workflow_dispatch`. Keep it as the local wrapper around `BionicCode/workflows/.github/workflows/sync-files-from-manifest.yml@main`.
6. Add `workflow_call` inputs to `sync-managed-files.yml` for the effective event type and normalized branch/default-branch context used by the current reject/inspect/init/sync job conditions. Preserve manifest inspection, missing-manifest PR failure, init behavior, sync behavior, and secret passthrough exactly.
7. Phase 2 - Add the orchestrator.
8. Create `.github/workflows/repository-maintenance.yml` with centralized `pull_request`, `push`, `schedule`, and `workflow_dispatch` triggers. Use a workflow name of `Repository maintenance`.
9. In the orchestrator, add an initial normalization job that computes the effective run context once: event name, current ref name, default branch, PR head/base details when present, whether the run is on a doc-metadata repair branch, whether doc-metadata should run for this event, and whether sync-managed-files should run for this event. Preserve current scope instead of broadening it: doc-metadata remains PR/manual/push-to-main-or-master; sync-managed-files keeps schedule/default-branch/manual/PR-to-default-branch behavior.
10. Add a job that calls `.github/workflows/doc-metadata.yml` first when the normalized context says it applies. Pass explicit inputs instead of depending on the callee to inspect the parent event payload implicitly.
11. Add a final job that calls `.github/workflows/sync-managed-files.yml` last, with `needs` pointing at the doc-metadata call job so ordering is preserved whenever doc-metadata is in scope.
12. Implement the sync call job with an explicit `always()` job-level guard combined with normalized outputs from the orchestration context and the doc-metadata call result. The guard must allow sync to run when doc-metadata was intentionally skipped by scope, but must not run sync when doc-metadata actually failed or was cancelled.
13. Keep schedule ownership only in `repository-maintenance.yml`; remove schedule ownership from `sync-managed-files.yml`.
14. Phase 3 - Tighten orchestration details.
15. Preserve concurrency intentionally: keep child-level concurrency where it protects local behavior, and add orchestrator-level concurrency only if needed to prevent duplicate top-level runs without introducing collisions across event types or refs.
16. Verify secrets and permissions wiring so the orchestrator can call the sync wrapper without changing the wrapper’s external behavior. Preserve `SOURCE_REPO_READ_TOKEN` passthrough into the local sync wrapper and then into the shared workflow.
17. Ensure the orchestrator skips calling doc-metadata on `codex/doc-metadata-repair/*` branches rather than invoking it and letting the child fail late. This keeps the existing recursion guard behavior while moving dispatch ownership upward.
18. Phase 4 - Review and validation.
19. Validate YAML structure and reusable-workflow call wiring for all three workflows.
20. Manually review trigger matrices for four paths: pull request to default branch, push to main/master, scheduled run, and workflow dispatch on default branch. Confirm doc-metadata is first and sync-managed-files is last.
21. Review the skip/failure contract explicitly: sync must run after an intentional doc-metadata skip, and must not run after a doc-metadata failure or cancellation.
22. Review public-contract impact. Because the request is explicitly YAML-only, do not change documentation in this task, but record that workflow-entrypoint docs may need a follow-up update if they describe the old direct-trigger ownership.

**Relevant files**
- `i:\GitHubRepositories\VisualStudioGitHubTemplate\.github\workflows\doc-metadata.yml` — convert to passive reusable/manual workflow; preserve existing job graph and metadata repair behavior.
- `i:\GitHubRepositories\VisualStudioGitHubTemplate\.github\workflows\sync-managed-files.yml` — convert to passive reusable/manual wrapper; preserve manifest inspection and delegation to `BionicCode/workflows`.
- `i:\GitHubRepositories\VisualStudioGitHubTemplate\.github\workflows\repository-maintenance.yml` — new centralized trigger owner and execution orchestrator.
- `i:\GitHubRepositories\VisualStudioGitHubTemplate\.github\tools\doc-metadata\documentation\update-doc-metadata.md` — reference only for behavior parity; excluded from this task unless scope changes.
- `i:\GitHubRepositories\VisualStudioGitHubTemplate\.github\tools\sync-config\documentation\sync-manifest.md` — reference only for sync behavior parity; excluded from this task unless scope changes.

**Verification**
1. Run YAML validation or GitHub Actions linting available in the repo/editor for `.github/workflows/repository-maintenance.yml`, `.github/workflows/doc-metadata.yml`, and `.github/workflows/sync-managed-files.yml`.
2. Staticaly inspect `workflow_call` input usage so every former `github.event.*` dependency in the two child workflows has a corresponding explicit input or a safe fallback for direct `workflow_dispatch` runs.
3. Verify orchestrator job ordering: doc-metadata call job runs before sync-managed-files call job via `needs`.
4. Verify the sync job-level `if` uses `always()` plus normalized outputs so sync runs after an intentional doc-metadata skip, but does not run after a doc-metadata failure or cancellation.
5. Verify schedule ownership exists only in the orchestrator and no longer in the child workflows.
6. Verify direct manual runs still work on both child workflows via `workflow_dispatch`, and orchestrator manual runs trigger the centralized path.
7. Verify the local sync workflow still uses `BionicCode/workflows/.github/workflows/sync-files-from-manifest.yml@main` and remains a wrapper rather than inlining shared logic.

**Decisions**
- Use `.github/workflows/repository-maintenance.yml` with workflow name `Repository maintenance`.
- Preserve current child behavior behind orchestrator guards rather than broadening when the workflows run.
- Use normalized orchestrator outputs plus an explicit `always()` sync job guard so `needs` preserves ordering without suppressing sync on intentional doc-metadata skips.
- Keep changes YAML-only: no PowerShell script edits, no manifest changes, no engine logic changes.
- Keep `doc-metadata` local in this repository for now.
- Keep `sync-managed-files` as a local wrapper around the shared workflow in `BionicCode/workflows`.
- Included scope: workflow trigger ownership, reusable workflow conversion, explicit input plumbing, job ordering, and schedule migration.
- Excluded scope: script logic, manifest/schema changes, doc-metadata repair semantics, sync engine semantics, and moving workflows to another repository.

**Further Considerations**
1. The highest-risk implementation detail is reusable-workflow event context loss. During implementation, treat every use of `github.event.*`, `github.head_ref`, `github.base_ref`, `github.ref_name`, and branch-specific guards in the child workflows as explicit migration points to inputs or normalized orchestrator outputs.
2. The second highest-risk detail is `needs` result handling in the orchestrator. Implementation should normalize whether doc-metadata was in scope and combine that with the doc-metadata job result so sync tolerates `skipped` but not `failure` or `cancelled`.
3. If documentation parity is required later, update workflow-behavior docs after the YAML change lands so they describe centralized trigger ownership without implying engine-behavior changes.
