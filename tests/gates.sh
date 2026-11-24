#!/bin/sh
# Runs G1-G4 (AGENTS.md) and prints "G<n> rc=<rc>". Exit: the first non-zero rc.
# usage: sh tests/gates.sh [--docker] [--only G<n>]
set -u
only=; docker=0
while [ $# -gt 0 ]; do
  case $1 in
    --docker) docker=1 ;;
    --only) shift; only=${1:?--only needs G1..G4} ;;
    *) echo "usage: sh tests/gates.sh [--docker] [--only G<n>]" >&2; exit 2 ;;
  esac
  shift
done

if [ "$docker" = 1 ]; then
  # Host security scanners inspect every write on the bind mount, so copy to the VM's own /tmp first.
  # shortcut: the image tag is not pinned by digest, pin it when CI uses this.
  here=$(cd "$(dirname "$0")/.." && pwd)
  exec docker run --rm --memory 2g -e SELFTEST_ONLY="${SELFTEST_ONLY:-}" -v "$here":/src:ro python:3.12 sh -c \
    'mkdir /tmp/s && cp -R /src/. /tmp/s/ && cd /tmp/s && sh tests/gates.sh "$@"' sh ${only:+--only "$only"}
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
gate G1 'sh -n install.sh && sh -n tests/selftest.sh && sh -n tests/acme-build.sh && sh -n tests/gates.sh'
# spec_lint exits 0 on a missing --specs dir ("0 FAIL of 0 citations"), so G2 also requires a non-zero citation count.
gate G2 'python3 kit/scripts/spec_lint.py --specs examples/acme-shop/.specs && o=$(python3 kit/scripts/spec_lint.py --specs examples/acme-shop/.specs --cites) && echo "$o" && case $o in *" of 0 citation"*) exit 1;; esac'
gate G3 'sh tests/selftest.sh'
gate G4 'python3 kit/scripts/spec_lint.py --specs .specs && python3 kit/scripts/spec_lint.py --specs .specs --cites'
exit "$first"
