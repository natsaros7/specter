# v060 Staged autonomy, configured per repository — Design

Security-sensitive from slice 2 on: tier routing decides where human review is relaxed. Review on the deep tier.
Stdlib only, Python 3.8+, offline, as the rest of the kit.

## Where the profile lives ([REQ-V060-01])

| Option | For | Against | Ops impact |
|---|---|---|---|
| **`.specs/steering/autonomy.md`** (chosen) | Templates mirror their target paths. Steering already holds the rules every change follows, and these are rules. Markdown tables are how the kit already declares executable rules (the Gates table). The human approves it like any steering file. Absent file = today's behaviour, easy to detect | Tables of globs are wordier than JSON lists | Diffable in review; a bad row stops the script with `file:line` (exit 2) |
| `autonomy` key in `spec-kit.json` | Lists of globs are native JSON; `load_config` already validates keys strictly | `spec-kit.json` tunes the lint, and the installer never rewrites it. Knowledge links in JSON would not be link-checked. No prose next to the rule saying why | Same validation story; harder to read in a PR |
| A new section in `spec-rules.md` | One file fewer | Adopted projects keep their own `spec-rules.md`, so they would have to edit it. "Profile absent" would mean "section absent" inside a file that always exists | Harder to tell an unconfigured repo from a broken one |

No new `spec-kit.json` key: the path is fixed, as `steering/spec-rules.md` is for `gates.py`. Each script that reads
a section takes `--file` for tests.

### Per-codebase configuration: what already exists, what this adds

| Per-repository setting | Today | This spec |
|---|---|---|
| Knowledge base, steering, decision records | The router, spec-rules §4 and `decisions.file`: per repo, but prose | Knowledge table: the same pointers, machine-readable, link-checked, and guarded |
| Gate commands | The spec-rules §7 Gates table, run by `gates.py` | Reused as is; Chores reuse its table shape |
| Risk-tier rules | None (one prose line in the reviewer role) | Tiers table |
| Who reviews each tier | The prose rule "security → deep" | Reviewer and Human columns |
| Evidence thresholds | None | Evidence table |

## The template ([REQ-V060-01] to [REQ-V060-08])

`kit/templates/steering/autonomy.md`, in order. The Tiers table comes before Chores, and has no Gate column, so
`gates.py` skips it and finds the Chores table.

```markdown
# Steering — Autonomy profile

What agents may do here without a human, and on what evidence. Editing this file is always a human-tier change.

## Knowledge
| Knowledge | Where | Read |
|---|---|---|
| Router | [router](../README.md) | start |
| Steering | [spec rules](spec-rules.md), [code standards](code-standards.md) | start |
| Decisions | [decisions](decisions.md), ADRs in [<adr folder>](<relative path>) | before a design |
| Architecture tests | [<test>](<relative path>) | before a design |
| Memory | [lessons](lessons.md) | start |

## Tiers
| Tier | Paths | Reviewer | Human |
|---|---|---|---|
| routine | `<tests glob>` `<docs glob>` `<lockfile>` | standard | none |
| domain | `<source glob>` | standard | spot |
| critical | `<security glob>` `<contracts glob>` `<migrations glob>` `<CI glob>` `CODEOWNERS` | deep | required |

## Chores
Runs: <schedule>, by <cron | launchd | CI schedule>, as `python3 .specs/kit/scripts/gates.py --file .specs/steering/autonomy.md`.

| # | Gate | Command |
|---|---|---|
| C1 | Spec health | `python3 .specs/kit/scripts/spec_lint.py --cites && python3 .specs/kit/scripts/spec_report.py` |

## Guardrails
| Guardrail | Enforced by | Verified |
|---|---|---|
| No direct or force push to the default branch | <platform setting> | <YYYY-MM-DD> |
| … (the six rows of REQ-V060-07) | | |

## Evidence
| Tier | Window (days) | Min merged | Max reverted % | Max escaped % | Max human-caught % |
|---|---|---|---|---|---|
| routine | <n> | <n> | <n> | <n> | <n> |
```

Setup fills the placeholders; a project that keeps one gets exit 2 from the script that reads it, never a guess.
`kit/templates/steering/lessons.md` is three lines: a heading, "one dated line per correction", and "a lesson seen
twice becomes a check first (a Gates row, a lint rule or a test); prose in spec-rules, code-standards or decisions
only when no check can catch it".

## Slice 1: a solid stage 3

### Knowledge and memory ([REQ-V060-02])

| File | Change |
|---|---|
| `kit/AGENT_RULES.md` | After "Read `.specs/README.md` first": if `steering/autonomy.md` has a Knowledge table, also read its `start` rows, and open the others on their trigger. When the user corrects you, add one dated line to the Memory row's file before the session ends |
| `kit/playbooks/sync.md` | Close-out step: a lesson in the memory file seen twice is proposed as a check first (Gates row, lint rule, test); a steering rule or a decision row only when no check can catch it |

