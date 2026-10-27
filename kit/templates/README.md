# .specs — <System> spec system

A **link layer** over the existing sources of truth. Where it summarises, the linked source wins.
Grounded on `<sha>`, <YYYY-MM-DD>. Workflow: [`steering/spec-rules.md`](steering/spec-rules.md). Kit: `kit/` (playbooks, templates, scripts).

## Router: read THIS, then open the ONE file you need

| If you need… | Open only |
|---|---|
| What the system does, topology, component registry | [`system/architecture.md`](system/architecture.md) |
| How one domain works | One link per domain: [`domains/<domain>/design.md`](domains/<domain>/design.md) · … (replace with the real list) |
| End-to-end flows, known drift | [`system/data-flows.md`](system/data-flows.md) |
| To make a non-trivial change | [`steering/spec-rules.md`](steering/spec-rules.md), then `kit/playbooks/new-feature.md` |
| Standards and gates | [`steering/code-standards.md`](steering/code-standards.md) |
| What setup learned, and the open UNKNOWNs | [`steering/project-profile.md`](steering/project-profile.md) |

## Sources of truth outside `.specs/`

| Source | Where | Rule |
|---|---|---|
| <ADRs / wiki / contract> | <path or link> | <read / link only> |
