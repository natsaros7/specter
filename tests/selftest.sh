#!/bin/sh
# Self-test: example specs lint clean; install is idempotent; hook warns; multi-repo skips the hook; uninstall is clean.
set -eu
KIT=$(cd "$(dirname "$0")/.." && pwd)
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
fail() { echo "FAIL: $*"; exit 1; }
gitq() { git -c user.name=t -c user.email=t@t -c init.defaultBranch=main "$@" >/dev/null; }

echo "1. example specs lint clean"
python3 "$KIT/kit/scripts/spec_lint.py" --specs "$KIT/examples/acme-shop/.specs" >/dev/null || fail "example lint"

echo "2. single repo: install, re-install, compare"
P="$TMP/single"; mkdir -p "$P/src" "$P/.cursor"; gitq -C "$P" init
printf '# Mine\nkeep me\n' > "$P/CLAUDE.md"
"$KIT/install.sh" "$P" --agents=claude,codex,cursor >/dev/null
snap() { (cd "$P" && find . -path ./.git -prune -o -type f -print | sort | xargs cat | shasum); }
first=$(snap); "$KIT/install.sh" "$P" --agents=claude,codex,cursor >/dev/null; [ "$first" = "$(snap)" ] || fail "install not idempotent"
grep -q "keep me" "$P/CLAUDE.md" || fail "user CLAUDE.md content lost"
[ "$(grep -c 'specter:begin' "$P/AGENTS.md")" = 1 ] || fail "duplicate marker block"
for f in .agents/skills/spec-first/SKILL.md .specs/kit/roles/reviewer.md .claude/agents/reviewer.md .specs/kit/playbooks/setup.md .specs/spec-kit.json .cursor/rules/spec-first.mdc .claude/skills/spec-first/SKILL.md .git/hooks/pre-commit; do
  [ -e "$P/$f" ] || fail "missing $f"
done
grep -qx "report.html" "$P/.specs/.gitignore" && [ "$(grep -c report.html "$P/.specs/.gitignore")" = 1 ] || fail ".specs/.gitignore line"
[ ! -e "$P/.specs/kit/scripts/install.py" ] || fail "installer copied into project"

mkdir -p "$P/.claude/agents"; echo "mine" > "$P/.claude/agents/planner.md"; "$KIT/install.sh" "$P" --agents=claude,codex,cursor >/dev/null
grep -q "^mine$" "$P/.claude/agents/planner.md" || fail "user agent overwritten"; rm "$P/.claude/agents/planner.md"; "$KIT/install.sh" "$P" --agents=claude,codex,cursor >/dev/null

echo "3. hook warns on code without spec change"
echo "x" > "$P/src/a.java"; gitq -C "$P" add src/a.java
out=$(cd "$P" && python3 .specs/kit/scripts/spec_sync_check.py); echo "$out" | grep -q "spec-sync WARN" || fail "no warning: $out"
gitq -C "$P" commit -m "code only"

echo "4. lint in a fresh install: setup-incomplete warning, exit 0"
out=$(python3 "$P/.specs/kit/scripts/spec_lint.py"); echo "$out" | grep -q "setup incomplete" || fail "no setup warning"

echo "5. multi-repo workspace: no hook, spec_sync off"
W="$TMP/ws"; mkdir -p "$W/svc-a" "$W/svc-b"; gitq -C "$W/svc-a" init; gitq -C "$W/svc-b" init
out=$("$KIT/install.sh" "$W"); echo "$out" | grep -q "multi-repo workspace" || fail "workspace not detected"
grep -q '"spec_sync": "off"' "$W/.specs/spec-kit.json" || fail "spec_sync not off"

echo "5b. agent override: codex only gets no Claude files"
C="$TMP/codex"; mkdir -p "$C"; gitq -C "$C" init
"$KIT/install.sh" "$C" --agents=codex >/dev/null
[ -e "$C/.agents/skills/spec-first/SKILL.md" ] && [ ! -e "$C/CLAUDE.md" ] && [ ! -e "$C/.claude" ] || fail "codex-only install"
grep -q "{{KIT_HOME}}" "$C/.agents/skills/spec-first/SKILL.md" && fail "KIT_HOME not substituted" || true

