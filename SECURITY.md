# Security policy

## Supported versions

Only the latest release gets fixes. It is the newest tag and GitHub Release; `VERSION` names it.

## Reporting a vulnerability

Report privately: on GitHub, open **Security → Report a vulnerability** in this repository. Please don't open a
public issue for it. Expect a first reply within a week.

These count as a vulnerability:

- any way to reach `human: none` or `ready.py --auto-merge` exit 0 without the conditions in
  [`docs/reference.md`](docs/reference.md) (the lowest tier, declared guardrails, evidence `eligible` from merged
  history, a reviewer from another model family);
- a way to make `tiers.py --evidence` count history that isn't the protected merged history (tags, replace refs,
  case-folded or shadowing refs, the change itself);
- a citation the lint accepts although its file or line does not exist;
- anything the installer writes outside the target project, or a script that sends data off the machine.

A bug that only makes specter stricter than it should be (a `spot` that could have been `none`) is an ordinary issue.

## Past findings

The trust layer's earlier review findings are public in [`docs/reviews/`](docs/reviews/). Human `none` was never on
when they were written. From now on, a finding that bypasses the human check is filed as a draft advisory and
published after its fix ships.
