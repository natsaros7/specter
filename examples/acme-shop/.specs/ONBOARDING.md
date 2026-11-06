# Onboarding: Acme Shop

You are joining Acme Shop. This page tells you what it is, what to read first, which rules you must not break and how
to take a change from "ready" to "merged". Generic spec-first rules are in the `AGENTS.md` block; this page adds what is
specific to this project. Generated from `.specs/kit/templates/ONBOARDING.md` on 2026-11-03 (`4e1c2a7`).

## What it is (1 minute)

An online shop for partner retailers. `orders-api` takes orders over REST (web) and gRPC (partners) and publishes
`order-events` to Kafka; `fulfilment-worker` consumes them and calls the carrier; `catalog-cache` proxies the catalogue;
`web` is the UI; `shop-common` carries the security filter and event schemas. Requirements come from a supply contract
(`CON-REQ-NNN`).

## Read in this order (15 minutes)

| # | File | What you get |
|---|---|---|
| 1 | [`README.md`](README.md) | the router: for each question, the one file to open |
| 2 | [`system/architecture.md`](system/architecture.md) | topology and the component registry |
| 3 | [`steering/decisions.md`](steering/decisions.md) | what is settled and why. Don't reopen a settled decision; supersede it with a new dated row |
| 4 | [`steering/spec-rules.md`](steering/spec-rules.md) | when a change needs a spec, the decision authority, the Gates table, the Definition of Done |
| 5 | `features/<feature>/requirements.md` | the REQs of the change you pick, each with its acceptance |

## Rules you must not break

- **Adapters own no transaction and touch no entity** (ADR-012; REQ-STB-01, REQ-STB-02). `ServiceBoundaryTest` fails
  the build otherwise.
- **A gRPC call commits before it answers** (D-1). Don't move the response back inside the transaction.
- **Timeouts stay at today's effective values** (D-3, which superseded D-2).
- **The contract wins.** A change that touches a `CON-REQ-NNN` updates `system/traceability.md` in the same PR.
- **Security paths** (`shop-common/security`) get the deep-tier reviewer.

## How to work a change

1. **Ready.** The feature spec is approved (`Status:` is not Proposed) and everything it depends on is merged.
   ORD-142 is not ready: it waits for the product owner's decision.
2. **Claim.** Assign the `ORD-` ticket to yourself and open a draft PR named `ORD-<n>: <title>`. One person per task.
3. **Test first.** The failing test is your first commit. A refactor starts with its safety net on unchanged code.
4. **Implement** the task's REQs, and nothing else (`.specs/kit/playbooks/next-task.md`).
5. **Gates.** Run `python3 .specs/kit/scripts/gates.py` from the repo root and paste its `### Gates` block into the PR
   description. Sonar runs in CI.
6. **Docs.** The spec ships with the code: `domains/` and `system/` updates per `.specs/kit/playbooks/sync.md`, and
   `CHANGELOG.md`, in the same PR.
7. **Review.** Someone who did not write the change approves it; the tech lead for anything under `shop-common/security`.
8. **Deploy impact.** Services deploy pinned image tags, but the nightly `catalog-sync` job builds from `main`. Add
   `Deploy impact: none` or `Deploy impact: <job or env>: <what changes>` to the PR description. If it is not `none`,
   the ops lead hears before the merge.

## Practical gotchas

- **Local run:** `./mvnw -pl orders-api spring-boot:run` needs Docker for the Testcontainers-backed dev profile.
- **Versions:** Java 21, Maven wrapper only; CI uses the same wrapper.
- **Tests:** ITs start Kafka and PostgreSQL containers; the first run pulls images.
- **Generated:** `openapi.yaml` is generated from the controllers. Change the code, not the file.

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
