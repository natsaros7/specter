# Chores (optional)

A chore is a row in the Chores table of `.specs/steering/autonomy.md`. Run all rows with one command from the project root:

```sh
python3 .specs/kit/scripts/gates.py --file .specs/steering/autonomy.md
```

It runs the rows in order, stops at the first failure and exits 1. The first chore is spec health: the citation check
and the report page. It uses no model and no tokens. The regenerated `.specs/report.html` is the dashboard.

Chore rows are code: run only reviewed rows.

Specter schedules nothing and sends nothing anywhere. You give the command to a scheduler. When a run fails, the
scheduler's own failure mail or notification is the alert.

## On your machine

Do not point a scheduler at your working copy: an uncommitted chore row, written by an agent or smuggled in through a
prompt, would run unreviewed as you. Use a separate clean clone that only the scheduler touches (`git clone <url>
/path/to/chores-clone`). Pull before each run with `git pull --ff-only`, so only reviewed rows run.
This rule is row eight of the Guardrails table in `autonomy.md`: name your scheduler entry there and date it.

Cron, every weekday at 07:00 (use an absolute path):

```
0 7 * * 1-5 cd /path/to/chores-clone && git pull --ff-only && python3 .specs/kit/scripts/gates.py --file .specs/steering/autonomy.md
```

launchd on macOS runs one program, so use `/bin/sh -c` for the pull. Save as `~/Library/LaunchAgents/dev.specter.chores.plist`, then `launchctl load` it.

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key><string>dev.specter.chores</string>
  <key>WorkingDirectory</key><string>/path/to/chores-clone</string>
  <key>ProgramArguments</key>
  <array>
    <string>/bin/sh</string>
    <string>-c</string>
    <string>git pull --ff-only &amp;&amp; /usr/bin/python3 .specs/kit/scripts/gates.py --file .specs/steering/autonomy.md</string>
  </array>
  <key>StartCalendarInterval</key>
  <dict><key>Hour</key><integer>7</integer><key>Minute</key><integer>0</integer></dict>
</dict>
</plist>
```

## On a shared machine (CI)

GitHub Actions:

```yaml
on:
  schedule:
    - cron: "0 7 * * 1-5"
jobs:
  chores:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - run: python3 .specs/kit/scripts/gates.py --file .specs/steering/autonomy.md
```

GitLab CI (create the schedule under Build, Pipeline schedules):

```yaml
chores:
  rules:
    - if: $CI_PIPELINE_SOURCE == "schedule"
  script:
    - python3 .specs/kit/scripts/gates.py --file .specs/steering/autonomy.md
```

A scheduled job runs from the default branch, so a change to a chore row takes effect on the next run after the merge.

## A chore that writes files

A chore that changes tracked files works on its own branch. It reaches the default branch only through the normal
review. It never pushes to the default branch.
