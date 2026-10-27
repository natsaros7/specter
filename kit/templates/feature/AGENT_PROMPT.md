## Agent prompt
Implement <ID>: <one line>. Work autonomously; stop and ask <who> only at the items marked DECISION.

### Context
- Repo `<repo>` (base `<main>`). Branch `<type>/<ID>-<summary>`.
- Problem (verified <date>, `<sha>`): <`path:line` facts>.
- Why it matters: <one line>.

### Requirements
- [REQ-<FEAT>-01] <…>

### Steps
1. DECISION: <wait for … before coding>.
2. <concrete step with class, method and pattern to copy>

### Constraints
- <commit style, language level, DI style, test naming, banned patterns>
- Out of scope: <…>

### Verification (everything must pass before the PR)
- <exact gate commands>

### Deliverables
- <PR title and body contents, changelog, tracker transitions>

### Open decisions / dependencies
- DECISION: <…>
