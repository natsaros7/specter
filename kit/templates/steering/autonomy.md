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
<!-- Keep lockfiles out of a `none` row: two changed lines can point a dependency at another tarball. Put the scripts your Gates commands run (test runners, lint scripts, CI config) in the last tier: ready.py compares Gates commands, not the scripts they call. -->
| Tier | Paths | Reviewer | Human |
|---|---|---|---|
| routine | `<tests glob>` `<docs glob>` | standard | none |
| domain | `<source glob>` | standard | spot |
| critical | `<security glob>` `<contracts glob>` `<migrations glob>` `<CI glob>` `CODEOWNERS` | deep | required |

## Chores
Runs: <schedule>, by <cron | launchd | CI schedule>, as `python3 .specs/kit/scripts/gates.py --file .specs/steering/autonomy.md`.

| # | Gate | Command |
|---|---|---|
| C1 | Spec health | `python3 .specs/kit/scripts/spec_lint.py --cites && python3 .specs/kit/scripts/spec_report.py` |

## Guardrails
<!-- Specter records these; the platform enforces them. A row counts as declared when Enforced by names what enforces it (no <placeholder>) and Verified is a YYYY-MM-DD date. Until every row is declared, a tier with Human none is labelled spot. Human none also needs the lowest tier and an eligible Evidence row; every PR needs an approval; for a none PR a non-required job runs `ready.py --range <base sha>...<head sha> --pr <pr text> --auto-merge` from a trusted worktree of the base and, on exit 0 only, approves with a non-agent identity and enables auto-merge (review-loop.md step 5). No such job or no chores: say so, e.g. "no such job, checked .github/workflows/", and date it. -->
| Guardrail | Enforced by | Verified |
|---|---|---|
| No direct or force push to the default branch | <branch protection or ruleset> | <YYYY-MM-DD> |
| The Gates run as required checks before a merge | <required status checks> | <YYYY-MM-DD> |
| Every PR needs an approval, dropped on a new commit; a human gives it, and only the `ready.py --auto-merge` job's identity (never an agent's) approves a PR labelled `none` | <the App or bot that approves, and where its key lives: a default-branch-only environment (GitHub) or a trusted project's protected variable (GitLab)> | <YYYY-MM-DD> |
| Agent credentials cannot approve or merge | <bot account or token scope> | <YYYY-MM-DD> |
| Agent permissions come from the host's configuration, not from a prompt | <agent settings file or CI permissions> | <YYYY-MM-DD> |
| Agents cannot edit merged history or review records, or create tags or `refs/replace/` refs | <history protection, tag rules and the platform's review log> | <YYYY-MM-DD> |
| An agent job triggered by untrusted text (an issue, a PR, a comment, an outside contribution) runs read-only, without secrets; its writes go through a separate step that validates them | <CI permissions and the platform's safe-output step, or "no such job, checked <how>"> | <YYYY-MM-DD> |
| Scheduled chores run from a clean clone or the CI checkout of the default branch, never a working copy | <the scheduler entry, or "no chores, checked <how>"> | <YYYY-MM-DD> |

## Evidence
<!-- tiers.py --evidence reads merged history on merged_ref and gives each tier eligible, hold (<why>) or breach (<metric>). A row that keeps a <placeholder> is a hold, so no tier is eligible until you set numbers. Suggested start: Window 90, Min merged 20, Max reverted 2, Max escaped 5, Max human-caught 10. A Max cell of - is not checked. Optional trailing columns `Max files` and `Max lines` cap a change in a tier whose Human is `none` (defaults 3 and 50; - is the default): a larger change is labelled `spot`. -->
| Tier | Window (days) | Min merged | Max reverted % | Max escaped % | Max human-caught % |
|---|---|---|---|---|---|
| routine | <days> | <n> | <%> | <%> | <%> |
| domain | <days> | <n> | <%> | <%> | <%> |

## Tests
<!-- Optional. Path globs (in backticks) of test files; a change in a Human `none` tier that deletes or edits a line of one is labelled `spot`, only adding lines keeps `none`. Default: `*test*`, `*spec*`, `conftest.py`. A deleted or re-moded test file and an added or changed `conftest.py` or `__init__.py` are `spot` too. An added line can still switch a test off (a skip marker): the reviewer's `complexity:` is the backstop. -->
