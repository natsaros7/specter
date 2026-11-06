#!/usr/bin/env python3
"""Script gate for the spec layer. Structural only: no AI and no network. Python 3.8+, stdlib only.

Usage: python3 .specs/kit/scripts/spec_lint.py [--specs DIR] [--json] [feature-dir-name ...]
       python3 .specs/kit/scripts/spec_lint.py [--specs DIR] [--json] --cites    check `path:line` citations only
       python3 .specs/kit/scripts/spec_lint.py --hash-term <word>               digest to add to denylist_sha256
       default DIR = the .specs/ this script is installed in; default features = all

--json prints one JSON object instead of text (same exit code): default mode {features, links, refs, drift, warnings, fails},
      --cites {count, problems}.

--cites resolves every citation in backticks against the project (the folder holding .specs/). Notations:
      `path:12`  `path:12-20`  `path:12-20,31,40-44`  `path#L12`  `path#L12-L20`  and `<repo>:path:12`, where <repo> is a
      key of cite_aliases (spec-kit.json: {"NS": "tools/load-sim"}) or the folder name of an indexed repo. Git repos are
      indexed up to two levels below the project. Elided paths (`.../web/Foo.java:12`) match by suffix; if several files
      match, those matching cite_ignore_globs are dropped. Every listed range is checked on its own.
      FAIL: no such file, ambiguous, unknown repo prefix, past EOF, or a blank cited range.

History: a feature whose Status is Done or Dropped reports its structural FAILs below as WARN `history: <message>` (exit code unaffected);
      broken links and citations still FAIL everywhere.

FAIL (exit 1): a feature is missing requirements/design/tasks.md; a feature folder name is not kebab-case;
      a feature defines no [REQ-..]; a defined REQ is absent from design.md or tasks.md; a REQ is
      referenced but defined neither in the feature nor in domains/*/requirements.md; a relative markdown link under .specs/ points to nothing.
      Opt-in, with file:line: when the decisions log (decisions.file, default steering/decisions.md) holds at least one
      decision row and decisions.enabled is not false, a cited D-<id> (standalone, with a digit)
      has no row, or a row's "Where it lands" names an undefined REQ (rows a later row supersedes are skipped); with
      decisions.backlinks true (or "warn": WARN), such a REQ's definition does not cite the decision; with denylist_sha256
      set, a token (dots kept; each run of dot segments; each adjacent pair joined by '-') hashes to a listed digest.
WARN: a REQ cited outside a feature's requirements/design/tasks.md is defined in no requirements.md (file:line);
      a task checkbox without a REQ; a required section (spec-kit.json) is missing; an upstream
      requirement id used in a feature is not in system/traceability.md; setup is still incomplete; an unresolved
      Drift Register row (any table with a Drift column; Logged optional) is older than drift_max_age_days (default 90, null = off),
      or, once per file, has open rows without a Logged date; a feature has no `Status:` line, an unknown status, or a status that
      disagrees with its tasks (all ticked but not Done, Done with unticked tasks, Done without a date); with tracker_pattern set,
      commits on merged_ref (else origin/HEAD, then HEAD; .specs-only commits ignored) name the feature's key while the spec says
      proposed or missing, or no task is ticked and it is not Done/Dropped.
"""
import datetime
import fnmatch
import hashlib
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
            "tracker_pattern": None, "merged_ref": None, "decisions": {}, "denylist_sha256": []}
STATUS = re.compile(r"^\s*>?\s*(?:\*\*Status:\*\*|\*\*Status\*\*:|Status:)\s*(.*)$", re.I)
STATES = (("proposed", "Proposed"), ("in progress", "In progress"), ("blocked on", "Blocked"), ("done", "Done"), ("dropped", "Dropped"))
MERGED = "merged work found"


