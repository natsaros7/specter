# v061 Trust-layer hardening — Tasks

Moved from v060 at its close-out (2026-11-24). Each keeps its v060 number in brackets.

- [ ] 1 `--evidence` thresholds from the profile at the `merged_ref` tip, and print its commit (v060 19a) — [REQ-V061-01]
- [ ] 2 `section()` skips fenced code and HTML comments (v060 19b) — [REQ-V061-01]
- [ ] 3 Docs: evidence assumes squash or merge commits (v060 19c) — [REQ-V061-01]
- [ ] 4 Flag a renamed or changed tier row in the window (v060 19d) — [REQ-V061-01]
- [ ] 5 Window reaches every commit a revert or `Fixes:` above the cut names (v060 19e) — [REQ-V061-01]
- [ ] 6 Unparseable commit date: exit 2 with its sha (v060 19f) — [REQ-V061-01]
- [ ] 7 `GIT_NO_REPLACE_OBJECTS=1` on every git call in `tiers.py`, with a selftest row (v060 19g) — [REQ-V061-01]
- [ ] 8 Who writes `Human-Findings:` on an auto-merge (v060 23a) — [REQ-V061-02]
- [ ] 9 Model family variants; a repeated `implementer:`/`reviewer:` line is not ready (v060 23b) — [REQ-V061-02]
- [ ] 10 Readable reason for an undecodable profile (v060 23c) — [REQ-V061-02]
- [ ] 11 Approver identity out of reach of the PR's jobs (v060 23d) — [REQ-V061-03]
- [ ] 12 Approve and merge the checked sha only (v060 23e) — [REQ-V061-03]
- [ ] 13 Refuse a symref to a `.../HEAD` ref; full ids at the repo's hash length only (final review D1, D2) — [REQ-V061-04]
- [ ] 14 A refused `origin/HEAD` fallback says why; v060's evidence amendment states the symref rule (D3, D4) — [REQ-V061-04]
- [ ] 15 Probe a case-folded `MAIN` branch on a case-insensitive runner — [REQ-V061-04]
- [ ] 16 Gate G1-G4, deep review, CHANGELOG, release — [REQ-V061-01] [REQ-V061-02] [REQ-V061-03] [REQ-V061-04]
