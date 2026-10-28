# specter: instructions for AI agents

You are inside **specter**, a spec-first workflow that any coding agent can follow.

## Whatever the user's first message is ("go", "hi", "what is this?"), follow [`GO.md`](GO.md).

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
| `examples/acme-shop/.specs/` | A complete worked example on a fictional shop |
| `tests/selftest.sh` | Lints the examples and dry-runs the installer |
| `.specs/` | Specter's own development specs, written with specter |

## Working on specter itself

Only when the user asks to change specter (not to install it). Spec non-trivial changes in `.specs/features/` first.
A change is mergeable only if every gate exits 0. Run them from the repo root; they are non-interactive and need no
network, and the selftest works in a `mktemp` dir and leaves the tree untouched.

| # | Gate | Command |
|---|---|---|
| G1 | Shell syntax | `sh -n install.sh && sh -n tests/selftest.sh` |
| G2 | Example specs lint | `python3 kit/scripts/spec_lint.py --specs examples/acme-shop/.specs` |
| G3 | Selftest (installer idempotency, hook, citations, drift, report, uninstall) | `sh tests/selftest.sh` |
| G4 | Specter's own specs | `python3 kit/scripts/spec_lint.py --specs .specs && python3 kit/scripts/spec_lint.py --specs .specs --cites` |

Don't invent features of the kit. If these files don't answer something, say so.
