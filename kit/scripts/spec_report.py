#!/usr/bin/env python3
"""One self-contained HTML page: feature progress, open drift, coverage, citation health. Python 3.8+, stdlib only.

Usage: python3 .specs/kit/scripts/spec_report.py [--specs DIR] [--out FILE]     default OUT = DIR/report.html
Reads through spec_lint.py (no checks of its own). Exit 0 once the page is written; the lint is the gate.
"""
import datetime
import os
import re
import sys
from html import escape as e
from pathlib import Path
from urllib.parse import quote

sys.path.insert(0, str(Path(__file__).resolve().parent))
import spec_lint  # noqa: E402

CSS = """
:root{--bg:#f6f7f9;--card:#fff;--fg:#1c2128;--mute:#667085;--line:#e4e7ec;--ok:#1a7f4b;--warn:#b54708;--bad:#c0262d;--bar:#2e6bd6}
@media(prefers-color-scheme:dark){:root{--bg:#0f1318;--card:#171c23;--fg:#e6e9ee;--mute:#98a2b3;--line:#2a313b;--ok:#4cc38a;--warn:#f0a35e;--bad:#f27278;--bar:#6b9bf2}}
*{box-sizing:border-box}body{margin:0;padding:2rem 1rem;background:var(--bg);color:var(--fg);font:15px/1.5 system-ui,sans-serif}
main{max-width:960px;margin:auto}h1{margin:0}h2{margin:0 0 .75rem;font-size:1.05rem}.mute{color:var(--mute);font-size:.85rem}
.row{display:grid;grid-template-columns:repeat(auto-fit,minmax(150px,1fr));gap:1rem;margin:1.25rem 0}
.card{background:var(--card);border:1px solid var(--line);border-radius:10px;padding:1rem 1.25rem;margin-bottom:1rem}
.row .card{margin:0}.num{font-size:1.9rem;font-weight:650}.ok{color:var(--ok)}.warn{color:var(--warn)}.bad{color:var(--bad)}
table{width:100%;border-collapse:collapse}th,td{text-align:left;padding:.4rem .5rem;border-bottom:1px solid var(--line);vertical-align:top}
th{color:var(--mute);font-weight:500;font-size:.8rem}tr:last-child td{border:0}tr.old td{background:color-mix(in srgb,var(--warn) 12%,transparent)}
.badge{margin-left:.4rem;padding:0 .4rem;border:1px solid var(--warn);border-radius:4px;font-size:.75rem;color:var(--warn)}
.bar{height:8px;min-width:90px;background:var(--line);border-radius:4px;overflow:hidden}.bar i{display:block;height:100%;background:var(--bar)}
a{color:var(--bar)}ul{margin:0;padding-left:1.2rem}code{font-size:.85em}
"""


def version(specs):
    for p in (specs / "kit" / "VERSION", Path(__file__).resolve().parents[2] / "VERSION"):
        if p.is_file():
            return p.read_text().strip()
    return "unknown"


def progress(specs, name):
    text = (specs / "features" / name / "tasks.md")
    lines = [l for l in text.read_text().splitlines() if spec_lint.TASK.match(l)] if text.exists() else []
    return sum(1 for l in lines if re.match(r"^\s*- \[[xX]\]", l)), len(lines)


def status(specs, name, done, total):
    req = specs / "features" / name / "requirements.md"
    text = req.read_text() if req.exists() else ""
    field = spec_lint.feature_status(text)
    if field and field["state"]:
        return field["state"]
    if re.search(r"^\s*>?\s*(\*\*)?Status:?(\*\*)?\s*\**Done\b", text, re.I | re.M) or (total and done == total):
        return "Done"
    lines = text.splitlines()
    head = lines[:next((i for i, l in enumerate(lines) if l.startswith("## ")), len(lines))]
    if any(re.search(r"(?<!not )(?<!no longer )\bBlocked on\b", l, re.I) for l in head) or any(l.lstrip().startswith("**Blocked on") for l in lines):
        return "Blocked"
    return "Not started" if not done else "In progress"


def table(head, rows, empty):
    if not rows:
        return '<p class="mute">' + e(empty) + "</p>"
    return "<table><tr>" + "".join("<th>" + e(h) + "</th>" for h in head) + "</tr>" + "".join(rows) + "</table>"


