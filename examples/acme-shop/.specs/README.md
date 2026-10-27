# .specs — Acme Shop spec system (example)

> **Example.** Acme Shop is fictional; it shows what `setup.md` produces and what two real-world features look like.
> Paths and line numbers point to an imaginary codebase.

A **link layer** over the existing sources of truth. Where it summarises, the linked source wins.
Grounded on `4e1c2a7`, 2026-10-20. Workflow: [`steering/spec-rules.md`](steering/spec-rules.md).

## Router: read THIS, then open the ONE file you need

| If you need… | Open only |
|---|---|
| What the system does, topology, component registry | [`system/architecture.md`](system/architecture.md) |
| How one domain works | `domains/<domain>/design.md`; this example contains [`orders-api`](domains/orders-api/design.md) |
| End-to-end flows, known drift | [`system/data-flows.md`](system/data-flows.md) |
| Whether a contract requirement (`CON-REQ-NNN`) is implemented | [`system/traceability.md`](system/traceability.md) |
| To make a non-trivial change | [`steering/spec-rules.md`](steering/spec-rules.md), then `kit/playbooks/new-feature.md` |
| Standards and gates | [`steering/code-standards.md`](steering/code-standards.md) |
| What setup learned, and the open UNKNOWNs | [`steering/project-profile.md`](steering/project-profile.md) |

**Domains:** `orders-api` (sync REST + gRPC, owns orders) · `fulfilment-worker` (async, consumes `order-events`) ·
`catalog-cache` (read proxy) · `web` (UI) · `shop-common` (shared lib). Only `orders-api` is written out in this example.

## Features in this example

| Feature | Shows |
|---|---|
| [`ord-142-request-timestamp-validation`](features/ord-142-request-timestamp-validation/requirements.md) | Small change, verified "why", **decision gate before code**, config-flag rollout, `AGENT_PROMPT.md` hand-off |
| [`ord-120-service-transaction-boundary`](features/ord-120-service-transaction-boundary/requirements.md) | Cross-cutting refactor: **safety net first**, measured baseline, behaviour-delta sign-off, ratchet, `▶ Resume here` |

## Sources of truth outside `.specs/`

| Source | Where | Rule |
|---|---|---|
| ADRs | `docs/adr/` | `design.md` must not contradict an Accepted ADR |
| Supply contract (requirements `CON-REQ-NNN`) | Shared drive, "Acme Shop – Contract Annex B" | Link only; traceability is kept in `system/traceability.md` |
| OpenAPI | `orders-api/src/main/resources/openapi.yaml` | Generated from code; authoritative for REST |
