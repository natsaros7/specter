# v075 Safe incremental kit upgrades — Tasks

Deploy impact: none (installer and selftest only; projects see the change on their next upgrade).

## ▶ Resume here (2026-11-25)

- **Now.** The spec waits for Nikos (task 1). Nothing is built and no issue is filed.
- **Next, after approval.** One issue per task under a new milestone. Task 3 has no dependency and can run beside
  task 2; task 4 needs both; task 5 needs 2 and 4; task 6 after 5; task 7 last. Batches of at most 3
  (`kit/playbooks/parallel.md`).

- [x] 1 DECISION: Nikos approves or amends decisions 1 to 8 in design.md (manifest then tag; back up, never refuse;
  `.specs/kit.bak-<old>/`; `kit/docs/upgrading.md`; keys listed, never written; no profile seed on upgrade; no
  migration code; synthesized fixtures plus a hand run). Amendments go in as dated rows; nothing below starts before
  this is ticked — [REQ-V075-01] [REQ-V075-02] [REQ-V075-03] [REQ-V075-04]
- [x] 2 `MANIFEST` at every install, the `v<old>` tag when there is none, back up every file that is neither recorded
  nor new into `.specs/kit.bak-<old>/`, lint and uninstall leave the backup alone (selftest 15) — [REQ-V075-01]
- [x] 3 `kit/docs/upgrading.md` with blocks 0.5.0 to 0.11.0; rows that fail on a CHANGELOG release with no block and on
  a key default that differs from the script's (selftest 15b a, b) — [REQ-V075-02]
- [ ] 4 The upgrade report: kit files added, changed and removed, backups, missing config keys, missing steering
  templates, action lines for the version range, in the run and in `--dry-run` (selftest 15b c to h) — [REQ-V075-02]
- [ ] 5 One step equals stepping, a re-run is a no-op, a dry run writes nothing, protected paths keep their bytes, no
  profile seed on upgrade, uninstall after an upgrade (selftest 15c) — [REQ-V075-03] [REQ-V075-04]
- [ ] 6 Docs: `docs/reference.md` upgrade section, GO.md's upgrade step, the `install.sh` usage line, CHANGELOG
  Unreleased — [REQ-V075-01] [REQ-V075-02] [REQ-V075-03]
- [ ] 7 Hand run of a real 0.4.1 install upgraded by this branch, G1 to G4 with rc per gate, deep review, PR with
  Gates, Review and Verification blocks — [REQ-V075-01] [REQ-V075-02] [REQ-V075-03] [REQ-V075-04]
