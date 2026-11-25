# acme-shop as specter's evaluation set

A fixed set of five goals ([`goals.md`](goals.md)) that measures whether a release makes the factory better. Run it
after each release; the score sheets accumulate in `docs/evals/` at the specter root.

## Run procedure

One goal at a time, each in a fresh sandbox. Maven never runs on the host.

1. **Clean copy.** From the specter root: `sh examples/acme-shop/eval/sandbox.sh ~/acme-eval-e1`. It does the
   [README sandbox recipe](../README.md#sandbox-for-agent-runs) and rewrites the three Maven Gates rows (G1 to G3) of
   the sandbox's `spec-rules.md` to `sh scripts/mvnw-docker.sh ...`, so every Gate runs in the JDK container
   (`azul/zulu-openjdk:21`; Alpine cannot run protoc). It exits 1 unless exactly three rows changed.
2. **Offline.** The Docker volume `specter-acme-m2` is already filled by an earlier `sh tests/acme-build.sh --docker`.
   Run the loop with `ACME_NETWORK=none` so a build cannot reach out; fill the volume again only with a networked build you
   chose to run.
3. **Run the loop as a user would.** Open the agent in the sandbox, give it the goal's prompt from `goals.md` and
   nothing else, and let it follow `.specs/kit/docs/pipeline.md`: spec, tasks, planner, generator, reviewer, the
   Gates, then `ready.py`. The lead answers only at the escalation points, with the answers `goals.md` records.
4. **Fix rounds.** A red Gate or a review finding sent back to the generator is one round. More than 2: not delivered.
5. **Check:** `python3 .specs/kit/scripts/gates.py` in the sandbox, `python3 .specs/kit/scripts/tiers.py` for the tier
   label, and `ready.py` for the human line. Compare with the expected values in `goals.md`.
6. **Score** into `docs/evals/<date>-acme.md` with the template below. Nothing from a sandbox is merged back into specter;
   lessons go to specter's `.specs/steering/lessons.md` as a Human-required change.

Dry run of the harness, with no agent: `sh examples/acme-shop/eval/sandbox.sh ~/acme-eval-dry`, then in it
`ACME_OFFLINE=1 ACME_NETWORK=none python3 .specs/kit/scripts/gates.py`, expecting `verdict: ready (6 passed)`.
Remove the folder afterwards.

## Score sheet template

```markdown
# acme-shop eval, <YYYY-MM-DD>

- specter: <sha> (<VERSION>)
- agent: <host and version>; models: planner <id>, generator <id>, reviewer <id>
- JDK image: azul/zulu-openjdk:21 (<digest or pull date>)

| Goal | Delivered (y/n) | Fix rounds | Gates green first try | Tier expected / actual | Human expected / actual | Wall time | Tokens | Notes |
|---|---|---|---|---|---|---|---|---|
| E1 | | | | routine / | spot / | | | |
| E2 | | | | domain / | spot / | | | |
| E3 | | | | critical / | required / | | | |
| E4 | | | | domain (table) / | required / | | | the S7 tier side-finding, see goals.md |
| E5 | | | | critical / | stop at decision gate / | | | |

## Findings
<what the factory got wrong, and which lesson or kit change follows>
```
