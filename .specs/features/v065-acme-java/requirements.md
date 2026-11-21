# v065 acme-shop gets real Java code — Requirements

Status: Proposed
Tracker: none. Branch `feat/0.6.5-acme-java`. Size L (about 1.5k to 2k lines of Java, tests and build files in the
example; one shell script and two selftest lines in specter).

## Why

The maintainer's goal (2026-11-21): give the acme-shop example real code, so it becomes the test project for the
agent "software factory" that v060 builds in slices (knowledge and lessons, chores, risk tiers by path, readiness
verdict, review contract, evidence per tier, later pipeline hand-offs). Language decided: Java 21, Spring Boot 4.x,
Spring Modulith 2.x, Maven wrapper. The point is rich deterministic checks.

Verified on `feat/0.6.0` 2026-11-21 (`aabed8b`):

- The example has no code. Its README says so: `examples/acme-shop/.specs/README.md:3-4` ("Paths and line numbers point
  to an imaginary codebase"), and the specter README turns that into a demo: `README.md:29-30` ("The example ships
  without its code, so its citation check fails on purpose").
- `python3 kit/scripts/spec_lint.py --specs examples/acme-shop/.specs --cites` prints `7 FAIL of 7 citation(s)`, exit 1,
  all "no such file". The seven citations are in `examples/acme-shop/.specs/domains/orders-api/requirements.md:9-10`,
  `examples/acme-shop/.specs/features/ord-142-request-timestamp-validation/requirements.md:11-14`,
  `examples/acme-shop/.specs/steering/project-profile.md:14` and `examples/acme-shop/.specs/system/traceability.md:7`.
  They name `shop-common/` and `orders-api/` paths, a `GrpcSecurityFilter`, a `SecurityHeader` enum, `orders.proto`
  and an `application.yml` holding the Kafka topic names.
- Citations resolve against the folder that holds `.specs/`, from `git ls-files` run there: `kit/scripts/spec_lint.py:482`
  and `kit/scripts/spec_lint.py:484-486`. So code committed under `examples/acme-shop/` makes them resolvable with no
  lint change. `cite_ignore_globs` breaks a tie between several matches (`kit/scripts/spec_lint.py:518-519`); the
  example sets only `ignore_globs`, which the citation check does not read (`examples/acme-shop/.specs/spec-kit.json:4`).
- The as-built steering describes a heavier stack than an offline example can run: Testcontainers ITs with Kafka and
  PostgreSQL and Docker for local runs (`examples/acme-shop/.specs/steering/spec-rules.md:10`,
  `examples/acme-shop/.specs/steering/spec-rules.md:21`, `examples/acme-shop/.specs/ONBOARDING.md:52-54`), and a Sonar
  gate (`examples/acme-shop/.specs/steering/code-standards.md:8`, `examples/acme-shop/.specs/ONBOARDING.md:42`).
- The example's two lessons are prose with no check behind them (`examples/acme-shop/.specs/steering/lessons.md:5-6`),
  while the lessons rule says a recurring lesson becomes a check first (`examples/acme-shop/.specs/steering/lessons.md:3`).
- The example's chore calls `.specs/kit/scripts/…` (`examples/acme-shop/.specs/steering/autonomy.md:18`), and the
  example has no `.specs/kit/` (`ls` returns "No such file or directory"). It runs only in an installed copy.
- Specter's gates promise no network (`AGENTS.md:27-28`), and none of G1 to G4 needs a JDK (`AGENTS.md:32-35`). The
  selftest uses the example once, for the structural lint (`tests/selftest.sh:11-12`).
- The installer copies only `kit/` parts into a project (`kit/scripts/install.py:11`, `kit/scripts/install.py:271`), so
  code under `examples/` never reaches an installed project.
- The research behind the factory: "every correction becomes a deterministic check"
  (`docs/research/2026-11-21-software-factories.md:18`), "foundations before the factory"
  (`docs/research/2026-11-21-software-factories.md:24`), and E6 names Spring Modulith `verify()` and property tests as
  the verification gates setup should propose (`docs/research/2026-11-21-software-factories.md:104`).
- Evidence counting reads `git log` only where the folder holding `.specs/` has its own `.git`
  (`kit/scripts/spec_lint.py:354-355`). Inside the specter repo the example has none, so factory evidence needs a
  separate repository.

## User story

As specter's maintainer, I want acme-shop to be a small, real, offline-buildable Java codebase whose specs are true and
whose rules are enforced by deterministic checks, so that every v060 slice can be tried on real code, agents can run
seed tasks end to end in a sandbox copy, and the README still shows the citation check failing.

## Requirements

| ID | Requirement | Acceptance |
|---|---|---|
| [REQ-V065-01] | One Maven reactor under `examples/acme-shop/`: a root `pom.xml`, the Maven wrapper (script-only, no jar, distribution checksum pinned), and two Maven modules, `shop-common` (plain library) and `orders-api` (Spring Boot application). Inside `orders-api`, three Spring Modulith application modules: `order`, `partner`, `outbox`. Java 21, enforced by the build; a `.sdkmanrc` with `java=21.0.13.1+2-tem` pins it for SDKMAN users. `fulfilment-worker`, `catalog-cache` and `web` stay spec-only. | `./mvnw -B verify` from `examples/acme-shop/` exits 0 on JDK 21; on JDK 17 the enforcer stops it with a message naming Java 21. `ApplicationModules` lists exactly `order`, `partner`, `outbox`. |
| [REQ-V065-02] | The code does what the as-built specs say, at the size of the example: REST create, get, list and cancel on `/api/v1/orders`; gRPC `PartnerOrders` with `PlaceOrder`, `GetOrder`, `CancelOrder`; adapters own no transaction and see no entity; the partner security filter maps the certificate subject to the partner id; the `timestamp` is checked for presence only (drift D1 and ORD-142 stay open); events go through a transactional outbox; an unknown `currency` gets 422. | Tests named in the design pass; `rg isMandatory` finds callers in tests only, as `ord-142` claims. |
| [REQ-V065-03] | The example builds and tests offline after one online run, and is safe to copy: no outbound network call in code or tests (no Kafka or HTTP client, no Testcontainers, no Docker), no secret or key material, no binary file, Maven Central as the only repository, fictional names only. | `./mvnw -B -o verify` exits 0 after one online run; `git grep -I -i -e testcontainers -e kafka-clients -- examples/acme-shop ':!examples/acme-shop/.specs'` and `git grep -I "PRIVATE KEY" -- examples/acme-shop` find nothing; `git ls-files examples/acme-shop` lists no `.jar`. |
| [REQ-V065-04] | The example's Gates table runs the deterministic checks, cheapest first: compile with Error Prone and NullAway plus the format check; the architecture tests (Spring Modulith `verify()`, ArchUnit); the full build with unit, property (jqwik) and integration tests; the spec lint; the citation check. Each check traces to a lesson, decision, ADR or steering row of the example. | `examples/acme-shop/.specs/steering/spec-rules.md` Gates table holds those rows; the design's check map names the source of each; breaking one rule on purpose (one per check) turns its gate red. |
| [REQ-V065-05] | Mutation testing (PIT) is a slower scheduled chore, not a gate. | Chore C2 in the example's `autonomy.md`; `./mvnw -B -Ppit verify` writes a report under `target/pit-reports/`. |
| [REQ-V065-06] | Every citation in the example resolves and points at the code it describes. Cited line numbers are updated to the real lines; code is never padded to hit an old number. A build output folder never makes a citation ambiguous. | `spec_lint.py --specs examples/acme-shop/.specs --cites` exits 0, also after `./mvnw verify` (with `target/` present) and in a copy without `.git`. A reviewer opens each cited line and confirms it. |
| [REQ-V065-07] | Where the code is smaller than the story (no Kafka broker, H2 instead of PostgreSQL, two Flyway migrations, no deploy charts, no Sonar), the as-built specs are edited to match, each edit with its reason. History features (`ord-120` Done, `ord-142` Blocked) keep their text. Dates and commit shas stay part of the story, and the example README says so. | The design's spec-delta table lists every edited file; no as-built claim names a file or tool the example lacks. |
| [REQ-V065-08] | The README still shows a failing citation check, on a fixture made for it, and stays true. | `examples/cite-demo/.specs/` reproduces `docs/assets/lint-demo.svg` (2 FAIL of 3, exit 1); the README runs it; the selftest asserts both FAIL lines and the exit code. |
| [REQ-V065-09] | Specter's own gates G1 to G4 need no JDK and no network. G2 also checks the example's citations. An optional G5 builds the example: without JDK 21 it prints a `SKIPPED` line and exits 0; any build or download failure fails. G5 must have run (not skipped) for a change to example code. The selftest never calls G5. | `AGENTS.md` table; G1 to G4 green on a machine with no `java`; `sh tests/acme-build.sh` with `PATH` stripped of `java` prints `G5 SKIPPED: needs JDK 21+` and exits 0. |
| [REQ-V065-10] | The example is usable as the factory test project: a documented sandbox recipe (copy, `git init`, `install.sh`, commit), a proposed Tiers table for v060 slice 2, and seed tasks covering the routine, domain and critical tiers (a test addition, a bug, a refactor, a feature, a decision-gated change, a lesson that must become a check). Seed tasks run in the sandbox and are never merged into specter. | The design's sections; one dry run (seed S5 up to its stop, seed S2 end to end) recorded in tasks.md. |
| [REQ-V065-11] | The kit is unchanged; installed projects see no difference. CHANGELOG and README describe the change; release 0.6.5. | `git diff --stat` shows no file under `kit/`; G1 to G5 green; CHANGELOG `[0.6.5]`. |

## Out of scope

- Code for `fulfilment-worker`, `catalog-cache` and `web`.
- A Kafka adapter, a TLS listener, deploy charts, a CI workflow, Sonar or any hosted service.
- Any change to `kit/` or to the v060 deliverables; the Tiers section lands in the example with v060 slice 2.
- An orchestrator or a ticket export (research E10).
- Keeping the example's fictional commit shas real.

## Decided

- 2026-11-21, maintainer: Spring Boot 4.x with Spring Modulith 2.x, not 3.5 and 1.4. Lands on [REQ-V065-01] and
  tasks 1 and 2; design.md "Offline and safe to copy" and the risk table. Exact patch versions stay UNKNOWN until
  task 2.
- 2026-11-21, maintainer: release 0.6.5 on its own, before v060 slice 2. Lands on [REQ-V065-11] and task 15.
- 2026-11-21, maintainer: G5 without JDK 21 exits 0 with a visible `G5 SKIPPED: needs JDK 21+` line (not exit 77).
  The maintainer's machine has Temurin 21.0.13.1 via SDKMAN, and acme-shop ships a `.sdkmanrc` with
  `java=21.0.13.1+2-tem`. Lands on [REQ-V065-09], [REQ-V065-01] and tasks 2 and 12.
- 2026-11-21, maintainer: the factory sandbox stays a local copy until v060 slice 3 needs platform guardrails
  (protected branch, required checks). Lands on [REQ-V065-10] and the design's sandbox section.
