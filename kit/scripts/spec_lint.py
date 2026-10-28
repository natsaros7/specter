#!/usr/bin/env python3
"""Script gate for the spec layer. Structural only: no AI and no network. Python 3.8+, stdlib only.

Usage: python3 .specs/kit/scripts/spec_lint.py [--specs DIR] [--json] [feature-dir-name ...]
       python3 .specs/kit/scripts/spec_lint.py [--specs DIR] [--json] --cites    check `path:line` citations only
       default DIR = the .specs/ this script is installed in; default features = all

--json prints one JSON object instead of text (same exit code): default mode {features, links, drift, warnings, fails},
      --cites {count, problems}.

--cites resolves every citation in backticks against the project (the folder holding .specs/). Notations:
      `path:12`  `path:12-20`  `path:12-20,31,40-44`  `path#L12`  `path#L12-L20`  and `<repo>:path:12`, where <repo> is a
      key of cite_aliases (spec-kit.json: {"NS": "tools/load-sim"}) or the folder name of an indexed repo. Git repos are
      indexed up to two levels below the project. Elided paths (`.../web/Foo.java:12`) match by suffix; if several files
      match, those matching cite_ignore_globs are dropped. Every listed range is checked on its own.
      FAIL: no such file, ambiguous, unknown repo prefix, past EOF, or a blank cited range.

FAIL (exit 1): a feature is missing requirements/design/tasks.md; a feature folder name is not kebab-case;
      a feature defines no [REQ-..]; a defined REQ is absent from design.md or tasks.md; a REQ is
      referenced but defined neither in the feature nor in domains/*/requirements.md; a relative markdown link under .specs/ points to nothing.
WARN: a task checkbox without a REQ; a required section (spec-kit.json) is missing; an upstream
      requirement id used in a feature is not in system/traceability.md; setup is still incomplete; an unresolved
      Drift Register row (any table with a Drift column; Logged optional) is older than drift_max_age_days (default 90, null = off),
      or, once per file, has open rows without a Logged date; a feature has no `Status:` line, an unknown status, or a status that
      disagrees with its tasks (all ticked but not Done, Done with unticked tasks, Done without a date); with tracker_pattern set,
      commits on merged_ref name the feature's key while the spec says proposed, missing or no task is ticked.
"""
import datetime
import fnmatch
import json
import re
import subprocess
import sys
from pathlib import Path

TASK = re.compile(r"^\s*- \[[ xX]\] ")
KEBAB = re.compile(r"^[a-z0-9]+(-[a-z0-9]+)*$")
LINK = re.compile(r"\[[^\]]*\]\(([^)\s]+)\)")
FENCE = re.compile(r"^```.*?^```", re.M | re.S)
DATE = re.compile(r"\d{4}-\d{2}-\d{2}")
DEFAULTS = {"req_id_pattern": "REQ-[A-Z0-9]+-[0-9]+", "upstream_req_pattern": None, "required_sections": {},
            "cite_aliases": {}, "cite_ignore_globs": [], "drift_max_age_days": 90,
            "tracker_pattern": None, "merged_ref": "origin/HEAD"}
STATUS = re.compile(r"^\s*>?\s*(\*\*)?Status:?(\*\*)?\s*(.+)$", re.I)
STATES = (("proposed", "Proposed"), ("in progress", "In progress"), ("blocked on", "Blocked"), ("done", "Done"), ("dropped", "Dropped"))
MERGED = "merged work found"


def feature_status(text):
    """First Status line before the first '## ': {"state", "date", "raw"}, or None. state is '' when the value is unknown."""
    for line in text.splitlines():
        if line.startswith("## "):
            return None
        m = STATUS.match(line)
        if m:
            raw = m.group(3).replace("**", "").strip()
            state = next((name for prefix, name in STATES if raw.lower().startswith(prefix)), "")
            found = DATE.search(raw)
            return {"state": state, "date": found.group() if found else None, "raw": raw}
    return None


def task_counts(text):
    lines = [l for l in text.splitlines() if TASK.match(l)]
    return sum(1 for l in lines if re.match(r"^\s*- \[[xX]\]", l)), len(lines)


