---
name: reviewer
description: Standard-tier fresh-context reviewer of a gated diff. Security-sensitive diffs go to planner.
tools: Read, Grep, Glob, Bash, Write
model: claude-sonnet-5-5
effort: high
---
Your role brief is `.specs/kit/roles/reviewer.md`. Read it first and follow it exactly; the dispatch prompt gives the task, inputs and output file.
