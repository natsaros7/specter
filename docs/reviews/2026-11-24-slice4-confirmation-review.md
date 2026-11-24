# Confirmation review: specter 0.9.0 slice 4, fix round 2 (`a6b4a3c..06eb9c5`)

Deep tier, security first. HEAD = `06eb9c5` on `feat/0.9.0`. The fix under review: `git diff a6b4a3c..06eb9c5`
(`spec_lint.branch_ref`, `merged_ref` returning `(ref, why)` and its callers, `tiers.end_commit`, `earned(..., base,
head)` with the contains-the-change check, `no_merge or warnings`, step 5 of review-loop.md, the Guardrails rows, the
2026-11-24 amendments, CHANGELOG, selftest 13e N1/N2). Earlier rounds: `2026-11-24-slice4-deep-review.md` (B1–B3, A4–A9)
and `2026-11-24-slice4-re-review.md` (N1–N4). Line numbers are at HEAD.

Scratch: `/private/tmp/claude-502/-Users-nikolaos-atsaros-Developer-projects-specter/39b113e0-f733-4594-98f2-dfa5f84bbd4e/scratchpad/`.
`rv3/` = `git worktree add --detach` at HEAD, removed after the review. `p4/` and `p5/` = the earlier probe repos, with
`p4/lib.sh` repointed to `rv3/kit` (`p5/ci2` had its tag re-fetched from `p5/up2`). `p6/` = new probe: `up` (working
repo), `srv.git` (a bare git server, receive-pack of git 2.54), `ci1` (the `p5/lib5.sh` CI-style checkout: `git init`,
fetch `+refs/heads/*:refs/remotes/origin/*` and tags, detached at the PR head). `p7/` = `branch_ref`/`end_commit` edge
cases on this Mac (APFS, case-insensitive). No tracked file was changed; this file is the only new one in the main tree.

## Gate results (re-run by me in `rv3/` at HEAD)

| Gate | Result |
|---|---|
| G1 | exit 0 |
| G2 | exit 0: `spec-lint: 0 FAIL across 2 feature(s)`, `spec-lint --cites: 0 FAIL of 7 citation(s)` |
| G3 | exit 0: `selftest: OK` (13e N1/N2 rows included); `git status --short --ignored` in `rv3/` empty afterwards. A first run exited 1 (`FAIL: 11e: a kit script left a __pycache__ in the installed kit`). The cause was my own `p7` probe, which imported `rv3/kit/scripts` before the run. I removed that cache and re-ran on a clean tree; it is not a finding |
| G4 | exit 0: `spec-lint: 0 FAIL across 7 feature(s)` (one WARN, `REQ-D-01`), `spec-lint --cites: 0 FAIL of 72 citation(s)` |
| G5 | not run: the diff does not touch `examples/acme-shop/` outside `.specs/` |

## Closure

