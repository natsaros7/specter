# v070 Live recipe, deep-review follow-ups and the acme eval set — Design

Security-sensitive: tasks 13 to 16 change what can earn `human: none` or `auto-merge: yes`, and the recipe is what
merges with no human. Review them on the deep tier, red first. Stdlib only, Python 3.8+, no new dependency.

| Requirement | Source |
|---|---|
| [REQ-V070-01] | CHANGELOG 0.10.0 Known limits ("not run live"); v061's design, "What it cannot check" under its platform requirement; Nikos, 2026-11-25 |
| [REQ-V070-02] | #40; deep review 2026-11-25 finding 3 |
| [REQ-V070-03] | #40; finding 4 |
| [REQ-V070-04] | #40; finding 5 |
| [REQ-V070-05] | #40 comment 1 (second review A7) |
| [REQ-V070-06] | #40 comment 2 (release run, 2026-11-25) |
| [REQ-V070-07] | #35; Nikos: never Maven on the host |
| [REQ-V070-08] | #35 |
| [REQ-V070-09] | v061 close-out: AGENTS.md still names `--label v061` |

## Rules for every worker

- **Who acts on GitHub.** A task marked **Nikos** acts on GitHub: it creates something, pushes, opens a PR or changes a
  setting. Nikos runs it, or he OKs an agent running it in that session. An agent never does such a step on its own.
  Agents may run read-only `gh` calls (`gh pr view`, `gh run view`, `gh api` GET).
- **Red first.** For tasks 13 to 16, add the row, run `SELFTEST_ONLY=<section> sh tests/gates.sh --docker --only G3`,
  and see it fail for the stated reason. A partial run prints `G3 PARTIAL` and exits 1, which is expected here. Then
  fix, then run the full `sh tests/gates.sh --docker`.
- **Fixture names**, so parallel branches never collide: new `--evidence` repos are `t13e24` (task 14), `t13e25`
  (task 15) and `t13e26` (task 16), built with the "13c. evidence" `nr` helper. Size rows go in 13c2 on fixture `t70b`
  (task 13).
- **Messages keep their forms:** `- human: none → spot (<why>)`, `auto-merge: no (<why>)`, `tiers: <why>` with exit 2.
- **No CHANGELOG edit per task.** Task 22 writes 0.11.0. Each task updates the docstring, `docs/reference.md` and the
  playbook lines that describe what it changes.
- **Gates in Docker** (`sh tests/gates.sh --docker`), `PYTHONDONTWRITEBYTECODE=1`, temp files from `mktemp` under
  `$HOME` (Colima shares only `$HOME`), no polling loops, one gate run on the batch tip (`kit/playbooks/parallel.md`).
- **Specs:** never cite a line number in backticks (G4 checks citations); name the function. Never write another
  feature's REQ id: name the requirement in words.
- **A bypass found while working** (any path to `none` or `auto-merge: yes` without a human) goes to a draft advisory
  (`SECURITY.md`), not to an issue or a review doc.

## Decisions

Rows 1 to 9 are proposals that task 1 confirms (requirements.md, Open decisions). The rest follow from them.

