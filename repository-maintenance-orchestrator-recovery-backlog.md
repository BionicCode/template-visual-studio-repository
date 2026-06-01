# Repository Maintenance Orchestrator Recovery Backlog

This document is not an instruction file for coding agents. All agents like Codex or Copilot must ignore this file and under no circumstances edit it.

This document tracks recovery and follow-up work after restoring the repository to the `ff13d50`-based orchestrator baseline.

It replaces the earlier regression-fix backlog that was written during the failed Sonnet/Codex repair attempts. Some lessons from those attempts remain useful, but they are no longer assumed to describe the current repository state.

## How to use this backlog

Only checklist items represent progress that should be ticked after review or validation.

- Use `- [ ]` / `- [x]` only for work items, acceptance checks, or validation checks.
- Keep design decisions, examples, notes, risks, and explanatory bullets as normal lists.
- Do not tick an item because an agent claims it is done. Tick it only after reviewing the implementation, seeing the relevant test/validation pass, or inspecting the workflow run result.
- Untick an item if a later ZIP review or workflow run proves that the behavior regressed.
- A top-level task is complete only when all its completion checks are complete and no blocking review finding remains.
- This file is expected to live in the repository during this recovery/development cycle and be updated after each ZIP-based review.

## Current restore point

The working baseline is the restored repository state around:

```text
ff13d50ba29de3aab658571ddae2f809570a44f5
```

Expected baseline characteristics:

- `repository-maintenance.yml` exists and is the central maintenance entry point.
- `doc-metadata.yml` is a passive reusable/manual workflow.
- `sync-managed-files.yml` is a passive reusable/manual workflow and remains a local wrapper around the shared workflow in `BionicCode/workflows`.
- The orchestrator calls doc-metadata first and sync-managed-files last.
- Later unstable doc-metadata script/test rescue attempts are not part of this baseline.

## Guiding decisions

These are design constraints, not tasks.

- **Behavior-preserving orchestrator first:** restore and verify the orchestration shape before modifying doc-metadata engine behavior.
- **Small agent passes:** each Copilot/Codex task should target one narrow problem.
- **No broad “fix regressions” prompts:** do not ask agents to fix vague behavior clusters. Use explicit files, expected behavior, stop conditions, and validation.
- **No source-side broadcasting:** source repositories stay passive. The target repository runs the caller workflow and observes configured sources through the sync manifest. Do not add source-side broadcasting or `repository_dispatch`.
- **Keep sync wrapper local:** `sync-managed-files.yml` remains a local wrapper around `BionicCode/workflows/.github/workflows/sync-files-from-manifest.yml@main`.
- **Do not mix workflow orchestration with doc-metadata engine changes:** workflow recovery should not edit PowerShell scripts, manifests, schemas, or sync engine behavior unless a later scoped task explicitly allows it.
- **Convention-based manifest design:** `included` is the positive allow-list; `excluded` subtracts from `included`; files with no `included` match are implicitly not governed.
- **Presentation scope:** `presentation.enabled` controls only the extended/rich presentation block. It must not decide whether a file participates in metadata/versioning.
- **Generated-link canonical format:** when implemented, the current/latest changes link is intentionally rendered as a Markdown blockquote line using `> `. History entries do not use the blockquote prefix.
- **No dead migration logic:** the tool is not published yet. Do not add permanent code solely to support stale generated formats from failed intermediate branches.
- **Internal safety boundaries:** internal workflow scratch files and machine-readable implementation files must not be protected by asking users to add ad-hoc manifest exclusions.

## Priority legend

- **P0:** Required to prove the restored orchestrator baseline is safe enough for further work.
- **P1:** Required before publishing or broad rollout.
- **P2:** Important hardening/design work, but not needed for the immediate recovery baseline.

---

## Active next pass

### P0-A — Verify restored `ff13d50` orchestrator baseline

**Goal:** establish a clean baseline before asking an agent to modify behavior again.

**Scope**

This pass is primarily review and validation. It may produce no code changes. If it finds issues, fix them in a separate narrowly scoped pass.

**Completion checklist**

