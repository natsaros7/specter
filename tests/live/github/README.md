# Live test of the GitHub `none` recipe

Runs review-loop step 5 for real in a public sandbox repository, with a GitHub App as approver. Spec:
`.specs/features/v070-live-and-eval/` (REQ-V070-01, design "Scenarios"). Each task below is one OK from Nikos. Agents
only read (`gh pr view`, `gh run view`, `gh api` GET) and never run a write command unless Nikos OKs it in that session.

Set once: `OWNER=<your account>`, `REPO=specter-live-sandbox`, `R=$OWNER/$REPO`.

Files here: `sandbox.sh` (below), `gates.yml` (the sandbox's required check `gates`), `probe.yml` (scenario K1). The
workflow under test is `kit/templates/github/specter-auto-merge.yml`; `sandbox.sh seed` adds the `SANDBOX_DELAY` sleep.

## Before any GitHub minute

```
sh tests/live/github/sandbox.sh seed ~/specter-live-dry
sh tests/live/github/sandbox.sh dry-run ~/specter-live-dry     # exit 0, every row ok
rm -rf ~/specter-live-dry
```

`dry-run` runs each scenario's `ready.py` call on a local bare origin. Row P2.2 prints PENDING until task 14 (`ready.py`
refuses `Human-Findings:`) has landed; after that it must say `ok`.

## What `sandbox.sh` does

| Command | Writes to GitHub? |
|---|---|
| `seed <dir>` | No. Builds a local repository (kit, profile, workflows, two routine commits). `<dir>` is new and under `$HOME`. |
| `dry-run <dir>` | No. Local clone and bare origin in a temp dir, removed on exit. |
| `open <dir> <id>` | No. Makes the scenario's local branch and PR text, then **prints** the `git push` and `gh pr create` commands. `--yes` runs them: use it only when Nikos OKs that scenario. |

## Setup (Nikos)

