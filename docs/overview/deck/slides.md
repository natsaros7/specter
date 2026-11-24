---
theme: apple-basic
colorSchema: light
transition: slide-left
mdc: true
title: specter overview
layout: intro
fonts:
  sans: Inter
  mono: Fira Code
---

# specter

Specs that don't go stale. A spec-first workflow for any AI coding agent.

<div class="pt-6 opacity-70">

Release 0.8.0 shipped · 0.9.0 in progress · Python 3.8+, stdlib only, no service

</div>

---

# The problem

<div class="grid grid-cols-2 gap-8 pt-4">
<div>

### Without a spec discipline

- An agent writes a spec that sounds right and cites code that does not exist
- The spec drifts from the code and nobody notices
- A human reads every change, with no hint where to look hardest
- A mistake is cheapest to catch in one line of a requirement, and dearest in code review

</div>
<div>

### With specter

- Every claim carries `path:line`; a lint fails the build when a citation points at nothing
- Drift goes into a dated Drift Register instead of being hidden
- Scripts judge structure; the model judges content
- Each change gets a risk label, a readiness verdict and, after the merge, evidence

</div>
</div>

---

# The spec-first workflow

<img src="/diagrams/workflow.svg" class="mx-auto" style="width: 900px; margin-top: 10px" />

<div class="text-sm opacity-70 pt-2">Setup reads your existing code and writes as-built docs first. Then every change runs the same loop.</div>

---

# What is in the kit

`install.sh` copies one folder into the project: `.specs/kit/`. Teammates get it with the repo.

| Part | What it holds |
|---|---|
| `AGENT_RULES.md`, `playbooks/` | setup, new-feature, next-task, sync, refresh |
| `roles/` | planner (deep), generator (standard), reviewer (fresh context) |
| `templates/` | requirements, design, tasks, steering files, autonomy profile |
| `scripts/` | `spec_lint`, `spec_report`, `spec_sync_check`, `gates`, `tiers`, `ready` |
| `docs/` | spec-driven method, review loop, model routing, chores |
| `adapters/` | Claude Code skill and agents, Cursor rule, `AGENTS.md` block |

<div class="text-sm opacity-70 pt-2">Works with Codex, Claude Code, Cursor, Copilot and Gemini CLI. Nothing leaves the machine.</div>

---

# Spec health in one page

<div class="grid grid-cols-5 gap-6">
<div class="col-span-2 text-sm">

`spec_report.py` writes `.specs/report.html`:

- feature progress from `tasks.md`
- open drift with age
- lint and citation counts
- **In flight**: worktrees and unmerged branches

Run on the acme-shop example at release 0.8.0.

</div>
<div class="col-span-3">
<img src="/screens/07-spec-report.png" style="width: 400px; border: 1px solid #ddd; border-radius: 6px" />
</div>
</div>

---

# The trust layer (0.8.0)

<img src="/diagrams/trust-layer.svg" class="mx-auto" style="width: 900px; margin-top: 6px" />

<div class="text-sm opacity-70">Everything runs offline and edits nothing. The profile is read at the base commit, so a change cannot rewrite its own rules.</div>

---

# Tiers: where to look hardest

<div class="grid grid-cols-5 gap-6">
<div class="col-span-2 text-sm">

`.specs/steering/autonomy.md` holds a Tiers table: routine, domain, critical.

- each file takes the lowest row a glob matches
- the change takes its strictest file
- guarded paths (profile, kit, agent files) always take the last row
- an undeclared guardrail turns `none` into `spot`

Labels only: every change still gets the human check.

</div>
<div class="col-span-3">
<img src="/screens/02-tiers-staged.png" style="width: 520px; border-radius: 6px" />
<img src="/screens/03-tiers-range.png" style="width: 520px; border-radius: 6px; margin-top: 10px" />
</div>
</div>

---

# Gates and the readiness verdict

<div class="grid grid-cols-2 gap-6 pt-2">
<div>

### `gates.py`

<img src="/screens/04-gates.png" style="width: 420px; border-radius: 6px" />

