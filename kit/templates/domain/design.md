# <domain> — Design (as-built)

> Path `<dir>`, version `<x.y.z>`, grounded on `<sha>` <YYYY-MM-DD>. Decisions: <links to ADRs>.

## Stack
<language, framework and version, key libraries>

## Behaviour
<Mermaid sequence of the main flow, then bullets with `Class.method` anchors>

## Public interface
- **REST**: <base path, key operations, link to OpenAPI>
- **gRPC / messaging**: <services, topics, produced or consumed>

## Data
<datastore, schema owner, migrations path>

## Config / ports
<local vs deployed; where the deployed values live>

## Drift register (local)
- <short items; material ones also go in system/data-flows.md>
