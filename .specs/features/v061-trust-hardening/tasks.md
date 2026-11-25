# v061 Trust-layer hardening — Tasks

Moved from v060 at its close-out (2026-11-24). Each keeps its v060 number in brackets.

## ▶ Resume here (2026-11-25)

- **Plan:** pinned issue #31 holds the batches, decisions and dispatch rules. Tick a batch there when it lands.
- **Landed on `feat/0.10.0`:** every task except 16, 19 and 20 (README pass 1 is in), plus the deep-review fix
  round (tasks 27 to 30; finding 1 is a private draft advisory, published after 0.10.0 ships). Bug #33 is fixed.
  G1 to G4 pass in Docker (`sh tests/gates.sh --docker`, about 25 s). 0.11 follow-ups are in #40.
- **Next: the 0.10.0 release.** Task 20 pass 2 (README, deck, roadmap, overview PDF), then task 16 (deep review,
  CHANGELOG, VERSION), then task 19 (the release PR's own Gates, Review and Verification blocks, `ready.py` says
  ready). The maintainer approves the merge to `main`, the tag and the GitHub Release.
- **Then:** the orchestrator (stage 5) spec as a proposal, no code; #35 acme eval set; the live recipe test with
  Nikos.
- **Rules:** 2 to 3 agents per batch. Reset each worktree to the tip. `PYTHONDONTWRITEBYTECODE=1`. Use
  `f=$(mktemp)` for every gate output. No polling loops. Gates in Docker. Land with `git cherry-pick`, check the rc,
  count the 24 task lines, then run the gates once on the tip.

- [x] 1 `--evidence` thresholds from the profile at the `merged_ref` tip, and print its commit (v060 19a) (#3) — [REQ-V061-01]
- [x] 2 `section()` skips fenced code and HTML comments (v060 19b) (#4) — [REQ-V061-01]
- [x] 3 Docs: evidence assumes squash or merge commits (v060 19c) (#5) — [REQ-V061-01]
- [x] 4 Count a commit only under its tier's current row; the rest on a `relabelled` line (v060 19d) (#6) — [REQ-V061-01]
- [x] 5 Window reaches every commit a revert or `Fixes:` above the cut names (v060 19e) (#7) — [REQ-V061-01]
- [x] 6 Unparseable commit date: exit 2 with its sha (v060 19f) (#8) — [REQ-V061-01]
- [x] 7 `GIT_NO_REPLACE_OBJECTS=1` on every git call in `tiers.py`, with a selftest row (v060 19g) (#9) — [REQ-V061-01]
- [x] 8 Nobody writes `Human-Findings:` on an auto-merge: ignore a `0` on a `none` commit, no trailer hold on a `none` tier (v060 23a) (#10) — [REQ-V061-02]
- [x] 9 Model family variants; a repeated `implementer:`/`reviewer:` line is not ready (v060 23b) (#11) — [REQ-V061-02]
- [x] 10 Readable reason for an undecodable profile (v060 23c) (#12) — [REQ-V061-02]
- [x] 11 Approver identity out of reach of the PR's jobs (v060 23d) (#13) — [REQ-V061-03]
- [x] 12 Approve and merge the checked sha only (v060 23e) (#14) — [REQ-V061-03]
- [x] 13 Refuse a symref to a `.../HEAD` ref; full ids at the repo's hash length only (final review D1, D2) (#15) — [REQ-V061-04]
- [x] 14 A refused `origin/HEAD` fallback says why; v060's evidence amendment states the symref rule (D3, D4) (#16) — [REQ-V061-04]
- [x] 15 Refuse a ref with a case-folded twin or an unlisted symref target (a pushed `MAIN` shadows `origin/main` on APFS) (#17) — [REQ-V061-04]
- [ ] 16 Gate G1-G4, deep review, CHANGELOG, release, after 17, 18, 20 to 31 (#18) — [REQ-V061-01] [REQ-V061-02] [REQ-V061-03] [REQ-V061-04] [REQ-V061-05] [REQ-V061-06] [REQ-V061-07] [REQ-V061-08] [REQ-V061-09]
- [x] 17 Specter's own `.specs/steering/autonomy.md`: trust-layer files on a Human `required` tier (#24) — [REQ-V061-05]
- [x] 18 G1-G4 locally before every push (`tests/gates.sh`, a pre-push hook); CI only with Nikos's OK (#25) — [REQ-V061-05]
- [ ] 19 The 0.10.0 PR carries Gates, Review and Verification blocks; `ready.py` says ready (#26) — [REQ-V061-05]
- [ ] 20 README rewritten as Story, How, Output, Worth; roadmap and deck refreshed, with a gates check that the overview names the current VERSION (#27) — [REQ-V061-06]
- [x] 21 `SECURITY.md`: trust-layer bypasses go to private advisories (#28) — [REQ-V061-07]
- [x] 22 Faster, deterministic selftest: section timings, `SELFTEST_ONLY`, copied fixtures, no clock content (#29) — [REQ-V061-08]
- [x] 23 Human `none` only within a size cap (3 files, 50 lines), tests only added, reviewer `complexity: trivial` (#30) — [REQ-V061-09]
- [x] 24 Specter's own `lessons.md`, a kit playbook for parallel agent dispatch, a retro step in the review loop (#32) — [REQ-V061-10]
- [x] 25 The lessons ship in the kit: container gates in setup, an empty-mount check, a generic playbook gates line, resume and SECURITY templates (#34) — [REQ-V061-10]
- [x] 26 `kit/scripts/readme_check.py`, a README check any project can run (#36) — [REQ-V061-10]
- [x] 27 Human `none` only when the label's base is the `merged_ref` tip (deep review 1, private advisory) — [REQ-V061-04]
- [x] 28 The test and size checks fail closed: deleted or chmod test files, wider test globs, gitlinks (deep review 2, 3, 10) (#37) — [REQ-V061-09]
- [x] 29 Grafts off; the NTFS fold in `branch_ref` (deep review 6, 7) (#38) — [REQ-V061-01] [REQ-V061-04]
- [x] 30 The gates and the hook cannot report green without running; the recipe fetches full history (deep review 8, 9) (#39) — [REQ-V061-05] [REQ-V061-03]
- [ ] 31 Second-review fixes: narrower test globs, hook checks the pushed sha and untracked files, selftest unsets git env, blank `SELFTEST_ONLY`, recipe fetch (#41) — [REQ-V061-05] [REQ-V061-09]