- [x] Confirm repository content was restored to the intended `ff13d50` baseline or a deliberate follow-up commit on top of that baseline.
- [x] Confirm no temporary diagnostic files exist, especially under `.github/scripts/doc-metadata/tests/`.
- [x] Confirm root-level planning prompt files are either intentionally kept or removed in a separate cleanup commit.
- [x] Inspect `AGENTS.md` and repository review protocol before reviewing implementation.
- [x] Confirm `.github/workflows/repository-maintenance.yml` exists.
- [x] Confirm `.github/workflows/doc-metadata.yml` exists.
- [x] Confirm `.github/workflows/sync-managed-files.yml` exists.
- [x] Confirm `repository-maintenance.yml` owns normal `pull_request`, `push`, `schedule`, and `workflow_dispatch` entry points.
- [x] Confirm `doc-metadata.yml` has only `workflow_call` and `workflow_dispatch` triggers.
- [x] Confirm `sync-managed-files.yml` has only `workflow_call` and `workflow_dispatch` triggers.
- [x] Confirm repository-maintenance calls doc-metadata before sync-managed-files.
- [x] Confirm sync-managed-files is the final maintenance child workflow.
- [x] Confirm the sync guard allows sync when doc-metadata is out of scope.
- [x] Confirm the sync guard allows sync after doc-metadata succeeds.
- [x] Confirm the sync guard does not allow sync when doc-metadata was expected but skipped, failed, or cancelled.
- [x] Confirm schedule ownership is centralized in `repository-maintenance.yml`, not in child workflows.
- [x] Confirm branch/tag guards prevent tag pushes from satisfying branch-based maintenance conditions.
- [x] Confirm direct/manual dispatch guards use branch context where needed.
- [x] Confirm `sync-managed-files.yml` still delegates to `BionicCode/workflows/.github/workflows/sync-files-from-manifest.yml@main`.
- [x] Confirm no PowerShell engine scripts were changed as part of the restored orchestration baseline.
- [x] Confirm no manifests or schemas were changed as part of the restored orchestration baseline.
- [x] Run YAML validation for all workflow files.
- [x] Run PowerShell parser validation for doc-metadata scripts and tests.
- [x] Run doc-metadata acceptance tests locally.
- [x] Review the acceptance test suite itself for stale workflow-shape assertions or weak fixtures.
- [x] Report any failing test as either baseline-blocking or clearly out of scope.

**Out of scope for this pass**

- Canonical history-link implementation.
- Protected metadata tamper behavior changes.
- Manifest governance redesign.
- Sync/doc-metadata ownership arbitration.
- Source-side dispatch or repository broadcasting.
- Any sync engine behavior changes.

---

## P0/P1 follow-up tasks

### P0-B — Fix only confirmed restored-baseline workflow issues

**Trigger:** use this only if P0-A finds a real workflow issue in the restored baseline.

**Allowed scope**

- `.github/workflows/repository-maintenance.yml`
- `.github/workflows/doc-metadata.yml`
- `.github/workflows/sync-managed-files.yml`
- workflow documentation only if it would otherwise become misleading

**Completion checklist**

- [ ] Each issue being fixed is tied to a concrete P0-A review finding or failing validation result.
- [ ] No PowerShell scripts changed.
- [ ] No manifests changed.
- [ ] No schemas changed.
- [ ] No sync engine behavior changed.
- [ ] No doc-metadata engine behavior changed.
- [ ] YAML validation passes.
- [ ] Relevant acceptance tests still pass.
- [ ] Changed files are reported.

>[!IMPORTANT]
> No issues found  in P0-A

---

### P1-A — Verify real repository-maintenance workflow execution

**Goal:** validate the orchestrator in GitHub Actions after the restored baseline is pushed.

**Completion checklist**

- [x] `Repository maintenance` starts from `workflow_dispatch` on the default branch.
- [x] `Repository maintenance` starts from a pull request.
- [x] `Repository maintenance` starts from a push to the default branch.
- [x] Scheduled trigger is present and owned by `repository-maintenance.yml`.
- [x] Doc-metadata child workflow is invoked when in scope.
- [x] Sync child workflow is invoked after doc-metadata succeeds.
- [x] Sync child workflow is invoked when doc-metadata is intentionally out of scope.
- [x] Sync child workflow is not invoked when doc-metadata was expected but failed, skipped, or cancelled.
- [x] Bot repair branch creation/update still works.
- [x] `doc-metadata-repair-paths.txt` is written to runner temp, not to the repository checkout.
- [x] `git ls-remote` output for repair branch push is parsed safely before `--force-with-lease`.
- [x] Any failure is investigated from job logs before changing workflow semantics.