def feature_status(text):
    """First non-empty Status field before the first '## ', outside fences: {"state", "date", "raw"}, or None.
    state is '' when the value is unknown."""
    for line in FENCE.sub("", text).splitlines():
        if line.startswith("## "):
            return None
        m = STATUS.match(line)
        if m and m.group(1).replace("**", "").strip():
            raw = m.group(1).replace("**", "").strip()
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
    deny, dec = config["denylist_sha256"], config["decisions"]
    if not isinstance(deny, list) or not all(isinstance(d, str) for d in deny):
        sys.exit("spec-kit.json: denylist_sha256 must be a list of hex digests, got " + json.dumps(deny))
    if not isinstance(dec, dict):
        sys.exit("spec-kit.json: decisions must be an object, got " + json.dumps(dec))
    dec = config["decisions"] = dict({"file": "steering/decisions.md", "backlinks": False, "enabled": True}, **dec)
    unknown = sorted(set(dec) - {"file", "backlinks", "enabled"})
    if unknown:
        sys.exit("spec-kit.json: decisions has unknown key(s) " + ", ".join(unknown) + " (known: file, backlinks, enabled)")
    if not isinstance(dec["file"], str):
        sys.exit("spec-kit.json: decisions.file must be a path string, got " + json.dumps(dec["file"]))
    if not (isinstance(dec["backlinks"], bool) or dec["backlinks"] == "warn"):
        sys.exit('spec-kit.json: decisions.backlinks must be false, "warn" or true, got ' + json.dumps(dec["backlinks"]))
    if not isinstance(dec["enabled"], bool):
        sys.exit("spec-kit.json: decisions.enabled must be true or false, got " + json.dumps(dec["enabled"]))
    return config


def task_blocks(text):
    """(checkbox line, whole item) per task: the checkbox plus the non-blank, non-heading lines indented deeper
    than it (tabs count as 4 spaces)."""
    blocks, lines = [], text.splitlines()
    for i, line in enumerate(lines):
        if not TASK.match(line):
            continue
        indent, block = len(line.expandtabs(4)) - len(line.lstrip()), [line]
        for nxt in lines[i + 1:]:
            if not nxt.strip() or re.match(r"#{1,6}(\s|$)", nxt.lstrip()) or len(nxt.expandtabs(4)) - len(nxt.lstrip()) <= indent:
                break
            block.append(nxt)
        blocks.append((line, "\n".join(block)))
    return blocks


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
        bare = [first.strip()[:70] for first, block in task_blocks(docs["tasks"]) if not req.search(block)]
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
        if not status["date"] or not re.search(r"\([^)]+\)", status["raw"]):
            warns.append("Done needs a date and a (branch, commit or PR) reference")
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




# a decision id stands alone (not inside REQ-D-01 or ADR-D-1, not a file name like D-1.md) and holds a digit, so prose
# such as D-DAY is not an id
DREF = re.compile(r"(?<![\w-])D-(?=[A-Z0-9-]*[0-9])[A-Z0-9]+(?:-[A-Z0-9]+)*(?![\w-]|\.\w)")
TOKEN = re.compile(r"[a-z0-9]+(?:\.[a-z0-9]+)*")


def unfenced(text):
    """text with fenced blocks blanked, line numbers kept."""
    return FENCE.sub(lambda m: "\n" * m.group().count("\n"), text)


def deny_hits(line, digests):
    """1-based numbers of the tokens in line that hit a digest: the token, any run of its dot segments (a host, an IP
    prefix), or the token joined to the next one with '-'."""
    toks, hits = TOKEN.findall(line.lower()), []
    for n, tok in enumerate(toks, 1):
        parts = tok.split(".")
        cands = {".".join(parts[i:j]) for i in range(len(parts)) for j in range(i + 1, len(parts) + 1)}
        if n < len(toks):
            cands.add(tok + "-" + toks[n])
        if any(hashlib.sha256(c.encode()).hexdigest() in digests for c in cands):
            hits.append(n)
    return hits


def decision_rows(lines):
    """(id, line no, Where it lands, Supersedes) per row whose first cell is a D- id, in tables with a Where it lands column."""
    rows, head = [], None
    for no, line in enumerate(lines, 1):
        if not line.lstrip().startswith("|"):
            head = None
            continue
        c = [x.strip() for x in re.split(r"(?<!\\)\|", line.strip().strip("|"))]
        if head is None:
            head = [x.lower() for x in c]
        elif "where it lands" in head and DREF.fullmatch(c[0]):
            cell = lambda name: c[head.index(name)] if name in head and head.index(name) < len(c) else ""
            rows.append((c[0], no, cell("where it lands"), cell("supersedes")))
    return rows


