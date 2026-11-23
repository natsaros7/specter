# Deep review: specter 0.8.0, slice 3 (guardrails and evidence), `197153d..0176d0f`

Deep tier, security first. HEAD = `0176d0f` on `feat/0.8.0`. Line numbers are at HEAD.
Scratch: `/private/tmp/claude-502/-Users-nikolaos-atsaros-Developer-projects-specter/39b113e0-f733-4594-98f2-dfa5f84bbd4e/scratchpad/`
(`wt/` = `git worktree add --detach` at `0176d0f`, removed after the review; `probe/lib.sh` = the fixture helpers:
a `mktemp`-style git repo with `kit/scripts` copied into `.specs/kit/scripts`, `merged_ref: "main"`, Tiers `routine`
`docs/*` none, `domain` `src/*` spot, `critical` `*/security/*` required, one declared guardrail, and the Evidence row
named per probe; `probe/b1` … `probe/a4` = one repo per finding). No tracked file was changed. The only new file is this one.

Gates re-run by me in `wt/` at HEAD: G1 exit 0; G2 `0 FAIL across 2 feature(s)`, `0 FAIL of 7 citation(s)`;
G3 `selftest: OK`, exit 0; G4 `0 FAIL across 7 feature(s)` (one WARN, `REQ-D-01`), `0 FAIL of 72 citation(s)`.
`git status --short` in `wt/` is empty afterwards, and no fixture has a `__pycache__`.

What this change does: the autonomy profile gains `## Guardrails` (what the platform is declared to enforce) and
`## Evidence` (per-tier thresholds). `tiers.classify` reads the Guardrails table at the base and reports a `none` tier
as `spot` while any row is undeclared or the section is missing. `label`, `--json`, `--check` and `ready.py` all show
this. `tiers.py --evidence` walks the first-parent history of `merged_ref` and labels each commit with its first
parent's profile. It counts reverts, `Fixes:` and `Human-Findings:` trailers and prints `eligible`, `hold` or `breach`
per tier. Template, acme example, docs and selftest cases 13c and 14b come with it.

## 1. What holds

- **Guardrail downgrade fails closed.** These all leave `none` downgraded, or exit 2 (`ready.py` then refuses):
  a missing section; a header-only section; a `<placeholder>` in Enforced by (also `<a\|b>`, because `split_row` unescapes
  first); an empty Enforced by; `2026-13-45` and `2026-1-2`; `### Guardrails` (not a section, so absent); a stray
  `\|` that leaves 2 cells (exit 2); a bad header (exit 2 in `--check` and in labelling). A second `## guardrails`
  heading in any case appends its rows, so it can only add undeclared rows. `ready.py` reads `change["human"]`, so
  the Readiness line, `### Risk tier` and `--json` agree. Labelling reads Guardrails at the base only
  (`tiers.py:294-297`). A working-tree edit does not move it (13c commits the profile first, then stages).
- **No writes, no commands from text.** `sys.dont_write_bytecode` is set before the kit imports. `evidence()` opens nothing for
  writing. Every subprocess gets a list argv. `parent...sha` comes from `%P`/`%H`, and the parts can only reach `git merge-base`,
  which rejects any option-like value before `git diff` runs.
- **NUL forgery is not reachable.** I built a commit whose message holds 25 forged `\0sha\0parent\0ct\0body`
  records. `git hash-object` refuses it (`nulInCommit`), so I wrote it with `--literally`. `git log --format=%B`
  (git 2.54) cuts the message at the first NUL: the walk had 6 commits, the forged ones did not appear, and the
  verdict did not change (`probe/b5`).
- **Merge and squash commits are labelled right.** `classify(p1...M)` diffs `p1..M`, which is the whole PR at the
  first parent's profile. In `probe/b1`, 7 `--no-ff` docs merges label `routine`.
