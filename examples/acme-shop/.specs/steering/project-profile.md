# Project profile

status: active
phase: done
grounded: 4e1c2a7 on main, 2026-10-20
agent: Claude Code (deep tier) for setup; refreshed by Codex on 2026-11-03

## Facts

| Fact | Evidence | Confidence | Open question |
|---|---|---|---|
| Monorepo, 4 deployables + 1 lib; this example builds two Maven modules (`orders-api`, `shop-common`), the other three are spec-only | `pom.xml` modules | high | — |
| orders-api exposes REST + gRPC | `OrderController.java`, `orders.proto` | high | — |
| Topics `order-events`, `.retry`, `.dlt` are config for the outbox sink (no Kafka client in the example) | `application.yml:16-18` | high | — |
| Requirements come from a supply contract | `docs/README.md` mentions "Annex B" | low → answered Q1 | — |
| ADRs in `docs/adr/`: the example ships ADR-007, ADR-012 and ADR-013 | folder listing | high | — |
| Gate = the Gates table in `spec-rules.md`; the example ships no CI workflow and no Sonar | `steering/spec-rules.md` | high | — |
| CI/CD consumes: pinned image tags (Argo CD, `deploy/`); the nightly `catalog-sync` job builds from `main` | answered Q9 | high | — |

## Domain map (approved 2026-10-20)

| Domain | Path | Kind | Contracts | Depends on | REQ prefix | Confidence |
|---|---|---|---|---|---|---|
| orders-api | `orders-api/` | deployable | REST, gRPC, Kafka producer | shop-common | ORD | high |
| fulfilment-worker | `fulfilment-worker/` | deployable | Kafka consumer, Carrier HTTPS | shop-common | FUL | high |
| catalog-cache | `catalog-cache/` | deployable | gRPC | orders-api | CAT | medium |
| web | `web/` | deployable | REST client | orders-api | WEB | high |
| shop-common | `shop-common/` | library | security filter, event schemas | — | COMMON | high |

## Interview log

| Date | Q | Question | Answer | Effect |
|---|---|---|---|---|
| 2026-10-20 | Q1 | Where do requirements live? | Contract Annex B on the shared drive, IDs `CON-REQ-NNN` | `traceability.md` created; `upstream_req_pattern` set |
| 2026-10-20 | Q3 | Who decides architecture? | ADRs; the tech lead accepts | spec-rules §4 |
| 2026-10-20 | Q4 | Gate? | `./mvnw verify`, Sonar new-code coverage ≥ 80 % | spec-rules §7 |
| 2026-10-20 | Q6 | Spec threshold? | assumed: default (15 LOC / multi-file / contract) | spec-rules §1 |
| 2026-10-20 | Q7 | Hook warn or block? Code paths? | Warn for now, block after a month; paths as detected | `spec_sync: warn`, `code_globs` |
| 2026-10-20 | Q9 | How does CI/CD consume the repo? | Services: pinned image tags; but `catalog-sync` builds from `main` every night | spec-rules §7 Deploy impact |
| 2026-10-20 | Phase 4 | Domain map + file list OK? | go, but keep `shop-common` separate (it carries the security filter) | 5 domains |

## UNKNOWN

- Whether catalog-cache is still used by partners or only by the web — asked 2026-10-20, ask the ops lead.
