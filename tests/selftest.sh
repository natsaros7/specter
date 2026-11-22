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
GT="$TMP/t12g"; mkdir -p "$GT/.specs/steering"; gitq -C "$GT" init
printf '| # | Gate | Command |\n|---|---|---|\n| G1 | makes output | `touch out.log; echo made` |\n' > "$GT/.specs/steering/spec-rules.md"
gitq -C "$GT" add .; gitq -C "$GT" commit -m x
gates() { python3 "$KIT/kit/scripts/gates.py" --specs "$GT/.specs" "$@"; }
for a in --bogus --file=x; do rc=0; out=$(gates "$a" 2>&1) || rc=$?; [ "$rc" = 2 ] && [ ! -e "$GT/out.log" ] || fail "gates.py ran with unknown argument $a: rc=$rc $out"; done
rc=0; out=$(gates --help 2>&1) || rc=$?; [ "$rc" = 0 ] && echo "$out" | grep -q "^Usage:" && [ ! -e "$GT/out.log" ] || fail "gates.py --help: rc=$rc $out"
out=$(gates 2>/dev/null) || fail "gates.py green run"; echo "$out" | grep -Eq "^- commit: [0-9a-f]{7,}$" || fail "commit taken after the gates ran: $out"
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
tprof() { printf '# Autonomy\n\n## Knowledge\n| Knowledge | Where | Read |\n|---|---|---|\n| Decisions | [adrs](../../docs/adr/) | start |\n\n## Tiers\n| Tier | Paths | Reviewer | Human |\n|---|---|---|---|\n%b\n' "$1" > "$B/.specs/steering/autonomy.md"; }
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
python3 "$B/.specs/kit/scripts/tiers.py" --bogus >/dev/null 2>&1 && fail "13b: unknown flag exits 0"
tprof "$GOOD"; gitq -C "$B" add .; gitq -C "$B" commit -m profile; tprof '| critical | `*` | deep | required |'
python3 -I - "$B" "$KIT/kit/scripts" <<'PY' || fail "13b: guarded globs or base read"
import sys; sys.path.insert(0, sys.argv[2])
import tiers, install
root = sys.argv[1]
txt = tiers.profile_at(root, "HEAD", ".specs/steering/autonomy.md")
assert txt and "src/*" in txt, "profile_at must read the committed text, not the working tree"
assert tiers.profile_at(root, "HEAD", ".specs/steering/none.md") is None
g = tiers.guarded_globs(txt, ".specs/steering/autonomy.md")
assert "docs/adr/*" in g and ".specs/steering/*" in g and "AGENTS.md" in g, g
for a in install.AGENTS.values():
    assert any(x.startswith(a[3].split("/")[0] + "/") for x in g), ("agent dir not guarded", a[3])
PY
echo "13b. tiers.py label: staged and --range, strictest file wins, guarded path takes the last row, base table rules, --json, usage errors"
tl() { python3 "$B/.specs/kit/scripts/tiers.py" --specs "$B/.specs" "$@" 2>&1; }
mkdir -p "$B/tests" "$B/src/security" "$B/docs"; echo a > "$B/tests/a.txt"; echo a > "$B/docs/d.md"; echo a > "$B/src/s.txt"
tprof "$GOOD"; gitq -C "$B" add -A; gitq -C "$B" commit -m base2; BASE=$(git -C "$B" rev-parse HEAD)
echo b > "$B/docs/d.md"; gitq -C "$B" add -A
out=$(tl) && echo "$out" | grep -q "tier: routine (reviewer: standard, human: none)" && echo "$out" | grep -q "^### Risk tier" || fail "13b: staged docs change not routine: $out"
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
js=$(tl --range "$BASE...HEAD" --json) && printf '%s' "$js" | python3 -c 'import json,sys; d=json.load(sys.stdin); assert d["tier"]=="routine" and d["reviewer"]=="standard" and d["human"]=="none" and d["set_by"]["file"]=="tests/z.txt" and d["set_by"]["glob"]=="tests/*" and d["counts"]=={"routine":1} and d["profile_commit"]=="'"$BASE"'" and d["labels_only"] is True, d' || fail "13b: --json shape: $js"
# a branch that rewrites the Tiers table is labelled by the base's table
tprof '| critical | `*` | deep | required |'; ( cd "$B" && echo q > docs/e.md ); gitq -C "$B" add -A; gitq -C "$B" commit -m rewrite
out=$(tl --range "$BASE..HEAD") && echo "$out" | grep -q "tier: critical" || fail "13b: guarded profile edit not critical: $out"
tprof '| critical | `*` | deep | required |'; gitq -C "$B" add -A; gitq -C "$B" commit -q -m same || true
echo w > "$B/docs/w.md"; gitq -C "$B" add docs/w.md
out=$(tl) && echo "$out" | grep -q "tier: critical" || fail "13b: head table not used for staged: $out"
N="$TMP/t13b-none"; mkdir -p "$N/.specs/steering"; gitq -C "$N" init; echo x > "$N/x"; gitq -C "$N" add -A; gitq -C "$N" commit -m x; echo y > "$N/x"; gitq -C "$N" add -A
out=$(python3 "$B/.specs/kit/scripts/tiers.py" --specs "$N/.specs" 2>&1) && echo "$out" | grep -q "no autonomy profile at" && echo "$out" | grep -q "human: required" || fail "13b: no profile at base is not the human tier: $out"
for a in "--range" "--range nodots" "--check --range a..b" "--json --check" "--range a..b --range c..d"; do
  rc=0; tl $a >/dev/null || rc=$?; [ "$rc" = 2 ] || fail "13b: 'tiers.py $a' exits $rc, want 2"
done
rc=0; tl --range nosuch..HEAD >/dev/null || rc=$?; [ "$rc" = 2 ] || fail "13b: unresolvable range exits $rc, want 2"

echo "selftest: OK"
