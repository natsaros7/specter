# Agent software factories: what people actually run (research, 2026-11-21)

Input for specter's evolution past v060 (staged autonomy). Web research plus one talk transcript; nearly all throughput numbers are self-reported. "[read]" = primary page read; "[snippet]" = search summary only: verify before citing in a decision row.

## Lauren "Potato" Tan, "All Code Is Slop (Except Mine)" (Graphbot, SpaceXsi) [transcript read]

Claims (self-reported): she shipped 3,000 PRs to production in a month; the Graphbot team 11,000 PRs/month, ~227 contributors in October, a stable release about daily, **revert rate steady at ~0.5%**, app performance improved while velocity rose. Took her 6 months to get there.

Thesis: a "software factory" is really about **trust**, earned by investing in the agent's environment, not by blind trust. "If your inner coding loop produces slop, automating that loop just produces more slop."

**The inverse trust pyramid** (where to spend effort, most to least):
1. **The codebase itself**: API design, architecture, refactoring. Code is the agent's largest input; agents copy whatever looks like the established pattern, including workarounds and deprecated code ("weeds spread").
2. **Deterministic checks**: lint rules, type systems, compilers, tests. Constrain agents so the right thing is the default.
3. **Verification**: runtime (agent runs the app via Chrome DevTools Protocol, with a "feature map" of user-facing features as shared vocabulary, custom CLIs inside skills) and formal (TLA+ model checking of cross-device flows, Lean proofs for a virtualization library, property-based UI tests with Bombadil). Found real bugs; "not a silver bullet".
4. **Prose last**: rules, skills, AGENTS.md: only for what needs judgment.

