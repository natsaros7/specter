# ADR-012: Services own the transaction; adapters do not

Status: Accepted (tech lead, 2026-11-03; implemented by ORD-120)

## Context

REST controllers and gRPC services owned the database transaction and passed JPA entities around. That hid lazy
loading in adapter code, overrode service-level `readOnly` and timeouts, and let a gRPC call report success before its
transaction committed.

## Decision

The transaction boundary is the service method. Adapters (`rest`, `grpc`) open no transaction and see no entity or
`jakarta.persistence` type. Services take commands and return DTOs; the entity-to-DTO mapping runs inside the
service's transaction. `ServiceBoundaryTest` (ArchUnit) enforces this as one global rule.

## Consequences

- A gRPC call commits before it answers (decision D-1).
- A new adapter that opens a transaction or reads an entity fails the architecture gate.
- Mapping code lives in the service layer.
