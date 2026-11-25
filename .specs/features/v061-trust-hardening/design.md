# v061 Trust-layer hardening — Design

Security-sensitive: every task changes what can earn `human: none` or `auto-merge: yes`. Review on the deep tier.
Stdlib only, Python 3.8+, offline, no new dependency. Each task names its source row in `docs/reviews/`; the row has
the probe. One task per dispatch (tasks 1 to 16 are issues #3 to #18; tasks 17 to 20 are issues #24 to #27; task 21 is #28; task 22 is #29; task 23 is #30; task 24 is #32), red first: add the selftest row, run `sh tests/selftest.sh`,
see it fail for the stated reason, then fix, then G1 to G4 (AGENTS.md).

| Requirement | Source rows |
|---|---|
| [REQ-V061-01] | slice 3 deep review advisories 6, 7, 9, 10; slice 3 confirmation review C1, C2, C3 |
| [REQ-V061-02] | slice 4 deep review advisories 5, 7, 9 |
| [REQ-V061-03] | slice 4 confirmation review C3, C4 |
| [REQ-V061-04] | slice 4 final review D1 to D4, and its "not checked" case-folded branch names (probed below, task 15) |
| [REQ-V061-05] | Nikos, 2026-11-24: specter should use its own trust layer (dogfooding) |
| [REQ-V061-06] | Nikos, 2026-11-24: the README rewritten along Story, How, Output, Worth |
| [REQ-V061-07] | Nikos, 2026-11-24: the issues are public, so future bypasses go to private advisories |
| [REQ-V061-08] | Nikos, 2026-11-24: five parallel selftests drained the laptop; make it faster and deterministic |
| [REQ-V061-09] | Nikos, 2026-11-24: no-human only for trivial changes, tests and easy fixes; the reviewer judges complexity on top |
| [REQ-V061-10] | Nikos, 2026-11-24: self-review and self-heal the process too, and put it into the kit |

## Rules for every worker

- Selftest rows go where this design says. New `--evidence` fixtures use the `nr` helper of the "13c. evidence" block
  (the one defined before 11b redefines `nr`) and take the repo name the task gives, so parallel branches never pick
  the same `$TMP/t13eN`.
- No CHANGELOG edit per task: task 16 writes the 0.10.0 entry from the merged tasks, so parallel branches do not
  conflict on it. Each task updates the docstring, `docs/reference.md` and the playbook lines that describe what it
  changes.
- Messages keep the existing forms: `tiers: <why>` on stderr with exit 2 for a refusal, `- human: none → spot (<why>)`
  in the label, `auto-merge: no (<why>)` in `ready.py`.
- Never cite a line number in backticks in a spec (G4 checks citations). Name the function.

## Decisions

| # | Decision | Chosen | Trade-off |
|---|---|---|---|
| 1 | Who writes `Human-Findings:` on an auto-merge (task 8) | **Nobody.** Only a human writes it, at a human check. The recipe's job writes no trailer. `--evidence` ignores a `0` on a commit labelled `none` at its parent (an agent's PR body may hold one), but still counts a caught value there. On a tier whose row says `none`, it does not hold for missing trailers; the rate is still checked over the trailers present | The job writing `0` would put non-human data in a human metric. A new `Human-Findings: none` token would need a parser change, and today's rule reads it as caught, which would breach the tier on its own merges. Cost: under `none`, human-caught only sees what humans wrote earlier in the window. Reverts and escapes keep checking the tier |
| 2 | GitHub approver (task 11) | **A GitHub App** whose key is an environment secret. The environment's deployment branches allow only the default branch. The job is `pull_request_target`, so it runs on the base. Every workflow that runs PR code has `permissions: contents: read` and checks out with `persist-credentials: false`. The `GITHUB_TOKEN` alternative is dropped, and "Allow GitHub Actions to create and approve pull requests" stays off | One App and one environment to set up. In exchange, a `pull_request` run (the Gates, the agent's code) cannot get the key. `GITHUB_TOKEN` approval is repo-wide: any workflow with a write token approves as the same bot |
| 3 | GitLab approver (task 11) | **A trusted project** (`<group>/specter-approver`; MR authors have Reporter at most) holds the bot's project access token as a protected, masked variable. The MR pipeline's last job (`allow_failure: true`, from the external CI config) starts that project's pipeline with a pipeline trigger token, passing only the MR iid. The trusted job checks the project id against a fixed value and reads the base and head shas from the MR API, never from the trigger's variables | An extra project and a trigger token. The trigger token is readable by MR jobs, but it can only start a pipeline that decides on its own. A token in the MR pipeline is either unprotected (the Gates jobs read it) or protected (unprotected source branches never get it, so nothing approves) |
| 4 | Bind to the checked sha (task 12) | GitHub: approve through `POST …/pulls/{n}/reviews` with `commit_id=<head sha>`, then `gh pr merge --auto --match-head-commit <head sha>`, then read the head again. If it moved, dismiss that review and run `gh pr merge --disable-auto`. `concurrency: specter-auto-merge-<pr number>` with `cancel-in-progress: false`. GitLab: `POST …/approve` and `PUT …/merge` (auto-merge on), both with `sha=<head sha>`, under `resource_group: mr-<iid>` | The re-read is three more recipe lines. GitHub documents no head check for a review's `commit_id`, while GitLab's `sha` refuses a moved head (409). `cancel-in-progress: true` would kill a job between its approval and its re-read, which leaves the approval on the new head |
| 5 | `GIT_NO_REPLACE_OBJECTS` scope (task 7) | `os.environ["GIT_NO_REPLACE_OBJECTS"] = "1"` once, when `tiers.py` is imported | One line, and it covers the `spec_lint` ref calls `tiers.py` makes and `ready.py`'s git calls (which import `tiers`). Passing `env=` per call is four edits in three functions, conflicts with lane A, and still misses `spec_lint`. `ready.py` runs only git, so nothing else inherits the setting |
| 6 | A full id at the repo's hash length (task 13, D2) | `end_commit` accepts a 40- or 64-hex end only when `rev-parse --verify <end>^{commit}` returns the input unchanged | No extra git call or version check. A 64-hex end in a SHA-1 repo reads as a ref and resolves to a 40-hex id; an annotated tag's id peels to another id. Both are refused. `--show-object-format` needs one more call and git 2.25 or later |
| 7 | What "the tier's row changed" means (task 4) | A commit counts for a tier only if the parent's row has the same name and the same set of Paths globs as the row read now. Other commits go on `- relabelled: <n> commit(s) …`. Reviewer and Human are not compared | A widened or renamed tier starts over (hold until it re-earns), which is fail-closed. Comparing Human would reset a tier on every promotion, so promotion could never be earned |
| 8 | Fenced code and comments in `section()` (task 2) | Skip them for every section except Knowledge: `guarded_globs` keeps reading the raw Knowledge lines | A Knowledge link inside a comment stays guarded, which is stricter. It costs one keyword argument with a single caller |
| 9 | A refused `origin/HEAD` fallback (task 14, D3) | `merged_ref` returns `(None, why)`, as it does for a set value | The lint WARNs, and `--evidence` exits 2 instead of silently counting HEAD. `spec_report`'s in-flight view shows nothing for that repo (its `ref` is None) instead of comparing against HEAD |
| 10 | Case-folded branch names (task 15) | `branch_ref` lists all refs once. It refuses a hit, or a symref's target, when another listed ref has the same NFC casefold, or when the target is not listed under its exact name. The recipe fetches `merged_ref` by an explicit refspec | The probe shows a real shadow on APFS (below). The listing check is deterministic on every disk, so the selftest runs on Linux CI too. It also refuses a repo that really has both `main` and `MAIN` (rare, and fail-closed). One spelling with the wrong content is invisible locally. The explicit refspec covers that, recorded as `shortcut:` |
| 11 | Nikos's calls (2026-11-24) | Decision 1 accepted. Decision 3: GitHub only for now, so the GitLab bullet is written as a sketch labelled untested. Task 15 runs next in lane F, ahead of task 14, and goes under Security in the CHANGELOG. Tasks 11 and 12 are verified live by the lead on a private sandbox repo under Nikos's account, using a GitHub App he creates, with his OK at that step. `none` stays off until then | Recorded on issues #10, #13, #14 and #17 |

