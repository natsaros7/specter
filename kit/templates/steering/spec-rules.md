# Steering — Spec rules (spec-first)

How changes are proposed, designed and tracked in <System>. It wraps the project's existing gates and doesn't replace them.

## 1. When a spec is required

| Change | Spec? |
|---|---|
| Trivial: ≤ <N> LOC, one file, no interface/schema/contract change | No. Edit directly; still pass the Definition of Done. |
| Non-trivial: > <N> LOC **or** several files **or** any API/contract, DB schema, message topic, or domain-boundary change | **Yes**, before touching code (`kit/playbooks/new-feature.md`). |

## 2. Feature layout

```
.specs/features/<id>-<summary>/
├── requirements.md   # WHAT & WHY: evidence, user story, [REQ-<FEAT>-NN] + acceptance
├── design.md         # HOW: every REQ traced to components/interfaces; tests; rollout; doc impact
├── tasks.md          # atomic `- [ ]` tasks, each linked to a REQ
└── AGENT_PROMPT.md   # optional: a standalone brief for an autonomous implementer
```

Folder names are kebab-case and prefixed with the tracker key (`<KEY>-123-…`) when one exists.
Acceptance criteria are testable. `design.md` must not contradict the architecture authority (§4).

## 3. Execution

One task at a time (`kit/playbooks/next-task.md`). Tick it when code and tests are in and the gate is green.
Refactors are characterised first: a safety net on the unchanged code, in its own commit, which the refactor must pass unchanged.

## 4. Decision authority

<ADRs in `<path>` / architecture doc `<path>` / <role>>. A design that needs a new architectural decision
raises one (an ADR, or the project's equivalent) before implementation.

## 5. Domains vs features

`domains/` = **as-built** (living documentation). `features/` = **proposed change**. When a feature lands, fold it into
`domains/`; the feature folder becomes history.

## 6. Grounding

Pull the main branch before asserting code facts. Cite `path:line`. Never assume an API, config key or feature exists.

## 7. Definition of Done

1. Gate: `<exact commands, e.g. ./gradlew check / npm test && npm run lint>`
2. `python3 .specs/kit/scripts/spec_lint.py` exits 0.
3. `tasks.md` fully ticked; affected `domains/` (and `system/`) docs updated in the same commit (§8).
4. <review rule, e.g. fresh-context review on the diff; security paths get the strongest reviewer>

## 8. Keep specs in sync

Follow `kit/playbooks/sync.md`. Enforcement: the `pre-commit` hook (`spec_sync` = <warn|block>), plus the
reviewer checking that the diff includes the spec update. If a spec statement becomes false and can't be fixed now,
add a dated Drift Register row.
