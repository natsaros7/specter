# spec-first-kit

A spec-first ("Kiro-style") workflow that any coding agent can follow (Claude Code, Codex, Cursor, Copilot, Gemini CLI and others) and that sets itself up in your project.

- **Before code:** a non-trivial change gets `requirements.md → design.md → tasks.md`, with traceable `[REQ-…]` IDs.
- **During code:** one task at a time, each closed by your project's gate.
- **After code:** the spec ships in the same commit. A **Drift Register** records anything that isn't true yet.
- **Setup is done by your agent:** it scans the project, interviews you only where the code can't answer, and writes `.specs/`.

Why it works this way: [`PHILOSOPHY.md`](PHILOSOPHY.md).

## Get started: 3 steps, about 20 minutes, mostly answering questions

**1. Download the kit** (anywhere *outside* your project; it is a tool, not part of your code):

```bash
git clone git@github.com:natsaros7/spec-first-kit.git ~/tools/spec-first-kit
```

**2. Open your AI agent in your project** (Claude Code, Codex, Cursor, Copilot, Gemini…) **and paste:**

```text
Follow ~/tools/spec-first-kit/GO.md for this project.
```

**3. Answer its questions.** Every question has a default, so `ok` is always a valid answer.

The agent then:
- looks at your project (read-only),
- proposes what it would install and asks **"Install it?"**,
- installs on your yes,
- interviews you briefly (where requirements live, who decides architecture, what your build gate is),
- shows you the list of parts ("domains") to approve,
- writes `.specs/` and offers to commit it.

Your teammates get everything with the repo. They never need to clone the kit.

> Prefer not to paste? Open the agent **in the kit folder** and just say **go**. It asks for your project path.
> Want no AI for the install itself? Run `~/tools/spec-first-kit/install.sh ~/code/my-project`, then tell your agent
> "follow .specs/kit/playbooks/setup.md".

## Where to install (the `<target>`)

`<target>` is the folder where `.specs/` should live:

| Your layout | `<target>` | Git hook |
|---|---|---|
| One repo | The repo root | Yes: warns when code changes without a spec change |
| Monorepo | The repo root (one `domains/` folder per deployable) | Yes |
| **Several repos for one system** | The **workspace folder** that holds them (`git init` it and add the child repos to `.gitignore`) | No (commits happen in the child repos); agent rules + review keep specs in sync |

## Day-to-day

Say these to your agent. With Claude Code, `/spec-first <request>` does the same.

| Say | Playbook |
|---|---|
| "Spec this: <change>" | `new-feature.md`: writes requirements/design/tasks, lints them, waits for your approval |
| "Next task on <feature>" | `next-task.md`: one task, gate, tick |
| "Sync specs, <feature> landed" | `sync.md`: fold into `domains/`, update traceability and drift |
| "Refresh the specs" | `refresh.md`: re-ground against the latest code |

The two scripts decide pass or fail; no AI is involved:

```bash
python3 .specs/kit/scripts/spec_lint.py         # structure + REQ traceability + broken links
python3 .specs/kit/scripts/spec_sync_check.py   # code changed without a spec change? (the pre-commit hook)
```

## What gets installed

```
<target>/
├── AGENTS.md                      # + marker block with the rules (created if missing)
├── CLAUDE.md, GEMINI.md, .github/copilot-instructions.md   # + same block, only if the file/agent is present
├── .cursor/rules/spec-first.mdc   # only if .cursor/ exists
├── <agent>/skills/spec-first/     # one per agent detected: .agents/ (Codex), .claude/, .cursor/, .gemini/, .github/
├── .claude/agents/                # Claude Code only: planner/generator/reviewer sub-agents
└── .specs/
    ├── spec-kit.json              # settings (setup tunes them)
    ├── kit/                       # playbooks, templates, scripts, docs (replaced on upgrade)
    └── …                          # what setup generates: README router, system/, domains/, steering/, features/
```

The installer never touches content outside its marker blocks. Re-run it to upgrade; `--uninstall` removes the kit
but keeps your specs. Requirements: `python3` (3.8+) and `git`. Nothing else.

## Example

[`examples/acme-shop/.specs/`](examples/acme-shop/.specs/README.md) is the whole system on a fictional shop:

- the router, architecture, data flows with a Drift Register, and traceability;
- a filled-in project profile showing the setup interview;
- an as-built domain;
- two features: a **small change blocked on a decision** (`ord-142`) and a **cross-cutting refactor** with a safety net and behaviour sign-offs (`ord-120`).

## Going further (optional)

- [`kit/docs/model-routing.md`](kit/docs/model-routing.md): which model tier runs which step, and when to escalate.
- [`kit/docs/review-loop.md`](kit/docs/review-loop.md): worker → gate → fresh-context reviewer → one retry → human.
- [`kit/roles/`](kit/roles/README.md): the generic planner / generator / reviewer roles. Claude Code gets them as native sub-agents automatically.
- `install.sh --user` adds the `spec-first` skill at user level for every agent detected.
