# Re-review: specter 0.9.0 slice 4, fix round 1 (`c46c2b7..a6b4a3c`)

Deep tier, security first. HEAD = `a6b4a3c` on `feat/0.9.0`. The fix under review: `git diff c46c2b7..a6b4a3c`
(tiers.py `earned()` with `base` and `profile_at`, `evidence(text=…)`, the `ref in (None, "HEAD")` fail-closed,
`guarded_globs()` + `rel`, the rounds regex, `ready.py --auto-merge`, step 5 of review-loop.md, selftest 13e).
First review: `docs/reviews/2026-11-24-slice4-deep-review.md`. Line numbers are at HEAD.

Scratch: `/private/tmp/claude-502/-Users-nikolaos-atsaros-Developer-projects-specter/39b113e0-f733-4594-98f2-dfa5f84bbd4e/scratchpad/`.
`rv2/` = `git worktree add --detach` at HEAD, removed after the review. `p4/` = the first review's probe repos,
unchanged, with `p4/lib.sh` repointed to `rv2/kit`. `p5/` = new probes: `p5/lib5.sh` adds `ci <upstream> <dir> <sha>`,
a CI-style checkout (`git init`, then fetch `+refs/heads/*:refs/remotes/origin/*` and `+refs/tags/*:refs/tags/*`, as
`actions/checkout` does with `fetch-depth: 0`; no `origin/HEAD`), detached at the PR head. `upN/` is the platform
repo, `ciN/` its CI checkout. No tracked file was changed.

## Gate results (re-run by me in `rv2/` at HEAD)

| Gate | Result |
|---|---|
| G1 | exit 0 |
| G2 | exit 0: `spec-lint: 0 FAIL across 2 feature(s)`, `spec-lint --cites: 0 FAIL of 7 citation(s)` |
| G3 | exit 0: `selftest: OK` (13e included). `git status --short --ignored` in `rv2/` empty afterwards, no `__pycache__` |
| G4 | exit 0: `spec-lint: 0 FAIL across 7 feature(s)` (one WARN, `REQ-D-01`), `spec-lint --cites: 0 FAIL of 72 citation(s)` |
| G5 | not run: the diff does not touch `examples/acme-shop/` |

## Closure of the first review

| # | Status | Probe at HEAD |
|---|---|---|
| B1 | CLOSED (in the scripts and the step-5 text; see N3, N4 for the recipe) | `p4/r1`, `ready.py --range main...HEAD --auto-merge`: reviewer `gpt-5-1` gives `human: none`, `verdict: ready`, `auto-merge: yes`, exit 0; reviewer `claude-opus-5-5` gives `human: none → spot (same family)`, `auto-merge: no (human spot: same family)`, exit 1, and exit 0 without the flag (unchanged). Staged `--auto-merge`: `auto-merge: no (needs --range base...head)`, exit 1. `p4/b2` (evidence hold): `auto-merge: no (human spot: evidence: hold (merged 1 < min 20))`, exit 1. Step 5 now says every PR needs a human approval and only the `--auto-merge` check may enable auto-merge; reference.md, pipeline.md's Merge row and the template's Guardrails comment say the same |
| B2 | CLOSED | `p4/b2` (` M .specs/steering/autonomy.md`, `-| routine | 90 | 20 |` → `+| routine | 90 | 1 |`, unstaged): `--range main...HEAD` gives `human: none → spot (evidence: hold (merged 1 < min 20))`; `ready.py --auto-merge` exit 1. `p4/b3` (base row `<days> <n> …`, numbers only in the tree): `human: none → spot (evidence: hold (thresholds not set))` |
| B3 | CLOSED for the literal `HEAD` fallback; bypassed by ref shadowing, see N1 | `p4/b1` (merged_ref `{}`, refs only `refs/heads/main`, `refs/heads/pr`): `human: none → spot (evidence: no merged_ref (set merged_ref or origin/HEAD))`; `ready.py --auto-merge`: `auto-merge: no (human spot: evidence: no merged_ref …)`, exit 1. `--evidence` alone still reports `history: HEAD at 68ed8df … routine: eligible — merged 3` (a report, not a label: as documented) |
| A4 | CLOSED | `p4/b5`, `--file docs/autonomy.md --range main...HEAD` over commit `lower min`: `tier: critical (reviewer: deep, human: required)`, `set by: docs/autonomy.md (`docs/autonomy.md`)` |
| A6 | CLOSED for the four reported spellings; residual in N2 | `p4/r1`: `  - rounds: 3`, `- Rounds: 3`, `- rounds : 3`, `* rounds: 3` each give `verdict: not ready`, `not ready: fix-round cap: rounds 3 > 2` |
| A8 | CLOSED | reference.md:143 now reads "Nothing in the kit merges: Human `none` is the platform's auto-merge, enabled only by a required check …" (no "Labels only"). review-loop.md:14-17 has `R -- "complete blockers: round 2" --> P` and `R -- "clean, none" --> A[Required check passes: platform auto-merge]` |
| A5, A7, A9 | filed as tasks 23a–23c; not made worse | A7: the family bar now also gates `--auto-merge`, so a missed family match is an auto-merge (same severity as before: REQ-V060-13 makes these declarations) |

