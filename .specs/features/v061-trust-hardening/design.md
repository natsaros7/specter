# v061 Trust-layer hardening — Design

Security-sensitive: every task changes what can earn `human: none` or `auto-merge: yes`. Review on the deep tier.
Stdlib only, Python 3.8+, offline, no new dependency. Each task names its source row in `docs/reviews/`; the row has
the probe. One task per dispatch (tasks 1 to 16 are issues #3 to #18; tasks 17 to 20 are issues #24 to #27; task 21 is #28), red first: add the selftest row, run `sh tests/selftest.sh`,
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
  first-parent sha below the cut, move the cut down to it, build the log entries in between, and repeat until it stops
  moving. It only ever moves down, so it ends. Each tier's cut follows the same rule inside its own window; windows
  nest, so the longest cut still bounds them. `shortcut: names are matched against first-parent shas only; a branch
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

### Task 18: gates in GitHub Actions (#25)

- **Touches:** a new `.github/workflows/gates.yml`. `on: pull_request` and `push` to `main`. `permissions: contents:
  read`. `actions/checkout` pinned to a full commit sha, with `persist-credentials: false`. One job on
  `ubuntu-latest` that runs G1, G2, G3 and G4 as separate steps, with no secrets. G5 is left out: it needs a JDK and
  the network, and stays optional as AGENTS.md says.
- Add a README badge for the workflow, and the Guardrails row "Gates run on every PR" with its date.
- **Check:** the workflow runs green on the 0.10.0 PR. A Linux run also proves the selftest does not depend on macOS.
  Task 15's case-fold rows must pass there.

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

## Task 16: gates, deep review, CHANGELOG, release (#18)

After tasks 1 to 15 are merged into `feat/0.10.0`: G1 to G4, plus G5 only if a task touched `examples/acme-shop/` outside
`.specs/` (none plans to). Then a deep review of `main..feat/0.10.0` with the probes above re-run, and the CHANGELOG
0.10.0 entry: Security bullets for tasks 7, 13 and 15, the Known limits list rewritten (the v061 items closed, the
"not run live" recipe limit kept, the task 5 and task 15 shortcuts added), and the version bump.

## Parallel lanes

Tasks 17 to 20: 17, then 18, then 20; 19 last, on the release PR. They touch no file of lanes A to G except
`README.md` (task 18's badge, task 20) and task 18's Guardrails row in task 17's profile.


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
