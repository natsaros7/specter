# v061 Trust-layer hardening — Design

Not designed yet. Each task names the review finding it comes from; the finding's table row has the location, the
probe, the trigger and the proposed fix. Start from those:

| Requirement | Source rows |
|---|---|
| [REQ-V061-01] | slice 3 deep review advisories 6, 7, 9, 10; slice 3 confirmation review C1, C2, C3 |
| [REQ-V061-02] | slice 4 deep review advisories 5, 7, 9 |
| [REQ-V061-03] | slice 4 confirmation review C3, C4 |

Trust-layer code (`tiers.py`, `ready.py`, `gates.py`, the ref handling in `spec_lint.py`) goes red first, as in v060.
