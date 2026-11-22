#!/usr/bin/env python3
"""Check a PR description's `### Gates` block against the repository and print a `### Readiness` block. Python 3.8+, stdlib only.

Usage: python3 .specs/kit/scripts/ready.py [--specs DIR] [--range A...B] [--pr FILE] [--json] | --help
       default DIR = the .specs/ this script is installed in; PR text comes from FILE, else stdin.

Reads only: it runs no command, and never executes or evals anything from the PR text. Base and head are as in
tiers.py: staged mode (base HEAD; the block's commit must be HEAD, `+dirty` allowed) or --range (base = merge-base
A B, head B; the block's commit must be B, a prefix of at least 7 hex, and not dirty).
Gates: the labels come from the Gates table of steering/spec-rules.md at the base, never the working tree. Every label
needs a `- <label>: pass (...)` row; a missing, `not run` or FAIL row, a repeated label, a stale or dirty commit, or a
verdict other than `ready (N passed)` is not ready. A row whose label is not in the base's table is a warning, never
trusted. The block's Risk tier (tiers.py) is printed. Exit 0 ready, 1 not ready, 2 bad argument or unreadable input.
--json: {verdict, gates, tier, review, verification, warnings}.
"""
import json
import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import gates  # noqa: E402
import tiers  # noqa: E402

USAGE = "usage: ready.py [--specs DIR] [--range A...B] [--pr FILE] [--json] | --help"
ROW = re.compile(r"- (.+?): (pass \(.*\)|FAIL \(exit \d+\)|not run)")


def block(text, heading):
    """The lines of every `### heading` block (up to the first line that is not a `- ` item or blank), as a list."""
    out, cur = [], None
    for line in text.splitlines():
        if line.strip() == "### " + heading:
            cur = []
            out.append(cur)
        elif cur is not None and line.startswith("- "):
            cur.append(line.rstrip())
        elif cur is not None and line.strip():
            cur = None
    return out


def check_gates(text, labels, head, ranged):
    """{ok, passed, total, commit, problems, warnings} for the PR's Gates block against the base's labels."""
    blocks, problems, warnings, status, sha = block(text, "Gates"), [], [], {}, None
    if len(blocks) != 1:
        problems.append("needs exactly one ### Gates block, found " + str(len(blocks)))
    for line in blocks[0] if len(blocks) == 1 else []:
        m = ROW.fullmatch(line)
        if m:
            status.setdefault(m.group(1), []).append(m.group(2))
        elif line.startswith("- commit: "):
            sha = line[len("- commit: "):].strip()
        elif re.fullmatch(r"- verdict: ready \(\d+ passed\)", line):
            status[" verdict"] = ["ok"]
    for label in labels:
        got = status.get(label)
        if not got:
            problems.append("lane '" + label + "' is missing")
        elif len(got) > 1:
            problems.append("lane '" + label + "' appears " + str(len(got)) + " times")
        elif not got[0].startswith("pass ("):
            problems.append("lane '" + label + "' is " + got[0].split(" (")[0])
    warnings += ["row '" + k + "' is not in the base's Gates table; ignored" for k in status if k not in labels and k != " verdict"]
    if blocks and " verdict" not in status:
        problems.append("block has no `- verdict: ready (N passed)` line")
    dirty = bool(sha) and sha.endswith("+dirty")
    bare = (sha or "")[:-len("+dirty")] if dirty else (sha or "")
    if not re.fullmatch(r"[0-9a-f]{7,40}", bare) or not (head or "").startswith(bare):
        problems.append("block commit " + (sha or "(none)") + " is not the head " + (head or "?")[:7])
    elif dirty and ranged:
        problems.append("block commit " + sha + " was dirty")
    passed = sum(1 for k in labels if len(status.get(k, [])) == 1 and status[k][0].startswith("pass ("))
    return {"ok": not problems, "passed": passed, "total": len(labels), "commit": sha, "problems": problems,
            "warnings": warnings}


def refuse(msg):
    print("ready: " + msg, file=sys.stderr)
    return 2


def main(argv):
    if "-h" in argv or "--help" in argv:
        print(__doc__.strip())
        return 0
    specs, pr, rng, as_json = Path(__file__).resolve().parents[2], None, None, "--json" in argv
    argv = [a for a in argv if a != "--json"]
    for flag in ("--specs", "--pr", "--range"):
        if flag in argv:
            i = argv.index(flag)
            if i + 1 >= len(argv):
                return refuse(USAGE)
            value, argv = argv[i + 1], argv[:i] + argv[i + 2:]
            if flag == "--specs":
                specs = Path(value).resolve()
            elif flag == "--pr":
                pr = value
            elif re.fullmatch(r"[^.\s][^\s]*?\.\.\.?[^.\s][^\s]*", value):
                rng = value
            else:
                return refuse("--range needs A...B; " + USAGE)
    if argv:
        return refuse("unknown or repeated argument(s) " + " ".join(argv) + "; " + USAGE)
    try:
        text = Path(pr).read_text(encoding="utf-8", errors="replace") if pr else sys.stdin.read()
    except OSError as err:
        return refuse("cannot read " + str(pr) + ": " + err.strerror)
    root, rel = specs.parent, "x"
    try:
        rel = (specs / "steering" / "spec-rules.md").relative_to(root).as_posix()
        change = tiers.classify(root, (specs / "steering" / "autonomy.md").relative_to(root).as_posix(), rng)
    except ValueError as err:
        return refuse(str(err))
    base = change["base"]
    head = tiers.git(root, "rev-parse", "--verify", "-q", (rng.replace("...", "..").split("..")[1] if rng else "HEAD"))
    rules = tiers.profile_at(root, base, rel) if base else None
    try:
        rows = gates.gate_rows(rules) if rules else None
    except ValueError as err:
        return refuse(rel + " at " + str(base)[:7] + ": " + str(err))
    if not rows or not head:
        return refuse("no Gates table in " + rel + " at the base, or no head commit")
    g = check_gates(text, [r[0] for r in rows], head, bool(rng))
    # Seams for 11c and 11d: each check adds its own entry here and its problems join `problems`.
    review = verification = None
    problems = g["problems"]
    verdict = "not ready" if problems else "ready"
    tier = {k: change[k] for k in ("tier", "reviewer", "human")}
    if as_json:
        print(json.dumps({"verdict": verdict, "gates": g, "tier": tier, "review": review,
                          "verification": verification, "warnings": g["warnings"]}))
    else:
        print("### Readiness")
        print("- gates: %d/%d pass at %s" % (g["passed"], g["total"], head[:7]))
        print("- tier: %s (reviewer: %s, human: %s)" % (tier["tier"], tier["reviewer"], tier["human"]))
        print("- verdict: " + verdict)
        for p in problems:
            print("- not ready: " + p)
        for w in g["warnings"]:
            print("- warning: " + w)
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
