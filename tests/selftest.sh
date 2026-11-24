#!/bin/sh
# Self-test: example specs lint clean; decisions, ids and denylist; gates.py; install is idempotent; hook warns; multi-repo skips the hook; uninstall is clean.
set -eu
KIT=$(cd "$(dirname "$0")/.." && pwd)
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
mkdir -p "$TMP/home"; export HOME="$TMP/home" GIT_CONFIG_NOSYSTEM=1  # the developer's real ~/.claude/agents must not change outcomes
fail() { echo "FAIL: $*"; exit 1; }
gitq() { git -c user.name=t -c user.email=t@t -c init.defaultBranch=main "$@" >/dev/null; }

echo "1. example specs lint clean"
python3 "$KIT/kit/scripts/spec_lint.py" --specs "$KIT/examples/acme-shop/.specs" >/dev/null || fail "example lint"
python3 "$KIT/kit/scripts/spec_lint.py" --specs "$KIT/examples/acme-shop/.specs" --cites >/dev/null || fail "acme citations"

echo "1b. cite-demo: two citations fail on purpose, exit 1"
out=$(python3 "$KIT/kit/scripts/spec_lint.py" --specs "$KIT/examples/cite-demo/.specs" --cites) && fail "cite-demo passed"
echo "$out" | grep -q "OrderService.java:142.* past end of file (39 lines)" || fail "cite-demo past-end: $out"
echo "$out" | grep -q "RateLimiter.java:12.* no such file" || fail "cite-demo no-such-file: $out"
echo "$out" | grep -q "2 FAIL of 3 citation(s)" || fail "cite-demo count: $out"

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
gitq -C "$M" tag v1; cfg ', "merged_ref": "v1"'; rc=0; out=$(L --specs "$M/.specs") || rc=$?
[ "$rc" = 0 ] && echo "$out" | grep -q "WARN merged-work check skipped in .: merged_ref v1 is a tag" || fail "a refused merged_ref was skipped silently: $out"
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

echo "7. adopt: existing .specs untouched, dry run writes nothing, user-level agent kept, foreign kit refused, history demoted"
X="$TMP/adopt"; mkdir -p "$X/.specs/features/a-1" "$X/.specs/steering" "$X/.claude"; gitq -C "$X" init
printf '# Mine\n\nStatus: Proposed\n\n[REQ-A-01] x\n' > "$X/.specs/features/a-1/requirements.md"
printf '# Rules\nmine\n' > "$X/.specs/steering/spec-rules.md"; printf '# Specs\n' > "$X/.specs/README.md"
printf 'no trailing newline' > "$X/AGENTS.md"
xsnap() { (cd "$X" && find . -path ./.git -prune -o -type f -print | sort | xargs shasum | shasum); }
mkdir -p "$HOME/.claude/agents"; echo "mine" > "$HOME/.claude/agents/planner.md"
before=$(xsnap); (cd "$X" && find . -path ./.git -prune -o -type f -print | sort | xargs shasum) > "$TMP/x.before"
out=$("$KIT/install.sh" "$X" --dry-run) || fail "dry run failed"
[ "$before" = "$(xsnap)" ] || fail "dry run wrote a file"
[ ! -e "$X/.specs/kit" ] && [ ! -e "$X/.git/hooks/pre-commit" ] && [ ! -e "$X/.claude/skills" ] && [ ! -e "$X/.specs/.gitignore" ] || fail "dry run created paths"
echo "$out" | grep -q "mode: adopt" && echo "$out" | grep -q "create .specs/kit" && echo "$out" | grep -q "modify .*AGENTS.md" || fail "dry run list: $out"
echo "$out" | grep -q "user-level planner agent found: kept yours, project copy skipped" || fail "dry run silent on user-level agent"
out=$("$KIT/install.sh" "$X") || fail "adopt install failed"
echo "$out" | grep -q "mode: adopt" || fail "adopt not announced"
(cd "$X" && sort "$TMP/x.before" | while read -r sum file; do printf '%s  %s\n' "$sum" "$file"; done | grep -v 'AGENTS.md' | shasum -c - >/dev/null) || fail "an existing file changed"
head -c 19 "$X/AGENTS.md" | grep -q "no trailing newline" && grep -q "specter:begin" "$X/AGENTS.md" || fail "AGENTS.md not append-only"
grep -q "^status: active" "$X/.specs/steering/project-profile.md" && grep -q "^adopted: " "$X/.specs/steering/project-profile.md" || fail "adopt profile"
[ ! -e "$X/.claude/agents/planner.md" ] && [ -e "$X/.claude/agents/reviewer.md" ] || fail "user-level agent shadowed or reviewer missing"
[ "$(cd "$X" && find .specs -type f -not -path '.specs/kit/*' | sort | tr '\n' ' ')" = ".specs/.gitignore .specs/features/a-1/requirements.md .specs/README.md .specs/spec-kit.json .specs/steering/project-profile.md .specs/steering/spec-rules.md " ] || fail "unexpected files under .specs"
rc=0; python3 "$X/.specs/kit/scripts/spec_lint.py" --specs "$X/.specs" >/dev/null || rc=$?; [ "$rc" = 1 ] || fail "incomplete live feature should FAIL"
printf '# Mine\n\nStatus: Done 2026-01-01 (x)\n\n[REQ-A-01] x\n' > "$X/.specs/features/a-1/requirements.md"
out=$(python3 "$X/.specs/kit/scripts/spec_lint.py" --specs "$X/.specs") || fail "history FAIL not demoted: $out"
echo "$out" | grep -q "WARN history: missing design.md" || fail "no history WARN: $out"
out=$("$KIT/install.sh" "$X") && echo "$out" | grep -q "mode:" && fail "re-install announced a mode" || true
F2="$TMP/foreign"; mkdir -p "$F2/.specs/kit"; echo keep > "$F2/.specs/kit/theirs.txt"
rc=0; out=$("$KIT/install.sh" "$F2" 2>&1) || rc=$?
[ "$rc" = 2 ] && echo "$out" | grep -q "isn't specter's" && [ "$(find "$F2" -type f | wc -l | tr -d ' ')" = 1 ] || fail "foreign kit: rc=$rc $out"
rc=0; "$KIT/install.sh" "$F2" --dry-run >/dev/null 2>&1 || rc=$?; [ "$rc" = 2 ] || fail "foreign kit dry run"
rc=0; "$KIT/install.sh" "$X" --uninstall --dry-run >/dev/null || rc=$?; [ "$rc" = 2 ] && [ -e "$X/.specs/kit" ] || fail "uninstall --dry-run must refuse"
H="$TMP/fresh-force"; mkdir -p "$H/.specs/steering"; gitq -C "$H" init
"$KIT/install.sh" "$H" --fresh >/dev/null; grep -q "status: setup-incomplete" "$H/.specs/steering/project-profile.md" || fail "--fresh did not force fresh"

echo "8. review round: links under Done, config and .gitignore kept, hook, ownership, byte-exact uninstall"
printf '# Mine\n\nStatus: Done 2026-01-01 (x)\n\n[REQ-A-01] x [gone](nope.md)\n' > "$X/.specs/features/a-1/requirements.md"
rc=0; out=$(python3 "$X/.specs/kit/scripts/spec_lint.py" --specs "$X/.specs") || rc=$?
[ "$rc" = 1 ] && echo "$out" | grep -q "FAIL broken link" || fail "broken link under a Done feature must still FAIL"
Y="$TMP/partial"; mkdir -p "$Y/.specs/features" "$Y/src"; gitq -C "$Y" init
printf '{"tracker_pattern":"ABC-[0-9]+"}' > "$Y/.specs/spec-kit.json"; printf 'foo' > "$Y/.specs/.gitignore"
cp "$Y/.specs/spec-kit.json" "$TMP/y.json"
"$KIT/install.sh" "$Y" >/dev/null
cmp -s "$Y/.specs/spec-kit.json" "$TMP/y.json" || fail "existing spec-kit.json rewritten"
[ ! -e "$Y/.git/hooks/pre-commit" ] || fail "adopt installed a hook without --hook"
echo a > "$Y/src/a.java"; gitq -C "$Y" add src/a.java; gitq -C "$Y" commit -m "code" || fail "commit blocked after adopting a partial spec-kit.json"
g1=$(shasum < "$Y/.specs/.gitignore"); "$KIT/install.sh" "$Y" >/dev/null
cmp -s "$Y/.specs/spec-kit.json" "$TMP/y.json" && [ "$g1" = "$(shasum < "$Y/.specs/.gitignore")" ] || fail "second install changed spec-kit.json or .gitignore"
[ ! -e "$Y/.git/hooks/pre-commit" ] || fail "re-installing an adopted project added a hook without --hook"
"$KIT/install.sh" "$Y" --hook >/dev/null; [ -x "$Y/.git/hooks/pre-commit" ] || fail "--hook did not install the hook"
echo b > "$Y/src/b.java"; gitq -C "$Y" add src/b.java; gitq -C "$Y" commit -m "code 2" || fail "hook crashed on a partial spec-kit.json"
"$KIT/install.sh" "$Y" --uninstall >/dev/null
printf 'foo' > "$TMP/y.gi"
cmp -s "$Y/.specs/spec-kit.json" "$TMP/y.json" && cmp -s "$Y/.specs/.gitignore" "$TMP/y.gi" || fail "uninstall touched the user's config or .gitignore"
Z="$TMP/owned"; mkdir -p "$Z/.claude/skills/spec-first" "$Z/.cursor/rules" "$Z/.claude/agents"; gitq -C "$Z" init
echo mine > "$Z/.claude/skills/spec-first/SKILL.md"; echo mine > "$Z/.cursor/rules/spec-first.mdc"; echo mine > "$Z/.claude/agents/generator.md"
out=$("$KIT/install.sh" "$Z" --agents=claude,cursor)
for f in .claude/skills/spec-first/SKILL.md .cursor/rules/spec-first.mdc .claude/agents/generator.md; do
  [ "$(cat "$Z/$f")" = mine ] && echo "$out" | grep -q "$f exists and is yours: kept it" || fail "user-owned $f not kept"
done
echo "$out" | grep -q "agents: reviewer (sub" || fail "summary lists agents it did not write: $out"
echo "$out" | grep -q "skill spec-first -> .claude" && fail "summary claims a skill it did not write" || true
"$KIT/install.sh" "$Z" --uninstall >/dev/null
for f in .claude/skills/spec-first/SKILL.md .cursor/rules/spec-first.mdc .claude/agents/generator.md; do
  [ "$(cat "$Z/$f")" = mine ] || fail "uninstall removed user-owned $f"
done
W="$TMP/bytes"; mkdir -p "$W"; gitq -C "$W" init
printf 'a\r\nb' > "$W/AGENTS.md"; printf '\n\n# x\n\n' > "$W/CLAUDE.md"; cp "$W/AGENTS.md" "$TMP/w.agents"; cp "$W/CLAUDE.md" "$TMP/w.claude"
"$KIT/install.sh" "$W" --agents=claude >/dev/null; grep -q "specter:begin" "$W/AGENTS.md" || fail "block not added"
"$KIT/install.sh" "$W" --uninstall >/dev/null
cmp -s "$W/AGENTS.md" "$TMP/w.agents" && cmp -s "$W/CLAUDE.md" "$TMP/w.claude" || fail "install then uninstall changed AGENTS.md or CLAUDE.md bytes"
V="$TMP/foreignkit"; mkdir -p "$V/.specs/kit"; echo keep > "$V/.specs/kit/theirs.txt"; printf 'report.html\n' > "$V/.specs/.gitignore"
"$KIT/install.sh" "$V" --uninstall >/dev/null
[ -e "$V/.specs/kit/theirs.txt" ] && grep -qx report.html "$V/.specs/.gitignore" || fail "uninstall removed a foreign kit or the user's report.html line"
V2="$TMP/halfkit"; mkdir -p "$V2/.specs/kit"; echo 0.1.0 > "$V2/.specs/kit/VERSION"; echo theirs > "$V2/.specs/kit/AGENT_RULES.md"
rc=0; "$KIT/install.sh" "$V2" >/dev/null 2>&1 || rc=$?; [ "$rc" = 2 ] && [ "$(cat "$V2/.specs/kit/AGENT_RULES.md")" = theirs ] || fail "foreign kit with only a VERSION file"
H3="$TMP/fresh2"; mkdir -p "$H3/.specs/steering"; "$KIT/install.sh" "$H3" --fresh --dry-run | grep -q "forced by --fresh" || fail "--fresh claims no spec system"
Y2="$TMP/p2"; mkdir -p "$Y2/.specs/steering"; gitq -C "$Y2" init
"$KIT/install.sh" "$Y2" --from-go | grep -q "Setup interview skipped" || fail "--from-go in adopt mode"

echo "9. rollback safety: edited config kept, version bump keeps config, byte-exact empty files, empty dirs, config types"
N2="$TMP/seed-clean"; mkdir -p "$N2"; gitq -C "$N2" init; "$KIT/install.sh" "$N2" --agents=claude >/dev/null
"$KIT/install.sh" "$N2" --uninstall >/dev/null
[ ! -e "$N2/.specs/spec-kit.json" ] && [ ! -e "$N2/.specs/steering/project-profile.md" ] && [ ! -e "$N2/AGENTS.md" ] && [ ! -e "$N2/CLAUDE.md" ] && [ ! -e "$N2/.specs/.gitignore" ] || fail "uninstall left files it created"
[ ! -d "$N2/.claude" ] && [ ! -d "$N2/.specs/steering" ] || fail "uninstall left empty directories"
N3="$TMP/seed-edit"; mkdir -p "$N3"; gitq -C "$N3" init; "$KIT/install.sh" "$N3" >/dev/null
sed 's/"spec_sync": "warn"/"spec_sync": "block"/' "$N3/.specs/spec-kit.json" > "$TMP/n3.json"; cmp -s "$TMP/n3.json" "$N3/.specs/spec-kit.json" && fail "test setup: spec_sync not edited"
cp "$TMP/n3.json" "$N3/.specs/spec-kit.json"; "$KIT/install.sh" "$N3" --uninstall >/dev/null
cmp -s "$TMP/n3.json" "$N3/.specs/spec-kit.json" || fail "uninstall removed an edited config"
Q="$TMP/bump"; mkdir -p "$Q/.specs/features"; gitq -C "$Q" init; printf '{ "drift_max_age_days" : 5 }' > "$Q/.specs/spec-kit.json"; cp "$Q/.specs/spec-kit.json" "$TMP/q.json"
"$KIT/install.sh" "$Q" >/dev/null; echo 0.0.1 > "$Q/.specs/kit/VERSION"; "$KIT/install.sh" "$Q" | grep -q "upgrade 0.0.1" || fail "version bump not seen"
cmp -s "$Q/.specs/spec-kit.json" "$TMP/q.json" || fail "version-bump re-install rewrote spec-kit.json"
E="$TMP/empties"; mkdir -p "$E/.specs"; gitq -C "$E" init; : > "$E/AGENTS.md"; printf '\r\n' > "$E/CLAUDE.md"; : > "$E/.specs/.gitignore"
printf '' > "$TMP/e.empty"; printf '\r\n' > "$TMP/e.crlf"
"$KIT/install.sh" "$E" --agents=claude >/dev/null; grep -q "specter:begin" "$E/AGENTS.md" || fail "block not added to an empty file"
"$KIT/install.sh" "$E" --uninstall >/dev/null
cmp -s "$E/AGENTS.md" "$TMP/e.empty" && cmp -s "$E/CLAUDE.md" "$TMP/e.crlf" && cmp -s "$E/.specs/.gitignore" "$TMP/e.empty" || fail "empty or whitespace-only files not restored byte for byte"
Z2="$TMP/skill2"; mkdir -p "$Z2/.claude/skills/spec-first"; gitq -C "$Z2" init
printf -- '---\nname: spec-first\n---\nuses .specs/kit/ but has no kit source line\n' > "$Z2/.claude/skills/spec-first/SKILL.md"; cp "$Z2/.claude/skills/spec-first/SKILL.md" "$TMP/z2.md"
"$KIT/install.sh" "$Z2" --agents=claude >/dev/null; cmp -s "$Z2/.claude/skills/spec-first/SKILL.md" "$TMP/z2.md" || fail "skill without the Kit source line was replaced"
S2="$TMP/badcfg"; mkdir -p "$S2/.specs/features" "$S2/src"; gitq -C "$S2" init; "$KIT/install.sh" "$S2" --hook >/dev/null
for body in 'null' '[1]' '"str"' '{"code_globs": null}' '{"spec_sync": 5}' '{"code_globs": [1]}' '[["spec_sync","block"],["code_globs",["src/*"]]]'; do
  printf '%s' "$body" > "$S2/.specs/spec-kit.json"; echo "$body" > "$S2/src/f.java"; gitq -C "$S2" add src/f.java
  gitq -C "$S2" commit -m "c" 2>/dev/null || fail "hook blocked a commit on config $body"
done

echo "10. multi-line tasks: a REQ on a continuation line or a nested sub-item links the task"
T10="$TMP/t10/.specs/features/m-1"; mkdir -p "$T10"
printf '# m\n\n- [REQ-M-01] a\n' > "$T10/requirements.md"; printf 'REQ-M-01\n' > "$T10/design.md"
printf '%b\n' '- [ ] 1 wrapped task' '  continues here — [REQ-M-01]' '- [ ] 2 parent' '  - [ ] 2a child — [REQ-M-01]' '- [ ] 3 bare task' '' '  not part of task 3 [REQ-M-01]' '- [ ] 4 issue ref' '  #12 follow-up [REQ-M-01]' '\t- [ ] 5 tabbed' '\t\tcontinued [REQ-M-01]' > "$T10/tasks.md"
out=$(L --specs "$TMP/t10/.specs")
echo "$out" | grep -q "1 task(s) without a REQ link, e.g. '- \[ \] 3 bare task'" || fail "multi-line tasks: $out"

