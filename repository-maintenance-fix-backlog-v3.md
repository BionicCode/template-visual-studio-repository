# Repository Maintenance Fix Backlog

This document tracks the remaining fixes after introducing the repository-maintenance orchestrator.

## Guiding decisions

- [ ] **Keep the convention-based manifest design.** Remove the silently introduced `documentEligibility` concept unless a later design explicitly re-approves it.
- [ ] **Use `included` as the positive allow-list.** A file is governed only when it matches at least one `included` rule.
- [ ] **Use `excluded` only as subtractive refinement.** `excluded` exists for cases such as “include all except these files/patterns.”
- [ ] **Implicit exclusion is the default.** Files that match no `included` rule are not governed and must not be analyzed, repaired, checked, versioned, or annotated.
- [ ] **Keep `presentation.enabled` narrow.** It controls the extended/rich presentation block, such as generated history/presentation details. It must not decide whether a file participates in versioning. Participation is controlled by `included`/`excluded`.
- [ ] **Do not keep legacy generated formats.** The tool is not published yet. Remove `Changes:` from generated history/current link lines and do not maintain long-term validator compatibility for it.
- [ ] **Do not delegate implementation-artifact safety to user configuration.** Internal workflow artifacts and machine-readable implementation files must not be protected by asking users to add ad-hoc exclusions.
- [ ] **Keep source repositories passive.** The target repository runs the caller workflow and observes configured sources through the sync manifest. Do not add source-side broadcasting or `repository_dispatch`.
- [ ] **Split fixes into small agent passes.** Copilot Agent should receive one focused problem at a time.

## Priority legend

- **P0**: Blocks reliable merge/use of the current regression-fix branch.
- **P1**: Required before publishing or broad rollout.
- **P2**: Important hardening/design work, but not needed for the immediate regression fix.

---

## Active next pass

### [ ] P0-A — Finish canonical history-link behavior and strict generated format

**Why this is first:** Sonnet already worked in this area, tests are close, and the current branch still fails a history-link preservation test. Finish this before starting manifest redesign.

**Must be fixed in the same pass**

- [ ] Preserve older proven content-change links when a later body change has no reliable new link.
- [ ] Do not add an `Unavailable` history item when no reliable content-change link exists.
- [ ] Remove the redundant `Changes:` label from generated current/history lines.
- [ ] Treat the standalone link directly below the frontmatter/presentation start as the **current changes link** and maintain it with the same canonical rules as history entries.
- [ ] Rename the current changes link from `View Commit` to `View Changes` whenever it points to a validated compare/diff URL for the current/latest version.
- [ ] Make the canonical generated formats:
  - [ ] current line: `[<b>View Changes</b>](...)`
  - [ ] history line: `| [<b>View Changes</b>](...)`
  - [ ] not current/history forms containing `Changes:`
- [ ] Keep `View Changes` for validated compare/diff links.
- [ ] Keep `View Commit` only as the fallback when a reliable compare/diff link cannot be generated or validated.
- [ ] Enforce link-kind consistency:
  - [ ] commit URL → `View Commit`
  - [ ] compare URL → `View Changes`
- [ ] Do not write a generated state that `Check` immediately rejects.
- [ ] Update acceptance tests for the new canonical format.
- [ ] Do not maintain legacy `Changes:` validation because the tool is not published yet.

**Basic concept**

`New-MarkdownPresentation` must treat the previous current proven link as history-worthy before clearing/replacing it. It must also maintain the current changes link directly below the frontmatter/presentation block start. That current link is not a history item, but it still uses the same URL-kind/label consistency rules: compare URL means `View Changes`, commit URL means `View Commit` fallback. The generator must use the new compact format without `Changes:`. The validator should accept only the current canonical generated format, not a legacy grammar.

Implementation constraint:
Do not add permanent compatibility or migration logic for stale generated `View Commit` labels or legacy `Changes:` labels. The tool is unpublished. Existing repository documents will be manually cleaned or fixed by a one-time repository commit. The generator and validator should define one strict canonical format.

**Out of scope for this pass**