def build(specs, out):
    lint, cite, config = spec_lint.lint_all(specs), spec_lint.cites(specs), spec_lint.load_config(specs)
    limit = config.get("drift_max_age_days")
    rel = os.path.relpath(specs, out.parent)
    feats, stale = [], 0
    for f in lint["features"]:
        done, total = progress(specs, f["name"])
        st = status(specs, f["name"], done, total)
        link = quote(rel + "/features/" + f["name"] + "/requirements.md", safe="/")
        pct = round(100 * done / total) if total else 0
        cls = {"Done": "ok", "Blocked": "bad"}.get(st, "warn" if st == "In progress" else "mute")
        merged = any(w.startswith(spec_lint.MERGED) for w in f["warns"])
        stale += merged
        feats.append("<tr><td><a href=\"" + e(link) + "\">" + e(f["name"]) + "</a></td><td>" + str(done) + "/" + str(total)
                     + '</td><td><div class="bar"><i style="width:' + str(pct) + '%"></i></div></td><td class="' + cls + '">'
                     + st + ('<span class="badge">merged, not closed</span>' if merged else "") + "</td></tr>")
    rows = [r for r in lint["drift"] if not r["resolved"]]
    rows.sort(key=lambda r: -(r["age_days"] if r["age_days"] is not None else -1))
    old = lambda r: limit is not None and r["age_days"] is not None and r["age_days"] > limit
    drift = ['<tr class="' + ("old" if old(r) else "") + '"><td>' + e(r["id"]) + "</td><td>" + e(r["sev"]) + '</td><td title="' + e(r["text"], True) + '">'
             + e(r["text"][:120] + ("…" if len(r["text"]) > 120 else "")) + "</td><td>" + (str(r["age_days"]) if r["age_days"] is not None else "\u2014") + "</td><td>" + e(r["file"]) + "</td></tr>" for r in rows]
    resolved = sum(1 for r in lint["drift"] if r["resolved"])
    miss = "tasks.md does not trace "
    findings = [("FAIL ", f["name"] + ": " + t) for f in lint["features"] for t in f["fails"] if not t.startswith(miss)] + \
               [("FAIL ", "broken link: " + l) for l in lint["links"]] + \
               [("WARN ", f["name"] + ": " + t) for f in lint["features"] for t in f["warns"]] + \
               [("", w) for w in lint["warnings"]]
    uncovered = [f["name"] + ": " + t[len(miss):] for f in lint["features"] for t in f["fails"] if t.startswith(miss)]
    nbad = len(cite["problems"])
    counters = [("Features", len(feats), ""), ("Open drift", len(rows), "warn" if any(old(r) for r in rows) else ""),
                ("Lint FAIL", lint["fails"], "bad" if lint["fails"] else "ok"),
                ("Citation failures", nbad, "bad" if nbad else "ok")] + \
               ([("Merged, not closed", stale, "warn")] if stale else [])
    cards = "".join('<div class="card"><div class="num ' + c + '">' + str(n) + '</div><div class="mute">' + e(t) + "</div></div>"
                    for t, n, c in counters)
    li = lambda items: "<ul>" + "".join("<li>" + i + "</li>" for i in items) + "</ul>" if items else '<p class="mute">None.</p>'
    now = datetime.datetime.now().strftime("%Y-%m-%d %H:%M")
    return f"""<!doctype html>
<html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>{e(specs.parent.name)} specs report</title><style>{CSS}</style></head><body><main>
<h1>{e(specs.parent.name)}</h1>
<p class="mute">specter {e(version(specs))} &middot; generated {now}</p>
<div class="row">{cards}</div>
<section class="card"><h2>Features</h2>{table(["Feature", "Tasks", "Progress", "Status"], feats, "No features.")}</section>
<section class="card"><h2>Drift</h2>{table(["#", "Sev", "Drift", "Age (days)", "File"], drift, "No open drift rows.")}
<p class="mute">{resolved} resolved{"" if limit is None else ", highlighted: open over " + str(limit) + " days"}</p></section>
<section class="card"><h2>Coverage</h2><p class="mute">Requirements no task links</p>
{li([e(t) for t in uncovered])}<p class="mute">Lint findings</p>{li([e(k + t) for k, t in findings])}</section>
<section class="card"><h2>Citations</h2><p>{cite["count"]} total, <span class="{"bad" if nbad else "ok"}">{nbad} failing</span></p>
{li(["<code>" + e(p["file"] + ": " + p["cite"]) + "</code> " + e(p["reason"]) for p in cite["problems"]]) if nbad else ""}</section>
</main></body></html>
"""


def main(argv):
    specs = Path(__file__).resolve().parents[2]
    out = None
    for flag in ("--specs", "--out"):
        if flag in argv:
            i = argv.index(flag)
            value, argv = Path(argv[i + 1]).resolve(), argv[:i] + argv[i + 2:]
            specs, out = (value, out) if flag == "--specs" else (specs, value)
    if not specs.is_dir():
        print("spec-report: no such specs directory: " + str(specs), file=sys.stderr)
        return 2
    out = out or specs / "report.html"
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(build(specs, out), encoding="utf-8")
    print("spec-report: wrote " + str(out))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
