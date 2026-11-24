# v061 Trust-layer hardening — Requirements

Status: Proposed
Tracker: none. Branch to be chosen when started. Size M.

## Why

v060 shipped the trust layer in four slices (0.6.0 to 0.9.0). Its deep reviews left advisories that were not blockers
and were filed as follow-ups instead of being fixed under the fix-round cap:

- slice 3: `docs/reviews/2026-11-23-slice3-deep-review.md` (advisories 6, 7, 9, 10) and
  `docs/reviews/2026-11-23-slice3-confirmation-review.md` (C1 to C3);
- slice 4: `docs/reviews/2026-11-24-slice4-deep-review.md` (advisories 5, 7, 9) and
  `docs/reviews/2026-11-24-slice4-confirmation-review.md` (C3, C4).

Each one is either a way for evidence to read wrong or a gap in the platform recipe for Human `none`. Since 0.9.0,
anything that flips an evidence verdict to `eligible` can end in a merge with no human, so they matter more than when
they were filed. This feature collects them; v060 is closed.

## Requirements

### [REQ-V061-01] Evidence reads only what it should

- `tiers.py --evidence` SHALL read its thresholds from the profile at the `merged_ref` tip and print that commit
  (v060 19a).
- `section()` SHALL skip fenced code and HTML comments for the Tiers, Guardrails and Evidence sections (v060 19b).
- The docs SHALL say evidence assumes squash or merge commits; a rebase merge counts each commit (v060 19c).
- A tier row whose name or globs changed inside the window SHALL be flagged, and a renamed tier's commits counted
  (v060 19d).
- The window SHALL extend down to any commit that a revert or `Fixes:` at or above the cut names (v060 19e).
- A commit with an unparseable date SHALL be refused with exit 2 and its sha, not a traceback (v060 19f).
- Every git call in `tiers.py` SHALL set `GIT_NO_REPLACE_OBJECTS=1` (v060 19g).

### [REQ-V061-02] Declarations read strictly

- Who writes `Human-Findings:` on an auto-merge SHALL be decided, so a `none` tier neither switches itself off nor
  carries an agent-written `0` (v060 23a).
- Model families SHALL read `_`-joined ids and bare model names; a repeated `implementer:` or `reviewer:` line SHALL be
  not ready (v060 23b).
- An undecodable profile SHALL give a readable `not UTF-8` reason (v060 23c).

### [REQ-V061-03] The `none` recipe holds on the platform

- The approver identity SHALL be out of reach of the PR's own jobs on GitHub and GitLab (v060 23d).
- The job SHALL approve and merge the checked sha only, one job per PR at a time (v060 23e).

## Out of scope

- Anything v060 left out of scope (an orchestrator, a merge bot, classifying by content).
