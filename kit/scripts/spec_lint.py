#!/usr/bin/env python3
"""Script gate for the spec layer. Structural only: no AI and no network. Python 3.8+, stdlib only.

Usage: python3 .specs/kit/scripts/spec_lint.py [--specs DIR] [--json] [feature-dir-name ...]
       python3 .specs/kit/scripts/spec_lint.py [--specs DIR] [--json] --cites    check `path:line` citations only
       python3 .specs/kit/scripts/spec_lint.py --members-root DIR   where a platform's member repos are checked out; --members (platform root, no --cites or names) lints it, then each member
       python3 .specs/kit/scripts/spec_lint.py --hash-term <word>               digest to add to denylist_sha256
       default DIR = the .specs/ this script is installed in; default features = all; exit 0 clean, 1 FAIL, 2 DIR not a directory

--json prints one JSON object instead of text (same exit code): default mode {features, links, refs, drift, warnings, fails},
      --cites {count, problems}.

--cites resolves every citation in backticks against the project (the folder holding .specs/). Notations:
      `path:12`  `path:12-20`  `path:12-20,31,40-44`  `path#L12`  `path#L12-L20`  and `<repo>:path:12`, where <repo> is a
      key of cite_aliases (spec-kit.json: {"NS": "tools/load-sim"}) or the folder name of an indexed repo. Git repos are
      indexed up to two levels below the project. Elided paths (`.../web/Foo.java:12`) match by suffix; if several files
      match, those matching cite_ignore_globs are dropped. Every listed range is checked on its own.
      FAIL: no such file, ambiguous, unknown repo prefix, past EOF, or a blank cited range.

Platform layer: spec-kit.json "layer" is "platform", "member" or null (default null; other values stop the lint) and
      "members_root" a path string (default: the project's parent). On "platform", system/repos.md must hold a table with a
      Repo and a Spec path column; a row whose repo is not a folder name, whose spec path is absolute or has a '..' part,
      or a repo listed twice, FAILs with file:line. Member lookup (members()) is <root>/<repo>/<spec path>, --members-root
      before members_root. A root without "layer": platform lints as before.
      On a platform root a feature's cited REQ id also resolves from the checked-out members' domains/*/ and features/*/
      requirements.md; an id the platform and a member, or two members, define FAILs as ambiguous; an id defined nowhere is a
      WARN naming the members not checked out, a FAIL when all are checked out. Brackets in a platform requirements.md still define.
      Task lines (every task of every feature on a platform root): `- [ ] N <repo>: <what> -> <repo>/.specs/features/<f>/ . after: N, N`
      with <repo> a registry repo or `platform:` (no child needed); the child is a feature of that repo (must exist when the
      member is checked out) or a PR (URL, #n, <repo>#n); after: names existing tasks, no cycle; numbers are unique.

History: a feature whose Status is Done or Dropped reports its structural FAILs below as WARN `history: <message>` (exit code unaffected);
      broken links and citations still FAIL everywhere.

FAIL (exit 1): a feature is missing requirements/design/tasks.md; a feature folder name is not kebab-case;
      a feature defines no [REQ-..]; a defined REQ is absent from design.md or tasks.md; a REQ is
      referenced but defined neither in the feature nor in domains/*/requirements.md; a relative markdown link under .specs/ points to nothing.
      Opt-in, with file:line: when the decisions log (decisions.file, default steering/decisions.md) holds at least one
      decision row and decisions.enabled is not false, a cited D-<id> (standalone, with a digit)
      has no row, or a row's "Where it lands" names an undefined REQ (rows a later row supersedes are skipped); with
      decisions.backlinks true (or "warn": WARN), such a REQ's definition does not cite the decision; with denylist_sha256
      set, a token (letters of any script and digits, NFC, lower-cased; dots kept; each run of dot segments; each adjacent
      pair joined by '-'; per line) hashes to a listed digest.
WARN: a REQ cited outside a feature's requirements/design/tasks.md and outside inline code is defined in no
      requirements.md (one line per id, up to 3 file:line; unresolved_req "off" silences it);
      a task checkbox without a REQ; a required section (spec-kit.json) is missing; an upstream
      requirement id used in a feature is not in system/traceability.md; setup is still incomplete; an unresolved
      Drift Register row (any table with a Drift column; Logged optional) is older than drift_max_age_days (default 90, null = off),
      or, once per file, has open rows without a Logged date; a feature has no `Status:` line, an unknown status, or a status that
      disagrees with its tasks (all ticked but not Done, Done with unticked tasks, Done without a date); with tracker_pattern set,
      commits on merged_ref (else refs/remotes/origin/HEAD, then HEAD; a tag or ambiguous name is skipped; .specs-only commits ignored) name the feature's key while the spec says
      proposed or missing, or no task is ticked and it is not Done/Dropped.
"""
import datetime
import fnmatch
import hashlib
import json
import os
import re
import subprocess
import sys
import unicodedata
from pathlib import Path

