# v065 acme-shop gets real Java code — Tasks

Deploy impact: none for installed projects (the installer copies only `kit/` parts; nothing under `kit/` changes).
Specter's clone grows by the example's sources, and contributors who touch example code need JDK 21 and one online
Maven run for G5.

## ▶ Resume here

Goal: acme-shop becomes a small real Java 21 / Spring Boot / Spring Modulith codebase whose specs are true, checked by
deterministic gates, and usable as the factory test project. Branch `feat/0.6.5-acme-java`. Open
decisions are recorded under Decided in requirements.md (Boot 4.x, release 0.6.5 alone, G5 skip exit 0, local sandbox). Gates: specter G1 to G5 from
`AGENTS.md`, and the example's own G1 to G3 from `examples/acme-shop/`.

## Tasks

- [x] 1 Gate: the Boot, release, G5-skip and sandbox decisions are recorded under Decided in requirements.md
  (done 2026-11-21); delete the losing options from the design — [REQ-V065-01] [REQ-V065-09] [REQ-V065-11]
- [x] 2 Reactor skeleton: root and module `pom.xml` files with pinned versions, Enforcer, Error Prone + NullAway,
  Spotless, script-only wrapper with checksum, `.sdkmanrc` (`java=21.0.13.1+2-tem`), a Boot 4.x pairing check of each
  library (record gaps), `.gitignore`, `.mvn/jvm.config`; an empty build passes offline on the
  second run — [REQ-V065-01] [REQ-V065-03]
  Done 2026-11-21. Files: `examples/acme-shop/` `pom.xml`, `shop-common/pom.xml`, `orders-api/pom.xml`, `mvnw`, `mvnw.cmd`,
  `.mvn/wrapper/maven-wrapper.properties` (Maven 3.9.16, `distributionSha256Sum`, type only-script, no jar),
  `.mvn/jvm.config`, `.sdkmanrc`, `.gitignore`; placeholders: `package-info.java` (`@NullMarked`) in
  `com.acme.shop.security` (shop-common) and `com.acme.shop.orders` plus `OrdersApplication` (orders-api).
  `./mvnw -B verify` and `./mvnw -B -o verify` both pass; Enforcer (Java 21+, Maven 3.9+, dependencyConvergence),
  Error Prone + NullAway (as ERROR, `-Werror`, OnlyNullMarked) and Spotless (palantir) ran; a planted nullable
  dereference and a badly formatted file each failed the build.
  Versions (all released 2026-11-07 or earlier): Boot 4.1.2, Modulith 2.1.2, grpc-java 1.84.1, protobuf-java 4.36.2,
  protobuf-maven-plugin 5.1.11 (`io.github.ascopes`), springdoc 3.2.0, jqwik 1.10.2, ArchUnit 1.5.1, Error Prone 2.51.0,
  NullAway 0.14.3, JSpecify 1.0.1, PIT 1.30.1 with pitest-junit5-plugin 1.2.3, Spotless 3.10.4, Enforcer 3.7.0,
  compiler plugin 3.16.0. The design's list is updated.
  Pairing check (scratch module with spring-boot-starter-test, jqwik, ArchUnit, Modulith test starter, springdoc api,
  PIT; not committed): all ran green on Boot 4.1.2 / JUnit Jupiter 6.0.3. **No gap found.** Findings: (1) the Boot BOM
  manages grpc-java 1.84.1, protobuf-java 4.36.2 and `io.github.ascopes` protobuf-maven-plugin 5.1.11, so the pins equal
  the BOM values (newer 1.85.1 / 5.1.12 exist; not used, to stay with the BOM); (2) `grpc-protobuf` still declares
  protobuf-java 3.25.9, the BOM's 4.36.2 wins through dependencyManagement, so tasks 5 must check the generated stubs
  compile against it; (3) the 4.1.3 and 4.2.0 Boot releases (2026-11-19) are inside the two-week window, so not used;
  (4) JDK 21 needs `-XDaddTypeAnnotationsToSymbol=true` and `--add-exports` flags for Error Prone, set in the compiler
  args and `.mvn/jvm.config`; (5) jqwik prints a banner telling AI agents to disregard its results: ignore it, but note
  it when reading test output.

