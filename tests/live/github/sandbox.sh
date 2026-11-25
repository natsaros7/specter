#!/bin/sh
# Live-recipe sandbox kit (v070 task 2). Nothing here writes to GitHub on its own.
#   sandbox.sh seed <dir>             build the sandbox repository locally (no network); <dir> must be new, under $HOME
#   sandbox.sh dry-run <dir>          run every scenario's ready.py call against a local bare origin; exit 0 = all as expected
#   sandbox.sh open <dir> <id> [--yes] make scenario <id> (K1 N1 N2 N3 N4 P1 N5 N6 P2) as a local branch with its PR text,
#                                      then PRINT the push and `gh pr create` commands. Only --yes runs them.
# Which scenario does what, and what is expected: .specs/features/v070-live-and-eval/design.md, "Scenarios".
set -eu
HERE=$(cd "$(dirname "$0")" && pwd)
REPO=$(cd "$HERE/../../.." && pwd)
export PYTHONDONTWRITEBYTECODE=1
g() { git -c user.name=specter-live -c user.email=live@example.invalid -c init.defaultBranch=main "$@"; }
die() { echo "sandbox: $*" >&2; exit 2; }

# An absolute path under $HOME, resolved ($HOME alone is refused): the Docker runtimes this repo targets share only $HOME.
resolve() {
  [ -n "${1-}" ] || die "usage: sandbox.sh seed|dry-run|open <dir> ..."
  mkdir -p "$1"; d=$(cd "$1" && pwd -P); h=$(cd "$HOME" && pwd -P)
  case $d in "$h"/?*) echo "$d" ;; *) die "$d is not under $h" ;; esac
}

