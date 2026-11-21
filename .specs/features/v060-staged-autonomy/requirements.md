# v060 Staged autonomy, configured per repository — Requirements

Status: In progress (slice 1 released in v0.6.0; slices 2 to 4 remain)
Tracker: none. Branch `feat/0.6.0` for slice 1; one branch and one release per slice after it. Size L.

## Why

The maintainer's plan (2026-11-21): take a codebase from "a human reads every change and makes every decision" to
more agent autonomy, in stages, each earned. Every codebase has its own rules, style and place for its knowledge, so
all of it is per-repository configuration, never hard-coded.

Outside reference, not evidence: Kiro's "software factory" post (https://kiro.dev/blog/software-factory-1000-prs/,
vendor, self-reported) describes five stages: one session; many sessions; memory, dashboard, cron and workflows; an
agent pipeline (triage, implement, review, merge) coordinating through a queue; a coordinating agent. It names human
attention as the limit, puts governance first, and reports throughput but no defect or rollback data.

**Where specter is today: between stage 2 and stage 3.** Several sessions run in parallel; specs and rules mean they
don't start from zero; there is no cron, no scheduled workflow and no session dashboard; the human tracks the sessions
and reads every change. Verified on `main` 2026-11-21 (`7c7f4f1`):

- Warm start exists, but only as one fixed entry point: `kit/AGENT_RULES.md:3` sends every agent to the router
  `.specs/README.md`. Where this repo keeps its ADRs, architecture tests or lessons is prose in the router or in
  spec-rules §4; no script can read it.
- Memory is per feature only: the `▶ Resume here` block (`kit/playbooks/new-feature.md:45`,
  `kit/playbooks/next-task.md:5`). A correction the human gives in one session has no place to land for the next one.
- Nothing runs on a schedule: `kit/playbooks/refresh.md:3` says "run this periodically", and nothing does.
- The one dashboard is spec health: `kit/scripts/spec_report.py:143-150` shows features, drift, coverage and citations.
  It does not show which sessions are working on what, although parallel worktrees are the documented way to run
  workers (`kit/docs/review-loop.md:42-46`).
- Every change ends at a human: `kit/docs/review-loop.md:28` ("Human check: rerun the gate yourself … then commit").
  The only routing by risk is prose: the reviewer goes deep "when the diff touches security" (`kit/roles/reviewer.md:3`),
  and the review rule in `kit/templates/steering/spec-rules.md:62` is a free-text placeholder.
- There is no record of how changes fared after merge (reverts, follow-up fixes, what the human still caught), so no
  tier could earn autonomy on numbers. Searched `grep -rniE 'autonom|auto-merge|codeowners|audit' kit`: the only hit
  is "Work autonomously" in `kit/templates/feature/AGENT_PROMPT.md:2`.

Pieces this spec reuses rather than rebuilds: the Gates table runner (`kit/scripts/gates.py:25`, it already skips
tables without Gate and Command columns), changed-file listing and fnmatch globs (`kit/scripts/spec_sync_check.py:18-27`),
the relative-link check that already resolves paths outside `.specs/` (`kit/scripts/spec_lint.py:188-200`), the
merged-commit log (`kit/scripts/spec_lint.py:349`), the decisions table parser (`kit/scripts/spec_lint.py:234`) and
the list of agent files the installer writes (`kit/scripts/install.py:20-26`).

## User story

As the lead of a codebase worked by several agent sessions, I want each repository to declare where its knowledge
lives, what runs on a schedule, how each change is routed by risk, which guardrails the platform enforces and what
evidence earns a tier more autonomy, so that my attention goes to the changes that need it, and a repository that
declares nothing behaves exactly as today: every change goes to a human.

## Stages

| Slice | Kiro stage | Adds | A human still |
|---|---|---|---|
| 1 | a solid 3 | Knowledge and memory that load per repo, one scheduled chore, an in-flight view | reads every change |
| 2 | 3, routed | Risk-tier labels on every change, decisions checked by gates | reads every change; the label says where to look hardest |
| 3 | 3, measured | Guardrails declared before autonomy; an evidence report per tier | reads every change; sees which tier the numbers would allow to relax |
| 4 | 4 | Human check by tier (only after the auto-merge decision), pipeline hand-offs | sets goals, approves rules, handles exceptions |

Each slice ships and gives value on its own. A later slice never starts before the earlier one is released.

## Requirements

### [REQ-V060-01] Autonomy profile

- A repository SHALL declare its autonomy settings in `.specs/steering/autonomy.md`, from a new
  `kit/templates/steering/autonomy.md`. Its sections are optional and independent: Knowledge, Chores, Tiers,
  Guardrails, Evidence. A section that is absent is not configured.
