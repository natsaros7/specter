# GO: assess, install and set up specter in one conversation

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

If you are not the strongest model the user has available, say so in one line: setup quality (depth of the Drift
Register, number of verified citations) follows the model, and they can switch now or carry on.

Then say, in three lines at most: what is about to happen (look → propose → install on your yes → a short interview → done),
and that nothing changes until they say yes.

## Step 2: Look (read-only, about 2 minutes)

At `PROJECT`, find out:

1. **Layout:** a git repo? A folder of several repos (`ls -d */.git`)? Is `.specs/` already there?
   (If `.specs/kit/` exists, this is an **upgrade**: say so, and the install step just refreshes the kit.)
2. **Agents in use:** run `KIT/install.sh <path> --detect`. It prints the agents it would wire (a skill for each, plus
   rule files) and whether it found them in the **project files** or only on **this machine**.
3. **Quick scan:** the deployables (build files, Dockerfiles, charts), the contracts (OpenAPI, proto, topics),
   any docs/ADRs, and the CI file. Skim only. The deep scan happens in setup.

## Step 3: Propose (one message, then one question)

Show this table, filled in:

| | Finding | What I'll do |
|---|---|---|
| Layout | single repo / monorepo / workspace of N repos | Install at `<path>`; git hook yes/no |
| Parts I see | e.g. 3 services, 1 UI, 1 shared lib | Become `domains/` (you approve the list in setup) |
| Requirements | e.g. Jira keys in commits / none found | I'll ask in setup |
| Agents | e.g. Codex + Claude Code (from project files) | `spec-first` skill for each; `AGENTS.md` (+ `CLAUDE.md` …) marker block only, your text untouched |

Then list exactly what the installer creates or changes (see "What gets installed" in `KIT/README.md`) and give your
recommendation in one line. If it's a poor fit, say why.

Ask:

> **Install it in `<path>`?**
> 1. yes **[default]**
> 2. not now

When `--detect` says **this machine only**, nothing agent-specific gets wired by default. Add to the same question:
*"…and wire it for `<the agent you are>`? Others found on this machine: `<list>`; name any you also use."* Pass the
answer as `--agents=a,b`. When the source is **project files**, don't ask about agents.

If the user picks 2, stop politely. You're done.

**Where to install:** a single repo or monorepo → its root. Several repos for one system → the folder that holds them.
If that folder isn't a git repo, recommend `git init` there with the child repos listed in `.gitignore`, and ask before doing it.

## Step 4: Install

Run `KIT/install.sh <path> --from-go` (plus `--agents=…` if the user named agents). Show its output as a short
bullet list. If it fails, show the error and stop.

## Step 5: Setup interview (continue straight on, no extra confirmation)

Tell the user: *"Installed. Now I'll learn the project. Expect 4–8 questions in 1–2 rounds, then one approval of the plan."*
Then follow `<path>/.specs/kit/playbooks/setup.md` from Phase 0 to the end.

If the session or context runs out, setup can resume. Tell the user they can say "continue setup" in a fresh session.

## Step 6: Wrap up

Give the setup report from Phase 6 of `setup.md`. Don't add a second report. Then ask:
**"Commit the new spec files? 1. yes [default] 2. no, I'll review first."**
On yes, commit only `.specs/` and the files the installer listed, with the message `docs(specs): add spec-first system`.