## New findings

| # | Severity | Location | Evidence | Trigger | Consequence | Fix |
|---|---|---|---|---|---|---|
| N1 | blocker | `kit/scripts/spec_lint.py:359`; `kit/scripts/tiers.py:280`, `:296`, `:359`; `docs/reference.md:91` | Refs are resolved by short name through git's DWIM order, where `refs/tags/<name>` wins over `refs/heads/` and `refs/remotes/`, and `earned()` compares the ref *string* to `"HEAD"`, never the commit. `p5/ci1` (merged_ref `null`, the kit default; no `origin/HEAD`, the exact B3 trigger; the agent pushed tag `origin/HEAD` at its PR head): `show-ref` lists `refs/tags/origin/HEAD`; `tiers.py --range origin/main...HEAD` gives `tier: routine (reviewer: standard, human: none)`; `ready.py --range origin/main...HEAD --auto-merge` gives `verdict: ready`, `auto-merge: yes`, exit 0; `--evidence`: `history: origin/HEAD at 14461d2 … routine: eligible — merged 3` (main has 0 merges). `p5/ci2` (merged_ref `"origin/main"`, as reference.md:91 suggests; tag `origin/main` at a side chain of 3 docs commits the agent made): `warning: refname 'origin/main' is ambiguous.`, `human: none`, `auto-merge: yes`, exit 0; control, tag deleted: `human: none → spot (evidence: hold (merged 0 < min 3))`. `p5/ci3` (PR = d1 d2 d3 docs, S `src/s.txt`, D docs; tag `origin/main` → S; real diff `docs/D docs/d1 docs/d2 docs/d3 src/s.txt`): `files: 1 (routine 1)`, `set by: docs/D`, `human: none`, `auto-merge: yes`, exit 0; control `--range refs/remotes/origin/main...HEAD`: `tier: domain (… human: spot)`. `p5/oh` (no tag; `refs/remotes/origin/HEAD` → `origin/pr`): `human: none` | An agent with push access pushes a tag (`origin/HEAD`, `origin/main`, or the merged_ref name) to the platform repo, and the binding check's checkout fetches tags. `actions/checkout` with `fetch-depth: 0` does, and the evidence needs full history (a shallow clone is a hold), so that setting is the one a `none` repo runs. No Guardrails row covers tags (“Agents cannot edit merged history” names history protection). In the shared local checkout of step 3, a local branch named `origin/main` shadows the remote the same way | The fix for B3 is bypassed in B3's own environment: the change, or history the agent fabricated, earns `eligible`, so `ready.py --auto-merge` exits 0 and the platform merges with no human. When the range is passed by name (`origin/main...HEAD`), the same tag also moves the label's base and hides files from it, so a `spot` path (`src/*`) merges as `routine`. Breaks REQ-V060-08 (count first-parent commits *on merged_ref*), -09 (`none` only when eligible) and -05 (the change takes its strictest file). The only trace is a git warning on stderr, and only when a real ref of the same name exists | Resolve every ref the label reads to a full refname and refuse tags: in `spec_lint.merged_ref` (or a tiers-only wrapper) take `git rev-parse --symbolic-full-name`, accept only `refs/heads/*` and `refs/remotes/*`, and spell the fallback `refs/remotes/origin/HEAD`. In `earned()`, compare commits, not names: refuse when the evidence head contains a commit of the change (`git rev-list --count <b> ^<base> ^<evhead>` differs from `git rev-list --count <b> ^<base>`). In `classify(--range)` refuse an end that resolves through `refs/tags/` or that git reports as ambiguous. In step 5 and reference.md, have the binding check pass `--range <base sha>...<head sha>`, and add tag creation to the Guardrails row on history. Selftest: a tag `origin/HEAD` and a tag `origin/main` each give `spot` and `auto-merge: no` |
| N2 | advisory | `kit/scripts/ready.py:189`, `:341` | Under `--auto-merge`, warnings do not block. `p4/r1`: `- **rounds**: 3`, `1. rounds: 3` and `` - `rounds: 3` `` each give `verdict: ready`, `warning: review has no `rounds: <n>` line`, `auto-merge: yes`; with no rounds line at all, the same | A rounds line in another Markdown form, or none | The fix-round cap (REQ-V060-15) is a warning that nobody reads on the `none` path, so it is not checked there. The lead declares rounds anyway (REQ-V060-15 makes the missing line a WARN), so this is advisory | Under `--auto-merge`, treat every warning as `auto-merge: no (<warning>)`: no human is there to read it. That also covers an unknown Gates label and a reviewer below the label's tier |
| N3 | advisory | `kit/docs/review-loop.md:56-65` | "a required check that the platform runs … A failing check leaves the PR for a human approval"; "It runs again in the merge queue". `p5/q` (main moved after the PR branched; queue branch `gh-readonly-queue/main/pr-1` = merge of main and pr): at the PR, `auto-merge: yes`, exit 0; in the queue (`--range main...HEAD`, HEAD = the merge-group commit), `not ready: block commit 3b8e9e5 is not the head 1d0e442`, `not ready: review rules f53bc03 is not the base aa839f0`, `auto-merge: no (verdict not ready)`, exit 1 | An operator sets the recipe up as written on GitHub or GitLab | Fails safe, but does not work as written. (a) In GitHub and GitLab a failing *required* check blocks the merge even after an approval, so if `ready.py --auto-merge` is required, no `spot` or `required` PR can merge; if it is not required, it gates nothing by itself. (b) A passing check does not waive a required approving review: GitHub auto-merge waits for it, GitLab merge-when-pipeline-succeeds waits for approval rules, so "enable auto-merge" alone never merges a `none` PR. (c) In the queue the head is the merge-group commit and the base has moved, so the check fails for every PR. An operator who finds `none` never merging will improvise (drop the approval rule, give the bot admin bypass), which reopens B1 | Name the mechanism: a non-required job runs the check from a trusted worktree of the base and, on exit 0 only, approves with a non-agent identity (GitHub App or `GITHUB_TOKEN` with PR approval allowed; GitLab bot user) and enables auto-merge. In the merge queue, re-run with `--range <queue base>...<PR head>` against the PR text, or run only `tiers.py --range` there (the evidence can move), and say which |
| N4 | advisory | `kit/templates/steering/autonomy.md:35`; `examples/acme-shop/.specs/steering/autonomy.md:38`, `:15` | Template row: "A human must approve a change to a `required` tier's paths \| <CODEOWNERS …>". acme: "Ruleset `protect-main` requires code-owner review … `critical` globs". No row says every PR needs an approval or that only the `--auto-merge` check may enable auto-merge. acme:15 still says "Until auto-merge is decided, `none` behaves as `spot`" | A repository declares every Guardrails row as the template and acme show | `none` is granted (`guardrails: N declared`) on a platform set up the way B1 described: approval only on CODEOWNERS paths. The step-5 text is right, but the dated declarations that gate `none` do not ask for it. acme's prose is stale for 0.9.0 | Change row 3 to "Every PR needs a human approval; only the `ready.py --auto-merge` check (run from the base) approves or enables auto-merge" (or add that row), and update acme's row and line 15. Adding a row makes every existing profile undeclared, so `none` turns off until the human re-dates it: that is the safe direction; note it in the CHANGELOG |

