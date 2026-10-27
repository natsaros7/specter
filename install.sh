#!/bin/sh
# specter installer. Copies the kit into <target>/.specs/kit/ and wires the agents it finds.
#
#   ./install.sh <target>                 install or upgrade (safe to re-run)
#   ./install.sh --user                   add the spec-first skill at user level for every agent detected
#   ... --agents=codex,claude             override agent detection (claude, codex, cursor, gemini, copilot)
#   ./install.sh <target> --detect        show which agents would be wired, and why; changes nothing
#   ... --from-go                         used by GO.md: shorter closing message
#   ./install.sh <target> --uninstall     remove the kit and marker blocks; your specs stay
#
# <target> = where .specs/ should live: the repo root, or the workspace folder that holds several repos.
set -eu
KIT_HOME=$(cd "$(dirname "$0")" && pwd)
command -v python3 >/dev/null || { echo "python3 is required"; exit 1; }
exec python3 -I "$KIT_HOME/kit/scripts/install.py" "$KIT_HOME" "$@"
