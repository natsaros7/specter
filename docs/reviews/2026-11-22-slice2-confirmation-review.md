# Confirmation review 3: specter 0.7.0, fix commit `c37a41c`

Deep tier, security first. HEAD = `c37a41c` on `feat/0.7.0`. Line numbers are at HEAD.
Scratch: `/private/tmp/claude-502/-Users-nikolaos-atsaros-Developer-projects/9b14f693-fb68-4017-8c4d-7666b85ba497/scratchpad/review-070-r3/`
(`kit/` = `git archive HEAD`, `setup.sh DIR` = the review-2 fixture: acme profile, G1 `grep -q ok shop/security/Auth.java || exit 1`,
G2 `echo two`). `t1` = F1-F3, F6, F7. `t4` = doc commands. `t5` = F5. No tracked file was changed. The uncommitted
`CHANGELOG.md` draft was left alone. Temporary `/tmp/specter-base`, `/tmp/pr.md` were made by the doc commands and removed.

Gates re-run by me at HEAD: G1 exit 0; G2 `0 FAIL of 7 citation(s)`; G3 `selftest: OK`; G4 `0 FAIL across 7 feature(s)`,
`0 FAIL of 72 citation(s)`. Afterwards `git status --short` shows only ` M CHANGELOG.md`.

What this change does: one key (NFKC, `upper().casefold()`, U+0307 removed) now compares every path and glob in
tiers.py: guarded globs, Tiers rows and `--check`. ready.py needs the head's Gates table to equal the base's. gates.py
reads the commit after the run and adds `- tree changed during gates` when the run changed the tree. Staged mode reads
`merged_ref` from HEAD's `spec-kit.json` and falls back to the last tier when there is no merge base. A blocker
with a Location it cannot read is now not ready. The docs give trusted-copy commands for both modes.

## 1. F1-F7 at HEAD

| Row | Status | Evidence (at HEAD) |
|---|---|---|
| F1 `ſ`/`ﬆ`/`ı` fold on APFS | **CLOSED** | `t1`, `merged_ref: "main"`, each file staged alone: `AGENTſ.md` → `critical`, `set by: AGENTſ.md (AGENTS*.md)`. `.ſpecs/steering/autonomy.md`, `.specs/ſteering/x.md`, `.specs/ﬆeering/x.md` → `critical (.specs/steering/*)`. `.clınerules` → `critical (.clinerules)`. Control `docs/x.md` → `routine (docs/*)` |
| F2 case in a profile row | **CLOSED** | `shop/src/main/java/com/acme/shop/Security/Bypass.java` → `critical (*/security/*)` (it was `domain`). `…/ſecurity/B.java` → `critical`. Control `…/shop/Foo.java` → `domain` |
| F3 prepended gate / duplicate label | **CLOSED** | Branch `pre` prepends `G0 Format` (rewrites `Auth.java`) and commits `bad`. Honest `gates.py` now prints `- tree changed during gates` and `commit: 1a991b9+dirty`. ready `--range main...pre`: `not ready` with three reasons, among them `Gates table changed in this change: goes to the human`, exit 1. A liar who deletes the two lines from the block is still caught by table equality. Duplicate `G1` row: `not ready` (`appears 2 times`, `Gates table changed`). Honest PR with the base table: `ready`, exit 0 |
| F4 trusted-copy docs | **CLOSED** | Ran `kit/docs/review-loop.md` steps 3 and 5 word for word in `t4` (branch `feat`, change staged, `main` checked out in the main worktree): `git worktree add --detach /tmp/specter-base main` works. Staged `ready.py --specs .specs --pr /tmp/pr.md` → `ready`. After `git commit` and a new gates run: `tiers.py --range main...HEAD` → `routine`, `base: 4e016d6 (merge base of main...HEAD)`. `ready.py --range main...HEAD --pr /tmp/pr.md` → `ready`, exit 0. `git worktree remove` exits 0 and leaves no files. The first-upgrade form (`python3 <specter>/kit/scripts/ready.py --specs .specs --range …`) works and writes no `__pycache__`. No doc still runs the in-tree `tiers.py`/`ready.py` for labels or the verdict (grep finds only `--check`) |
| F5 staged base steered by the work tree | **CLOSED** (one shortcut, stated in the docs) | `t5`: (a) default install (`merged_ref: null`, no origin) → every file takes the last tier, `base: HEAD (no merge base: last tier)`. (c) unstaged `"merged_ref": "feat3"` → ignored, `critical`, `base: a0e899c (merge base with main)`. A branch commit that edits `autonomy.md` (routine `*`) and `spec-kit.json` → `critical`, `set by: .specs/spec-kit.json`. Bad JSON or `merged_ref: 5` at HEAD → exit 2. Left open: a committed `merged_ref: "feat3"` (the branch names itself) → `routine`. The block shows it (`base: 4d12e9f (merge base with feat3)`), and `--range main...HEAD` → `critical`. This is the `shortcut:` in `tiers.py:179` and in the design, and the CHANGELOG lists it under Known limits. Fine for labels-only |
| F6 non-empty Location demoted | **CLOSED** | Each of `p:1,7`, `p:1, 7`, `` `p`:1 ``, `p:L1`, `p (line 1)`, `my file.java:3`, `p`, `n/a`, `-` → `not ready: blocker location unreadable: …`. `p:1–3` and `p:1` → `open blocker`. An empty cell → advisory warning, `ready` (as specified) |
| F7 guarded gaps | **CLOSED** | `AGENTS.override.md`, `sub/AGENTS.override.md`, `CLAUDE.local.md`, `pkg/.claude/skills/x/SKILL.md` → `critical` |

