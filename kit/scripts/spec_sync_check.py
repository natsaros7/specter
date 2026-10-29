#!/usr/bin/env python3
"""Spec-sync gate: code changed without any .specs/ change -> warn or block (spec-rules.md §8).

Usage: python3 .specs/kit/scripts/spec_sync_check.py              staged files (pre-commit hook)
       python3 .specs/kit/scripts/spec_sync_check.py --range A...B  a commit range (CI)
Mode comes from .specs/spec-kit.json "spec_sync": warn | block | off.
Skip once: SPEC_SYNC_SKIP=1 git commit ...  (say why in the commit message).
Globs use fnmatch: '*' also matches '/', so 'src/*' covers the whole src tree.
"""
import fnmatch
import json
import os
import subprocess
import sys
from pathlib import Path


def changed_files(argv):
    if argv[:1] == ["--range"]:
        cmd = ["git", "diff", "--name-only", argv[1]]
    else:
        cmd = ["git", "diff", "--cached", "--name-only", "--diff-filter=ACMRD"]
    return [line for line in subprocess.check_output(cmd, text=True).splitlines() if line]


def matches(path, globs):
    return any(fnmatch.fnmatch(path, g) for g in globs)


def main(argv):
    specs = Path(__file__).resolve().parents[2]
    config = {"spec_sync": "warn", "code_globs": [], "ignore_globs": []}
    path = specs / "spec-kit.json"
    try:
        config.update(json.loads(path.read_text()) if path.exists() else {})
    except ValueError:
        print("spec-sync: " + str(path) + " is not valid JSON: check skipped")
        return 0
    mode = config.get("spec_sync", "warn")
    if mode == "off" or os.environ.get("SPEC_SYNC_SKIP") == "1":
        return 0
    prefix = specs.name + "/"
    files = changed_files(argv)
    code = [f for f in files if matches(f, config["code_globs"]) and not matches(f, config.get("ignore_globs", []))]
    spec_touched = any(f.startswith(prefix) or ("/" + prefix) in f for f in files)
    if not code or spec_touched:
        return 0
    label = "BLOCK" if mode == "block" else "WARN"
    print("spec-sync " + label + ": " + str(len(code)) + " code file(s) changed, no " + prefix + " change, e.g. " + code[0])
    print("  Update the matching .specs/domains/<domain>/ docs (see .specs/kit/playbooks/sync.md),")
    print("  or SPEC_SYNC_SKIP=1 if the change has no spec impact, and say why in the commit message.")
    return 1 if mode == "block" else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
