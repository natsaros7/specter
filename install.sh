#!/bin/sh
# spec-first-kit installer. Copies the kit into <target>/.specs/kit/ and wires the agents it finds.
#
#   ./install.sh <target>                 install or upgrade (safe to re-run)
#   ./install.sh <target> --with-agents   also add Claude Code tier agents (planner/generator/reviewer)
#   ./install.sh --user                   Claude Code only: add the /spec-first skill for all your projects
#   ./install.sh <target> --uninstall     remove the kit and marker blocks; your specs stay
#
# <target> = where .specs/ should live: the repo root, or the workspace folder that holds several repos.
set -eu
KIT_HOME=$(cd "$(dirname "$0")" && pwd)
command -v python3 >/dev/null || { echo "python3 is required"; exit 1; }
exec python3 -I "$KIT_HOME/kit/scripts/install.py" "$KIT_HOME" "$@"