Also checked: ready `--range` with a bad `spec-kit.json` now exits 2 (`ready: cannot read …`). The template `autonomy.md`
with its new `<!-- … -->` line above the Tiers table passes `tiers.py --check`.

## 2. Attacks on c37a41c

**Over-fold (a fold key wider than the filesystem).** The key folds more than APFS does. I checked on this Mac (APFS):
`AGENTſ.md` opens `AGENTS.md`, but `ＡGENTS.md` (full-width) and `AGEN‌TS.md` (zero-width) are different files.
NFKC folds full-width forms, so the key folds more than APFS. On Linux it folds case too, and Linux keeps case.
- *Does over-folding move a file to a lower tier wrongly?* Yes, but only a file that no glob matches as spelled (that file
  would take the last row). `Docs/release.sh`, `ＤＯＣＳ/release.sh` → `routine (docs/*)`. `shop/src/TEST/x.sh` →
  `routine (*/src/test/*)`. At `2aeb464` the first and third were `critical (no glob matched)`. **Is it a real hole?**
  Only in a narrow case. On Linux, or with a full-width name on APFS, the folded path is a different file from the one
  the glob names. A new file there has no more power than a file the author could add under the real routine path.
  The hole needs an existing file, outside every glob, that something runs by its exact spelling (for example a
  case-sensitive repo where CI calls `Docs/release.sh`). Rated MINOR (finding 1).
- *The design says "folding only adds matches". That is false.* NFKC joins a combining mark with the letter before it, so a
  glob letter followed by `*` can lose a match. `AGENTŚ.md` (shown as `AGENTŚ.md`) → `routine (*.md)`, because
  `AGENTS*.md` stops matching. `mvnẁ` no longer matches `mvnw*`. Both are inert names: APFS keeps `Ś` apart from
  `S`, so no agent and no build reads them. A name glob such as `*Auth*` loses `AutḣService.java`, but an attacker can
  pick any other name anyway. NIT (finding 2).

**Exact Gates-table equality.** It holds: prepended rows, duplicate labels and changed commands are all `not ready`.
Reformatting the table (spacing, `\|`) compares equal, because `gate_rows` parses each row into (label, command).
An honest PR that changes a gate is never `ready` and gets `Gates table changed in this change: goes to the human`. The
ready.py docstring, the design (`:231`) and the CHANGELOG draft say so. `kit/docs/review-loop.md` step 5 and
`docs/reference.md` do not, so the reader of the loop does not learn what to do (finding 3).

**gates.py tree check.** `tree()` = `git status --porcelain` + `git diff HEAD`. An untracked file that a gate writes
makes the tree look changed, and ready says not ready. This is stated in three places: the gates.py docstring, ready's
message `(gitignore gate output)`, and the CHANGELOG Breaking entry ("gitignore gate output"). The new content of an
untracked file is not compared: that is a `shortcut:` at `gates.py:63-64`. A gate that **commits** leaves the status and
the diff unchanged, so the check misses it (finding 4, MINOR). The Gates table is now trusted from the base, so neither
case is a bypass. A test that runs during a gate can do anything, and the docs say `ready` does not prove the gates ran.

**merged_ref read at HEAD.** Verified (F5 row). A branch commit that edits `spec-kit.json` is in
`git diff --cached <merge base>` and is guarded → `critical`. The self-naming case is the stated shortcut.

**Unreadable-location rule.** Verified (F6 row). `-` and `n/a` in a blocker's Location are now not ready. They were
advisory before, and that fails closed. The CHANGELOG Breaking entry says so.

