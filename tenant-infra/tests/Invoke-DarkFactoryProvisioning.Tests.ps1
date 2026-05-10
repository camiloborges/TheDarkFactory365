<#
.SYNOPSIS
    Pester 5 integration tests for Invoke-DarkFactoryProvisioning.ps1
    — idempotency, parameter validation, -WhatIf, partial failure recovery.
#>

BeforeAll {
    $ScriptPath = Join-Path $PSScriptRoot '..\Invoke-DarkFactoryProvisioning.ps1'
    $ModulesDir = Join-Path $PSScriptRoot '..\modules'

    # Load report module for helper in tests
    Import-Module (Join-Path $ModulesDir 'DarkFactory.Report.psm1') -Force

    # Common valid params
    $script:ValidParams = @{
        Latitude     = -36.8509
        Longitude    = 174.7645
        Timezone     = 'Pacific/Auckland'
        LocationName = 'Home'
        City         = 'Auckland'
    }
}

# ──────────────────────────────────────────────────────────────────────────────
Describe 'Parameter Validation' {
    It 'Throws ParameterArgumentValidationError for Latitude > 90' {
        { & $ScriptPath @script:ValidParams -Latitude 91 -WhatIf } | Should -Throw
    }

    It 'Throws ParameterArgumentValidationError for Latitude < -90' {
        { & $ScriptPath @script:ValidParams -Latitude -91 -WhatIf } | Should -Throw
    }

    It 'Throws ParameterArgumentValidationError for Longitude > 180' {
        { & $ScriptPath @script:ValidParams -Longitude 181 -WhatIf } | Should -Throw
    }

    It 'Throws ParameterArgumentValidationError for Longitude < -180' {
        { & $ScriptPath @script:ValidParams -Longitude -181 -WhatIf } | Should -Throw
    }

    It 'Throws for invalid email in GuestEmails' {
        { & $ScriptPath @script:ValidParams -GuestEmails @('not-an-email') -WhatIf } | Should -Throw
    }

    It 'Accepts valid email addresses in GuestEmails' {
        { & $ScriptPath @script:ValidParams -GuestEmails @('valid@example.com') -WhatIf } | Should -Not -Throw
    }
}

# ──────────────────────────────────────────────────────────────────────────────
Describe 'Idempotency — all resources already provisioned' {
    BeforeEach {
        # Mock all provisioning modules to return fully-provisioned state
        Mock Invoke-AppCatalogProvisioning        { New-ProvisioningResult -Resource 'App Catalog'          -Status 'AlreadyExists' -Detail 'https://x.com' }
        Mock Invoke-CSPProvisioning               { New-ProvisioningResult -Resource 'CSP'                  -Status 'AlreadyExists' }
        Mock Invoke-SiteProvisioning              { New-ProvisioningResult -Resource 'DarkFactory site'     -Status 'AlreadyExists' }
        Mock Invoke-ExternalSharingProvisioning   { @(
            New-ProvisioningResult -Resource 'External sharing (tenant)' -Status 'AlreadyCorrect'
            New-ProvisioningResult -Resource 'External sharing (site)'   -Status 'AlreadyCorrect'
        )}
        Mock Invoke-ListProvisioning              { New-ProvisioningResult -Resource 'DarkFactory-Settings list' -Status 'AlreadyExists' }
        Mock Invoke-ListPermissionsProvisioning   { New-ProvisioningResult -Resource 'DarkFactory-Settings permissions' -Status 'AlreadyExists' }
        Mock Invoke-ConfigSeedProvisioning        {
            $SeedEntries | ForEach-Object {
                New-ProvisioningResult -Resource "Seed: $($_.Key)" -Status 'AlreadyExists'
            }
        }
        Mock Invoke-TeamsProvisioning             { @(
            New-ProvisioningResult -Resource 'DarkFactory Teams team' -Status 'AlreadyExists'
            New-ProvisioningResult -Resource 'General channel'        -Status 'AlreadyExists'
        )}
        Mock Get-PowerPlatformEnvironmentUrl      { New-ProvisioningResult -Resource 'Power Platform environment' -Status 'AlreadyExists' }
        Mock Connect-SPOService                   { }
        Mock Connect-PnPOnline                    { }
        Mock Add-PowerAppsAccount                 { }
        Mock Write-ProvisioningReport             { return 0 }

        # Ensure no write cmdlets are defined/callable
        Mock New-PnPSite      { throw 'Should not be called' }
        Mock New-PnPList      { throw 'Should not be called' }
        Mock New-PnPTeamsTeam { throw 'Should not be called' }
        Mock Add-PnPListItem  { throw 'Should not be called' }
        Mock Register-PnPAppCatalogSite { throw 'Should not be called' }
        Mock Add-SPOContentSecurityPolicy { throw 'Should not be called' }
        Mock Add-PnPUser      { throw 'Should not be called' }
    }

    It 'Completes without calling any create/write cmdlets' {
        { & $ScriptPath @script:ValidParams } | Should -Not -Throw
    }
}