- **Thresholds.** `1e2`, `nan`, `inf`, `-1`, `100.` are rejected (exit 2). `-` skips the check. `Min merged 0` still
  needs one merge (`max(low, 1)`). A short-sha prefix collision or a forged `This reverts commit` line can only *add*
  reverts, which is stricter, never looser.

## 2. Findings

| # | Severity | Location | Evidence | Trigger | Consequence | Fix |
|---|---|---|---|---|---|---|
| 1 | blocker | `kit/scripts/tiers.py:379-380`, `:405-409`; `kit/playbooks/sync.md:37,40` | `git log --first-parent ... --format=%H%x00%P%x00%ct%x00%B` reads only the merge commit's body. `probe/b1`: 5 docs PRs merged `--no-ff`. PR 1 is reverted by `git revert -m 1` on a branch merged `--no-ff`; that commit's body is `This reverts commit 90fe2f5…, reversing`. A fix branch carries `Fixes: 2e23498`. Output: `- routine: eligible — merged 7, reverted 0 (0.0%), escaped 0 (0.0%)` with `Max reverted 10`, `Max escaped 10` | The repository merges with merge commits (GitHub's default "Create a merge commit", GitLab's default). The revert and the fix are branch commits, so they sit on the second parent | Every revert and every `Fixes:` is invisible. A tier at 1 revert in 5 merges (20% > 10%) reports `eligible`, not `breach`. sync.md:40 says a revert "counts as reverted", which is false in this mode | For each first-parent commit F, read what it brought in: `git log -z --format=%H%x00%B F^1..F` (the root: F alone). Search the revert and `Fixes:` patterns over those bodies. A named sha hits F when it prefixes any sha in that set (the merge itself or a branch commit). Selftest: `--no-ff` merges plus `git revert -m 1` give `breach` |
| 2 | blocker | `kit/scripts/tiers.py:410-415`; `kit/docs/review-loop.md:62-64`; design `:364-365`; `tests/selftest.sh:659` | `m["with_trailer"] \|= ...` is one flag per window, so a commit without a trailer counts as 0 findings. `probe/b2`: 2 merges carry `Human-Findings: 1`, 18 carry no trailer. Output: `- domain: eligible — merged 20, ... human-caught 2 (10.0%)` with `Max human-caught 10`. Among checked merges the rate is 2 of 2 (100%) | The human forgets the trailer on some merges. Or a rebase or fast-forward merge puts each PR commit on the first-parent chain, and only one of them carries the trailer | A missing trailer counts as "no findings", which breaks REQ-V060-08 ("a metric with no data is a hold, never a pass"). review-loop.md:64 says the trailer on every merge lets `--evidence` "tell 'no findings' from 'no data'", but the code does not do that per merge. The agent's commit count sets the denominator | Count `checked` = commits with a well-formed trailer. Human-caught % = caught / checked. Hold when `checked < max(min, 1)`, as `hold (k of n merged without Human-Findings)`. Amend design :364-365. 13c (:659 expects `eligible` with 4 of 5 untrailered) then expects `hold` |
| 3 | blocker | `kit/scripts/tiers.py:410-412` | `n = re.search(r"^Human-Findings:[ \t]*(\d+)[ \t]*$", ...)` takes the first strict match, while `with_trailer` takes any `^Human-Findings:`. `probe/b3`: 10 merges with `Human-Findings: 2 (missing null check, wrong log level)` give `domain: eligible ... human-caught 0 (0.0%)`. 10 merges with `Human-Findings: 0` above `Human-Findings: 3` (agent-written squash text, then the human's line) give `human-caught 0`. 10 CRLF messages (`Human-Findings: 4\r`) give `human-caught 0` | A human adds a note after the number. Or an agent's PR body already holds `Human-Findings: 0` and the human appends the real count. Or the message has CRLF line ends | The trailer counts as present with zero findings, so a tier where the human caught problems on every merge reports `eligible` | Read every `^Human-Findings:(.*)$` line (strip `\r`). Any value that is not exactly `[0-9]+`, or any value above 0, counts as caught. Take the maximum, not the first. Selftest: a note, two trailers, CRLF |
| 4 | blocker | `kit/scripts/tiers.py:378-380`; `CHANGELOG.md:43-44`; `tests/selftest.sh:645` | `"--since=" + str(int(now - longest * 86400))`: git stops the first-parent walk at the first commit older than the cutoff. `probe/b4`: 5 docs commits, 2 of them reverted, give `breach (reverted 28.6% > 10%)`. Then one commit lands with `GIT_COMMITTER_DATE=2020-01-01`, and 6 clean ones after it. Output: `history: ... 6 commit(s) in the longest window`, `- routine: eligible — merged 6, reverted 0`. git has 14 first-parent commits inside the window | A fast-forward or rebase merge that keeps the author's committer date (GitLab "Fast-forward merge", a local `merge --ff-only` and push, a machine with a wrong clock), or an agent that sets `GIT_COMMITTER_DATE` | One old-dated commit hides all history behind it, so a `breach` becomes `eligible`. The CHANGELOG lists the stop as a known limit, but it does not say that a change can use it to clear a breach | Drop `--since`. Walk the whole first-parent chain and call `classify` only for commits whose `%ct` is inside the longest window (`:403` already filters `mine` by `ct`). Then each backdated commit drops out alone. This also removes a git date-parse problem: a cutoff under 9 digits is not read as a timestamp (`--since=100000` gave 0 commits here), so windows over about 53 years see no history. Remove the CHANGELOG line, fix the :645 comment, and add a selftest with one backdated commit in the middle |
| 5 | blocker | `kit/scripts/tiers.py:408-409` | `([0-9a-f]{7,40})\b` cannot match a 64-hex sha: after 40 hex the next character is hex, so `\b` fails. `probe/a4`, `git init --object-format=sha256`, 3 docs commits and one `git revert` (body `This reverts commit 9c9f1a6b…5cf064668.`): `- routine: eligible — merged 4, reverted 0`. The same history in SHA-1 (`probe/a4s`): `breach (reverted 25.0% > 10%)` | A SHA-256 repository (`extensions.objectFormat=sha256`); `git revert` writes the full sha | Reverts, and `Fixes:` with a full sha, are never counted, so a breach reads `eligible` | `{7,64}` in both patterns |
| 6 | advisory | `kit/scripts/tiers.py:357-363`, `:371` | `text = profile.read_text()` for the thresholds and the tier names, and `committed_ref(..., HEAD)` for the history. `probe/a1`: a clean `main` checkout gives `breach (reverted 25.0% > 10%)`. An uncommitted edit of `Max reverted %` from 10 to 50 gives `eligible`, and nothing in the report says the thresholds came from a modified working tree | `--evidence` is run in the checkout of the PR that proposes a promotion. That PR can also lower thresholds or point `merged_ref` at itself | The report the human reads to decide a promotion uses the change's own rules. Labelling avoids exactly this (profile at the base) | Read the profile at the resolved `merged_ref` tip (`profile_at(root, head, rel)`), and print `- profile: <rel> at <sha>`. Or print `(working tree, modified)` when it differs from HEAD. File as a follow-up task under [REQ-V060-08] |
| 7 | advisory | `kit/scripts/tiers.py:75-84`, `:150-154` | `section()` ignores code fences and HTML comments. `probe/a2-fence`: no real Guardrails section, but a fenced `markdown` example holds `## Guardrails` with one dated row, and the label is `human: none`, `guardrails: 1 declared`. `probe/a2-comment`: the same with the rows inside `<!-- … -->`. `\| x \| - \| 2026-01-02 \|` and `\| x \| TBD \| 2099-12-31 \|` count as declared | A profile edit that a human approves from the rendered view | The rendered profile shows no guardrails, yet `none` stays `none`. The profile is guarded (last tier, human required), so the raw diff is reviewed. That is why this is advisory | Skip lines inside fences and `<!-- -->` in `section()`. This applies to Tiers too. Treat `-`, `TBD`, `none` and a future date as undeclared. Follow-up task under [REQ-V060-07] |
| 8 | advisory | `kit/scripts/tiers.py:188-195`, `:410` | `re.fullmatch(r"\d+", ...)` on `str` matches Unicode digits, and `int()`/`float()` accept them. `৪` (Bengali four, looks like 8) gives `4.0`, `１００` gives `100.0`, and `Human-Findings: ٣` matches | A threshold or trailer written with non-ASCII digits | What a reviewer reads is not what the code compares. This is stricter or looser depending on the glyph | `re.ASCII` (or `[0-9]`) in these patterns. Follow-up under [REQ-V060-08] |
| 9 | advisory | `kit/scripts/tiers.py:403`; design `:359` | `merged` counts first-parent commits, not merges | Rebase-merge or fast-forward: one PR split into 20 commits | Min merged is reached by one PR, and one revert of a squashed fix dilutes 20 ways. Finding 2's fix covers human-caught, not Min merged or reverted/escaped % | State in sync.md § Trailers and the reference that evidence assumes squash or merge commits. Optionally hold when a tier's first-parent commits have no merge or `(#n)` marker. Follow-up under [REQ-V060-08] |
| 10 | advisory | `kit/scripts/tiers.py:392`, `:403` | Evidence matches commits to tiers by name only. A commit labelled with a tier name that the working-tree table no longer has is dropped from every tier and from the `unprofiled` count. A tier that keeps its name but widens its globs inherits the evidence earned on its old paths | A tier rename, or `routine: docs/*` widened to `src/*` | A rename silently empties the history (hold, so fail-closed). A widened tier can show `eligible` on evidence it did not earn on the new paths | Print `- relabelled: <n> commit(s) under tiers not in the table`, and note when the tier's row changed inside the window. Follow-up under [REQ-V060-08] |

Docs and coverage:
- The docs claims I checked match the output. Labelling: `- guardrails: <m> of <n> undeclared, none → spot`,
  `n declared` and `no Guardrails section`. `--check`: one `guardrail file:line:` line per row. Evidence: the `hold`,
  `breach` and `eligible` wording and the `history:`, `unprofiled:` and `profile: unchanged` lines. Nothing claims
  specter enforces a guardrail; template, acme, reference, CHANGELOG and design all say "declared". The false claims are
  the ones in findings 1 (sync.md:40), 2 (review-loop.md:64) and 4 (CHANGELOG:43-44, which understates the
  consequence). One small slip: the docstring at `tiers.py:33` says "as --check's staged mode finds it", but `--check`
  has no staged mode (it means the label's staged mode). A header-only Guardrails section prints
  `no Guardrails section`.
- Requirement coverage. REQ-V060-07 is covered in 13c and 14b: eight template rows, acme all declared, an undeclared
  row seven downgrading `none` through `--range`, "no such job, checked …" counting as declared, and the bad date and
  header cases. REQ-V060-08 is covered in 13c: no section or no trailers is a hold, revert breach, `Fixes: <sha>` counted
  and `Fixes: #12` ignored, Min merged, labels from the parent's profile, profile byte-identical. Not tested: a
  merge-commit history, an `escaped` breach, malformed or duplicate trailers, non-monotonic committer dates.
  Findings 1 to 4 each name the test that would have caught them. REQ-V060-11's slice 3 items are present.
  (The evidence half of 13c reuses the heading `13c` with dir `t13d`, and design :467 reserves 13d for slice 4.)

## Verdict

fix then re-review. Fix blockers 1 to 5, all in `tiers.evidence()`: each one lets a merged history that breaches its
thresholds print `eligible`. Labelling and the guardrail downgrade are sound.