def req_block(lines, i, defined_re):
    """The definition of the REQ on line index i: its heading section (sub-headings included), or the line and the
    non-blank lines after it up to the next heading or definition."""
    level = len(re.match(r"#*", lines[i]).group())
    block = [lines[i]]
    for nxt in lines[i + 1:]:
        sub = re.match(r"(#+)\s", nxt)
        if (sub and (not level or len(sub.group(1)) <= level)) or (not level and (not nxt.strip() or defined_re.search(nxt))):
            break
        block.append(nxt)
    return "\n".join(block)


def refs(specs, config, req_defs):
    """Checks across files, each 'file:line: message': cited REQ and D- ids resolve, decision rows land on defined REQs
    that cite them back, no denylisted term. Returns (fails, warns)."""
    fails, warns = [], []
    req, dec = re.compile(config["req_id_pattern"]), config["decisions"]
    dec_path = specs / dec["file"]
    # on only when the file holds at least one decision row: a decisions.md in another format lints as before
    rows = (decision_rows(unfenced(dec_path.read_text()).splitlines()) or None) if dec["enabled"] and dec_path.is_file() else None
    ids = {r[0] for r in rows or ()}
    digests = {d.lower() for d in config["denylist_sha256"]}
    for md in sorted(specs.rglob("*.md")):
        rel = md.relative_to(specs)
        if rel.parts[0] == "kit":
            continue
        raw = md.read_text()
        # lint_feature already FAILs undefined REQs in these three
        own = len(rel.parts) == 3 and rel.parts[0] == "features" and rel.name in ("requirements.md", "design.md", "tasks.md")
        for no, line in enumerate(unfenced(raw).splitlines(), 1):
            at = rel.as_posix() + ":" + str(no) + ": "
            warns += [at + r + " is cited but defined in no requirements.md"
                      for r in dict.fromkeys(req.findall(line)) if not own and r not in req_defs]
            if rows is not None:
                fails += [at + d + " is cited but has no row in " + dec["file"] for d in dict.fromkeys(DREF.findall(line)) if d not in ids]
        if digests:
            fails += [rel.as_posix() + ":" + str(no) + ": denylisted term (token #" + str(n) + ")"
                      for no, line in enumerate(raw.splitlines(), 1) for n in deny_hits(line, digests)]
    superseded = {d for r in rows or () for d in DREF.findall(r[3])}
    defined_re = re.compile(r"\[(" + config["req_id_pattern"] + r")\]")
    for d, no, lands, _ in rows or ():
        if d in superseded:
            continue
        for r in dict.fromkeys(req.findall(lands)):
            if r not in req_defs:
                fails.append(dec["file"] + ":" + str(no) + ": " + d + " lands on " + r + ", which no requirements.md defines")
                continue
            path, line_no = req_defs[r]
            block = req_block((specs / path).read_text().splitlines(), line_no - 1, defined_re)
            if dec["backlinks"] and not re.search(r"(?<![\w-])" + re.escape(d) + r"(?![\w-])", block):
                (warns if dec["backlinks"] == "warn" else fails).append(
                    path + ":" + str(line_no) + ": " + r + " does not cite " + d + ", which lands on it")
    return fails, warns


def repos(root):
    """Child git repos up to two levels below root, no hidden parts. Linked worktrees (`.git` file with a `gitdir:` into
    `/worktrees/`) are skipped; submodules stay."""
    def worktree(p):
        try:
            return p.is_file() and bool(re.search(r"\.git/(modules/.+/)?worktrees/[^/]+\s*$",
                                                  p.read_text(errors="replace").replace("\\", "/")))
        except OSError:
            return True
    return sorted({p.parent.relative_to(root).as_posix() for pat in ("*/.git", "*/*/.git") for p in root.glob(pat)
                   if not worktree(p) and not any(part.startswith(".") for part in p.parent.relative_to(root).parts)})