---


### P1-B — Documentation correctness and structure audit

**Status:** do this before the next behavior-changing implementation pass, or at minimum before asking a coding agent to rely on repository Markdown documentation.

**Problem**

The current documentation contains stale, misplaced, incomplete, or redundant pages. This is a practical risk because coding agents may index repository Markdown files and infer behavior from them even when a handoff tries to limit scope.

Known examples to verify and resolve:

- `.github/tools/doc-metadata/documentation/types/report-analysis.md` describes workflow/report output, not a manifest JSON type. It does not belong under `types/`.
- `report-analysis.md` must be verified against the implementation before being kept. The tool appears to have console reporting, optional `GITHUB_STEP_SUMMARY` output, and `-ReportOutputPath` JSON output, but the document must match actual script/workflow behavior exactly.
- `.github/tools/doc-metadata/documentation/types/manifest-document.md` appears redundant with `doc-metadata-manifest.md` and/or the API reference unless it is rewritten as a real schema object reference.
- The manifest reference is missing dedicated API pages for `exclude` and `presentation`.
- `metadata-settings.md` is incomplete as an object reference. It should explain the purpose and behavior impact of the `metadata` object, list all fields, and link each field to a dedicated field/value reference page.
- Fields such as `versioningMode`, `timestampFormat`, `format`, `placement`, field-name settings, and comment-block settings need dedicated reference pages that document valid values, defaults, constraints, and behavior effects.
- The same documentation pattern should apply to each manifest object: the object page explains purpose/context and lists fields; field/value pages explain valid values and constraints.
- Documentation must not present stale semantics such as `documentEligibility` as an approved final model if the intended design is still convention-based `included minus excluded` governance.

**Documentation model to establish**

Object pages should:

- explain the object's purpose;
- explain where the object is valid;
- explain how it steers runtime behavior;
- list all fields;
- link each field to its dedicated field/value reference page;
- distinguish immutable/generated metadata concepts from user-configurable fields where relevant.

Field/value pages should:

- define the key;
- list valid values or value shape;
- state defaults;
- state constraints and invalid combinations;
- show minimal examples;
- mention behavior impact and validation errors.

Workflow-output documentation should live with workflow documentation, not manifest type references. For example, a verified `report-analysis.md` should be moved or recreated near `.github/workflows/documentation/doc-metadata.md`, and that workflow documentation should link to it.

**Completion checklist**

- [x] Inventory all doc-metadata documentation files and classify them as concept, workflow, manifest object reference, field/value reference, or obsolete/redundant.
- [x] Verify whether the documented JSON report is implemented by `update-doc-metadata.ps1` and/or consumed by `.github/workflows/doc-metadata.yml`.
- [x] Decide whether `report-analysis.md` should be kept, moved next to workflow documentation, rewritten, or deleted.
- [x] Decide whether `manifest-document.md` should be rewritten as a real object reference or deleted as redundant.
- [x] Add or plan dedicated reference pages for `exclude` and `presentation`.
- [x] Rewrite or plan `metadata-settings.md` as a proper object page with field links.
- [x] Add or plan dedicated field/value pages for all metadata fields, including `format`, `placement`, `versionField`, `createdField`, `updatedField`, `authorField`, `versioningMode`, `timestampFormat`, `commentStart`, `commentLinePrefix`, and `commentEnd`.
- [x] Add or plan dedicated field/value pages for all presentation fields, including `enabled`, `historyLimit`, `includeSeparator`, and `spacingBreaks`.
- [x] Verify that docs do not claim unsupported behavior or stale implementation details.
- [x] Verify that examples match the current schema and intended convention-based governance model.
- [x] Verify all relative links after any move/delete/rename.
- [x] Do not edit PowerShell behavior, workflow behavior, manifests, or schemas during this documentation-only pass unless the user explicitly opens a separate implementation task.

---

### P1-C — Canonical current/history link behavior