**Trusted-copy commands.** All run as written (F4 row). The staged preflight in a repo with no `merged_ref` and no
`origin/HEAD` labels everything with the last tier, and the human sees why. Nothing tells the user that `merged_ref`
now matters for this (finding 5).

## 3. Findings

No BLOCKER or MAJOR.

| severity | file:line | issue | fix |
|---|---|---|---|
| MINOR | `kit/scripts/tiers.py:129-132` | Over-fold moves a file that matches no glob as spelled from the last row to a lower one. `Docs/release.sh` / `ＤＯＣＳ/release.sh` → `routine (docs/*)`. It was `critical (no glob matched)` at `2aeb464`. A real hole only when an existing file at such a path does something (a case-sensitive repo) | Accept it: add `shortcut: the key folds more than APFS (NFKC) and Linux (case), so an unmatched case- or width-variant path can take a lower row; upgrade if a profile relies on the last row for such a path` next to `key()`. Or drop the fold for row globs and keep it for guarded globs. That brings F2 back, so do not do it |
| NIT | `kit/scripts/tiers.py:122-126`, design `:134` | The claim "folding only adds matches" is false. A combining mark right after a glob letter that is followed by `*` composes, so `AGENTŚ.md` loses `AGENTS*.md` → `routine (*.md)`, and `mvnẁ` loses `mvnw*`. Both are inert names on APFS | One line makes the claim true: `fnmatch.fnmatchcase(path, g) or fnmatch.fnmatchcase(k, key(g))` in `hit()` |
| MINOR | `kit/docs/review-loop.md:55-58`, `docs/reference.md:143-148` | A PR that changes the Gates table is never `ready`. The loop and the reference do not say this, or what the human does then: read the new gates, run them, merge on their own check. Only the docstring, the design and the uncommitted CHANGELOG say it | One sentence in step 5: "A change to the Gates table is never `ready` (`Gates table changed…`): the human reviews the new gates, runs them, and merges on their own check; the next PR is checked against the new table" |
| MINOR | `kit/scripts/gates.py:62-66` | `tree()` does not include HEAD. A gate that commits (for example a bump or format script that commits its result) leaves the status and the diff unchanged. The block then names the new commit, but earlier gates checked the old one | Add `run("rev-parse", "HEAD")` to the returned bytes. One line |
| MINOR | `docs/reference.md:89`, `kit/docs/review-loop.md:27-32` | `merged_ref` is documented only for tracker detection. It now sets the staged-tier base. With it unset and no `origin/HEAD` (a local-only repo), every staged preflight is the last tier, so the step-3 lead label always says `reviewer: deep` | Add to the `merged_ref` row: "also the base of `tiers.py`/`ready.py` staged mode; unset with no `origin/HEAD`, staged labels take the last tier". Ask for `merged_ref` in setup Q10 |
| MINOR | `kit/scripts/tiers.py:47-51` | `.clinerules` is guarded as a file, but Cline also reads a `.clinerules/` folder (review 1 asked for `.clinerules/*`): `.clinerules/evil.md` → `routine (*.md)`. Not wired by `install.AGENTS`, and the hand-kept list has a `shortcut:` | Add `.clinerules/*` |
| NIT | `kit/scripts/tiers.py:239` | In fail-closed mode the line reads `set by: docs/a.md (no glob matched)`, although `docs/*` matches. The `base:` line gives the real reason | Print `(no merge base: last tier)` when `closed` |
| NIT | release | `VERSION` at HEAD is `0.6.5`, and the 0.7.0 CHANGELOG is not committed | Bump `VERSION` and commit the CHANGELOG before the tag |

Not findings (checked): `merged_ref` option strings fail closed (`merge-base` errors, last tier). APFS does not fold
zero-width characters or full-width forms, so the key misses no fold that APFS makes (NTFS `ı` was reasoned, not run).
A staged-mode gates run uses the work-tree table while ready compares the index. Staged mode is a preflight, and
"`+dirty` binds no content" is documented.

## Verdict

**Ship 0.7.0: yes.** F1-F7 are closed, with evidence above, and I found no new BLOCKER or MAJOR. Before the tag: commit
the CHANGELOG, bump `VERSION`, and add the step-5 sentence on Gates-table changes (finding 3). The other MINORs can wait
for 0.7.1.

Not checked: Windows/NTFS (the upcase table is reasoned, not run); CI on shallow clones (no merge base gives the last
tier, which fails closed); Linux case-sensitive behaviour (reasoned from `fnmatchcase` on the folded key).
