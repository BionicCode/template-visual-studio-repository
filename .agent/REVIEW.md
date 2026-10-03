# REVIEW.md - Code Review Backlog

## Introduction

This is the user's manual fix backlog produced by code reviews.

It is a review artifact, not an implementation task list. Do not read, use, or maintain `REVIEW.md` during implementation tasks unless the user explicitly requests it.

Each actionable finding in the [Log](#log) must be represented as a Markdown
task item. The first line must start with a checkbox followed by a
backlog-stable finding identifier of the form `RNN`, where `NN` is a decimal
sequence number padded to at least two digits (`R01`, `R02`, …, `R99`,
`R100`, …), its review category, and its source location when available.

For example:

```markdown
- [ ] R01 [BUG] `Foo.cs` [L123] — Cancellation can race disposal.
- [ ] R02 [DESIGN] `Bar.cs` [L45] — Responsibility should be moved to the owning abstraction.
```

Additional explanation may be placed on indented continuation lines below the task item.

The reviewing agent maintains the backlog as follows:

- Update `REVIEW.md` only after completing the code review. Do not use existing backlog entries to guide, constrain, or validate the review itself.
- The `Log` contains only actionable findings from code reviews.
- The user's checkbox state is authoritative. Never infer completion from the current code.
- If at least one unchecked item exists, the current backlog remains active.
- For an active backlog, determine the next identifier before removing checked entries. Use one greater than the greatest valid numeric `RNN` identifier currently present anywhere in the `Log`, including checked entries.
- Before appending new findings, remove all checked entries.
- Preserve unchecked entries and any user-added notes unchanged, except when an
  identifier must be repaired under the malformed, missing, or duplicate
  identifier rule below.
- Never renumber existing findings to close gaps, and never deliberately reuse an identifier within the current backlog.
- If a current review finding matches an existing unchecked backlog item, preserve that item's identifier rather than creating a duplicate.
- Append only new, non-duplicate findings and assign their identifiers consecutively from the next available number.
- If no unchecked entries remain, start a new backlog: replace the `Log` with the current review findings and assign identifiers consecutively beginning with `R01`.
- If the current review has no actionable findings and no unchecked entries remain, leave the `Log` empty.
- If malformed, missing, or duplicate identifiers are encountered, preserve valid unique identifiers where possible and assign replacement or new identifiers above the greatest valid identifier currently present. Do not renumber unaffected items merely to restore continuity.
- Preserve this introduction and all content outside the `Log`.

## Log