sys.dont_write_bytecode = True  # an installed kit must stay free of __pycache__ (guarded path)
sys.path.insert(0, str(Path(__file__).resolve().parent))
import gates  # noqa: E402

# Run standalone, this file's git calls (branch_ref, merged_commits) need the same protection as tiers.py's: refs/replace,
# .git/info/grafts and a forged .git/objects/info/commit-graph can rewrite the chain or a blob; children (git) inherit
# these. The graft path never exists (a file under /dev/null). core.commitGraph=false goes in through GIT_CONFIG_COUNT
# and GIT_CONFIG_PARAMETERS, appended to any inherited entries.
os.environ["GIT_NO_REPLACE_OBJECTS"] = "1"
os.environ["GIT_GRAFT_FILE"] = os.devnull + "/none"
# shortcut: git < 2.31 ignores GIT_CONFIG_COUNT; refuse older git if a job can run one
_n = int(os.environ.get("GIT_CONFIG_COUNT") or 0)
if os.environ.get(f"GIT_CONFIG_KEY_{_n - 1}") != "core.commitGraph" or os.environ.get(f"GIT_CONFIG_VALUE_{_n - 1}") != "false":
    os.environ[f"GIT_CONFIG_KEY_{_n}"] = "core.commitGraph"  # appended last, so it wins; not twice when both modules import
    os.environ[f"GIT_CONFIG_VALUE_{_n}"] = "false"
    os.environ["GIT_CONFIG_COUNT"] = str(_n + 1)
_p, _f = os.environ.get("GIT_CONFIG_PARAMETERS", ""), "'core.commitgraph'='false'"
if not (" " + _p).endswith(" " + _f):  # git reads these after GIT_CONFIG_COUNT, so an inherited 'true' here would win
    os.environ["GIT_CONFIG_PARAMETERS"] = (_p + " " if _p else "") + _f

TASK = re.compile(r"^\s*- \[[ xX]\] ")
KEBAB = re.compile(r"^[a-z0-9]+(-[a-z0-9]+)*$")
LINK = re.compile(r"\[[^\]]*\]\(([^)\s]+)\)")
FENCE = re.compile(r"^```.*?^```", re.M | re.S)
DATE = re.compile(r"\d{4}-\d{2}-\d{2}")
DEFAULTS = {"req_id_pattern": "REQ-[A-Z0-9]+-[0-9]+", "upstream_req_pattern": None, "required_sections": {},
            "cite_aliases": {}, "cite_ignore_globs": [], "drift_max_age_days": 90,
            "tracker_pattern": None, "merged_ref": None, "decisions": {}, "denylist_sha256": [], "unresolved_req": "warn",
            "layer": None, "members_root": None}
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
    if config["unresolved_req"] not in ("warn", "off"):
        sys.exit('spec-kit.json: unresolved_req must be "warn" or "off", got ' + json.dumps(config["unresolved_req"]))
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
    if config["layer"] not in ("platform", "member", None):
        sys.exit('spec-kit.json: layer must be "platform", "member" or null, got ' + json.dumps(config["layer"]))
    if config["members_root"] is not None and not isinstance(config["members_root"], str):
        sys.exit("spec-kit.json: members_root must be a path string, got " + json.dumps(config["members_root"]))
    return config


