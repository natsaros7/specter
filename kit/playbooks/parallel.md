# Playbook: parallel dispatch

Run several agents on one feature without them trampling each other. **Run on:** the lead (dispatcher) only; workers
follow `next-task.md`. Each rule exists because skipping it cost a session; see `.specs/steering/lessons.md`.

## Before a batch

1. **Size.** At most 3 agents per batch. Group tasks by the functions and files they touch, so one batch never has two
   workers in the same code. Tasks that touch the same function go in different batches.
2. **Worktrees.** Give each worker its own `git worktree`; never share a checkout (see "Running parallel workers
   safely" in `.specs/kit/docs/review-loop.md`). Put scratch clones under `$HOME`, not `/tmp`: a container runtime
   may share only `$HOME`.
3. **Base check.** A worktree can start on the default branch, not on the feature tip. The worker's first step is
   `git log -1 --format=%H` and, if it differs from the sha you name, `git reset --hard <sha>`.
4. **No bytecode, unique temp files.** Set `PYTHONDONTWRITEBYTECODE=1`. Every temp file comes from `mktemp`; never
   write a fixed name in a shared `$TMPDIR`.
5. **Claim.** Each worker comments on its issue that it took the task.

## While it runs

- **Red first.** The worker writes the failing test, then the fix. It runs the full selftest once, at the end, not
  after every edit.
- **No polling loops.** Nobody writes `until …; sleep`. The dispatcher is notified when a worker finishes; it does
  not poll. A waiting agent does other work or stops.
- **Gate output goes to a file** from `mktemp`. Read the `rc` lines, never judge a gate through `| tail`.

## Landing

1. Land each worker's commit on the feature branch with `git cherry-pick <sha>` and check its exit code. A conflict
   is resolved by hand, not skipped.
2. After each landing, count the task lines in `tasks.md`: a conflict can drop one.
3. Run G1 to G4 once on the tip (`sh tests/gates.sh --docker`), not per worker. Read each `G<n> rc=` line.
4. Close the issues (`Closes #n` in the commit) and update the `▶ Resume here` block with what landed and what is next.

## Stopping

- At the end of each batch and at session start, list running processes from earlier work (leftover selftests, polling
  loops, agents from another session) and stop them.
- Kill by PID, never by a pattern: a pattern your own command contains matches that command too.

## Changing this file

This file and `lessons.md` are trust-layer files. An agent proposes the change, a human approves it.
