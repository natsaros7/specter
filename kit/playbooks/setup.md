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
3. **Evidence or UNKNOWN.** Every fact cites `path:line` (repo-relative path; a bare filename only when it is unique in
   the repo), a command output, or a user answer with its date.
   Something you can't support is written as `UNKNOWN (asked YYYY-MM-DD)` or as a Drift Register row. Never guess.
4. **Token discipline.** Find with search (`git ls-files`, `rg`, `grep`), then read excerpts. Never bulk-read
   generated files, lock files, vendored code or large doc trees.
5. **Ask well.** Ask at most 5 questions per round, in chat, and wait for the answer. Each question carries
   (a) why you ask, (b) what changes depending on the answer, and (c) your best guess as the default:
   "Reply `ok` to accept the defaults". Record answers immediately.

## Phase 0: Orient (no questions yet)

The installer created `.specs/steering/project-profile.md` (`status: setup-incomplete`). If it is missing, create the
folder and copy it from `.specs/kit/templates/steering/project-profile.md`. Set `phase: 0`.
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
| External config and sources | Config servers or remote config repos (Spring Cloud Config, Consul, etcd), env-injected settings, a wiki or contract the README points to. Anything outside the repo that decides runtime behaviour is a **must-ask** (Q2) |
| Architecture rules | ADR folder, architecture docs, enforced rules (ArchUnit, dependency-cruiser, import-linter, Nx module boundaries, eslint boundaries) |
| Requirements | Requirement IDs in code, tests or docs (`REQ-`, `FR-`, a tracker key such as `ABC-123`), `docs/requirements*`, user stories, feature files (Gherkin) |
| Quality gate | CI config (`.github/workflows`, `Jenkinsfile`, `.gitlab-ci.yml`), test commands, linters, coverage and static-analysis thresholds |
| Conventions | Commit style (from `git log`), branch naming, existing `AGENTS.md`/`CLAUDE.md`/`CONTRIBUTING.md` |

Give each fact a confidence: **high** (read in code or config), **medium** (inferred from naming or structure),
**low** (seen only in docs or comments).

## Phase 2: Draft the domain map

A **domain** is one folder under `.specs/domains/`. The default is one per deployable plus one per shared library that
carries real logic. Draft it in the profile as a table (domain, path, kind, contracts, depends on, REQ prefix, confidence).
**REQ prefix:** uppercase letters and digits only, ≤ 10 characters, unique; drop hyphens or abbreviate
(`api-gateway` → `APIGW`, `customers` → `CUST`). Requirement IDs are then `[REQ-<PREFIX>-NN]`.
Flag the hard calls: twins (one codebase, several deployments), modules that are split but behave as one, and
libraries too thin to deserve a domain.

## Phase 3: Interview (gaps only)

Ask only what Phases 1–2 left at low or medium confidence, or what the code can't answer. Typically 4–8 questions in
1–2 rounds. **Must-ask** questions are always asked unless the evidence is conclusive. **Ask-if-unclear** questions
are skipped when you have a confident default, which you then record as `assumed` in the interview log.

| # | Kind | Question | What the answer changes |
|---|---|---|---|
| Q1 | must-ask | Where do requirements live: a tracker (which key?), a docs folder, a contract annex, a wiki, or nowhere formal? Any ID scheme you're held to (`FR-012`, `ABC-123`)? | Whether `system/traceability.md` exists; `upstream_req_pattern` |
| Q2 | must-ask *if Phase 1 found external sources* | `<source>` decides `<what>`. Should I read it, or only link to it? Does it outrank the repo? | The router's "Sources of truth"; what setup reads |
| Q3 | must-ask | Who or what decides architecture: ADRs (where?), an architecture doc, a person, or "the code is the spec"? | What `design.md` must not contradict; whether new decisions need an ADR |
| Q4 | must-ask | What is the gate: the exact commands that must pass before merge? | Definition of Done; the `next-task` gate |
| Q5 | ask-if-unclear | (Multi-repo only) Are all the child repos part of this system? Are any missing from the folder? | The domain list; repos to clone |
| Q6 | ask-if-unclear | Which changes need a spec first? Default: multi-file, any contract/schema/boundary change, or more than 15 LOC. | `spec_threshold_loc`; spec-rules §1 |
| Q7 | ask-if-unclear | Git hook when code changes without a spec update: warn or block? Code paths = `<detected globs>`? | `spec_sync`, `code_globs` |
| Q8 | ask-if-unclear | Anything already known to be wrong or stale (docs vs reality)? | Seeds the Drift Register |

Record each answer in the profile's **Interview log** as you get it. Set `phase: 3`.

## Phase 4: Approve (the one approval)

Show, in one message: the domain map (with REQ prefixes), the planned file list, and any assumed answers. Ask for
"go", or for changes to the map. This is the only approval in setup. Set `phase: 4`.

## Phase 5: Generate

From `.specs/kit/templates/`:

1. `.specs/README.md`: the router. Fill the "If you need… → open only" table with real paths.
2. `system/architecture.md`: overview, a Mermaid diagram (protocols on edges, no ports), and a component registry.
   Ports and endpoints go in the registry only.
3. `system/data-flows.md`: the 3–6 flows that matter most, as sequence diagrams, then the **Drift Register**
   seeded with everything you found in Phases 1–3 where docs, code and answers disagree. A row is a **disagreement**
   or a hazard (docs vs code, config vs code, code that contradicts its stated behaviour, e.g. a lookup that ignores
   part of its key, a client that always takes the first instance). Never a restated fact like "uses version X".
4. `system/traceability.md`: **only if Q1 found an upstream requirement source.** Requirement ID → domain → code → test → status.
   If you can't verify an ID, mark it 🔴 and give the reason.
5. `domains/<domain>/design.md` (as-built: stack, behaviour, public interface, data, config, local drift) and
   `domains/<domain>/requirements.md` (capabilities with `[REQ-<PREFIX>-NN]` ids, each with evidence). Leave out
   template fields that don't apply (a version for a merged domain, the Upstream column when there's no traceability).
6. `steering/spec-rules.md`: copy the template and put in the threshold (Q6), the gate commands (Q4) and the decision
   authority (Q3).
7. `steering/code-standards.md`: link to the project's existing standards and CI gate. Don't restate them.
8. Update `.specs/spec-kit.json`: `upstream_req_pattern` (Q1), `spec_threshold_loc` (Q6), `spec_sync` and `code_globs` (Q7).

## Phase 6: Verify and report

1. Set the profile to `status: verifying` and `phase: 6`.
2. `python3 .specs/kit/scripts/spec_lint.py` exits 0.
3. `python3 .specs/kit/scripts/spec_lint.py --cites` reports no broken citations. Fix every `path:line` it flags
   (a missing or ambiguous file, a line past the end of the file, or only blank cited lines).
4. Every Mermaid block is fenced with `mermaid` and parses (if no renderer is available, check the syntax by eye).
5. Nothing outside `.specs/` changed apart from the installer's files (`git status`).
   Only now set the profile to `status: active` and `phase: done`.
6. **Report** (≤ 8 lines): domains created, open UNKNOWNs, the top 3 Drift Register rows, the three highest-value
   next steps, and the four everyday phrases ("Spec this", "Next task on", "Sync specs", "Refresh the specs").

## Re-running

Run `refresh.md` for later re-grounding. Run `setup.md` again only to redo the domain map (Phase 2 onward).