| # | Status | Probe at HEAD |
|---|---|---|
| N1 | CLOSED for tags and the PR branch as `origin/HEAD`; the fallback still takes a plain ref, see C1 | `p5/ci1` (tag `origin/HEAD` at the PR head, merged_ref `null`): `human: none → spot (evidence: no merged_ref (set merged_ref or refs/remotes/origin/HEAD))`, `ready.py --range <sha>...<sha> --auto-merge` `auto-merge: no (…)`, exit 1 (also with `origin/main...HEAD`). `p5/ci2` (tag `origin/main` on the agent's side chain, merged_ref `"origin/main"`): range by sha gives `human: none → spot (evidence: merged_ref origin/main is ambiguous (refs/tags/origin/main, refs/remotes/origin/main))`, `--auto-merge` exit 1; `--range origin/main...HEAD` gives `tiers: --range end origin/main is ambiguous (…)`, exit 2 in both scripts; `--evidence` exit 2. `p5/ci3` (tag `origin/main` on `S`, inside the PR): by name, exit 2; by sha, `tier: domain (… human: spot)`, `files: 5 (routine 4, domain 1)` (the hidden `src/s.txt` is back). `p5/oh` (`refs/remotes/origin/HEAD` → the PR branch): `human: none → spot (evidence: refs/remotes/origin/HEAD contains the change)`, `--auto-merge` exit 1 |
| N2 | CLOSED | `p4/r1` with `- **rounds**: 3`, `1. rounds: 3`, `` - `rounds: 3` `` and no rounds line: each `verdict: ready`, `warning: review has no `rounds: <n>` line …`, `auto-merge: no (review has no `rounds: <n>` line …)`, exit 1 |
| N3 | CLOSED in the text (no live platform run); new advisories on the recipe in C3, C4 | Step 5 now has a non-required job that approves with a non-agent identity on exit 0 only, a merge queue that re-runs only the Gates, and a `shortcut:` comment naming the stale-label limit (a decision, not a finding). REQ-V060-16 amended to match. `p5/q` not re-run: `ready.py` is no longer meant to run on the queue commit |
| N4 | CLOSED in the template; acme half-done, see C5 | Template row 3 now requires an approval on every PR, dropped on a new commit, and only the job's identity for `none`; acme row 3 matches and line 15 is current. acme row 6 was not updated (C5) |
| B1 | still CLOSED | `p4/r1`: reviewer `gpt-5-1` gives `human: none`, `verdict: ready`, `auto-merge: yes`, exit 0; reviewer `claude-opus-5-5` gives `human: none → spot (same family)`, `auto-merge: no (human spot: same family)`, exit 1 (exit 0 without the flag). Staged: `auto-merge: no (needs --range base...head)`, exit 1 |
| B2 | still CLOSED | `p4/b2` (unstaged `Min merged 20 → 1`): `human: none → spot (evidence: hold (merged 1 < min 20))`, `--auto-merge` exit 1. `p4/b3` (placeholders at the base, numbers only in the tree): `human: none → spot (evidence: hold (thresholds not set))` |
| B3 | still CLOSED | `p4/b1` (merged_ref `{}`, no `origin/HEAD`): `human: none → spot (evidence: no merged_ref (set merged_ref or refs/remotes/origin/HEAD))`, `--auto-merge` exit 1. Control `p4/b1m`: `evidence: hold (merged 0 < min 3)`. `p4/b2c` staged: `tier: critical …`, `base: HEAD (no merge base: last tier)`. A4 `p4/b5` (`--file docs/autonomy.md`): `tier: critical …`, `set by: docs/autonomy.md`. `p4/b4`: `set by: .specs/steering/autonomy.md` |

## New findings

| # | Severity | Location | Evidence | Trigger | Consequence | Fix |
|---|---|---|---|---|---|---|
| C1 | blocker (on a git server that accepts the ref name; GitHub and GitLab unverified) | `kit/scripts/spec_lint.py:381`, `:356-370`; `.specs/features/v060-staged-autonomy/requirements.md:169` | The fallback asks `branch_ref` for `refs/remotes/origin/HEAD` and accepts it whether or not it is a symref. A fetch with `+refs/heads/*:refs/remotes/origin/*` maps a branch named `HEAD` onto exactly that name. `p6`: the agent pushes 3 docs commits off `main` as `fake:refs/heads/HEAD` (`* [new branch] fake -> HEAD`, accepted by git 2.54 receive-pack). In `p6/ci1`, `show-ref`: `d3e0a04 refs/remotes/origin/HEAD`; `git symbolic-ref refs/remotes/origin/HEAD`: `fatal: ref refs/remotes/origin/HEAD is not a symbolic ref`. merged_ref `null` (the kit default), PR = one docs commit: `tiers.py --range <main sha>...<head sha>` gives `tier: routine (reviewer: standard, human: none)`; `--evidence`: `history: refs/remotes/origin/HEAD at d3e0a04 …`, `routine: eligible — merged 3`; `ready.py --range <sha>...<sha> --auto-merge`: `verdict: ready`, `auto-merge: yes`, exit 0. Control, that ref deleted: `auto-merge: no (human spot: evidence: no merged_ref (…))` | merged_ref left at `null` (step 5 item 2 and reference.md:91 say to set it in CI, but nothing enforces that), and the platform accepts a pushed `refs/heads/HEAD`. Plain git does: since 2017 git refuses only `git branch HEAD`, not a push. Some GitLab instances reject it with a pre-receive hook; I could not confirm GitHub either way. The Guardrails rows bar tags, not branch names, and an agent must be able to create branches | This is the N1 bypass again, through a branch instead of a tag. The side chain holds no commit of the change, so the contains-the-change check passes. Fabricated history earns `eligible`, and `ready.py --auto-merge` exits 0, so the job approves and the platform merges with no human. This breaks REQ-V060-08 (it counts commits that are not merged), -09 and the 2026-11-24 amendment's intent ("its fallback SHALL resolve to exactly one branch or remote-tracking ref": a plain ref passes the letter) | Accept the fallback only as a symref: `git symbolic-ref -q refs/remotes/origin/HEAD`, then `branch_ref` on its target (refuse when it is not a symref). The same rule applies to the `refs/remotes/<name>/HEAD` candidate in `branch_ref`: a hit ending in `/HEAD` must have a non-empty `%(symref)`. Selftest: a pushed branch `HEAD` with merged_ref `null` gives `spot` and `auto-merge: no`. Optionally amend the requirement: "the fallback SHALL be the symref `refs/remotes/origin/HEAD`" |
| C2 | advisory | `kit/scripts/tiers.py:299-301` | A short hex that no ref in `branch_ref`'s exact list names goes to `rev-parse <hex>^{commit}`, which resolves refs before object ids. On a case-insensitive filesystem the loose-ref lookup also folds case. `p7/r` (APFS): tag `C282714` on commit `A`, the head is `c282714…`. `branch_ref('c282714')` gives `(None, None)`, and `end_commit('c282714')` gives `c816d7a…` (= `A`, the tag's commit), not the head; `git rev-parse c282714` prints `warning: refname 'c282714' is ambiguous.`, then `c816d7a…`. After `pack-refs` it gives the right commit. A branch named like the short hex is taken as that branch, which the docstring's "a short sha that no ref is named" does not say | A short sha passed as a range end on a macOS or Windows runner, plus a pushed upper-case hex tag. The docs say to pass full shas, and the new row 6 bars agents from creating tags | The range base or head moves to a commit the agent chose, as in N1's `ci3`: files are hidden, or `ready.py` checks the wrong commit | Accept only full object ids (`[0-9a-f]{40}` / `{64}`), `HEAD`, or a ref `branch_ref` names. Drop the `{4,63}` rule: the binding check already passes full shas |
| C3 | advisory (recipe text; no live platform run) | `kit/docs/review-loop.md:76-82` | GitHub line: "… `gh pr review --approve` and `gh pr merge --auto` with a GitHub App token (or `GITHUB_TOKEN` with "Allow GitHub Actions to create and approve pull requests" on …)". That setting is repo-wide, and every workflow's `GITHUB_TOKEN` approves as the same `github-actions[bot]`. A `pull_request` run from a same-repo branch gets a write token when the workflow asks for it, or when the repo default is read and write. `actions/checkout` keeps that token in `.git/config` by default, so the Gates job, which runs the agent's code (`./mvnw verify`), can read it. GitLab line: the bot's project access token must sit in a CI/CD variable. If the variable is unprotected, every job of the MR pipeline can read it, the Gates jobs included. If it is protected, an MR pipeline from an unprotected source branch does not get it, so the job cannot approve | A repository follows the GitHub `GITHUB_TOKEN` option or the GitLab line as written | The "non-agent identity" can be reached from the agent's own code. A test that calls the reviews API approves the PR, and `gh pr merge --auto` merges it at any tier. No Guardrails row covers this: row 4 is about the agent's own token, and row 7 is about agent jobs. On GitLab the safe setting does not work at all | Say that the approver's credential is readable only by that job. On GitHub: a GitHub App key in an environment whose deployment branches allow only the default branch (a `pull_request_target` run qualifies), and every workflow that runs PR code with `permissions: contents: read` and `persist-credentials: false`. Drop the `GITHUB_TOKEN` alternative, or require every other workflow to be read-only. On GitLab: run the job in a pipeline of a trusted project (a pipeline trigger or an MR webhook) that holds the token, not in the MR pipeline. Add both to template row 3's `Enforced by` hint |
| C4 | advisory (recipe text; no live platform run) | `kit/docs/review-loop.md:64-67`, `:76-78`, `:81-82` | The job runs `ready.py` on `<head sha>` from the event, then approves and enables auto-merge on the PR *as it is then*. `gh pr review --approve` and `gh pr merge --auto` without `--match-head-commit` take the current head. "Dismiss stale approvals" acts only at push time | The agent pushes commit Y while the job for X runs (tens of seconds: a base checkout, a fetch, `ready.py`). The job for Y fails, and per item 3 "any other exit does nothing" | X's approval lands on Y after Y's push, so it is never dismissed. Auto-merge is enabled for Y, and Y (say a `src/` or `critical` change) merges once the Gates pass. That breaks REQ-V060-09 by timing alone | Bind both calls to the checked sha. On GitHub: `gh pr merge --auto --match-head-commit <head sha>` and approve through `POST …/pulls/{n}/reviews` with `commit_id=<head sha>`; then re-read the head and dismiss the review if it moved. On GitLab: `POST …/merge_requests/:iid/approve` with `sha=<head sha>` and the merge call with `sha=<head sha>`, which both refuse a moved head. Also run one job per PR at a time (a concurrency group) |
| C5 | advisory | `examples/acme-shop/.specs/steering/autonomy.md:41`; `CHANGELOG.md:40` | Template row 6 now reads "…or create tags or `refs/replace/` refs", and the requirements amendment (`requirements.md:156-157`) says row six SHALL bar them. acme row 6 still reads "Agents cannot edit merged history or review records \| Ruleset `protect-main` (no force push, no deletion) … \| 2026-11-23". CHANGELOG: "acme-shop's rows are re-dated 2026-11-24" (only row 3 was) | Reading the worked example | The example declares the old row 6 and still earns `guardrails: N declared`, which is the drift the CHANGELOG tells upgraders to fix | Update acme row 6 (a tag ruleset, e.g. "Ruleset `protect-tags`: tag creation restricted to the release team"), re-date it, or say in the CHANGELOG that only row 3 was re-dated |
| C6 | advisory | `kit/scripts/spec_lint.py:396` | `merged_commits` takes `merged_ref(...)[0]` and drops `why`: a merged_ref refused as a tag or ambiguous disables the tracker check for that repo without a word. reference.md:91 documents the skip | merged_ref `"origin/develop"` next to a local branch or tag of that name | The lint keeps passing, with the check off. Fails closed for the labels; only the lint loses a check | Print `WARN merged_ref: <why>` once per repo when `why` is set |

