# Project profile

status: active

| Question | Answer |
|---|---|
| Layout | One repo. The kit is `kit/`; `install.sh` copies it into a project's `.specs/kit/`. |
| Stack | Markdown, POSIX sh, Python 3.8+ stdlib only. No dependencies, no network. |
| Gate | `tests/selftest.sh`, then both `spec_lint.py --specs .specs` runs (see the [router](../README.md)). |
| REQ prefix | Per feature, e.g. `REQ-V020-NN`. |
| Branching | Trunk + tags: short `feat/`/`fix/` branches merged `--no-ff` into `main`. A release closes a `CHANGELOG.md` section, bumps `VERSION`, and gets an annotated `vX.Y.Z` tag and a GitHub Release. |
| Cost | Free: no GitHub Actions, no paid APIs. |
