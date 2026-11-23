# Re-review: specter 0.8.0, slice 3 fix, `0176d0f..983d8da`

Deep tier, security first. HEAD = `983d8da` on `feat/0.8.0`. Line numbers are at HEAD.
First review: `docs/reviews/2026-11-23-slice3-deep-review.md` (at `0176d0f`).
Scratch: `/private/tmp/claude-502/-Users-nikolaos-atsaros-Developer-projects-specter/39b113e0-f733-4594-98f2-dfa5f84bbd4e/scratchpad/r2/`
(`head/` and `old/` = `git archive` of `983d8da` and `0176d0f`; `fx/` = copies of the round-1 fixtures `probe/b1`…`a4s`
with the HEAD `kit/scripts` swapped in; `p1.sh`…`p10.sh` = new probes, built with `probe/lib.sh`, repos in `p/`;
`wt/` = `git worktree add --detach 983d8da` for the gates, removed afterwards). No tracked file was changed; this file is
the only new one.

Gates at HEAD (in `wt/`): G1 exit 0. G2 exit 0, `0 FAIL across 2 feature(s)`, `0 FAIL of 7 citation(s)`.
G3 `selftest: OK`, exit 0 (no `FAIL` line). `git status --short` in `wt/` was empty afterwards. G4 exit 0, `0 FAIL across 7 feature(s)` (one WARN, `REQ-D-01`, as in round 1), `0 FAIL of 72 citation(s)`.

Deferred and not re-raised: advisories 6, 9, 10 and the fenced-section part of 7 (tasks 19a-19d).

## 1. Blockers from round 1

| # | Status | Evidence at HEAD (same fixture as round 1) |
|---|---|---|
| 1 merge-commit reverts and `Fixes:` invisible | CLOSED | `fx/b1` (5 `--no-ff` PRs, `git revert -m 1` on a branch, `Fixes: 2e23498` on a branch): `- routine: breach (reverted 14.3% > 10%) — merged 7, reverted 1 (14.3%), escaped 1 (14.3%)`. Round 1: `eligible — merged 7, reverted 0, escaped 0`. Octopus (`p3`, 4 parents, revert of leg 3 and `Fixes:` of leg 2 on a merged branch): `reverted 1 (9.1%), escaped 1 (9.1%)`, both on the octopus. Selftest t13e1/t13e2 cover it |
| 2 missing trailer counted as "no findings" | CLOSED | `fx/b2` (2 of 20 merges trailered `Human-Findings: 1`): `- domain: hold (Human-Findings on 2 of 20 merges) — merged 20, … human-caught 2 (100.0%)`. Round 1: `eligible … human-caught 2 (10.0%)`. Selftest t13e3 |
| 3 first strict match only | CLOSED | `fx/b3` (note after the number), `fx/b3b` (`0` above `3`), `fx/b3c` (CRLF): each `- domain: breach (human-caught 100.0% > 10%) — merged 10, … human-caught 10 (100.0%)`. Round 1: `human-caught 0`. `findings()` direct: `007`, `+1`, `-0`, a 5000-digit string, empty, blanks, `0 0`, `0.0`, `٣`, `０` all `(True, True)` (caught); `0`, `00`, `000`, `0\t` `(True, False)`; `Human-Findings : 3` `(False, False)` (no data, so it holds). No `int()` on the value, so no digit-limit error. Selftest t13e4 |
| 4 `--since` stops the walk | CLOSED for the reported trigger, residual below as N1 | `fx/b4` (2 reverts in 5, then one commit dated 2020, then 6 clean): `- history: main at 3307f85, first-parent, 14 commit(s) in the longest window`, `- routine: breach (reverted 15.4% > 10%) — merged 13, reverted 2`. Round 1: `6 commit(s)`, `eligible`. `--since` is gone (`tiers.py:388`). But a backdated commit is still dropped by date, with its own revert: see N1 |
| 5 SHA-256 shas | CLOSED | `fx/a4` (`--object-format=sha256`): `- routine: breach (reverted 25.0% > 10%) — merged 4, reverted 1`, same as the SHA-1 twin `fx/a4s`. Round 1: `eligible … reverted 0`. `{7,64}` at `tiers.py:418`. Selftest t13e6 |

