# Branching Guidelines (GitHub Flow)

Purpose

- Standardize branching and workflow for better collaboration, history, and release management.
- All repositories use Release Please and manage versioning automatically.

## Branching model

GitHub Flow

- `master` is the default and protected branch; it always reflects production-ready code.
- Create short-lived branches from `master` for any change.
    - Suggested prefixes: `feat/*`, `fix/*`, `docs/*`, `style/*`, `refactor/*`, `perf/*`, `test/*`, `build/*`, `ci/*`,
      `chore/*`, `revert/*`.
- Open a Pull Request (PR) from your branch into `master` as soon as possible (drafts encouraged).
- Merge via squash-merge after review and passing CI; delete the branch after merging.

## Typical workflow

- Create a topic branch from `master` for your change:
    - Name it by intent (e.g., `feat/auth`, `fix/api-400`, `docs/readme-quickstart`).
- Commit early and push regularly; keep the branch focused and short-lived.
- Open a PR into `master` (draft if still in progress) to run CI and gather feedback.
- Ensure PRs are reviewed and all checks pass.
- Use squash merge to keep a clean history on `master`. Delete the branch after merge.

## Urgent production fixes

- Create a `hotfix/*` branch from `master`.
- Implement the fix, open a PR into `master`, get review, and merge via squash.

## Best practices

- Make small, focused commits and PRs; split unrelated changes.
- Keep branches short-lived; rebase or merge `master` as needed to resolve conflicts.
- Use squash merges for all PRs into `master`.
- Do not annotate version tags on the branch; let Release-Please handle versioning.
