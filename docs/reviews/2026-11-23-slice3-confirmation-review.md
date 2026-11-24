# Confirmation review: specter 0.8.0, slice 3 fix, `983d8da..6f85946`

Deep tier, security first (review 3). HEAD = `6f85946` on `feat/0.8.0`. Line numbers are at HEAD.
Earlier reviews: `docs/reviews/2026-11-23-slice3-deep-review.md` (at `0176d0f`) and
`docs/reviews/2026-11-23-slice3-re-review.md` (at `983d8da`: blocker N1, advisories A1 to A7).
Scratch: `/private/tmp/claude-502/-Users-nikolaos-atsaros-Developer-projects-specter/39b113e0-f733-4594-98f2-dfa5f84bbd4e/scratchpad/r4/`
(`head/` = `git archive 6f85946`; `p1.sh`…`p14.sh` = probes built with `../probe/lib.sh`, repos in `p/`; round-2
probes are the `r2/` scripts with the HEAD kit swapped in; `p11`…`p14` are new; `e2e/` = the end-to-end install;
`wt/` = `git worktree add --detach 6f85946` for the gates, removed afterwards). No tracked file was changed; this file
is the only new one.

Gates at HEAD (in `wt/`): G1 exit 0. G2 exit 0, `0 FAIL across 2 feature(s)`, `0 FAIL of 7 citation(s)`.
G3 `selftest: OK`, exit 0, no `FAIL` line; `git status --short` in `wt/` empty afterwards. G4 exit 0, `0 FAIL across 7 feature(s)` (one WARN, `REQ-D-01`, as before), `0 FAIL of 72 citation(s)`.

Deferred and not re-raised: round-1 advisories 6, 9, 10 and fenced sections (7); the shortcut "a recently dated commit
deep in history widens the window down to it" (`tiers.py:404-405`, design, CHANGELOG Known limits). One note on it,
not a finding: with future dates kept out of `cut`, a commit dated today + N days is inert now and becomes that
widening anchor N days later, so its trigger can be planted by whoever writes a commit date, not only by a wrong clock.
The effect is still dilution only (more clean merges counted); no revert or `Fixes:` can be hidden by it. The upgrade
trigger in the shortcut ("cap the window by count") still fits.

## 1. Re-review items

| # | Status | Evidence at HEAD |
|---|---|---|
| N1 backdated commit and its revert drop out | CLOSED | `p1.sh` (5 clean, then twice an agent commit dated 2020 and its revert dated now): `- routine: breach (reverted 22.2% > 10%) — merged 9, reverted 2 (22.2%)`. At `983d8da`: `eligible — merged 7, reverted 0`. `tiers.py:406` `cut` takes the deepest index dated in `[now - win, now]`; `:442` counts every commit at or above it. Selftest t13e8. Residual at the tail of the window: see C1 |
| A1 future date sets the window forever | CLOSED | `p2b.sh` (profile dated 2024, a 2099 commit, 30 commits dated 2025, one current): `1 commit(s) in the longest window`, `routine: eligible — merged 1`. At `983d8da`: `merged 2`. (`p2.sh` as written in round 2 now reads `merged 32`, but only because its root profile commit is dated today: that is the deferred shortcut, not A1.) `p13.sh` future-dated tip over old history: `0 commit(s) in the longest window`, `hold (merged 0 < min 1)`. Selftest t13e9 |
| A2 change-set failure falls back to the merge body | CLOSED | `p10.sh` (branch revert whose parent object is missing): `tiers: cannot read the change set of 5b3c1d5`, exit 2. At `983d8da`: `eligible — merged 6, reverted 0`. `tiers.py:424-425`. Selftest t13e10 |
| A3 shallow clone not detected | CLOSED | `git clone --depth 6` of round 1's `fx/b1`: `- history: main at f7e7c9e, first-parent, shallow clone, not read`, `- routine: hold (shallow clone: fetch the full history)`. The full clone: `breach (reverted 14.3% > 10%) — merged 7, reverted 1`. `tiers.py:393` `!= "false"`: a failed `rev-parse` (None) and git < 2.15 (echoes the flag) both read as shallow, so both hold. Selftest t13e11 |
| A4 two `rev-parse` per commit | CLOSED | `where` read once, `tiers.py:411`. `p8.sh` (201 first-parent commits): `real 45.64`, `user 6.61`, `sys 8.36` (66.6 s at `983d8da` in round 2, different load). The change-set log per commit remains and is named in the shortcut at `:478` |
| A5 empty Enforced by words | CLOSED | `parse_guardrails` direct: `none`, `None.`, `—`, `–`, `?`, `TBD.`, `pending`, `PENDING..`, `na`, `n/a.`, `...` all `no Enforced by`. The rule (empty words, trailing `.`, future date) is stated in `CHANGELOG.md:19-20`, `docs/reference.md:158-160` and the docstring `tiers.py:25-27`, and the list matches `EMPTY` (`tiers.py:64`). A deny list stays open (`--`, `N.A.`, `` `none` ``, `nothing`, `unknown`, `ＴＢＤ` are declared); the profile is a guarded path and its raw diff is reviewed, so not re-raised |
| A6 docs and denominator | CLOSED | CHANGELOG Known limits now reads "`Fixes:` and reverts match any commit a merge brought in"; reference.md `:163-172` describes change sets, non-digit values caught, max(Min merged, 1) and shallow hold, matching design `:355-370`. Output prints the denominator: `p8` `human-caught 0 of 100 (0.0%)`, selftest t13e4 `human-caught 5 of 6 (83.3%)` |
| A7 bare CR joins lines | CLOSED | `findings("x\rHuman-Findings: 3")` = `(True, True)`; `"Human-Findings: 0\r\nnote\rHuman-Findings: 2"` = `(True, True)`; `"Human-Findings: 0\r"` = `(True, False)`. `tiers.py:366`. NEL (`\x85`) stays inside one line and the value is then not plain digits, so it reads as caught (fails closed) |