The link check (`broken_links`) already resolves relative links from the file's folder, inside or outside `.specs/`,
so a moved ADR folder fails the lint with no new code.

### One scheduled chore ([REQ-V060-03])

No new runner. `gates.py --file .specs/steering/autonomy.md` reads the first table with Gate and Command columns,
runs it from the project root, stops at the first failure and exits 1. That is the chore contract. The page it
regenerates (`.specs/report.html`) is the dashboard.

`kit/docs/chores.md` (new, short): a crontab line and a launchd plist for a local machine, a scheduled CI job for a
shared one, and the rule that a chore which writes tracked files works on a branch and goes through review. The
scheduler's own failure mail or notification is the alert.

shortcut: every chore runs on the one schedule line; add a per-row cadence when a second chore needs a different one.

### In-flight view ([REQ-V060-04])

`spec_report.py` gains a card after Features: `In flight`, built from `git worktree list --porcelain` and
`git for-each-ref --no-merged=<ref> refs/heads/` (ref resolved as `merged_commits` does). One row per unmerged
branch, plus one per worktree on no such branch (detached, or on a merged commit); the main checkout shows only when
dirty. Per row: worktree path (if any), last commit date, uncommitted file count
(`git --no-optional-locks status --porcelain`, so it never takes an agent's `index.lock`; "—" when the folder is gone),
and the `.specs/features/<name>/` folders in `git diff --name-only --relative <ref>...<head> -- .specs/features`. A branch that touches no feature folder shows "no spec". Git missing or
timing out: one line, "no git data (git missing, not a repo, or merged ref unresolved)". The rest of the page is unchanged.

shortcut: local worktrees and branches only; read remote branches when sessions run on more than one machine.

## Slice 2: risk-tier labels

### `tiers.py` ([REQ-V060-05])

`python3 .specs/kit/scripts/tiers.py [--specs DIR] [--file PATH] [--range A...B] [--json] | --check | --evidence | --help`

1. **Base.** Staged mode: `HEAD`. Range mode: `git merge-base A B`. Read the profile with `git show <base>:.specs/steering/autonomy.md`.
   Missing at the base: the human tier, reason "no autonomy profile at <base>". `--check` reads the working-tree file.
2. **Parse.** Same cell split as `gates.py` (`\|` escapes). Validate: unique tier names; every Paths cell holds at
   least one code span; Reviewer in {standard, deep}; Human in {none, spot, required}, non-decreasing down the table;
   the last row `required`; no `<…>` placeholder. Any failure: exit 2 with `file:line`.
3. **Files.** `changed_files` from `spec_sync_check.py` (imported the way `spec_report.py` imports `spec_lint`).
   Renames count under both paths, deletions under their old path.
4. **Label.** Guarded globs first: `.specs/steering/*`, `.specs/spec-kit.json`, `.specs/kit/*`, the in-repo targets
   of Knowledge links (a folder becomes `<folder>/*`), and the agent paths from `install.py`'s `AGENTS` table plus
   `AGENTS.md` (imported, not copied, so a new agent is guarded the day it is added). A guarded file takes the last
   row. Otherwise each file takes the lowest row any of its globs matches, or the last row when none does. The change
   takes the lowest row among its files.
5. **Out.** stdout:

   ```text
   ### Risk tier
   - tier: domain (reviewer: standard, human: spot)
   - set by: src/main/shop/Order.java (`src/main/*`)
   - files: 4 (routine 2, domain 2)
   - profile: .specs/steering/autonomy.md at 1a2b3c4
   - autonomy: labels only; every change still gets the human check
   ```

   `--json`: `{tier, reviewer, human, set_by: {file, glob}, counts, profile_commit, labels_only}`. Exit 0.

Why the lowest row wins: a file matching both `src/*` and `*/security/*` must land on `critical`. The cost is that a
test kept next to the source takes the source's tier (open decision).

### Review loop wiring ([REQ-V060-05])

| File | Change |
|---|---|
| `kit/docs/review-loop.md` | Step 3: run `tiers.py` on the frozen diff; the reviewer tier is the label's. Step 5 unchanged in slice 2; paste the `### Risk tier` block next to `### Gates` |
| `kit/roles/reviewer.md`, `kit/docs/model-routing.md` | "deep when the diff touches security" becomes "the tier `tiers.py` gives; deep when the profile is absent and the diff touches security" |
| `kit/templates/steering/spec-rules.md` §7.4 | Points to the profile's Tiers table |

### Decide once ([REQ-V060-06])

`decision_rows` keeps its shape and also returns the `checked by` cell when the header has one. `landings` checks
each non-empty cell against the labels of `gates.gate_rows(spec-rules.md)` (the `#` plus the Gate name, or either
alone). Unknown label: FAIL with `file:line`. No column: no check, so 0.5.0 output is unchanged.

## Slice 3: guardrails and evidence

### Guardrails ([REQ-V060-07])

`tiers.py` parses the Guardrails table. When any row lacks a non-placeholder "Enforced by" or a dated "Verified",
a tier with Human `none` is reported as `spot`, with `- guardrails: <n> undeclared, none → spot`. `--check` lists the
rows. Nothing probes the platform: specter cannot see branch protection, and says "declared", never "enforced".

### Evidence ([REQ-V060-08])

| Metric | Source on `merged_ref`, first-parent, inside the tier's window |
|---|---|
| merged | commits, each labelled with the profile as of its first parent (unprofiled ones are left out and counted separately) |
| reverted | a later commit whose body has `This reverts commit <sha>` (git's own revert text) naming it |
| escaped | a later commit with a `Fixes: <sha>` trailer naming it (prefix match, at least 7 hex) |
| human-caught | its own `Human-Findings: <n>` trailer, n > 0, written at the human check |

Verdict per tier: `hold (n < min)` · `hold (no Human-Findings trailers)` when that limit is set and no commit carries
one · `breach (<metric> x% > y%)` · else `eligible`. Exit 0; `--json` has the counts. `kit/docs/review-loop.md` step 5
and `sync.md` document the two trailers.

shortcut: one git log per run, no cache; cache by commit when a window holds thousands of merges.

## Slice 4: the pipeline

### Human check by tier ([REQ-V060-09])

Starts only after the auto-merge decision is recorded in `steering/decisions.md`. Review-loop step 5 then branches on
the label: `required` as today; `spot` as defined in the requirement; `none` documents the platform recipe (required
checks = the Gates, auto-merge on green, CODEOWNERS for `required` paths) and nothing in the kit merges. The
`labels_only` flag goes `false`.

### Hand-offs ([REQ-V060-10])

`kit/docs/pipeline.md`:

| Stage | Role and playbook | Hands on | Human enters when |
|---|---|---|---|
| Triage | planner, `new-feature.md` (small changes skip it) | approved spec and tasks, or "small change" | spec approval |
| Implement | generator, `next-task.md` | frozen patch and `### Gates` block | second red gate |
| Review | reviewer at the label's tier | verdict table and `### Risk tier` block | disputed finding; Human `spot` or `required` |
| Merge | the platform | merge commit with trailers | guarded path; `Deploy impact` not `none` |

The queue is whatever the host has: issues, draft PRs, a CI queue. Kiro's advice applies: a pipeline before an
orchestrator.

## Setup ([REQ-V060-11])

`kit/playbooks/setup.md` gets Q10, ask-if-unclear: "Set up an autonomy profile now? Knowledge: <found ADR folder,
arch tests>; tiers from <found test, docs, migration, contract, CI paths>. [not now]". On yes, Phase 5 writes
`steering/autonomy.md` (Knowledge and Chores in slice 1; later slices add their sections) and `steering/lessons.md`.
Adopt mode never writes it.

## Tests ([REQ-V060-11])

`tests/selftest.sh` case 13, in a `mktemp` git project, grown per slice:

- 13 and 13a (slice 1): the In flight card lists unmerged branches, fresh and detached worktrees and their features,
  hides a clean main checkout and merged branches, and degrades without git (13); a Knowledge link to a missing ADR
  folder fails the lint, `gates.py --file` runs the Chores table past a Tiers table, a placeholder chore exits 2 (13a).
- 13b (slice 2): no profile → human tier; strictest file wins; unmatched → last row; an edit to `autonomy.md` → last
  row; a profile added in the staged change is not used; a decreasing Human column exits 2; `Checked by` naming no
  gate FAILs; a 0.5.0-shaped project lints unchanged.
- 13c (slice 3): `none` → `spot` with an undeclared guardrail; evidence with a revert, a `Fixes:` and no
  `Human-Findings` gives `breach` and `hold`.

## Rollout / rollback

Nothing changes until a repository adds `steering/autonomy.md`. Rollback: delete the file; every change is back to
the human. Each slice is its own release (0.6.0 = slice 1), so a slice can be reverted alone.

## Spec and doc impact

- `docs/reference.md`: a section per slice; `README.md`: one subsection; `CHANGELOG.md`: per release.
- `examples/acme-shop/.specs/steering/autonomy.md`: Knowledge and Chores in slice 1, then Tiers and the rest.
