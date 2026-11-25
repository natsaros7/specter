#!/usr/bin/env python3
"""Check the Tiers table of the autonomy profile. Python 3.8+, stdlib only.

Usage: python3 .specs/kit/scripts/tiers.py [--specs DIR] [--file PATH] [--range A...B] [--json] | --check [--specs DIR] [--file PATH]
       | --evidence [--specs DIR] [--file PATH] [--json] | --help
       default DIR = the .specs/ this script is installed in; default PATH = DIR/steering/autonomy.md

--check reads the working-tree profile and validates its `## Tiers` table: unique tier names, at least one `glob`
code span per Paths cell, Reviewer standard|deep, Human none|spot|required and never decreasing down the table, the
last row `required`, no <placeholder> left in. It also fails when a tier above the last lists a guarded path (the
profile itself, the installed kit, Knowledge targets, agent files): guarded paths always take the last row.
Exit 0: valid, or no profile / no Tiers section (not configured: the human tier applies, as in 0.5.0).
Exit 1: a guarded path sits in a tier above the last. Exit 2: bad profile or argument, with `file:line`.

Without --check it labels a change and prints a `### Risk tier` block (--json: the same as JSON). The change is the
staged files (base = merge-base of HEAD and merged_ref, read from spec-kit.json as committed at HEAD, so the branch's
own commits count; no merged_ref, refs/remotes/origin/HEAD or merge base: every file takes the last row) or --range A...B / A..B
(base = merge-base A B, head B); the block names the base. merged_ref must name exactly one branch or remote-tracking
ref (`refs/remotes/origin/main`, or a short name that is not also a tag or another ref): a tag or an ambiguous name is
refused (staged: the last row; label: spot; --evidence: exit 2). A --range end is HEAD, a full commit id or such a ref; a
tag, an ambiguous name or an expression (`main~1`) is exit 2. The binding check passes full shas. The profile is read at the base, never the working tree.
Paths and globs are repo-root-relative, even when .specs/ sits in a subfolder, and compared under one key (NFKC and a
full case fold), the way APFS and NTFS open them. Each file takes the lowest row a glob matches (none: the last row;
guarded: the last row) and the change takes its strictest file's tier. Renames count under both paths. Staged mode is
a preflight; the binding label is --range after the commit, run from a trusted copy of the kit.
Exit 0, or 2 on a bad argument, profile or spec-kit.json.
Guardrails: an optional `## Guardrails` table `| Guardrail | Enforced by | Verified |` records what the platform is
declared to enforce (specter never checks it). A row is declared when Enforced by names something (no <placeholder>,
and not a word that names nothing: - — – ? tbd todo n/a na none pending, in any case, a trailing `.` ignored) and
Verified is a YYYY-MM-DD date that is not in the future. A tier whose Human is `none` is reported as `spot` ("none → spot") while the section is
absent or empty or any row is undeclared; --check prints one line per row (undeclared rows keep exit 0), a bad header is exit 2.
Human `none` also needs the lowest row (the first of the Tiers table) and, in the label (not --check), `eligible` from
--evidence below for that tier; otherwise the label says `spot` and `- human: none → spot (<why>)` names it (--json: `reasons`).
The label counts history with the Evidence thresholds of the profile at the base (never the working tree), and with no
merged_ref or refs/remotes/origin/HEAD (the history would be HEAD, the change itself) it says `spot` (`evidence: no
merged_ref …`), and so it does when that history holds any commit of the change (`evidence: <ref> contains the change`).
A --range label keeps `none` only when its base is the merged_ref tip that --evidence reads (full shas compared): a base
behind it says `base <sha7> is behind <ref>: update the branch`. Staged mode is a preflight and keeps its base.
A refusing evidence run is `spot` too. So is a change over the size cap of the tier's Evidence row (optional trailing columns
`Max files`, `Max lines` and `Max bytes`, defaults 3, 50 and 4000 changed bytes, `-` is the default; a Git LFS pointer line changed is over the cap; a bad value is exit 2 in --evidence, `spot` in the label) or one that deletes or edits a line of a test file
(globs of an optional `## Tests` section, default: test directories, `*_test.*`, `*.test.*`, `test_*`, spec files, conftest.py): `size <f> files / <l> lines > cap <F>/<L>`,
`tests changed, not only added: <path>` (also a deleted test file, a mode or type change on one, an added or changed conftest.py or __init__.py); a binary file or a gitlink counts as over the cap; both read at the base. `labels_only` is false: a `none` merge is the platform's auto-merge, never specter's.
No profile or Tiers section at the base: the human tier (the last row's strictness: deep reviewer, human required).

--evidence prints, per tier of the Tiers table at the merged_ref tip (never the working tree; it prints that commit), `eligible`, `hold (<why>)` or `breach (<metric>)` from the
`## Evidence` table `| Tier | Window (days) | Min merged | Max reverted % | Max escaped % | Max human-caught % |`
(a Max of `-` is not checked; a row that keeps a <placeholder> is `hold (thresholds not set)`). It reads the first-parent
commits on merged_ref (as the label's staged mode finds it) inside each tier's window, by position: from the tip down to
the oldest commit dated inside the window, whatever the dates above it (a future date sets no window; a shallow clone
holds every tier with a row; an unreadable change set is exit 2), labels each with the profile as of
its first parent (a parent with no profile or Tiers, and the root commit, are `unprofiled`: left out and counted), and
counts it for a tier only when that profile's rows from the tier down to the last (name and Paths globs) and its guarded
globs equal those of the profile read now (Reviewer and Human are not compared); the others are `- relabelled: <n>`
(--json `relabelled`). It counts per tier: merged; reverted (a later commit whose change set, F^1..F, has a `This reverts commit <sha>` line naming
any commit of this one's change set); escaped (the same with `Fixes: <sha, 7 to 64 hex>`; `Fixes: #12` is ignored);
human-caught (its own `Human-Findings: <n>` lines: the max, and a value that is not plain digits counts as caught), as a
share of the merges that carry one, a `0` on a `none` merge included (ready.py --auto-merge refuses a PR whose text or commits carry the trailer, so it is a human's).
With a Max human-caught set, fewer such merges than max(Min merged, 1) is a hold, except for a tier whose Human is `none`. It never edits the profile.
Under a `breach` it prints `  demote: <file>:<line> Human <cur> → <one step stricter> (a human edit; tiers.py changes nothing)` for that tier's
row (none → spot, spot → required; `required` says already required); --json: per tier `demote` {file, line, from, to} or null.
Exit 0 whenever it printed a report; 2 on a bad profile, argument or ref, with `file:line` for a bad row.
"""
import datetime
import fnmatch
import contextlib
import io
import json
import os
import posixpath
import re
import subprocess
import sys
import time
from pathlib import Path