| # | Decision | Chosen (proposed) | Trade-off |
|---|---|---|---|
| 1 | Ship the workflow | `kit/templates/github/specter-auto-merge.yml`, the file the live test runs, minus the sandbox-only delay step. It gets a `Verified:` header line on a pass | One more template. The installer copies templates as a tree, so `install.sh` does not change. If declined, the file lives in `tests/live/github/` and only the prose ships |
| 2 | Byte cap | Optional `Max bytes` Evidence column after `Max lines`, default 4000. The bytes are the content of `+` and `-` lines inside hunks, from one `git diff -U0` | One more git call in `small()`. Blob sizes would be fewer bytes to read but wrong: a one-line edit in a 100 KB file would be over the cap |
| 3 | Evidence key | Equality of the rows from the tier down to the last row (name and sorted globs), plus the sorted Knowledge-guarded globs | Fail-closed and short. Cost: any edit to a stricter row restarts the lower tiers, including edits that only narrow them |
| 4 | Commit-graph off | Append `core.commitGraph=false` through `GIT_CONFIG_COUNT`, `GIT_CONFIG_KEY_<n>` and `GIT_CONFIG_VALUE_<n>`, after any pairs the caller already set | Documented interface. git before 2.31 ignores it, recorded as a `shortcut:` |
| 5 | Squash message | The job merges with `--subject "<title> (#<n>)" --body-file <the PR text it checked>` | The merged commit carries exactly what `ready.py` read: its `Fixes:` lines stay, and an edit after the check cannot add a trailer |
| 6 | JDK image | `azul/zulu-openjdk-alpine:21`. Fall back to `azul/zulu-openjdk:21` if task 18's probe shows protoc failing on musl | Both images are local. `apk add gcompat` would need network in every fresh container |
| 7 | Eval goals | E1 S1, E2 S2, E3 S6, E4 S7, E5 S5 | They reuse seeds and acceptance that already exist, so nothing new is planted. A docs-only goal adds no new tier |
| 8 | Sandbox | Public repository under Nikos's account, interaction limit "collaborators only" while the test runs, archived after | Free minutes. Public because `none` is off everywhere, so a failure exposes nobody. This supersedes the "private" in v061's decision 11 |
| 9 | Resume | AGENTS.md: read the in-progress feature's Resume block, which names the plan issue; that issue is pinned | No label convention to keep up |
| 10 | Refusal shape (task 14) | A warning in every mode, checked on the raw PR text before `visible()` drops comments: a trailer inside an HTML comment still lands in the squash body | `spot` PRs get a warning too. That is right: the human writes the trailer at the merge, never the agent |
| 11 | Order of the live run | Setup (tasks 3 to 5) any time. The seed push (task 6) installs the `feat/0.11.0` tip after batch 3, so the live run exercises the candidate's `ready.py`. The report names that sha | The run waits for batch 3. In return, "verified" means this release, not 0.10.0 |
| 12 | Scenario order | The key probe first, then the cases that must not merge, then the merging ones | If the key is reachable, everything stops before an approval can happen |

## [REQ-V070-01] The GitHub `none` recipe is verified live

### What the sandbox holds

`tests/live/github/sandbox.sh seed <dir>` builds it locally, with no network. `<dir>` must be under `$HOME`.

| Path in the sandbox | Content |
|---|---|
| `.specs/kit/` | `install.sh` from the specter tip named in the report |
| `.specs/spec-kit.json` | `merged_ref: "refs/remotes/origin/main"` |
| `.specs/steering/spec-rules.md` | One Gates row: G1 `python3 .specs/kit/scripts/spec_lint.py` |
| `.specs/steering/autonomy.md` | Tiers: `routine` `docs/*` (standard, none) and `critical` `.github/*` (deep, required). All eight Guardrails rows, each stating what enforces it in the sandbox, dated on the setup day in task 6. Evidence: `routine` `\| 90 \| 2 \| 50 \| 50 \| - \|`, size defaults |
| `.github/workflows/gates.yml` | `pull_request` to `main`. `permissions: contents: read`, checkout pinned by sha with `persist-credentials: false`, runs G1, `timeout-minutes: 5`, `concurrency` with `cancel-in-progress: true`. Sandbox-only: sleeps 60 s when the head branch starts with `slow/` |
| `.github/workflows/specter-auto-merge.yml` | The template (decision 1). Sandbox-only: one step sleeps `vars.SANDBOX_DELAY` seconds (default 0) between `ready.py` and the approval |
| `docs/seed-1.md`, `docs/seed-2.md` | Two routine commits, so `routine` has its 2 merges and is `eligible` |

The template workflow, in order:

1. Triggers and limits. `on: pull_request_target`, types opened, synchronize, reopened, edited and
   ready_for_review, branches `main`. `permissions: contents: read, pull-requests: read`. `concurrency:
   specter-auto-merge-<pr number>` with `cancel-in-progress: false`. One job with `environment: specter-approver`
   and `timeout-minutes: 5`, skipped for drafts.
2. Checkout. Check out the base with `persist-credentials: false`, and fetch
   `+refs/heads/main:refs/remotes/origin/main <head sha>` with `--no-tags`, adding `--unshallow` only when
   `git rev-parse --is-shallow-repository` prints `true`.
3. Inputs as data. The PR body and title come in through `env:`, never `${{ }}` in a script, and the body is written
   to `$RUNNER_TEMP/pr.md`.
4. The check. `<base sha>` is `git rev-parse refs/remotes/origin/main`. The job runs `python3
   .specs/kit/scripts/ready.py --specs .specs --range <base sha>...<head sha> --pr $RUNNER_TEMP/pr.md --auto-merge`
   from the base checkout. It prints the output and records the rc. A non-zero rc ends the job green, having done
   nothing.
