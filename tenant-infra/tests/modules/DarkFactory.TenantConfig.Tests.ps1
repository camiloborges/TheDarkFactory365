<#
.SYNOPSIS
    Pester 5 unit tests for DarkFactory.AppCatalog.psm1 and DarkFactory.CSP.psm1
#>

BeforeAll {
    $base     = Join-Path $PSScriptRoot '..\..\modules'
    $stubsDir = Join-Path $PSScriptRoot '..\Stubs'
    Import-Module (Join-Path $stubsDir 'PnP.Stubs.psm1')          -Force
    Import-Module (Join-Path $base 'DarkFactory.Report.psm1')      -Force
    Import-Module (Join-Path $base 'DarkFactory.AppCatalog.psm1')  -Force
    Import-Module (Join-Path $base 'DarkFactory.CSP.psm1')         -Force
}

# ──────────────────────────────────────────────────────────────────────────────
Describe 'Invoke-AppCatalogProvisioning' {
    Context 'When App Catalog does not exist' {
        BeforeEach {
            Mock Get-PnPTenantAppCatalogUrl  -ModuleName DarkFactory.AppCatalog { return $null }
            Mock Register-PnPAppCatalogSite  -ModuleName DarkFactory.AppCatalog { }
        }

        It 'Calls Register-PnPAppCatalogSite' {
            Invoke-AppCatalogProvisioning -Confirm:$false
            Should -Invoke Register-PnPAppCatalogSite -ModuleName DarkFactory.AppCatalog -Times 1 -Exactly
        }

        It 'Returns Created status with propagation warning' {
            $r = Invoke-AppCatalogProvisioning -Confirm:$false
            $r.Status | Should -Be 'Created'
            $r.Detail | Should -Match '⚠'
        }
    }

    Context 'When App Catalog already exists' {
        BeforeEach {
            Mock Get-PnPTenantAppCatalogUrl  -ModuleName DarkFactory.AppCatalog { return 'https://aiwhisperer.sharepoint.com/sites/appcatalog' }
            Mock Register-PnPAppCatalogSite  -ModuleName DarkFactory.AppCatalog { }
        }

        It 'Does NOT call Register-PnPAppCatalogSite' {
            Invoke-AppCatalogProvisioning -Confirm:$false
            Should -Invoke Register-PnPAppCatalogSite -ModuleName DarkFactory.AppCatalog -Times 0
        }

        It 'Returns AlreadyExists with the catalog URL' {
            $r = Invoke-AppCatalogProvisioning -Confirm:$false
            $r.Status | Should -Be 'AlreadyExists'
            $r.Detail | Should -Match 'aiwhisperer'
        }
    }
}

