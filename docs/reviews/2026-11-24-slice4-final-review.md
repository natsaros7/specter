# Final review: specter 0.9.0 slice 4, fix round 3 (`3f19cac..236541a`)

Deep tier, security first, confirmation scope. HEAD = `434d965` on `feat/0.9.0`. The fix under review: `git diff
3f19cac..236541a` (`spec_lint.branch_ref`'s symref rule for `refs/remotes/<remote>/HEAD`, `merged_commits` returning
`(out, skipped)` and the lint WARN, `tiers.end_commit` taking full ids only, acme row 6, CHANGELOG, reference.md,
selftest 13e C1/C2 and the merged-work WARN row). `434d965` is spec-only (v060 Status Done, v061-trust-hardening with
C3/C4 as tasks 11/12); no code or doc behaviour changes there. Earlier round: `2026-11-24-slice4-confirmation-review.md`
(C1 blocker, C2–C6). Line numbers are at HEAD.

Scratch: `/private/tmp/claude-502/-Users-nikolaos-atsaros-Developer-projects-specter/39b113e0-f733-4594-98f2-dfa5f84bbd4e/scratchpad/`.
`rv4/` = `git worktree add --detach` at HEAD, removed after the review. `p4/lib.sh` and `p7/t.py` repointed to
`rv4/kit`; every probe ran with `PYTHONDONTWRITEBYTECODE=1`, so no `__pycache__` reached `rv4/` before G3. `p6/ci1` had
its plain `refs/remotes/origin/HEAD` re-fetched from `p6/srv.git`. New: `p8/` (real-setup checkouts against bare
servers `srv2.git` with a pushed `refs/heads/HEAD`, `srv3.git` without it, `srv5.git` with a lowercase `head`) and
`p8c6/` (lint WARN). No tracked file was changed; this file is the only new one in the main tree.

## Gates (re-run in `rv4/` at HEAD)

| Gate | Result |
|---|---|
| G1 | exit 0 |
| G2 | exit 0: `spec-lint: 0 FAIL across 2 feature(s)`, `spec-lint --cites: 0 FAIL of 7 citation(s)` |
| G4 | exit 0: `spec-lint: 0 FAIL across 8 feature(s)` (one WARN, `REQ-D-01`), `spec-lint --cites: 0 FAIL of 72 citation(s)` |
| G3 | exit 0, first run: `selftest: OK` (13e C1/C2 rows included); `git status --short --ignored` in `rv4/` empty before and after |
| G5 | not run: the diff does not touch `examples/acme-shop/` outside `.specs/` |

## Closure

| # | Status | Probe at HEAD |
|---|---|---|
| C1 | CLOSED | `p6/ci1`: `show-ref` `d3e0a04… refs/remotes/origin/HEAD`, `symbolic-ref`: `fatal: ref refs/remotes/origin/HEAD is not a symbolic ref`, merged_ref `null`. `tiers.py --range <main sha>...<head sha>`: `human: none → spot (evidence: no merged_ref (set merged_ref or refs/remotes/origin/HEAD))`. `--evidence`: `history: HEAD at 4e018a3` (no longer the fake chain). `ready.py … --auto-merge`: `verdict: ready`, `auto-merge: no (human spot: evidence: no merged_ref (…))`, exit 1. Was `auto-merge: yes`, exit 0 |
| C2 | CLOSED | `p7/r` (APFS, packed tag `C282714` on `A`, head `c282714…`): `end_commit('c282714')` → `ValueError: --range end c282714 is not a branch, a remote-tracking ref, HEAD or a full commit id`; `C282714` → `is a tag (refs/tags/C282714)`; the full 40-hex id → `c28271497242…` (the head). Selftest 13e C2 row passes |
| C3 | filed (v061 task 11), not made worse | The diff does not touch `kit/docs/review-loop.md` |
| C4 | filed (v061 task 12), not made worse | Same |
| C5 | CLOSED | acme `autonomy.md:41` Guardrail column is byte-identical to template row 6 (`kit/templates/steering/autonomy.md:38`): "Agents cannot edit merged history or review records, or create tags or `refs/replace/` refs"; Enforced by adds `tag ruleset protect-tags on refs/tags/* (creation by maintainers only); the CI checkout fetches no refs/replace/*`; Verified `2026-11-24`. CHANGELOG "acme-shop's rows are re-dated 2026-11-24" is now true for rows 3 and 6 |
| C6 | CLOSED | `p8c6`, merged_ref `"v1"` (a tag): `WARN merged-work check skipped in .: merged_ref v1 is a tag (refs/tags/v1)`. Controls `"dev"`, `"main"`, `"refs/remotes/origin/dev"`: `WARN merged work found (1 commit(s) in .) …` (check runs). Selftest row after "missing git" passes, exit code unchanged |

