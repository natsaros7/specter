# Contracts

What the member repos promise each other: an API, an event, a schema. One row per contract. The provider's spec owns
the detail; this file says who depends on whom.

| Contract | Provider | Consumers | Spec |
|---|---|---|---|
| <name> | <repo> | <repo, repo> | <path in the provider's .specs/> |
