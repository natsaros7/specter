# v061 Trust-layer hardening — Requirements

Status: Done 2026-11-25 (release 0.10.0, feat/0.10.0)
Tracker: GitHub milestone "0.10.0 — v061 trust hardening", issues #3 to #18 for tasks 1 to 16 (task n is issue n+2), #24 to #27 for tasks 17 to 20, #28 for task 21, #29 for task 22, #30 for task 23, #32 for task 24. Branch `feat/0.10.0`. Size M.

## Why

v060 shipped the trust layer in four slices (0.6.0 to 0.9.0). Its deep reviews left advisories that were not blockers
and were filed as follow-ups instead of being fixed under the fix-round cap:

- slice 3: `docs/reviews/2026-11-23-slice3-deep-review.md` (advisories 6, 7, 9, 10) and
  `docs/reviews/2026-11-23-slice3-confirmation-review.md` (C1 to C3);
- slice 4: `docs/reviews/2026-11-24-slice4-deep-review.md` (advisories 5, 7, 9),
  `docs/reviews/2026-11-24-slice4-confirmation-review.md` (C3, C4) and `docs/reviews/2026-11-24-slice4-final-review.md`
  (D1 to D4).

Each one is either a way for evidence to read wrong or a gap in the platform recipe for Human `none`. Since 0.9.0,
anything that flips an evidence verdict to `eligible` can end in a merge with no human, so they matter more than when
they were filed. This feature collects them; v060 is closed.

## Requirements

### [REQ-V061-01] Evidence reads only what it should

- `tiers.py --evidence` SHALL read its thresholds from the profile at the `merged_ref` tip and print that commit
  (v060 19a).
- `section()` SHALL skip fenced code and HTML comments for the Tiers, Guardrails and Evidence sections; Knowledge keeps
  reading them, so a link there stays guarded (v060 19b).
- The docs SHALL say evidence assumes squash or merge commits; a rebase merge counts each commit (v060 19c).
- A commit SHALL count for a tier only when its parent's row has the same name and Paths globs as the row read now;
  the others SHALL be counted on a `relabelled` line, so a renamed or widened tier re-earns its evidence (v060 19d).
- The window SHALL extend down to any commit that a revert or `Fixes:` at or above the cut names (v060 19e).
- A commit with an unparseable date SHALL be refused with exit 2 and its sha, not a traceback (v060 19f).
- Every git call in `tiers.py` SHALL set `GIT_NO_REPLACE_OBJECTS=1` (v060 19g).

### [REQ-V061-02] Declarations read strictly

- Nobody SHALL write `Human-Findings:` on an auto-merge. On a commit labelled `none` at its parent, a `0` SHALL count as
  no trailer (a caught value still counts), and a tier whose row says `none` SHALL not hold for missing trailers, so it
  neither switches itself off nor counts an agent-written `0` (v060 23a).
- Model families SHALL read `_`-joined ids and bare model names; a repeated `implementer:` or `reviewer:` line SHALL be
  not ready (v060 23b).
- An undecodable profile SHALL give a readable `not UTF-8` reason (v060 23c).

### [REQ-V061-03] The `none` recipe holds on the platform

- The approver identity SHALL be out of reach of the PR's own jobs on GitHub and GitLab (v060 23d).
- The job SHALL approve and merge the checked sha only, one job per PR at a time (v060 23e).

### [REQ-V061-04] Refs resolve strictly

- A symref SHALL be refused when its target is itself a `.../HEAD` ref; only a symref to a branch or remote-tracking
  branch is a remote's default branch (final review D1).
- A `--range` end SHALL be a full id only at the repository's own hash length (40 in a SHA-1 repo, 64 in SHA-256) (D2).
- A refused `refs/remotes/origin/HEAD` fallback SHALL say why in the label and the lint, not "no merged_ref" (D3).
- v060's evidence requirement (its 2026-11-24 amendment) SHALL state the symref condition, as the code and reference.md do (D4).
- A ref, or a symref's target, SHALL be refused when another listed ref differs from it only by case, or when the
  target is not listed under its exact name: on a case-folding disk a pushed `MAIN` shadows `origin/main` (final
  review, not checked; probed 2026-11-24, see design task 15).

