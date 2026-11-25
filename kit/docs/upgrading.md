# Upgrading the kit

What a project that already runs specter does by hand after `install.sh` replaces the kit. The installer replaces
`.specs/kit/` whole and never edits your `spec-kit.json`, steering files or specs, so this file lists only what it cannot
do for you. After an upgrade it prints the blocks for the versions between yours and the new one. To read it again, open
this file.

Newest first, one `## <version>` block per release since 0.4.1 (a release that changes nothing for a project says so).
Two line forms are machine-read; everything else is prose:

- `- action:` something you do, once.
- ``- key: `name` = `<JSON default>` `` a `spec-kit.json` key you may add. A missing key already acts as this default,
  so adding it is optional.

## 0.11.0

No `action`. The `Max bytes` Evidence column in `steering/autonomy.md` is optional (default 4000), and
`.specs/kit/templates/github/specter-auto-merge.yml` is a workflow template you may copy.

## 0.10.0

- action: if a tier in `.specs/steering/autonomy.md` is Human `none`, re-read review-loop step 5 (an App approver,
  approval bound to the head sha, the size cap and `complexity: trivial`) before relying on it.
- action: a public repository with no `SECURITY.md`: copy `.specs/kit/templates/SECURITY.md` to the root.
- key: `readme` = `{"path": "README.md", "max_lines": 200, "sections": [], "deny": []}`: settings for `readme_check.py`.

## 0.9.0

- action: if `autonomy.md` has a Guardrails section, rows three and six were reworded: update both, check the platform
  does what they say, re-date them.
- action: the `### Review` block carries `rounds: <n>`; `ready.py` warns when it is missing.

## 0.8.0

- action: if `autonomy.md` exists, add the `## Guardrails` and `## Evidence` sections from the template: without
  Guardrails every `none` tier is labelled `spot`.
- action: write `Human-Findings: <n>` on every merge and `Fixes: <sha>` on an escaped-defect fix (`sync.md`).

## 0.7.0

- action: the `### Gates` block from `gates.py` changed (`pass (…)`, `FAIL (exit N)`, `not run`, a verdict line): change
  any script that greps it, and gitignore gate output.
- action: the review table is `| Severity | Location | Evidence | Trigger | Consequence | Fix |` with `blocker` or
  `advisory` only.
- action: tiers and guarded globs are relative to the repository root: a profile under a subfolder's `.specs/` adds the
  subfolder prefix.
- action: set `merged_ref` in `spec-kit.json` for `tiers.py` and `ready.py`; the first run after this upgrade runs them
  from the specter checkout, since the base has no kit yet.
- action: delete any committed `__pycache__` under `.specs/kit/`.

## 0.6.5

No `action`: the kit did not change.

## 0.6.0

No `action`. `autonomy.md` and `lessons.md` are optional; without `autonomy.md` nothing changes.

## 0.5.0

- action: `gates.py` reads a `| # | Gate | Command |` table in `.specs/steering/spec-rules.md` (Definition of Done). A 0.4.1
  spec-rules has a one-line gate: move the commands into that table, as in
  `.specs/kit/templates/steering/spec-rules.md`, or `gates.py` exits 2.
- action: add a `Deploy impact:` line to open tasks, and record how CI/CD consumes the repository (setup Q9) in the
  profile.
- action: optional: setup can generate `.specs/ONBOARDING.md` from `.specs/kit/templates/ONBOARDING.md`.
- key: `decisions` = `{}`: `enabled` (true) and `backlinks` (false, "warn", true) for the decisions log checks.
- key: `denylist_sha256` = `[]`: digests of names kept out of shared specs (`spec_lint.py --hash-term`).
- key: `unresolved_req` = `"warn"`: `"off"` silences the WARN for a REQ cited outside a feature and defined nowhere.
