# Changelog

All notable changes to specter. Format: [Keep a Changelog](https://keepachangelog.com/en/1.1.0/); versioning: [SemVer](https://semver.org/).
The installed version is stamped into each project (`.specs/kit/VERSION`, `spec-kit.json` → `kit_version`).

## [Unreleased]

### Added
- Feature `Status:` line (Proposed, In progress, Blocked on …, Done <date> (<PR>), Dropped <date> (<why>)) in the `requirements.md` template; the lint reads the first one before the first `## `.
- Lint WARNs: no `Status:` line, unknown status, all tasks ticked but not Done/Dropped, Done with unticked tasks, Done without a date.
- Merged-work detection: with `tracker_pattern` set, the lint WARNs when commits on `merged_ref` name a feature's key while its spec says Proposed, has no status, or has no task ticked. One `git log` per repo; exit code unchanged.
- `spec-kit.json` keys `tracker_pattern` (default `null`) and `merged_ref` (default `origin/HEAD`, falls back to `HEAD`).
- Report: status comes from the `Status:` line; a `merged, not closed` badge and a counter.
- Close-out steps in `sync.md`, `next-task.md`, `refresh.md`, `AGENT_RULES.md` and the spec-rules Definition of Done.

### Changed
- The repo index for `--cites` and merged-work detection skips linked worktrees and submodules (`.git` is a file).
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
