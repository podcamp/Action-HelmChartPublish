# SPDX-License-Identifier: GPL-3.0
# Copyright (C) 2025 Nicola Preden

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateSet('CheckRelease','Prepare','PublishToGitHubRegistry','PublishToPrivateRegistry','CosignSign','CosignAttest')]
    [string]$Task,

    [string]$Token,
    [string]$GitHubApiUrl,
    [string]$TagName,
    [string]$RepositoryUrl,

    [string]$ChartPath,

    # For private registry task
    [string]$PrivateRegistryUrl,
    [string]$PrivateRegistryUsername,
    [string]$PrivateRegistryPassword,

    # For GitHub registry customization
    [string]$GitHubRegistryPath,

    # Cosign parameters
    [string]$CosignTarget,            # 'GitHub' or 'Private'
    [string]$ChartName,
    [string]$ChartVersion,
    [string]$CosignKey,
    [string]$CosignKeyPassword,
    [string]$CosignAnnotations,       # comma-separated: key=value,key2=value2
    [string]$CosignArgs,               # extra flags, raw string

    # Cosign attestation
    [string]$CosignAttestType,
    [string]$CosignAttestPredicate,
    [string]$CosignAttestPredicatePath
)

$ErrorActionPreference = 'Stop'

function Write-GitHubOutput {
    param(
        [Parameter(Mandatory=$true)] [string] $Name,
        [Parameter(Mandatory=$true)] [string] $Value
    )
    if (-not $env:GITHUB_OUTPUT) { return }
    Add-Content -Path $env:GITHUB_OUTPUT -Value ("{0}={1}" -f $Name, $Value)
}

function Test-HelmCliAvailable {
    try {
        $null = helm version --short 2>$null
    }
    catch {
        throw 'Helm CLI is not available in PATH. Install Helm v3 before running this task.'
    }
}

function Test-CosignCliAvailable {
    try {
        $null = cosign version 2>$null
    }
    catch {
        throw 'cosign CLI is not available in PATH. Install cosign before running this task.'
    }
}

function Read-ChartInfo {
    param([Parameter(Mandatory=$true)][string]$Path)
    $chartFile = Join-Path -Path $Path -ChildPath 'Chart.yaml'
    if (-not (Test-Path $chartFile)) { throw "Chart.yaml not found under '$Path'" }

    $chartName = $null; $chartVersion = $null
    if (Get-Command ConvertFrom-Yaml -ErrorAction SilentlyContinue) {
        $yaml = Get-Content -Raw -Path $chartFile | ConvertFrom-Yaml
        $chartName = $yaml.name
        $chartVersion = $yaml.version
    } else {
        $content = Get-Content -Raw -Path $chartFile
        if ($content -match '(?im)^name:\s*(.+)$') { $chartName = $Matches[1].Trim() }
        if ($content -match '(?im)^version:\s*([^\s#]+)') { $chartVersion = $Matches[1].Trim() }
    }
    if (-not $chartName) { throw 'Chart name not found in Chart.yaml' }
    if (-not $chartVersion) { throw 'Chart version not found in Chart.yaml' }
    [pscustomobject]@{ Name = $chartName; Version = $chartVersion; ChartFile = $chartFile }
}

# Fallback token from environment if not provided
if (-not $Token) { $Token = $env:GITHUB_TOKEN }

