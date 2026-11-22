#!/usr/bin/env python3
"""Check the Tiers table of the autonomy profile. Python 3.8+, stdlib only.

Usage: python3 .specs/kit/scripts/tiers.py --check [--specs DIR] [--file PATH] | --help
       default DIR = the .specs/ this script is installed in; default PATH = DIR/steering/autonomy.md

--check reads the working-tree profile and validates its `## Tiers` table: unique tier names, at least one `glob`
code span per Paths cell, Reviewer standard|deep, Human none|spot|required and never decreasing down the table, the
last row `required`, no <placeholder> left in. It also fails when a tier above the last lists a guarded path (the
profile itself, the installed kit, Knowledge targets, agent files): guarded paths always take the last row.
Exit 0: valid, or no profile / no Tiers section (not configured: the human tier applies, as in 0.5.0).
Exit 1: a guarded path sits in a tier above the last. Exit 2: bad profile or argument, with `file:line`.
Labelling a change (staged or --range, reading the profile at the base commit) is not built yet.
"""
import fnmatch
import posixpath
import re
import subprocess
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import gates  # noqa: E402

HEAD = ["Tier", "Paths", "Reviewer", "Human"]
REVIEWER = ("standard", "deep")
HUMAN = ("none", "spot", "required")
# The installer writes these; install.py is not copied into projects, so they are listed here.
# shortcut: kept by hand; selftest 13b fails when install.AGENTS gains a skills folder not covered, add it here then.
GUARDED = [".specs/steering/*", ".specs/spec-kit.json", ".specs/kit/*", "AGENTS.md", "CLAUDE.md", "GEMINI.md",
           ".github/copilot-instructions.md", ".claude/*", ".codex/*", ".cursor/*", ".gemini/*", ".agents/*",
           ".agent/*", ".github/skills/*"]
PLACEHOLDER = re.compile(r"<[^<>`]*>")


def section(text, name):
    """[(lineno, line)] under `## name` up to the next `## `, or None when the heading is absent."""
    out, inside = None, False
    for n, line in enumerate(text.splitlines(), 1):
        if line.startswith("## "):
            inside = line[3:].strip().lower() == name.lower()
            out = [] if inside and out is None else out
        elif inside:
            out.append((n, line))
    return out


def parse_tiers(text):
    """[(tier, globs, reviewer, human, lineno)] or None when there is no Tiers section.
    Raises ValueError((lineno, message)) on the first bad row."""
    lines = section(text, "Tiers")
    if lines is None:
        return None
    rows, head = [], None
    for n, line in lines:
        if not line.lstrip().startswith("|"):
            continue
        cells = gates.split_row(line)
        if head is None:
            head = [c.lower() for c in cells]
            if head != [h.lower() for h in HEAD]:
                raise ValueError((n, "header must be | " + " | ".join(HEAD) + " |"))
            continue
        if set("".join(cells)) <= set("-: "):
            continue
        if len(cells) != 4:
            raise ValueError((n, "row needs 4 cells, found " + str(len(cells))))
        tier, paths, reviewer, human = cells
        if PLACEHOLDER.search(line):
            raise ValueError((n, "tier '" + tier + "' still holds a template placeholder"))
        spans = re.findall(r"`([^`]+)`", paths)
        if not tier or not spans:
            raise ValueError((n, "tier '" + tier + "' needs a name and at least one `glob` in Paths"))
        if tier in [r[0] for r in rows]:
            raise ValueError((n, "duplicate tier '" + tier + "'"))
        if reviewer not in REVIEWER or human not in HUMAN:
            raise ValueError((n, "Reviewer is standard|deep and Human is none|spot|required, found " + reviewer + "|" + human))
        if rows and HUMAN.index(human) < HUMAN.index(rows[-1][3]):
            raise ValueError((n, "Human goes down (" + rows[-1][3] + " then " + human + "); order rows from most to least autonomous"))
        rows.append((tier, spans, reviewer, human, n))
    if not rows:
        raise ValueError((lines[0][0] - 1, "Tiers has no rows"))
    if rows[-1][3] != "required":
        raise ValueError((rows[-1][4], "the last tier must be Human required"))
    return rows


def guarded_globs(text, rel):
    """GUARDED plus the in-repo link targets of the Knowledge table (a folder becomes folder/*). rel is the profile's
    path from the repo root, which relative links resolve against."""
    out = list(GUARDED)
    for _, line in section(text, "Knowledge") or []:
        for target in re.findall(r"\]\(([^)\s]+)\)", line):
            target = target.split("#")[0]
            path = posixpath.normpath(posixpath.join(posixpath.dirname(rel), target)) if target else ""
            if not path or ":" in target or path.startswith(("..", "/")):
                continue
            out.append(path + "/*" if target.endswith("/") else path)
    return out


def profile_at(root, base, rel):
    """The profile's text as of commit `base`, or None when it does not exist there (never the working tree)."""
    run = subprocess.run(["git", "-C", str(root), "show", base + ":./" + rel], capture_output=True, text=True)
    return run.stdout if run.returncode == 0 else None


USAGE = "usage: tiers.py --check [--specs DIR] [--file PATH] | --help"


def refuse(msg):
    print("tiers: " + msg, file=sys.stderr)
    return 2


def main(argv):
    if "-h" in argv or "--help" in argv:
        print(__doc__.strip())
        return 0
    specs = Path(__file__).resolve().parents[2]
    profile = None
    for flag in ("--specs", "--file"):
        if flag in argv:
            i = argv.index(flag)
            if i + 1 >= len(argv):
                return refuse(USAGE)
            value, argv = Path(argv[i + 1]).resolve(), argv[:i] + argv[i + 2:]
            specs, profile = (value, profile) if flag == "--specs" else (specs, value)
    if argv != ["--check"]:
        return refuse("expected --check" + ("; unknown argument(s) " + " ".join(argv) if argv else "") + "; " + USAGE)
    profile = profile or specs / "steering" / "autonomy.md"
    try:
        text = profile.read_text()
    except OSError:
        print("tiers: no " + str(profile) + ": not configured, every change takes the human tier")
        return 0
    try:
        rows = parse_tiers(text)
    except ValueError as err:
        return refuse(str(profile) + ":" + str(err.args[0][0]) + ": " + err.args[0][1])
    if rows is None:
        print("tiers: no Tiers section in " + str(profile) + ": not configured, every change takes the human tier")
        return 0
    try:
        rel = profile.relative_to(specs.parent).as_posix()
    except ValueError:
        rel = ".specs/steering/autonomy.md"
    guarded = guarded_globs(text, rel)
    for tier, globs, _, _, n in rows[:-1]:
        for g in globs:
            if any(fnmatch.fnmatch(g, p) for p in guarded):
                print("FAIL " + str(profile) + ":" + str(n) + ": tier '" + tier + "' lists guarded path " + g + ", which always takes '" + rows[-1][0] + "'")
                return 1
    print("tiers: " + str(len(rows)) + " tier(s) ok in " + str(profile))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
