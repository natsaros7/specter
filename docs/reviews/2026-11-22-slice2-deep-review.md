# Gate review: specter 0.7.0 slice 2 (`feat/0.6.5-acme-java...feat/0.7.0`)

Deep tier, security first. Line numbers are at `feat/0.7.0`. All repros ran in scratch repos under
`/private/tmp/claude-502/-Users-nikolaos-atsaros-Developer-projects/9b14f693-fb68-4017-8c4d-7666b85ba497/scratchpad/review-070/`
(`kit070/` = `git archive feat/0.7.0`, installed with its own `install.sh`; the acme `autonomy.md` was the profile).
No tracked file was changed.

Gates re-run by the reviewer: G1 exit 0, G2 exit 0, G3 `selftest: OK` exit 0 (in `kit070/`), G4 `0 FAIL across 7
feature(s)`, `0 FAIL of 72 citation(s)` exit 0.

Framing: `ready.py` can only check the PR text, and the PR author writes that text. An agent that types
`- G1: pass (x)` defeats it, and REQ-V060-13 already says this for model ids. So I graded parser leniency that only
helps a forger as MINOR. A **BLOCKER** is a case where `ready.py` says `ready`, or `tiers.py` gives a lower tier,
**on honest tool output** or through a path the design says is protected.

## Findings

