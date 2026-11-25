# Changelog

All notable changes to specter. Format: [Keep a Changelog](https://keepachangelog.com/en/1.1.0/); versioning: [SemVer](https://semver.org/).
The installed version is stamped into each project (`.specs/kit/VERSION`; a `spec-kit.json` the installer creates records the first-install version in `kit_version`, and is never rewritten).

## [Unreleased]

## [0.11.0] - 2026-11-25

Live and eval (v070). Human `none` is still off in every known repository. This release closes the paths the 0.11.0
security reviews found to reach it without a human, and adds the kit to test the recipe on a hosted repository and an
eval set to measure the loop.

### Security
- The commit-graph is off for every repository call: a forged commit-graph file could hide a parent, as a graft does.
  Found by the v070 reviews.
- A hidden submodule bump could reach `none`; diffs now see every gitlink. Fixed; the advisory is published with this
  release.
- Fork PRs never reach the auto-merge job.
- CRLF and aliased LFS pointers, symlinks, filtered paths (`filter=` attributes) and attribute files are guarded: each
  counts as over the cap or is `spot`.
- A PR title or a commit carrying `Human-Findings:` is refused for auto-merge.

### Added
- Byte cap: the optional `Max bytes` Evidence column (default 4000), with LFS pointer and filter detection.
- `kit/templates/github/specter-auto-merge.yml`: the step 5 recipe as a workflow template.
- `tests/live/github/`: a sandbox kit to run the recipe against a real GitHub repository.
- `examples/acme-shop/eval/`: an eval set (goals E1 to E5 and the run procedure) for the acme-shop example.
- G5 in a container: `tests/acme-build.sh --docker` builds acme-shop without Maven or a JDK on the host.

### Changed
- Evidence is keyed by the Tiers rows from the commit's tier down, plus the guarded globs.
- Human zeros count again in evidence.
- `tests/gates.sh --docker` copies tracked and unignored files only.
- `AGENTS.md` carries a generic "pick up and continue" resume rule.
- A failed re-check revokes a live approval; the eval sandbox is safe to run.

### Known limits
- The GitHub recipe is still not run live. Human `none` stays off until it is verified on a live host.
- GitLab stays an untested sketch.
- Switching off the commit-graph needs git 2.31 or newer (older git ignores the setting). The filter-attribute check
  needs git 2.40 or newer; older git marks every `none` change `spot`.
- The eval's reviewer is of the same model family as the implementer, so its findings are correlated.
- Round 3 of the security review left four advisories, which must be fixed before any repository turns `none` on (#73).

## [0.10.0] - 2026-11-25

Trust-layer hardening (v061). Human `none` is still off in every known repository; this release closes the ways the
0.9.0 reviews found to reach it without a human, and makes it apply only to small changes.

### Security
- Human `none` holds only when the label's base is the `merged_ref` tip: a PR behind it is `spot (base <sha7> is behind
  <ref>: update the branch)`, so a demotion or a tighter threshold on the trunk reaches PRs already in flight. Found by
  the 0.10.0 deep review; the advisory is published with this release.
- A ref is refused when another listed ref differs from it only by case (NFKC, casefold, upper, as NTFS and APFS fold),
  or when a symref's target is not listed under its exact name: a pushed `MAIN` shadowed `origin/main`. The recipe
  fetches `merged_ref` with an explicit refspec.
- `--evidence` ignores `refs/replace` and grafts (`GIT_NO_REPLACE_OBJECTS=1`, `GIT_GRAFT_FILE` set to a path that never
  exists), so a local object cannot hide a revert.
- A symref to a `.../HEAD` ref is refused; a full commit id is accepted only at the repository's hash length.

### Added
- Human `none` only within a size cap and a trivial review: at most 3 files and 50 lines by default (optional `Max files`
  and `Max lines` Evidence columns), tests only added (a deleted, edited, `chmod`ed or retyped test file, or any
  `conftest.py` or `__init__.py` change, is `spot`; default test globs are the usual test folders and names
  (`tests/`, `__tests__/`, `spec/`, `*_test.*`, `*.spec.*`, `test_*`, `conftest.py`…), or a `## Tests` section), a binary file or a gitlink counts as over the cap, and the reviewer writes `- complexity:
  trivial` (anything else, a missing line or a repeated one bars it). `ready.py` runs the same check.
- `kit/playbooks/parallel.md`: run several agents on one feature (batches of at most 3, a worktree base check, unique
  temp files, red first, land with `cherry-pick` and check its exit code, one gate run on the tip, stop leftover runs,
  no polling loops). A retro step in the review loop turns a mistake into a lessons line and the check that catches it.
- `kit/scripts/readme_check.py`: a README check any project can run (links, images and anchors resolve, alt text, a
  line cap, required sections in order, a word denylist; settings under `readme` in `spec-kit.json`).
- `kit/templates/SECURITY.md`, offered by setup for a public repository without one.
- Setup asks whether the machine inspects every process launch and, on yes, wraps heavy Gates rows in a container; the
  note says some runtimes (Colima) share only `$HOME`.
- "Pick up and continue" in `next-task.md`: read the `▶ Resume here` block and the pinned plan issue, run the next task.
- Specter runs its own trust layer: `.specs/steering/autonomy.md` (trust-layer files on Human `required`),
  `.specs/steering/lessons.md`, `SECURITY.md` with private vulnerability reporting, `tests/gates.sh` (G1 to G4,
  `--docker` in a container) and a local `.githooks/pre-push` hook. No CI was added.

### Changed
- `--evidence` reads its thresholds from the profile at the `merged_ref` tip, counts a commit only under the tier row it
  was labelled with (`- relabelled: <n>` for the rest), reaches every commit a revert or `Fixes:` names, and refuses a
  commit with an unreadable date (exit 2 with its sha).
- A `none` merge carries no `Human-Findings:` (nobody writes it for the human): a `0` on it is ignored, a value above 0
  still counts, and a `none` tier no longer holds for missing trailers.
- `section()` skips fenced code and HTML comments (an unclosed comment hides the rest of the file); Knowledge is read raw.
- `ready.py`: model family variants (`claude-…`, `anthropic/…`) are one family; a repeated `implementer:`, `reviewer:`
  or `complexity:` line is not ready. A profile that is not UTF-8 is refused with `<profile> at <sha7>: not UTF-8`.
- Review-loop step 5: the GitHub approver is an App whose key lives in a default-branch-only environment, never
  `GITHUB_TOKEN`; it approves with `commit_id=<head sha>`, merges with `--match-head-commit`, re-reads the head and
  withdraws on a move, one job per PR (`cancel-in-progress: false`), fetches full history with the explicit refspec, and
  names all five `none` conditions. The GitLab bullet is an untested sketch (a trusted project, `sha=`,
  `resource_group`).
- `spec_lint.py` exits 2 when `--specs` is not a directory (it printed `0 FAIL` and exited 0); a refused `origin/HEAD`
  fallback says why.
- `tests/selftest.sh`: section timings, `SELFTEST_ONLY` (an unknown name exits 2, a partial run is not a pass in
  `gates.sh`), copied fixtures, no clock or locale in the output.
- README rewritten: the problem first, the trust layer, where specter is going, decisions and limits.

### Known limits (follow-ups in #40)
- The step 5 recipe is written from the platforms' documented settings, not run live. Human `none` stays off until it
  is verified on a live host.
- "Small" is files and lines, not bytes: a one-line minified file or an LFS pointer passes the cap. An added line can
  still disable a test; the reviewer's `complexity:` is the backstop.
- On a `none` row one human finding in the window is a breach whatever the threshold (human zeros on `spot` merges are
  dropped). A stricter row narrowed by a human leaves its files on the lowest tier with that tier's evidence.
- Commit-graph files can carry parents the way grafts do (local `.git` write needed, as for grafts).
- `.githooks/pre-push` is a local habit: `--no-verify` skips it, and it is on only after `git config core.hooksPath
  .githooks`.

## [0.9.0] - 2026-11-24

### Added
- Review-loop step 5 branches by the label's Human value: `required`, `spot`, and `none` as a platform recipe: branch
  protection requires one approval on every PR, dropped on a new commit, and the Gates as required checks; a
  non-required job runs `ready.py --range <base sha>...<head sha> --pr … --auto-merge` from a trusted worktree of the
  base and, on exit 0 only, approves with a non-agent identity and enables auto-merge. The merge queue re-runs the
  Gates, not `ready.py` (its commit and rules checks are for the PR). One concrete line each for GitHub and GitLab.
  Nothing in the kit merges.
- `ready.py --auto-merge`: exit 0 only when the verdict is `ready`, the reported human is `none` and there is no
  warning (a missing `rounds:` line, a Gates row not in the base's table, a reviewer below the label's tier), else exit
  1 with `auto-merge: no (<why>)`; `--json` has `auto_merge`.
- Fix-round cap: at most 2 fix rounds per task (worker retry, then the planner), then the task goes to the human with
  both outputs. The `### Review` block carries `rounds: <n>`; `ready.py` says `not ready` above 2 or for a malformed
  value, warns when the line is missing, and `--json` has `review.rounds`.
- `tiers.py --evidence` prints `demote: <file>:<line> Human <cur> → <one step stricter>` under a tier in `breach`
  (`required` says already required) and `--json` has `demote` per tier. The profile is still a human edit.
- `kit/docs/pipeline.md`: triage, implement, review, merge and evidence mapped to the playbooks and roles, what each hands
  on, and when the human enters (spec approval, the fix-round cap, a disputed finding, the tier's Human value, a
  guarded path, `Deploy impact`, a `demote:` line). The queue is the host's; the kit ships no orchestrator.

### Changed
- `tiers.py` label: Human `none` survives only on the lowest Tiers row with every guardrail declared and the tier
  `eligible` in `--evidence`; otherwise `spot`, with `- human: none → spot (<why>)` and `reasons` in `--json`. A failing
  evidence read fails closed to `spot`; so does a run with no `merged_ref` or `origin/HEAD` (the history would be the
  change itself). The label and `ready.py` read the Evidence thresholds from the profile at the base, never the working
  tree (`tiers.py --evidence` still reads the working tree). `labels_only` is `false`; the `- autonomy:` line states what the Human value means.
- `tiers.py` guards the profile at the `--file` path too, so an edit of it takes the last tier.
- `ready.py` reads a `rounds:` list item in any Markdown spelling (`*`, indent, case, `rounds :`); a rounds item that does not parse is not ready.
- `ready.py` reports Human `none` as `spot` on the same rules as the label, and when reviewer and implementer share a
  model family (exit code unchanged).
- Guardrails template: row three is now "every PR needs an approval, dropped on a new commit; only the `ready.py
  --auto-merge` job's identity approves a `none` PR", and row six also bars agents from creating tags and
  `refs/replace/` refs. An existing profile keeps its old wording and stays declared: update both rows, check the
  platform does what they say, and re-date them. acme-shop's rows are re-dated 2026-11-24.

### Security
- Refs resolve to full names. `merged_ref`, its fallback (now spelled `refs/remotes/origin/HEAD`) and each `--range`
  end must name exactly one branch or remote-tracking ref (or `HEAD`, or a full commit id for a range end): git's own lookup
  takes `refs/tags/<name>` first, so a pushed tag `origin/HEAD` or `origin/main` stood in for merged history or moved the
  range base, and earned `none`. A tag or an ambiguous name is refused: the label says `spot` (`evidence: merged_ref
  … is ambiguous`), `tiers.py --evidence` and a bad `--range` end exit 2, staged mode takes the last row, and
  `spec_lint.py` skips that ref with `WARN merged-work check skipped in <repo>: merged_ref …`, and `spec_report.py`
  skips it. The staged note names the full ref (`merge base with refs/heads/main`).
- A `refs/remotes/<remote>/HEAD` counts only as a symbolic ref: a pushed branch named `HEAD` lands there as a plain
  ref in a CI fetch and stood in for merged history. A short sha is no longer a `--range` end (git looks it up as a ref
  first, and a loose tag can shadow it on a case-insensitive disk): pass full commit ids.
- The label and `ready.py` refuse evidence whose history holds any commit of the change (`evidence: <ref> contains the
  change`), so an `origin/HEAD` pointing at the PR branch earns nothing.

### Known limits (open in `.specs/features/v061-trust-hardening/`)
- `none` is earned from declarations and trailers: who writes `Human-Findings:` on an auto-merge is open (v061 task 8).
- The step 5 recipe is written from the platforms' documented settings, not run live; keep the approver identity out of
  reach of the PR's own jobs and approve the checked sha only (v061 tasks 11, 12).
- A hand-made symref chain (`origin/HEAD` → another remote's plain `HEAD` ref) and a 64-hex range end in a SHA-1 repo
  are still read; neither comes from a git command or a platform event (v061 task 13).
- The slice 3 evidence advisories (thresholds at the working tree for plain `--evidence`, fenced sections, rebase
  merges, renamed tiers, the idle-gap window, bad dates, `refs/replace`) are v061 tasks 1-7.

## [0.8.0] - 2026-11-23

Slice 3 of staged autonomy: guardrails and evidence. The profile records what the platform enforces, and
`tiers.py --evidence` says from merged history which tier has earned more autonomy. Still labels only: nothing
merges on its own yet (that is slice 4). Re-run `install.sh` to get the new script version.

### Added
- Autonomy profile `## Guardrails`: `| Guardrail | Enforced by | Verified |`, eight template rows (protected default
  branch, Gates as required checks, human review on `required` paths, agent credentials that cannot approve or merge,
  agent permissions from the host's configuration, history and review records agents cannot edit, untrusted-text
  agent jobs read-only and without secrets, chores from a clean clone). A row is declared when Enforced by names
  something (not `-`, `—`, `–`, `?`, `tbd`, `todo`, `n/a`, `na`, `none` or `pending`, any case, trailing `.` ignored)
  and Verified is a `YYYY-MM-DD` date that is not in the future. `tiers.py --check` lists each row.
