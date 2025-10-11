# HelmChartPublish Action

This action packages a Helm chart and publishes it to GitHub Releases and/or OCI registries (GitHub Container Registry or a private registry).

## What it does

- Checks if a GitHub Release exists for a given tag.
- Checks out the repository at that tag.
- Packages the chart from `chart-path` into `out/<chart>-<version>.tgz`.
- Optionally attaches the tgz to the existing GitHub Release.
- Optionally pushes the chart to:
  - GitHub Container Registry (ghcr.io)
  - A private OCI registry (e.g., `oci://registry.example.com/org/charts`)

## Requirements

- Helm 3 (installed automatically via `azure/setup-helm`).
- A GitHub Release must already exist for the provided tag.
- The action expects a `Chart.yaml` under `chart-path` (default `./src`).

## Inputs

- token: GitHub token for API calls and GHCR auth. Defaults to `GITHUB_TOKEN`.
- tag-name: Tag to package (e.g., `v1.2.3`). Required.
- chart-path: Path to chart root (default `./src`).
- github-registry-path: Path segment under `ghcr.io/<owner>/...` to push into (default `charts`).
- enable-cosign: If `true`, cosign will sign pushed OCI references (global default).
- enable-cosign-ghcr: Override for GHCR (true/false). Empty means inherit `enable-cosign`.
- enable-cosign-private: Override for Private registry (true/false). Empty means inherit `enable-cosign`.
- cosign-key: Optional PEM private key for cosign; omit for keyless OIDC.
- cosign-key-password: Optional password for the cosign private key.
- cosign-annotations: Optional comma-separated annotations for cosign (key=value,key2=value2).
- cosign-args: Optional extra arguments to pass to `cosign sign` and `cosign attest`.
- enable-cosign-attest: If `true`, cosign will create an attestation (global default).
- enable-cosign-attest-ghcr: Override for GHCR attestation (true/false). Empty means inherit `enable-cosign-attest`.
- enable-cosign-attest-private: Override for Private attestation (true/false). Empty means inherit `enable-cosign-attest`.
- cosign-attest-type: Predicate type for cosign attest (default `application/vnd.in-toto+json`).
- cosign-attest-predicate: Inline JSON/YAML predicate for attestation (optional).
- cosign-attest-predicate-path: Path to a predicate file (takes precedence over inline).
- push-to-github-release: Attach tgz to the existing GitHub Release (default `true`).
- push-to-github-registry: Push to GHCR (default `true`).
- push-to-private-registry: Push to a private OCI registry (default `false`).
- private-registry-url: The target `oci://...` URL for the private registry.
- private-registry-username / private-registry-password: Optional credentials; if set, the action will docker login to the private registry host before pushing, signing, or attesting.
- repo-url / github-api-url: Defaults from the runtime context.

## Outputs

- version: Chart version from `Chart.yaml`.
- chart-name: Chart name from `Chart.yaml`.
- tgz: Absolute path to the packaged tarball.
- release-exists: `true`/`false` whether a GitHub Release exists for `tag-name`.

## Example workflow

Note: Requires permissions to read contents and write packages if pushing to GHCR.

```yaml
name: Publish Helm Chart
on:
  workflow_dispatch:
  release:
    types: [published]

permissions:
  contents: read
  packages: write
  id-token: write # required for cosign keyless signing/attestation

jobs:
  publish:
    runs-on: ubuntu-latest
    steps:
      - name: Publish chart (with cosign keyless)
        uses: ./. # or nicola-preden/HelmChartPublish@v1 when published
        with:
          tag-name: ${{ github.ref_name }}
          chart-path: ./charts/mychart
          github-registry-path: charts
          push-to-github-release: 'true'
          push-to-github-registry: 'true'
          push-to-private-registry: 'false'
          enable-cosign: 'true'        # enable built-in cosign signing
          # For key-based instead of keyless, also provide:
          # cosign-key: ${{ secrets.COSIGN_PRIVATE_KEY_PEM }}
          # cosign-key-password: ${{ secrets.COSIGN_KEY_PASSWORD }}
          # cosign-annotations: repo=${{ github.repository }},ref=${{ github.ref }}
          # cosign-args: '--tlog-upload=true'
```

