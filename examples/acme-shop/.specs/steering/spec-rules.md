# Steering — Spec rules (Acme Shop)

Instantiated from `kit/templates/steering/spec-rules.md`. Only the project-specific values are shown here.

| Rule | Acme Shop value |
|---|---|
| §1 Spec required | > 15 LOC, several files, or any REST/gRPC/Kafka/schema/boundary change |
| §2 Feature folder | `features/ord-<ticket>-<summary>/` (tracker project key `ORD`) |
| §4 Decision authority | ADRs in `docs/adr/`, accepted by the tech lead; contract questions go to the client's product owner; settled non-ADR decisions in [`decisions.md`](decisions.md) |
| §7 Gate | `./mvnw verify` (unit + Testcontainers ITs) · Sonar new-code coverage ≥ 80 %, 0 new blockers · `spec_lint.py` exit 0 |
| §7 Review | Fresh-context review on the diff; security paths (`shop-common/security`) get the deep tier |
| §7 Deploy impact | Argo CD deploys the image tags pinned in `deploy/`, but the nightly `catalog-sync` job builds from `main` (Q9): a merge reaches it the same night. Not `none` → tell the ops lead before the merge |
| §8 Sync enforcement | `pre-commit` hook in `warn` mode |

## Gates

Run in order from the repo root; `python3 .specs/kit/scripts/gates.py` prints the summary for the PR. Sonar runs in CI only.

| # | Gate | Command |
|---|---|---|
| G1 | Build, unit and Testcontainers ITs | `./mvnw verify` |
| G2 | Spec lint | `python3 .specs/kit/scripts/spec_lint.py` |
| G3 | Citations | `python3 .specs/kit/scripts/spec_lint.py --cites` |