- Autonomy profile `## Evidence`: `| Tier | Window (days) | Min merged | Max reverted % | Max escaped % | Max human-caught % |`,
  shipped as placeholders (no tier is eligible until you set numbers; suggested numbers in a comment). A Max of `-`
  is not checked.
- `tiers.py --evidence [--json]`: reads first-parent commits on `merged_ref`, labels each with the profile as of its
  parent, and prints per tier `eligible`, `hold (<why>)` or `breach (<metric> x% > y%)` with the counts. Reverted is a
  later commit whose change set has `This reverts commit <sha>` naming one of this commit's; escaped the same with a
  `Fixes: <sha>` trailer; human-caught a `Human-Findings: <n>` trailer above 0 or not plain digits, as a rate over the
  merges that carry one (`human-caught <c> of <k> (<pct>%)`). The window is by position: from the tip down to the
  oldest commit dated inside it, whatever the dates above it; a future date never sets it. Too few merges, placeholder
  thresholds, fewer trailered merges than max(Min merged, 1) or a shallow clone is a hold, never a pass; a change set
  git cannot read is exit 2. Commits whose parent has no profile are left out and counted. It edits nothing.
- `kit/playbooks/sync.md` § Trailers and review-loop step 5: write `Human-Findings: <n>` on every merge (`0` when
  none) and `Fixes: <sha>` on a fix for an escaped defect.