REPO = re.compile(r"^[A-Za-z0-9][A-Za-z0-9._-]*$")


def registry(specs):
    """The platform's repo registry: the first table of system/repos.md with a Repo and a Spec path column.
    Returns (rows, fails): rows are (repo, spec path, line) of the valid rows; each bad row (repo not a folder name,
    spec path absolute or with a '..' part, repo listed twice) is one FAIL 'system/repos.md:<line>: <why>'."""
    path, name = specs / "system" / "repos.md", "system/repos.md"
    cols, head, rows, fails, seen = None, None, [], [], {}
    for no, line in enumerate(unfenced(path.read_text()).splitlines() if path.is_file() else [], 1):
        if not line.lstrip().startswith("|"):
            if cols:
                break
            head = None
            continue
        cells = [c.strip().replace("`", "") for c in re.split(r"(?<!\\)\|", line.strip().strip("|"))]
        if head is None:
            head = [c.lower() for c in cells]
            if "repo" in head and "spec path" in head:
                cols = (head.index("repo"), head.index("spec path"))
        elif cols and not re.fullmatch(r"[\s|:-]+", line) and len(cells) > max(cols):
            repo, sub = cells[cols[0]], cells[cols[1]]
            why = ("repo '" + repo + "' is not a folder name" if not REPO.match(repo)
                   else "spec path '" + sub + "' must be relative, with no .. part" if not sub or sub.startswith("/") or ".." in sub.split("/")
                   else "repo '" + repo + "' is listed twice (first on line " + str(seen[repo]) + ")" if repo in seen else "")
            if why:
                fails.append(name + ":" + str(no) + ": " + why)
            else:
                seen[repo] = no
                rows.append((repo, sub, no))
    return rows, fails if cols else [name + ": no registry table (Repo, Spec path)"]


def members(specs, config, root=None):
    """(repo, spec dir or None when not checked out) per registry row. root: the --members-root argument, else
    members_root of spec-kit.json relative to the project, else the project's parent. The platform itself is dropped."""
    base = Path(root) if root else specs.parent / (config["members_root"] or "..")
    found = [(repo, (base / repo / sub).resolve()) for repo, sub, _ in registry(specs)[0]]
    return [(repo, d if d.is_dir() else None) for repo, d in found if d != specs.resolve()]


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