## Regressions (run once)

| Probe | Result at HEAD |
|---|---|
| N1 `p5/ci1` (tag `origin/HEAD` at the PR head) | by sha and by `origin/main...HEAD`: `human: none → spot (evidence: no merged_ref (…))`, `--auto-merge` exit 1 |
| N1 `p5/ci2` (tag `origin/main`, merged_ref `"origin/main"`) | by sha: `evidence: merged_ref origin/main is ambiguous (refs/tags/origin/main, refs/remotes/origin/main)`, exit 1; by name: `--range end origin/main is ambiguous`, exit 2 in both scripts; `--evidence` exit 2 |
| N1 `p5/ci3` (tag inside the PR) | by name exit 2; by sha `tier: domain`, `files: 5 (routine 4, domain 1)`, `auto-merge: no`, exit 1 |
| N1 `p5/oh` (origin/HEAD symref → PR branch) | `evidence: refs/remotes/origin/HEAD contains the change`, exit 1 |
| B1 `p4/r1` | gpt reviewer: `human: none`, `verdict: ready`, `auto-merge: yes`, exit 0; `claude-opus-5-5`: `none → spot (same family)`, exit 1 |
| B2 `p4/b2`, `p4/b3` | `evidence: hold (merged 1 < min 20)`; `evidence: hold (thresholds not set)`; exit 1 |
| B3 `p4/b1`, `b1m`, `b2c` | `evidence: no merged_ref (…)` exit 1; control `hold (merged 0 < min 3)`; staged `tier: critical`, `base: HEAD (no merge base: last tier)`, `auto-merge: no (needs --range base...head; …)` exit 1 |
| A4 `p4/b5`, `p4/b4` | `tier: critical`, `set by: docs/autonomy.md`; `set by: .specs/steering/autonomy.md` |

## Symref rule against real setups (`p8`, git 2.54, APFS)

PR = one docs commit `4e018a3` off `main` `3378b4e`; merged_ref `null`; label by full shas; `ready.py --auto-merge`.

