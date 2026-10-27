# ORD-142 Validate the request timestamp or amend the contract — Requirements

Tracker: ORD-142. Branch `fix/ORD-142-request-timestamp-validation`. Size S. **Blocked on a product-owner decision.**

## Why

Verified on main 2026-10-20 (`4e1c2a7`):

- `shop-common/src/main/java/com/acme/shop/security/SecurityHeader.java:41`: `TIMESTAMP("timestamp", true)`, javadoc
  "mandatory, for replay prevention". `isMandatory()` has no caller in main code (`rg isMandatory` finds tests only).
- `shop-common/.../security/GrpcSecurityFilter.java:120-131` reads partner id and certificate subject; it never reads `timestamp`.
- `orders.proto:23` marks `timestamp` as required. That checks presence only: an epoch-0 or week-old value passes.
- The partner ICD (Annex B, CON-REQ-015) says stale requests are rejected.

So the contract promises a replay control that the code doesn't have. A captured request can be replayed unchanged.

## User story

As the client's security officer, I want the request timestamp either checked against a time window or dropped from
the contract, so that the documented control matches the system.

## Decision — blocks implementation

| Option | Meaning | Code effect |
|---|---|---|
| A. Validate | Reject requests whose `timestamp` is outside `now ± W` | Filter check, config, tests |
| B. Amend contract | `timestamp` is informational (audit only) | Javadoc and flag corrected; ICD updated by its owner |

Note for the decision: a window limits replay to the window. It does not prevent replay inside it (no nonce).

## Requirements

| ID | Requirement | Acceptance |
|---|---|---|
| [REQ-TSV-01] | The decision (A or B, and `W` for A) is recorded on the ticket before implementation. | Ticket comment; the unused option is deleted from this spec. |
| [REQ-TSV-02] | (A) A partner request with `timestamp` outside `now ± W` is rejected with `PERMISSION_DENIED` and a security event. | Filter tests: inside passes; ±(W−1 ms) passes; ±(W+1 ms) is rejected; unset is rejected. |
| [REQ-TSV-03] | (A) `W` and enforcement are config: `acme.security.timestamp.max-skew` (default `PT5M`), `acme.security.timestamp.enforce` (default `false` = log and event only). | Tests for both modes; binding test for the properties. |
| [REQ-TSV-04] | (A) Internal system calls and messages without a `timestamp` field are not affected. | Tests: internal call and a type with no getter both pass. |
| [REQ-TSV-05] | (B) `SecurityHeader.TIMESTAMP` no longer claims replay prevention. | `SecurityHeaderTest` updated; filter unchanged. |
| [REQ-TSV-06] | Valid in-window requests and all other headers behave as before. | Existing filter tests pass unedited (only the test clock is injected). |

## Out of scope

- Nonce or request-id replay cache.
- Clock-sync requirements on partners.
- Editing the ICD (its owner does that after the decision).

## Open decisions

- DECISION (product owner): A or B; for A, `W` and the date enforcement is switched on.
