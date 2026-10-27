# Steering — Spec rules (Acme Shop)

Instantiated from `kit/templates/steering/spec-rules.md`. Only the project-specific values are shown here.

| Rule | Acme Shop value |
|---|---|
| §1 Spec required | > 15 LOC, several files, or any REST/gRPC/Kafka/schema/boundary change |
| §2 Feature folder | `features/ord-<ticket>-<summary>/` (tracker project key `ORD`) |
| §4 Decision authority | ADRs in `docs/adr/`, accepted by the tech lead; contract questions go to the client's product owner |
| §7 Gate | `./mvnw verify` (unit + Testcontainers ITs) · Sonar new-code coverage ≥ 80 %, 0 new blockers · `spec_lint.py` exit 0 |
| §7 Review | Fresh-context review on the diff; security paths (`shop-common/security`) get the deep tier |
| §8 Sync enforcement | `pre-commit` hook in `warn` mode |
