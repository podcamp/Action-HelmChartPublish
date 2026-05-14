# HelmChartPublish Action

This action packages a Helm chart and publishes it to GitHub Releases and/or OCI registries (GitHub Container Registry or DockerHub).

## What it does

- Checks if a GitHub Release exists for a given tag.
- Checks out the repository at that tag.
- Packages the chart from `chart-path` into `out/<chart>-<version>.tgz`.
- Optionally attaches the tgz to the existing GitHub Release.
- Optionally pushes the chart to:
  - GitHub Container Registry (ghcr.io)
  - DockerHub (registry-1.docker.io)

## Requirements

- Helm 3 (installed automatically via `azure/setup-helm`).
- A GitHub Release must already exist for the provided tag.
- The action expects a `Chart.yaml` under `chart-path`.

## Inputs

- token: GitHub token for API calls and GHCR auth. Defaults to `GITHUB_TOKEN`.
- tag-name: Tag to package (e.g., `v1.2.3`). Required.
- chart-path: Path to chart root.
- github-registry-path: Path segment under `ghcr.io/<owner>/...` to push into (default `charts`).
- push-to-github-release: Attach tgz to the existing GitHub Release (default `true`).
- push-to-github-registry: Push to GHCR (default `true`).
- push-to-dockerhub: Push to DockerHub (default `false`).
- dockerhub-username / dockerhub-password: DockerHub credentials.
- dockerhub-namespace: DockerHub namespace (defaults to username if empty).
- dockerhub-path: Path segment under the namespace (default `charts`).

Cosign (optional, keyless only; global toggles only):
- enable-cosign: If `true`, cosign will sign pushed OCI references.
- cosign-annotations: Optional comma-separated annotations for cosign (key=value,key2=value2).
- cosign-args: Optional extra arguments to pass to `cosign sign` and `cosign attest`.
- enable-cosign-attest: If `true`, cosign will create an attestation.
- cosign-attest-type: Predicate type for cosign attest (default `application/vnd.in-toto+json`).
- cosign-attest-predicate: Inline JSON/YAML predicate for attestation (optional).
- cosign-attest-predicate-path: Path to a predicate file (takes precedence over inline).

Keyless notes:
- Set `permissions: id-token: write` for the job so cosign can obtain an OIDC token.
- For GHCR signatures, the action performs a `docker login ghcr.io` with the provided token (or `GITHUB_TOKEN`); for DockerHub, it logs in with `dockerhub-username`/`dockerhub-password`.
- No private keys are needed or supported; cosign uses OIDC keyless flow.

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
        uses: ./. # or podcamp/HelmChartPublish@v1 when published
        with:
          tag-name: ${{ github.ref_name }}
          chart-path: ./charts/mychart
          github-registry-path: charts
          push-to-github-release: 'true'
          push-to-github-registry: 'true'
          push-to-dockerhub: 'false'
          enable-cosign: 'true'
          # enable-cosign-attest: 'true'        # uncomment to add attestations globally
          # cosign-annotations: repo=${{ github.repository }},ref=${{ github.ref }}
          # cosign-args: '--tlog-upload=true'
```

## More examples

Example 1: Sign on both GHCR and DockerHub (no attestations)

```yaml
with:
  tag-name: ${{ github.ref_name }}
  chart-path: ./charts/mychart
  push-to-github-registry: 'true'
  push-to-dockerhub: 'true'
  dockerhub-username: ${{ secrets.DOCKERHUB_USERNAME }}
  dockerhub-password: ${{ secrets.DOCKERHUB_TOKEN }}
  enable-cosign: 'true'
  enable-cosign-attest: 'false'
```

Example 2: Sign + attest on both GHCR and DockerHub

```yaml
with:
  tag-name: ${{ github.ref_name }}
  chart-path: ./charts/mychart
  push-to-github-registry: 'true'
  push-to-dockerhub: 'true'
  dockerhub-username: ${{ secrets.DOCKERHUB_USERNAME }}
  dockerhub-password: ${{ secrets.DOCKERHUB_TOKEN }}
  enable-cosign: 'true'
  enable-cosign-attest: 'true'
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

To push to DockerHub locally:

```powershell
pwsh -NoLogo -NoProfile -File ./src/Invoke-HelmChartPublishAction.ps1 -Task PublishToDockerHub -DockerHubUsername '<user>' -DockerHubToken '<token>' -DockerHubNamespace '<org-or-user>' -DockerHubPath 'charts'
```

## Notes

- For GHCR, the action logs in to `ghcr.io` and pushes to `oci://ghcr.io/<owner>/<github-registry-path>`.
- For DockerHub, the action logs in to `registry-1.docker.io` and pushes to `oci://registry-1.docker.io/<namespace>/<dockerhub-path>`.
- Cosign references follow the same hosts and include `<chart>:<version>` tags.
- The reference `azure/setup-helm@v4` is resolved at runtime; local static analyzers may warn if offline.

## Migration notes (breaking changes)

- Per-target cosign override flags were removed: `enable-cosign-ghcr`, `enable-cosign-dockerhub`, `enable-cosign-attest-ghcr`, `enable-cosign-attest-dockerhub`. Use the global `enable-cosign` and `enable-cosign-attest` instead.
- Cosign keys were removed previously; keyless (OIDC) is now the only supported mode. Ensure your workflow has `permissions: id-token: write`.
- Earlier versions also supported a generic "private registry"; this has been specialized to DockerHub.

## Commit messages and Git hook

This repo enforces Conventional Commits via commitlint.

- A commit-msg Git hook (managed by Husky) blocks commits with invalid messages.
- After cloning, run `npm install` once to set up Husky hooks (via the `prepare` script).
- Examples:
    - good: `feat: add commit hook`
    - bad: `update readme`

Configuration lives in `commitlint.config.mjs`.

## Releases

- Managed by Release Please.
- Do not bump versions or edit CHANGELOG manually.
- The Release Please workflow on `master`/`main` opens (or updates) a release PR with the next version and release notes.
- Merge the release PR to publish a GitHub Release, tag (e.g., `vX.Y.Z`), update `CHANGELOG.md`, and bump `package.json`.

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines on branching, commits, PRs, testing, and docs.

## Code of Conduct

See [CODE_OF_CONDUCT.md](CODE_OF_CONDUCT.md).

## Cosign signing and attestation (built-in)

Toggles:
- Signing: `enable-cosign` (global)
- Attestation: `enable-cosign-attest` (global)

Common scenarios:
- Sign on all enabled targets (no attestation):
  - enable-cosign: 'true'
  - enable-cosign-attest: 'false'
- Sign + attest on all enabled targets:
  - enable-cosign: 'true'
  - enable-cosign-attest: 'true'