seed() {
  d=$(resolve "${1-}"); [ -z "$(ls -A "$d")" ] || die "$d is not empty"
  today=$(date +%F)
  # git init first: the installer then puts its pre-commit hook in this repository, which we drop.
  g init -q "$d"; "$REPO/install.sh" "$d" >/dev/null; rm -f "$d/.git/hooks/pre-commit"
  mkdir -p "$d/.github/workflows" "$d/docs"
  printf '{"merged_ref": "refs/remotes/origin/main"}\n' > "$d/.specs/spec-kit.json"
  cat > "$d/.specs/steering/spec-rules.md" <<'EOF'
# Spec rules (sandbox)

| # | Gate | Command |
|---|---|---|
| G1 | Spec lint | `python3 .specs/kit/scripts/spec_lint.py` |
EOF
  cat > "$d/.specs/steering/autonomy.md" <<EOF
# Steering: Autonomy profile (live sandbox)

## Tiers
| Tier | Paths | Reviewer | Human |
|---|---|---|---|
| routine | \`docs/*\` | standard | none |
| critical | \`.github/*\` | deep | required |

## Guardrails
| Guardrail | Enforced by | Verified |
|---|---|---|
| No direct or force push to the default branch | ruleset "main": no deletion, no force push, PR required | $today |
| The Gates run as required checks before a merge | ruleset "main": required check \`gates\`, branches up to date | $today |
| Every PR needs an approval, dropped on a new commit; a human gives it, and only the \`ready.py --auto-merge\` job's identity (never an agent's) approves a PR labelled \`none\` | ruleset "main": 1 approval, stale dismissed; the approver is a GitHub App whose key is a secret of environment \`specter-approver\` (deployment branch main only) | $today |
| Agent credentials cannot approve or merge | no agent runs here; GITHUB_TOKEN cannot approve (workflow permission setting off) | $today |
| Agent permissions come from the host's configuration, not from a prompt | no agent job here, checked .github/workflows/ | $today |
| Agents cannot edit merged history or review records, or create tags or \`refs/replace/\` refs | ruleset "main" (no force push); no agent has write access to the repository | $today |
| An agent job triggered by untrusted text (an issue, a PR, a comment, an outside contribution) runs read-only, without secrets | no such job, checked .github/workflows/ | $today |
| Scheduled chores run from a clean clone or the CI checkout of the default branch, never a working copy | no chores, checked .github/workflows/ (no schedule trigger) | $today |

## Evidence
| Tier | Window (days) | Min merged | Max reverted % | Max escaped % | Max human-caught % |
|---|---|---|---|---|---|
| routine | 90 | 2 | 50 | 50 | - |
EOF
  cp "$HERE/gates.yml" "$d/.github/workflows/gates.yml"
  # the template, plus the sandbox-only sleep between the check and the approval (scenario N6)
  awk '/^      # sandbox-delay:/ {
         print "      - name: Sandbox delay (live test only)"
         print "        if: steps.check.outputs.rc == '"'0'"'"
         print "        env:"
         print "          DELAY: ${{ vars.SANDBOX_DELAY }}"
         print "        run: sleep \"${DELAY:-0}\""
         next } { print }' "$REPO/kit/templates/github/specter-auto-merge.yml" > "$d/.github/workflows/specter-auto-merge.yml"
  grep -q 'Sandbox delay' "$d/.github/workflows/specter-auto-merge.yml" || die "the template lost its sandbox-delay marker"
  echo "specter $(g -C "$REPO" rev-parse HEAD 2>/dev/null || echo unknown)" > "$d/docs/SANDBOX.md"
  g -C "$d" add -A; g -C "$d" commit -qm "chore: sandbox base"
  for i in 1 2; do echo "seed $i" > "$d/docs/seed-$i.md"; g -C "$d" add -A; g -C "$d" commit -qm "docs: seed $i"; done
  echo "seeded $d (3 commits on main). Next: add the remote, see README, task 6."
}

# ---- scenarios; run inside a clone whose origin/main is the base ----
mkdocs() { i=1; while [ "$i" -le "$1" ]; do echo "$BR $i" > "docs/$(echo "$BR" | tr / -)-$i.md"; i=$((i+1)); done; }

# setup <id> <base ref>: branch, change, commit. Sets BR IMPL REV LVL CX.
setup() {
  BR=live/$(echo "$1" | tr 'A-Z' 'a-z'); IMPL=claude-sonnet-5-5; REV=gpt-5-1; LVL=standard; CX=trivial
  case $1 in N5|P2) BR=slow/$(echo "$1" | tr 'A-Z' 'a-z') ;; esac
  g checkout -q -B "$BR" "$2"
  case $1 in
    K1) mkdir -p .github/workflows; cp "$HERE/probe.yml" .github/workflows/probe.yml; LVL=deep ;;
    N1) mkdocs 4 ;;
    N2) mkdocs 1; CX=non-trivial ;;
    N3) mkdocs 1; REV=claude-opus-5-5 ;;
    N4|P1|N5|N6|P2) mkdocs 1 ;;
    *) die "unknown scenario '$1' (K1 N1 N2 N3 N4 P1 N5 N6 P2)" ;;
  esac
  g add -A; g commit -qm "docs: live scenario $1"
}

# body <base ref>: the PR text for the commit at HEAD: the Gates block from gates.py, then the Review block
body() {
  gb=$(python3 .specs/kit/scripts/gates.py 2>&1) || die "gates.py failed: $gb"
  printf '%s\n\n### Review\n- implementer: %s\n- reviewer: %s (%s)\n- rules: %s\n- rounds: 1\n- complexity: %s\n' \
    "$gb" "$IMPL" "$REV" "$LVL" "$(g merge-base "$1" HEAD | cut -c1-7)" "$CX"
}

# ready <base ref> <pr file>: the job's check, as the workflow runs it
ready() {
  python3 .specs/kit/scripts/ready.py --specs .specs --range "$(g rev-parse "$1")...$(g rev-parse HEAD)" --pr "$2" --auto-merge 2>&1
}

ROWS=0; BAD=0
# expect <id> <exit> <regex> <base> <pr file>
expect() {
  rc=0; out=$(ready "$4" "$5") || rc=$?; ROWS=$((ROWS+1))
  last=$(printf '%s\n' "$out" | grep -E '^auto-merge: ' | tail -n 1)
  if [ "$rc" = "$2" ] && printf '%s\n' "$last" | grep -qE -e "$3"; then st=ok; else st=FAIL; BAD=$((BAD+1)); fi
  printf '%-4s expected exit %s /%s/  got exit %s "%s"  %s\n' "$1" "$2" "$3" "$rc" "$last" "$st"
  [ "$st" = ok ] || printf '%s\n' "$out" | sed 's/^/     | /'
}

dry_run() {
  d=$(resolve "${1-}"); [ -d "$d/.git" ] || die "$d is not a seeded sandbox"
  T=$(mktemp -d); trap 'rm -rf "$T"' EXIT
  g clone -q --bare "$d" "$T/origin.git"; g clone -q "$T/origin.git" "$T/w"; cd "$T/w"
  b0=origin/main; pf="$T/pr.md"
  for id in K1 N1 N2 N3; do setup $id $b0; body $b0 > "$pf"
    case $id in
      K1) expect K1 1 '^auto-merge: no \(human required' $b0 "$pf" ;;
      N1) expect N1 1 'size 4 files' $b0 "$pf" ;;
      N2) expect N2 1 'complexity non-trivial' $b0 "$pf" ;;
      N3) expect N3 1 'same family' $b0 "$pf" ;;
    esac
  done
  setup N4 $b0; N4_PR="$T/n4.md"; body $b0 > "$N4_PR"            # branched before P1 merges, opened after
  setup P1 $b0; body $b0 > "$pf"; expect P1 0 '^auto-merge: yes' $b0 "$pf"
  g checkout -q -B main origin/main; g merge -q --ff-only live/p1; g push -q origin main; g fetch -q origin
  g checkout -q live/n4; expect N4 1 'is behind refs/remotes/origin/main: update the branch' $b0 "$N4_PR"
  # after P1 merged, the base is the new tip
  b1=origin/main
  setup N5 $b1; body $b1 > "$pf"; expect N5.1 0 '^auto-merge: yes' $b1 "$pf"
  BR=slow/n5-over; mkdocs 4; g add -A; g commit -qm "docs: push after approval"; body $b1 > "$pf"
  expect N5.2 1 'size [0-9]+ files' $b1 "$pf"
  setup N6 $b1; body $b1 > "$pf"; expect N6.1 0 '^auto-merge: yes' $b1 "$pf"
  BR=live/n6-over; mkdocs 4; g add -A; g commit -qm "docs: push during the check"; body $b1 > "$pf"
  expect N6.2 1 'size [0-9]+ files' $b1 "$pf"
  setup P2 $b1; body $b1 > "$pf"; expect P2.1 0 '^auto-merge: yes' $b1 "$pf"
  printf '\nHuman-Findings: 0\n' >> "$pf"; expect P2.2 1 'Human-Findings' $b1 "$pf"
  echo "dry-run: $ROWS rows, $BAD failed"
  [ "$BAD" = 0 ]
}

open_pr() {
  d=$(resolve "${1-}"); id=${2-}; yes=0; [ "${3-}" != --yes ] || yes=1
  [ -d "$d/.git" ] || die "$d is not a seeded sandbox"; [ -n "$id" ] || die "usage: sandbox.sh open <dir> <id> [--yes]"
  g -C "$d" remote get-url origin >/dev/null 2>&1 || die "$d has no origin: add the sandbox remote first (README, task 6)"
  cd "$d"; g fetch -q origin  # read only
  [ -z "$(g status --porcelain)" ] || die "$d has uncommitted changes"
  setup "$id" origin/main; f=$(mktemp "${TMPDIR:-/tmp}/specter-live-$id.XXXXXX"); body origin/main > "$f"
  title="docs: live scenario $id"
  push="git -C $d push origin $BR"
  create="cd $d && gh pr create --base main --head $BR --title \"$title\" --body-file $f"
  echo "scenario $id is on local branch $BR, PR text in $f"
  case $id in
    K1) echo "note: expect no merge; read the three probe jobs, see README task 8" ;;
    N5|P2) echo "note: the branch starts with slow/: the check holds for a minute; do the mid-flight step from README task 9 then" ;;
    N6) echo "note: set the variable SANDBOX_DELAY=30 first (README task 9) and delete it afterwards" ;;
    N4) echo "note: open it only after P1 has merged" ;;
  esac
  if [ "$yes" = 1 ]; then echo "+ $push"; $push; echo "+ $create"; eval "$create"
  else echo "not run (no --yes). To open it:"; echo "  $push"; echo "  $create"; fi
}

cmd=${1-}; [ $# -gt 0 ] && shift
case $cmd in
  seed) seed "$@" ;;
  dry-run) dry_run "$@" ;;
  open) open_pr "$@" ;;
  *) die "usage: sandbox.sh seed <dir> | dry-run <dir> | open <dir> <id> [--yes]" ;;
esac
