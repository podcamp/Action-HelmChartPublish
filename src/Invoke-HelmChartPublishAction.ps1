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
        [Parameter(Mandatory)] [string] $Name,
        [Parameter(Mandatory)] [string] $Value
    )
    if (-not $env:GITHUB_OUTPUT) { return }
    Add-Content -Path $env:GITHUB_OUTPUT -Value ("{0}={1}" -f $Name, $Value)
}

function Get-GitHubServerUrl {
    param([Parameter(Mandatory)][string]$ApiUrl)
    if ($ApiUrl -match '^https://api\.github\.com/?$') {
        return 'https://github.com'
    }
    return ($ApiUrl -replace '/api/v3/?$', '')
}

function Ensure-HelmAvailable {
    try { $null = helm version --short 2>$null } catch { throw 'Helm CLI is not available in PATH. Install Helm v3 before running this task.' }
}

function Ensure-CosignAvailable {
    try { $null = cosign version 2>$null } catch { throw 'cosign CLI is not available in PATH. Install cosign before running this task.' }
}

function Read-ChartInfo {
    param([Parameter(Mandatory)][string]$Path)
    $chartFile = Join-Path -Path $Path -ChildPath 'Chart.yaml'
    if (-not (Test-Path $chartFile)) { throw "Chart.yaml not found under '$Path'" }

    $name = $null; $version = $null
    if (Get-Command ConvertFrom-Yaml -ErrorAction SilentlyContinue) {
        $yaml = Get-Content -Raw -Path $chartFile | ConvertFrom-Yaml
        $name = $yaml.name
        $version = $yaml.version
    } else {
        $content = Get-Content -Raw -Path $chartFile
        if ($content -match '(?im)^name:\s*(.+)$') { $name = $Matches[1].Trim() }
        if ($content -match '(?im)^version:\s*([^\s#]+)') { $version = $Matches[1].Trim() }
    }
    if (-not $name) { throw 'Chart name not found in Chart.yaml' }
    if (-not $version) { throw 'Chart version not found in Chart.yaml' }
    [pscustomobject]@{ Name = $name; Version = $version; ChartFile = $chartFile }
}