# Dispatch by task using switch for clarity
switch ($Task) {
    'CheckRelease' {
        if (-not $GitHubApiUrl) { $GitHubApiUrl = $env:GITHUB_API_URL }
        if (-not $RepositoryUrl) { $RepositoryUrl = $env:GITHUB_REPOSITORY }
        if (-not $TagName) { throw 'TagName is required for CheckRelease' }

        $uri = "$GitHubApiUrl/repos/$RepositoryUrl/releases/tags/$TagName"
        try {
            $headers = @{ Accept = 'application/vnd.github+json'; 'X-GitHub-Api-Version' = '2022-11-28' }
            if ($Token) { $headers.Authorization = "Bearer $Token" }
            $resp = Invoke-WebRequest -Headers $headers -Uri $uri -Method GET -ErrorAction Stop
            if ($resp.StatusCode -eq 200) {
                Write-GitHubOutput -Name 'release-exists' -Value 'true'
            } else {
                Write-GitHubOutput -Name 'release-exists' -Value 'false'
            }
        } catch {
            Write-GitHubOutput -Name 'release-exists' -Value 'false'
        }
        break
    }
    'Prepare' {
        if (-not $ChartPath) { throw '$ChartPath is not set.' }
        Test-HelmCliAvailable

        $info = Read-ChartInfo -Path $ChartPath

        # Create output folder and package
        Remove-Item -Recurse -Force -ErrorAction SilentlyContinue out
        New-Item -ItemType Directory -Path out | Out-Null

        $packageOutput = helm package "$ChartPath" -d out 2>&1
        if ($LASTEXITCODE -ne 0) { throw "helm package failed: $packageOutput" }

        # Find produced tgz
        $tgz = Get-ChildItem -Path out -Filter "$($info.Name)-$($info.Version).tgz" | Select-Object -First 1
        if (-not $tgz) {
            $tgz = Get-ChildItem -Path out -Filter '*.tgz' | Select-Object -First 1
        }
        if (-not $tgz) { throw 'Packaged chart (.tgz) not found in ./out' }

        Write-Verbose "Packaged chart: $($tgz.FullName)"
        Write-GitHubOutput -Name 'version' -Value $info.Version
        Write-GitHubOutput -Name 'tgz' -Value $tgz.FullName
        Write-GitHubOutput -Name 'chart-name' -Value $info.Name
        break
    }
    'PublishToGitHubRegistry' {
        Test-HelmCliAvailable
        if (-not $RepositoryUrl) { $RepositoryUrl = $env:GITHUB_REPOSITORY }
        if (-not ($RepositoryUrl -and $RepositoryUrl.Contains('/'))) { throw "Invalid RepositoryUrl '$RepositoryUrl' (expected 'owner/repo')" }
        if (-not $Token) { throw 'Token is required to authenticate to ghcr.io' }
        if (-not $GitHubRegistryPath) { $GitHubRegistryPath = 'charts' }

        $owner = $RepositoryUrl.Split('/')[0]
        $ociHost = 'ghcr.io'
        $repo = "oci://$ociHost/$owner/$GitHubRegistryPath"

        $loginOut = helm registry login $ociHost --username $owner --password $Token 2>&1
        if ($LASTEXITCODE -ne 0) { throw "Helm registry login to $ociHost failed: $loginOut" }

        $tgz = Get-ChildItem -Path out -Filter '*.tgz' | Select-Object -First 1
        if (-not $tgz) { throw 'No packaged chart found under ./out. Run -Task Prepare first.' }

        $helmPushProvArgs = @()
        if (Test-Path ("{0}.prov" -f $tgz.FullName)) { $helmPushProvArgs = @('--prov') }

        $pushOut = helm push "$($tgz.FullName)" "$repo" @helmPushProvArgs 2>&1
        if ($LASTEXITCODE -ne 0) { throw "Helm push to $repo failed: $pushOut" }
        Write-Verbose "Pushed chart to $repo"
        break
    }
    'PublishToPrivateRegistry' {
        Test-HelmCliAvailable
        if (-not $PrivateRegistryUrl) { throw 'PrivateRegistryUrl is required (e.g., registry.example.com/org/charts or registry.example.com)' }

        $tgz = Get-ChildItem -Path out -Filter '*.tgz' | Select-Object -First 1
        if (-not $tgz) { throw 'No packaged chart found under ./out. Run -Task Prepare first.' }

        $helmPushProvArgs = @()
        if (Test-Path ("{0}.prov" -f $tgz.FullName)) { $helmPushProvArgs = @('--prov') }

        # Login for Helm registry if credentials are provided or token exists
        $ociHostPrivate = ($PrivateRegistryUrl -replace '^oci://','').Split('/')[0]
        if ($PrivateRegistryUsername -and $PrivateRegistryPassword) {
            $loginOut = helm registry login $ociHostPrivate --username $PrivateRegistryUsername --password $PrivateRegistryPassword 2>&1
            if ($LASTEXITCODE -ne 0) { throw "Helm registry login to $ociHostPrivate failed: $loginOut" }
            Write-Verbose "Helm registry login succeeded for $ociHostPrivate using username/password"
        } elseif ($Token) {
            $loginOut = helm registry login $ociHostPrivate --username token --password $Token 2>&1
            if ($LASTEXITCODE -ne 0) { Write-Verbose "Helm registry login to $ociHostPrivate with token failed (continuing if registry allows anonymous)" }
        }

        $target = if ($PrivateRegistryUrl.StartsWith('oci://')) { $PrivateRegistryUrl } else { "oci://$PrivateRegistryUrl" }
        $pushOut = helm push "$($tgz.FullName)" "$target" @helmPushProvArgs 2>&1
        if ($LASTEXITCODE -ne 0) { throw "Helm push to $target failed: $pushOut" }
        Write-Verbose "Pushed chart to $target"
        break
    }
    'CosignSign' {
        Test-CosignCliAvailable

        if (-not $ChartName -or -not $ChartVersion) {
            if ($ChartPath) {
                $info = Read-ChartInfo -Path $ChartPath
                if (-not $ChartName) { $ChartName = $info.Name }
                if (-not $ChartVersion) { $ChartVersion = $info.Version }
            }
        }
        if (-not $ChartName -or -not $ChartVersion) { throw 'ChartName and ChartVersion are required for CosignSign' }

        $ref = $null
        if ($CosignTarget -eq 'GitHub') {
            if (-not $RepositoryUrl) { $RepositoryUrl = $env:GITHUB_REPOSITORY }
            if (-not ($RepositoryUrl -and $RepositoryUrl.Contains('/'))) { throw "Invalid RepositoryUrl '$RepositoryUrl' (expected 'owner/repo')" }
            if (-not $GitHubRegistryPath) { $GitHubRegistryPath = 'charts' }
            $owner = $RepositoryUrl.Split('/')[0]
            $ref = "ghcr.io/$($owner)/$($GitHubRegistryPath)/$($ChartName):$($ChartVersion)"
        }
        elseif ($CosignTarget -eq 'Private') {
            if (-not $PrivateRegistryUrl) { throw 'PrivateRegistryUrl is required for CosignSign when CosignTarget=Private' }
            $url = $PrivateRegistryUrl -replace '^oci://',''
            $url = $url.TrimEnd('/')
            $ref = "$url/$($ChartName):$($ChartVersion)"
        }
        else { throw "Unsupported CosignTarget '$CosignTarget' (use 'GitHub' or 'Private')" }

        $annoFlags = @()
        if ($CosignAnnotations) {
            foreach ($pair in $CosignAnnotations.Split(',')) {
                if ([string]::IsNullOrWhiteSpace($pair)) { continue }
                $annoFlags += @('-a', $pair.Trim())
            }
        }

        $keyFile = $null
        if ($CosignKey) {
            $keyFile = Join-Path ([IO.Path]::GetTempPath()) ('cosign-key-' + [guid]::NewGuid().ToString('N') + '.pem')
            Set-Content -Path $keyFile -Value $CosignKey -Encoding UTF8 -NoNewline
            if ($CosignKeyPassword) { $env:COSIGN_PASSWORD = $CosignKeyPassword }
        }

        $extraArgs = @()
        if ($CosignArgs) { $extraArgs = $CosignArgs -split '\s+' }

        $cmd = @('sign','--yes')
        if ($keyFile) { $cmd += @('--key', $keyFile) }
        $cmd += $annoFlags
        $cmd += $extraArgs
        $cmd += @($ref)

        Write-Verbose "Running: cosign $($cmd -join ' ')"
        $out = cosign @cmd 2>&1
        if ($LASTEXITCODE -ne 0) { throw "cosign sign failed: $out" }
        Write-Verbose "cosign sign succeeded for $ref"
        break
    }
    'CosignAttest' {
        Test-CosignCliAvailable

        if (-not $ChartName -or -not $ChartVersion) {
            if ($ChartPath) {
                $info = Read-ChartInfo -Path $ChartPath
                if (-not $ChartName) { $ChartName = $info.Name }
                if (-not $ChartVersion) { $ChartVersion = $info.Version }
            }
        }
        if (-not $ChartName -or -not $ChartVersion) { throw 'ChartName and ChartVersion are required for CosignAttest' }

        $ref = $null
        if ($CosignTarget -eq 'GitHub') {
            if (-not $RepositoryUrl) { $RepositoryUrl = $env:GITHUB_REPOSITORY }
            if (-not ($RepositoryUrl -and $RepositoryUrl.Contains('/'))) { throw "Invalid RepositoryUrl '$RepositoryUrl' (expected 'owner/repo')" }
            if (-not $GitHubRegistryPath) { $GitHubRegistryPath = 'charts' }
            $owner = $RepositoryUrl.Split('/')[0]
            $ref = "ghcr.io/$($owner)/$($GitHubRegistryPath)/$($ChartName):$($ChartVersion)"
        }
        elseif ($CosignTarget -eq 'Private') {
            if (-not $PrivateRegistryUrl) { throw 'PrivateRegistryUrl is required for CosignAttest when CosignTarget=Private' }
            $url = $PrivateRegistryUrl -replace '^oci://',''
            $url = $url.TrimEnd('/')
            $ref = "$($url)/$($ChartName):$($ChartVersion)"
        }
        else { throw "Unsupported CosignTarget '$CosignTarget' (use 'GitHub' or 'Private')" }

        $annoFlags = @()
        if ($CosignAnnotations) {
            foreach ($pair in $CosignAnnotations.Split(',')) {
                if ([string]::IsNullOrWhiteSpace($pair)) { continue }
                $annoFlags += @('-a', $pair.Trim())
            }
        }

        $keyFile = $null
        if ($CosignKey) {
            $keyFile = Join-Path ([IO.Path]::GetTempPath()) ('cosign-key-' + [guid]::NewGuid().ToString('N') + '.pem')
            Set-Content -Path $keyFile -Value $CosignKey -Encoding UTF8 -NoNewline
            if ($CosignKeyPassword) { $env:COSIGN_PASSWORD = $CosignKeyPassword }
        }

        $extraArgs = @()
        if ($CosignArgs) { $extraArgs = $CosignArgs -split '\s+' }

        if (-not $CosignAttestType) { $CosignAttestType = 'application/vnd.in-toto+json' }

        $predicateFile = $CosignAttestPredicatePath
        $tempPredicate = $false
        if (-not $predicateFile) {
            if ($CosignAttestPredicate) {
                $predicateFile = Join-Path ([IO.Path]::GetTempPath()) ('predicate-' + [guid]::NewGuid().ToString('N') + '.json')
                Set-Content -Path $predicateFile -Value $CosignAttestPredicate -Encoding UTF8
                $tempPredicate = $true
            } else {
                $predicateFile = Join-Path ([IO.Path]::GetTempPath()) ('predicate-' + [guid]::NewGuid().ToString('N') + '.json')
                $now = [DateTime]::UtcNow.ToString('o')
                $payload = @{ chart = $ChartName; version = $ChartVersion; buildTime = $now } | ConvertTo-Json -Depth 5
                Set-Content -Path $predicateFile -Value $payload -Encoding UTF8
                $tempPredicate = $true
            }
        }

        $cmd = @('attest','--yes','--type', $CosignAttestType,'--predicate', $predicateFile)
        if ($keyFile) { $cmd += @('--key', $keyFile) }
        $cmd += $annoFlags
        $cmd += $extraArgs
        $cmd += @($ref)

        Write-Verbose "Running: cosign $($cmd -join ' ')"
        $out = cosign @cmd 2>&1
        if ($LASTEXITCODE -ne 0) { throw "cosign attest failed: $out" }
        Write-Verbose "cosign attest succeeded for $ref"

        if ($tempPredicate -and (Test-Path $predicateFile)) { Remove-Item -Force $predicateFile -ErrorAction SilentlyContinue }
        if ($keyFile -and (Test-Path $keyFile)) { Remove-Item -Force $keyFile -ErrorAction SilentlyContinue }
        break
    }
    Default {
        throw "Unknown -Task '$Task'."
    }
}