def load_config(specs):
    path = specs / "spec-kit.json"
    config = dict(DEFAULTS)
    if path.exists():
        config.update(json.loads(path.read_text()))
    age = config["drift_max_age_days"]
    if age is not None:
        try:
            config["drift_max_age_days"] = int(age)
        except (TypeError, ValueError):
            sys.exit("spec-kit.json: drift_max_age_days must be an integer or null, got " + json.dumps(age))
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
    status = feature_status(docs["requirements"])
    done, total = task_counts(docs.get("tasks", ""))
    if status is None:
        warns.append("no Status line (see the requirements template)")
    elif not status["state"]:
        warns.append("unknown status '" + status["raw"] + "'")
    state = status["state"] if status else ""
    if total and done == total and state not in ("Done", "Dropped"):
        warns.append("all tasks ticked: close out (Status: Done <date> (<PR>), fold into domains/ per sync.md)")
    if state == "Done":
        if done < total:
            warns.append("Status is Done but " + str(total - done) + " task(s) are unticked")
        if not status["date"]:
            warns.append("Done needs a date and the PR or commit")
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




def repos(root):
    """Child git repos up to two levels below root: `.git` is a directory (skips linked worktrees and submodules), no hidden parts."""
    return sorted({p.parent.relative_to(root).as_posix() for pat in ("*/.git", "*/*/.git") for p in root.glob(pat)
                   if p.is_dir() and not any(part.startswith(".") for part in p.parent.relative_to(root).parts)})


def merged_commits(root, child_repos, config):
    """{repo label: [commit message, ...]} on merged_ref (else HEAD), one git log per repo. Repos with no usable ref are skipped."""
    out = {}
    for label, path in [(root.name, root)] + [(r, root / r) for r in child_repos]:
        if not (path / ".git").exists():
            continue
        git = lambda *a: subprocess.run(["git", "-C", str(path)] + list(a), capture_output=True, encoding="utf-8", errors="replace")
        ref = config["merged_ref"] if git("rev-parse", "--verify", "--quiet", config["merged_ref"]).returncode == 0 else "HEAD"
        log = git("log", ref, "--format=%x00%s%n%b")
        if log.returncode == 0:
            out[label] = [m for m in log.stdout.split("\0") if m.strip()]
    return out


def drift_rows(specs, max_age):
    today, rows = datetime.date.today(), []
    for md in sorted(specs.rglob("*.md")):
        if md.relative_to(specs).parts[0] == "kit":
            continue
        cols = None
        for line in FENCE.sub("", md.read_text()).splitlines():
            if not line.lstrip().startswith("|"):
                cols = None
                continue
            cells = [c.strip() for c in line.strip().strip("|").replace("\\|", "\x00").split("|")]
            lower = [c.lower() for c in cells]
            if cols is None:
                cols = {name: i for i, name in enumerate(lower)} if "drift" in lower else False
                continue
            if not cols or not cells[0] or set("".join(cells)) <= set("-: "):
                continue
            cell = lambda name: cells[cols[name]] if name in cols and cols[name] < len(cells) else ""
            found = DATE.search(cell("logged"))
            try:
                logged = datetime.date.fromisoformat(found.group()) if found else None
            except ValueError:
                logged = None
            sev = cell("sev")
            rows.append({"file": str(md.relative_to(specs)), "id": cells[0], "sev": sev, "text": cell("drift").replace("\x00", "|"),
                         "logged": str(logged) if logged else None,
                         "age_days": (today - logged).days if logged else None, "resolved": "RESOLVED" in line})
    return rows


