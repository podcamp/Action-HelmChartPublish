# Pester 5+ tests for HelmChartPublish action
# These tests validate the Prepare task packages a simple Helm chart

BeforeAll {
    Set-StrictMode -Version Latest
}

Describe 'Invoke-HelmChartPublishAction.ps1 - Prepare' {
    It 'Packages a minimal chart into ./out/<name>-<version>.tgz' -Tag 'integration' {
        # Arrange: create a minimal chart in a temp location
        $chartDir = Join-Path $TestDrive 'chart'
        New-Item -ItemType Directory -Path $chartDir | Out-Null
        New-Item -ItemType Directory -Path (Join-Path $chartDir 'templates') | Out-Null

        @(
            'apiVersion: v2'
            'name: testchart'
            'version: 0.1.0'
            'type: application'
        ) | Set-Content -Path (Join-Path $chartDir 'Chart.yaml') -Encoding UTF8

        # Ensure clean out folder in repo root
        $repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
        Push-Location $repoRoot
        try {
            Remove-Item -Recurse -Force -ErrorAction SilentlyContinue 'out'

            # Act
            & (Join-Path $repoRoot 'src/Invoke-HelmChartPublishAction.ps1') -Task Prepare -ChartPath $chartDir

            # Assert
            $tgzPath = Join-Path $repoRoot 'out/testchart-0.1.0.tgz'
            Test-Path $tgzPath | Should -BeTrue
        }
        finally {
            Pop-Location
            # Cleanup
            Remove-Item -Recurse -Force -ErrorAction SilentlyContinue (Join-Path $repoRoot 'out')
        }
    }
}

