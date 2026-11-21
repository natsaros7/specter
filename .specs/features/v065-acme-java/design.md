# v065 acme-shop gets real Java code — Design

Risk: low for specter users (no file under `kit/` changes, the installer never copies `examples/`). Medium for the repo:
the example becomes code that must keep building, and its line-number citations move whenever that code moves.
Review on the standard tier; the security filter (`shop-common/…/security/`) and the G5 script on the deep tier.

## Shape ([REQ-V065-01])

| Option | For | Against | Ops impact |
|---|---|---|---|
| **One Maven reactor: root `pom.xml`, modules `shop-common` and `orders-api`; Spring Modulith modules inside `orders-api`** (chosen) | Four of the seven citations already name `shop-common/src/main/java/…` paths. The approved domain map keeps `shop-common` a separate library because it carries the security filter (`examples/acme-shop/.specs/steering/project-profile.md:40`). Still one build, one wrapper, one `./mvnw verify`. The library/app split gives tiers a clean path for security code | Two `pom.xml` files instead of one | One command builds all; `-pl orders-api` for a quicker loop |
| One Maven module, everything as Modulith modules (shop-common becomes a package) | Smallest build file count; every boundary checked by `verify()` | Rewrites four citations, the domain map and the ONBOARDING rules; a shared library that is not a library misteaches the multi-service story the specs tell | Same build time |
| Separate repository for the code, linked from the example | Specter's clone stays small; evidence counting works there at once | Citations from `examples/acme-shop/.specs/` can't resolve without a second checkout; the README demo needs a clone step; two repos to keep in step | Two release trains |

Inside `orders-api` the application root is `com.acme.shop.orders`; each direct sub-package is a Modulith module.
Sub-packages of a module are internal to it, which is how Modulith enforces "talk through the API only".

