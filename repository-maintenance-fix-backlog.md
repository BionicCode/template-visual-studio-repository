# Repository Maintenance Fix Backlog

This document tracks the remaining fixes after introducing the repository-maintenance orchestrator.

## How to use this backlog

Only checklist items represent progress that should be ticked after review or validation.

- Use `- [ ]` / `- [x]` only for work items, acceptance checks, or validation checks.
- Keep design decisions, examples, notes, and explanatory bullets as normal lists.
- Do not tick an item because an agent claims it is done. Tick it only after reviewing the implementation or seeing the relevant test/validation pass.
- A top-level task is complete only when all its completion checks are complete and no blocking review finding remains.
- This file is expected to live in the repository during this development cycle and be updated after each ZIP-based review.

## Guiding decisions

These are design constraints, not tasks.

- **Convention-based manifest design:** remove the silently introduced `documentEligibility` concept unless a later design explicitly re-approves it.
- **Positive allow-list:** `included` is the only positive selection surface. A file is governed only when it matches at least one `included` rule.
- **Implicit exclusion:** files that match no `included` rule are not governed and must not be analyzed, repaired, checked, versioned, or annotated.
- **Subtractive refinement:** `excluded` subtracts from `included` and is mainly for “include all except these files/patterns.”
- **Presentation scope:** `presentation.enabled` controls only the extended/rich presentation block, such as generated history/presentation details. It does not decide whether a file participates in versioning.
- **Strict generated format:** the tool is not published yet. Remove `Changes:` from generated current/history link lines and do not keep long-term validator compatibility for that legacy format.
- **No dead migration logic:** do not add permanent code to repair stale labels in existing repository documents. Current repository documents can be cleaned by one deliberate one-time commit after the generator/validator is fixed.
- **Internal safety boundaries:** do not delegate implementation-artifact safety to user configuration. Internal workflow artifacts and machine-readable implementation files must not require ad-hoc user exclusions.
- **Passive sources:** source repositories stay passive. The target repository runs the caller workflow and observes configured sources through the sync manifest. Do not add source-side broadcasting or `repository_dispatch`.
- **Small agent passes:** Copilot Agent should receive one focused problem at a time.

## Priority legend

- **P0:** Blocks reliable merge/use of the current regression-fix branch.
- **P1:** Required before publishing or broad rollout.
- **P2:** Important hardening/design work, but not needed for the immediate regression fix.

---

## Active next pass

### P0-A — Finish canonical history-link behavior and strict generated format

**Why this is first:** Sonnet already worked in this area, tests are close, and the current branch still had a history-link preservation failure. Finish this before starting manifest redesign.

**Basic concept**

`New-MarkdownPresentation` must preserve older proven content-change links correctly, maintain the standalone current changes link, and generate one strict canonical format.

The current changes link is the standalone generated/protected link directly below the metadata presentation start. It is not a history item, but it follows the same URL-kind/label rules as history entries:

- compare/diff URL means `View Changes`;
- commit URL means `View Commit` fallback.

The script must find the current changes line by parsing the managed presentation block and matching the current-link regex. It must not assume “the first line after frontmatter.”

**Canonical generated formats**

Current changes line:

```markdown
> [<b>View Changes</b>](...)
```

History entry:

```markdown
- Updated: <b>...</b> | Author: <b>...</b> | [<b>View Changes</b>](...)
```

Legacy forms containing `Changes:` are not supported.

**Implementation constraints**

- Do not add permanent compatibility or migration logic for stale generated `View Commit` labels.
- Do not add permanent compatibility or migration logic for legacy `Changes:` labels.
- Do not preserve a stale current changes line during a real body update.
- Existing repository documents will be manually cleaned or fixed by one deliberate repository cleanup commit.

**Completion checklist**

- [ ] Older proven content-change links are preserved when a later body change has no reliable new link.
- [ ] No `Unavailable` history item is added when no reliable content-change link exists.
- [ ] No new history entry is added when no reliable new content-change link exists.
- [ ] The standalone current changes link is maintained with the same canonical rules as history entries.
- [ ] The current changes line is found by managed-block parsing and regex matching, not by “first line after frontmatter.”
- [ ] Generated current changes lines do not contain `Changes:`.
- [ ] Generated history entries do not contain `Changes:`.
- [ ] Validated compare/diff links generate `View Changes`.
- [ ] Commit links generate `View Commit` only as fallback.
- [ ] Link-kind consistency is enforced: commit URL → `View Commit`, compare URL → `View Changes`.
- [ ] The tool does not write a generated state that `Check` immediately rejects.
- [ ] Acceptance tests cover the new canonical current link format.
- [ ] Acceptance tests cover the new canonical history entry format.
- [ ] Acceptance tests cover older proven link preservation.
- [ ] Acceptance tests reject invalid label/URL combinations.
- [ ] YAML parsing passes.
- [ ] PowerShell parser validation passes.
- [ ] Doc-metadata acceptance tests pass or all remaining failures are documented as unrelated.

