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

- [ ] 9 Gate: record the template-tiers and strictest-file decisions — [REQ-V060-05]
- [ ] 10 `tiers.py`: parse and `--check` the Tiers table, profile at the base, guarded paths — [REQ-V060-01] [REQ-V060-05]
- [ ] 11 `tiers.py`: label staged or `--range`, `### Risk tier` block, `--json` — [REQ-V060-05]
- [ ] 12 Review loop, reviewer role, model routing, spec-rules §7.4: reviewer tier from the label — [REQ-V060-05]
- [ ] 13 Lint: decisions `Checked by` column against the Gates table; decisions template column — [REQ-V060-06]
- [ ] 14 Tiers section in the template, setup Q10 and the example; selftest case 13b — [REQ-V060-05] [REQ-V060-06]
  [REQ-V060-11]
- [ ] 15 Gate G1-G4 green (deep-tier review); docs; release 0.7.0 — [REQ-V060-11]

## Slice 3: guardrails and evidence (release 0.8.0)

- [ ] 16 Gate: record the evidence-thresholds decision — [REQ-V060-08]
- [ ] 17 Guardrails section and the `none` → `spot` downgrade in `tiers.py` — [REQ-V060-07]
- [ ] 18 `tiers.py --evidence`; the `Fixes:` and `Human-Findings:` trailers in review-loop and `sync.md` — [REQ-V060-08]
- [ ] 19 Selftest case 13c; gate G1-G4 green; docs; release 0.8.0 — [REQ-V060-07] [REQ-V060-08] [REQ-V060-11]

## Slice 4: the pipeline (release 0.9.0)

- [ ] 20 Gate: record the auto-merge and `spot` decisions as decision rows — [REQ-V060-09]
- [ ] 21 Review-loop step 5 by tier; `labels_only` off; the platform recipe — [REQ-V060-09]
- [ ] 22 `kit/docs/pipeline.md`: stages, hand-offs, when the human enters — [REQ-V060-10]
- [ ] 23 Gate G1-G4 green; docs; release 0.9.0; close the feature out — [REQ-V060-09] [REQ-V060-10] [REQ-V060-11]
