# v060 Staged autonomy, configured per repository — Requirements

Status: In progress (slice 1 released in v0.6.0, slice 2 in v0.7.0; slices 3 and 4 remain)
Tracker: none. Branch `feat/0.6.0` for slice 1; one branch and one release per slice after it. Size L.

## Why

The maintainer's plan (2026-11-21): take a codebase from "a human reads every change and makes every decision" to
more agent autonomy, in stages, each earned. Every codebase has its own rules, style and place for its knowledge, so
all of it is per-repository configuration, never hard-coded.

Outside reference, not evidence: Kiro's "software factory" post (https://kiro.dev/blog/software-factory-1000-prs/,
vendor, self-reported) describes five stages: one session; many sessions; memory, dashboard, cron and workflows; an
agent pipeline (triage, implement, review, merge) coordinating through a queue; a coordinating agent. It names human
attention as the limit, puts governance first, and reports throughput but no defect or rollback data.

Research input for slices 2 to 4: [software factories](../../../docs/research/2026-11-21-software-factories.md), final
section, rows E1 to E10 (candidates, mostly self-reported sources). E1 landed in slice 1; E2, E4 and E5 amend slice 2,
E8 slice 3, E3 and E7 slice 4; E6, E9 and E10 wait for v070.

**Where specter is today: between stage 2 and stage 3.** Several sessions run in parallel; specs and rules mean they
don't start from zero; there is no cron, no scheduled workflow and no session dashboard; the human tracks the sessions
and reads every change. Verified on `main` 2026-11-21 (`7c7f4f1`):

- Warm start exists, but only as one fixed entry point: `kit/AGENT_RULES.md:3` sends every agent to the router
  `.specs/README.md`. Where this repo keeps its ADRs, architecture tests or lessons is prose in the router or in
  spec-rules §4; no script can read it.
- Memory is per feature only: the `▶ Resume here` block (`kit/playbooks/new-feature.md:45`,
  `kit/playbooks/next-task.md:5`). A correction the human gives in one session has no place to land for the next one.
- Nothing runs on a schedule: `kit/playbooks/refresh.md:3` says "run this periodically", and nothing does.
- The one dashboard is spec health: `kit/scripts/spec_report.py` (before slice 1) shows features, drift, coverage and citations.
  It does not show which sessions are working on what, although parallel worktrees are the documented way to run
  workers (review-loop.md lines 42-46 at aabed8b).
- Every change ends at a human: review-loop.md lines 28 at aabed8b ("Human check: rerun the gate yourself … then commit").
  The only routing by risk is prose: the reviewer goes deep "when the diff touches security" (`kit/roles/reviewer.md:3`),
  and the review rule in `kit/templates/steering/spec-rules.md:62` is a free-text placeholder.
- There is no record of how changes fared after merge (reverts, follow-up fixes, what the human still caught), so no
  tier could earn autonomy on numbers. Searched `grep -rniE 'autonom|auto-merge|codeowners|audit' kit`: the only hit
  is "Work autonomously" in `kit/templates/feature/AGENT_PROMPT.md:2`.

Pieces this spec reuses rather than rebuilds: the Gates table runner (`kit/scripts/gates.py:33`, it already skips
tables without Gate and Command columns), changed-file listing and fnmatch globs (`kit/scripts/spec_sync_check.py:18-27`),
the relative-link check that already resolves paths outside `.specs/` (`kit/scripts/spec_lint.py:188-200`), the
merged-commit log (`kit/scripts/spec_lint.py:349`), the decisions table parser (`kit/scripts/spec_lint.py:234`) and
the list of agent files the installer writes (`kit/scripts/install.py:20-26`).

Verified on `feat/0.6.0` 2026-11-21 (`aabed8b`), for the research rows:

- A red gate hides what did not run: `gates.py` stops at the first failure and writes only to stderr
  (`kit/scripts/gates.py:103-106`); the `### Gates` block exists only when every row passed (`kit/scripts/gates.py:109`).
  The selftest pins today's block lines (`tests/selftest.sh:370`).
- The reviewer reads "the project rules" with no commit named, so in practice the working tree, which the diff may
  have edited (review-loop.md lines 23-25 at aabed8b). Its findings are `blocker/major/minor` with no evidence required
  (review-loop.md lines 38 at aabed8b, the 0.6 `kit/roles/reviewer.md` output line), and every finding goes back to the worker
  (review-loop.md lines 26-27 at aabed8b).
