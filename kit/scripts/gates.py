#!/usr/bin/env python3
"""Run the project's gates in order and print a summary block for the PR description. Python 3.8+, stdlib only.

Usage: python3 .specs/kit/scripts/gates.py [--specs DIR] [--file PATH]
       default DIR = the .specs/ this script is installed in; default PATH = DIR/steering/spec-rules.md

Reads the first table whose header has a Gate and a Command column (a # column is optional and joins the label).
Each row's Command cell holds exactly one `code span`: that is the command, with \\| read as |. Commands run with
`sh -c` from the folder holding .specs/, in table order.
Exit 0: all green; stdout gets a `### Gates` block, one line per gate (its last output line) and `commit: <sha>[+dirty]`.
Exit 1: a gate failed; its output and `GATE FAILED: <gate> (exit N)` go to stderr and later gates don't run.
Exit 2: no file, no table, a row without exactly one code span, or a template placeholder (`<...>`) left in. Nothing
        runs: commands are never guessed.
"""
import re
import subprocess
import sys
from pathlib import Path


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
        cells = [c.strip().replace("\\|", "|") for c in re.split(r"(?<!\\)\|", line.strip().strip("|"))]
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


def commit(root):
    sha = subprocess.run(["git", "-C", str(root), "rev-parse", "--short", "HEAD"], capture_output=True, text=True)
    if sha.returncode:
        return "none"
    dirty = subprocess.run(["git", "-C", str(root), "status", "--porcelain"], capture_output=True, text=True).stdout.strip()
    return sha.stdout.strip() + ("+dirty" if dirty else "")


def refuse(msg):
    print("gates: " + msg + ". Nothing run", file=sys.stderr)
    return 2


def main(argv):
    specs = Path(__file__).resolve().parents[2]
    rules = None
    for flag in ("--specs", "--file"):
        if flag in argv:
            i = argv.index(flag)
            if i + 1 >= len(argv):
                return refuse("usage: gates.py [--specs DIR] [--file PATH]")
            value, argv = Path(argv[i + 1]).resolve(), argv[:i] + argv[i + 2:]
            specs, rules = (value, rules) if flag == "--specs" else (specs, value)
    rules = rules or specs / "steering" / "spec-rules.md"
    try:
        rows = gate_rows(rules.read_text())
    except OSError:
        return refuse("no " + str(rules))
    except ValueError as err:
        return refuse(str(rules) + ": " + str(err))
    if not rows:
        return refuse("no Gates table (| # | Gate | Command |) in " + str(rules) + "; add one, see .specs/kit/templates/steering/spec-rules.md")
    root, summary = specs.parent, []
    if not root.is_dir():
        return refuse("no project folder " + str(root))
    for label, cmd in rows:
        print(">> " + label + ": " + cmd, file=sys.stderr)
        run = subprocess.run(["sh", "-c", cmd], cwd=str(root), stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                             encoding="utf-8", errors="replace")
        if run.returncode:
            sys.stderr.write(run.stdout)
            print("GATE FAILED: " + label + " (exit " + str(run.returncode) + ")", file=sys.stderr)
            return 1
        last = [l for l in run.stdout.splitlines() if l.strip()]
        summary.append("- " + label + ": " + (last[-1].strip() if last else "exit 0"))
    print("### Gates\n" + "\n".join(summary) + "\n- commit: " + commit(root))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
