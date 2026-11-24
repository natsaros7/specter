#!/usr/bin/env python3
"""Check a PR description's `### Gates` block against the repository and print a `### Readiness` block. Python 3.8+, stdlib only.

Usage: python3 .specs/kit/scripts/ready.py [--specs DIR] [--range A...B] [--pr FILE] [--json] | --help
       default DIR = the .specs/ this script is installed in; PR text comes from FILE, else stdin.

Reads only: it runs no command, and never executes or evals anything from the PR text. Base and head are as in
tiers.py: staged mode, a preflight before the commit (base = tiers.py's staged base, head the index; the block's
commit must be HEAD, and `+dirty` while files are staged) or --range, the binding check after the commit (base =
merge-base A B, head B; the block's commit must be B, a prefix of at least 7 hex, and not dirty). Run it from a
trusted copy of the kit (a worktree of the base), never the PR's own.
Gates: the labels come from the Gates table of steering/spec-rules.md at the base, never the working tree, and the
head's table (the index in staged mode) must equal it row for row: a changed table goes to the human. Every label
needs a `- <label>: pass (...)` row; a missing, `not run` or FAIL row, a repeated label, a stale or dirty commit, a
`- tree changed during gates` line, or a verdict other than `ready (N passed)` is not ready. A row whose label is not
in the base's table is a warning, never trusted. The block's Risk tier (tiers.py) is printed.
Exit 0 ready, 1 not ready, 2 bad argument or unreadable input (a bad spec-kit.json included).
Review: both model ids (families = first `-` token, same family is a warning), `rules:` a prefix of the base, one
verdict table; a blocker with file:line, evidence, trigger and consequence is open and not ready; an empty cell makes
it advisory; a Location that is not file:line is not ready.
Verification: each `- [REQ] <path or URL>: ...` line needs a REQ defined in a requirements.md at the head, and a path
that is a regular file at the head (index in staged mode; no `..`, no absolute path, no symlink); a URL is `declared,
not fetched`. A missing block changes nothing.
Human `none` is reported as `spot` when the tier's evidence is not eligible (as tiers.py labels it) or the review shares the
implementer's model family (`- human: none → spot (<why>)`; --json tier.human_why); the exit code is unchanged.
--json: {verdict, gates, tier, review, verification, warnings}.
"""
import json
import posixpath
import re
import subprocess
import sys
from pathlib import Path

sys.dont_write_bytecode = True  # an installed kit must stay free of __pycache__ (guarded path)
sys.path.insert(0, str(Path(__file__).resolve().parent))
import gates  # noqa: E402
import spec_lint  # noqa: E402
import tiers  # noqa: E402

USAGE = "usage: ready.py [--specs DIR] [--range A...B] [--pr FILE] [--json] | --help"
ROW = re.compile(r"- (.+?): (pass \(.*\)|FAIL \(exit -?\d+\)|not run)")


def visible(text):
    """The text a reader sees: HTML comments and fenced code blocks dropped, so a hidden block counts for nothing."""
    out, fence = [], None
    for line in re.sub(r"<!--.*?(?:-->|\Z)", "", text, flags=re.S).splitlines():
        m = re.match(r"\s*(```|~~~)", line)
        if fence:
            fence = None if m and m.group(1) == fence else fence
        elif m:
            fence = m.group(1)
        else:
            out.append(line)
    return "\n".join(out)


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


def check_gates(text, labels, head, ranged, staged=False):
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
    elif staged and not ranged and not dirty:
        problems.append("block commit " + sha + " is clean but files are staged; it needs +dirty")
    if blocks and "- tree changed during gates" in blocks[0]:
        problems.append("gates changed the tree during the run: the commit is not what they checked (gitignore gate output)")
    passed = sum(1 for k in labels if len(status.get(k, [])) == 1 and status[k][0].startswith("pass ("))
    return {"ok": not problems, "passed": passed, "total": len(labels), "commit": sha, "problems": problems,
            "warnings": warnings}