<div class="text-sm pt-2">Runs the project's own Gates table, stops at the first red, prints the block for the PR.</div>

</div>
<div>

### `ready.py`

<img src="/screens/05-ready.png" style="width: 440px; border-radius: 6px" />

<div class="text-sm pt-2">Reads the PR text: Gates at the head commit, the Review block, Verification lines. It runs no command.</div>

</div>
</div>

---

# Review contract and guardrails

<div class="grid grid-cols-2 gap-8 pt-2">
<div>

### Review contract

- reviewer is a fresh context, working from the **base** commit's rules
- a reviewer model in the implementer's family is a warning
- a **blocker** needs location, evidence, trigger and consequence; anything less is advisory and becomes a follow-up
- a Verification line must point at an artifact that exists at the head

</div>
<div>

### Guardrails

- eight declared rows: protected branch, required checks, human review on `required` paths, agent credentials that cannot merge, host-set permissions, immutable history, read-only untrusted-text jobs, chores from a clean clone
- a row counts when it names what enforces it and a date
- specter records the declaration and probes nothing

</div>
</div>

---

# Evidence: which tier earned more autonomy

<div class="grid grid-cols-5 gap-6">
<div class="col-span-2 text-sm">

`tiers.py --evidence` reads merged history and counts per tier: merged, reverted, escaped, human-caught.

- each tier is `eligible`, `hold` or `breach`
- too few merges or a shallow clone is a hold, never a pass
- it edits nothing; raising a tier is a human edit

Demo history: ten commits with `Human-Findings:` trailers and one `git revert`. Thresholds were set small for the demo.

</div>
<div class="col-span-3">
<img src="/screens/06-evidence.png" style="width: 540px; border-radius: 6px" />
</div>
</div>

---

# Where it stands on the ladder

<img src="/diagrams/roadmap.svg" class="mx-auto" style="height: 400px; margin-top: 6px" />

<div class="text-sm opacity-70">Shipped: 0.6.0 to 0.8.0. Planned: 0.9.0. Candidates: v070. Stage 5 is out of scope.</div>

---

# What 0.9.0 adds (planned, not shipped)

Slice 4 of the staged-autonomy feature. Tasks 21 to 23 are open on the `feat/0.9.0` branch.

| Piece | What it does |
|---|---|
| Human check by tier | `required` as today; `spot` approves on the verdict, gates and tests; `none` only on the lowest tier, with guardrails declared and evidence `eligible` |
| Platform recipe | required checks, auto-merge on green, CODEOWNERS, a merge queue; the kit merges nothing |
| Fix-round cap | two fix rounds per task, then the human gets both outputs; `ready.py` checks `rounds:` |
| Demotion on breach | `--evidence` prints the profile line to tighten; a human edits it |
| `pipeline.md` | triage, implement, review, merge: what each hands on, when the human enters |

---

# What v070 might add, and what stays out

<div class="grid grid-cols-2 gap-8 pt-2">
<div>

### Candidates (not decided)

- **E6** verification gates proposed by stack: property tests, contract tests, architecture tests
- **E9** a Drift Register entry that names an anti-pattern gets a contain action: a lint rule first, then cleanup tasks
- **E10** task export to a tracker (GitHub, GitLab, Jira, Linear) through a small offline adapter

</div>
<div>

### Out of scope

- Kiro's stage 5, a coordinating agent
- a queue, scheduler, orchestrator or merge bot in the kit
- classifying a change by content: tiers go by path
- live platform APIs; specter stays offline

</div>
</div>

---

# Try it

```bash
git clone https://github.com/natsaros7/specter.git ~/tools/specter && cd ~/tools/specter
python3 kit/scripts/spec_lint.py --specs examples/acme-shop/.specs --cites   # passes
python3 kit/scripts/spec_lint.py --specs examples/cite-demo/.specs --cites   # fails on purpose, exit 1
```

In your project, open your agent and paste:

```text
Follow ~/tools/specter/GO.md for this project.
```

It looks, proposes, installs on your yes, then interviews you (about 20 minutes). Without AI: `install.sh ~/code/my-project --dry-run`.