echo "11. decisions log, cited ids, denylist, gates.py, 0.4.1-shaped project"
S="$TMP/t11/.specs"; mkdir -p "$S/features/d-1" "$S/steering" "$S/system"
printf '# d\n\nStatus: In progress\n\n### [REQ-DL-01] a\n\nLands D-1.\n\n### [REQ-DL-02] b\n\nNo back-link.\n' > "$S/features/d-1/requirements.md"
printf 'REQ-DL-01 REQ-DL-02\n' > "$S/features/d-1/design.md"; printf -- '- [ ] 1 a [REQ-DL-01] [REQ-DL-02]\n' > "$S/features/d-1/tasks.md"
printf 'See D-9 and the Zork.io gateway at Big Corp.\n' > "$S/system/notes.md"
out=$(L --specs "$S") || fail "0.4.1-shaped project (no decisions file, no denylist) no longer exits 0: $out"
echo "$out" | grep -v "^spec-lint:" | grep -q "FAIL\|D-9\|denylist" && fail "0.4.1-shaped project got a new FAIL: $out" || true
printf 'Cites REQ-DL-77.\n' >> "$S/system/notes.md"
out=$(L --specs "$S") || fail "unresolved REQ outside a feature must not FAIL"
echo "$out" | grep -q "WARN REQ-DL-77 is cited but defined in no requirements.md: system/notes.md:2$" || fail "unresolved REQ not warned: $out"
DEC="$S/steering/decisions.md"; deccfg() { printf '{"decisions": {"backlinks": %s}%s}\n' "$1" "${2:-}" > "$S/spec-kit.json"; }
printf '# Decisions\n\n| ID | Decision | Why | Where it lands | Supersedes |\n|---|---|---|---|---|\n| D-1 | x | y | REQ-DL-01, REQ-DL-02 | |\n' > "$DEC"
rc=0; out=$(L --specs "$S") || rc=$?
[ "$rc" = 1 ] && echo "$out" | grep -q "FAIL system/notes.md:1: D-9 is cited but has no row in steering/decisions.md" || fail "unresolved D- id: rc=$rc $out"
printf 'See D-1.\n' > "$S/system/notes.md"; out=$(L --specs "$S") || fail "resolved D- id still fails: $out"
echo "$out" | grep -q "back-link" && fail "back-links checked while off: $out" || true
deccfg '"warn"'; out=$(L --specs "$S") || fail "backlinks warn changed the exit code"
echo "$out" | grep -q "WARN features/d-1/requirements.md:9: REQ-DL-02 does not cite D-1, which lands on it" || fail "back-link warn: $out"
echo "$out" | grep -q "REQ-DL-01 does not cite" && fail "present back-link reported: $out" || true
deccfg true; rc=0; out=$(L --specs "$S") || rc=$?; [ "$rc" = 1 ] && echo "$out" | grep -q "FAIL features/d-1/requirements.md:9: REQ-DL-02 does not cite D-1" || fail "back-link fail: rc=$rc $out"
deccfg false; printf '| D-2 | x | y | REQ-DL-99 | |\n' >> "$DEC"
rc=0; out=$(L --specs "$S") || rc=$?; [ "$rc" = 1 ] && echo "$out" | grep -q "FAIL steering/decisions.md:6: D-2 lands on REQ-DL-99, which no requirements.md defines" || fail "undefined landing REQ: rc=$rc $out"
printf '| D-3 | x | y | REQ-DL-01 | D-2 |\n' >> "$DEC"; out=$(L --specs "$S") || fail "superseded row still checked: $out"
Z1=$(printf %s zork | shasum -a 256 | cut -c1-64); Z2=$(printf %s big-corp | shasum -a 256 | cut -c1-64); [ "$(L --hash-term "Big Corp")" = "$Z2" ] || fail "--hash-term pair"
[ "$(L --hash-term ZORK)" = "$Z1" ] || fail "--hash-term digest"
printf 'See D-1, the Zork.io gateway at Big Corp.\n' > "$S/system/notes.md"; deccfg false ", \"denylist_sha256\": [\"$Z1\", \"$Z2\"]"
rc=0; out=$(L --specs "$S") || rc=$?
[ "$rc" = 1 ] && echo "$out" | grep -q "FAIL system/notes.md:1: denylisted term (token #5)" && echo "$out" | grep -q "denylisted term (token #8)" || fail "denylist: rc=$rc $out"
echo "$out" | grep -qi "zork\|big" && fail "denylist echoed the term: $out" || true
GT="$TMP/t11g"; mkdir -p "$GT/.specs/steering"; gitq -C "$GT" init; echo x > "$GT/x"; gitq -C "$GT" add x; gitq -C "$GT" commit -m x
GR="$GT/.specs/steering/spec-rules.md"; gates() { python3 "$KIT/kit/scripts/gates.py" --specs "$GT/.specs" "$@"; }
printf '## Gates\n\n| # | Gate | Command |\n|---|---|---|\n| G1 | ok | `echo first ok` |\n| G2 | bad | `echo broke; exit 3` |\n| G3 | never | `touch ran3` |\n' > "$GR"
rc=0; out=$(gates 2>&1) || rc=$?
[ "$rc" = 1 ] && echo "$out" | grep -q "GATE FAILED: G2 bad (exit 3)" && echo "$out" | grep -q broke && [ ! -e "$GT/ran3" ] || fail "gates.py did not stop at G2: rc=$rc $out"
out=$(gates 2>/dev/null) && fail "red run exited 0" || true
printf '### Gates\n- G1 ok: pass (first ok)\n- G2 bad: FAIL (exit 3)\n- G3 never: not run\n' > "$TMP/g.want"; echo "$out" | head -4 | cmp -s - "$TMP/g.want" || fail "red gates block on stdout: $out"
echo "$out" | tail -1 | grep -qx -- "- verdict: not ready (1 failed, 1 not run)" || fail "red verdict: $out"
printf '| # | Gate | Command |\n|---|---|---|\n| G1 | ok | `echo one` |\n| G2 | pipe | `printf "a\\n\\n" && echo x \\| tr x y` |\n' > "$GR"
out=$(gates 2>/dev/null) || fail "gates.py failed a green table"
printf '### Gates\n- G1 ok: pass (one)\n- G2 pipe: pass (y)\n' > "$TMP/g.want"; echo "$out" | head -3 | cmp -s - "$TMP/g.want" || fail "gates block: $out"
echo "$out" | tail -1 | grep -qx -- "- verdict: ready (2 passed)" || fail "gates verdict: $out"
echo "$out" | grep -Eq "^- commit: [0-9a-f]{7,}\+dirty$" || fail "gates commit line: $out"
gitq -C "$GT" add -A; gitq -C "$GT" commit -qm rules
printf '| # | Gate | Command |\n|---|---|---|\n| G1 | ok | `echo fine` |\n' > "$GR"; gitq -C "$GT" commit -qam ok
out=$(gates 2>/dev/null) && echo "$out" | grep -Eq "^- commit: [0-9a-f]{7,}$" && ! echo "$out" | grep -q "tree changed" || fail "gates: a clean run is not clean: $out"
printf '| # | Gate | Command |\n|---|---|---|\n| G1 | fmt | `echo y > x; echo formatted` |\n' > "$GR"; gitq -C "$GT" commit -qam fmt
out=$(gates 2>/dev/null); echo "$out" | grep -Eq "^- commit: [0-9a-f]{7,}\+dirty$" && echo "$out" | grep -qx -- "- tree changed during gates" || fail "gates: a gate that rewrote a file left the block clean: $out"
gitq -C "$GT" reset -q --hard
printf '| # | Gate | Command |\n|---|---|---|\n| G1 | ok | `touch ran1` |\n| G2 | prose | run the tests |\n' > "$GR"
rc=0; out=$(gates 2>&1) || rc=$?; [ "$rc" = 2 ] && [ ! -e "$GT/ran1" ] && echo "$out" | grep -q "G2" || fail "row without a command: rc=$rc $out"
printf '| # | Gate | Command |\n|---|---|---|\n| G1 | tests | `<exact command>` |\n' > "$GR"
rc=0; out=$(gates 2>&1) || rc=$?; [ "$rc" = 2 ] && echo "$out" | grep -q "template placeholder" || fail "placeholder ran: rc=$rc $out"
printf '# no table\n' > "$GR"; rc=0; out=$(gates 2>&1) || rc=$?; [ "$rc" = 2 ] && echo "$out" | grep -q "no Gates table" || fail "missing table: rc=$rc $out"
rm "$GR"; rc=0; gates >/dev/null 2>&1 || rc=$?; [ "$rc" = 2 ] || fail "missing spec-rules.md: rc=$rc"

echo "12. review round: other-format decisions.md, D- id bounds, strict config, REQ WARN shape, sub-headings, hash-term, gates.py args"
S="$TMP/t12/.specs"; mkdir -p "$S/features/d-1" "$S/steering" "$S/system"; DEC="$S/steering/decisions.md"
printf '# d\n\nStatus: In progress\n\n### [REQ-D-01] a\n\n#### Acceptance\n\nLands D-1.\n' > "$S/features/d-1/requirements.md"
printf 'REQ-D-01\n' > "$S/features/d-1/design.md"; printf -- '- [ ] 1 a [REQ-D-01]\n' > "$S/features/d-1/tasks.md"
printf '# Decisions\n\nWe chose Postgres. D-DAY, D-1 and D-7 came up.\n\n| ID | Decision | Date |\n|---|---|---|\n| D-7 | x | 2026-01-01 |\n' > "$DEC"
out=$(L --specs "$S") || fail "decisions.md in another format changed the exit code: $out"
echo "$out" | grep -q "has no row" && fail "decisions.md without a decision row was checked: $out" || true
printf '| ID | Decision | Why | Where it lands | Supersedes |\n|---|---|---|---|---|\n| D-1 | x | y | REQ-D-01 | |\n' > "$DEC"
printf 'Not ids: [REQ-D-01] ADR-D-1 TLS-D-9 PO-D-3 D-1.md D-DAY D-ROM. Ids: D-9, D-N7 and D-R2C5.\n' > "$S/system/notes.md"
rc=0; out=$(L --specs "$S") || rc=$?; [ "$rc" = 1 ] || fail "unresolved ids passed: $out"
for d in D-9 D-N7 D-R2C5; do echo "$out" | grep -q "notes.md:1: $d is cited" || fail "$d not seen: $out"; done
[ "$(echo "$out" | grep -c 'is cited but has no row')" = 3 ] || fail "D- matched inside another id or a file name: $out"
printf '{"decisions": {"enabled": false}}\n' > "$S/spec-kit.json"; out=$(L --specs "$S") || fail "decisions.enabled false still checks: $out"
printf 'See D-1.\n' > "$S/system/notes.md"; printf '{"decisions": {"backlinks": true}}\n' > "$S/spec-kit.json"
out=$(L --specs "$S") || fail "back-link under a #### sub-heading not found: $out"
for cfg in '{"backlinks": "off"}' '{"backlinks": "false"}' '{"backlinks": 1}' '{"file": 3}' '{"backlink": true}' '{"enabled": "no"}' '[]'; do
  printf '{"decisions": %s}\n' "$cfg" > "$S/spec-kit.json"; rc=0; out=$(L --specs "$S" 2>&1) || rc=$?
  [ "$rc" != 0 ] && echo "$out" | grep -q "spec-kit.json: decisions" || fail "bad decisions config $cfg accepted: rc=$rc $out"
done
printf '{"unresolved_req": "loud"}\n' > "$S/spec-kit.json"; rc=0; L --specs "$S" >/dev/null 2>&1 || rc=$?; [ "$rc" != 0 ] || fail "bad unresolved_req accepted"
rm "$S/spec-kit.json"
printf 'An example: `REQ-OLD-01`.\nREQ-OLD-02\nREQ-OLD-02\nREQ-OLD-02\nREQ-OLD-02\nREQ-OLD-02\n' > "$S/system/old.md"
out=$(L --specs "$S") || fail "unresolved REQ changed the exit code"
echo "$out" | grep -q "REQ-OLD-01" && fail "REQ in inline code warned: $out" || true
[ "$(echo "$out" | grep -c 'REQ-OLD-02')" = 1 ] && echo "$out" | grep -q "WARN REQ-OLD-02 is cited but defined in no requirements.md: system/old.md:2, system/old.md:3, system/old.md:4 and 2 more" || fail "unresolved REQ WARN shape: $out"
printf '{"unresolved_req": "off"}\n' > "$S/spec-kit.json"; out=$(L --specs "$S") || fail "unresolved_req off"
echo "$out" | grep -q "REQ-OLD" && fail "unresolved_req off still warns: $out" || true
rm "$S/spec-kit.json" "$S/system/old.md"
[ "$(L --hash-term Big Corp)" = "$(printf %s big-corp | shasum -a 256 | cut -c1-64)" ] || fail "--hash-term ignored a word"
J=$(printf %s 'josé' | shasum -a 256 | cut -c1-64); [ "$(L --hash-term 'José')" = "$J" ] || fail "--hash-term dropped a non-ASCII letter"
printf 'José came. Jos stayed.\n' > "$S/system/notes.md"; printf '{"denylist_sha256": ["%s"]}\n' "$J" > "$S/spec-kit.json"
out=$(L --specs "$S" 2>&1 || true); echo "$out" | grep -q "notes.md:1: denylisted term (token #1)" && ! echo "$out" | grep -q "token #3" || fail "non-ASCII tokenising: $out"
rm "$S/spec-kit.json"; printf 'See D-1.\n' > "$S/system/notes.md"
C="$TMP/t12c/.specs"; mkdir -p "$C/steering"; CD="$C/steering/decisions.md"
printf '| # | Gate | Command |\n|---|---|---|\n| G1 | Shell syntax | `true` |\n' > "$C/steering/spec-rules.md"
printf '| ID | Decision | Why | Where it lands | Supersedes |\n|---|---|---|---|---|\n| D-1 | a | b | words | |\n' > "$CD"
out=$(L --specs "$C") || fail "decisions without Checked by column changed the exit code: $out"
printf '| ID | Decision | Why | Where it lands | Checked by | Supersedes |\n|---|---|---|---|---|---|\n| D-1 | a | b | words | G1 | |\n| D-2 | a | b | words | | |\n| D-3 | a | b | words | Shell syntax | |\n' > "$CD"
out=$(L --specs "$C") || fail "Checked by naming real gates (G1, Shell syntax) or empty failed: $out"
printf '| D-4 | a | b | words | G9 | |\n' >> "$CD"
rc=0; out=$(L --specs "$C") || rc=$?; [ "$rc" = 1 ] && echo "$out" | grep -q "FAIL steering/decisions.md:6: D-4 is checked by G9, which is no row of the Gates table in steering/spec-rules.md" || fail "unknown Checked by gate: rc=$rc $out"
printf '| D-5 | a | b | words | | D-4 |\n' >> "$CD"; out=$(L --specs "$C") || fail "superseded row's Checked by still checked: $out"
GT="$TMP/t12g"; mkdir -p "$GT/.specs/steering"; gitq -C "$GT" init
printf '| # | Gate | Command |\n|---|---|---|\n| G1 | makes output | `touch out.log; echo made` |\n' > "$GT/.specs/steering/spec-rules.md"
gitq -C "$GT" add .; gitq -C "$GT" commit -m x
gates() { python3 "$KIT/kit/scripts/gates.py" --specs "$GT/.specs" "$@"; }
for a in --bogus --file=x; do rc=0; out=$(gates "$a" 2>&1) || rc=$?; [ "$rc" = 2 ] && [ ! -e "$GT/out.log" ] || fail "gates.py ran with unknown argument $a: rc=$rc $out"; done
rc=0; out=$(gates --help 2>&1) || rc=$?; [ "$rc" = 0 ] && echo "$out" | grep -q "^Usage:" && [ ! -e "$GT/out.log" ] || fail "gates.py --help: rc=$rc $out"
out=$(gates 2>/dev/null) || fail "gates.py green run"; echo "$out" | grep -Eq "^- commit: [0-9a-f]{7,}\+dirty$" && echo "$out" | grep -qx -- "- tree changed during gates" || fail "commit not read after the gates ran, or untracked gate output not reported: $out"
I="$TMP/t12i"; mkdir -p "$I"; gitq -C "$I" init; "$KIT/install.sh" "$I" >/dev/null
printf '| # | Gate | Command |\n|---|---|---|\n| G1 | where | `pwd -P` |\n' > "$I/.specs/steering/spec-rules.md"
out=$(python3 "$I/.specs/kit/scripts/gates.py" 2>/dev/null) || fail "installed gates.py"; echo "$out" | grep -q "^- G1 where: pass ($(cd "$I" && pwd -P))$" || fail "installed gates.py root: $out"

