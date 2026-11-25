# v075 Safe incremental kit upgrades — Design

Stdlib only, Python 3.8+, offline, no new dependency, no new flag. All of it lives in `kit/scripts/install.py`, plus a
skip rule in `spec_lint.py` and one new kit doc. One task per dispatch, red first: add the selftest rows, run
`SELFTEST_ONLY="15" sh tests/selftest.sh` and see them fail for the stated reason, then fix, then G1 to G4
(AGENTS.md). Never cite a line number in backticks in a spec; name the function.

## Decisions

Approving task 1 accepts each row's recommendation, unless Nikos amends it.

| # | Question | Recommendation | Trade-off |
|---|---|---|---|
| 1 | How the installer knows a file was edited | **A manifest, then the old tag.** Each install writes `.specs/kit/MANIFEST` (git blob id and root-relative path per file written). With no manifest, one `git -C <kit_home> ls-tree -r v<old>` gives what that release shipped; a stdlib blob hash compares it with no call per file. With no tag, each file counts as unverified | Tag only: a tarball install, or one made from `main` between releases (its VERSION names the last tag but its bytes are newer), gets false "edited" hits; that is noise, not loss, but every upgrade would be noisy. Manifest only: nothing installed up to 0.11.0 has one, so each first upgrade would back up the whole kit and hide the one file the project edited. Cost: one file in the kit and one git call per upgrade |
| 2 | Refuse or back up | **Back up and continue.** The rule: keep a file when its bytes are neither the recorded ones nor the new ones, so nothing that is lost could not be rebuilt from a release | Refusing stalls an upgrade of several repos on the first edited file, needs a `--force` flag, and leaves the hand-copying to the user, which is where files get lost. A backup that nobody reads is the cost; the report names it on every run that makes one |
| 3 | Where backups go | **`.specs/kit.bak-<old>/`**, next to the kit, so `diff -r .specs/kit.bak-0.4.1 .specs/kit` shows the edit and the agent doing the upgrade sees it. The lint skips it like `kit/`. Not gitignored: the user decides whether to commit it | Outside the project (under `~`): no lint change, but invisible to the team and to the agent, and lost on another machine. At the project root: the same lint and citation-pool exposure, plus a new top-level folder |
| 4 | Where the per-release notes live | **`kit/docs/upgrading.md`**, so it ships into `.specs/kit/docs/` and an agent can re-read the actions after the run. Machine-read lines are `- action:` and `- key:`; the rest is prose | Parsing CHANGELOG: it is prose, mixes "must do" with "nice to know", and would print hundreds of lines. A JSON file: no person reads it in the kit docs |
| 5 | New config keys | **Listed, never written.** A missing key already acts as the script's default (`spec_lint.DEFAULTS`, `readme_check.DEFAULTS`), so the report is enough | Writing defaults would break "an existing config is never rewritten" and the `untouched_seed()` comparison that uninstall relies on |
| 6 | A missing profile in upgrade mode | **Reported, not seeded.** Upgrade mode writes nothing under `.specs/steering/` | Seeding brings back `status: setup-incomplete`, which makes the lint and agents think setup never ran. Cost: a user who deleted the profile has to run setup on purpose |
| 7 | Stepping through releases | **No migration code.** The kit is replaced whole and the config is never touched, so one step and many steps end equal by construction; the notes are the union of a version range. The selftest proves it | Per-release migration scripts would be needed only if a release rewrote project files, and none does |
| 8 | Old-version fixtures | **Built inside the selftest:** a throwaway specter checkout, tagged `v0.4.1`, whose kit drops the files added after 0.4.1. The gates container has no `.git`, so G3 cannot read the real tag | The fixture models 0.4.1's shape, not its bytes. Task 7 upgrades a real 0.4.1 install by hand before the release |

## The report, for a 0.4.1 project

Printed after the existing `upgrade <old> -> <new>` line, in upgrade mode and in its `--dry-run`. Paths are inside
`.specs/kit/` unless they start with `project/`.

