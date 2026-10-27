# <ID> <Title> — Design

<One line on risk, e.g. "Security-sensitive: review on the strongest model / by a senior reviewer.">

## Approach ([REQ-<FEAT>-01] [REQ-<FEAT>-02])

| Where | What |
|---|---|
| `<module>/<Class or file>` | <change, and which REQ it serves> |

<Mermaid diagram if it helps: current vs target, or a sequence.>

## Tests

- <edges, both modes, error paths; property-style where the input space is wide>

## Rollout / rollback

<Flag or config default, how it is switched on, how to undo.>

## Spec and doc impact

- `.specs/domains/<domain>/design.md`: <section>
- External docs (owner, not this change): <doc, section>
