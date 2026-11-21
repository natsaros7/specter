# v065 acme-shop gets real Java code — Tasks

Deploy impact: none for installed projects (the installer copies only `kit/` parts; nothing under `kit/` changes).
Specter's clone grows by the example's sources, and contributors who touch example code need JDK 21 and one online
Maven run for G5.

## ▶ Resume here

Goal: acme-shop becomes a small real Java 21 / Spring Boot / Spring Modulith codebase whose specs are true, checked by
deterministic gates, and usable as the factory test project. Branch `feat/0.6.5-acme-java` (not created yet). Open
decisions: Boot line, release number, G5 skip code, hosted sandbox (requirements.md). Gates: specter G1 to G5 from
`AGENTS.md`, and the example's own G1 to G3 from `examples/acme-shop/`.

## Tasks

- [ ] 1 Gate: record the Boot-line, release and G5-skip decisions in requirements.md; delete the losing options from
  the design — [REQ-V065-01] [REQ-V065-09] [REQ-V065-11]
- [ ] 2 Reactor skeleton: root and module `pom.xml` files with pinned versions, Enforcer, Error Prone + NullAway,
  Spotless, script-only wrapper with checksum, `.gitignore`, `.mvn/jvm.config`; an empty build passes offline on the
  second run — [REQ-V065-01] [REQ-V065-03]
- [ ] 3 `shop-common`: `SecurityHeader`, `GrpcSecurityFilter` (presence-only timestamp kept), `PeerSubjectResolver`,
  `ShopSecurityConfiguration`, event records, error codes, `MutableClock` test jar; `GrpcSecurityFilterTest`,
  `SecurityHeaderTest` — [REQ-V065-02]
- [ ] 4 `order` module: Flyway V1, entities, `OrderService`, `OrderController`, `CurrencyPolicy`, `OrderControllerIT`,
  `OpenApiSnapshotTest` with the recorded `openapi.yaml`; plant the S2 defect with no test covering it —
  [REQ-V065-02] [REQ-V065-10]
- [ ] 5 `partner` module: proto2 `orders.proto`, in-process gRPC server, `PartnerOrdersService`,
  `PartnerOrdersCommitTest` — [REQ-V065-02] [REQ-V065-03]
- [ ] 6 `outbox` module: Flyway V2, Modulith JPA registry, `OutboxRelay`, logging sink, topic properties, Clock-driven
  resubmission, `OrderOutboxIT` — [REQ-V065-02]
- [ ] 7 Architecture lane: `ModulesTest` (with the module docs), `ServiceBoundaryTest`, `CodingRulesTest`, all tagged
  `architecture`; settle the G2 `groups` UNKNOWN — [REQ-V065-04]
- [ ] 8 jqwik `CurrencyPolicyProperties`; `pit` profile, first measured threshold, the jqwik UNKNOWN settled —
  [REQ-V065-04] [REQ-V065-05]
- [ ] 9 Prove the check map: break each rule once on a scratch branch, paste each red gate line into the PR, drop the
  branch — [REQ-V065-04]
- [ ] 10 Example spec sync: every row of the spec-delta table, the three ADR files, citation line numbers set to the
  real lines and opened one by one, `examples/acme-shop/README.md` with the sandbox recipe; `--cites` exit 0 on a clean
  tree, after a build, and in a copy without `.git` — [REQ-V065-05] [REQ-V065-06] [REQ-V065-07] [REQ-V065-10]
- [ ] 11 `examples/cite-demo/` fixture, README Try it block and sentence, selftest case 1 `--cites` and the cite-demo
  case, `AGENTS.md` G1 and G2 commands — [REQ-V065-08] [REQ-V065-09]
- [ ] 12 `tests/acme-build.sh` and the G5 row; run it with no `java` on `PATH`, online, and with `ACME_OFFLINE=1` —
  [REQ-V065-09]
- [ ] 13 Dry run in a sandbox: S5 up to its stop, S2 end to end; record what the agent did, the gate lines and what
  the human caught, here under the task — [REQ-V065-10]
- [ ] 14 Gate green: specter G1 to G5 (G5 run, not skipped) and the example's G1 to G3; `git diff --stat` shows nothing
  under `kit/`; deep review of the security filter and the G5 script — [REQ-V065-03] [REQ-V065-11]
- [ ] 15 CHANGELOG `[0.6.5]`, `VERSION`, `docs/reference.md` line, `docs/assets/report.png` regenerated or noted;
  release 0.6.5 — [REQ-V065-11]
