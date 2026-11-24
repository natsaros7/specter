# Acme Shop example

A small, fictional online shop with real code and a complete specter spec tree. It has two jobs. It shows what a
specter-managed project looks like, and it is the test project for the agent workflow that v060 builds in slices.

The code is Java 21, Spring Boot 4.1 and Spring Modulith 2.1, built with the Maven wrapper.

| Maven module | What it holds |
|---|---|
| `shop-common` | Library: the gRPC security filter, event records, error codes, a test clock |
| `orders-api` | Spring Boot app with three Modulith modules: `order` (REST), `partner` (gRPC), `outbox` (events) |

`fulfilment-worker`, `catalog-cache` and `web` appear in the specs only. The example is smaller than its story: H2
replaces PostgreSQL, the gRPC server is in-process and opens no port, and events end in a logging sink instead of
Kafka. Nothing in the build or the tests touches the network after the first Maven run, and there is no Docker,
no CI workflow and no Sonar. Dates and commit shas in the specs belong to the story. Paths and line numbers are real,
and `spec_lint.py --cites` checks them.

## Build and test

You need JDK 21. The repo pins Temurin with SDKMAN:

```sh
cd examples/acme-shop
sdk env                  # reads .sdkmanrc (java=21.0.13.1+2-tem)
./mvnw -B verify         # first run downloads dependencies; later runs work offline with -o
```

On JDK 17 the Maven Enforcer stops the build with a message naming Java 21. To start the app (REST on port 8080):

```sh
./mvnw -B -DskipTests install
cd orders-api && ../mvnw org.springframework.boot:spring-boot-maven-plugin:4.1.2:run
```

The example declares no Boot plugin, so there is no runnable jar.

## Gates

The Gates table is in [`.specs/steering/spec-rules.md`](.specs/steering/spec-rules.md), cheapest check first: compile
with Error Prone and NullAway plus the format check, the architecture tests, the full build, an agent-text scan of the
build log, the spec lint and the citation check. A weekly mutation run (PIT) is chore C2 in
[`.specs/steering/autonomy.md`](.specs/steering/autonomy.md).

G4 and G5 call `python3 .specs/kit/scripts/spec_lint.py`. That path exists only after `install.sh` has copied the kit
in, which the sandbox below does. In a bare checkout, run them from this folder as
`python3 ../../kit/scripts/spec_lint.py --specs .specs [--cites]`.

## Sandbox for agent runs

Agents work in a disposable copy with its own git history, never in specter itself. From the specter repo root:

```sh
S=~/sandbox/acme-shop; rm -rf "$S" && cp -R examples/acme-shop "$S" && git -C "$S" init -q
./install.sh "$S"        # adopt mode: adds .specs/kit/, keeps the specs; add --agents=... to wire agents
git -C "$S" add -A && git -C "$S" commit -qm "chore: acme-shop sandbox from specter $(git rev-parse --short HEAD)"
```

After the install the Gates rows G4 and G5 and chore C1 find `.specs/kit/scripts/` and run. Reset a run by repeating
the recipe. Nothing from a sandbox is merged back into specter.

## Seed tasks

Each seed runs in a fresh sandbox. The tier is the risk tier a change should land in.

| ID | Ticket | Tier | Kind | Title |
|---|---|---|---|---|
| S1 | ORD-151 | routine | test addition | List orders: empty page and oversized page |
| S2 | ORD-152 | domain | bug | Two cancel events for one cancel request |
| S3 | ORD-153 | domain | refactor | Move the entity-to-DTO mapping out of `OrderService` |
| S4 | ORD-154 | critical | feature | Mark an order paid (drift D5) |
| S5 | ORD-142 | critical | decision-gated | Validate the request timestamp |
| S6 | ORD-155 | critical | lesson to check | Time read without the injected Clock |
| S7 | ORD-156 | domain | domain rule | Currency rule into the order API, plus an ArchUnit rule (drift D6) |
| S8 | ORD-157 | domain | rule | Service queries are read-only, plus an ArchUnit rule |

Some seeds rely on a planted defect or a known gap, so do not fix them in this folder.