echo "13. in flight: a worktree branch lists its feature, no git shows one line"
W="$TMP/t13"; mkdir -p "$W/.specs/features/base"; gitq -C "$W" init
printf '# base\n' > "$W/.specs/features/base/requirements.md"; gitq -C "$W" add .; gitq -C "$W" commit -m base
gitq -C "$W" worktree add -b feat-x "$TMP/t13-wt"; mkdir -p "$TMP/t13-wt/.specs/features/xfeat"
printf '# x\n' > "$TMP/t13-wt/.specs/features/xfeat/requirements.md"; gitq -C "$TMP/t13-wt" add .; gitq -C "$TMP/t13-wt" commit -m x
echo dirty > "$TMP/t13-wt/u.txt"
gitq -C "$W" branch lone
gitq -C "$W" worktree add -b fresh "$TMP/t13-fresh"; echo dirty > "$TMP/t13-fresh/f.txt"
python3 -I "$KIT/kit/scripts/spec_report.py" --specs "$W/.specs" --out "$TMP/t13.html" >/dev/null || fail "13: report"
W_HTML="$TMP/t13.html"; rowsof() { sed 's/<tr>/\n&/g' "$1"; }
grep -q "In flight" "$W_HTML" && grep -q ">feat-x<" "$W_HTML" && grep -q "xfeat" "$W_HTML" && grep -q "t13-wt" "$W_HTML" || fail "13: In flight lacks the worktree branch and feature"
rowsof "$W_HTML" | grep ">feat-x<" | grep -q "<td>1</td>" || fail "13: feat-x row lacks the uncommitted count"
rowsof "$W_HTML" | grep -q ">lone<" && fail "13: merged branch lone listed" || true
rowsof "$W_HTML" | grep ">fresh<" | grep -q "<td>1</td>" || fail "13: fresh worktree on a merged commit missing or uncounted"
rowsof "$W_HTML" | grep -q "/t13</td>" && fail "13: clean main checkout listed" || true
grep -q "no git data" "$W_HTML" && fail "13: git reported missing in a repo" || true
D="$TMP/t13d"; mkdir -p "$D/.specs/features/base"; gitq -C "$D" init; printf '# b\n' > "$D/.specs/features/base/requirements.md"; gitq -C "$D" add .; gitq -C "$D" commit -m base
gitq -C "$D" checkout -b side; echo s > "$D/s"; gitq -C "$D" add .; gitq -C "$D" commit -m s; gitq -C "$D" checkout --detach HEAD~1
gitq -C "$D" worktree add --detach "$TMP/t13d-wt"; echo y > "$TMP/t13d-wt/y"; gitq -C "$TMP/t13d-wt" add .; gitq -C "$TMP/t13d-wt" commit -m y
python3 -I "$KIT/kit/scripts/spec_report.py" --specs "$D/.specs" --out "$TMP/t13d.html" >/dev/null || fail "13: report on a detached HEAD"
grep -Eq "\(HEAD|no branch|detached at" "$TMP/t13d.html" && fail "13: detached HEAD leaked into a row" || true
rowsof "$TMP/t13d.html" | grep -q ">side<" && rowsof "$TMP/t13d.html" | grep "t13d-wt" | grep -q "detached " || fail "13: detached worktree row missing"
S="$TMP/t13s"; mkdir -p "$S/sub/.specs/features/base"; gitq -C "$S" init; printf '# b\n' > "$S/sub/.specs/features/base/requirements.md"; gitq -C "$S" add .; gitq -C "$S" commit -m base
gitq -C "$S" checkout -b feat-s; mkdir "$S/sub/.specs/features/sfeat"; printf '# s\n' > "$S/sub/.specs/features/sfeat/requirements.md"; gitq -C "$S" add .; gitq -C "$S" commit -m s; gitq -C "$S" checkout main
python3 -I "$KIT/kit/scripts/spec_report.py" --specs "$S/sub/.specs" --out "$TMP/t13s.html" >/dev/null || fail "13: report with .specs in a subfolder"
rowsof "$TMP/t13s.html" | grep ">feat-s<" | grep -q "sfeat" || fail "13: feature on a branch not listed when .specs is in a subfolder"
echo dirty > "$W/m.txt"; rm -rf "$TMP/t13-fresh"
python3 -I "$KIT/kit/scripts/spec_report.py" --specs "$W/.specs" --out "$TMP/t13b.html" >/dev/null || fail "13: report after rm -rf worktree"
rowsof "$TMP/t13b.html" | grep -q "/t13</td>" || fail "13: dirty main checkout not listed"
rowsof "$TMP/t13b.html" | grep ">fresh<" | grep -q "</td><td>—</td><td>" || fail "13: worktree with its folder removed lacks the dash in Uncommitted"
E="$TMP/t13e"; mkdir -p "$E/.specs/features/base"; gitq -C "$E" init; printf '# b\n' > "$E/.specs/features/base/requirements.md"; gitq -C "$E" add .; gitq -C "$E" commit -m base
gitq -C "$E" worktree add -b feat-e "$TMP/t13e-wt"; echo e > "$TMP/t13e-wt/e"; gitq -C "$TMP/t13e-wt" add .; gitq -C "$TMP/t13e-wt" commit -m e
echo m > "$E/m"; gitq -C "$E" add .; gitq -C "$E" commit -m main-ahead
python3 -I "$KIT/kit/scripts/spec_report.py" --specs "$TMP/t13e-wt/.specs" --out "$TMP/t13e.html" >/dev/null || fail "13: report from a linked worktree"
rowsof "$TMP/t13e.html" | grep -q ">feat-e<" && ! rowsof "$TMP/t13e.html" | grep -q ">main<" || fail "13: run from a linked worktree without origin compared against the worktree's own HEAD"
N="$TMP/t13-norepo"; mkdir -p "$N"; cp -R "$W/.specs" "$N/.specs"
python3 -I "$KIT/kit/scripts/spec_report.py" --specs "$N/.specs" --out "$N/r.html" >/dev/null || fail "13: report outside a repo"
grep -q "no git data" "$N/r.html" && grep -q "<h2>Features</h2>" "$N/r.html" || fail "13: no 'no git data' line outside a repo"

echo "13a. autonomy profile: bad Knowledge link fails the lint; Chores run past a Tiers table; placeholder exits 2; absent profile unchanged"
A="$TMP/t13a"; mkdir -p "$A"; gitq -C "$A" init; "$KIT/install.sh" "$A" >/dev/null
lint13() { python3 "$A/.specs/kit/scripts/spec_lint.py" --specs "$A/.specs" 2>&1; }
rc0=0; lint13 >/dev/null || rc0=$?; [ "$rc0" = 0 ] || fail "13a: a project without autonomy.md does not lint clean: rc=$rc0"
printf '# Autonomy\n\n## Knowledge\n| Knowledge | Where | Read |\n|---|---|---|\n| Decisions | [adrs](../adr-missing/) | before a design |\n' > "$A/.specs/steering/autonomy.md"
rc=0; out=$(lint13) || rc=$?; [ "$rc" != 0 ] && echo "$out" | grep -q "autonomy.md" || fail "13a: a Knowledge link to a missing ADR folder did not fail the lint (rc=$rc): $out"
printf '# Autonomy\n\n## Tiers\n| Tier | Paths |\n|---|---|\n| routine | docs |\n\n## Chores\n| # | Gate | Command |\n|---|---|---|\n| C1 | ran | `echo chore-ran > chore.out` |\n' > "$A/.specs/steering/autonomy.md"
(cd "$A" && python3 .specs/kit/scripts/gates.py --file .specs/steering/autonomy.md >/dev/null 2>&1) && grep -q chore-ran "$A/chore.out" || fail "13a: gates.py --file did not run the Chores table past a Tiers table"
printf '# Autonomy\n\n## Chores\n| # | Gate | Command |\n|---|---|---|\n| C1 | todo | `<command>` |\n' > "$A/.specs/steering/autonomy.md"
rc=0; (cd "$A" && python3 .specs/kit/scripts/gates.py --file .specs/steering/autonomy.md >/dev/null 2>&1) || rc=$?; [ "$rc" = 2 ] || fail "13a: placeholder chore exits $rc, want 2"

echo "13b. tiers.py --check: valid table passes; bad rows exit 2 with file:line; a guarded path in a lower row exits 1; profile read at the base"
B="$TMP/t13b"; mkdir -p "$B"; gitq -C "$B" init; "$KIT/install.sh" "$B" >/dev/null
tprof() { printf '# Autonomy\n\n## Knowledge\n| Knowledge | Where | Read |\n|---|---|---|\n| Decisions | [adrs](../../docs/adr/) | start |\n\n## Tiers\n| Tier | Paths | Reviewer | Human |\n|---|---|---|---|\n%b\n\n## Guardrails\n| Guardrail | Enforced by | Verified |\n|---|---|---|\n| Protected branch | branch rule on main | 2026-01-02 |\n' "$1" > "$B/.specs/steering/autonomy.md"; }
tchk() { python3 "$B/.specs/kit/scripts/tiers.py" --specs "$B/.specs" --check 2>&1; }
GOOD='| routine | `tests/*` `docs/*` | standard | none |\n| domain | `src/*` | standard | spot |\n| critical | `*/security/*` `CODEOWNERS` | deep | required |'
rc=0; out=$(tchk) || rc=$?; [ "$rc" = 0 ] || fail "13b: --check without a profile exits $rc, want 0: $out"
tprof "$GOOD"; rc=0; out=$(tchk) || rc=$?; [ "$rc" = 0 ] || fail "13b: valid table exits $rc: $out"
bad() { tprof "$2"; rc=0; out=$(tchk) || rc=$?; [ "$rc" = "$3" ] || fail "13b: $1 exits $rc, want $3: $out"; case "$out" in *autonomy.md:*) ;; *) fail "13b: $1 lacks file:line: $out";; esac; }
bad "unknown reviewer" '| routine | `tests/*` | medium | none |\n| critical | `*` | deep | required |' 2
bad "unknown human" '| routine | `tests/*` | standard | maybe |\n| critical | `*` | deep | required |' 2
bad "decreasing human" '| domain | `src/*` | standard | spot |\n| routine | `tests/*` | standard | none |\n| critical | `*` | deep | required |' 2
bad "last row not required" '| routine | `tests/*` | standard | none |\n| domain | `src/*` | standard | spot |' 2
bad "duplicate tier" '| routine | `tests/*` | standard | none |\n| routine | `src/*` | deep | required |' 2
bad "no code span in Paths" '| routine | tests | standard | none |\n| critical | `*` | deep | required |' 2
bad "placeholder left in" '| routine | `<tests glob>` | standard | none |\n| critical | `*` | deep | required |' 2
bad "short row" '| routine | `tests/*` |\n| critical | `*` | deep | required |' 2
bad "guarded path in a lower row" '| routine | `docs/adr/*` | standard | none |\n| critical | `*` | deep | required |' 1
bad "agent file in a lower row" '| routine | `CLAUDE.md` | standard | none |\n| critical | `*` | deep | required |' 1
bad "folded agent file in a lower row" '| routine | `AGENTſ.md` | standard | none |\n| critical | `*` | deep | required |' 1
bad "override agent file in a lower row" '| routine | `AGENTS.override.md` | standard | none |\n| critical | `*` | deep | required |' 1
python3 "$B/.specs/kit/scripts/tiers.py" --bogus >/dev/null 2>&1 && fail "13b: unknown flag exits 0"
tprof "$GOOD"; gitq -C "$B" add .; gitq -C "$B" commit -m profile; tprof '| critical | `*` | deep | required |'
python3 -I - "$B" "$KIT/kit/scripts" <<'PY' || fail "13b: guarded globs or base read"
import sys; sys.dont_write_bytecode = True; sys.path.insert(0, sys.argv[2])
import tiers, install
root = sys.argv[1]
txt = tiers.profile_at(root, "HEAD", ".specs/steering/autonomy.md")
assert txt and "src/*" in txt, "profile_at must read the committed text, not the working tree"
assert tiers.profile_at(root, "HEAD", ".specs/steering/none.md") is None
g = tiers.guarded_globs(txt, ".specs/steering/autonomy.md")
assert "docs/adr/*" in g and ".specs/steering/*" in g and tiers.hit("AGENTS.md", g), g
import unicodedata
k = tiers.guarded_globs("## Knowledge\n| D | [d](../../docs/d\u00e9cisions.md) | start |\n", ".specs/steering/autonomy.md")
assert tiers.hit(unicodedata.normalize("NFD", "docs/d\u00e9cisions.md"), k), "an NFD path must hit its NFC Knowledge target (APFS opens one as the other)"
for a in install.AGENTS.values():
    assert any(x.startswith(a[3].split("/")[0] + "/") for x in g), ("agent dir not guarded", a[3])