- [ ] Manifest redesign.
- [ ] `documentEligibility` removal.
- [ ] Sync/doc-metadata ownership arbitration.
- [ ] Source-side dispatch or repository broadcasting.
- [ ] The already manually fixed `requirements.txt` file.

---

## Remaining P0/P1 fixes

### [ ] P0-B — Add explicit protected-field tamper tests

**Status:** The latest script behavior appears to repair `Created` tampering, but tests must lock this down.

**Tasks**

- [ ] Add tests for `Created` tampering.
- [ ] Add tests for `Updated` tampering.
- [ ] Add tests for `Author` tampering.
- [ ] Add tests for generated presentation/history tampering.
- [ ] Verify metadata-only tampering is repaired even when body content does not change.
- [ ] Verify manual/`workflow_dispatch` comparison path repairs protected metadata drift using explicit or safe local comparison.
- [ ] Keep push and pull-request comparison behavior unchanged.

**Basic concept**

Protected metadata fields are generated state. A metadata-only change is not a legitimate “no body change” no-op. If previous trusted metadata exists, protected fields must be restored.

---

### [ ] P1-A — Fix manifest governance semantics and remove `documentEligibility`

**Problem**

`documentEligibility` was silently introduced and appears to bypass or confuse the original convention-based manifest model. This is a design regression.

**Required convention**

- [ ] A file is governed only if it matches `included`.
- [ ] Files that match no `included` pattern are implicitly excluded.
- [ ] `excluded` subtracts from `included` and is mainly for “include all except” cases.
- [ ] `presentation.enabled` controls only the extended/rich metadata presentation block.
- [ ] `presentation.enabled` does not decide whether a file is governed.
- [ ] Remove `documentEligibility` from schema, docs, examples, and implementation unless explicitly re-approved later.

**Examples**

- [ ] `included: ["docs/**/*.md"]` → only matching Markdown files under `docs` are governed.
- [ ] `included: ["**/*.*"], excluded: ["example.md", "*.log"]` → everything is governed except `example.md` and `.log` files.
- [ ] A `.txt` file is not governed unless it matches an `included` rule.
- [ ] A governed file with `presentation.enabled = false` may still receive compact/core metadata if that is the intended compact-governed mode.
- [ ] A non-governed file must never receive metadata, version changes, or presentation changes.

**Acceptance tests**

- [ ] No `included` match → file is not modified.
- [ ] `excluded` match overrides `included` match.
- [ ] `presentation.enabled = false` disables extended presentation only.
- [ ] `documentEligibility` no longer affects selection.
- [ ] `requirements.txt` is not modified unless explicitly included as governed input.
- [ ] Machine-readable `.txt` files are safe under default/example manifests.

**Basic concept**

Selection must be a simple set operation:

```text
governedFiles = files matching any included pattern minus files matching any excluded pattern
```

All other settings apply only after a file is already governed.



### [ ] P1-B — Document the convention-based manifest model

**Priority rule:** This documentation belongs immediately after the manifest governance implementation fix. Do not document stale semantics before P1-A is complete.

**Problem**

The convention-based manifest model is the intended user-facing design, but the documentation does not yet state it clearly enough. This allowed confusing concepts such as `documentEligibility` to appear and made `presentation.enabled` easy to misread as a governance switch.

**Required documentation updates**

- [ ] Update the tool-level documentation to state the high-level governance model:
  - [ ] files are governed only when they match `included`;
  - [ ] files that do not match `included` are implicitly excluded;
  - [ ] `excluded` subtracts from `included`;
  - [ ] `presentation.enabled` controls only the extended/rich presentation block, not governance.
- [ ] Update the manifest documentation with a detailed explanation of `included` and `excluded` working together.
- [ ] Explain that `excluded` is mainly a refinement mechanism for cases like “include all except ...”.
- [ ] Remove or rewrite any documentation that describes `documentEligibility` as part of the supported design.
- [ ] Document that `documentEligibility` was not part of the approved convention-based design and must not be used unless a later design explicitly reintroduces it.
- [ ] Document the difference between:
  - [ ] governed with metadata and rich presentation;
  - [ ] governed with metadata but no rich presentation;
  - [ ] not governed and never modified.

**Examples required in manifest documentation**

