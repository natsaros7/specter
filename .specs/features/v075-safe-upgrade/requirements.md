# v075 Safe incremental kit upgrades — Requirements

Status: Proposed — awaiting approval
Tracker: none yet (one issue per task once task 1 is ticked). Branch `feat/v075-safe-upgrade`. Size S to M.

## Why

Existing projects installed at 0.4.1 are about to move to 0.11.0, several of them in one sitting. An upgrade today
re-runs `install()`: it deletes and re-copies each kit part and prints one line, `upgrade 0.4.1 -> 0.11.0 (your
settings kept)`. Three things go wrong:

- An edit to a kit file, or a file the project added under a kit part, is deleted without a word. So is an edit to a
  role agent, a skill copy or the Cursor rule that specter wrote: they still carry its marker, so `ours()` says they
  are specter's and `put_file` overwrites them on every run, same version or not.
- Seven releases of "what you must do now" sit in CHANGELOG prose. Some of it breaks things: the Gates table that
  `gates.py` reads, the `### Gates` block format, the review table, repo-root-relative tier globs, the Guardrails rows.
- New `spec-kit.json` keys (`decisions`, `denylist_sha256`, `unresolved_req`, `readme`) and new steering templates
  (`decisions.md`, `autonomy.md`, `lessons.md`) are visible only to someone who reads the scripts.

What upgrading already gets right stays: `spec-kit.json` is never rewritten, marker blocks only, a foreign kit is
refused, `--dry-run` writes nothing, uninstall is byte-exact.

## Requirements

### [REQ-V075-01] No silent loss

- Every install SHALL write `.specs/kit/MANIFEST`: one line per file it wrote (kit files, role agents, skill copies,
  the Cursor rule), with the git blob id of the bytes it wrote and the path from the project root.
- With no manifest (every install up to 0.11.0), the installer SHALL take what the old version shipped from the tag
  `v<old version>` of the specter checkout it runs from. With no such tag either, nothing is known, and each file
  counts as unverified.
- Before it replaces or overwrites a file, the installer SHALL back it up when the file's bytes are neither the
  recorded ones nor the ones it is about to write. That covers an edited kit file, a file added under a kit part,
  an unverified file that differs from the new one, and an edited agent, skill or rule. `VERSION`, `MANIFEST` and
  `__pycache__` are not compared.
- Backups SHALL go to `.specs/kit.bak-<old version>/`: kit files at their path inside the kit, other files under
  `project/<path from the root>`. An existing backup folder is never written into; the next free name (`-2`, `-3`)
  is used. The install then continues and names each file it backed up, and the folder. A run that backs nothing up
  creates no folder.
- `spec_lint.py` SHALL skip `.specs/kit.bak-*/` wherever it skips `.specs/kit/`, including the citation file pool.
  Uninstall SHALL keep the folder and name it.

### [REQ-V075-02] Upgrade report

- On upgrade, and on `--dry-run` of one, the installer SHALL print, in this order:
  - the kit files this run adds, changes and removes, compared with the kit as it sits in the project, one path per
    line;
  - the files it backs up (REQ-V075-01), or `none`;
  - each `spec-kit.json` key that came in after the old version and is missing from the project's config, with its
    default and release. The installer never writes one: a missing key acts as its default, and adding it is the
    opt-in;
  - each steering template in `.specs/kit/templates/steering/` that has no file of the same name in
    `.specs/steering/`;
  - the `action` lines of every release after the old version, up to and including the new one.
- Those lines SHALL come from `kit/docs/upgrading.md`, which ships into projects as `.specs/kit/docs/upgrading.md`.
  It has one `## <version>` block per release, holding `- action: <what an existing project must do>` and
  ``- key: `<name>` = <JSON default>: <what it does>`` lines. Other lines are prose for people.
- `kit/docs/upgrading.md` SHALL have a block for every CHANGELOG release after 0.4.1. This feature writes 0.5.0 to
  0.11.0. A selftest row SHALL fail when a release has no block, and when a `key` line's default differs from the
  default the script uses.
- An old version that does not parse SHALL print every block and say why. A downgrade SHALL print none.

### [REQ-V075-03] Incremental and repeatable

- Upgrading 0.4.1 to 0.11.0 in one run SHALL leave the same project tree, backups aside, as 0.4.1 to an intermediate
  release and then to 0.11.0. The action lines printed across the steps SHALL be the same set as the one run prints.
- A second run at the same version SHALL change no byte and create no backup, and the report SHALL say the kit is
  current.
- `--dry-run` SHALL write nothing (no backup, no manifest). It SHALL print the same report and name the backups it
  would make.
- Uninstall after an upgrade SHALL remove everything it removes today, `MANIFEST` with the kit, and keep the backups.

### [REQ-V075-04] The project's own files are never touched

- In upgrade mode the installer SHALL write nothing under `.specs/features/`, `.specs/domains/`, `.specs/steering/` or
  `.specs/system/`, nor to `.specs/spec-kit.json`. A missing project profile SHALL be reported, not seeded again.
- `AGENTS.md`, `CLAUDE.md`, `GEMINI.md` and `.github/copilot-instructions.md` SHALL keep every byte outside the marker
  block. This already holds; the feature adds the upgrade row that proves it.

## Out of scope

- Migrating project files (rewriting a profile table, adding a config key). Each is an `action` line for the person
  or agent doing the upgrade.
- Merging kit edits into the new kit. The backup is the input to a manual merge.
- Reading the real `v0.4.1` tag in G3: the gates container has no `.git`. Task 7 runs that upgrade by hand.
- The git hook specter owns, and the user-level skill that `--user` writes.
- Installs older than 0.4.1: same code path, not tested.

## Acceptance

Every requirement has its selftest rows in section 15 (design.md), G1 to G4 exit 0, and task 7's hand run upgrades a
real 0.4.1 install, made with the 0.4.1 installer, to the new version with no loss.