## [REQ-V061-01] Evidence reads only what it should

### Task 1: thresholds from the `merged_ref` tip (#3)

- **Touches:** `tiers.evidence()` (read order and messages), its docstring, `docs/reference.md` Evidence bullet.
- **Red row:** 13e, after the B2 rows, on the same `xmk b2` fixture (the working tree lowers Min merged from 20 to 1,
  trunk at the tip): `xl --evidence` must print `routine: hold (merged 2 < min 20)` and
  `- profile: .specs/steering/autonomy.md at <trunk sha7>, unchanged; …`. Today it prints `eligible` from the working tree.
- **Fix:** resolve `committed_ref` and `head` first. Then `text = profile_at(root, head, rel)` when the caller gave
  none: `None` is `refuse("no <rel> at <ref> <sha7>: nothing to count")`, and a `ValueError` from it is
  `refuse(str(err))`, never indexed as a tuple (task 10 relies on this). Parse errors read `<rel> at <sha7>:<line>: <msg>`, as
  `classify` writes them. The last report line becomes `- profile: <rel> at <sha7>, unchanged; promotion and demotion
  are a human edit of <rel>`. `earned()` still passes the base's text, so the label path does not change.
- **Fixture migration (same commit):** the "13c. evidence" block edits the profile in the working tree through `ev`.
  `ev` must now also commit it, but only when it changed. Each such commit touches a guarded path, so it lands under
  `critical` and in the window. The routine, domain and `unprofiled: 3` numbers do not move. The critical ones do:
  the demote case becomes `critical: breach (escaped 20.0% > 10%)` (1 of 5: three profile commits plus k1 and k2). The
  `bad()` rows commit their profile and grep `autonomy.md at [0-9a-f]*:[0-9]*: <msg>`. Re-derive any other number
  by running the block, never by guessing.
- **Depends on:** nothing. Tasks 4, 5, 6, 8 and 10 rebase on it.

### Task 2: `section()` skips fenced code and HTML comments (#4)

- **Touches:** `tiers.section()`, `tiers.guarded_globs()` (passes `raw=True`).
- **Red rows:** 13c, with `cset`. (a) No real Guardrails section, and a fenced ```` ```markdown ```` block that holds
  `## Guardrails`, its header and one dated row: the label must say `guardrails: no Guardrails section, none → spot`.
  Today it says `1 declared`. (b) The same rows inside `<!-- … -->`. (c) A fenced `## Tiers` example after the real
  table does not end or replace it: the label still reads the real rows.
