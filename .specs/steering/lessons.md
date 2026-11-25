# Steering — Lessons
One dated line per correction.
A lesson seen twice becomes a check first: a Gates row, a lint rule or a test. Only when no check can catch it does it become a rule in spec-rules, code-standards or decisions, with the reason it can't be checked.

- 2026-11-24 A gate's exit code was masked by `| tail` → `tests/gates.sh` prints one `G<n> rc=` line per gate.
- 2026-11-24 Agent worktrees started on `main`, not the feature tip → the base check in `kit/playbooks/parallel.md`.
- 2026-11-24 A stray `__pycache__` showed up in a diff → `PYTHONDONTWRITEBYTECODE=1`, set in the playbook.
- 2026-11-24 Parallel agents shared one `$TMPDIR` file → `mktemp` for every temp file, in the playbook.
- 2026-11-24 Selftests were left running after a batch → the playbook's stop step.
- 2026-11-24 A `cherry-pick` failure went unnoticed → the playbook's landing step checks its rc.
- 2026-11-24 A task line was dropped in a merge conflict → the playbook counts the task lines after each landing.
- 2026-11-24 "Continue" started GO instead of resuming → the exception in `AGENTS.md`.
- 2026-11-25 Corporate scanners slow every process the host launches → run the gates in a container (`tests/gates.sh --docker`) and launch fewer processes.
- 2026-11-25 Agents left polling loops (`until …; sleep`) running for hours → the playbook forbids them, and the dispatcher checks for stray loops at each batch.
- 2026-11-25 An agent from an earlier session was still running 33 h later → the same stray-process check, at session start.
- 2026-11-25 Killing by a pattern that the kill command itself contains killed that command → kill by PID (the playbook's stop step).
- 2026-11-25 A container runtime that shares only `$HOME` mounted a clone under `/tmp` as an empty dir → put scratch clones under `$HOME` (task 25 adds a mount check).