# ──────────────────────────────────────────────────────────────────────────────
Describe 'Partial failure recovery' {
    It 'Continues past a failing module and reports failure in results' {
        Mock Invoke-AppCatalogProvisioning        { throw 'Simulated App Catalog failure' }
        Mock Invoke-CSPProvisioning               { New-ProvisioningResult -Resource 'CSP' -Status 'AlreadyExists' }
        Mock Invoke-SiteProvisioning              { New-ProvisioningResult -Resource 'DarkFactory site' -Status 'AlreadyExists' }
        Mock Invoke-ExternalSharingProvisioning   { @() }
        Mock Invoke-ListProvisioning              { New-ProvisioningResult -Resource 'list' -Status 'AlreadyExists' }
        Mock Invoke-ListPermissionsProvisioning   { New-ProvisioningResult -Resource 'perms' -Status 'AlreadyExists' }
        Mock Invoke-ConfigSeedProvisioning        { @() }
        Mock Invoke-TeamsProvisioning             { @() }
        Mock Get-PowerPlatformEnvironmentUrl      { New-ProvisioningResult -Resource 'PP' -Status 'AlreadyExists' }
        Mock Connect-SPOService                   { }
        Mock Connect-PnPOnline                    { }
        Mock Add-PowerAppsAccount                 { }
        Mock Write-ProvisioningReport {
            param($Results)
            # The results array should contain the 'App Catalog' failure
            $failedResult = $Results | Where-Object { $_.Status -eq 'Failed' -and $_.Resource -eq 'App Catalog' }
            $failedResult | Should -Not -BeNullOrEmpty
            return 2
        }

        { & $ScriptPath @script:ValidParams } | Should -Not -Throw
        Should -Invoke Write-ProvisioningReport -Times 1
    }
}

# ──────────────────────────────────────────────────────────────────────────────
Describe 'Edge cases' {
    It 'HasUniqueRoleAssignments=true does NOT call BreakRoleInheritance' {
        $ModulePath = Join-Path $PSScriptRoot '..\modules\DarkFactory.List.psm1'
        Import-Module $ModulePath -Force

        Mock Get-PnPList {
            [PSCustomObject]@{ Title = 'DarkFactory-Settings'; HasUniqueRoleAssignments = $true }
        }
        Mock Set-PnPList            { }
        Mock Set-PnPListPermission  { }

        Invoke-ListPermissionsProvisioning -SiteUrl 'https://t.com' -Confirm:$false
        Should -Invoke Set-PnPList -Times 0
    }

    It 'CSP partial host name (not-api.open-meteo.com) does NOT prevent adding api.open-meteo.com' {
        $ModulePath = Join-Path $PSScriptRoot '..\modules\DarkFactory.CSP.psm1'
        Import-Module $ModulePath -Force

        Mock Get-SPOContentSecurityPolicy { return @('https://not-api.open-meteo.com') }
        Mock Add-SPOContentSecurityPolicy { }
        Mock Get-PnPTenant { return [PSCustomObject]@{ DelayContentSecurityPolicyEnforcement = $false } }

        Invoke-CSPProvisioning -Source 'https://api.open-meteo.com' -Confirm:$false
        Should -Invoke Add-SPOContentSecurityPolicy -Times 1
    }
}
