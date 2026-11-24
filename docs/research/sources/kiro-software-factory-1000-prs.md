# Source notes: Kiro, "software factory: 1,000 PRs" (2026-09-18)

URL: https://kiro.dev/blog/software-factory-1000-prs/. Follow-up: https://kiro.dev/blog/software-factory-stability/ (2026-10-26). Authors: Zejiang (Joe) Guo, Bolin Chen, Zezhen Xu (Kiro Crew team, AWS). Product blog by the product's own engineers. All numbers self-reported. Notes, not a copy; short quotes only. Read 2026-11-21.

## Claim

Three full-time engineers merged 1,000 PRs in seven days ("over 120 a day"), each through CI and review, running 30 to 50 sessions at once on six to ten machines. No defect, revert or incident data. It does not say how many PRs were agent-authored or community-contributed.

## The five stages (classified by concurrent sessions)

| Stage | Sessions | What it adds | What the human does |
|---|---|---|---|
| 1. One session by hand | 1 | — | Drives; the agent waits on the human |
| 2. Many sessions by hand | 3–5 | More tabs | Is "the glue", re-explaining the project per tab |
| 3. Memory, dashboard, cron, workflows | ~10–20 | Sessions "start warm"; one dashboard; cron/monitor loops; fixed or dynamic workflows | Still reads every update and picks what to act on. "This is where Kiro Crew really started." |
| 4. Agent pipeline | 20+ | Triage → implement → review → merge as independent stages coordinated only through a message queue | Designs the fixed shape; must revise when a result invalidates the plan ("cannot re-plan") |
| 5. Operate sessions the agentic way (Crew Mode) | 50+ | An agent outside any session decomposes, dispatches, patrols, accepts, sequences; creates, seeds, watches, closes sessions | "You keep the goal." Still in progress, behind a feature preview |

Specter's position on 2026-11-21: between stage 2 and stage 3 (see `.specs/features/v060-staged-autonomy/requirements.md`).

## Governance (from day one)

Four controls: coordination between agents ("explicit and durable"; coordination that lives only in a model's context "disappears on the next compaction"); memory (what may be remembered, by which agent, for which project, visible to whom); permission control ("Enforced by the host, not requested politely in a prompt"); audit trail ("recorded where the agent cannot edit it"). "Nearly impossible to retrofit when you have fifty." "A capability an enterprise cannot control, audit, or afford is a demo, not a product."

## Stability follow-up (2026-10-26, from the research agent's read)

Role-split AI reviewers (design, first-principles, UX) on different model families; a blocking finding needs location, quoted evidence, trigger and consequence, otherwise advisory; review rules load from main so a PR cannot judge itself; fork PRs run without secrets. "PR Readiness": one verdict over 80+ checks, every expected lane must have run; cheap gate first; a check that the PR description matches the code; a test pod with screenshots and video; >90% coverage; hourly compliance, daily security scans, a red-team bot after merge. The simple tier auto-merges; features classified simple (straight to build) / medium (one-page design) / complex (team review). ~20% of team time on factory infrastructure. Failure modes: "resolve every comment" churn; review rounds over-engineering (fixed with proportionality checks and a "conductor" agent).

## Starter advice

A file in the repo every session reads (conventions, repeated corrections); hand one recurring chore (issue triage, flaky re-runs) to a timed session; GitHub issue labels as a first queue, one session type per label. Don't start at stage 5: find the duty that eats your day.

## Gaps

Review, gate, merge and queue mechanics are vague in the first post; the spec format is not described; cost is named as the adoption barrier (coordination overhead) with no figures.