- Fix rounds are bounded only up to the deep tier: retry once, then escalate (`kit/docs/model-routing.md:28-29`).
  Nothing says what happens when the deep round fails too.
- The clean-clone rule for scheduled chores exists as prose only (`kit/docs/chores.md:19-21`); the Guardrails table
  of REQ-V060-07 does not list it, nor a row for agent jobs that read untrusted text.

## User story

As the lead of a codebase worked by several agent sessions, I want each repository to declare where its knowledge
lives, what runs on a schedule, how each change is routed by risk, which guardrails the platform enforces and what
evidence earns a tier more autonomy, so that my attention goes to the changes that need it, and a repository that
declares nothing behaves exactly as today: every change goes to a human.

## Stages

| Slice | Kiro stage | Adds | A human still |
|---|---|---|---|
| 1 | a solid 3 | Knowledge and memory that load per repo, one scheduled chore, an in-flight view | reads every change |
| 2 | 3, routed | Risk-tier labels on every change, decisions checked by gates, a readiness verdict, a review contract, verification artifacts | reads every change; the label says where to look hardest |
| 3 | 3, measured | Guardrails declared before autonomy (untrusted triggers and chores included); an evidence report per tier | reads every change; sees which tier the numbers would allow to relax |
| 4 | 4 | Human check by tier (only after the auto-merge decision), pipeline hand-offs, a fix-round cap, a merge queue and demotion on breach | sets goals, approves rules, handles exceptions |

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
- The profile SHALL be read as of the change's base (the merge base for a range; for staged files the merge base with `merged_ref` as committed at `HEAD`, and the last tier for every file when there is none), so a
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
- Amended 2026-11-21 (research E8): the template SHALL also list two more rows, eight in all. Seven: an agent job
  triggered by untrusted text (an issue, a PR, a comment, an outside contribution) runs read-only and without
  secrets, and its writes go through a separate step that validates them. Eight: scheduled chores run from a clean
  clone or the CI checkout of the default branch, never from a working copy (the rule in `kit/docs/chores.md:19-21`).
  A repository with no such job or no chores SHALL say so in `Enforced by` ("no such job, checked <how>"), with the
  `Verified` date; the row then counts as declared.
- Amended 2026-11-24 (slice 4 re-review N1, N4): row three SHALL say that every PR needs an approval, dropped on a new
  commit, which only the `ready.py --auto-merge` job's non-agent identity may give for a `none` PR (REQ-V060-09); row
  six SHALL also bar agents from creating tags and `refs/replace/` refs.
- A tier whose Human is `none` SHALL be labelled as `spot`, with the reason, until every row names what enforces it
  and has a `Verified` date.
- Specter SHALL NOT claim to enforce any guardrail. It records the declaration; the platform enforces it.

### [REQ-V060-08] Evidence per tier

- The Evidence section SHALL be a table `| Tier | Window (days) | Min merged | Max reverted % | Max escaped % | Max human-caught % |`.
- `tiers.py --evidence` SHALL read first-parent commits on `merged_ref` inside each window, label each with the profile
  as of its parent, and count per tier: merged; reverted (a later `This reverts commit <sha>`); escaped (a later
  `Fixes: <sha>` trailer); human-caught (a `Human-Findings: <n>` trailer with n > 0).
- Per tier it SHALL print `eligible`, `hold (<why>)` or `breach (<metric>)`. A metric with no data is a hold, never a pass.
- Amended 2026-11-24 (slice 4 re-review N1): `merged_ref` and its fallback (`refs/remotes/origin/HEAD`) SHALL resolve
  to exactly one branch or remote-tracking ref; a tag or an ambiguous name SHALL be refused, and a label SHALL not
  count a history that holds any commit of the change.
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
  table; `### Risk tier` block) and when the human enters: spec approval, the fix-round cap reached (REQ-V060-15;
  amended 2026-11-21, was "second red gate"), disputed finding, the tier's Human value, an edit to a guarded path,
  `Deploy impact` not `none`.
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
  - an evidence hold with no data;
  - added 2026-11-21, slice 2: a red table's block lists `FAIL` and `not run`; `ready.py` refuses a block that lacks a
    row of the base's Gates table or names another commit; rules read at another commit; an incomplete blocker
    counted as advisory; the same model family warned; a declared artifact missing at the head; `ready.py` runs no
    command;
  - slice 3: the eight guardrail rows, and an undeclared row seven downgrading `none`;
  - slice 4: a task over the fix-round cap; the demotion line on a breach, with the profile left unchanged.

