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

if [ "$docker" = 1 ]; then
  # Host security scanners inspect every write on the bind mount, so copy to the VM's own /tmp first.
  # Colima and similar runtimes share only $HOME: a clone elsewhere mounts empty, which the first command catches.
  # shortcut: the image tag is not pinned by digest, pin it when CI uses this.
  here=$(cd "$(dirname "$0")/.." && pwd)
  exec docker run --rm --memory 2g -e SELFTEST_ONLY="${SELFTEST_ONLY:-}" -v "$here":/src:ro python:3.12 sh -c \
    '[ -f /src/tests/gates.sh ] || { echo "gates: /src is empty (does your container runtime share this path?)" >&2; exit 2; }
     mkdir /tmp/s && cp -R /src/. /tmp/s/ && cd /tmp/s && sh tests/gates.sh "$@"' sh ${only:+--only "$only"}
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
gate G1 'sh -n install.sh && sh -n tests/selftest.sh && sh -n tests/acme-build.sh && sh -n tests/gates.sh && sh -n .githooks/pre-push'
gate G2 'python3 kit/scripts/spec_lint.py --specs examples/acme-shop/.specs && o=$(python3 kit/scripts/spec_lint.py --specs examples/acme-shop/.specs --cites) && echo "$o" && case $o in *" of 0 citation"*) exit 1;; esac'
gate G3 'sh tests/selftest.sh'
gate G4 'python3 kit/scripts/spec_lint.py --specs .specs && python3 kit/scripts/spec_lint.py --specs .specs --cites && python3 tests/readme_check.py'
# A partial selftest is not a green G3: say so and fail overall.
if [ -n "${SELFTEST_ONLY:-}" ] && { [ -z "$only" ] || [ "$only" = G3 ]; }; then
  echo "G3 PARTIAL (SELFTEST_ONLY=$SELFTEST_ONLY)"; [ "$first" != 0 ] || first=1
fi
exit "$first"
