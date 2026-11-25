#!/bin/sh
# Builds a disposable acme-shop sandbox for one eval goal: sh examples/acme-shop/eval/sandbox.sh ~/acme-eval-e1
# Same as the README sandbox recipe, then the Maven Gates rows go through the JDK container so Maven never runs on
# the host. The example's own Gates table is left as a real project would have it. Needs docker only at gate time.
set -eu
dir=${1:?usage: sandbox.sh <dir under \$HOME>}
case $dir in "$HOME"/?*) ;; *) echo "sandbox: $dir must be a path under \$HOME" >&2; exit 2 ;; esac
root=$(cd "$(dirname "$0")/../../.." && pwd)
rm -rf "$dir"
cp -R "$root/examples/acme-shop" "$dir"
rm -rf "$dir/target" "$dir"/*/target
git -C "$dir" init -q
"$root/install.sh" "$dir" >/dev/null
rules=$dir/.specs/steering/spec-rules.md
# Gates rows only: the prose above the table also names ./mvnw.
sed -i.bak '/^| G[0-9b]* |/s|\./mvnw |sh scripts/mvnw-docker.sh |' "$rules" && rm "$rules.bak"
n=$(grep -c '^| G[0-9b]* |.*sh scripts/mvnw-docker.sh ' "$rules" || true)
left=$(grep -c '^| G[0-9b]* |.*\./mvnw ' "$rules" || true)
[ "$n" = 3 ] && [ "$left" = 0 ] || { echo "sandbox: expected 3 Maven Gates rows rewritten, got $n (left $left)" >&2; exit 1; }
git -C "$dir" add -A
git -C "$dir" -c user.name=specter-eval -c user.email=eval@example.invalid \
    commit -qm "chore: acme-shop eval sandbox from specter $(git -C "$root" rev-parse --short HEAD)"
echo "sandbox ready: $dir (3 Maven Gates rows run in the container)"
