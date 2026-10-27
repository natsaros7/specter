# Changelog

All notable changes to specter. Format: [Keep a Changelog](https://keepachangelog.com/en/1.1.0/); versioning: [SemVer](https://semver.org/).
The installed version is stamped into each project (`.specs/kit/VERSION`, `spec-kit.json` → `kit_version`).

## [Unreleased]

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
- Animated README diagrams (`docs/assets/*.svg`) and `tests/selftest.sh`.
