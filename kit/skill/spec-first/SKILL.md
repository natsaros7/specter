---
name: spec-first
description: Spec-first workflow: set up .specs/ for a repo, spec a change, run the next task, sync or refresh specs. Use for "set up specs", "spec this", "next task", "sync specs".
---

# spec-first

Kit source: `{{KIT_HOME}}`

Pick the mode from the request, then follow the playbook **exactly**. The playbooks are the source of truth; this skill only routes.

| Request | Playbook |
|---|---|
| "install spec-first here", with no `.specs/kit/` yet | `{{KIT_HOME}}/GO.md` (assess → install on yes → setup) |
| "set up / bootstrap specs", or setup still incomplete | `.specs/kit/playbooks/setup.md` |
| "spec this / new feature" | `.specs/kit/playbooks/new-feature.md` |
| "next task / continue <feature>" | `.specs/kit/playbooks/next-task.md` |
| "sync specs / <feature> landed" | `.specs/kit/playbooks/sync.md` |
| "refresh / re-ground specs" | `.specs/kit/playbooks/refresh.md` |
| "lint specs" | `python3 .specs/kit/scripts/spec_lint.py` |

- If your tool has a question UI, use it for the interview questions; otherwise ask in chat.
- If your tool has sub-agents or model profiles, run each step in the role from `.specs/kit/roles/`
  (planner for setup, refresh and specs; generator for tasks; reviewer for diffs).