def platform_tasks(text, rows, members):
    """task-line FAILs of a platform feature (every task): '- [ ] N <repo>: <what> -> <child> · after: N, N' where <repo>
    is a registry repo or 'platform', the child (first token after the arrow, the item may wrap) is a feature
    '<repo>/<spec path>/features/<f>/' or a PR (URL, '#n', '<repo>#n'), and after: names existing tasks with no cycle.
    rows: registry rows; members: repo -> spec dir or None (not checked out; the child path is then not checked)."""
    fails, after, seen = [], {}, set()
    for line, block in task_blocks(text):
        m = re.match(r"\s*- \[[ xX]\] (\d+) (?:([\w.-]+): )?", line)
        if not m:
            fails.append("task line without a number: '" + line.strip()[:70] + "'")
            continue
        n, who, why = m.group(1), m.group(2), None
        if n in seen:
            fails.append("task " + n + ": number used twice")
        seen.add(n)
        ids = [int(i) for i in re.findall(r"\d+", (re.search(r"after:\s*(\d+(?:\s*,\s*\d+)*)", block) or [0, ""])[1])]
        after.setdefault(n, [str(i) for i in ids])
        if not who:
            why = "no repo (<repo>: or platform:)"
        elif who != "platform" and who not in {r[0] for r in rows}:
            why = "unknown repo '" + who + "' (not in system/repos.md)"
        elif who != "platform":
            arrow = re.search(r"(?:\u2192|->)\s*(\S+)", block)
            child = arrow.group(1).rstrip(".,;") if arrow else ""
            feat = re.match(r"([\w.-]+)/.+/features/([^/]+)/?$", child)
            pr = re.match(r"(?:https?://\S+|([\w.-]*)#\d+)$", child)
            if not child:
                why = "no child (\u2192 " + who + "/.specs/features/<f>/ or a PR)"
            elif not ((feat and feat.group(1) == who) or (pr and pr.group(1) in (None, "", who))):
                why = "child is not " + ("an " if who[0] in "aeiou" else "a ") + who + " feature or PR"
            elif feat and members.get(who) and not (members[who] / "features" / feat.group(2)).is_dir():
                why = "child " + child + " not found"
        if why:
            fails.append("task " + n + ": " + why)
    for n in sorted(after, key=int):
        fails += ["task " + n + ": after " + a + ": no such task" for a in after[n] if a not in after]
    done, path = set(), []

    def walk(n):  # first cycle only
        if n in path:
            return path[path.index(n):] + [n]
        if n in done or n not in after:
            return None
        path.append(n)
        for a in after[n]:
            cyc = walk(a)
            if cyc:
                return cyc
        path.pop()
        done.add(n)
    for n in sorted(after, key=int):
        cyc = walk(n)
        if cyc:
            fails.append("task " + cyc[0] + ": after: cycle " + " \u2192 ".join(cyc))
            break
    return fails


def lint_feature(feature, config, traceability, domain_reqs=frozenset(), member_ids=None, unchecked=(), platform=None):
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
    member_ids = member_ids or {}
    for r in sorted(referenced - defined):  # platform root: ids of checked-out members (v080 decisions 5-7)
        repos = sorted(member_ids.get(r, []) + (["platform"] if r in domain_reqs else []))
        if len(repos) > 1:
            fails.append(r + " is ambiguous: defined in " + ", ".join(repos))
    dangling = sorted(referenced - defined - domain_reqs - member_ids.keys())
    if dangling and unchecked:
        warns.append(", ".join(dangling) + " referenced but defined in no checked-out repo; not checked: " + ", ".join(unchecked))
    elif dangling:
        fails.append("referenced but never defined: " + ", ".join(dangling))
    if "tasks" in docs:
        bare = [first.strip()[:70] for first, block in task_blocks(docs["tasks"]) if not req.search(block)]
        if bare:
            warns.append(str(len(bare)) + " task(s) without a REQ link, e.g. '" + bare[0] + "'")
        if platform:  # (registry rows, members dict) on a platform root, v080 task 5
            fails += platform_tasks(docs["tasks"], *platform)
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
TOKEN = re.compile(r"[^\W_]+(?:\.[^\W_]+)*")  # letters (any script) and digits; dots kept inside


def tokens(text):
    return TOKEN.findall(unicodedata.normalize("NFC", text).lower())


def unfenced(text):
    """text with fenced blocks blanked, line numbers kept (FENCE.sub("", ...) elsewhere drops them: not the same)."""
    return FENCE.sub(lambda m: "\n" * m.group().count("\n"), text)


def deny_hits(line, digests):
    """1-based numbers of the tokens in line that hit a digest: the token, any run of its dot segments (a host, an IP
    prefix), or the token joined to the next one with '-'."""
    toks, hits = tokens(line), []
    for n, tok in enumerate(toks, 1):
        parts = tok.split(".")
        cands = {".".join(parts[i:j]) for i in range(len(parts)) for j in range(i + 1, len(parts) + 1)}
        if n < len(toks):
            cands.add(tok + "-" + toks[n])
        if any(hashlib.sha256(c.encode()).hexdigest() in digests for c in cands):
            hits.append(n)
    return hits


