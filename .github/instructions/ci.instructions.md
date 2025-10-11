# CI/CD Guidelines (GitHub Actions)

Purpose

- Fast, reproducible PR validation and secure releases with automated versioning.
- Keep workflows simple, cache aggressively, and surface failures early.

Triggers

- Manual trigger via the Actions tab (`Release Please`).
- Only on `master` branch for CI and releases.

Versioning and releases (Release Please)

- This repo uses Release Please to manage versions, CHANGELOG, and GitHub Releases.
- Configuration: `.release-please-config.json` (packages and options) and `.release-please-manifest.json` (last released
  versions).
- Workflow: `.github/workflows/release-please.yml` runs on pushes to `master` and can be triggered manually via the
  Actions tab.
- Behavior: Release Please opens/updates a release PR. When merged, it tags the repo (e.g., `v1.2.3`), updates
  `CHANGELOG.md`, and bumps `package.json`.
- Conventional Commits are required so Release Please can infer correct semver bumps.

Concurrency and performance

- Set per-workflow concurrency to cancel superseded runs on the same ref.
- Use actions/cache for dependency caches (keyed by lockfile + runner OS).
- Use matrix testing only where it adds value (e.g., OS or supported runtime versions).

Permissions and security

- Pin actions to a stable major version (or SHA) and review supply chain changes.
- Minimize GITHUB_TOKEN permissions (contents: read for CI; contents: write only for release jobs).
- Prefer OIDC for deployments over long-lived secrets; use environment protection rules for prod.

Required status checks (recommended)

- build: Build and test job must pass on PRs.
- lint: Static analysis and formatting.
- security: CodeQL or language-specific audit if applicable.

Job outline (generic)

- checkout (fetch-depth: 0)
- setup language/runtime (dotnet/node/python/pwsh as relevant)
- restore dependencies (use cache)
- build
- test (with coverage if applicable)
- package (artifact name contains version)
- upload artifacts
- on tags: create release and attach artifacts

Minimal workflow templates

All templates on `workflows_disabled` folder has been removed form the repository and substituted with specific actions.
Ask to @nicola-preden or check to the private repository `@nicola-preden/Action-*` for the best action for your needs.

Caching guidance

- .NET: cache ~/.nuget/packages keyed by packages.lock.json; also consider dotnet restore --locked-mode.
- Node: use setup-node cache; key by package-lock.json/pnpm-lock.yaml.
- PowerShell: cache tool directories if expensive.

Secrets and variables

- No secrets needed for CI-only runs. For releases and deployments:
    - Use environments and OIDC where possible.
    - If publishing to external registries (NuGet/npm): set NUGET_API_KEY or NPM_TOKEN secrets and add a publish job.

Common pitfalls

- Windows runners are recommended for PowerShell module testing; Linux is fine for cross-platform scripts.

How to adopt in this repo

- Run once on a test PR. Verify version output in logs and artifact names.
