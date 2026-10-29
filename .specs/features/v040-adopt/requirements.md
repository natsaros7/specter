# v040 Adopt existing spec systems without breaking them — Requirements

Status: Done 2026-10-29 (v0.4.0)
Tracker: none. Branch `feat/0.4.0`. Size M.

## Why

Verified on `main` after 0.3.0 (2026-10-28):

- `kit/scripts/install.py` assumes a fresh project:
  - it seeds `steering/project-profile.md` as `setup-incomplete`, and `kit/AGENT_RULES.md` then tells agents to do
    nothing spec-related until setup runs;
  - it writes project-level `.claude/agents/{planner,generator,reviewer}.md`, which shadow same-named user-level
    agents in `~/.claude/agents/`;
  - it deletes and recopies `.specs/kit/` without checking that specter put it there.
- A survey of 9 projects that already run a spec system (2026-10-28) found:
  - none has a project profile, so all 9 would be switched off;
  - every one that uses Claude Code has user-level role agents with model pins;
  - 4 fail the structural lint, mostly in finished features (untraced REQs, a missing `design.md`). Under the
    "lint must exit 0" rule, agents would start rewriting history.
- There is no way to see what the installer will touch before it touches it.

## User story

As someone with working spec systems in several repos, I want to adopt specter in each without losing or changing
anything that already works, and to see the exact change list before anything is written.

## Requirements

### [REQ-V040-01] Adopt mode

- The installer SHALL detect an existing spec system: `.specs/` already holds a `features/`, `domains/`, `system/` or
  `steering/` folder, and `.specs/kit/VERSION` doesn't exist. It SHALL then run in adopt mode and say so.
- In adopt mode, a missing profile SHALL be seeded with `status: active` and an `adopted: <YYYY-MM-DD>, existing spec
  system kept; setup interview not run` line, never with `setup-incomplete`.
- In adopt mode the installer SHALL NOT create or overwrite any file under `.specs/` except `.specs/kit/`,
  `.specs/spec-kit.json` (only when absent), `.specs/.gitignore` (append-only) and the seeded profile.
- `--fresh` SHALL force the old behaviour.
- In adopt mode the installer SHALL NOT install a git hook unless `--hook` is given. It SHALL print how to enable
  it. Adopting never changes how commits behave.
- An existing `.specs/spec-kit.json` SHALL never be rewritten, in any mode. The installed version lives in
  `.specs/kit/VERSION`, and `kit_version` is written only into a config the installer creates.
- With `--from-go`, adopt mode SHALL print that the setup interview is skipped and point to the README section.
  `GO.md` SHALL have an adopt branch: run `--dry-run` first, show it, install on yes, and skip the setup step.

### [REQ-V040-02] Never shadow or overwrite what the user owns

The installer SHALL NOT write `.claude/agents/<role>.md` when `~/.claude/agents/<role>.md` exists. It SHALL print
`user-level <role> agent found: kept yours, project copy skipped`. This applies in every mode. The installer SHALL replace an existing
`spec-first` skill folder, Cursor rule or project role agent only when specter wrote it, that is when it carries
specter's marker. Otherwise it SHALL keep the file and print `<path> exists and is yours: kept it`. Summary lines list
only what was actually written.

### [REQ-V040-03] Never delete a foreign kit

The installer SHALL replace `.specs/kit/` only when it is specter's: `.specs/kit/VERSION` exists AND
`.specs/kit/AGENT_RULES.md` contains the specter marker. Otherwise, if `.specs/kit/` exists,
it SHALL stop with exit 2 and `.specs/kit/ exists and isn't specter's: move it, then re-run`.

### [REQ-V040-08] Uninstall is as careful as install

`--uninstall` SHALL apply the same ownership rules:
- it removes `.specs/kit/` only if it is specter's;
- it removes the skill, Cursor rule and agents only if specter wrote them;
- it removes marker blocks preserving the remaining bytes, line endings included;
- it removes only the `.gitignore` lines specter added, which install marks with a `# specter` comment line.

### [REQ-V040-04] Dry run

- `--dry-run` SHALL print every path it would create, modify (marker block, append) or replace, each marked
  `create`, `modify` or `replace`, and SHALL write nothing, with exit 0.
- It SHALL print the detected mode (fresh, adopt or upgrade).

### [REQ-V040-05] History is not linted structurally

- Features whose status is `Done` or `Dropped` (the `Status:` field from 0.3.0) are history. Their structural FAILs SHALL be reported as
  WARN `history: <message>`, and SHALL NOT count toward the exit code.
- Broken links and citations still FAIL everywhere.

### [REQ-V040-06] Agent rules for adopted systems

`AGENT_RULES.md` SHALL treat a profile with `status: active` as set up, whether adopted or not. An adopted profile
SHALL point agents to the project's own `steering/spec-rules.md` as the authority wherever it differs from the kit's
defaults.

### [REQ-V040-07] Docs and tests

- The README gets a section on adding specter to a project that already has specs: run `--dry-run` first, then
  install; what adopt mode keeps; how to set `tracker_pattern` and `merged_ref`. The CHANGELOG lists every change.
- The usage text printed by `install.sh` lists `--dry-run`, `--fresh` and `--hook`.
- The selftest covers:
  - adopt detection, with the profile seeded as active;
  - no file under an existing `.specs/` modified, by byte comparison except the allowed paths;
  - a user-level agent skipped (using a fake `HOME`);
  - a foreign kit refused with exit 2;
  - `--dry-run` writes nothing (tree identical) and lists paths;
  - history FAIL demoted to WARN, while broken links under a Done feature still FAIL;
  - a second install on an adopted project leaves an existing `spec-kit.json` and `.specs/.gitignore` byte-identical;
  - an adopted repo with a partial `spec-kit.json` can still commit (no hook by default; with `--hook`, no crash);
  - a user-owned skill and Cursor rule are kept;
  - install then uninstall on a CRLF `AGENTS.md` without a trailing newline restores it byte for byte;
  - uninstall keeps a foreign kit and a user's own `report.html` line.

## Out of scope

- Rewriting an adopted project's steering into the kit templates.
- Automatic `Status:` lines. Adding those is a per-project judgement made during rollout.