### [REQ-V060-12] Readiness verdict (slice 2, research E2)

- `gates.py` SHALL write the `### Gates` block to stdout on every run that reaches the table, green or red: one line
  per Gates row in table order, `pass (<last output line>)`, `FAIL (exit <n>)` or `not run`, then `commit:`, then
  `verdict: ready` only when every row passed, else `verdict: not ready (<n> failed, <m> not run)`. It SHALL still stop
  at the first failure and keep its exit codes (0 green, 1 a gate failed, 2 nothing run).
- A row that did not run SHALL count as a FAIL. The run order SHALL stay the table's order: the spec-rules template
  advises cheapest rows first, and no script reorders rows.
- A new `kit/scripts/ready.py` SHALL check a PR description (a file, or stdin) against the repository without running
  any command. The `### Gates` block SHALL list every row of the Gates table as of the change's base (the base of
  REQ-V060-05) as `pass`, end with `verdict: ready`, and name the change's head as its commit. A missing row, a row
  not `pass`, or another commit SHALL make the verdict `not ready`.
- Output: a `### Readiness` block (one line per check, then `verdict: ready` or `verdict: not ready (<why>)`) and
  `--json`. Exit 0 ready, 1 not ready, 2 on a bad argument or an unreadable input. It SHALL never run a gate, merge,
  approve or edit.

### [REQ-V060-13] Review contract (slice 2, research E4)

- The PR description SHALL carry a `### Review` block: the implementer's model id, the reviewer's model id and tier,
  the commit at which the reviewer read the rules (`rules: <sha>`), and the verdict table.
- The reviewer SHALL read the project rules (`AGENTS.md`, `.specs/steering/*`, the Knowledge `start` rows) as of the
  change's base, with `git show <base>:<path>`, never from the working tree, the way `tiers.py` reads the profile.
  `ready.py` SHALL report `not ready` when `rules:` is not the base.
- The verdict table SHALL be `| Severity | Location | Evidence | Trigger | Consequence | Fix |`, severity `blocker` or
  `advisory`. A blocker SHALL give a `file:line` location, quoted code or output as evidence, the input or state that
  triggers it, and its consequence. A blocker with any of the four empty SHALL count as advisory; `ready.py` SHALL say
  so and name the empty cell.
- Only blockers SHALL go back to the implementer. An advisory SHALL be filed as a follow-up (a task in the feature's
  `tasks.md` with its REQ, or a tracker key, named in the Fix cell) and SHALL NOT block the merge. A complete blocker
  in the final `### Review` block SHALL make `ready.py` report `not ready`.
- `ready.py` SHALL compare the implementer's and the reviewer's model families (how a family is read: Open
  decisions). A shared family SHALL print `review: same family (<family>)` as a WARN, exit code unchanged. Once
  REQ-V060-09 lands, a change reviewed in its implementer's family SHALL NOT take Human `none`; it is labelled `spot`.
- Specter SHALL record and check these declarations only. It runs no model and cannot prove which model ran; the
  platform's review record is the evidence.

### [REQ-V060-14] Verification artifacts (slice 2, research E5)

- A PR description MAY carry a `### Verification` block, one line per artifact: `- [<REQ id>] <relative path or URL>:
  <what it shows>`. Without the block nothing changes.
- `ready.py` SHALL check each line: the REQ id is defined in a feature's `requirements.md`; a relative path exists at
  the change's head (in the index for staged mode); a URL is reported `declared, not fetched`. An undefined REQ SHALL
  be `not ready`; a path missing at the head SHALL be `not ready` (FAIL or WARN: Open decisions).
- The reviewer SHALL open each artifact and check it against that REQ's acceptance, not only the diff. An artifact
  that does not show the acceptance SHALL be a blocker, with the artifact as its evidence.

### [REQ-V060-15] Fix-round cap (slice 4, research E3)

- A task SHALL get at most 2 fix rounds. A round is one attempt to fix a red gate or the complete blockers of a
  review. The worker's retry is round 1, the planner's escalation round 2 (Open decisions).
- When round 2 ends with a red gate or a complete blocker, the task SHALL go back to the human with both rounds'
  outputs (gate output or verdict table), and no agent SHALL retry it until the human acts.
