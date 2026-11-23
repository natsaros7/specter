# Steering — Autonomy profile

What agents may do here without a human, and on what evidence. Editing this file is always a human-tier change.

## Knowledge
| Knowledge | Where | Read |
|---|---|---|
| Router | [router](../README.md) | start |
| Steering | [spec rules](spec-rules.md), [code standards](code-standards.md) | start |
| Decisions | [decisions](decisions.md), ADRs in [<adr-folder>](<adr-folder>) | before a design |
| Architecture tests | [<arch-test>](<arch-test>) | before a design |
| Memory | [lessons](lessons.md) | start |

## Tiers
<!-- Put the scripts your Gates commands run (test runners, lint scripts, CI config) in the last tier: ready.py compares Gates commands, not the scripts they call. -->
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
<!-- Specter records these; the platform enforces them. A row counts as declared when Enforced by names what enforces it (no <placeholder>) and Verified is a YYYY-MM-DD date. Until every row is declared, a tier with Human none is labelled spot. No such job or no chores: say so, e.g. "no such job, checked .github/workflows/", and date it. -->
| Guardrail | Enforced by | Verified |
|---|---|---|
| No direct or force push to the default branch | <branch protection or ruleset> | <YYYY-MM-DD> |
| The Gates run as required checks before a merge | <required status checks> | <YYYY-MM-DD> |
| A human must approve a change to a `required` tier's paths | <CODEOWNERS or the platform's equivalent> | <YYYY-MM-DD> |
| Agent credentials cannot approve or merge | <bot account or token scope> | <YYYY-MM-DD> |
| Agent permissions come from the host's configuration, not from a prompt | <agent settings file or CI permissions> | <YYYY-MM-DD> |
| Agents cannot edit merged history or review records | <history protection and the platform's review log> | <YYYY-MM-DD> |
| An agent job triggered by untrusted text (an issue, a PR, a comment, an outside contribution) runs read-only, without secrets; its writes go through a separate step that validates them | <CI permissions and the platform's safe-output step, or "no such job, checked <how>"> | <YYYY-MM-DD> |
| Scheduled chores run from a clean clone or the CI checkout of the default branch, never a working copy | <the scheduler entry, or "no chores, checked <how>"> | <YYYY-MM-DD> |

## Evidence
<!-- tiers.py --evidence reads merged history on merged_ref and gives each tier eligible, hold (<why>) or breach (<metric>). A row that keeps a <placeholder> is a hold, so no tier is eligible until you set numbers. Suggested start: Window 90, Min merged 20, Max reverted 2, Max escaped 5, Max human-caught 10. A Max cell of - is not checked. -->
| Tier | Window (days) | Min merged | Max reverted % | Max escaped % | Max human-caught % |
|---|---|---|---|---|---|
| routine | <days> | <n> | <%> | <%> | <%> |
| domain | <days> | <n> | <%> | <%> | <%> |