What still holds from round 1, re-checked at HEAD: no writes (`evidence()` opens nothing for writing, no `__pycache__`
in any fixture); every subprocess is a list argv, and `parent..sha` comes from `%P`/`%H`. NUL forgery is still out of
reach in the change-set log too. In `p7`, a branch commit written with `hash-object --literally` whose message holds NULs and forged records sits in the
same merge as a real revert. `git log -z F^1..F` cuts that body at the first NUL, and the result is
`breach (reverted 14.3% > 10%)`. Change sets are disjoint (a commit in `F^1..F` is reachable from every later
`F'^1`), so no commit is counted twice. A huge change set can only add matches, which is stricter. In `p4`, a 20000-commit
unrelated history is merged with `--allow-unrelated-histories` and a later revert names `orphan~100`. Result:
`critical: breach (reverted 50.0% > 10%)`, correct, 5.4 s. A short `Fixes:`/revert prefix that matches commits in several
change sets counts each of them (`any(h.startswith(x) …)` per counted commit), which is stricter too. The root commit and a shallow boundary have empty `%P`, so no change-set log runs and the commit is unprofiled.
Guardrails: `TBD`, `tbd`, `N/A`, `-` are undeclared (`no Enforced by`). Tomorrow's date gives `Verified is in the future`, today and
yesterday are declared, and `２０２６-01-01` is `not a YYYY-MM-DD date`. `date.today()` is local time, so a row dated
"today" in a zone ahead of the runner reads as future for a few hours. That fails closed (none → spot).
ASCII digits: no `\d` is left in `tiers.py`. Window, Min, caps, dates and Human-Findings all use `[0-9]`. The sha
classes `[0-9a-f]` under `re.I` match no non-ASCII character.

Run time, `p8`: 201 first-parent commits (100 `--no-ff` merges of one-commit branches, 100 linear commits), 90-day
window: **66.6 s** at HEAD, 46.8 s at `0176d0f` on the same repo. Each git spawn costs about 60 ms on this machine.
Per commit that is `classify` (diff, `rev-parse --show-toplevel`, `--show-prefix`, merge-base, show) plus the new
change-set log. Of 66.6 s, 14.1 s is the change-set logs and 21.1 s the two `rev-parse` calls, which give the same answer every time (A4).

## 2. New findings