5. On rc 0 only:
   - Mint the App token with `actions/create-github-app-token`, pinned by sha, from `vars.SPECTER_APP_ID` and
     `secrets.SPECTER_APP_KEY`.
   - Approve through `POST …/pulls/<n>/reviews` with `event=APPROVE` and `commit_id=<head sha>`, and keep the review id.
   - Merge with `gh pr merge <n> --auto --squash --match-head-commit <head sha> --subject … --body-file
     $RUNNER_TEMP/pr.md` (decision 5).
   - Read the head again. If it moved, dismiss that review and run `gh pr merge <n> --disable-auto`.

Look the action shas up with a read-only `gh api …/git/ref/tags/<tag>` when the file is written.

### Scenarios

`sandbox.sh open <dir> <id>` makes each PR. It branches from `origin/main`, makes the change, commits, writes the
Gates block from `gates.py` and the Review block, pushes, and runs `gh pr create --body-file`. This is a Nikos step.
`sandbox.sh dry-run <dir>` runs every scenario's `ready.py` call against a local bare origin, with no network. It
checks the "ready.py says" column, and task 2 must pass it before any minute is spent.

All reads below are read-only. `pr N` is `gh pr view N --json state,reviews,autoMergeRequest,headRefOid,mergeCommit`;
`log` is `gh run view <run> --log`; `body` is `git log -1 --format=%B origin/main` after a fetch.

| Id | Setup | ready.py says | Expected on GitHub | Observed by |
|---|---|---|---|---|
| K1 | The PR adds `.github/workflows/probe.yml` with three `pull_request` jobs. (a) No environment, prints only the length of `secrets.SPECTER_APP_KEY`. (b) `environment: specter-approver`. (c) `gh pr review --approve` with `GITHUB_TOKEN` | `human required` (`.github/*`): `auto-merge: no` | (a) prints `0`. (b) fails before any step, because the branch may not deploy to the environment. (c) is refused. Not approved, not merged | `log` for (a) and (c); `gh run view --json jobs` for (b); `pr N`. **If (a) prints anything but 0: stop, run task 12 now, open a draft advisory** |
| N1 | 4 files in `docs/`, one line each | `spot (size 4 files …)` | No App review, PR open | `log`, `pr N` |
| N2 | 1 docs line, `complexity: non-trivial` | `spot (reviewer: complexity non-trivial)` | Same as N1 | `log`, `pr N` |
| N3 | 1 docs line, reviewer `claude-opus-5-5` against implementer `claude-sonnet-5-5` | `spot (same family)` | Same as N1 | `log`, `pr N` |
| P1 | 1 docs line, reviewer `gpt-5-1` (standard), `rounds: 1`, `complexity: trivial` | `auto-merge: yes` | The App's review is APPROVED on the head sha, auto-merge is on, the Gates pass, and the PR is squash-merged. The merged body is the checked text, with no `Human-Findings:` | `pr N` (the review author is the App's bot, its commit id is the head), `body` |
| N4 | Branch made from `main` before P1 merges, opened after | `spot (base <sha7> is behind refs/remotes/origin/main: update the branch)` | Not approved. Optional, two more jobs: "Update branch", after which the job approves and the PR merges | `log`, `pr N` |
| N5 | Branch `slow/…`, eligible. After the App approves, Nikos pushes a commit that adds 4 docs files | 1st run `yes`, 2nd `spot (size …)` | The approval is dismissed as stale, the 2nd run does nothing, and the PR is not merged | `gh api …/issues/<n>/timeline` (`review_dismissed`), `pr N` |
| N6 | Repo variable `SANDBOX_DELAY=30`. Eligible PR; during the job's sleep, Nikos pushes an over-cap commit | 1st `yes` (old head), 2nd `spot` | Not merged. The report records which line caught it: the approval on an old commit id not counting, `--match-head-commit` refusing, or the re-read dismissing. This is the open platform question | 1st `log`, `pr N`, timeline. Delete the variable afterwards |
| P2 | Branch `slow/…`, eligible. After approval, Nikos edits the PR body to add `Human-Findings: 0` | 1st `yes`; the `edited` run says `auto-merge: no (… Human-Findings …)` | The PR merges with the body that was checked, with no trailer (task 14, decision 5) | `body`, the 2nd `log` |