def merged_commits(root, child_repos, config):
    """{repo label: [commit message, ...]}, one git log per repo, ignoring commits that touch only .specs/.
    Ref: merged_ref if set (a repo without it is skipped), else origin/HEAD, then HEAD. None when git is missing or times out."""
    out = {}
    for label, path in [(".", root)] + [(r, root / r) for r in child_repos]:
        if not (path / ".git").exists():
            continue
        git = lambda *a: subprocess.run(["git", "-C", str(path)] + list(a), capture_output=True, encoding="utf-8", errors="replace",
                                        timeout=60)
        try:
            ref = next((r for r in ([config["merged_ref"]] if config["merged_ref"] else ["origin/HEAD", "HEAD"])
                        if git("rev-parse", "--verify", "--quiet", r).returncode == 0), None)
            log = git("log", ref, "--format=%x00%s%n%b", "--", ".", ":(exclude).specs") if ref else None
        except (OSError, subprocess.TimeoutExpired):
            return None
        if log and log.returncode == 0:
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
    req_defs = {}
    for p in sorted(specs.glob("features/*/requirements.md")) + sorted(specs.glob("domains/*/requirements.md")):
        for no, line in enumerate(p.read_text().splitlines(), 1):
            for r in defined_re.findall(line):
                req_defs.setdefault(r, (p.relative_to(specs).as_posix(), no))
    warnings = []
    profile = specs / "steering" / "project-profile.md"
    if not profile.exists() or "status: setup-incomplete" in profile.read_text():
        warnings.append("WARN setup incomplete: run .specs/kit/playbooks/setup.md")
    features, commits, tracker = [], None, None
    if config["tracker_pattern"]:
        try:
            tracker = re.compile(config["tracker_pattern"], re.I)
        except re.error as err:
            warnings.append("WARN merged-work check skipped: invalid tracker_pattern (" + str(err) + ")")
    for feature in targets:
        if feature.is_dir():
            fails, warns = lint_feature(feature, config, traceability, domain_reqs)
            req_path = feature / "requirements.md"
            status = feature_status(req_path.read_text()) if req_path.exists() else None
            if status and status["state"] in ("Done", "Dropped"):
                fails, warns = [], ["history: " + f for f in fails] + warns
            keys = {m.group(0).upper() for m in tracker.finditer(feature.name) if m.group(0)} if tracker else set()
            if keys and (feature / "requirements.md").exists():
                if commits is None:
                    commits = merged_commits(specs.parent, repos(specs.parent), config)
                    if commits is None:
                        commits = {}
                        warnings.append("WARN merged-work check skipped: git not available or timed out")
                hit = re.compile("|".join("(?<![A-Za-z0-9])" + re.escape(k) + "(?![A-Za-z0-9])" for k in sorted(keys)))
                found = {r: sum(1 for m in msgs if hit.search(m.upper())) for r, msgs in commits.items()}
                found = {r: n for r, n in found.items() if n}
                status = feature_status((feature / "requirements.md").read_text())
                tasks = feature / "tasks.md"
                done, total = task_counts(tasks.read_text() if tasks.exists() else "")
                state = status["state"] if status else ""
                if found and (not status or state == "Proposed" or (not done and state not in ("Done", "Dropped"))):
                    says = status["state"] or status["raw"] if status else "no Status"
                    warns.append(MERGED + " (" + str(sum(found.values())) + " commit(s) in " + ", ".join(found) + ") but the spec says "
                                 + says + ", " + str(done) + "/" + str(total) + " tasks")
        else:
            fails, warns = ["no such feature directory"], []
        features.append({"name": feature.name, "ok": not fails, "fails": fails, "warns": warns})
    links = broken_links(specs)
    ref_fails, ref_warns = refs(specs, config, req_defs)
    warnings += ["WARN " + w for w in ref_warns]
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
    total = sum(len(f["fails"]) for f in features) + len(links) + len(ref_fails)
    return {"features": features, "links": links, "refs": ref_fails, "drift": drift, "warnings": warnings, "fails": total}


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
    if "--hash-term" in argv:
        words = argv[argv.index("--hash-term") + 1:][:1]
        toks = TOKEN.findall(words[0].lower()) if words else []
        if not 1 <= len(toks) <= 2:
            sys.exit("usage: --hash-term <term of one or two words>")
        print(hashlib.sha256("-".join(toks).encode()).hexdigest())
        return 0
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
    for ref in result["refs"]:
        print("FAIL " + ref)
    for w in drift_warns:
        print(w)
    print("spec-lint: " + str(result["fails"]) + " FAIL across " + str(len(result["features"])) + " feature(s)")
    return 1 if result["fails"] else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