| # | Severity | Location | Evidence | Trigger | Consequence | Fix |
|---|---|---|---|---|---|---|
| N1 | blocker | `kit/scripts/tiers.py:403`, `:428`; design `:357` ("inside the tier's window") | `if int(ct) >= now - longest * 86400:` decides who is classified, and `mine = [… if e[1] == name and e[0] >= now - win * 86400]` decides who is counted, both by the commit's own date. A backdated commit is never counted, so a revert of it hits nothing. `p1.sh`: 5 clean docs commits, then twice an agent commit with `GIT_COMMITTER_DATE=2020-01-01` and a normally dated `git revert` of it. 9 commits, 2 reverted (22%). HEAD: `- routine: eligible — merged 7, reverted 0 (0.0%)`. `0176d0f` on the same repo: `hold (merged 1 < min 5)`. So the fix turned a hold into eligible | The same trigger round 1 accepted for blocker 4: a fast-forward or rebase merge that keeps the author's committer date (GitLab fast-forward, `merge --ff-only` and push), a wrong clock, or an agent that sets `GIT_COMMITTER_DATE` on its own commits | An agent that backdates its commits takes them out of the evidence, and every revert or `Fixes:` of them out with them. A tier that breaches prints `eligible`. The commits an agent can backdate are its own, which are the ones that get reverted | Count by position, as the comment at `:397` already says: per tier, `cut = max(i for i, r in enumerate(recs) if now - win*86400 <= ct <= now)`. A commit is in that tier's window when its index is `<= cut`, whatever its own date. Classify every commit at index `<= last`. Leave future dates out of `cut`/`last` (that also closes A1). Selftest next to t13e5/t13e7: a backdated commit, then its revert, expects `breach`. Amend design `:357` to "at or above the oldest first-parent commit dated inside the window" |
| A1 | advisory | `kit/scripts/tiers.py:399`, `:403`, `:428` | `>= now - …` has no upper bound. `p2.sh`: a commit dated 2099 below 30 commits dated 2025, then one current commit, with a 30-day window: `routine: eligible — merged 2`. The 2099 commit is counted, and it will be in every window forever. Round 1's `--since` walk stopped at the 2025 commits and never reached it; the whole-chain walk does | A wrong clock, or a forward-dated commit, anywhere in history | The count is inflated forever, which dilutes the rates. `last` lands on that commit, so a change-set log and a classify run for every commit above it | Ignore `ct > now` (plus a small skew allowance) when computing `last`/`cut`, as in N1's fix |
| A2 | advisory | `kit/scripts/tiers.py:415` | `cs = … if not sub_.returncode and len(t) % 2 == 0 and t else cs`. When the change-set log fails, the merge body alone is used, with no error. `p10.sh`: a branch revert whose parent object is missing (`git log main^1..main` exit 128, `fatal: revision walk setup failed`). Result: `routine: eligible — merged 6, reverted 0`. The main log refuses in the same case (`:391`) | A broken object graph: local corruption, `refs/replace`, or a missing promisor object. A server push cannot deliver one (its connectivity check rejects it), so this is advisory | Data is dropped silently and the result leans toward eligible, against the fail-closed rule | `return refuse("cannot read the change set of " + sha[:7])` instead of falling back |
| A3 | advisory | `kit/scripts/tiers.py:388` (pre-existing, not from the fix) | Nothing checks for a shallow clone. `git clone --depth 6` of `fx/b1`, `Max escaped` set to `-`: `is-shallow-repository=true`, `6 commit(s)`, `routine: eligible — merged 5, reverted 0`. The full clone gives `breach (reverted 14.3% > 10%) — merged 7, reverted 1` | CI runs `--evidence` on a checkout with `fetch-depth: N`. Depth 1 gives a hold, so it fails closed; a depth of a few dozen does not | Reverted commits below the depth are invisible while their reverts still count as clean merges | `git rev-parse --is-shallow-repository` true: refuse, or print `- history: shallow` and hold every tier. One line |
| A4 | advisory | `kit/scripts/tiers.py:277-278`, `:406`, `:412` | `p8`, 201 commits: 66.6 s, against 46.8 s at `0176d0f`. Per run: 200 change-set logs (14.1 s), 200 `rev-parse --show-toplevel` (10.7 s), 200 `--show-prefix` (10.4 s), 200 diffs (12.2 s) | A 90-day window with about 1000 merges: about 5.5 min at this spawn cost | Slow, but the shortcut at `:464` names this. No correctness impact | Resolve top and prefix once in `evidence()` and pass them to `classify`, which cuts about a third. Optionally one `git log -z --format=%H%x00%P%x00%B <head>` over all parents instead of N change-set logs |
| A5 | advisory | `kit/scripts/tiers.py:154`; `CHANGELOG.md:18-19`; `docs/reference.md:158`; `tiers.py:25` | Only `-`, `tbd`, `todo`, `n/a` are treated as empty. In `parse_guardrails`, Enforced by `none`, `—`, `–`, `?`, `TBD.` and `pending` are all `declared`. Round 1's advisory 7 named `none` explicitly (that part was not deferred). The three docs still define declared as "Enforced by names something and Verified is a YYYY-MM-DD date", with no mention of the empty words or the future-date rule the code now applies | A profile row that says nothing enforces it | `none` stays `none`. The profile is a guarded path and its raw diff is reviewed, so this is advisory | Add `none`, `—`, `–`, `?` and the same words with trailing punctuation stripped. State the rule (empty words, future date) in the three docs |
| A6 | advisory | `CHANGELOG.md:43`; `docs/reference.md:165-167`; `tiers.py:460` | CHANGELOG Known limits still says "A `Fixes:` sha is matched against first-parent commits only." That is now false: `:418` matches any commit of the change set, and `sync.md:37` says so. reference.md still says "no `Human-Findings` trailers at all is a hold" and "n > 0"; the code holds below max(Min merged, 1) trailered merges and counts a non-digit value as caught. The text report prints `merged 20, … human-caught 2 (100.0%)` and never shows the denominator of 2 | Anyone reading the docs or the report | A reader computes 2 of 20 = 10% where the code used 2 of 2. The docs describe the old rules | Delete CHANGELOG:43 (or replace it with "`Fixes:` and reverts match any commit a merge brought in"). Align reference.md:165-167 with design `:364`. Print `human-caught 2 of 2 (100.0%)` |
| A7 | advisory | `kit/scripts/tiers.py:361` | `body.replace("\r", "")` joins lines split by a bare CR: `findings("x\rHuman-Findings: 3")` gives `(False, False)`. With an LF `Human-Findings: 0` line elsewhere in the body, it reads 0 | A message with CR-only line ends (rare; git does not convert them) | A finding can read as 0 | `replace("\r", "\n")` |

Docs that match the code: `kit/playbooks/sync.md` § Trailers (7 to 64 hex, any commit the merge brought in, revert
of the merge or any merged commit); `kit/docs/review-loop.md` step 5 (rate over trailered merges, too few is a hold);
design Evidence section `:357-365` (change sets, max over lines, non-digit caught, `hold (Human-Findings on k of n
merges)` under max(Min merged, 1)), except the window wording in N1. The output strings `hold (Human-Findings on
2 of 20 merges)`, `history: … N commit(s) in the longest window` (now in-window commits only) and the `--json` keys
(`with_trailer` is now an int; no other caller reads it) match.

## Verdict

verdict: fix then re-review. Blockers 1 to 5 are closed. N1 is a residual of blocker 4 that the fix exposed: a
backdated commit and its revert both drop out, so a breaching tier prints `eligible` (and `0176d0f` printed `hold`
on the same history). The fix is small (count by position, ignore future dates) and closes A1 too. A2, A3 and A6 are
cheap to fold into the same change.
