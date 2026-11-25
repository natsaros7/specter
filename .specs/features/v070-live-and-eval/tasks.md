# v070 Live recipe, deep-review follow-ups and the acme eval set — Tasks

Deploy impact: none (specter ships as files from tagged releases). Outside this repo, a public sandbox repository
and a GitHub App are created under Nikos's account for the live test, then archived (tasks 3 to 12).

## ▶ Resume here (2026-11-25)

- **Plan:** pinned issue #68. Tick a batch there when it lands.
- **Where:** branch `feat/0.11.0`. The spec was approved 2026-11-25 with decisions 1 to 9 as recommended (task 1, #46).
- **Landed (batch 1):** task 2 (#47, sandbox kit and workflow template), task 13 (#58, byte cap and LFS), task 16 (#61,
  commit-graph off). G1 to G4 pass in Docker on the tip. The dry-run row P2.2 is PENDING until task 14 lands.
- **Next: batch 2.** Task 14 (#59, human zeros and the checked body), task 17 (#62, the docker copy), task 18 (#63, G5 in
  a container).
- **Waiting on Nikos:** tasks 3 to 5 (#48 to #50; steps in `tests/live/github/README.md`); PRs #44 and #45.
- **Rules:** 2 to 3 agents per batch, worktrees reset to the tip, `PYTHONDONTWRITEBYTECODE=1`, `mktemp` for gate output,
  no polling loops, gates in Docker, land with `cherry-pick` and check its rc, count the task lines, then gates once on
  the tip. Outward-facing steps need Nikos's OK.

- [x] 1 Gate: Nikos approves the spec and decisions 1 to 9, recorded on the plan issue (Nikos) (#46) — [REQ-V070-01] [REQ-V070-02] [REQ-V070-03] [REQ-V070-04] [REQ-V070-05] [REQ-V070-06] [REQ-V070-07] [REQ-V070-08] [REQ-V070-09]
- [x] 2 Sandbox kit: `tests/live/github/` (checklist, `sandbox.sh` seed/dry-run/open, sandbox workflows), the `specter-auto-merge.yml` template, a 14b grep row; the local dry run passes (#47) — [REQ-V070-01]
- [ ] 3 Create the public sandbox repository and its settings, with the interaction limit (Nikos) (#48) — [REQ-V070-01]
- [ ] 4 Create the GitHub App and install it on the sandbox only (Nikos) (#49) — [REQ-V070-01]
- [ ] 5 Environment `specter-approver` (deployment branch `main` only), App id variable and key secret (Nikos) (#50) — [REQ-V070-01]
- [ ] 6 After batch 3: seed the sandbox from the `feat/0.11.0` tip and push `main` with its workflows (Nikos) (#51) — [REQ-V070-01]
- [ ] 7 Ruleset on `main`: PR, 1 approval, stale dismissed, required `gates`, up to date, no bypass (Nikos) (#52) — [REQ-V070-01]
- [ ] 8 Scenarios K1, N1, N2, N3: nothing merges; the key is unreachable (Nikos opens, the agent observes) (#53) — [REQ-V070-01]
- [ ] 9 Scenarios P1, N4, N5, N6, P2: only P1 and P2 merge, P2 with the checked body (Nikos opens, the agent observes) (#54) — [REQ-V070-01] [REQ-V070-03]
- [ ] 10 Write `docs/reviews/<date>-live-recipe.md` from the observations (#55) — [REQ-V070-01]
- [ ] 11 Pass: lift the CHANGELOG limit, mark step 5 and the template Verified; fail: correct the recipe and rerun only the failing rows (Human required) (#56) — [REQ-V070-01]
- [ ] 12 Teardown: delete the App key, uninstall the App, delete the environment, disable Actions, archive (Nikos) (#57) — [REQ-V070-01]
- [x] 13 Byte cap (`Max bytes`, default 4000) and LFS pointers in `small()`, red rows in 13c2 `t70b` (security) (#58) — [REQ-V070-02]
- [ ] 14 `ready.py` refuses `Human-Findings:` in the PR text or range commits; the job merges with the checked body; drop the 0.10.0 zero-drop (security) (#59) — [REQ-V070-03]
- [ ] 15 Key evidence by the Tiers rows from the tier down plus Knowledge globs; the finding-5 probe in 13c3 `t13e25` (security) (#60) — [REQ-V070-04]
- [x] 16 `core.commitGraph=false` at the `tiers` import; probe a forged commit-graph first, row `t13e26` (security) (#61) — [REQ-V070-05]
- [ ] 17 `tests/gates.sh --docker` copies only `git ls-files --cached --others --exclude-standard` (#62) — [REQ-V070-06]
- [ ] 18 G5 in a container: `scripts/mvnw-docker.sh`, `tests/acme-build.sh --docker`; probe alpine and protoc first (Nikos OKs the first networked build) (#63) — [REQ-V070-07]
- [ ] 19 Eval set: `examples/acme-shop/eval/` goals E1 to E5, run procedure, `sandbox.sh`, score-sheet template; the dry run is green (#64) — [REQ-V070-08]
- [ ] 20 First eval run, one goal at a time, then `docs/evals/<date>-acme.md` (Nikos OKs the token spend) (#65) — [REQ-V070-08]
- [ ] 21 AGENTS.md: a generic resume rule, and the G1 and G5 rows matching the scripts (rule change, Human required) (#66) — [REQ-V070-09] [REQ-V070-07]
- [ ] 22 G1 to G5 with `--docker`, deep review, CHANGELOG 0.11.0, overview refresh, release PR with Readiness, retro (#67) — [REQ-V070-01] [REQ-V070-02] [REQ-V070-03] [REQ-V070-04] [REQ-V070-05] [REQ-V070-06] [REQ-V070-07] [REQ-V070-08] [REQ-V070-09]
