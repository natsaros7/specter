# Philosophy

These are the lessons from running this workflow on a multi-service production system with AI agents doing most of the
typing. Each one is here because skipping it went wrong at least once.

## 1. Spec before code, but only when it pays

Trivial changes go straight to code. A change needs a spec when it touches several files, any contract (API,
schema, message topic, domain boundary), or more than a small LOC threshold. The spec is where an agent's mistakes are
cheapest to catch: a wrong assumption costs one line in `requirements.md`, or a day in code review.

## 2. Requirements → design → tasks

The Kiro triplet. **requirements.md** says *what and why*, with testable acceptance criteria and stable
`[REQ-…]` IDs. **design.md** says *how*, and traces every REQ to a concrete component. **tasks.md** is a checklist
where every box links to a REQ. The lint checks that links go both ways: no requirement without design and tasks,
and no task without a requirement.

## 3. Evidence or it didn't happen

"Why" sections cite `path:line`, the commit, and *how* the claim was checked. Agents are confident by default; citations
make that confidence checkable. Anything that can't be supported is written as **UNKNOWN**, never guessed.

## 4. A link layer, not a second copy

`.specs/` indexes the real sources of truth (ADRs, contracts, architecture docs) and summarises them in a line. Where
they conflict, the source wins and the conflict is logged. Two copies always drift apart.

## 5. As-built vs proposed

`domains/` describes the system **as it is**. `features/` describes **a proposed change**. When a feature lands, it is
folded into `domains/` and the feature folder becomes history. Readers always know which tense they're reading.

## 6. The spec ships with the code

Same commit, or the change isn't done. A hook reminds (or blocks); review checks.

## 7. A logged drift beats a confident, stale spec

When the spec is wrong and you can't fix it now, add a dated **Drift Register** row. A known drift is recoverable. A
spec that is confidently wrong misleads every agent that reads it, and agents read it on every task.

## 8. Scripts judge structure; AI judges content

Pass or fail on structure (files present, IDs traced, links resolve, spec touched) is a script: fast, free, the same
every time. Models are for what scripts can't judge: is this design sound, is this acceptance criterion testable.

## 9. Routers save tokens and attention

One small index file says "for X, open only Y". Agents that read everything get slower, costlier and less accurate.

## 10. Ask, but ask well

Setup interviews the user only where the code is silent: at most five questions a round, each saying what the
answer changes, each with a default. Answers are recorded so nobody asks twice. Good questions are cheap; wrong
guesses cost a lot later.

## 11. One task, one gate, one fresh reviewer

Work goes one task at a time. Each task ends with the project's gate, and a reviewer that didn't write the code
looks at the frozen diff. The implementer gets one retry; after that, escalate (`kit/docs/review-loop.md`).

## 12. Decisions block code

If the right behaviour is somebody's decision (product, security, a client), the first task is the decision gate
and nothing starts before it. Writing both options into the design is fine. Implementing a guess is not.