**Cost.** Each PR event runs two jobs (Gates and auto-merge). K1 adds three. About 28 jobs, billed at most 2 minutes
each, which is under an hour of runner time. GitHub-hosted runners are free on a public repository. A private one
would use the account's included minutes and then bill, which is why the sandbox is public (decision 8). The design
keeps it small: no `push`, `schedule` or `workflow_run` triggers, timeouts on every job, one PR at a time, and
Actions disabled at teardown.

**On a failure.** The scenario's row says what happened. If a PR merged when it should not have, it is a bypass:
stop, open a draft advisory, and only then write the report. Otherwise, task 11 corrects the recipe and the template,
and task 9 reruns only the failing scenarios.

### Task 2: sandbox kit and local dry run (agent)

- **Touches:**
  - new `tests/live/github/` with `README.md` (the checklist for tasks 3 to 12), `sandbox.sh` (`seed`, `dry-run`,
    `open`), `gates.yml` and `probe.yml`;
  - new `kit/templates/github/specter-auto-merge.yml` (decision 1);
  - `tests/gates.sh` G1 gains `sh -n tests/live/github/sandbox.sh`.
- **Red row:** a 14b-style grep row in the selftest. The template names `pull_request_target`, `environment:`,
  `persist-credentials: false`, `commit_id`, `--match-head-commit`, `--body-file`, `cancel-in-progress: false` and
  `--disable-auto`, and `GITHUB_TOKEN` is not passed to `gh`. It fails until the file exists.
- **Check:** `sandbox.sh seed ~/specter-live-dry && sandbox.sh dry-run ~/specter-live-dry` exits 0 with every row as
  in the table, then G1 to G4.

### Tasks 3 to 7: setup (Nikos)

The `tests/live/github/README.md` checklist holds the exact commands. Each task is one OK.

| Task | Step | Done when |
|---|---|---|
| 3 | Create the public repository `<owner>/specter-live-sandbox` with nothing in it. Settings: allow auto-merge; squash only; Actions workflow permissions read-only; "Allow GitHub Actions to create and approve pull requests" off. Interaction limit `collaborators_only` for one week (`gh api -X PUT repos/<o>/<r>/interaction-limits`): on a public repository, a stranger's PR would run `pull_request_target` | `gh api repos/<o>/<r>` shows `allow_auto_merge: true`; `gh api repos/<o>/<r>/actions/permissions/workflow` shows `read` and `can_approve_pull_request_reviews: false` |
| 4 | Create a GitHub App: Pull requests read/write, Contents read/write, Metadata read, no webhook. Install it on this repository only | The installation lists one repository |
| 5 | Create the environment `specter-approver`, with deployment branches set to `main` only and no required reviewers. Add the variable `SPECTER_APP_ID` and the secret `SPECTER_APP_KEY` there, never as repository secrets | `gh api repos/<o>/<r>/environments/specter-approver` shows the branch policy; `gh secret list` (repository level) is empty |
| 6 | After batch 3: `sandbox.sh seed`, confirm the Guardrails rows and dates, push `main` (workflows included) | A fresh clone gives `routine: eligible` from `tiers.py --evidence` |
| 7 | A ruleset on the default branch: no deletion or force push; PR required with 1 approval, stale approvals dismissed on push; required check `gates`, branches up to date; no bypass actors | `gh api repos/<o>/<r>/rulesets` shows it |

### Tasks 8 and 9: scenarios (Nikos opens, the agent observes)

- 8: K1, N1, N2, N3, in that order. Nothing may merge.
- 9: create N4's branch, then P1, N4, N5, N6, P2.
- After each one, the agent records the observation in the report draft.

### Task 10: the report (agent)

`docs/reviews/<date>-live-recipe.md`. It records the sandbox, the specter sha and the ruleset JSON, then one row per
scenario (expected, observed, PR, run). It ends with what was not covered: GitLab, a separate agent token, merge
queues, fork PRs.

### Task 11: lift or correct (agent, Human required)

- **On a pass:**
  - the CHANGELOG `[Unreleased]` Known limits drop the GitHub "not run live" line, and the GitLab sketch stays;
  - the README Limits bullets change: the recipe is verified on GitHub, and `none` is still off until a repository
    declares it;
  - the review-loop step 5 GitHub bullet gets "Verified live <date> (`docs/reviews/<date>-live-recipe.md`)";
  - the template workflow gets a `# Verified: <date>` header;
  - template row 3's hint names the template.
