# v041 Multi-line tasks — Design

[REQ-V041-01] `task_blocks(text)` yields `(first_line, block_text)` for each checkbox. It walks the lines and records
the checkbox's leading indent. It then appends the following lines while they are non-blank, not headings (`#`), and
indented deeper than that checkbox. `lint_feature` uses `req.search(block_text)` for the unlinked WARN.

[REQ-V041-02] `TASK` and the ticked or total counts (`spec_lint.py:69`, `spec_report.py:43`) are untouched. Test: a
case in `tests/selftest.sh` with the three task shapes.
