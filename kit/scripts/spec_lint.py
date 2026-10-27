#!/usr/bin/env python3
"""Script gate for the spec layer. Structural only: no AI and no network. Python 3.8+, stdlib only.

Usage: python3 .specs/kit/scripts/spec_lint.py [--specs DIR] [feature-dir-name ...]
       python3 .specs/kit/scripts/spec_lint.py [--specs DIR] --cites    check `path:line` citations only
       default DIR = the .specs/ this script is installed in; default features = all

--cites resolves every `path:line` / `path:a-b` in backticks against the project (the folder holding .specs/).
      Elided paths (`.../web/Foo.java:12`) match by suffix. FAIL: no such file, ambiguous, past EOF, or a blank cited line.

FAIL (exit 1): a feature is missing requirements/design/tasks.md; a feature folder name is not kebab-case;
      a feature defines no [REQ-..]; a defined REQ is absent from design.md or tasks.md; a REQ is
      referenced but defined neither in the feature nor in domains/*/requirements.md; a relative markdown link under .specs/ points to nothing.
WARN: a task checkbox without a REQ; a required section (spec-kit.json) is missing; an upstream
      requirement id used in a feature is not in system/traceability.md; setup is still incomplete.
"""
import json
import re
import subprocess
import sys
from pathlib import Path

TASK = re.compile(r"^\s*- \[[ xX]\] ")
KEBAB = re.compile(r"^[a-z0-9]+(-[a-z0-9]+)*$")
LINK = re.compile(r"\[[^\]]*\]\(([^)\s]+)\)")
FENCE = re.compile(r"^```.*?^```", re.M | re.S)
DEFAULTS = {"req_id_pattern": "REQ-[A-Z0-9]+-[0-9]+", "upstream_req_pattern": None, "required_sections": {}}


def load_config(specs):
    path = specs / "spec-kit.json"
    config = dict(DEFAULTS)
    if path.exists():
        config.update(json.loads(path.read_text()))
    return config


def lint_feature(feature, config, traceability, domain_reqs=frozenset()):
    fails, warns = [], []
    req = re.compile(config["req_id_pattern"])
    defined_re = re.compile(r"\[(" + config["req_id_pattern"] + r")\]")
    if not KEBAB.match(feature.name):
        fails.append("folder name is not kebab-case")
    docs = {}
    for name in ("requirements", "design", "tasks"):
        path = feature / (name + ".md")
        if path.exists():
            docs[name] = path.read_text()
        else:
            fails.append("missing " + name + ".md")
    if "requirements" not in docs:
        return fails, warns
    defined = set(defined_re.findall(docs["requirements"]))
    if not defined:
        fails.append("requirements.md defines no [" + config["req_id_pattern"] + "]")
    for name in ("design", "tasks"):
        if name in docs:
            untraced = sorted(defined - set(req.findall(docs[name])))
            if untraced:
                fails.append(name + ".md does not trace " + ", ".join(untraced))
    referenced = set().union(*(req.findall(text) for text in docs.values()))
    dangling = sorted(referenced - defined - domain_reqs)
    if dangling:
        fails.append("referenced but never defined: " + ", ".join(dangling))
    if "tasks" in docs:
        bare = [line.strip()[:70] for line in docs["tasks"].splitlines() if TASK.match(line) and not req.search(line)]
        if bare:
            warns.append(str(len(bare)) + " task(s) without a REQ link, e.g. '" + bare[0] + "'")
    for name, headings in config.get("required_sections", {}).items():
        for heading in headings:
            if name in docs and not re.search(r"^" + re.escape(heading) + r"\s*$", docs[name], re.M):
                warns.append(name + ".md has no '" + heading + "' section")
    if config.get("upstream_req_pattern") and traceability is not None:
        upstream = re.compile(config["upstream_req_pattern"])
        unknown = sorted(set().union(*(upstream.findall(t) for t in docs.values())) - set(upstream.findall(traceability)))
        if unknown:
            warns.append("upstream id(s) not in system/traceability.md: " + ", ".join(unknown))
    return fails, warns


