# Visual overview

Diagrams, screenshots from real runs, and a slide deck for specter. Release 0.8.0 is shipped. 0.9.0 is in progress and drawn as planned.

## Diagrams

![Spec-first workflow: GO, install, setup interview, then spec, implement, gates, review, human check, sync](workflow.svg)

`workflow.svg`: the one-time setup and the loop every change follows.

![Trust layer at 0.8.0: tiers and guardrails give a label, gates, review and verification feed a readiness verdict, evidence flows back from merged history](trust-layer.svg)

`trust-layer.svg`: how a change is judged today, and how merged history reports which tier earned more autonomy.

![Kiro stage ladder with specter's releases: 0.6.0 to 0.8.0 shipped, 0.9.0 planned, v070 candidates, stage 5 out of scope](roadmap.svg)

`roadmap.svg`: shipped, planned and candidate work against the Kiro five-stage ladder.

## Screenshots

Every screenshot comes from a command run on the acme-shop example at release 0.8.0 (`41583e2`), in a sandbox built with the recipe in [`examples/acme-shop/README.md`](../../examples/acme-shop/README.md). The raw text sits next to each PNG. Absolute paths are replaced by `~`.

| Screenshot | Command | Raw text |
|---|---|---|
| ![spec report](screenshots/07-spec-report.png) | `spec_report.py`, page opened in headless Chrome | [txt](screenshots/07-spec-report.txt) |
| ![tiers check](screenshots/01-tiers-check.png) | `tiers.py --check` | [txt](screenshots/01-tiers-check.txt) |
| ![staged label](screenshots/02-tiers-staged.png) | `tiers.py` on a staged `pom.xml` change | [txt](screenshots/02-tiers-staged.txt) |
| ![range label](screenshots/03-tiers-range.png) | `tiers.py --range main...HEAD` | [txt](screenshots/03-tiers-range.txt) |
| ![gates](screenshots/04-gates.png) | `gates.py` | [txt](screenshots/04-gates.txt) |
| ![ready](screenshots/05-ready.png) | `ready.py --range main...HEAD --pr pr.md` ([PR text](screenshots/05a-pr-text.txt)) | [txt](screenshots/05-ready.txt) |
| ![evidence](screenshots/06-evidence.png) | `tiers.py --evidence` | [txt](screenshots/06-evidence.txt) |

Sandbox changes you should know about, since the screenshots depend on them:

- `merged_ref` is set to `main`, so staged and range labels have a base.
- The Gates table is cut to the two script rows (G4, G5) because the Maven gates need JDK 21.
- Evidence thresholds are small (min merged 3, human-caught max 50%) so ten demo commits can show `eligible` and `breach`.
- The history has `Human-Findings:` trailers and one `git revert`. The PR text, including the reviewer model ids, is written by hand as demo input; only the scripts' output is real.
- The terminal PNGs are the captured text rendered into a dark HTML page. The spec report is the real page.

## Deck

[`deck/slides.md`](deck/slides.md) is a Slidev source (14 slides). The exported [`deck/specter-overview.pdf`](deck/specter-overview.pdf) is included.

```bash
cd docs/overview/deck && npm install
npx slidev slides.md                                   # live
npx slidev export slides.md --output specter-overview.pdf --dark false
```
