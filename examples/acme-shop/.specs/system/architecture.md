# Acme Shop — Architecture

> Grounded on `4e1c2a7` 2026-10-20. Authority: ADRs in `docs/adr/`. Where this summarises, the source wins.

## Overview
Acme Shop takes orders from the web shop and from partner systems, reserves stock, and hands paid orders to
fulfilment. Partners integrate over gRPC with mutual TLS; shoppers use the web UI over REST.

## Domain map

| Domain | Kind | Responsibility | Spec |
|---|---|---|---|
| orders-api | deployable | Orders lifecycle, REST + gRPC, owns `orders` schema | [`domains/orders-api/`](../domains/orders-api/design.md) |
| fulfilment-worker | deployable | Consumes `order-events`, books shipments | not written out in the example; spec-only, no code |
| catalog-cache | deployable | Read-through cache of the product catalog | not written out in the example; spec-only, no code |
| web | deployable | Shopper UI | not written out in the example; spec-only, no code |
| shop-common | library | Security filters, error model, event schemas | code in `shop-common/`; no domain spec in the example |

## Master diagram (protocols, no ports)

```mermaid
flowchart LR
  shopper[Shopper] -- HTTPS --> web[web]
  web -- REST/JSON --> orders[orders-api]
  partner[Partner system] -- gRPC + mTLS --> orders
  orders -- SQL --> db[(PostgreSQL: orders)]
  orders -- Kafka: order-events --> worker[fulfilment-worker]
  orders -- gRPC --> cache[catalog-cache]
  worker -- HTTPS --> carrier[Carrier API]
```

Not in the example code: PostgreSQL (the example runs H2), Kafka (events end in a logging sink), `web`, `fulfilment-worker`,
`catalog-cache` and the Carrier API. The gRPC server runs in-process, with no port.

## Component registry (ports and endpoints live here only)

| Component | Path | Stack | Key deps | Ports / endpoints |
|---|---|---|---|---|
| orders-api | `orders-api/` | Java 21, Spring Boot 4.1, Spring Modulith 2.1, H2 in the example, in-process gRPC, logging event sink | shop-common, PostgreSQL, Kafka (deployed) | REST 8080 `/api/v1/orders`; gRPC 9090 deployed, in-process in the example |
| fulfilment-worker | `fulfilment-worker/` | Java 21, Spring Boot 3.5 | Kafka, Carrier API | actuator 8081 |
| catalog-cache | `catalog-cache/` | Java 21, Redis | orders-api | gRPC 9095 |
| web | `web/` | React 19, Vite | orders-api | 443 (ingress) |
