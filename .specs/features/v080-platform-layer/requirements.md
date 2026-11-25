# v080 Platform layer for multi-repo systems — Requirements

Status: In progress (first slice approved 2026-11-25, decisions 1 to 11 as recommended)
Tracker: none yet. After task 1, one GitHub issue per task under the milestone of the release that ships it. Size M
for this slice.

## Why

A system made of several repositories needs specs that span them: the architecture, data flows, one Drift Register,
a repo registry and a contracts registry. The kit supports one repository, a monorepo or a workspace. It has no
platform layer above member repos. A multi-repo adoption on another project split its specs that way, and its gap
list is in [`input.md`](input.md) (G1 to G14, plus the model that worked).

Pinned in v060 until that split proved the model; unpinned on 2026-11-25. The maintainer needs it soon for a feature
that spans several member repos, and on 2026-11-25 chose the first slice: G2 (lint the platform and every member),
G3 (cite member requirements), G11 (cross-repo task lines), and the part of G1 those three need.

What the kit does today, checked at `42c3464` on a scratch fixture (a platform `.specs/` with one feature, an
`orders/.specs/` sibling whose `domains/` defines one requirement):

- `spec_lint.py` takes one spec root (`main()` reads one `--specs`). `--members` is not rejected: it is dropped with
  the other `--` words and the platform alone is linted.
- `load_config()` ignores unknown keys, so `"layer": "plat"` lints with no message. `grep '"layer"\|members'` in
  `spec_lint.py` finds nothing.
- `lint_feature()` resolves a referenced id only against the feature and the root's own `domains/` (`domain_reqs` in
  `lint_all()`). A platform design that cites the orders requirement exits 1 with "referenced but never defined".
- In `requirements.md` an id in brackets is a definition (the `defined_re` pattern matches anywhere), so the same
  cite in brackets there FAILs as "design.md does not trace" instead.
- `task_blocks()` only checks that a task links a requirement: a task line `1 shipping: … after: 9` lints clean.
- Setup's Layout row knows single repo, monorepo and workspace; `kit/templates/system/` has no registry.

## User story

As the maintainer of a system split over several repos, I keep what spans them in one platform `.specs/`, lint it and
every member checkout with one command, cite member requirements from platform features, and write a cross-repo
feature as one task per repo in an order the lint checks.

## Requirements

### [REQ-V080-01] A platform layer above member repos

- Specter SHALL let a platform `.specs/` hold what spans repos (system architecture, data flows, the one Drift
  Register, upstream traceability, `system/repos.md`, `system/contracts.md`), while each member repo keeps its own
  `domains/` and single-repo features.
- A member SHALL lint alone: its lint never reads the platform or the registry, and its result is the same with or
  without a platform checkout beside it.
- Every check this feature adds SHALL run only on a spec root whose `layer` is `platform`. A root without `layer`
  lints exactly as today.
- Acceptance: selftest section 27 lints the member fixture with the platform folder deleted and gets the same output;
  every existing selftest section passes unchanged.

### [REQ-V080-02] The layer key and the two registries (G1, the minimum)

- `spec-kit.json` SHALL accept `"layer"`: `"platform"`, `"member"` or `null` (the default), and `"members_root"`: a
  path string. Any other value SHALL exit with a readable message, as the other keys do. `member` lints as `null` in
  this slice.
- The kit SHALL ship `kit/templates/system/repos.md` (repo, default branch, deployables, domains, spec path) and
  `kit/templates/system/contracts.md` (contract, provider repo, consumers, rule).
- On a platform root the lint SHALL read `system/repos.md` and FAIL, with file and line, when it is missing, holds no
  table with a Repo and a Spec path column, names a repo that is not a plain folder name, gives a spec path that is
  absolute or climbs out with `..`, or lists a repo twice. A blank spec path means `.specs`.
- A member's specs SHALL be looked for at `<members root>/<repo>/<spec path>`. The members root is the
  `--members-root DIR` flag, else `members_root` (relative to the folder that holds the platform's `.specs/`), else
  `..`, the platform repo's siblings. A repo that resolves to the platform itself is skipped.
- `kit/playbooks/setup.md` (the Layout row and Phase 5) and `GO.md` (the Layout row) SHALL name the platform layout
  and the files it writes.
- Acceptance: design task 2's red rows.

### [REQ-V080-03] Lint the platform and every member (G2)

- `spec_lint.py --members` on a platform root SHALL lint the platform, then each registry member with that member's
  own `spec-kit.json`, print each under a `== <repo>` header, and exit 1 when any of them has a FAIL.
- A member with no checkout SHALL print `WARN member <repo>: no checkout at <path>` and be named on the summary line
  (`spec-lint --members: <n> FAIL across <k> repo(s); <m> not checked: <repos>`). It is never skipped silently; on its
  own it does not change the exit code.
- `--members` on a root whose layer is not `platform`, or together with `--cites` or feature names, SHALL exit 2 with a
  usage message. `--json --members` SHALL print one object `{platform, members, unchecked}` with the same exit code.
- Acceptance: design task 3's red rows.

### [REQ-V080-04] Platform features cite member requirements (G3)

- On a platform root, with or without `--members`, an id that a platform feature references SHALL resolve against the
  platform's own definitions and against every checked-out member's `domains/*/requirements.md` and
  `features/*/requirements.md`.
- An id defined nowhere SHALL FAIL as today, except when a member is not checked out: then it is a WARN that names the
  members not checked.
- An id that two repos define (the platform counts as one) SHALL FAIL as ambiguous, naming both.
- The existing WARN for ids cited outside feature files SHALL resolve the same way.
- In a platform feature's `requirements.md`, a member id SHALL be cited without brackets: brackets there define an id,
  as in every feature. The tasks template note says so.
- Acceptance: design task 4's red rows.

### [REQ-V080-05] Cross-repo task lines (G11)

- On a platform root, every task in `features/*/tasks.md` SHALL read `- [ ] N <who>: <what> …`, where `N` is a number
  unique in the file and `<who>` is a registry repo or `platform`.
- A repo line SHALL carry a child after `→` (or `->`): the member feature `<repo>/<spec path>/features/<f>/`, or a PR
  (a URL, `#N` or `<repo>#N`), of the line's own repo. A child path SHALL exist when that member is checked out. A
  `platform:` line (a decision, a release cut) needs no child.
- `after: N[, M…]` SHALL name task numbers of the same file and SHALL form no cycle.
- Each break SHALL FAIL as `task N: <why>`. A Done or Dropped feature reports them as `history:` WARNs, like its other
  structural FAILs.
- `kit/templates/feature/tasks.md` and `kit/playbooks/new-feature.md` SHALL show the line form.
- Acceptance: design task 5's red rows.

## Out of scope

G4 to G14 and the rest of G1: one line each in design.md, "Out of scope".

## Open decisions

Decisions 1 to 11 in design.md, each with a recommendation. Task 1 records the maintainer's answers.
