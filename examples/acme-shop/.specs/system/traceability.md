# Traceability — contract requirements ↔ code

Source: Acme Shop Contract Annex B (shared drive). Status: ✅ implemented + tested · 🟡 partial · 🔴 missing or unverified.

| Upstream ID | Requirement (short) | Domain REQ | Code | Test | Status |
|---|---|---|---|---|---|
| CON-REQ-014 | Partners authenticate with mutual TLS | REQ-ORD-03 | `shop-common/…/security/GrpcSecurityFilter.java:88` | `GrpcSecurityFilterTest` | ✅ |
| CON-REQ-015 | Stale or replayed partner requests are rejected | REQ-ORD-04 | presence check only (D1) | — | 🔴 see ord-142 |
| CON-REQ-021 | An accepted order is never lost if publishing fails | REQ-ORD-02 | `OrderService.placeOrder` + outbox | `OrderOutboxIT` | ✅ |