## More examples

Example 1: GHCR sign + attest, Private sign-only

```yaml
permissions:
  contents: read
  packages: write
  id-token: write

jobs:
  publish:
    runs-on: ubuntu-latest
    steps:
      - name: Publish chart with per-target cosign
        uses: ./. 
        with:
          tag-name: ${{ github.ref_name }}
          chart-path: ./charts/mychart
          push-to-github-registry: 'true'
          push-to-private-registry: 'true'
          private-registry-url: oci://registry.example.com/org/charts
          private-registry-username: ${{ secrets.PRIVATE_REGISTRY_USER }}
          private-registry-password: ${{ secrets.PRIVATE_REGISTRY_PASS }}
          # Global defaults
          enable-cosign: 'true'              # sign everywhere by default
          enable-cosign-attest: 'false'      # no attestation by default
          # Per-target overrides
          enable-cosign-attest-ghcr: 'true'  # add attestation on GHCR
```

Example 2: GHCR sign-only, Private sign + attest

```yaml
permissions:
  contents: read
  packages: write
  id-token: write

jobs:
  publish:
    runs-on: ubuntu-latest
    steps:
      - name: Publish chart with per-target cosign
        uses: ./. 
        with:
          tag-name: ${{ github.ref_name }}
          chart-path: ./charts/mychart
          push-to-github-registry: 'true'
          push-to-private-registry: 'true'
          private-registry-url: oci://registry.example.com/org/charts
          private-registry-username: ${{ secrets.PRIVATE_REGISTRY_USER }}
          private-registry-password: ${{ secrets.PRIVATE_REGISTRY_PASS }}
          # Global defaults
          enable-cosign: 'false'                 # default off
          enable-cosign-attest: 'false'          # default off
          # Per-target overrides
          enable-cosign-ghcr: 'true'             # sign on GHCR only
          enable-cosign-private: 'true'          # sign on private
          enable-cosign-attest-private: 'true'   # attest on private only
```

## Local quick test (optional)

From a PowerShell 7+ session with Helm installed:

```powershell
pwsh -NoLogo -NoProfile -File ./src/Invoke-HelmChartPublishAction.ps1 -Task Prepare -ChartPath ./src
```

This produces the packaged chart under `./out`. To push to GHCR locally:

```powershell
$env:GITHUB_TOKEN = '<token-with-packages-scope>'
pwsh -NoLogo -NoProfile -File ./src/Invoke-HelmChartPublishAction.ps1 -Task PublishToGitHubRegistry -RepositoryUrl 'owner/repo'
```

## Notes

- GHES is supported via `github-api-url`; the script derives the correct web URL when constructing release links.
- For GHCR, the action logs in to `ghcr.io` and pushes to `oci://ghcr.io/<owner>/<github-registry-path>`, with the final chart reference including the chart name and version tag.
- The reference `azure/setup-helm@v4` is resolved at runtime; local static analyzers may warn if offline.

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

## Cosign signing and attestation (built-in)

Toggles and precedence:
- Signing: `enable-cosign` (global), overridden by `enable-cosign-ghcr` and `enable-cosign-private` if set.
- Attestation: `enable-cosign-attest` (global), overridden by `enable-cosign-attest-ghcr` and `enable-cosign-attest-private` if set.
- Empty string for per-target toggles means "inherit the global".

Common scenarios:
- Sign GHCR only (no attestation anywhere):
  - enable-cosign: 'true'
  - enable-cosign-attest: 'false'
  - enable-cosign-private: 'false'
- Sign+attest GHCR; sign-only Private:
  - enable-cosign: 'true'
  - enable-cosign-attest: 'false'
  - enable-cosign-attest-ghcr: 'true'
  - enable-cosign-private: 'true'
- Sign+attest Private only:
  - enable-cosign: 'false'
  - enable-cosign-attest: 'false'
  - enable-cosign-private: 'true'
  - enable-cosign-attest-private: 'true'

Private registries:
- If `private-registry-username` and `private-registry-password` are provided, the action logs in with Docker to the registry host derived from `private-registry-url` before any private push/sign/attest steps.
