# ORD-120 Service transaction boundary — Tasks

## ▶ Resume here (updated 2026-11-03)

**Goal:** ADR-012: adapters own no transaction and touch no entity. **Status: DONE**, PR #88 merged 2026-11-03.

| What | Where |
|---|---|
| Branch / PR | `refactor/ORD-120-service-boundary` → #88 (merged) |
| Burn-down | `target/service-boundary-report.md`: 14/23/6 → 6/9/2 → **0/0/0** |
| Gate | `./mvnw verify` (unit + Testcontainers ITs) |
| Open decisions | none |

## Tasks

- [x] 0.1 `ServiceBoundaryTest` in report mode + baseline recorded — [REQ-STB-06]
- [x] 1.1 Orders: safety net on unchanged code (goldens, SQL counts, auth matrix, events) — [REQ-STB-05]
- [x] 1.2 Orders: move tx + mapping into `OrderService`; net passes unchanged; add to `CLEAN_DOMAINS` — [REQ-STB-01] [REQ-STB-02] [REQ-STB-03] [REQ-STB-04]
- [x] 2.1 Cancellations: safety net — [REQ-STB-05]
- [x] 2.2 Cancellations: refactor; event after commit (signed-off delta) — [REQ-STB-01] [REQ-STB-02] [REQ-STB-04]
- [x] 3.1 Partners + reporting: net, then refactor — [REQ-STB-01] [REQ-STB-03] [REQ-STB-05]
- [x] 4.1 Replace `CLEAN_DOMAINS` with one global strict rule — [REQ-STB-06]
- [x] 4.2 ADR-012 Accepted; domain spec + Drift Register D2 synced — [REQ-STB-04]