def family(model):
    # shortcut: a fixed prefix list and the first `-` token; o3 vs gpt-5 and unlisted regions are missed. A miss
    # leaves Human none unbarred; replace with a profile table when a repo mixes providers behind one family name.
    """First `-` token of a model id once a provider path or prefix (`bedrock/`, `us.anthropic.`) is dropped."""
    m = re.sub(r"^(?:(?:us|eu|apac|global)\.)?(?:(?:anthropic|openai|google|meta|mistral|amazon|cohere)\.)?", "", model.lower().rsplit("/", 1)[-1])
    return m.split("-")[0]


def check_review(text, base, want="standard"):
    """{implementer, reviewer, same_family, rules, blockers, advisories, problems, warnings} for the ### Review block."""
    r = {"implementer": None, "reviewer": None, "reviewer_tier": None, "same_family": False, "rules": None, "blockers": [], "advisories": [],
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
        m = re.fullmatch(r"- (implementer|reviewer|rules): *(\S*)(?: *\((\w+)\))?.*", line)
        if m:
            r[m.group(1)] = m.group(2) or None
            if m.group(1) == "reviewer":
                r["reviewer_tier"] = (m.group(3) or "").lower() or None
        elif line.startswith("|"):
            c = gates.split_row(line) + [""] * 6
            if c[0].lower() == "severity" or set("".join(c)) <= set("-: "):
                continue
            sev = c[0].lower()
            if sev not in ("blocker", "advisory"):
                r["problems"].append("verdict row has severity '" + c[0] + "', not blocker or advisory")
                continue
            loc = c[1] if re.fullmatch(r"`?[^\s:#`]+(?::\d+(?:[-\u2013]\d+)?(?::\d+)?|#L\d+(?:-L\d+)?)`?", c[1]) else ""
            if sev == "blocker" and c[1] and not loc:
                r["problems"].append("blocker location unreadable: " + c[1])
                continue
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
        fam = [family(r[k]) for k in ("implementer", "reviewer")]
        r["same_family"] = fam[0] == fam[1]
        if r["same_family"]:
            r["warnings"].append("reviewer " + r["reviewer"] + " is in the implementer's family '" + fam[0] + "'; it bars Human none")
    # shortcut: warning only; slice 4 makes a reviewer below the label's reviewer blocking.
    if r["reviewer"] and want == "deep" and r["reviewer_tier"] != "deep":
        r["warnings"].append("reviewer tier below the label's reviewer (" + (r["reviewer_tier"] or "none") + " < " + want + ")")
    rules = r["rules"] or ""
    if not re.fullmatch(r"[0-9a-f]{7,40}", rules) or not (base or "").startswith(rules):
        r["problems"].append("review rules " + (rules or "(none)") + " is not the base " + (base or "?")[:7])
    return r


VLINE = re.compile(r"- \[([^\]\s]+)\] (\S+?):(?: .*)?")


def check_verification(text, root, head, ranged, req_pattern):
    """{lines: [{req, target, status}], problems} for the ### Verification block; reads git at the head, never the tree."""
    v, blocks = {"lines": [], "problems": []}, block(text, "Verification")
    if len(blocks) > 1:
        v["problems"].append("needs at most one ### Verification block, found " + str(len(blocks)))
    ref = head + ":" if ranged else ":"
    listing = ["ls-tree", "-r", "--name-only", head] if ranged else ["ls-files"]
    defined_re = re.compile(r"\[(" + req_pattern + r")\]")
    defined = set()
    for f in (tiers.git(root, *listing) or "").splitlines():
        if re.fullmatch(r"(?:.*/)?(?:features|domains)/[^/]+/requirements\.md", f):
            defined.update(defined_re.findall(tiers.git(root, "show", ref + f) or ""))
    for line in blocks[0] if len(blocks) == 1 else []:
        m = VLINE.fullmatch(line)
        if not m:
            v["problems"].append("verification line is not `- [REQ] <path or URL>: <what it shows>`: " + line[:60])
            continue
        req, target = m.groups()
        if re.match(r"https?://", target):
            status = "declared, not fetched"
        elif target.startswith("/") or ".." in target.split("/") or "\\" in target:
            status = "path outside the repository"
        else:
            path = posixpath.normpath(target)
            out = tiers.git(root, "--literal-pathspecs", "ls-tree" if ranged else "ls-files", *(["-s"] if not ranged else []), *([head] if ranged else []), "--", path) or ""
            ent = [x.split() for x in out.splitlines() if x.partition("\t")[2] == path]  # a directory lists its children, not itself
            status = "ok" if ent and ent[0][0] in ("100644", "100755") else "symlink or not a file" if ent or out or path == "." else "missing at the head"
        v["lines"].append({"req": req, "target": target, "status": status})
        if req not in defined:
            v["problems"].append("verification REQ " + req + " is not defined in any requirements.md")
        if status not in ("ok", "declared, not fetched"):
            v["problems"].append("verification artifact " + target + ": " + status)
    return v


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
    text = visible(text)
    root, rel = specs.parent, "x"
    try:
        rel = (specs / "steering" / "spec-rules.md").relative_to(root).as_posix()
        change = tiers.classify(root, (specs / "steering" / "autonomy.md").relative_to(root).as_posix(), rng, specs)
        # shortcut: req_id_pattern comes from the working tree's spec-kit.json, not the head; upgrade if a PR can edit it to pass.
        pattern = spec_lint.load_config(specs)["req_id_pattern"]
    except SystemExit as err:
        return refuse(str(err.code))
    except (json.JSONDecodeError, OSError) as err:
        return refuse("cannot read " + str(specs / "spec-kit.json") + ": " + str(err))
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
    staged = not rng and subprocess.run(["git", "-C", str(root), "diff", "--cached", "--quiet"]).returncode == 1
    g = check_gates(text, [r[0] for r in rows], head, bool(rng), staged)
    # gates.py runs the head's table in order, so any edit (a row added before a base row, a duplicate label, a changed
    # command) changes what ran. Equal rows or not ready.
    # shortcut: equal commands do not mean equal scripts: a PR that edits a script a gate calls still passes; setup
    # puts gate scripts in the last tier; upgrade by comparing the files a command names.
    hrules = tiers.profile_at(root, head if rng else "", rel)
    try:
        hrows = gates.gate_rows(hrules) if hrules else None
    except ValueError:
        hrows = None
    if hrows != rows:
        g["problems"].append("Gates table changed in this change: goes to the human")
    g["ok"] = not g["problems"]
    review = check_review(text, base, change["reviewer"])
    verification = check_verification(text, root, head, bool(rng), pattern)
    problems = g["problems"] + review["problems"] + verification["problems"]
    warnings = g["warnings"] + review["warnings"]
    verdict = "not ready" if problems else "ready"
    tier = {k: change[k] for k in ("tier", "reviewer", "human")}
    # none needs earned evidence, as in the label, and a reviewer of another family (REQ-V060-09, -13); exit code unchanged
    why = []
    if tier["human"] == "none":
        prof = specs / "steering" / "autonomy.md"
        why = [w for w in (tiers.earned(root, prof.relative_to(root).as_posix(), specs, prof, tier["tier"])
                           if change["why"] is None else None,
                           "same family" if review["same_family"] else None) if w]
    tier["human_why"] = "; ".join(why) or None
    tier["human"] = "spot" if tier["human_why"] else tier["human"]
    if as_json:
        print(json.dumps({"verdict": verdict, "gates": g, "tier": tier, "review": review,
                          "verification": verification, "warnings": warnings}))
    else:
        print("### Readiness")
        print("- gates: %d/%d pass at %s" % (g["passed"], g["total"], head[:7]))
        print("- tier: %s (reviewer: %s, human: %s)" % (tier["tier"], tier["reviewer"], tier["human"]))
        if tier["human_why"]:
            print("- human: none → spot (" + tier["human_why"] + ")")
        print("- verdict: " + verdict)
        for ln in verification["lines"]:
            print("- verification: %s %s: %s" % (ln["req"], ln["target"], ln["status"]))
        for p in problems:
            print("- not ready: " + p)
        for w in warnings:
            print("- warning: " + w)
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