- [ ] `included: ["docs/**/*.md"]` → only matching Markdown files under `docs` are governed.
- [ ] `included: ["**/*.*"]`, `excluded: ["example.md", "*.log"]` → all files are governed except `example.md` and `.log` files.
- [ ] A file that matches no `included` rule is ignored even if it has a supported extension.
- [ ] A file that matches both `included` and `excluded` is not governed.
- [ ] A governed file with `presentation.enabled = false` still participates in core metadata/versioning, but does not receive the extended generated presentation/history block.
- [ ] A non-governed file must never receive metadata, version changes, or generated presentation.

**Acceptance checks**

- [ ] Documentation and schema examples use the same terminology as the implementation.
- [ ] Examples cover positive include, implicit exclude, explicit exclude, and presentation-only disabling.
- [ ] No documentation presents `documentEligibility` as supported behavior.
- [ ] Tool documentation gives the short concept; manifest documentation gives the detailed rules and examples.

---

### [ ] P1-E — Final documentation alignment pass

**Priority rule:** This comes after semantic/behavior fixes are complete. It is lower priority than implementation fixes that change behavior, but higher priority than deferred performance or internal cleanup tasks.

**Problem**

The repository now has workflow documentation, tool documentation, and manifest documentation that can drift from the implementation while the orchestration and manifest semantics are still changing.

**Tasks**

- [ ] Review all workflow documentation after the final behavior is implemented.
- [ ] Review all doc-metadata tool documentation after P0/P1 behavior fixes are implemented.
- [ ] Review all manifest documentation after convention-based governance is restored.
- [ ] Review examples and diagrams for stale orchestration order, trigger ownership, passive reusable workflows, and sync/doc-metadata boundaries.
- [ ] Remove references to obsolete implementation details, especially `documentEligibility` if it is removed.
- [ ] Ensure user-facing docs explain behavior, not internal accident history.
- [ ] Ensure maintainer-facing docs include safe edit boundaries and validation expectations.
- [ ] Ensure docs mention that source repositories stay passive and that the target workflow invokes shared reusable workflows.

**Basic concept**

Documentation should be updated after behavior stabilizes, not used as a substitute for behavior fixes. This pass is a final alignment pass so users and maintainers see the actual implemented model.

---

### [ ] P1-C — One-time repository migration for stale generated history lines

**Problem**

Existing documents contain generated history items using stale labels such as `View Commit` and/or the old `Changes:` label.

**Strategy**

- [ ] First finish P0-A so the generator and validator define the final canonical format.
- [ ] Then run a one-time migration on the current repository documents.
- [ ] Do not weaken normal validation permanently.
- [ ] Do not keep legacy `Changes:` support.
- [ ] Convert safe history entries to the canonical format:
  - [ ] `| [<b>View Changes</b>](...)`
- [ ] Convert safe current changes lines to the canonical format:
  - [ ] `[<b>View Changes</b>](...)`
- [ ] Keep `View Commit` only where a compare/diff link cannot be safely derived.
- [ ] Run `Check` after migration using the final strict validator.

**Basic concept**

The migration is a repository-cleanup operation, not a permanent compatibility promise.

---

### [ ] P1-D — Verify sync workflow after dependency-file fix

**Status**

The immediate failure was resolved manually by removing metadata front matter from `requirements.txt`.

**Tasks**

- [ ] Rerun `Repository maintenance`.
- [ ] Confirm `sync-managed-files` reaches the real sync step.
- [ ] Confirm whole-file managed drift creates or updates the expected sync PR.
- [ ] If sync still fails after dependency installation succeeds, inspect the failing job logs before changing sync semantics.

**Out of scope**

- [ ] Do not add source-side broadcasting.
- [ ] Do not add `repository_dispatch`.
- [ ] Do not change `managed_scope` unless logs prove a sync-engine bug.

---

## P2 design backlog

### [ ] P2-A — Sync/doc-metadata ownership arbitration

**Problem**

The orchestrator only orders workflow execution. It does not resolve file/scope ownership when sync-managed files are also doc-metadata-governed.

**Race/conflict scenario**

- [ ] A user modifies a sync-protected file/scope.
- [ ] doc-metadata sees the file as changed and creates a metadata/version repair PR.
- [ ] sync later reverts the protected file/scope and creates a sync PR.
- [ ] The PRs conflict, and manual conflict resolution can accidentally preserve the invalid change.

