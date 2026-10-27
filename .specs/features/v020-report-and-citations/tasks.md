# v020 Report page, citation notations, drift aging, JSON output — Tasks

## ▶ Resume here

Goal: 0.2.0 on branch `feat/0.2.0`. The gate: `tests/selftest.sh && python3 kit/scripts/spec_lint.py --specs .specs &&
python3 kit/scripts/spec_lint.py --specs .specs --cites`. The release waits for the Codex dry run.

- [x] 1 Split `spec_lint.py` into collect (dicts) and print, with no output change for existing cases — [REQ-V020-06]
- [x] 2 New citation pattern: prefix + `cite_aliases`, multi-range, `#L` — [REQ-V020-01] [REQ-V020-02]
- [x] 3 Index nested repos two levels deep; `cite_ignore_globs` tie-break — [REQ-V020-03] [REQ-V020-04]
- [x] 4 Drift aging with `drift_max_age_days` — [REQ-V020-05]
- [x] 5 `--json` for both modes — [REQ-V020-06]
- [x] 6 `spec_report.py` → `report.html` — [REQ-V020-07]
- [x] 7 `.specs/.gitignore` on install and uninstall; defaults in `kit/spec-kit.json` — [REQ-V020-08]
- [x] 8 Self-test cases (a)–(i) — [REQ-V020-01] [REQ-V020-02] [REQ-V020-03] [REQ-V020-04] [REQ-V020-05] [REQ-V020-06] [REQ-V020-07] [REQ-V020-08]
- [x] 9 README Scripts and settings, CHANGELOG `[Unreleased]` — [REQ-V020-08]
- [ ] 10 Gate green; review in a fresh context — [REQ-V020-01] [REQ-V020-07]
- [ ] 11 Codex dry-run friction log folded in, then release 0.2.0 (with confirmation) — [REQ-V020-08]
