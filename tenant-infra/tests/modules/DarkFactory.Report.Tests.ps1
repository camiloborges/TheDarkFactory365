<#
.SYNOPSIS
    Pester 5 unit tests for DarkFactory.Report.psm1
#>

BeforeAll {
    $ModulePath = Join-Path $PSScriptRoot '..\..\modules\DarkFactory.Report.psm1'
    Import-Module $ModulePath -Force
}

Describe 'New-ProvisioningResult' {
    It 'Creates a PSCustomObject with all three properties' {
        $r = New-ProvisioningResult -Resource 'App Catalog' -Status 'Created' -Detail 'https://example.com'
        $r.Resource | Should -Be 'App Catalog'
        $r.Status   | Should -Be 'Created'
        $r.Detail   | Should -Be 'https://example.com'
    }

    It 'Detail defaults to empty string when omitted' {
        $r = New-ProvisioningResult -Resource 'Teams' -Status 'AlreadyExists'
        $r.Detail | Should -Be ''
    }

    It 'Throws when Resource is missing' {
        { New-ProvisioningResult -Status 'Created' } | Should -Throw
    }

    It 'Throws when Status is missing' {
        { New-ProvisioningResult -Resource 'X' } | Should -Throw
    }
}

Describe 'Write-ProvisioningReport' {
    BeforeEach {
        # Fixture: one of each status
        $script:Fixture = @(
            New-ProvisioningResult -Resource 'App Catalog'   -Status 'Created'            -Detail 'https://c.com'
            New-ProvisioningResult -Resource 'CSP'           -Status 'AlreadyExists'       -Detail 'Present'
            New-ProvisioningResult -Resource 'DarkFactory site' -Status 'AlreadyCorrect'   -Detail 'Correct'
            New-ProvisioningResult -Resource 'Teams'         -Status 'SkippedWithWarning'  -Detail 'No account'
            New-ProvisioningResult -Resource 'Access'        -Status 'Failed'              -Detail 'Error'
        )
    }

    AfterEach {
        $reportFile = Join-Path (Get-Location) 'darkfactory-provisioning-report.txt'
        if (Test-Path $reportFile) { Remove-Item $reportFile -Force }
    }

    It 'Creates the report file' {
        Write-ProvisioningReport -Results $script:Fixture -TenantDomain 'test.onmicrosoft.com' | Out-Null
        $reportFile = Join-Path (Get-Location) 'darkfactory-provisioning-report.txt'
        Test-Path $reportFile | Should -Be $true
    }

    It 'Report file contains all resource names' {
        Write-ProvisioningReport -Results $script:Fixture | Out-Null
        $content = Get-Content (Join-Path (Get-Location) 'darkfactory-provisioning-report.txt') -Raw
        $content | Should -Match 'App Catalog'
        $content | Should -Match 'CSP'
        $content | Should -Match 'DarkFactory site'
        $content | Should -Match 'Teams'
        $content | Should -Match 'Access'
    }

    It 'Returns exit code 2 when any result is Failed' {
        $exitCode = Write-ProvisioningReport -Results $script:Fixture
        $exitCode | Should -Be 2
    }

    It 'Returns exit code 1 when SkippedWithWarning and no Failed' {
        $results = @(
            New-ProvisioningResult -Resource 'A' -Status 'Created'
            New-ProvisioningResult -Resource 'B' -Status 'SkippedWithWarning' -Detail 'warn'
        )
        $exitCode = Write-ProvisioningReport -Results $results
        $exitCode | Should -Be 1
    }

    It 'Returns exit code 0 when all AlreadyExists or AlreadyCorrect' {
        $results = @(
            New-ProvisioningResult -Resource 'A' -Status 'AlreadyExists'
            New-ProvisioningResult -Resource 'B' -Status 'AlreadyCorrect'
        )
        $exitCode = Write-ProvisioningReport -Results $results
        $exitCode | Should -Be 0
    }

    It 'Appends AppCatalogUrl to report file when provided' {
        Write-ProvisioningReport -Results $script:Fixture -AppCatalogUrl 'https://cat.com' | Out-Null
        $content = Get-Content (Join-Path (Get-Location) 'darkfactory-provisioning-report.txt') -Raw
        $content | Should -Match 'App Catalog URL: https://cat.com'
    }

    It 'Appends PowerPlatformUrl to report file when provided' {
        Write-ProvisioningReport -Results $script:Fixture -PowerPlatformUrl 'https://pp.com' | Out-Null
        $content = Get-Content (Join-Path (Get-Location) 'darkfactory-provisioning-report.txt') -Raw
        $content | Should -Match 'Power Platform Default Environment: https://pp.com'
    }
}
