# v080 Platform layer for multi-repo systems — Requirements

Status: Draft (unpinned 2026-11-25; not designed)

## Context

A system made of several repositories needs specs that span them: the architecture, data flows, one Drift Register,
a repo registry and a contracts registry. The kit supports one repository, a monorepo or a workspace. It has no
platform layer above member repos. A multi-repo adoption on another project split its specs that way, and its gap
list is in [`input.md`](input.md) (G1 to G14, plus the model that worked).

Pinned in v060 until that split proved the model. Unpinned on 2026-11-25 by the maintainer. Design starts only when
the maintainer says so.

## Requirements

### [REQ-V080-01] A platform layer above member repos

- Specter SHALL let a platform `.specs/` hold what spans repos, while each member repo keeps its own specs and lints
  alone. The gaps in `input.md` are the input; which ones this feature closes is decided at design time.
