---
Version: 1
Created: 2026-10-05T14:43:12+00:00
Updated: 2026-10-05T14:43:12+00:00
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

# Code review instructions

Read before beginning a code review, including the exact `<review>` prompt. Analysis or design feedback without a code-review request does not invoke this workflow. Implementation self-review does not invoke backlog maintenance. Load the other domain and task instructions selected by the root router as well.

## Code Review Rules
Goal: perform a deep, evidence-based code review focused on correctness, behavioral risk, contract mismatches, and maintainability.

If the user does not provide review scope:
- Start from the changed files, the requested entry points, or the most relevant public API surface you can identify.
- Trace the reachable call tree as far as repository context reasonably allows.
- Prioritize actual behavior over naming assumptions.

### Review Priorities
Prioritize findings in this order:
1. Correctness
2. Behavioral risk and hidden edge cases
3. API or contract mismatches
4. Data consistency / state consistency / cache consistency
5. Performance on meaningful paths
6. Maintainability and design clarity
7. Tests and documentation coverage

### Required Review Method
- Review by tracing actual call paths, not by isolated file scanning only.
- Start from the selected entry point(s) and follow calls downward until:
  - the full relevant path is understood, or
  - you hit a boundary caused by missing files, generated code, dynamic dispatch you cannot resolve, external dependencies, or insufficient context.
- Prefer evidence-based findings over speculative concerns.
- Distinguish clearly between confirmed defects, likely risks, and unverified suspicions.
- When a finding depends on branch-sensitive behavior or framework/library helper behavior, verify it with at least one concrete witness input and trace that input through the relevant branches before labeling the finding as `[BUG]`.
- If the concern is based on a plausible pattern but no concrete witness input has been traced successfully, report it as `[RISK]` or stop with uncertainty instead of escalating it to a confirmed defect.
- For edge-case claims, include the minimal witness input in the finding explanation.
- If a finding depends on framework or library API semantics that are not proven by the local code alone, verify that behavior from trusted documentation, runtime evidence, or other repository-local proof before labeling the finding as `[BUG]`; otherwise report it as `[RISK]` or stop with uncertainty.

### Review Output Format

Organize the review by file.

Each actionable finding must have a backlog-stable identifier of the form `RNN`,
where `NN` is a decimal sequence number padded to at least two digits
(`R01`, `R02`, …, `R99`, `R100`, …). A new backlog begins with `R01`;
an active backlog continues according to the Review Backlog rules below. Place the identifier before the primary category tag.

For each file:
- Use a file header with the filename.
- Use 1-based line references in the format `[L123]`.
- Format each actionable finding beginning with its identifier and one primary category, for example:
  - `R01 [BUG] [L123] — <finding>`
  - `R02 [DESIGN] [L45] — <finding>`
- Tag each finding with one primary category:
  - `[ERROR]`
  - `[BUG]`
  - `[SECURITY]`
  - `[PERF]`
  - `[DESIGN]`
  - `[API]`
  - `[DOCS]`
  - `[TEST]`
  - `[STYLE]`
  - `[RISK]`

When useful, mention secondary impacts in the explanation, but keep one primary tag per finding.

Finding identifiers are assigned only after the review findings themselves have been determined. Identifier assignment must not influence review scope, finding discovery, severity, or completeness.

### Required Review Sections

Include these sections in this order:
1. `Scope / Entry Points`
2. `Call-tree`
3. `Findings`
4. `Coverage / Call-tree traversal depth`

### Stop / Uncertainty Rules

- If you cannot fully verify a path, stop and explicitly say where verification stopped.
- Do not present an assumption as a confirmed defect.
- State why verification stopped: missing file, generated code, unclear runtime behavior, unresolved dynamic dispatch, external dependency, insufficient context, or command execution not requested.

### Review Backlog

After completing a code review and determining all findings, read [`.agent/REVIEW.md`](../REVIEW.md) and reconcile the review identifiers with its `Log` before producing the final review response.

- Do not consult `REVIEW.md` when determining review scope, findings, severity, or completeness.
- Use the same `RNN` identifier for a finding in both the review report and `REVIEW.md`.
- If a current finding matches an existing unchecked backlog entry, preserve and reuse that entry's identifier.
- Assign identifiers for new findings according to the allocation rules defined in `REVIEW.md`.
- Never change an existing backlog identifier merely to make numbering continuous.
- References such as `R03` refer to the current state of `REVIEW.md` unless the user explicitly identifies an earlier review or report.
- After identifier reconciliation, update the `Log` according to the maintenance rules defined in `REVIEW.md`.
- If `REVIEW.md` is unavailable, the review report remains valid independently: assign current findings consecutively beginning with `R01` and report that the backlog could not be updated.
- The normal final response must still follow the complete review-output contract above.
- During implementation tasks, do not read, use, or modify `REVIEW.md` unless the user explicitly requests it.