PY
echo "13b. tiers.py label: staged and --range, strictest file wins, guarded path takes the last row, base table rules, --json, usage errors"
tl() { python3 "$B/.specs/kit/scripts/tiers.py" --specs "$B/.specs" "$@" 2>&1; }
mkdir -p "$B/tests" "$B/src/security" "$B/docs"; echo a > "$B/tests/a.txt"; echo a > "$B/docs/d.md"; echo a > "$B/src/s.txt"
tprof "$GOOD"; printf '{"merged_ref": "trunk"}' > "$B/.specs/spec-kit.json"; gitq -C "$B" add -A; gitq -C "$B" commit -m base2; BASE=$(git -C "$B" rev-parse HEAD); gitq -C "$B" branch trunk
echo b > "$B/docs/d.md"; gitq -C "$B" add -A
out=$(tl) && echo "$out" | grep -q "tier: routine (reviewer: standard, human: spot)" && echo "$out" | grep -q "^### Risk tier" || fail "13b: staged docs change not routine: $out"
echo b > "$B/src/s.txt"; gitq -C "$B" add -A
out=$(tl) && echo "$out" | grep -q "tier: domain" && echo "$out" | grep -q "files: 2 (routine 1, domain 1)" && echo "$out" | grep -q 'set by: src/s.txt (`src/\*`)' || fail "13b: strictest file did not win: $out"
echo b > "$B/src/security/k.txt"; gitq -C "$B" add -A
out=$(tl) && echo "$out" | grep -q "tier: critical (reviewer: deep, human: required)" || fail "13b: security file not critical: $out"
gitq -C "$B" reset -q; gitq -C "$B" add docs/d.md; echo c > "$B/AGENTS.md"; gitq -C "$B" add AGENTS.md
out=$(tl) && echo "$out" | grep -q "tier: critical" && echo "$out" | grep -q "set by: AGENTS.md" || fail "13b: guarded AGENTS.md not critical: $out"
gitq -C "$B" reset -q --hard; gitq -C "$B" clean -fdq; gitq -C "$B" mv tests/a.txt tests/b.txt
out=$(tl) && echo "$out" | grep -q "files: 2" || fail "13b: rename not counted under both paths: $out"
gitq -C "$B" reset -q --hard; gitq -C "$B" clean -fdq
echo z > "$B/tests/z.txt"; gitq -C "$B" add -A; gitq -C "$B" commit -m z
out=$(tl --range "$BASE..HEAD") && echo "$out" | grep -q "tier: routine" && echo "$out" | grep -q "profile: .specs/steering/autonomy.md at ${BASE%"${BASE#???????}"}" || fail "13b: --range label: $out"
js=$(tl --range "$BASE...HEAD" --json) && printf '%s' "$js" | python3 -c 'import json,sys; d=json.load(sys.stdin); assert d["tier"]=="routine" and d["reviewer"]=="standard" and d["human"]=="spot" and d["set_by"]["file"]=="tests/z.txt" and d["set_by"]["glob"]=="tests/*" and d["counts"]=={"routine":1} and d["profile_commit"]=="'"$BASE"'" and d["labels_only"] is False, d' || fail "13b: --json shape: $js"
# a branch that rewrites the Tiers table is labelled by the base's table
tprof '| critical | `*` | deep | required |'; ( cd "$B" && echo q > docs/e.md ); gitq -C "$B" add -A; gitq -C "$B" commit -m rewrite
out=$(tl --range "$BASE..HEAD") && echo "$out" | grep -q "tier: critical" || fail "13b: guarded profile edit not critical: $out"
tprof '| critical | `*` | deep | required |'; gitq -C "$B" add -A; gitq -C "$B" commit -q -m same || true
echo w > "$B/docs/w.md"; gitq -C "$B" add docs/w.md
out=$(tl) && echo "$out" | grep -q "at ${BASE%"${BASE#???????}"}" && echo "$out" | grep -q "tier: critical" && ! echo "$out" | grep -q "no merge base" || fail "13b: staged mode did not use the merge-base table after the branch committed a profile change: $out"
out=$(tl) && echo "$out" | grep -q "files: 4" || fail "13b: staged mode dropped committed-and-staged branch changes: $out"
printf '{bad' > "$B/.specs/spec-kit.json"; gitq -C "$B" commit -qam bad; rc=0; tl >/dev/null || rc=$?; [ "$rc" = 2 ] || fail "13b: bad committed spec-kit.json exits $rc, want 2"
gitq -C "$B" reset -q --hard HEAD~1
echo "13b. tiers.py guards: case-folded, nested, quoted paths, subfolder .specs"
G="$TMP/t13b-g"; mkdir -p "$G"; gitq -C "$G" init; "$KIT/install.sh" "$G" >/dev/null
printf '# Autonomy\n\n## Tiers\n| Tier | Paths | Reviewer | Human |\n|---|---|---|---|\n| routine | `*` | standard | none |\n| critical | `*/security/*` | deep | required |\n' > "$G/.specs/steering/autonomy.md"
printf '{"merged_ref": "main"}' > "$G/.specs/spec-kit.json"; echo r > "$G/readme"; gitq -C "$G" add -A; gitq -C "$G" commit -m g
tg() { python3 "$G/.specs/kit/scripts/tiers.py" --specs "$G/.specs" 2>&1; }
echo x > "$G/readme2"; gitq -C "$G" add -A; out=$(tg) && echo "$out" | grep -q "tier: routine" && echo "$out" | grep -q "base: $(git -C "$G" rev-parse --short HEAD) (merge base with refs/heads/main)" || fail "13b: control file not routine at the merge base: $out"
gitq -C "$G" reset -q --hard; gitq -C "$G" clean -fdq
# Names a folding filesystem opens as a guarded or critical path (APFS: s-long, st-ligature, NFD; NTFS: dotless i).
# Staged by blob so the folding checkout never rewrites them; a mixed reset leaves the work tree alone.
XB=$(echo x | git -C "$G" hash-object -w --stdin)
for f in "AGENTſ.md" ".ſpecs/kit/x" ".specs/ﬆeering/x.md" ".clınerules" "src/Security/Bypass.java"; do
  git -C "$G" update-index --add --cacheinfo "100644,$XB,$f"
  out=$(tg) && echo "$out" | grep -q "tier: critical" || fail "13b: folded name '$f' escaped the last tier: $out"
  gitq -C "$G" reset -q
done
for f in AGENTS.override.md CLAUDE.local.md pkg/.claude/skills/x/SKILL.md pkg/.cursor/rules/x.mdc pkg/.github/copilot-instructions.md .Claude/skills/x/SKILL.md claude.md a/b/AGENTS.md sub/CLAUDE.md .github/instructions/x.md .github/prompts/x.md .github/agents/x.md .github/copilot-instructions.md .clinerules .windsurfrules .cursorrules .mcp.json CODEOWNERS docs/CODEOWNERS .github/CODEOWNERS .specs/README.md .specs/steering/x.md .specs/kit/x.py ".claude/é.md" ".claude/a
b.md"; do
  mkdir -p "$G/$(dirname "$f")"; echo x > "$G/$f"; gitq -C "$G" add -A
  out=$(tg) && echo "$out" | grep -q "tier: critical" && echo "$out" | grep -q "files: 1 " || fail "13b: guarded path '$f' did not take the last tier with 1 file: $out"
  gitq -C "$G" reset -q --hard; gitq -C "$G" clean -fdq
done
# staged base: merged_ref as committed at HEAD, never the work tree; no merge base fails closed to the last tier
gitq -C "$G" checkout -q -b feat
printf '# Autonomy\n\n## Tiers\n| Tier | Paths | Reviewer | Human |\n|---|---|---|---|\n| routine | `*` | standard | none |\n| critical | `nothing` | deep | required |\n' > "$G/.specs/steering/autonomy.md"; gitq -C "$G" commit -qam loosen
mkdir -p "$G/src/security"; echo x > "$G/src/security/k.java"; gitq -C "$G" add src/security/k.java
printf '{"merged_ref": "feat"}' > "$G/.specs/spec-kit.json"
out=$(tg) && echo "$out" | grep -q "tier: critical" && echo "$out" | grep -q "(merge base with refs/heads/main)" || fail "13b: a work-tree merged_ref edit moved the staged base: $out"
gitq -C "$G" reset -q --hard; printf '{"merged_ref": null}' > "$G/.specs/spec-kit.json"; gitq -C "$G" commit -qam nobase
echo x > "$G/readme3"; gitq -C "$G" add readme3
out=$(tg) && echo "$out" | grep -q "tier: critical" && echo "$out" | grep -q "base: HEAD (no merge base: last tier)" || fail "13b: no merge base did not fail closed to the last tier: $out"
gitq -C "$G" reset -q --hard; gitq -C "$G" clean -fdq; gitq -C "$G" checkout -q main
S="$TMP/t13b-sub"; mkdir -p "$S/proj"; gitq -C "$S" init; "$KIT/install.sh" "$S/proj" >/dev/null
cp "$G/.specs/steering/autonomy.md" "$S/proj/.specs/steering/autonomy.md"; echo r > "$S/readme"; gitq -C "$S" add -A; gitq -C "$S" commit -m s
mkdir -p "$S/.claude"; echo x > "$S/.claude/settings.json"; gitq -C "$S" add -A
out=$(python3 "$S/proj/.specs/kit/scripts/tiers.py" --specs "$S/proj/.specs" 2>&1) && echo "$out" | grep -q "tier: critical" && echo "$out" | grep -q "files: 1 " || fail "13b: root file outside a subfolder .specs not counted as guarded: $out"
N="$TMP/t13b-none"; mkdir -p "$N/.specs/steering"; gitq -C "$N" init; echo x > "$N/x"; gitq -C "$N" add -A; gitq -C "$N" commit -m x; echo y > "$N/x"; gitq -C "$N" add -A
out=$(python3 "$B/.specs/kit/scripts/tiers.py" --specs "$N/.specs" 2>&1) && echo "$out" | grep -q "no autonomy profile at" && echo "$out" | grep -q "human: required" || fail "13b: no profile at base is not the human tier: $out"
for a in "--range" "--range nodots" "--check --range a..b" "--json --check" "--range a..b --range c..d"; do
  rc=0; tl $a >/dev/null || rc=$?; [ "$rc" = 2 ] || fail "13b: 'tiers.py $a' exits $rc, want 2"
done
rc=0; tl --range nosuch..HEAD >/dev/null || rc=$?; [ "$rc" = 2 ] || fail "13b: unresolvable range exits $rc, want 2"

echo "13c. tiers.py guardrails: undeclared rows turn Human none into spot; declared rows keep it; --check lists rows; bad header exits 2"
C="$TMP/t13c"; mkdir -p "$C/docs" "$C/src"; gitq -C "$C" init; "$KIT/install.sh" "$C" >/dev/null
TIERS='| routine | `docs/*` | standard | none |\n| domain | `src/*` | standard | spot |\n| critical | `*/security/*` | deep | required |'
printf '{"merged_ref": "trunk"}' > "$C/.specs/spec-kit.json"; echo a > "$C/docs/d.md"; echo a > "$C/src/s.txt"
cl() { python3 "$C/.specs/kit/scripts/tiers.py" --specs "$C/.specs" "$@" 2>&1; }
# cset <Guardrails section or empty>: commit the profile as the base, then stage a docs change
cset() { printf '# Autonomy\n\n## Tiers\n| Tier | Paths | Reviewer | Human |\n|---|---|---|---|\n%b\n%b' "$TIERS" "$1" > "$C/.specs/steering/autonomy.md"
  gitq -C "$C" add -A; gitq -C "$C" commit -m p; gitq -C "$C" branch -f trunk; date +%s%N > "$C/docs/d.md"; gitq -C "$C" add -A; }
GH='\n## Guardrails\n| Guardrail | Enforced by | Verified |\n|---|---|---|\n'
cset ''; out=$(cl)
echo "$out" | grep -q "human: spot" && echo "$out" | grep -q "guardrails: no Guardrails section, none → spot" || fail "13c: no Guardrails section did not downgrade none: $out"
echo "$out" | tail -1 | grep -q "^- autonomy: human spot" || fail "13c: autonomy line not last: $out"
cset "${GH}| Protected branch | branch rule main | 2026-01-02 |\n| Untrusted jobs | <platform setting> | 2026-01-02 |\n"; out=$(cl)
echo "$out" | grep -q "human: spot" && echo "$out" | grep -q "guardrails: 1 of 2 undeclared, none → spot" || fail "13c: placeholder row did not downgrade: $out"
cset "${GH}| Protected branch | branch rule main | 2026-01-02 |\n| Untrusted jobs | no such job, checked CI workflows | 2026-01-02 |\n"; out=$(cl)
echo "$out" | grep -q "tier: routine (reviewer: standard, human: spot)" && echo "$out" | grep -q "guardrails: 2 declared$" && ! echo "$out" | grep -q "guardrails: .*none → spot" || fail "13c: declared rows changed the label: $out"
js=$(cl --json); printf '%s' "$js" | python3 -c 'import json,sys; d=json.load(sys.stdin); assert d["human"]=="spot" and d["guardrails"]=={"rows":2,"undeclared":0,"downgraded":False}, d' || fail "13c: --json declared: $js"
cset "${GH}| Protected branch | branch rule main | 2026-13-45 |\n| Untrusted jobs | no such job, checked CI | 2026-01-02 |\n"; out=$(cl)
echo "$out" | grep -q "guardrails: 1 of 2 undeclared, none → spot" || fail "13c: bad date was not undeclared: $out"
js=$(cl --json); printf '%s' "$js" | python3 -c 'import json,sys; d=json.load(sys.stdin); assert d["human"]=="spot" and d["tier"]=="routine" and d["guardrails"]=={"rows":2,"undeclared":1,"downgraded":True}, d' || fail "13c: --json downgraded: $js"
cset "${GH}| A | TBD | 2026-01-02 |\n| B | N/A | 2026-01-02 |\n| C | - | 2026-01-02 |\n| D | x | 2099-01-01 |\n| E | none | 2026-01-02 |\n| F | — | 2026-01-02 |\n| G | – | 2026-01-02 |\n| H | ? | 2026-01-02 |\n| I | TBD. | 2026-01-02 |\n| J | Pending | 2026-01-02 |\n| K | na | 2026-01-02 |\n"; out=$(cl --check)
[ "$(echo "$out" | grep -c 'undeclared (no Enforced by)')" = 10 ] && echo "$out" | grep -q "undeclared (Verified is in the future)" || fail "13c: TBD/N/A/-/future date are declared: $out"
cset "${GH}| Protected branch | | 2026-01-02 |\n"; out=$(cl --check)
echo "$out" | grep -q "guardrail .*autonomy.md:[0-9]*: undeclared (no Enforced by)" || fail "13c: --check lacks the undeclared row with file:line: $out"
cset "${GH}| A | x | 2026-01-02 |\n| B | y | soon |\n| C | <z> | 2026-01-02 |\n"; rc=0; out=$(cl --check) || rc=$?
[ "$rc" = 0 ] && echo "$out" | grep -q "autonomy.md:[0-9]*: declared" && echo "$out" | grep -q "undeclared (Verified is not a YYYY-MM-DD date)" && echo "$out" | grep -q "undeclared (placeholder in Enforced by)" || fail "13c: --check rows (exit $rc): $out"
cset "${GH}| A | x | 2026-01-02 |\n"; sed -i.bak 's/^| Guardrail | Enforced by | Verified |/| Guardrail | Enforced | Date |/' "$C/.specs/steering/autonomy.md"; rm -f "$C/.specs/steering/autonomy.md.bak"
rc=0; out=$(cl --check) || rc=$?; [ "$rc" = 2 ] && echo "$out" | grep -q "autonomy.md:[0-9]*: header must be" || fail "13c: bad Guardrails header --check exits $rc: $out"
gitq -C "$C" add -A; gitq -C "$C" commit -m badhead; gitq -C "$C" branch -f trunk; echo q > "$C/docs/d.md"; gitq -C "$C" add -A
rc=0; out=$(cl) || rc=$?; [ "$rc" = 2 ] && echo "$out" | grep -q "header must be" || fail "13c: bad Guardrails header label exits $rc: $out"
cset "${GH}| A | <x> | 2026-01-02 |\n"; echo b > "$C/src/s.txt"; gitq -C "$C" add -A; out=$(cl)
echo "$out" | grep -q "tier: domain (reviewer: standard, human: spot)" && echo "$out" | grep -q "guardrails: 1 of 1 undeclared$" && ! echo "$out" | grep -q "none → spot" || fail "13c: a spot change was touched by the downgrade: $out"
# a fenced or commented example is not a section: a ```markdown block or <!-- --> holding a Guardrails section declares nothing, and a fenced ## Tiers does not join the real table
EXG='## Guardrails\n| Guardrail | Enforced by | Verified |\n|---|---|---|\n| Protected branch | branch rule main | 2026-01-02 |\n'
cset "\n"'```markdown\n'"${EXG}"'```\n'; out=$(cl)
echo "$out" | grep -q "guardrails: no Guardrails section, none → spot" || fail "13c: a fenced Guardrails example counted as a section: $out"
cset "\n<!--\n${EXG}-->\n"; out=$(cl)
echo "$out" | grep -q "guardrails: no Guardrails section, none → spot" || fail "13c: a commented Guardrails example counted as a section: $out"
cset "\n<!--\n${GH}| Protected branch | branch rule main | 2026-01-02 |\n"; out=$(cl)
echo "$out" | grep -q "guardrails: no Guardrails section, none → spot" || fail "13c: an unclosed comment still showed a Guardrails section: $out"
cset "\n"'~~~\n## Tiers\n| Tier | Paths | Reviewer | Human |\n|---|---|---|---|\n| routine | `docs/*` | deep | required |\n~~~\n'"${GH}| Protected branch | branch rule main | 2026-01-02 |\n"; rc=0; out=$(cl) || rc=$?
[ "$rc" = 0 ] && echo "$out" | grep -q "tier: routine (reviewer: standard, human: spot)" && echo "$out" | grep -q "guardrails: 1 declared$" || fail "13c: a fenced Tiers example changed the real table (exit $rc): $out"
# Knowledge keeps reading raw lines: a link inside a comment stays guarded
cset "\n## Knowledge\n"'<!-- [x](../../docs/d.md) -->\n'; out=$(cl)
echo "$out" | grep -q "tier: critical" || fail "13c: a commented Knowledge link left docs/d.md unguarded: $out"
echo "13c2. human none by tier: only the lowest row, guardrails declared and evidence eligible keep it; labels_only false; ready.py same family bars it"
F="$TMP/t13f"; mkdir -p "$F/docs" "$F/src"; gitq -C "$F" init; "$KIT/install.sh" "$F" >/dev/null
printf '{"merged_ref": "trunk"}' > "$F/.specs/spec-kit.json"; echo a > "$F/src/s.txt"
fl() { python3 "$F/.specs/kit/scripts/tiers.py" --specs "$F/.specs" "$@" 2>&1; }
# fset <tiers> <min merged>: commit a profile with declared guardrails and a routine Evidence row, two routine commits, then stage a docs change
fset() { printf '# Autonomy\n\n## Tiers\n| Tier | Paths | Reviewer | Human |\n|---|---|---|---|\n%b\n\n## Guardrails\n| Guardrail | Enforced by | Verified |\n|---|---|---|\n| Protected branch | branch rule main | 2026-01-02 |\n\n## Evidence\n| Tier | Window (days) | Min merged | Max reverted %% | Max escaped %% | Max human-caught %% |\n|---|---|---|---|---|---|\n| routine | 30 | %s | - | - | - |\n' "$1" "$2" > "$F/.specs/steering/autonomy.md"
  printf '# Rules\n\n| # | Gate | Command |\n|---|---|---|\n| G1 | Lint | `echo a` |\n' > "$F/.specs/steering/spec-rules.md"
  gitq -C "$F" add -A; gitq -C "$F" commit -m "p$2$n"; for i in 1 2; do date +%s%N > "$F/docs/m$i"; gitq -C "$F" add -A; gitq -C "$F" commit -m "m$i"; done
  gitq -C "$F" branch -f trunk; date +%s%N > "$F/docs/d.md"; gitq -C "$F" add -A; }
T1='| routine | `docs/*` | standard | none |\n| domain | `src/*` | standard | spot |\n| critical | `*/security/*` | deep | required |'
n=1; fset "$T1" 2; out=$(fl)
echo "$out" | grep -q "tier: routine (reviewer: standard, human: none)" && ! echo "$out" | grep -q "none → spot" && echo "$out" | grep -q "^- autonomy: human none.*auto-merge" || fail "13c2: lowest tier, declared, eligible lost none: $out"
js=$(fl --json); printf '%s' "$js" | python3 -c 'import json,sys; d=json.load(sys.stdin); assert d["human"]=="none" and d["labels_only"] is False and d["reasons"]==[], d' || fail "13c2: --json eligible: $js"
n=2; fset "$T1" 20; out=$(fl)
echo "$out" | grep -q "human: spot" && echo "$out" | grep -q "none → spot (evidence: hold (merged [0-9]* < min 20))" || fail "13c2: evidence hold did not give spot: $out"
js=$(fl --json); printf '%s' "$js" | python3 -c 'import json,sys; d=json.load(sys.stdin); assert d["human"]=="spot" and d["reasons"] and d["reasons"][0].startswith("evidence: hold"), d' || fail "13c2: --json hold: $js"
n=3; fset "$T1" 2; sed -i.bak 's/^| Tier | Window (days) | Min merged/| Tier | Window | Min merged/' "$F/.specs/steering/autonomy.md"; rm -f "$F/.specs/steering/autonomy.md.bak"
# the bad header must be in the base's profile (the label reads the base, never the working tree): commit it, move trunk, stage a change
gitq -C "$F" add -A; gitq -C "$F" commit -m badhdr; gitq -C "$F" branch -f trunk; date +%s%N > "$F/docs/e.md"; gitq -C "$F" add -A
rc=0; out=$(fl) || rc=$?; [ "$rc" = 0 ] && echo "$out" | grep -q "human: spot" && echo "$out" | grep -q "none → spot (evidence: " || fail "13c2: a refusing evidence run did not fail closed to spot (exit $rc): $out"
n=4; fset '| routine | `docs/*` | standard | none |\n| domain | `src/*` | standard | none |\n| critical | `*/security/*` | deep | required |' 2; echo b > "$F/src/s.txt"; gitq -C "$F" add -A; out=$(fl)
echo "$out" | grep -q "tier: domain (reviewer: standard, human: spot)" && echo "$out" | grep -q "none → spot (not the lowest tier)" || fail "13c2: none on a non-lowest row kept none: $out"
# ready.py: a shared family and Human none reports spot, exit unchanged
n=5; fset "$T1" 2; FH=$(git -C "$F" rev-parse --short HEAD)
fr() { m=$1; shift; printf '### Gates\n- G1 Lint: pass (a)\n- commit: %s+dirty\n- verdict: ready (1 passed)\n\n### Review\n- implementer: claude-sonnet-5-5\n- reviewer: %s (deep)\n- rules: %s\n' "$FH" "$m" "$FH" | python3 "$F/.specs/kit/scripts/ready.py" --specs "$F/.specs" "$@" 2>&1; }
rc=0; out=$(fr claude-opus-5-5) || rc=$?; [ "$rc" = 0 ] && echo "$out" | grep -q "human: none → spot (same family)" || fail "13c2: ready.py same family kept none (exit $rc): $out"
rc=0; out=$(fr gpt-5-1) || rc=$?; [ "$rc" = 0 ] && ! echo "$out" | grep -q "same family" && echo "$out" | grep -q "human: none" || fail "13c2: ready.py other family lost none (exit $rc): $out"
js=$(fr claude-opus-5-5 --json); printf '%s' "$js" | python3 -c 'import json,sys; d=json.load(sys.stdin); assert d["tier"]["human"]=="spot" and d["tier"]["human_why"]=="same family", d' || fail "13c2: ready --json same family: $js"
# ready.py agrees with the label: evidence on hold bars none whatever the reviewer's family
n=6; fset "$T1" 20; FH=$(git -C "$F" rev-parse --short HEAD)
rc=0; out=$(fr gpt-5-1) || rc=$?; [ "$rc" = 0 ] && echo "$out" | grep -q "human: none → spot (evidence: hold (merged [0-9]* < min 20))" || fail "13c2: ready.py kept none on held evidence (exit $rc): $out"
echo "13d. fix-round cap: rounds <= 2 ready, > 2, malformed or repeated not ready, missing a warning (the demote line is in 13c, on its evidence fixture)"
fk() { printf '### Gates\n- G1 Lint: pass (a)\n- commit: %s+dirty\n- verdict: ready (1 passed)\n\n### Review\n- implementer: claude-sonnet-5-5\n- reviewer: gpt-5-1 (deep)\n- rules: %s\n%s' "$FH" "$FH" "$1" | python3 "$F/.specs/kit/scripts/ready.py" --specs "$F/.specs" ${2:+"$2"} 2>&1; }
rc=0; out=$(fk '- rounds: 3
') || rc=$?; [ "$rc" = 1 ] && echo "$out" | grep -q "^- verdict: not ready" && echo "$out" | grep -q "not ready: fix-round cap" || fail "13c2: rounds 3 was not capped (exit $rc): $out"
rc=0; out=$(fk '- rounds: 2
') || rc=$?; [ "$rc" = 0 ] && echo "$out" | grep -q "^- verdict: ready" && ! echo "$out" | grep -q "rounds" || fail "13c2: rounds 2 not ready or warned (exit $rc): $out"
rc=0; out=$(fk '') || rc=$?; [ "$rc" = 0 ] && echo "$out" | grep -q "warning: .*rounds" || fail "13c2: missing rounds gave no warning (exit $rc): $out"
rc=0; out=$(fk '- rounds: two
') || rc=$?; [ "$rc" = 1 ] && echo "$out" | grep -q "not ready: .*rounds" || fail "13c2: malformed rounds did not fail closed (exit $rc): $out"
rc=0; out=$(fk '- rounds: 3
- rounds: 1
') || rc=$?; [ "$rc" = 1 ] && echo "$out" | grep -q "not ready: .*rounds.*repeated" || fail "13c2: a repeated rounds line overrode the cap (exit $rc): $out"
js=$(fk '- rounds: 1
' --json); printf '%s' "$js" | python3 -c 'import json,sys; d=json.load(sys.stdin); assert d["review"]["rounds"]==1, d' || fail "13c2: --json review.rounds: $js"
echo "13e. label and ready.py trust only the base: thresholds read at the base, no merged_ref fails closed, --auto-merge is the one exit code for none, a profile outside .specs/steering is guarded, rounds line variants, refs are branches or remotes only (no tag, no ambiguous name, no history holding the change), every warning bars auto-merge"
X="$TMP/t13e"; mkdir -p "$X"
xprof() { mkdir -p "$(dirname "$1")"; printf '# Autonomy\n\n## Tiers\n| Tier | Paths | Reviewer | Human |\n|---|---|---|---|\n| routine | `docs/*` | standard | none |\n| domain | `src/*` | standard | spot |\n| critical | `*/security/*` | deep | required |\n\n## Guardrails\n| Guardrail | Enforced by | Verified |\n|---|---|---|\n| Protected branch | branch rule main | 2026-01-02 |\n\n## Evidence\n| Tier | Window (days) | Min merged | Max reverted %% | Max escaped %% | Max human-caught %% |\n|---|---|---|---|---|---|\n| routine | 30 | %s | - | - | - |\n' "$2" > "$1"; }
# xmk <name> <spec-kit.json> <min merged> <profile path from the repo root> <merges on main>: the profile commit, then that many docs merges, trunk at the tip
xmk() { R="$X/$1"; rm -rf "$R"; mkdir -p "$R/.specs/steering" "$R/.specs/kit" "$R/docs" "$R/src"; gitq -C "$R" init; cp -R "$KIT/kit/scripts" "$R/.specs/kit/scripts"
  printf '%s' "$2" > "$R/.specs/spec-kit.json"; xprof "$R/$4" "$3"; echo s > "$R/src/s.txt"
  printf '# Rules\n\n| # | Gate | Command |\n|---|---|---|\n| G1 | Lint | `echo a` |\n' > "$R/.specs/steering/spec-rules.md"
  gitq -C "$R" add -A; gitq -C "$R" commit -m profile
  for i in $(seq 1 "${5:-0}"); do date +%s%N > "$R/docs/m$i"; gitq -C "$R" add -A; gitq -C "$R" commit -m "m$i"; done; gitq -C "$R" branch -f trunk; }
xdoc() { date +%s%N > "$R/docs/new$1"; gitq -C "$R" add -A; gitq -C "$R" commit -m "new$1"; }
xl() { python3 "$R/.specs/kit/scripts/tiers.py" --specs "$R/.specs" "$@" 2>&1; }
# xrd <reviewer> <extra Review lines> [ready.py flags]: the PR text for trunk...HEAD, checked with ready.py
xrd() { rv=$1; ex=$2; shift 2; printf '### Gates\n- G1 Lint: pass (a)\n- commit: %s\n- verdict: ready (1 passed)\n\n### Review\n- implementer: claude-sonnet-5-5\n- reviewer: %s (deep)\n- rules: %s\n%s' "$(git -C "$R" rev-parse --short HEAD)" "$rv" "$(git -C "$R" merge-base trunk HEAD | cut -c1-7)" "$ex" | python3 "$R/.specs/kit/scripts/ready.py" --specs "$R/.specs" --range trunk...HEAD "$@" 2>&1; }
TJ='{"merged_ref": "trunk"}'; AP=.specs/steering/autonomy.md

# B2: Min merged lowered in the working tree only (never committed, never reviewed) must not earn none
xmk b2 "$TJ" 20 $AP 2; sed -i.bak 's/| 30 | 20 |/| 30 | 1 |/' "$R/$AP"; rm -f "$R/$AP.bak"
gitq -C "$R" checkout -q -b pr; echo n > "$R/docs/new"; gitq -C "$R" add docs/new
out=$(xl); echo "$out" | grep -q "human: spot" && echo "$out" | grep -q "evidence: hold (merged 2 < min 20)" || fail "13e B2: staged label took the working-tree threshold: $out"
gitq -C "$R" commit -m docs
out=$(xl --range trunk...HEAD); echo "$out" | grep -q "human: spot" && echo "$out" | grep -q "evidence: hold (merged 2 < min 20)" || fail "13e B2: range label took the working-tree threshold: $out"
rc=0; out=$(xrd gpt-5-1 '' --json) || rc=$?; printf '%s' "$out" | python3 -c 'import json,sys; d=json.load(sys.stdin); assert d["tier"]["human"]=="spot" and d["tier"]["human_why"].startswith("evidence: hold (merged 2 < min 20)"), d' || fail "13e B2: ready.py took the working-tree threshold: $out"
gitq -C "$R" add -A; gitq -C "$R" commit -m "lower the bar"
out=$(xl --range trunk...HEAD); echo "$out" | grep -q "human: required" || fail "13e B2: a committed threshold edit is not guarded: $out"
# v061 task 1: --evidence reads thresholds at the merged_ref tip, never the working tree, and prints that commit
out=$(xl --evidence); echo "$out" | grep -q "routine: hold (merged 2 < min 20)" && echo "$out" | grep -qF -- "- profile: $AP at $(git -C "$R" rev-parse --short trunk), unchanged;" || fail "13e v061-1: --evidence took the working-tree threshold or omitted the tip commit: $out"

# B3: merged_ref null and no origin/HEAD resolves to HEAD, the PR head: its own commits must not count
xmk b3 '{"merged_ref": null}' 3 $AP 0; gitq -C "$R" checkout -q -b pr; xdoc 1; xdoc 2; xdoc 3
out=$(xl --range main...HEAD); echo "$out" | grep -q "human: spot" && echo "$out" | grep -q "evidence: no merged_ref" || fail "13e B3: the change earned its own evidence: $out"
out=$(printf '### Gates\n- G1 Lint: pass (a)\n- commit: %s\n- verdict: ready (1 passed)\n\n### Review\n- implementer: claude-sonnet-5-5\n- reviewer: gpt-5-1 (deep)\n- rules: %s\n' "$(git -C "$R" rev-parse --short HEAD)" "$(git -C "$R" rev-parse --short main)" | python3 "$R/.specs/kit/scripts/ready.py" --specs "$R/.specs" --range main...HEAD 2>&1)
echo "$out" | grep -q "human: spot" && echo "$out" | grep -q "evidence: no merged_ref" || fail "13e B3: ready.py let the change earn its own evidence: $out"

# B1: --auto-merge exits 0 only for ready and none
xmk b1 "$TJ" 2 $AP 2; gitq -C "$R" checkout -q -b pr; xdoc 1
rc=0; out=$(xrd gpt-5-1 '- rounds: 1
' --auto-merge) || rc=$?; [ "$rc" = 0 ] && echo "$out" | grep -q "human: none" && echo "$out" | grep -q "verdict: ready" || fail "13e B1: ready and none was refused (exit $rc): $out"
rc=0; out=$(printf '### Review\n- rounds: 1\n' | python3 "$R/.specs/kit/scripts/ready.py" --specs "$R/.specs" --auto-merge 2>&1) || rc=$?; [ "$rc" = 1 ] && echo "$out" | grep -q "^auto-merge: no (.*needs --range" || fail "13e B1: --auto-merge without --range was not refused (exit $rc): $out"
rc=0; out=$(xrd gpt-5-1 '- rounds: 1
' --json) || rc=$?; [ "$rc" = 0 ] && printf '%s' "$out" | python3 -c 'import json,sys; d=json.load(sys.stdin); assert d["auto_merge"] is True, d' || fail "13e B1: --json auto_merge true (exit $rc): $out"
rc=0; out=$(xrd claude-opus-5-5 '- rounds: 1
' --auto-merge) || rc=$?; [ "$rc" = 1 ] && echo "$out" | grep -q "^auto-merge: no (human spot: same family)" || fail "13e B1: spot (same family) was not refused (exit $rc): $out"
rc=0; out=$(xrd claude-opus-5-5 '- rounds: 1
') || rc=$?; [ "$rc" = 0 ] || fail "13e B1: without the flag the exit changed (exit $rc): $out"
rc=0; out=$(xrd claude-opus-5-5 '- rounds: 1
' --json --auto-merge) || rc=$?; [ "$rc" = 1 ] && printf '%s' "$out" | python3 -c 'import json,sys; d=json.load(sys.stdin); assert d["auto_merge"] is False, d' || fail "13e B1: --json auto_merge false (exit $rc): $out"
rc=0; out=$(xrd gpt-5-1 '- rounds: 3
' --auto-merge) || rc=$?; [ "$rc" = 1 ] && echo "$out" | grep -q "human: none" && echo "$out" | grep -q "^auto-merge: no (verdict not ready)" || fail "13e B1: none but not ready was not refused (exit $rc): $out"
xmk b1h "$TJ" 20 $AP 2; gitq -C "$R" checkout -q -b pr; xdoc 1
rc=0; out=$(xrd gpt-5-1 '- rounds: 1
' --auto-merge) || rc=$?; [ "$rc" = 1 ] && echo "$out" | grep -q "^auto-merge: no (human spot: evidence: hold" || fail "13e B1: spot (evidence hold) was not refused (exit $rc): $out"

# A4: a profile kept outside .specs/steering through --file is guarded too
xmk a4 "$TJ" 2 docs/autonomy.md 2; gitq -C "$R" checkout -q -b pr; echo "# edit" >> "$R/docs/autonomy.md"; gitq -C "$R" add -A; gitq -C "$R" commit -m "edit the profile"
out=$(xl --file "$R/docs/autonomy.md" --range trunk...HEAD); echo "$out" | grep -q "human: required" && echo "$out" | grep -q "set by: docs/autonomy.md" || fail "13e A4: --file profile edit is not guarded: $out"

# A6: every list-item spelling of rounds is read; one that looks like a rounds line and does not parse fails closed
xmk a6 "$TJ" 2 $AP 2; gitq -C "$R" checkout -q -b pr; xdoc 1
for v in '  - rounds: 3' '- Rounds: 3' '- rounds : 3' '* rounds: 3' '+ ROUNDS:3'; do
  rc=0; out=$(xrd gpt-5-1 "$v
") || rc=$?; [ "$rc" = 1 ] && echo "$out" | grep -q "not ready: fix-round cap" || fail "13e A6: '$v' was not read as rounds 3 (exit $rc): $out"
done
for v in '* rounds: two' '- rounds 3' '- rounds; 1'; do
  rc=0; out=$(xrd gpt-5-1 "$v
") || rc=$?; [ "$rc" = 1 ] && echo "$out" | grep -q "not ready: review rounds" || fail "13e A6: '$v' did not fail closed (exit $rc): $out"
done
rc=0; out=$(xrd gpt-5-1 '  * Rounds : 2
') || rc=$?; [ "$rc" = 0 ] && ! echo "$out" | grep -q "rounds" || fail "13e A6: a valid variant was refused (exit $rc): $out"
# N1: refs resolve to branches and remote-tracking refs only; a tag or an ambiguous name is never the evidence or a range end.
# xci <pr ref>: a CI-style checkout of R (heads to refs/remotes/origin/*, tags fetched, no origin/HEAD), detached at the PR head
xci() { C="$R-ci"; rm -rf "$C"; gitq init "$C"; gitq -C "$C" fetch -q "$R" '+refs/heads/*:refs/remotes/origin/*' '+refs/tags/*:refs/tags/*'; gitq -C "$C" checkout -q --detach "$(git -C "$R" rev-parse "$1")"; }
cl() { python3 "$C/.specs/kit/scripts/tiers.py" --specs "$C/.specs" "$@" 2>&1; }
# crd <range> [flags]: ready.py on the CI checkout, PR text for its HEAD, base main
crd() { rng=$1; shift; printf '### Gates\n- G1 Lint: pass (a)\n- commit: %s\n- verdict: ready (1 passed)\n\n### Review\n- implementer: claude-sonnet-5-5\n- reviewer: gpt-5-1 (deep)\n- rules: %s\n- rounds: 0\n' "$(git -C "$C" rev-parse --short HEAD)" "$(git -C "$C" merge-base refs/remotes/origin/main HEAD | cut -c1-7)" | python3 "$C/.specs/kit/scripts/ready.py" --specs "$C/.specs" --range "$rng" "$@" 2>&1; }
# a pushed tag origin/HEAD at the PR head, merged_ref null: the change is not its own history
xmk n1a '{"merged_ref": null}' 3 $AP 0; gitq -C "$R" checkout -q -b pr; xdoc 1; xdoc 2; xdoc 3; gitq -C "$R" tag origin/HEAD; xci pr
MB=$(git -C "$C" rev-parse refs/remotes/origin/main)
out=$(cl --range origin/main...HEAD); echo "$out" | grep -q "human: spot" && echo "$out" | grep -q "evidence: no merged_ref" || fail "13e N1: tag origin/HEAD at the PR head earned none: $out"
rc=0; out=$(crd "$MB...HEAD" --auto-merge) || rc=$?; [ "$rc" = 1 ] && echo "$out" | grep -q "^auto-merge: no (human spot: evidence: no merged_ref" || fail "13e N1: tag origin/HEAD gave auto-merge (exit $rc): $out"
# a tag origin/main on a side chain the agent made, merged_ref "origin/main": ambiguous, refused
xmk n1b '{"merged_ref": "origin/main"}' 3 $AP 0; gitq -C "$R" checkout -q -b side; xdoc 1; xdoc 2; xdoc 3; gitq -C "$R" tag origin/main
gitq -C "$R" checkout -q main; gitq -C "$R" branch -D side; gitq -C "$R" checkout -q -b pr; xdoc 4; xci pr; MB=$(git -C "$C" rev-parse refs/remotes/origin/main)
out=$(cl --range "$MB...HEAD"); echo "$out" | grep -q "human: spot" && echo "$out" | grep -q "evidence: merged_ref origin/main is ambiguous" || fail "13e N1: tag origin/main on a side chain earned none: $out"
rc=0; out=$(crd "$MB...HEAD" --auto-merge) || rc=$?; [ "$rc" = 1 ] && echo "$out" | grep -q "^auto-merge: no (human spot: evidence: merged_ref origin/main is ambiguous" || fail "13e N1: tag origin/main gave auto-merge (exit $rc): $out"
rc=0; out=$(cl --evidence) || rc=$?; [ "$rc" = 2 ] && echo "$out" | grep -q "merged_ref origin/main is ambiguous" || fail "13e N1: --evidence read a tag origin/main (exit $rc): $out"
# a tag origin/main on a src/ commit inside the PR, the range given by name: the end is refused, not moved
xmk n1c '{"merged_ref": "origin/main"}' 3 $AP 0; gitq -C "$R" checkout -q -b pr; xdoc 1; xdoc 2; xdoc 3
echo t > "$R/src/t.txt"; gitq -C "$R" add -A; gitq -C "$R" commit -m src; gitq -C "$R" tag origin/main; xdoc 5; xci pr
rc=0; out=$(cl --range origin/main...HEAD) || rc=$?; [ "$rc" = 2 ] && echo "$out" | grep -q "origin/main is ambiguous" || fail "13e N1: a tag moved the range base (exit $rc): $out"
rc=0; out=$(crd origin/main...HEAD --auto-merge) || rc=$?; [ "$rc" = 2 ] && echo "$out" | grep -q "origin/main is ambiguous" || fail "13e N1: ready.py took a tag as the range base (exit $rc): $out"
gitq -C "$C" tag v9 HEAD
rc=0; out=$(cl --range "$(git -C "$C" rev-parse refs/remotes/origin/main)...v9") || rc=$?; [ "$rc" = 2 ] && echo "$out" | grep -q "v9 is a tag" || fail "13e N1: a tag range end was read (exit $rc): $out"
# origin/HEAD pointing at the PR branch: evidence that contains the change is refused
xmk n1d '{"merged_ref": null}' 3 $AP 0; gitq -C "$R" checkout -q -b pr; xdoc 1; xdoc 2; xdoc 3; xci pr
gitq -C "$C" symbolic-ref refs/remotes/origin/HEAD refs/remotes/origin/pr
out=$(cl --range origin/main...HEAD); echo "$out" | grep -q "human: spot" && echo "$out" | grep -q "evidence: refs/remotes/origin/HEAD contains the change" || fail "13e N1: origin/HEAD at the PR branch earned none: $out"
rc=0; out=$(crd origin/main...HEAD --auto-merge) || rc=$?; [ "$rc" = 1 ] && echo "$out" | grep -q "^auto-merge: no (human spot: evidence: refs/remotes/origin/HEAD contains the change" || fail "13e N1: origin/HEAD at the PR branch gave auto-merge (exit $rc): $out"
# control: the real remote-tracking origin/HEAD, at main, still earns none
gitq -C "$C" symbolic-ref refs/remotes/origin/HEAD refs/remotes/origin/main
out=$(cl --range origin/main...HEAD); echo "$out" | grep -q "evidence: hold (merged [0-9]* < min 3)" || fail "13e N1: control origin/HEAD at main: $out"
# C1: a pushed branch named HEAD lands as a plain refs/remotes/origin/HEAD in CI: only a symref is the remote's HEAD
xmk c1 '{"merged_ref": null}' 3 $AP 0; gitq -C "$R" checkout -q -b side; xdoc 1; xdoc 2; xdoc 3
gitq -C "$R" checkout -q main; gitq -C "$R" checkout -q -b pr; xdoc 4; gitq -C "$R" update-ref refs/heads/HEAD side; gitq -C "$R" branch -D side
xci pr; MB=$(git -C "$C" rev-parse refs/remotes/origin/main)
out=$(cl --range "$MB...HEAD"); echo "$out" | grep -q "human: spot" && echo "$out" | grep -q "evidence: no merged_ref" || fail "13e C1: a branch named HEAD earned none: $out"
rc=0; out=$(crd "$MB...HEAD" --auto-merge) || rc=$?; [ "$rc" = 1 ] && echo "$out" | grep -q "^auto-merge: no (human spot: evidence: no merged_ref" || fail "13e C1: a branch named HEAD gave auto-merge (exit $rc): $out"
# C2: a short sha as a range end goes through git's ref lookup (a loose tag can shadow it on a case-insensitive disk): full ids only
rc=0; out=$(cl --range "$(git -C "$C" rev-parse --short "$MB")...HEAD") || rc=$?; [ "$rc" = 2 ] && echo "$out" | grep -q "full commit id" || fail "13e C2: a short sha range end was read (exit $rc): $out"
# D1: a symref to another .../HEAD ref (itself a plain pushed branch) is not a remote's default branch
SIDE=$(git -C "$C" rev-parse refs/remotes/origin/HEAD); gitq -C "$C" update-ref refs/remotes/up2/HEAD "$SIDE"; gitq -C "$C" symbolic-ref refs/remotes/origin/HEAD refs/remotes/up2/HEAD
rc=0; out=$(crd "$MB...HEAD" --auto-merge) || rc=$?; [ "$rc" = 1 ] && echo "$out" | grep -q "^auto-merge: no (human spot: evidence:" || fail "13e D1: origin/HEAD symref to another HEAD ref gave auto-merge (exit $rc): $out"
# D2: a 64-hex end in a SHA-1 repo reads as a ref, not as a full id
A64=$(printf 'a%.0s' $(seq 1 64)); gitq -C "$C" update-ref "refs/heads/$A64" "$SIDE"
rc=0; out=$(cl --range "$A64...HEAD") || rc=$?; [ "$rc" = 2 ] && echo "$out" | grep -q "full commit id" || fail "13e D2: a 64-hex end resolved in a SHA-1 repo (exit $rc): $out"

# N2: under --auto-merge every warning is a no: no human is there to read it
xmk n2 "$TJ" 2 $AP 2; gitq -C "$R" checkout -q -b pr; xdoc 1
for ex in '' '- **rounds**: 1' '1. rounds: 1'; do
  rc=0; out=$(xrd gpt-5-1 "$ex
" --auto-merge) || rc=$?; [ "$rc" = 1 ] && echo "$out" | grep -q "verdict: ready" && echo "$out" | grep -q "^auto-merge: no (" || fail "13e N2: a warning under --auto-merge merged ('$ex', exit $rc): $out"
done
rc=0; out=$(xrd gpt-5-1 '
' --json --auto-merge) || rc=$?; [ "$rc" = 1 ] && printf '%s' "$out" | python3 -c 'import json,sys; d=json.load(sys.stdin); assert d["auto_merge"] is False and d["warnings"], d' || fail "13e N2: --json auto_merge with a warning (exit $rc): $out"
rc=0; out=$(printf '### Gates\n- G1 Lint: pass (a)\n- G9 Extra: pass (x)\n- commit: %s\n- verdict: ready (1 passed)\n\n### Review\n- implementer: claude-sonnet-5-5\n- reviewer: gpt-5-1 (deep)\n- rules: %s\n- rounds: 1\n' "$(git -C "$R" rev-parse --short HEAD)" "$(git -C "$R" merge-base trunk HEAD | cut -c1-7)" | python3 "$R/.specs/kit/scripts/ready.py" --specs "$R/.specs" --range trunk...HEAD --auto-merge 2>&1) || rc=$?
[ "$rc" = 1 ] && echo "$out" | grep -q "^auto-merge: no (row 'G9 Extra' is not in the base" || fail "13e N2: an unknown Gates row under --auto-merge merged (exit $rc): $out"
echo "13c. evidence: tiers.py --evidence counts first-parent merges per tier by the parent's profile; hold, breach, eligible; bad rows exit 2; profile never edited"
D="$TMP/t13d"; mkdir -p "$D/docs" "$D/src"; gitq -C "$D" init; "$KIT/install.sh" "$D" >/dev/null
el() { python3 "$D/.specs/kit/scripts/tiers.py" --specs "$D/.specs" --evidence "$@" 2>&1; }
AP="$D/.specs/steering/autonomy.md"; n=0
TD='| routine | `docs/*` | standard | none |\n| domain | `src/*` | standard | spot |\n| critical | `*/security/*` | deep | required |'
EVH='\n## Evidence\n| Tier | Window (days) | Min merged | Max reverted % | Max escaped % | Max human-caught % |\n|---|---|---|---|---|---|\n'
ev() { printf '# Autonomy\n\n## Tiers\n| Tier | Paths | Reviewer | Human |\n|---|---|---|---|\n%b\n%b' "$TD" "$1" > "$AP"
  # --evidence reads the profile at the tip, so a changed, already tracked profile is committed (it is a guarded path: critical)
  gitq -C "$D" diff --quiet -- "$AP" || { gitq -C "$D" add "$AP"; gitq -C "$D" commit -q -m "profile edit"; }; }
mk() { d=$1; shift; n=$((n+1)); echo $n > "$D/$d/f$n"; gitq -C "$D" add "$d"; gitq -C "$D" commit -q "$@"; }
sha() { git -C "$D" rev-parse HEAD; }
printf '{"merged_ref": "HEAD"}' > "$D/.specs/spec-kit.json"
# c1 is dated before every window but sits above case 13's `base` root commit, dated now, so it counts by position: base, c1 and the profile commit have no profile above them: 3 unprofiled
export GIT_COMMITTER_DATE=2020-01-01T00:00:00; mk docs -m c1-before-the-profile; unset GIT_COMMITTER_DATE
ev ""; gitq -C "$D" add .specs/steering/autonomy.md .specs/spec-kit.json; gitq -C "$D" commit -q -m profile
mk docs -m d1; D1=$(sha); mk docs -m d2; mk docs -m d3; mk docs -m d4
gitq -C "$D" revert --no-edit "$D1"
mk src -m s1; S1=$(sha | cut -c1-7); mk src -m s2; mk src -m s3 -m "Fixes: $S1"; mk src -m s4 -m "Fixes: #12" -m "Human-Findings: 0"
# no Evidence section: every tier holds, exit 0
rc=0; out=$(el) || rc=$?
[ "$rc" = 0 ] && echo "$out" | grep -q "^### Evidence" && [ "$(echo "$out" | grep -c 'hold (no Evidence row)')" = 3 ] || fail "13c evidence: no section (exit $rc): $out"
echo "$out" | grep -q "unprofiled: 3 commit(s) left out" && echo "$out" | grep -q "history: HEAD at $(sha | cut -c1-7), first-parent" || fail "13c evidence: unprofiled or history line: $out"
EV1='| routine | 90 | 3 | 10 | 20 | - |\n| domain | 90 | 2 | 10 | 50 | 10 |\n| critical | <days> | <n> | <%> | <%> | <%> |\n'
ev "${EVH}${EV1}"; SUM=$(cksum < "$AP"); rc=0; out=$(el) || rc=$?
[ "$rc" = 0 ] && echo "$out" | grep -q "routine: breach (reverted 20.0% > 10%)" && echo "$out" | grep -q "domain: hold (Human-Findings on 1 of 4 merges)" && echo "$out" | grep -q "critical: hold (thresholds not set)" || fail "13c evidence: revert breach, no trailers, placeholder (exit $rc): $out"
[ "$SUM" = "$(cksum < "$AP")" ] || fail "13c evidence: the profile changed"
mk src -m s5 -m "Human-Findings: 0"
out=$(el) && echo "$out" | grep -q "domain: eligible" || fail "13c evidence: domain not eligible: $out"
js=$(el --json); printf '%s' "$js" | python3 -c 'import json,sys; d=json.load(sys.stdin); t=d["tiers"]
assert d["ref"]=="HEAD" and d["unprofiled"]==3, d
assert t["routine"]=={"verdict":"breach","why":"reverted 20.0% > 10%","window_days":90,"merged":5,"reverted":1,"escaped":0,"human_caught":0,"with_trailer":0,"demote":{"file":".specs/steering/autonomy.md","line":6,"from":"none","to":"spot"}}, t["routine"]
assert t["domain"]=={"verdict":"eligible","why":None,"window_days":90,"merged":5,"reverted":0,"escaped":1,"human_caught":0,"with_trailer":2,"demote":None}, t["domain"]
assert t["critical"]["verdict"]=="hold" and t["critical"]["why"]=="thresholds not set", t["critical"]' || fail "13c evidence: --json: $js"
mk src -m s6 -m "Human-Findings: 2"
out=$(el) && echo "$out" | grep -q "domain: breach (human-caught 33.3% > 10%)" || fail "13c evidence: human-caught breach: $out"
ev "${EVH}| routine | 90 | 3 | 10 | 20 | - |\n| domain | 90 | 100 | 10 | 50 | 10 |\n"
out=$(el) && echo "$out" | grep -q "domain: hold (merged 6 < min 100)" || fail "13c evidence: min merged: $out"
# demote: a breached tier names its profile row and one step stricter; eligible and hold print nothing; the profile is untouched
mkdir -p "$D/src/security"; mk src/security -m k1; K1=$(sha | cut -c1-7); mk src/security -m k2 -m "Fixes: $K1"
ev "${EVH}| routine | 90 | 3 | 10 | 20 | - |\n| domain | 90 | 2 | 10 | 50 | 10 |\n| critical | 90 | 1 | - | 10 | - |\n"; cp "$AP" "$TMP/ap.copy"
AR=.specs/steering/autonomy.md; out=$(el); echo "$out" | grep -q "critical: breach (escaped 20.0% > 10%)" || fail "13c demote: critical fixture is not in breach: $out"
echo "$out" | grep -qxF "  demote: $AR:6 Human none → spot (a human edit; tiers.py changes nothing)" || fail "13c demote: none → spot: $out"
echo "$out" | grep -qxF "  demote: $AR:7 Human spot → required (a human edit; tiers.py changes nothing)" || fail "13c demote: spot → required: $out"
echo "$out" | grep -qxF "  demote: $AR:8 Human required: already required" || fail "13c demote: required: $out"
cmp -s "$AP" "$TMP/ap.copy" || fail "13c demote: the profile changed"
js=$(el --json); printf '%s' "$js" | python3 -c 'import json,sys; t=json.load(sys.stdin)["tiers"]
assert t["routine"]["demote"]=={"file":".specs/steering/autonomy.md","line":6,"from":"none","to":"spot"}, t["routine"]
assert t["domain"]["demote"]=={"file":".specs/steering/autonomy.md","line":7,"from":"spot","to":"required"}, t["domain"]
assert t["critical"]["demote"]=={"file":".specs/steering/autonomy.md","line":8,"from":"required","to":None}, t["critical"]' || fail "13c demote: --json: $js"
ev "${EVH}| routine | 90 | 3 | 10 | 20 | - |\n| domain | 90 | 100 | 10 | 50 | 10 |\n| critical | 90 | 1 | - | 100 | - |\n"
out=$(el); echo "$out" | grep -q "domain: hold" && echo "$out" | grep -q "critical: eligible" && [ "$(echo "$out" | grep -c '^  demote:')" = 1 ] || fail "13c demote: eligible or hold got a demote line: $out"
js=$(el --json); printf '%s' "$js" | python3 -c 'import json,sys; t=json.load(sys.stdin)["tiers"]
assert t["domain"]["demote"] is None and t["critical"]["demote"] is None and t["routine"]["demote"] is not None, t' || fail "13c demote: --json null off breach: $js"
# the parent's table labels, not the working tree: docs no longer match routine, the counts do not move
TD='| routine | `nothing/*` | standard | none |\n| domain | `src/*` | standard | spot |\n| critical | `*/security/*` | deep | required |'
ev "${EVH}${EV1}"; js=$(el --json); printf '%s' "$js" | python3 -c 'import json,sys; t=json.load(sys.stdin)["tiers"]; assert t["routine"]["merged"]==5 and t["domain"]["merged"]==6, t' || fail "13c evidence: working-tree table relabelled history: $js"
TD='| routine | `docs/*` | standard | none |\n| domain | `src/*` | standard | spot |\n| critical | `*/security/*` | deep | required |'
bad() { ev "$2"; rc=0; out=$(el) || rc=$?; [ "$rc" = 2 ] && echo "$out" | grep -q "autonomy.md at [0-9a-f]*:[0-9]*: $3" || fail "13c evidence: $1 (exit $rc, want 2 and '$3'): $out"; }
bad "bad header" '\n## Evidence\n| Tier | Days |\n|---|---|\n| routine | 90 |\n' "header must be"
bad "bad window" "${EVH}| routine | abc | 3 | 10 | 20 | - |\n" "Window"
bad "zero window" "${EVH}| routine | 0 | 3 | 10 | 20 | - |\n" "Window"
bad "bad min" "${EVH}| routine | 90 | -1 | 10 | 20 | - |\n" "Min merged"
bad "percent over 100" "${EVH}| routine | 90 | 3 | 150 | 20 | - |\n" "Max reverted"
bad "wrong cell count" "${EVH}| routine | 90 | 3 |\n" "row needs 6 cells"
bad "unknown tier" "${EVH}| nosuch | 90 | 3 | 10 | 20 | - |\n" "unknown tier"
bad "duplicate tier" "${EVH}| routine | 90 | 3 | 10 | 20 | - |\n| routine | 90 | 3 | 10 | 20 | - |\n" "duplicate tier"
bad "non-ASCII window" "${EVH}| routine | ９０ | 3 | 10 | 20 | - |\n" "Window"
bad "non-ASCII percent" "${EVH}| routine | 90 | 3 | ４ | 20 | - |\n" "Max reverted"
# review fixes: merge commits, trailer denominators, trailer parsing, backdated commits, sha-256 (each repo is a bare-bones copy of the kit)
nr() { R="$TMP/$1"; shift; mkdir -p "$R/.specs/steering" "$R/.specs/kit" "$R/docs" "$R/src"; gitq -C "$R" init "$@"; cp -R "$KIT/kit/scripts" "$R/.specs/kit/scripts"
  printf '{"merged_ref": "main"}' > "$R/.specs/spec-kit.json"; N=0
  printf '# Autonomy\n\n## Tiers\n| Tier | Paths | Reviewer | Human |\n|---|---|---|---|\n%b\n%b' "$TD" "${EVH}${ER}" > "$R/.specs/steering/autonomy.md"
  gitq -C "$R" add -A; gitq -C "$R" commit -qm profile; }
mr() { d=$1; shift; N=$((N+1)); echo $N > "$R/$d/f$N"; gitq -C "$R" add "$d"; gitq -C "$R" commit -q "$@"; }
er() { python3 "$R/.specs/kit/scripts/tiers.py" --specs "$R/.specs" --evidence "$@" 2>&1; }
want() { out=$(er) && echo "$out" | grep -qF "$2" || fail "13c evidence: $1 (want '$2'): $out"; }
# a PR branch merged --no-ff: pr <name> <commit args...> (returns to main)
pr() { b=$1; shift; gitq -C "$R" checkout -q -b "$b"; mr docs "$@"; gitq -C "$R" checkout -q main; gitq -C "$R" merge -q --no-ff "$b" -m "merge $b"; }
ER='| routine | 90 | 1 | 10 | - | -  |\n| domain | 90 | 1 | - | - | - |\n'
nr t13e1 -b main; mr docs -m d0; pr p1 -m p1; P1=$(git -C "$R" rev-parse HEAD); pr p2 -m p2; pr p3 -m p3; pr p4 -m p4
gitq -C "$R" checkout -q -b rv; gitq -C "$R" revert --no-edit -m 1 "$P1"; gitq -C "$R" checkout -q main; gitq -C "$R" merge -q --no-ff rv -m "merge rv"
want "revert on a merged branch counts" "routine: breach (reverted 16.7% > 10%)"
ER='| routine | 90 | 1 | - | 10 | -  |\n| domain | 90 | 1 | - | - | - |\n'
nr t13e2 -b main; mr docs -m d0; pr p1 -m p1; B1=$(git -C "$R" rev-parse HEAD^2); pr p2 -m p2; pr p3 -m p3; pr p4 -m p4; pr fx -m fx -m "Fixes: $B1"
want "Fixes naming a branch commit counts" "routine: breach (escaped 16.7% > 10%)"
ER='| routine | 90 | 1 | - | - | - |\n| domain | 90 | 5 | - | - | 10 |\n'
nr t13e3 -b main; for i in 1 2 3 4 5 6 7 8; do mr src -m "s$i"; done; mr src -m s9 -m "Human-Findings: 1"; mr src -m s10 -m "Human-Findings: 1"
want "human-caught denominator is the commits with a trailer" "domain: hold (Human-Findings on 2 of 10 merges)"
printf '%s' "$out" > /dev/null; js=$(er --json); printf '%s' "$js" | python3 -c 'import json,sys; t=json.load(sys.stdin)["tiers"]["domain"]; assert t["with_trailer"]==2 and t["merged"]==10, t' || fail "13c evidence: with_trailer count: $js"
ER='| routine | 90 | 1 | - | - | - |\n| domain | 90 | 1 | - | - | 10 |\n'
nr t13e4 -b main; mr src -m s1 -m "Human-Findings: 2 (missing null check)"; mr src -m s2 -m "Human-Findings: 0" -m "Human-Findings: 3"
printf 's3\n\nHuman-Findings: 4\r\n' > "$TMP/crlf"; mr src -F "$TMP/crlf"; mr src -m s4 -m "Human-Findings: ٣"; mr src -m s5 -m "Human-Findings: 0"
printf 's6\n\nnote\rHuman-Findings: 3\n' > "$TMP/cr"; mr src -F "$TMP/cr"
want "malformed, repeated, CRLF and bare-CR trailers count as caught" "domain: breach (human-caught 83.3% > 10%)"
echo "$out" | grep -qF "human-caught 5 of 6 (83.3%)" || fail "13c evidence: human-caught names its denominator: $out"
ER='| routine | 90 | 1 | 10 | - | - |\n| domain | 90 | 1 | - | - | - |\n'
nr t13e5 -b main; mr docs -m a1; A1=$(git -C "$R" rev-parse HEAD); mr docs -m a2; gitq -C "$R" revert --no-edit "$A1"
export GIT_COMMITTER_DATE=2020-01-01T00:00:00; mr docs -m backdated; unset GIT_COMMITTER_DATE; mr docs -m c1; mr docs -m c2; mr docs -m c3
want "a backdated commit does not hide older history, and counts by position" "routine: breach (reverted 14.3% > 10%)"
nr t13e7 -b main; mr docs -m a1; A1=$(git -C "$R" rev-parse HEAD); mr docs -m a2; mr docs -m a3
export GIT_COMMITTER_DATE=2020-01-01T00:00:00; gitq -C "$R" revert --no-edit "$A1"; unset GIT_COMMITTER_DATE; mr docs -m c1
want "a backdated revert above a counted commit still counts, and is counted itself" "routine: breach (reverted 20.0% > 10%)"
if git init -q --object-format=sha256 "$TMP/t13e6x" 2>/dev/null; then
  nr t13e6 -q --object-format=sha256; mr docs -m a1; mr docs -m a2; gitq -C "$R" revert --no-edit HEAD~1
  want "a sha-256 revert counts" "routine: breach (reverted 33.3% > 10%)"
fi
ER='| routine | 90 | 1 | 10 | - | - |\n| domain | 90 | 1 | - | - | - |\n'
nr t13e8 -b main; mr docs -m a1; mr docs -m a2; mr docs -m a3
export GIT_COMMITTER_DATE=2020-01-01T00:00:00; mr docs -m backdated; unset GIT_COMMITTER_DATE; gitq -C "$R" revert --no-edit HEAD
want "a backdated commit above a dated one counts by position, and so does its revert" "routine: breach (reverted 20.0% > 10%)"
R="$TMP/t13e11"; gitq clone -q --depth 2 "file://$TMP/t13e8" "$R"
want "a shallow clone holds every tier with a row" "routine: hold (shallow clone: fetch the full history)"
echo "$out" | grep -qF "domain: hold (shallow clone: fetch the full history)" && echo "$out" | grep -qF "first-parent, shallow clone, not read" && echo "$out" | grep -qF "critical: hold (no Evidence row)" || fail "13c evidence: shallow clone: $out"
export GIT_COMMITTER_DATE=2020-01-01T00:00:00; nr t13e9 -b main; mr docs -m old1; export GIT_COMMITTER_DATE=2099-01-01T00:00:00; mr docs -m future
export GIT_COMMITTER_DATE=2020-01-01T00:00:00; mr docs -m old2; unset GIT_COMMITTER_DATE; mr docs -m recent
want "a future-dated commit below the window neither counts nor sets the cut" "routine: eligible — merged 1, reverted 0"
nr t13e10 -b main; mr docs -m bad; X=$(git -C "$R" rev-parse HEAD); mr docs -m c1; T=$(git -C "$R" rev-parse HEAD^{tree})
printf 'tree %s\nparent %s\nauthor a <a@a> 1700000000 +0000\ncommitter a <a@a> 1700000000 +0000\n\nThis reverts commit %s.\n' "$T" 1111111111111111111111111111111111111111 "$X" > "$TMP/orphan"
B=$(git -C "$R" hash-object --literally -t commit -w "$TMP/orphan"); M=$(git -C "$R" -c user.name=t -c user.email=t@t commit-tree "$T" -p main -p "$B" -m "merge rv")
gitq -C "$R" update-ref refs/heads/main "$M"; rc=0; out=$(er) || rc=$?
[ "$rc" = 2 ] && echo "$out" | grep -qF "cannot read the change set of $(echo "$M" | cut -c1-7)" || fail "13c evidence: an unreadable change set exits $rc, want 2: $out"
for a in "--range a..b" "--check"; do rc=0; el $a >/dev/null || rc=$?; [ "$rc" = 2 ] || fail "13c evidence: '--evidence $a' exits $rc, want 2"; done
nr t13e13 -b main; mr docs -m c1; T=$(git -C "$R" rev-parse HEAD^{tree}); P=$(git -C "$R" rev-parse HEAD)
printf 'tree %s\nparent %s\nauthor a <a@a> 1700000000 +0000\ncommitter a <a@a> notadate +0000\n\nbad date\n' "$T" "$P" > "$TMP/baddate"
B=$(git -C "$R" hash-object --literally -t commit -w "$TMP/baddate"); gitq -C "$R" update-ref refs/heads/main "$B"; mr docs -m top
rc=0; out=$(er) || rc=$?
[ "$rc" = 2 ] && echo "$out" | grep -qF "tiers: commit $(echo "$B" | cut -c1-7) has an unreadable committer date" || fail "13e evidence: an unparseable commit date exits $rc, want 2 naming $B: $out"

# refs/replace can swap a commit body: the revert below is replaced by a clean twin, and the breach must still show
ER='| routine | 90 | 1 | 10 | - | -  |\n| domain | 90 | 1 | - | - | - |\n'
nr "t13e14"; mr docs -m a1; A1=$(git -C "$R" rev-parse HEAD); mr docs -m a2; gitq -C "$R" revert --no-edit "$A1"; RV=$(git -C "$R" rev-parse HEAD); mr docs -m a3
CL=$(git -C "$R" -c user.name=t -c user.email=t@t commit-tree "$RV^{tree}" -p "$RV^" -m clean); gitq -C "$R" replace "$RV" "$CL"
want "13e14 a replace ref hid a revert" "routine: breach (reverted 25.0% > 10%)"

echo "11b. ready.py: Gates block vs the base's table and the head commit; no command run; --json; usage errors"
R="$TMP/t11b"; mkdir -p "$R/.specs/steering" "$R/src" "$R/.specs/kit"; gitq -C "$R" init; cp -R "$KIT/kit/scripts" "$R/.specs/kit/scripts"
printf '# Rules\n\n| # | Gate | Command |\n|---|---|---|\n| G1 | Lint | `echo a` |\n| G2 | Tests | `echo b` |\n' > "$R/.specs/steering/spec-rules.md"
echo a > "$R/src/a.txt"; gitq -C "$R" add -A; gitq -C "$R" commit -m base; RB=$(git -C "$R" rev-parse HEAD)
echo b > "$R/src/a.txt"; gitq -C "$R" add -A; gitq -C "$R" commit -m head; RH=$(git -C "$R" rev-parse --short HEAD)
rd() { python3 "$R/.specs/kit/scripts/ready.py" --specs "$R/.specs" --range "$RB..HEAD" "$@" 2>&1; }
RV() { printf '### Review\n- implementer: claude-sonnet-5-5\n- reviewer: gpt-5-1 (deep)\n- rules: %s\n- rounds: 1\n| Severity | Location | Evidence | Trigger | Consequence | Fix |\n|---|---|---|---|---|---|\n%b\n' "$(echo "$RB" | cut -c1-7)" "$1"; }
blk() { printf 'Body text\n\n### Gates\n%b\n- commit: %s\n- verdict: %s\n\n%s\nafter\n' "$1" "$2" "$3" "$(RV '| advisory | a.txt:1 | | | | follow-up |')"; }
OK='- G1 Lint: pass (a)\n- G2 Tests: pass (b)'
blk "$OK" "$RH" "ready (2 passed)" > "$R/pr.md"
out=$(rd --pr "$R/pr.md") && echo "$out" | grep -q "^### Readiness" && echo "$out" | grep -q "gates: 2/2 pass at $RH" && echo "$out" | grep -q "verdict: ready" && echo "$out" | grep -q "tier: human" || fail "11b: ready block: $out"
out=$(blk "$OK" "$RH" "ready (2 passed)" | rd) || fail "11b: stdin PR text: $out"
nr() { rc=0; out=$(printf '%s' "$2" | rd) || rc=$?; [ "$rc" = 1 ] && echo "$out" | grep -q "verdict: not ready" && echo "$out" | grep -q "$3" || fail "11b: $1 (exit $rc, want 1 and '$3'): $out"; }
nr "missing lane" "$(blk '- G1 Lint: pass (a)' "$RH" 'ready (1 passed)')" "G2 Tests"
nr "not-run lane" "$(blk '- G1 Lint: pass (a)\n- G2 Tests: not run' "$RH" 'ready (1 passed)')" "G2 Tests"
nr "failed lane" "$(blk '- G1 Lint: pass (a)\n- G2 Tests: FAIL (exit 1)' "$RH" 'not ready (1 failed, 0 not run)')" "G2 Tests"
nr "stale commit" "$(blk "$OK" "$(git -C "$R" rev-parse --short "$RB")" 'ready (2 passed)')" "commit"
nr "dirty commit" "$(blk "$OK" "$RH+dirty" 'ready (2 passed)')" "dirty"
nr "no verdict ready" "$(blk "$OK" "$RH" 'not ready (1 failed, 0 not run)')" "verdict"
nr "no Gates block" "just prose" "Gates"
nr "forged extra row" "$(blk '- G1 Lint: pass (a)\n- G2 Tests: FAIL (exit 1)\n- G2 Tests: pass (b)\n- G9 Forged: pass (x)' "$RH" 'ready (3 passed)')" "G2 Tests"
out=$(blk "$OK"'\n- G9 Forged: pass (x)' "$RH" 'ready (3 passed)' | rd) && echo "$out" | grep -q "G9 Forged" || fail "11b: extra row not reported: $out"
js=$(blk "$OK" "$RH" "ready (2 passed)" | rd --json) && printf '%s' "$js" | python3 -c 'import json,sys; d=json.load(sys.stdin); assert d["verdict"]=="ready" and d["gates"]["passed"]==2 and d["gates"]["total"]==2 and d["gates"]["commit"] and d["tier"]["tier"]=="human" and d["warnings"]==[] and "review" in d and "verification" in d, d' || fail "11b: --json shape: $js"
# a PR that edits the table is checked against the base's table; text never runs: a gate-looking command stays inert
printf '| # | Gate | Command |\n|---|---|---|\n| G1 | Lint | `touch pwned` |\n' > "$R/.specs/steering/spec-rules.md"; gitq -C "$R" add -A; gitq -C "$R" commit -m edit; RH=$(git -C "$R" rev-parse --short HEAD)
nr "head table instead of base" "$(blk '- G1 Lint: pass (a)' "$RH" 'ready (1 passed)')" "G2 Tests"
[ ! -e "$R/pwned" ] || fail "11b: ready.py ran a command"
nr "gate removed at the head, honest block" "$(blk "$OK" "$RH" 'ready (2 passed)')" "Gates table changed in this change"
printf '| # | Gate | Command |\n|---|---|---|\n| G1 | Lint | `echo lint ok` |\n| G2 | Tests | `echo b` |\n' > "$R/.specs/steering/spec-rules.md"; gitq -C "$R" add -A; gitq -C "$R" commit -m cmd; RH=$(git -C "$R" rev-parse --short HEAD)
nr "gate command changed at the head, honest block" "$(blk "$OK" "$RH" 'ready (2 passed)')" "Gates table changed in this change"
printf '| # | Gate | Command |\n|---|---|---|\n| G0 | Format | `echo fmt` |\n| G1 | Lint | `echo a` |\n| G2 | Tests | `echo b` |\n' > "$R/.specs/steering/spec-rules.md"; gitq -C "$R" add -A; gitq -C "$R" commit -m prepend; RH=$(git -C "$R" rev-parse --short HEAD)
nr "gate prepended at the head, base rows unchanged" "$(blk "$OK\n- G0 Format: pass (fmt)" "$RH" 'ready (3 passed)')" "Gates table changed in this change"
printf '| # | Gate | Command |\n|---|---|---|\n| G1 | Lint | `true` |\n| G1 | Lint | `echo a` |\n| G2 | Tests | `echo b` |\n' > "$R/.specs/steering/spec-rules.md"; gitq -C "$R" add -A; gitq -C "$R" commit -m dup; RH=$(git -C "$R" rev-parse --short HEAD)
nr "duplicate label at the head" "$(blk "$OK" "$RH" 'ready (2 passed)')" "Gates table changed in this change"
printf '# Rules\n\n| # | Gate | Command |\n|---|---|---|\n| G1 | Lint | `echo a` |\n| G2 | Tests | `echo b` |\n' > "$R/.specs/steering/spec-rules.md"; gitq -C "$R" add -A; gitq -C "$R" commit -m restore; RH=$(git -C "$R" rev-parse --short HEAD)
nr "tree changed during gates" "$(blk "$OK\n- tree changed during gates" "$RH" 'ready (2 passed)')" "gates changed the tree"
nr "FAIL with a negative exit" "$(blk '- G1 Lint: pass (a)\n- G2 Tests: FAIL (exit -9)' "$RH" 'not ready (1 failed, 0 not run)')" "G2 Tests' is FAIL"
# staged mode: block commit must be HEAD, +dirty allowed
echo s > "$R/src/s.txt"; gitq -C "$R" add -A; H=$(git -C "$R" rev-parse --short HEAD)
{ printf '### Gates\n- G1 Lint: pass (a)\n- G2 Tests: pass (b)\n- commit: %s+dirty\n- verdict: ready (2 passed)\n' "$H"; printf '### Review\n- implementer: claude-sonnet-5-5\n- reviewer: gpt-5-1 (deep)\n- rules: %s\n' "$H"; } | python3 "$R/.specs/kit/scripts/ready.py" --specs "$R/.specs" >/dev/null 2>&1; rc=$?
[ "$rc" = 0 ] || fail "11b: staged mode with +dirty exits $rc, want 0"
for a in "--bogus" "--range" "--range nodots" "--pr" "--pr $R/nosuch.md"; do
  rc=0; python3 "$R/.specs/kit/scripts/ready.py" --specs "$R/.specs" $a </dev/null >/dev/null 2>&1 || rc=$?; [ "$rc" = 2 ] || fail "11b: 'ready.py $a' exits $rc, want 2"
done
rc=0; python3 "$R/.specs/kit/scripts/ready.py" --specs "$R/.specs" --range nosuch..HEAD </dev/null >/dev/null || rc=$?; [ "$rc" = 2 ] || fail "11b: unresolvable range exits $rc, want 2"
printf '{bad' > "$R/.specs/spec-kit.json"; rc=0; blk "$OK" "$RH" 'ready (2 passed)' | rd >/dev/null || rc=$?; rm "$R/.specs/spec-kit.json"; [ "$rc" = 2 ] || fail "11b: --range with a bad spec-kit.json exits $rc, want 2"

echo "11c. ready.py: ### Review block: model ids, families, rules at the base, blocker form, --json review"
rv() { blk "$OK" "$RH" "ready (1 passed)" | sed '/^### Review/,$d'; RV "$1"; }
RO=$(rv '| advisory | a.txt:1 | | | | follow-up: tasks.md task 9 |'); out=$(printf '%s' "$RO" | rd) && echo "$out" | grep -q "verdict: ready" || fail "11c: valid review: $out"
nr "no review block" "$(blk "$OK" "$RH" 'ready (1 passed)' | sed '/^### Review/,$d')" "Review"
nr "missing reviewer id" "$(printf '%s' "$RO" | sed 's/^- reviewer: .*/- reviewer: /')" "reviewer"
nr "rules not the base" "$(printf '%s' "$RO" | sed "s/^- rules: .*/- rules: $RH/")" "rules"
out=$(printf '%s' "$RO" | sed 's/gpt-5-1/claude-opus-5-5/' | rd) && echo "$out" | grep -q "warning: .*family" || fail "11c: same family is a warning only: $out"
for rf in claude_opus_5_5 opus-5-5 anthropic:claude-opus; do
  out=$(printf '%s' "$RO" | sed "s/gpt-5-1/$rf/" | rd) && echo "$out" | grep -q "warning: .*family" || fail "11c: $rf is the implementer's family: $out"
done
nr "repeated implementer line" "$(printf '%s' "$RO" | sed 's/^- implementer: .*/&\n&/')" "review implementer repeated: one line per Review block"
nr "repeated rules line" "$(printf '%s' "$RO" | sed 's/^- rules: .*/&\n&/')" "review rules repeated"
BL='| blocker | src/a.c:42 | "if (t > 0)" | total 0 | ships free | >= 0 |'
nr "open blocker" "$(rv "$BL")" "blocker at src/a.c:42"
out=$(rv '| blocker | src/a.c:42 | | total 0 | ships free | x |' | rd) && echo "$out" | grep -q "advisory (no evidence)" || fail "11c: blocker without evidence is advisory: $out"
nr "blocker with an unreadable location" "$(rv '| blocker | nowhere | "q" | t | c | x |')" "blocker location unreadable: nowhere"
nr "blocker with a list location" "$(rv '| blocker | src/a.c:1,7 | "q" | t | c | x |')" "blocker location unreadable: src/a.c:1,7"
out=$(rv '| blocker | | "q" | t | c | x |' | rd) && echo "$out" | grep -q "advisory (no location)" || fail "11c: blocker without a location is advisory: $out"
js=$(rv "$BL" | rd --json) || true; printf '%s' "$js" | python3 -c 'import json,sys; d=json.load(sys.stdin); r=d["review"]; assert d["verdict"]=="not ready" and r["implementer"]=="claude-sonnet-5-5" and r["reviewer"]=="gpt-5-1" and r["same_family"] is False and len(r["blockers"])==1 and r["advisories"]==[] and r["problems"], d' || fail "11c: --json review shape: $js"

echo "11d. ready.py: ### Verification lines: REQ defined, path at the head, URL declared not fetched, --json verification"
mkdir -p "$R/.specs/features/f" "$R/docs"; printf '### [REQ-F-01] x\n' > "$R/.specs/features/f/requirements.md"; echo png > "$R/docs/a.png"; ln -s /etc/hosts "$R/docs/link.png"
gitq -C "$R" add -A; gitq -C "$R" commit -m art; RH=$(git -C "$R" rev-parse --short HEAD)
vb() { blk "$OK" "$RH" "ready (2 passed)" | sed '/^### Review/,$d'; RV '| advisory | a.txt:1 | | | | f |'; printf '\n### Verification\n%b\n' "$1"; }
out=$(vb '- [REQ-F-01] docs/a.png: shows it\n- [REQ-F-01] https://ci.example/r/1.mp4: video' | rd) && echo "$out" | grep -q "https://ci.example/r/1.mp4: declared, not fetched" && echo "$out" | grep -q "docs/a.png: ok" || fail "11d: valid lines: $out"
nr "unknown REQ" "$(vb '- [REQ-F-99] docs/a.png: x')" "REQ-F-99"
nr "missing path" "$(vb '- [REQ-F-01] docs/none.png: x')" "missing at the head"
nr "path with .." "$(vb '- [REQ-F-01] ../etc/hosts: x')" "outside the repository"
nr "absolute path" "$(vb '- [REQ-F-01] /etc/hosts: x')" "outside the repository"
nr "symlink out" "$(vb '- [REQ-F-01] docs/link.png: x')" "symlink or not a file"
nr "malformed line" "$(vb '- REQ-F-01 docs/a.png')" "verification line"
out=$(vb '- [REQ-F-01] ./docs/a.png: x' | rd) && echo "$out" | grep -q "./docs/a.png: ok" || fail "11d: ./ path to a real file: $out"
for t in docs docs/ .; do nr "directory target $t" "$(vb "- [REQ-F-01] $t: x")" "not a file"; done
js=$(vb '- [REQ-F-01] docs/a.png: s' | rd --json) && printf '%s' "$js" | python3 -c 'import json,sys; d=json.load(sys.stdin); assert d["verification"]=={"lines":[{"req":"REQ-F-01","target":"docs/a.png","status":"ok"}],"problems":[]}, d' || fail "11d: --json verification shape: $js"
js=$(blk "$OK" "$RH" "ready (2 passed)" | rd --json) && printf '%s' "$js" | python3 -c 'import json,sys; d=json.load(sys.stdin); assert d["verdict"]=="ready" and d["verification"]["lines"]==[], d' || fail "11d: no block is ready: $js"

echo "11e. ready.py: head gate commands, staged base and stale block, blocker forms, tiers, ids, hidden blocks, no __pycache__"
rv() { blk "$OK" "$RH" "ready (1 passed)" | sed '/^### Review/,$d'; RV "$1"; }
for loc in 'src/a.c:42–45' 'src/a.c:42-45' 'src/a.c:42:7' '`src/a.c:42`' 'src/a.c#L42' 'src/a.c#L42-L45'; do
  nr "blocker location $loc" "$(rv "| blocker | $loc | \"q\" | t | c | x |")" "open blocker"
done
RO=$(rv '| advisory | a.txt:1 | | | | f |')
out=$(printf '%s' "$RO" | sed 's/(deep)/(standard)/' | rd) && echo "$out" | grep -q "reviewer tier below the label's reviewer" || fail "11e: reviewer tier below the label is not warned: $out"
for id in anthropic/claude-opus-5-5 us.anthropic.claude-opus-5-5-v1:0 bedrock/claude-opus-5-5 bedrock/anthropic.claude-opus-5-5; do
  out=$(printf '%s' "$RO" | sed "s|gpt-5-1|$id|" | rd) && echo "$out" | grep -q "warning: .*family" || fail "11e: provider-prefixed id $id not compared by family: $out"
done
GOOD=$(blk "$OK" "$RH" "ready (2 passed)")
out=$(printf '%s\n<!--\n### Gates\n- G1 Lint: pass (x)\n-->\n```\n### Gates\n- G1 Lint: pass (y)\n```\n' "$GOOD" | rd) || fail "11e: a Gates block in a comment or fence is counted: $out"
nr "Gates block only in a comment" "$(printf 'x\n<!--\n%s\n-->\n' "$GOOD")" "exactly one ### Gates"
# staged mode: base = merge-base with merged_ref, head = index
S2="$TMP/t11e"; mkdir -p "$S2/.specs/steering" "$S2/.specs/features/f" "$S2/docs" "$S2/src" "$S2/.specs/kit"; gitq -C "$S2" init; cp -R "$KIT/kit/scripts" "$S2/.specs/kit/scripts"
printf '{"merged_ref": "main"}' > "$S2/.specs/spec-kit.json"; printf '### [REQ-F-01] x\n' > "$S2/.specs/features/f/requirements.md"; echo p > "$S2/docs/a.png"
printf '# Rules\n\n| # | Gate | Command |\n|---|---|---|\n| G1 | Lint | `echo a` |\n| G2 | Tests | `echo b` |\n' > "$S2/.specs/steering/spec-rules.md"
echo a > "$S2/src/a.txt"; gitq -C "$S2" add -A; gitq -C "$S2" commit -m base; MB=$(git -C "$S2" rev-parse --short HEAD); gitq -C "$S2" checkout -b work
sr() { python3 "$S2/.specs/kit/scripts/ready.py" --specs "$S2/.specs" 2>&1; }
sg() { printf '### Gates\n- G1 Lint: pass (a)\n%b- commit: %s\n- verdict: ready (%s passed)\n\n### Review\n- implementer: claude-sonnet-5-5\n- reviewer: gpt-5-1 (deep)\n- rules: %s\n%s' "$2" "$1" "$3" "$MB" "${4:-}"; }
snr() { rc=0; out=$(printf '%s' "$2" | sr) || rc=$?; [ "$rc" = 1 ] && echo "$out" | grep -q "$3" || fail "11e: staged $1 (exit $rc, want 1 and '$3'): $out"; }
echo s > "$S2/src/s.txt"; gitq -C "$S2" add -A; W=$(git -C "$S2" rev-parse --short HEAD)
G2='- G2 Tests: pass (b)\n'
snr "clean-HEAD block with staged files" "$(sg "$W" "$G2" 2)" "staged"
out=$(sg "$W+dirty" "$G2" 2 | sr) || fail "11e: staged +dirty block should be ready: $out"
snr "directory target in the index" "$(sg "$W+dirty" "$G2" 2; printf '\n### Verification\n- [REQ-F-01] docs: x\n')" "not a file"
printf '| # | Gate | Command |\n|---|---|---|\n| G1 | Lint | `echo a` |\n' > "$S2/.specs/steering/spec-rules.md"; gitq -C "$S2" add -A; gitq -C "$S2" commit -m drop-g2; W=$(git -C "$S2" rev-parse --short HEAD)
snr "worker-committed gate removal, block lists both" "$(sg "$W+dirty" "$G2" 2)" "Gates table changed in this change"
snr "worker-committed gate removal, block lists one" "$(sg "$W+dirty" "" 1)" "G2 Tests"
printf '| # | Gate | Command |\n|---|---|---|\n| G1 | Lint | `echo ok` |\n| G2 | Tests | `echo b` |\n' > "$S2/.specs/steering/spec-rules.md"; gitq -C "$S2" add -A; gitq -C "$S2" commit -m cmd; W=$(git -C "$S2" rev-parse --short HEAD)
snr "worker-committed command change" "$(sg "$W+dirty" "$G2" 2)" "Gates table changed in this change"
python3 "$S2/.specs/kit/scripts/spec_lint.py" --specs "$S2/.specs" >/dev/null 2>&1 || true
python3 "$S2/.specs/kit/scripts/tiers.py" --specs "$S2/.specs" >/dev/null 2>&1 || true
[ -z "$(find "$S2/.specs/kit/scripts" "$R/.specs/kit/scripts" -name __pycache__)" ] || fail "11e: a kit script left a __pycache__ in the installed kit"

echo "14. end to end: the acme Tiers table in an installed repo labels real paths, and ready.py gives the verdict"
E="$TMP/t14"; mkdir -p "$E"; gitq -C "$E" init; "$KIT/install.sh" "$E" >/dev/null
cp "$KIT/examples/acme-shop/.specs/steering/autonomy.md" "$E/.specs/steering/autonomy.md"
python3 "$E/.specs/kit/scripts/tiers.py" --specs "$E/.specs" --check >/dev/null || fail "14: acme Tiers table fails --check"
printf '# Rules\n\n| # | Gate | Command |\n|---|---|---|\n| G1 | Lint | `echo a` |\n' > "$E/.specs/steering/spec-rules.md"
gitq -C "$E" add -A; gitq -C "$E" commit -m base; EB=$(git -C "$E" rev-parse HEAD)
et() { python3 "$E/.specs/kit/scripts/tiers.py" --specs "$E/.specs" --range "$EB..HEAD" 2>&1; }
chg() { git -C "$E" reset -q --hard "$EB"; for f in "$@"; do mkdir -p "$E/$(dirname "$f")"; echo x >> "$E/$f"; done; gitq -C "$E" add -A; gitq -C "$E" commit -m chg; }
chg orders-api/src/test/java/com/acme/shop/orders/order/rest/FooTest.java; et | grep -q "tier: routine" || fail "14: test file not routine: $(et)"
chg orders-api/src/main/java/com/acme/shop/orders/order/OrderService.java; et | grep -q "tier: domain" || fail "14: order source not domain: $(et)"
chg orders-api/src/main/java/com/acme/shop/orders/order/OrderService.java shop-common/src/main/java/com/acme/shop/security/GrpcSecurityFilter.java
et | grep -q "tier: critical" && et | grep -q "GrpcSecurityFilter" || fail "14: GrpcSecurityFilter does not win: $(et)"
EH=$(git -C "$E" rev-parse --short HEAD)
pr() { printf '### Gates\n- G1 Lint: pass (a)\n- commit: %s\n- verdict: ready (1 passed)\n\n### Review\n- implementer: claude-sonnet-5-5\n- reviewer: gpt-5-1 (deep)\n- rules: %s\n' "$1" "$(echo "$EB" | cut -c1-7)"; }
out=$(pr "$EH" | python3 "$E/.specs/kit/scripts/ready.py" --specs "$E/.specs" --range "$EB..HEAD" 2>&1) && echo "$out" | grep -q "verdict: ready" && echo "$out" | grep -q "tier: critical" || fail "14: ready verdict: $out"
rc=0; pr "$EB" | python3 "$E/.specs/kit/scripts/ready.py" --specs "$E/.specs" --range "$EB..HEAD" >/dev/null 2>&1 || rc=$?; [ "$rc" = 1 ] || fail "14: stale commit exits $rc, want 1"

echo "14b. the eight guardrail rows: template undeclared, acme declared; an undeclared row seven turns none into spot"
python3 -I - "$KIT/kit/scripts" "$KIT/kit/templates/steering/autonomy.md" "$E/.specs/steering/autonomy.md" <<'PY2' || fail "14b: guardrail rows"
import sys; sys.dont_write_bytecode = True; sys.path.insert(0, sys.argv[1])
import tiers
t = tiers.parse_guardrails(open(sys.argv[2]).read()); a = tiers.parse_guardrails(open(sys.argv[3]).read())
assert len(t) == 8 and all(r[4] for r in t), ("template: eight undeclared rows", t)
assert len(a) == 8 and not any(r[4] for r in a), ("acme: eight declared rows", a)
assert "untrusted text" in t[6][0] and "clean clone" in t[7][0], "rows seven and eight"
assert a[6][1].startswith("no such job, checked"), "acme row seven: no such job, dated"
PY2
chg orders-api/src/test/java/com/acme/shop/orders/order/rest/FooTest.java; et | grep -q "human: spot" && et | grep -q "guardrails: 8 declared$" || fail "14b: acme declared rows (no earned evidence in a sandbox) did not give spot: $(et)"
git -C "$E" reset -q --hard "$EB"
python3 - "$E/.specs/steering/autonomy.md" <<'PY2'
import sys; p = sys.argv[1]; s = open(p).read().splitlines(True)
i = next(n for n, l in enumerate(s) if "untrusted text" in l)
s[i] = s[i].split("|")[0] + "|" + s[i].split("|")[1] + "| <CI permissions and the platform's safe-output step> | <YYYY-MM-DD> |\n"
open(p, "w").write("".join(s))
PY2
gitq -C "$E" commit -qam "row seven undeclared"; E7=$(git -C "$E" rev-parse HEAD)
mkdir -p "$E/docs"; echo x >> "$E/docs/x.md"; gitq -C "$E" add -A; gitq -C "$E" commit -qm docs
out=$(python3 "$E/.specs/kit/scripts/tiers.py" --specs "$E/.specs" --range "$E7..HEAD" 2>&1) && echo "$out" | grep -q "tier: routine (reviewer: standard, human: spot)" && echo "$out" | grep -q "guardrails: 1 of 8 undeclared, none → spot" || fail "14b: undeclared row seven did not downgrade none: $out"
out=$(python3 "$E/.specs/kit/scripts/tiers.py" --specs "$E/.specs" --check 2>&1) && echo "$out" | grep -q "autonomy.md:[0-9]*: undeclared (placeholder in Enforced by)" || fail "14b: --check did not list row seven: $out"

echo "selftest: OK"