| Setup | `refs/remotes/origin/HEAD` | Result |
|---|---|---|
| `git clone` of a server that already has `refs/heads/HEAD` | symref → `origin/main` (clone ignores the branch) | `hold (merged 0 < min 3)`, exit 1 |
| `git clone`, then the branch `HEAD` is pushed, then `git fetch` / `fetch --prune` / explicit `+refs/heads/*:refs/remotes/origin/*` | symref kept; `origin/main` unchanged (fetch never writes through the symref) | `hold`, exit 1 |
| Positive control: clone, `origin/main` with 3 docs merges | symref → `origin/main` | `human: none`, `auto-merge: yes`, exit 0 (the rule does not break the legitimate path) |
| Same, after `git pack-refs --all` | symref stays loose | `none`, exit 0 |
| `git init` + `remote add` + `fetch origin` (configured or explicit refspec), server has branch `HEAD` | plain `d3e0a04` (`[new branch] HEAD -> origin/HEAD`) | `no merged_ref`, exit 1 |
| Same, plain ref packed (`packed-refs` line `d3e0a04… refs/remotes/origin/HEAD`) | plain, packed | `no merged_ref`, exit 1 |
| Same, `--ref-format=reftable` | plain | `no merged_ref`, exit 1; after `symbolic-ref` → `origin/main` (3 merges): `none`, exit 0 |
| `init` + `fetch origin`, no branch `HEAD` (git ≥ 2.48 `followRemoteHEAD` default) | symref → `origin/main` | `hold`, exit 1 |
| `actions/checkout` style (`fetch --depth=1 origin +<sha>:refs/remotes/pull/1/merge`) | absent | `no merged_ref`, fails closed (step 5 item 2: set merged_ref) |
| `git remote set-head origin -a` over the plain ref | `'origin/HEAD' was detached at 'd3e0a04…' and now points to 'main'`; a later fetch keeps the symref | `hold`, exit 1 |
| `git remote set-head origin HEAD` | self-loop (`ref: refs/remotes/origin/HEAD`); `for-each-ref` skips it | fallback `HEAD`, `no merged_ref` |
| Fresh fetch of a lowercase branch `head` (APFS) | loose file `head`; `git rev-parse refs/remotes/origin/HEAD` → `d3e0a04` by case folding | `branch_ref` matches names exactly, so no hit: `no merged_ref`, exit 1 |
| Clone (symref), then branch `head` pushed and fetched (APFS) | symref kept, `ref: refs/remotes/origin/main` | `hold`, exit 1 |
| symref → `refs/remotes/upstream/main` (another remote, 3 merges) | accepted | `none`, exit 0: history is `upstream/main`, a deliberate local choice |
| symref → `refs/remotes/up2/HEAD`, a plain ref from a branch `HEAD` pushed to another remote | accepted | `none`, `auto-merge: yes`, exit 0: see D1 |

## New findings