## What I checked and found clean

- **`branch_ref` against git's DWIM order.** The candidates are git's `ref_rev_parse_rules` except the bare
  `$GIT_DIR/<name>` rule, which a fetched CI checkout cannot gain. The result is always a full ref name, and
  every caller resolves that name, never the short one, so case-folding and later DWIM cannot move it (`p7`:
  `origin/release/1.0` → `refs/remotes/origin/release/1.0`; `origin` → `refs/remotes/origin/HEAD`; `main` →
  `refs/heads/main`; the same after `pack-refs --all`). A name starting `refs/` is taken as written. Every candidate
  starts with `refs/`, so no name reaches git as an option. Glob characters in a name match no exact candidate. A
  symref to a tag is refused. A broken symref is skipped by `for-each-ref`, which falls back closed. `HEAD` skips
  `branch_ref` (`rev-parse HEAD` takes `$GIT_DIR/HEAD` first, whatever `refs/heads/HEAD` holds).
- **`merged_ref` callers.** `spec_lint.merged_commits` and `spec_report.in_flight` take `[0]`: a refused ref is `None`,
  so the repo is skipped or there are no branches (C6). `tiers.committed_ref` passes `(ref, why)` through. Staged
  `classify` with `why` set takes the last row (`HEAD (merged_ref … is ambiguous …: last tier)`). `earned()` returns
  `evidence: <why>`, and `evidence()` refuses with exit 2. Each refusal is spot, the last tier or exit 2, never `none`.
