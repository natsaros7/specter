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

Not finished until all six are done. The lint WARNs on "all tasks ticked" without `Done`, and on merged work in a spec
that still says Proposed.

1. Set `Status: Done <YYYY-MM-DD> (<branch, commit or PR>)` in the feature's `requirements.md`.
2. Tick every task; for one you won't do, tick it and write `Dropped: <reason>` in its text.
3. Fold the outcome into `domains/` (as-built state) and `system/`. The feature folder is now history: don't delete it,
   and don't keep editing it.
4. Resolve the Drift Register rows it fixed (mark **RESOLVED YYYY-MM-DD**).
5. A lesson in the memory file (the Memory row of `steering/autonomy.md`) seen twice: propose a check that catches it (a Gates row, a lint rule or a test). Propose a steering rule or a decision row only when no check can, and say why.
6. Run `python3 .specs/kit/scripts/spec_lint.py`.

If you can't make a spec statement true right now, add a dated Drift Register row instead.
A logged drift can be fixed later; a confident spec that has gone stale misleads everyone who reads it.

## Trailers (evidence per tier)

Two commit trailers on the default branch feed `tiers.py --evidence`, which counts per tier what was merged, reverted,
fixed later and caught by a human. Write them as the last lines of the commit message, after a blank line.

| Trailer | Where | Means |
|---|---|---|
| `Fixes: <sha>` | the commit that fixes a defect an earlier merged commit shipped (7 to 64 hex of the merged commit on the default branch, or of any commit it merged) | that change escaped the gates and the review |
| `Human-Findings: <n>` | the merge (or squash) commit, written at the human check, `0` when none; never on a `none` merge (no human check): `ready.py --auto-merge` refuses a PR whose text or commits carry it, so every value on the merged history counts, a `0` included | the human found n problems the gates and the reviewer missed |

A revert needs no trailer: `git revert` writes `This reverts commit <sha>.`, which counts as reverted: the sha may be the merge commit or any commit it merged.

Evidence counts first-parent commits, so it assumes squash or merge commits. A rebase merge or fast-forward puts each PR commit on the chain: Min merged is reached faster, and one revert is diluted over the PR's commits.
