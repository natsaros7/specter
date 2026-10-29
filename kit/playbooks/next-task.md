# Playbook: next task

Execute a feature one task at a time. **Run on:** a mid-tier model is enough when the spec is clear.

1. Open `.specs/features/<feature>/tasks.md`. Read the `▶ Resume here` block if there is one, then
   `requirements.md` and `design.md`.
2. Take the **first unchecked** task whose prerequisites are done. If it is a `DECISION` gate that is still open, stop and
   ask the user. Don't work around it.
3. Implement only that task. Follow the design. Where the design is silent, don't decide: record an open question
   in `requirements.md` and ask.
4. Run the gate from `.specs/steering/spec-rules.md` (Definition of Done): the narrowest command that covers the change
   now, and the full gate before a push.
   - On failure, fix it and run once more with the full error output in front of you.
   - A second failure means stop: report the spec, the diff and both error outputs (see `.specs/kit/docs/review-loop.md`
     — it escalates to a stronger model or to a human).
5. Review the diff yourself: does it do only what the task says, and does every changed behaviour trace to a REQ?
6. Tick `- [x]` only when code and tests are in and the gate is green. Update `▶ Resume here`.
7. If the task changed an interface, config, schema or dependency, do the matching part of `sync.md` now, in the
   same commit.
8. If this was the last task, run the close-out in `.specs/kit/playbooks/sync.md` before you say the feature is finished.

Never tick a task because the code "looks right". Never commit on behalf of the user unless they asked you to.