- **On a fail:** fix the prose and the template, then rerun only the failing rows (task 9).

### Task 12: teardown (Nikos)

- Delete the App's private key, and uninstall the App (or delete it).
- Delete the environment.
- Disable Actions, then archive the repository, so the report's PR links still resolve.

## [REQ-V070-02] "Small" counts bytes and refuses LFS pointers

### Task 13: byte cap and LFS pointers in `small()` (security)

- **Touches:**
  - `tiers.small()`;
  - `tiers.parse_evidence()` and `SIZE`, which take a third optional column, `Max bytes`;
  - the `kit/templates/steering/autonomy.md` Evidence comment;
  - `docs/reference.md` Evidence bullet;
  - the docstrings of `small()` and `ready.py`.
- **Red rows** (13c2, fixture `t70b`, a `none`-eligible routine tier):
  - (a) a one-line 200 KB file in `docs/` must give `spot (bytes`. Today it stays `none`, and `ready.py
    --auto-merge` exits 0;
  - (b) an added LFS pointer file (3 lines) must give `spot (LFS pointer: docs/x.bin)`;
  - (c) an `oid` and `size` swap in an existing pointer must give the same;
  - (d) an added content line `++ x` counts its bytes, so the hunk parser takes no header lookalike;
  - (e) a three-line docs edit stays `none`;
  - (f) `Max bytes` 10 makes (e) `spot`;
  - (g) `Max bytes x` exits 2 with `file:line`.
- **Fix:**
  - One `git diff -U0 --no-color --no-ext-diff --no-textconv` over the same spec as numstat. Add `--no-ext-diff
    --no-textconv` to the numstat and raw calls too.
  - Sum the bytes of `+` and `-` lines after each file's first `@@`.
  - Over `Max bytes` (default 4000) gives `bytes <b> > cap <B>`.
  - A changed line matching `^[+-](version https://git-lfs\.github\.com/spec/|oid sha256:[0-9a-f]{64}$)` gives
    `LFS pointer: <path>`.
  - The existing `size …` message is unchanged, so the 13c2 greps hold.
- **Depends on:** nothing. Lane B.

## [REQ-V070-03] Human zeros count; nobody writes one for an auto-merge

### Task 14: refuse the trailer in an auto-merge PR, then keep human zeros (security)

- **Touches:**
  - `ready.main()`: read the raw text before `visible()`, and run one `git log -z --format=%H%x00%B base..head` in
    range mode;
  - `tiers.evidence()`: the counting loop, and the log entry drops its `human` field;
  - `kit/docs/review-loop.md`: step 5's `Human-Findings` paragraph, and GitHub bullet 3's merge line (decision 5);
  - `kit/playbooks/sync.md` § Trailers;
  - `docs/reference.md`;
  - the docstrings of both scripts.
- **Red rows:**
  - (a) 13e, with `xrd`: a ready `none` PR text plus `Human-Findings: 0` must give `auto-merge: no (… Human-Findings
    …)`, exit 1. Today it exits 0;
  - (b) the same trailer inside `<!-- … -->` must give the same;
  - (c) a range commit whose message carries the trailer must give the same;
  - (d) 13c3, `t13e24`, the finding-4 probe: a `none` row with Max human-caught 10, and 20 docs commits, nineteen with
    `Human-Findings: 0` and one with `1`. It must give `routine: eligible … human-caught 1 of 20 (5.0%)`. Today it
    gives `breach (human-caught 100.0% > 10%)`;
  - (e) the 0.10.0 row `t13e19` (13c3: three zeros on `none` commits, then the row becomes `spot`) changes its
    expectation from `hold (Human-Findings on 0 of 3 merges)` to `routine: eligible`. Its comment changes too: the
    zeros count now, because `ready.py` keeps them off auto-merges. `t13e18` stays as it is. Re-derive any other
    number that moves by running the block, and say in the commit body why it moved.
