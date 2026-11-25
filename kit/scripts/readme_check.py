#!/usr/bin/env python3
"""Mechanical README checks, one stdlib process, any project. Python 3.8+.

Usage: python3 .specs/kit/scripts/readme_check.py [--specs DIR] | --help
       default DIR = the .specs/ this script is installed in; the README path is relative to its parent, the project root.

One line per check, `PASS C1 ...` or `FAIL C1 ...`:
  C1  links, images and anchors resolve (relative to the project root; URLs are not fetched)
  C2  every image has alt text
  C13 the README has fewer than max_lines lines
  C7  the `sections` headings (## level, prefix match) are present, in that order (only when configured)
  C17 no word of `deny` appears outside code fences, case-insensitive (only when configured)
Settings: spec-kit.json key `readme`: {"path": "README.md", "max_lines": 200, "sections": [], "deny": []}.
A missing key means the default.
Exit 0 all pass, 1 a FAIL, 2 a bad argument, a bad `readme` setting, or a README that cannot be read (never "0 checks").
"""
import argparse
import json
import os
import re
import sys
from pathlib import Path

DEFAULTS = {"path": "README.md", "max_lines": 200, "sections": [], "deny": []}


def slugs(text):
    out, fence = set(), False
    for line in text.splitlines():
        if line.startswith("```"):
            fence = not fence
        m = None if fence else re.match(r"#{1,6}\s+(.*)", line)
        if m:
            h = re.sub(r"[`*_]", "", m.group(1)).strip().lower()
            out.add(re.sub(r"\s", "-", re.sub(r"[^\w\s-]", "", h)))
    return out


def targets(text):
    t = re.findall(r"\]\(([^)\s]+)\)", text) + re.findall(r'(?:src|href)="([^"]+)"', text)
    return [x for x in t if not re.match(r"[a-z]+:", x)]


def prose_lines(lines):
    fence = False
    for n, line in enumerate(lines, 1):
        if line.startswith("```"):
            fence = not fence
        elif not fence:
            yield n, line


def broken_links(text, root, readme, skip=()):
    """Targets (relative to root) whose file or `#anchor` does not exist; `skip` names targets left to another check."""
    bad = []
    for t in targets(text):
        path, _, anchor = t.partition("#")
        if path in skip:
            continue
        f = os.path.join(root, path) if path else os.path.join(root, readme)
        if not os.path.exists(f):
            bad.append(t)
        elif anchor and f.endswith(".md") and anchor not in slugs(open(f, encoding="utf-8").read()):
            bad.append(t)
    return bad


def alt_check(text):
    """(images without alt text, image count)."""
    imgs = re.findall(r"<img\b[^>]*>", text)
    noalt = [i for i in imgs if not re.search(r'alt="[^"]+"', i)]
    noalt += [m for m in re.findall(r"!\[([^\]]*)\]\(", text) if not m.strip()]
    return len(noalt), len(imgs)


def missing_sections(text, need):
    """(problems, headings): each `need` entry absent, or present but out of order, against the `##` headings."""
    heads = [re.sub(r"[`*]", "", m) for m in re.findall(r"^##\s+(.*)$", text, re.M)]
    out, pos = [], 0
    for s in need:
        i = next((n for n in range(pos, len(heads)) if heads[n].startswith(s)), None)
        if i is not None:
            pos = i + 1
        elif any(h.startswith(s) for h in heads):
            out.append(s + " (out of order)")
        else:
            out.append(s)
    return out, heads


def deny_hits(lines, pattern):
    """`line:word` for each prose line that matches the compiled `pattern`."""
    return ["%d:%s" % (n, m.group(0)) for n, l in prose_lines(lines) for m in [pattern.search(l)] if m]


def load_settings(specs):
    """The `readme` settings with defaults; ValueError names a wrong type."""
    path = Path(specs) / "spec-kit.json"
    try:
        raw = json.loads(path.read_text(encoding="utf-8")) if path.exists() else {}
    except (OSError, ValueError) as err:
        raise ValueError("cannot read %s: %s" % (path, err))
    cfg = raw.get("readme", {}) if isinstance(raw, dict) else None
    if not isinstance(cfg, dict):
        raise ValueError("spec-kit.json: readme must be an object")
    unknown = sorted(set(cfg) - set(DEFAULTS))
    if unknown:
        raise ValueError("spec-kit.json: readme has unknown key(s) " + ", ".join(unknown))
    out = dict(DEFAULTS, **cfg)
    p = out["path"]
    if not isinstance(p, str) or not p or os.path.isabs(p) or ".." in Path(p).parts:
        raise ValueError("spec-kit.json: readme.path must be a relative path inside the project, got " + json.dumps(p))
    m = out["max_lines"]
    if not isinstance(m, int) or isinstance(m, bool) or m < 1:
        raise ValueError("spec-kit.json: readme.max_lines must be a positive integer, got " + json.dumps(m))
    for k in ("sections", "deny"):
        if not isinstance(out[k], list) or not all(isinstance(x, str) and x for x in out[k]):
            raise ValueError("spec-kit.json: readme.%s must be a list of non-empty strings, got %s" % (k, json.dumps(out[k])))
    return out


def main(argv=None):
    ap = argparse.ArgumentParser(description="Mechanical README checks (see the module docstring).")
    ap.add_argument("--specs", default=str(Path(__file__).resolve().parents[2]), help="the .specs/ folder")
    args = ap.parse_args(argv)
    specs = Path(args.specs)
    try:
        cfg = load_settings(specs)
        root = specs.resolve().parent
        text = (root / cfg["path"]).read_text(encoding="utf-8")
    except (ValueError, OSError) as err:
        print("readme_check: " + str(err), file=sys.stderr)
        return 2
    lines = text.splitlines()
    res = []
    bad = broken_links(text, str(root), cfg["path"])
    res.append(("C1", not bad, "broken: " + ", ".join(bad) if bad else "links, images and anchors resolve"))
    n, total = alt_check(text)
    res.append(("C2", not n, "%d image(s) without alt" % n if n else "%d image(s) all have alt" % total))
    res.append(("C13", len(lines) < cfg["max_lines"], "%d lines (limit %d)" % (len(lines), cfg["max_lines"] - 1)))
    if cfg["sections"]:
        miss, _ = missing_sections(text, cfg["sections"])
        res.append(("C7", not miss, "missing: " + ", ".join(miss) if miss else "required sections present, in order"))
    if cfg["deny"]:
        hits = deny_hits(lines, re.compile(r"\b(" + "|".join(map(re.escape, cfg["deny"])) + r")\b", re.I))
        res.append(("C17", not hits, "denied words " + ", ".join(hits) if hits else "no denied words"))
    for c, ok, msg in res:
        print("%s %-3s %s" % ("PASS" if ok else "FAIL", c, msg))
    return 0 if all(r[1] for r in res) else 1


if __name__ == "__main__":
    sys.exit(main())
