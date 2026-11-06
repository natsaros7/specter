# v050 Decisions, ids, denylist, deploy impact, gates — Design

Everything is in `kit/scripts/spec_lint.py` (one new pass) and a new `kit/scripts/gates.py`. Stdlib only, Python 3.8+.

## Where the decisions log lives — [REQ-V050-01]

`.specs/steering/decisions.md`, from `kit/templates/steering/decisions.md`.

| Option | For | Against |
|---|---|---|
| **`steering/decisions.md`** (chosen) | Templates mirror their target paths (`templates/steering/*` → `.specs/steering/*`). Steering already holds the project-wide rules every change must follow, and a settled decision is one. | One folder deeper than a top-level file |
| `.specs/decisions.md` | Short path | Breaks the template-to-path mirror; a new top-level kind of file |

`decisions.file` in `spec-kit.json` points elsewhere (an adopted project that already keeps `.specs/decisions.md`).
Projects without the file get none of the decision checks, so a 0.4.1 project is unchanged.

## Config — [REQ-V050-01] [REQ-V050-03]

`DEFAULTS` gains `"decisions": {}` and `"denylist_sha256": []`. `load_config` fills `decisions` with
`{"file": "steering/decisions.md", "backlinks": false, "enabled": true}`, rejects unknown keys and wrong types, and exits
with a message on a non-list denylist or an `unresolved_req` other than `"warn"`/`"off"`, as it already
does for `drift_max_age_days`. `kit/spec-kit.json` is unchanged, so `untouched_seed` in the installer keeps working.

## One pass over the specs — [REQ-V050-01] [REQ-V050-02] [REQ-V050-03]

`refs(specs, config, req_defs)` returns `(fails, warns)`. It calls `cited_ids`, `landings` and `denylisted`, one per
job:

| Check | Source | Level |
|---|---|---|
| REQ cited, not defined | every `req_id_pattern` match outside fences and inline code, outside the three files `lint_feature` already checks; one WARN per id, up to 3 locations | WARN (`unresolved_req: "off"`) |
| `D-<id>` cited, no row | `(?<![\w-])D-` + id with a digit + `(?![\w-]\|\.\w)` outside fences, when the decisions file holds a decision row | FAIL |
| REQ in "Where it lands", not defined | rows of every table whose header has `Where it lands` and whose first cell is a `D-` id; rows named in a later "Supersedes" cell are skipped | FAIL |
| Back-link missing | the REQ's definition block (the heading section with its sub-headings, or the line and its following non-blank lines up to the next definition) lacks the id | per `decisions.backlinks` |
| Denylisted term | every line, fences included (a name in a code block leaks too) | FAIL when the list is set |

`req_defs` maps each `[REQ-…]` defined in `features/*/requirements.md` and `domains/*/requirements.md` to its
`(file, line)`; `lint_all` builds it once. `lint_all` adds the result as `refs` (counted in `fails`) and appends the
WARNs to `warnings`. `spec_report.py` lists `refs` with the other findings. `--hash-term <word>` prints
`sha256(word.lower())` and exits 0 before any linting.

The tokeniser is `re.findall(r"[^\W_]+(?:\.[^\W_]+)*", nfc(line).lower())`. Each token also counts as every run of its
dot segments (an IP prefix, a host name), and as `token-next` for the adjacent pair. A hit prints only the token
number.

## `gates.py` — [REQ-V050-05]

`python3 .specs/kit/scripts/gates.py [--specs DIR] [--file PATH] | --help`. Root = the folder holding `.specs/`. Any
other argument exits 2. It reads the commit and dirty state first, so output the gates write doesn't count, and gives
the gates a closed stdin.

1. Read `--file`, else `<specs>/steering/spec-rules.md`. Find the first table whose header cells include `gate` and
   `command` (case-insensitive; a `#` column is optional and joins the label). Cells split on unescaped `|`, and `\|`
   becomes `|`.
2. Each row's Command cell must hold exactly one code span. Otherwise it exits 2 before running anything, as it does
   for a missing file or table.
3. Run each command with `sh -c` in the root, in order. Progress goes to stderr. On a non-zero exit it prints the
   output, then `GATE FAILED: <label> (exit N)`, and exits 1.
4. All green: stdout gets `### Gates`, then one `- <label>: <last non-blank output line, or "exit 0">` per gate, then
   `- commit: <short sha>` plus `+dirty` when `git status --porcelain` is non-empty (`none` outside git).

The spec-rules template's §7 gets the table; `next-task.md` already points to the Definition of Done.

## Docs and templates — [REQ-V050-04] [REQ-V050-06] [REQ-V050-07]

| File | Change |
|---|---|
| `kit/templates/feature/tasks.md` | `Deploy impact:` line under the title; the PR task restates it |
| `kit/templates/steering/spec-rules.md` | §4 points to `decisions.md`; §7 Gates table and the deploy-impact item |
| `kit/templates/steering/decisions.md` | new |
| `kit/templates/ONBOARDING.md` | new; generated to `.specs/ONBOARDING.md`, since setup writes only under `.specs/` |
| `kit/playbooks/setup.md` | Q9 (must-ask, CI/CD consumption) → profile Facts and spec-rules §7; Phase 5 writes the Gates table; Phase 6 offers the onboarding page |
| `kit/docs/review-loop.md` | deploy-impact sentence in the human check; "Grill the artifact" section |
| `README.md` | one short subsection |

## Example — [REQ-V050-08]

`examples/acme-shop/.specs/steering/decisions.md` with three rows landing on `REQ-TSV-*` and `REQ-ORD-*`, back-linked from
those REQs; `"decisions": {"backlinks": true}` in its `spec-kit.json`; a `Deploy impact:` line in both features' tasks;
a Gates table in its spec-rules; `ONBOARDING.md`, linked from its router.

## Tests — [REQ-V050-08]

New `tests/selftest.sh` case 11 in a `mktemp` project:

- unresolved `D-` id FAIL with `file:line`;
- back-link: WARN with `"warn"`, FAIL with `true`, silent by default;
- landing REQ undefined FAIL;
- REQ cited in `system/` undefined WARN;
- denylist hit printed without the word, and `--hash-term`;
- `gates.py`: a failing middle gate stops before the third, a green run prints the block with `+dirty`, and a missing
  table exits 2;
- a 0.4.1-shaped project lints with exit 0 and no new FAIL.

## Rollout / rollback

Every check is off or WARN until a project adds the decisions file or a denylist. Rollback: remove the file or the key.
