# ORD-142 Validate the request timestamp or amend the contract — Tasks

- [ ] 1 Gate: decision (A or B, and `W`) recorded on ORD-142; delete the unused option from this spec — [REQ-TSV-01]
- [ ] 2 (A) Properties record + `Clock` bean + binding test — [REQ-TSV-03]
- [ ] 3 (A) `validateTimestamp` with reflective getter, skipped when absent — [REQ-TSV-02] [REQ-TSV-04]
- [ ] 4 (A) Deny path and log-only mode — [REQ-TSV-02] [REQ-TSV-03]
- [ ] 5 (A) Tests: edges, unset, both modes, internal call, no getter, property-style — [REQ-TSV-02] [REQ-TSV-03] [REQ-TSV-04]
- [ ] 6 (B) Javadoc and flag corrected; `SecurityHeaderTest` — [REQ-TSV-05]
- [ ] 7 Existing filter tests pass unedited apart from the clock — [REQ-TSV-06]
- [ ] 8 Gate: `./mvnw verify`, deep-tier review (security path) — [REQ-TSV-06]
- [ ] 9 Spec sync: domain requirements, traceability, Drift Register D1 — [REQ-TSV-02] [REQ-TSV-05]
