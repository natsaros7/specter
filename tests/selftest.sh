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
[ "$(grep -c 'spec-first-kit:begin' "$P/AGENTS.md")" = 1 ] || fail "duplicate marker block"
for f in .agents/skills/spec-first/SKILL.md .specs/kit/roles/reviewer.md .claude/agents/reviewer.md .specs/kit/playbooks/setup.md .specs/spec-kit.json .cursor/rules/spec-first.mdc .claude/skills/spec-first/SKILL.md .git/hooks/pre-commit; do
  [ -e "$P/$f" ] || fail "missing $f"
done
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

echo "6. uninstall keeps user content"
"$KIT/install.sh" "$P" --uninstall >/dev/null
[ ! -e "$P/.agents/skills/spec-first" ] || fail "codex skill left"
[ ! -e "$P/.specs/kit" ] && [ ! -e "$P/AGENTS.md" ] && [ ! -e "$P/.claude/agents/reviewer.md" ] && [ ! -e "$P/.git/hooks/pre-commit" ] || fail "uninstall left kit files"
grep -q "keep me" "$P/CLAUDE.md" && ! grep -q "spec-first-kit" "$P/CLAUDE.md" || fail "CLAUDE.md not restored"

echo "selftest: OK"