| # | Severity | Location | Evidence | Trigger | Consequence | Fix |
|---|---|---|---|---|---|---|
| D1 | advisory | `kit/scripts/spec_lint.py:368-372` | The rule checks one level: `%(symref)` must be non-empty and start with `refs/heads/` or `refs/remotes/`. A symref whose target is itself a plain `refs/remotes/<other>/HEAD` passes. `p8/ow2`: `refs/remotes/up2/HEAD` plain (fetched branch `HEAD`), `git symbolic-ref refs/remotes/origin/HEAD refs/remotes/up2/HEAD`: `tier: routine (… human: none)`, `auto-merge: yes`, `ready exit 0` | A person or CI script points `origin/HEAD` by hand at another remote's `HEAD` and that remote carries a pushed branch `HEAD`. No git command does this on its own: clone, `set-head -a`, `set-head <branch>` and `followRemoteHEAD` all target `refs/remotes/origin/<branch>`, and none writes through or replaces an existing symref with a plain ref (table above) | C1's fabricated history again, one hop removed. Not a blocker: it needs a local misconfiguration the attacker cannot make by pushing | Also refuse a symref whose target ends in `/HEAD` (one more clause on line 371), or require the target to be `refs/heads/*` or `refs/remotes/<same remote>/*` not ending `/HEAD` |
| D2 | advisory | `kit/scripts/tiers.py:296` | A 64-hex end skips `branch_ref` in a SHA-1 repo too, where git does not read it as an object id and DWIMs it as a ref. `p8/ci-b` (SHA-1), branch `refs/heads/aaaa…` (64 a's) → `d3e0a04`: `end_commit('aaaa…')` returns `d3e0a046b8d3…`. This predates the diff, but it is now the only ref-lookup path left in `end_commit` | The job passes a 64-hex end in a SHA-1 repo. Platform events give 40-hex shas there, so an agent cannot reach this through the documented recipe | Base or head moves to the agent's commit, as in N1 `ci3` | Accept the length of `git rev-parse --show-object-format` only, or compare `rev-parse`'s output with the input |
| D3 | advisory (diagnosis only) | `kit/scripts/spec_lint.py:384` | The fallback takes `branch_ref(…)[0]` and drops `why`. With a plain `origin/HEAD` the label says `no merged_ref (set merged_ref or refs/remotes/origin/HEAD)` although the ref exists, and the lint falls back to `HEAD` without a WARN | Any CI that fetches a pushed branch `HEAD` | Fails closed; the operator is told to set a ref that is already there, and does not learn a branch `HEAD` was pushed | Return the fallback's `why` (`refs/remotes/origin/HEAD is not a symbolic ref (…: a branch named HEAD?)`) as merged_ref does for a set value |
| D4 | advisory (text) | `.specs/features/v060-staged-autonomy/requirements.md:169-171` | The 2026-11-24 amendment still says the fallback "SHALL resolve to exactly one branch or remote-tracking ref"; the symref condition C1 proposed is in the code, reference.md:91 and CHANGELOG, not in the requirement | Reading the spec | A later change could drop the rule and still meet REQ-V060-08's letter | Add "the fallback counts only as a symbolic ref" to the amendment |

## Clean checks

- **Only refusals added.** Every changed code path in the diff adds a refusal (`branch_ref` `/HEAD` clause, `end_commit`
  without the `{4,63}` branch) or touches only the lint (`merged_commits`, WARN). Neither can turn `spot`, `required` or
  exit 1 into `none` or exit 0. Each refusal ends in `spot` (label), the last row (staged), exit 2 (`--evidence`, a bad
  `--range` end) or a skipped lint check. No new path crashes: `lint_all` unpacks `got[0]`/`got[1]` only when `got` is
  not `None`, and `spec_report.in_flight` still takes `merged_ref(...)[0]`.
- **Scope of the `/HEAD` clause.** It applies to every way the name reaches `branch_ref`: the fallback, merged_ref
  `"origin"`, `"origin/HEAD"` or `"refs/remotes/origin/HEAD"`, and a `--range` end `origin` (now exit 2 when plain). It
  checks `hits[0]` after the ambiguity and tag checks, so a symref to a tag is still refused first. `%(symref)` comes
  from `for-each-ref` in all three backends tried (loose, packed, reftable).
- **Callers resolve the full name.** `evidence()` runs `rev-parse refs/remotes/origin/HEAD^{commit}`, which follows the
  symref accepted by `branch_ref`, never the short name, so case folding cannot reach it (APFS `head` row above).
- **REQ-V060-05/-08/-09/-13/-15.** -08: history is only a symref default branch or an explicit branch or remote-tracking
  ref; the contains-the-change check is unchanged (`p5/oh`). -09: `none` still needs eligible evidence (positive
  control) and `--auto-merge` still says no on every reason (`p4`, `p5`). -05: the lowest-row rule and `set by` are
  untouched (A4). -13: same-family stays `spot` (`p4/r1`). -15: `rounds` handling is untouched by the diff (N2
  selftest rows pass in G3).
- **Docs agree with the code.** CHANGELOG Security bullets, reference.md:91 (`when it is a symbolic ref (a plain one, as
  a pushed branch named HEAD makes, is refused)`), the `tiers.py` docstring ("a full commit id") and selftest 13e
  describe the same rules.

## Not checked

- Live GitHub and GitLab: whether either accepts a pushed `refs/heads/HEAD`. C1 is closed in code whatever they do.
- The live-platform side of C3/C4 (filed as v061 tasks 11/12; the diff does not touch the recipe).
- A Windows runner (NTFS case folding); APFS only.
- Case-folded branch names other than `head` (for example a pushed `MAIN` against `refs/remotes/origin/main` on a
  case-insensitive runner). This would affect an explicit merged_ref too, is outside this diff, and I did not probe it.
- G5, `docs/overview/`, and the advisories now in v061 beyond "not made worse".

## Verdict

ship

C1, C2, C5 and C6 are closed with probe output; N1 and B1–B3 hold; all gates exit 0. The symref rule fails closed in
every setup git produces on its own (clone, CI fetch with and without a branch `HEAD`, `actions/checkout`,
`set-head -a`, `followRemoteHEAD`, packed refs, reftable, APFS case folding) and keeps the legitimate `none` path. D1 is
the same bypass one hop away, but only through a hand-made symref to another remote's `HEAD`. D1–D4 are small and can go
into v061 next to tasks 11/12.
