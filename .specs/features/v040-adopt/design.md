# v040 Adopt — Design

## Mode detection — [REQ-V040-01] [REQ-V040-03]

`mode(target)` returns one of:

- `upgrade`: `.specs/kit/VERSION` exists.
- `adopt`: no `VERSION`, and any of `features/`, `domains/`, `system/` or `steering/` exists under `.specs/`.
- `fresh`: otherwise. `--fresh` forces this mode unless the kit is already installed.

Before copying, a `.specs/kit/` without `VERSION` triggers the REQ-V040-03 stop.

## Writes go through one function — [REQ-V040-04]

Every write in `install()` goes through `write(path, kind, fn)`. `kind` is `create`, `modify` or `replace`. In
`--dry-run` it prints `kind path` and skips `fn`. The affected writes are:

- `shutil.copytree`/`copy` for kit parts;
- the config, `.gitignore`, profile, `put_block`, skills, agents and Cursor rule writes;
- the hook.

`put_block` and `ensure_line` report `modify` only when the file exists and would change.

## Profile — [REQ-V040-01] [REQ-V040-06]

In adopt mode the seeded profile is the template with `status: active` plus an `adopted:` line, written with plain
string replacement on the template text. `AGENT_RULES.md` keeps its first bullet (missing profile or
`setup-incomplete` → offer setup) and gains one line: "Adopted systems (`adopted:` in the profile): the project's
`steering/spec-rules.md` wins where it differs from the kit."

## User-level agents — [REQ-V040-02]

`HOME / ".claude/agents" / name` is checked before the project write. `HOME` is the existing module global, so tests
override it by setting the `HOME` environment variable.

## History — [REQ-V040-05]

`lint_feature` returns `(fails, warns)` as today. `lint_all` reads `feature_status`, and when the state is `done` or
`dropped` it moves structural FAILs into warns, prefixed `history: `. Link checking is separate (`broken_links`) and
stays FAIL. Citations already run separately.

## Tests — [REQ-V040-07]

Case 7 in `tests/selftest.sh` builds a fake project with an existing `.specs` (`features/a-1/` with files missing,
`steering/spec-rules.md`, `README.md`). It then:

1. snapshots hashes of every existing file;
2. runs `--dry-run` with `HOME=$TMP/home`, where `$TMP/home/.claude/agents/planner.md` exists, and checks the
   snapshot is unchanged and the output lists `create .specs/kit`;
3. runs a real install, checks the original files are byte-identical, the profile says `status: active` with an
   `adopted:` line, and `.claude/agents/planner.md` was not created while `reviewer.md` was;
4. marks `a-1` `Status: Done 2026-01-01 (x)` and checks the lint exits 0 with a `history:` WARN;
5. checks that a foreign `.specs/kit/` makes the install exit 2.

## Risks

| Risk | Mitigation |
|---|---|
| An agent obeys the kit's generic rules over the project's own | REQ-V040-06 line: the project's spec-rules win |
| Demoting history hides real problems | Only for `Done` and `Dropped`; links and citations still fail; WARNs stay visible in the report |
