# specter: its own specs

Specter's development specs, written with specter and linted by the copy of the kit in this repo (it is not installed into
itself):

```bash
python3 kit/scripts/spec_lint.py --specs .specs           # structure and traceability
python3 kit/scripts/spec_lint.py --specs .specs --cites   # citations
```

| For | Open |
|---|---|
| How specter is built, the gate and the release routine | [`steering/project-profile.md`](steering/project-profile.md) |
| 0.2.0: report page, citation notations, drift aging, JSON output | [`features/v020-report-and-citations/`](features/v020-report-and-citations/requirements.md) |