- [x] 3 `shop-common`: `SecurityHeader`, `GrpcSecurityFilter` (presence-only timestamp kept), `PeerSubjectResolver`,
  `ShopSecurityConfiguration`, event records, error codes, `MutableClock` test jar; `GrpcSecurityFilterTest`,
  `SecurityHeaderTest` — [REQ-V065-02]
  Done 2026-11-21. Files under `examples/acme-shop/shop-common/`: `security/{SecurityHeader,GrpcSecurityFilter,PeerSubjectResolver,ShopSecurityConfiguration}`, `events/{OrderPlaced,OrderCancelled}`, `errors/ErrorCode`, test jar `time/MutableClock`; tests `GrpcSecurityFilterTest` (in-process gRPC, stub subject), `SecurityHeaderTest`, `ShopSecurityConfigurationTest`. orders-api gets the test jar as a test dependency. Root pom pins `error_prone_annotations` (grpc-api and guava disagreed; dependencyConvergence) and maven-jar-plugin 3.5.1. Timestamp is never read, as designed.
- [ ] 4 `order` module: Flyway V1, entities, `OrderService`, `OrderController`, `CurrencyPolicy`, `OrderControllerIT`,
  `OpenApiSnapshotTest` with the recorded `openapi.yaml`; plant the S2 defect with no test covering it —
  [REQ-V065-02] [REQ-V065-10]
- [ ] 5 `partner` module: proto2 `orders.proto`, in-process gRPC server, `PartnerOrdersService`,
  `PartnerOrdersCommitTest` — [REQ-V065-02] [REQ-V065-03]
- [ ] 6 `outbox` module: Flyway V2, Modulith JPA registry, `OutboxRelay`, logging sink, topic properties, Clock-driven
  resubmission, `OrderOutboxIT` — [REQ-V065-02]
- [ ] 7 Architecture lane: `ModulesTest` (with the module docs), `ServiceBoundaryTest`, `CodingRulesTest`, all tagged
  `architecture` and in package `com.acme.shop.orders.architecture` so the `*/architecture/*` tier glob matches (check
  that Modulith does not read that package as a fourth module); settle the G2 `groups` UNKNOWN — [REQ-V065-04]
- [ ] 8 jqwik fence (Decided 2026-11-21): exact 1.10.2 pin, an output-scan gate that fails on agent-directed text in
  Maven test output except the one known jqwik clause (allow-listed verbatim), proven red with a planted line; jqwik `CurrencyPolicyProperties`; `pit` profile, first measured threshold, the jqwik UNKNOWN settled —
  [REQ-V065-04] [REQ-V065-05]
- [ ] 9 Prove the check map: break each rule once on a scratch branch, paste each red gate line into the PR, drop the
  branch — [REQ-V065-04]
- [ ] 10 Example spec sync: every row of the spec-delta table, the three ADR files, citation line numbers set to the
  real lines and opened one by one, `examples/acme-shop/README.md` with the sandbox recipe; `--cites` exit 0 on a clean
  tree, after a build, and in a copy without `.git` — [REQ-V065-05] [REQ-V065-06] [REQ-V065-07] [REQ-V065-10]
- [ ] 11 `examples/cite-demo/` fixture, README Try it block and sentence, selftest case 1 `--cites` and the cite-demo
  case, `AGENTS.md` G1 and G2 commands — [REQ-V065-08] [REQ-V065-09]
- [ ] 12 `tests/acme-build.sh` and the G5 row; with no `java` on `PATH` it prints `G5 SKIPPED: needs JDK 21+` and exits
  0; run it also online and with `ACME_OFFLINE=1` — [REQ-V065-09]
- [ ] 13 Dry run in a sandbox: S5 up to its stop, S2 end to end; record what the agent did, the gate lines and what
  the human caught, here under the task — [REQ-V065-10]
- [ ] 14 Gate green: specter G1 to G5 (G5 run, not skipped) and the example's G1 to G3; `git diff --stat` shows nothing
  under `kit/`; deep review of the security filter and the G5 script — [REQ-V065-03] [REQ-V065-11]
- [ ] 15 CHANGELOG `[0.6.5]`, `VERSION`, `docs/reference.md` line, `docs/assets/report.png` regenerated or noted;
  release 0.6.5 — [REQ-V065-11]