def decision_rows(lines):
    """(id, line no, Where it lands, Supersedes, Checked by or None without that column) per row whose first cell is a D- id, in tables with a Where it lands column."""
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
            rows.append((c[0], no, cell("where it lands"), cell("supersedes"), cell("checked by") if "checked by" in head else None))
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


def spec_docs(specs):
    """[(relative path, text)] of every .md under specs, outside kit/."""
    return [(md.relative_to(specs).as_posix(), md.read_text()) for md in sorted(specs.rglob("*.md"))
            if md.relative_to(specs).parts[0] != "kit"]


def cited_ids(docs, config, req_defs, rows):
    """Cited REQ ids defined nowhere (WARN, one per id) and, with a decisions log, cited D- ids without a row (FAIL)."""
    req, dec, ids = re.compile(config["req_id_pattern"]), config["decisions"], {r[0] for r in rows or ()}
    fails, missing = [], {}
    for rel, raw in docs:
        parts = rel.split("/")
        # lint_feature already FAILs undefined REQs in these three
        own = len(parts) == 3 and parts[0] == "features" and parts[2] in ("requirements.md", "design.md", "tasks.md")
        for no, line in enumerate(unfenced(raw).splitlines(), 1):
            at = rel + ":" + str(no)
            if not own and config["unresolved_req"] != "off":
                for r in dict.fromkeys(req.findall(re.sub(r"`[^`]*`", "", line))):  # an id in inline code is an example
                    if r not in req_defs:
                        missing.setdefault(r, []).append(at)
            if rows is not None:
                fails += [at + ": " + d + " is cited but has no row in " + dec["file"] for d in dict.fromkeys(DREF.findall(line)) if d not in ids]
    warns = [r + " is cited but defined in no requirements.md: " + ", ".join(locs[:3])
             + (" and " + str(len(locs) - 3) + " more" if len(locs) > 3 else "") for r, locs in missing.items()]
    return fails, warns


def denylisted(docs, digests):
    """A FAIL per denylisted token, fenced blocks included (a name in a code block leaks too). Never prints the term."""
    return [rel + ":" + str(no) + ": denylisted term (token #" + str(n) + ")"
            for rel, raw in docs for no, line in enumerate(raw.splitlines(), 1) for n in deny_hits(line, digests)]


def landings(specs, config, req_defs, rows):
    """Each REQ a live decision row lands on is defined (FAIL) and, with decisions.backlinks, cites it back."""
    req, dec, fails, warns = re.compile(config["req_id_pattern"]), config["decisions"], [], []
    superseded = {d for r in rows or () for d in DREF.findall(r[3])}
    defined_re = re.compile(r"\[(" + config["req_id_pattern"] + r")\]")
    gate_ids = None
    for d, no, lands, _, checked in rows or ():
        if d in superseded:
            continue
        for g in [x.strip() for x in (checked or "").split(",") if x.strip()]:
            if gate_ids is None:  # a label is "#", "Gate" or "# Gate"; no table or a bad one (gates.py reports it) leaves none
                try:
                    rules = specs / "steering" / "spec-rules.md"
                    gate_ids = {w for l, _ in (gates.gate_rows(rules.read_text()) or ()) for w in (l, l.split(" ", 1)[0], l.split(" ", 1)[-1])} if rules.is_file() else set()
                except ValueError:
                    gate_ids = set()
            if g not in gate_ids:
                fails.append(dec["file"] + ":" + str(no) + ": " + d + " is checked by " + g + ", which is no row of the Gates table in steering/spec-rules.md")
        for r in dict.fromkeys(req.findall(lands)):
            if r not in req_defs:
                fails.append(dec["file"] + ":" + str(no) + ": " + d + " lands on " + r + ", which no requirements.md defines")
                continue
            path, line_no = req_defs[r]
            block = req_block((specs / path).read_text().splitlines(), line_no - 1, defined_re)
            if dec["backlinks"] and not re.search(r"(?<![\w-])" + re.escape(d) + r"(?![\w-]|\.\w)", block):
                (warns if dec["backlinks"] == "warn" else fails).append(
                    path + ":" + str(line_no) + ": " + r + " does not cite " + d + ", which lands on it")
    return fails, warns


