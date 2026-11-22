# ADR-007: Publish events through a transactional outbox

Status: Accepted (tech lead, 2026-06-14)

## Context

`orders-api` must not lose an accepted order's event when the broker or a consumer is down (contract requirement
CON-REQ-021). Publishing straight from the service after the commit loses the event if the process dies in between.
Publishing before the commit announces orders that may roll back.

## Decision

The service publishes each event inside the order's transaction. The event is stored with the order and handed to the
broker after the commit. A publication that did not complete is retried on a schedule. Delivery is at least once:
every event carries an id, and a consumer drops an id it has seen.

## Consequences

- An accepted order is never lost when publishing fails. A consumer can see the same event twice.
- A table of incomplete publications exists and can be read when delivery stalls.
- In the example the store is the Spring Modulith event publication registry and the end of the line is a logging
  sink (`OrderEventSink`). No Kafka broker runs. `OrderOutboxIT` shows the order commits when the sink fails and the
  event arrives after resubmission.