sys.dont_write_bytecode = True  # an installed kit must stay free of __pycache__ (guarded path)
sys.path.insert(0, str(Path(__file__).resolve().parent))
import gates  # noqa: E402
import spec_lint  # noqa: E402

# refs/replace, .git/info/grafts and a forged .git/objects/info/commit-graph can swap any commit body, rewrite the chain or
# the profile blob, turning a breach into eligible; children (git) inherit these. The graft path never exists (a file
# under /dev/null). core.commitGraph=false goes in through GIT_CONFIG_COUNT, appended to any inherited entries, once.
os.environ["GIT_NO_REPLACE_OBJECTS"] = "1"
os.environ["GIT_GRAFT_FILE"] = os.devnull + "/none"
# shortcut: git < 2.31 ignores GIT_CONFIG_COUNT; refuse older git if a job can run one
_n = int(os.environ.get("GIT_CONFIG_COUNT") or 0)
if os.environ.get(f"GIT_CONFIG_KEY_{_n - 1}") != "core.commitGraph" or os.environ.get(f"GIT_CONFIG_VALUE_{_n - 1}") != "false":
    os.environ[f"GIT_CONFIG_KEY_{_n}"] = "core.commitGraph"  # appended last, so it wins; not twice when both modules import
    os.environ[f"GIT_CONFIG_VALUE_{_n}"] = "false"
    os.environ["GIT_CONFIG_COUNT"] = str(_n + 1)

HEAD = ["Tier", "Paths", "Reviewer", "Human"]
GHEAD = ["Guardrail", "Enforced by", "Verified"]
REVIEWER = ("standard", "deep")
HUMAN = ("none", "spot", "required")
EMPTY = ("-", "—", "–", "?", "tbd", "todo", "n/a", "na", "none", "pending")  # Enforced by words that name nothing
# The installer writes these; install.py is not copied into projects, so they are listed here.
# Matched under key() (macOS and Windows checkouts fold case and Unicode) against repo-root-relative paths.
# shortcut: kept by hand; selftest 13b fails when install.AGENTS gains a skills folder not covered, add it here then;
# new agent-instruction file conventions outside install.AGENTS (rules files, MCP config) are added here too.
# AGENTS*.md and CLAUDE*.md take AGENTS.override.md (Codex) and CLAUDE.local.md (Claude Code) at any depth.
GUARDED = [".specs/steering/*", ".specs/spec-kit.json", ".specs/kit/*", ".specs/README.md", "AGENTS*.md", "CLAUDE*.md",
           "GEMINI*.md", "*/AGENTS*.md", "*/CLAUDE*.md", "*/GEMINI*.md", ".github/copilot-instructions.md",
           ".github/instructions/*", ".github/prompts/*", ".github/agents/*", ".github/skills/*", "*/.github/*instructions*",
           ".claude/*", "*/.claude/*", ".codex/*", ".cursor/*", "*/.cursor/*", ".gemini/*", ".agents/*", ".agent/*",
           ".clinerules", ".clinerules/*", ".windsurfrules", ".cursorrules", ".mcp.json", "CODEOWNERS", ".github/CODEOWNERS",
           "docs/CODEOWNERS"]
EHEAD = ["Tier", "Window (days)", "Min merged", "Max reverted %", "Max escaped %", "Max human-caught %"]
SIZE = ["Max files", "Max lines", "Max bytes"]  # optional trailing columns of Evidence: the size cap of Human none (defaults 3, 50, 4000)
# Default `## Tests` globs: wide on purpose, an unknown layout (pkg/tests/, __tests__/, *.spec.ts, spec/) counts as tests.
TESTS = ["tests/*", "*/tests/*", "test/*", "*/test/*", "__tests__/*", "*/__tests__/*", "spec/*", "*/spec/*", "*_test.*",
         "*.test.*", "*_spec.*", "*.spec.*", "test_*", "*/test_*", "conftest.py", "*/conftest.py"]  # fnmatch: * crosses /
PLACEHOLDER = re.compile(r"<[^<>`]*>")


def section(text, name, raw=False):
    """[(lineno, line)] under `## name` up to the next `## `, or None when the heading is absent. Unless `raw`, HTML
    comments (blanked, newlines kept) and fenced code (``` or ~~~, fences included) are not read: an example is no section.
    An unclosed `<!--` hides the rest, as a renderer does. shortcut: a fence closes on any fence line, a marker mismatch needs a CommonMark parser."""
    if not raw:
        text = re.sub(r"<!--.*?(?:-->|\Z)", lambda m: "\n" * m.group().count("\n"), text, flags=re.S)
    out, inside, fenced = None, False, False
    for n, line in enumerate(text.splitlines(), 1):
        if not raw and line.lstrip().startswith(("```", "~~~")):
            fenced = not fenced
        elif fenced:
            continue
        elif line.startswith("## "):
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


