# Repos

The member repos this platform spec covers. The lint reads the first table with a `Repo` and a `Spec path` column:
`Repo` is the checkout's folder name, `Spec path` is relative to it (no `..`). Members are looked up under the
members root (`--members-root`, else `members_root` in `spec-kit.json`, else this repo's parent folder).

| Repo | Spec path | Owns |
|---|---|---|
| <repo> | .specs | <what this repo is the source of truth for> |