# ──────────────────────────────────────────────────────────────────────────────
Describe 'Invoke-CSPProvisioning' {
    Context 'When SPO CSP cmdlets are available and source is NOT in list' {
        BeforeEach {
            Mock Get-SPOContentSecurityPolicy -ModuleName DarkFactory.CSP { return @('https://other.com') }
            Mock Add-SPOContentSecurityPolicy -ModuleName DarkFactory.CSP { }
            Mock Get-PnPTenant               -ModuleName DarkFactory.CSP { return [PSCustomObject]@{ DelayContentSecurityPolicyEnforcement = $false } }
        }

        It 'Calls Add-SPOContentSecurityPolicy with exact source' {
            Invoke-CSPProvisioning -Source 'https://api.open-meteo.com' -Confirm:$false
            Should -Invoke Add-SPOContentSecurityPolicy -ModuleName DarkFactory.CSP -Times 1 -Exactly
        }

        It 'Returns Created status' {
            $results = Invoke-CSPProvisioning -Source 'https://api.open-meteo.com' -Confirm:$false
            $cspResult = $results | Where-Object { $_.Resource -like 'CSP*' } | Select-Object -First 1
            $cspResult.Status | Should -Be 'Created'
        }
    }

    Context 'When partial host name exists but exact source does NOT (e.g. not-api.open-meteo.com)' {
        BeforeEach {
            Mock Get-SPOContentSecurityPolicy -ModuleName DarkFactory.CSP { return @('https://not-api.open-meteo.com') }
            Mock Add-SPOContentSecurityPolicy -ModuleName DarkFactory.CSP { }
            Mock Get-PnPTenant               -ModuleName DarkFactory.CSP { return [PSCustomObject]@{ DelayContentSecurityPolicyEnforcement = $false } }
        }

        It 'Still calls Add-SPOContentSecurityPolicy (exact match, not substring)' {
            Invoke-CSPProvisioning -Source 'https://api.open-meteo.com' -Confirm:$false
            Should -Invoke Add-SPOContentSecurityPolicy -ModuleName DarkFactory.CSP -Times 1 -Exactly
        }
    }

    Context 'When exact source IS already present' {
        BeforeEach {
            Mock Get-SPOContentSecurityPolicy -ModuleName DarkFactory.CSP { return @('https://api.open-meteo.com') }
            Mock Add-SPOContentSecurityPolicy -ModuleName DarkFactory.CSP { }
            Mock Get-PnPTenant               -ModuleName DarkFactory.CSP { return [PSCustomObject]@{ DelayContentSecurityPolicyEnforcement = $false } }
        }

        It 'Does NOT call Add-SPOContentSecurityPolicy' {
            Invoke-CSPProvisioning -Source 'https://api.open-meteo.com' -Confirm:$false
            Should -Invoke Add-SPOContentSecurityPolicy -ModuleName DarkFactory.CSP -Times 0
        }

        It 'Returns AlreadyExists' {
            $results = Invoke-CSPProvisioning -Source 'https://api.open-meteo.com' -Confirm:$false
            $cspResult = $results | Where-Object { $_.Resource -like 'CSP*' } | Select-Object -First 1
            $cspResult.Status | Should -Be 'AlreadyExists'
        }
    }

    Context 'When CSP enforcement is delayed' {
        BeforeEach {
            Mock Get-SPOContentSecurityPolicy -ModuleName DarkFactory.CSP { return @() }
            Mock Add-SPOContentSecurityPolicy -ModuleName DarkFactory.CSP { }
            Mock Get-PnPTenant               -ModuleName DarkFactory.CSP { return [PSCustomObject]@{ DelayContentSecurityPolicyEnforcement = $true } }
        }

        It 'Returns a SkippedWithWarning result for CSP enforcement' {
            $results = Invoke-CSPProvisioning -Source 'https://api.open-meteo.com' -Confirm:$false
            $warn = $results | Where-Object { $_.Status -eq 'SkippedWithWarning' }
            $warn | Should -Not -BeNullOrEmpty
            $warn.Detail | Should -Match 'delayed'
        }
    }

    Context 'When SPO CSP cmdlets are NOT installed (CommandNotFoundException fallback)' {
        BeforeEach {
            Mock Get-SPOContentSecurityPolicy -ModuleName DarkFactory.CSP { throw [System.Management.Automation.CommandNotFoundException]::new('Get-SPOContentSecurityPolicy') }
            Mock Add-SPOContentSecurityPolicy -ModuleName DarkFactory.CSP { }
        }

        It 'Returns SkippedWithWarning with manual step instructions' {
            $results = Invoke-CSPProvisioning -Source 'https://api.open-meteo.com' -Confirm:$false
            $warn = $results | Where-Object { $_.Status -eq 'SkippedWithWarning' }
            $warn | Should -Not -BeNullOrEmpty
            $warn.Detail | Should -Match 'Manual step'
        }

        It 'Does NOT call Add-SPOContentSecurityPolicy when cmdlets are unavailable' {
            Invoke-CSPProvisioning -Source 'https://api.open-meteo.com' -Confirm:$false
            Should -Invoke Add-SPOContentSecurityPolicy -ModuleName DarkFactory.CSP -Times 0
        }
    }
}