```text
  upgrade 0.4.1 -> 0.11.0 (your settings kept)
  kit files: 14 added, 12 changed, 0 removed
    + scripts/tiers.py
    ~ playbooks/sync.md
    …
  backed up to .specs/kit.bak-0.4.1/ (yours, not in 0.4.1 or 0.11.0): playbooks/setup.md, project/.claude/agents/reviewer.md
  spec-kit.json keys you can add (missing = the default; never written for you):
    decisions = {} (0.5.0): enabled (true) and backlinks (false, "warn", true) for the decisions log checks
    …
  steering templates not in .specs/steering/: autonomy.md, decisions.md, lessons.md (copy from .specs/kit/templates/steering/)
  action needed (from .specs/kit/docs/upgrading.md):
    0.5.0: gates.py reads a | # | Gate | Command | table in .specs/steering/spec-rules.md …
    …
```

A re-run prints `kit 0.11.0 is current: nothing to change` and nothing else of the report. A run with no backup prints
`backed up: none`.

## `kit/docs/upgrading.md`, as written by task 3

Newest first. Each block holds only what an existing project acts on.

- **0.11.0:** no `action`. Prose: the optional `Max bytes` Evidence column, the `specter-auto-merge.yml` template.
- **0.10.0:**
  - `action:` if a tier in `.specs/steering/autonomy.md` is Human `none`, re-read review-loop step 5 (an App approver,
    approval bound to the head sha, the size cap and `complexity: trivial`) before relying on it.
  - `action:` a public repository with no `SECURITY.md`: copy `.specs/kit/templates/SECURITY.md` to the root.
  - ``key: `readme` = {"path": "README.md", "max_lines": 200, "sections": [], "deny": []}``: settings for
    `readme_check.py`.
- **0.9.0:**
  - `action:` if `autonomy.md` has a Guardrails section, rows three and six were reworded: update both, check the
    platform does what they say, re-date them.
  - `action:` the `### Review` block carries `rounds: <n>`; `ready.py` warns when it is missing.
- **0.8.0:**
  - `action:` if `autonomy.md` exists, add the `## Guardrails` and `## Evidence` sections from the template: without
    Guardrails every `none` tier is labelled `spot`.
  - `action:` write `Human-Findings: <n>` on every merge and `Fixes: <sha>` on an escaped-defect fix (`sync.md`).
- **0.7.0:**
  - `action:` the `### Gates` block from `gates.py` changed (`pass (…)`, `FAIL (exit N)`, `not run`, a verdict line):
    change any script that greps it, and gitignore gate output.
  - `action:` the review table is `| Severity | Location | Evidence | Trigger | Consequence | Fix |` with `blocker` or
    `advisory` only.
  - `action:` Tiers and guarded globs are relative to the repository root: a profile under a subfolder's `.specs/` adds
    the subfolder prefix.
  - `action:` set `merged_ref` in `spec-kit.json` for `tiers.py` and `ready.py`; the first run after this upgrade runs
    them from the specter checkout, since the base has no kit yet.
  - `action:` delete any committed `__pycache__` under `.specs/kit/`.
- **0.6.5:** no `action` (the kit did not change).
- **0.6.0:** no `action`. Prose: `autonomy.md` and `lessons.md` are optional; without `autonomy.md` nothing changes.
- **0.5.0:**
  - `action:` `gates.py` reads a `| # | Gate | Command |` table in `.specs/steering/spec-rules.md` (Definition of
    Done). A 0.4.1 spec-rules has a one-line gate: move the commands into that table, as in
    `.specs/kit/templates/steering/spec-rules.md`, or `gates.py` exits 2.
  - `action:` add a `Deploy impact:` line to open tasks, and record how CI/CD consumes the repository (setup Q9) in the
    profile.
  - `action:` optional: setup can generate `.specs/ONBOARDING.md` from `.specs/kit/templates/ONBOARDING.md`.
  - ``key: `decisions` = {}``: `enabled` (true) and `backlinks` (false, "warn", true) for the decisions log checks.
  - ``key: `denylist_sha256` = []``: digests of names kept out of shared specs (`spec_lint.py --hash-term`).
  - ``key: `unresolved_req` = "warn"``: `"off"` silences the WARN for a REQ cited outside a feature and defined
    nowhere.

## Selftest section 15

New sections after 14b: `15`, `15b` and `15c`, with `15b:15 15c:15` in `DEPS`. They share one helper:

```sh
# kh <version> [kit paths to drop...]: commit this repo's install.sh, VERSION and kit/ into the fake specter checkout
# $KH with VERSION <version> and the listed paths removed, and tag it v<version>
```

