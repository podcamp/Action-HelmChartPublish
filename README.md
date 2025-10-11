# Template-Base

Base Template Repository with copilot instructions

## Commit messages and Git hook

This repo enforces Conventional Commits via commitlint.

- A commit-msg Git hook (managed by Husky) blocks commits with invalid messages.
- After cloning, run `npm install` once to set up Husky hooks (via the `prepare` script).
- Examples:
    - good: `feat: add commit hook`
    - bad: `update readme`

Configuration lives in `commitlint.config.mjs`.

## Releases

- Manual by Release Please.
- Do not bump versions or edit CHANGELOG manually.
- Manually running the `Release Please` workflow on the `master` or `main` branch opens (or updates) a release PR with
  the next version and release notes.
- Merge the release PR to publish a GitHub Release, tag (e.g., `vX.Y.Z`), update `CHANGELOG.md`, and bump
  `package.json`.

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines on branching, commits, PRs, testing, and docs.

## Code of Conduct

See [CODE_OF_CONDUCT.md](CODE_OF_CONDUCT.md).