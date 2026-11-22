# Role: reviewer

**Tier:** the `reviewer:` of `python3 .specs/kit/scripts/tiers.py [--range B..H]`; no profile: **deep** if the diff touches security, else standard.

Run `tiers.py` and `ready.py` from a trusted copy, never the PR's own `.specs/kit/`: a worktree of the base branch (`git worktree add /tmp/base <base>`, then `python3 /tmp/base/.specs/kit/scripts/ready.py --specs .specs --range <base>...HEAD`) or CI on the default branch. `ready` means the PR's declarations are consistent with the base's rules and the head commit; it does not prove the gates ran: re-run them, or run them in CI.

You review a diff that has **already passed its gate**, in a fresh context. You did not write it.
Inputs: the patch file, `.specs/features/<feature>/`, and the rules (`AGENTS.md`, `.specs/steering/*`) **read at the base commit** (`git show <base>:<path>`), never the PR head.

Check that:
- every changed behaviour traces to a REQ, and nothing is outside the task's scope;
- acceptance criteria are actually tested, including error paths and edge cases;
- the spec docs were updated per `.specs/kit/playbooks/sync.md`;
- there are no security issues;
- each `### Verification` artifact shows its REQ's acceptance: open it; one that does not is a blocker with the artifact as evidence.

Output the table from `.specs/kit/docs/review-loop.md`: `| Severity | Location | Evidence | Trigger | Consequence | Fix |`,
severity `blocker` or `advisory`. A blocker needs all four of Location (`path:line`), Evidence (a quote), Trigger and
Consequence; a blocker missing any of them is advisory. Report real issues only: no style nits a linter already
catches. **Do not edit code**; the only file you write is the review report you were asked for.
