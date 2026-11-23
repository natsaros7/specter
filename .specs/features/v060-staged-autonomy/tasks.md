# v060 Staged autonomy, configured per repository — Tasks

Deploy impact: none (specter has no CI/CD; a project gets each slice only when it re-runs `install.sh`, and nothing
changes until it adds `steering/autonomy.md`)

## ▶ Resume here (2026-11-22, end of session)

Slice 2 is released as 0.7.0 on branch `feat/0.7.0` (pushed; stacked on `feat/0.6.5-acme-java` and `feat/0.6.0`;
none merged to `main`, none tagged). Three security reviews in `docs/reviews/2026-11-22-slice2-*.md`; the last one
says ship, with MINORs left for 0.7.1 (listed in `docs/reviews/2026-11-22-slice2-confirmation-review.md`; the cheap
ones are already in).
- Next: slice 3, tasks 16-19 (guardrails and evidence, release 0.8.0); task 16's decision is already recorded
  (Decided 2026-11-22). Then slice 4, tasks 20-23 (pipeline, release 0.9.0), which closes the v060 milestone.
- Work one task per dispatch, gates G1-G4 after each, a deep-tier security review before each release: slice 2
  needed three review rounds, so plan for it. Trust-layer code (tiers.py, ready.py, gates.py) changes go red-first.
- Release order needs the maintainer: merge 0.6.0, 0.6.5, 0.7.0 to `main` and tag, in that order.
- Pinned (do not start): the platform layer for multi-repo systems, until the CRRD spec split closes. Its input is
  gaps G1-G13 in CRRD's `.specs/features/crrd-platform-split/design.md` § 8.4.

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
- [x] 10 `tiers.py`: parse and `--check` the Tiers table, profile at the base, guarded paths — [REQ-V060-01] [REQ-V060-05]
  - Evidence: `kit/scripts/tiers.py` (`parse_tiers`, `guarded_globs`, `profile_at`, `--check`); selftest 13b red (no script) then green.
- [x] 11 `tiers.py`: label staged or `--range`, `### Risk tier` block, `--json` — [REQ-V060-05]
  - Evidence: `kit/scripts/tiers.py` (`label`); selftest 13b label part red ("expected --check") then green.
- [x] 11a `gates.py`: every row in the `### Gates` block as `pass (…)`, `FAIL (exit n)` or `not run`, a verdict line,
  the block on red runs too; spec-rules §7.1 "cheapest rows first"; selftest case 11 expectation — [REQ-V060-12]
  - Evidence: `kit/scripts/gates.py`; selftest 11 red ("red gates block on stdout") then green; spec-rules §7.1, `docs/reference.md` updated.
- [x] 11b `ready.py`: PR text from `--pr` or stdin, base and head as `tiers.py`, `### Gates` against the base's table
  and the head commit, `### Readiness` block, `--json`, no command run — [REQ-V060-12]
  - Evidence: `kit/scripts/ready.py` (+ `tiers.classify` extracted from `label`); selftest 11b red (ready.py missing) then green: ready, missing/not-run/FAIL lane, stale, dirty, forged row, `--json`, usage.
- [x] 11c `ready.py`: `### Review` block: both model ids, families compared, `rules:` at the base, blocker form — [REQ-V060-13]
  - Evidence: `kit/scripts/ready.py` `check_review`; selftest 11c red (a PR with no `### Review` read as ready) then green: valid, missing block, missing id, rules not the base, same-family WARN, open blocker, blocker without evidence or file:line advisory, `--json` review.
- [x] 11d `ready.py`: `### Verification` lines: REQ defined, path at the head, URL declared not fetched — [REQ-V060-14]
  - Evidence: `kit/scripts/ready.py` `check_verification`; selftest 11d: valid lines (path ok, URL `declared, not fetched`), unknown REQ, missing path, `..`, absolute path, symlink, malformed line, no block ready, `--json` verification.
- [x] 12 Review loop, reviewer role, model routing, spec-rules §7.4: reviewer tier from the label — [REQ-V060-05]
  - Evidence: prose only: `review-loop.md` step 3 and 5, `roles/reviewer.md`, `model-routing.md`, `spec-rules.md` §7.4 point at `tiers.py` and `ready.py`; gates green.