def parse_guardrails(text):
    """[(guardrail, enforced_by, verified, lineno, why)] or None when there is no Guardrails section. why is None for
    a declared row (Enforced by filled, no <placeholder>, Verified a real YYYY-MM-DD date), else the reason it is not.
    Placeholders are the undeclared state, not an error; raises ValueError((lineno, message)) on a bad header or row."""
    lines = section(text, "Guardrails")
    if lines is None:
        return None
    rows, head = [], None
    for n, line in lines:
        if not line.lstrip().startswith("|"):
            continue
        cells = gates.split_row(line)
        if head is None:
            head = [c.lower() for c in cells]
            if head != [h.lower() for h in GHEAD]:
                raise ValueError((n, "header must be | " + " | ".join(GHEAD) + " |"))
            continue
        if set("".join(cells)) <= set("-: "):
            continue
        if len(cells) != 3:
            raise ValueError((n, "row needs 3 cells, found " + str(len(cells))))
        name, by, ver = cells
        try:
            dated = re.fullmatch(r"[0-9]{4}-[0-9]{2}-[0-9]{2}", ver) and datetime.date.fromisoformat(ver)
        except ValueError:
            dated = None
        word = by.strip().rstrip(".").strip().lower()
        why = ("no Enforced by" if not word or word in EMPTY else "placeholder in Enforced by" if PLACEHOLDER.search(by)
               else "Verified is not a YYYY-MM-DD date" if not dated else "Verified is in the future" if dated > datetime.date.today() else None)
        rows.append((name, by, ver, n, why))
    return rows


def parse_evidence(text, tiers):
    """{tier: (window, min_merged, [max reverted, escaped, human-caught, files, lines, bytes; None for -], lineno)} or None when there is no
    Evidence section; a row that keeps a <placeholder> maps to None (thresholds not set, a hold, not an error).
    Raises ValueError((lineno, message)) on a bad header, a bad cell, an unknown or duplicate tier."""
    lines = section(text, "Evidence")
    if lines is None:
        return None
    rows, head = {}, None
    for n, line in lines:
        if not line.lstrip().startswith("|"):
            continue
        cells = gates.split_row(line)
        if head is None:
            head = [c.lower() for c in cells]
            if head not in [[h.lower() for h in EHEAD + SIZE[:k]] for k in (0, 2, 3)]:  # Max bytes is the optional third
                raise ValueError((n, "header must be | " + " | ".join(EHEAD) + " | (then optionally " + " | ".join(SIZE) + " |)"))
            continue
        if set("".join(cells)) <= set("-: "):
            continue
        if len(cells) != len(head):
            raise ValueError((n, "row needs " + str(len(head)) + " cells, found " + str(len(cells))))
        if cells[0] not in tiers:
            raise ValueError((n, "unknown tier '" + cells[0] + "' (not in the Tiers table)"))
        if cells[0] in rows:
            raise ValueError((n, "duplicate tier '" + cells[0] + "'"))
        if PLACEHOLDER.search(line):
            rows[cells[0]] = None
            continue
        win, low, *caps = cells[1:]
        caps += ["-"] * (len(EHEAD + SIZE) - len(cells))  # no size columns: the defaults
        if not (re.fullmatch(r"[0-9]+", win) and int(win) > 0):
            raise ValueError((n, "Window (days) must be a whole number above 0, found " + win))
        if not re.fullmatch(r"[0-9]+", low):
            raise ValueError((n, "Min merged must be a whole number, found " + low))
        for i, c in enumerate(caps):
            if i < 3 and c != "-" and not (re.fullmatch(r"[0-9]+(\.[0-9]+)?", c) and float(c) <= 100):
                raise ValueError((n, EHEAD[3 + i] + " must be 0 to 100 or -, found " + c))
            if i >= 3 and c != "-" and not re.fullmatch(r"[0-9]{1,9}", c):
                raise ValueError((n, SIZE[i - 3] + " must be a whole number or -, found " + c))
        rows[cells[0]] = (int(win), int(low), [None if c == "-" else float(c) for c in caps], n)
    return rows


def guarded_globs(text, rel):
    """GUARDED, the profile itself (rel, its path from the repo root, which also resolves relative links; --file can put it
    outside GUARDED) and the in-repo link targets of the Knowledge table (a folder becomes folder/*)."""
    out = list(GUARDED) + [rel]
    for _, line in section(text, "Knowledge", raw=True) or []:
        for target in re.findall(r"\]\(([^)\s]+)\)", line):
            target = target.split("#")[0]
            path = posixpath.normpath(posixpath.join(posixpath.dirname(rel), target)) if target else ""
            if not path or ":" in target or path.startswith(("..", "/")):
                continue
            out.append(path + "/*" if target.endswith("/") else path)
    return out


def row_keys(rows, guarded):
    """One evidence key per row index: (name, sorted globs) of that row and every stricter row below it, and the sorted
    guarded globs. classify() tries the strictest row first, so these decide which files the row's tier gets."""
    g = tuple(sorted(guarded))
    return [(tuple((r[0], tuple(sorted(r[1]))) for r in rows[i:]), g) for i in range(len(rows))]


key = spec_lint.fold  # one fold for paths, globs and ref names (see spec_lint.fold)


def hit(path, globs):
    """First glob matching path under key(): a path must not escape its row through a folding checkout."""
    k = key(path)
    return next((g for g in globs if fnmatch.fnmatchcase(path, g) or fnmatch.fnmatchcase(k, key(g))), None)


def profile_at(root, base, rel):
    """The profile's text as of commit `base`, or None when it does not exist there (never the working tree).
    Raises ValueError(message) when the bytes are not UTF-8."""
    run = subprocess.run(["git", "-C", str(root), "show", base + ":./" + rel], capture_output=True)
    if run.returncode:
        return None
    try:
        return run.stdout.decode("utf-8")
    except UnicodeDecodeError:
        raise ValueError(rel + " at " + base[:7] + ": not UTF-8")


USAGE = "usage: tiers.py [--specs DIR] [--file PATH] [--range A...B] [--json] | --check | --evidence [--json] | --help"


