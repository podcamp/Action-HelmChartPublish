# Pester 5+ tests for HelmChartPublish action
# These tests validate the Prepare task packages a simple Helm chart

Describe 'Invoke-HelmChartPublishAction.ps1 - Prepare' {
    BeforeAll{
        $repoRoot   = Split-Path -Parent $PSScriptRoot
        $scriptPath = Join-Path $repoRoot 'src' 'Invoke-HelmChartPublishAction.ps1'
        if (-not (Test-Path $scriptPath)) {
            throw "Action script not found at $scriptPath"
        }
    }
    BeforeEach {
        Push-Location -Path "TestDrive:\"
        
        # Arrange: create a minimal chart in a temp location
        $chartDir = New-Item -ItemType Directory -Path "TestDrive:\" -Name 'chart' -Force
        if(-not (Test-Path $chartDir)) {
            throw "Failed to create chart directory at $chartDir"
        }
        
        @(
            'apiVersion: v2'
            'name: testchart'
            'version: 0.1.0'
            'appVersion: 0.1.0'
            'type: application'
        ) | Set-Content -Path (Join-Path $chartDir 'Chart.yaml') -Encoding UTF8 | Out-Null
        
        @(
            'global: {}'
            'enabled: true'
        ) | Set-Content -Path (Join-Path $chartDir 'values.yaml') -Encoding UTF8 | Out-Null
    }
    
    AfterEach{
        Pop-Location
    }

    It 'Packages a minimal chart into ./out/<name>-<version>.tgz' -Tag 'integration' {
        # Arrange: create a minimal chart in a temp location
        $currentLocation = Get-Location
        $chartDir = Join-Path $currentLocation 'chart'

        # Ensure clean out folder in repo root
        $outLocation = Join-Path $repoRoot 'out'
        
        if(-not (Test-Path (Join-Path $chartDir 'Chart.yaml'))) {
            throw "Chart.yaml not found in $chartDir"
        }
        
        try {
            if(Test-Path $outLocation) {
                Remove-Item -Recurse -Force -ErrorAction SilentlyContinue $outLocation
            }

            # Act
            & $scriptPath -Task Prepare -ChartPath $chartDir

            # Assert
            $tgzPath = Join-Path $repoRoot 'out/testchart-0.1.0.tgz'
            Test-Path $tgzPath | Should -BeTrue
        }
        finally {
            # Cleanup
            Remove-Item -Recurse -Force -ErrorAction SilentlyContinue $outLocation
        }
    }
}

