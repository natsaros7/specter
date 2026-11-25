# Steering — Spec rules (spec-first)

How changes are proposed, designed and tracked in specter. It wraps the project's existing gates and doesn't replace them.

## 1. When a spec is required

| Change | Spec? |
|---|---|
| Trivial: ≤ 30 LOC, one file, no interface/schema/contract change | No. Edit directly; still pass the Definition of Done. |
| Non-trivial: > 30 LOC **or** several files **or** any API/contract, DB schema, message topic, or domain-boundary change | **Yes**, before touching code (`kit/playbooks/new-feature.md`). |

## 2. Feature layout

```
.specs/features/v<NNN>-<summary>/
├── requirements.md   # WHAT & WHY: evidence, user story, [REQ-<FEAT>-NN] + acceptance
├── design.md         # HOW: every REQ traced to components/interfaces; tests; rollout; doc impact
├── tasks.md          # atomic `- [ ]` tasks, each linked to a REQ
└── AGENT_PROMPT.md   # optional: a standalone brief for an autonomous implementer
```

Folder names are kebab-case and prefixed with the release they target (`v061-…`); GitHub issues track each task.
Acceptance criteria are testable. `design.md` must not contradict the architecture authority (§4).

## 3. Execution

One task at a time (`kit/playbooks/next-task.md`). Tick it when code and tests are in and the gate is green.
Refactors are characterised first: a safety net on the unchanged code, in its own commit, which the refactor must pass unchanged.

## 4. Decision authority

The maintainer decides, in PR review; each feature's `design.md` keeps a Decisions table. A design that needs a new architectural decision
raises one (an ADR, or the project's equivalent) before implementation. Settled decisions that are not ADRs go in
`steering/decisions.md` (template `kit/templates/steering/decisions.md`): cite them by id, and change one only by a new
dated row that supersedes it.

## 5. Domains vs features

`domains/` = **as-built** (living documentation). `features/` = **proposed change**. When a feature lands, fold it into
`domains/`; the feature folder becomes history.

## 6. Grounding

Pull the main branch before asserting code facts. Cite `path:line`. Never assume an API, config key or feature exists.

## 7. Definition of Done

1. Every gate below exits 0. `python3 .specs/kit/scripts/gates.py` runs them in order, stops at the first failure and
   prints a `### Gates` block for the PR description, red runs too (rows after a failure read `not run`). Put the
   cheapest rows first: the run stops at the first failure. One command per row, in backticks; write a `|` inside a command
   as `\|`. `gates.py` executes these commands with `sh -c` from the project root, and nothing else: treat this table
   like code, and read it before running `gates.py` on a branch you didn't write.

   | # | Gate | Command |
   |---|---|---|
   | G1 | Shell syntax | `sh tests/gates.sh --docker --only G1` |
   | G2 | Example specs lint and citations | `sh tests/gates.sh --docker --only G2` |
   | G3 | Selftest | `sh tests/gates.sh --docker --only G3` |
   | G4 | Specter's own specs and README | `sh tests/gates.sh --docker --only G4` |

2. `tasks.md` fully ticked and `Status: Done <date> (<branch, commit or PR>)` set; affected `domains/` (and `system/`) docs updated in the same commit (§8).
3. The change states `Deploy impact: none` or `Deploy impact: <job or env>: <what changes>`. Specter ships as files
   from tagged releases; there is no deploy (setup Q9). If it is not `none`, the people who run CI/CD
   hear before the merge.
4. Fresh-context review on the diff. The reviewer's tier is the `Reviewer` column of the row `tiers.py` gives, run from a
   trusted copy of the kit at the base (`.specs/kit/docs/review-loop.md` step 3), from the Tiers table in `steering/autonomy.md`.

## 8. Keep specs in sync

Follow `kit/playbooks/sync.md`. Enforcement: the `pre-commit` hook (not installed in specter itself; `tests/gates.sh` and the pre-push hook run instead), plus the
reviewer checking that the diff includes the spec update. If a spec statement becomes false and can't be fixed now,
add a dated Drift Register row.