def refuse(msg):
    print("tiers: " + msg, file=sys.stderr)
    return 2


def git(root, *args):
    run = subprocess.run(["git", "-C", str(root)] + list(args), capture_output=True, text=True)
    return run.stdout.strip() if run.returncode == 0 else None


def gitz(root, *args):
    """NUL-split stdout of a git command, or None on failure; never parses quoted paths."""
    run = subprocess.run(["git", "-C", str(root)] + list(args), capture_output=True)
    return [x.decode("utf-8", "surrogateescape") for x in run.stdout.split(b"\0") if x] if run.returncode == 0 else None


def committed_ref(root, specs, head):
    """(ref, why): merged_ref as spec-kit.json is committed at head (next to the profile's .specs/ folder `specs`, default
    root/.specs), resolved by spec_lint.merged_ref to a full branch or remote-tracking ref name (or HEAD); ref None when
    nothing resolves, why the reason a tag or ambiguous name was refused. Raises ValueError on a bad spec-kit.json."""
    cfg = (Path(specs).name if specs else ".specs") + "/spec-kit.json"
    try:
        # As committed at HEAD: a work-tree edit must not move the base. An edit the branch committed is in the
        # diff from any older merge base, and spec-kit.json is guarded.
        # shortcut: a committed merged_ref naming the branch itself makes HEAD the base and hides its commits;
        # only --range binds, upgrade if staged labels ever gate a merge.
        conf = json.loads(profile_at(root, "HEAD", cfg) or "{}") if head else {}
        want = conf.get("merged_ref") if isinstance(conf, dict) else 0
        if not (want is None or isinstance(want, str)):
            raise ValueError("merged_ref must be a ref name or null")
        return spec_lint.merged_ref(root, {"merged_ref": want})
    except (ValueError, OSError, subprocess.SubprocessError) as err:
        raise ValueError("cannot read " + cfg + " at HEAD: " + str(err))


def end_commit(root, end):
    """The commit a --range end names, or None: HEAD, a full object id, or exactly one branch or remote-tracking ref
    (spec_lint.branch_ref). Raises ValueError for a tag, an ambiguous name, a short sha or anything else (`main~1`): git
    would resolve a tag `origin/main` before the remote, and a short sha goes through the same ref lookup (a loose tag
    `C282714` shadows `c282714` on a case-insensitive disk), moving the base or the head."""
    name = end
    full = re.fullmatch(r"[0-9a-f]{40}|[0-9a-f]{64}", end)
    if end != "HEAD" and not full:
        name, why = spec_lint.branch_ref(root, end)
        if why:
            raise ValueError("--range end " + why)
        if not name:
            raise ValueError("--range end " + end + " is not a branch, a remote-tracking ref, HEAD or a full commit id")
    sha = git(root, "rev-parse", "--verify", "-q", (name or end) + "^{commit}")
    if full and sha and sha != end:  # a 64-hex ref in a SHA-1 repo, or a tag id that peels
        raise ValueError("--range end " + end + " is not a full commit id of this repository")
    return sha


def classify(root, rel, rng, specs=None, where=None):
    """Label the staged change or the range. Returns {base, head, files, tier, reviewer, human, set_by, counts, guardrails, why, note, globs, key}
    (why is None when a profile was read; guardrails is then {rows, undeclared, downgraded} (else None) and human is
    `spot` when the tier's Human is `none` and the Guardrails section is absent, empty or has an undeclared row; note names the base and how it was found) or raises ValueError(message).
    ready.py reuses it. Files and Tiers globs are repo-root-relative, whatever folder .specs/ sits in; specs (default
    root/.specs) is the folder whose spec-kit.json, as committed at HEAD, names merged_ref. key is the tier's row_keys()
    entry (evidence compares it). where: (top-level, prefix) of
    root when the caller already has them (evidence calls this once per commit)."""
    top, prefix = where or (git(root, "rev-parse", "--show-toplevel"), git(root, "rev-parse", "--show-prefix") or "")
    closed = False
    if rng:
        a, _, b = rng.partition("...") if "..." in rng else rng.partition("..")
        a, head = end_commit(root, a), end_commit(root, b)
        base = git(root, "merge-base", a, head) if a and head else None
        files = gitz(top, "diff", "--no-renames", "--name-only", "-z", base, head) if base else None
        note = str(base)[:7] + " (merge base of " + rng + ")"
    else:
        head = git(root, "rev-parse", "--verify", "-q", "HEAD")
        ref, rwhy = committed_ref(root, specs, head)
        merge = git(root, "merge-base", "HEAD", ref) if ref and ref != "HEAD" and head else None
        # No merge base (or a merged_ref refused as a tag or ambiguous): fail closed, every file takes the last row.
        base, closed = merge or head, not merge
        note = merge[:7] + " (merge base with " + ref + ")" if merge else "HEAD (" + (rwhy or "no merge base") + ": last tier)"
        files = gitz(top, "diff", "--cached", "--no-renames", "--name-only", "-z", *([base] if base else []))
    if files is None:
        raise ValueError("cannot resolve " + (("--range " + rng) if rng else "the staged change") + " in " + str(root))
    text = profile_at(root, base, rel) if base else None
    try:
        rows = parse_tiers(text) if text else None
        gr = parse_guardrails(text) if rows else None
    except ValueError as err:
        raise ValueError(rel + " at " + str(base)[:7] + ":" + str(err.args[0][0]) + ": " + err.args[0][1])
    short = (base or "HEAD")[:7]
    if rows is None:
        # Not configured: the human tier, as in 0.5.0.
        rows = [("human", ["*"], "deep", "required", 0)]
        text, why = "", ("no autonomy profile at " if not text else "no Tiers section in profile at ") + short
    else:
        why = None
    guarded = guarded_globs(text, rel)
    keys = row_keys(rows, guarded)
    guarded += [prefix + g for g in guarded] if prefix else []
    last, counts, top = len(rows) - 1, {}, (-1, None, None)
    for f in files:
        g0 = hit(f, guarded)
        idx, glob = (last, g0) if g0 or closed else next(
            ((k, g) for k, r in reversed(list(enumerate(rows))) for g in [hit(f, r[1])] if g), (last, None))
        counts[rows[idx][0]] = counts.get(rows[idx][0], 0) + 1
        top = max(top, (idx, f, glob), key=lambda t: t[0])
    idx = top[0] if files else last
    tier, _, reviewer, human, _ = rows[idx]
    guard, no_low = None, False
    if why is None:
        undeclared = sum(1 for r in gr or [] if r[4])
        down = human == "none" and (not gr or undeclared > 0)
        guard = {"rows": len(gr or []), "undeclared": undeclared, "downgraded": down}
        human = "spot" if down else human
        # none is for the lowest row only; a higher row that says none is read as spot
        no_low = human == "none" and idx != 0
        human = "spot" if no_low else human
    return {"base": base, "head": head, "files": files, "tier": tier, "reviewer": reviewer, "human": human, "why": why, "note": note, "guardrails": guard,
            "reasons": ["not the lowest tier"] if why is None and no_low else [],
            "globs": rows[idx][1], "key": keys[idx], "set_by": {"file": top[1], "glob": top[2]} if files else None,
            "counts": {r[0]: counts[r[0]] for r in rows if r[0] in counts}}