- **Fix:**
  - In `ready.main()`, if `tiers.findings(raw text)[0]` is set, or any range commit's is, add a warning: `PR text
    carries Human-Findings: the human writes it at the merge` (decision 10).
  - In `evidence()`, delete the line `carries = carries and (caught or human != "none")`. Keep the hold skip for
    `none` rows.
  - Step 5 says: "A `none` merge carries no `Human-Findings:`. `ready.py --auto-merge` refuses a PR whose text or
    commits carry one, and the job sets the squash message to the text it checked."
- **Depends on:** nothing before it. It runs before task 15, in lane A. The drop and the refusal are one commit: the
  drop alone would loosen evidence.

## [REQ-V070-04] A changed Tiers table above a tier resets its evidence

### Task 15: key evidence by the rows from the tier down (security)

- **Touches:**
  - a new `tiers.row_keys(rows, guarded)`, which returns one key per row index;
  - `tiers.classify()`, which returns `"key"` beside `"globs"`;
  - `tiers.evidence()`: `ents` keyed by `c["key"]`, and `cur` built with the same helper from the profile it reads;
  - the relabelled line's text, `docs/reference.md` and the docstring.
- **Red rows** (13c3, `t13e25`, the finding-5 probe):
  - Tiers `routine` `docs/*` `*.md` (none) and `domain` `src/*` (spot). Two `src/README.md` commits are labelled
    `domain`, then routine docs commits follow. A profile commit narrows `domain` to `src/*.py`;
  - after that commit, `--evidence` must give `routine: hold (merged 0 < min …)` and `relabelled: <n>`, and a PR
    editing `src/README.md` must be `spot (evidence: hold`. Today it gives `routine: eligible … merged 2` and
    `human: none`;
  - a profile commit that changes only `domain`'s Human keeps routine's count;
  - removing a Knowledge link resets every tier.
- **Fix:** key = (tuple of `(name, tuple(sorted(globs)))` for `rows[idx:]`, `tuple(sorted(guarded))`), from the
  `guarded` list `classify()` already builds (decision 3). The "13c. evidence" numbers that move when the block's
  profile edits now reset lower tiers are re-derived by running the block, never by guessing.
- **Depends on:** task 14 (same function). Lane A.

## [REQ-V070-05] Commit-graph files cannot change parents

### Task 16: `core.commitGraph=false` (security)

- **Touches:** the `tiers.py` import block, beside `GIT_NO_REPLACE_OBJECTS` and `GIT_GRAFT_FILE`, with the comment
  widened.
- **Probe first** (time box one hour, in a scratch dir under `$HOME`):
  - set up `a1`, `a2`, `git revert a1` and `a3`, then `git commit-graph write --reachable`;
  - rewrite, in a Python copy of the file's CDAT chunk, `a3`'s first-parent position to point at `a2`, so the revert
    drops out of the chain;
  - see whether `git log --first-parent` follows the forged parent.
- **Red row** (13c3, `t13e26`):
  - if the probe reproduces: the forged graph must still give `routine: breach (reverted …)`. Today it gives
    `eligible`;
  - if git ignores the forgery: a row that shows `git config core.commitGraph` prints `false` in a child of `import
    tiers`. Record the probe result in the commit body.
- **Fix:** `n = int(os.environ.get("GIT_CONFIG_COUNT") or 0)`, then set `GIT_CONFIG_KEY_<n>`, `GIT_CONFIG_VALUE_<n>`
  and `GIT_CONFIG_COUNT=n+1` (decision 4). Add `shortcut: git < 2.31 ignores GIT_CONFIG_COUNT; refuse older git if a
  job can run one`.
- **Depends on:** nothing. Lane C.

## [REQ-V070-06] Container gates see only the tracked and unignored tree

### Task 17: `gates.sh --docker` copies listed files only

- **Touches:** the `--docker` branch of `tests/gates.sh`.
- **Fix:**
  - On the host, `git ls-files -z --cached --others --exclude-standard` is piped into `docker run -i`.
  - In the container: `cd /src && tar --null --ignore-failed-read -T - -cf - | tar -xf - -C /tmp/s`. A tracked file
    deleted in the work tree is skipped.
  - The empty-mount check stays first.
  - Not a git checkout: exit 2, `gates: --docker needs a git checkout`.
  - `.git` is no longer copied. A worktree's `.git` is a file that points outside the mount, so it never worked in
    the container, and G1 to G4 pass without it today. Confirm that with the full run.
- **Red (manual, host with Docker):**
  - `mkdir -p kit/scripts/__pycache__ && touch kit/scripts/__pycache__/x.cpython-312.pyc`, then `sh tests/gates.sh
    --docker --only G3` must exit 0. Today 11e fails;
  - an untracked `.specs/features/zz-tmp/requirements.md` must make G4 fail. That proves untracked files arrive;
  - remove both afterwards;
  - record the wall time before and after with the agent worktrees present.
- **Check:** G1 to G4 with `--docker`.
- **Depends on:** nothing. Lane D. Task 18 edits only the G1 line of the same file.

## [REQ-V070-07] G5 runs in a container

### Task 18: `tests/acme-build.sh --docker` (Nikos OKs the first, networked run)

- **Touches:**
  - new `examples/acme-shop/scripts/mvnw-docker.sh`, the one place the docker command lives;
  - `tests/acme-build.sh`, which gains `--docker`: skip the host JDK check and run the build through the script, with
    the same log, scan and exit codes;
  - `examples/acme-shop/README.md` § Build and test, one paragraph;
  - `tests/gates.sh` G1 gains `sh -n examples/acme-shop/scripts/mvnw-docker.sh`.
- **The script:**
  - `docker run --rm --memory 3g -v "$PWD":/src:ro -v specter-acme-m2:/root/.m2 <image> sh -c 'cp -R /src /tmp/a &&
    cd /tmp/a && ./mvnw "$@"' sh "$@"`;
  - the empty-mount check from `gates.sh`;
  - stdout goes to the host, so `acme-build.sh`'s `> target/build.log` and the agent-text scan run as today.
- **Probe first:** `sh tests/acme-build.sh --docker` on alpine. The first run downloads Maven and its dependencies
  into the volume (network, Maven Central only). If protoc or `protoc-gen-grpc-java` fails to exec, stop and apply
  decision 6.
- **Check:** `G5 OK`, rc 0. `ACME_OFFLINE=1 sh tests/acme-build.sh --docker` also passes. G1 and G2.
- **Depends on:** nothing. Lane H, before task 19.

## [REQ-V070-08] acme-shop is specter's eval set

### Task 19: the eval set

- **Touches:**
  - new `examples/acme-shop/eval/README.md`: the procedure and the score-sheet template;
  - new `examples/acme-shop/eval/goals.md`;
  - new `examples/acme-shop/eval/sandbox.sh`;
  - `tests/gates.sh` G1 gains its `sh -n`;
  - one line in `examples/acme-shop/README.md` § Seed tasks.
- **Goals** (decision 7). Each states the prompt (the seed's ticket text), the acceptance (from v065's seed table),
  the expected tier read from the acme Tiers globs, the expected escalation, and at most 2 fix rounds:

  | Id | Seed | Expected tier | Expected human |
  |---|---|---|---|
  | E1 | S1 | routine (`*/src/test/*`) | `spot`: evidence on hold in a fresh sandbox |
  | E2 | S2 | domain | spot |
  | E3 | S6 | critical (`*/architecture/*`), plus `lessons.md`, a guarded path | required |
  | E4 | S7 | critical if the ArchUnit rule lands in `*/architecture/*` (the seed table says domain; the eval records the table's answer) | required |
  | E5 | S5 | critical | the run stops at the decision gate with a question and no code |

- **`sandbox.sh <dir>`:**
  - performs the README sandbox recipe under `$HOME`;
  - rewrites the four Maven Gates rows of the sandbox's `spec-rules.md` to `sh scripts/mvnw-docker.sh …`, and exits 1
    unless exactly four rows changed;
  - commits.

  The example's own Gates table stays as a real project would have it.
- **Score sheet:**
  - columns: goal; delivered (y/n); fix rounds; gates green on the first try; tier expected and actual; escalations
    expected and actual; wall time; tokens if known; notes;
  - header: date, the specter sha and version, the agent and the model id per role, and the image.
- **Check:**
  - `sh examples/acme-shop/eval/sandbox.sh ~/acme-eval-dry`, then `python3 .specs/kit/scripts/gates.py` in it, with
    every row green through the containers;
  - G1, G2, and G5 with `--docker`. The diff touches `examples/acme-shop/` outside `.specs/`, so G5 must run.
- **Depends on:** task 18. Lane H.

### Task 20: first eval run (Nikos OKs the token spend)

- One goal at a time, each in a fresh sandbox.
- The lead runs the kit's loop (`kit/docs/pipeline.md`) as a user would, and plays the human at the escalation points
  with the answers recorded in `goals.md`.
- Nothing is merged back into specter.
- Write `docs/evals/<date>-acme.md`.
- Lessons go to `.specs/steering/lessons.md`, Human required.
- **Depends on:** tasks 13 to 19 merged on `feat/0.11.0`, so the run measures the candidate.

## [REQ-V070-09] The resume rule is generic

### Task 21: AGENTS.md (rule change, Human required)

- **Touches:** `AGENTS.md`:
  - the exception sentence (decision 9);
  - the Gates table: G1 lists `.githooks/pre-push`, `tests/live/github/sandbox.sh`,
    `examples/acme-shop/scripts/mvnw-docker.sh` and `examples/acme-shop/eval/sandbox.sh`, as `tests/gates.sh` runs
    them; G5 becomes `sh tests/acme-build.sh --docker`;
  - the map row for `tests/live/`.
- **Check:** G4. Nikos approves the diff on the PR. It is AGENTS.md, specter's `trust` tier.
- **Depends on:** tasks 2, 18 and 19, so the table names files that exist. Lane I.

## Task 22: gates, deep review, CHANGELOG, release

- G1 to G4 with `--docker`, and G5 with `--docker` (the diff touches `examples/acme-shop/`).
- A deep review of `main...feat/0.11.0`, with the probes of tasks 13 to 16 rerun.
- CHANGELOG 0.11.0:
  - Security for 13 to 16;
  - Known limits rewritten: the #40 items are closed; "not run live" is lifted or kept by task 11's outcome;
  - the shortcuts added in 16 and 17.
- Version bump, and the `docs/overview/` refresh (the deck "Release 0.11.0 shipped", the roadmap "today (0.11.0)").
- The release PR carries `### Gates`, `### Review`, `### Verification` and the `ready.py --range` output.
- A retro into `lessons.md`.

## Parallel lanes

Batches hold at most 3 agent tasks. Inside a lane, tasks run in order, each merged before the next starts.

| Lane | Files and functions | Tasks |
|---|---|---|
| A evidence | `tiers.evidence()`, `tiers.classify()`'s return, `ready.main()`; 13c3 and 13e rows | 14 → 15 |
| B size | `tiers.small()`, `tiers.parse_evidence()`, `SIZE`; 13c2 rows | 13 |
| C import | `tiers.py` import block; one 13c3 row | 16 |
| D container gates | the `--docker` branch of `tests/gates.sh` | 17 |
| G live | `tests/live/github/`, `kit/templates/github/`, a 14b row; then review-loop step 5's Verified marks | 2 → 10 → 11 |
| H eval | `examples/acme-shop/scripts/`, `examples/acme-shop/eval/`, `tests/acme-build.sh` | 18 → 19 → 20 |
| I rules | `AGENTS.md` | 21 |
| Nikos | GitHub only | 1, then 3 → 4 → 5 any time; 6 → 7 after batch 3; 8 → 9; 12 last |

| Batch | Agent tasks | Nikos alongside |
|---|---|---|
| 0 | none | 1 (approve this spec and decisions 1 to 9) |
| 1 | 2, 13, 16 | 3, 4, 5 |
| 2 | 14, 17, 18 | OK for 18's first networked build |
| 3 | 15, 19, 21 | approve 21 |
| live | none | 6, 7, 8, 9 (the agent observes) |
| 4 | 10, 11, 20 | OK for 20's token spend |
| 5 | 22 | 12, then the release merge |

Edits to `tests/gates.sh` G1 come from tasks 2, 18 and 19, in different batches. Task 17 changes another part of the
file. Step 5 of `review-loop.md` is edited by task 14 (the trailer paragraph and the merge line) and task 11 (the
Verified marks): different paragraphs, in different batches.

## Rollout / rollback

- Tasks 13, 15 and 16 only take `none` away. Task 14's zero-drop removal is the one loosening. It is safe only with its
  refusal and decision 5, so all three ship in one commit, and a revert removes all three together.
- Task 17 and task 18 change specter's own gate scripts, not the kit.
- The profile format gains one optional column. A profile without it reads as in 0.10.0.
- Rollback is a revert of the task's commit.
- The sandbox is archived at teardown. Nothing in specter depends on it.

## Spec and doc impact

- `kit/docs/review-loop.md` step 5 (tasks 14, 11), `kit/playbooks/sync.md` § Trailers (14),
  `kit/templates/steering/autonomy.md` (13, 11), `kit/templates/github/` (2).
- `docs/reference.md` (13 to 16), README Limits (11), CHANGELOG (22), `docs/overview/` (22).
- `examples/acme-shop/README.md` (18, 19).
- AGENTS.md (21).
- No `domains/` folder in specter's own `.specs/`, so there is nothing to fold.
