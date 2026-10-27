# GO: assess, install and set up spec-first-kit in one conversation

**For the AI agent.** The user wants this to take no effort: they say "go" and answer your questions. Do everything
else yourself, in this order. Keep each message short and plain.

## Ground rules

- **Read-only until the user says yes to installing.** Before that, only look.
- Ask **numbered questions with a default in brackets**, at most 5 at a time, and say: *"Reply `ok` to accept all defaults."*
- Never ask what you can find out yourself by looking at the files.
- If you cannot run shell commands, tell the user the exact command to paste, and wait.
- `KIT` = the folder this file is in. `PROJECT` = the user's project folder.

## Step 1: Find the project

- If your working folder is **not** `KIT`, then `PROJECT` = your working folder. Don't ask.
- If your working folder **is** `KIT`, ask one question: *"Which project folder should I look at? (path)"*

Then say, in three lines at most: what is about to happen (look → propose → install on your yes → a short interview → done),
and that nothing changes until they say yes.

## Step 2: Look (read-only, about 2 minutes)

At `PROJECT`, find out:

1. **Layout:** a git repo? A folder of several repos (`ls -d */.git`)? Is `.specs/` already there?
   (If `.specs/kit/` exists, this is an **upgrade**: say so, and the install step just refreshes the kit.)
2. **Agents in use:** `AGENTS.md`, `CLAUDE.md`/`.claude/`, `.cursor/`, `.github/copilot-instructions.md`, `GEMINI.md`.
3. **Quick scan:** the deployables (build files, Dockerfiles, charts), the contracts (OpenAPI, proto, topics),
   any docs/ADRs, and the CI file. Skim only. The deep scan happens in setup.

## Step 3: Propose (one message, then one question)

Show this table, filled in:

| | Finding | What I'll do |
|---|---|---|
| Layout | single repo / monorepo / workspace of N repos | Install at `<path>`; git hook yes/no |
| Parts I see | e.g. 3 services, 1 UI, 1 shared lib | Become `domains/` (you approve the list in setup) |
| Requirements | e.g. Jira keys in commits / none found | I'll ask in setup |
| Agent files | e.g. AGENTS.md (new), CLAUDE.md (block added) | Marker block only; your text untouched |

Then list exactly what the installer creates or changes (see "What gets installed" in `KIT/README.md`) and give your
recommendation in one line. If it's a poor fit, say why.

Ask:

> **Install it in `<path>`?**
> 1. yes **[default]**
> 2. yes, and add the Claude Code helper agents *(only offer this if Claude Code is in use)*
> 3. not now

If the user picks 3, stop politely. You're done.

**Where to install:** a single repo or monorepo → its root. Several repos for one system → the folder that holds them.
If that folder isn't a git repo, recommend `git init` there with the child repos listed in `.gitignore`, and ask before doing it.

## Step 4: Install

Run `KIT/install.sh <path>` (add `--with-agents` for option 2). Show the user the "Done" lines of its output, nothing more.
If it fails, show the error and stop.

## Step 5: Setup interview (continue straight on, no extra confirmation)

Tell the user: *"Installed. Now I'll learn the project. I'll ask a few questions as I go, usually 5–10 in total."*
Then follow `<path>/.specs/kit/playbooks/setup.md` from Phase 0 to the end. It includes one approval: the domain map.

If the session or context runs out, setup can resume. Tell the user they can say "continue setup" in a fresh session.

## Step 6: Wrap up

Report in at most 8 lines: what was created, the open UNKNOWNs, the top 3 drift findings, and how to use it from now on:

- *"Spec this: <change>"* → a feature spec before code
- *"Next task on <feature>"* → implement one task
- *"Sync specs"* → after a change lands
- *"Refresh the specs"* → now and then

Finally ask: **"Commit the new spec files? 1. yes [default] 2. no, I'll review first."**
On yes, commit only `.specs/` and the agent files the installer touched, with the message
`docs(specs): add spec-first system`.