- The `### Review` block SHALL carry `rounds: <n>`. `ready.py` SHALL report `not ready (fix-round cap)` when n > 2
  and a WARN when the line is missing.
- `kit/docs/review-loop.md`, `kit/docs/model-routing.md`, `kit/roles/generator.md` and `kit/playbooks/next-task.md`
  SHALL state the cap.

### [REQ-V060-16] Merge queue and demotion on breach (slice 4, research E7)

- The platform recipe of REQ-V060-09 SHALL include a merge queue (GitHub merge queue, GitLab merge trains or the
  platform's equivalent), so changes that are green alone are gated together before they merge. Amended 2026-11-24
  (slice 4 re-review N3): the queue re-runs the Gates on the merged result; `ready.py` runs at the PR (its head and base),
  never on the queue's merge commit.
- When `tiers.py --evidence` reports `breach` for a tier, it SHALL also print the demotion: the tier row as
  `file:line` and its Human value one step stricter (`none` → `spot`, `spot` → `required`; `required` prints
  "already required"). The human edits the profile; `tiers.py` SHALL NOT (REQ-V060-08). A tier in breach is not
  `eligible`, so REQ-V060-09 already refuses it `none` until the evidence recovers.

## Out of scope

- Classifying a change by its content (a new dependency vs a version bump, a public signature change): tiers are by
  path. Size limits per tier.
- Per-tier gate lists: every tier runs the full Gates table.
- Remote branches, PRs or any platform API in the in-flight view: specter stays offline.
- A queue, scheduler, orchestrator or merge bot in the kit, and Kiro's stage 5 (a coordinating agent).
- Making `.specs/` relocatable: the folder name stays fixed; what is inside points outward.
- Multi-repo workspaces: slice 2 labels the repository that holds `.specs/` only.
- Running or calling a model, or proving which model ran: specter checks declarations offline (REQ-V060-13).
- Deferred to v070 (research rows, not decided here):
  - E6: setup proposes verification gates by stack (property, contract and architecture tests, runtime checks), and
    the Knowledge table points to a feature map.
  - E9: a Drift Register row that describes an anti-pattern gets a "contain" action: a lint rule that stops new
    occurrences, then cleanup tasks.
  - E10: tracker-agnostic task export: spec tasks become tickets with blockers and tier labels through one small
    adapter per tracker (GitHub Issues, GitLab, Jira, Linear), chosen per repository in config. Offline by default: it
    writes an export file that the adapter or the host's orchestrator consumes. Still no orchestrator in the kit.

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
- 2026-11-21, maintainer: "amend v060, then v070". Slices 2 to 4 absorb research rows E2, E4 and E5 (slice 2), E8
  (slice 3), E3 and E7 (slice 4); E6, E9 and E10 go to v070. Lands on [REQ-V060-07], [REQ-V060-10], [REQ-V060-11]
  and [REQ-V060-12] to [REQ-V060-16].

- 2026-11-22, maintainer ("please dive in": the lead's recommended calls, open to correction): the eight open
  decisions are settled as follows.
  - Strictest file wins: a test kept next to the source takes the source's tier; no exclusion syntax. Lands on
    [REQ-V060-05].
  - A model's family is the model id's first `-`-separated token (`claude`, `gpt`, `gemini`); no config. Lands on
    [REQ-V060-13].
  - A reviewer in the implementer's family is a WARN that bars Human `none` once [REQ-V060-09] lands; never
    `not ready` on its own, so a single-vendor repository can still work. Lands on [REQ-V060-13].
  - A declared artifact path missing at the head is `not ready`: a declared artifact that is not there is a false
    claim. Lands on [REQ-V060-14].
  - Evidence thresholds ship as placeholders, so no tier is eligible until the repository sets numbers; the template
    suggests numbers in a comment. Lands on [REQ-V060-08].
  - Auto-merge (Human `none`) is allowed only on the lowest tier, only when the repository opts in, its evidence
    thresholds are met and every guardrail row passes; otherwise `none` behaves as `spot`. Lands on [REQ-V060-09].
  - `spot` means approve on the readiness verdict, gates and tests; reading a sampled diff in full is not shipped.
    Lands on [REQ-V060-09].
  - The planner's escalation counts as fix round 2: worker retry, planner, then the human (Stripe caps at two CI
    rounds; the model-routing rule already escalates this way). Lands on [REQ-V060-15].

## Open decisions

None. Platform-wide (multi-repository) specs are pinned until the CRRD split proves the model (2026-11-22).
