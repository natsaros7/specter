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
Review: both model ids (families = first `-` token, same family is a warning), `rules:` a prefix of the base, one
verdict table; a blocker with file:line, evidence, trigger and consequence is open and not ready, else advisory.
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


def check_review(text, base):
    """{implementer, reviewer, same_family, rules, blockers, advisories, problems, warnings} for the ### Review block."""
    r = {"implementer": None, "reviewer": None, "same_family": False, "rules": None, "blockers": [], "advisories": [],
         "problems": [], "warnings": []}
    lines, cur, n = [], False, 0
    for line in text.splitlines():
        if line.strip() == "### Review":
            cur, n = True, n + 1
        elif cur and line.startswith("#"):
            cur = False
        elif cur:
            lines.append(line.rstrip())
    if n != 1:
        r["problems"].append("needs exactly one ### Review block, found " + str(n))
        return r
    for line in lines:
        m = re.fullmatch(r"- (implementer|reviewer|rules): *(\S*).*", line)
        if m:
            r[m.group(1)] = m.group(2) or None
        elif line.startswith("|"):
            c = gates.split_row(line) + [""] * 6
            if c[0].lower() == "severity" or set("".join(c)) <= set("-: "):
                continue
            sev = c[0].lower()
            if sev not in ("blocker", "advisory"):
                r["problems"].append("verdict row has severity '" + c[0] + "', not blocker or advisory")
                continue
            loc = c[1] if re.fullmatch(r"[^\s:]+:\d+", c[1]) else ""
            empty = [n for n, v in (("location", loc), ("evidence", c[2]), ("trigger", c[3]), ("consequence", c[4])) if not v]
            if sev == "blocker" and not empty:
                r["blockers"].append(c[1])
                r["problems"].append("open blocker at " + c[1])
            else:
                r["advisories"].append(c[1])
                if sev == "blocker":
                    r["warnings"].append("blocker at '" + c[1] + "' is advisory (no " + ", no ".join(empty) + ")")
    for who in ("implementer", "reviewer"):
        if not r[who]:
            r["problems"].append("review has no " + who + " model id")
    if r["implementer"] and r["reviewer"]:
        fam = [r[k].split("-")[0].lower() for k in ("implementer", "reviewer")]
        r["same_family"] = fam[0] == fam[1]
        if r["same_family"]:
            r["warnings"].append("reviewer " + r["reviewer"] + " is in the implementer's family '" + fam[0] + "'; it bars Human none")
    rules = r["rules"] or ""
    if not re.fullmatch(r"[0-9a-f]{7,40}", rules) or not (base or "").startswith(rules):
        r["problems"].append("review rules " + (rules or "(none)") + " is not the base " + (base or "?")[:7])
    return r


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
    # Seam for 11d: its check adds `verification` here and its problems join `problems`.
    review, verification = check_review(text, base), None
    problems = g["problems"] + review["problems"]
    warnings = g["warnings"] + review["warnings"]
    verdict = "not ready" if problems else "ready"
    tier = {k: change[k] for k in ("tier", "reviewer", "human")}
    if as_json:
        print(json.dumps({"verdict": verdict, "gates": g, "tier": tier, "review": review,
                          "verification": verification, "warnings": warnings}))
    else:
        print("### Readiness")
        print("- gates: %d/%d pass at %s" % (g["passed"], g["total"], head[:7]))
        print("- tier: %s (reviewer: %s, human: %s)" % (tier["tier"], tier["reviewer"], tier["human"]))
        print("- verdict: " + verdict)
        for p in problems:
            print("- not ready: " + p)
        for w in warnings:
            print("- warning: " + w)
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
