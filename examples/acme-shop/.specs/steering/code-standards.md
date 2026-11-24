# Steering — Code standards

| Topic | Source |
|---|---|
| Style / format | Spotless (palantir-java-format) in the root `pom.xml`; `./mvnw spotless:apply` fixes it |
| Static analysis | Error Prone and NullAway in the root `pom.xml`, as compile errors; packages are `@NullMarked` |
| Build floor | Maven Enforcer in the root `pom.xml`: Java 21, Maven 3.9, no version conflicts |
| Tests | JUnit 5, `should_doX_when_Y`; jqwik for properties; ITs run on H2, no containers |
| Architecture | `ModulesTest`, `ServiceBoundaryTest`, `CodingRulesTest` in `orders-api` (`architecture` package, tag `architecture`) |
| Gate | the Gates table in [`spec-rules.md`](spec-rules.md) |
