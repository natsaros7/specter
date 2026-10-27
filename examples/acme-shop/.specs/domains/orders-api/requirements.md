# orders-api — Requirements (as-built)

Upstream coverage: [`../../system/traceability.md`](../../system/traceability.md).

| ID | Capability | Evidence | Upstream |
|---|---|---|---|
| [REQ-ORD-01] | Create, read, list and cancel orders over REST | `OrderController.java`, `OrderControllerIT` | — |
| [REQ-ORD-02] | An accepted order is published exactly once, even if Kafka is down | `OutboxRelay.java`, `OrderOutboxIT` | CON-REQ-021 |
| [REQ-ORD-03] | Partner calls are authenticated by mTLS subject → partner mapping | `GrpcSecurityFilter.java:88` | CON-REQ-014 |
| [REQ-ORD-04] | Partner requests carry a `timestamp` (presence only; see D1) | `orders.proto:23` | CON-REQ-015 (🔴) |