echo "5c. no agent files in the project: nothing agent-specific wired, profile seeded"
N="$TMP/plain"; mkdir -p "$N"; gitq -C "$N" init
"$KIT/install.sh" "$N" >/dev/null
[ ! -e "$N/CLAUDE.md" ] && [ ! -e "$N/.claude" ] && [ ! -e "$N/.agents" ] || fail "machine-only detection wired agents"
grep -q "status: setup-incomplete" "$N/.specs/steering/project-profile.md" || fail "profile not seeded"

echo "5d. antigravity detected from project files"
A="$TMP/agy"; mkdir -p "$A/.agents/rules"; gitq -C "$A" init
"$KIT/install.sh" "$A" --detect | grep -q "agents: antigravity" || fail "antigravity not detected"

echo "5e. citations: a range is valid if any cited line has content; a blank single line fails"
R="$TMP/cite"; mkdir -p "$R/.specs/domains/x"; gitq -C "$R" init
printf 'a\n\nb\n' > "$R/f.txt"; gitq -C "$R" add f.txt
printf '`f.txt:2-3`\n' > "$R/.specs/domains/x/design.md"
python3 "$KIT/kit/scripts/spec_lint.py" --specs "$R/.specs" --cites >/dev/null || fail "range with content rejected"
printf '`f.txt:2`\n' > "$R/.specs/domains/x/design.md"
! python3 "$KIT/kit/scripts/spec_lint.py" --specs "$R/.specs" --cites >/dev/null || fail "blank single line accepted"

echo "5f. citations: prefix, alias, multi-range, #L, nested repo, ignore globs"
L() { python3 "$KIT/kit/scripts/spec_lint.py" "$@"; }
V="$TMP/v020"; mkdir -p "$V/.specs/domains/x" "$V/tools/svc/core" "$V/tools/sim" "$V/mirror/core"; gitq -C "$V" init
gitq -C "$V/tools/svc" init; gitq -C "$V/tools/sim" init
seq 1 30 > "$V/tools/svc/core/a.txt"; seq 1 30 > "$V/tools/sim/a.txt"; seq 1 30 > "$V/tools/sim/only.txt"
printf '1\n\n\n4\n' > "$V/tools/svc/core/gaps.txt"; seq 1 5 > "$V/mirror/core/m.txt"; seq 1 5 > "$V/tools/svc/m.txt"
gitq -C "$V" add mirror; gitq -C "$V/tools/svc" add .; gitq -C "$V/tools/sim" add .
D="$V/.specs/domains/x/design.md"; cites() { printf '%s\n' "$1" > "$D"; L --specs "$V/.specs" --cites; }
cites '`svc:core/a.txt:5` `sim:a.txt:30` `core/a.txt:1-3,10,20-25` `core/a.txt#L4` `core/a.txt#L4-L9` `core/a.txt#L4-9`' >/dev/null || fail "(a,c,d) good citations rejected"
cites '`core/a.txt:1-3,31,40-44`' | grep -q "range 31: past end of file" || fail "(b) bad range not named"
cites '`core/gaps.txt:1,2-3`' | grep -q "range 2-3: cited lines are blank" || fail "(b) blank range not named"
cites '`nope:a.txt:1`' | grep -q "unknown repo prefix 'nope'" || fail "(a) unknown prefix passed"
cites '`a.txt:1`' | grep -q "ambiguous" || fail "(e) ambiguity not reported"
printf '{"cite_aliases": {"NS": "tools/sim"}, "cite_ignore_globs": ["tools/sim/*"]}\n' > "$V/.specs/spec-kit.json"
cites '`NS:only.txt:2` `a.txt:1`' >/dev/null || fail "(a,e) alias or ignore-glob tie-break"
cites '`m.txt:2`' | grep -q "ambiguous" || fail "(e) unrelated glob resolved an ambiguity"
printf '{"cite_ignore_globs": ["mirror/*"]}\n' > "$V/.specs/spec-kit.json"
cites '`m.txt:1`' >/dev/null || fail "(e) tie-break"
printf '{"cite_ignore_globs": ["*m.txt"]}\n' > "$V/.specs/spec-kit.json"
cites '`m.txt:1`' | grep -q "ambiguous" || fail "(e) tie-break dropped every candidate"
rm "$V/.specs/spec-kit.json"