**Status:** still desired, but do not assume the restored baseline currently has this regression. Verify first, then implement in a dedicated pass.

**Basic concept**

The generated current/latest changes link should be visually highlighted with Markdown blockquote syntax. History entries remain normal list entries.

**Canonical generated formats**

Current/latest compare link:

```markdown
> [<b>View Changes</b>](...)
```

Current/latest fallback commit link:

```markdown
> [<b>View Commit</b>](...)
```

History compare entry:

```markdown
- Updated: <b>...</b> | Author: <b>...</b> | [<b>View Changes</b>](...)
```

History fallback commit entry:

```markdown
- Updated: <b>...</b> | Author: <b>...</b> | [<b>View Commit</b>](...)
```

Legacy generated forms containing `Changes:` are not supported.

**Implementation constraints**

- Do not add permanent compatibility or migration logic for stale generated `View Commit` labels.
- Do not add permanent compatibility or migration logic for legacy `Changes:` labels.
- Do not rely on “first line after frontmatter” heuristics.
- Current/latest link detection must parse the managed presentation block and match a current-link regex.
- The `> ` prefix belongs only to the standalone current/latest link.
- History entries must not use the `> ` prefix.
- Link-kind consistency is strict: commit URL means `View Commit`; compare URL means `View Changes`.
- The tool must not write a generated state that `Check` immediately rejects.

**Completion checklist**

- [ ] Baseline behavior is tested before implementation.
- [ ] Current/latest compare links generate `> [<b>View Changes</b>](...)`.
- [ ] Current/latest commit fallback links generate `> [<b>View Commit</b>](...)`.
- [ ] History compare entries generate `[<b>View Changes</b>](...)` without `> `.
- [ ] History commit fallback entries generate `[<b>View Commit</b>](...)` without `> `.
- [ ] Generated current/latest lines do not contain `Changes:`.
- [ ] Generated history entries do not contain `Changes:`.
- [ ] Invalid label/URL combinations are rejected or normalized before writing.
- [ ] Older proven content-change links are preserved when a later body change has no reliable new link.
- [ ] No `Unavailable` history item is added when no reliable content-change link exists.
- [ ] No new history entry is added when no reliable new content-change link exists.
- [ ] Acceptance tests cover current/latest blockquote format.
- [ ] Acceptance tests cover canonical history format.
- [ ] Acceptance tests cover invalid label/URL combinations.
- [ ] PowerShell parser validation passes.
- [ ] Doc-metadata acceptance tests pass or unrelated failures are documented.

---

### P1-D — Protected metadata tamper coverage

**Status:** verify first. Implement only if restored baseline lacks coverage or behavior.

**Basic concept**

Protected metadata fields are generated state. A metadata-only change is not a legitimate “no body change” no-op when previous trusted metadata is available.

**Completion checklist**

- [ ] Test covers `Created` tampering.
- [ ] Test covers `Updated` tampering.
- [ ] Test covers `Author` tampering.
- [ ] Test covers generated presentation/history tampering.
- [ ] Metadata-only tampering is repaired even when body content does not change.
- [ ] Manual/`workflow_dispatch` comparison path repairs protected metadata drift using explicit or safe local comparison.
- [ ] Push comparison behavior remains unchanged.
- [ ] Pull-request comparison behavior remains unchanged.
- [ ] PowerShell parser validation passes.
- [ ] Doc-metadata acceptance tests pass or unrelated failures are documented.

---

### P1-E — Convention-based manifest governance

**Status:** deferred semantic fix. Do not mix this into orchestrator recovery.

**Basic concept**

Selection should be a simple set operation:

```text
governedFiles = files matching any included pattern minus files matching any excluded pattern
```

All other settings apply only after a file is already governed.

**Required convention**

- A file is governed only if it matches `included`.
- Files that match no `included` pattern are implicitly excluded.
- `excluded` subtracts from `included`.
- `excluded` is mainly for “include all except” cases.
- `presentation.enabled` controls only the extended/rich metadata presentation block.
- `presentation.enabled` does not decide whether a file is governed.
- `documentEligibility` is removed from schema, docs, examples, and implementation unless explicitly re-approved later.

**Completion checklist**

