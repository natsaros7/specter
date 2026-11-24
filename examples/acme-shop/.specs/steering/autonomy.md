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
Rows run from most to least autonomous. A file takes the lowest row a glob matches, so security tests and architecture tests land on `critical` although `*/src/test/*` also matches them; the change takes its strictest file's tier. `pom.xml`, `.mvn/` and the architecture tests are `critical` because a check is switched off there. Until auto-merge is decided, `none` behaves as `spot`.

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