echo "5f2. elided paths keep their head"
E="$TMP/elide"; mkdir -p "$E/.specs/domains/x" "$E/svc-a/x" "$E/svc-b/x"; gitq -C "$E" init
echo c > "$E/svc-a/x/conf.yml"; echo c > "$E/svc-b/x/conf.yml"; gitq -C "$E" add .
printf '`svc-a/.../conf.yml:1`\n' > "$E/.specs/domains/x/design.md"
L --specs "$E/.specs" --cites >/dev/null || fail "head-elided path did not resolve"
printf '`.../conf.yml:1`\n' > "$E/.specs/domains/x/design.md"
L --specs "$E/.specs" --cites | grep -q ambiguous || fail "headless elision not ambiguous"

echo "5g. drift aging: old open row warns, resolved and null do not; exit code unchanged"
G="$TMP/drift"; mkdir -p "$G/.specs"; gitq -C "$G" init
printf '| # | Sev | Drift | Logged |\n|---|---|---|---|\n| D1 | x | old | 2020-01-01 |\n| D2 | x | gone **RESOLVED** | 2020-01-01 |\n| D3 | x | undated | |\n| D4 | x | fresh | %s |\n' "$(date +%Y-%m-%d)" > "$G/.specs/drift.md"
out=$(L --specs "$G/.specs") || fail "drift aging changed the exit code"
echo "$out" | grep -q "WARN drift drift.md D1: open [0-9]* days" || fail "old row did not warn"
echo "$out" | grep -q "WARN drift drift.md: 1 open row(s) without a Logged date" || fail "undated row did not warn"
echo "$out" | grep -q "D2\|D4" && fail "resolved or fresh row warned" || true
printf '{"drift_max_age_days": null}\n' > "$G/.specs/spec-kit.json"
L --specs "$G/.specs" | grep -q "WARN drift" && fail "null did not switch drift aging off" || true

printf '| # | Sev | Drift |\n|---|---|---|\n| U1 | x | a |\n| U2 | x | b |\n| U3 | x | c **RESOLVED** |\n' > "$G/.specs/nolog.md"
rm "$G/.specs/spec-kit.json"
out=$(L --specs "$G/.specs"); [ "$(echo "$out" | grep -c 'nolog.md')" = 1 ] && echo "$out" | grep -q "nolog.md: 2 open row(s) without a Logged date" || fail "undated rows: want one per-file WARN"
python3 -I "$KIT/kit/scripts/spec_report.py" --specs "$G/.specs" --out "$G/r0.html" >/dev/null
grep -q ">U1<" "$G/r0.html" && grep -q ">U2<" "$G/r0.html" && ! grep -q ">U3<" "$G/r0.html" || fail "report undated rows"
rm "$G/.specs/nolog.md"
printf '{"drift_max_age_days": null}\n' > "$G/.specs/spec-kit.json"

echo "5h. --json parses in both modes, exit codes match"
L --specs "$G/.specs" --json | python3 -c 'import json,sys; json.load(sys.stdin)' || fail "json default"
cites '`core/a.txt:99`' > /dev/null && fail "cites should fail" || true
L --specs "$V/.specs" --cites --json | python3 -c 'import json,sys; d=json.load(sys.stdin); assert d["problems"]' || fail "json cites"
rc=0; L --specs "$V/.specs" --cites --json >/dev/null || rc=$?; [ "$rc" = 1 ] || fail "json cites exit code"

