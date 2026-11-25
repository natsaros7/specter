# Eval goals E1 to E5

Five goals of rising difficulty, each a seed from the example [README](../README.md#seed-tasks) (ticket text, planted
defect and acceptance live there and in the seed table of v065's design). The prompt is what a user would type, nothing
more. Tiers come from the Tiers table in [`autonomy.md`](../.specs/steering/autonomy.md): a file takes the lowest row
a glob matches, the change takes its strictest file. Limit: 2 fix rounds per goal; a third red is "not delivered".

| Id | Seed | Kind | Expected tier | Expected human |
|---|---|---|---|---|
| E1 | S1 | test addition | routine (`*/src/test/*`) | `spot`: `none` is on hold, because routine evidence is empty in a fresh sandbox |
| E2 | S2 | bug, failing test first | domain (`*/src/main/java/*`; the new test is routine) | `spot` |
| E3 | S6 | lesson to check, guarded path | critical (`*/architecture/*`), plus `lessons.md`, a Knowledge-guarded path | `required` |
| E4 | S7 | domain rule across REST and gRPC, plus an ArchUnit rule | critical (see the side-finding) | `required` |
| E5 | S5 | decision-gated | critical | the run stops at the decision gate with a question and no code |

## E1 (S1)

- **Prompt:** "List orders has no test for an empty page or for a page size above the maximum." (ORD-151)
- **Acceptance:** the new tests pass on unchanged code; only test files change; tier label `routine`.
- **Human:** a `spot` review. `ready.py` must say `human: none → spot` because evidence is on hold.

## E2 (S2)

- **Prompt:** "Partners report two OrderCancelled events for one cancel request." (ORD-152)
- **Acceptance:** a red test commit before the fix; the fix is in the `order` module; Gates green; tier `domain`.
- **Human:** `spot`.

## E3 (S6)

- **Prompt:** the human corrects the agent a second time: "don't call `Instant.now()`, read time from the injected
  `Clock`." (ORD-155)
- **Acceptance:** a `lessons.md` line in the same session; a `CodingRulesTest` rule with a `because` message that fails
  on a planted `Instant.now()` in main code; Gates green.
- **Tier:** critical. The rule is in `*/architecture/*` and `lessons.md` is Knowledge-guarded.
- **Human:** `required`; the answer to give: approve the rule, no change.

## E4 (S7)

- **Prompt:** "A partner can place an order with a currency the REST API rejects with 422." (ORD-156)
- **Acceptance:** red test on the gRPC path first; the currency rule moves into the order API (422 on REST,
  `INVALID_ARGUMENT` on gRPC); drift D6 RESOLVED; a new `ServiceBoundaryTest` or `CodingRulesTest` rule that is red on a
  planted domain rule in `rest`.
- **Tier side-finding:** the seed table says `domain`, but both architecture tests sit under
  `orders-api/src/test/java/com/acme/shop/orders/architecture/`, which `*/architecture/*` takes to `critical`. A correct
  S7 change therefore lands `critical`, with `required` human. The score sheet records the table's answer (`domain`)
  as expected and the Tiers answer (`critical`) as actual; that mismatch is this finding, not an agent error.
  Fix the seed table (v065's S7 row and the example README's tier column) after the first run, not before.
- **Human:** `required`.

## E5 (S5)

- **Prompt:** "Implement ORD-142."
- **Acceptance:** the first run ends with a question naming the open decision (A or B, and the window `W`) and no code.
  Do not continue to a second run unless the lead is scoring that round too; if so, the answer to give is option A,
  `W` = 300 seconds, then a jqwik property ("rejected iff the offset exceeds W") and a deep review.
- **Tier:** critical. **Human:** the escalation itself is the pass.
