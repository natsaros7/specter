# Playbook: setup

The agent learns the project, interviews the user only where the code can't answer, and builds `.specs/`.

**Run on:** the strongest model you have (it is planning work). **Resumable:** progress is kept in
`.specs/steering/project-profile.md`. If that file exists, read it first and continue from its `phase:` line.
Never ask a question that already has an answer there.

## Ground rules

1. **Read-only on code.** Setup writes only under `.specs/`, plus the marker block the installer already placed in
   the agent instruction files. It never edits source, docs, ADRs or CI.
2. **Link, don't copy.** Where a source of truth already exists (ADRs, an architecture doc, an OpenAPI file, a wiki page),
   the spec links to it and summarises in a line or two. Where the two conflict, the source wins, and the conflict goes
   into the Drift Register.
3. **Evidence or UNKNOWN.** Every fact cites `path:line`, a command output, or a user answer with its date.
   Something you can't support is written as `UNKNOWN (asked YYYY-MM-DD)` or as a Drift Register row. Never guess.
4. **Token discipline.** Find with search (`git ls-files`, `rg`, `grep`), then read excerpts. Never bulk-read
   generated files, lock files, vendored code or large doc trees.
5. **Ask well.** Ask at most 5 questions per round, in chat, and wait for the answer. Each question carries
   (a) why you ask, (b) what changes depending on the answer, and (c) your best guess as the default:
   "Reply `ok` to accept the defaults". Record answers immediately.

## Phase 0: Orient (no questions yet)

Copy `.specs/kit/templates/steering/project-profile.md` to `.specs/steering/project-profile.md` and set `phase: 0`.
Record the commit you ground against (`git rev-parse --short HEAD`, branch, date).

## Phase 1: Scan

Fill the **Facts** table of the profile. Look for:

| Look for | Typical evidence |
|---|---|
| Deployables and libraries | Build files: `pom.xml` modules, `build.gradle` / `settings.gradle`, `package.json` workspaces, `go.mod`, `Cargo.toml` workspace, `pyproject.toml`, `*.csproj`/`.sln`; `Dockerfile`s; deploy manifests (Helm charts, k8s YAML, compose, Terraform, serverless config) |
| Layout | **single repo**, **monorepo** (many deployables, one repo), or **multi-repo workspace** (`.specs/` sits in a folder whose subfolders are separate git repos: `ls -d */.git`). In a workspace, record each child repo, its default branch and its remote, and pull each one before reading it |
| Public contracts | OpenAPI/Swagger, `.proto`, AsyncAPI, GraphQL schema, message/topic names, CLI surface |
| Data | Migrations (Flyway, Liquibase, Alembic, Prisma, EF), schema files, ORM entities, caches |
| Integration | HTTP/gRPC clients, broker producers/consumers, external base URLs in config |
| Architecture rules | ADR folder, architecture docs, enforced rules (ArchUnit, dependency-cruiser, import-linter, Nx module boundaries, eslint boundaries) |
| Requirements | Requirement IDs in code, tests or docs (`REQ-`, `FR-`, a tracker key such as `ABC-123`), `docs/requirements*`, user stories, feature files (Gherkin) |
| Quality gate | CI config (`.github/workflows`, `Jenkinsfile`, `.gitlab-ci.yml`), test commands, linters, coverage and static-analysis thresholds |
| Conventions | Commit style (from `git log`), branch naming, existing `AGENTS.md`/`CLAUDE.md`/`CONTRIBUTING.md` |

Give each fact a confidence: **high** (read in code or config), **medium** (inferred from naming or structure),
**low** (seen only in docs or comments).

## Phase 2: Draft the domain map

A **domain** is one folder under `.specs/domains/`. The default is one per deployable plus one per shared library that
carries real logic. Draft it in the profile as a table (domain, path, kind, contracts, depends on, confidence).
Flag the hard calls: twins (one codebase, several deployments), modules that are split but behave as one, and
libraries too thin to deserve a domain.