echo "5i. report: written, no script, escapes spec text"
mkdir -p "$G/.specs/features/f-one"
printf '# F\n[REQ-F-01] <b>bold</b>\n' > "$G/.specs/features/f-one/requirements.md"
printf 'REQ-F-01\n' > "$G/.specs/features/f-one/design.md"
printf -- '- [x] 1 a [REQ-F-01]\n- [ ] 2 b <b>x</b> [REQ-F-01]\n' > "$G/.specs/features/f-one/tasks.md"
printf '| # | Drift | Logged |\n|---|---|---|\n| D<b>9</b> | x | 2020-01-01 |\n' > "$G/.specs/drift2.md"
python3 -I "$KIT/kit/scripts/spec_report.py" --specs "$G/.specs" --out "$G/r.html" >/dev/null || fail "report not written"
grep -q "f-one" "$G/r.html" && grep -q "1/2" "$G/r.html" || fail "report lacks feature progress"
grep -q "<script" "$G/r.html" && fail "report has a script" || true
grep -q "<b>9</b>" "$G/r.html" && fail "report did not escape spec text" || true
grep -q "D&lt;b&gt;9" "$G/r.html" || fail "escaped drift id missing"

echo "5j. prefix scope via suffix pool, hidden folder in a nested repo, elision fallback"
mkdir -p "$V/tools/svc/sub" "$V/tools/svc/.github"; seq 1 5 > "$V/tools/svc/sub/b.txt"; seq 1 5 > "$V/tools/svc/.github/ci.yml"; gitq -C "$V/tools/svc" add .
cites '`svc:b.txt:2` `.github/ci.yml:1` `my-repo/.../b.txt:1`' >/dev/null || fail "suffix pool, .github or elision fallback"
cites '`sim:b.txt:2`' | grep -q "no such file" || fail "prefix scope leaked into another repo"
mkdir -p "$V/.venv/pkg"; gitq -C "$V/.venv/pkg" init; seq 1 3 > "$V/.venv/pkg/v.txt"; gitq -C "$V/.venv/pkg" add .
cites '`v.txt:1`' | grep -q "no such file" || fail "hidden folder was indexed"

echo "5k. ragged drift rows, prose does not set status, hostile names, missing specs dir"
K="$TMP/ragged"; mkdir -p "$K/.specs/features/f-two"
printf '| # | Sev | Drift |\n|---|---|---|\n| D1 | hi |\n| D2 |\n' > "$K/.specs/drift.md"
out=$(L --specs "$K/.specs" 2>&1 || true); echo "$out" | grep -q "^spec-lint:" && ! echo "$out" | grep -q Traceback || fail "ragged table crashed lint"
printf '# F\n\nTracker: none.\n\n## Notes\nThe old status: Done flag is gone; unblocked on Monday.\n[REQ-F-02] x\n' > "$K/.specs/features/f-two/requirements.md"
printf 'REQ-F-02\n' > "$K/.specs/features/f-two/design.md"
printf -- '- [x] 1 a [REQ-F-02]\n- [ ] 2 b [REQ-F-02]\n' > "$K/.specs/features/f-two/tasks.md"
mkdir -p "$K/.specs/features/h\"><i>x"
python3 -I "$KIT/kit/scripts/spec_report.py" --specs "$K/.specs" --out "$K/r.html" >/dev/null || fail "report crashed on ragged table"
grep -q 'warn">In progress' "$K/r.html" || fail "prose changed the feature status"
grep -qF '<i>x' "$K/r.html" && fail "hostile folder name not escaped" || true
grep -q 'h%22%3E%3Ci%3Ex' "$K/r.html" && grep -q 'h&quot;&gt;&lt;i&gt;x' "$K/r.html" || fail "hostile name href or text"
rc=0; python3 -I "$KIT/kit/scripts/spec_report.py" --specs "$K/nope" >/dev/null 2>&1 || rc=$?
[ "$rc" = 2 ] && [ ! -e "$K/nope" ] || fail "missing specs dir: want exit 2 and nothing created"

