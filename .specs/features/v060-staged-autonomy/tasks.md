# v060 Staged autonomy, configured per repository — Tasks

Deploy impact: none (specter has no CI/CD; a project gets each slice only when it re-runs `install.sh`, and nothing
changes until it adds `steering/autonomy.md`)

## Slice 1: a solid stage 3 (release 0.6.0)

- [x] 1 Gate: record the memory-file and first-chore decisions in the Open decisions; delete the unused option —
  [REQ-V060-02] [REQ-V060-03]
- [x] 2 Templates `steering/autonomy.md` (Knowledge and Chores sections only) and `steering/lessons.md` — [REQ-V060-01]
  [REQ-V060-02] [REQ-V060-03]
- [x] 3 `AGENT_RULES.md` (read `start` rows, write lessons) and `sync.md` (a lesson seen twice becomes a check first, prose only when uncheckable) — [REQ-V060-02]
- [x] 4 `kit/docs/chores.md`: cron, launchd and CI schedule recipes; a writing chore works on a branch — [REQ-V060-03]
- [x] 5 `spec_report.py`: In flight card from worktrees and unmerged branches — [REQ-V060-04]
- [x] 6 Setup Q10 for Knowledge and Chores; example `autonomy.md` in acme-shop — [REQ-V060-11]
- [x] 7 Selftest cases 13 and 13a — [REQ-V060-01] [REQ-V060-03] [REQ-V060-04] [REQ-V060-11]
- [x] 8 Gate G1-G4 green; reference, README, CHANGELOG; release 0.6.0 — [REQ-V060-11]

## Slice 2: risk-tier labels (release 0.7.0)

- [x] 9 Gate: record the strictest-file, model-family, shared-family and missing-artifact decisions —
  [REQ-V060-05] [REQ-V060-13] [REQ-V060-14]
- [ ] 10 `tiers.py`: parse and `--check` the Tiers table, profile at the base, guarded paths — [REQ-V060-01] [REQ-V060-05]
- [ ] 11 `tiers.py`: label staged or `--range`, `### Risk tier` block, `--json` — [REQ-V060-05]
- [ ] 11a `gates.py`: every row in the `### Gates` block as `pass (…)`, `FAIL (exit n)` or `not run`, a verdict line,
  the block on red runs too; spec-rules §7.1 "cheapest rows first"; selftest case 11 expectation — [REQ-V060-12]
- [ ] 11b `ready.py`: PR text from `--pr` or stdin, base and head as `tiers.py`, `### Gates` against the base's table
  and the head commit, `### Readiness` block, `--json`, no command run — [REQ-V060-12]
- [ ] 11c `ready.py`: `### Review` block: both model ids, families compared, `rules:` at the base, blocker form — [REQ-V060-13]
- [ ] 11d `ready.py`: `### Verification` lines: REQ defined, path at the head, URL declared not fetched — [REQ-V060-14]
- [ ] 12 Review loop, reviewer role, model routing, spec-rules §7.4: reviewer tier from the label — [REQ-V060-05]
- [ ] 12a Review loop, reviewer and generator roles, feature `tasks.md` template: rules read at the base, the
  blocker/advisory verdict table, advisories filed as follow-ups, artifacts checked against acceptance — [REQ-V060-13]
  [REQ-V060-14]
- [ ] 13 Lint: decisions `Checked by` column against the Gates table; decisions template column — [REQ-V060-06]
- [ ] 14 Tiers section in the template, setup Q10 and the example; selftest case 13b, readiness, review and artifact
  cases included — [REQ-V060-05] [REQ-V060-06] [REQ-V060-11] [REQ-V060-12] [REQ-V060-13] [REQ-V060-14]
- [ ] 15 Gate G1-G4 green (deep-tier review); docs, CHANGELOG naming the `### Gates` format change; release 0.7.0 —
  [REQ-V060-11] [REQ-V060-12]

## Slice 3: guardrails and evidence (release 0.8.0)

- [x] 16 Gate: record the evidence-thresholds decision — [REQ-V060-08]
- [ ] 17 Guardrails section and the `none` → `spot` downgrade in `tiers.py` — [REQ-V060-07]
- [ ] 17a Guardrail rows seven (untrusted-text jobs read-only, no secrets, validated write step) and eight (chores from
  a clean clone) in the template and the example; `chores.md` points to row eight — [REQ-V060-07]
- [ ] 18 `tiers.py --evidence`; the `Fixes:` and `Human-Findings:` trailers in review-loop and `sync.md` — [REQ-V060-08]
- [ ] 19 Selftest case 13c (eight guardrail rows included); gate G1-G4 green; docs; release 0.8.0 — [REQ-V060-07]
  [REQ-V060-08] [REQ-V060-11]

## Slice 4: the pipeline (release 0.9.0)

- [x] 20 Gate: record the auto-merge, `spot` and planner-round decisions as decision rows — [REQ-V060-09] [REQ-V060-15]
- [ ] 21 Review-loop step 5 by tier; `labels_only` off; the platform recipe with a merge queue; a shared family bars
  `none` — [REQ-V060-09] [REQ-V060-13] [REQ-V060-16]
- [ ] 21a Fix-round cap: review-loop diagram and step 4, model-routing rule 3, generator role, `next-task.md`;
  `rounds:` in `### Review`, checked by `ready.py` — [REQ-V060-15]
- [ ] 21b `tiers.py --evidence`: the `demote:` line on a breach, profile untouched — [REQ-V060-16]
- [ ] 22 `kit/docs/pipeline.md`: stages, hand-offs, when the human enters (the fix-round cap, not "second red gate") —
  [REQ-V060-10] [REQ-V060-15]
- [ ] 22a Selftest case 13d: fix-round cap, demotion line — [REQ-V060-11] [REQ-V060-15] [REQ-V060-16]
- [ ] 23 Gate G1-G4 green; docs; release 0.9.0; close the feature out — [REQ-V060-09] [REQ-V060-10] [REQ-V060-11]
  [REQ-V060-15] [REQ-V060-16]
