#!/usr/bin/env python3
"""Run the project's gates in order and print a summary block for the PR description. Python 3.8+, stdlib only.

Usage: python3 .specs/kit/scripts/gates.py [--specs DIR] [--file PATH] | --help
       default DIR = the .specs/ this script is installed in; default PATH = DIR/steering/spec-rules.md

It executes, with `sh -c` from the project root, every command in that Gates table and nothing else: whoever can edit
the table decides what runs. Treat the table like code, and read it before running gates.py on a branch you didn't write.

Reads the first table whose header has a Gate and a Command column (a # column is optional and joins the label).
Each row's Command cell holds exactly one `code span`: that is the command, with \\| read as |. Commands run with
`sh -c` from the folder holding .specs/, in table order.
Exit 0: all green; stdout gets a `### Gates` block: one line per gate (`pass (<last output line>)`), then
        `tree changed during gates` when a gate changed git status or the diff against HEAD, then
        `commit: <sha>[+dirty]`, taken after the gates ran (`none` outside git), then `verdict: ready (N passed)`.
        ready.py refuses a block whose gates changed the tree: the commit is not what they checked. Stdin is closed.
Exit 1: a gate failed; later gates don't run. stdout gets the same block with `FAIL (exit N)` and `not run` rows and
        `verdict: not ready (F failed, R not run)`; the failing output and `GATE FAILED: <gate> (exit N)` go to stderr.
Exit 2: no file, no table, a row without exactly one code span, or a template placeholder (`<...>`) left in. Nothing
        runs: commands are never guessed.
"""
import re
import subprocess
import sys
from pathlib import Path


def split_row(line):
    """The cells of one table row, trimmed, with \\| read as |."""
    return [c.strip().replace("\\|", "|") for c in re.split(r"(?<!\\)\|", line.strip().strip("|"))]


def gate_rows(text):
    """[(label, command)] from the first Gate/Command table, or None when there is none. Raises ValueError on a row
    whose Command cell doesn't hold exactly one code span."""
    head, rows = None, []
    for line in text.splitlines():
        if not line.lstrip().startswith("|"):
            if rows:
                break
            head = None
            continue
        cells = split_row(line)
        if head is None:
            head = [c.lower() for c in cells]
            if not ("gate" in head and "command" in head):
                head = False
            continue
        if not head or set("".join(cells)) <= set("-: "):
            continue
        get = lambda name: cells[head.index(name)] if name in head and head.index(name) < len(cells) else ""
        label = " ".join(x for x in (get("#"), get("gate")) if x)
        spans = re.findall(r"`([^`]+)`", get("command"))
        if len(spans) != 1:
            raise ValueError("gate '" + label + "' needs exactly one `command` in its Command cell, found " + str(len(spans)))
        if re.fullmatch(r"<[^<>]*>", spans[0].strip()):
            raise ValueError("gate '" + label + "' still holds the template placeholder " + spans[0])
        rows.append((label, spans[0]))
    return rows or None


def tree(root):
    """git status plus the diff against HEAD: what a run must leave as it found.
    shortcut: an untracked file's content is not compared, only its name; add it if a gate edits untracked files."""
    run = lambda *a: subprocess.run(["git", "-C", str(root)] + list(a), capture_output=True).stdout
    return run("status", "--porcelain") + run("diff", "HEAD")


def commit(root):
    sha = subprocess.run(["git", "-C", str(root), "rev-parse", "--short", "HEAD"], capture_output=True, text=True)
    if sha.returncode:
        return "none"
    dirty = subprocess.run(["git", "-C", str(root), "status", "--porcelain"], capture_output=True, text=True).stdout.strip()
    return sha.stdout.strip() + ("+dirty" if dirty else "")


USAGE = "usage: gates.py [--specs DIR] [--file PATH] | --help"


def refuse(msg):
    print("gates: " + msg + ". Nothing run", file=sys.stderr)
    return 2


def main(argv):
    if "-h" in argv or "--help" in argv:
        print(__doc__.strip())
        return 0
    specs = Path(__file__).resolve().parents[2]
    rules = None
    for flag in ("--specs", "--file"):
        if flag in argv:
            i = argv.index(flag)
            if i + 1 >= len(argv):
                return refuse(USAGE)
            value, argv = Path(argv[i + 1]).resolve(), argv[:i] + argv[i + 2:]
            specs, rules = (value, rules) if flag == "--specs" else (specs, value)
    if argv:
        return refuse("unknown argument(s) " + " ".join(argv) + "; " + USAGE)
    rules = rules or specs / "steering" / "spec-rules.md"
    try:
        rows = gate_rows(rules.read_text())
    except OSError:
        return refuse("no " + str(rules))
    except ValueError as err:
        return refuse(str(rules) + ": " + str(err))
    if not rows:
        return refuse("no Gates table (| # | Gate | Command |) in " + str(rules) + "; add one, see .specs/kit/templates/steering/spec-rules.md")
    root, summary, failed = specs.parent, [], 0
    if not root.is_dir():
        return refuse("no project folder " + str(root))
    before = tree(root)
    for label, cmd in rows:
        if failed:
            summary.append("- " + label + ": not run")
            continue
        print(">> " + label + ": " + cmd, file=sys.stderr)
        # stdin closed: a gate that prompts fails instead of hanging. shortcut: no timeout, add one if a gate can hang
        run = subprocess.run(["sh", "-c", cmd], cwd=str(root), stdin=subprocess.DEVNULL, stdout=subprocess.PIPE,
                             stderr=subprocess.STDOUT, encoding="utf-8", errors="replace")
        if run.returncode:
            sys.stderr.write(run.stdout)
            print("GATE FAILED: " + label + " (exit " + str(run.returncode) + ")", file=sys.stderr)
            failed = run.returncode
            summary.append("- " + label + ": FAIL (exit " + str(failed) + ")")
            continue
        last = [l for l in run.stdout.splitlines() if l.strip()]
        summary.append("- " + label + ": pass (" + (last[-1].strip() if last else "exit 0") + ")")
    skipped = sum(l.endswith(": not run") for l in summary)  # a gate's output sits inside "pass (...)", so it can't end so
    verdict = "not ready (1 failed, %d not run)" % skipped if failed else "ready (%d passed)" % len(summary)
    changed = "\n- tree changed during gates" if tree(root) != before else ""
    print("### Gates\n" + "\n".join(summary) + changed + "\n- commit: " + commit(root) + "\n- verdict: " + verdict)
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
