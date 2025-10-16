# SPDX-License-Identifier: GPL-3.0
# Copyright (C) 2025 Nicola Preden

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateSet('SetPSGalleryTrusted','DetectModulePath','InstallConvertFromYaml','CheckRelease','Prepare','PublishToGitHubRegistry','PublishToDockerHub','CosignSign')]
    [string]$Task,

    [string]$Token,
    [string]$GitHubApiUrl,
    [string]$TagName,
    [string]$RepositoryUrl,

    [string]$ChartPath,

    # For GitHub registry customization
    [string]$GitHubRegistryPath,

    # For DockerHub
    [string]$DockerHubUsername,
    [string]$DockerHubToken,
    [string]$DockerHubNamespace,
    [string]$DockerHubPath,

    # Cosign parameters
    [string]$CosignTarget,            # 'GitHub' or 'DockerHub'
    [string]$ChartName,
    [string]$ChartVersion,
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
    }
    
    if (-not $chartName) { throw 'Chart name not found in Chart.yaml' }
    if (-not $chartVersion) { throw 'Chart version not found in Chart.yaml' }
    [pscustomobject]@{ Name = $chartName; Version = $chartVersion; ChartFile = $chartFile }
}

# Fallback token from environment if not provided
if (-not $Token) { $Token = $env:GITHUB_TOKEN }

