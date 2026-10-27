# Playbook: new feature spec

Write the spec **before** code, for any change over the threshold in `.specs/steering/spec-rules.md` §1.
**Run on:** the strongest model (planning). **Gate:** `spec_lint.py <feature>` exits 0, **and** the user approves.

## 1. Name and frame

- Folder: `.specs/features/<id>-<kebab-summary>/`. Use the tracker key as the prefix when one exists
  (for example `ord-142-request-timestamp-validation`).
- Pick a short, unique `<FEAT>` code for requirement IDs (for example `TSV`, giving `[REQ-TSV-01]`).
- Read the router, the affected `domains/<domain>/design.md`, the Drift Register, and the decision authority
  (spec-rules §4). Pull or fetch first, so you ground against the current main branch.

## 2. requirements.md: WHAT and WHY

Copy the template. Keep the sections in this order:

1. **Why.** Verified evidence: commit sha, date, `path:line`, and what the code does today. Write down what you
   checked and how (`rg isMandatory` finds only tests). This is what makes the spec trustworthy.
2. **User story.** One or two lines.
3. **Decisions that block implementation.** An options table (option, meaning, code effect). If one exists,
   the first task in `tasks.md` is the gate that records the decision.
4. **Requirements.** A table of `[REQ-<FEAT>-NN]`, requirement and acceptance. The acceptance must be testable:
   name the test or the observable behaviour. EARS phrasing ("When …, the system shall …") helps; see `.specs/kit/docs/spec-driven.md`.
5. **Behaviour deltas** (refactors): every observable change, with who signed it off and when.
6. **Out of scope**, then **Open decisions**.

## 3. design.md: HOW

- Trace **every** REQ to concrete components, files and interfaces. Tables beat prose.
- One section per option when a decision is still open. Delete the losing option after the decision.
- Use **Mermaid** for current-vs-target or sequence diagrams where they help.
- Include **Tests** (edges, both modes, property-style where the input space is wide), **Rollout / rollback**
  (feature flag or config default, how to undo) and **Spec and doc impact** (which `domains/` files change, and which
  external documents need the owner's attention).
- It must not contradict the architecture authority. If it needs a new decision, say "ADR required" and stop for the user.

## 4. tasks.md: atomic and traceable

- `- [ ] N <imperative task> — [REQ-…]`. Every task links at least one REQ. One task is roughly one reviewable diff.
- The first task is the decision gate (if there is one). Near the end come the gate run, the spec sync
  (`domains/` update) and the PR.
- For refactors, the **safety net comes first**: characterisation tests (golden responses, query counts, auth matrix)
  on the *unchanged* code, in their own commit or PR. The refactor must pass them unchanged.
- For long work, keep a `## ▶ Resume here` block at the top: goal, where the code is (branch, PR), what's done,
  open decisions, and the exact gate commands.

## 5. Optional: AGENT_PROMPT.md

When an autonomous agent (or a colleague) will implement the feature, also write `AGENT_PROMPT.md` from the template:
context, requirements, steps, constraints, verification, deliverables, and the points where it must **stop and ask**
(marked `DECISION`). It must stand on its own: someone with no access to this conversation can execute it.

## 6. Gate

```bash
python3 .specs/kit/scripts/spec_lint.py <feature-folder>
```

Then show the user the requirements table and the open decisions, and wait for approval before any code.
