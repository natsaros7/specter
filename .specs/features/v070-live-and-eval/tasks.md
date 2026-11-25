# v070 Live recipe, deep-review follow-ups and the acme eval set — Tasks

Deploy impact: none (specter ships as files from tagged releases). Outside this repo, a public sandbox repository
and a GitHub App are created under Nikos's account for the live test, then archived (tasks 3 to 12).

## ▶ Resume here (2026-11-25)

- **Goal:** release 0.11.0. Verify the GitHub `none` recipe live, close #40 red-first, and ship acme-shop as the eval
  set (#35).
- **Where:** the spec is a draft on `main` + 1 commit, not pushed. Next comes branch `feat/0.11.0`. The plan issue
  and one issue per task are still to be created by Nikos; this block names the plan issue once it exists.
- **Done:** nothing. The spec is awaiting approval.
- **Open:** decisions 1 to 9 in requirements.md, each with a recommendation. Task 1 records them.
- **Nikos steps** (outward-facing, his OK each time): 1, 3, 4, 5, 6, 7, 8, 9, 12; the OKs in 18 (first networked
  build) and 20 (token spend); approving 11 and 21.
- **Gates:** `sh tests/gates.sh --docker` (G1 to G4), and G5 with `sh tests/acme-build.sh --docker` once task 18
  lands. The diff touches `examples/acme-shop/` outside `.specs/`, so G5 must run.

- [ ] 1 Gate: Nikos approves the spec and decisions 1 to 9, recorded on the plan issue (Nikos) — [REQ-V070-01] [REQ-V070-02] [REQ-V070-03] [REQ-V070-04] [REQ-V070-05] [REQ-V070-06] [REQ-V070-07] [REQ-V070-08] [REQ-V070-09]
- [ ] 2 Sandbox kit: `tests/live/github/` (checklist, `sandbox.sh` seed/dry-run/open, sandbox workflows), the `specter-auto-merge.yml` template, a 14b grep row; the local dry run passes — [REQ-V070-01]
- [ ] 3 Create the public sandbox repository and its settings, with the interaction limit (Nikos) — [REQ-V070-01]
- [ ] 4 Create the GitHub App and install it on the sandbox only (Nikos) — [REQ-V070-01]
- [ ] 5 Environment `specter-approver` (deployment branch `main` only), App id variable and key secret (Nikos) — [REQ-V070-01]
- [ ] 6 After batch 3: seed the sandbox from the `feat/0.11.0` tip and push `main` with its workflows (Nikos) — [REQ-V070-01]
- [ ] 7 Ruleset on `main`: PR, 1 approval, stale dismissed, required `gates`, up to date, no bypass (Nikos) — [REQ-V070-01]
- [ ] 8 Scenarios K1, N1, N2, N3: nothing merges; the key is unreachable (Nikos opens, the agent observes) — [REQ-V070-01]
- [ ] 9 Scenarios P1, N4, N5, N6, P2: only P1 and P2 merge, P2 with the checked body (Nikos opens, the agent observes) — [REQ-V070-01] [REQ-V070-03]
- [ ] 10 Write `docs/reviews/<date>-live-recipe.md` from the observations — [REQ-V070-01]
- [ ] 11 Pass: lift the CHANGELOG limit, mark step 5 and the template Verified; fail: correct the recipe and rerun only the failing rows (Human required) — [REQ-V070-01]
- [ ] 12 Teardown: delete the App key, uninstall the App, delete the environment, disable Actions, archive (Nikos) — [REQ-V070-01]
- [ ] 13 Byte cap (`Max bytes`, default 4000) and LFS pointers in `small()`, red rows in 13c2 `t70b` (security) — [REQ-V070-02]
- [ ] 14 `ready.py` refuses `Human-Findings:` in the PR text or range commits; the job merges with the checked body; drop the 0.10.0 zero-drop (security) — [REQ-V070-03]
- [ ] 15 Key evidence by the Tiers rows from the tier down plus Knowledge globs; the finding-5 probe in 13c3 `t13e25` (security) — [REQ-V070-04]
- [ ] 16 `core.commitGraph=false` at the `tiers` import; probe a forged commit-graph first, row `t13e26` (security) — [REQ-V070-05]
- [ ] 17 `tests/gates.sh --docker` copies only `git ls-files --cached --others --exclude-standard` — [REQ-V070-06]
- [ ] 18 G5 in a container: `scripts/mvnw-docker.sh`, `tests/acme-build.sh --docker`; probe alpine and protoc first (Nikos OKs the first networked build) — [REQ-V070-07]
- [ ] 19 Eval set: `examples/acme-shop/eval/` goals E1 to E5, run procedure, `sandbox.sh`, score-sheet template; the dry run is green — [REQ-V070-08]
- [ ] 20 First eval run, one goal at a time, then `docs/evals/<date>-acme.md` (Nikos OKs the token spend) — [REQ-V070-08]
- [ ] 21 AGENTS.md: a generic resume rule, and the G1 and G5 rows matching the scripts (rule change, Human required) — [REQ-V070-09] [REQ-V070-07]
- [ ] 22 G1 to G5 with `--docker`, deep review, CHANGELOG 0.11.0, overview refresh, release PR with Readiness, retro — [REQ-V070-01] [REQ-V070-02] [REQ-V070-03] [REQ-V070-04] [REQ-V070-05] [REQ-V070-06] [REQ-V070-07] [REQ-V070-08] [REQ-V070-09]
