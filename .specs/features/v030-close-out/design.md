# v030 Close-out — Design

## Status parsing — [REQ-V030-01] [REQ-V030-02]

The parser in `spec_lint.py` is `feature_status(text)`:

1. It finds the first line before the first `## ` that matches `^\s*>?\s*(\*\*)?Status:?(\*\*)?\s*(.+)$`.
2. It strips `**`, then classifies the value by prefix (case-insensitive): `proposed`, `in progress`, `blocked on`,
   `done`, `dropped`.
3. It returns `{"state", "date", "raw"}`, or `None` if there is no line.

`lint_feature` adds the REQ-V030-02 warnings, using the task counts it already computes from `TASK`. A
task is ticked when it matches `[x]`/`[X]`.

`spec_report.py` imports `feature_status` and keeps its existing inference only as a fallback when the parser returns
`None`. The prose-matching guards stay for that path only.

## Merged-work detection — [REQ-V030-03] [REQ-V030-05]

`merged_commits(root, repos, config)` collects the commits first:

1. For each repo (the root and the indexed child repos) it resolves the ref with `git rev-parse --verify --quiet`:
   `merged_ref` if set (missing → skip the repo), else `origin/HEAD`, then `HEAD`.
2. It runs one `git log <ref> --format=%x00%s%n%b -- . ':(exclude).specs'`. The pathspec drops commits that touch only
   `.specs/`.
3. It splits the output on `\0` and keeps a list of messages per repo.

`lint_all` then checks each feature:

1. It extracts keys from the folder name with `tracker_pattern` (case-insensitive) and normalises them to upper case.
2. It counts the messages containing the key with `(?<![A-Za-z0-9])KEY(?![A-Za-z0-9])`.
3. It applies the REQ-V030-03 conditions.

Cost: one `git log` per repo per lint run. A 30-repo workspace with long histories takes seconds; the lint already
lists files with one `git ls-files` per repo.

The repo index helper moves from `cites` into a shared `repos(root)` used by both checks. It returns paths at depth 1 and 2 whose `.git` is a
directory, or a file whose `gitdir:` doesn't contain `/worktrees/`, skipping hidden parts (already in 0.2.0). That
excludes linked worktrees and keeps submodules.

## Playbooks and templates — [REQ-V030-04] [REQ-V030-07]

- `kit/templates/feature/requirements.md`: line 3 becomes `Status: Proposed`, and the "Blocked on" note moves into
  it.
- `kit/playbooks/sync.md` gets a "Close-out (when a feature lands)" section with the numbered steps.
- `next-task.md` step 6 adds "if this was the last task → close-out".
- The `refresh.md` checklist gains "merged-work warnings".
- `AGENT_RULES.md` gets one bullet. Item 3 of the spec-rules template's Definition of Done gains "Status: Done".
- Example: ord-120's existing `> Status: **Done** (merged 2026-11-03, PR #88)` already parses. ord-142 gets
  `Status: Blocked on <decision>`. Specter's own v020 gets `Status: Done 2026-10-28 (v0.2.0)`.

## Report — [REQ-V030-06]

The status column is coloured as today. A `merged, not closed` badge appears next to the status, and the summary row
gets a fifth counter when it is non-zero.

## Tests

The selftest gets the following:

1. A temp git repo with `.specs/features/abc-7-x/`, `spec-kit.json` with `tracker_pattern: "ABC-[0-9]+"`, and a commit
   `feat: thing (ABC-7)`, with tasks unticked. The lint WARNs "merged work found (1 commit…".
2. A commit for `ABC-70`, which must not count for `ABC-7`.
3. All tasks ticked without `Done`: the close-out WARN.
4. `Done` without a date: a WARN.
5. Missing status: a WARN.
6. A linked worktree (`git worktree add`) inside the project, which is not indexed: no duplicate citation matches.
7. The report shows the badge.

## Risks

| Risk | Mitigation |
|---|---|
| Old spec sets get one "no Status line" WARN per feature | Intended: it is the to-do list. WARN only, exit unchanged |
| A key mentioned in an unrelated commit ("see ABC-7") counts as merged work | It is only a WARN, it names the repos, and a person decides |
| `origin/HEAD` is unset in some clones | Without `merged_ref`, falls back to `HEAD`. Projects set `merged_ref` (e.g. `origin/develop`), and then repos without it are skipped |
| Spec commits naming the key look like merged work | The `.specs` exclude pathspec |
