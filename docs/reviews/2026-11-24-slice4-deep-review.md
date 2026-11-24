# Deep review: specter 0.9.0 candidate, slice 4 (the pipeline), `feat/0.8.0..c46c2b7`

Deep tier, security first. HEAD = `c46c2b7` on `feat/0.9.0`. Diff: `git diff feat/0.8.0..HEAD -- . ':!docs/overview'`
(commits a9d4a67, 4aac58d, 9c4d6a2, 77aa7cd, c46c2b7). Line numbers are at HEAD.
Scratch: `/private/tmp/claude-502/-Users-nikolaos-atsaros-Developer-projects-specter/39b113e0-f733-4594-98f2-dfa5f84bbd4e/scratchpad/`
(`rv/` = `git worktree add --detach` at HEAD, removed after the review; `p4/lib.sh` = fixture helpers: a git repo
with Tiers `routine` `docs/*` standard none, `domain` `src/*` spot, `critical` `*/security/*` required, one declared
guardrail, Evidence `| routine | 90 | <min> | 5 | 5 | - |`, and the labels run with the trusted kit from `rv/kit`;
`p4/b1` … `p4/w1` = one repo per probe). No tracked file was changed. The only new file is this one.

Central question: can a change, a PR author, or an agent with write access to the branch obtain `human: none` or
`verdict: ready` when the spec says it must not? Yes, three ways (findings 1 to 3).

## Gate results (re-run by me in `rv/` at HEAD)

| Gate | Result |
|---|---|
| G1 | exit 0 |
| G2 | exit 0: `spec-lint: 0 FAIL across 2 feature(s)`, `spec-lint --cites: 0 FAIL of 7 citation(s)` |
| G3 | exit 0: `selftest: OK` |
| G4 | exit 0: `spec-lint: 0 FAIL across 7 feature(s)` (one WARN), `spec-lint --cites: 0 FAIL of 72 citation(s)` |

`git status --short` in `rv/` was empty afterwards; no fixture or kit copy has a `__pycache__`.

## Findings

