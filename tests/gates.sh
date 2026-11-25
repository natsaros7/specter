#!/bin/sh
# Runs G1-G4 (AGENTS.md) and prints "G<n> rc=<rc>". Exit: the first non-zero rc.
# usage: sh tests/gates.sh [--docker] [--only G<n>]
set -u
only=; docker=0
while [ $# -gt 0 ]; do
  case $1 in
    --docker) docker=1 ;;
    --only) shift; only=${1:?--only needs G1..G4}
      case $only in G1|G2|G3|G4) ;; *) echo "gates: unknown gate '$only' (G1..G4)" >&2; exit 2;; esac ;;
    *) echo "usage: sh tests/gates.sh [--docker] [--only G<n>]" >&2; exit 2 ;;
  esac
  shift
done

# A release (VERSION differs from origin/main) must refresh docs/overview; empty when origin/main is unavailable (skip).
# Computed here because the container copy may not carry a usable .git.
BASE_VERSION=$(git -C "$(dirname "$0")/.." show origin/main:VERSION 2>/dev/null) || BASE_VERSION=
export BASE_VERSION

if [ "$docker" = 1 ]; then
  # Host security scanners inspect every write on the bind mount, so copy to the VM's own /tmp first.
  # Colima and similar runtimes share only $HOME: a clone elsewhere mounts empty, which the first command catches.
  # shortcut: the image tag is not pinned by digest, pin it when CI uses this.
  here=$(cd "$(dirname "$0")/.." && pwd)
  git -C "$here" rev-parse --git-dir >/dev/null 2>&1 || { echo "gates: --docker needs a git checkout" >&2; exit 2; }
  # Only tracked and unignored files go in (a stray __pycache__ must not reach G3). The list is made on the host because a
  # worktree's .git file points outside the mount; -z keeps odd names whole, --ignore-failed-read skips a tracked file
  # deleted in the work tree. .git stays out: no gate reads it in the container (BASE_VERSION is passed in).
  git -C "$here" ls-files -z --cached --others --exclude-standard | docker run --rm -i --memory 2g -e SELFTEST_ONLY="${SELFTEST_ONLY:-}" -e BASE_VERSION="$BASE_VERSION" -v "$here":/src:ro python:3.12 sh -c \
    '[ -f /src/tests/gates.sh ] || { echo "gates: /src is empty (does your container runtime share this path?)" >&2; exit 2; }
     mkdir /tmp/s && cd /src && tar --null --ignore-failed-read -T - -cf - | tar -xf - -C /tmp/s && cd /tmp/s && sh tests/gates.sh "$@"' sh ${only:+--only "$only"}
  exit $?
fi

cd "$(dirname "$0")/.." || exit 2
export PYTHONDONTWRITEBYTECODE=1
first=0
gate() { # id command
  [ -z "$only" ] || [ "$only" = "$1" ] || return 0
  rc=0; sh -c "$2" || rc=$?
  echo "$1 rc=$rc"
  [ "$first" != 0 ] || first=$rc
}
gate G1 'sh -n install.sh && sh -n tests/selftest.sh && sh -n tests/acme-build.sh && sh -n tests/gates.sh && sh -n examples/acme-shop/scripts/mvnw-docker.sh && sh -n tests/live/github/sandbox.sh && sh -n .githooks/pre-push'
gate G2 'python3 kit/scripts/spec_lint.py --specs examples/acme-shop/.specs && o=$(python3 kit/scripts/spec_lint.py --specs examples/acme-shop/.specs --cites) && echo "$o" && case $o in *" of 0 citation"*) exit 1;; esac'
gate G3 'sh tests/selftest.sh'
gate G4 'python3 kit/scripts/spec_lint.py --specs .specs && python3 kit/scripts/spec_lint.py --specs .specs --cites && python3 tests/readme_check.py && v=$(cat VERSION) && { [ -z "$BASE_VERSION" ] || [ "$BASE_VERSION" = "$v" ] || { grep -q "Release $v shipped" docs/overview/deck/specter-overview.html && grep -q "today ($v)" docs/overview/roadmap.svg || { echo "overview: deck must say \"Release $v shipped\" and roadmap \"today ($v)\"" >&2; exit 1; }; }; }'
# A partial selftest is not a green G3: say so and fail overall.
if [ -n "${SELFTEST_ONLY:-}" ] && { [ -z "$only" ] || [ "$only" = G3 ]; }; then
  echo "G3 PARTIAL (SELFTEST_ONLY=$SELFTEST_ONLY)"; [ "$first" != 0 ] || first=1
fi
exit "$first"