- **`end_commit`.** 40- and 64-hex ends skip refs (git takes a full object id as an id and only warns), so a branch
  named like a full sha cannot shadow one. Upper-case hex, an expression (`main~1`) or an empty end (`...HEAD`) is
  exit 2. `classify` now gets two shas, so `merge-base` and `diff` can no longer take an option-like name. The
  per-commit `classify(parent...sha)` inside `evidence()` passes full shas, so the stricter ends do not change
  counting (G3 13c/13d).
- **Contains-the-change.** `rev-list --count head ^base` against the same count with `^<evidence head>`: an evidence
  head at or below the base removes nothing (no refusal, fewer merges counted), and a PR branch that merged `main` has
  a base at `main`'s tip, so its merge commit is inside `base..head` and is still not on the evidence head. A failing
  `rev-list` is `None`, which is a refusal. An empty change (head == base) gives `tier: critical` before `earned()` runs.
- **`no_merge or warnings`.** Every warning (unknown Gates row, a blocker with empty fields, same family, reviewer
  below the tier, no rounds line) is now `auto-merge: no (<warning>)`, exit 1. A clean `none` PR (`p4/r1`, gpt
  reviewer) still has no warning and gives `auto-merge: yes`. The text and `--json` agree (`auto_merge: false`).
- **Legitimate setups.** CI with `merged_ref: "refs/remotes/origin/main"`: selftest 13e control and `p5/ci3` by sha
  label correctly. A plain local `main` (`p4/r1`): `none`, `auto-merge: yes`. A real symref `origin/HEAD` → `main`:
  `evidence: hold (merged …)` (selftest control). A CI checkout with merged_ref `"main"` (no local branch), or
  GitLab's detached MR checkout without the target fetched: `evidence: no merged_ref`, so `spot`. That fails closed,
  and step 5 item 2 says to set merged_ref to a ref the checkout has. No path crashes: bad names are exit 2 with a
  message.
