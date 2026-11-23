# Changelog

All notable changes to specter. Format: [Keep a Changelog](https://keepachangelog.com/en/1.1.0/); versioning: [SemVer](https://semver.org/).
The installed version is stamped into each project (`.specs/kit/VERSION`; a `spec-kit.json` the installer creates records the first-install version in `kit_version`, and is never rewritten).

## [Unreleased]

## [0.8.0] - 2026-11-23

Slice 3 of staged autonomy: guardrails and evidence. The profile records what the platform enforces, and
`tiers.py --evidence` says from merged history which tier has earned more autonomy. Still labels only: nothing
merges on its own yet (that is slice 4). Re-run `install.sh` to get the new script version.

### Added
- Autonomy profile `## Guardrails`: `| Guardrail | Enforced by | Verified |`, eight template rows (protected default
  branch, Gates as required checks, human review on `required` paths, agent credentials that cannot approve or merge,
  agent permissions from the host's configuration, history and review records agents cannot edit, untrusted-text
  agent jobs read-only and without secrets, chores from a clean clone). A row is declared when Enforced by names
  something and Verified is a `YYYY-MM-DD` date. `tiers.py --check` lists each row.
- Autonomy profile `## Evidence`: `| Tier | Window (days) | Min merged | Max reverted % | Max escaped % | Max human-caught % |`,
  shipped as placeholders (no tier is eligible until you set numbers; suggested numbers in a comment). A Max of `-`
  is not checked.
- `tiers.py --evidence [--json]`: reads first-parent commits on `merged_ref`, labels each with the profile as of its
  parent, and prints per tier `eligible`, `hold (<why>)` or `breach (<metric> x% > y%)` with the counts. Reverted is a
  later `This reverts commit <sha>`; escaped a later `Fixes: <sha>` trailer; human-caught a `Human-Findings: <n>`
  trailer, n > 0. Too few merges, placeholder thresholds or too few `Human-Findings` trailers (human-caught % is over the merges that carry one) is a hold, never a
  pass. Commits whose parent has no profile are left out and counted. It edits nothing.
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
  A `Fixes:` sha is matched against first-parent commits only.

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
