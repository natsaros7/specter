# Onboarding: <System>

You are joining <System>. This page tells you what it is, what to read first, which rules you must not break and how
to take a change from "ready" to "merged". Generic spec-first rules are in the `AGENTS.md` block; this page adds what is
specific to this project. Generated from `.specs/kit/templates/ONBOARDING.md` on <YYYY-MM-DD> (`<sha>`).

## What it is (1 minute)

<Two to five lines: what the system does, for whom, the main parts and the source of truth for its data.>

## Read in this order (15 minutes)

| # | File | What you get |
|---|---|---|
| 1 | [`README.md`](README.md) | the router: for each question, the one file to open |
| 2 | `system/architecture.md` | topology and the component registry |
| 3 | `steering/decisions.md` | what is settled and why. Don't reopen a settled decision; supersede it with a new dated row |
| 4 | [`steering/spec-rules.md`](steering/spec-rules.md) | when a change needs a spec, the decision authority, the Gates table, the Definition of Done |
| 5 | `features/<feature>/requirements.md` | the REQs of the change you pick, each with its acceptance |

## Rules you must not break

<Three to seven rules, each one line, each citing the decision it comes from (`D-<id>`) or the spec-rules section.
Delete this placeholder. Examples of the kind: "no evidence, no claim"; "one writer for X"; "nothing public is removed
without a deprecation".>

- **Names.** <If specs are read by several teams: no team, client, project or person names in `.specs/`; the lint's
  `denylist_sha256` enforces it. Otherwise delete this line.>

## How to work a change

1. **Ready.** The feature spec is approved (`Status:` is not Proposed) and everything it depends on is merged.
2. **Claim.** <How you claim it: assign the ticket, open a draft PR named `<convention>`>. One person per task.
3. **Test first.** The failing test is your first commit. A tests-only change shows its tests failing on a
   deliberately broken copy.
4. **Implement** the task's REQs, and nothing else (`.specs/kit/playbooks/next-task.md`).
5. **Gates.** Run `python3 .specs/kit/scripts/gates.py` from the repo root and paste its `### Gates` block into the PR
   description. It runs the Gates table of `steering/spec-rules.md` in order and stops at the first failure.
6. **Docs.** The spec ships with the code: `domains/` and `system/` updates per `.specs/kit/playbooks/sync.md`, plus
   <CHANGELOG or other project docs>, in the same PR.
7. **Review.** Someone who did not write the change approves it. <Who; which paths get the strongest reviewer.>
8. **Deploy impact.** CI/CD consumes <a pinned artifact or image | the default branch directly: <jobs>>. Add
   `Deploy impact: none` or `Deploy impact: <job or env>: <what changes>` to the PR description. If it is not `none`,
   <the people who run CI/CD> hear before the merge.

## Practical gotchas

- <Local run: how to run the code from source, and what needs a rebuild or reinstall.>
- <Versions: language, runtime and tool versions the gates and CI use.>
- <Tests: network, fixtures, slow suites.>
- <Anything that looks editable by hand but is generated.>

## Starter prompts (any coding agent)

Paste one at the repo root.

**1. Orient me**
```text
Read .specs/ONBOARDING.md, then .specs/README.md, .specs/steering/spec-rules.md and .specs/steering/decisions.md.
Explain in plain words what the system does, how a change is made here, and the rules I must not break (cite the
D-ids). Do not read code yet. End with the changes that are ready to start and what each needs from me.
```

**2. Pick up a change**
```text
I am picking up <feature or task>. Read its requirements.md, design.md and tasks.md under .specs/features/, every
decision its REQs cite in .specs/steering/decisions.md, and check that what it depends on is merged. Then give me the
plan: the failing tests to write first, the files to change, and the exact gate commands from the Gates table.
Do not write code until I confirm. Follow AGENTS.md and .specs/kit/playbooks/next-task.md.
```

**3. Check my change against the spec**
```text
Review my branch against .specs/features/<feature>/: does it implement exactly its REQs and nothing else? Does each
REQ's acceptance test exist and fail without the change? Does it break a decision in .specs/steering/decisions.md?
Is the Deploy impact line right? Run python3 .specs/kit/scripts/gates.py and report the summary. List problems with
file:line and the smallest fix.
```

**4. I disagree with a decision**
```text
I disagree with decision D-<id> in .specs/steering/decisions.md. Show me its reason, where it lands and what it
supersedes. Then draft a new dated row that supersedes it, with my reason, and list every REQ and spec that would
change. Do not edit the old row.
```
