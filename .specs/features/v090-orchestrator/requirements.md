# v090 Orchestrator (stage 5) — Requirements

Status: Proposed — a proposal awaiting the maintainer's approval; no implementation until task 1 is ticked
Tracker: none yet (one issue per task once task 1 is approved). Branch `docs/v090-orchestrator`. Size L if built in
full; the first slice is S to M.

## Why

Stage 4 is built: the trust layer (`tiers.py`, `ready.py`, `gates.py`, the review loop) decides which changes need a
human. But a human still coordinates every step around it. In v061 the maintainer's session was the orchestrator: it
grouped 31 tasks into lanes ([v061 design](../v061-trust-hardening/design.md), "Parallel lanes"), briefed each worker
with the same rules ("Rules for every worker"), created worktrees, checked their base, counted fix rounds, landed
commits by cherry-pick, re-ran the gates on the tip and kept the "▶ Resume here" block current
([v061 tasks](../v061-trust-hardening/tasks.md)). Most lessons in [lessons.md](../../steering/lessons.md) are slips
in that manual coordination: a masked exit code, a worktree on the wrong base, a shared temp file, a missed
cherry-pick failure, a dropped task line, a polling loop left running for hours, a 33-hour-old agent, a kill by
pattern.
[parallel.md](../../../kit/playbooks/parallel.md) now writes those rules down, but a playbook is prose, and prose is
the last layer ([PHILOSOPHY.md](../../../PHILOSOPHY.md) § 8; research E1).

The README's roadmap puts stage 5 "later, as a separate layer on top of the kit", and the kit's decisions say "no
orchestrator or merge bot in the kit; the platform merges" ([README](../../../README.md), "Where it is going" and
"Decisions"). [pipeline.md](../../../kit/docs/pipeline.md) already names what an orchestrator would read: the
`### Gates`, `### Review`, `### Risk tier` and `### Readiness` blocks, and `--evidence` after the merge. The research
says to adopt before building and to build only the last layer ([research](../../../docs/research/2026-11-21-software-factories.md),
"Orchestrators to adopt rather than build" and E10). Issue #35 (acme-shop as the evaluation set) is the test bed it
names for this proposal.

This file states what the orchestrator must do and must never do. [design.md](design.md) answers how, with the
alternatives and the decisions left to the maintainer.

## User story

As specter's maintainer, I want to hand an approved spec and a goal to a program that runs the planner, generator and
reviewer agents through the existing trust layer, so that I approve specs and answer escalations instead of
dispatching, counting rounds and landing commits by hand, and so that no change merges with less human checking than
the trust layer already requires.

## Requirements

### [REQ-V090-01] A separate layer; the kit stays orchestrator-free

- The orchestrator SHALL live outside `kit/` and SHALL never be copied into a project by `install.sh`. The kit SHALL
  keep working, unchanged, without it.
- It SHALL use only Python 3.8+ stdlib, `git`, the platform CLI (`gh` first) and Docker, and the agent CLIs it is
  configured to run. It SHALL call the kit's scripts (`gates.py`, `tiers.py`, `ready.py`, `spec_lint.py`) as programs,
  from a trusted worktree of the base, never import or copy their logic.
- It SHALL be agent-neutral: each role (planner, generator, reviewer) maps to a runner, a configured command that takes
  a prompt file and a worktree and writes a report. Role briefs come from the kit's `roles/`.
- Acceptance: `install.sh` into a scratch project copies no orchestrator file; the orchestrator's selftest runs with a
  fake runner (a shell script) and no agent CLI installed.

### [REQ-V090-02] It starts only from an approved spec

- It SHALL run a feature only when the feature folder exists at the `merged_ref` tip (full sha), its `Status:` is
  `In progress`, and no `DECISION` task is unticked. An open DECISION SHALL stop it with an escalation, as
  `next-task.md` step 2 stops a human-driven agent.
