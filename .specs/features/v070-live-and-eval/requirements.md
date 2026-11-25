# v070 Live recipe, deep-review follow-ups and the acme eval set — Requirements

Status: Proposed — draft, awaiting approval
Tracker: GitHub milestone "0.11.0" and one issue per task (Nikos creates them; #40 and #35 are the sources). Branch
`feat/0.11.0`. Size M.

## Why

Verified on `main` 2026-11-25 (`cac0e97`, v0.10.0):

- **The `none` recipe has never run.** CHANGELOG 0.10.0 Known limits: "The step 5 recipe is written from the platforms'
  documented settings, not run live. Human `none` stays off until it is verified on a live host." README § Limits says
  the same. `kit/docs/review-loop.md` step 5 gives the GitHub recipe (an App in a default-branch-only environment,
  `pull_request_target`, `commit_id`, `--match-head-commit`, a head re-read, `concurrency` without cancel). v061's
  design (its "What it cannot check" list under the platform requirement) names what only a live host can show:
  whether an approval with a stale `commit_id` counts, whether an environment secret is out of reach of a
  `pull_request` run, whether `concurrency` queues the jobs.
- **#40, deep review 2026-11-25 findings 3, 4, 5** (`docs/reviews/2026-11-25-v061-deep-review.md`) and two comments:
  - `tiers.small()` counts files and newline-separated lines from `git diff --numstat`, plus binary entries and
    gitlinks. A 200 KB one-line file is `1 0`, and an LFS pointer swap is two changed lines, whatever the object
    (finding 3).
  - `tiers.evidence()` drops a `Human-Findings: 0` on any commit that `classify()` labels `none`
    (`carries = carries and (caught or human != "none")`). `classify()` ignores `earned()`, `small()`, the family and
    `complexity:`, so a merge that really had a human check (it was `spot` because it was over the cap) loses its
    human `0`. On a `none` row, one human finding is then a 100% breach (finding 4).
  - `tiers.evidence()` keys each commit by its own tier row only, `(tier, sorted globs)`. When a human narrows a
    stricter row, files fall through to the lowest tier, and that tier keeps its evidence (finding 5).
  - The `tiers.py` import block sets `GIT_NO_REPLACE_OBJECTS` and `GIT_GRAFT_FILE`, not `core.commitGraph`. Commit-graph
    files can carry parents the way grafts do (second review, A7).
  - The `--docker` branch of `tests/gates.sh` runs `cp -R /src/.`, so ignored files reach the container. A stray
    `kit/scripts/__pycache__` failed G3 11e on the release run. `.gitignore` also lists `.claude/worktrees/`, so every
    agent worktree is copied into each container run too.
- **#35:** there is no repeatable measure of whether a release makes the agent loop better. `examples/acme-shop/README.md`
  has eight seed tasks (S1 to S8) with acceptance criteria in v065's design, but no fixed set, run procedure or
  score sheet. `tests/acme-build.sh` (G5) runs Maven on the host JDK, which the corporate-scanned laptop must not do.
- **AGENTS.md** still says "`gh issue list --label v061` shows the plan issue", which is true only for v061.

## User story

As Nikos, I want the `none` recipe proven on a real GitHub repository, the review's follow-ups closed red-first, and a
fixed eval I can rerun each release, so that switching `none` on rests on observed behaviour and each release is
measured against the last one.

## Requirements

### [REQ-V070-01] The GitHub `none` recipe is verified live

- A public sandbox repository SHALL run the recipe of review-loop step 5 as written, with a GitHub App as approver.
- Each step that acts on GitHub (creating the repository, the App and its installation, the environment and secrets,
  pushing workflows, the ruleset, opening PRs, teardown) SHALL be a separate task that Nikos runs or OKs. Agents only
  prepare files, scripts and checklists, and read results with read-only `gh` calls.
- These scenarios SHALL be run, each with an expected outcome and an observation recorded: an eligible trivial PR
  auto-merges. A stale base, an over-cap change, a `complexity: non-trivial` review, a same-family reviewer, a push
  after approval and a push during the job's check each do NOT merge. The App key is unreachable from a
  `pull_request` job. A PR text edited after the check does not change the merged message.
- The run SHALL be minimal: public repository (GitHub-hosted runners are free there), `timeout-minutes` on every
  job, no `push`, `schedule` or `workflow_run` trigger, and teardown after. The estimate is about 30 runner-minutes.
- The outcome SHALL be `docs/reviews/<date>-live-recipe.md`: per scenario the expected and observed outcome, the PR
  and run, and the specter sha installed in the sandbox.
- On a pass, the CHANGELOG's "not run live" limit SHALL be lifted for GitHub, and the recipe and its template SHALL
  carry the Verified date. On a fail, the recipe SHALL be corrected and only the failing scenarios rerun. GitLab stays
  an untested sketch.

**Acceptance:** the report exists, and every scenario row has an observation that names the PR number and the run.
After a pass, `grep -n "not run live" CHANGELOG.md` finds no unreleased GitHub limit, and the review-loop GitHub
bullet names the report.

### [REQ-V070-02] "Small" counts bytes and refuses LFS pointers (security)

- In a tier whose Human is `none`, `small()` SHALL also cap the changed bytes (the content of added and deleted lines).
  The cap is an optional `Max bytes` Evidence column, read at the base like `Max files` and `Max lines`. The
  default is decision 2.
- A changed line that is part of a Git LFS pointer (`version https://git-lfs.github.com/spec/…` or
  `oid sha256:<64 hex>`) SHALL count as over the cap.
- Each SHALL only take `none` away, with a `- human: none → spot (<why>)` reason.

**Acceptance:** selftest rows in 13c2 (below) fail on 0.10.0 and pass after: a one-line 200 KB docs file and an LFS
pointer add or swap are `spot`, and a three-line docs edit stays `none`.

### [REQ-V070-03] Human zeros count; nobody writes one for an auto-merge (security)

- `ready.py` SHALL warn when the PR text (raw, comments and fences included) or a commit message in the range carries a
  `Human-Findings:` line. With `--auto-merge`, that warning is `auto-merge: no`.
- The recipe's job SHALL set the squash commit message to the PR text it checked, so an edit after the check cannot
  put a trailer into the merged commit.
- Then `--evidence` SHALL count a `0` on every commit again (the 0.10.0 drop on `none`-labelled commits is removed).
  A tier whose row says `none` still does not hold for missing trailers.

**Acceptance:** the finding-4 probe (a `none` row, 20 merges with nineteen human `0`s and one `1`, Max human-caught 10)
gives `eligible … human-caught 1 of 20 (5.0%)` instead of a 100% breach. A ready `none` PR whose text or commit
carries `Human-Findings: 0` gets `auto-merge: no`, exit 1.

### [REQ-V070-04] A changed Tiers table above a tier resets its evidence (security)

- A commit SHALL count for a tier only when its parent's profile has the same rows, by name and Paths globs, from that
  tier down to the last row, and the same Knowledge-guarded globs, as the profile `--evidence` reads. Other commits go
  on the `relabelled` line. Reviewer and Human are still not compared, so a promotion keeps its evidence.

**Acceptance:** the finding-5 probe (narrowing `domain` from `src/*` to `src/*.py`) gives `routine: hold` and a
`relabelled` count, and a PR editing `src/README.md` is `spot`. Today it gives `routine: eligible` and `human: none`.

### [REQ-V070-05] Commit-graph files cannot change parents (security)

- Every git call that `tiers.py`, `ready.py` and `spec_lint.py` make from a `tiers` import SHALL run with
  `core.commitGraph=false`, set once at import next to the replace and graft settings.

**Acceptance:** a selftest row in 13c3: a forged commit-graph that hides a revert still gives `breach`, or, if git
ignores the forgery (the probe decides), a row that shows git reads `core.commitGraph` as false under `tiers`.

### [REQ-V070-06] Container gates see only the tracked and unignored tree

- `tests/gates.sh --docker` SHALL copy into the container only the files that `git ls-files --cached --others
  --exclude-standard` lists: tracked files and new files that are not ignored.

**Acceptance:** with a stray `kit/scripts/__pycache__/*.pyc`, `sh tests/gates.sh --docker --only G3` exits 0 (today
11e fails). An untracked, unignored feature folder is still seen by G4.

### [REQ-V070-07] G5 runs in a container, never Maven on the host

- `tests/acme-build.sh --docker` SHALL build acme-shop inside the local `azul/zulu-openjdk-alpine:21` image (decision 6
  covers a fallback), with Maven's repository in a named volume. It SHALL keep today's exit codes, log and agent-text
  scan.
- AGENTS.md's G5 row SHALL name `--docker`.

**Acceptance:** `sh tests/acme-build.sh --docker` prints `G5 OK` and exits 0 on the laptop. No `java` or `mvn`
process runs on the host.

### [REQ-V070-08] acme-shop is specter's eval set

- `examples/acme-shop/eval/` SHALL hold 3 to 5 goals of rising difficulty, each with its prompt, acceptance criteria,
  expected tier and expected human escalation. They are taken from the seed tasks, so no new defects are planted
  (decision 7).
- It SHALL hold a run procedure: a sandbox script that copies the example under `$HOME`, installs the kit, and runs
  every Maven Gates row through the G5 container, then the loop per goal as a user would.
- A first run SHALL be recorded in `docs/evals/<date>-acme.md`, with one row per goal: delivered, fix rounds, gates
  green on the first try, tier expected and actual, human escalations expected and actual, wall time, tokens if known.

**Acceptance:** the sandbox script's dry run passes every sandbox Gates row in containers, and the score sheet has a
row for every goal and names the specter sha, the agent and the model ids.

### [REQ-V070-09] The resume rule is generic (rule change, Human required)

- AGENTS.md's "pick up and continue" exception SHALL name no release label. It SHALL say to read the in-progress
  feature's `▶ Resume here` block, which names the plan issue, and the pinned plan issue on GitHub.
- The AGENTS.md Gates table SHALL list the new scripts in G1 and `--docker` in G5.
- An agent proposes this diff. Nikos approves it.

**Acceptance:** `grep -n "label v061" AGENTS.md` finds nothing, and the G1 and G5 rows match `tests/gates.sh` and
`tests/acme-build.sh`.

## Out of scope

- The stage 5 orchestrator. It is a separate proposal, written elsewhere.
- Running GitLab live. The GitLab bullet stays an untested sketch.
- Switching `none` on in specter's own repository: its trust-layer paths stay `required`, and it has no CI.
- GitHub Actions in this repository. The sandbox repository is the only place a workflow runs.
- A separate agent identity in the sandbox. The PR author is Nikos's account, so the test covers the approver and the
  platform rules, not an agent token's scope (the Guardrails row on agent credentials).
- New planted defects in acme-shop.

## Open decisions

Each has a recommendation. Task 1 records Nikos's call on the plan issue.

- **DECISION 1, ship the tested workflow?** Recommended: yes, as `kit/templates/github/specter-auto-merge.yml`. The
  live test needs the file anyway, and the file is what got verified, not the prose. Without it, every project
  rebuilds the workflow from the prose. — Nikos
- **DECISION 2, byte cap form and default:** recommended: an optional `Max bytes` Evidence column, default 4000
  changed bytes (50 lines of 80 columns). — Nikos
- **DECISION 3, evidence key:** recommended: (A) the rows from the tier down to the last, plus the Knowledge-guarded
  globs, compared for equality. Any edit to a stricter row resets the lower tiers. (B) a containment check keeps
  evidence when stricter rows only grow, but it costs more code and is harder to review. — Nikos
- **DECISION 4, commit-graph setting:** recommended: (A) `GIT_CONFIG_COUNT`, which is documented but needs git 2.31
  or later (older git ignores it, recorded as a `shortcut:`). The alternative (B) is `GIT_CONFIG_PARAMETERS`, which
  works on every git but is internal. — Nikos
- **DECISION 5, squash message set by the job (`--body-file` of the checked text):** recommended: yes. Without it, an
  edit to the PR body after the check puts an agent-written trailer into the merged commit, and then dropping the
  0.10.0 zero-drop is unsafe. — Nikos
- **DECISION 6, JDK image:** recommended: `azul/zulu-openjdk-alpine:21` as asked, probed first. protoc and
  `protoc-gen-grpc-java` are glibc binaries and may not run on musl. If the probe fails, fall back to the local
  `azul/zulu-openjdk:21` (glibc), which is already pulled, rather than `apk add gcompat` (network on every fresh
  container). — Nikos
- **DECISION 7, eval goals:** recommended: E1 S1 (routine test addition), E2 S2 (one-file bug, failing test first),
  E3 S6 (lesson to check: a guarded path), E4 S7 (two layers, REST and gRPC), E5 S5 (must stop at the decision gate).
  There is no separate docs-only goal: it would land in the same routine tier as S1 and measure nothing new. — Nikos
- **DECISION 8, public sandbox:** recommended: public, so the minutes are free. v061's decision 11 said private.
  Public is safe because `none` is off in every known repository. A wrong merge is still filed as a draft advisory
  first. — Nikos
- **DECISION 9, how resume finds the plan issue:** recommended: the Resume block names the plan issue's number, and
  the issue is pinned. No release label convention. — Nikos
