## Spec-first workflow (specter)

This project keeps its specs in `.specs/`. Read `.specs/README.md` first. It is the router: open only the one file it points to.

**Before you change code**
- If `.specs/steering/project-profile.md` is missing or still lists `status: setup-incomplete`, the spec system is not set up yet. Offer to run `.specs/kit/playbooks/setup.md`, and do nothing else spec-related until the user answers.
- Use the size threshold in `.specs/steering/spec-rules.md` §1. A non-trivial change (multi-file, any contract/schema/boundary change, or over the LOC threshold) needs a feature spec **before** code: follow `.specs/kit/playbooks/new-feature.md`.
- Never assume an API, config key or feature exists. Verify it in code and cite `path:line`.

**While you change code**
- Work one task from `tasks.md` at a time (`.specs/kit/playbooks/next-task.md`). Tick a task only when its code and tests are in and the project's gate is green.
- Do not make design decisions the spec left open. Stop and ask, or record an open question.

**Before you call it done**
- The spec ships in the same commit as the code: follow `.specs/kit/playbooks/sync.md`.
- If a spec statement becomes false and you can't fix it now, add a dated row to the Drift Register (`.specs/system/data-flows.md`). Don't leave the spec silently wrong.
- Run `python3 .specs/kit/scripts/spec_lint.py`. It must exit 0.

**Asking the user**
Ask in chat and wait for the answer. Ask at most 5 questions per round. For each question, say what the answer changes and give your best guess as the default. Record each answer in `.specs/steering/project-profile.md` so nobody asks it again.
