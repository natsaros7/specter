# Steering — Autonomy profile

What agents may do on specter without a human. Editing this file is always a human-tier change.

## Tiers
<!-- Least autonomous last: a file takes the lowest row a glob matches. AGENTS.md is a guarded path (tiers.py), so it sits in trust, not kit as the design had it. -->
| Tier | Paths | Reviewer | Human |
|---|---|---|---|
| docs | `docs/*` `README.md` `CHANGELOG.md` `examples/*` `.specs/features/*` | standard | spot |
| kit | `kit/*` `GO.md` | standard | required |
| trust | `kit/scripts/*` `install.sh` `tests/*` `.github/*` `.specs/steering/*` `AGENTS.md` | deep | required |

## Guardrails
<!-- Only true rows. Branch protection is not set on main, and the Gates run in CI only from task 18 of v061. -->
| Guardrail | Enforced by | Verified |
|---|---|---|
| No direct or force push to the default branch | <branch protection or ruleset> (not set on main) | <YYYY-MM-DD> |
| The Gates run as required checks before a merge | <required status checks> (CI arrives with v061 task 18) | <YYYY-MM-DD> |
| An agent job triggered by untrusted text runs read-only, without secrets | no such job, checked `.github/` (absent) | 2026-11-24 |
| Scheduled chores run from a clean clone | no chores, checked this profile has no Chores section | 2026-11-24 |

## Evidence
| Tier | Window (days) | Min merged | Max reverted % | Max escaped % | Max human-caught % |
|---|---|---|---|---|---|
| docs | <days> | <n> | <%> | <%> | <%> |
