# Research: why specter is growing into a software factory

## The goal (maintainer, 2026-11-21)

Take a codebase from "a human reads every change and makes every decision" to agent autonomy **in stages, each earned**. The end state: the human defines the spec and the goal; an orchestrator runs the agents; **trustworthy reviews, gates and evidence** decide what merges. Teams such as Kiro and Graphbot report ~1,000 to 11,000 agent PRs a month; specter does not start there. On 2026-11-21 it sits between Kiro's stage 2 and stage 3, and moves one stage at a time. Every codebase keeps its own rules, style and knowledge, so all of it is per-repository configuration.

## Inspiration and sources

| Source | What it gave specter | Notes |
|---|---|---|
| Kiro, "software factory: 1,000 PRs" (2026-09-18) and its stability follow-up | The five-stage ladder, governance from day one, readiness verdict, review contract, a pipeline before an orchestrator | [notes](sources/kiro-software-factory-1000-prs.md) |
| Lauren "Potato" Tan, "All Code Is Slop (Except Mine)" (Graphbot, SpaceXsi) | Trust is earned through the environment; every correction becomes a deterministic check; prose last; review shrinks to verification artifacts; foundations before the factory | Summary in [the research](2026-11-21-software-factories.md#lauren-potato-tan-all-code-is-slop-except-mine-graphbot-spacexsi-transcript-read); full transcript kept locally only (`sources/local/`, git-ignored: third-party content) |
| Stripe, Spotify, Ramp, Uber, PostHog, OpenAI, dotnet/runtime, Ona, StrongDM | What runs at scale, what fails, which orchestrators to adopt | [research](2026-11-21-software-factories.md) |
| GitHub Docs, Standard Readme, Art of README, Diátaxis; five README and badge studies; twelve tool READMEs | What a README needs on its first screen, which signals readers trust, SHOW tested, a checkable README checklist and outline for specter | [research](2026-11-25-readme.md) |

## Where it landed

- [Research and candidate changes E1–E10](2026-11-21-software-factories.md#what-this-means-for-specter)
- [v060 staged autonomy](../../.specs/features/v060-staged-autonomy/requirements.md): slice 1 shipped (0.6.0); slices 2–4 absorb E2–E5, E7 and E8
- [v065 acme-shop in Java](../../.specs/features/v065-acme-java/requirements.md): a real codebase for the factory to work on