## What I checked and found clean

- **Base thresholds.** `earned()` reads `profile_at(root, base, rel)`, the same `base` and `rel` that `classify()` used
  (`ready.py:315` passes `change["base"]`), and `evidence(text=…)` parses Tiers and Evidence from that text only. The
  tier name comes from the base Tiers table, so it is always in the report. A missing profile at the base gives
  `evidence: no profile at the base`, but `classify` has already set `why` and `earned()` is not reached.
- **Guarded `rel`.** `guarded_globs()` adds `rel`; the `prefix + g` pass covers it when `.specs/` sits in a subfolder.
  `ready.py` has no `--file`: for `docs/autonomy.md` it reads the default path, finds no profile and says `required`,
  so the two scripts no longer disagree towards `none`.
- **`--auto-merge`.** Exit 1 without `--range` (`auto-merge: no (needs --range base...head)`), for `not ready`, and for
  any human other than `none`. Exit 2 paths (bad argument, unreadable input, no Gates table) return before the flag
  is read, so they are never 0. `--json` has `auto_merge` and keeps the same exit code. Without the flag the exit is
  unchanged.
- **Rounds regex.** `rounds\b` then a `fullmatch` on `rounds\s*:(.*)`: `- rounds; 1`, `- rounds 3`, `- rounds: 3 rounds`
  and a zero-width space before the colon are `not ready`; `-rounds: 3` and an ideographic space after the colon read 3
  (not ready). `rounds_count:` is ignored (`\b`). The value regex stays ASCII `[0-9]{1,6}`. Only non-`-*+` forms
  escape (N2).
