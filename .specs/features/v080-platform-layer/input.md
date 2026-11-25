# Input: platform layer for multi-repo systems

Source: a private multi-repo adoption that split one workspace spec tree into a platform layer plus per-repo specs.
The split closed on 2026-11-25 (all member PRs merged). Kit line numbers refer to kit 0.4.1 and are history, not citations: the code has moved since.

## Model that worked
- Platform `.specs/` holds only what spans repos: system architecture, data flows and the one Drift Register,
  upstream-requirement traceability, a repo registry (system/repos.md: repo, default branch, deployables,
  domains, spec path) and a contracts registry (system/contracts.md: contract, provider repo, consumers, rule).
- Each member repo holds its own `domains/` and single-repo features, plus the vendored kit, so a fresh clone
  lints alone.
- Cross-repo feature tasks: one repo per line, `- [ ] N <repo>: <what> → <repo>/.specs/features/<f>/ · after: N
  — [REQ-…]`; `platform:` lines for work in no repo (decision, release cut); chart twins may share a line.
- The agent file in member repos is the tool-neutral AGENTS.md; CLAUDE.md is git-ignored and kept locally
  as `@AGENTS.md`.
- When the platform is private, member repos never name or link it ("platform specs, maintained outside this repo").
  A leak gate then needs care: a `.specs/` path in a member repo is legitimate only if it resolves inside that repo.

## Gaps
| # | Gap | Kit evidence (0.4.1) |
|---|---|---|
| G1 | No platform/member layout: no `layer:`/`platform:` keys in profile or spec-kit.json; setup knows single, monorepo and workspace only | playbooks/setup.md (0.4.1 line 38), playbooks/setup.md (0.4.1 line 72), templates/steering/project-profile.md (0.4.1 line 1-7) |
| G2 | Lint takes one spec root; no mode that lints the platform plus every member from a registry | scripts/spec_lint.py (0.4.1 line 389-391) |
| G3 | REQ ids resolve only against the root's own `domains/`: a platform feature citing a member REQ fails as undefined | scripts/spec_lint.py (0.4.1 line 252) |
| G4 | Cites root at the parent of `.specs/`; a platform in a sibling folder cannot cite members, and in a member any other-repo prefix fails | scripts/spec_lint.py (0.4.1 line 177-187), line 317, line 333 |
| G5 | Relative links are checked on disk only; no "link into another repo" notion (pass if absent, check if present) | scripts/spec_lint.py (0.4.1 line 160-174) |
| G6 | No contracts-registry check, no traceability reachability check; the upstream-id check silently skips when the root has no system/traceability.md | scripts/spec_lint.py (0.4.1 line 152) |
| G7 | The marker block assumes one Drift Register location | marker block template |
| G8 | Marker block has no "platform rules live at…" line; no platform fetch helper | AGENT_RULES.md (0.4.1 line 1-9) |
| G9 | `kit_version` can be null; nothing compares member kit versions with the platform's | spec-kit.json |
| G10 | The report renders one root; no cross-repo readiness view of a platform feature | scripts/spec_report.py (0.4.1 line 4) |
| G11 | No format or lint for platform feature tasks (one repo per task, child link or PR, `after:` order) | templates/feature/tasks.md (0.4.1 line 1-10) |
| G12 | Status vocabulary lacks Superseded and Moved | scripts/spec_lint.py (0.4.1 line 49) |
| G13 | A `path:line` cite is checked for existence only: when a member checkout moves, cites shift onto other lines and still pass. Needs a content anchor or commit-pinned cites; the platform gate should resolve members at their default branch, not the checkout | scripts/spec_lint.py cites check |
| G14 | The vendored kit (~32 files) is copied into every member; consider a trimmed member kit or a fetch | — |
