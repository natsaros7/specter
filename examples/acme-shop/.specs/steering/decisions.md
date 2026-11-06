# Steering — Decisions (Acme Shop)

Instantiated from `kit/templates/steering/decisions.md`. A decision changes only by a new dated row that supersedes the
old one; settled rows are never edited. Architecture decisions stay ADRs in `docs/adr/` (spec-rules §4).

## 2026-10-02: ORD-120 behaviour deltas

| ID | Decision | Why | Where it lands | Supersedes |
|---|---|---|---|---|
| D-1 | A gRPC call commits its transaction before the response is sent. | It used to answer first, so a partner could see success for a write that then rolled back. Accepted as a bug fix by the tech lead. | [REQ-STB-02], [REQ-STB-04] | |
| D-2 | Service-level timeouts apply with their configured values once adapters stop owning the transaction. | The configured values are the documented ones. | [REQ-STB-04] | |

## 2026-10-09: ORD-120 safety net findings

| ID | Decision | Why | Where it lands | Supersedes |
|---|---|---|---|---|
| D-3 | Service-level timeouts are aligned to today's effective values, so nothing changes for callers. | The safety net showed the configured values are shorter than what adapters effectively allowed: two partner reports would start timing out. Tech lead, 2026-10-09. | [REQ-STB-04] | D-2 |