def refs(specs, config, req_defs, known=()):
    """Checks across files: cited ids, decision landings and back-links, denylisted terms. Returns (fails, warns)."""
    dec = config["decisions"]
    dec_path = specs / dec["file"]
    # on only when the file holds at least one decision row: a decisions.md in another format lints as before
    rows = (decision_rows(unfenced(dec_path.read_text()).splitlines()) or None) if dec["enabled"] and dec_path.is_file() else None
    docs = spec_docs(specs)
    id_fails, id_warns = cited_ids(docs, config, req_defs.keys() | set(known), rows)
    land_fails, land_warns = landings(specs, config, req_defs, rows)
    deny = {d.lower() for d in config["denylist_sha256"]}
    return id_fails + land_fails + (denylisted(docs, deny) if deny else []), id_warns + land_warns


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


def fold(s):
    """The one key paths, globs and ref names are compared under: NFKC, then a full case fold that also takes what APFS
    and NTFS fold (APFS opens AGENT\u017f.md as AGENTS.md, .\ufb06 as .st, NFD as NFC; NTFS upcases \u0131 to I, so
    ref ma\u0131n is main's twin).
    shortcut: the key folds more than APFS (NFKC) or a case-sensitive disk, so a file that matches no glob as spelled
    (Docs/x on Linux) can take a lower row's tier; tighten when a project runs files by exact case-variant names."""
    return unicodedata.normalize("NFKC", s).upper().casefold().replace("\u0307", "")


def branch_ref(path, name):
    """(full ref name, None) when `name` names exactly one branch or remote-tracking ref (a symref only to one), else
    (None, why), why None when no ref has that name. Git's own lookup takes refs/tags/<name> before refs/heads/ and
    refs/remotes/, so a pushed tag `origin/main` would stand in for the remote: a tag or an ambiguous name is refused.
    Raises OSError or subprocess.TimeoutExpired when git is missing or hangs."""
    cand = [name] if name.startswith("refs/") else [p + name for p in ("refs/", "refs/tags/", "refs/heads/", "refs/remotes/")] + ["refs/remotes/" + name + "/HEAD"]
    run = subprocess.run(["git", "-C", str(path), "for-each-ref", "--format=%(refname)%00%(symref)"], capture_output=True, text=True, timeout=60)
    found = dict(line.split("\0", 1) for line in run.stdout.splitlines() if "\0" in line) if run.returncode == 0 else {}
    hits = [c for c in cand if c in found]  # every ref is listed (no patterns): keep exact names only
    # shortcut: one listed spelling holding another branch's sha is invisible locally; the recipe's explicit refspec closes it, probe the server with ls-remote if a job must fetch the wildcard
    for r in hits[:1] + ([found[hits[0]]] if hits and found[hits[0]] else []):  # on a case-folding disk rev-parse opens the twin's file
        twin = next((n for n in found if n != r and fold(n) == fold(r)), None)
        who = name if r == hits[0] else "the target " + r
        if twin or r not in found:
            return None, who + (" differs only by case from " + twin if twin else " is not listed under its exact name")
    ok = lambda r: r.startswith(("refs/heads/", "refs/remotes/"))
    if len(hits) > 1:
        return None, name + " is ambiguous (" + ", ".join(hits) + ")"
    if hits and not (ok(hits[0]) and (not found[hits[0]] or ok(found[hits[0]]))):
        return None, name + " is " + ("a tag" if hits[0].startswith("refs/tags/") else "not a branch or remote-tracking ref") + " (" + hits[0] + ")"
    if hits and found[hits[0]].endswith("/HEAD"):  # a symref to another HEAD ref is no remote's default branch
        return None, name + " points at " + found[hits[0]] + ", another HEAD ref"
    # a pushed branch named HEAD lands as a plain refs/remotes/<remote>/HEAD: only a symref is the remote's default branch
    if hits and hits[0].startswith("refs/remotes/") and hits[0].endswith("/HEAD") and not found[hits[0]]:
        return None, name + " is not a symbolic ref (" + hits[0] + ": a branch named HEAD?)"
    return (hits[0] if hits else None), None