`OLD` names the paths 0.4.1 did not ship: `scripts/tiers.py`, `scripts/ready.py`, `scripts/gates.py`,
`scripts/readme_check.py`, `templates/steering/autonomy.md`, `templates/steering/decisions.md`,
`templates/steering/lessons.md`, `templates/SECURITY.md`, `templates/ONBOARDING.md`, `templates/github`,
`docs/chores.md`, `docs/pipeline.md`, `docs/upgrading.md`, `playbooks/parallel.md`. The 0.4.1 commit also appends a
line to `playbooks/sync.md`, so the upgrade has a changed file. A project installed from `$KH` at `v0.4.1`, with its
`MANIFEST` deleted, is a 0.4.1 install.

## [REQ-V075-01] No silent loss

### Task 2: manifest, tag fallback, backups

- **Touches:** `install.py`: `install()`, `install_skill()`, `uninstall()`, the `put_file` calls for agents and the
  Cursor rule; new `blob_id()`, `recorded()`, `back_up()`. `spec_lint.py`: the four `rglob` walks that skip `kit`, and
  the file pool in `cites()`. `tests/selftest.sh` section 15 and the `kh` helper.
- **Red rows (15):**
  - (a) A pristine 0.4.1 install (no manifest, `$KH` tagged): the upgrade makes no `.specs/kit.bak-*` folder.
  - (b) The same with `playbooks/setup.md` edited, `scripts/mine.py` added under the kit and the project's
    `.claude/agents/reviewer.md` edited: `.specs/kit.bak-0.4.1/` holds the three files byte for byte (the agent under
    `project/.claude/agents/`) and nothing else; the output names each.
  - (c) No manifest and no tag (`$KH` copied without `.git`), with the same edit: the backup holds every file that
    differs from the new kit, the edited one among them, and the output says `could not verify`.
  - (d) A current install with an edited kit file, re-run at the same version: `.specs/kit.bak-<version>/` holds it.
    Run again after editing once more: a second folder `-2`; the first is unchanged.
  - (e) A backed-up `.md` holding a broken link and a `D-9` id: `spec_lint.py` on the project gives the same exit and
    output as before the upgrade.
  - (f) Uninstall after (b): `.specs/kit.bak-0.4.1/` is kept, and the output names it under `Kept`.
- **Fix:** `blob_id(data)` is git's blob hash (sha1 of `blob <len>\0` plus the bytes). `recorded()` returns
  `{path: blob id}` from `MANIFEST`. A missing or unreadable manifest falls back to `ls-tree -r -z v<old> --` on the
  `KIT_PARTS`, mapping `kit/<x>` to `.specs/kit/<x>` and dropping `install.py`. A failed git call returns `None`
  (unverified). Before the part loop, walk the old kit; for each file outside the skip list, back it up when its blob is
  not the recorded one and not the new source's. Each `put_file` over an existing owned agent, skill or rule does the
  same check against the new text. `back_up()` copies through `write()`, so a dry run prints `back up <path>` and
  writes nothing. `MANIFEST` is written last, from the bytes on disk, sorted, skipped in a dry run. Uninstall prints
  each `.specs/kit.bak-*` under `Kept`. In `spec_lint.py`, one predicate (first part `kit`, or `kit.bak-` followed by
  anything) replaces the four inline checks, and the pool drops `.specs/kit.bak-*/` paths.
- **Check:** `SELFTEST_ONLY="15" sh tests/selftest.sh`, then `sh tests/gates.sh --docker`.

## [REQ-V075-02] Upgrade report

### Task 3: `kit/docs/upgrading.md` and its drift rows

- **Touches:** new `kit/docs/upgrading.md` (content above, with a short header saying how to read it); section 15b.
- **Red rows (15b):**
  - (a) Every `## [x.y.z]` in `CHANGELOG.md` above 0.4.1 has a `## x.y.z` block in `kit/docs/upgrading.md`. Fails
    today: the file does not exist.
  - (b) Every `key` line's JSON default equals the script's: `decisions`, `denylist_sha256` and `unresolved_req`
    against `spec_lint.DEFAULTS`, `readme` against `readme_check.DEFAULTS` (one `python3 -c` that imports both).
- **Fix:** write the file. No code.
- **Check:** `SELFTEST_ONLY="15b" sh tests/selftest.sh`; G2 and G4 untouched.

### Task 4: the report

