# ORD-142 Validate the request timestamp or amend the contract — Design

Security-sensitive: the diff gets a deep-tier review.

## Option A ([REQ-TSV-02] [REQ-TSV-03] [REQ-TSV-04])

| Where | What |
|---|---|
| `GrpcSecurityFilter.onMessage` | After the partner-id check and before the certificate check, call `validateTimestamp(message)`. It reads `getTimestamp` reflectively, like the existing `getStringValue` helper. A missing getter means skip ([REQ-TSV-04]). |
| Failure | The same shape as the partner-id failure: close with `PERMISSION_DENIED` "Timestamp outside accepted window", security event `AUTH_FAILED`. With `enforce=false`, warn, emit the event and continue. |
| Config | `@ConfigurationProperties("acme.security.timestamp")` record: `Duration maxSkew = PT5M`, `boolean enforce = false`. |
| Clock | Inject `java.time.Clock` (system UTC by default) so tests are deterministic. |

`|now − timestamp| > maxSkew` rejects in both directions. An unset timestamp (epoch 0) is outside every window.

## Option B ([REQ-TSV-05])

Correct the `SecurityHeader.TIMESTAMP` javadoc and flag, and update `SecurityHeaderTest`. No filter change.

## Common ([REQ-TSV-01] [REQ-TSV-06])

[REQ-TSV-01] is task 1, and nothing starts before it. Existing filter tests change only by having the test clock injected.

## Tests

Fixed clock: inside, ±(W−1 ms), ±(W+1 ms), unset, both modes, internal call, type without getter.
Property-style: for random offsets, a request is rejected if and only if |offset| > W.

## Rollout / rollback

Ship with `enforce=false`. Watch the security events for one release, confirm partner clocks, then switch on per
environment. Rollback: `enforce=false`, or revert.

## Spec and doc impact

- `.specs/domains/orders-api/requirements.md` REQ-ORD-04 and `system/traceability.md` CON-REQ-015 → ✅ (A) or amended (B).
- `system/data-flows.md` D1 → RESOLVED.
- ICD Annex B (owner: client product owner): window described (A) or attribute made informational (B).
