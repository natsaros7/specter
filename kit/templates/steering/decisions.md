# Steering — Decisions

The record of what was settled, and why. Read it before you open a question it already answers.

- **A decision changes only by a new dated row that supersedes the old one.** Never edit or delete a settled row: add
  the new row under today's heading, put the old id in its "Supersedes" cell, and keep the old row as history.
- Ids are `D-<id>`, where `<id>` is uppercase letters and digits in hyphen-joined groups (a number, or a topic and a
  number). Cite them as `Decision: D-<id>` in requirements, designs and PR descriptions.
- "Where it lands" names the `[REQ-…]` ids (and anything else, in words) the decision governs. Each REQ named there
  cites the decision back in its definition.
- Only decisions that are settled go here. An open question stays in the feature's "Open decisions" until its owner
  answers it.

`spec_lint.py` checks this file once it exists: every cited `D-<id>` has a row, and every REQ in "Where it lands" is
defined. With `"decisions": {"backlinks": true}` in `.specs/spec-kit.json` (or `"warn"`), it also checks the back-links.

## <YYYY-MM-DD>: <topic, e.g. "review of the payment refactor">

| ID | Decision | Why | Where it lands | Supersedes |
|---|---|---|---|---|
| D-<id> | <what was decided, one testable sentence> | <the evidence or reason; who decided> | [REQ-<FEAT>-NN], <other places> | <D-<old id>, or empty> |