3. Repository, settings, interaction limit (#48):
   ```
   gh repo create "$R" --public --description "specter live recipe test, archived after"
   gh repo edit "$R" --enable-auto-merge --enable-squash-merge --enable-merge-commit=false --enable-rebase-merge=false
   gh api -X PUT "repos/$R/actions/permissions/workflow" -f default_workflow_permissions=read -F can_approve_pull_request_reviews=false
   gh api -X PUT "repos/$R/interaction-limits" -f limit=collaborators_only -f expiry=one_week
   ```
   Done when `gh api repos/$R --jq .allow_auto_merge` prints `true` and
   `gh api repos/$R/actions/permissions/workflow` shows `"default_workflow_permissions":"read"` and
   `"can_approve_pull_request_reviews":false`.
4. GitHub App (#49), in the browser: Settings, Developer settings, GitHub Apps, New. Permissions: Pull requests
   read/write, Contents read/write, Metadata read. Uncheck Webhook. Create it, generate a private key (`.pem`), note the
   App ID, install it on `$R` only. Done when the installation lists one repository.
5. Environment and credentials (#50), never repository-level secrets:
   ```
   gh api -X PUT "repos/$R/environments/specter-approver" -F 'deployment_branch_policy[protected_branches]=false' -F 'deployment_branch_policy[custom_branch_policies]=true'
   gh api -X POST "repos/$R/environments/specter-approver/deployment-branch-policies" -f name=main -f type=branch
   gh variable set SPECTER_APP_ID --env specter-approver --repo "$R" --body "<App ID>"
   gh secret set SPECTER_APP_KEY --env specter-approver --repo "$R" < path/to/key.pem
   ```
   Done when `gh api repos/$R/environments/specter-approver` shows the branch policy and `gh secret list --repo $R` is empty.
   Note: `create-github-app-token` v3 marks `app-id` deprecated in favour of `client-id`. The template still passes
   `app-id`, which works with the App ID above.
6. After batch 3, seed and push (#51). `<dir>` is a new folder under `$HOME`:
   ```
   sh tests/live/github/sandbox.sh seed ~/specter-live
   git -C ~/specter-live remote add origin "https://github.com/$R.git"
   ```
   Read `~/specter-live/.specs/steering/autonomy.md` (the eight Guardrails rows and their dates), then
   `git -C ~/specter-live push -u origin main`. Done when a fresh clone gives `routine: eligible` from
   `python3 .specs/kit/scripts/tiers.py --specs .specs --evidence`. Write the specter sha (`docs/SANDBOX.md`) in the report.
7. Ruleset on `main` (#52), `ruleset.json`:
   ```
   {"name":"main","target":"branch","enforcement":"active",
    "conditions":{"ref_name":{"include":["~DEFAULT_BRANCH"],"exclude":[]}},"bypass_actors":[],
    "rules":[{"type":"deletion"},{"type":"non_fast_forward"},
      {"type":"pull_request","parameters":{"required_approving_review_count":1,"dismiss_stale_reviews_on_push":true,
        "require_code_owner_review":false,"require_last_push_approval":false,"required_review_thread_resolution":false}},
      {"type":"required_status_checks","parameters":{"strict_required_status_checks_policy":true,
        "required_status_checks":[{"context":"gates"}]}}]}
   ```
   `gh api -X POST "repos/$R/rulesets" --input ruleset.json`. Done when `gh api repos/$R/rulesets` lists it.

## Scenarios (Nikos opens, the agent observes)

Order: K1 first. If its job (a) prints anything but `0`, stop: run task 12 now and open a draft advisory
(`SECURITY.md`). Opening one: `sh tests/live/github/sandbox.sh open ~/specter-live <id>`, then the printed commands.

Reads: `pr N` is `gh pr view N --json state,reviews,autoMergeRequest,headRefOid,mergeCommit`; `log` is
`gh run view <run> --log`; `body` is `git log -1 --format=%B origin/main` after a fetch.

8. K1, N1, N2, N3 (#53). Nothing may merge. K1: (a) prints `0`, (b) fails before any step, (c) is refused.
9. P1, N4, N5, N6, P2 (#54). Create N4's branch first (`open ... N4` makes it from the current `main`), then open P1 and
   let it merge, then open N4:

   | Id | Mid-flight step by Nikos | Expected |
   |---|---|---|
   | P1 | none | App review APPROVED on the head, squash-merged, body is the checked text |
   | N4 | none, open it after P1 merged | not approved (behind `main`) |
   | N5 | during the 60 s hold: `for i in 1 2 3 4; do echo x > docs/over-$i.md; done; git add docs; git commit -m over; git push` on the branch | approval dismissed stale, 2nd run does nothing, not merged |
   | N6 | first `gh variable set SANDBOX_DELAY --repo $R --body 30`; during the sleep push the same over-cap commit; afterwards `gh variable delete SANDBOX_DELAY --repo $R` | not merged; record which line caught it |
   | P2 | during the 60 s hold: `gh pr edit <n> --body-file <the text plus a line "Human-Findings: 0">` | merges with the checked body, no trailer |

   Observations: the table's "Observed by" column in the design. For N5 the timeline is
   `gh api repos/$R/issues/<n>/timeline` (look for `review_dismissed`).

## After (tasks 10 to 12)

10. The agent writes `docs/reviews/<date>-live-recipe.md` from the observations.
11. Pass: lift the CHANGELOG limit and mark review-loop step 5 and the template Verified. Fail: correct, rerun only the failing rows.
12. Teardown (Nikos, #57): delete the App's private key and uninstall or delete the App; `gh api -X DELETE repos/$R/environments/specter-approver`; disable Actions (`gh api -X PUT repos/$R/actions/permissions -F enabled=false`); `gh repo archive $R --yes`.

Cost: about 28 jobs of at most 2 minutes, free on a public repository. No `push`, `schedule` or `workflow_run` trigger, a
timeout on every job, one PR at a time.