- [ ] Baseline behavior is verified before implementation.
- [ ] Implementation selects governed files using `included minus excluded`.
- [ ] Files with no `included` match are not modified.
- [ ] `excluded` match overrides `included` match.
- [ ] `presentation.enabled = false` disables extended presentation only.
- [ ] `documentEligibility` is removed from implementation.
- [ ] `documentEligibility` is removed from schema.
- [ ] `documentEligibility` is removed from examples.
- [ ] `requirements.txt` is not modified unless explicitly included as governed input.
- [ ] Machine-readable `.txt` files are safe under default/example manifests.
- [ ] Relevant tests pass.

---

### P1-F — Document the convention-based manifest model

**Priority rule:** do this after P1-D. Do not document stale semantics before implementation is fixed.

**Completion checklist**

- [ ] Tool documentation explains that files are governed only when they match `included`.
- [ ] Tool documentation explains implicit exclusion.
- [ ] Tool documentation explains that `excluded` subtracts from `included`.
- [ ] Tool documentation explains that `presentation.enabled` is not a governance switch.
- [ ] Manifest documentation gives detailed `included` and `excluded` semantics.
- [ ] Manifest documentation explains “include all except ...” configurations.
- [ ] Manifest documentation explains governed with metadata + rich presentation.
- [ ] Manifest documentation explains governed with metadata but no rich presentation.
- [ ] Manifest documentation explains not governed and never modified.
- [ ] Documentation removes `documentEligibility` as supported behavior.
- [ ] Documentation and schema examples use the same terminology as the implementation.
- [ ] Examples cover positive include, implicit exclude, explicit exclude, and presentation-only disabling.

---

### P1-G — Final workflow/tool documentation alignment

**Priority rule:** do this after behavior stabilizes. It is lower priority than behavior fixes, but higher priority than deferred performance cleanup.

**Completion checklist**

- [ ] Workflow documentation matches final trigger ownership and reusable/passive workflow behavior.
- [ ] Workflow documentation matches final sync/doc-metadata boundaries.
- [ ] Tool documentation matches final doc-metadata behavior.
- [ ] Manifest documentation matches final convention-based governance semantics.
- [ ] Examples and diagrams are reviewed for stale orchestration order.
- [ ] Obsolete implementation details are removed.
- [ ] User-facing docs explain behavior, not failed-attempt history.
- [ ] Maintainer-facing docs include safe edit boundaries and validation expectations.
- [ ] Docs mention that source repositories stay passive and the target workflow invokes shared reusable workflows.

---

## P2 design backlog

### P2-A — Sync/doc-metadata ownership arbitration

**Priority note:** this is important before publishing or broad rollout, but should not be implemented as part of the initial orchestrator recovery.

**Problem**

The orchestrator only orders workflow execution. It does not resolve file/scope ownership when sync-managed files are also doc-metadata-governed.

**Race/conflict scenario**

- A user modifies a sync-protected file/scope.
- doc-metadata sees the file as changed and creates a metadata/version repair PR.
- sync later reverts the protected file/scope and creates a sync PR.
- The PRs conflict, and manual conflict resolution can accidentally preserve the invalid change.

**Naive inversion problem**

- Running sync before doc-metadata avoids some conflicts.
- But doc-metadata can add headers to files that sync later considers fully managed.
- This can create ping-pong: sync removes metadata, doc-metadata re-adds it.

**Required design direction**

Treat `sync-manifest.json` as higher authority for sync-managed files/scopes. Before doc-metadata analyzes or repairs a file, classify sync ownership.

The classification must understand:

- `managed_scope`;
- `lifecycle_policy`;
- marker-scoped ownership;
- whole-file ownership.

Active `whole_file` managed files should normally be ineligible for doc-metadata unless explicitly allowed by shared policy. Marker-scoped files may allow doc-metadata only outside protected regions. Allowed target changes remain eligible for doc-metadata. Violating changes should be handled by sync before doc-metadata analyzes remaining legal changes.

**Completion checklist**

- [ ] Design decision made: shared library, merged engine, or preflight ownership plan.
- [ ] Sync ownership classification is specified.
- [ ] Whole-file managed behavior is specified.
- [ ] Marker-scoped managed behavior is specified.
- [ ] Interaction with `lifecycle_policy` is specified.
- [ ] Conflict/ping-pong prevention strategy is specified.
- [ ] Implementation plan is reviewed before coding.

