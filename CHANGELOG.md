# Changelog

All notable changes to specter. Format: [Keep a Changelog](https://keepachangelog.com/en/1.1.0/); versioning: [SemVer](https://semver.org/).
The installed version is stamped into each project (`.specs/kit/VERSION`, `spec-kit.json` → `kit_version`).

## [Unreleased]

### Added
- `docs/assets/social-preview.svg`: source of the GitHub social preview card (render with `rsvg-convert -w 1280 -h 640`).

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