def lint_all(specs, names=()):
    config = load_config(specs)
    features_dir = specs / "features"
    trace_path = specs / "system" / "traceability.md"
    traceability = trace_path.read_text() if trace_path.exists() else None
    if names:
        targets = [features_dir / n for n in names]
    elif features_dir.is_dir():
        targets = sorted(p for p in features_dir.iterdir() if p.is_dir())
    else:
        targets = []
    defined_re = re.compile(r"\[(" + config["req_id_pattern"] + r")\]")
    domain_reqs = frozenset(i for p in sorted(specs.glob("domains/*/requirements.md")) for i in defined_re.findall(p.read_text()))
    warnings = []
    profile = specs / "steering" / "project-profile.md"
    if not profile.exists() or "status: setup-incomplete" in profile.read_text():
        warnings.append("WARN setup incomplete: run .specs/kit/playbooks/setup.md")
    features, commits = [], None
    for feature in targets:
        if feature.is_dir():
            fails, warns = lint_feature(feature, config, traceability, domain_reqs)
            keys = {m.group(0).upper() for m in re.finditer(config["tracker_pattern"], feature.name, re.I)} if config["tracker_pattern"] else set()
            if keys and (feature / "requirements.md").exists():
                if commits is None:
                    commits = merged_commits(specs.parent, repos(specs.parent), config)
                hit = re.compile("|".join(re.escape(k) + "(?![0-9])" for k in sorted(keys)))
                found = {r: sum(1 for m in msgs if hit.search(m.upper())) for r, msgs in commits.items()}
                found = {r: n for r, n in found.items() if n}
                status = feature_status((feature / "requirements.md").read_text())
                tasks = feature / "tasks.md"
                done, total = task_counts(tasks.read_text() if tasks.exists() else "")
                if found and (status is None or status["state"] == "Proposed" or not done):
                    says = status["state"] or status["raw"] if status else "no Status"
                    warns.append(MERGED + " (" + str(sum(found.values())) + " commit(s) in " + ", ".join(found) + ") but the spec says "
                                 + says + ", " + str(done) + "/" + str(total) + " tasks")
        else:
            fails, warns = ["no such feature directory"], []
        features.append({"name": feature.name, "ok": not fails, "fails": fails, "warns": warns})
    links = broken_links(specs)
    max_age = config.get("drift_max_age_days")
    drift = drift_rows(specs, max_age)
    if max_age is not None:
        undated = {}
        for row in (r for r in drift if not r["resolved"]):
            if row["age_days"] is None:
                undated[row["file"]] = undated.get(row["file"], 0) + 1
            elif row["age_days"] > max_age:
                warnings.append("WARN drift " + row["file"] + " " + row["id"] + ": open " + str(row["age_days"]) + " days")
        warnings += ["WARN drift " + f + ": " + str(n) + " open row(s) without a Logged date" for f, n in undated.items()]
    total = sum(len(f["fails"]) for f in features) + len(links)
    return {"features": features, "links": links, "drift": drift, "warnings": warnings, "fails": total}


CITE = re.compile(r"`(?:([\w.-]+):)?([^`\s:#]*?[\w-]+\.[A-Za-z0-9]+)"
                  r"(?::(\d+(?:-\d+)?(?:,\d+(?:-\d+)?)*)|#L(\d+)(?:-L?(\d+))?)`")


def parse_ranges(colon, start, end):
    if colon:
        return [(int(r.split("-")[0]), int(r.split("-")[-1])) for r in colon.split(",")]
    return [(int(start), int(end or start))]