**Naive inversion problem**

- [ ] Running sync before doc-metadata avoids some conflicts.
- [ ] But doc-metadata can add headers to files that sync later considers fully managed.
- [ ] This can create ping-pong: sync removes metadata, doc-metadata re-adds it.

**Required design direction**

- [ ] Treat `sync-manifest.json` as higher authority for sync-managed files/scopes.
- [ ] Before doc-metadata analyzes or repairs a file, classify sync ownership.
- [ ] doc-metadata must understand at least:
  - [ ] `managed_scope`
  - [ ] `lifecycle_policy`
  - [ ] marker-scoped ownership
  - [ ] whole-file ownership
- [ ] Active `whole_file` managed files should normally be ineligible for doc-metadata unless explicitly allowed by shared policy.
- [ ] Marker-scoped files may allow doc-metadata only outside protected regions.
- [ ] Allowed target changes remain eligible for doc-metadata.
- [ ] Violating changes should be handled by sync before doc-metadata analyzes remaining legal changes.

**Possible implementation models**

- [ ] Shared eligibility/classification library used by both workflows.
- [ ] One merged repository-maintenance engine with separate sync and doc-metadata modules.
- [ ] A preflight ownership-plan job that produces a file/scope decision table consumed by both engines.

---

### [ ] P2-B — Excluded → modified → re-included lifecycle semantics

**Problem**

The tool currently has no persistent tracking database. It relies on the current manifest and Git comparison base. Exclusion can act as a rebaseline only if the excluded state becomes the comparison base before re-inclusion.

**Desired behavior to define**

- [ ] File excluded by manifest → ignored completely.
- [ ] Excluded file modified and committed → changes bypass doc-metadata.
- [ ] File re-included in a later commit/PR where the comparison base already contains the excluded modifications → treat current file as new baseline.
- [ ] Headerless re-included file → initialize as newly tracked.
- [ ] File excluded, modified, and re-included in the same comparison range → either fail with explicit rebaseline-required guidance or handle through a defined rebaseline rule.

**Basic concept**

A file should not be treated as tampered merely because it changed while it was not governed, but this requires either documented workflow discipline or explicit manifest-history analysis.

---

### [ ] P2-C — Workflow repository variant

**Problem**

`BionicCode/workflows` should remain passive as a source/shared-workflow repository.

**Guidance**

- [ ] Use a doc-metadata-only `repository-maintenance.yml` if needed inside `BionicCode/workflows`.
- [ ] Remove sync orchestration from that repository unless explicitly needed.
- [ ] Do not copy the template repository’s local `sync-managed-files.yml` wrapper into `BionicCode/workflows` unless intentionally wanted.
- [ ] Keep shared workflows passive and callable.

---

### [ ] P2-D — Performance follow-up

**Already approved safe tweak**

- [ ] Trusted-script checkouts may use `fetch-depth: 1`.
- [ ] Work checkouts must keep full history for comparison, merge-base, rev-list, repair link generation, and validation.

**Deferred optimizations**

- [ ] Do not collapse jobs until behavior is stable.
- [ ] Do not rewrite resolver batching until tests are stable.
- [ ] Do not add caching unless a real reusable dependency/build output exists.

---

## Current recommended order

1. [ ] **P0-A** — Finish canonical history-link behavior and strict generated format.
2. [ ] **P0-B** — Lock protected-field tamper repair with tests.
3. [ ] **P1-A** — Fix convention-based manifest governance and remove `documentEligibility`.
4. [ ] **P1-B** — Document the convention-based manifest model.
5. [ ] **P1-C** — One-time migration for stale generated history lines.
6. [ ] **P1-D** — Verify sync workflow after the dependency-file fix.
7. [ ] **P1-E** — Final documentation alignment pass.
8. [ ] **P2-A** — Design ownership arbitration between sync and doc-metadata.
9. [ ] **P2-B** — Define excluded/re-included lifecycle semantics.
10. [ ] **P2-C** — Finalize workflow-repository variant.
11. [ ] **P2-D** — Performance follow-up.

