# Changelog

## [0.2.3](https://github.com/nicola-preden/Action-HelmChartPublish/compare/v0.2.2...v0.2.3) (2025-10-12)


### Bug Fixes

* update Invoke-HelmChartPublishAction.ps1 to use token for GitHub authentication ([d857d69](https://github.com/nicola-preden/Action-HelmChartPublish/commit/d857d6980443d9951c10c356adfce87a0e22328e))

## [0.2.2](https://github.com/nicola-preden/Action-HelmChartPublish/compare/v0.2.1...v0.2.2) (2025-10-12)


### Bug Fixes

* correct ValidateSet options in Invoke-HelmChartPublishAction.ps1 ([c56a89e](https://github.com/nicola-preden/Action-HelmChartPublish/commit/c56a89ed51306f474f61ed885890a3061f7553d2))

## [0.2.1](https://github.com/nicola-preden/Action-HelmChartPublish/compare/v0.2.0...v0.2.1) (2025-10-12)


### Features

* add PowerShell tasks for PSGallery trust, module path detection, and ConvertFrom-Yaml installation ([b0696bb](https://github.com/nicola-preden/Action-HelmChartPublish/commit/b0696bba6f96dc7b73285ba29d171a17719ad3ed))


### Bug Fixes

* ensure ConvertFrom-Yaml is available by installing powershell-yaml module if missing ([a1f7407](https://github.com/nicola-preden/Action-HelmChartPublish/commit/a1f74077b92edc36f85de5160b8f1752313efbde))

## [0.2.0](https://github.com/nicola-preden/Action-HelmChartPublish/compare/v0.1.1...v0.2.0) (2025-10-12)


### ⚠ BREAKING CHANGES

* streamline cosign configuration in action.yml and remove attest functionality from Invoke-HelmChartPublishAction.ps1
* simplify cosign configuration in action.yml and update README for clarity
* enhance action.yml and Invoke-HelmChartPublishAction.ps1 for DockerHub support

### Features

* enhance action.yml and Invoke-HelmChartPublishAction.ps1 for DockerHub support ([9b4b4d3](https://github.com/nicola-preden/Action-HelmChartPublish/commit/9b4b4d3ef7063f168e653dbe515c9aa647731fca))
* streamline cosign configuration in action.yml and remove attest functionality from Invoke-HelmChartPublishAction.ps1 ([8a8980e](https://github.com/nicola-preden/Action-HelmChartPublish/commit/8a8980ed42f1142a03612618e798dcd7d0e75a8b))


### Bug Fixes

* simplify cosign configuration in action.yml and update README for clarity ([19c6e7c](https://github.com/nicola-preden/Action-HelmChartPublish/commit/19c6e7c62ea49a12e5ba9f08bd6e346fc1007d97))
* update DockerHub authentication from password to token in action.yml and Invoke-HelmChartPublishAction.ps1 ([5623da4](https://github.com/nicola-preden/Action-HelmChartPublish/commit/5623da406647f934090b3b3ea8678ee22ff42e31))
* update README to reflect DockerHub token usage instead of password ([246bdb5](https://github.com/nicola-preden/Action-HelmChartPublish/commit/246bdb5d2d5193537481cc53d88fc5f18781c8b3))

## [0.1.1](https://github.com/nicola-preden/Action-HelmChartPublish/compare/v0.1.0...v0.1.1) (2025-10-12)


### Features

* deploy a helm chart on GitHub or a Private Registry ([#1](https://github.com/nicola-preden/Action-HelmChartPublish/issues/1)) ([f108ba7](https://github.com/nicola-preden/Action-HelmChartPublish/commit/f108ba78908c208b509f1cf6a4c48b286eedf0b7))


### Bug Fixes

* add test results file to .gitignore ([9de2d4d](https://github.com/nicola-preden/Action-HelmChartPublish/commit/9de2d4d3477bfed2dfa374c47f8bd963b361d8e1))
* enforce required chart-path in action.yml and improve error handling in Prepare task ([4f18683](https://github.com/nicola-preden/Action-HelmChartPublish/commit/4f18683caaa5fc2a297a08bd3f608e1caec2b1cc))
* enhance tests in Prepare.Tests.ps1 for better error handling and directory management ([da2c7e1](https://github.com/nicola-preden/Action-HelmChartPublish/commit/da2c7e1bac017a6f7afbf8cc0041deb2c00ca3f4))
* improve function naming and error handling in Invoke-HelmChartPublishAction.ps1 ([6dc3f87](https://github.com/nicola-preden/Action-HelmChartPublish/commit/6dc3f87d6ecce7282c17d6f26d35beedca03878c))
* update output location in Prepare.Tests.ps1 for improved directory management ([06b88d8](https://github.com/nicola-preden/Action-HelmChartPublish/commit/06b88d8807aa3763322af6cbafd29b8013e9cb33))
* update release-please.yml to streamline testing and improve artifact handling ([3595e8e](https://github.com/nicola-preden/Action-HelmChartPublish/commit/3595e8e2a9e82ce739ff65446091c769e48cad7a))
* update version in .release-please-manifest.json to 0.1.0 ([a48029c](https://github.com/nicola-preden/Action-HelmChartPublish/commit/a48029cf9d749947c288bea1f792b6ca89c60df3))

## Changelog