- When the file is absent, every script and playbook SHALL behave as in 0.5.0, and any risk label (REQ-V060-05)
  SHALL be the human tier.
- The scripts that read a section SHALL exit 2 with `file:line` on a malformed row or a template placeholder (`<…>`)
  left in, and SHALL never guess a value. A Knowledge placeholder surfaces as a broken-link FAIL of the lint (exit 1);
  the Chores `Runs:` line is prose that no script reads. The gate commands stay in spec-rules §7 and are not repeated here.

### [REQ-V060-02] Knowledge and memory that load per repository

- The Knowledge section SHALL be a table `| Knowledge | Where | Read |`: what it is, one or more relative links or
  URLs, and `start` (every session reads it after the router) or the trigger for reading it (e.g. "before a design").
- The existing link check SHALL cover its relative links; no new check is needed.
- One row SHALL be the memory: the file where sessions record lessons. `kit/AGENT_RULES.md` SHALL tell agents to read
  the `start` rows and, when the human corrects them, to write one dated line to the memory file in the same session.
- A lesson that recurs SHALL be proposed first as a check (a Gates row, a lint rule or a test); a steering rule or a
  decision row only when no check can catch it, with the reason. Either way it is decided once (REQ-V060-06).

### [REQ-V060-03] One recurring chore on a schedule

- The Chores section SHALL be a table in the Gates shape (`| # | Gate | Command |`), run by
  `gates.py --file .specs/steering/autonomy.md`, with one line naming the schedule and what runs it.
- The template SHALL ship one scripted chore, spec health: the citation check and the report page.
- `kit/docs/` SHALL give a local scheduler recipe (cron, launchd) and a CI schedule recipe. The kit itself schedules
  nothing and sends nothing anywhere.
- A chore that changes files SHALL work on its own branch and reach the default branch only through the normal
  review; the docs say so.

### [REQ-V060-04] In-flight view

- `spec_report.py` SHALL add an "In flight" section: each linked worktree and each local branch not merged into
  `merged_ref` (or its fallback), with its last commit date, its uncommitted file count (worktrees) and the feature
  folders its diff touches.
- It SHALL read git only, offline, and show "no git data" instead of failing.
- The In flight card is unconditional: it does not depend on `autonomy.md` (REQ-V060-01 covers the lint and playbooks).

### [REQ-V060-05] Risk tiers: labels only

- The Tiers section SHALL be a table `| Tier | Paths | Reviewer | Human |`, rows ordered from most to least autonomous.
  Paths are fnmatch globs, one per code span, matched as in `spec_sync_check.py`. Reviewer is `standard` or `deep`.
  Human is `none`, `spot` or `required`, never decreasing down the table, and the last row SHALL be `required`.
- A new `kit/scripts/tiers.py` SHALL label a change (staged files, or `--range A...B`): each file takes the lowest row
  it matches, an unmatched file takes the last row, and the change takes its strictest file's tier.
- Guarded paths SHALL always take the last row, whatever the table says: `.specs/steering/*`, `.specs/spec-kit.json`,
  `.specs/kit/*`, every in-repo path the Knowledge section names, and the agent files the installer writes.
- The profile SHALL be read as of the change's base (the merge base for a range, `HEAD` for staged files), so a
  change is judged by the rules it started under. No profile at the base means the human tier.
- Output: a `### Risk tier` block for the PR (tier, Reviewer, Human, the file and glob that set it, the profile's
  commit) and `--json`. Exit 0 once labelled, 2 on a bad profile or argument. It SHALL never merge, approve or edit.
- Until REQ-V060-09 lands, the block SHALL say that every change still gets the human check. The reviewer tier comes
  from the label instead of the prose rule.

### [REQ-V060-06] Decide once: decisions checked by gates

- The decisions template SHALL gain an optional `Checked by` column: a gate label from the spec-rules Gates table, or
  empty when the decision is guidance only.
- When the column is present, the lint SHALL FAIL with `file:line` on a label that names no gate. Without the column,
  nothing changes.

### [REQ-V060-07] Guardrails before autonomy

