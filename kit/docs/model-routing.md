# Model routing (optional)

The point is to spend the strongest model only where judgement matters, and let deterministic scripts decide
pass or fail everywhere else. This works with any vendor: map the tiers to whatever your tool offers.

## Tiers

| Tier | Use for | Claude example | Other tools |
|---|---|---|---|
| **script** | Gates: build, tests, lint, `spec_lint.py`, `spec_sync_check.py`, CI | (no model) | (no model) |
| **light** | Extraction, formatting, release-note drafts | `claude-haiku-5-5` | Your vendor's small/fast model |
| **standard** | Implementation against a clear spec, tests, fixes with a known cause, docs, first-pass review | `claude-sonnet-5-5` | Mid-tier model |
| **deep** | Specs, architecture, setup/refresh, root-cause diagnosis, security-sensitive review, escalations | `claude-opus-5-5`, high effort | Frontier/reasoning model, high effort |

## Which step runs where

| Step | Tier | Gate (must pass before the next step) |
|---|---|---|
| Setup / refresh (`setup.md`, `refresh.md`) | deep | `spec_lint.py` + the user approves the domain map |
| Plan: feature spec (`new-feature.md`) | deep | `spec_lint.py <feature>` + the user approves |
| Generate: one task (`next-task.md`) | standard | The project's gate (spec-rules §7) |
| Review: diff after a green gate | standard, fresh context; **security paths → deep** | Findings resolved or rejected with a reason |
| Sync (`sync.md`) | standard | `spec_lint.py` + `spec_sync_check.py` |

## Rules

1. Default to the tier in the table.
2. Every standard-tier task ends with its gate. On failure, retry **once** at the same tier with the **full** error output.
3. A second failure escalates to deep, with the spec, the diff and both error outputs.
4. Never escalate without a failed gate. Never skip the gate.
5. **Pin full model IDs, not aliases.** Vendors and org admins remap aliases (`opus`, `sonnet`, `latest`), and an
   unavailable ID can silently fall back to another model. When you change a pin, check what a fresh session actually serves.

## Claude Code wiring

`install.sh <project> --with-agents` installs three tier agents into `.claude/agents/`, each pinned in its
frontmatter: `planner` (deep), `generator` (standard), `reviewer` (standard, read-only on code). The main session
plans; `generator` implements one task; `reviewer` reviews the diff; `planner` takes escalations and security reviews.

## Other agents

Most agentic CLIs let you choose the model per session or per profile (for example Codex profiles in
`~/.codex/config.toml`, or Cursor's per-chat model picker). Map the three tiers to three profiles and switch by step.
If your tool has sub-agents, mirror the planner/generator/reviewer split. If it doesn't, run review in a **new
session** so the reviewer doesn't share the implementer's context.
