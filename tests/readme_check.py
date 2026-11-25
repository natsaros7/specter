#!/usr/bin/env python3
"""Mechanical README checks (C-numbers from docs/research/2026-11-25-readme.md), one stdlib process.

Run from anywhere: python3 tests/readme_check.py. One line per check, exit 1 on any FAIL.
TODO(gates.sh): C3 (run each try-it command, compare exit codes, require citation count > 0) needs
one process per command, so it belongs in tests/gates.sh, not here.
"""
import os
import re
import sys

sys.dont_write_bytecode = True
sys.path.insert(0, os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "kit", "scripts"))
import readme_check as kit  # C1, C2, C7, C13, C17 live in the kit script; the rest is specter's own

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
rd = lambda *p: open(os.path.join(ROOT, *p), encoding="utf-8").read()
README = rd("README.md")
LINES = README.splitlines()
VERSION = rd("VERSION").strip()
results = []  # (status, check, message)


def rec(status, check, msg):
    results.append((status, check, msg))


# C1 links, images and anchors resolve (SECURITY.md is C11's job while task 21 is open)
bad = kit.broken_links(README, ROOT, "README.md", skip=("SECURITY.md",))
rec("FAIL" if bad else "PASS", "C1", "broken: " + ", ".join(bad) if bad else "links, images and anchors resolve")

# C2 alt text on every image
n_noalt, n_imgs = kit.alt_check(README)
rec("FAIL" if n_noalt else "PASS", "C2", "%d image(s) without alt" % n_noalt if n_noalt else "%d image(s) all have alt" % n_imgs)

# C4 no OS-only command in a code block
os_only = re.compile(r"^\s*(open|xdg-open|pbcopy|pbpaste|start)\s|&&\s*(open|xdg-open)\s")
hits, fence = [], False
for n, line in enumerate(LINES, 1):
    if line.startswith("```"):
        fence = not fence
    elif fence and os_only.search(line):
        hits.append(str(n))
rec("FAIL" if hits else "PASS", "C4", "OS-only command at line " + ",".join(hits) if hits else "no OS-only command in code blocks")

# C5 versions match VERSION; deck and roadmap name it. A line saying "captured at" dates a screenshot, not the kit.
vers = {v for n, l in enumerate(LINES, 1) if "captured at" not in l for v in re.findall(r"\b\d+\.\d+\.\d+\b", l)}
wrong = sorted(vers - {VERSION})
for f in ("docs/overview/deck/specter-overview.html", "docs/overview/roadmap.svg"):
    if VERSION not in rd(*f.split("/")):
        wrong.append(f + " lacks " + VERSION)
rec("FAIL" if wrong else "PASS", "C5", "stale: " + ", ".join(wrong) if wrong else "README, deck and roadmap name " + VERSION)

# C7 required sections, in order, License last
need = ["Try it", "Set it up", "Decisions", "How it compares", "Limits", "Security", "Contributing", "License"]
miss, heads = kit.missing_sections(README, need)
if heads and not heads[-1].startswith("License"):
    miss.append("License last")
rec("FAIL" if miss else "PASS", "C7", "missing: " + ", ".join(miss) if miss else "required sections present, License last")

# C9 badge count and kind: licence, version or assessment only
badges = re.findall(r"https://img\.shields\.io/[^\"')\s]+", README)
ok_kind = re.compile(r"badge/license-|github/(license|v/|actions/workflow|check-runs)|codecov|coveralls")
odd = [b for b in badges if not ok_kind.search(b)]
rec("FAIL" if len(badges) > 4 or odd else "PASS", "C9", "%d badge(s)%s" % (len(badges), "; not licence/version/assessment: " + ", ".join(odd) if odd else ""))

# C11 SECURITY.md linked; warn while the file is missing (task 21 adds it)
linked = "SECURITY.md" in kit.targets(README)
exists = os.path.exists(os.path.join(ROOT, "SECURITY.md"))
if not linked:
    rec("FAIL", "C11", "README does not link SECURITY.md")
elif not exists:
    rec("WARN", "C11", "linked, but SECURITY.md does not exist yet (task 21)")
else:
    s = rd("SECURITY.md").lower()
    rec("PASS" if "version" in s and "report" in s else "FAIL", "C11", "SECURITY.md linked; needs supported versions and a report channel")

# C12 a "works with" badge may name only agents with a check mark in the table
rows = {m[0].strip(): m[1] for m in re.findall(r"^\|\s*([^|]+?)\s*\|[^\n]*\|\s*([^|\n]+?)\s*\|$", README, re.M)}
good = [a for a, st in rows.items() if "✅" in st]
wb = [b for b in re.findall(r"badge/works[^\"')\s]+", README)]
over = []
for b in wb:
    names = re.split(r"[·,]", b.split("works%20with-", 1)[-1].rsplit("-", 1)[0].replace("%20", " "))
    over += [n.strip() for n in names if not any(n.strip().lower() == g.lower() for g in good)]
rec("FAIL" if over else "PASS", "C12", "badge names non-checked agent(s): " + ", ".join(over) if over else "no works-with badge overclaims (checked: %s)" % ", ".join(good))

# C13 length
rec("FAIL" if len(LINES) >= kit.DEFAULTS["max_lines"] else "PASS", "C13", "%d lines (limit %d)" % (len(LINES), kit.DEFAULTS["max_lines"] - 1))

# C15 each screenshot shown in the README or the overview has its raw text beside it
shots = set()
for f in ("README.md", "docs/overview/README.md"):
    base = os.path.dirname(f)
    for t in kit.targets(rd(*f.split("/"))):
        p = os.path.normpath(os.path.join(base, t.split("#")[0]))
        if "screenshots/" in p and p.endswith(".png"):
            shots.add(p)
nots = [s for s in sorted(shots) if not os.path.exists(os.path.join(ROOT, s[:-4] + ".txt"))]
rec("FAIL" if nots else "PASS", "C15", "no raw text: " + ", ".join(nots) if nots else "%d screenshot(s) all have raw text" % len(shots))

# C17 marketing words
deny = re.compile(r"\b(blazing|seamless(ly)?|powerful|most loved|best-in-class|cutting-edge|revolutionary|game-chang\w+|supercharge\w*|effortless(ly)?|robust|world-class|10x)\b", re.I)
mk = kit.deny_hits(LINES, deny)
rec("FAIL" if mk else "PASS", "C17", "marketing words " + ", ".join(mk) if mk else "no marketing words")

for st, c, msg in results:
    print("%-4s %-3s %s" % (st, c, msg))
sys.exit(1 if any(r[0] == "FAIL" for r in results) else 0)
