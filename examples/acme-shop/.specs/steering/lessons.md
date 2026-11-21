# Steering — Lessons
One dated line per correction.
A lesson seen twice becomes a check first: a Gates row, a lint rule or a test. Only when no check can catch it does it become a rule in spec-rules, code-standards or decisions, with the reason it can't be checked.

- 2026-10-27: a retry test sleeps for real time; use the fake clock in `shop-common`, or the suite slows by 40 s.
- 2026-11-03: `orders-api` rejects an unknown `currency` with 422, not 400; the contract annex wins over the old wiki.
