## Agent prompt
Implement ORD-142: validate the partner request `timestamp`, or amend the contract. Work autonomously; stop and ask the
ticket reporter only at items marked DECISION.

### Context
- Repo `acme-shop` (base `main`). Branch `fix/ORD-142-request-timestamp-validation`.
- Problem (verified 2026-10-20, `4e1c2a7`): `SecurityHeader.TIMESTAMP` is flagged mandatory "for replay prevention", but
  `GrpcSecurityFilter` never reads it; the proto only checks presence.
- Why it matters: the ICD promises a replay control that doesn't exist.

### Requirements
- [REQ-TSV-01] … [REQ-TSV-06]: see `requirements.md` in this folder (the table is the contract).

### Steps
1. DECISION: wait for A or B (and `W`, plus the enforcement date, for A). Do not code before it.
2. (A) Add the properties record and `Clock` bean in `shop-common`.
3. (A) Add `validateTimestamp` to `GrpcSecurityFilter`, copying the partner-id failure pattern.
4. (A) Tests as listed in `design.md` § Tests.
5. (B) Javadoc, flag and `SecurityHeaderTest` only.
6. `./mvnw verify` from the root.

### Constraints
- Conventional Commits, subject ≤ 72 chars, includes `ORD-142`.
- Constructor injection; `@ConfigurationProperties` over `@Value`; tests named `should_doX_when_Y`.
- Out of scope: nonce cache, proto changes, ICD edits.

### Verification
- `./mvnw verify` green; Sonar new-code coverage ≥ 80 %, 0 new blockers.
- (A) With `enforce=false` an out-of-window request succeeds and emits an event; with `true` it is denied.

### Deliverables
- One PR to `main`: what changed, the partner clock check, the residual replay-inside-window risk, how it was verified.
- Specs synced per `design.md` § Spec and doc impact.

### Open decisions / dependencies
- DECISION: A or B, `W`, enforcement date (product owner).
