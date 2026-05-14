# Contributing

Thanks for taking the time to contribute! This repository is a template; keep changes minimal, generic, and
well-documented.

## Quick start

- Requirements: Node.js LTS, npm, Git
- Setup (installs dev tools and Husky hooks):
    - Windows/PowerShell 7+
    - Run:
      ```powershell
      npm install
      ```
- Verify commit tooling:
  ```powershell
  npx commitlint --version
  ```

## Branching strategy

- See `.github/instructions/branching.instructions.md` for details.
- Branch naming (GitHub Flow):
    - `master` is the default and protected branch; it always reflects production-ready code.
    - Use short-lived branches from `master`: `chore/*`, `ci/*`, `docs/*`, `feat/*`, `fix/*`, `hotfix/*`, `perf/*`,
      `refactor/*`, `revert/*`, `style/*`, `test/*`.
    - Open a PR into `master` early (drafts encouraged); merge via squash after review and passing CI.
    - Releases are tagged directly on `master` (e.g., `v1.2.3`).

## Commit messages

- This repo enforces Conventional Commits via commitlint and a Husky commit-msg hook.
- See `.github/instructions/commit.instructions.md` for the full guide.
- Examples:
    - feat: add authentication middleware
    - fix(api): handle 400 on invalid payload
    - docs: update README with setup steps

If your commit is rejected, adjust the message and commit again. The hook runs automatically during git commit.

## Pull Requests

- New PRs are pre-filled using `.github/pull_request_template.md`. Please complete all sections and check the checklist.
- Keep PRs focused and small when possible. Link issues using keywords (e.g., closes #123).
- Follow the repo’s conventions (layout, naming, docs, tests) before requesting review.

## Tests

- See `.github/instructions/testing.instructions.md` for how we write and run tests.
- Add or update tests for all non-trivial changes. Ensure they pass locally before opening a PR.

## Documentation

- See `.github/instructions/doc.instructions.md`.
- Update README.md and/or in-repo docs when behavior or public APIs change.

## Project layout

- See `.github/instructions/layout.instructions.md` for structure and naming.

## CI/CD

- See `.github/instructions/ci.instructions.md`.
- Ensure linting/tests pass locally before pushing to speed up reviews.

## Versioning and releases

- This repo uses Release Please for automated semantic versioning, CHANGELOG generation, and GitHub Releases.
- Do not manually bump versions or edit CHANGELOG.md; Release Please manage these when its release PR is merged.
- Conventional Commits determine semver bumps: `feat` (minor), `fix` (patch), `feat!`/`fix!` or `BREAKING CHANGE:` (
  major).
- How it works:
    - On pushes to `master`, the Release Please workflow opens/updates a release PR with proposed version and notes.
    - Merge that PR to cut a release: tags are created (e.g., `vX.Y.Z`), `package.json` is updated, and `CHANGELOG.md`
      is written.
    - You can also trigger it manually from the Actions tab (workflow: "Release Please").

## Communication

- Primary maintainer: @podcamp
- For security or architecture changes: open an issue/RFC and tag the maintainers.

## License

By contributing, you agree that your contributions are licensed under the repository’s LICENSE.

Participation is governed by the project’s Code of Conduct (CODE_OF_CONDUCT.md).
