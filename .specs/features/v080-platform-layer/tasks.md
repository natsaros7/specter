# v080 Platform layer — Tasks

Deploy impact: none (a lint mode and templates; a root without `"layer": "platform"` lints as before)

## ▶ Resume here (2026-11-25)

- **Goal.** The first slice of the platform layer: lint the platform and every member (G2), cite member requirements
  (G3), cross-repo task lines (G11), and the `layer` key and two registries they need (G1, minimum).
- **Now.** The spec is written and waits for Nikos (task 1). Nothing is built and no issue is filed.
- **Open.** Decisions 1 to 11 in design.md, each with a recommendation; the out-of-scope list (G4 to G14).
- **Next, after approval.** One issue per task under the release milestone, then task 2, then 3, 4 and 5 (one after
  another, or each rebased on the last), then 6.
- **Gates.** `sh tests/gates.sh --docker` (G1 to G4); per task `SELFTEST_ONLY=<27…> sh tests/selftest.sh` first.

- [x] 1 DECISION: Nikos approves or amends the slice: decisions 1 to 11 and the out-of-scope list in design.md. Answers go into the Decisions table as dated rows; nothing below starts before this is ticked — [REQ-V080-01] [REQ-V080-02] [REQ-V080-03] [REQ-V080-04] [REQ-V080-05]
- [x] 2 `layer` and `members_root` keys, the `system/repos.md` registry check, member lookup and `--members-root`; `repos.md` and `contracts.md` templates; setup and GO layout notes (selftest 27) (#85) — [REQ-V080-01] [REQ-V080-02]
- [x] 3 `spec_lint.py --members`: platform plus each member under its own config, `== <repo>` blocks, a missing checkout WARNs and is named on the summary, `--json` (selftest 27b) (#86) — [REQ-V080-03]
- [ ] 4 Platform features resolve member ids from checked-out members' domains and features; ambiguous FAILs; unchecked members turn a miss into a WARN (selftest 27c) (#87) — [REQ-V080-04]
- [ ] 5 Cross-repo task lines: one repo or `platform:` per task, a child feature or PR, `after:` to existing tasks with no cycle; template and playbook line (selftest 27d) (#88) — [REQ-V080-05]
- [ ] 6 Close-out: CHANGELOG, `docs/reference.md` pass, G1 to G4 green, gate-review, PR with Gates, Review and Verification blocks (#89) — [REQ-V080-01] [REQ-V080-02] [REQ-V080-03] [REQ-V080-04] [REQ-V080-05]
