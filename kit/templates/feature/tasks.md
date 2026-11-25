# <ID> <Title> — Tasks

<For long work, add a "## ▶ Resume here" block: goal, branch/PR, the pinned plan issue (if the project has a tracker), done, open decisions, gate commands.>

Deploy impact: none | <job or env>: <what changes: new outbound calls, runtime, exit codes, output, a dependency>

- [ ] 1 <Gate: decision recorded on the ticket; delete the unused option from the spec> — [REQ-<FEAT>-01]
- [ ] 2 <atomic implementation task> — [REQ-<FEAT>-01]
- [ ] 3 <tests for …> — [REQ-<FEAT>-01] [REQ-<FEAT>-02]
- [ ] 4 Gate green: <commands from spec-rules Definition of Done> — [REQ-<FEAT>-02]
- [ ] 5 `.specs/domains/<domain>/` sync — [REQ-<FEAT>-01]
<!-- Platform root (spec-kit.json "layer": "platform"): each task is one repo, `platform:` for work in no repo, member REQ ids unbracketed in requirements.md:
- [ ] 2 orders: <what> → orders/.specs/features/<f>/ · after: 1 — [REQ-<FEAT>-01]
- [ ] 3 billing: <what> → billing#13 · after: 2 — [REQ-<FEAT>-01] -->
- [ ] 6 PR: the `### Gates` and `### Review` blocks (and `### Verification` when there are artifacts) and the `Deploy impact:` line in its description — [REQ-<FEAT>-02]
