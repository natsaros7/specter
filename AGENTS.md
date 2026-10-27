# spec-first-kit: instructions for AI agents

You are inside **spec-first-kit**, a spec-first ("Kiro-style") workflow that any coding agent can follow.

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

Don't invent features of the kit. If these files don't answer something, say so.