| Maven module / Modulith module | Holds | Makes true |
|---|---|---|
| `shop-common` (library, depends on `grpc-api`, `spring-boot`, JSpecify; no web, no JPA) | `security.SecurityHeader` (enum; `TIMESTAMP("timestamp", true)`, javadoc "mandatory, for replay prevention"), `security.GrpcSecurityFilter` (a gRPC `ServerInterceptor`; certificate subject to partner id; reads `partnerId` from the message reflectively with a `getStringValue` helper; never reads `timestamp`), `security.PeerSubjectResolver` (reads the TLS session's peer subject; tests pass a stub), `security.ShopSecurityConfiguration` (imported by the app), `events.OrderPlaced` and `events.OrderCancelled` records with an event id, `errors.ErrorCode`. Test jar: `time.MutableClock` | ord-142 Why lines, requirement ORD-03, CON-REQ-014, lesson 2026-10-27 (the fake clock), architecture "security filter, error model, event schemas" |
| `orders-api` → `order` | API: `OrderService` (`@Transactional`, queries `readOnly`), `PlaceOrderCommand`, `OrderDto`, `OrderLineDto`. Internal: `order.internal` (entities, repository, entity-to-DTO mapping inside the service), `order.rest.OrderController` (create, get, list, cancel on `/api/v1/orders`), `order.rest.CurrencyPolicy` (unknown currency → 422) | requirement ORD-01, ord-120 end state (STB-01 to STB-03), lesson 2026-11-03 |
| `orders-api` → `partner` | `orders.proto` (proto2, so `required int64 timestamp` is a presence check enforced by protobuf), `partner.grpc.PartnerOrdersService` (`PlaceOrder`, `GetOrder`, `CancelOrder`, calls `OrderService`, owns no transaction), `partner.GrpcServerLifecycle` (an in-process gRPC server with the security filter) | gRPC interface, D-1, requirement ORD-04 presence only, drift D1 |
| `orders-api` → `outbox` | Spring Modulith event publication registry on JPA (the publication row is written in the order's transaction), `OutboxRelay` (an `@ApplicationModuleListener` that hands each event to `OrderEventSink`), `LoggingOrderEventSink`, `EventTopicsProperties` bound from `application.yml` (`order-events`, `.retry`, `.dlt`), resubmission of incomplete publications on a `Clock`-driven schedule | ADR-007, requirement ORD-02, CON-REQ-021, the `application.yml` topics citation |
| `orders-api` resources | `application.yml`, Flyway `V1__orders.sql`, `V2__event_publication.sql`, `openapi.yaml` (generated, snapshot-checked) | domain design Data and Public interface |

`pom.xml` version `2.4.0-SNAPSHOT`, as the domain design says. `ShopSecurityConfiguration` exists because ord-142's
option A puts its properties record and `Clock` bean in `shop-common`; seed S5 needs that seam.

### gRPC without a network listener ([REQ-V065-02] [REQ-V065-03])

| Option | For | Against | Ops impact |
|---|---|---|---|
| **grpc-java with protoc codegen; an in-process server only; no starter** (chosen) | The filter is a real `ServerInterceptor`, so ORD-142 (seed S5) is real work; in-process transport opens no port; about 30 lines replace a starter (Boot 4.x support not checked, none needed) | No TLS listener, so the production subject path (`PeerSubjectResolver` reading the SSL session) is unit-tested with a stub, not end to end. `shortcut: in-process gRPC only, add a TLS listener with generated test certificates when a seed task needs a real partner client` | protoc is downloaded once per OS by the build plugin, then cached |
| A gRPC starter (`grpc-spring-boot-starter` as the domain design names, or Spring gRPC) | Matches the domain design's stack line | Opens port 9090 by default; Boot 4.x compatibility not checked; more config to read | A listening port during tests |
| Keep `orders.proto` as a contract file only; no gRPC code | Smallest | ORD-142, D-1 and requirement ORD-03 lose their code; the critical-tier seed tasks disappear | — |

### Events without a broker ([REQ-V065-02] [REQ-V065-03])

| Option | For | Against | Ops impact |
|---|---|---|---|
| **Spring Modulith event publication registry (JPA) + an `OrderEventSink` port with a logging sink** (chosen) | A real transactional outbox in a few lines; incomplete publications are visible in a table and resubmitted; no network | No Kafka adapter. `shortcut: events end in a logging sink, add a Kafka adapter behind OrderEventSink when a seed task needs a consumer` | One more table in H2 |
| Spring Kafka with an embedded broker in tests | Matches "Spring Kafka" in the stack line | Embedded broker is slow, flaky on laptops, opens ports; a runtime broker is still needed to run the app | Port use, longer builds |
| Hand-written outbox table and relay | Mirrors ADR-007 literally | More code that Modulith already ships, more to review | Same as chosen |

An outbox delivers at least once: a crash between the sink call and the completion mark repeats the event. So the
as-built requirement ORD-02 changes from "exactly once" to "never lost, at least once; each event carries an id for consumers
to drop repeats" (spec delta below). `OrderOutboxIT` proves: the order commits when the sink fails, the event arrives
after resubmission, and it arrives once on that path.

### Persistence

H2 in memory, PostgreSQL mode, schema `orders`, Flyway V1 and V2. `shortcut: H2 in PostgreSQL mode, not PostgreSQL;
move the ITs to Testcontainers when a seed task needs PostgreSQL-only SQL`. No Testcontainers: they need Docker, which
breaks the offline rule and the "protect the laptop" preference.

## Offline and safe to copy ([REQ-V065-03])

- Dependencies only from Maven Central; the wrapper is the script-only type, with `distributionSha256Sum` pinned in
  `.mvn/wrapper/maven-wrapper.properties`. No `maven-wrapper.jar`, no binary file of any kind.
- Versions are pinned in the root `pom.xml` properties, chosen in task 2 from Maven Central, each released at least two
  weeks before 2026-11-21 (so 2026-11-07 or earlier). Pairing check done 2026-11-21 (details in tasks.md task 2):

  | Library | Version | Pairing with Boot 4.1.2 |
  |---|---|---|
  | Spring Boot BOM | 4.1.2 (4.1.3 and 4.2.0 are from 2026-11-19, too new) | the base |
  | Spring Modulith BOM | 2.1.2 | `spring-modulith-starter-test` and `ApplicationModules.verify()` run on Boot 4.1.2 |
  | grpc-java, protobuf-java, protobuf-maven-plugin (`io.github.ascopes`) | 1.84.1, 4.36.2, 5.1.11 | the Boot 4.1.2 BOM manages exactly these three, so no clash; no gRPC starter, as chosen |
  | springdoc-openapi | 3.2.0 | its own parent is Boot 4.1.2; `springdoc-openapi-starter-webmvc-api` resolves |
  | jqwik | 1.10.2 | runs on JUnit Jupiter 6.0.3 (Boot's); its engine pom names platform 1.14.4, so keep it under the Boot-managed JUnit |
  | ArchUnit | 1.5.1 | loads and imports classes on JDK 21 / JUnit 6 |
  | Error Prone, NullAway, JSpecify | 2.51.0, 0.14.3, 1.0.1 | NullAway 0.14.3 builds on JSpecify 1.0.1; Spring Framework 7 is JSpecify-annotated |
  | PIT, JUnit 5 plugin | 1.30.1, 1.2.3 | runs the jqwik property and the Jupiter tests |
  | Spotless, Enforcer | 3.10.4, 3.7.0 | no pairing issue |

  No gap found; the checks ran in a scratch build, not on the real code (tasks 7 and 8 confirm there).
- No outbound call anywhere: no Kafka or HTTP client, no carrier client, no Testcontainers, no telemetry, no devtools.
  The app listens on 8080 for REST when run locally; tests use MockMvc and the in-process gRPC channel.
- No secret: no keystore, certificate, private key or password beyond H2's default empty one. Partner subjects and ids
  are fictional (`CN=partner-a.example`, `P-0001`).
- Maven Enforcer: Java 21 or newer, Maven 3.9 or newer, no duplicate dependency versions.
- `examples/acme-shop/.gitignore`: `target/`. `.mvn/jvm.config`: the `--add-exports` flags Error Prone needs on JDK 21.
- `examples/acme-shop/.sdkmanrc`: `java=21.0.13.1+2-tem` (the maintainer's Temurin 21.0.13.1 via SDKMAN).

## Deterministic checks ([REQ-V065-04] [REQ-V065-05])

### Static analyzer

| Option | For | Against | Ops impact |
|---|---|---|---|
| **Error Prone + NullAway (JSpecify `@NullMarked` packages)** (chosen) | Runs inside `javac`, so a finding fails the compile, the cheapest lane; finds bug patterns and null dereferences, the classes agents produce most; JSpecify is the annotation set Spring itself adopted | Needs `--add-exports` flags; tied to JDK versions; generated proto code must be excluded | Adds a few seconds to compile |
| Checkstyle | Familiar; can ban imports and patterns | Mostly style, which the formatter already settles; its bans are regex-level. The bans this example needs (sleep, field injection, `@Value`) read better as ArchUnit rules with a `because` message that tells the agent the fix | Separate plugin run, more noise for agents |
| SpotBugs | Bytecode analysis; finds some bugs Error Prone misses | Separate phase after compile; more false positives to triage; slower | Slower gate |
| PMD | Many rules out of the box | Overlaps Error Prone and the formatter; rule tuning work | Slower gate |

Formatting is a separate, complementary check: Spotless with palantir-java-format, `spotless:check` in `verify`
(the as-built code standards already name Spotless). Agents fix with `./mvnw spotless:apply`.

### How many Gates rows

| Option | For | Against | Ops impact |
|---|---|---|---|
| One row: `./mvnw -B verify` | Fastest total; one Maven start | The `### Gates` block can't say which check failed or ran; a decision's `Checked by` (v060 slice 2) can only ever say G1 | One line per PR |
| **A fast row per lane, then the full build** (chosen) | Cheapest lanes fail first (the slice-2 template advice); `Checked by` can name the lane that enforces a decision; the readiness verdict shows which lane ran | Three Maven starts; the full build reruns the architecture tests (seconds) | About 20 to 30 s more per gate run on a warm cache |
| One row per check, nothing repeated | Exact lane evidence | Surefire and failsafe selection gets fragile; ITs need the `verify` phase anyway | Most config to maintain |

The example's Gates table (`examples/acme-shop/.specs/steering/spec-rules.md`), run from the repo root:

| # | Gate | Command |
|---|---|---|
| G1 | Compile, Error Prone + NullAway, format | `./mvnw -B -q -DskipTests verify` |
| G2 | Architecture: Modulith `verify()`, ArchUnit | `./mvnw -B -q test -Dgroups=architecture` |
| G3 | Full build: unit, property, integration and architecture tests | `./mvnw -B verify` |
| G4 | Spec lint | `python3 .specs/kit/scripts/spec_lint.py` |
| G5 | Citations | `python3 .specs/kit/scripts/spec_lint.py --cites` |

Architecture tests carry the JUnit tag `architecture`. Settled in task 7: Surefire's `groups` filter passes quietly in `shop-common` (no tagged test, no report, exit 0), so G2 stays as written, run from the reactor root (`-pl orders-api` alone cannot resolve the unbuilt `shop-common` jars).

### Check map: lesson or decision → check

This is the "every correction becomes a deterministic check" flow, made visible. A broken rule turns its gate red;
task 9 proves each row by breaking it once on a scratch branch.

| Source in the example | Rule | Check | Gate |
|---|---|---|---|
| Lesson 2026-10-27 (`examples/acme-shop/.specs/steering/lessons.md:5`) | No real sleeps; time comes from a `Clock` | `CodingRulesTest`: no class, main or test, calls `Thread.sleep` or `TimeUnit.sleep` (`because`: "use MutableClock from shop-common's test jar"); the outbox resubmission test drives a `MutableClock` | G2 |
| Lesson 2026-11-03 (`examples/acme-shop/.specs/steering/lessons.md:6`) | Unknown `currency` → 422, never 400 | jqwik `CurrencyPolicyProperties`: for any string outside the accepted set, the status is 422; malformed JSON stays 400 (one MockMvc example each) | G3 |
| ADR-012, ord-120 STB-01 to STB-03 (`ServiceBoundaryTest` named in `examples/acme-shop/.specs/ONBOARDING.md:26-27`) | Adapters own no transaction and see no entity; services take and return DTOs; queries `readOnly` | `ServiceBoundaryTest` (ArchUnit, one global strict rule set: ord-120's end state) | G2 |
| ADR-013 (new: Modulith modules) | Modules use each other's API package only; no cycles | `ModulesTest`: `ApplicationModules.of(...).verify()`; it also writes the module diagrams to `target/spring-modulith-docs/`, a verification artifact a reviewer can open | G2 |
| D-1 (`examples/acme-shop/.specs/steering/decisions.md:10`) | A gRPC call commits before it answers | `PartnerOrdersCommitTest`: inside the test observer's `onNext`, no transaction is active and the order is readable from a new transaction | G3 |
| ONBOARDING gotcha "Generated" (`examples/acme-shop/.specs/ONBOARDING.md:55`) | Change the controllers, not `openapi.yaml` | `OpenApiSnapshotTest`: the generated document equals the committed file; `-Dopenapi.record=true` rewrites it, like ord-120's `-Dsafetynet.record=true` | G3 |
| AGENT_PROMPT constraints (`examples/acme-shop/.specs/features/ord-142-request-timestamp-validation/AGENT_PROMPT.md:24`) | Constructor injection | `CodingRulesTest`: no field injection (ArchUnit's general coding rule) | G2 |
| Code standards (new row) | No unchecked null dereference | NullAway in compile | G1 |
| Code standards (Spotless row) | One format | `spotless:check` | G1 |
| ADR-007, CON-REQ-021 | An accepted order is never lost when the sink fails | `OrderOutboxIT` | G3 |
| Lesson rule "a lesson seen twice becomes a check" | Tests that can't kill mutants don't count | PIT on `com.acme.shop.security` and `com.acme.shop.orders.order`, threshold = the first measured score, raised by hand only (ord-120's ratchet idea) | chore C2 |

D-3 (timeouts at today's values) stays guidance with no check: a test that pins two numbers adds little. It shows
that `Checked by` may be empty. `@Value` is deliberately not banned yet: that ban is seed S6.

PIT runs weekly as chore C2 (`./mvnw -B -Ppit verify`), not as a gate: it takes minutes and its score moves with the
code, so it reports rather than blocks. Task 2's scratch build showed PIT's JUnit 5 plugin runs jqwik properties; task 8 confirms it on the real tests, and if
not, the `pit` profile excludes them.

## Citations stay true ([REQ-V065-06])

- The code is written first; then every cited line number in the example is updated to the real line, and a reviewer
  opens each one. Padding code (blank lines, filler comments) to hit an old number is a review blocker.
- The seven citations and what each line must show: `GrpcSecurityFilter` subject-to-partner mapping (requirement ORD-03 and
  CON-REQ-014, today line 88); `orders.proto` `timestamp` declared `required` (today line 23, two places);
  `SecurityHeader` `TIMESTAMP("timestamp", true)` (today line 41); `GrpcSecurityFilter` reading partner id and
  certificate subject and no timestamp (today lines 120-131); `application.yml` topic names (today lines 41-47).
- A build leaves copies such as `orders-api/target/classes/application.yml`. `.gitignore` keeps them out of
  `git ls-files`; for a copy without git, where the lint falls back to every file, the example's `spec-kit.json` gains
  `"cite_ignore_globs": ["*/target/*"]`.
- Specter's G2 gains `--cites` for the example, so an edit to example code that moves a cited line fails specter's
  gate. That is the product working, and the reason the citations are worth keeping.

## Spec deltas in the example ([REQ-V065-07])

| File | Change | Why |
|---|---|---|
| `.specs/README.md` | "imaginary codebase" → the code is in this folder; dates and shas are part of the story, paths and lines are real and lint-checked. Sources table: three ADR files. Domains line: three domains are spec-only | REQ-V065-01, REQ-V065-07 |
| `.specs/ONBOARDING.md` | Local run needs no Docker (H2, in-process gRPC); tests start no containers; no Sonar step; the "Generated" gotcha names `OpenApiSnapshotTest` | REQ-V065-03 |
| `.specs/spec-kit.json` | `cite_ignore_globs` | REQ-V065-06 |
| `.specs/steering/spec-rules.md` | §7 Gate row and the Gates table above; Sonar removed | REQ-V065-04 |
| `.specs/steering/code-standards.md` | Rows point to the root `pom.xml` (Spotless, Error Prone, NullAway, Enforcer) and the architecture tests; CONTRIBUTING, CI workflow and Sonar rows removed (the example ships none) | REQ-V065-04 |
| `.specs/steering/autonomy.md` | Knowledge rows: ADRs (`../../docs/adr/`), architecture tests; chore C2 (PIT) | REQ-V065-05 |
| `.specs/steering/lessons.md` | One new line: 2026-11-12, config read with `@Value`; use a `@ConfigurationProperties` record. Seen once, so no check yet (seed S6) | REQ-V065-10 |
| `.specs/steering/project-profile.md` | Facts: two Maven modules plus three spec-only domains; topics are config for the outbox sink; three ADRs; the gate is the Gates table. The interview log stays as it is (history) | REQ-V065-07 |
| `.specs/system/architecture.md` | Registry: orders-api is Java 21, Boot 4.x, Spring Modulith 2.x, H2, in-process gRPC, logging event sink; the diagram marks PostgreSQL, Kafka and the three spec-only components as "not in the example code" | REQ-V065-07 |
| `.specs/system/data-flows.md` | §2 notes OrderPaid is not implemented; new drift D5 (🟡, OrderPaid named in the docs, not in the code, resolved by seed S4); D4's ground truth drops "and chart" | REQ-V065-07, REQ-V065-10 |
| `.specs/system/traceability.md` | Line numbers only | REQ-V065-06 |
| `.specs/domains/orders-api/design.md` | Stack line (grpc-java in-process, Modulith registry, no Kafka client), Behaviour adds the three modules, events `OrderPlaced` and `OrderCancelled` (OrderPaid → D5), Data H2 with V1–V2, Config: no deploy charts in the example | REQ-V065-07 |
| `.specs/domains/orders-api/requirements.md` | Requirement ORD-02 wording: never lost, at least once, events carry an id; line numbers | Outbox semantics above |
| `.specs/features/ord-142-…/requirements.md`, `AGENT_PROMPT.md` | Line numbers; AGENT_PROMPT verification runs the Gates table instead of Sonar. It is the live seed S5, not history | REQ-V065-06 |
| `docs/adr/ADR-007-*.md`, `ADR-012-*.md`, `ADR-013-*.md` (new, short) | The ADRs the specs name, and the Modulith one | Knowledge rows must link to real files |

`ord-120` keeps every line, including "Testcontainers ITs" in its tasks: it is Done and history.

## The README demo ([REQ-V065-08])

| Option | For | Against | Ops impact |
|---|---|---|---|
| **A fixture `examples/cite-demo/` built to fail** (chosen) | Keeps the two-minute "watch it fail" moment; reproduces `docs/assets/lint-demo.svg`, so the picture becomes real output; acme stays green | One more small folder | The selftest pins its output, so the README can't drift |
| A deliberately broken citation inside acme-shop | No new folder | Acme's citation gate and its chore C1 are red forever; the factory's readiness verdict can never be green | Every sandbox run starts red |
| README shows acme passing, then a `sed` that breaks a line in a temp copy | No new files | Longer demo; `sed -i` differs on macOS and Linux | Fragile instructions |
| Drop the failure demo; the SVG alone shows it | Zero files | Loses try-it-yourself | — |

Fixture: `examples/cite-demo/.specs/domains/orders/requirements.md` with the SVG's three citations, and
`examples/cite-demo/src/orders/OrderService.java`, 39 lines, line 20 not blank. Expected output: `past end of file
(39 lines)` for the line-142 citation, `no such file` for `RateLimiter.java`, `2 FAIL of 3 citation(s)`, exit 1.

README "Try it" block: lint the example (passes), check its citations (passes), then
`python3 kit/scripts/spec_lint.py --specs examples/cite-demo/.specs --cites` (fails on purpose). The sentence at
`README.md:29-30` changes to say that acme-shop's citations resolve against its code and cite-demo shows a failure.

## Specter's gates ([REQ-V065-09])

| Decided for G5 (2026-11-21; losing options removed) | For | Against | Ops impact |
|---|---|---|---|
| **Optional G5, `sh tests/acme-build.sh`: no JDK 21 → `G5 SKIPPED: needs JDK 21+ (found: <version or none>)`, exit 0; a build or download failure → exit 1** (chosen) | Kit contributors need no JDK; the skip is visible as the last line, which is what a `### Gates` block shows; a broken pom or a bad version pin is never mistaken for "offline" | A skip exits 0, so only the rule below stops a change to example code going in unbuilt | First run downloads about 200 to 400 MB into `~/.m2`, then `-o` works |

Script behaviour, about fifteen lines of POSIX sh: find `java` (`JAVA_HOME` first, then `PATH`), read the major
version, skip below 21; otherwise `cd examples/acme-shop && ./mvnw -B verify`, adding `-o` when `ACME_OFFLINE=1`.
On a dependency resolution failure it prints one hint line ("the first run needs network to fill ~/.m2") before
exiting 1.

`AGENTS.md` table after the change:

| # | Gate | Command |
|---|---|---|
| G1 | Shell syntax | `sh -n install.sh && sh -n tests/selftest.sh && sh -n tests/acme-build.sh` |
| G2 | Example specs lint and citations | `python3 kit/scripts/spec_lint.py --specs examples/acme-shop/.specs && python3 kit/scripts/spec_lint.py --specs examples/acme-shop/.specs --cites` |
| G3 | Selftest | `sh tests/selftest.sh` |
| G4 | Specter's own specs | (unchanged) |
| G5 | Example build (optional; must run, not skip, when the diff touches `examples/acme-shop/` outside `.specs/`) | `sh tests/acme-build.sh` |

Selftest: case 1 adds the example's `--cites` (no JDK needed: it checks files and lines only) and a case for the
cite-demo fixture (both FAIL lines, exit 1). It never calls `acme-build.sh`.

## The factory test project ([REQ-V065-10])

### Where agents work

| Option | For | Against | Ops impact |
|---|---|---|---|
| **A disposable local copy with its own `git init`** (chosen until v060 slice 3) | Agents merge freely; evidence accrues in its own log; reset and re-run seeds as a benchmark; nothing leaves the machine | No platform guardrails (protected branch, required checks) to test | Re-copy to pick up example changes |

Sandbox recipe (goes into `examples/acme-shop/README.md`, a new file for humans: build, run, sandbox):

```sh
S=~/sandbox/acme-shop; rm -rf "$S" && cp -R examples/acme-shop "$S" && git -C "$S" init -q
./install.sh "$S"                      # adopt mode: adds .specs/kit/, keeps the specs; add --agents=… to wire agents
git -C "$S" add -A && git -C "$S" commit -qm "chore: acme-shop sandbox from specter $(git rev-parse --short HEAD)"
```

After install, the example's own Gates rows G4 and G5 and chore C1 find `.specs/kit/scripts/` and run.

### Proposed tiers (written into the example by v060 slice 2, task 14)

Rows from most to least autonomous; the lowest row a file matches wins, so security tests and architecture tests land
on `critical` even though `*/src/test/*` also matches them. The three architecture tests live in package
`com.acme.shop.orders.architecture` (test sources), so `*/architecture/*` matches.

| Tier | Paths | Reviewer | Human |
|---|---|---|---|
| routine | `*/src/test/*` `docs/*` `*.md` | standard | none |
| domain | `*/src/main/java/*` `*/src/main/resources/application.yml` | standard | spot |
| critical | `*/security/*` `*/architecture/*` `*/src/main/proto/*` `*/openapi.yaml` `*/db/migration/*` `*pom.xml` `.mvn/*` `mvnw*` | deep | required |

`pom.xml`, `.mvn/` and the architecture tests are critical because that is where a check is switched off. Until the
auto-merge decision, `none` behaves as `spot`, which the routine row exercises on purpose.

### Seed tasks

Ticket texts give the symptom only; they live here, not in the example, so the sandbox carries no answers. Each runs
in a fresh sandbox; nothing is merged into specter. A planted defect is listed here so no specter contributor
"fixes" it in the example.

| ID | Tier | Kind | Ticket text | Exercises | Expected evidence |
|---|---|---|---|---|---|
| S1 (ORD-151) | routine | test addition | "List orders has no test for an empty page or for a page size above the maximum." | Test-only change, routine label, `spot` review | New tests pass on unchanged code; tier `routine` |
| S2 (ORD-152) | domain | bug (planted: cancelling an already-cancelled order answers 200 and records a second `OrderCancelled` publication; no test covers it) | "Partners report two OrderCancelled events for one cancel request." | Failing test first, fix in `order`, outbox behaviour | A red test before the fix; G1 to G5 green; tier `domain` |
| S3 (ORD-153) | domain | refactor | "Move the entity-to-DTO mapping out of OrderService into its own class in the order module; no behaviour change." | Characterisation first (playbook), `ServiceBoundaryTest` and `verify()` hold | Safety-net commit before the refactor commit; nothing else changes |
| S4 (ORD-154) | critical | feature | "Docs mention OrderPaid, but no order can be marked paid. Add it." | Spec first (contract change), `openapi.yaml` snapshot re-recorded, drift D5 resolved, deep review | New feature folder under `.specs/features/`; D5 RESOLVED; tier `critical` |
| S5 (ORD-142) | critical | decision-gated | "Implement ORD-142." | The agent must stop at the decision gate (task 1) and ask; after the human records option A and `W`, a jqwik property ("rejected iff the offset exceeds W") and deep review | First run ends with a question, no code; second run green |
| S6 (ORD-155) | critical | lesson → check | The human corrects the agent a second time: "don't use `@Value`, use a `@ConfigurationProperties` record". | Lesson recorded the same session; seen twice → a check first (`sync.md`), an ArchUnit rule with a `because` message, not prose | lessons.md line; a `CodingRulesTest` rule that fails on a planted `@Value` |

Evidence per run, once the v060 scripts exist: the `### Risk tier`, `### Gates` and `### Review` blocks in the
sandbox PR or commit text, and the `Fixes:` and `Human-Findings:` trailers slice 3 counts.

### What stays out

No real secrets or key material; no outbound network call in code, tests or build plugins beyond Maven Central
downloads; no Docker; no real company, person or partner names; no generated files committed except `openapi.yaml`
(snapshot-checked); no CI workflow (a nested `.github/` would never run and would mislead); no answers to seed tasks.

## Release ([REQ-V065-11])

| Option | For | Against | Ops impact |
|---|---|---|---|
| **0.6.5, on its own, before slice 2** (chosen) | Slice 2's tiers, readiness verdict and `Checked by` can then be built and tried on real code; the kit is unchanged, so a patch-level number is honest | One more release to cut | Nothing for installed projects |

## Tests

- Each check in the check map is broken once on a scratch branch and its gate goes red (task 9); the output is pasted
  in the PR, then the scratch branch is dropped.
- The example's `--cites` passes on a clean tree, after `./mvnw verify`, and in a copy without `.git`.
- Specter G1 to G4 on a shell with no `java` on `PATH`; G5 there prints the skip line, exit 0.
- G5 with `ACME_OFFLINE=1` after one online run.
- Selftest: example `--cites` and the cite-demo case.

## Rollout / rollback

One PR, then the 0.6.5 tag. Rollback is a revert: the kit is untouched, so no installed project changes either way.

## Risks

| Risk | Mitigation |
|---|---|
| Line-number citations break on every code edit | Intended: G2 catches it, the fix is a one-line spec edit |
| Dependency versions age and gather CVEs; no Dependabot without hosted CI | Bump at each specter release; `shortcut: manual version bumps, add Dependabot when the sandbox moves to a hosted repo` |
| Error Prone breaks on a JDK update | Enforcer pins the JDK floor; G5 shows it at once |
| A contributor fixes the planted S2 defect | It is listed in this design; the PR review checks it stays |
| New files make one of specter's own suffix-style citations ambiguous | G4 catches it; use repo-relative paths |
| A Boot 4.x library gap (see the versions list) | Task 2 checks each pairing before any code; record gaps in tasks.md |

## Spec and doc impact

- Specter: `AGENTS.md` (Gates table), `README.md` (Try it block and the sentence at lines 29-30), `CHANGELOG.md`,
  `VERSION`, `tests/selftest.sh` (case 1 and the cite-demo case), `tests/acme-build.sh` (new),
  `docs/assets/report.png` (citations now pass; regenerate, or note it as stale in the CHANGELOG).
- Example: the spec-delta table above.
- `docs/reference.md`: one line naming the example's code and the sandbox recipe.