- Its inputs SHALL be: the goal (one line), the feature folder, the repository's autonomy profile as read at the base,
  the plan issue (optional; offline mode reads only `tasks.md`), and a run configuration (runners, limits) that a human
  writes and the orchestrator never edits.
- It SHALL never change a `Status:` line, a `DECISION` task or a requirement. A worker diff that does SHALL be an
  escalation.
- Acceptance: the selftest runs it on a feature with Status `Proposed`, on one with an open DECISION, and on one present
  only on a branch: each exits non-zero, dispatches nothing and prints why.

### [REQ-V090-03] The task loop follows the review loop, counted by code

- For one task it SHALL: create a worktree at the base sha and check `git rev-parse HEAD` equals it; dispatch the
  generator; freeze the diff to a patch file; run `gates.py` itself and read the exit code (never the worker's report);
  label the frozen diff with `tiers.py` from the trusted copy; dispatch a reviewer in a fresh process, from a runner
  whose model family differs from the implementer's, with the rules read at the base; parse the verdict table.
- A red gate or a complete blocker SHALL start a fix round: round 1 the generator with the full output, round 2 the
  planner with the spec, the diff and both outputs. After round 2 with a red gate or a complete blocker, the task SHALL
  escalate and no agent SHALL retry it until a human acts. The cap is 2, as [review-loop.md](../../../kit/docs/review-loop.md)
  step 4 sets it.
- The orchestrator SHALL write `rounds:` from its own count, not from an agent's claim. Advisories SHALL become
  follow-up issues (or `tasks.md` follow-ups offline) and never block.
- Acceptance: with fake runners, a gate red once then green gives `rounds: 1`; red three times gives an escalation after
  the planner round and no third dispatch; a reviewer configured in the implementer's family is refused before dispatch.

### [REQ-V090-04] Outputs a human can read and the trust layer can check

- Each finished task SHALL produce one PR (offline: one PR text file and a branch) with the `### Gates` block from
  `gates.py`, the `### Risk tier` block, the `### Review` block (implementer, reviewer, rules, rounds, complexity, verdict
  table), any `### Verification` lines, and the `### Readiness` block from `ready.py --range <base sha>...<head sha>`.
- A `not ready` verdict SHALL open the PR as a draft with the reason and an escalation, never as ready for review.
- It SHALL keep the plan issue current in one comment it edits: tasks claimed, in review, merged, escalated, and what
  runs next. It SHALL write an escalation as a label and a comment holding both rounds' outputs.
- Acceptance: on the acme-shop eval set (#35), every PR text passes `ready.py` or is a draft that names why; the plan
  issue comment matches the PR states.

### [REQ-V090-05] The dispatch rules are code, and a run resumes

- The rules of [parallel.md](../../../kit/playbooks/parallel.md) SHALL be enforced by the orchestrator: at most 3 agents
  at once (a lower cap in the run configuration wins); no two tasks in a batch that declare the same file or function;
  a task that declares none runs alone; one worktree per worker under `$HOME`; `PYTHONDONTWRITEBYTECODE=1` and `mktemp`
  for every temp file; a claim comment before dispatch; no polling loop; the Gates on the tip once per batch, in a
  container, before the next batch.
- It SHALL be a reconciler: each invocation reads the state (git, the platform, its journal), advances what it can, and
  exits. A run stopped at any point SHALL resume from that state in a new session. A state it cannot explain (an `orch/`
  branch with no journal entry, a journal entry with no branch) SHALL be an escalation, never a redo.
- Acceptance: killing a run between any two steps and starting it again finishes the same tasks with no duplicate PR,
  claim or dispatch; two tasks that declare the same function never run in one batch.

### [REQ-V090-06] Humans stay where the trust layer puts them

- The orchestrator SHALL never merge, approve, enable auto-merge or hold the approver identity of the Human `none`
  recipe. A merge SHALL happen only as the platform allows it: a human approval, or the separate `ready.py --auto-merge`
  job of review-loop step 5.
- It SHALL never edit the trust layer's own files: the autonomy profile, the Gates table, the installed kit, the
  repository's agent files, `lessons.md`, its own code and its run configuration. A worker diff touching any of them, or
  any path `tiers.py` treats as guarded, SHALL be an escalation, not a PR.
- It SHALL run `tiers.py --evidence` before each batch. A `breach` or a `demote:` line SHALL pause dispatch for that tier
  and escalate; the profile edit stays the human's.
- A change whose `Deploy impact:` is not `none`, a disputed finding, and a red tip SHALL each escalate.
- Acceptance: the orchestrator's source has no call that approves or merges (a selftest greps for the platform calls);
  a fake worker that edits the autonomy profile ends in an escalation with no push.

### [REQ-V090-07] It is safe to leave running, and fails closed

- Credentials: agent processes SHALL get no platform token. The orchestrator's own token SHALL push only to `orch/*`
  branches and write issues and PRs; it SHALL have no merge, admin, tag or `refs/replace/` right, and pushing to the
  default branch SHALL be refused by the platform, not only by the orchestrator. Gates SHALL run in a container with no
  secrets, and with no network unless the run configuration allows it for a gate that needs it.
- Untrusted text: it SHALL build every prompt from the spec at the base sha and its own templates. Issue and PR text
  SHALL be read only for structured markers written by its own identity or labels set by a maintainer.
- Limits: a per-task wall-clock limit, a per-run cap on dispatches and on reported tokens, one gate container at a time
  with a memory cap, and child processes tracked by PID.
- A kill switch (a stop file and a `specter:stop` label on the plan issue) SHALL be checked before every dispatch and
  every platform write; `stop` SHALL kill the recorded PIDs, never by pattern.
- It SHALL append every dispatch, gate result, verdict and platform write to a journal (JSON lines) outside the
  repository: runner, model id, prompt sha256, base and head shas, exit codes.
- Any unexpected state (an exit code it does not know, an unparseable verdict, `ready.py` exit 2, a moved sha, a missing
  runner, a budget it cannot read) SHALL stop that task with an escalation. It SHALL never guess.
- Acceptance: the selftest drives each of these cases with fake runners and checks the exit code, the journal line and
  that nothing was pushed.

### [REQ-V090-08] Trust is earned on the eval set before real use

- The orchestrator SHALL move through rollout stages (dry run, shadow, assisted on a sandbox repository, real
  repository) only on measured results from the acme-shop eval set (#35), recorded in `docs/evals/`.
- Each run SHALL score, per goal: delivered, fix rounds, gates green on the first try, label as expected, escalations
  expected vs actual, unauthorized writes, trust-layer files touched, wall time, human minutes, tokens if reported.
- Two scores SHALL have zero tolerance at every stage: a missed expected escalation, and any write the stage does not
  allow. Either one moves the orchestrator back a stage.
- Acceptance: each stage change cites the eval report that earned it; the maintainer approves it.

## Out of scope

- Merging or approving anything, and the `none` approver job (it stays a platform job, review-loop step 5).
- Writing or approving a spec on its own. Turning a goal into a draft spec (the triage stage) is a later slice whose
  output is a spec PR for the human to approve.
- Turning Human `none` on. That stays the stage-4 live verification, done by a human.
- Specter's own development: its trust tier covers the scripts the orchestrator calls, so every such task escalates by
  design until a human decides otherwise.
- GitLab and other platforms, several repositories in one run, a long-running daemon, a web UI, a cost dashboard.
- Any change to the kit's scripts or playbooks. Where a later slice needs one (an optional `Touches:` line in the
  design template), it is a separate kit change, human-approved.

## Open decisions

The decisions are listed in [design.md](design.md) "Open decisions for the maintainer", each with a recommendation.
Task 1 of [tasks.md](tasks.md) is the decision gate: nothing is built before it is ticked.