- acme-shop declares all eight guardrails and sets evidence thresholds. Selftest case 13c (guardrails, evidence).

### Changed
- A tier whose Human is `none` is labelled `spot` while any guardrail row is undeclared or the section is missing;
  the `### Risk tier` block adds `- guardrails: …` (`, none → spot` when downgraded) and `--json` a `guardrails`
  object. A 0.7.0 profile without Guardrails therefore labels `none` tiers as `spot`; `ready.py` reports the same.
- Setup Phase 5 keeps Guardrails and Evidence; it fills a guardrail row only with what the user names, and dates it.
- `kit/docs/chores.md` points to guardrail row eight.

### Known limits (`shortcut:` in code and design)
- Guardrails are declared, never probed: specter cannot see branch protection or CI permissions.
- `--evidence` runs one git log and labels each commit separately, no cache; slow on windows of thousands of merges.
  `Human-Findings:` and `Fixes:` are read as written; their honesty is the human's and the platform's review record.
  `Fixes:` and reverts match any commit a merge brought in. A recently dated commit deep in history widens the window
  down to it (merged history is guardrail row one's to protect).
- Open from the confirmation review (tasks 19e-19g): a `refs/replace` ref in the clone can hide a revert, so run
  `--evidence` in a clone without `refs/replace/*`; a commit with an unparseable date crashes it (exit 1); after an idle
  gap of a full window, the oldest backdated commits in the window can drop out with their reverts.

## [0.7.0] - 2026-11-22

Slice 2 of staged autonomy: every change gets a risk tier and one readiness verdict, and reviews follow a contract.
Labels only: nothing merges on its own yet (that is slice 4). Re-run `install.sh` to get the new scripts.

### Breaking
- `gates.py`'s `### Gates` block changed. Rows read `- <label>: pass (<last line>)`, `FAIL (exit N)` or `not run`
  (they were `- <label>: <last line>`); a last line `- verdict: ready (N passed)` or
  `- verdict: not ready (F failed, R not run)` follows; a red run prints the block on stdout too, so "stdout not
  empty" no longer means green. `commit:` is read after the gates run, and a run that changes `git status` or the
  diff against `HEAD` adds `- tree changed during gates`: gitignore gate output. Exit codes are unchanged. Scripts
  that grep the block must change, and a 0.6 PR description fails `ready.py`.
- The review verdict table is `| Severity | Location | Evidence | Trigger | Consequence | Fix |` with `blocker` or
  `advisory` only. A blocker with an empty cell is advisory (a follow-up); a non-empty Location that is not
  `path:line` is not ready. A 0.6-style `major`/`minor` row makes `ready.py` say not ready.
- Tiers and guarded globs are relative to the repository root. A 0.6.5 profile written relative to a subfolder's
  `.specs/` parent no longer matches and fails closed to the last tier: add the subfolder prefix.

### Added
- `kit/scripts/tiers.py`: `--check` validates the Tiers table of `steering/autonomy.md`. Label mode labels the staged
  change (a preflight) or `--range A...B` (binding) from the profile at the base: the merge base of the range, or for
  staged files the merge base with `merged_ref` as committed at `HEAD`; with no merge base every file takes the last
  tier (`- base: HEAD (no merge base: last tier)`). Set `merged_ref` in `spec-kit.json`. The strictest file sets the
  tier. Paths and globs are compared under NFKC and a full case fold (what APFS and NTFS fold). Guarded paths always
  take the last row: `AGENTS*.md`, `CLAUDE*.md`, `GEMINI*.md` at any depth, nested `.claude/` and `.cursor/`,
  `.github/*instructions*`, skills folders, other agents' rules files, CODEOWNERS, Knowledge targets,
  `.specs/README.md`, `.specs/steering/`, `.specs/kit/` (`tiers.GUARDED`). Prints `### Risk tier` (with a `- base:`
  line) or `--json`.
- `kit/scripts/ready.py`: reads the PR text (untrusted: parsed, never run; blocks inside HTML comments and code fences
  are ignored) and says ready only when the head's Gates table equals the base's row for row and every row passed,
  the block's commit is the head (`+dirty` while files are staged) and no gate changed the tree, one `### Review`
  block names implementer, reviewer and `rules: <base sha>` with no open blocker, and every `### Verification` line
  names a defined REQ and a regular file at the head. A change to the Gates table is never ready: it goes to the
  human. Same-family reviewer and a reviewer below the label's tier are warnings. Prints `### Readiness` or `--json`.
- Run both from a trusted copy of the base, never from the PR's own `.specs/kit/`:
  `git worktree add --detach /tmp/specter-base <base>`, then
  `python3 /tmp/specter-base/.specs/kit/scripts/ready.py --specs .specs --pr /tmp/pr.md` (staged, before the
  commit: a preflight), and after the commit rerun `gates.py` and use `--range <base>...HEAD --pr /tmp/pr.md` (the
  binding check). The first upgrade to 0.7.0 runs the scripts from the specter release checkout. Ready means the
  declarations agree with the base's rules and the head commit; it does not prove the gates ran.
- Decisions log: an optional `Checked by` column; a gate it names must be a row of the Gates table (lint FAIL).
- Autonomy template: a Tiers section with three suggested tiers, and a note to put gate scripts in the last tier;
  setup Q10 proposes them; acme-shop ships a table.
- Selftest cases 11b-11e, 12 (Checked by), 13b and 14 (install, label, verdict end to end).

### Changed
- Review loop, reviewer role, model routing and spec-rules §7.4: the reviewer's tier comes from `tiers.py`; reviewers
  read the rules at the base and check verification artifacts against acceptance.
- Kit scripts no longer write `__pycache__`; projects that committed one under `.specs/kit/` should delete it.

### Known limits (`shortcut:` in code and design)
- A gate command that runs a repository script is only as trusted as that script at the head (setup puts gate
  scripts in the last tier). Model ids are self-declared and families are a prefix heuristic (`o3` vs `gpt` is not
  detected). A reviewer tier below the label is a warning until slice 4. A committed `merged_ref` naming the branch
  itself hides the branch's commits in staged mode; only `--range` binds. `+dirty` binds no content. Evidence is
  checked for presence, not content. `gates.py` stops at the first failure. Verification URLs are never fetched.
  The guarded list is kept by hand.

## [0.6.5] - 2026-11-22

The acme-shop example gets real code, so the factory has a codebase to work on. The kit is unchanged: installed projects see no difference.

### Added
- `examples/acme-shop/`: a Java 21, Spring Boot 4 Maven reactor (`shop-common`, `orders-api` with Spring Modulith modules `order`, `partner`, `outbox`) on H2, in-process gRPC and a transactional outbox. Error Prone with NullAway, Spotless, ArchUnit and Modulith rules, an OpenAPI snapshot, jqwik properties and PIT. Its specs cite real lines and pass `--cites`.
- A Gates table in the example (`G1`–`G5`, with `G3b` scanning the build log for text aimed at agents: jqwik 1.10.x prints such text, kept on an exact pin and allow-listed for that one clause), drift rows D5–D7, ADRs 007/012/013, chores for spec health and weekly PIT, and seed tasks S1–S8 across the routine, domain and critical tiers.
- `examples/acme-shop/README.md`: build with JDK 21 (`.sdkmanrc`), run, and the factory sandbox recipe.
- `examples/cite-demo/`: a small fixture whose citations fail on purpose; it reproduces `docs/assets/lint-demo.svg`.
- `tests/acme-build.sh`, specter gate G5 (optional): builds the example. Without JDK 21 it prints `G5 SKIPPED` and exits 0; any build failure exits 1. It must run, not skip, when a change touches the example's code.

### Changed
- Specter G2 also checks the example's citations; the selftest covers that and the cite-demo failure.
- README "Try it" runs the passing check on acme-shop and the failing one on cite-demo.

### Known
- `docs/assets/report.png` predates this release: its citation count shows the old failing state.

## [0.6.0] - 2026-11-21

First slice of staged autonomy, set per repository. Without `steering/autonomy.md`, the lint and playbooks behave as in 0.5.0; the report always gains the In flight card.

### Added
- `kit/templates/steering/autonomy.md` with a Knowledge table (a `Read` column: `start` rows are read first) and a Chores table, and `kit/templates/steering/lessons.md` for one dated line per correction.
- Chores run with `gates.py --file .specs/steering/autonomy.md`; `kit/docs/chores.md` has cron, launchd and CI schedule recipes.
- `spec_report.py`: an In flight card from worktrees and unmerged branches.
- Setup question Q10 for Knowledge and Chores. Example `autonomy.md` and `lessons.md` in acme-shop.
- Selftest cases 13 and 13a.

### Changed
- `AGENT_RULES.md`: read the `start` rows, write lessons. `sync.md`: a lesson seen twice becomes a check (Gates row, lint rule or test) first, prose only when it can't be checked.
- `spec_lint.py`: the `merged_ref` lookup is a shared helper; output is unchanged.

## [0.5.0] - 2026-11-06

Settled decisions recorded once and cited by id, every cited id checked, names kept out of shared specs, deploy impact
stated per change, and the gates run by a script. A 0.4.1 project keeps its exit code: new checks are off until their
file or config exists, and the one new default output is a WARN for REQ ids cited but defined nowhere.

### Added
- Decisions log: `kit/templates/steering/decisions.md` (`| ID | Decision | Why | Where it lands | Supersedes |`, ids `D-<id>`, a decision changes only by a new dated row that supersedes it). Once `.specs/steering/decisions.md` (or `decisions.file`) holds at least one decision row, the lint FAILs with `file:line` on a cited `D-<id>` without a row (an id stands alone and holds a digit: not `REQ-D-01`, `D-1.md` or `D-DAY`) and on a "Where it lands" REQ that no `requirements.md` defines; rows a later row supersedes are skipped.
- `spec-kit.json` `decisions.enabled` (default `true`) turns the decision checks off; a `decisions.md` in another format, with no decision row, is never checked.
- `spec-kit.json` `decisions.backlinks` (`false` default, `"warn"`, `true`): each REQ a decision lands on must cite the decision in its definition (a `###` REQ section includes its sub-headings). Any other value, a non-string `file`, a non-boolean `enabled` or an unknown `decisions` key stops the lint with a message.
- Lint WARN for a REQ cited outside a feature's own `requirements.md`, `design.md` and `tasks.md` (router, `system/`, `steering/`, `AGENT_PROMPT.md`, domain designs) and outside inline code that is defined in no `requirements.md`: one line per id with up to three `file:line` locations. `spec-kit.json` `unresolved_req: "off"` silences it.
- Names denylist: `spec-kit.json` `denylist_sha256` (default `[]`). The lint tokenises each line of `.specs/**/*.md` outside `kit/` (letters of any script and digits, lower-cased; dots kept in tokens, each run of dot segments, adjacent pairs joined by `-`) and FAILs as `denylisted term (token #n)` without printing the word. `spec_lint.py --hash-term <one or two words>` prints the digest, tokenised the same way.
- `kit/scripts/gates.py`: runs the Gates table (`| # | Gate | Command |`) of `steering/spec-rules.md`, or `--file`, in order from the project root. It stops at the first failure (exit 1, naming the gate) and prints a `### Gates` block with `commit: <sha>[+dirty]`. The commit is read before the gates run, and gates get a closed stdin. It exits 2 without running anything on a missing file or table, a row without exactly one code span, an unfilled template placeholder, or an unknown argument; `--help` prints the usage.
- `kit/templates/ONBOARDING.md`: what the project is, read order, rules not to break, how to work a change, gotchas, four starter prompts for any agent. Setup offers to generate it as `.specs/ONBOARDING.md`.
- `Deploy impact: none | <job or env>: <what changes>` in the tasks template; the spec-rules Definition of Done, `AGENT_RULES.md` and the review loop say the people who run CI/CD hear before the merge when it isn't `none`.
- Setup question Q9 (must-ask): how CI/CD consumes the repository (a pinned artifact or image, or the default branch directly), recorded in the profile.
- `kit/docs/review-loop.md`: "Grill the artifact": independent reviewers attack a spec or plan with recommended answers they try to refute, in rounds until one finds nothing material; settled answers go into the decisions log.
- Example: decisions log with back-links and a superseded row, `Deploy impact:` lines, a Gates table, `ONBOARDING.md`.
- Selftest case 11.

### Changed
- The spec-rules template's Definition of Done holds the gates as a `| # | Gate | Command |` table, and §4 points to the decisions log. Setup writes the gate commands into that table.
- `AGENT_RULES.md`: don't reopen a settled decision; state the deploy impact.
- `spec_lint.py --json` has a `refs` list (the new `file:line` FAILs, counted in `fails`); `spec_report.py` lists them with the other findings.

## [0.4.1] - 2026-10-29

### Fixed
- A task whose REQ ID sits on an indented continuation line, or on a nested sub-item, counts as linked. A task ends at a blank line, a heading or the next item at its level (tabs count as 4 spaces). Ticked and total counts are unchanged.

## [0.4.0] - 2026-10-29

Add specter to a project that already has specs without changing anything that works: preview with `--dry-run`, install, and roll back byte for byte with `--uninstall`.

### Added
- Adopt mode: a project with `features/`, `domains/`, `system/` or `steering/` under `.specs/` and no kit keeps everything it has. Only `.specs/kit/`, an absent `spec-kit.json`, an appended `.gitignore` line and a seeded profile (`status: active`, `adopted:` line) are written under `.specs/`. `--fresh` forces the old behaviour.
- `--dry-run`: lists every path it would create, modify or replace, and the mode (fresh, adopt, upgrade); writes nothing. Refused together with `--uninstall`.
- Lint: structural FAILs in `Done` and `Dropped` features are reported as `WARN history: ...` and don't count toward the exit code; broken links and citations still FAIL.
- `AGENT_RULES.md`: for adopted systems the project's `steering/spec-rules.md` wins where it differs.
- Selftest case 7 (adopt, dry run, user-level agent, foreign kit, history); the selftest now runs with a temporary `HOME`.
- `--hook`: adopt mode installs no git hook unless it is given, and prints how to enable it.
- Uninstall is as careful as install: it removes `.specs/kit/`, the skill, the Cursor rule and role agents only when specter wrote them, restores marker-block files byte for byte (CRLF included), removes only the `.gitignore` lines specter added (marked `# specter`), removes the seeded profile and config only when neither was edited (any edited key keeps the config), restores files without a trailing newline or empty files byte for byte, removes empty directories it leaves, and lists what it removed and kept.
- `GO.md`: an adopt branch (dry run first, no setup interview); `--from-go` in adopt mode says setup was skipped.

### Changed
- An existing `.specs/spec-kit.json` is never rewritten (before, an upgrade added `kit_version` and reformatted it).
- A skill, Cursor rule or project role agent that specter didn't write is kept on install, with `<path> exists and is yours: kept it`; summary lines list only what was written.
- A `.specs/kit/` counts as specter's only with `VERSION` and the specter marker in `AGENT_RULES.md`.
- `install.sh` usage lists `--dry-run`, `--fresh`, `--hook`.
- The installer never writes `.claude/agents/<role>.md` when `~/.claude/agents/<role>.md` exists (every mode).
- A `.specs/kit/` without `VERSION` stops the install with exit 2 instead of being deleted.
- Appending a marker block leaves existing file bytes (leading and trailing whitespace, CRLF) untouched.

### Fixed
- `spec_sync_check.py` crashed with a `KeyError` on a `spec-kit.json` without `code_globs`, blocking commits; missing keys take defaults, and an unusable config (null, a list, wrong types) skips the check instead of blocking the commit.
- A skill counts as specter's only with the substituted `Kit source:` line too.

## [0.3.0] - 2026-10-28

Every feature says whether it is proposed, in progress, blocked, done or dropped, and the lint tells you when that disagrees with the tasks or with what has been merged.

### Added
- Feature `Status:` line (Proposed, In progress, Blocked on …, Done <date> (<branch, commit or PR>), Dropped <date> (<why>)) in the `requirements.md` template; the lint reads the first non-empty `Status:` field (colon required) before the first `## `, outside fenced blocks.
- Lint WARNs: no `Status:` line, unknown status, all tasks ticked but not Done/Dropped, Done with unticked tasks, Done without a date or a `(…)` reference.
- Merged-work detection: with `tracker_pattern` set, the lint WARNs when commits on `merged_ref` name a feature's key while its spec says Proposed, has no status, or has no task ticked. Keys match with no letter or digit on either side. One `git log` per repo; exit code unchanged, also when git is missing or times out, or `tracker_pattern` is invalid (one WARN, check skipped).
- `spec-kit.json` keys `tracker_pattern` (default `null`) and `merged_ref` (default `null`: `origin/HEAD`, then `HEAD`; when set, repos without it are skipped; `.specs`-only commits are ignored).
- Report: status comes from the `Status:` line; a `merged, not closed` badge and a counter.
- Close-out steps in `sync.md`, `next-task.md`, `refresh.md`, `AGENT_RULES.md` and the spec-rules Definition of Done.

### Changed
- The repo index for `--cites` and merged-work detection skips linked git worktrees (a stray worktree in a workspace no longer makes citations ambiguous); submodules stay indexed.
- Specs without a `Status:` line now get one WARN per feature (exit code unchanged); `spec_report.py` infers the status as before for them.
- The feature template moves the "Blocked on" note into `Status:`.

## [0.2.0] - 2026-10-28

Specs you can see at a glance, and a citation checker that understands how people actually cite code.

### Added
- `spec_report.py`: one self-contained HTML page (no JavaScript, light and dark) with feature progress, open drift, coverage and citation health; written to `.specs/report.html`.
- `spec_lint.py --json` for the default and `--cites` modes (same exit codes).
- `--cites` notations: repo prefix (`<repo>:path:12`), several ranges (`path:12-20,31`), GitHub style (`path#L12-L20`); each range is checked on its own.
- `--cites` indexes git repos two levels below the project (`charts/<chart>/.git`).
- Drift aging: unresolved Drift Register rows (any table with a `Drift` column) older than `drift_max_age_days` (default 90) WARN; open rows without a `Logged` date (or no `Logged` column) WARN once per file.
- `spec-kit.json` keys `cite_aliases`, `cite_ignore_globs`, `drift_max_age_days`.
- Installer writes `.specs/.gitignore` with `report.html`; `--uninstall` removes that line.
- `docs/assets/social-preview.svg`: source of the GitHub social preview card (render with `rsvg-convert -w 1280 -h 640`).

### Changed
- `--cites`: an elided path (`head/.../tail`) narrows to files containing `head` as whole path segments; if none does, it falls back to matching `tail` alone.
- `--cites` does not look for repos inside folders whose name starts with `.`.
- Multi-range citations (`path:12-20,31`) used to be skipped silently; they are now checked, so existing projects can see new `--cites` failures.
- `--cites` ambiguity can be resolved with `cite_ignore_globs`; a citation can name its repo.
- `spec_lint.py` is split into collect and print (`lint_all`, `cites`) so the report reuses the checks.
- `AGENTS.md` lists the contributor gates for changing specter itself; specter's own specs live in `.specs/`.

## [0.1.1] - 2026-10-27

From the first non-Claude dry run (Antigravity CLI, Gemini).

### Added
- Antigravity (`agy`) as a detected agent; the skill goes to `.agents/skills/`.
- Installer seeds `.specs/steering/project-profile.md` (`status: setup-incomplete`).
- `GO.md` says when the running model isn't the strongest available, and why setup depth depends on it.

### Changed
- Agents found only on the machine (CLI or home folder) are reported but not wired; `GO.md` wires the running agent plus any the user names.
- Codex is detected from `.codex/` only; `.agents/` is shared across agents.
- Setup verifies under `status: verifying` and sets `active` only after both lint runs pass.
- Drift Register rows must be disagreements or hazards, not restated facts.
- Router template lists one link per domain.

### Fixed
- `spec_lint.py --cites`: a range is valid if any cited line has content; the ambiguous-file message says to use the repo-relative path.
- Removed dead detection code in the installer.

## [0.1.0] - 2026-10-27

### Added
- `GO.md`: one-conversation flow (look → propose → install on yes → setup interview → generate → commit?), started from any agent with a single pasted line.
- Playbooks: `setup` (scan, must-ask / ask-if-unclear interview, one approval, generate, verify), `new-feature`, `next-task`, `sync`, `refresh`.
- Templates for feature specs (requirements / design / tasks / `AGENT_PROMPT`), as-built domains, system docs (architecture, data flows + Drift Register, traceability) and steering (spec rules, code standards, project profile).
- Generic roles `planner` / `generator` / `reviewer`, plus model-routing and review-loop guides.
- `spec-first` skill (Agent Skills format), installed per detected agent: Codex, Claude Code, Cursor, Gemini CLI, Copilot. Claude Code also gets the roles as native sub-agents.
- `install.sh`: idempotent install and upgrade, `--detect`, `--agents=`, `--user`, `--uninstall`; marker blocks in `AGENTS.md` / `CLAUDE.md` / `GEMINI.md` / Copilot instructions; code paths detected from build files; multi-repo workspaces skip the git hook.
- Scripts (stdlib Python 3.8+): `spec_lint.py` (structure, REQ traceability, links, `--cites` citation checker) and `spec_sync_check.py` (pre-commit / range spec-sync gate).
- Worked example `examples/acme-shop/` with a small decision-gated change and a cross-cutting refactor.
- MIT license.
- Logo and animated README diagrams (`docs/assets/*.svg`) and `tests/selftest.sh`.
