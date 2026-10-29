# v041 Multi-line tasks count their continuation lines — Requirements

Status: In progress
Tracker: none. Branch `fix/0.4.1`. Size S.

## Why

Verified on `main` 2026-10-29 (`4552f40`):

- `kit/scripts/spec_lint.py:115` checks only the checkbox line of a task for a REQ link. Tasks that wrap, with the REQ
  ID on an indented continuation line, are reported as unlinked. During the 0.4.0 rollout, a real project got
  `12 task(s) without a REQ link` although every task carried its ID on its second line.

## Requirements

### [REQ-V041-01] A task is its whole item

- A task SHALL be its checkbox line plus the lines that continue it. A continuation line is non-blank and indented
  deeper than the checkbox's `-`.
- The task ends at a blank line, a heading, or a line indented no deeper than the checkbox. That includes the next
  item at the same level.
- The "task(s) without a REQ link" WARN SHALL search the whole task. Its example text stays the checkbox line.

### [REQ-V041-02] Nothing else changes

- Task counting, ticked detection (the checkbox line only) and every other check SHALL be unchanged.
- The selftest SHALL cover:
  - a wrapped task with its REQ on the continuation line, which counts as linked;
  - a single-line task without a REQ, which still WARNs;
  - a nested sub-item that carries a REQ, which links its parent task, as in Markdown nesting.
