# Orders — Requirements
- Requests older than the clock-skew window are rejected (`src/orders/OrderService.java:20`).
- Retries reuse the idempotency key (`src/orders/OrderService.java:142`).
- Rate limits come from `src/orders/RateLimiter.java:12`.