# Dispatch by task using switch for clarity
switch ($Task) {
    'SetPSGalleryTrusted' {
        Set-PSRepository -Name 'PSGallery' -InstallationPolicy Trusted
    }
    'DetectModulePath' {
        $paths = $env:PSModulePath -split [IO.Path]::PathSeparator
        $homePath = $env:HOME
        if (-not $homePath) { $homePath = $env:USERPROFILE }
        $currentUserPath = $paths |
                Where-Object { $_ -like "$homePath*" -and $_ -match '[Pp]ower[Ss]hell[\\/]Modules$' } |
                Select-Object -First 1
        if (-not $currentUserPath) {
            if ($IsWindows) {
                $currentUserPath = Join-Path $homePath 'Documents\PowerShell\Modules'
            } else {
                $currentUserPath = Join-Path $homePath '.local/share/powershell/Modules'
            }
        }
        New-Item -ItemType Directory -Force -Path $currentUserPath | Out-Null

        Write-GithubOutput -Name 'path' -Value $currentUserPath
    }
    'InstallConvertFromYaml' {
        if (-not (Get-Command ConvertFrom-Yaml -ErrorAction SilentlyContinue)) {
            Install-Module -Name powershell-yaml -Scope CurrentUser -Force -AcceptLicense -SkipPublisherCheck
        }
        if (-not (Get-Command ConvertFrom-Yaml -ErrorAction SilentlyContinue)) {
            throw 'ConvertFrom-Yaml is not available even after installing powershell-yaml module.'
        }
    }
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
        $tgz = Get-ChildItem -Path out -Filter "$(
            $info.Name
        )-$(
            $info.Version
        ).tgz" | Select-Object -First 1
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

        $pushOut = helm push "$(
            $tgz.FullName
        )" "$repo" @helmPushProvArgs 2>&1
        if ($LASTEXITCODE -ne 0) { throw "Helm push to $repo failed: $pushOut" }
        Write-Verbose "Pushed chart to $repo"
        break
    }
    'PublishToDockerHub' {
        Test-HelmCliAvailable
        if (-not $DockerHubUsername -or -not $DockerHubToken) { throw 'DockerHubUsername and DockerHubToken are required for PublishToDockerHub' }
        if (-not $DockerHubNamespace) { $DockerHubNamespace = $DockerHubUsername }
        if (-not $DockerHubPath) { $DockerHubPath = 'charts' }

        $tgz = Get-ChildItem -Path out -Filter '*.tgz' | Select-Object -First 1
        if (-not $tgz) { throw 'No packaged chart found under ./out. Run -Task Prepare first.' }

        $helmPushProvArgs = @()
        if (Test-Path ("{0}.prov" -f $tgz.FullName)) { $helmPushProvArgs = @('--prov') }

        $ociHostDh = 'registry-1.docker.io'
        $loginOut = helm registry login $ociHostDh --username $DockerHubUsername --password $DockerHubToken 2>&1
        if ($LASTEXITCODE -ne 0) { throw "Helm registry login to $ociHostDh failed: $loginOut" }

        $repo = "oci://$ociHostDh/$DockerHubNamespace/$DockerHubPath"
        $pushOut = helm push "$(
            $tgz.FullName
        )" "$repo" @helmPushProvArgs 2>&1
        if ($LASTEXITCODE -ne 0) { throw "Helm push to $repo failed: $pushOut" }
        Write-Verbose "Pushed chart to $repo"
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

        # Build a tag-based reference first; we'll resolve it to a digest-based reference
        $ref = $null
        if ($CosignTarget -eq 'GitHub') {
            if (-not $RepositoryUrl) { $RepositoryUrl = $env:GITHUB_REPOSITORY }
            if (-not ($RepositoryUrl -and $RepositoryUrl.Contains('/'))) { throw "Invalid RepositoryUrl '$RepositoryUrl' (expected 'owner/repo')" }
            if (-not $GitHubRegistryPath) { $GitHubRegistryPath = 'charts' }
            $owner = $RepositoryUrl.Split('/')[0]
            $ref = "ghcr.io/$($owner)/$($GitHubRegistryPath)/$($ChartName):$($ChartVersion)"

            # Ensure docker login for GHCR so cosign can push signatures
            $tok = $Token
            if (-not $tok) { $tok = $env:GITHUB_TOKEN }
            if (-not $tok) { throw 'Token or GITHUB_TOKEN is required for ghcr.io docker login in keyless cosign.' }
            $dl = docker login ghcr.io -u $owner -p $tok 2>&1
            if ($LASTEXITCODE -ne 0) { throw "Docker login to ghcr.io failed: $dl" }
        }
        elseif ($CosignTarget -eq 'DockerHub') {
            if (-not $DockerHubNamespace) { $DockerHubNamespace = $DockerHubUsername }
            if (-not $DockerHubNamespace) { throw 'DockerHubNamespace or DockerHubUsername is required for CosignSign when CosignTarget=DockerHub' }
            if (-not $DockerHubPath) { $DockerHubPath = 'charts' }
            $ref = "registry-1.docker.io/$($DockerHubNamespace)/$($DockerHubPath)/$($ChartName):$($ChartVersion)"

            # Ensure docker login for DockerHub so cosign can push signatures
            if (-not $DockerHubUsername -or -not $DockerHubToken) {
                throw 'DockerHubUsername and DockerHubToken are required for docker login in keyless cosign to DockerHub.'
            }
            $dl = docker login registry-1.docker.io -u $DockerHubUsername -p $DockerHubToken 2>&1
            if ($LASTEXITCODE -ne 0) { throw "Docker login to registry-1.docker.io failed: $dl" }
        }
        else { throw "Unsupported CosignTarget '$CosignTarget' (use 'GitHub' or 'DockerHub')" }

        Write-Verbose "Using digest reference: $ref"

        # Common flags
        $annoFlags = @()
        if ($CosignAnnotations) {
            foreach ($pair in $CosignAnnotations.Split(',')) {
                if ([string]::IsNullOrWhiteSpace($pair)) { continue }
                $annoFlags += @('-a', $pair.Trim())
            }
        }
        $extraArgs = @()
        if ($CosignArgs) { $extraArgs = $CosignArgs -split '\s+' }

        # Sign using digest ref
        $signCmd = @('sign','--yes', '--recursive')
        $signCmd += $annoFlags
        $signCmd += $extraArgs
        $signCmd += @($ref)
        Write-Verbose "Running: cosign $($signCmd -join ' ')"
        $signOut = cosign @signCmd 2>&1
        if ($LASTEXITCODE -ne 0) { throw "cosign sign failed: $signOut" }
        Write-Verbose "cosign sign succeeded for $ref"

        # Attest (unified) using digest ref
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
        $attestCmd = @('attest','--yes')
        
        if ($CosignAttestType) { $attestCmd += @('--type', $CosignAttestType) }
        $attestCmd += @('--predicate', $predicateFile)
        $attestCmd += $annoFlags
        $attestCmd += $extraArgs
        $attestCmd += @($ref)
        Write-Verbose "Running: cosign $($attestCmd -join ' ')"
        $attestOut = cosign @attestCmd 2>&1
        if ($LASTEXITCODE -ne 0) { throw "cosign attest failed: $attestOut" }
        Write-Verbose "cosign attest succeeded for $ref"

        if ($tempPredicate -and (Test-Path $predicateFile)) { Remove-Item -Force $predicateFile -ErrorAction SilentlyContinue }
        break
    }
    Default {
        throw "Unknown -Task '$Task'."
    }
}