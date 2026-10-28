# Playbook: sync specs with code

The spec ships **in the same commit** as the code, or the change isn't done. The `pre-commit` hook
(`spec_sync_check.py`) reminds you, or blocks, depending on `spec_sync` in `.specs/spec-kit.json`.

| Code change | Update |
|---|---|
| New or changed REST/gRPC/GraphQL/CLI interface, message topic, port, config key, dependency, DB schema or migration | `.specs/domains/<domain>/design.md` |
| New or changed capability | `.specs/domains/<domain>/requirements.md` |
| Anything that adds, removes or moves coverage of an upstream requirement | `.specs/system/traceability.md` |
| New drift found, or a listed drift resolved | `.specs/system/data-flows.md` § Drift Register (resolved rows stay, marked **RESOLVED YYYY-MM-DD**) |
| Topology, a cross-service protocol, or a new deployable | `.specs/system/architecture.md` + component registry, and a new `domains/<domain>/` |

## Close-out (when a feature lands)

Not finished until all five are done. The lint WARNs on "all tasks ticked" without `Done`, and on merged work in a spec
that still says Proposed.

1. Set `Status: Done <YYYY-MM-DD> (<PR or commit>)` in the feature's `requirements.md`.
2. Tick the remaining tasks, or mark them dropped with a reason.
3. Fold the outcome into `domains/` (as-built state) and `system/`. The feature folder is now history: don't delete it,
   and don't keep editing it.
4. Resolve the Drift Register rows it fixed (mark **RESOLVED YYYY-MM-DD**).
5. Run `python3 .specs/kit/scripts/spec_lint.py`.

If you can't make a spec statement true right now, add a dated Drift Register row instead.
A logged drift can be fixed later; a confident spec that has gone stale misleads everyone who reads it.