Practices:
- **Every correction becomes a deterministic check**, not another line in the rules file. "Far more reproducible when it's in code." Do this enough and "there's nothing left to review and you can just let agents merge most of their own pull requests."
- **Ban what needs nuance**: `useEffect` banned in product code, allowed only inside framework APIs; the class of bug is "categorically eliminated".
- **Context through directory structure**: `electron-main` / `electron-renderer` top-level dirs, cross-imports banned by a dependency-graph analyzer + lint.
- **Ban ~99% of comments**: agents use markdown (comments, docs, rules) to justify not doing the right thing, or over-rotate a one-off correction into a permanent rule. Comments aren't enforceable. Lint errors instead, with messages that tell the agent to fix the root cause.
- **Review = verification artifacts**: videos, screenshots, diagrams, state charts (her "statechart" skill in the "PSAC" plugin), formal results.
- **~70% of tokens go to verification** (hers and a cited peer's). Agents make once-uneconomical testing cheap: "a golden age of software testing and verification".
- **Foundations before the factory**: lint to stop new occurrences, then clean old ones, then strong verification; only then the outer loop (routines, cloud agents, projects). Example: each release auto-spins a project that fuzzes the app like a user, opens a fix PR per bug, and **auto-merges** them, because "pull requests tend to just be good by default".

## Who claims ~1000+ agent PRs and how

| Org / system | Claim | Sandbox / trigger | Review | Gates | Merge | Quality data |
|---|---|---|---|---|---|---|
| **Kiro Crew** (AWS) [read] | 1,000 PRs / 7 days, 3 engineers, 30–50 sessions | Cron, monitor loops, queue between triage→implement→review→merge; issue labels as starter queue; host-enforced permissions | Role-split AI reviewers on **different model families**; a blocker needs location + quoted evidence + trigger + consequence, else advisory; review rules load from main | "PR Readiness": one verdict over 80+ checks, every expected lane must have *run*; cheap gate first; PR-description-matches-code check; test pod screenshots/video | **Simple tier auto-merges**; others human with AI-drafted suggestions | No revert/incident data; ~20% of team time on factory infra |
| **Stripe Minions** [read] | 1,300+ merged PRs/week, no human-written code | Warm-pool devboxes (~10 s), QA env, no prod data, no egress; Slack/Jira trigger | **Human review required** | "Blueprints": deterministic nodes (lint, push) + agent nodes; **max 2 CI rounds** then human | Human | None published |
| **Spotify Honk** [read] | 650+ merged PRs/month (Honk); fleet changes mostly auto-merged | Claude Agent SDK in K8s pods | Verifiers + LLM judge [snippet] | CI | Auto-merge for fleet maintenance | **A dependency bump passed checks and broke prod**; added rollback capacity, owner-hours-only runs |
| **Ramp Inspect** [read] | ~50% of merged PRs started by the agent | Modal full-stack sandboxes, 30-min snapshots; Slack, web, Chrome extension | Not stated | App in Chromium, before/after screenshots | Not stated | — |
| **Uber** [read] | Minion ~11–15% of prod PRs | DevPod; context graph; MCP gateway | **uReview** on all PRs, benchmarked on known-bug PRs | Self-healing CI agents | Not stated | Cost/session −52%; revert tracked, value not given |
| **PostHog** [read] | 1,441 → 4,725 PRs/month, ~70% agent-opened | Cloud dev machines, skills (`babysit-prs`, `qa-swarm`) | **StampHog**: deterministic checks, then LLM showstopper hunt; auto-*approves* ~20% for ~$300/mo; all PRs still need an approval | 250k tests, flaky quarantined, browser QA agent | Trunk; merge queue planned (PRs green alone break main together) | **Revert ~0.2%**; review quality drops past a PR-size threshold |
| **OpenAI Symphony** [read] | Some teams +500% landed PRs | Linear as state machine, workspace per issue | Proof-of-work packet → "Human Review" state | Agents watch CI, rebase, retry flakes | Configurable | — |
| **dotnet/runtime + Copilot agent** [read] | 878 PRs, 535 merged (68%) | — | Human | CI | Human | **Revert 0.6% vs 0.8% human**; success 38% → 69% from instructions + setup alone; cleanup 85%, tests 76%, features 65%, perf 55% |
| **Ona "Memo"** | 375+ PRs/10 days, 87% merged autonomously | Hourly builder + PR shepherd; Sentry-triggered responder | Reviewer agent vs the spec, 5 lenses | CI, threads resolved, post-merge smoke → auto P1 bug | Risk-based auto-approve | "UI bugs still slip through" |
| **StrongDM** [snippet] | "Dark factory": no human writes or reviews | Specs + scenarios, digital twins of SaaS deps | None | Scenario scores | Autonomous | No volume data; questioned for security software |

"tometo" = **Potato** (Lauren Tan, Graphbot at SpaceXsi): see her section above.

## Patterns that recur

1. **Environment before agents**: fast reproducible sandboxes (devboxes, snapshots, worktrees).
2. **Deterministic + agentic hybrid**: scripts do lint/push/CI/autofix; agents only judge.
3. **Bounded fix loops**: max 2 CI rounds (Stripe), then human.
4. **Scoped context**: short AGENTS.md as an index into docs/specs; path-scoped rules; small toolsets.
5. **Review is the bottleneck everywhere**: evidenced-blocker-only, auto-approve a low-risk slice, a reviewer model different from the implementer, rules loaded from main.
6. **Proof of work on the PR**: screenshots, video, test-pod runs.
7. **Governance below the prompt**: host permissions, secretless untrusted triggers, egress limits.
8. **Start with toil that has a clear definition of done**: cleanup, tests, deps, migrations.

## What fails

- Review concentration (dotnet: 2 people gave 36% of feedback) and "resolve every comment" churn (Kiro).
- Volume outpacing verification (Spotify prod break; PostHog green-alone-red-together).
- Flaky CI, API rate limits, CI minutes.
- Review loops over-engineering the code (Kiro → proportionality checks).
- Ungrounded agents and context rot (Uber 20 min wrong vs 38 s grounded).
- **Prompt injection via issues/PRs is exploited in 2026** (Cline npm token theft, "Comment and Control", GitLost) [snippet]. An agent that reads untrusted text never gets secrets + write together.
- PR counts are a fragile metric ("attributed" vs "authored").

## Orchestrators to adopt rather than build

| Option | Status | Fit |
|---|---|---|
| GitHub Copilot agent + **Agentic Workflows (gh-aw)** | GA Oct 2026 [snippet] | Read-only agent job + "safe outputs" maps onto risk tiers; engines incl. Claude Code |
| **Claude Code Action / `claude -p` / Agent SDK** | Mature; harden against injection | Building block; you own queue and gates |
| **Kiro Crew** | Apache-2.0, 0.1.x, young | Matches the staged model; pipeline not clearly packaged |
| **OpenAI Symphony** | Draft spec, not maintained as product | Steal the state-machine board + proof-of-work idea |
| **Composio Agent Orchestrator** | OSS, ~7.5k stars | Closest off-the-shelf issue→worktree→PR→CI-fix loop |
| OpenHands | MIT, mature | Single-agent engine |
| Temporal custom | Mature infra, no packaged agent orchestrator | Only after a measured bottleneck |

## Recommendations (solo architect, between stage 2 and 3)

1. Issue tracker = queue; each spec task = one issue with blockers; ownership and rejected attempts live in the issue.
2. Gates table → one **readiness verdict** that requires every lane *ran*; PR-matches-spec-task check; max 2 CI fix rounds.
3. Auto-merge by path tier **and evidence**: start at zero; after N clean PRs in a tier, auto-merge only that tier; reviewer from a different model family; merge queue; auto-demote on a revert.
4. Trustworthy reviewer by construction: rules from main, no write access or secrets, evidenced blockers only, nits → follow-up issues.
5. Untrusted text is hostile: read-only agent jobs, separate validated write steps, no `pull_request_target` with secrets, egress allowlist.
6. Environment and context before parallelism (dotnet 38% → 69%).
7. Adopt the orchestrator first (Actions + Claude Code Action or gh-aw); budget ~20% time for factory infra.
8. Measure per task class: merge rate, revert rate, CI rounds, human minutes/PR, tokens/merged PR, PR size. Never raw PR counts.

## Sources

kiro.dev/blog/software-factory-1000-prs/ · kiro.dev/blog/software-factory-stability/ · github.com/kirodotdev/KiroCrew · stripe.dev/blog/minions-stripes-one-shot-end-to-end-coding-agents-part-2 · infoq.com/news/2026/10/spotify-ai-quality-controls · modal.com/blog/how-ramp-built-a-full-context-background-coding-agent-on-modal · uber.com/us/en/blog/efficient-software-factory · posthog.com/blog/10k-prs-a-month · openai.com/index/open-source-codex-orchestration-symphony/ · devblogs.microsoft.com/dotnet/ten-months-with-cca-in-dotnet-runtime/ · zenml.io/llmops-database/building-a-software-factory-with-ai-agents-and-automation-loops · strongdm.com/blog/the-strongdm-software-factory-building-software-with-ai · github.github.com/gh-aw/reference/safe-outputs/ · microsoft.com/en-us/security/blog/2026/06/05/securing-ci-cd-in-agentic-world-claude-code-github-action-case/ · noma.security/noma-labs/gitlost-how-we-tricked-githubs-ai-agent-into-leaking-private-repos · arxiv.org/abs/2602.08915

Talk: "All Code Is Slop (Except Mine)", Lauren Tan, YouTube O_zcc6Xl12g (transcript supplied by the maintainer).

## What this means for specter

Where the evidence agrees with v060, and where it says specter should change. Each row is a candidate requirement, not yet a decision.

| # | Evidence | Specter today | Candidate change |
|---|---|---|---|
| E1 | Potato: every correction becomes a deterministic check; prose is the last layer and gives agents an escape hatch | `sync.md`: a lesson seen twice becomes a rule in spec-rules, code-standards or decisions (prose) | A recurring lesson becomes a **Gates row or lint rule first**; prose only when no check is possible, and the lesson row records which (`check:` or `prose: <why uncheckable>`). Extends the slice-2 decisions `Checked by` column |
| E2 | Kiro "PR Readiness": every expected lane must have *run* | `gates.py` stops at the first failure; a skipped or missing gate is invisible | One **readiness verdict**: the `### Gates` block lists every row with ran/passed; a row that did not run is a FAIL |
| E3 | Stripe: max 2 CI rounds, then a human | Review loop: human enters at the "second red gate" (v060 pipeline table) | Make the cap explicit and counted: 2 fix rounds per task, then the task goes back to the human with both outputs (already the global routing rule; put it in the kit) |
| E4 | Kiro: reviewer from a different model family; rules loaded from main; evidenced blockers only. This repo's own slice-1 review: a deep reviewer found 2 BLOCKERs that 4 green gates and the worker's tests missed | `tiers.py` (slice 2) sets reviewer depth by path | Review contract: reviewer ≠ implementer model; reviewer reads rules from the base commit (as `tiers.py` already reads the profile at the base); a BLOCKER needs location + evidence + trigger + consequence, else it is advisory and becomes a follow-up |
| E5 | Potato, Kiro, Ramp, OpenAI: review shrinks to verification artifacts (video, screenshots, state charts, formal results) | Tasks end with a `### Gates` block | Tasks may declare a **verification artifact** (path or link) in the PR block; the reviewer checks the artifact against the spec's acceptance, not only the diff |
| E6 | Potato: ~70% of tokens on verification; property-based and formal checks now economical | Gates are whatever the project lists | Setup proposes verification gates by stack (property tests, contract tests, architecture tests such as Spring Modulith `verify()`, runtime checks) and the Knowledge table points to a feature map |
| E7 | Spotify prod break; PostHog green-alone-red-together | Evidence counts reverts and `Fixes:` after merge | Add a merge-queue recommendation to the slice-4 platform recipe; evidence breach demotes a tier automatically (report says `breach`, the human edits the profile) |
| E8 | Prompt injection via issues/PRs exploited in 2026 | Guardrails table (slice 3) lists six rows | Add a seventh guardrail: an agent job triggered by untrusted text runs read-only with no secrets; writes go through a separate validated step. And the chores fix from the slice-1 review: scheduled chores run from a clean clone, never the working copy |
| E9 | dotnet: 38% → 69% success from instructions + setup alone; Potato: codebase quality is the largest input | Setup writes as-built docs and a Drift Register | Drift Register entries that describe an anti-pattern get a "contain" action: a lint rule that stops new occurrences, then cleanup tasks (Potato's "lint first, then clean the old") |
| E10 | All: the orchestrator is the last layer; adopt before build (Actions + Claude Code Action / gh-aw, Kiro Crew, Composio) | v060 ships no orchestrator (out of scope); `tracker_pattern` already recognises ticket keys | A later feature: tracker-agnostic task export (spec tasks → tickets with blockers and tier labels) through a small adapter per tracker: GitHub Issues, GitLab, Jira, Linear, chosen per repo in config; offline by default (writes a file the adapter or the orchestrator consumes); still no orchestrator in the kit |

Order that follows from the evidence: E1, E2, E9 (foundations: checks and codebase) → E4, E5 (trustworthy review) → E3, E7, E8 (bounded loops and guardrails) → E10 (orchestration). That matches Potato's "foundations before factory" and Kiro's "governance from day one".
