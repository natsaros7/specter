# v050 Decisions log, resolving ids, names denylist, deploy impact, gate summary — Requirements

Status: Done 2026-11-06 (v0.5.0)
Tracker: none. Branch `feat/0.5.0`. Size M.

## Why

Verified on `main` 2026-11-06 (`6578fb1`), and on a multi-team refactor plan written with specter 0.4.1:

- `kit/scripts/spec_lint.py:139-142` resolves a REQ only inside its own feature (plus `domains/`). A REQ cited from
  `system/`, `steering/` or a router is never checked, and nothing knows about decision ids. The refactor needed its
  own checker for settled decisions (`D-<id>` rows, about 160 of them) to keep cited ids, landing REQs and back-links
  consistent.
- Nothing stops a team, client or person name from landing in specs that several teams read. The refactor kept a
  hashed denylist so the list itself named nobody.
- The refactor assumed CI/CD ran pinned images. A job actually ran from the default branch, so a merge reached a
  production job without warning. The setup interview (`kit/playbooks/setup.md`, Phase 3 at `6578fb1`) never asks how CI/CD consumes
  the repository.
- Every PR pasted gate results by hand. `kit/templates/steering/spec-rules.md` §7 lists the gate as free text, so no
  script can run it.
- New contributors needed a one-page onboarding with starter prompts; the kit has no template for it.

## User story

As a lead running a spec-first change across teams, I want settled decisions recorded once and cited by id, cited ids
checked, names kept out of shared specs, deploy impact stated per change, and the gates run and summarised by a script,
without any of it changing a project that doesn't opt in.

## Requirements

### [REQ-V050-01] Decisions log

- The kit SHALL ship `templates/steering/decisions.md`: one table `| ID | Decision | Why | Where it lands | Supersedes |`,
  ids `D-<id>`, rows grouped under dated headings, and the rule that a decision changes only by a new dated row that
  supersedes the old one.
- When the decisions file exists (`steering/decisions.md`, or `decisions.file` in `spec-kit.json`), the lint SHALL
  FAIL, with `file:line`, on each REQ named in a row's "Where it lands" that no `requirements.md` defines. Rows that a
  later row supersedes are skipped.
- `decisions.backlinks` (default `false`): `"warn"` WARNs and `true` FAILs when such a REQ's definition does not cite
  the decision id.

### [REQ-V050-02] Every cited id resolves

- Every REQ id in `.specs/**/*.md` outside `kit/` SHALL resolve to a `[REQ-…]` definition in a feature or domain
  `requirements.md`. Unresolved ids outside a feature's own `requirements.md`, `design.md` and `tasks.md` (which keep
  their FAIL) SHALL WARN with `file:line`.
- When the decisions file exists, every `D-<id>` cited in `.specs/**/*.md` outside `kit/` SHALL resolve to a row, or
  the lint FAILs with `file:line`.
- Fenced blocks are skipped, as for links.

### [REQ-V050-03] Names denylist

- `spec-kit.json` `denylist_sha256` (default `[]`) holds SHA-256 digests of lower-cased terms.
- The lint SHALL tokenise every line of `.specs/**/*.md` outside `kit/`: lower-cased `[a-z0-9]+` runs with dots kept
  inside tokens, each dotted token also as every run of its segments, and each adjacent pair joined with `-`. A hit
  FAILs as `file:line: denylisted term (token #n)` and never prints the term.
- `spec_lint.py --hash-term <word>` SHALL print the digest to add.

### [REQ-V050-04] Deploy impact

- The tasks template SHALL carry `Deploy impact: none | <job or env>: <what changes>`.
- The review guidance and the spec-rules Definition of Done SHALL say: if it is not `none`, the people who run CI/CD
  hear before the merge.
- Setup SHALL ask, as a must-ask question, how CI/CD consumes the repository (a pinned artifact or image, or the default
  branch directly), and record the answer in the project profile.

### [REQ-V050-05] Gate summary script

- `kit/scripts/gates.py` SHALL read the first table with `Gate` and `Command` columns from `steering/spec-rules.md`
  (or `--file`), take each row's command from its single code span, and run the rows in order from the project root.
- It SHALL stop at the first non-zero exit, naming the gate, and exit 1.
- When all pass it SHALL print a `### Gates` block, one line per gate plus `commit: <sha>[+dirty]`.
- It SHALL exit 2 without running anything when the file, the table or a row's single code span is missing. It never
  invents a command.
- The spec-rules template SHALL hold the Gates table in that shape.

### [REQ-V050-06] Onboarding template

- The kit SHALL ship `templates/ONBOARDING.md` with: what the project is, the read order, the rules not to break, how
  to work a change (ready, claim, failing test first, gates, docs, review, deploy impact), practical gotchas, and four
  generic starter prompts (orient me; pick up a change; check my change against the spec; I disagree with a decision).
- Setup SHALL offer to generate it at the end.

### [REQ-V050-07] Grill the artifact

- `kit/docs/review-loop.md` SHALL describe an optional loop: independent reviewers attack a spec or plan, each with a
  recommended answer they try to refute with evidence; rounds go on until one finds nothing material; settled answers
  go into the decisions log; only questions whose decision is genuinely the human's go to the human.

### [REQ-V050-08] Example and compatibility

- `examples/acme-shop/.specs/` SHALL carry a decisions log with 2-3 rows cited from its REQs, a `Deploy impact:` line
  and an `ONBOARDING.md`, and lint clean with `decisions.backlinks: true`.
- A 0.4.1-shaped project (no decisions file, no denylist) SHALL keep its exit code. Every new check is WARN or off
  until enabled.
- The selftest SHALL cover:
  - an unresolved `D-` id;
  - a missing back-link (warn and fail);
  - a denylisted token reported without the word;
  - `gates.py` stopping, passing and refusing;
  - the 0.4.1-shaped upgrade.

## Out of scope

- Plan-specific checks of the reference checker: PR tables, lanes, roadmap rows, sign-off themes, acceptance-test
  naming.
- A `STATUS.md` file per feature: the kit keeps status in the `Status:` line.
- Enforcing that a superseding row is dated.

## Open decisions

- None.
