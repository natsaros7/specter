# Roles: planner, generator, reviewer

Three role briefs that any agent can take on. They split the work so that **the one who writes the code is never the one
who approves it**, and so that the strongest (most expensive) model is used only where judgement matters.

| Role | Model tier | Does | Never does |
|---|---|---|---|
| [planner](planner.md) | deep (your strongest model, high effort) | Setup/refresh, feature specs, architecture, root-cause diagnosis, security review, escalations | — |
| [generator](generator.md) | standard (mid-tier model) | Implements **one** task, writes tests, runs the gate, reports the exit code | Commit; decide what the spec left open |
| [reviewer](reviewer.md) | standard; deep for security paths | Reviews the frozen diff in a **fresh context** against the spec | Edit code |

## How to use them with any agent

| Your tool | How |
|---|---|
| Any agent, no extra features | Start a **new session** and say: *"Act as `.specs/kit/roles/reviewer.md`. The diff is in `<patch>` and the feature is `<feature>`."* A new session is a fresh context. |
| Model per session or profile (e.g. Codex profiles, Gemini `--model`, Cursor's model picker) | Map deep / standard to two profiles; pick the profile by role |
| Sub-agents (e.g. Claude Code) | The installer wires these roles in as native sub-agents automatically (`.claude/agents/`) |

The loop that ties them together: [`../docs/review-loop.md`](../docs/review-loop.md). Which tier runs which step:
[`../docs/model-routing.md`](../docs/model-routing.md).
