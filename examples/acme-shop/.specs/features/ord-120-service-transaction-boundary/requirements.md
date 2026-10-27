# ORD-120 Service transaction boundary — Requirements

> Status: **Done** (merged 2026-11-03, PR #88). ADR-012 Accepted. Kept as history; as-built state is in `domains/orders-api/`.

## Why

Measured on main 2026-10-01 (`b71d0e3`) with `ServiceBoundaryTest` in report mode:

- REST controllers and gRPC services **own the DB transaction** (`@Transactional` on the adapter) and pass JPA entities
  (`*Entity`) in and out of services.
- So lazy relations are loaded from adapter code (hidden N+1), service-level `readOnly`/timeouts are overridden, and
  a gRPC call can report success before its transaction commits.

### Baseline (2026-10-01)

| Metric | Value |
|---|---|
| Adapter classes depending on JPA types | 14 of 41 |
| Lazy relations read in adapters | 23 |
| Adapters owning the transaction | 6 |

## Requirements

| ID | Requirement | Acceptance |
|---|---|---|
| [REQ-STB-01] | Adapters (`..rest..`, `..grpc..`) don't depend on JPA entities or `jakarta.persistence`. | `ServiceBoundaryTest` strict; report shows 0. |
| [REQ-STB-02] | The transaction boundary is the service method, never the adapter. | No `@Transactional` in adapters (ArchUnit); queries are `readOnly`. |
| [REQ-STB-03] | Services take commands/DTOs and return DTOs/records. | No public service method has an entity in its signature (ArchUnit). |
| [REQ-STB-04] | No functional change: REST/gRPC contracts, schema, events and authorisation are unchanged. | The safety net (REQ-STB-05) passes unchanged after each domain. |
| [REQ-STB-05] | A safety net on the **unchanged** code, per domain, before it is touched. | Golden responses for every endpoint (success, 400, 403, 404); SQL statement count ≤ baseline; role × endpoint auth matrix; event payloads equal. Committed in its own PR first. |
| [REQ-STB-06] | Progress is ratcheted: a clean domain can't regress; the end state is one global rule. | `CLEAN_DOMAINS` list in `ServiceBoundaryTest`, replaced at the end by a global strict rule. |

## Behaviour deltas — sign-off

Moving the boundary changes some failure modes. Each was accepted before phase 1:

| Delta | Impact | Decision |
|---|---|---|
| gRPC: commit happens **before** the response is sent (it used to be after) | Removes a false-success window | Accepted as a bug fix — tech lead, 2026-10-02 |
| `OrderCancelled` is published after the commit (it used to be before) | Fixes an event for a cancel that was rolled back | Accepted — tech lead, 2026-10-02 |
| Service-level timeouts start applying | A long query could now time out | Decided: align to today's effective values, so nothing changes |

## Out of scope

- A separate pure domain model (full hexagonal).
- N+1 query tuning (measured separately).