- **Fix:** blank out `<!--…-->` spans while keeping their newlines, so line numbers stay right (the same pattern as
  `ready.visible`, which drops lines and so cannot be reused). Then ignore lines inside a ```` ``` ```` or `~~~` fence,
  headings included. `raw=True` keeps today's behaviour for Knowledge (decision 8).
- **Depends on:** nothing. Parallel with every other task.

### Task 3: docs say evidence assumes squash or merge commits (#5)

- **Touches:** `kit/playbooks/sync.md` § Trailers, `docs/reference.md` Evidence bullet.
- **Red row:** none, because this is prose. The reviewer checks the sentence against `evidence()`, which counts
  first-parent commits.
- **Fix:** one sentence in each: "Evidence counts first-parent commits, so it assumes squash or merge commits. A rebase
  merge or fast-forward puts each PR commit on the chain: Min merged is reached faster, and one revert is diluted over
  the PR's commits."
- **Depends on:** nothing. It touches other sentences than task 8 in the same files.

### Task 4: a renamed or changed tier row (#6)

- **Touches:** `tiers.classify()` (adds `"globs": rows[idx][1]` to the result), `tiers.evidence()` (labelling loop,
  report and JSON).
- **Red row:** the "13c. evidence" row "the parent's table labels, not the working tree". After task 1 it commits
  `routine` with `nothing/*`. Today `routine.merged == 5`; after this task, `routine.merged == 0`, the report prints
  `- relabelled: 5 commit(s) under a tier row renamed or changed in the window`, and JSON has `"relabelled": 5`.
  `domain` stays at 6. Add a rename case: `routine` renamed to `docs` with the same globs counts its old commits as
  relabelled, not under `docs`.
- **Fix:** key each commit by `(tier, sorted globs)` from its parent's profile, and each tier now by
  `(name, sorted globs)` from the profile `evidence` read. A commit whose key is not a current row is relabelled:
  counted on that line and under no tier (decision 7).
- **Depends on:** task 1 (same function; "the table" is the tip's). Serial with tasks 5, 6 and 8.

### Task 5: the window reaches what a revert or `Fixes:` names (#7)

- **Touches:** `tiers.evidence()` (`cut` and building `log`).
- **Red row:** new repo `t13e12` (the C1 probe). Profile and `d0` dated 2025-06-01; an `agent` docs commit dated five
  minutes later; then, dated now, `git revert` of `agent` and five clean docs commits. With
  `ER='| routine | 90 | 1 | 10 | - | - |…'`, want `routine: breach (reverted 14.3% > 10%)`. Today it is
  `eligible — merged 6, reverted 0`.
- **Fix:** after the date cut, look at every revert and `Fixes:` sha in `log[:cut + 1]`. When one prefixes a
  first-parent sha below the cut, add **that commit only** (and, transitively, what it names). The commits between it
  and the cut stay out: pulling the whole range in would let one revert of an ancient commit dilute the rates with old
  clean history (lead review, 2026-11-25; row `t13e15`). Each commit enters at most once, so it ends. Each tier's log
  follows the same rule inside its own window. `shortcut: names are matched against first-parent shas only; a branch
  commit of a merge below the cut stays out, extend to change sets if a merge's date can be forged`.
- **Depends on:** task 1. Serial with tasks 4, 6 and 8 (task 6 guards the same `cut`).

### Task 6: an unparseable commit date (#8)

- **Touches:** `tiers.evidence()`, just before `cut`.
- **Red row:** new repo `t13e13`. One commit is written with `hash-object --literally` and the line
  `committer a <a@a> notadate +0000` (as `t13e10` builds its orphan), then `update-ref` main to it, then one normal
  commit on top. Want exit 2 and `tiers: commit <sha7> has an unreadable committer date`. Today it is exit 1 with a
  `ValueError` traceback.
- **Fix:** refuse on the first record whose `%ct` is not `[0-9]+` (ASCII), before any `int()`. This is fail-closed:
  every run exits 2 until the history is repaired, and the label then says `spot` with that reason.
- **Depends on:** task 1. Serial in lane A.

### Task 7: `GIT_NO_REPLACE_OBJECTS=1` (#9)

- **Touches:** the top of `tiers.py`, one line after the imports (decision 5).
- **Red row:** new repo `t13e14`: `a1`, `a2`, `git revert a1`, `a3`. Then
  `CL=$(git commit-tree <revert>^{tree} -p <revert>^ -m clean)` and `git replace <revert> $CL`. Want
  `routine: breach (reverted 25.0% > 10%)`. Today it is `eligible — merged 4, reverted 0`.
- **Fix:** the line, with a comment that `refs/replace` can swap any commit body or the profile blob.
- **Depends on:** nothing. It touches no function, so it runs in parallel with lane A.

## [REQ-V061-02] Declarations read strictly

### Task 8: `Human-Findings:` on an auto-merge (#10)

- **Touches:** `tiers.evidence()` (the log entry keeps `c["human"]`; the counting loop and the hold), `kit/docs/review-loop.md`
  (the step 5 paragraph on `Human-Findings`), `kit/playbooks/sync.md` (the Trailers row), `docs/reference.md`, the
  `tiers.py` docstring.
- **Red rows:** each repo's profile adds a declared Guardrails section after its Evidence rows (append
  `\n## Guardrails\n…` to `ER`), so `routine` is labelled `none` at each parent.
  (a) `t13e15`, `ER` routine `| 90 | 3 | - | - | 10 |`, three docs commits without a trailer: want `routine: eligible`.
  Today it is `hold (Human-Findings on 0 of 3 merges)`, so `none` switches itself off. Then add a docs commit with
  `Human-Findings: 2`: want `breach (human-caught 100.0% > 10%)`, because a caught value still counts.
  (b) `t13e16`: three docs commits with `Human-Findings: 0`, then a profile commit that makes `routine` `spot`. Want
  `routine: hold (Human-Findings on 0 of 3 merges)`. Today it is `eligible`, counting the agent-written zeros.
- **Fix:** in the count, a commit labelled `none` whose trailer reads 0 counts as carrying no trailer. In the hold,
  skip `Human-Findings on k of n` when the tier's row (in the profile `evidence` read) says `none`. The rate test is
  unchanged. Docs: "a `none` merge carries no `Human-Findings:`; nobody writes it for the human".
- **Depends on:** task 1. Serial in lane A. Its doc edits are in other paragraphs than tasks 3, 11 and 12.

### Task 9: model family variants, repeated id lines (#11)

- **Touches:** `ready.family()`, `ready.check_review()`.
- **Red rows:** 11c, with `rv`/`rd`. Implementer `claude-sonnet-5-5` against reviewers `claude_opus_5_5`, `opus-5-5`
  and `anthropic:claude-opus`: each must warn `family`. Today none of them does. `gpt-5-1` must still not warn.
  Two `- implementer:` lines must be `not ready: review implementer repeated: one line per Review block`, exit 1.
  Today the last one wins silently.
- **Fix:** also drop a `vendor:` prefix (the same vendor list), split on `[-_.:@]`, and map bare names
  (`opus`, `sonnet`, `haiku`, `fable` to `claude`; `o1`, `o3`, `o4`, `codex` to `gpt`). Keep the shortcut comment,
  updated. In `check_review`, an `implementer`, `reviewer` or `rules` line already set is a problem, as a repeated
  `rounds:` is.
- **Depends on:** nothing. Parallel. Task 10 touches only `ready.main()`.

### Task 10: a readable reason for a profile that is not UTF-8 (#12)

- **Touches:** `tiers.profile_at()`, `tiers.main()` (`--check`), and the two `profile_at` calls in `ready.main()`.
- **Red rows:** "13c. evidence", new repo `t13e17`: append the bytes `\xff\xfe` to the profile and commit. `er` must
  exit 2 with `not UTF-8`; today the message is garbled, `…autonomy.md:u: t`. `tiers.py --check` on the same working
  tree must exit 2 with `autonomy.md: not UTF-8`; today it is a traceback, exit 1.
- **Fix:** `profile_at` runs without `text=True` and decodes the bytes as UTF-8. On `UnicodeDecodeError` it raises
  `ValueError(rel + " at " + base[:7] + ": not UTF-8")`. `--check` reads with `encoding="utf-8"` and catches
  `UnicodeDecodeError` before `ValueError`. `ready.main()` moves `rules = profile_at(…)` into the `try` that already
  refuses on `ValueError`, and `hrules` into its own `try`.
- **Depends on:** task 1 (it moves `evidence`'s read onto `profile_at` and catches the string error). Otherwise
  parallel.

## [REQ-V061-03] The `none` recipe holds on the platform

Tasks 11 and 12 change `kit/docs/review-loop.md` step 5 (the `none` items and the GitHub and GitLab bullets) and the
Enforced-by hint of template row 3 (`kit/templates/steering/autonomy.md`). They cannot be run on a live platform from
here.

- **What the selftest can check:** that the text says what was decided. Add one grep row in 14b, in task 12: the
  recipe names `--match-head-commit`, `commit_id`, `sha=`, `cancel-in-progress: false` and `resource_group`, and no
  longer offers `GITHUB_TOKEN` as the approver.
- **What it cannot check:** whether GitHub counts an approval whose `commit_id` is no longer the head, whether an
  environment secret is really out of reach of a `pull_request` run, whether GitLab's `sha` refuses a moved head on
  the version in use, whether `concurrency` or `resource_group` actually queue the jobs, and whether a trigger token
  can do anything else. Each repository verifies these when it declares row 3, with a date in Verified. The CHANGELOG
  keeps the "written from the platforms' documented settings, not run live" limit.

### Task 11: the approver identity is out of reach of the PR's jobs (#13)

- **Touches:** step 5's GitHub and GitLab bullets and item 3; the template row 3 hint.
- **Red row:** none of its own (see above).
- **Fix:** the GitHub bullet as decision 2 and the GitLab bullet as decision 3, each as a short ordered list of
  settings. Item 3 says the approver's credential is readable only by that job. Template row 3's hint becomes:
  "<the App or bot that approves, and where its key lives: a default-branch-only environment (GitHub) or a trusted
  project's protected variable (GitLab)>".
- **Depends on:** nothing. Serial with task 12 (same bullets).

### Task 12: approve and merge the checked sha only (#14)

- **Touches:** step 5 item 3 and the same two bullets.
- **Red row:** the 14b grep row above.
- **Fix:** decision 4, written into both bullets. Item 3 says the job passes the head sha it checked to every
  platform call, and that one job per PR runs at a time.
- **Depends on:** task 11.

## [REQ-V061-04] Refs resolve strictly

### Task 13: no symref to a `.../HEAD` ref; full ids at the repo's length (#15)

- **Touches:** `spec_lint.branch_ref()` (D1) and `tiers.end_commit()` (D2).
- **Red rows:** 13e, after C2, on an `xci` checkout. D1: a side chain of three docs commits on the source,
  `update-ref refs/remotes/up2/HEAD <side tip>` (plain) and
  `symbolic-ref refs/remotes/origin/HEAD refs/remotes/up2/HEAD`, with `merged_ref` null: `crd "$MB...HEAD" --auto-merge`
  must exit 1 with `auto-merge: no (human spot: evidence:`. Today it exits 0, `auto-merge: yes`. Assert only the
  prefix; task 14 adds the reason. D2: `update-ref refs/heads/<64 a's> <side tip>` in the SHA-1 checkout:
  `cl --range <64 a's>...HEAD` must exit 2 with `full commit id`. Today it resolves to the side tip.
- **Fix:** D1, one more clause: a symref whose target ends in `/HEAD` is refused with
  `<name> points at <target>, another HEAD ref`. D2, decision 6.
- **Depends on:** nothing. Lane F: before task 15 (same function).

### Task 14: a refused `origin/HEAD` fallback says why; v060's amendment (#16)

- **Touches:** `spec_lint.merged_ref()`; the 2026-11-24 amendment in v060's requirements.md (its evidence requirement).
- **Red rows:** the two 13e C1 rows change their expectation from `evidence: no merged_ref` to
  `evidence: refs/remotes/origin/HEAD is not a symbolic ref`. Task 13's D1 row gets `points at`. 5l: a repo with a plain
  `refs/remotes/origin/HEAD`, `merged_ref` null and `tracker_pattern` set must WARN
  `merged-work check skipped in .: refs/remotes/origin/HEAD is not a symbolic ref`. Today the lint is silent and logs HEAD.
- **Fix:** the fallback keeps `branch_ref`'s `why` and returns `(None, why)` (decision 9). Callers already handle a
  `why`. The amendment gains "the fallback counts only as a symbolic ref to a branch or remote-tracking ref that is not
  itself a `HEAD` ref" (D4). G4 checks the edit.
- **Depends on:** task 13 (its D1 message). Lane F, before task 15.

### Task 15: case-folded branch names (#17)

**Probe** (git 2.54, APFS, 2026-11-24). A bare server with `main` and `MAIN` (created through a reftable repo, so they
coexist). `c1` is a normal clone (refs packed); the agent then pushes a new `MAIN`, and `c1` fetches:

```
$ git -C c1 fetch -q origin; ls c1/.git/refs/remotes/origin
HEAD  MAIN
$ git -C c1 for-each-ref refs/remotes
c11fe3f… refs/remotes/origin/HEAD
c11fe3f… refs/remotes/origin/MAIN
0f93fcf… refs/remotes/origin/main        <- packed, the real main
$ git -C c1 rev-parse refs/remotes/origin/main
c11fe3f…                                  <- the loose MAIN file, opened case-insensitively
$ python3 -c '… spec_lint.branch_ref("c1", "origin/main")'
('refs/remotes/origin/main', None)        <- accepted; evidence then reads the agent's chain
```

In `c2` (`git init`, then `fetch origin`, the CI shape), the only listed name is `refs/remotes/origin/MAIN`, holding the
agent's sha. `origin/HEAD` is a symref to `refs/remotes/origin/main`, and `branch_ref` accepts it. The root cause is
that `branch_ref` checks names against the listing, while callers resolve them with `rev-parse`, which opens the loose
path. On a case-folding disk the two disagree. Explicit `merged_ref` values (`main`, `origin/main`,
`refs/remotes/origin/main`) are open in `c1`. Linux runners are not affected; macOS and Windows runners are.

- **Touches:** `spec_lint.branch_ref()`. Step 5 item 2 of `kit/docs/review-loop.md`: fetch `merged_ref` with an
  explicit refspec (`+refs/heads/main:refs/remotes/origin/main`), never the wildcard.
- **Red rows:** 13e, on an `xci` checkout, after `git pack-refs --all`. (a) `update-ref refs/remotes/origin/MAIN
  <side tip>`, which is loose next to the packed `main` on every disk, with `merged_ref` `"origin/main"`: the label must say
  `evidence: merged_ref origin/main differs only by case from refs/remotes/origin/MAIN` and `crd … --auto-merge` must exit 1.
  Today `origin/main` is accepted: on Linux the evidence reads the real `main`, on APFS the agent's chain. (b) Only when the disk folds case
  (`touch $TMP/ci-a; [ -e $TMP/CI-A ]`, otherwise print a skip line): the `c2` shape, with `merged_ref` null, must be
  refused the same way.
- **Fix:** decision 10. List every ref in the one `for-each-ref` call that is already made (no patterns), and keep the
  exact-name filter. For the hit (or its symref target), refuse when the target is not listed exactly or when another
  listed name has the same `unicodedata.normalize("NFC", n).casefold()`. Add
  `shortcut: one listed spelling holding another branch's sha is invisible locally; the recipe's explicit refspec closes it, probe the server with ls-remote if a job must fetch the wildcard`.
- **Depends on:** tasks 13 and 14 (same function, same rows). Its doc line goes after tasks 11 and 12 in step 5.

## [REQ-V061-05] Specter runs its own trust layer

### Task 17: specter's own autonomy profile (#24)

- **Touches:** a new `.specs/steering/autonomy.md`, built from `kit/templates/steering/autonomy.md`. Nothing in `kit/`.
- **Tiers**, strictest first. The first row that matches wins:
  - `trust`: `kit/scripts/*`, `install.sh`, `tests/*`, `.github/*`, `.specs/steering/*`. Reviewer deep, Human required.
  - `kit`: `kit/*`, `AGENTS.md`, `GO.md`. Reviewer standard, Human required.
  - `docs`: `docs/*`, `README.md`, `CHANGELOG.md`, `examples/*`, `.specs/features/*`. Reviewer standard, Human spot.
- **Guardrails:** only rows that are true today. Gates in CI arrive with task 18, so date that row then. Branch
  protection is not set on `main`, so leave its row as a placeholder with a note.
- **Evidence:** thresholds stay `<placeholder>` (hold), because no tier asks for `none`.
- **Check:** `tiers.py --check` exits 0, and `tiers.py --range origin/main...HEAD` labels this branch `trust`. Add one
  selftest row only if the profile surfaces a kit bug.

### Task 18: gates run locally before every push; CI only with Nikos's OK (#25)

- **Local first (Nikos, 2026-11-24).**
  - A new `tests/gates.sh` runs G1 to G4 in order. It prints `G<n> rc=<rc>` per gate and exits non-zero on the first
    failure, so nobody judges a gate through a pipe again.
  - `.githooks/pre-push` calls it. It is enabled per clone with `git config core.hooksPath .githooks`, documented in
    AGENTS.md "Working on specter itself".
  - A push that skips the hook (`--no-verify`) is the developer's call. The hook is a habit, not a guardrail.
- **The Guardrails row** reads "Gates run before every push (local hook)". It is dated, and its enforcement column
  says plainly that it is local and can be skipped.
- **CI comes later, only on Nikos's OK.** On a public repo, GitHub-hosted runners cost nothing and use no minutes, but
  Nikos wants the work done locally first. If it is added later: `.github/workflows/gates.yml` with
  `on: pull_request` to `main` only, `permissions: contents: read`, a pinned checkout sha,
  `persist-credentials: false`, `concurrency` with `cancel-in-progress: true`, `ubuntu-latest`, and no secrets.
  A Linux run would also prove that task 15's case-fold rows don't depend on macOS. Until then, run them once in a
  local Linux container (`docker run --rm -v "$PWD":/s -w /s python:3.12 sh tests/gates.sh`).
- **Check:** `sh tests/gates.sh` exits 0. A push with a broken G4 (a bad cite in a scratch commit) is refused by the
  hook.

### Task 19: the release PR carries its own readiness verdict (#26)

- **Touches:** the 0.10.0 PR body only. It gets `### Gates` (G1 to G4 with rc), `### Review` (`implementer:`,
  `reviewer:` with tier, `rules:`, `rounds:`) and `### Verification`.
- **Check:** `ready.py --range <base sha>...<head sha> --pr <body file>` prints `verdict: ready` and `human: required`.
  Paste the output into the PR as a comment. Runs after task 16's deep review, before the merge.

## [REQ-V061-06] The README shows what specter does

### Task 20: README along Story, How, Output, Worth (#27)

- **Touches:** `README.md`. Also `docs/overview/roadmap.svg`, `deck/slides.md` and the HTML deck, which still say
  0.9.0 is planned. Detail moves to `docs/reference.md`, nothing is deleted.
- **Story:** keep the first paragraph, the citation problem. Add one paragraph: since 0.7, specter also labels each
  change by risk and decides when a human must look.
- **How:** `docs/overview/workflow.svg` and `trust-layer.svg`. A **Decisions** list: markdown and stdlib only (no
  service, no lock-in); citations checked by a lint, not by trust; risk read from paths and the base commit, never
  the change itself; no orchestrator or merge bot in the kit; `none` earned from merged history.
- **Output:** the 2-minute demo stays first. Add the `tiers`, `ready` and `evidence` screenshots from
  `docs/overview/screenshots/`.
- **Worth:** only measured or checkable claims. The setup-model comparison moves up from the FAQ. The trust layer
  took five deep reviews and each found a way to reach `none` without a human (link `docs/reviews/`). Tests: the
  selftest, its row count, and the CI badge.
- **Test reader:** a fresh-context reviewer sees only the rendered README and answers three questions: what it does,
  for whom, how it is tested. Fix any gap. Then run a humanizer pass.
- **Overview kept current:** add a fast check to `tests/gates.sh`, with no extra process per row. It fails when `docs/overview/deck/specter-overview.html` or `roadmap.svg` does not name the version in `VERSION`. It runs only when `VERSION` changed against `origin/main`, so day-to-day pushes are not blocked.
- **Not here:** pinning repos on the GitHub profile is Nikos's call, outside this repo.

## [REQ-V061-07] Bypasses are reported privately

### Task 21: SECURITY.md (#28)

- **Touches:** a new `SECURITY.md` at the repo root (GitHub shows it on the Security tab), plus one line in
  `kit/docs/review-loop.md` step 5: a finding that bypasses the human check goes to a draft advisory.
- **Content, short:** supported version (the latest release); report privately via Security → Report a
  vulnerability; what counts (any path to `human: none`, `auto-merge: yes` or a faked evidence verdict); response
  target; past findings are public in `docs/reviews/` because `none` was never on.
- **Nikos:** enable private vulnerability reporting in the repo settings. The lead can do it with
  `gh api -X PUT repos/<owner>/<repo>/private-vulnerability-reporting`, with his OK.
- **Check:** G1 to G4. The link from the README lands with task 20.

## [REQ-V061-08] The selftest is fast and deterministic

### Task 22: a faster, deterministic selftest (#29)

- **Runs alone**, between batches. It touches the whole of `tests/selftest.sh`, which every other task edits.
- **Measure first.** Print the elapsed seconds after each `echo "<n>. …"` section header, and record the top five
  sections in the commit body. Optimize only those.
- **Likely wins, confirmed by the timings:**
  - Build each repeated fixture repo once and `cp -R` it, instead of `git init` plus commits every time.
  - Share installer runs where a section only reads the result.
- **`SELFTEST_ONLY`:** a space-separated list of section ids. Sections it doesn't name are skipped, after the shared
  setup at the top. A section that depends on an earlier one names it, so the dependency runs as well.
- **Determinism:**
  - Replace `date +%s%N` fixture content with a counter.
  - Export `TZ=UTC` and `LC_ALL=C`.
  - Add `GIT_CONFIG_GLOBAL=/dev/null` beside the existing `HOME` and `GIT_CONFIG_NOSYSTEM`.
  - Leave the evidence "now" as the real clock. A test-only clock override in `tiers.py` would be a knob that moves
    evidence windows, so `shortcut:` record the midnight edge instead.
- **No weakened assertion:** every `fail` line keeps its condition.
- **Proof:** check out the parents of tasks 1, 2, 9 and 13 in turn (`git revert --no-commit` of each fix into a
  scratch worktree). The new selftest must fail on each one at the same row.
- **Check:** G1 to G4, and the before and after wall time on the same idle machine.

## [REQ-V061-09] Human `none` only for small changes the reviewer calls trivial

### Task 23: size cap, tests only grow, reviewer complexity (#30)

- **Why:** a tier is chosen by path, so a 2,000-line change inside a `none` path could merge with no human. Size is
  the mechanical stand-in for "trivial". The reviewer's judgment comes on top, and the planner, generator and reviewer
  loop is unchanged. Each check only takes `none` away.
- **Profile:** `## Evidence` gets two optional columns, `Max files` and `Max lines`. When they're missing or `-`, the
  defaults 3 and 50 apply. Test globs come from a new optional `## Tests` section of path globs, defaulting to
  `tests/*`, `test/*`, `*/test/*`, `*_test.*`, `*.test.*` and `test_*`. Both are read from the profile at the base,
  like the Tiers table (`earned()`).
- **`tiers.py`:** in the `none` branch of the label, after `earned()`, run `git diff --numstat <base> <head>` once.
  - More files or lines than the cap gives `size <f> files / <l> lines > cap <F>/<L>`.
  - Any deleted line in a test-glob file gives `tests changed, not only added: <path>`.
  - A binary file in numstat (`-`) counts as over the cap.
- **`ready.py`:** `check_review()` reads `- complexity: trivial|non-trivial`. With Human `none`, anything other than
  `trivial` gives `reviewer: complexity <value>` in `human_why`. A repeated `complexity:` line is not ready, as the
  other id lines are (task 9).
- **Docs:** `kit/roles/reviewer.md` adds one line. The reviewer writes `complexity: trivial` only for a change a
  reader understands in one pass, with no new branch, no new dependency, and no changed contract. Also update
  `kit/templates/steering/autonomy.md`, `docs/reference.md` and `kit/docs/review-loop.md` step 5.
- **Red rows, in 13c2 on fixture `t13e18`:**
  - a `none`-eligible change of 4 files must give `spot (size`;
  - one deleted line in `tests/x_test.py` must give `spot (tests changed`;
  - `complexity: non-trivial` must make `ready.py --auto-merge` exit 1;
  - a change within the cap, adding tests only, with `complexity: trivial`, must stay `none`.
- **Lane:** after task 8, on `tiers.py`'s `none` branch, and after task 9, on `check_review()`. It runs in a later
  batch.

## [REQ-V061-10] Specter learns from its own mistakes

### Task 24: lessons loop and the parallel-dispatch playbook (#32)

- **Touches:**
  - a new `.specs/steering/lessons.md`, from `kit/templates/steering/lessons.md`;
  - a new `kit/playbooks/parallel.md`;
  - one retro step in `kit/docs/review-loop.md`;
  - the playbook list in `kit/rules` or AGENTS markers, wherever playbooks are listed today;
  - `docs/reference.md`.
- **Lessons:** seed `lessons.md` with the eight from 2026-11-24. Each line names the check that now catches it.
  - a gate rc masked by `| tail` → `tests/gates.sh` (task 18);
  - worktrees started on `main` → the playbook's base check;
  - a stray `__pycache__` → `PYTHONDONTWRITEBYTECODE`;
  - a shared `$TMPDIR` → `mktemp`;
  - leftover selftests → the playbook's stop step;
  - an unchecked cherry-pick rc → the playbook's landing step;
  - a task line dropped in a conflict → a task-line count check;
  - "continue" starting GO → the AGENTS.md exception.
  - Also record the corporate-scanner cost: run the gates in Docker and launch fewer processes.
- **Playbook:** about one page, agent-neutral. It covers:
  - batches of at most 3 agents, grouped by the functions they touch;
  - the worktree base check;
  - unique temp files;
  - red first, with the full selftest run once;
  - landing with `cherry-pick` and checking its rc;
  - G1 to G4 once on the tip;
  - stopping leftover runs;
  - closing issues and updating the Resume block.
- **Safety:** the playbook and the lessons file sit on specter's own `trust` tier (task 17). An agent proposes a
  rule change and a human approves it.
- **Check:** G1 to G4. Run `spec_lint` on the new playbook if playbooks are linted.

### Task 25: the lessons ship in the kit (#34)

- **Why:** specter runs on other projects. A lesson fixed only in specter's `tests/` or `.specs/` helps only specter.
- **Container gates:**
  - `kit/playbooks/setup.md` adds one ask-if-unclear question: does this machine inspect every process launch
    (endpoint security)?
  - On yes, step 6 writes heavy Gates rows wrapped in `docker run --rm --memory 2g -v "$PWD":/src:ro <image>`, which
    copy `/src` to the container's `/tmp` first. It adds a note that some runtimes (Colima, for example) share only
    `$HOME`, so a clone elsewhere mounts empty.
  - `kit/templates/steering/spec-rules.md` gets the same note as a comment by the Gates table.
- **Mount check:** in `tests/gates.sh --docker`, the container's first command refuses with
  `gates: /src is empty (does your container runtime share this path?)` and exit 2 when `/src/tests/gates.sh` is
  missing. This is the lesson's source, and specter's own pre-push hook relies on it.
- **Playbook:** `kit/playbooks/parallel.md` says "the project's Gates (in a container where scanners slow the host)"
  where it now says specter's `tests/gates.sh --docker`.
- **Resume:**
  - `kit/playbooks/next-task.md` says that "pick up and continue", "resume" or "continue" means: read the
    `▶ Resume here` block, and the pinned plan issue when the project has a tracker, then run the next task.
  - `kit/templates/feature/tasks.md` names the pinned plan issue in its Resume hint.
- **Advisories:** `kit/templates/SECURITY.md`, adapted from specter's own with placeholders for the channel and what
  counts. `setup.md` offers it when the repository is public and has no `SECURITY.md`. The installer copies
  templates as a tree, so no list changes.
- **Check:**
  - one 14b-style grep row in the selftest, which checks that `setup.md` names the container wrap and the empty-mount
    note;
  - one row that runs `gates.sh --docker` against an empty mount dir, only when Docker is up, and otherwise prints
    "skipped" as 13e E2 does. Skip it in the selftest if Docker is not reachable from inside the gates container,
    and say so;
  - G1 to G4.
- **Lane:** docs and `tests/gates.sh`. No conflict with tasks 23 and 26.

### Task 26: a README check any project can run (#36)

- **Why:** specter's README gate is a lesson too, but `tests/readme_check.py` is specter-only.
- **`kit/scripts/readme_check.py`:** stdlib, one process, one line per check, exit 1 on any FAIL and 2 on a bad
  argument. It checks:
  - links, images and anchors resolve (C1);
  - every image has alt text (C2);
  - a line cap (C13);
  - required section headings, in order (C7);
  - a denylist of words (C17).
- **Config:** settings come from `spec-kit.json` key `readme`: `path`, `max_lines`, `sections`, `deny`. Defaults:
  `README.md`, 200, no required sections, an empty denylist. A missing key means defaults; a wrong type exits 2.
- **Specter:** `tests/readme_check.py` keeps C4, C5, C9, C11, C12 and C15, and calls the kit script's functions for
  the rest, so the output lines stay the same.
- **Docs:** `docs/reference.md` and `kit/docs/chores.md` offer it as a Gates row or a scheduled chore.
- **Check:** selftest rows on a fixture README:
  - a broken link fails;
  - a missing alt text fails;
  - a clean one passes;
  - a bad config type exits 2.
  - Then G1 to G4.
- **Lane:** new files plus `tests/readme_check.py`. Independent of tasks 23 and 25.

## Fix round from the 0.10.0 deep review

The report is `docs/reviews/2026-11-25-v061-deep-review.md`. Finding 1 is handled privately (SECURITY.md). Findings 3
(the byte cap), 4 and 5 move to 0.11.

### Task 27: Human `none` only on a current base (finding 1)

- **Touches:**
  - `tiers.classify()` or `tiers.earned()`, in range mode;
  - `ready.py` through the same label;
  - `kit/docs/review-loop.md` step 5 item 2;
  - `docs/reference.md`.
- **Fix:** Human `none` is kept only when the base the label reads equals the tip of `merged_ref` (the commit that
  `--evidence` reads). Otherwise the label says `- human: none → spot (base <sha7> is behind <ref>: update the branch)`.
  The recipe says the job's `<base sha>` is the `merged_ref` tip and must equal the merge base. If no `merged_ref`
  resolves, the label already fails closed. Staged mode is a preflight and keeps its base.
- **Red row:** in 13e, on fixture `t13e22`. The trunk gets a revert and then a profile commit that makes routine
  `spot`. A PR branched before that commit must give `spot (base`, and `ready.py --auto-merge` must exit 1. A PR from
  the tip stays as it is today.

### Task 28: the test and size checks fail closed (findings 2, 3 in part, 10)

- **Touches:** `tiers.small()`, `TESTS`, `kit/templates/steering/autonomy.md`, and 13c2 rows `t23`.
- **Fix:**
  - also read `git diff --raw -z --no-renames`. Each of these gives `tests changed, not only added`:
    - a deleted test file;
    - a mode or type change on a test file;
    - an added or changed `conftest.py` or `__init__.py`.
  - A gitlink (mode `160000`) counts as over the cap.
  - Widen the default test globs so that an unknown layout counts as a test: `*test*`, `*spec*`, `conftest.py`,
    matched with `tiers.key()`'s fold.
  - The template drops `<lockfile>` from the `none` row, and says that an added line can still disable a test, so
    the reviewer's `complexity:` remains the backstop.
- **Red rows:**
  - a deleted empty test file;
  - a `chmod` on a test file;
  - `pkg/tests/test_a.py` edited;
  - a binary file in `docs/`;
  - a custom `## Tests` glob;
  - a staged change of four files.
  - Also reword the 13e18 row text.

### Task 29: grafts and the NTFS fold (findings 6, 7)

- **Touches:** the `tiers.py` import block (next to task 7), and `spec_lint.branch_ref()` `fold`.
- **Fix:**
  - set `os.environ["GIT_GRAFT_FILE"]` to a path that never exists;
  - `branch_ref` uses `tiers.key()`'s fold, which is NFC, casefold and upper. Move the fold into `spec_lint` and
    import it in `tiers`.
- **Red rows:**
  - a grafts file that hides a revert must still give `breach` (13c3, `t13e23`);
  - `maın` against `main` must be a twin (13e, a Python one-liner).

### Task 30: the gates cannot go green without running (findings 8, 9)

- **Touches:**
  - `.githooks/pre-push`;
  - `tests/gates.sh`;
  - the `tests/selftest.sh` `sect` filter;
  - `kit/docs/review-loop.md` step 5 items 2 and 3 and GitHub bullet 3.
- **Fix:**
  - The hook unsets `SELFTEST_ONLY`, and refuses with exit 1 and a reason when the tree has uncommitted or untracked
    changes.
  - `gates.sh --only` with an unknown gate exits 2.
  - When `SELFTEST_ONLY` is set, `gates.sh` prints `G3 PARTIAL (SELFTEST_ONLY=…)` and exits 1.
  - `selftest.sh` exits 2 when `SELFTEST_ONLY` names no known section.
  - Drop the stale G2 comment.
  - The recipe says to fetch full history with the explicit refspec (`--unshallow`, or `fetch-depth: 0` with the
    refspec overridden). Item 2 names all five `none` conditions.
- **Check:**
  - G1 to G4;
  - a scratch run that shows each refusal, from a clone under `$HOME`.

### Task 31: second-review fixes (#41)

The second review (2026-11-25) found no blocker, but these need fixing before the release:

- **A1, `TESTS` too wide:** drop the bare `*spec*` and `*test*`. Use `tests/*`, `*/tests/*`, `test/*`, `*/test/*`,
  `__tests__/*`, `*/__tests__/*`, `spec/*`, `*/spec/*`, `*_test.*`, `*.test.*`, `*_spec.*`, `*.spec.*`, `test_*`,
  `*/test_*`, `conftest.py`, `*/conftest.py`. The rows to add:
  - ticking a box in `.specs/features/f/tasks.md` keeps `none`;
  - editing `docs/latest.md` keeps `none`;
  - editing `pkg/tests/test_a.py` is still `spot`.
- **A2, git variables leak into fixtures:** `selftest.sh` unsets `GIT_DIR`, `GIT_WORK_TREE`, `GIT_INDEX_FILE`,
  `GIT_PREFIX` and `GIT_COMMON_DIR` next to its `GIT_CONFIG_*` exports.
- **A3, the hook checks the wrong commits:** the hook reads its stdin and refuses (exit 1) when a pushed local sha that
  is not all zeros differs from `HEAD`.
- **A4, untracked files hidden by config:** the hook uses `git status --porcelain --untracked-files=normal`.
- **A5, blank `SELFTEST_ONLY`:** a value that is only whitespace exits 2, as an unknown name does.
- **A6, the recipe's fetch:** it runs `--unshallow` only when `git rev-parse --is-shallow-repository` prints `true`,
  and it adds the platform setting "require branches to be up to date".
- **A8:** remove the unused `import unicodedata` from `tiers.py`.
- **A7, commit-graph parents:** moves to #40.

## Task 16: gates, deep review, CHANGELOG, release (#18)

After tasks 1 to 15 are merged into `feat/0.10.0`: G1 to G4, plus G5 only if a task touched `examples/acme-shop/` outside
`.specs/` (none plans to). Then a deep review of `main..feat/0.10.0` with the probes above re-run, and the CHANGELOG
0.10.0 entry: Security bullets for tasks 7, 13 and 15, the Known limits list rewritten (the v061 items closed, the
"not run live" recipe limit kept, the task 5 and task 15 shortcuts added), and the version bump.

- **Release step, from 0.10.0 on:** refresh `docs/overview/` for the new version.
  - Update the version line in `deck/specter-overview.html` and `deck/slides.md`, and the stage boxes in `roadmap.svg`.
  - Re-capture any screenshot whose command output changed.
  - Re-export the PDF.
  - The fast check in `tests/gates.sh` (task 20) refuses a release whose overview still names an older version.

## Parallel lanes

Tasks 17 to 22: 22 alone first, then 17, 18 and 21, then 20; 19 last, on the release PR. Task 18 adds `tests/gates.sh` and a
Guardrails row in task 17's profile; task 20 owns `README.md`.


Lanes run in parallel. Tasks inside a lane run in order, one merged before the next starts.

| Lane | Files and functions | Tasks, in order |
|---|---|---|
| A evidence | `tiers.evidence()` (and `classify()`'s return for task 4); "13c. evidence" rows | 1 → 6 → 5 → 4 → 8 |
| B sections | `tiers.section()`, `tiers.guarded_globs()`; 13c rows | 2 |
| C replace | `tiers.py` import block; one "13c. evidence" row | 7 |
| D decoding | `tiers.profile_at()`, `tiers.main()`, `ready.main()` | 10 (after task 1) |
| E families | `ready.family()`, `ready.check_review()`; 11c rows | 9 |
| F refs | `spec_lint.branch_ref()`, `spec_lint.merged_ref()`, `tiers.end_commit()`, v060 requirements; 13e and 5l rows | 13 → 14 → 15 |
| G docs | `kit/docs/review-loop.md` step 5, template row 3, `sync.md`, `docs/reference.md`; 14b row | 3 (any time); 11 → 12 |
| H release | everything | 16, last |

All lanes add rows to `tests/selftest.sh`, in different blocks or under their own repo names, so a rebase is a
textual merge. When two lanes edit the same doc file, they edit different paragraphs: task 3 and task 8 (`sync.md`,
`reference.md`), and tasks 8, 11, 12 and 15 (`review-loop.md` step 5).

## Rollout / rollback

Every task adds a refusal or a stricter count. None turns `spot`, `required` or exit 1 into `none` or exit 0. The
exception is decision 1's hold skip: it applies only to a tier whose row is already `none`, and it brings back the
behaviour 0.9.0 intended. Rollback is a revert of the task's commit. No data or config format changes: the profile
tables, the trailers and `spec-kit.json` read as in 0.9.0.