- The Guardrails section SHALL be a table `| Guardrail | Enforced by | Verified |`. The template SHALL list: protected
  default branch (no direct or force push); the Gates as required checks; required human review on `required` paths
  (CODEOWNERS or the platform's equivalent); agent credentials that cannot approve or merge; agent permissions set by
  the host's configuration, not by a prompt; merged history and review records the agents cannot edit.
- A tier whose Human is `none` SHALL be labelled as `spot`, with the reason, until every row names what enforces it
  and has a `Verified` date.
- Specter SHALL NOT claim to enforce any guardrail. It records the declaration; the platform enforces it.

### [REQ-V060-08] Evidence per tier

- The Evidence section SHALL be a table `| Tier | Window (days) | Min merged | Max reverted % | Max escaped % | Max human-caught % |`.
- `tiers.py --evidence` SHALL read first-parent commits on `merged_ref` inside each window, label each with the profile
  as of its parent, and count per tier: merged; reverted (a later `This reverts commit <sha>`); escaped (a later
  `Fixes: <sha>` trailer); human-caught (a `Human-Findings: <n>` trailer with n > 0).
- Per tier it SHALL print `eligible`, `hold (<why>)` or `breach (<metric>)`. A metric with no data is a hold, never a pass.
- It SHALL never edit the profile. Promotion is a human edit of the profile, which is itself a guarded path.

### [REQ-V060-09] Human check by tier

Blocked on the auto-merge decision.

- `required` SHALL stay today's human check.
- `spot` SHALL mean that the human approves on the reviewer's verdict, the `### Gates` block and the tests, and reads
  the flagged files in full.
- `none` SHALL mean no human before merge, only when the guardrails are declared (REQ-V060-07), the tier is
  `eligible` (REQ-V060-08) and the decision allows it. The merge is the platform's (its auto-merge on required checks),
  never a specter script's.

### [REQ-V060-10] Pipeline hand-offs

- A new `kit/docs/pipeline.md` SHALL map triage, implement, review and merge to the existing playbooks and roles.
- For each stage it SHALL name what is handed on (approved spec and tasks; frozen patch and `### Gates` block; verdict
  table; `### Risk tier` block) and when the human enters: spec approval, second red gate, disputed finding, the tier's
  Human value, an edit to a guarded path, `Deploy impact` not `none`.
- The queue SHALL be the host's (issues, draft PRs, CI). The kit ships no orchestrator.

### [REQ-V060-11] Setup, docs and compatibility

- Setup SHALL offer the profile as an ask-if-unclear question, default "not now" (no file, everything human), and
  propose Knowledge rows and tier globs from what Phase 1 found.
- `docs/reference.md`, the README and the CHANGELOG SHALL describe each slice as it ships.
- A 0.5.0 project without the profile SHALL keep its lint exit code and output.
- The selftest SHALL cover, per slice:
  - the missing profile;
  - a placeholder refused;
  - a chore run through `gates.py`;
  - the in-flight section;
  - strictest-file labelling, an unmatched file and a guarded path;
  - the profile read at the base;
  - an unknown `Checked by` gate;
  - `none` downgraded without guardrails;
  - an evidence hold with no data.

## Out of scope

- Classifying a change by its content (a new dependency vs a version bump, a public signature change): tiers are by
  path. Size limits per tier.
- Per-tier gate lists: every tier runs the full Gates table.
- Remote branches, PRs or any platform API in the in-flight view: specter stays offline.
- A queue, scheduler, orchestrator or merge bot in the kit, and Kiro's stage 5 (a coordinating agent).
- Making `.specs/` relocatable: the folder name stays fixed; what is inside points outward.
- Multi-repo workspaces: slice 2 labels the repository that holds `.specs/` only.

## Decided

- 2026-11-21, maintainer: the memory file is `.specs/steering/lessons.md`, in git, shared, link-checked, and a
  guarded path, because a lesson steers every agent that reads it. Lands on [REQ-V060-02] and [REQ-V060-05].
- 2026-11-21, maintainer: the first chore is scripted spec health (citation check and report page). It costs no
  tokens and needs no host permissions. A scheduled agent refresh is not shipped. Lands on [REQ-V060-03].
- 2026-11-21, maintainer: the template ships three suggested tiers (`routine`: tests, docs, lockfiles; `domain`:
  source; `critical`: security, interfaces, migrations, CI) for setup to confirm. Lands on [REQ-V060-05].
- 2026-11-21, maintainer: a recurring lesson becomes a deterministic check first and prose only when it can't be
  checked, because prose is the weakest layer and agents use it to justify workarounds
  (`docs/research/2026-11-21-software-factories.md`, Potato section). Lands on [REQ-V060-02].

## Open decisions

- DECISION: Is auto-merge (Human `none`) ever allowed, and for which tier? Default until answered: no; `none` behaves
  as `spot`. Blocks REQ-V060-09. — maintainer
- DECISION: `spot` means approve on verdict, gates and tests (default), or read one sampled diff in N in full? — maintainer
- DECISION: Evidence thresholds: ship placeholders, so no tier is ever eligible until the repo sets numbers (default),
  or ship suggested numbers? — maintainer
- DECISION: Strictest file wins, so a test kept next to the source takes the source's tier. Accept (default), or add
  an exclusion syntax? — maintainer
