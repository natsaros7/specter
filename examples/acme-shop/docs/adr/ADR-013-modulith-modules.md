# ADR-013: Spring Modulith application modules inside orders-api

Status: Accepted (tech lead, 2026-11-21)

## Context

`orders-api` holds three concerns that grew side by side: orders, the partner gRPC adapter and the event outbox.
Nothing stopped one from reaching into another's internals.

## Decision

Each direct sub-package of `com.acme.shop.orders` is a Spring Modulith application module: `order`, `partner`,
`outbox`. A module's public API is its top package; sub-packages are internal. Modules call each other through the API
only, and the module graph has no cycles. `ModulesTest` runs `ApplicationModules.verify()` and writes the module
diagrams to `target/spring-modulith-docs/`. Architecture tests live in `com.acme.shop.orders.architecture`, which is
not a module.

## Consequences

- A cross-module reach into an internal package, or a cycle, fails the architecture gate (G2).
- The domain stays one deployable. A module can move to its own service later; its API package is the seam.
- `shop-common` stays a separate Maven module: it is a library several deployables share.