- **Docs.** review-loop.md step 5, pipeline.md's Merge row, reference.md (merged_ref row, Pipeline and Human value
  paragraphs), the template's Guardrails comment, the REQ-V060-08/-16 and Guardrails amendments and CHANGELOG
  [Unreleased] agree with the code: full shas, exit 2 for a tag or ambiguous end, `refs/remotes/origin/HEAD`, `contains
  the change`, no warning under `--auto-merge`. Each says nothing in the kit merges. The GitHub and GitLab setting
  names are real ("Require a pull request before merging", "Dismiss stale pull request approvals when new commits are
  pushed", "Allow GitHub Actions to create and approve pull requests", `pull_request_target` running the base's
  definition, "Prevent approval by author", "Remove all approvals when commits are added to the source branch",
  `allow_failure: true`, a CI config file in another project). A `GITHUB_TOKEN` merge does not start workflows. The
  identity and timing gaps are C3 and C4.

## What I did not check

- Live GitHub or GitLab: whether either accepts a pushed `refs/heads/HEAD` (C1's platform condition), and the
  approval and auto-merge behaviour behind C3 and C4. These come from the platforms' documented rules.
- A Windows runner for C2. I reproduced it on APFS only.
- A5, A7, A9 (tasks 23a–23c) and the known advisories 19b–19g beyond "not made worse".
- G5, and `docs/overview/` (out of scope).

## Verdict

fix then re-review

C1 is the one blocker. With merged_ref left at its default, one pushed branch named `HEAD` turns the fallback into
fabricated history and gives `ready.py --auto-merge` exit 0. The fix is one rule (the fallback must be a symref) and
one selftest row. If GitHub and GitLab both reject `refs/heads/HEAD`, C1 drops to advisory for those platforms, but
the kit also runs on plain git servers. C3 and C4 are text-only fixes to the step 5 recipe, and they decide whether
the recipe holds on a real platform. Fix them in the same round. C2, C5 and C6 are small.
