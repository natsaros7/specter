# v061 Trust-layer hardening — Tasks

Moved from v060 at its close-out (2026-11-24). Each keeps its v060 number in brackets.

## ▶ Resume here (2026-11-24)

- **Plan:** pinned issue #31 holds the batches, decisions and dispatch rules. Tick a batch there when it lands.
- **Landed on `feat/0.10.0`:** tasks 1, 2, 3, 6, 7, 9, 13, 15, 17. G1 to G4 pass at the tip; G3 took 54 min on the
  corporate-scanned Mac.
- **Next: batch 1, task 22 (#29), alone.** Make the selftest faster with fewer process launches and copied fixtures,
  and add `tests/gates.sh --docker` (Colima). Every later batch runs its gates in Docker.
- **Then** batches 2 to 5 and the release, as listed in #31. Task 24 (#32, the lessons loop and the parallel-dispatch
  playbook) is in batch 4.
- **Rules:** 2 to 3 agents per batch. Reset each worktree to the tip. `PYTHONDONTWRITEBYTECODE=1`. Use
  `f=$(mktemp)` for every gate output. Kill an agent's leftover selftests after it reports. Run the full G3 once
  per batch, on the tip.

- [x] 1 `--evidence` thresholds from the profile at the `merged_ref` tip, and print its commit (v060 19a) (#3) — [REQ-V061-01]
- [x] 2 `section()` skips fenced code and HTML comments (v060 19b) (#4) — [REQ-V061-01]
- [x] 3 Docs: evidence assumes squash or merge commits (v060 19c) (#5) — [REQ-V061-01]
- [ ] 4 Count a commit only under its tier's current row; the rest on a `relabelled` line (v060 19d) (#6) — [REQ-V061-01]
- [ ] 5 Window reaches every commit a revert or `Fixes:` above the cut names (v060 19e) (#7) — [REQ-V061-01]
- [x] 6 Unparseable commit date: exit 2 with its sha (v060 19f) (#8) — [REQ-V061-01]
- [x] 7 `GIT_NO_REPLACE_OBJECTS=1` on every git call in `tiers.py`, with a selftest row (v060 19g) (#9) — [REQ-V061-01]
- [ ] 8 Nobody writes `Human-Findings:` on an auto-merge: ignore a `0` on a `none` commit, no trailer hold on a `none` tier (v060 23a) (#10) — [REQ-V061-02]
- [x] 9 Model family variants; a repeated `implementer:`/`reviewer:` line is not ready (v060 23b) (#11) — [REQ-V061-02]
- [ ] 10 Readable reason for an undecodable profile (v060 23c) (#12) — [REQ-V061-02]
- [ ] 11 Approver identity out of reach of the PR's jobs (v060 23d) (#13) — [REQ-V061-03]
- [ ] 12 Approve and merge the checked sha only (v060 23e) (#14) — [REQ-V061-03]
- [x] 13 Refuse a symref to a `.../HEAD` ref; full ids at the repo's hash length only (final review D1, D2) (#15) — [REQ-V061-04]
- [ ] 14 A refused `origin/HEAD` fallback says why; v060's evidence amendment states the symref rule (D3, D4) (#16) — [REQ-V061-04]
- [x] 15 Refuse a ref with a case-folded twin or an unlisted symref target (a pushed `MAIN` shadows `origin/main` on APFS) (#17) — [REQ-V061-04]
- [ ] 16 Gate G1-G4, deep review, CHANGELOG, release, after 17, 18, 20 to 24 (#18) — [REQ-V061-01] [REQ-V061-02] [REQ-V061-03] [REQ-V061-04] [REQ-V061-05] [REQ-V061-06] [REQ-V061-07] [REQ-V061-08] [REQ-V061-09]
- [x] 17 Specter's own `.specs/steering/autonomy.md`: trust-layer files on a Human `required` tier (#24) — [REQ-V061-05]
- [ ] 18 G1-G4 locally before every push (`tests/gates.sh`, a pre-push hook); CI only with Nikos's OK (#25) — [REQ-V061-05]
- [ ] 19 The 0.10.0 PR carries Gates, Review and Verification blocks; `ready.py` says ready (#26) — [REQ-V061-05]
- [ ] 20 README rewritten as Story, How, Output, Worth; roadmap and deck refreshed, with a gates check that the overview names the current VERSION (#27) — [REQ-V061-06]
- [ ] 21 `SECURITY.md`: trust-layer bypasses go to private advisories (#28) — [REQ-V061-07]
- [ ] 22 Faster, deterministic selftest: section timings, `SELFTEST_ONLY`, copied fixtures, no clock content (#29) — [REQ-V061-08]
- [ ] 23 Human `none` only within a size cap (3 files, 50 lines), tests only added, reviewer `complexity: trivial` (#30) — [REQ-V061-09]
- [ ] 24 Specter's own `lessons.md`, a kit playbook for parallel agent dispatch, a retro step in the review loop (#32) — [REQ-V061-10]