def broken_links(specs):
    broken = []
    for md in sorted(specs.rglob("*.md")):
        if "kit" in md.relative_to(specs).parts[:1]:
            continue
        text = FENCE.sub("", md.read_text())
        for target in LINK.findall(text):
            if re.match(r"^[a-z]+:", target) or target.startswith("#"):
                continue
            path = target.split("#", 1)[0]
            if path and not (md.parent / path).exists():
                broken.append(str(md.relative_to(specs)) + " -> " + target)
    return broken


CITE = re.compile(r"`([^`\s]*?[\w-]+\.[A-Za-z0-9]+):(\d+)(?:-(\d+))?`")


def check_cites(specs):
    root = specs.parent
    def ls(repo, prefix=""):
        out = subprocess.run(["git", "-C", str(repo), "ls-files", "--cached", "--others", "--exclude-standard"],
                             capture_output=True, text=True).stdout.splitlines()
        return [prefix + f for f in out]
    files = ls(root) + [f for child in sorted(root.glob("*/.git")) for f in ls(child.parent, child.parent.name + "/")]
    files = files or [str(p.relative_to(root)) for p in root.rglob("*") if p.is_file()]
    problems, count = [], 0
    for md in sorted(specs.rglob("*.md")):
        if "kit" in md.relative_to(specs).parts[:1]:
            continue
        for path, start, end in CITE.findall(FENCE.sub("", md.read_text())):
            count += 1
            where = str(md.relative_to(specs)) + ": `" + path + ":" + start + (("-" + end) if end else "") + "`"
            tail = re.split(r"\.\.\./|…/", path)[-1].lstrip("./")
            if (root / path).is_file():
                target = root / path
            else:
                hits = [f for f in files if f == tail or f.endswith("/" + tail)]
                parts = md.relative_to(specs).parts
                if len(hits) > 1 and parts[0] == "domains":
                    hits = [f for f in hits if parts[1] in f.split("/")[0]] or hits
                if len(hits) != 1:
                    problems.append(where + (" ambiguous (use the repo-relative path): " + ", ".join(hits[:3]) if hits else " no such file"))
                    continue
                target = root / hits[0]
            lines = target.read_text(errors="replace").splitlines()
            last = int(end or start)
            if last > len(lines):
                problems.append(where + " past end of file (" + str(len(lines)) + " lines)")
            elif not any(line.strip() for line in lines[int(start) - 1:last]):
                problems.append(where + (" cited lines are blank" if end else " cited line is blank"))
    for p in problems:
        print("FAIL cite " + p)
    print("spec-lint --cites: " + str(len(problems)) + " FAIL of " + str(count) + " citation(s)")
    return 1 if problems else 0


def main(argv):
    specs = Path(__file__).resolve().parents[2]
    if argv[:1] == ["--specs"]:
        specs, argv = Path(argv[1]).resolve(), argv[2:]
    if "--cites" in argv:
        return check_cites(specs)
    config = load_config(specs)
    features_dir = specs / "features"
    trace_path = specs / "system" / "traceability.md"
    traceability = trace_path.read_text() if trace_path.exists() else None
    if argv:
        targets = [features_dir / n for n in argv]
    elif features_dir.is_dir():
        targets = sorted(p for p in features_dir.iterdir() if p.is_dir())
    else:
        targets = []
    defined_re = re.compile(r"\[(" + config["req_id_pattern"] + r")\]")
    domain_reqs = frozenset(i for p in sorted(specs.glob("domains/*/requirements.md")) for i in defined_re.findall(p.read_text()))
    total = 0
    profile = specs / "steering" / "project-profile.md"
    if not profile.exists() or "status: setup-incomplete" in profile.read_text():
        print("WARN setup incomplete: run .specs/kit/playbooks/setup.md")
    for feature in targets:
        if not feature.is_dir():
            print("FAIL " + feature.name + ": no such feature directory")
            total += 1
            continue
        fails, warns = lint_feature(feature, config, traceability, domain_reqs)
        total += len(fails)
        print(("FAIL " if fails else "OK   ") + feature.name)
        for f in fails:
            print("     FAIL " + f)
        for w in warns:
            print("     WARN " + w)
    links = broken_links(specs)
    for link in links:
        print("FAIL broken link: " + link)
    total += len(links)
    print("spec-lint: " + str(total) + " FAIL across " + str(len(targets)) + " feature(s)")
    return 1 if total else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