def earned(root, rel, specs, profile, tier, base, head, staged=False):
    """None when `tier` is eligible in the Evidence report, else why not; a refusing report is a why too (fails closed).
    Thresholds are the profile's text at `base`, the text classify() read, never the working tree. With no merged_ref the
    history would be HEAD, the change itself: refused, as staged mode refuses it. So is a history that holds any commit
    of the change (base..head), whatever its name: a merged_ref or origin/HEAD at the PR branch, or one that merged it.
    Unless staged (a preflight), an eligible tier also needs base to equal the merged_ref tip the report read."""
    text = profile_at(root, base, rel) if base and head else None
    if text is None:
        return "evidence: no profile at the base"
    try:
        ref, why = committed_ref(root, specs, git(root, "rev-parse", "--verify", "-q", "HEAD"))
    except ValueError as err:
        return "evidence: " + str(err)
    if why:
        return "evidence: " + why
    if ref in (None, "HEAD"):
        return "evidence: no merged_ref (set merged_ref or refs/remotes/origin/HEAD)"
    out, err = io.StringIO(), io.StringIO()
    with contextlib.redirect_stdout(out), contextlib.redirect_stderr(err):
        rc = evidence(root, rel, specs, profile, True, text)
    if rc:
        return "evidence: " + (err.getvalue().strip().replace("tiers: ", "", 1) or "cannot be read")
    rep_ = json.loads(out.getvalue())
    mine = git(root, "rev-list", "--count", head, "^" + base)
    if mine is None or mine != git(root, "rev-list", "--count", head, "^" + base, "^" + rep_["head"]):
        return "evidence: " + ref + " contains the change"
    m = rep_["tiers"].get(tier) or {}
    if m.get("verdict") != "eligible":
        return "evidence: %s (%s)" % (m.get("verdict", "hold"), m.get("why") or "no report")
    return None if staged or base == rep_["head"] else "base %s is behind %s: update the branch" % (base[:7], ref)


def small(root, rel, tier, base, head, staged):
    """[why] when a change in Human none's tier is over the size cap or edits a test other than by adding lines, else [].
    One `git diff --numstat`, one `--raw` and one `-U0` patch (the index against base when staged). Cap: Max files / Max lines / Max
    bytes of the tier's Evidence row at base (3, 50 and 4000 when absent or -); bytes are those of the + and - lines of the hunks, and a
    changed Git LFS pointer line (version or oid) is over the cap whatever its size; tests: the `## Tests` globs at base (TESTS). A
    binary file, a gitlink or a diff that cannot be read counts as over the cap.
    A profile that cannot be read says so: none is never kept on a guess."""
    try:
        text = profile_at(root, base, rel) or ""
        rows = parse_tiers(text)
        row = (parse_evidence(text, [r[0] for r in rows or []]) or {}).get(tier)
    except ValueError as err:
        return ["size: " + (err.args[0][1] if isinstance(err.args[0], tuple) else str(err))]
    mf, ml, mb = ((row[2][3:6] if row else []) + [None] * 3)[:3]
    mf, ml, mb = (int(v if v is not None else d) for v, d in ((mf, 3), (ml, 50), (mb, 4000)))
    globs = [g for _, ln in section(text, "Tests") or [] for g in re.findall(r"`([^`]+)`", ln)] or TESTS
    top, spec = git(root, "rev-parse", "--show-toplevel"), (["--cached", base] if staged else [base, head])
    quiet = ("--no-renames", "--no-ext-diff", "--no-textconv")  # no configured driver runs on the change
    out, raw = (gitz(top, "diff", f, "-z", *quiet, *spec) for f in ("--numstat", "--raw"))
    run = subprocess.run(["git", "-C", str(top), "diff", "-U0", "--no-color", *quiet, *spec], capture_output=True)
    if out is None or raw is None or run.returncode:
        return ["size: cannot read the diff"]
    # Walk the patch as bytes: a line counts only inside a hunk, so an added `++ x` is content, not a `+++` header.
    # shortcut: the whole patch is held in memory, upgrade when a none tier takes diffs of hundreds of MB.
    nbytes, lfs, at, hunk = 0, None, -1, False
    for ln in run.stdout.split(b"\n"):
        if ln.startswith(b"diff --git "):
            at, hunk = at + 1, False
        elif ln.startswith(b"@@"):
            hunk = True
        elif hunk and ln[:1] in (b"+", b"-"):
            nbytes += len(ln)  # marker stands in for the newline
            if lfs is None and re.match(rb"[+-](version https://git-lfs\.github\.com/spec/|oid sha256:[0-9a-f]{64}$)", ln):
                lfs = at
    ent = [e.split("\t", 2) for e in out]
    meta = [(m.split(), p) for m, p in zip(raw[::2], raw[1::2])]  # ":<old mode> <new mode> <old sha> <new sha> <status>", path
    lines = sum(int(a) + int(d) for a, d, _ in ent if a != "-")
    binary = any(a == "-" for a, _, _ in ent) or any("160000" in (m[0][1:], m[1]) for m, _ in meta)
    why = []
    if at + 1 != len(ent):
        return ["size: cannot read the diff"]
    if len(ent) > mf or lines > ml or binary:
        why.append("size %d files / %d%s lines > cap %d/%d" % (len(ent), lines, "+" if binary else "", mf, ml))
    if nbytes > mb:
        why.append("bytes %d > cap %d" % (nbytes, mb))
    if lfs is not None:
        why.append("LFS pointer: " + ent[lfs][2])
    # numstat misses a deleted empty file, a mode change and an added skip line; `__init__.py` and conftest.py change what runs
    changed = next((p for a, d, p in ent if hit(p, globs) and d != "0"), None) or next((p for m, p in meta if (
        hit(p, globs) and (m[4][0] in "DT" or m[4][0] == "M" and m[0][1:] != m[1])) or key(posixpath.basename(p)) in ("conftest.py", "__init__.py")), None)
    return why + (["tests changed, not only added: " + changed] if changed else [])