- **Committed threshold edit.** selftest 13e: committing the lowered bar gives `human: required` (guarded).
- **`merged_ref` in spec-kit.json.** `committed_ref()` reads it at HEAD; an edit by the PR is a guarded path in the
  range diff (`required`). Only the resolution of the name is open (N1).
- **Docs.** CHANGELOG, reference.md, pipeline.md's Merge row and the template's Guardrails comment agree with step 5
  and with the code (`auto_merge`, `auto-merge: no (<why>)`, the base read, `spot` with no merged_ref).

## What I did not check

- Live GitHub or GitLab behaviour. N3 (b) and (c) are read from the platforms' documented rules and reproduced only as
  far as `ready.py` goes (the queue-commit probe). Whether a GitLab runner's default refspecs fetch tags (N1's trigger
  there) is unverified; on GitHub, `actions/checkout` with `fetch-depth: 0` fetches tags.
- A5, A7, A9 (tasks 23a–23c) beyond "not made worse"; the earlier known advisories 19b–19g.
- G5 (`tests/acme-build.sh`): the diff does not touch `examples/acme-shop/`.
- `docs/overview/` (excluded from scope).

## Verdict

fix then re-review

N1 is a blocker: one pushed tag gives `ready.py --auto-merge` exit 0 for a change that earned nothing, or for a
`spot` change. N2–N4 are advisories; N3 and N4 are cheap and touch the same recipe text, so fix them in the same round.