| # | Severity | Location | Evidence | Trigger | Consequence | Fix |
|---|---|---|---|---|---|---|
| 1 | blocker | `kit/docs/review-loop.md:54-58`; `kit/scripts/ready.py:300-311,328`; `kit/scripts/tiers.py:362-391` | Step 5, `none`: "Set the platform up once: the Gates as required checks, auto-merge on green, CODEOWNERS for the `required` paths, and a merge queue". Line 58: "For `required` and `spot`, write the PR description … Then check it with the trusted copy", so the `none` path runs neither `ready.py` nor the `--range` label. The two scripts give the same exit code for `none` and `spot`. `p4/r1`, `ready.py --range main...HEAD`: reviewer `gpt-5-1` gives `tier: routine (… human: none)`, `verdict: ready`, `ready exit=0`; reviewer `claude-opus-5-5` gives `human: spot`, `verdict: ready`, `ready exit=0`; `tiers.py` exit 0 in both | A repository sets the platform up as step 5 says | Nothing on the platform reads the label. Every green PR outside the CODEOWNERS paths auto-merges: a `spot` change (`src/*`), a lowest-tier change with evidence on hold, and a change reviewed in its implementer's family. That breaks REQ-V060-09 (`spot` = a human approves; `none` only when eligible) and REQ-V060-13. The only check left is the staged preflight label of step 3, and it is not binding. A label made at review time also goes stale by merge time, because the queue does not re-run it | Name what turns the label into the merge. A required check, run from a trusted worktree of the base, runs `tiers.py --range <base>...<head> --json` and `ready.py --range … --json`. It passes only when both say `human == "none"` and the verdict is `ready`. Only that check (or a bot that runs it) may enable auto-merge, and it re-runs in the merge queue. Every other PR needs a human approval by default (branch protection), not only CODEOWNERS paths. Add the same text to pipeline.md's Merge row and the template's Guardrails comment. An exit code for "not none" (e.g. `ready.py --require-none`) would save each repo a jq line |
| 2 | blocker | `kit/scripts/tiers.py:346-353`, `:406`; `kit/scripts/ready.py:306-308` | `earned()` calls `evidence(root, rel, specs, profile, True)` and `evidence()` reads `profile.read_text()`, the working tree. `classify()` reads Tiers and Guardrails at the base. `p4/b2`: base Min merged 20, one routine merge. Clean tree: `human: none → spot (evidence: hold (merged 1 < min 20))`. An unstaged edit `20 → 1` (`git status`: ` M .specs/steering/autonomy.md`, `A  docs/new.md`) gives staged `tier: routine (… human: none)`, then after the commit `--range main...HEAD` gives `human: none` and `ready.py --range` gives `human: none`, `verdict: ready`, exit 0. `p4/b3`: base Evidence row still `<days> <n> …` (the shipped placeholders): clean `hold (thresholds not set)`; with numbers typed into the working tree only, `human: none` | The label runs in a checkout whose working tree an agent can write. In the documented flow the workers share the lead's checkout and never commit, and step 3 and the binding check both run `tiers.py --specs .specs` there. The edit is never staged, so the guarded-path rule never sees it | `none` (no human) comes from thresholds the change set itself, never committed and never reviewed. This breaks REQ-V060-05 ("the profile SHALL be read as of the change's base, so a change is judged by the rules it started under") and the 2026-11-22 decision that no tier is eligible until the repository sets numbers in a guarded, human-reviewed commit. This is known advisory 19a, made worse: slice 3 rated it advisory because "Labelling avoids exactly this"; slice 4 makes the label depend on it | For the label and `ready.py`, read the Evidence table (and its tier names) from the profile text at the label's base, the same text `classify()` parsed: pass the text into `evidence()`, e.g. `evidence(root, rel, specs, profile, as_json, text=None)` and `earned(..., text)`. Keep 19a (the merged_ref tip) for the `--evidence` report. Selftest: an unstaged threshold edit leaves `spot` |
| 3 | blocker | `kit/scripts/tiers.py:417-421`; `kit/scripts/spec_lint.py:359`; `kit/spec-kit.json:13` | `evidence()` takes `committed_ref()`, and `spec_lint.merged_ref` falls back to `origin/HEAD`, then `HEAD`. In `--range` mode, `HEAD` is the PR head. Staged mode refuses this (`tiers.py:300`, `ref != "HEAD"`); evidence does not. `p4/b1`: `merged_ref` unset (the kit default `null`), no `origin/HEAD`, `main` has zero routine merges, branch `pr` has 3 unmerged docs commits. `tiers.py --range main...HEAD` gives `tier: routine (… human: none)`; `--evidence`: `history: HEAD at 68ed8df …`, `routine: eligible — merged 3`; `ready.py --range` gives `human: none`, `verdict: ready`, exit 0. Control `p4/b1m` with `merged_ref: "main"`: `human: none → spot (evidence: hold (merged 0 < min 3))`. Control `p4/b2c`, staged with no merged_ref: `tier: critical … required`, `base: HEAD (no merge base: last tier)` | `merged_ref` left at its default and no `refs/remotes/origin/HEAD` (a repo with no remote, or a checkout made by `git init` + fetch, as CI checkouts often are). This is the documented binding run (`review-loop.md:67`, `--range <base>...HEAD`) | The change's own commits count as merged history, so the change earns its own evidence. An agent with push access to the branch can reach any Min merged by splitting the change into small lowest-tier commits, with `Human-Findings: 0` lines if Max human-caught is set | In `earned()`, fail closed (`evidence: merged_ref resolves to HEAD, the change itself`) when the resolved ref is `HEAD`, the same rule as staged mode. Optionally also when the label's head commit is an ancestor of the evidence head. Selftest: merged_ref null, no origin/HEAD, `--range` gives `spot` |
| 4 | advisory | `kit/scripts/tiers.py:212-215` | `guarded_globs()` starts from `GUARDED` (`.specs/steering/*`) and never adds `rel`. `p4/b5`, `--file docs/autonomy.md`: a PR that commits `Min merged 20 → 1` in that file gives `set by: docs/autonomy.md (`docs/*`)` and `human: none` | A profile kept outside `.specs/steering/` through `--file` | The profile is not guarded, and with finding 2 the PR's own threshold edit earns its own `none`. `ready.py` has no `--file`, so it reads the default path and says `required`: the two scripts disagree | `out = list(GUARDED) + [rel]` in `guarded_globs()`. The fix for finding 2 removes the `none` part |
| 5 | advisory | `kit/docs/review-loop.md:79-82`; `kit/playbooks/sync.md:38`; `kit/docs/pipeline.md:22` | "At the merge, the human adds `Human-Findings: <n>`"; sync.md: "written at the human check". Under `none` there is no human at the merge, yet pipeline.md's Merge row still says "the merge commit, with `Human-Findings: <n>`" | A `none` merge | Two outcomes, both wrong. Without a trailer, once the trailered human merges leave the window, a tier with Max human-caught set goes to `hold`, so `none` turns itself off. With a squash auto-merge, the commit message comes from the agent-written PR body, and `Human-Findings: 0` there is evidence the agent wrote | Say what a `none` merge carries: no trailer, and the human-caught rate counts only merges with a human check. Or have `findings()` ignore trailers on merges labelled `none`. Note it under sync.md § Trailers |
| 6 | advisory | `kit/scripts/ready.py:142` | `line.startswith("- rounds:")`. `p4/r1`: `  - rounds: 3`, `- Rounds: 3`, `- rounds : 3` and `* rounds: 3` each give `verdict: ready`, `warning: review has no rounds: <n> line`, exit 0. `- rounds: 3` gives `not ready: fix-round cap`, exit 1 | A list item written in another valid Markdown form | Rendered, it shows `rounds: 3`, but `ready.py` reads it as missing (a WARN), so the cap is skipped. The lead declares rounds anyway, so leaving the line out does the same thing | `re.match(r"\s*[-*+]\s*rounds\s*:", line, re.I)`, with the same treatment for the `implementer`, `reviewer` and `rules` lines |
| 7 | advisory | `kit/scripts/ready.py:113-118`, `:137-141` | `p4/r1`: reviewer `claude_opus_5_5` and `opus-5-5` give `human: none` (no family match). Two `- implementer:` lines (`claude-sonnet-5-5`, then `gpt-5`) with reviewer `anthropic.claude-opus`: the last one wins, `human: none`, no warning. Slice 3 had promised "replace with a profile table before slice 4 lets a family bar Human none"; slice 4 rewrote that comment as a deferral | A model id spelled with `_` or without its vendor prefix, or a second `implementer:`/`reviewer:` line | The family bar on `none` (REQ-V060-13) misses. These lines are declarations (REQ-V060-13: specter cannot prove which model ran), so this is advisory | Treat a repeated `implementer:`/`reviewer:` line like a repeated `rounds:` line (not ready). Split the family on `[-_.:@]`. A missing reviewer also prints `human: none` next to `not ready`; print `spot` when the Review block cannot be read |
| 8 | advisory | `docs/reference.md:143`; `kit/docs/review-loop.md:14-15` | reference.md: "Labels only: nothing merges by itself." The diagram: `R -- clean --> C[Human check + commit]` for every clean review, with no `none` branch. It also draws `R -- complete blockers: next round --> W` for every round, while step 4 says round 2 is the planner's | Reading the 0.9.0 docs | The reference still says "labels only", the diagram shows a human after every review, and round 2's blockers go to the worker in the picture but to the planner in the text | Drop "Labels only" at :143. Add a `none` edge (`R -- clean, none --> PM[Platform auto-merge]`). Route round-2 blockers to `P` in the diagram |
| 9 | advisory | `kit/scripts/tiers.py:406-413` | A working-tree profile ending in bytes `\xff\xfe`: `--evidence` exits 2 with `…/autonomy.md:u: t`. The label says `none → spot (evidence: …autonomy.md:u: t)`, exit 0 | An invalid UTF-8 profile | Fails closed, but the message is garbled: `UnicodeDecodeError` is a `ValueError`, and its `args` are indexed as `(lineno, message)` | Catch `UnicodeDecodeError` before `ValueError` and print `not UTF-8`. Finding 2's fix removes the label's read |

## What I checked and found clean

- **Guarded profile.** A PR that commits its own `autonomy.md` edit (thresholds lowered) gives `tier: critical (…
  human: required)`, `set by: .specs/steering/autonomy.md (`.specs/steering/*`)` (`p4/b4`). A profile missing at the
  base, whether the PR adds it or it is only untracked in the tree, gives `tier: human (… required)`, `profile: no
  autonomy profile at <base>`; `earned()` is not reached (`why` set).
- **`none` only on the lowest row.** `parse_tiers` keeps Human non-decreasing, and `classify` downgrades `none` on
  any `idx != 0` row with `reasons: ["not the lowest tier"]` (13c2). Guardrail downgrade runs first.
- **Fails closed.** A refusing evidence run (bad header, no Tiers in the tree, unreadable or non-UTF-8 profile) gives
  `spot`, exit 0. A base tier name that is missing from the working-tree report gives `evidence: hold (no report)`.
  An uncaught exception in `earned()` exits 1 in both scripts (not ready, not a label), never 0. `ready.py` checks
  `change["why"] is None`, so with no profile the label stays `required`.
- **tiers.py and ready.py agree** on `none` vs `spot` for the same mode and default profile (same `classify`, same
  `earned`). `ready.py` adds only the family bar. The one exception is `--file` (finding 4).
- **Family parsing.** Case (`Claude-Opus-5-5`), `vertex_ai/…`, `us.anthropic.…-v1:0`, extra spaces after the colon
  and `reviewer:claude-…` with no space all give `same family`. A missing reviewer or an indented `-  reviewer:` gives
  `not ready: review has no reviewer model id`.
- **`rounds:`.** `visible()` runs before `check_review` (`ready.py:261`). A `- rounds: 1` inside `<!-- -->` or a
  fence, followed by a visible `- rounds: 3`, is `not ready: fix-round cap`. `- rounds: 1 <!-- 3 -->` reads 1. These
  are all not ready: `３` (fullwidth), `9999999`, `-0`, `3 (worker, planner, worker)`, a repeated line (also with
  prose between), and two `### Review` blocks. `0003`, `\t3` and `3\r` read as 3 (not ready). `- rounds:3` reads 3.
- **`demote:`.** `p4/w1` (1 revert in 2 merges): `routine: breach (reverted 50.0% > 5%)`, `  demote:
  .specs/steering/autonomy.md:6 Human none → spot (a human edit; tiers.py changes nothing)`, and line 6 is the routine
  row. `--json` gives `{'file': '.specs/steering/autonomy.md', 'line': 6, 'from': 'none', 'to': 'spot'}`. The selftest
  covers spot → required, `already required`, and null off breach.
- **`--evidence` never writes.** After a breach run plus `--json`, `git status --porcelain --ignored`, the file list
  and the profile `cksum` were identical, with no `__pycache__` in the repo or the kit. `evidence()` opens nothing
  for writing; `earned()` only redirects stdout and stderr into `StringIO`.
- **Docs.** CHANGELOG [Unreleased], model-routing rule 3, generator, next-task, pipeline.md and reference.md § Human
  value match the code: `labels_only: false`, the `- human: none → spot (<why>)` line, `reasons`, `human_why`,
  `review.rounds`, the cap at 2 with the planner as round 2. No doc claims the kit merges: each says "nothing in the
  kit merges" / "never a specter script's". Findings 1, 5 and 8 are the gaps.

## What I did not check

- G5 (`tests/acme-build.sh`): the diff does not touch `examples/acme-shop/` outside `.specs/`.
- Whether a given CI provider's checkout creates `refs/remotes/origin/HEAD` (finding 3's trigger). I reproduced it
  with a repo that has no remote.
- Platform behaviour (GitHub or GitLab auto-merge, merge queue, rulesets). Finding 1 is read from the recipe text.
- The known advisories 19b–19g. Only 19a is made worse (finding 2). None of the other six gets worse in slice 4,
  except that each one that turns a breach or hold into `eligible` now leads to `none`, not only a report line.
- `docs/overview/` (excluded from scope).

## Verdict

fix then re-review
