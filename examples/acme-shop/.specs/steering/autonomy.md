# Steering — Autonomy profile

What agents may do here without a human, and on what evidence. Editing this file is always a human-tier change.

## Knowledge
| Knowledge | Where | Read |
|---|---|---|
| Router | [router](../README.md) | start |
| Steering | [spec rules](spec-rules.md), [code standards](code-standards.md) | start |
| Decisions | [decisions](decisions.md), ADRs in [`docs/adr/`](../../docs/adr/) | before a design |
| Architecture tests | `ModulesTest`, `ServiceBoundaryTest`, `CodingRulesTest` in `orders-api/src/test/java/com/acme/shop/orders/architecture/` | before a change to a boundary |
| Memory | [lessons](lessons.md) | start |

## Tiers
Rows run from most to least autonomous. A file takes the lowest row a glob matches, so security tests and architecture tests land on `critical` although `*/src/test/*` also matches them; the change takes its strictest file's tier. `pom.xml`, `.mvn/` and the architecture tests are `critical` because a check is switched off there. `none` holds only on `routine`, with every guardrail declared and `routine` `eligible` in `tiers.py --evidence`; the example ships no `--auto-merge` job, so a `none` PR still waits for a human approval.

| Tier | Paths | Reviewer | Human |
|---|---|---|---|
| routine | `*/src/test/*` `docs/*` `*.md` | standard | none |
| domain | `*/src/main/java/*` `*/src/main/resources/application.yml` | standard | spot |
| critical | `*/security/*` `*/architecture/*` `*/src/main/proto/*` `*/openapi.yaml` `*/db/migration/*` `*pom.xml` `.mvn/*` `mvnw*` | deep | required |

## Chores
Runs: C1 weekly, Monday 06:00; C2 weekly, Sunday 22:00. By a schedule you set up (the example ships no CI workflow), as `python3 .specs/kit/scripts/gates.py --file .specs/steering/autonomy.md`. They report; they do not block a merge.

| # | Gate | Command |
|---|---|---|
| C1 | Spec health | `python3 .specs/kit/scripts/spec_lint.py --cites && python3 .specs/kit/scripts/spec_report.py` |
| C2 | Mutation testing (PIT), weekly; the threshold is the first measured score, raised by hand only | `./mvnw -B -Ppit verify` |

## Guardrails
Declared here, enforced by the platform; specter checks only that each row names what enforces it and a date. The platform settings named are the shop's, outside this example.

| Guardrail | Enforced by | Verified |
|---|---|---|
| No direct or force push to the default branch | GitHub ruleset `protect-main` on `main`: no bypass, no force push | 2026-11-23 |
| The Gates run as required checks before a merge | Ruleset `protect-main`: required check `build` (`./mvnw -B verify`) | 2026-11-23 |
| Every PR needs an approval, dropped on a new commit; a human gives it, and only the `ready.py --auto-merge` job's identity (never an agent's) approves a PR labelled `none` | Ruleset `protect-main`: one approving review on every PR, stale approvals dismissed on push, code-owner review on the `critical` globs (the platform repo's `CODEOWNERS` gives them to the platform team; not shipped in the example); no `--auto-merge` job, checked `.github/workflows/` (the example ships no workflow) | 2026-11-24 |
| Agent credentials cannot approve or merge | Agents push as `acme-agent` with a fine-grained token: contents and pull requests write, no admin; not a code owner | 2026-11-23 |
| Agent permissions come from the host's configuration, not from a prompt | The agent host's managed settings on the build host (not in this repository, so no prompt or commit can widen them) | 2026-11-23 |
| Agents cannot edit merged history or review records | Ruleset `protect-main` (no force push, no deletion); GitHub keeps the review log | 2026-11-23 |
| An agent job triggered by untrusted text (an issue, a PR, a comment, an outside contribution) runs read-only, without secrets; its writes go through a separate step that validates them | no such job, checked `.github/workflows/` (the example ships no workflow) | 2026-11-23 |
| Scheduled chores run from a clean clone or the CI checkout of the default branch, never a working copy | launchd `dev.specter.chores` on the build host, from `/srv/chores/acme-shop` (a clone only it pulls), as in `kit/docs/chores.md` | 2026-11-23 |

## Evidence
`python3 .specs/kit/scripts/tiers.py --evidence` counts merges on `main` per tier. Raising a tier's Human value is a human edit of this file, on that report.

| Tier | Window (days) | Min merged | Max reverted % | Max escaped % | Max human-caught % |
|---|---|---|---|---|---|
| routine | 90 | 20 | 2 | 5 | 10 |
| domain | 90 | 30 | 2 | 5 | 10 |