AUTONOMY = {"required": "the human check before merge",
            "spot": "approve on the readiness verdict, the ### Gates block and the tests; read the flagged files in full",
            "none": "no human before merge; the merge is the platform's auto-merge on required checks, never a specter script's"}


def label(root, rel, rng, as_json, specs=None, profile=None):
    """Print the Risk tier block for the staged change or the range; return the exit code."""
    try:
        c = classify(root, rel, rng, specs)
        # Only a label that would still be none reads history; a profile with no Tiers section has no tier to count.
        if c["human"] == "none" and c["why"] is None:
            why = earned(root, rel, specs, profile or Path(specs) / "steering" / "autonomy.md", c["tier"], c["base"], c["head"], not rng)
            c["human"], c["reasons"] = ("spot", [why]) if why else ("none", c["reasons"])
        if c["human"] == "none" and c["why"] is None:
            more = small(root, rel, c["tier"], c["base"], c["head"], not rng)
            c["human"], c["reasons"] = ("spot", more) if more else ("none", c["reasons"])
    except ValueError as err:
        return refuse(str(err))
    base, files, tier, reviewer, human, why, set_by, ordered, guard = (c[k] for k in (
        "base", "files", "tier", "reviewer", "human", "why", "set_by", "counts", "guardrails"))
    short = (base or "HEAD")[:7]
    if as_json:
        print(json.dumps({"tier": tier, "reviewer": reviewer, "human": human, "set_by": set_by, "counts": ordered,
                          "guardrails": guard, "reasons": c["reasons"], "profile_commit": base if why is None else None, "labels_only": False}))
        return 0
    print("### Risk tier")
    print("- tier: " + tier + " (reviewer: " + reviewer + ", human: " + human + ")")
    if set_by:
        print("- set by: " + set_by["file"] + (" (`" + set_by["glob"] + "`)" if set_by["glob"] else " (no glob matched)"))
    print("- files: " + str(len(files)) + (" (" + ", ".join(k + " " + str(v) for k, v in ordered.items()) + ")" if files else ""))
    print("- base: " + c["note"])
    print("- profile: " + (why or rel + " at " + short))
    if guard:
        n, m = guard["rows"], guard["undeclared"]
        print("- guardrails: " + ("no Guardrails section" if not n else str(m) + " of " + str(n) + " undeclared" if m else str(n) + " declared")
              + (", none → spot" if guard["downgraded"] else ""))
    if c["reasons"]:
        print("- human: none → spot (" + "; ".join(c["reasons"]) + ")")
    print("- autonomy: human " + human + ": " + AUTONOMY[human])
    return 0


def findings(body):
    """(carries, caught) for the Human-Findings: lines of a commit body: carries when there is one; caught when a value is
    not exactly ASCII digits (a note, junk: fails closed) or any value is above 0. Takes the max over lines, never the first."""
    vals = [v.strip() for v in re.findall(r"^Human-Findings:(.*)$", body.replace("\r\n", "\n").replace("\r", "\n"), re.M | re.I)]
    return bool(vals), any(not re.fullmatch(r"[0-9]+", v) or v.strip("0") for v in vals)