def merged_ref(path, config):
    """(ref, why): merged_ref if set, else refs/remotes/origin/HEAD, then HEAD; the first that resolves in the repo at path,
    as a full ref name (or HEAD), else None. why names a merged_ref or the origin/HEAD fallback that branch_ref refused, else None.
    Raises OSError or subprocess.TimeoutExpired when git is missing or hangs."""
    want = config["merged_ref"]
    if want and want != "HEAD":
        ref, why = branch_ref(path, want)
        return ref, ("merged_ref " + why if why else None)
    ref, why = (None, None) if want else branch_ref(path, "refs/remotes/origin/HEAD")
    if why:  # a refused fallback must not count HEAD, the change itself
        return None, why
    head = ref or subprocess.run(["git", "-C", str(path), "rev-parse", "--verify", "--quiet", "HEAD"], capture_output=True, timeout=60).returncode == 0
    return (ref or ("HEAD" if head else None)), None


def merged_commits(root, child_repos, config):
    """({repo label: [commit message, ...]}, [why a repo was skipped]), one git log per repo, ignoring commits that touch
    only .specs/. Ref: merged_ref if set (a repo without it is skipped; one where it names a tag or is ambiguous is skipped
    with a why), else refs/remotes/origin/HEAD, then HEAD. None when git is missing or times out."""
    out, skipped = {}, []
    for label, path in [(".", root)] + [(r, root / r) for r in child_repos]:
        if not (path / ".git").exists():
            continue
        git = lambda *a: subprocess.run(["git", "-C", str(path)] + list(a), capture_output=True, encoding="utf-8", errors="replace",
                                        timeout=60)
        try:
            ref, why = merged_ref(path, config)
            if why:
                skipped.append(label + ": " + why)
            log = git("log", ref, "--format=%x00%s%n%b", "--", ".", ":(exclude).specs") if ref else None
        except (OSError, subprocess.TimeoutExpired):
            return None
        if log and log.returncode == 0:
            out[label] = [m for m in log.stdout.split("\0") if m.strip()]
    return out, skipped


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


def lint_all(specs, names=(), members_root=None):
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
    member_ids, unchecked = {}, []
    if config["layer"] == "platform":
        for repo, d in members(specs, config, members_root):
            if d is None:
                unchecked.append(repo)
                continue
            for p in sorted(d.glob("domains/*/requirements.md")) + sorted(d.glob("features/*/requirements.md")):
                for i in defined_re.findall(p.read_text()):
                    member_ids.setdefault(i, [])
                    if repo not in member_ids[i]:
                        member_ids[i].append(repo)
    req_defs = {}
    for p in sorted(specs.glob("features/*/requirements.md")) + sorted(specs.glob("domains/*/requirements.md")):
        for no, line in enumerate(p.read_text().splitlines(), 1):
            for r in defined_re.findall(line):
                req_defs.setdefault(r, (p.relative_to(specs).as_posix(), no))
    platform = (registry(specs)[0], dict(members(specs, config, members_root))) if config["layer"] == "platform" else None
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
            fails, warns = lint_feature(feature, config, traceability, domain_reqs, member_ids, unchecked, platform)
            req_path = feature / "requirements.md"
            status = feature_status(req_path.read_text()) if req_path.exists() else None
            if status and status["state"] in ("Done", "Dropped"):
                fails, warns = [], ["history: " + f for f in fails] + warns
            keys = {m.group(0).upper() for m in tracker.finditer(feature.name) if m.group(0)} if tracker else set()
            if keys and (feature / "requirements.md").exists():
                if commits is None:
                    got = merged_commits(specs.parent, repos(specs.parent), config)
                    if got is None:
                        commits = {}
                        warnings.append("WARN merged-work check skipped: git not available or timed out")
                    else:
                        commits = got[0]
                        warnings.extend("WARN merged-work check skipped in " + w for w in got[1])
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
    ref_fails, ref_warns = refs(specs, config, req_defs, member_ids)
    warnings += ["WARN " + w for w in ref_warns]
    if config["layer"] == "platform":
        ref_fails += registry(specs)[1]
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