**Out of scope for this pass**

- Manifest redesign.
- `documentEligibility` removal.
- Sync/doc-metadata ownership arbitration.
- Source-side dispatch or repository broadcasting.
- The already manually fixed `requirements.txt` file.

---

## Remaining P0/P1 fixes

### P0-B — Add explicit protected-field tamper tests

**Status:** the latest script behavior appeared to repair `Created` tampering in targeted local review, but tests must lock this down.

**Basic concept**

Protected metadata fields are generated state. A metadata-only change is not a legitimate “no body change” no-op. If previous trusted metadata exists, protected fields must be restored.

**Completion checklist**

- [ ] Test covers `Created` tampering.
- [ ] Test covers `Updated` tampering.
- [ ] Test covers `Author` tampering.
- [ ] Test covers generated presentation/history tampering.
- [ ] Metadata-only tampering is repaired even when body content does not change.
- [ ] Manual/`workflow_dispatch` comparison path repairs protected metadata drift using explicit or safe local comparison.
- [ ] Push comparison behavior remains unchanged.
- [ ] Pull-request comparison behavior remains unchanged.
- [ ] YAML parsing passes.
- [ ] PowerShell parser validation passes.
- [ ] Doc-metadata acceptance tests pass or all remaining failures are documented as unrelated.

---

### P1-A — Fix convention-based manifest governance and remove `documentEligibility`

**Problem**

`documentEligibility` was silently introduced and appears to bypass or confuse the original convention-based manifest model. This is a design regression.

**Basic concept**

Selection must be a simple set operation:

```text
governedFiles = files matching any included pattern minus files matching any excluded pattern
```

All other settings apply only after a file is already governed.

**Required convention**

- A file is governed only if it matches `included`.
- Files that match no `included` pattern are implicitly excluded.
- `excluded` subtracts from `included` and is mainly for “include all except” cases.
- `presentation.enabled` controls only the extended/rich metadata presentation block.
- `presentation.enabled` does not decide whether a file is governed.
- `documentEligibility` is removed from schema, docs, examples, and implementation unless explicitly re-approved later.

**Examples to preserve in tests/docs**

- `included: ["docs/**/*.md"]` means only matching Markdown files under `docs` are governed.
- `included: ["**/*.*"], excluded: ["example.md", "*.log"]` means everything is governed except `example.md` and `.log` files.
- A `.txt` file is not governed unless it matches an `included` rule.
- A governed file with `presentation.enabled = false` may still receive compact/core metadata if that is the intended compact-governed mode.
- A non-governed file must never receive metadata, version changes, or presentation changes.

**Completion checklist**

- [ ] Implementation selects governed files using `included minus excluded`.
- [ ] Files with no `included` match are not modified.
- [ ] `excluded` match overrides `included` match.
- [ ] `presentation.enabled = false` disables extended presentation only.
- [ ] `documentEligibility` is removed from implementation.
- [ ] `documentEligibility` is removed from schema.
- [ ] `documentEligibility` is removed from examples.
- [ ] Existing governed Markdown behavior remains unchanged.
- [ ] `requirements.txt` is not modified unless explicitly included as governed input.
- [ ] Machine-readable `.txt` files are safe under default/example manifests.
- [ ] Tests cover no included match → no modification.
- [ ] Tests cover excluded overriding included.
- [ ] Tests cover presentation-disabled compact-governed behavior.
- [ ] Tests prove `documentEligibility` no longer affects selection.
- [ ] YAML parsing passes.
- [ ] PowerShell parser validation passes.
- [ ] Relevant acceptance tests pass.

---

### P1-B — Document the convention-based manifest model

**Priority rule:** do this immediately after P1-A. Do not document stale semantics before the implementation fix is complete.

**Problem**

The convention-based manifest model is the intended user-facing design, but the documentation does not yet state it clearly enough. This allowed confusing concepts such as `documentEligibility` to appear and made `presentation.enabled` easy to misread as a governance switch.

**Required documentation content**

Tool-level documentation should state the high-level governance model.

Manifest documentation should provide the detailed rules and examples for `included`, `excluded`, implicit exclusion, explicit exclusion, and `presentation.enabled`.

**Examples required in manifest documentation**

