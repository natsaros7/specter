# Playbook: refresh (re-ground the specs)

Run this periodically (each release, or when the specs feel stale) or after a large merge. **Run on:** the strongest model.

1. Read `.specs/steering/project-profile.md`. Note the commit the specs were last grounded on.
2. `git diff --stat <grounded-sha>..HEAD`. List the domains whose paths changed.
3. For each changed domain, re-verify `domains/<domain>/design.md` claims against code: interfaces, config keys,
   dependencies, schema. Re-read only what changed. Don't rescan untouched domains.
4. Look for new deployables or contracts (Phase 1 of `setup.md`, limited to the changed paths).
5. Fix spec statements that are now false. Where a fix needs a decision, add a Drift Register row and ask the user
   (same question rules as setup).
6. Update the profile: new grounded sha, date, and any new interview answers.
7. Run `spec_lint.py`. Go through its Status warnings and any "merged work found" ones: close the feature out
   (`sync.md`) or correct its status. Then report the docs changed, the drifts opened and resolved, and the open questions.