- [x] 12a Review loop, reviewer and generator roles, feature `tasks.md` template: rules read at the base, the
  blocker/advisory verdict table, advisories filed as follow-ups, artifacts checked against acceptance — [REQ-V060-13]
  [REQ-V060-14]
  - Evidence: prose only: `review-loop.md` steps 3-5, prompt and verdict table; `roles/reviewer.md`, `roles/generator.md`, feature `tasks.md` PR task; formats match `ready.py` `check_review`/`check_verification`; gates green.
- [x] 13 Lint: decisions `Checked by` column against the Gates table; decisions template column — [REQ-V060-06]
  - Evidence: `spec_lint.py` (`decision_rows`, `landings`); selftest case 12 "Checked by" part red (rc=0) then green.
- [x] 14 Tiers section in the template, setup Q10 and the example; selftest case 13b, readiness, review and artifact
  cases included — [REQ-V060-05] [REQ-V060-06] [REQ-V060-11] [REQ-V060-12] [REQ-V060-13] [REQ-V060-14]
  - Evidence: template and acme `autonomy.md` gain `## Tiers`; setup Q10 and Phase 5 step 8 cover it; selftest case 14 (installed repo, acme table: test file routine, order source domain, GrpcSecurityFilter critical; `ready.py` verdict) beside 13b, 11b-11d.
- [x] 15 Gate G1-G4 green (deep-tier review); docs, CHANGELOG naming the `### Gates` format change; release 0.7.0 —
  [REQ-V060-11] [REQ-V060-12]
  - Evidence (review fix, ready.py): selftest 11b/11e rows red then green for head gate commands (changed, removed), staged base, stale staged block, blocker location forms, `FAIL (exit -9)`, reviewer-tier warning, provider-prefixed ids, hidden blocks, directory targets, no `__pycache__`; docs name the trusted-copy run.
  - Evidence (review fix, tiers.py): selftest 13b rows for case-folded, nested, quoted-path, subfolder-.specs guards and the merge-base staged base red, then green.
  - Evidence (re-review fix): selftest rows red, then green: folded names (`AGENTſ.md`, `.ſpecs/kit/x`, `.specs/ﬆeering/x.md`, `.clınerules`, `src/Security/Bypass.java`, NFD Knowledge target), `AGENTS.override.md`/`CLAUDE.local.md`/nested `.claude`, work-tree `merged_ref` ignored, no merge base fails closed, Gates table equal (prepended row, duplicate label), `tree changed during gates`, unreadable and en-dash blocker locations, `./` targets, `--range` bad `spec-kit.json` exits 2.

## Slice 3: guardrails and evidence (release 0.8.0)

- [x] 16 Gate: record the evidence-thresholds decision — [REQ-V060-08]
- [x] 17 Guardrails section and the `none` → `spot` downgrade in `tiers.py` — [REQ-V060-07]
  - Evidence: `tiers.parse_guardrails` added; `classify` gains `guardrails` and reports `spot` for an undeclared `none`; `label`, `--json` and `--check` print it (docstring updated). Selftest 13c rows red first (no section left `human: none`), then green; 13b `tprof` now carries a declared Guardrails row so its `none` rows stay `none`; `ready.py` unchanged (reads `change["human"]`).
- [x] 17a Guardrail rows seven (untrusted-text jobs read-only, no secrets, validated write step) and eight (chores from
  a clean clone) in the template and the example; `chores.md` points to row eight — [REQ-V060-07]
  - Evidence: template and acme `autonomy.md` gain `## Guardrails` (eight rows; acme declares all, row seven "no such job, checked `.github/workflows/`") and `## Evidence` (template placeholders with suggested numbers in a comment); `chores.md` "On your machine" points to row eight.
- [x] 18 `tiers.py --evidence`; the `Fixes:` and `Human-Findings:` trailers in review-loop and `sync.md` — [REQ-V060-08]
  - Evidence: `tiers.parse_evidence` and `tiers.evidence` added (`--evidence [--json]`, conflicts with `--check`/`--range`); the merged_ref read is factored out of `classify` as `committed_ref`. One `git log --first-parent -z`, one `classify` per commit by its first parent. Selftest 13c evidence rows red first (`--evidence` was an unknown argument), then green; the docs half (review-loop step 5, sync.md Trailers) was already in.
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