---

### P2-B — Excluded → modified → re-included lifecycle semantics

**Problem**

The tool currently has no persistent tracking database. It relies on the current manifest and Git comparison base. Exclusion can act as a rebaseline only if the excluded state becomes the comparison base before re-inclusion.

**Desired behavior**

- File excluded by manifest → ignored completely.
- Excluded file modified and committed → changes bypass doc-metadata.
- File re-included in a later commit/PR where the comparison base already contains the excluded modifications → treat current file as new baseline.
- Headerless re-included file → initialize as newly tracked.
- File excluded, modified, and re-included in the same comparison range → either fail with explicit rebaseline-required guidance or handle through a defined rebaseline rule.

**Completion checklist**

- [ ] Re-inclusion semantics are decided.
- [ ] Safe rebaseline workflow is documented.
- [ ] Same-range exclude/modify/re-include behavior is defined.
- [ ] Tests are designed for excluded file ignored.
- [ ] Tests are designed for headerless re-included file initialized.
- [ ] Tests are designed for same-range exclude/modify/re-include behavior.

---

### P2-C — Workflow repository variant

**Problem**

`BionicCode/workflows` should remain passive as a source/shared-workflow repository.

**Completion checklist**

- [ ] Decide whether `BionicCode/workflows` needs its own doc-metadata-only maintenance workflow.
- [ ] If needed, define the doc-metadata-only workflow shape.
- [ ] Confirm no sync wrapper is copied unintentionally.
- [ ] Confirm shared workflows remain passive and callable.
- [ ] Document the repository-specific variant.

---

### P2-D — Performance follow-up

**Already approved safe tweak**

Trusted-script checkouts may use `fetch-depth: 1`. Work checkouts must keep full history for comparison, merge-base, rev-list, repair link generation, and validation.

**Deferred optimizations**

- Do not collapse jobs until behavior is stable.
- Do not rewrite resolver batching until tests are stable.
- Do not add caching unless a real reusable dependency/build output exists.

**Completion checklist**

- [ ] Verify trusted-script checkout optimization is present.
- [ ] Verify work checkouts still keep full history.
- [ ] Collect workflow timings after behavior stabilizes.
- [ ] Decide whether job collapse is worth the risk.
- [ ] Decide whether resolver batching is worth a dedicated design pass.
- [ ] Decide whether caching has a real reusable dependency/build output.

---

## Archived failed-attempt lessons

These are not active tasks. They document failure modes to avoid.

- The failed Sonnet/Codex repair attempts mixed orchestration recovery, doc-metadata engine fixes, tests, and manifest semantics. Do not repeat that broad scope.
- Do not let an agent continue static reasoning loops when tests contradict its expectations. Require targeted diagnostics and a concrete failing branch/guard.
- Do not alter acceptance tests merely to match a broken implementation.
- Do not introduce governed test files as “unrelated” commits in tests. Use non-governed fixture paths for unrelated commits.
- Do not add temporary diagnostic scripts under real test directories unless they are removed before final patch.
- Do not treat `View Changes` failures as proof of URL logic failure until unrelated governed-file validation failures are ruled out.
- Do not continue from a branch where an agent has already made broad speculative production changes; restore a clean baseline first.

## Current recommended order

1. **P0-A** — Verify restored `ff13d50` orchestrator baseline.
2. **P0-B** — Not triggered unless P0-A finds a restored-baseline workflow issue.
3. **P1-A** — Verify real repository-maintenance workflow execution.
4. **P1-B** — Documentation correctness and structure audit.
5. **P1-C** — Implement/verify canonical current/history link behavior.
6. **P1-D** — Add/verify protected metadata tamper coverage.
7. **P1-E** — Fix convention-based manifest governance.
8. **P1-F** — Document the convention-based manifest model.
9. **P1-G** — Final workflow/tool documentation alignment.
10. **P2-A** — Design sync/doc-metadata ownership arbitration.
11. **P2-B** — Define excluded/re-included lifecycle semantics.
12. **P2-C** — Finalize workflow-repository variant.
13. **P2-D** — Performance follow-up.
