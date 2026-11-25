# v090 Orchestrator (stage 5) — Tasks

A proposal. Task 1 is the decision gate; tasks 2 to 8 are sketches, to be specified in full (one issue each, Touches
lines, red rows) only after task 1 is ticked.

## ▶ Resume here (2026-11-25)

- **Now.** The proposal is written and waits for Nikos (task 1). Nothing is built and no issue is filed.
- **Next, after approval.** File one issue per task under a new milestone, then task 2 (#35's goals and the hand-run
  baseline) before task 3.

- [ ] 1 DECISION: Nikos approves or amends the proposal: the recommendation (option D), decisions 1 to 8 and open
  decisions O1 to O8 in design.md, the rollout stages and their thresholds, the first slice and the out-of-scope list.
  Answers go into design.md's Decisions table as dated rows; nothing below starts before this is ticked — [REQ-V090-01] [REQ-V090-02] [REQ-V090-03] [REQ-V090-04] [REQ-V090-05] [REQ-V090-06] [REQ-V090-07] [REQ-V090-08]
- [ ] 2 Prerequisite, tracked on #35: the eval set's first three goals in `examples/acme-shop/eval/`, and a baseline run
  by hand (human minutes, wall time, rounds) in `docs/evals/` — [REQ-V090-08]
- [ ] 3 Slice 1, offline and single-task: `orchestrator/specter_run.py` with `plan` and `task --sandbox`, runners from
  the run configuration, one commit per round, gates in the named container, `tiers.py` and `ready.py` from a trusted
  base worktree, rounds counted, escalation and PR text as files, journal, stop file, per-dispatch timeout;
  `orchestrator/selftest.sh` with fake runners; a gate row for it in AGENTS.md and `tests/gates.sh` (trust tier, Nikos
  reviews); `install.sh` still copies no orchestrator file — [REQ-V090-01] [REQ-V090-02] [REQ-V090-03] [REQ-V090-06] [REQ-V090-07]
- [ ] 4 R1 shadow runs: the eval set twice through slice 1; report in `docs/evals/`; Nikos decides on R2 — [REQ-V090-08]
- [ ] 5 Slice 2, the platform on a sandbox repository: its own identity (O4) with write limited to `orch/*`, claims,
  PRs with the five blocks, drafts for `not ready`, escalation labels, follow-up issues, the plan comment; resume from
  the journal and the platform; the live check that its token cannot approve or merge; then R2 runs — [REQ-V090-04] [REQ-V090-05] [REQ-V090-07] [REQ-V090-08]
- [ ] 6 Slice 3, batches: disjoint `Touches:` sets, up to 3 agents, gates on each new tip, the evidence pause on a
  breach or `demote:` line, the tick PR per batch (O3) — [REQ-V090-05] [REQ-V090-06]
- [ ] 7 Later, each its own proposal: the triage stage (a planner drafts a spec PR from a goal, a human approves it);
  a CI trigger for the same command, only with Nikos's OK (O6); R3 on a real repository — [REQ-V090-02] [REQ-V090-08]
- [ ] 8 Close-out: README stage-5 row, roadmap and deck, CHANGELOG, `docs/reference.md` decisions — [REQ-V090-01]