Focus checks with no finding:

- `classify(..., where=)`: the only caller passing it is `evidence` (`tiers.py:415`); `label` (`:338`) and `ready.py:249`
  pass no `where` and still compute top-level and prefix themselves (`:283`). `where` is read from the same `root`
  that every `classify` call uses, and `or ""` keeps the old prefix default, so it cannot differ from what `classify`
  would compute. A failed `rev-parse` gives `(None, "")`, and `gitz(None, …)` fails, so the commit is unprofiled, as before.
- `cut`/`last`: windows nest (a longer window's condition is a superset), so `cut(longest)` is the max of the tier cuts
  and `log[:cut(win) + 1]` is always inside `log`. "Later" is `log[:i]`, position only. No path writes or runs text:
  every subprocess is a list argv, `parent..sha` comes from `%P`/`%H`, nothing opens a file for writing, no `__pycache__`
  in any fixture.
- Exit 2 on an unreadable change set: an attacker who can only push through the host cannot trigger it, since a push
  with a missing object fails the connectivity check. If it is triggered (local corruption, a missing promisor object
  offline), every `--evidence` run exits 2 until it is repaired: no tier can be shown eligible, which is fail-closed.
  The realistic "block evidence for good" trigger is C2 instead, which exits 1.
- A NUL in a first-parent body (`hash-object --literally`, fsck `nulInCommit` warning only): `git log -z` cuts the body
  at the NUL, the record count stays a multiple of 4, no refuse; a revert line after the NUL is not seen, which can only
  hide a revert the attacker wrote themselves (git never writes NULs).
- Docs against output: design Evidence `:355-370`, `docs/reference.md:163-172`, `CHANGELOG.md` [0.8.0] `:24-31` and
  `:47-48`, `kit/playbooks/sync.md` § Trailers `:30-40`, `kit/docs/review-loop.md` step 5 `:62-65` and the `tiers.py`
  docstring `:31-42` match the strings printed: `shallow clone, not read`, `hold (shallow clone: fetch the full
  history)`, `cannot read the change set of <sha7>`, `human-caught <c> of <k> (<pct>%)` (the percent is left out when
  k is 0: `human-caught 0 of 0`). reference.md does not mention the exit 2 on an unreadable change set; the other four
  do. Not worth a row.

End to end (`e2e/`): `git init`, `./install.sh e2e` from `head/`, acme's `autonomy.md` copied and committed.
`tiers.py --check`: 8 rows `declared`, `tiers: 3 tier(s) ok`, exit 0. Staged label with `merged_ref: null`: `tier:
critical`, `base: HEAD (no merge base: last tier)` (fails closed, as documented). After setting `merged_ref: main` and a
one-row Gates table on `main`, branch `feat/x` with `svc/src/main/java/A.java` and `docs/x.md`: `--range main...HEAD`
gives `tier: domain`, `set by: svc/src/main/java/A.java (\`*/src/main/java/*\`)`, `guardrails: 8 declared`. `gates.py`
exit 0; `ready.py --range main...HEAD --pr pr.md` from a detached worktree of `main`: `gates: 1/1 pass at 3b6d468`,
`verdict: ready`, exit 0 (with a failing gate and no Review block it said `not ready` for each, exit 1). After
`merge --no-ff` with `Human-Findings: 0` and `git revert -m 1`: `domain: hold (merged 2 < min 30) — merged 2, reverted 1
(50.0%), … human-caught 0 of 1 (0.0%)`, `unprofiled: 2`; `--json` has the same counts. `git status` clean, no
`__pycache__`. `spec-kit.json` says `"kit_version": "0.7.0"`: expected, the version bump is task 19.

## 2. New findings

| # | Severity | Location | Evidence | Trigger | Consequence | Fix |
|---|---|---|---|---|---|---|
| C1 | advisory | `kit/scripts/tiers.py:406` | `cut` anchors the window on the deepest commit dated inside it, so a commit with nothing in-window below it is out, whatever its position. `p11.sh`: profile and seed dated 2025-06-01, an agent commit dated 5 minutes after its parent, a revert of it dated today, 5 clean commits today. HEAD: `routine: eligible — merged 6, reverted 0 (0.0%)`; true rate 1 of 7 (14.3% > 10%). `983d8da` and `0176d0f` print the same, so the fix did not cause it | The repo was idle for at least the window just below the agent's first commit(s), and a fast-forward or rebase merge keeps the agent's committer date | Those commits and their reverts drop out, and the reverts count as clean merges. Narrow: it needs an idle gap of a whole window, and only the commits at the very tail are affected. The agent's commit is indistinguishable from a genuinely old one by date alone | Cheap and stricter: also extend `cut` down to any commit named by a revert or `Fixes:` at or above the cut (a reverted commit is counted even when it looks old). Or record it as a `shortcut:` next to the other one |
| C2 | advisory | `kit/scripts/tiers.py:406` (from `983d8da`, not this fix) | `int(r[2])` over every record. `p13.sh`: one commit with `committer a <a@a> notadate +0000` (fsck `badDate`) under 20 normal ones. HEAD and `983d8da`: exit 1, `ValueError: invalid literal for int() with base 10: ''`. `0176d0f`: exit 0 (its `--since` walk never read that date) | A commit whose committer date git cannot parse, on a host that accepts fsck-invalid objects (vanilla git leaves `receive.fsckObjects` off; GitHub and GitLab not tested here), merged by fast-forward | Every `--evidence` run fails with a traceback for good, because `cut` reads the whole chain, not just the window. Fail-closed (no eligible), but it is exit 1 with a traceback, not the documented exit 2 | `int(ct) if ct.isdigit() else 0`: a bad date then sets no window and counts by position, like a backdated one. Or refuse with exit 2 naming the sha |
| C3 | advisory | `kit/scripts/tiers.py:247-255`, `:395`, `:421` (pre-existing) | No `--no-replace-objects`. `p14.sh`: `git replace <revert> <clean-looking commit>` turns `breach (reverted 25.0% > 10%) — merged 4, reverted 1` into `eligible — merged 4, reverted 0`; with `GIT_NO_REPLACE_OBJECTS=1` it is `breach` again; a plain clone (no `refs/replace` fetched) is `breach`. `983d8da` and `0176d0f` also print `eligible` with the replace ref | `refs/replace/*` present where `--evidence` runs: a mirror clone, an explicit fetch of that namespace, or a local ref. An agent with contents write can usually push such a ref | Any commit body or parent can be swapped, so reverts and `Fixes:` vanish. The same applies to the profile blob `classify` reads at a base. Needs the replace ref in the evaluating clone, hence advisory | `env={**os.environ, "GIT_NO_REPLACE_OBJECTS": "1"}` in `git()`, `gitz()` and the two `subprocess.run` calls (or `git --no-replace-objects`); one selftest row with `git replace` |

## Verdict

verdict: ship. N1 and A1 to A7 are closed, each re-run on its round-2 fixture. Nothing in the diff opens a
way to pass: every new path (position window, future dates, shallow, unreadable change set, bare CR, empty words)
fails toward hold, breach or exit 2, and `where` cannot differ from what `classify` computes itself. C1 to C3 are
advisories that the fix did not cause (each reproduces at `983d8da`, C1 and C3 at `0176d0f` too); C2 is a one-line
fix worth folding into task 19.
