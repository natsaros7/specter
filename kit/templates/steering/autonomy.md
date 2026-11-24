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

## Chores
Runs: <schedule>, by <cron | launchd | CI schedule>, as `python3 .specs/kit/scripts/gates.py --file .specs/steering/autonomy.md`.

| # | Gate | Command |
|---|---|---|
| C1 | Spec health | `python3 .specs/kit/scripts/spec_lint.py --cites && python3 .specs/kit/scripts/spec_report.py` |
