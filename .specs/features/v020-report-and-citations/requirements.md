# v020 Report page, citation notations, drift aging, JSON output — Requirements

Status: Done 2026-10-28 (v0.2.0)

Tracker: none. Branch `feat/0.2.0`. Size M. Release: 0.2.0, after the Codex dry run, so its friction log ships in the same release.

## Why

Verified on `main` 2026-10-28 (`053958a`):

- `kit/scripts/spec_lint.py:96`: a citation is `path:N` or `path:A-B` in backticks, nothing else. On a mature workspace spec set
  (17 repos, months old), `--cites` failed 85 of 191 citations. Grouped by cause:
  - **Repo prefix (23):** `<repo>:<path>:<lines>`, where the prefix names a repo or an alias for one (a two-letter
    shorthand, or a chart's folder name). The checker treats it as part of the path.
  - **Multiple ranges:** `<path>:<a>-<b>,<c>-<d>` doesn't match the pattern at all, so it is silently uncounted.
  - **Nested repos:** `kit/scripts/spec_lint.py:105` indexes child repos one level deep only. A charts folder with one repo per
    chart (`charts/<chart>/.git`) is invisible, so its files are "no such file".
  - **Ambiguous (40):** the same file exists in the code repo, a load-test copy and a generated docs mirror. There is no way to
    say "never resolve citations into the mirror".
  - Real staleness: the remainder (past end of file, blank lines, files really gone).
- Drift Register rows have a `Logged` date, but nothing reads it. A row can stay open forever without anyone noticing.
- `spec_lint.py` output is text only, so other tools have to scrape it.
- Nobody outside the agent session sees the state of the specs. A lead has to open markdown files one by one.

## User story

As a lead or a teammate who doesn't live in `.specs/`, I want one page that shows feature progress, open drift and
citation health, so that I can tell at a glance whether the specs are still true. As a spec author, I want the citation
checker to understand the notations people actually write, so that a red result means stale, not unparsed.

## Requirements

### [REQ-V020-01] Repo-prefixed citations

- WHEN a citation has the form `` `<prefix>:<path>:<lines>` `` THEN `--cites` SHALL resolve `<path>` only inside the folder
  `<prefix>` names.
- `<prefix>` SHALL resolve first through `cite_aliases` in `spec-kit.json` (`{"NS": "tools/load-sim"}`), else to an indexed
  repo whose folder name equals `<prefix>` at any indexed depth.
- IF `<prefix>` resolves to nothing THEN the citation SHALL FAIL with `unknown repo prefix '<prefix>'` (add it to
  `cite_aliases`).
- `<path>` keeps today's rules inside that folder: exact path first, else suffix match, with `.../` and `…/` elision.
- Elided heads narrow the match: in `head/.../tail` a candidate must end with `tail` and contain `head` as a run of whole
  path segments before it. IF no candidate does THEN matching falls back to `tail` alone (today's behaviour), so a head
  that isn't a folder of the file, like the repo's own name, still resolves.

### [REQ-V020-02] Line notations

`--cites` SHALL accept, and check every listed line range of:

```text
a/b.py:12               today
a/b.py:12-20            today
a/b.py:12-20,31,40-44   several ranges
a/b.py#L12  a/b.py#L12-L20  a/b.py#L12-20   GitHub style
```

Each range is checked on its own: past end of file, or all its lines blank, fails with that range named.

### [REQ-V020-03] Nested repos

The citation index SHALL include git repos up to two levels below the project root (`*/.git` and `*/*/.git`), with paths
relative to the project root. Folders whose name starts with `.` (`.venv`, `.cache`, …) are not searched for repos, at any depth.

### [REQ-V020-04] Citation tie-break

WHEN a citation matches more than one file THEN candidates matching `cite_ignore_globs` (`spec-kit.json`, default `[]`,
fnmatch on the root-relative path) SHALL be dropped. IF exactly one candidate is left THEN it resolves; otherwise the
citation stays ambiguous. An exact path is never dropped.

### [REQ-V020-05] Drift aging

- `spec_lint.py` SHALL read every markdown table under `.specs/` (outside `kit/`) whose header has a `Drift` column. A
  `Logged` column is optional: registers written before the template had one are still read.
- A row is open unless it contains `RESOLVED`. Its date is the first `YYYY-MM-DD` in the `Logged` cell.
- WHEN an open row's date is older than `drift_max_age_days` (`spec-kit.json`, default 90) THEN it SHALL print
  `WARN drift <file> <id>: open <N> days`.
- WHEN a file has open rows without a date THEN it SHALL print one `WARN drift <file>: <N> open row(s) without a Logged
  date`, once per file, not once per row.
- `"drift_max_age_days": null` SHALL switch both warnings off. Drift aging SHALL NOT change the exit code.

### [REQ-V020-06] JSON output

- WHEN `--json` is given THEN both modes SHALL print one JSON object on stdout and nothing else:
  - default mode: `{"features": [{"name", "ok", "fails", "warns"}], "links": [...], "drift": [{"file", "id", "sev", "text", "logged", "age_days", "resolved"}], "warnings": [...], "fails": N}`
  - `--cites`: `{"count": N, "problems": [{"file", "cite", "reason"}]}`
- Exit codes SHALL be the same as without `--json`.

### [REQ-V020-07] Report page

- `kit/scripts/spec_report.py [--specs DIR] [--out FILE]` SHALL write one self-contained HTML file (default
  `.specs/report.html`): inline CSS, no JavaScript needed, no network, no external fonts or images.
- The page SHALL show:
  - **Features:** name (linked to `requirements.md`), tasks done/total with a bar, and a status: `Done` (a `Status: Done`
    line or every task ticked), `Blocked` (a `Blocked on:` line), `Not started` (no task ticked), else `In progress`.
  - **Drift:** open rows, oldest first, with severity, age in days and file. Rows over `drift_max_age_days` are highlighted.
    The resolved count is shown.
  - **Coverage:** REQs defined in features that no task links, and lint FAIL/WARN lines.
  - **Citations:** total, failing count and the failing list, from `--cites`.
  - A header with the project folder name, the kit version and the generation time.
- All text from spec files SHALL be HTML-escaped.
- It SHALL reuse `spec_lint.py` (import), not re-implement the checks.
- Exit code 0 when the page is written, whatever the findings; the lint is the gate, the report is for reading.

### [REQ-V020-08] Wiring and docs

- `install.sh` SHALL write `.specs/.gitignore` containing `report.html` (idempotent, keeps other lines), and `--uninstall`
  SHALL remove that line only.
- README "Scripts" lists `spec_report.py` and the new `spec-kit.json` keys. `CHANGELOG.md` `[Unreleased]` lists every
  change. `tests/selftest.sh` covers REQ-V020-01 to 08.
- Python 3.8+, stdlib only, no new files outside `kit/scripts/`, `tests/` and docs.

## Out of scope

- `Class#method` / symbol citations (none found in the corpus).
- A served or interactive UI, GitHub Pages publishing, CI.
