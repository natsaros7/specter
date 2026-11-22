#!/bin/sh
# G5: build the acme-shop example. No JDK 21 -> visible skip, exit 0; any build failure -> exit 1.
# ACME_OFFLINE=1 adds -o (needs one online run first to fill ~/.m2).
set -u
cd "$(dirname "$0")/../examples/acme-shop" || exit 1

java_bin=java
[ -n "${JAVA_HOME:-}" ] && [ -x "$JAVA_HOME/bin/java" ] && java_bin="$JAVA_HOME/bin/java"
ver=$("$java_bin" -version 2>&1 | sed -n 's/.*version "\([0-9][0-9]*\).*/\1/p' | head -n 1)
if [ -z "$ver" ] || [ "$ver" -lt 21 ]; then
    echo "G5 SKIPPED: needs JDK 21+ (found: ${ver:-none})"
    exit 0
fi
# An unusable JAVA_HOME would send mvnw to the wrong JDK; fall back to java on PATH.
[ "$java_bin" = java ] && unset JAVA_HOME

offline=
[ "${ACME_OFFLINE:-}" = 1 ] && offline=-o
mkdir -p target
if ! ./mvnw -B $offline verify > target/build.log 2>&1; then
    tail -n 40 target/build.log
    grep -q 'Could not resolve\|Could not transfer\|offline mode' target/build.log &&
        echo "hint: the first run needs network to fill ~/.m2 (drop ACME_OFFLINE)"
    echo "G5 FAILED: see examples/acme-shop/target/build.log"
    exit 1
fi
# jqwik fence: the build log must carry no instruction aimed at agents beyond the allow-listed clause.
sh scripts/scan-agent-text.sh target/build.log || { echo "G5 FAILED: agent-directed text in build log"; exit 1; }
echo "G5 OK: acme-shop verify (JDK $ver${offline:+, offline})"