# Fallback token from environment if not provided
if (-not $Token) { $Token = $env:GITHUB_TOKEN }

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
    }

    'Prepare' {
        if (-not $ChartPath) { $ChartPath = './src' }
        Ensure-HelmAvailable

        $info = Read-ChartInfo -Path $ChartPath

        # Create output folder and package
        $outDir = Join-Path $PWD 'out'
        if (Test-Path $outDir) {
            Remove-Item -Recurse -Force -ErrorAction SilentlyContinue $outDir
        }
        New-Item -ItemType Directory -Path $outDir | Out-Null

        $args = @('-d', $outDir)
        $packageOutput = helm package "$ChartPath" @args 2>&1
        if ($LASTEXITCODE -ne 0) {
            throw "helm package failed: $packageOutput"
        }

        # Find produced tgz
        $tgz = Get-ChildItem -Path $outDir -Filter "$($info.Name)-$($info.Version).tgz" | Select-Object -First 1
        if (-not $tgz) {
            # Fallback: pick any tgz in out
            $tgz = Get-ChildItem -Path $outDir -Filter '*.tgz' | Select-Object -First 1
        }
        if (-not $tgz) { throw "Packaged chart (.tgz) not found in $outDir" }

        Write-Host "Packaged chart: $($tgz.FullName)"
        Write-GitHubOutput -Name 'version' -Value $info.Version
        Write-GitHubOutput -Name 'tgz' -Value $tgz.FullName
        Write-GitHubOutput -Name 'chart-name' -Value $info.Name
    }

    'PublishToGitHubRegistry' {
        Ensure-HelmAvailable
        if (-not $RepositoryUrl) { $RepositoryUrl = $env:GITHUB_REPOSITORY }
        if (-not ($RepositoryUrl -and $RepositoryUrl.Contains('/'))) {
            throw "Invalid RepositoryUrl '$RepositoryUrl' (expected 'owner/repo')"
        }
        if (-not $Token) { throw 'Token is required to authenticate to ghcr.io' }
        if (-not $GitHubRegistryPath) { $GitHubRegistryPath = 'charts' }

        $owner = $RepositoryUrl.Split('/')[0]
        $registry = 'ghcr.io'
        $repo = "oci://$registry/$owner/$GitHubRegistryPath"

        $loginOut = helm registry login $registry --username $owner --password $Token 2>&1
        if ($LASTEXITCODE -ne 0) { throw "Helm registry login to $registry failed: $loginOut" }

        $tgz = Get-ChildItem -Path out -Filter '*.tgz' | Select-Object -First 1
        if (-not $tgz) { throw 'No packaged chart found under ./out. Run -Task Prepare first.' }

        $provFlag = @()
        if (Test-Path ("{0}.prov" -f $tgz.FullName)) { $provFlag = @('--prov') }

        $pushOut = helm push "$($tgz.FullName)" "$repo" @provFlag 2>&1
        if ($LASTEXITCODE -ne 0) { throw "Helm push to $repo failed: $pushOut" }
        Write-Host "Pushed chart to $repo"
    }

    'PublishToPrivateRegistry' {
        Ensure-HelmAvailable
        if (-not $PrivateRegistryUrl) { throw 'PrivateRegistryUrl is required (e.g., registry.example.com/org/charts or registry.example.com)' }

        $tgz = Get-ChildItem -Path out -Filter '*.tgz' | Select-Object -First 1
        if (-not $tgz) { throw 'No packaged chart found under ./out. Run -Task Prepare first.' }

        $provFlag = @()
        if (Test-Path ("{0}.prov" -f $tgz.FullName)) { $provFlag = @('--prov') }

        $target = if ($PrivateRegistryUrl.StartsWith('oci://')) { $PrivateRegistryUrl } else { "oci://$PrivateRegistryUrl" }
        $pushOut = helm push "$($tgz.FullName)" "$target" @provFlag 2>&1
        if ($LASTEXITCODE -ne 0) { throw "Helm push to $target failed: $pushOut" }
        Write-Host "Pushed chart to $target"
    }

    'CosignSign' {
        Ensure-CosignAvailable

        if (-not $ChartName -or -not $ChartVersion) {
            # Try to derive from ChartPath if available
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
            # If user passed only host, append chart path later
            $url = $url.TrimEnd('/')
            $ref = "$url/$($ChartName):$($ChartVersion)"
        }
        else {
            throw "Unsupported CosignTarget '$CosignTarget' (use 'GitHub' or 'Private')"
        }

        # Build annotation flags
        $annoFlags = @()
        if ($CosignAnnotations) {
            foreach ($pair in $CosignAnnotations.Split(',')) {
                if ([string]::IsNullOrWhiteSpace($pair)) { continue }
                $annoFlags += @('-a', $pair.Trim())
            }
        }

        # Write key to a temp file if provided
        $keyFile = $null
        if ($CosignKey) {
            $keyFile = Join-Path ([IO.Path]::GetTempPath()) ('cosign-key-' + [guid]::NewGuid().ToString('N') + '.pem')
            Set-Content -Path $keyFile -Value $CosignKey -Encoding UTF8 -NoNewline
            if ($CosignKeyPassword) { $env:COSIGN_PASSWORD = $CosignKeyPassword }
        }

        $extraArgs = @()
        if ($CosignArgs) {
            # naive split on spaces; for complex quoting, prefer passing via CosignArgs already tokenized
            $extraArgs = $CosignArgs -split '\s+'
        }

        $cmd = @('sign','--yes')
        if ($keyFile) { $cmd += @('--key', $keyFile) }
        $cmd += $annoFlags
        $cmd += $extraArgs
        $cmd += @($ref)

        Write-Host "Running: cosign $($cmd -join ' ')"
        $out = cosign @cmd 2>&1
        if ($LASTEXITCODE -ne 0) { throw "cosign sign failed: $out" }
        Write-Host "cosign sign succeeded for $ref"
    }

    'CosignAttest' {
        Ensure-CosignAvailable

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
        else {
            throw "Unsupported CosignTarget '$CosignTarget' (use 'GitHub' or 'Private')"
        }

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
                # Create a minimal predicate if none provided
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

        Write-Host "Running: cosign $($cmd -join ' ')"
        $out = cosign @cmd 2>&1
        if ($LASTEXITCODE -ne 0) { throw "cosign attest failed: $out" }
        Write-Host "cosign attest succeeded for $ref"

        if ($tempPredicate -and (Test-Path $predicateFile)) {
            Remove-Item -Force $predicateFile -ErrorAction SilentlyContinue
        }
        if ($keyFile -and (Test-Path $keyFile)) {
            Remove-Item -Force $keyFile -ErrorAction SilentlyContinue
        }
    }

    default { throw "Unknown -Task '$Task'." }
}