def lint_members(specs, config, root, as_json):
    """--members: the platform, then each checked-out member under its own spec-kit.json. A member that is itself a
    platform root is linted as a plain root, no recursion."""
    base = Path(root) if root else specs.parent / (config["members_root"] or "..")
    top = lint_all(specs, members_root=root)
    found = members(specs, config, root)
    results = {repo: lint_all(d) if d else None for repo, d in found}
    unchecked = [repo for repo, d in found if d is None]
    fails = top["fails"] + sum(r["fails"] for r in results.values() if r)
    if as_json:
        json.dump({"platform": top, "members": results, "unchecked": unchecked}, sys.stdout)
    else:
        print("== platform")
        print_text(top)
        for repo, result in results.items():
            print("== " + repo)
            if result is None:
                # shortcut: a missing checkout WARNs and exits as before (CI may check out one repo), --strict-members when a pipeline must fail on it
                print("WARN member " + repo + ": no checkout at " + str(base / repo))
            else:
                print_text(result)
        print("spec-lint --members: " + str(fails) + " FAIL across " + str(len(results) + 1) + " repo(s)"
              + ("; " + str(len(unchecked)) + " not checked: " + ", ".join(unchecked) if unchecked else ""))
    return 1 if fails else 0


def print_text(result):
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


def main(argv):
    specs = given = Path(__file__).resolve().parents[2]
    if "--specs" in argv:
        i = argv.index("--specs")
        given, argv = argv[i + 1], argv[:i] + argv[i + 2:]
        specs = Path(given).resolve()
    members_root = None
    if "--members-root" in argv:
        i = argv.index("--members-root")
        members_root, argv = argv[i + 1], argv[:i] + argv[i + 2:]
    if "--hash-term" in argv:
        toks = tokens(" ".join(a for a in argv[argv.index("--hash-term") + 1:] if not a.startswith("--")))
        if not 1 <= len(toks) <= 2:
            sys.exit("usage: --hash-term <term of one or two words>")
        print(hashlib.sha256("-".join(toks).encode()).hexdigest())
        return 0
    if not specs.is_dir():  # a moved or misspelled path must not pass as "0 FAIL"
        print("spec-lint: " + str(given) + ": not a directory", file=sys.stderr)
        return 2
    as_json = "--json" in argv
    if "--cites" in argv:
        if "--members" in argv:
            print("spec-lint: --members does not combine with --cites", file=sys.stderr)
            return 2
        result = cites(specs)
        if as_json:
            json.dump(result, sys.stdout)
        else:
            for p in result["problems"]:
                print("FAIL cite " + p["file"] + ": `" + p["cite"] + "` " + p["reason"])
            print("spec-lint --cites: " + str(len(result["problems"])) + " FAIL of " + str(result["count"]) + " citation(s)")
        return 1 if result["problems"] else 0
    names = [a for a in argv if not a.startswith("--")]
    if "--members" in argv:
        config = load_config(specs)
        if config["layer"] != "platform" or names:
            print("spec-lint: --members needs a platform root (\"layer\": \"platform\") and no feature names", file=sys.stderr)
            return 2
        return lint_members(specs, config, members_root, as_json)
    result = lint_all(specs, names, members_root)
    if as_json:
        json.dump(result, sys.stdout)
        return 1 if result["fails"] else 0
    print_text(result)
    print("spec-lint: " + str(result["fails"]) + " FAIL across " + str(len(result["features"])) + " feature(s)")
    return 1 if result["fails"] else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