- **Touches:** `install()` (its `old_version` branch), new `upgrade_report()` and `notes()`; section 15b.
- **Red rows (15b, on the 0.4.1 fixture):**
  - (c) The upgrade prints `+ scripts/tiers.py`, `~ playbooks/sync.md` and a `kit files:` count line.
  - (d) It prints a header for each release 0.5.0 to 0.11.0 that has an `action` line, and none for 0.4.1 or earlier.
  - (e) It lists `decisions`, `denylist_sha256` and `readme` with their defaults. With `"unresolved_req": "off"` in the
    project's config, `unresolved_req` is not listed; `spec-kit.json` is byte-identical afterwards.
  - (f) It lists `autonomy.md`, `decisions.md` and `lessons.md` as missing templates, and not `spec-rules.md`.
  - (g) The `--dry-run` output carries the same report lines.
  - (h) `0.0.x` as the old version prints every block. A `VERSION` above the new one prints no `action` line.
- **Fix:** `notes(text, old, new)` parses `## <version>` headings and their `- action:` and `- key:` lines, and keeps
  the blocks with `old < v <= new`, compared as integer tuples. An old version that does not parse keeps every block
  and says so. `upgrade_report()` compares the old kit on disk with the new source by blob id, and the steering
  templates by name. It prints through `say(..., True)`, so the dry run shows it too.
- **Check:** `SELFTEST_ONLY="15b" sh tests/selftest.sh`, then the gates.

## [REQ-V075-03] Incremental and repeatable · [REQ-V075-04] Untouched project files

### Task 5: repeatability and protected paths

- **Touches:** `install()`: the profile seed is skipped in upgrade mode and reported instead. Section 15c.
- **Red rows (15c):**
  - (a) One step vs stepped: project A goes from `v0.4.1` to the current kit; project B goes from `v0.4.1` to a
    `v0.7.0` commit of `$KH` (the 0.4.1 shape with `gates.py`, `tiers.py` and `ready.py` back), then to the current
    kit. The `.specs/` trees and `AGENTS.md` are byte-equal, and the sorted `action` lines of B's two runs equal A's.
  - (b) A second run after (a) changes no byte (a tree hash like section 2's `snap`), makes no backup, and prints
    `is current`.
  - (c) A dry run of the 0.4.1 upgrade leaves the tree hash unchanged: no backup, no `MANIFEST`.
  - (d) A 0.4.1 project with features, domains, steering, system, a `spec-kit.json` and text around the marker block
    in `AGENTS.md` and `CLAUDE.md`: after the upgrade each of those files hashes the same, and the marker blocks
    hold the new rules.
  - (e) The same project with its profile deleted: the upgrade does not create one and prints that it is missing.
    Fails today: `install()` seeds it.
  - (f) Uninstall after (a): the section 6 checks hold, and `.specs/kit/MANIFEST` is gone with the kit.
- **Fix:** only (e) needs code; the other rows pin behaviour that tasks 2 and 4 must keep. If a row fails, fix the
  installer, never the row.
- **Check:** `SELFTEST_ONLY="15c" sh tests/selftest.sh`, then the full gates.

## Docs and release

### Task 6: docs

- **Touches:** `docs/reference.md` "Upgrade, uninstall, versions" (manifest, the backup rule and folder, the report,
  `upgrading.md`, run `--dry-run` first), `GO.md` step 2's upgrade line (show the dry-run report, run the upgrade, then
  walk the `action` lines and any backup with the user), the `install.sh` usage comment for `--dry-run`, `CHANGELOG.md`
  under Unreleased.
- **Red rows:** none (prose). G4's `readme_check.py` covers the README if it changes.
- **Check:** G4.

### Task 7: gates, hand run, review

- **Hand run (decision 8):** `git worktree add --detach "$TMPDIR/s041" v0.4.1`, install it into a scratch git repo
  with `"$TMPDIR/s041/install.sh"`, edit one kit file, then run this branch's `install.sh --dry-run` and the upgrade.
  Paste both outputs, and `diff -r` of the backup against the edit, into the PR's `### Verification`.
- **Then:** `sh tests/gates.sh --docker`, rc per gate; a fresh-context review on the tier `tiers.py` gives
  (`install.sh` and `kit/scripts/` are on the `trust` tier: deep reviewer, Human `required`); the PR carries the
  Gates, Review and Verification blocks.