- `included: ["docs/**/*.md"]` → only matching Markdown files under `docs` are governed.
- `included: ["**/*.*"]`, `excluded: ["example.md", "*.log"]` → all files are governed except `example.md` and `.log` files.
- A file that matches no `included` rule is ignored even if it has a supported extension.
- A file that matches both `included` and `excluded` is not governed.
- A governed file with `presentation.enabled = false` still participates in core metadata/versioning but does not receive the extended generated presentation/history block.
- A non-governed file must never receive metadata, version changes, or generated presentation.

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

### P1-C — One-time repository migration for stale generated history lines

**Problem**

Existing repository documents contain generated history/current-link lines using stale labels such as `View Commit` and/or the old `Changes:` label.

**Basic concept**

The migration is a repository-cleanup operation, not a permanent compatibility promise.

**Strategy**

First finish P0-A so the generator and validator define the final canonical format. Then run one deliberate migration/cleanup commit on the current repository documents. Do not weaken normal validation permanently.

**Completion checklist**

- [ ] P0-A is complete before this migration starts.
- [ ] Stale current changes lines are converted to the canonical format where safe.
- [ ] Stale history entries are converted to the canonical format where safe.
- [ ] `View Commit` remains only where a compare/diff link cannot be safely derived.
- [ ] No permanent legacy `Changes:` support is added.
- [ ] Normal strict `Check` passes after migration.
- [ ] Migration changes are isolated in a clear cleanup commit or PR.

---

### P1-D — Verify sync workflow after dependency-file fix

**Status**

The immediate failure was resolved manually by removing metadata front matter from `requirements.txt`.

**Completion checklist**

- [ ] `Repository maintenance` rerun completed far enough to invoke `sync-managed-files`.
- [ ] `sync-managed-files` reached the real sync step.
- [ ] Whole-file managed drift creates or updates the expected sync PR.
- [ ] If sync still fails after dependency installation succeeds, the failing job logs are inspected before changing sync semantics.
- [ ] No source-side broadcasting was added.
- [ ] No `repository_dispatch` was added.
- [ ] `managed_scope` was not changed unless logs proved a sync-engine bug.

---

### P1-E — Final documentation alignment pass

**Priority rule:** this comes after semantic/behavior fixes are complete. It is lower priority than implementation fixes that change behavior, but higher priority than deferred performance or internal cleanup tasks.

**Problem**

The repository has workflow documentation, tool documentation, and manifest documentation that can drift from the implementation while orchestration and manifest semantics are still changing.

**Basic concept**

Documentation should be updated after behavior stabilizes, not used as a substitute for behavior fixes. This pass is a final alignment pass so users and maintainers see the actual implemented model.

**Completion checklist**

- [ ] Workflow documentation matches final trigger ownership and reusable/passive workflow behavior.
- [ ] Workflow documentation matches final sync/doc-metadata boundaries.
- [ ] Tool documentation matches final doc-metadata behavior.
- [ ] Manifest documentation matches final convention-based governance semantics.
- [ ] Examples and diagrams are reviewed for stale orchestration order.
- [ ] Obsolete implementation details are removed, especially `documentEligibility` if removed.
- [ ] User-facing docs explain behavior, not internal accident history.
- [ ] Maintainer-facing docs include safe edit boundaries and validation expectations.
- [ ] Docs mention that source repositories stay passive and the target workflow invokes shared reusable workflows.

---

## P2 design backlog

### P2-A — Sync/doc-metadata ownership arbitration

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

**Possible implementation models**

- Shared eligibility/classification library used by both workflows.
- One merged repository-maintenance engine with separate sync and doc-metadata modules.
- A preflight ownership-plan job that produces a file/scope decision table consumed by both engines.

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

**Basic concept**

A file should not be treated as tampered merely because it changed while it was not governed, but this requires either documented workflow discipline or explicit manifest-history analysis.

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

**Guidance**

Use a doc-metadata-only `repository-maintenance.yml` if needed inside `BionicCode/workflows`. Remove sync orchestration from that repository unless explicitly needed. Do not copy the template repository’s local `sync-managed-files.yml` wrapper into `BionicCode/workflows` unless intentionally wanted. Keep shared workflows passive and callable.

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

## Current recommended order

1. **P0-A** — Finish canonical history-link behavior and strict generated format.
2. **P0-B** — Lock protected-field tamper repair with tests.
3. **P1-A** — Fix convention-based manifest governance and remove `documentEligibility`.
4. **P1-B** — Document the convention-based manifest model.
5. **P1-C** — One-time migration for stale generated history lines.
6. **P1-D** — Verify sync workflow after the dependency-file fix.
7. **P1-E** — Final documentation alignment pass.
8. **P2-A** — Design ownership arbitration between sync and doc-metadata.
9. **P2-B** — Define excluded/re-included lifecycle semantics.
10. **P2-C** — Finalize workflow-repository variant.
11. **P2-D** — Performance follow-up.