echo "5l. status checks, merged-work detection, linked worktrees and submodules, report badge"
M="$TMP/merged"; mkdir -p "$M/.specs/features/abc-7-x" "$M/.specs/features/abc-70-y" "$M/pkg"; gitq -C "$M" init
F="$M/.specs/features/abc-7-x"; F2="$M/.specs/features/abc-70-y"
cfg() { printf '{"tracker_pattern": "ABC-[0-9]+"%s}\n' "$1" > "$M/.specs/spec-kit.json"; }
req() { printf '# X\n\n%s\n\n[REQ-X-01] a\n' "$1" > "$F/requirements.md"; }
tasks() { printf -- '%s\n' "$1" > "$F/tasks.md"; }
warns() { L --specs "$M/.specs" --json | python3 -c 'import json,sys; d=json.load(sys.stdin); print("\n".join(d["warnings"] + [f["name"] + ": " + w for f in d["features"] for w in f["warns"]]))'; }
cfg ""; req "Status: In progress"; tasks '- [ ] 1 a [REQ-X-01]'; echo REQ-X-01 > "$F/design.md"
printf '# Y\n\nStatus: In progress\n\n[REQ-X-01] a\n' > "$F2/requirements.md"; echo REQ-X-01 > "$F2/design.md"; cp "$F/tasks.md" "$F2/tasks.md"
echo a > "$M/a.txt"; gitq -C "$M" add a.txt; gitq -C "$M" commit -m "feat: thing (ABC-7)"
warns | grep -q "abc-7-x: merged work found (1 commit(s) in .) but the spec says In progress, 0/1 tasks" || fail "merged work not reported: $(warns)"
echo b > "$M/b.txt"; gitq -C "$M" add b.txt; gitq -C "$M" commit -m "feat: other (ABC-70)"
echo c > "$M/c.txt"; gitq -C "$M" add c.txt; gitq -C "$M" commit -m "chore: XABC-7 and ABC-7x are not it"
warns | grep -q "abc-7-x: merged work found (1 commit(s) in .)" || fail "ABC-70 or XABC-7 counted for ABC-7: $(warns)"
warns | grep -q "abc-70-y: merged work found (1 commit(s) in .)" || fail "ABC-70 feature got no warning: $(warns)"
mkdir -p "$M/kid"; gitq -C "$M/kid" init; echo k > "$M/kid/k.txt"; gitq -C "$M/kid" add k.txt; gitq -C "$M/kid" commit -m "kid (ABC-7)"; gitq -C "$M/kid" branch -m trunk
echo s >> "$M/.specs/note.md"; gitq -C "$M" add .specs/note.md; gitq -C "$M" commit -m "docs(specs): ABC-7 spec only"
cfg ', "merged_ref": "main"'
warns | grep -q "abc-7-x: merged work found (1 commit(s) in .)" || fail "spec-only commit counted or repo without merged_ref not skipped: $(warns)"
req "Status: Dropped 2026-01-02 (no)"
warns | grep -q "abc-7-x: merged work" && fail "Dropped feature got a merged-work WARN" || true
req "Status: In progress"; tasks '- [x] 1 a [REQ-X-01]'
warns | grep -q "abc-7-x: all tasks ticked: close out" || fail "no close-out warning"
warns | grep -q "abc-7-x: merged work" && fail "merged warning with a ticked task" || true
req "Status: Done"; warns | grep -q "Done needs a date and a (branch, commit or PR) reference" || fail "Done without a date accepted"
req "Status: Done 2026-01-02"; warns | grep -q "Done needs a date and a" || fail "Done without a reference accepted"
tasks '- [x] 1 a [REQ-X-01]
- [ ] 2 b [REQ-X-01]'
req "Status: Done 2026-01-02 (feat/x)"; warns | grep -q "Status is Done but 1 task(s) are unticked" || fail "unticked tasks under Done"
req "> **Status:** Done 2026-01-02 (PR 3)"; tasks '- [x] 1 a [REQ-X-01]'
warns | grep -q "^abc-7-x: " && fail "clean Done feature warns: $(warns)" || true
req "**Status**: Maybe"; warns | grep -q "unknown status 'Maybe'" || fail "unknown status accepted"
req "Status quo is bad."; warns | grep -q "abc-7-x: no Status line" || fail "'Status quo' read as a status"
req '```
Status: Done 2026-01-02 (x)
```'; warns | grep -q "abc-7-x: no Status line" || fail "fenced Status read"
req "Status:

**Status:** Blocked on y"; warns | grep -Eq "abc-7-x: (no Status|unknown status)" && fail "empty Status field hid the real one: $(warns)" || true
cfg ', "merged_ref": "main"'; req "Status: Proposed"; tasks '- [ ] 1 a [REQ-X-01]'
python3 -I "$KIT/kit/scripts/spec_report.py" --specs "$M/.specs" --out "$M/r.html" >/dev/null || fail "report"
grep -q "merged, not closed" "$M/r.html" && grep -q "Merged, not closed" "$M/r.html" || fail "report lacks the merged badge"
rc=0; L --specs "$M/.specs" >/dev/null || rc=$?; [ "$rc" = 0 ] || fail "merged warning changed the exit code"
rc=0; out=$(PATH=/nonexistent "$(command -v python3)" "$KIT/kit/scripts/spec_lint.py" --specs "$M/.specs") || rc=$?
[ "$rc" = 0 ] && echo "$out" | grep -q "WARN merged-work check skipped: git not available or timed out" || fail "missing git: $out"
printf '{"tracker_pattern": "ABC-["}\n' > "$M/.specs/spec-kit.json"
rc=0; out=$(L --specs "$M/.specs") || rc=$?
[ "$rc" = 0 ] && [ "$(echo "$out" | grep -c 'invalid tracker_pattern')" = 1 ] || fail "invalid tracker_pattern: $out"
mkdir -p "$M/pkg"; seq 1 3 > "$M/pkg/w.txt"; gitq -C "$M" add pkg/w.txt; gitq -C "$M" commit -m "add w"
gitq -C "$M" worktree add "$M/wt" -b side; [ -e "$M/wt/.git" ] && [ -e "$M/wt/pkg/w.txt" ] || fail "worktree not created"
printf '`w.txt:2`\n' > "$M/.specs/domains.md"
L --specs "$M/.specs" --cites >/dev/null || fail "linked worktree made a citation ambiguous"
mkdir -p "$M/libx" "$M/.git/modules"; git -c init.defaultBranch=main init -q --separate-git-dir "$M/.git/modules/libx" "$M/libx"
grep -q "/.git/modules/libx" "$M/libx/.git" || fail "fake submodule not created"
echo l > "$M/libx/l.txt"; gitq -C "$M/libx" add l.txt
printf '`libx:l.txt:1`\n' > "$M/.specs/domains.md"
L --specs "$M/.specs" --cites >/dev/null || fail "submodule-style repo not indexed"

echo "6. uninstall keeps user content"
printf 'mine\n' >> "$P/.specs/.gitignore"; "$KIT/install.sh" "$P" --agents=claude,codex,cursor >/dev/null
[ "$(grep -c report.html "$P/.specs/.gitignore")" = 1 ] && grep -qx mine "$P/.specs/.gitignore" || fail "re-install changed .gitignore"
"$KIT/install.sh" "$P" --uninstall >/dev/null
[ ! -e "$P/.agents/skills/spec-first" ] || fail "codex skill left"
[ ! -e "$P/.specs/kit" ] && [ ! -e "$P/AGENTS.md" ] && [ ! -e "$P/.claude/agents/reviewer.md" ] && [ ! -e "$P/.git/hooks/pre-commit" ] || fail "uninstall left kit files"
grep -qx mine "$P/.specs/.gitignore" && ! grep -q report.html "$P/.specs/.gitignore" || fail ".gitignore after uninstall"
grep -q "keep me" "$P/CLAUDE.md" && ! grep -q "specter" "$P/CLAUDE.md" || fail "CLAUDE.md not restored"

echo "selftest: OK"
