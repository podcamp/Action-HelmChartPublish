# Commit Guidelines

Purpose

- Standardize commit messages for better history, changelogs, and automation (releases, changelog generation).
- All repositories use Release Please and manage versioning automatically.

# Commit and PR Formatting

Use Conventional Commits and validate with `@commitlint/config-conventional` (if locally installed).
The convention is validated with GitHub Actions on PRs and pushes to `master`.

Best practices

- Make small, focused commits. If a change spans multiple concerns, split it into separate commits.
- Use squash merges for all PRs into `master`.
- Always use signed commits if possible (GPG or SSH signing).

How to write commit messages for merges

- When merging feature branches, prefer a concise summary that indicates the final intent, or let release tooling
  generate notes from commit messages.

Custom notes for contributors

- If you're unsure about type or scope, mention it in the PR description; maintainers will help classify.
- For work in progress, you may use "WIP:" in the subject, but squash/reword to a clean commit message before merging.
- Avoid generic subjects like "update" or "changes".
- For breaking changes use `!` after the type/scope, e.g., `feat!: new API` or `fix(api)!: change response format`.
- When PR contains multiple commits, use the footer as:
    - *Important: The additional messages must be added to the bottom of the commit*.
      ```
        feat: adds v4 UUID to crypto
      
        This adds support for v4 UUIDs to the library.
      
        fix(utils)!: unicode no longer throws exception
        PiperOrigin-RevId: 345559154
        Source-Link: googleapis/googleapis@5e0dcb2
      
        feat(utils): update encode to support unicode
        PiperOrigin-RevId: 345559182
        Source-Link: googleapis/googleapis@e5eef86
      ```