### [REQ-V061-05] Specter runs its own trust layer

- Specter's repo SHALL have its own `.specs/steering/autonomy.md`. The trust-layer scripts (`tiers.py`, `ready.py`,
  `gates.py`, `spec_lint.py`), `install.sh` and `tests/` SHALL be on a tier whose Human is `required`. No tier SHALL be
  `none` until the recipe is verified live.
- G1 to G4 SHALL run locally before every push, from one script that reports each gate's exit code. A GitHub
  Actions run SHALL be added only with Nikos's OK, read-only (`contents: read`) and with no secrets.
- The 0.10.0 release PR SHALL carry `### Gates`, `### Review` and `### Verification` blocks, and
  `ready.py --range <base>...<head>` SHALL say ready on it.

### [REQ-V061-06] The README shows what specter does

- The README SHALL open with the problem and who has it (Story). It SHALL then show how specter works, with a diagram
  and a short Decisions list (How), what it produces, with real screenshots and the 2-minute demo (Output), and what it
  is worth, with measured results and what broke and changed (Worth).
- Every claim in it SHALL be checkable in the repo. It SHALL say plainly that Human `none` is off until verified live.
- A fresh-context reader who sees only the README SHALL be able to say what specter does, for whom, and how it is
  tested.

### [REQ-V061-07] Bypasses are reported privately

- The repo SHALL have a `SECURITY.md` that sends trust-layer bypasses to GitHub private vulnerability reporting, not
  to public issues.
- Before Human `none` is verified live, a review finding that reaches `none` or `auto-merge: yes` without a human
  SHALL be filed as a draft advisory and published only after its fix ships. Findings that are already public stay
  where they are.

### [REQ-V061-08] The selftest is fast and deterministic

- `tests/selftest.sh` SHALL print each section's elapsed time, and SHALL run only the named sections when
  `SELFTEST_ONLY` is set.
- It SHALL give the same result at any time of day and on any locale or time zone. Fixture content SHALL NOT depend
  on the clock's resolution.
- A faster selftest SHALL catch every regression the old one caught: re-breaking each fix landed in v061 SHALL still
  fail it.

### [REQ-V061-09] Human `none` only for small changes the reviewer calls trivial

- Human `none` SHALL also need the change to fit the profile's size cap: at most `Max files` files and `Max lines`
  changed lines (added plus deleted, from `git diff --numstat` on the range). The defaults are 3 and 50. The cap is
  read from the profile at the base.
- Human `none` SHALL also need the test paths to only gain lines: no deleted or changed line in a file matching the
  profile's test globs.
- Human `none` SHALL also need the reviewer's `### Review` block to say `complexity: trivial`. A missing or other
  value is `spot`. The reviewer is still from a different model family, as v060 requires.
- Each condition SHALL only take `none` away and never grant it. A breach prints which one failed, as `human: none →
  spot (<why>)`.

### [REQ-V061-10] Specter learns from its own mistakes

- Specter's repo SHALL keep its own `.specs/steering/lessons.md`. A lesson seen twice SHALL become a check (a gate,
  a lint rule or a test) before it becomes a rule.
- The kit SHALL carry a playbook for parallel agent dispatch: worktree base check, unique temp files, landing a
  batch, one gate run on the tip, stopping leftover runs, and a cap on agents per batch.
- The review loop SHALL end each batch or release with a retro that adds lessons.
- A change to the rules themselves (`AGENTS.md`, kit rules and playbooks, steering) SHALL stay on a Human `required`
  tier: an agent may propose, a human approves.

## Out of scope

- Anything v060 left out of scope (an orchestrator, a merge bot, classifying by content).