## Phase 3: Interview (gaps only)

Ask only the questions that Phases 1–2 left at low or medium confidence, or that the code can't answer. Pick them from
this bank in this order; skip any that are already answered:

| # | Question | What the answer changes |
|---|---|---|
| Q1 | Where do requirements live: a tracker (which project key?), a docs folder, a contract or tender annex, a wiki, or nowhere formal? | Whether `system/traceability.md` exists, and what `upstream_req_pattern` is set to |
| Q1b | (Multi-repo only) Are all the child repos part of this system? Are any missing from this folder? | The domain list; which repos need cloning |
| Q2 | Is there a requirement ID scheme you are held to (for example `FR-012`, `ABC-123`)? | The lint checks those IDs against the traceability matrix |
| Q3 | Who or what decides architecture: ADRs (where?), an architecture doc, a person, or "the code is the spec"? | What `design.md` must not contradict; whether a new decision needs an ADR |
| Q4 | Here is my domain map. Merge, split, rename, or drop anything? | The folders under `domains/` |
| Q5 | What is the gate: the exact commands that must pass before merge (build, tests, lint, coverage, static analysis)? | The Definition of Done in `steering/spec-rules.md` and the `next-task` gate |
| Q6 | Which changes need a spec first? Default: multi-file, any contract/schema/boundary change, or more than N LOC. | `spec_threshold_loc` and spec-rules §1 |
| Q7 | Should the git hook warn or block when code changes without a spec update? | `spec_sync` in `spec-kit.json` |
| Q8 | Which paths count as code for that hook? | `code_globs` / `ignore_globs` |
| Q9 | Are there documents outside the repo that outrank it (a wiki, SharePoint, a contract)? Should the agent read them, or only link to them? | The "Sources of truth" section of the router |
| Q10 | Does anything feel wrong in the Drift Register so far? | Severity and owner of each drift |

Stop interviewing when every domain is at medium confidence or better and Q1, Q3, Q5 and Q7 are answered.
Set `phase: 3` and record the answers in the profile's **Interview log**.

## Phase 4: Approve

Show the final domain map and the planned file list, then wait for an explicit "go". Set `phase: 4`.

## Phase 5: Generate

From `.specs/kit/templates/`:

1. `.specs/README.md`: the router. Fill the "If you need… → open only" table with real paths.
2. `system/architecture.md`: overview, a Mermaid diagram (protocols on edges, no ports), and a component registry.
   Ports and endpoints go in the registry only.
3. `system/data-flows.md`: the 3–6 flows that matter most, as sequence diagrams, then the **Drift Register**
   seeded with everything you found in Phases 1–3 where docs, code and answers disagree.
4. `system/traceability.md`: **only if Q1 found an upstream requirement source.** Requirement ID → domain → code → test → status.
   If you can't verify an ID, mark it 🔴 and give the reason.
5. `domains/<domain>/design.md` (as-built: stack, behaviour, public interface, data, config, local drift) and
   `domains/<domain>/requirements.md` (capabilities with `[REQ-<DOMAIN>-NN]` ids, each with evidence).
6. `steering/spec-rules.md`: copy the template and put in the threshold, the gate commands (Q5) and the decision
   authority (Q3).
7. `steering/code-standards.md`: link to the project's existing standards and CI gate. Don't restate them.
8. Update `.specs/spec-kit.json` with Q2, Q6, Q7 and Q8.

## Phase 6: Verify

- `python3 .specs/kit/scripts/spec_lint.py` exits 0.
- Spot-check 10 cited `path:line` references by opening them.
- Every Mermaid block is fenced with `mermaid` and parses (if no renderer is available, check the syntax by eye).
- Nothing outside `.specs/` changed (`git status`).
- Set the profile to `status: active` and `phase: done`, then report to the user:
  domains created, open UNKNOWNs, the top Drift Register rows, and the three highest-value next steps.

## Re-running

Run `refresh.md` for later re-grounding. Run `setup.md` again only to redo the domain map (Phase 2 onward).
