---
name: spec-first
description: Spec-first workflow: set up .specs/ for a repo, write a feature spec, run the next task, sync specs, refresh. Use for "set up specs", "spec this", "next task", "sync specs".
---

# spec-first

Kit source: `{{KIT_HOME}}` (empty = installed per project only).

Pick the mode from the request, then follow the playbook **exactly**. The playbooks are the source of truth;
this skill only routes.

| Request | Playbook |
|---|---|
| "install spec-first here", with no `.specs/kit/` yet | `{{KIT_HOME}}/GO.md` (assess → install on yes → setup) |
| "set up / bootstrap specs", or setup still incomplete | `.specs/kit/playbooks/setup.md` |
| "spec this / new feature" | `.specs/kit/playbooks/new-feature.md` |
| "next task / continue <feature>" | `.specs/kit/playbooks/next-task.md` |
| "sync specs / the feature landed" | `.specs/kit/playbooks/sync.md` |
| "refresh / re-ground specs" | `.specs/kit/playbooks/refresh.md` |
| "lint specs" | `python3 .specs/kit/scripts/spec_lint.py` |

Claude Code specifics:
- Ask the setup interview questions with the AskUserQuestion tool where it fits (≤4 per call). Otherwise ask in chat.
- Setup, refresh and new-feature are deep-tier work. If the `planner` agent is installed, delegate there with the
  playbook path. Implementation tasks go to `generator`, and diff review to `reviewer`
  (`.specs/kit/docs/model-routing.md`, `.specs/kit/docs/review-loop.md`).