def evidence(root, rel, specs, profile, as_json, text=None):
    """Print the Evidence report for the profile at the merged_ref tip (or `text`, the profile as of the label's base);
    return the exit code. Never reads the working tree, never writes anything."""
    try:
        ref, why = committed_ref(root, specs, git(root, "rev-parse", "--verify", "-q", "HEAD"))
    except ValueError as err:
        return refuse(str(err))
    if why:
        return refuse(why)
    head = git(root, "rev-parse", "--verify", "-q", ref + "^{commit}") if ref else None
    if not head:
        return refuse("no merged_ref, refs/remotes/origin/HEAD or HEAD resolves in " + str(root))
    src = str(profile)  # the label passes the base's text; otherwise the thresholds are the merged_ref tip's, never the working tree
    if text is None:
        src = rel + " at " + head[:7]
        try:
            text = profile_at(root, head, rel)
        except ValueError as err:
            return refuse(str(err))
        if text is None:
            return refuse("no " + rel + " at " + ref + " " + head[:7] + ": nothing to count")
    try:
        tiers = parse_tiers(text)
        names = [r[0] for r in tiers or []]
        ev = parse_evidence(text, names)
    except ValueError as err:
        return refuse(src + ":" + str(err.args[0][0]) + ": " + err.args[0][1])
    if tiers is None:
        return refuse("no Tiers section in " + src + ": nothing to count")
    now = time.time()
    longest = max([r[0] for r in (ev or {}).values() if r] or [90])
    # commits below the depth, and their reverts, are missing; only an explicit "false" counts as full (git < 2.15 echoes the flag)
    shallow = git(root, "rev-parse", "--is-shallow-repository") != "false"
    # The whole first-parent chain, never --since: git stops at the first old-dated commit, which would hide the rest.
    run = subprocess.run(["git", "-C", str(root), "log", "--first-parent", "-z", "--format=%H%x00%P%x00%ct%x00%B", head], capture_output=True)
    toks = run.stdout.decode("utf-8", "replace").split("\0")
    toks = toks[:-1] if toks and toks[-1] == "" else toks  # -z ends every record with a NUL; an empty body is a real token
    if run.returncode or len(toks) % 4:
        return refuse("cannot read the history of " + ref)
    recs = list(zip(*[iter(toks)] * 4))
    # Position, not date, says what is in a window and what is later: a tier's window runs from the tip down to the oldest
    # commit dated inside it, and every commit above that one counts whatever its own date, so a backdated commit (or a
    # fast-forward that kept its date) cannot leave the window. A future date never sets the cut.
    # shortcut: a recently dated commit deep in history widens the window down to it (merged history is protected by
    # guardrail row one); cap the window by count if that is ever abused.
    for r in recs:  # git prints an empty %ct for a date it cannot parse; fail closed before int()
        if not re.fullmatch(r"[0-9]+", r[2], re.A):
            return refuse("commit " + r[0][:7] + " has an unreadable committer date")
    cut = lambda win: max([i for i, r in enumerate(recs) if now - win * 86400 <= int(r[2]) <= now] or [-1])
    last = -1 if shallow else cut(longest)  # windows nest, so the longest one's cut is the max of the tier cuts
    # newest first: (tier or None, change-set shas, shas named by reverts, shas named by Fixes:, own body, position).
    # The change set of F is F^1..F: F itself for a squash or linear commit, every commit a merge brought in otherwise.
    ents, unprofiled = {}, 0
    where = (git(root, "rev-parse", "--show-toplevel"), git(root, "rev-parse", "--show-prefix") or "")
    todo, k = list(range(last + 1)), 0
    while k < len(todo):  # a commit enters the list at most once, so this ends
        i, k = todo[k], k + 1
        sha, parents, _, body = recs[i]
        parent = parents.split()[0] if parents else None
        try:
            c = classify(root, rel, parent + "..." + sha, specs, where) if parent else None
        except ValueError:
            c = None  # shortcut: a parent whose profile is unreadable counts as unprofiled; --check on that commit names the error
        unprofiled += not (c and c["why"] is None)
        cs = [(sha, body)]
        if parent:
            sub_ = subprocess.run(["git", "-C", str(root), "log", "-z", "--format=%H%x00%B", parent + ".." + sha], capture_output=True)
            t = sub_.stdout.decode("utf-8", "replace").split("\0")
            t = t[:-1] if t and t[-1] == "" else t
            if sub_.returncode or len(t) % 2 or not t:
                return refuse("cannot read the change set of " + sha[:7])  # never the body alone: a missed revert passes
            cs = list(zip(t[::2], t[1::2]))
        named = lambda pat: [x.lower() for _, b in cs for x in re.findall(pat, b, re.M | re.I)]
        ents[i] = (c["key"] if c and c["why"] is None else None, [h for h, _ in cs],
                   named(r"^This reverts commit ([0-9a-f]{7,64})\b"), named(r"^Fixes:[ \t]*([0-9a-f]{7,64})\b"), body, i)
        # a commit below the cut that a revert or Fixes: in the window names joins it alone, not the commits between
        todo += sorted({j for x in ents[i][2] + ents[i][3] for j in range(last + 1, len(recs)) if recs[j][0].startswith(x)} - set(todo[last + 1:]))
    log = [ents[i] for i in sorted(ents)]  # newest first
    inwin = len(log)
    # shortcut: names are matched against first-parent shas only; a branch commit of a merge below the cut stays out, extend to change sets if a merge's date can be forged

    def tier_log(win):  # the tier's own window, plus the commits below it that its entries name (the longest window bounds it)
        mine = [e for e in log if e[5] <= cut(win)]
        while True:
            more = [e for e in log if e not in mine and any(recs[e[5]][0].startswith(x) for m in mine for x in m[2] + m[3])]
            if not more:
                return [e for e in log if e in mine]
            mine += more
    # a commit counts for a tier only when its parent's profile had the same rows from that tier down to the last (name,
    # Paths globs) and guarded globs as the profile read now: a stricter row narrowed moves files into the lower tiers.
    # Reviewer and Human are not compared, so a promotion keeps its evidence.
    keys = row_keys(tiers, guarded_globs(text, rel))
    relabelled = sum(1 for e in log if e[0] and e[0] not in keys)
    out, rows_h = {}, {r[0]: r[3] for r in tiers}
    for name, k in zip(names, keys):
        row = (ev or {}).get(name)
        m = dict(verdict="hold", why="thresholds not set" if name in (ev or {}) else "no Evidence row",
                 window_days=None, merged=0, reverted=0, escaped=0, human_caught=0, with_trailer=0)
        out[name] = m
        if row is None:
            continue
        win, low, caps, _ = row
        if shallow:
            m["why"] = "shallow clone: fetch the full history"
            continue
        wlog = tier_log(win)
        mine = [(i, e) for i, e in enumerate(wlog) if e[0] == k]
        m.update(window_days=win, merged=len(mine))
        for i, (_, shas, _, _, body, _) in mine:
            later = wlog[:i]  # the log is newest first, so these came after this commit
            hit_ = lambda k: any(h.startswith(x) for e in later for x in e[k] for h in shas)
            m["reverted"] += hit_(2)
            m["escaped"] += hit_(3)
            carries, caught = findings(body)  # every value counts: ready.py --auto-merge refuses a PR that carries one
            m["human_caught"] += caught
            m["with_trailer"] += carries
        den = {"reverted": m["merged"], "escaped": m["merged"], "human_caught": m["with_trailer"]}
        pct = {k: m[k] * 100.0 / den[k] if den[k] else 0.0 for k in den}
        # a merge without the trailer is no data, never "no findings": the rate is over the merges that carry one
        why = ("merged " + str(m["merged"]) + " < min " + str(low)) if m["merged"] < max(low, 1) else \
              "Human-Findings on %d of %d merges" % (m["with_trailer"], m["merged"]) \
              if caps[2] is not None and m["with_trailer"] < max(low, 1) and rows_h[name] != "none" else None
        if why:
            m["why"] = why
            continue
        m["why"] = next(("%s %.1f%% > %g%%" % (k.replace("_", "-"), pct[k], cap) for k, cap in zip(pct, caps)
                         if cap is not None and pct[k] > cap), None)
        m["verdict"] = "breach" if m["why"] else "eligible"
    rows = {r[0]: r for r in tiers}  # Evidence rows name Tiers rows of the same profile (parse_evidence)
    for name, m in out.items():  # the demotion is a report: the human edits the row, tiers.py never does
        r, m["demote"] = rows[name], None
        if m["verdict"] == "breach":
            m["demote"] = {"file": rel, "line": r[4], "from": r[3],
                           "to": None if r[3] == "required" else HUMAN[HUMAN.index(r[3]) + 1]}
    if as_json:
        print(json.dumps({"ref": ref, "head": head, "unprofiled": unprofiled, "relabelled": relabelled, "tiers": out}))
        return 0
    print("### Evidence")
    print("- history: " + ref + " at " + head[:7] + ", first-parent, " + ("shallow clone, not read" if shallow else str(inwin) + " commit(s) in the longest window"))
    if ev is None:
        print("- no Evidence section in " + src)
    for name, m in out.items():
        pc = lambda k, d="merged": str(m[k]) + (" of %d" % m[d] if d != "merged" else "") + (" (%.1f%%)" % (m[k] * 100.0 / m[d]) if m[d] else "")
        print("- " + name + ": " + m["verdict"] + (" (" + m["why"] + ")" if m["why"] else "") + (
            " — merged %d, reverted %s, escaped %s, human-caught %s, %d days" % (m["merged"], pc("reverted"), pc("escaped"), pc("human_caught", "with_trailer"), m["window_days"])
            if m["window_days"] else ""))
        d = m["demote"]
        if d is not None:
            print("  demote: %s:%d Human %s" % (d["file"], d["line"], d["from"])
                  + (" → %s (a human edit; tiers.py changes nothing)" % d["to"] if d["to"] else ": already required"))
    print("- relabelled: " + str(relabelled) + " commit(s) whose tier, a stricter row or a guarded path changed in the window")
    print("- unprofiled: " + str(unprofiled) + " commit(s) left out")
    print("- profile: " + src + ", unchanged; promotion and demotion are a human edit of " + rel)
    # shortcut: one history log, then one classify and one change-set log per commit in the window (top-level and prefix read once); cache by commit when a window holds thousands of merges.
    return 0


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
    rng, as_json = None, "--json" in argv
    argv = [a for a in argv if a != "--json"]
    if "--range" in argv:
        i = argv.index("--range")
        if i + 1 >= len(argv) or not re.fullmatch(r"[^.\s][^\s]*?\.\.\.?[^.\s][^\s]*", argv[i + 1]):
            return refuse("--range needs A...B; " + USAGE)
        rng, argv = argv[i + 1], argv[:i] + argv[i + 2:]
    evid = "--evidence" in argv
    argv = [a for a in argv if a != "--evidence"]
    check = argv == ["--check"]
    if argv and not check or check and (rng or as_json) or evid and (check or rng):
        return refuse("unknown or conflicting argument(s) " + " ".join(argv + (["--json"] if as_json else []) + (["--range"] if rng else [])) + "; " + USAGE)
    profile = profile or specs / "steering" / "autonomy.md"
    if not check:
        try:
            rel = profile.relative_to(specs.parent).as_posix()
        except ValueError:
            return refuse(str(profile) + " is outside " + str(specs.parent) + "; " + USAGE)
        if evid:
            return evidence(specs.parent, rel, specs, profile, as_json)
        return label(specs.parent, rel, rng, as_json, specs, profile)
    try:
        text = profile.read_text(encoding="utf-8")
    except UnicodeDecodeError:
        return refuse(str(profile) + ": not UTF-8")
    except OSError:
        print("tiers: no " + str(profile) + ": not configured, every change takes the human tier")
        return 0
    try:
        rows = parse_tiers(text)
        gr = parse_guardrails(text)
    except ValueError as err:
        return refuse(str(profile) + ":" + str(err.args[0][0]) + ": " + err.args[0][1])
    if rows is None:
        print("tiers: no Tiers section in " + str(profile) + ": not configured, every change takes the human tier")
        return 0
    try:
        rel = profile.relative_to(specs.parent).as_posix()
    except ValueError:
        rel = ".specs/steering/autonomy.md"
    for _, _, _, n, why in gr or []:
        print("guardrail " + str(profile) + ":" + str(n) + ": " + ("declared" if not why else "undeclared (" + why + ")"))
    if gr is None:
        print("guardrail: no Guardrails section in " + str(profile))
    guarded = guarded_globs(text, rel)
    for tier, globs, _, _, n in rows[:-1]:
        for g in globs:
            if hit(g, guarded):
                print("FAIL " + str(profile) + ":" + str(n) + ": tier '" + tier + "' lists guarded path " + g + ", which always takes '" + rows[-1][0] + "'")
                return 1
    print("tiers: " + str(len(rows)) + " tier(s) ok in " + str(profile))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
