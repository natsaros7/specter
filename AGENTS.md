# specter: instructions for AI agents

You are inside **specter**, a spec-first workflow that any coding agent can follow.

## Whatever the user's first message is ("go", "hi", "what is this?"), follow [`GO.md`](GO.md).

Exception: "pick up and continue", "resume" or "continue" in this repo means work on specter itself. Read the pinned
GitHub issue (`gh issue list --label v061` shows the plan issue) and the "▶ Resume here" block in the in-progress
feature's `tasks.md`, then run the next batch. Don't start GO.

It walks them through it: look at their project → propose → install on their yes → setup interview → done.
If they only want to understand the kit first, summarise `README.md` and `PHILOSOPHY.md` in under 10 lines, then
offer GO.

## Map of this repo

| Path | What |
|---|---|
| `GO.md` | The one-conversation flow: assess, install, set up |
| `README.md` / `PHILOSOPHY.md` | Human guide / the why |
| `install.sh` | One-command install, upgrade and uninstall (used by GO) |
| `kit/` | What gets copied into `<project>/.specs/kit/`: rules, playbooks, templates, scripts, docs |
| `kit/adapters/` | Thin per-agent extras (Claude skill and agents, Cursor rule) |
| `examples/acme-shop/` | A worked example: a Java 21 / Spring Boot 4 shop and its full `.specs/` tree |
| `examples/cite-demo/` | A tiny fixture whose citations fail on purpose (README demo) |
| `tests/selftest.sh` | Lints the examples and dry-runs the installer |
| `tests/gates.sh` | Runs G1 to G4, `--docker` inside a container (use it where scanners slow the host), `--only G3` for one |
| `tests/acme-build.sh` | Optional G5: builds acme-shop with JDK 21 |
| `.specs/` | Specter's own development specs, written with specter |

## Working on specter itself

Only when the user asks to change specter (not to install it). Spec non-trivial changes in `.specs/features/` first.
A change is mergeable only if every gate exits 0. Run them from the repo root; they are non-interactive and G1 to G4 need no
network or JDK, and the selftest works in a `mktemp` dir and leaves the tree untouched.

| # | Gate | Command |
|---|---|---|
| G1 | Shell syntax | `sh -n install.sh && sh -n tests/selftest.sh && sh -n tests/acme-build.sh && sh -n tests/gates.sh` |
| G2 | Example specs lint and citations | `python3 kit/scripts/spec_lint.py --specs examples/acme-shop/.specs && python3 kit/scripts/spec_lint.py --specs examples/acme-shop/.specs --cites` |
| G3 | Selftest (installer idempotency, hook, citations, drift, report, uninstall) | `sh tests/selftest.sh` |
| G4 | Specter's own specs and README | `python3 kit/scripts/spec_lint.py --specs .specs && python3 kit/scripts/spec_lint.py --specs .specs --cites && python3 tests/readme_check.py` |
| G5 | Example build (optional; needs JDK 21 and, on the first run, network; must run, not skip, when the diff touches `examples/acme-shop/` outside `.specs/`) | `sh tests/acme-build.sh` |

A release also refreshes `docs/overview/`: the deck, the roadmap, and any screenshot whose output changed.

Don't invent features of the kit. If these files don't answer something, say so.
