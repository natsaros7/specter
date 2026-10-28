# v030 Close-out: feature status, done checks, merged-work detection — Requirements

Status: In progress
Tracker: none. Branch `feat/0.3.0`. Size M.

## Why

Verified on `main` 2026-10-28 (`96b4cd8`):

- Closing a feature is a rule but not a step anyone checks. `kit/playbooks/sync.md:17` says to tick `tasks.md` and record
  the merge, and `kit/templates/steering/spec-rules.md:48` repeats it in the Definition of Done. Nothing verifies either.
- There is no status field. `kit/templates/feature/requirements.md:3` has an optional "Blocked on" note only, so
  `kit/scripts/spec_report.py:49` has to guess Done/Blocked from prose and checkboxes.
- The pre-commit hook is the only enforcement, and it doesn't run in multi-repo workspaces, where commits happen in the
  child repos. An audit of a mature workspace (2026-10-28) found:
  - a feature merged with **0 of 10** tasks ticked;
  - a finished feature never folded into `domains/`;
  - several features whose last tasks were done but never ticked.
- Linked git worktrees inside the workspace (`.git` is a file) are indexed as extra repos. During that audit a single
  worktree made 122 citations ambiguous.

## User story

As a lead, I want every feature to say plainly whether it is proposed, in progress, blocked, done or dropped, and the
lint to tell me when that claim disagrees with the tasks or with what has been merged, so that "done in code, open in
the spec" can't go unnoticed.

## Requirements

### [REQ-V030-01] Status field

- The feature `requirements.md` template SHALL start with a `Status:` line right under the title, with one of:
  `Proposed` · `In progress` · `Blocked on <what>` · `Done <YYYY-MM-DD> (<PR or commit>)` · `Dropped <YYYY-MM-DD> (<why>)`.
- The lint SHALL read the first `Status:` line before the first `## ` heading (optional leading `>` and `**`). An
  unknown value SHALL WARN `unknown status '<value>'`.

### [REQ-V030-02] Consistency checks

`spec_lint.py` SHALL WARN (exit code unchanged) when:

| Condition | Message |
|---|---|
| No `Status:` line | `no Status line (see the requirements template)` |
| All tasks ticked, status not `Done`/`Dropped` | `all tasks ticked: close out (Status: Done <date> (<PR>), fold into domains/ per sync.md)` |
| Status `Done`, some tasks unticked | `Status is Done but N task(s) are unticked` |
| Status `Done` without a date | `Done needs a date and the PR or commit` |

### [REQ-V030-03] Merged-work detection

- WHEN `tracker_pattern` is set in `spec-kit.json` (default `null`, off) THEN for each feature whose folder name
  contains a match, the lint SHALL count commits on the merged ref whose message contains that key not followed by a
  digit. It SHALL count in the project root and in every indexed child repo, with one `git log` per repo.
- Merged ref: `merged_ref` when set; a repo where it doesn't resolve SHALL be skipped silently, so branch-only work
  never counts. When `merged_ref` is not set, the lint SHALL use `origin/HEAD`, then `HEAD`.
- Commits that change only files under `.specs/` SHALL NOT count: writing the spec is not merged work.
- WHEN commits exist AND the status is missing or `Proposed`, or (no task is ticked AND the status is not `Done` or
  `Dropped`) THEN it SHALL WARN
  `merged work found (<N> commit(s) in <repos>) but the spec says <status>, <done>/<total> tasks`.
- The project root SHALL be labelled `.` in the repo list. The check SHALL NOT change the exit code.

### [REQ-V030-04] Close-out step in the playbooks

- `next-task.md`: after ticking the last task, the agent SHALL run the close-out in `sync.md` and SHALL NOT report the
  feature as finished before it.
- `sync.md` "When a feature lands" SHALL be a numbered close-out:
  1. set `Status: Done <date> (<PR>)`;
  2. tick the remaining tasks or mark them dropped with a reason;
  3. fold the outcome into `domains/` and `system/`;
  4. resolve Drift Register rows it fixed;
  5. run the lint.
- `AGENT_RULES.md` "Before you call it done" and the spec-rules template's Definition of Done SHALL name the status
  update.
- `refresh.md` SHALL include a pass over the merged-work warnings.

### [REQ-V030-05] Linked worktrees

The repo index (`--cites` and REQ-V030-03) SHALL skip folders whose `.git` is a file (linked worktrees and
submodules).

### [REQ-V030-06] Report

- `spec_report.py` SHALL take the status from the `Status:` line when present, and fall back to today's inference
  for specs without one.
- A feature with a REQ-V030-03 warning SHALL be marked `merged, not closed`, and the summary SHALL count those features.

### [REQ-V030-07] Docs and tests

- The template, the example specs and specter's own specs SHALL carry `Status:` lines, and the example SHALL lint
  without status warnings.
- The README loop table SHALL mention the close-out. The CHANGELOG `[Unreleased]` SHALL list every change.
- The selftest SHALL cover REQ-V030-01 to 06, including a temp repo with a commit naming a feature's key while its
  tasks are unticked.

## Out of scope

- Changing statuses automatically. The lint only reports; a person or agent closes out.
- Tracker APIs (Jira and so on). Git history is the only source.
