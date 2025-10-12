# Pester 5+ tests for HelmChartPublish action
# These tests validate the Prepare task packages a simple Helm chart

BeforeAll {
    Set-StrictMode -Version Latest
}

Describe 'Invoke-HelmChartPublishAction.ps1 - Prepare' {
    BeforeEach {
        Push-Location -Path "TestDrive:\"
        
        # Arrange: create a minimal chart in a temp location
        $chartDir = New-Item -ItemType Directory -Path 'chart'
        @(
            'apiVersion: v2'
            'name: testchart'
            'version: 0.1.0'
            'type: application'
        ) | Set-Content -Path (Join-Path $chartDir 'Chart.yaml') -Encoding UTF8 | Out-Null
    }
    
    AfterEach{
        Pop-Location
    }

    It 'Packages a minimal chart into ./out/<name>-<version>.tgz' -Tag 'integration' {
        # Arrange: create a minimal chart in a temp location
        $currentLocation = Get-Location
        $chartDir = Join-Path $currentLocation 'chart'

        # Ensure clean out folder in repo root
        $outLocation = Join-Path ((Resolve-Path (Join-Path $PSScriptRoot '..')).Path) 'out'
        Push-Location $repoRoot
        try {
            if(Test-Path $outLocation) {
                Remove-Item -Recurse -Force -ErrorAction SilentlyContinue $outLocation
            }

            # Act
            & (Join-Path $repoRoot 'src/Invoke-HelmChartPublishAction.ps1') -Task Prepare -ChartPath $chartDir

            # Assert
            $tgzPath = Join-Path $repoRoot 'out/testchart-0.1.0.tgz'
            Test-Path $tgzPath | Should -BeTrue
        }
        finally {
            # Cleanup
            Remove-Item -Recurse -Force -ErrorAction SilentlyContinue $outLocation
            
            Pop-Location
        }
    }
}