def cites(specs):
    root, config = specs.parent, load_config(specs)
    aliases, ignore = config["cite_aliases"], config["cite_ignore_globs"]
    def ls(repo, prefix=""):
        out = subprocess.run(["git", "-C", str(repo), "ls-files", "--cached", "--others", "--exclude-standard"],
                             capture_output=True, text=True).stdout.splitlines()
        return [prefix + f for f in out if not f.endswith("/")]
    children = repos(root)
    files = list(dict.fromkeys(ls(root) + [f for repo in children for f in ls(root / repo, repo + "/")]))
    files = files or [p.relative_to(root).as_posix() for p in root.rglob("*") if p.is_file()]
    problems, count = [], 0
    def resolve(md, prefix, path):
        """Returns (file, None) or (None, reason)."""
        scope, base = None, ""
        if prefix:
            scope = [aliases[prefix].strip("/")] if prefix in aliases else [r for r in children if r.split("/")[-1] == prefix]
            if not scope:
                return None, "unknown repo prefix '" + prefix + "' (add it to cite_aliases)"
            base = scope[0] + "/"
        if (root / (base + path)).is_file():
            return root / (base + path), None
        pool = [f for f in files if any(f.startswith(s + "/") for s in scope)] if scope else files
        pieces = [re.sub(r"^(\./)+", "", x) for x in re.split(r"\.\.\./|…/", path)]
        tail, heads = pieces[-1], [x.strip("/").split("/") for x in pieces[:-1] if x.strip("/")]
        def has_heads(f):
            segs, at = f[:len(f) - len(tail)].strip("/").split("/"), 0
            for head in heads:
                runs = [i for i in range(at, len(segs) - len(head) + 1) if segs[i:i + len(head)] == head]
                if not runs:
                    return False
                at = runs[0] + len(head)
            return True
        tails = [f for f in pool if f == tail or f.endswith("/" + tail)]
        hits = [f for f in tails if has_heads(f)] or tails
        parts = md.relative_to(specs).parts
        if len(hits) > 1 and parts[0] == "domains":
            hits = [f for f in hits if parts[1] in f.split("/")[0]] or hits
        if len(hits) > 1 and ignore:
            hits = [f for f in hits if not any(fnmatch.fnmatch(f, g) for g in ignore)] or hits
        if len(hits) == 1:
            return root / hits[0], None
        return None, "ambiguous (use the repo-relative path): " + ", ".join(hits[:3]) if hits else "no such file"
    for md in sorted(specs.rglob("*.md")):
        if "kit" in md.relative_to(specs).parts[:1]:
            continue
        for m in CITE.finditer(FENCE.sub("", md.read_text())):
            count += 1
            prefix, path = m.group(1), m.group(2)
            ranges = parse_ranges(m.group(3), m.group(4), m.group(5))
            cite, file = m.group(0).strip("`"), str(md.relative_to(specs))
            target, reason = resolve(md, prefix, path)
            if reason:
                problems.append({"file": file, "cite": cite, "reason": reason})
                continue
            try:
                lines = target.read_text(errors="replace").splitlines()
            except OSError:
                problems.append({"file": file, "cite": cite, "reason": "no such file"})
                continue
            for a, b in ranges:
                label = "range " + str(a) + ("-" + str(b) if b != a else "") + ": " if len(ranges) > 1 else ""
                if b > len(lines):
                    why = "past end of file (" + str(len(lines)) + " lines)"
                elif not any(line.strip() for line in lines[a - 1:b]):
                    why = "cited lines are blank" if b != a else "cited line is blank"
                else:
                    continue
                problems.append({"file": file, "cite": cite, "reason": label + why})
    return {"count": count, "problems": problems}


def main(argv):
    specs = Path(__file__).resolve().parents[2]
    if "--specs" in argv:
        i = argv.index("--specs")
        specs, argv = Path(argv[i + 1]).resolve(), argv[:i] + argv[i + 2:]
    as_json = "--json" in argv
    if "--cites" in argv:
        result = cites(specs)
        if as_json:
            json.dump(result, sys.stdout)
        else:
            for p in result["problems"]:
                print("FAIL cite " + p["file"] + ": `" + p["cite"] + "` " + p["reason"])
            print("spec-lint --cites: " + str(len(result["problems"])) + " FAIL of " + str(result["count"]) + " citation(s)")
        return 1 if result["problems"] else 0
    names = [a for a in argv if not a.startswith("--")]
    result = lint_all(specs, names)
    if as_json:
        json.dump(result, sys.stdout)
        return 1 if result["fails"] else 0
    drift_warns = [w for w in result["warnings"] if w.startswith("WARN drift")]
    for w in result["warnings"]:
        if w not in drift_warns:
            print(w)
    for f in result["features"]:
        if f["fails"] == ["no such feature directory"]:
            print("FAIL " + f["name"] + ": no such feature directory")
            continue
        print(("OK   " if f["ok"] else "FAIL ") + f["name"])
        for text in f["fails"]:
            print("     FAIL " + text)
        for text in f["warns"]:
            print("     WARN " + text)
    for link in result["links"]:
        print("FAIL broken link: " + link)
    for w in drift_warns:
        print(w)
    print("spec-lint: " + str(result["fails"]) + " FAIL across " + str(len(result["features"])) + " feature(s)")
    return 1 if result["fails"] else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