| severity | file:line | issue | fix |
|---|---|---|---|
| BLOCKER | `kit/scripts/tiers.py:155` (GUARDED match), `:36-38` | Guarded globs match case-sensitively, but macOS and Windows checkouts fold case. A PR adds `.Claude/skills/evil/SKILL.md` (it lands in `.claude/skills/evil/` on disk) or a root `claude.md` (opened as `CLAUDE.md`). The guard misses it, acme `*.md` matches, and the tier is `routine`/`none`. Repro B1 | Match guarded globs on `f.lower()` against lower-cased globs (`fnmatch.fnmatchcase(f.lower(), g.lower())`). Add a selftest row for `.Claude/...` and `claude.md` |
| BLOCKER | `kit/scripts/ready.py:209-217`, `:63-70` | Gate labels are read at the base, but gate **commands** are not compared. A PR keeps label `G1 Lint` and changes its command to `echo lint ok`. The honest `gates.py` output (which runs the working-tree table) is `pass`, and `ready.py` says `ready`. This is the attack that reading at the base exists to stop. Repro B2 | Read `gate_rows` at the head too (`git show <head>:` or `:` for the index). If any base label's command differs, or a row was removed: `not ready: gate '<label>' command changed since the base; the block does not attest the base's gates`. Selftest row |
| BLOCKER | `kit/scripts/tiers.py:135-136`, `ready.py:209-210` (staged mode) | Staged mode uses `HEAD` as the base. On a feature branch, `HEAD` includes the branch's own unreviewed commits. A worker commits a profile edit (routine `*`, critical `nothing`) or drops a Gates row, then stages the real change. `tiers.py` gives `routine`; `ready.py` gives `ready` and needs no row for the dropped gate. The doc claim "a change cannot edit its own review rules" does not hold here. Selftest `13b: head table not used for staged` pins this behaviour, under a name that says the opposite. Repro B3 | Staged base = `git merge-base HEAD <merged_ref>` (the `spec-kit.json` key `spec_report.py` already uses, with its fallback). Files = `git diff --cached <base>`, which covers the branch commits plus the index. Rename and invert selftest 13b's last case |
| BLOCKER | `kit/docs/review-loop.md:27,34`, `kit/roles/reviewer.md:3`, `docs/reference.md` | The docs tell the human and the lead to run `python3 .specs/kit/scripts/{tiers,ready}.py`, which is the copy **in the tree under review**. A PR that edits `.specs/kit/scripts/ready.py` makes it print `ready` for any input. The edited `tiers.py` prints `routine` even while its own `set by:` line names the guarded `.specs/kit/*`. A self-check inside the script does not help, because the PR can delete it. Repro B4 | Docs (review-loop step 3 and step 5, reviewer role, reference, CHANGELOG): run `tiers.py` and `ready.py` from a trusted copy (a `git worktree add <tmp> <base>` of the base, or CI on the default branch) with `--specs <pr-checkout>/.specs`. The imports already resolve from the script's own folder, so this works today. Also state that `ready` means "the declarations are consistent", not "the gates ran": the platform's required checks are the evidence (Guardrail row 2, slice 3) |
| MAJOR | `kit/scripts/tiers.py:133,136` | `git diff --name-only` without `-z`: git quotes non-ASCII and control-character paths (`".claude/skills/good/src/test/r\303\274n.sh"`). The leading `"` defeats every guarded glob, and an unanchored lower glob (acme `*/src/test/*`, or a `*/docs/*` that would match namespaced `.claude/commands/docs/…`) still matches, so the file gets `routine`. Newline names behave the same. Repro M1 | `git diff -z --name-only …` and split on `\0` (or `-c core.quotePath=false` plus `-z`). One selftest row with a non-ASCII guarded path |
| MAJOR | `kit/scripts/tiers.py:133,136` (`--relative`) | When `.specs/` sits in a subfolder (the acme-in-specter layout), `--relative` drops every file outside it. A change to the repo-root `.claude/settings.json` (`Bash(*)` allowed) and `.github/workflows/ci.yml` plus one doc gets `routine, files: 1`. REQ-V060-05 says the change is labelled, not a subtree. Repro M2 | Drop `--relative` and match paths relative to the repo top (`git rev-parse --show-prefix` gives the `.specs` prefix for GUARDED and the profile globs). Or refuse (exit 2) when root is not the repo top, until that is supported. Either way, add `shortcut:` or a test |
| MAJOR | `kit/scripts/ready.py:74-79` | Staged mode accepts a clean `<HEAD>` (no `+dirty`) block while the index holds staged changes. Run `gates.py` on the clean tree (green), stage a breaking change, paste the block: `ready`. Rerunning the gates on that index gives `FAIL`. Repro M3 | When the staged file list is non-empty, require `+dirty`. Note in the docstring and review-loop that `+dirty` binds no content, so only `--range` on a commit is a binding check, and the human's final check uses `--range` |
| MAJOR | `kit/scripts/ready.py:112` | A blocker's Location must match `[^\s:]+:\d+`. A reviewer writing `` `path:42` `` (code span, the LLM default), `path:42-45`, `path:42:7` or the kit's own citation forms `path#L42` and `path:12-20` (reference.md) gets a complete blocker demoted to advisory, with verdict `ready` and only a warning. The warning also says `no location` when the cell is not empty. Repro M4 | Strip backticks, then accept `path:N[-M][,…]`, `path:N:C` and `path#LN[-LM]`. Demote only an **empty** cell (REQ-V060-13 says "with any of the four empty"). A non-empty unparseable location on a blocker is a `not ready` problem, never advisory |
| MAJOR | `kit/scripts/spec_lint.py:51-52` (new `import gates`) | `spec_lint.py`, the most common gate, now writes `.specs/kit/scripts/__pycache__/` in an installed project (no `.gitignore` is installed; 0.6.5 left the tree clean). Effects: (a) the next `gates.py` run reports `+dirty`, and `ready.py --range` rejects it ("was dirty"); (b) a worker's `git add -A` commits `.pyc` into `.specs/kit/`, which is guarded, so every change becomes critical. Repro M5 | `sys.dont_write_bytecode = True` before the sibling imports in `spec_lint.py`, `tiers.py`, `ready.py` and `spec_report.py`. Or have the installer write `.specs/kit/.gitignore` with `__pycache__/`. Selftest: `git status --porcelain` empty after a lint run in an installed repo |
| MAJOR | `kit/scripts/tiers.py:36-38` | Guarded list gaps that the acme `*.md` routine glob matches: nested `*/AGENTS.md` and `*/CLAUDE.md` (Claude Code and Codex load them per directory), `.github/instructions/*`, `.github/prompts/*`, `.github/agents/*`, `.clinerules/*`, `.windsurfrules`. `.specs/README.md` (the router `AGENT_RULES.md` sends every agent to) is guarded only while the Knowledge Router row survives. `.mcp.json` and `CODEOWNERS` are only covered by "unmatched → last row" | Add `*/AGENTS.md`, `*/CLAUDE.md`, `*/GEMINI.md`, `.specs/README.md`, `.mcp.json`, `.github/instructions/*`, `.github/prompts/*`, `.github/agents/*`, `CODEOWNERS`, `.github/CODEOWNERS` to GUARDED. Record the list in the REQ-V060-05 bullet |
| MINOR | `kit/scripts/ready.py:121-131` | The review's declared tier is never compared with the label. A `critical (reviewer: deep)` change reviewed by `gpt-5-1-mini (standard)` gives `ready`. Repro m1. Harmless while a human reads every change; it **must be a BLOCKER fix before slice 4** (auto-merge on readiness) | Parse `(standard|deep)` from `- reviewer:`. Missing, or below `change["reviewer"]`: `not ready` |
| MINOR | `kit/scripts/ready.py:125` | Family = first `-` token, so a provider prefix evades the same-family WARN: `anthropic/claude-opus-5-5`, `us.anthropic.claude-opus-5` and `anthropic.claude-sonnet-5-5` vs `claude-sonnet-5-5` give no warning (control: `claude-opus-5-5` vs `claude-sonnet-5-5` warns). `o3` vs `gpt-5` is the same vendor and no warning. WARN only today; it bars `none` in slice 4 | Take the last `/`- or `.`-separated segment before the first `-` (`rsplit` on `/` and `.`), lower-cased. That keeps the decided "first token" rule and drops provider routing prefixes |
| MINOR | `kit/scripts/ready.py:36-47,55-62` | The parser does not see what the human sees. A `### Gates` block inside `<!-- … -->` is parsed, while a visible red block under `##### Gates` is ignored, and the verdict is `ready`. Inside the block, unrecognised lines are dropped silently: `- G1 Lint:  FAIL (exit 1)` (two spaces) next to a pass row, or `- verdict: not ready (…)` next to `- verdict: ready (9 passed)`, still gives `ready`. A fenced example `### Gates` counts as a second block (false `not ready`). This only helps a forger, so MINOR | Before parsing, drop HTML comments and fenced code. In the Gates block, any line that is neither a ROW, `commit:` nor `verdict:` is a problem. Count `verdict:` lines (exactly one) and check that N equals the base row count |
| MINOR | `kit/scripts/ready.py:161-162` | Staged mode: `git ls-files -s -- <dir>` lists the directory's files, so a Verification target of `docs/shots` or `.` reports `ok` (range mode correctly says `not a file`). Case folding is fine: `DOCS/SHOTS/A.PNG` gives `missing` | Staged mode: require exactly one output line whose path equals the target (`ent[-1] == target`) |
| MINOR | `kit/scripts/ready.py:220` | A bad `spec-kit.json` (invalid JSON, a bad `req_id_pattern` regex, a bad key) exits 1 with a traceback or `sys.exit(msg)`. Exit 1 means `not ready`, so a config error reads as a verdict. A capturing group in the pattern makes every REQ undefined. Not exploitable for a pass: a PR can already define its REQ in its own `requirements.md` at the head, which is acceptable for a new feature. So the existing `shortcut:` stays, and its upgrade trigger can say so | Wrap `load_config` and `re.compile` in try/except (`SystemExit`, `ValueError`, `re.error`) and call `refuse()` (exit 2). Use `(?:…)` or `re.finditer(...).group(1)` |
| MINOR | `kit/scripts/gates.py:120` | A passing gate's last output line goes raw into PR markdown. `tests ok <!--` hides every later line (other rows, commit, verdict, `### Review`) in the rendered PR, while `ready.py` still parses them | Wrap the text in a code span with backticks removed, or strip `<>` and backticks. Cap it at about 120 characters |
| MINOR | `kit/scripts/tiers.py:155` | A guarded **directory name itself** is not guarded: `fnmatch(".claude", ".claude/*")` is False. A symlink or submodule named `.claude` pointing at `docs/agent/` is caught once (unmatched → last row), but after that, edits under `docs/agent/` are routine and steer the agent. The same applies to `AGENTS.md -> docs/agents.md` symlinks | Also guard `g[:-2]` for `dir/*` globs. Add the in-repo target of any guarded path that is a symlink at the base (`ls-tree` mode `120000`) |
| NIT | `kit/scripts/spec_lint.py:312` | Without a `#` column, gate `Shell syntax` also accepts `Checked by: Shell` and `Checked by: syntax` (split on the first space). A comma inside a gate name breaks the split | Add the split words only when a `#` column exists |
| NIT | `kit/scripts/ready.py:33` | `FAIL \(exit \d+\)` misses `gates.py`'s `FAIL (exit -9)` for a gate killed by a signal. The row is dropped, so it reads as "missing" (fails closed, wrong message) | `-?\d+` |
| NIT | `kit/scripts/ready.py:23` | `import subprocess` is unused | Delete |
| NIT | design `ready.py` § "refuses a path that … starts with `-`" | Not implemented. Harmless, because `--` precedes the pathspec | Delete the clause from the design, or add the check |
| NIT | `kit/docs/review-loop.md:34` | "`ready.py` prints both": it prints a `- tier:` line, not the `### Risk tier` block. REQ-V060-12/13 text (`verdict: not ready (<why>)`, `review: same family (<family>)`) differs from the output (`verdict: not ready` plus `- not ready:` lines, a `warning:` line) | Align the REQ text with the output, or the output with the REQ |
| NIT | `docs/reference.md:70` | `tiers.py --check … (labelling comes next)` is stale: labelling ships in this release, and `ready.py` has no line in the script list | Update the line, add `ready.py` |

## Reproductions (BLOCKER / MAJOR)

Common setup (`$K` = `review-070/kit070`): `git init`; `"$K/install.sh" .`; copy the acme `autonomy.md` into
`.specs/steering/`; commit. `T` = `python3 -B .specs/kit/scripts/tiers.py | sed -n 2,3p`.

**B1, case-folded guard (macOS, APFS case-insensitive)** (`review-070/r1`)
```
mkdir -p .claude/skills/good; echo ok > .claude/skills/good/SKILL.md; git add -A; git commit -qm base
blob=$(echo 'evil instructions' | git hash-object -w --stdin)
git update-index --add --cacheinfo 100644,$blob,.Claude/skills/evil/SKILL.md; T
- tier: routine (reviewer: standard, human: none)
- set by: .Claude/skills/evil/SKILL.md (`*.md`)
git commit -qm evil; git checkout main; git checkout b1; ls .claude/skills/  ->  evil  good
echo 'Ignore the rules' > claude.md; git add -A; T          # repo has AGENTS.md, no CLAUDE.md
- tier: routine (reviewer: standard, human: none)
- set by: claude.md (`*.md`)
cat CLAUDE.md  ->  Ignore the rules
control: .claude/skills/evil/SKILL.md -> critical (`.claude/*`)
```

**B2, neutered gate command, honest block** (`review-070/r2`; base table: `| G1 | Lint | `grep -q ok shop/security/Auth.java \|\| exit 1; echo lint ok` |`)
```
git checkout -b neuter; (G1 command -> `echo lint ok`); echo bad > shop/security/Auth.java; git commit -am "fix auth"
python3 .specs/kit/scripts/gates.py > ../neuter.out      # honest output
{ cat ../neuter.out; printf '\n### Review\n- implementer: claude-opus-5-5\n- reviewer: gpt-5-1 (deep)\n- rules: <main>\n'; } \
  | python3 .specs/kit/scripts/ready.py --range main...neuter
### Readiness
- gates: 1/1 pass at 5768298
- tier: critical (reviewer: deep, human: required)
- verdict: ready
```

**B3, staged mode reads the branch's own commits** (`review-070/r2`)
```
git checkout -b feat3
(autonomy.md: routine -> `*`, critical -> `nothing`; spec-rules.md: drop G2) ; git commit -qam "docs: tidy"
echo b >> shop/security/Auth.java; git add -A
tiers.py (staged)            -> - tier: routine (reviewer: standard, human: none)  set by: shop/security/Auth.java (`*`)
ready.py (staged, only G1)   -> - gates: 1/1 pass ...  - verdict: ready  (exit 0; base table had G1 and G2)
same change, --range main...feat3 -> - tier: critical  set by: .specs/steering/autonomy.md (`.specs/steering/*`)
```

**B4, the tree's own copy of the trust scripts** (`review-070/r2`, staged)
```
(.specs/kit/scripts/tiers.py: idx = 0; ready.py: problems = []; verdict = "ready")
echo bad > shop/security/Auth.java; git add -A
tiers.py  -> - tier: routine (reviewer: standard, human: none)
             - set by: .specs/kit/scripts/ready.py (`.specs/kit/*`)
echo garbage | ready.py -> - gates: 0/1 pass ...  - verdict: ready   exit=0
```

**M1, quoted path defeats the guard** (`review-070/r1`)
```
mkdir -p .claude/skills/good/src/test; echo x > ".claude/skills/good/src/test/rün.sh"; git add -A; T
".claude/skills/good/src/test/r\303\274n.sh"
- tier: routine (reviewer: standard, human: none)
- set by: ".claude/skills/good/src/test/r\303\274n.sh" (`*/src/test/*`)
same with a newline in the name under .specs/kit/scripts/src/test/ -> routine
ASCII control (run.sh) -> critical (`.claude/*`)
```

**M2, subfolder `.specs/` ignores repo-root files** (`review-070/r15`, kit installed into `app/`)
```
edit .claude/settings.json ({"permissions":{"allow":["Bash(*)"]}}), .github/workflows/ci.yml, app/docs/a.md; git add -A
python3 app/.specs/kit/scripts/tiers.py   (and --range main~1...main after commit)
- tier: routine (reviewer: standard, human: none)
- set by: docs/a.md (`docs/*`)
- files: 1 (routine 1)
```

**M3, stale clean block in staged mode** (`review-070/r2`)
```
python3 .specs/kit/scripts/gates.py > ../r3-gates.out   -> G1 pass, commit: 118f1f7, verdict: ready (1 passed)
echo bad > shop/security/Auth.java; git add shop/security/Auth.java
ready.py --pr ../r3-pr.md  -> - verdict: ready  exit=0
gates.py now               -> - G1 Lint: FAIL (exit 1)  commit: 118f1f7+dirty  exit=1
```

**M4, blocker location formats demoted to advisory** (`review-070/r2`)
```
| blocker | `shop/security/Auth.java:1` | "if (t > 0)" | total 0 | ships unpaid | >= 0 |
-> - verdict: ready
   - warning: blocker at '`shop/security/Auth.java:1`' is advisory (no location)
same verdict for  shop/security/Auth.java:1-3 | :1:5 | #L1
```

**M5, `__pycache__` in the installed kit** (`review-070/rpyc` vs `rpyc65`)
```
install; commit; python3 .specs/kit/scripts/spec_lint.py; git status --porcelain
0.7.0:  ?? .specs/kit/scripts/__pycache__/
0.6.5:  (clean)
```

**m1, reviewer tier below the label** (`review-070/r2`)
```
critical change; - reviewer: gpt-5-1-mini (standard)
-> - tier: critical (reviewer: deep, human: required)   - verdict: ready
```

## Checked and holding (no finding)

- Profile and Gates table read at the merge base in `--range`, for both `A...B` and `A..B`. A branch's profile or table edit does not change its label. Renames are counted under both paths, deletions under the old path. Mode changes, submodules and binaries are listed by path.
- Strictest wins: `reversed(enumerate(rows))` picks the last matching row, so a security file never takes a routine glob "first". fnmatch `*` crosses `/`, and GUARDED relies on that (`.claude/*` covers depth).
- Commit binding in `--range`: 7–40 lowercase hex prefix of B, compared as a string with no ref resolution, so a prefix of another commit cannot help. `+dirty` is refused.
- Rows for gates the base doesn't have only produce a warning. Duplicate pass rows give `not ready`. Label lookalikes (trailing space, case, Unicode) fail closed as "missing". Multiple `### Gates` or `### Review` blocks give `not ready`.
- `review rules:` must be at least 7 hex and a prefix of the base string, so a short or ambiguous value fails.
- Verification refuses `..`, absolute paths, backslashes and symlinks (`120000`). Pathspecs are passed after `--` with `--literal-pathspecs`, and macOS case folding does not match (`git ls-files` is case-sensitive). URLs are never fetched.
- `gates.py`: the gate's output is one `splitlines()` line inside `pass (…)`, so a newline or `)` cannot forge a row or a verdict. The `not run` count cannot be spoofed (a pass row always ends in `)`). Exit codes are unchanged.
- No `ready.py` path runs a shell. Every PR value reaches git as an argv item.

## CHANGELOG must say (task 15)

- **Breaking for 0.5/0.6 users: the `### Gates` block format.** Rows are now `- <label>: pass (<last output line>)`
  (was `- <label>: <last output line>`). A red run now also prints the block on **stdout**, with `FAIL (exit N)` and
  `not run` rows. Before, stdout was empty on failure, so "stdout non-empty" no longer means green. The block ends
  with a new `- verdict: ready (N passed)` / `- verdict: not ready (F failed, R not run)` line. Exit codes are
  unchanged (0/1/2). Any CI step or script that parses the block, or greps a row's text, must change. PR
  descriptions from 0.6 fail `ready.py`.
- **Review verdict table changed**: `severity | file:line | issue | fix` with `blocker/major/minor` becomes
  `| Severity | Location | Evidence | Trigger | Consequence | Fix |` with `blocker`/`advisory` only. A 0.6-style
  `major` or `minor` row makes `ready.py` say `not ready` ("severity … not blocker or advisory"). Only complete blockers go
  back to the worker. Advisories become follow-ups.
- **New `ready.py`**: reads PR text, runs nothing, exit 0 ready / 1 not ready / 2 usage. It **requires** exactly one
  `### Gates` and one `### Review` block (with `implementer:`, `reviewer:`, `rules: <base sha>`), and checks
  `### Verification` lines when that block is present. Say that `ready` means "the declarations match the repository", not
  "the gates ran". The proof is the platform's required checks.
- **New `tiers.py`** (`--check`, and staged or `--range` labelling, `### Risk tier`, `--json`): labels only, nothing
  merges. The profile is read at the base. Guarded paths (list them) always take the last row. No profile or no Tiers
  section gives the human tier, as before.
- **Run `tiers.py` and `ready.py` from a trusted copy** (the base's worktree or a default-branch CI job) with
  `--specs`, never from the PR's own `.specs/kit/` (B4). Say which mode binds: `--range` on a commit binds the block,
  staged mode with `+dirty` does not.
- **Reviewer reads rules at the base** (`git show <base>:…`). The reviewer's tier comes from `tiers.py`, which replaces
  the "security paths → deep" prose. spec-rules §7.4 changed its placeholder (adopt-mode projects: re-check §7).
- **Decisions `Checked by` column** (optional). Once added, an unknown gate label is a lint FAIL (exit 1). Without the
  column, the output is unchanged.
- **Setup Q10** now proposes Tiers. The example `acme-shop` ships a Tiers table. Upgrade note: re-run `install.sh` to get
  the new scripts. An existing `autonomy.md` without `## Tiers` keeps the human tier.
- If M5 is not fixed before release: add `.specs/kit/scripts/__pycache__/` to `.gitignore`. Otherwise `gates.py`
  reports `+dirty` and `ready.py --range` refuses the block.
- Known limits carried as `shortcut:` (named so users don't over-trust): model ids are self-declared; Evidence is checked
  for presence only; `req_id_pattern` comes from the working tree; the run stops at the first failure; URLs are not fetched.

Skipped or unchecked: Windows (case and `\` paths) not run, only reasoned about; I did not test ReDoS through a hostile
`req_id_pattern` (DoS only); I did not test `--range` on shallow CI clones (no merge base gives exit 2, which fails
closed). Risk: B1–B4 make the slice 2 trust signal unreliable on the maintainer's own platform (macOS) and in the
documented workflow. Fix them before 0.7.0 ships, or at least before slice 4 gives `ready` any authority.
